local gadget = gadget ---@type Gadget
--[[
This gadget classifies dguns fired by the player to three possible outcomes:
* DGUN nominal: the Dgun is a normal dgun that doesn't threaten any allies. This should be most legitimately fired combat dguns (but also includes dguns that only threaten self-owned units)
* DGUN grief negative: the Dgun threatens allied units, but for one reason or another (see below), it is not actually considered griefing
* DGUN grief positive: the Dgun threatens allied units and is considered griefing

Reasons a Dgun would threaten allies, but be classified as not griefing:
* Not enough allied metal value threatened (ignored as inconsequential)
* Commander is on the frontline (all dguns are considered combat dguns that can potentially hit allies for the greater good). Frontline indicators:
  * Enemies nearby on vision, radar, or seismic
  * Enemies recently detected nearby on vision, radar, or seismic (in case allied radar is briefly destroyed, or LOS is briefly lost, etc)
  * Allies damaged nearby recently (implies enemy activity nearby even if it might be jammed)
  * Enemy buildings detected nearby (including building ghosts)

Reasons for these exceptions: some Dguns that hit allies are nonetheless for the greater good. e.g.,
* Dgunning enemy razor but accidentally hitting allied popup nearby;
* Denying reclaim by dgunning allied buildings while the position is actively collapsing to enemy activity;
* Dgunning through allied walls or other pathblocking units to escape enemy comm snipe attempt;
* Dgun attempts at jammed units on high ground (but accidentally clipping allied units)

We don't want to flag legitimate ally-hitting dgun usages as griefing, so these are all marked as grief-negatives.

The goal of this gadget is to eventually ENTIRELY PREVENT the issuance of grief-positive DGun commands. This approach must be first
validated through analytics, however; that's what this gadget gathers.
]]

