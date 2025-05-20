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

local spSetProjectileVelocity = Spring.SetProjectileVelocity
local spSetProjectileTarget = Spring.SetProjectileTarget

local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spGetProjectileOwnerID = Spring.GetProjectileOwnerID
local spGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local spGetUnitWeaponTarget = Spring.GetUnitWeaponTarget
local spGetProjectileTarget = Spring.GetProjectileTarget
local spGetUnitIsDead = Spring.GetUnitIsDead

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

local projectiles = {}
local projectileData = {}
local checkingFunctions = {}
local applyingFunctions = {}

local specialWeaponCustomDefs = {}
local weaponDefNamesID = {}
for id, def in pairs(WeaponDefs) do
	weaponDefNamesID[def.name] = id
	if def.customParams.speceffect then
		specialWeaponCustomDefs[id] = def.customParams
	end
end

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

-- Cruise

checkingFunctions.cruise = {}
checkingFunctions.cruise["distance>0"] = function(proID)
	--Spring.Echo()

	if spGetProjectileTimeToLive(proID) <= 0 then
		return true
	end
	local targetTypeInt, target = spGetProjectileTarget(proID)
	local targetX, targetY, targetZ
	local velocityX, velocityY, velocityZ
	if targetTypeInt == string.byte('g') then
		targetX = target[1]
		targetY = target[2]
		targetZ = target[3]
	end
	if targetTypeInt == string.byte('u') then
		_, _, _, _, _, _, targetX, targetY, targetZ = Spring.GetUnitPosition(target, true, true)
	end
	local positionX, positionY, positionz = Spring.GetProjectilePosition(proID)
	local velocityX, velocityY, velocityZ = Spring.GetProjectileVelocity(proID)
	local speed = math_sqrt(velocityX * velocityX + velocityY * velocityY + velocityZ * velocityZ)
	local params = projectiles[proID]
	if math_sqrt((positionX - targetX) ^ 2 + (positionY - targetY) ^ 2 + (positionz - targetZ) ^ 2) > tonumber(params.lockon_dist) then
		elevation = Spring.GetGroundHeight(positionX, positionz)
		normalX, normalY, normalZ, slope = Spring.GetGroundNormal(positionX, positionz)
		--Spring.Echo(Spring.GetGroundNormal(xp,zp))
		--Spring.Echo(tonumber(infos.cruise_height)*slope)
		if positionY < elevation + tonumber(params.cruise_min_height) then
			projectileData[proID] = true
			Spring.SetProjectilePosition(proID, positionX, elevation + tonumber(params.cruise_min_height), positionz)
			local dotProduct = (velocityX * normalX + velocityY * normalY + velocityZ * normalZ)
			velocityX = velocityX - dotProduct * normalX * 0
			velocityY = velocityY - dotProduct * normalY
			velocityZ = velocityZ - dotProduct * normalZ * 0
			spSetProjectileVelocity(proID, velocityX, velocityY, velocityZ)
		end
		if positionY > elevation + tonumber(params.cruise_max_height) and projectileData[proID] and velocityY > -speed * .25 then
			-- do not clamp to max height if
			-- vertical velocity downward is more than 1/4 of current speed
			-- probably just went off lip of steep cliff
			Spring.SetProjectilePosition(proID, positionX, elevation + tonumber(params.cruise_max_height), positionz)
			local norm = (velocityX * normalX + velocityY * normalY + velocityZ * normalZ)
			velocityX = velocityX - norm * normalX * 0
			velocityY = velocityY - norm * normalY
			velocityZ = velocityZ - norm * normalZ * 0
			spSetProjectileVelocity(proID, velocityX, velocityY, velocityZ)
		end
		return false
	else
		return true
	end
end
applyingFunctions.cruise = function(proID)
	return false
end

-- Retarget

checkingFunctions.retarget = {}
checkingFunctions.retarget["always"] = function(proID)
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
	local targetType, targetID = spGetProjectileTarget(proID)
	-- if the missile is heading towards a unit
	if targetType == string.byte('u') then
		--check if the target unit is dead or dying
		local dead_state = spGetUnitIsDead(targetID)
		if dead_state == nil or dead_state == true then
			--hardcoded to assume the retarget weapon is the primary weapon.
			--TODO, make this more general
			local targetTypeOwner, _, targetOwner = spGetUnitWeaponTarget(spGetProjectileOwnerID(proID), 1)
			if targetTypeOwner == 1 then
				--hardcoded to assume the retarget weapon does not target features or intercept projectiles, only targets units if not shooting ground.
				--TODO, make this more general
				spSetProjectileTarget(proID, targetOwner, string.byte('u'))
			end
			if targetTypeOwner == 2 then
				spSetProjectileTarget(proID, targetOwner[1], targetOwner[2], targetOwner[3])
			end
		end
	end

	return false
