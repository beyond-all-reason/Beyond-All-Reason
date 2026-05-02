local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "DGun Griefing Prevention",
		desc    = "Prevents players from firing DGuns that intersect ally units and gives them both text and audio warning. Note that DGuns are always allowed if the commander is on the frontline.",
		author  = "TheDujin, with Codex. DGun ally detection code by kroIya/Color",
		date    = "2026-05-01",
		license = "GNU GPL, v2 or later",
		layer   = 0,
        version = "1.0",
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
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetGameFrame = Spring.GetGameFrame
local spPlaySoundFile = Spring.PlaySoundFile
local spEcho = Spring.Echo

local CMD_DGUN = CMD.DGUN
local DGUN_RANGE = 280

-- Excessively large dgun safety width to acount for some units, such as behemoths, being quite large.
-- Note that this safety width is only used to find allies that could be POTENTIALLY hit by the DGun.
-- A more precise check is used to evaluated whether a potential ally target is actually in danger.
local DGUN_SAFETY_WIDTH = 100

-- Approximate actual width of the dgun projectile
local DGUN_WIDTH = 20

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

-- Hook DGun commands into allow/disallow interface
function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_DGUN)
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
		return 0 -- If unknown unit, then we pretend it is tiny. This is to minimize false positives
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

local function HandleDGunAllyRisk(teamID, firingUnitID, playerID, sx, sy, sz, ex, ey, ez)
	-- Build a cheap box around the beam first, then do the precise segment test
	local minx = math.min(sx, ex) - DGUN_SAFETY_WIDTH
	local maxx = math.max(sx, ex) + DGUN_SAFETY_WIDTH
	local miny = math.min(sy, ey) - DGUN_SAFETY_WIDTH
	local maxy = math.max(sy, ey) + DGUN_SAFETY_WIDTH
	local minz = math.min(sz, ez) - DGUN_SAFETY_WIDTH
	local maxz = math.max(sz, ez) + DGUN_SAFETY_WIDTH

	local candidates = spGetUnitsInBox(minx, miny, minz, maxx, maxy, maxz)
	local myAllyTeam = GetAllyTeamID(teamID)
	for i = 1, #candidates do
		local unitID = candidates[i]
		local unitTeam = spGetUnitTeam(unitID)
		local unitDefID = spGetUnitDefID(unitID)
		local unitRadius = GetApproxUnitRadius(unitDefID)
		-- Skip the firing commander itself; only warn on other units in the path
		if unitID ~= firingUnitID and unitTeam and GetAllyTeamID(unitTeam) == myAllyTeam then
			local ux, uy, uz = spGetUnitPosition(unitID)
			if ux then
				local d = DistPointToSegment(ux, uy, uz, sx, sy, sz, ex, ey, ez)
				if d < unitRadius + DGUN_WIDTH / 2 then
					spPlaySoundFile("sounds/ui/warning2.wav")
					spEcho(string.format(
						"WARNING: %s attempted to D-Gun allies. Please remember that the Code of Conduct prohibits griefing.",
						GetPlayerName(playerID)
					))
					return true
				end
			end
		end
	end

	return false
end

-- If the commander is already near a visible enemy, we leave the order alone
local function HasKnownEnemyNearby(teamID, ux, uy, uz)
	local myAllyTeam = GetAllyTeamID(teamID)
	local currentFrame = spGetGameFrame()
	PruneExpiredContacts(currentFrame)

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

	-- Treat recent contacts as visible enemy presence.
	for i = 1, #contactsCache do
		local ping = contactsCache[i]
		if ping.contactTeam ~= myAllyTeam then
			local dx, dy, dz = ping.x - ux, ping.y - uy, ping.z - uz
			if (dx * dx + dy * dy + dz * dz) <= (ENEMY_SCAN_RADIUS * ENEMY_SCAN_RADIUS) then
				return true
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

	local x, y, z = spGetUnitPosition(unitID)
	if not x then
		return
	end

	-- Note: we want to track the team of the unit that left radar.
	-- 'allyTeam' in this context is actually which team that lost track of a radar contact
	AddExpiringUnitContact(x, y, z, unitTeam, spGetGameFrame())
end

-- Cache seismic detections briefly so they count as visible enemy presence.
function gadget:UnitSeismicPing(x, y, z, strength, allyTeam, unitID, unitDefID)
	AddExpiringUnitContact(x, y, z, allyTeam, spGetGameFrame())
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

-- Allow normal DGuns, block only ally-targeted hits. If an enemy is visible nearby, DGuns are always allowed.
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
	return not HandleDGunAllyRisk(teamID, unitID, playerID, sx, sy, sz, ex, ey, ez)
end