function gadget:GetInfo()
	return {
		name    = "DGun Griefing Detection",
		desc    = "Logs DGun commands to analytics based on whether they classify as griefing or not.",
		author  = "TheDujin, with Codex. DGun ally detection code by kroIya/Color",
		date    = "2026-05-01",
		license = "GNU GPL, v2 or later",
		layer   = 0,
        version = "1.5",
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	return false
end

local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitsInBox = Spring.GetUnitsInBox
local spGetUnitsInSphere = Spring.GetUnitsInSphere
local spGetTeamInfo = Spring.GetTeamInfo
local spGetPositionLosState = Spring.GetPositionLosState
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetUnitLosState = Spring.GetUnitLosState
local spGetGaiaTeamID = Spring.GetGaiaTeamID
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetGameFrame = Spring.GetGameFrame
local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetUnitHealth = Spring.GetUnitHealth

local CMD_DGUN = CMD.DGUN
local DGUN_RANGE = 280

-- Excessively large dgun safety width to acount for some units, such as behemoths, being quite large.
-- Note that this safety width is only used to find allies that could be POTENTIALLY hit by the DGun.
-- A more precise check is used to evaluated whether a potential ally target is actually in danger.
local DGUN_SAFETY_WIDTH = 100

-- Approximate actual width of the dgun projectile
local DGUN_WIDTH = 20

-- Dguns that threaten less than this amount of metal (in allied units) are ignored as inconsequential
local MIN_THREATENED_ALLY_METAL = 400

-- 1500 is a bit more than the range of a Vanguard
-- In my opinion, there is never a reason to even fire a DGun if there is no frontline action within VANGUARD distance
-- We can tweak this smaller as needed
local FRONTLINE_SCAN_RADIUS = 1500
local gaiaTeamID = spGetGaiaTeamID()

-- Tracks enemy contacts briefly so that dguns are allowed for a few seconds even after contact is lost
local contactsCache = {}
local CONTACT_WINDOW_DURATION = 5 * 30 -- five seconds at 30 gameframes per second
-- Tracks enemy buildings that leave ghosts so they can keep contributing to enemy presence
local enemyBuildingsCache = {}
-- Allies being damaged nearby recently implies we are near combat, so dguns are allowed
local ALLY_DAMAGE_WINDOW = 30 * 30 -- 30 seconds at 30 gameframes per second
local CACHE_PRUNE_INTERVAL = 60 * 30 -- prune expired cache contents every minute
local nextContactPruneFrame = CACHE_PRUNE_INTERVAL
local recentlyDamagedAlliedUnits = {}

function gadget:Initialize()
end

local function GetAllyTeamID(teamID)
	local _, _, _, _, _, allyTeamID = spGetTeamInfo(teamID)
	return allyTeamID
end

local function GetPlayerName(playerID)
	local name = playerID and select(1, spGetPlayerInfo(playerID, false))
	return name or "unknown player"
end

local function GetUnitDisplayName(unitDefID)
	local unitDef = unitDefID and UnitDefs[unitDefID]
	if not unitDef then
		return "unknown_unit"
	end

	return unitDef.name
		or ("unit #" .. tostring(unitDefID))
end

-- Used to determine whether DGun intersects a given unit
local function GetApproxUnitRadius(unitDefID)
	local unitDef = unitDefID and UnitDefs[unitDefID]
	if not unitDef then
		return 0 -- If unknown unit, then we pretend it is tiny. This is to avoid false positives
	end

	if unitDef.radius and unitDef.radius > 0 then
		return unitDef.radius
	end

	local footprintX = unitDef.xsize or 0
	local footprintZ = unitDef.zsize or 0
	local approxRadius = math.min(footprintX, footprintZ) * 4
	return approxRadius
end

-- Removes old frontline contacts that are stale.
-- Nearby frontline contacts enable dguns to be fired indiscriminately
local function PruneExpiredCaches(currentFrame)
	for i = #contactsCache, 1, -1 do
		if contactsCache[i].expiresFrame <= currentFrame then
			table.remove(contactsCache, i)
		end
	end

	for unitID, cache in pairs(recentlyDamagedAlliedUnits) do
		if cache.expiresFrame <= currentFrame then
			recentlyDamagedAlliedUnits[unitID] = nil
		end
	end
end

-- Removes enemy building from our building cache.
-- Nearby enemy buidlings enable dguns to be fired indiscriminately
local function RemoveEnemyBuildingFromCache(unitID)
	enemyBuildingsCache[unitID] = nil
end

-- Adds an enemy building to our building cache.
-- Nearby enemy buidlings enable dguns to be fired indiscriminately
local function AddEnemyBuildingToCache(unitID)
	local unitTeam = spGetUnitTeam(unitID)
	if unitTeam == gaiaTeamID then
		return
	end

	local unitX, unitY, unitZ = spGetUnitPosition(unitID)
	if not unitX then
		return
	end

	enemyBuildingsCache[unitID] = {
		x = unitX,
		y = unitY,
		z = unitZ,
	}
end

-- Updates the enemy building cache based on LOS info on the current frame.
-- Nearby enemy buidlings enable dguns to be fired indiscriminately
local function UpdateEnemyBuildingCache()
	for unitID, site in pairs(enemyBuildingsCache) do
		local _, inLos = spGetPositionLosState(site.x, site.y, site.z, spGetMyAllyTeamID())
		if inLos then
			local unitX, unitY, unitZ = spGetUnitPosition(unitID)
			if not unitX then
				-- building has been destroyed, and we just discovered this
				RemoveEnemyBuildingFromCache(unitID)
			else
				local deltaX = unitX - site.x
				local deltaY = unitY - site.y
				local deltaZ = unitZ - site.z

				-- building has been moved elsewhere, and we just discovered this
				if (deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ) > 1 then
					RemoveEnemyBuildingFromCache(unitID)
				end
			end
		end
	end
end

-- Caches a unit contact briefly. This can be checked for the sake of allowing/disallowing DGun later
local function AddExpiringEnemyContact(x, y, z, currentFrame)
	contactsCache[#contactsCache + 1] = {
		x = x,
		y = y,
		z = z,
		expiresFrame = currentFrame + CONTACT_WINDOW_DURATION,
	}
end

-- Convert a DGun target into a line segment representing the beam path
local function BuildDGunSegment(unitX, unitY, unitZ, targetX, targetY, targetZ)
	local deltaX, deltaY, deltaZ = targetX - unitX, targetY - unitY, targetZ - unitZ
	local dist = math.sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ)
	if dist == 0 then
		dist = 1
	end

	local dirX, dirY, dirZ = deltaX / dist, deltaY / dist, deltaZ / dist
	if dist <= DGUN_RANGE then
		return unitX, unitY, unitZ, unitX + dirX * DGUN_RANGE, unitY + dirY * DGUN_RANGE, unitZ + dirZ * DGUN_RANGE
	end

	return targetX - dirX * DGUN_RANGE, targetY - dirY * DGUN_RANGE, targetZ - dirZ * DGUN_RANGE, targetX, targetY, targetZ
