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

if not gadgetHandler:IsSyncedCode() then
	return
end

--------------------------------------------------------------------------------
-- Localization ----------------------------------------------------------------

local math_random = math.random
local math_sqrt = math.sqrt
local math_cos = math.cos
local math_sin = math.sin
local math_pi = math.pi
local distance3dSquared = math.distance3dSquared

local spGetGroundHeight = Spring.GetGroundHeight
local spGetGroundNormal = Spring.GetGroundNormal
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileTarget = Spring.GetProjectileTarget
local spGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitPosition = Spring.GetUnitPosition
local spSetProjectilePosition = Spring.SetProjectilePosition
local spSetProjectileTarget = Spring.SetProjectileTarget
local spSetProjectileVelocity = Spring.SetProjectileVelocity

local gravityPerFrame = -Game.gravity / (Game.gameSpeed * Game.gameSpeed)

local targetedGround = string.byte('g')
local targetedUnit = string.byte('u')

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

local weaponCustomParamKeys = {} -- [effect] = { key => conversion function }
local weaponSpecialEffect = {}

local weaponParams = {}

local projectiles = {}
local projectilesData = {}

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function parseCustomParams(weaponDef)
	local success = true

	local effectName = weaponDef.customParams.speceffect

	if not weaponSpecialEffect[effectName] then
		local message = weaponDef.name .. " has bad speceffect: " .. effectName
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)

		success = false
	end

	local effectParams = {}

	if weaponCustomParamKeys[effectName] then
		for key, conversion in pairs(weaponCustomParamKeys[effectName]) do
			if weaponDef.customParams[key] then
				local value = conversion(weaponDef.customParams[key])
				if value ~= nil then
					effectParams[key] = value
				else
					local message = weaponDef.name .. " has bad customparam: " .. key
					Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)

					success = false
				end
			end
		end
	end

	-- Modders/tweakdefs are likely to use these values for a while:
	if weaponDef.customParams.def or weaponDef.customParams.when then
		local message = weaponDef.name .. " uses old customparams (def/when)"
		Spring.Log(gadget:GetInfo().name, LOG.DEPRECATED, message)
	end

	if success then
		return effectName, effectParams
	end
end

local function toWeaponDefID(value)
	local spawnDef = WeaponDefNames[value]
	return spawnDef and spawnDef.id or nil
end

local function toPositiveNumber(value)
	value = tonumber(value)
	return value and math.max(0, value) or nil
end

--- Weapon behaviors -----------------------------------------------------------

-- Cruise

weaponCustomParamKeys.cruise = {
	cruise_min_height = toPositiveNumber,
	lockon_dist = toPositiveNumber,
}

local function applyCruiseCorrection(projectileID, positionX, positionY, positionZ, velocityX, velocityY, velocityZ)
	local normalX, normalY, normalZ = spGetGroundNormal(positionX, positionZ)
	local codirection = velocityX * normalX + velocityY * normalY + velocityZ * normalZ
	velocityY = velocityY - normalY * codirection -- NB: can be a little strong on uneven terrain
	spSetProjectilePosition(projectileID, positionX, positionY, positionZ)
	spSetProjectileVelocity(projectileID, velocityX, velocityY, velocityZ)
end

weaponSpecialEffect.cruise = function(params, projectileID)
	if spGetProjectileTimeToLive(projectileID) > 0 then
		local positionX, positionY, positionZ = spGetProjectilePosition(projectileID)
		local velocityX, velocityY, velocityZ, speed = spGetProjectileVelocity(projectileID)

		local targetX, targetY, targetZ
		do
			local targetType, target = spGetProjectileTarget(projectileID)
			if targetType == targetedUnit then
				local _; -- sink for unused values
				_, _, _, -- like so
				targetX, targetY, targetZ = spGetUnitPosition(target, false, true)
			elseif targetType == targetedGround then
				targetX, targetY, targetZ = target[1], target[2], target[3]
			end
		end

		local distance = params.lockon_dist

		if distance * distance < distance3dSquared(positionX, positionY, positionZ, targetX, targetY, targetZ) then
			local cruiseHeight = spGetGroundHeight(positionX, positionZ) + params.cruise_min_height

			if positionY < cruiseHeight then
				projectilesData[projectileID] = true
				applyCruiseCorrection(projectileID, positionX, cruiseHeight, positionZ, velocityX, velocityY, velocityZ)
			elseif projectilesData[projectileID]
				and positionY > cruiseHeight
				and velocityY > speed * -0.25 -- Avoid going into steep dives, e.g. after cliffs.
			then
				applyCruiseCorrection(projectileID, positionX, cruiseHeight, positionZ, velocityX, velocityY, velocityZ)
			end

			return false
		end
	end

	projectilesData[projectileID] = nil

	return true
