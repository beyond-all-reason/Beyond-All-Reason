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
-- Localization ----------------------------------------------------------------

local math_max = math.max

local Verticalize = require("modules/verticalize")
local getVerticalizeWeapon = Verticalize.getVerticalizeWeapon
local getAscendHeight = Verticalize.getAscendHeight
local newProjectile = Verticalize.newProjectile
local getUpTimeFrames = Verticalize.getUpTimeFrames
local shouldRespawn = Verticalize.shouldRespawn
local getFirstCheckFrame = Verticalize.getFirstCheckFrame
local isTargetInsideAscentTurn = Verticalize.isTargetInsideAscentTurn
local getAimHeight = Verticalize.getAimHeight
local updateFlightPhase = Verticalize.updateFlightPhase
local verticalize = Verticalize.verticalize

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
	scheduleAt(respawnID, getFirstCheckFrame(upTimeFrames, gameFrame))

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

	if shouldRespawn(weapon, upTimeFrames) then
		if respawn(weapon, projectileID, projectile, upTimeFrames) then
			return
		end
		upTimeFrames = weapon.upTimeMinFrames ---@type number
	end

	if isTargetInsideAscentTurn(weapon, position, target) then
		return -- Nothing to guide, with the target this far inside the ascent turn.
	end

	projectiles[projectileID] = projectile
	scheduleAt(projectileID, getFirstCheckFrame(upTimeFrames, gameFrame))

	local targetHeight = getAimHeight(weapon, projectile)
	Spring.SetProjectileTarget(projectileID, target[1], targetHeight, target[3])
end

-- Flight phases ---------------------------------------------------------------

local function startVerticalize(projectileID, projectile)
	-- We leave the engine `phase` tracking and begin using lua's scripted MoveControl.
	moveControl[projectileID] = projectile

	local target = projectile.target
	Spring.SetProjectileMoveControl(projectileID, true)
	Spring.SetProjectileTarget(projectileID, target[1], target[2], target[3])
end

local function updatePhases(checkList, frame)
	for i = 1, #checkList do
		local projectileID = checkList[i]
		local projectile = projectiles[projectileID] -- may have been destroyed
		if projectile then
			repeat
				local position, velocity = getPositionAndVelocity(projectileID)
				local checkFrame = updateFlightPhase(projectile, position, velocity, frame)
				if not checkFrame then
					startVerticalize(projectileID, projectile)
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
		verticalize(projectile)
		spSetProjectilePosition(projectileID, projectile.px, projectile.py, projectile.pz)
		spSetProjectileVelocity(projectileID, projectile.vx, projectile.vy, projectile.vz)
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