end

-- Measure the shortest distance from a unit position to the DGun beam segment
local function DistPointToSegment(pointX, pointY, pointZ, segmentStartX, segmentStartY, segmentStartZ, segmentEndX, segmentEndY, segmentEndZ)
	local segmentX, segmentY, segmentZ = segmentEndX - segmentStartX, segmentEndY - segmentStartY, segmentEndZ - segmentStartZ
	local offsetX, offsetY, offsetZ = pointX - segmentStartX, pointY - segmentStartY, pointZ - segmentStartZ

	local projectionNumerator = segmentX * offsetX + segmentY * offsetY + segmentZ * offsetZ
	if projectionNumerator <= 0 then
		local deltaX, deltaY, deltaZ = pointX - segmentStartX, pointY - segmentStartY, pointZ - segmentStartZ
		return math.sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ)
	end

	local segmentLengthSquared = segmentX * segmentX + segmentY * segmentY + segmentZ * segmentZ
	if segmentLengthSquared <= projectionNumerator then
		local deltaX, deltaY, deltaZ = pointX - segmentEndX, pointY - segmentEndY, pointZ - segmentEndZ
		return math.sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ)
	end

	local t = projectionNumerator / segmentLengthSquared
	local closestX, closestY, closestZ = segmentStartX + t * segmentX, segmentStartY + t * segmentY, segmentStartZ + t * segmentZ
	local deltaX, deltaY, deltaZ = pointX - closestX, pointY - closestY, pointZ - closestZ
	return math.sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ)
end

-- Returns True and explanation of most expensive threatened ally if DGUN threatens too much allied stuff (see: MIN_THREATENED_ALLY_METAL)
-- Returns False and nill if DGUN threatens nothing
-- Returns False and an explanation if DGUN threatens stuff, but not enough to be concerned about
local function HandleDGunAllyRisk(teamID, startX, startY, startZ, endX, endY, endZ)
	-- Build a cheap box around the beam first, then do the precise segment test
	local minx = math.min(startX, endX) - DGUN_SAFETY_WIDTH
	local maxx = math.max(startX, endX) + DGUN_SAFETY_WIDTH
	local miny = math.min(startY, endY) - DGUN_SAFETY_WIDTH
	local maxy = math.max(startY, endY) + DGUN_SAFETY_WIDTH
	local minz = math.min(startZ, endZ) - DGUN_SAFETY_WIDTH
	local maxz = math.max(startZ, endZ) + DGUN_SAFETY_WIDTH

	local candidates = spGetUnitsInBox(minx, miny, minz, maxx, maxy, maxz)
	local myAllyTeam = GetAllyTeamID(teamID)
	local threatenedAllyMetal = 0
	local mostExpensiveThreatenedMetal = 0
	local mostExpensiveThreatenedUnitName = nil
	for i = 1, #candidates do
		local unitID = candidates[i]
		local unitTeam = spGetUnitTeam(unitID)
		local unitDefID = spGetUnitDefID(unitID)
		local unitRadius = GetApproxUnitRadius(unitDefID)
		-- Self-owned units are exempt (only consider allied owned units).
		if unitTeam and unitTeam ~= teamID and GetAllyTeamID(unitTeam) == myAllyTeam then
			local unitX, unitY, unitZ = spGetUnitPosition(unitID)
			if unitX then
				local d = DistPointToSegment(unitX, unitY, unitZ, startX, startY, startZ, endX, endY, endZ)
				if d < unitRadius + DGUN_WIDTH / 2 then
					local unitDef = unitDefID and UnitDefs[unitDefID]
					local threatenedMetal = 0
					if unitDef then
						-- Partially built units only contribute proportional metal value to threat
						local buildProgress = select(5, spGetUnitHealth(unitID)) or 1
						threatenedMetal = unitDef.metalCost * math.min(buildProgress, 1)
					end
					threatenedAllyMetal = threatenedAllyMetal + threatenedMetal
					if threatenedMetal > mostExpensiveThreatenedMetal then
						mostExpensiveThreatenedMetal = threatenedMetal
						mostExpensiveThreatenedUnitName = GetUnitDisplayName(unitDefID)
					end
				end
			end
		end
	end

	if threatenedAllyMetal >= MIN_THREATENED_ALLY_METAL then
		return true, string.format("DGun threatens %d metal of allies, including %s", threatenedAllyMetal, mostExpensiveThreatenedUnitName or "unknown_unit")
	end

	if threatenedAllyMetal == 0 then
		return false
	end
	
	return false, string.format("Only %d allied metal threatened (inconsequential)", threatenedAllyMetal)
