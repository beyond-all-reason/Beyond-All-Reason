local gadget = gadget ---@type Gadget

-- FIXME:
-- - logging/notification only version
-- - explore ideas on how to deal with jammed high ground units (but there's allied stuff blocking you)

function gadget:GetInfo()
	return {
		name    = "DGun Griefing Prevention",
		desc    = "Logs DGun commands that intersect allied units and echoes a warning when the threatened metal value is high enough.",
		author  = "TheDujin, with Codex. DGun ally detection code by kroIya/Color",
		date    = "2026-05-01",
		license = "GNU GPL, v2 or later",
		layer   = 0,
        version = "1.2",
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
local spGetUnitLosState = Spring.GetUnitLosState
local spGetGaiaTeamID = Spring.GetGaiaTeamID
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetGameFrame = Spring.GetGameFrame
local spGetGameRulesParam = Spring.GetGameRulesParam

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
-- In my opinion, there is never a reason to even fire a DGun if there are no enemies within VANGUARD distance
-- We can tweak this smaller as needed
local ENEMY_SCAN_RADIUS = 1500
local gaiaTeamID = spGetGaiaTeamID()

-- Tracks enemy contacts briefly so that dguns are allowed for a few seconds even after contact is lost
local contactsCache = {}
local CONTACT_WINDOW_DURATION = 5 * 30 -- five seconds at 30 gameframes per second
local CONTACT_PRUNE_INTERVAL = 60 * 30 -- prune expired contacts every minute
local nextContactPruneFrame = CONTACT_PRUNE_INTERVAL
local USE_WG_ANALYTICS = false

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

local function PruneExpiredContacts(currentFrame)
	for i = #contactsCache, 1, -1 do
		if contactsCache[i].expiresFrame <= currentFrame then
			table.remove(contactsCache, i)
		end
	end
end

-- Caches a unit contact briefly. This can be checked for the sake of allowing/disallowing DGun later
local function AddExpiringUnitContact(x, y, z, contactTeam, currentFrame)
	contactsCache[#contactsCache + 1] = {
		x = x,
		y = y,
		z = z,
		contactTeam = contactTeam,
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

-- Returns True if DGUN threatens too much allied stuff (see: MIN_THREATENED_ALLY_METAL)
-- Returns False if DGUN threatens nothing
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
	for i = 1, #candidates do
		local unitID = candidates[i]
		local unitTeam = spGetUnitTeam(unitID)
		local unitDefID = spGetUnitDefID(unitID)
		local unitRadius = GetApproxUnitRadius(unitDefID)
		-- Self-owned units are exempt (only consider allied owned units).
		if unitTeam ~= teamID and GetAllyTeamID(unitTeam) == myAllyTeam then
			local unitX, unitY, unitZ = spGetUnitPosition(unitID)
			if unitX then
				local d = DistPointToSegment(unitX, unitY, unitZ, startX, startY, startZ, endX, endY, endZ)
				if d < unitRadius + DGUN_WIDTH / 2 then
					local unitDef = unitDefID and UnitDefs[unitDefID]
					local threatenedMetal = unitDef and unitDef.metalCost or 0
					threatenedAllyMetal = threatenedAllyMetal + threatenedMetal
				end
			end
		end
	end

	if threatenedAllyMetal >= MIN_THREATENED_ALLY_METAL then
		return true
	end

	if threatenedAllyMetal == 0 then
		return false
	end
	
	return false, string.format("Only %d metal threatened (inconsequential)", threatenedAllyMetal)
end

-- If DGun target location is near a visible enemy, we leave the order alone
local function HasKnownEnemyNearby(teamID, targetX, targetY, targetZ)
	local myAllyTeam = GetAllyTeamID(teamID)
	local currentFrame = spGetGameFrame()
	PruneExpiredContacts(currentFrame)

	local candidates = spGetUnitsInSphere(targetX, targetY, targetZ, ENEMY_SCAN_RADIUS)

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

	-- Treat recent contacts as visible enemy presence.
	for i = 1, #contactsCache do
		local ping = contactsCache[i]
		if ping.contactTeam ~= myAllyTeam then
			local deltaX, deltaY, deltaZ = ping.x - targetX, ping.y - targetY, ping.z - targetZ
			if (deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ) <= (ENEMY_SCAN_RADIUS * ENEMY_SCAN_RADIUS) then
				return true, "Enemies recently on radar/seismic within range"
			end
		end
	end

	return false
end

-- Cache units that leave radar briefly so they count as visible enemy presence
-- This allows players to attempt dguns even if radar contact is lost.
function gadget:UnitLeftRadar(unitID, unitTeam, allyTeam, unitDefID)
	if not unitTeam or unitTeam == gaiaTeamID then
		return
	end

	if allyTeam and GetAllyTeamID(unitTeam) == allyTeam then
		return
	end

	local unitX, unitY, unitZ = spGetUnitPosition(unitID)
	Spring.Echo(unitX, unitY, unitZ) -- FIXME
	if not unitX then
		return
	end

	-- Note: we want to track the team of the unit that left radar.
	-- 'allyTeam' in this context is actually which team that lost track of a radar contact
	AddExpiringUnitContact(unitX, unitY, unitZ, unitTeam, spGetGameFrame())
end

-- Cache seismic detections briefly so they count as visible enemy presence.
function gadget:UnitSeismicPing(positionX, positionY, positionZ, strength, allyTeam, unitID, unitDefID)
	Spring.Echo(positionX, positionY, positionZ) -- FIXME
	AddExpiringUnitContact(positionX, positionY, positionZ, allyTeam, spGetGameFrame())
end

function gadget:GameFrame(currentFrame)
	if currentFrame < nextContactPruneFrame then
		return
	end

	if #contactsCache > 0 then
		PruneExpiredContacts(currentFrame)
	end

	while nextContactPruneFrame <= currentFrame do
		nextContactPruneFrame = nextContactPruneFrame + CONTACT_PRUNE_INTERVAL
	end
end

local function SendAnalyticsEvent(eventType, eventData)
	if USE_WG_ANALYTICS and WG and WG.Analytics and WG.Analytics.SendEvent then
		WG.Analytics.SendEvent(eventType, eventData)
		return
	end

	Spring.Echo(string.format("[DGunAnalytics] %s %s", eventType, table.toString(eventData)))
end

local function GetGameID()
	return Game.gameID or spGetGameRulesParam("GameID")
end

-- Observe DGun commands and echo only. We do not block the command anymore.
function gadget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if cmdID ~= CMD_DGUN then
		return
	end

	local uDef = UnitDefs[unitDefID]
	if not (uDef and uDef.customParams and uDef.customParams.iscommander) then
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

	local risksAllies, explanation = HandleDGunAllyRisk(teamID, startX, startY, startZ, endX, endY, endZ)

	if not risksAllies then
		if explanation then
			SendAnalyticsEvent("dgun_grief_negative", {
				position = { targetX, targetY, targetZ },
				time = spGetGameFrame(),
				gameID = GetGameID(),
				player = GetPlayerName(playerID),
				reason = explanation,
			})
		end
		-- Else send no event as no allies were threatened at all
		return
	end

	local enemiesNearby, explanation = HasKnownEnemyNearby(teamID, targetX, targetY, targetZ)

	if enemiesNearby then
		SendAnalyticsEvent("dgun_grief_negative", {
			position = { targetX, targetY, targetZ },
			time = spGetGameFrame(),
			gameID = GetGameID(),
			player = GetPlayerName(playerID),
			reason = explanation,
		})
		return
	end

	SendAnalyticsEvent("dgun_grief_positive", {
		position = { targetX, targetY, targetZ },
		time = spGetGameFrame(),
		gameID = GetGameID(),
		player = GetPlayerName(playerID),
	})


end
