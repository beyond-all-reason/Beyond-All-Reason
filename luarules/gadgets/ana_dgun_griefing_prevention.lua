local gadget = gadget ---@type Gadget
--[[
This gadget classifies dguns fired by the player to three possible outcomes:
* DGUN nominal: the Dgun is a normal dgun that doesn't threaten any allies. This should be most legitimately fired combat dguns (but also includes dguns that only threaten self-owned units)
* DGUN grief negative: the Dgun threatens allied units, but for one reason or another (see below), it is not actually considered griefing
* DGUN grief positive: the Dgun threatens allied units and is considered griefing

Reasons a Dgun would threaten allies, but be classified as not griefing:
* Commander is on the frontline (all dguns are considered combat dguns that can potentially hit allies for the greater good). Frontline indicators:
  * Enemies nearby on vision, radar, or seismic
  * Enemies recently detected nearby on vision, radar, or seismic (in case allied radar is briefly destroyed, or LOS is briefly lost, etc)
  * Allies damaged nearby recently (implies enemy activity nearby even if it might be jammed)
  * Enemy unit ghosts detected nearby (generally: enemy buildings. But there are other types of ghosts)
* Not enough allied power threatened (ignored as inconsequential)

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
		author  = "TheDujin. DGun ally detection code by kroIya/Color",
		date    = "2026-05-01",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	return false
end

local CallAsTeam = CallAsTeam

local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitsInSphere = Spring.GetUnitsInSphere
local spGetUnitsInPlanes = Spring.GetUnitsInPlanes
local spGetTeamInfo = Spring.GetTeamInfo
local spGetPositionLosState = Spring.GetPositionLosState
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetUnitLosState = Spring.GetUnitLosState
local spGetGaiaTeamID = Spring.GetGaiaTeamID
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetMyTeamID = Spring.GetMyTeamID
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetGameFrame = Spring.GetGameFrame
local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetUnitHealth = Spring.GetUnitHealth
local ALLY_UNITS = Spring.ALLY_UNITS
local ENEMY_UNITS = Spring.ENEMY_UNITS

-- cached unitDef lookups
local isCommander = {}
local unitPower = {}
local unitDisplayName = {}
local unitApproxRadius = {}

for unitDefID, unitDef in ipairs(UnitDefs) do
	local customParams = unitDef.customParams
	if customParams and customParams.iscommander then
		isCommander[unitDefID] = true
	end

	unitPower[unitDefID] = unitDef.power or 0
	unitDisplayName[unitDefID] = unitDef.name or ("unit #" .. tostring(unitDefID))

	local radius = unitDef.radius
	if radius and radius > 0 then
		unitApproxRadius[unitDefID] = radius
	else
		local footprintX = unitDef.xsize or 0
		local footprintZ = unitDef.zsize or 0
		unitApproxRadius[unitDefID] = math.min(footprintX, footprintZ) * 4
	end
end

local CMD_DGUN = CMD.DGUN
local DGUN_RANGE = 280

-- Excessively large dgun safety width to acount for some units, such as behemoths, being quite large.
-- Note that this safety width is only used to find allies that could be POTENTIALLY hit by the DGun.
-- A more precise check is used to evaluated whether a potential ally target is actually in danger.
local DGUN_SAFETY_WIDTH = 100

-- Approximate actual width of the dgun projectile
local DGUN_WIDTH = 20

local function GetConstructionTurretPower()
	local unitDef = UnitDefNames.armnanotc or UnitDefNames.cornanotc or UnitDefNames.legnanotc
	return (unitDef and unitPower[unitDef.id]) or 0
end

-- Dguns that threaten less than this amount of allied power are ignored as inconsequential.
-- Cutoff is arbitrary chosen as 150% the power value of a construction turret
local MIN_THREATENED_ALLY_POWER = GetConstructionTurretPower() * 1.5

-- 1500 is a bit more than the range of a Vanguard
-- In my opinion, there is never a reason to even fire a DGun if there is no frontline action within VANGUARD distance
-- We can tweak this smaller as needed
local FRONTLINE_SCAN_RADIUS = 1500
local gaiaTeamID = spGetGaiaTeamID()

-- Tracks enemy contacts briefly so that dguns are allowed for a few seconds even after contact is lost
-- Note that this table uses a queue/head structure to reduce cache modification cost to amortized O(1)
local contactsCache = {}
local contactsHead = 1
local CONTACT_WINDOW_DURATION = 5 * Game.gameSpeed -- five seconds

-- Tracks enemy ghosts (generally: building ghosts) so they can keep contributing to enemy presence
local enemyGhostsCache = {}
local ENEMY_GHOST_UPDATE_INTERVAL = 10 -- check ghost LOS on this interval (frame count)
local nextEnemyGhostUpdateFrame = 0

-- Allies being damaged nearby recently implies we are near combat, so dguns are allowed
local recentlyDamagedAlliedUnits = {}
local ALLY_DAMAGE_WINDOW = 20 * Game.gameSpeed -- 20 seconds

local CACHE_PRUNE_INTERVAL = 60 * Game.gameSpeed -- prune expired cache contents every minute
local nextContactPruneFrame = CACHE_PRUNE_INTERVAL

-- cache these for faster lookups
local myTeamID = spGetMyTeamID()
local myAllyTeamID = spGetMyAllyTeamID()
local allyTeamIDCache = {}


-- Called if player becomes spec (or god forbid, player changes teams or ally-teams somehow? Shouldn't be possible in real game?)
local function RefreshPlayerState()
	myTeamID = spGetMyTeamID()
	myAllyTeamID = spGetMyAllyTeamID()

	contactsCache = {}
	contactsHead = 1
	enemyGhostsCache = {}
	allyTeamIDCache = {}
end

local function GetAllyTeamID(teamID)
	local cachedAllyTeamID = allyTeamIDCache[teamID]
	if cachedAllyTeamID ~= nil then
		return cachedAllyTeamID
	end

	local _, _, _, _, _, allyTeamID = spGetTeamInfo(teamID)
	allyTeamIDCache[teamID] = allyTeamID
	return allyTeamID
end

local function GetPlayerName(playerID)
	return playerID and spGetPlayerInfo(playerID, false) or "unknown player"
end

local function GetUnitDisplayName(unitDefID)
	return unitDefID and unitDisplayName[unitDefID] or "unknown_unit"
end

-- Used to determine whether DGun intersects a given unit
local function GetApproxUnitRadius(unitDefID)
	return unitDefID and unitApproxRadius[unitDefID] or 0 -- If unknown unit, then we pretend it is tiny. This is to avoid false positives
end

local function MakePlane(normalX, normalY, normalZ, pointX, pointY, pointZ)
	return {normalX, normalY, normalZ, -(normalX * pointX + normalY * pointY + normalZ * pointZ)}
end

local function BuildBeamPrismPlanes(startX, startY, startZ, endX, endY, endZ, halfWidth)
	-- compute Dgun vector
	local deltaX, deltaY, deltaZ = endX - startX, endY - startY, endZ - startZ
	local length = math.sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ)
	if length == 0 then
		length = 1
	end

	-- normalizes vector of Dgun
	local axisX, axisY, axisZ = deltaX / length, deltaY / length, deltaZ / length

	-- arbitrary vector so we can do cross product to find an orthogonal vector to the original one
	local refX, refY, refZ = 0, 1, 0
	if math.abs(axisY) > 0.9 then
		refX, refY, refZ = 1, 0, 0
	end

	local sideX = axisY * refZ - axisZ * refY
	local sideY = axisZ * refX - axisX * refZ
	local sideZ = axisX * refY - axisY * refX
	local sideLength = math.sqrt(sideX * sideX + sideY * sideY + sideZ * sideZ)
	if sideLength == 0 then
		sideLength = 1
	end
	sideX, sideY, sideZ = sideX / sideLength, sideY / sideLength, sideZ / sideLength

	-- third orthogonal vector
	local upX = axisY * sideZ - axisZ * sideY
	local upY = axisZ * sideX - axisX * sideZ
	local upZ = axisX * sideY - axisY * sideX

	local centerX = (startX + endX) * 0.5
	local centerY = (startY + endY) * 0.5
	local centerZ = (startZ + endZ) * 0.5

	local planes = {
		MakePlane(-axisX, -axisY, -axisZ, startX, startY, startZ), -- excludes units behind dgun
		MakePlane(axisX, axisY, axisZ, endX, endY, endZ), -- excludes units ahead of dgun
		MakePlane(sideX, sideY, sideZ, centerX + sideX * halfWidth, centerY + sideY * halfWidth, centerZ + sideZ * halfWidth), -- excludes units to the "right side" of dgun
		MakePlane(-sideX, -sideY, -sideZ, centerX - sideX * halfWidth, centerY - sideY * halfWidth, centerZ - sideZ * halfWidth), -- excludes units to the "left side" of dgun
		MakePlane(upX, upY, upZ, centerX + upX * halfWidth, centerY + upY * halfWidth, centerZ + upZ * halfWidth), -- excludes units "above" the dgun
		MakePlane(-upX, -upY, -upZ, centerX - upX * halfWidth, centerY - upY * halfWidth, centerZ - upZ * halfWidth), -- excludes units "below" the dgun
	}

	Spring.Echo("BuildBeamPrismPlanes", "start", startX, startY, startZ, "end", endX, endY, endZ, "halfWidth", halfWidth)
	-- for i = 1, #planes do
	-- 	local plane = planes[i]
	-- 	Spring.Echo("plane", i, "n", plane.normalVecX, plane.normalVecY, plane.normalVecZ, "d", plane.d)
	-- end

	return planes
end

-- Removes old frontline contacts that are stale.
-- Nearby frontline contacts enable dguns to be fired indiscriminately
local function PruneExpiredContacts(currentFrame)
	while contactsHead <= #contactsCache do
		local contact = contactsCache[contactsHead]
		if contact.expiresFrame > currentFrame then
			break
		end

		contactsHead = contactsHead + 1
	end

	if contactsHead > #contactsCache then
		contactsCache = {}
		contactsHead = 1
	elseif contactsHead > 64 and contactsHead * 2 > #contactsCache then
		local compactedContactsCache = {}
		local newIndex = 1
		for i = contactsHead, #contactsCache do
			compactedContactsCache[newIndex] = contactsCache[i]
			newIndex = newIndex + 1
		end
		contactsCache = compactedContactsCache
		contactsHead = 1
	end

	for unitID, cache in pairs(recentlyDamagedAlliedUnits) do
		if cache.expiresFrame <= currentFrame then
			recentlyDamagedAlliedUnits[unitID] = nil
		end
	end
end

-- Removes enemy ghost from our ghost cache.
-- Nearby enemy ghosts enable dguns to be fired indiscriminately
local function RemoveEnemyGhostFromCache(unitID)
	enemyGhostsCache[unitID] = nil
end

-- Adds an enemy ghost to our ghost cache.
-- Nearby enemy ghosts enable dguns to be fired indiscriminately
local function AddEnemyGhostToCache(unitID)
	local unitTeam = spGetUnitTeam(unitID)
	if unitTeam == gaiaTeamID then
		return
	end

	local unitX, unitY, unitZ = spGetUnitPosition(unitID)
	if not unitX then -- shouldn't happen, just in case...
		return
	end

	local cache = enemyGhostsCache[unitID]
	if cache then
		cache.x = unitX
		cache.y = unitY
		cache.z = unitZ
		return
	end

	enemyGhostsCache[unitID] = {
		x = unitX,
		y = unitY,
		z = unitZ,
	}
end

-- Updates the enemy ghost cache every couple frames based on current LOS info.
-- Nearby enemy ghosts enable dguns to be fired indiscriminately
local function UpdateEnemyGhostCache(currentFrame)
	if currentFrame < nextEnemyGhostUpdateFrame then
		return
	end
	nextEnemyGhostUpdateFrame = currentFrame + ENEMY_GHOST_UPDATE_INTERVAL

	if not next(enemyGhostsCache) then
		return
	end

	for unitID, site in pairs(enemyGhostsCache) do
		local _, inLos = spGetPositionLosState(site.x, site.y, site.z, myAllyTeamID)
		if inLos then
			local unitX, unitY, unitZ = spGetUnitPosition(unitID)
			if not unitX then
				-- the unit represented by this ghost has been destroyed, and we just discovered this
				RemoveEnemyGhostFromCache(unitID)
			else
				local deltaX = unitX - site.x
				local deltaY = unitY - site.y
				local deltaZ = unitZ - site.z

				-- the unit represented by this ghost has been moved elsewhere, and we just discovered this
				if (deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ) > 1 then
					RemoveEnemyGhostFromCache(unitID)
				end
			end
		end
	end
end

-- Caches an enemy unit contact briefly.
-- Nearby frontline contacts enable dguns to be fired indiscriminately
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

-- Returns True and explanation of most powerful threatened ally if DGUN threatens too much allied stuff (see: MIN_THREATENED_ALLY_POWER)
-- Returns False and nil if DGUN threatens nothing
-- Returns False and an explanation if DGUN threatens stuff, but not enough to be concerned about
local function HandleDGunAllyRisk(teamID, startX, startY, startZ, endX, endY, endZ)
	-- Build a prism around the beam, then filter allied units manually.
	-- Note: we would rather use the allegiance parameter with ALLY_UNITS. However, as of 2026-08-20, there is an engine-side bug that throws uncaught exception when trying to use it.
	-- TODO use allegiance parameter once sprunk's fix is published in live engine version
	local candidates = CallAsTeam(myTeamID, spGetUnitsInPlanes, BuildBeamPrismPlanes(startX, startY, startZ, endX, endY, endZ, DGUN_WIDTH / 2))
	local threatenedAllyPower = 0
	local mostPowerfulThreatenedPower = 0
	local mostPowerfulThreatenedUnitName = nil
	for i = 1, #candidates do
		local unitID = candidates[i]
		local unitDefID = spGetUnitDefID(unitID)
		local unitTeam = spGetUnitTeam(unitID)

		-- Exclude self-owned units (should always be allowed to shoot those)
		-- Exclude non-allied units and allied comms (you can't DGun grief an allied comm)
		if unitTeam and unitTeam ~= myTeamID and spAreTeamsAllied(unitTeam, myTeamID) and not isCommander[unitDefID] then
			local unitX = spGetUnitPosition(unitID)
			if unitX then -- FIXME this check may be a relic of old line segment stuff
				local _, _, _, captureProgress, buildProgress = spGetUnitHealth(unitID)
				if (captureProgress or 0) > 0 then
					-- A unit being captured implies presence of cloaked/jammed enemy comm or enemy decoy.
					-- It is ok to dgun to prevent unit capture.
					return false, string.format("DGun is targeting allied %s, which is currently being captured", GetUnitDisplayName(unitDefID))
				end

				local threatenedPower = 0
				-- Partially built units only contribute proportional power to threat.
				-- This is to prevent a malicious player from triggering false positives
				-- by trapping an allied comm with a bunch of 1%-built AFUS blueprints or something similar.
				buildProgress = buildProgress or 1
				threatenedPower = (unitPower[unitDefID] or 0) * math.min(buildProgress, 1)
				threatenedAllyPower = threatenedAllyPower + threatenedPower
				if threatenedPower > mostPowerfulThreatenedPower then
					mostPowerfulThreatenedPower = threatenedPower
					mostPowerfulThreatenedUnitName = GetUnitDisplayName(unitDefID)
				end
			end
		end
	end

	if threatenedAllyPower >= MIN_THREATENED_ALLY_POWER then
		return true, string.format("DGun threatens %d allied power, including %s", threatenedAllyPower, mostPowerfulThreatenedUnitName or "unknown_unit")
	end

	if threatenedAllyPower == 0 then
		return false
	end
	
	return false, string.format("Only %d allied power threatened, including %s. Ignored as inconsequential", threatenedAllyPower, mostPowerfulThreatenedUnitName or "unknown_unit")
end

-- If DGun target location is near a visible enemy, it can be fired indiscriminately (it won't be classified as griefing)
local function HasKnownEnemyNearby(teamID, targetX, targetY, targetZ)
	local currentFrame = spGetGameFrame()
	PruneExpiredContacts(currentFrame)

	local candidates = CallAsTeam(myTeamID, spGetUnitsInSphere, targetX, targetY, targetZ, FRONTLINE_SCAN_RADIUS, ENEMY_UNITS)

	for i = 1, #candidates do
		local unitID = candidates[i]
		local losState = spGetUnitLosState(unitID, myAllyTeamID, true)
		local unitTeam = spGetUnitTeam(unitID)
		-- Turns out seagulls and such are counted. So need to gaia check
		if unitTeam ~= gaiaTeamID and losState and (losState % 4) > 0 then
			return true, "Enemies on radar/LOS within range"
		end
	end

	-- Treat recent contacts as enemy presence.
	for i = contactsHead, #contactsCache do
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

	-- Nearby enemy ghosts implies we are on the frontline
	for _, site in pairs(enemyGhostsCache) do
		local deltaX, deltaY, deltaZ = site.x - targetX, site.y - targetY, site.z - targetZ
		if (deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ) <= (FRONTLINE_SCAN_RADIUS * FRONTLINE_SCAN_RADIUS) then
			return true, "Enemy ghosts nearby (usually: building ghosts)"
		end
	end

	return false
end

local function ForwardAnalyticsEvent(eventType, eventData)
	Script.LuaUI.DGunGriefingDetection(eventType, eventData)
end

local function GetGameID()
	return Game.gameID or spGetGameRulesParam("GameID")
end

function gadget:Initialize()
	RefreshPlayerState()
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if GetAllyTeamID(unitTeam) ~= myAllyTeamID then
		return -- not one of our allies that was damaged
	end

	if not (attackerTeam and attackerTeam ~= gaiaTeamID and GetAllyTeamID(attackerTeam) ~= myAllyTeamID) then
		return
	end

	local unitX, unitY, unitZ = spGetUnitPosition(unitID)
	if not unitX then
		return
	end

	local expiresFrame = spGetGameFrame() + ALLY_DAMAGE_WINDOW
	local cache = recentlyDamagedAlliedUnits[unitID]
	if cache then
		cache.x = unitX
		cache.y = unitY
		cache.z = unitZ
		cache.expiresFrame = expiresFrame
	else
		recentlyDamagedAlliedUnits[unitID] = {
			x = unitX,
			y = unitY,
			z = unitZ,
			expiresFrame = expiresFrame,
		}
	end
end

function gadget:UnitLeftLos(unitID, unitTeam, allyTeam)
	-- If it's an enemy ghost, add to cache. Otherwise don't worry about it
	if allyTeam ~= myAllyTeamID or unitTeam == gaiaTeamID then
		return -- not an event for us
	end

	local unitDefID = spGetUnitDefID(unitID)
	local unitX, unitY, unitZ = spGetUnitPosition(unitID)
	Spring.Echo(
		"UnitLeftLos:",
		"unitID", unitID,
		"name", GetUnitDisplayName(unitDefID),
		"team", unitTeam,
		"allied", GetAllyTeamID(unitTeam) == myAllyTeamID,
		"pos", unitX, unitY, unitZ
	)

	if Spring.GetUnitLeavesGhost(unitID) then
		AddEnemyGhostToCache(unitID)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	-- If it's a ghost, remove from cache. Otherwise don't worry about it
	local site = enemyGhostsCache[unitID]
	if not site then
		return
	end

	local _, inLos = spGetPositionLosState(site.x, site.y, site.z, myAllyTeamID)
	if inLos then
		RemoveEnemyGhostFromCache(unitID)
	end
end

function gadget:UnitTaken(unitID, unitDefID, oldTeamID, newTeamID)
	if not spAreTeamsAllied(oldTeamID, newTeamID) then
		RemoveEnemyGhostFromCache(unitID) -- unit changed team ownership
	end
end

function gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
	if not spAreTeamsAllied(oldTeamID, newTeamID) then
		if GetAllyTeamID(newTeamID) ~= myAllyTeamID and Spring.GetUnitLeavesGhost(unitID) then
			AddEnemyGhostToCache(unitID) -- ghost now owned by enemy
		end
	end
end

-- Cache units that leave radar briefly so they count as visible enemy presence
-- This allows players to attempt dguns even if radar contact is lost.
function gadget:UnitLeftRadar(unitID, unitTeam, allyTeam, unitDefID)
	if allyTeam ~= myAllyTeamID then
		return -- not an event for us
	end

	if unitTeam == gaiaTeamID then
		return
	end

	local unitX, unitY, unitZ = spGetUnitPosition(unitID)
	if not unitX then
		return
	end

	AddExpiringEnemyContact(unitX, unitY, unitZ, spGetGameFrame())
end

-- Cache seismic detections briefly so they count as visible enemy presence.
function gadget:UnitSeismicPing(positionX, positionY, positionZ, strength, allyTeam, unitID, unitDefID)
	if allyTeam ~= myAllyTeamID then
		return -- not an event for us
	end
	AddExpiringEnemyContact(positionX, positionY, positionZ, spGetGameFrame())
end

function gadget:GameFrame(currentFrame)
	UpdateEnemyGhostCache(currentFrame)
	if currentFrame < nextContactPruneFrame then
		return
	end

	if contactsCache[contactsHead + 1] then -- slightly more performant way of checking "is head <= length of cache"
		PruneExpiredContacts(currentFrame)
	end

	nextContactPruneFrame = nextContactPruneFrame + CACHE_PRUNE_INTERVAL
end

function gadget:PlayerChanged(playerID)
	RefreshPlayerState()
end

-- Observe DGun commands and write analytics
function gadget:UnitCmdDone(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if not (cmdID == CMD_DGUN and teamID == myTeamID and isCommander[unitDefID]) then
		return -- only care about DGUN commands issued by this player fired from non-decoy comms
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
		return -- shouldn't happen, just in case...
	end

	local startX, startY, startZ, endX, endY, endZ = BuildDGunSegment(unitX, unitY, unitZ, targetX, targetY, targetZ)
	Spring.Echo("DGun segment", "start", startX, startY, startZ, "end", endX, endY, endZ)

	local enemiesNearby, explanation = HasKnownEnemyNearby(teamID, targetX, targetY, targetZ)

	local risksAllies, allyThreatInfo = HandleDGunAllyRisk(teamID, startX, startY, startZ, endX, endY, endZ)

	-- If no allies threatened, then it's a nominal dgun
	if not risksAllies and not allyThreatInfo then
		ForwardAnalyticsEvent("dgun_nominal", {
			position = { targetX, targetY, targetZ },
			time = spGetGameFrame(),
			gameID = GetGameID(),
			player = GetPlayerName(playerID),
			reason = "No allies threatened",
		})
		return
	end

	-- If frontline indicators are present, then all DGuns are ok
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

	-- If no frontline indicators are present and we don't threaten enough allied metal (or we are Dgunning to prevent capture), it's ok
	if not risksAllies and allyThreatInfo then
		ForwardAnalyticsEvent("dgun_grief_negative", {
			position = { targetX, targetY, targetZ },
			time = spGetGameFrame(),
			gameID = GetGameID(),
			player = GetPlayerName(playerID),
			reason = allyThreatInfo,
		})
		return
	end

	-- Otherwise it's classified as griefing
	ForwardAnalyticsEvent("dgun_grief_positive", {
		position = { targetX, targetY, targetZ },
		time = spGetGameFrame(),
		gameID = GetGameID(),
		player = GetPlayerName(playerID),
		reason = allyThreatInfo,
	})
end