end

-- If DGun target location is near a visible enemy, we leave the order alone
local function HasKnownEnemyNearby(teamID, targetX, targetY, targetZ)
	local myAllyTeam = GetAllyTeamID(teamID)
	local currentFrame = spGetGameFrame()
	PruneExpiredCaches(currentFrame)

	local candidates = spGetUnitsInSphere(targetX, targetY, targetZ, FRONTLINE_SCAN_RADIUS)

	for i = 1, #candidates do
		local unitID = candidates[i]
		local unitTeam = spGetUnitTeam(unitID)
		if unitTeam and unitTeam ~= gaiaTeamID and GetAllyTeamID(unitTeam) ~= myAllyTeam then
			local losState = spGetUnitLosState(unitID, myAllyTeam, true)
			if losState and (losState % 4) > 0 then
				return true, "Enemies on radar/LOS within range"
			end
		end
	end

	-- Treat recent contacts as enemy presence.
	for i = 1, #contactsCache do
		local ping = contactsCache[i]
		local deltaX, deltaY, deltaZ = ping.x - targetX, ping.y - targetY, ping.z - targetZ
		if (deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ) <= (FRONTLINE_SCAN_RADIUS * FRONTLINE_SCAN_RADIUS) then
			return true, "Enemies recently on radar/seismic within range"
		end
	end

	-- Allied units damaged nearby implies we are on the frontline
	for _, cache in pairs(recentlyDamagedAlliedUnits) do
		local deltaX, deltaY, deltaZ = cache.x - targetX, cache.y - targetY, cache.z - targetZ
		if (deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ) <= (FRONTLINE_SCAN_RADIUS * FRONTLINE_SCAN_RADIUS) then
			return true, "Allies recently damaged nearby"
		end
	end

	-- Nearby enemy buildings implies we are on the frontline
	for _, site in pairs(enemyBuildingsCache) do
		local deltaX, deltaY, deltaZ = site.x - targetX, site.y - targetY, site.z - targetZ
		if (deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ) <= (FRONTLINE_SCAN_RADIUS * FRONTLINE_SCAN_RADIUS) then
			return true, "Enemy buildings nearby"
		end
	end

	return false
end

local function ForwardAnalyticsEvent(eventType, eventData)
	if Script.LuaUI and Script.LuaUI.DGunGriefingDetection then
		Script.LuaUI.DGunGriefingDetection(eventType, eventData)
	end
end

local function GetGameID()
	return Game.gameID or spGetGameRulesParam("GameID")
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if unitTeam == gaiaTeamID then
		return
	end

	local myAllyTeam = spGetMyAllyTeamID()
	if GetAllyTeamID(unitTeam) ~= myAllyTeam then
		return -- not one of our allies that was damaged
	end

	if attackerTeam and attackerTeam ~= gaiaTeamID and GetAllyTeamID(attackerTeam) ~= myAllyTeam then
		local unitX, unitY, unitZ = spGetUnitPosition(unitID)
		if unitX then
			recentlyDamagedAlliedUnits[unitID] = {
				x = unitX,
				y = unitY,
				z = unitZ,
				expiresFrame = spGetGameFrame() + ALLY_DAMAGE_WINDOW,
			}
		end
	end
end

function gadget:UnitEnteredLos(unitID, unitTeam, allyTeam)
	if allyTeam ~= spGetMyAllyTeamID() then
		return -- not an event for us
	end
	if Spring.GetUnitLeavesGhost(unitID) then
		AddEnemyBuildingToCache(unitID)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	local site = enemyBuildingsCache[unitID]
	if not site then
		return
	end

	local _, inLos = spGetPositionLosState(site.x, site.y, site.z, spGetMyAllyTeamID())
	if inLos then
		RemoveEnemyBuildingFromCache(unitID)
	end
end

