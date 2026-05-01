local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "DGun Griefing Prevention",
		desc    = "Prevents players from firing DGuns that intersect ally units and gives them both text and audio warning. Note that DGuns are always allowed if the commander is on the frontline.",
		author  = "TheDujin, with Codex",
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
-- 1500 is a bit more than the range of a Vanguard
-- In my opinion, there is never a reason to even fire a DGun if there are no enemies within VANGUARD distance
-- We can tweak this smaller as needed
local ENEMY_SCAN_RADIUS = 1500
local gaiaTeamID = spGetGaiaTeamID()

function gadget:Initialize()
	-- Hook DGun commands into allow/disallow interface
	gadgetHandler:RegisterAllowCommand(CMD_DGUN)
end

local function GetAllyTeamID(teamID)
	local _, _, _, _, _, allyTeamID = spGetTeamInfo(teamID)
	return allyTeamID
end

-- Convert a DGun target into a line segment representing the beam path
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

-- Measure the shortest distance from a unit position to the DGun beam segment
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
	-- Build a cheap box around the beam first, then do the precise segment test
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
		-- Skip the firing commander itself; only warn on other units in the path
		if unitID ~= firingUnitID and unitTeam and GetAllyTeamID(unitTeam) == myAllyTeam then
			local ux, uy, uz = spGetUnitPosition(unitID)
			if ux then
				local d = DistPointToSegment(ux, uy, uz, sx, sy, sz, ex, ey, ez)
				if d < DGUN_WIDTH then
					spPlaySoundFile("sounds/ui/warning2.wav")
					spEcho("WARNING: we have recorded an attempt to D-Gun your allies. Griefing your team is a violation of the Code of Conduct!")
					return true
				end
			end
		end
	end

	return false
end

local function HasKnownEnemyNearby(teamID, ux, uy, uz)
	-- If the commander is already near a visible enemy, we leave the order alone
	local myAllyTeam = GetAllyTeamID(teamID)
	local candidates = spGetUnitsInSphere(ux, uy, uz, ENEMY_SCAN_RADIUS)

	for i = 1, #candidates do
		local unitID = candidates[i]
		local unitTeam = spGetUnitTeam(unitID)
		if unitTeam and unitTeam ~= gaiaTeamID and GetAllyTeamID(unitTeam) ~= myAllyTeam then
			local losState = spGetUnitLosState(unitID, myAllyTeam, true)
			if losState and (losState % 4) > 0 then
				return true
			end
		end
	end

	return false
end

-- Allow normal DGuns, block only ally-targeted hits. If an enemy is visibly nearby, DGuns are always allowed.
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
