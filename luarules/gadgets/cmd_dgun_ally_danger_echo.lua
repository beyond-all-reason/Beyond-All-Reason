local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "DGun Ally Danger Echo",
		desc    = "Echoes DANGER when an ally's DGun path intersects allied units",
		author  = "Codex",
		date    = "2026-05-01",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
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
local spPlaySoundFile = Spring.PlaySoundFile
local spEcho = Spring.Echo

local CMD_DGUN = CMD.DGUN
local DGUN_RANGE = 280
local DGUN_WIDTH = 60
local ENEMY_SCAN_RADIUS = 1500
local dangerCount = 0
local gaiaTeamID = spGetGaiaTeamID()

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_DGUN)
end

local function GetAllyTeamID(teamID)
	local _, _, _, _, _, allyTeamID = spGetTeamInfo(teamID)
	return allyTeamID
end

local function BuildDGunSegment(ux, uy, uz, tx, ty, tz)
	local dx, dy, dz = tx - ux, ty - uy, tz - uz
	local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
	if dist == 0 then
		dist = 1
	end

	local nx, ny, nz = dx / dist, dy / dist, dz / dist
	if dist <= DGUN_RANGE then
		return ux, uy, uz, ux + nx * DGUN_RANGE, uy + ny * DGUN_RANGE, uz + nz * DGUN_RANGE
	end

	return tx - nx * DGUN_RANGE, ty - ny * DGUN_RANGE, tz - nz * DGUN_RANGE, tx, ty, tz
end

local function DistPointToSegment(px, py, pz, ax, ay, az, bx, by, bz)
	local vx, vy, vz = bx - ax, by - ay, bz - az
	local wx, wy, wz = px - ax, py - ay, pz - az

	local c1 = vx * wx + vy * wy + vz * wz
	if c1 <= 0 then
		local dx, dy, dz = px - ax, py - ay, pz - az
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end

	local c2 = vx * vx + vy * vy + vz * vz
	if c2 <= c1 then
		local dx, dy, dz = px - bx, py - by, pz - bz
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end

	local b = c1 / c2
	local bx2, by2, bz2 = ax + b * vx, ay + b * vy, az + b * vz
	local dx, dy, dz = px - bx2, py - by2, pz - bz2
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function HandleDGunAllyRisk(teamID, firingUnitID, sx, sy, sz, ex, ey, ez)
	local minx = math.min(sx, ex) - DGUN_WIDTH
	local maxx = math.max(sx, ex) + DGUN_WIDTH
	local miny = math.min(sy, ey) - DGUN_WIDTH
	local maxy = math.max(sy, ey) + DGUN_WIDTH
	local minz = math.min(sz, ez) - DGUN_WIDTH
	local maxz = math.max(sz, ez) + DGUN_WIDTH

	local candidates = spGetUnitsInBox(minx, miny, minz, maxx, maxy, maxz)
	local myAllyTeam = GetAllyTeamID(teamID)

	for i = 1, #candidates do
		local unitID = candidates[i]
		local unitTeam = spGetUnitTeam(unitID)
		if unitID ~= firingUnitID and unitTeam and GetAllyTeamID(unitTeam) == myAllyTeam then
			local ux, uy, uz = spGetUnitPosition(unitID)
			if ux then
				local d = DistPointToSegment(ux, uy, uz, sx, sy, sz, ex, ey, ez)
					if d < DGUN_WIDTH then
						dangerCount = dangerCount + 1
						spPlaySoundFile("sounds/ui/warning2.wav", 1, "ui")
						spEcho("WARNING: we have recorded an attempt to D-Gun your allies. Griefing your team is a violation of the Code of Conduct!" .. dangerCount)
						return true
					end
			end
		end
	end

	return false
end

local function HasKnownEnemyNearby(teamID, ux, uy, uz)
	local myAllyTeam = GetAllyTeamID(teamID)
	local candidates = spGetUnitsInSphere(ux, uy, uz, ENEMY_SCAN_RADIUS)

	for i = 1, #candidates do
		local unitID = candidates[i]
		local unitTeam = spGetUnitTeam(unitID)
		if unitTeam and unitTeam ~= gaiaTeamID and GetAllyTeamID(unitTeam) ~= myAllyTeam then
			local losState = spGetUnitLosState(unitID, myAllyTeam, true)
			if losState and (losState % 4) > 0 then
				local ex, ey, ez = spGetUnitPosition(unitID)
				local unitDefID = spGetUnitDefID(unitID)
				local unitDef = unitDefID and UnitDefs[unitDefID]
				local unitName = unitDef and (unitDef.translatedHumanName or unitDef.name) or "unknown"
				local dist = (ex and math.sqrt((ex - ux) * (ex - ux) + (ey - uy) * (ey - uy) + (ez - uz) * (ez - uz))) or ENEMY_SCAN_RADIUS
				return true
			end
		end
	end

	return false
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if cmdID ~= CMD_DGUN then
		return true
	end

	local uDef = UnitDefs[unitDefID]
	if not (uDef and uDef.customParams and uDef.customParams.iscommander) then
		return true
	end

	local ux, uy, uz = spGetUnitPosition(unitID)
	if not ux then
		return true
	end

	if HasKnownEnemyNearby(teamID, ux, uy, uz) then
		return true
	end

	local tx, ty, tz
	if #cmdParams == 1 and cmdParams[1] > 0 then
		tx, ty, tz = spGetUnitPosition(cmdParams[1])
	else
		tx, ty, tz = cmdParams[1], cmdParams[2], cmdParams[3]
	end

	if not tx then
		return true
	end

	local sx, sy, sz, ex, ey, ez = BuildDGunSegment(ux, uy, uz, tx, ty, tz)
	return not HandleDGunAllyRisk(teamID, unitID, sx, sy, sz, ex, ey, ez)
end
