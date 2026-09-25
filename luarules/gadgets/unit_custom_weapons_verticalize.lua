local gadget = gadget ---@type Gadget

if not gadgetHandler:IsSyncedCode() then
	return false
end

function gadget:GetInfo()
	return {
		name = "Starburst cruise and verticalize",
		desc = "Trajectory alchemy for projectiles that must not hit terrain",
		author = "efrec",
		license = "GNU GPL, v2 or later",
		layer = -10000, -- before other gadgets can process projectiles
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local checkWindowFrames = 6 -- count of polling frames used to predict new phases

--------------------------------------------------------------------------------
-- Localization ----------------------------------------------------------------

local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local math_clamp = math.clamp
local math_sqrt = math.sqrt
local math_floor = math.floor
local math_diag = math.diag
local math_pi = math.pi
local math_asin = math.asin
local distance2D = math.distance2d
local distance2DSquared = math.distance2dSquared

local slerp = VFS.Include("common/vectors.lua").slerp

local Verticalize = VFS.Include("modules/verticalize.lua")
local getVerticalizeWeapon = Verticalize.getVerticalizeWeapon
local getAscendHeight = Verticalize.getAscendHeight
local newProjectile = Verticalize.newProjectile
local getUpTimeFrames = Verticalize.getUpTimeFrames
local isTargetInsideAscentTurn = Verticalize.isTargetInsideAscentTurn
local getAimHeight = Verticalize.getAimHeight

local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spSetProjectilePosition = Spring.SetProjectilePosition
local spSetProjectileVelocity = Spring.SetProjectileVelocity

local targetedUnit = string.byte("u")

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

local weapons = {} ---@type table<integer, table?>
local projectiles = {} ---@type table<integer, table?>
local moveControl = {} ---@type table<integer, table?>
local scheduled = {} ---@type table<integer, integer[]?>

local gameFrame = 0
local inSpawnProjectile = false

--------------------------------------------------------------------------------
-- Vectors minilib -------------------------------------------------------------

local positionGuidance = table.new(3, 1) ---@type xyz
local velocityGuidance = table.new(4, 0) ---@type xyzw

local function getPosition(projectileID)
	local position = positionGuidance
	position[1], position[2], position[3] = spGetProjectilePosition(projectileID)
	return position
end

local function getVelocity(projectileID)
	local velocity = velocityGuidance
	velocity[1], velocity[2], velocity[3], velocity[4] = spGetProjectileVelocity(projectileID)
	return velocity
end

local function getPositionAndVelocity(projectileID)
	local position, velocity = positionGuidance, velocityGuidance
	position[1], position[2], position[3] = spGetProjectilePosition(projectileID)
	velocity[1], velocity[2], velocity[3], velocity[4] = spGetProjectileVelocity(projectileID)
	return position, velocity
end

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function scheduleAt(projectileID, frame)
	local bin = scheduled[frame]
	if not bin then
		bin = {}
		scheduled[frame] = bin
	end
	bin[#bin + 1] = projectileID
end

local function getUnitPositionWithError(unitID, teamID)
	return CallAsTeam(teamID, Spring.GetUnitPosition, unitID)
end

local function getTargetPosition(projectileID)
	local xyz
	local targetType, target = Spring.GetProjectileTarget(projectileID)
	if type(target) == "table" then
		xyz = target
	elseif targetType == targetedUnit then
		xyz = { getUnitPositionWithError(target, Spring.GetProjectileTeamID(projectileID)) }
		xyz[2] = math_max(Spring.GetGroundHeight(xyz[1], xyz[3]), 0) ---@diagnostic disable-line
	end
	return xyz
end

-- Launching -------------------------------------------------------------------

---@class StarburstParams : ProjectileParams
---@field cegtag number
---@field maxRange number
---@field tracking number
---@field upTime number
local projectileParams = {
	pos = positionGuidance,
	speed = velocityGuidance,
	["end"] = table.new(3, 0),
}

local function respawn(weapon, projectileID, projectile, upTimeFrames)
	if upTimeFrames <= 0 then
		local target = projectile.target
		Spring.SetProjectileTarget(projectileID, target[1], target[2], target[3])
		return false
	end

	local weaponDefID = assert(Spring.GetProjectileDefID(projectileID))
	local spawnParams = projectileParams
	spawnParams.owner = Spring.GetProjectileOwnerID(projectileID) or -1
	spawnParams.team = Spring.GetProjectileTeamID(projectileID)
	spawnParams.ttl = Spring.GetProjectileTimeToLive(projectileID) or 1e6
	spawnParams.gravity = weapon.gravity
	spawnParams.cegtag = weapon.cegTag -- note: is lower case
	spawnParams.maxRange = weapon.rangeMaximum -- zero disables StarburstProjectile turn/tracking
	spawnParams.tracking = weapon.tracking
	spawnParams.upTime = upTimeFrames
	getVelocity(projectileID) -- populates spawnParams.speed
	spawnParams.speed[4] = nil -- engine needs `xyz`

	local aim = spawnParams["end"] -- must be known at spawn time for interceptors
	aim[1] = projectile.target[1]
	aim[2] = getAimHeight(weapon, projectile)
	aim[3] = projectile.target[3]

	Spring.DeleteProjectile(projectileID)

	inSpawnProjectile = true
	local respawnID = Spring.SpawnProjectile(weaponDefID, spawnParams)
	inSpawnProjectile = false

	if not respawnID then
		return false
	end

	projectiles[respawnID] = projectile
	scheduleAt(respawnID, math_max(gameFrame + math_floor(upTimeFrames) - checkWindowFrames, gameFrame + 1))

	return true
end

local function register(projectileID, weaponDefID)
	if inSpawnProjectile then
		return
	end

	local target = getTargetPosition(projectileID)
	if not target then
		return
	end

	local weapon = weapons[weaponDefID]
	if not weapon then
		return
	end

	local position = getPosition(projectileID)
	local projectile = newProjectile(weapon, target, getAscendHeight(weapon, position, target))
	local upTimeFrames = getUpTimeFrames(weapon, projectile, position)

	if upTimeFrames >= weapon.upTimeMinFrames + 0.5 then
		if respawn(weapon, projectileID, projectile, upTimeFrames) then
			return
		end
		upTimeFrames = weapon.upTimeMinFrames ---@type number
	end

	if isTargetInsideAscentTurn(weapon, position, target) then
		return -- Nothing to guide, with the target this far inside the ascent turn.
	end

	projectiles[projectileID] = projectile
	scheduleAt(projectileID, math_max(gameFrame + math_floor(upTimeFrames) - checkWindowFrames, gameFrame + 1))

	local targetHeight = getAimHeight(weapon, projectile)
	Spring.SetProjectileTarget(projectileID, target[1], targetHeight, target[3])
end

-- Flight phases ---------------------------------------------------------------

local function ascend(projectileID, projectile, frame)
	local position, velocity = getPositionAndVelocity(projectileID)

	if velocity[4] <= 0 then
		return frame + 1
	end

	-- Hand off at the ascend height or, on a climb cut short, once it stops climbing.
	if velocity[2] > 0 and projectile.ascendHeight - position[2] >= velocity[2] then
		return frame + 1
	end

	projectile.phase = projectile.phase + 1

	local pitchAngle = math_asin(math_clamp(math_abs(velocity[2]) / velocity[4], 0, 1))
	local turnFrames = pitchAngle / projectile.turnRate

	local speedMax = projectile.speedMax
	local target = projectile.target
	local targetDistance = distance2D(position[1], position[3], target[1], target[3])
	local dropRadiusFrames = (targetDistance - projectile.diveRadiusMax) / speedMax

	return frame + math_floor(math_min(turnFrames, dropRadiusFrames)) - checkWindowFrames
end

-- Descent curvature is constant at radius r := (1 + chase) * v / turnRate.
-- The radius increases with chase factor, then. Once r exceeds the height,
-- which has to be avoided by tuning the weapondef properly and has no fix,
-- the projectile flies in on a wider drop and impacts before verticalized.
--
-- That impact comes before the quarter turn, then, at acos(1 - height/r).
-- Taking the quarter turn as the arc length is therefore an upper bound:
--     v^2 = speed^2 + 2 * acceleration * arc
--  => v^2 - diveSpeedGain * v - speed^2 = 0
local function getDiveSpeed(projectile, speed)
	local gain = projectile.diveSpeedGain
	local diveSpeed = 0.5 * (gain + math_sqrt(gain * gain + 4 * speed * speed))
	return math_min(diveSpeed, projectile.speedMax)
end

local function turnToLevel(projectileID, projectile, frame)
	local velocity = getVelocity(projectileID)
	if velocity[4] <= 0 then
		return frame + 1
	end

	local pitch = math_asin(math_clamp(velocity[2] / velocity[4], -1, 1))

	-- Pitch is constant while still climbing, too, so wait out an early hand-off.
	if pitch >= math_pi * 0.5 - projectile.turnRate then
		projectile.pitch = pitch
		return frame + 1
	end

	-- StarburstProjectile disables turning at 8.1 degrees to target, then keeps constant pitch.
	if projectile.pitch - pitch > projectile.turnRate * 0.5 then
		projectile.pitch = pitch
		return frame + 1
	end

	projectile.phase = projectile.phase + 1
	local cruiseEndRadius = (1 + projectile.chaseFactor) * getDiveSpeed(projectile, velocity[4]) / projectile.turnRate
	local position, target = getPosition(projectileID), projectile.target
	local cruiseDistance = distance2D(position[1], position[3], target[1], target[3]) - cruiseEndRadius
	return frame + math_floor(cruiseDistance / projectile.speedMax) - checkWindowFrames
end

local function cruise(projectileID, projectile, frame)
	local position, velocity = getPositionAndVelocity(projectileID)
	if velocity[4] <= 0 then
		return frame + 1 -- guidance will div0
	end

	-- Most vertical-launch missiles accelerate slowly so are still gaining speed here.
	local target = projectile.target
	local cruiseEndRadius = (1 + projectile.chaseFactor) * getDiveSpeed(projectile, velocity[4]) / projectile.turnRate
	local targetDistanceSquared = distance2DSquared(position[1], position[3], target[1], target[3])
	if targetDistanceSquared > cruiseEndRadius * cruiseEndRadius then
		return frame + 1
	end

	-- We leave the engine `phase` tracking and begin using lua's scripted MoveControl.
	moveControl[projectileID] = projectile

	projectile.cruiseEndInverse = 1 / cruiseEndRadius
	projectile.px, projectile.py, projectile.pz = position[1], position[2], position[3]
	projectile.vx, projectile.vy, projectile.vz = velocity[1], velocity[2], velocity[3]
	projectile.speed = velocity[4]
	Spring.SetProjectileMoveControl(projectileID, true)
	Spring.SetProjectileTarget(projectileID, target[1], target[2], target[3])
end

local function verticalize(projectileID, projectile)
	local px, py, pz = projectile.px, projectile.py, projectile.pz
	local vx, vy, vz = projectile.vx, projectile.vy, projectile.vz
	local speed = projectile.speed

	local target = projectile.target
	local dx = target[1] - px
	local dz = target[3] - pz
	local distance = math_diag(dx, dz)

	-- We don't have many weapondef-invariant checks left, so this
	-- may be useful only for consistently shaping the drop, now.
	local sinPitch = 1 - distance * projectile.cruiseEndInverse
	if sinPitch < 0 then
		sinPitch = 0
	end
	local cosPitch = math_sqrt(1 - sinPitch * sinPitch)

	-- Unit vector towards target
	local tx, ty, tz = 0.0, -sinPitch, 0.0
	if distance > 0 then
		local distInverse = cosPitch / distance
		tx = dx * distInverse
		tz = dz * distInverse
	end

	vx, vy, vz = slerp(vx, vy, vz, speed, tx, ty, tz, projectile.turnRate)

	local speedNew = math_min(speed + projectile.acceleration, projectile.speedMax)
	local ratio = speedNew / speed
	vx, vy, vz = vx * ratio, vy * ratio, vz * ratio
	px, py, pz = px + vx, py + vy, pz + vz

	projectile.px, projectile.py, projectile.pz = px, py, pz
	projectile.vx, projectile.vy, projectile.vz = vx, vy, vz
	projectile.speed = speed * ratio

	spSetProjectilePosition(projectileID, px, py, pz)
	spSetProjectileVelocity(projectileID, vx, vy, vz)
end

local enginePhases = { ascend, turnToLevel, cruise } -- end into => verticalize

local function updatePhases(checkList, frame)
	for i = 1, #checkList do
		local projectileID = checkList[i]
		local projectile = projectiles[projectileID] -- may have been destroyed
		if projectile then
			repeat
				local checkFrame = enginePhases[projectile.phase](projectileID, projectile, frame)
				if not checkFrame then
					break
				elseif checkFrame > frame then
					scheduleAt(projectileID, checkFrame)
					break
				end
			until false
		end
	end
end

--------------------------------------------------------------------------------
-- Engine call-ins -------------------------------------------------------------

function gadget:GameFrame(frame)
	gameFrame = frame

	local checkList = scheduled[frame]
	if checkList then
		scheduled[frame] = nil
		updatePhases(checkList, frame)
	end

	for projectileID, projectile in pairs(moveControl) do
		verticalize(projectileID, projectile)
	end
end

function gadget:ProjectileCreated(projectileID, ownerID, weaponDefID)
	if weapons[weaponDefID] then
		register(projectileID, weaponDefID)
	end
end

function gadget:ProjectileDestroyed(projectileID, ownerID, weaponDefID)
	projectiles[projectileID] = nil
	moveControl[projectileID] = nil
end

function gadget:Initialize()
	for weaponDefID = 0, #WeaponDefs do
		local weaponDef = WeaponDefs[weaponDefID] ---@type table
		local weapon = getVerticalizeWeapon(weaponDef)
		if weapon then
			if weapon.diveRadiusMax > weapon.cruiseHeight then
				local message = weaponDef.name .. " drops on a turn wider than its cruise height so impacts on a curve."
				Spring.Log(gadget:GetInfo().name, LOG.NOTICE, message)
			end
			weapons[weaponDefID] = weapon
			Script.SetWatchProjectile(weaponDefID, true)
		end
	end

	if not next(weapons) then
		Spring.Log(gadget:GetInfo().name, LOG.INFO, "No weapons found.")
		gadgetHandler:RemoveGadget()
		return
	end
end