function gadget:UnitTaken(unitID, unitDefID, oldTeamID, newTeamID)
	if not spAreTeamsAllied(oldTeamID, newTeamID) then
		RemoveEnemyBuildingFromCache(unitID) -- unit changed team ownership
	end
end

function gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
	if not spAreTeamsAllied(oldTeamID, newTeamID) then
		local myAllyTeam = spGetMyAllyTeamID()
		if GetAllyTeamID(newTeamID) ~= myAllyTeam and Spring.GetUnitLeavesGhost(unitID) then
			AddEnemyBuildingToCache(unitID) -- building now owned by enemy
		end
	end
end

-- Cache units that leave radar briefly so they count as visible enemy presence
-- This allows players to attempt dguns even if radar contact is lost.
function gadget:UnitLeftRadar(unitID, unitTeam, allyTeam, unitDefID)
	if unitTeam == gaiaTeamID then
		return
	end

	if allyTeam ~= spGetMyAllyTeamID() then
		return -- not an event for us
	end

	local unitX, unitY, unitZ = spGetUnitPosition(unitID)
	if not unitX then
		return
	end

	AddExpiringEnemyContact(unitX, unitY, unitZ, spGetGameFrame())
end

-- Cache seismic detections briefly so they count as visible enemy presence.
function gadget:UnitSeismicPing(positionX, positionY, positionZ, strength, allyTeam, unitID, unitDefID)
	if allyTeam ~= spGetMyAllyTeamID() then
		return -- not an event for us
	end
	AddExpiringEnemyContact(positionX, positionY, positionZ, spGetGameFrame())
end

function gadget:GameFrame(currentFrame)
	UpdateEnemyBuildingCache()
	if currentFrame < nextContactPruneFrame then
		return
	end

	if #contactsCache > 0 then
		PruneExpiredCaches(currentFrame)
	end

	while nextContactPruneFrame <= currentFrame do
		nextContactPruneFrame = nextContactPruneFrame + CACHE_PRUNE_INTERVAL
	end
end

-- Observe DGun commands and write analytics
function gadget:UnitCmdDone(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if teamID ~= Spring.GetMyTeamID() then
		return -- not one of our commands
	end
	if cmdID ~= CMD_DGUN then
		return
	end

	local uDef = UnitDefs[unitDefID]
	if not (uDef.customParams and uDef.customParams.iscommander) then
		return
	end

	local unitX, unitY, unitZ = spGetUnitPosition(unitID)
	if not unitX then
		return
	end

	local targetX, targetY, targetZ
	if #cmdParams == 1 and cmdParams[1] > 0 then
		targetX, targetY, targetZ = spGetUnitPosition(cmdParams[1])
	else
		targetX, targetY, targetZ = cmdParams[1], cmdParams[2], cmdParams[3]
	end
	if not targetX then
		return
	end

	local startX, startY, startZ, endX, endY, endZ = BuildDGunSegment(unitX, unitY, unitZ, targetX, targetY, targetZ)

	local risksAllies, allyThreatInfo = HandleDGunAllyRisk(teamID, startX, startY, startZ, endX, endY, endZ)

	if not risksAllies then
		if allyThreatInfo then
			ForwardAnalyticsEvent("dgun_grief_negative", {
				position = { targetX, targetY, targetZ },
				time = spGetGameFrame(),
				gameID = GetGameID(),
				player = GetPlayerName(playerID),
				reason = allyThreatInfo,
			})
		else
			ForwardAnalyticsEvent("dgun_nominal", {
				position = { targetX, targetY, targetZ },
				time = spGetGameFrame(),
				gameID = GetGameID(),
				player = GetPlayerName(playerID),
				reason = "No allies threatened",
			})

		end
		return
	end

	local enemiesNearby, explanation = HasKnownEnemyNearby(teamID, targetX, targetY, targetZ)

	if enemiesNearby then
		ForwardAnalyticsEvent("dgun_grief_negative", {
			position = { targetX, targetY, targetZ },
			time = spGetGameFrame(),
			gameID = GetGameID(),
			player = GetPlayerName(playerID),
			reason = explanation,
		})
		return
	end

	ForwardAnalyticsEvent("dgun_grief_positive", {
		position = { targetX, targetY, targetZ },
		time = spGetGameFrame(),
		gameID = GetGameID(),
		player = GetPlayerName(playerID),
		reason = allyThreatInfo,
	})
end