end

-- Retarget

weaponSpecialEffect.retarget = function(params, projectileID)
	if spGetProjectileTimeToLive(projectileID) > 0 then
		local targetType, target = spGetProjectileTarget(projectileID)

		if targetType == targetedUnit and spGetUnitIsDead(target) ~= false then
			local ownerID = Spring.GetProjectileOwnerID(projectileID)

			if ownerID then
				-- Hardcoded to retarget only from the primary weapon and only units or ground
				local ownerTargetType, _, ownerTarget = Spring.GetUnitWeaponTarget(ownerID, 1)

				if ownerTargetType == 1 then
					spSetProjectileTarget(projectileID, ownerTarget, targetedUnit)
				elseif ownerTargetType == 2 then
					spSetProjectileTarget(projectileID, ownerTarget[1], ownerTarget[2], ownerTarget[3])
				end
				return false
			end
		end
	end
	return true
end

-- Sector fire

weaponCustomParamKeys.sector_fire = {
	max_range_reduction = function(value)
		value = tonumber(value)
		return value and math.clamp(value, 0, 1)
	end,
	spread_angle = function(value)
		value = tonumber(value)
		return value and value * math_pi / 180 or nil
	end,
}

weaponSpecialEffect.sector_fire = function(params, projectileID)
	local rangeReductionMax = params.max_range_reduction
	local transformXZ = 1 - (math_random() ^ (1 + rangeReductionMax)) * rangeReductionMax

	local angleSpread = params.spread_angle * (math_random() - 0.5)
	local transformX = math_cos(angleSpread)
	local transformZ = math_sin(angleSpread)

	local velocityX, velocityY, velocityZ = spGetProjectileVelocity(projectileID)
	velocityX = (velocityX * transformX - velocityZ * transformZ) * transformXZ
	velocityZ = (velocityX * transformZ + velocityZ * transformX) * transformXZ
	spSetProjectileVelocity(projectileID, velocityX, velocityY, velocityZ)

	return true
end

-- Split

weaponCustomParamKeys.split = {
	speceffect_def = toWeaponDefID,
	number = tonumber,
	splitexplosionceg = tostring,
	cegtag = tostring,
	model = tostring,
}

local function split(params, projectileID)
	local spawnDefID, cache, velocity, speed = getSpawnParams(params, projectileID)

	Spring.DeleteProjectile(projectileID)
	Spring.SpawnCEG(params.splitexplosionceg, cache.pos[1], cache.pos[2], cache.pos[3])

	cache.gravity = gravityPerFrame

	for _ = 1, params.number do
		velocity[1] = velocityX + speed * (math_random(-100, 100) / 880)
		velocity[2] = velocityY + speed * (math_random(-100, 100) / 440)
		velocity[3] = velocityZ + speed * (math_random(-100, 100) / 880)

		Spring.SpawnProjectile(spawnDefID, cache)
	end
end

weaponSpecialEffect.split = function(params, projectileID)
	if isProjectileFalling(projectileID) then
		split(params, projectileID)
		return true
	end
end

-- Water penetration (cannon)

weaponCustomParamKeys.cannonwaterpen = {
	speceffect_def = toWeaponDefID,
	waterpenceg = tostring,
	cegtag = tostring,
	model = tostring,
}

