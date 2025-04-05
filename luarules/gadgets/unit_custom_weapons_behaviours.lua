local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Custom weapon behaviours",
		desc    = "Handler for special weapon behaviours",
		author  = "Doo",
		date    = "Sept 19th 2017",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then return false end

-- customparams = {
--     speceffect      := string
--     speceffect_when := string
--     speceffect_def  := string?
-- }

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local random = math.random
local math_sqrt = math.sqrt
local mathCos = math.cos
local mathSin = math.sin
local mathPi = math.pi

local SpGetGroundHeight = Spring.GetGroundHeight
local SpGetProjectileTarget = Spring.GetProjectileTarget
local SpGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local SpGetProjectilePosition = Spring.GetProjectilePosition
local SpGetProjectileVelocity = Spring.GetProjectileVelocity
local SpGetUnitIsDead = Spring.GetUnitIsDead
local SpSetProjectilePosition = Spring.SetProjectilePosition
local SpSetProjectileTarget = Spring.SetProjectileTarget
local SpSetProjectileVelocity = Spring.SetProjectileVelocity

local targetedGround = string.byte('g')
local targetedUnit = string.byte('u')
local gravityPerFrame = -Game.gravity / (Game.gameSpeed * Game.gameSpeed)

local projectiles = {}
local projectilesData = {}
local checkingFunctions = {}
local applyingFunctions = {}
local weaponCustomParams = {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function alwaysTrue()
	return true
end

local function elevationIsNonpositive(proID)
	local _, y = SpGetProjectilePosition(proID)
	return y <= 0
end

local function velocityIsNegative(proID)
	local _, vy = SpGetProjectileVelocity(proID)
	return vy < 0
end

local function doNothing()
	return
end

local defaultApply = doNothing
local defaultCheck = { when = 'always', check = alwaysTrue }

--------------------------------------------------------------------------------

checkingFunctions.cruise = {}
checkingFunctions.cruise["until lockon"] = function(proID)
	if SpGetProjectileTimeToLive(proID) > 0 then
		local targetPosX, targetPosY, targetPosZ
		do
			local targetTypeInt, target = SpGetProjectileTarget(proID)
			if targetTypeInt == targetedGround then
				targetPosX, targetPosY, targetPosZ = target[1], target[2], target[3]
			elseif targetTypeInt == targetedUnit then
				local _;
				_, _, _, _, _, _,
				targetPosX, targetPosY, targetPosZ = Spring.GetUnitPosition(target, true, true)
			end
		end
		local infos = projectiles[proID]
		local projectilePosX, projectilePosY, projectilePosZ = SpGetProjectilePosition(proID)
		local projectileVelX, projectileVelY, projectileVelZ, speed = SpGetProjectileVelocity(proID)
		if tonumber(infos.lockon_dist) < math_sqrt((projectilePosX - targetPosX) ^ 2 + (projectilePosY - targetPosY) ^ 2 + (projectilePosZ - targetPosZ) ^ 2) then
			local groundNormX, groundNormY, groundNormZ = Spring.GetGroundNormal(projectilePosX, projectilePosZ)
			local cruisePosY = SpGetGroundHeight(projectilePosX, projectilePosZ) + tonumber(infos.cruise_min_height)
			local correction = groundNormY *
				(projectileVelX * groundNormX + projectileVelY * groundNormY + projectileVelZ * groundNormZ)
			-- Always correct for ground clearance. Follow terrain after first ground clear.
			-- Then, follow terrain also, but avoid going into steep dives, eg after cliffs.
			local cruiseVelY
			if projectilePosY < cruisePosY then
				cruiseVelY = projectileVelY - correction
				projectilesData[proID] = true
			elseif projectilePosY > cruisePosY and projectileVelY > speed * -0.25 and projectilesData[proID] then
				cruiseVelY = projectileVelY - correction
			end
			if cruiseVelY then
				SpSetProjectilePosition(proID, projectilePosX, cruisePosY, projectilePosZ)
				SpSetProjectileVelocity(proID, projectileVelX, cruiseVelY, projectileVelZ)
			end
			return false
		end
	end
	return true
end

checkingFunctions.retarget = {}
checkingFunctions.retarget["always"] = function(proID)
	if SpGetProjectileTimeToLive(proID) > 0 then
		local targetType, target = SpGetProjectileTarget(proID)
		if targetType == targetedUnit and SpGetUnitIsDead(target) ~= false then
			local ownerID = Spring.GetProjectileOwnerID(proID)
			-- Hardcoded to retarget only from the primary weapon and only units or ground
			local ownerTargetType, _, ownerTarget = Spring.GetUnitWeaponTarget(ownerID, 1)
			if ownerTargetType == 1 then
				SpSetProjectileTarget(proID, ownerTarget, targetedUnit)
			elseif ownerTargetType == 2 then
				SpSetProjectileTarget(proID, ownerTarget[1], ownerTarget[2], ownerTarget[3])
			end
			return false
		end
	end
	return true
end

checkingFunctions.sector_fire = {}
applyingFunctions.sector_fire = function(proID)
	local infos = projectiles[proID]

	local maxRangeReduction = tonumber(infos.max_range_reduction)
	local transformXZ = 1 - (random() ^ (1 + maxRangeReduction)) * maxRangeReduction

	local angleXZ = tonumber(infos.spread_angle) * (random() - 0.5) * mathPi / 180
	local transformX = mathCos(angleXZ)
	local transformZ = mathSin(angleXZ)

	local velX, velY, velZ = SpGetProjectileVelocity(proID)
	velX = (velX * transformX - velZ * transformZ) * transformXZ
	velZ = (velX * transformZ + velZ * transformX) * transformXZ

	SpSetProjectileVelocity(proID, velX, velY, velZ)
end

checkingFunctions.split = {}
checkingFunctions.split["at apex"] = velocityIsNegative
applyingFunctions.split = function(proID)
	local projectilePosX, projectilePosY, projectilePosZ = SpGetProjectilePosition(proID)
	local projectileVelX, projectileVelY, projectileVelZ, speed = SpGetProjectileVelocity(proID)
	local ownerID = Spring.GetProjectileOwnerID(proID)
	local infos = projectiles[proID]
	local projectileDefID = WeaponDefNames[infos.speceffect_def].id
	local projectileParams = {
		pos     = { projectilePosX, projectilePosY, projectilePosZ },
		owner   = ownerID,
		ttl     = 3000,
		gravity = gravityPerFrame,
		model   = infos.model,
		cegTag  = infos.cegtag,
	}
	for _ = 1, tonumber(infos.number) do
		projectileParams.speed = {
			projectileVelX - speed * (random(-100, 100) / 880),
			projectileVelY - speed * (random(-100, 100) / 440),
			projectileVelZ - speed * (random(-100, 100) / 880)
		}
		Spring.SpawnProjectile(projectileDefID, projectileParams)
	end
	Spring.SpawnCEG(infos.splitexplosionceg, projectilePosX, projectilePosY, projectilePosZ)
	Spring.DeleteProjectile(proID)
end

-- Water penetration behaviors

checkingFunctions.cannonwaterpen = {}
checkingFunctions.cannonwaterpen["at water level"] = elevationIsNonpositive
applyingFunctions.cannonwaterpen = function(proID)
	local projectilePosX, projectilePosY, projectilePosZ = SpGetProjectilePosition(proID)
	local projectileVelX, projectileVelY, projectileVelZ = SpGetProjectileVelocity(proID)
	local ownerID = Spring.GetProjectileOwnerID(proID)
	local infos = projectiles[proID]
	local projectileParams = {
		pos     = { projectilePosX, projectilePosY, projectilePosZ },
		speed   = { projectileVelX * 0.5, projectileVelY * 0.5, projectileVelZ * 0.5 },
		owner   = ownerID,
		ttl     = 3000,
		gravity = gravityPerFrame * 0.5,
		model   = infos.model,
		cegTag  = infos.cegtag,
	}
	Spring.SpawnProjectile(WeaponDefNames[infos.speceffect_def].id, projectileParams)
	Spring.SpawnCEG(infos.waterpenceg, projectilePosX, projectilePosY, projectilePosZ)
	Spring.DeleteProjectile(proID)
end

checkingFunctions.torpwaterpen = {}
checkingFunctions.torpwaterpen["at water level"] = elevationIsNonpositive
applyingFunctions.torpwaterpen = function(proID)
	local projectileVelX, projectileVelY, projectileVelZ = SpGetProjectileVelocity(proID)
	local targetType, targetID = SpGetProjectileTarget(proID)
	-- Only dive below surface if the target is at an appreciable depth.
	local diveSpeed = 0
	if targetType == targetedUnit and targetID then
		local _, unitPosY = Spring.GetUnitPosition(targetID)
		if unitPosY and unitPosY < -10 then
			diveSpeed = projectileVelY / 6
		end
	end
	-- Brake without halting, else torpedoes may overshoot close targets.
	SpSetProjectileVelocity(proID, projectileVelX / 1.3, diveSpeed, projectileVelZ / 1.3)
end

--------------------------------------------------------------------------------

for speceffect in pairs(checkingFunctions) do
	if not applyingFunctions[speceffect] then
		applyingFunctions[speceffect] = defaultApply
	end
end

for speceffect in pairs(applyingFunctions) do
	if not checkingFunctions[speceffect] or not next(checkingFunctions[speceffect]) then
		checkingFunctions[speceffect] = checkingFunctions[speceffect] or {}
		checkingFunctions[speceffect][defaultCheck.when] = defaultCheck.check
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:Initialize()
	for weaponDefID, weaponDef in pairs(WeaponDefs) do
		if weaponDef.customParams.speceffect then
			local speceffect = weaponDef.customParams.speceffect
			local when = weaponDef.customParams.speceffect_when
			local def = weaponDef.customParams.speceffect_def
			if def and not WeaponDefNames[def] then
				local message = "Custom weapon has bad custom params: " .. weaponDef.name
				message = message .. ' (speceffect_def=' .. def .. ')'
				Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)
			elseif not (checkingFunctions[speceffect] and checkingFunctions[speceffect][when]) or not applyingFunctions[speceffect] then
				local message = "Custom weapon has bad custom params: " .. weaponDef.name
				message = message .. ' (speceffect=' .. speceffect .. ',speceffect_when=' .. (when or 'nil') .. ')'
				Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)
			else
				weaponCustomParams[weaponDefID] = weaponDef.customParams
			end
		end
	end
	if not next(weaponCustomParams) then
		Spring.Log(gadget:GetInfo().name, LOG.INFO, "No custom weapons found. Removing.")
		gadgetHandler:RemoveGadget(self)
		return
	end
end

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	if weaponCustomParams[weaponDefID] then
		projectiles[proID] = weaponCustomParams[weaponDefID]
	end
end

function gadget:ProjectileDestroyed(proID)
	projectiles[proID] = nil
	projectilesData[proID] = nil
end

function gadget:GameFrame(f)
	for proID, infos in pairs(projectiles) do
		if checkingFunctions[infos.speceffect][infos.speceffect_when](proID) then
			applyingFunctions[infos.speceffect](proID)
			projectiles[proID] = nil
			projectilesData[proID] = nil
		end
	end
end
