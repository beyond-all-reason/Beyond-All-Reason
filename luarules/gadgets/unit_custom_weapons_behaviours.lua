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
local spGetProjectileTarget = Spring.GetProjectileTarget
local spGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spGetUnitIsDead = Spring.GetUnitIsDead
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

weaponSpecialEffects.cruise = function(proID)
	if spGetProjectileTimeToLive(proID) <= 0 then
		return true
	end
	local targetTypeInt, target = spGetProjectileTarget(proID)
	local targetPosX, targetPosY, targetPosZ
	local projectileVelXNew, projectileVelYNew, projectileVelZNew
	if targetTypeInt == string.byte('g') then
		targetPosX = target[1]
		targetPosY = target[2]
		targetPosZ = target[3]
	end
	if targetTypeInt == string.byte('u') then
		_, _, _, _, _, _, targetPosX, targetPosY, targetPosZ = Spring.GetUnitPosition(target, true, true)
	end
	local projectilePosX, projectilePosY, projectilePosZ = Spring.GetProjectilePosition(proID)
	local projectileVelX, projectileVelY, projectileVelZ = spGetProjectileVelocity(proID)
	local speed = sqrt(projectileVelX * projectileVelX + projectileVelY * projectileVelY + projectileVelZ *
		projectileVelZ)
	local infos = projectiles[proID]
	if sqrt((projectilePosX - targetPosX) ^ 2 + (projectilePosY - targetPosY) ^ 2 + (projectilePosZ - targetPosZ) ^ 2) > tonumber(infos.lockon_dist) then
		groundPosY = Spring.GetGroundHeight(projectilePosX, projectilePosZ)
		groundNormX, groundNormY, groundNormZ, slope = Spring.GetGroundNormal(projectilePosX, projectilePosZ)
		--Spring.Echo(Spring.GetGroundNormal(xp,zp))
		--Spring.Echo(tonumber(infos.cruise_height)*slope)
		if projectilePosY < groundPosY + tonumber(infos.cruise_min_height) then
			projectilesData[proID] = true
			Spring.SetProjectilePosition(proID, projectilePosX, groundPosY + tonumber(infos.cruise_min_height),
				projectilePosZ)
			local norm = (projectileVelX * groundNormX + projectileVelY * groundNormY + projectileVelZ * groundNormZ)
			projectileVelXNew = projectileVelX - norm * groundNormX * 0
			projectileVelYNew = projectileVelY - norm * groundNormY
			projectileVelZNew = projectileVelZ - norm * groundNormZ * 0
			spSetProjectileVelocity(proID, projectileVelXNew, projectileVelYNew, projectileVelZNew)
		end
		if projectilePosY > groundPosY + tonumber(infos.cruise_max_height) and projectilesData[proID] and projectileVelY > -speed * .25 then
			-- do not clamp to max height if
			-- vertical velocity downward is more than 1/4 of current speed
			-- probably just went off lip of steep cliff
			Spring.SetProjectilePosition(proID, projectilePosX, groundPosY + tonumber(infos.cruise_max_height),
				projectilePosZ)
			local norm = (projectileVelX * groundNormX + projectileVelY * groundNormY + projectileVelZ * groundNormZ)
			projectileVelXNew = projectileVelX - norm * groundNormX * 0
			projectileVelYNew = projectileVelY - norm * groundNormY
			projectileVelZNew = projectileVelZ - norm * groundNormZ * 0
			spSetProjectileVelocity(proID, projectileVelXNew, projectileVelYNew, projectileVelZNew)
		end
		return false
	else
		return true
	end
end

weaponSpecialEffects.retarget = function(proID)
	-- Might be slightly more optimal to check the unit itself if it changes target,
	-- then tell the in-flight missiles to change target if the unit changes target
	-- instead of checking each in-flight missile
	-- but not sure if there is an easy hook function or callin function
	-- that only runs if a unit changes target

	-- refactor slightly, only do target change if the target the missile
	-- is heading towards is dead
	-- karganeth switches away from alive units a little too often, causing
	-- missiles that would have hit to instead miss
	if spGetProjectileTimeToLive(proID) <= 0 then
		-- stop missile retargeting when it runs out of fuel
		return true
	end
	local targetTypeInt, targetID = spGetProjectileTarget(proID)
	-- if the missile is heading towards a unit
	if targetTypeInt == string.byte('u') then
		--check if the target unit is dead or dying
		local isDead = spGetUnitIsDead(targetID)
		if isDead == nil or isDead == true then
			--hardcoded to assume the retarget weapon is the primary weapon.
			--TODO, make this more general
			local ownerTargetType, _, ownerTarget = spGetUnitWeaponTarget(spGetProjectileOwnerID(proID), 1)
			if ownerTargetType == 1 then
				--hardcoded to assume the retarget weapon does not target features or intercept projectiles, only targets units if not shooting ground.
				--TODO, make this more general
				spSetProjectileTarget(proID, ownerTarget, string.byte('u'))
			end
			if ownerTargetType == 2 then
				spSetProjectileTarget(proID, ownerTarget[1], ownerTarget[2], ownerTarget[3])
			end
		end
	end

	return false
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