local function cannonWaterPen(params, projectileID)
	local spawnDefID, cache, velocity = getSpawnParams(params, projectileID)

	Spring.DeleteProjectile(projectileID)
	Spring.SpawnCEG(params.waterpenceg, cache.pos[1], cache.pos[2], cache.pos[3])

	cache.gravity = gravityPerFrame * 0.5

	velocity[1] = velocity[1] * 0.5
	velocity[2] = velocity[2] * 0.5
	velocity[3] = velocity[3] * 0.5

	Spring.SpawnProjectile(spawnDefID, cache)
end

weaponSpecialEffect.cannonwaterpen = function(projectileID)
	if isProjectileInWater(projectileID) then
		cannonWaterPen(projectileID)
		return true
	end
end

-- Water penetration (torpedo)

checkingFunctions.torpwaterpen = {}
checkingFunctions.torpwaterpen["ypos<0"] = function(proID)
	local _, positionY, _ = Spring.GetProjectilePosition(proID)
	if positionY <= 0 then
		return true
	else
		return false
	end
end

applyingFunctions.torpwaterpen = function(proID)
	local velocityX, velocityY, velocityZ = Spring.GetProjectileVelocity(proID)
	--if target is close under the shooter, however, this resetting makes the torp always miss, unless it has amazing tracking
	--needs special case handling (and there's no point having it visually on top of water for an UW target anyway)

	local bypass = false
	local targetType, targetID = spGetProjectileTarget(proID)

	if (targetType ~= nil) and (targetID ~= nil) and (targetType ~= 103) then --ground attack borks it; skip
		local unitPosX, unitPosY, unitPosZ = Spring.GetUnitPosition(targetID)
		if (unitPosY ~= nil) and unitPosY < -10 then
			bypass = true
			spSetProjectileVelocity(proID, velocityX / 1.3, velocityY / 6, velocityZ / 1.3) --apply brake without fully halting, otherwise it will overshoot very close targets before tracking can reorient it
		end
	end

	if not bypass then
		spSetProjectileVelocity(proID, velocityX, 0, velocityZ)
	end
end

-- Water penetration with retargeting (torpedo)

--a Hornet special, mangle different two things into working as one (they're otherwise mutually exclusive)
checkingFunctions.torpwaterpenretarget = {}
checkingFunctions.torpwaterpenretarget["ypos<0"] = function(proID)
	checkingFunctions.retarget["always"](proID) --subcontract that part

	local _, positionY, _ = Spring.GetProjectilePosition(proID)
	if positionY <= 0 then
		--and delegate that too
		applyingFunctions.torpwaterpen(proID)
	else
		return false
	end
end

--fake function
applyingFunctions.torpwaterpenretarget = function(proID)
	return false
end

--------------------------------------------------------------------------------
-- Engine call-ins -------------------------------------------------------------

function gadget:Initialize()
	local metatables = {}

	for effectName, effectMethod in pairs(weaponSpecialEffect) do
		-- Add self-call syntax to weapon special effects:
		metatables[effectName] = { __call = effectMethod }
	end

	for weaponDefID, weaponDef in pairs(WeaponDefs) do
		if weaponDef.customParams.speceffect then
			local effectName, effectParams = parseCustomParams(weaponDef)

			if effectName then
				weaponParams[weaponDefID] = setmetatable(effectParams, metatables[effectName])
			end
		end
	end

	if not next(weaponParams) then
		Spring.Log(gadget:GetInfo().name, LOG.INFO, "No custom weapons found.")
		gadgetHandler:RemoveGadget(self)
	end
end

function gadget:ProjectileCreated(projectileID, proOwnerID, weaponDefID)
	if weaponParams[weaponDefID] then
		projectiles[projectileID] = weaponParams[weaponDefID]
	end
end

function gadget:ProjectileDestroyed(projectileID)
	projectiles[projectileID] = nil
	projectilesData[projectileID] = nil
end

function gadget:GameFrame(frame)
	for projectileID, effect in pairs(projectiles) do
		if effect(projectileID) then
			projectiles[projectileID] = nil
		end
	end
end