end

applyingFunctions.retarget = function(proID)
	return false
end

-- Sector fire

checkingFunctions.sector_fire = {}
checkingFunctions.sector_fire["always"] = function(proID)
	-- as soon as the siege projectile is created, pass true on the
	-- checking function, to go to applying function
	-- so the unit state is only checked when the projectile is created
	return true
end
applyingFunctions.sector_fire = function(proID)
	local params = projectiles[proID]
	local velocityX, velocityY, velocityZ = spGetProjectileVelocity(proID)

	local angleSpread = tonumber(params.spread_angle)
	local rangeReductionMax = tonumber(params.max_range_reduction)

	local angleFactor = (angleSpread * (math_random() - 0.5)) * math_pi / 180
	local angleCos = math_cos(angleFactor)
	local angleSin = math_sin(angleFactor)

	local vx_new = velocityX * angleCos - velocityZ * angleSin
	local vz_new = velocityX * angleSin + velocityZ * angleCos

	local velocityFactor = 1 - (math_random() ^ (1 + rangeReductionMax)) * rangeReductionMax

	velocityX = vx_new * velocityFactor
	velocityZ = vz_new * velocityFactor

	spSetProjectileVelocity(proID, velocityX, velocityY, velocityZ)
end

-- Split

checkingFunctions.split = {}
checkingFunctions.split["yvel<0"] = function(proID)
	local _, velocityY, _ = Spring.GetProjectileVelocity(proID)
	if velocityY < 0 then
		return true
	else
		return false
	end
end

applyingFunctions.split = function(proID)
	local positionX, positionY, positionZ = Spring.GetProjectilePosition(proID)
	local velocityX, velocityY, velocityZ = Spring.GetProjectileVelocity(proID)
	local speed = math_sqrt(velocityX * velocityX + velocityY * velocityY + velocityZ * velocityZ)
	local ownerID = spGetProjectileOwnerID(proID)
	local params = projectiles[proID]
	for i = 1, tonumber(params.number) do
		local projectileParams = {
			pos = { positionX, positionY, positionZ },
			speed = { velocityX - speed * (math_random(-100, 100) / 880), velocityY - speed * (math_random(-100, 100) / 440), velocityZ - speed * (math_random(-100, 100) / 880) },
			owner = ownerID,
			ttl = 3000,
			gravity = -Game.gravity / 900,
			model = params.model,
			cegTag = params.cegtag,
		}
		Spring.SpawnProjectile(weaponDefNamesID[params.def], projectileParams)
	end
	Spring.SpawnCEG(params.splitexplosionceg, positionX, positionY, positionZ, 0, 0, 0, 0, 0)
	Spring.DeleteProjectile(proID)
end

-- Water penetration (cannon)

checkingFunctions.cannonwaterpen = {}
checkingFunctions.cannonwaterpen["ypos<0"] = function(proID)
	local _, positionY, _ = Spring.GetProjectilePosition(proID)
	if positionY <= 0 then
		return true
	else
		return false
	end
end

applyingFunctions.cannonwaterpen = function(proID)
	local projectileX, projectileY, projectileZ = Spring.GetProjectilePosition(proID)
	local velocityX, velocityY, velocityZ = Spring.GetProjectileVelocity(proID)
	velocityX, velocityY, velocityZ = velocityX * 0.5, velocityY * 0.5, velocityZ * 0.5
	local ownerID = spGetProjectileOwnerID(proID)
	local params = projectiles[proID]
	local projectileParams = {
		pos = { projectileX, projectileY, projectileZ },
		speed = { velocityX, velocityY, velocityZ },
		owner = ownerID,
		ttl = 3000,
		gravity = -Game.gravity / 3600,
		model = params.model,
		cegTag = params.cegtag,
	}
	Spring.SpawnProjectile(weaponDefNamesID[params.def], projectileParams)
	Spring.SpawnCEG(params.waterpenceg, projectileX, projectileY, projectileZ, 0, 0, 0, 0, 0)
	Spring.DeleteProjectile(proID)
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

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	if specialWeaponCustomDefs[weaponDefID] then
		projectiles[proID] = specialWeaponCustomDefs[weaponDefID]
		projectileData[proID] = nil
	end
end

function gadget:ProjectileDestroyed(proID)
	projectiles[proID] = nil
	projectileData[proID] = nil
end

function gadget:GameFrame(f)
	for proID, infos in pairs(projectiles) do
		if checkingFunctions[infos.speceffect][infos.when](proID) == true then
			applyingFunctions[infos.speceffect](proID)
			projectiles[proID] = nil
			projectileData[proID] = nil
		end
	end
end
