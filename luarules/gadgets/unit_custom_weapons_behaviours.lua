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
--     speceffect_def  := string?
-- }

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local random = math.random
local sqrt = math.sqrt
local cos = math.cos
local sin = math.sin
local pi = math.pi

local spGetGroundHeight = Spring.GetGroundHeight
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileTarget = Spring.GetProjectileTarget
local spGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitPosition = Spring.GetUnitPosition
local spSetProjectilePosition = Spring.SetProjectilePosition
local spSetProjectileTarget = Spring.SetProjectileTarget
local spSetProjectileVelocity = Spring.SetProjectileVelocity

local targetedGround = string.byte('g')
local targetedUnit = string.byte('u')
local gravityPerFrame = -Game.gravity / (Game.gameSpeed * Game.gameSpeed)

local weaponSpecialEffect = {}
local weaponCustomParams = {}

local projectiles = {}
local projectilesData = {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function elevationIsNonpositive(proID)
	local _, projectilePosY = spGetProjectilePosition(proID)
	return projectilePosY <= 0
end

local function velocityIsNegative(proID)
	local _, projectileVelY = spGetProjectileVelocity(proID)
	return projectileVelY < 0
end

--------------------------------------------------------------------------------

weaponSpecialEffect.cruise = function(proID)
	if spGetProjectileTimeToLive(proID) > 0 then
		local targetPosX, targetPosY, targetPosZ
		do
			local targetTypeInt, target = spGetProjectileTarget(proID)
			if targetTypeInt == targetedGround then
				targetPosX, targetPosY, targetPosZ = target[1], target[2], target[3]
			elseif targetTypeInt == targetedUnit then
				local _;
				_, _, _, _, _, _,
				targetPosX, targetPosY, targetPosZ = spGetUnitPosition(target, true, true)
			end
		end
		local infos = projectiles[proID]
		local projectilePosX, projectilePosY, projectilePosZ = spGetProjectilePosition(proID)
		local projectileVelX, projectileVelY, projectileVelZ, speed = spGetProjectileVelocity(proID)
		if tonumber(infos.lockon_dist) ^ 2 < (projectilePosX - targetPosX) ^ 2 + (projectilePosY - targetPosY) ^ 2 + (projectilePosZ - targetPosZ) ^ 2 then
			local groundNormX, groundNormY, groundNormZ = Spring.GetGroundNormal(projectilePosX, projectilePosZ)
			local cruisePosY = spGetGroundHeight(projectilePosX, projectilePosZ) + tonumber(infos.cruise_min_height)
			local correction = groundNormY *
				(projectileVelX * groundNormX + projectileVelY * groundNormY + projectileVelZ * groundNormZ)
			-- Always correct for ground clearance. Follow terrain after first ground clear.
			-- Then, follow terrain also, but avoid going into steep dives, eg after cliffs.
			local cruiseVelY
			if projectilePosY < cruisePosY then
				cruiseVelY = projectileVelY - correction
				projectilesData[proID] = true
			elseif projectilesData[proID] and projectilePosY > cruisePosY and projectileVelY > speed * -0.25 then
				cruiseVelY = projectileVelY - correction
			end
			if cruiseVelY then
				spSetProjectilePosition(proID, projectilePosX, cruisePosY, projectilePosZ)
				spSetProjectileVelocity(proID, projectileVelX, cruiseVelY, projectileVelZ)
			end
			return false
		end
	end
	return true
end

weaponSpecialEffect.retarget = function(proID)
	if spGetProjectileTimeToLive(proID) > 0 then
		local targetType, target = spGetProjectileTarget(proID)
		if targetType == targetedUnit and spGetUnitIsDead(target) ~= false then
			local ownerID = Spring.GetProjectileOwnerID(proID)
			-- Hardcoded to retarget only from the primary weapon and only units or ground
			local ownerTargetType, _, ownerTarget = Spring.GetUnitWeaponTarget(ownerID, 1)
			if ownerTargetType == 1 then
				spSetProjectileTarget(proID, ownerTarget, targetedUnit)
			elseif ownerTargetType == 2 then
				spSetProjectileTarget(proID, ownerTarget[1], ownerTarget[2], ownerTarget[3])
			end
			return false
		end
	end
	return true
end

weaponSpecialEffects.sector_fire = function(proID)
	local infos = projectiles[proID]
	local velX, velY, velZ = spGetProjectileVelocity(proID)

	local spreadAngle = tonumber(infos.spread_angle)
	local maxRangeReduction = tonumber(infos.max_range_reduction)

	local angleFactor = (spreadAngle * (random() - 0.5)) * pi / 180
	local angleCos = cos(angleFactor)
	local angleSin = sin(angleFactor)

	local velXNew = velX * angleCos - velZ * angleSin
	local velZNew = velX * angleSin + velZ * angleCos

	local velocityFactor = 1 - (random() ^ (1 + maxRangeReduction)) * maxRangeReduction

	velX = velXNew * velocityFactor
	velZ = velZNew * velocityFactor

	spSetProjectileVelocity(proID, velX, velY, velZ)
	return true
end

weaponSpecialEffects.split = function(proID)
	local _, projectileVelY, _ = spGetProjectileVelocity(proID)
	if projectileVelY < 0 then
		local projectilePosX, projectilePosY, projectilePosZ = Spring.GetProjectilePosition(proID)
		local projectileVelX, projectileVelY, projectileVelZ = spGetProjectileVelocity(proID)
		local speed = sqrt(projectileVelX * projectileVelX + projectileVelY * projectileVelY +
			projectileVelZ * projectileVelZ)
		local ownerID = spGetProjectileOwnerID(proID)
		local infos = projectiles[proID]
		for i = 1, tonumber(infos.number) do
			local projectileParams = {
				pos = { projectilePosX, projectilePosY, projectilePosZ },
				speed = { projectileVelX - speed * (math.random(-100, 100) / 880), projectileVelY - speed * (math.random(-100, 100) / 440), projectileVelZ - speed * (math.random(-100, 100) / 880) },
				owner = ownerID,
				ttl = 3000,
				gravity = -Game.gravity / 900,
				model = infos.model,
				cegTag = infos.cegtag,
			}
			Spring.SpawnProjectile(WeaponDefNames[infos.speceffect_def].id, projectileParams)
		end
		Spring.SpawnCEG(infos.splitexplosionceg, projectilePosX, projectilePosY, projectilePosZ, 0, 0, 0, 0, 0)
		Spring.DeleteProjectile(proID)
		return true
	else
		return false
	end
end

weaponSpecialEffects.cannonwaterpen = function(proID)
	local _, projectilePosY, _ = Spring.GetProjectilePosition(proID)
	if projectilePosY <= 0 then
		local projectilePosX, projectilePosY, projectilePosZ = Spring.GetProjectilePosition(proID)
		local projectileVelX, projectileVelY, projectileVelZ = spGetProjectileVelocity(proID)
		local nvx, nvy, nvz = projectileVelX * 0.5, projectileVelY * 0.5, projectileVelZ * 0.5
		local ownerID = spGetProjectileOwnerID(proID)
		local infos = projectiles[proID]
		local projectileParams = {
			pos = { projectilePosX, projectilePosY, projectilePosZ },
			speed = { nvx, nvy, nvz },
			owner = ownerID,
			ttl = 3000,
			gravity = -Game.gravity / 3600,
			model = infos.model,
			cegTag = infos.cegtag,
		}
		Spring.SpawnProjectile(WeaponDefNames[infos.speceffect_def].id, projectileParams)
		Spring.SpawnCEG(infos.waterpenceg, projectilePosX, projectilePosY, projectilePosZ, 0, 0, 0, 0, 0)
		Spring.DeleteProjectile(proID)
		return true
	else
		return false
	end
end

weaponSpecialEffects.torpwaterpen = function(proID)
	local _, projectilePosY, _ = Spring.GetProjectilePosition(proID)
	if projectilePosY <= 0 then
		local projectileVelX, projectileVelY, projectileVelZ = spGetProjectileVelocity(proID)
		--if target is close under the shooter, however, this resetting makes the torp always miss, unless it has amazing tracking
		--needs special case handling (and there's no point having it visually on top of water for an UW target anyway)

		local bypass = false
		local targetType, targetID = spGetProjectileTarget(proID)

		if (targetType ~= nil) and (targetID ~= nil) and (targetType ~= 103) then --ground attack borks it; skip
			local unitPosX, unitPosY, unitPosZ = Spring.GetUnitPosition(targetID)
			if (unitPosY ~= nil) and unitPosY < -10 then
				bypass = true
				spSetProjectileVelocity(proID, projectileVelX / 1.3, projectileVelY / 6, projectileVelZ / 1.3) --apply brake without fully halting, otherwise it will overshoot very close targets before tracking can reorient it
			end
		end

		if not bypass then
			spSetProjectileVelocity(proID, projectileVelX, 0, projectileVelZ)
		end
		return true
	else
		return false
	end
end

--a Hornet special, mangle different two things into working as one (they're otherwise mutually exclusive)
weaponSpecialEffects.torpwaterpenretarget = function(proID)
	weaponSpecialEffects.retarget(proID) --subcontract that part

	local _, projectilePosY, _ = Spring.GetProjectilePosition(proID)
	if projectilePosY <= 0 then
		--and delegate that too
		weaponSpecialEffects.torpwaterpen(proID)
	end
	return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:Initialize()
	for weaponDefID, weaponDef in pairs(WeaponDefs) do
		if weaponDef.customParams.speceffect then
			local def = weaponDef.customParams.speceffect_def
			if def and not WeaponDefNames[def] then
				local message = "Weapon has bad custom params: " .. weaponDef.name
				message = message .. ' (speceffect_def=' .. def .. ')'
				Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)
			else
				weaponCustomParams[weaponDefID] = weaponDef.customParams
			end
			-- TODO: Remove deprecate warning once modders have had time to fix.
			if weaponDef.customParams.when then
				local message = "Deprecated customparam 'when': " .. weaponDef.name
				Spring.Log(gadget:GetInfo().name, LOG.DEPRECATED, message)
			end
		end
	end
	if not next(weaponCustomParams) then
		Spring.Log(gadget:GetInfo().name, LOG.INFO, "No custom weapons found.")
		gadgetHandler:RemoveGadget(self)
		return
	end
end

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	if weaponCustomParams[weaponDefID] then
		projectiles[proID] = weaponCustomParams[weaponDefID]
		projectilesData[proID] = nil
	end
end

function gadget:ProjectileDestroyed(proID)
	projectiles[proID] = nil
	projectilesData[proID] = nil
end

function gadget:GameFrame(f)
	for proID, infos in pairs(projectiles) do
		if weaponSpecialEffects[infos.speceffect](proID) == true then
			applyingFunctions[infos.speceffect](proID)
			projectiles[proID] = nil
			projectilesData[proID] = nil
		end
	end
end
