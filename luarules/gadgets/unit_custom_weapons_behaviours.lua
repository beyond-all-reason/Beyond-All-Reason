local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Custom weapon behaviours",
		desc      = "Handler for special weapon behaviours",
		author    = "Doo",
		date      = "Sept 19th 2017",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

if not gadgetHandler:IsSyncedCode() then return false end

local random = math.random

local spSetProjectileVelocity = Spring.SetProjectileVelocity
local spSetProjectileTarget = Spring.SetProjectileTarget

local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spGetProjectileOwnerID = Spring.GetProjectileOwnerID
local spGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local spGetUnitWeaponTarget = Spring.GetUnitWeaponTarget
local spGetProjectileTarget = Spring.GetProjectileTarget
local spGetUnitIsDead = Spring.GetUnitIsDead

local projectiles = {}
local projectilesData = {}
local checkingFunctions = {}
local applyingFunctions = {}
local sqrt = math.sqrt
local cos = math.cos
local sin = math.sin
local pi = math.pi

local specialWeaponCustomDefs = {}
local weaponDefNamesID = {}
for id, def in pairs(WeaponDefs) do
	weaponDefNamesID[def.name] = id
	if def.customParams.speceffect then
		specialWeaponCustomDefs[id] = def.customParams
	end
end

checkingFunctions.cruise = {}
checkingFunctions.cruise["distance>0"] = function (proID)
	if Spring.GetProjectileTimeToLive(proID) <= 0 then
		return true
	end
	local targetTypeInt,target = Spring.GetProjectileTarget(proID)
	local targetPosX,targetPosY,targetPosZ
	local projectileVelXNew,projectileVelYNew,projectileVelZNew
	if targetTypeInt == string.byte('g') then
		targetPosX = target[1]
		targetPosY = target[2]
		targetPosZ = target[3]
	end
	if targetTypeInt == string.byte('u') then
		_,_,_,_,_,_,targetPosX,targetPosY,targetPosZ = Spring.GetUnitPosition(target,true,true)
	end
	local projectilePosX,projectilePosY,projectilePosZ = Spring.GetProjectilePosition(proID)
	local projectileVelX,projectileVelY,projectileVelZ = Spring.GetProjectileVelocity(proID)
	local speed = sqrt(projectileVelX*projectileVelX+projectileVelY*projectileVelY+projectileVelZ*projectileVelZ)
	local infos = projectiles[proID]
	if sqrt((projectilePosX-targetPosX)^2 + (projectilePosY-targetPosY)^2 + (projectilePosZ-targetPosZ)^2) > tonumber(infos.lockon_dist) then
		groundPosY = Spring.GetGroundHeight(projectilePosX,projectilePosZ)
		groundNormX,groundNormY,groundNormZ,slope= Spring.GetGroundNormal(projectilePosX,projectilePosZ)
		--Spring.Echo(Spring.GetGroundNormal(xp,zp))
		--Spring.Echo(tonumber(infos.cruise_height)*slope)
		if projectilePosY < groundPosY + tonumber(infos.cruise_min_height) then
			projectilesData[proID] = true
			Spring.SetProjectilePosition(proID,projectilePosX,groundPosY + tonumber(infos.cruise_min_height),projectilePosZ)
			local norm = (projectileVelX*groundNormX+projectileVelY*groundNormY+projectileVelZ*groundNormZ)
			projectileVelXNew = projectileVelX - norm*groundNormX*0
			projectileVelYNew = projectileVelY - norm*groundNormY
			projectileVelZNew = projectileVelZ - norm*groundNormZ*0
			Spring.SetProjectileVelocity(proID,projectileVelXNew,projectileVelYNew,projectileVelZNew)
		end
		if projectilePosY > groundPosY + tonumber(infos.cruise_max_height) and projectilesData[proID] and projectileVelY > -speed*.25 then
			-- do not clamp to max height if
			-- vertical velocity downward is more than 1/4 of current speed
			-- probably just went off lip of steep cliff
			Spring.SetProjectilePosition(proID,projectilePosX,groundPosY + tonumber(infos.cruise_max_height),projectilePosZ)
			local norm = (projectileVelX*groundNormX+projectileVelY*groundNormY+projectileVelZ*groundNormZ)
			projectileVelXNew = projectileVelX - norm*groundNormX*0
			projectileVelYNew = projectileVelY - norm*groundNormY
			projectileVelZNew = projectileVelZ - norm*groundNormZ*0
			Spring.SetProjectileVelocity(proID,projectileVelXNew,projectileVelYNew,projectileVelZNew)
		end
		return false
	else
		return true
	end
end
applyingFunctions.cruise = function (proID)
	return false
end

checkingFunctions.retarget = {}
checkingFunctions.retarget["always"] = function (proID)
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
			local ownerTargetType,_,ownerTarget = spGetUnitWeaponTarget(spGetProjectileOwnerID(proID),1)
			if ownerTargetType == 1 then
				--hardcoded to assume the retarget weapon does not target features or intercept projectiles, only targets units if not shooting ground.
				--TODO, make this more general
					spSetProjectileTarget(proID,ownerTarget,string.byte('u'))
			end
			if ownerTargetType == 2 then
				spSetProjectileTarget(proID,ownerTarget[1],ownerTarget[2],ownerTarget[3])
			end
		end
	end

	return false
end
applyingFunctions.retarget = function (proID)
	return false
end

checkingFunctions.sector_fire = {}
checkingFunctions.sector_fire["always"] = function (proID)
	-- as soon as the siege projectile is created, pass true on the
	-- checking function, to go to applying function
	-- so the unit state is only checked when the projectile is created
	return true
end
applyingFunctions.sector_fire = function (proID)
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
end

checkingFunctions.split = {}
checkingFunctions.split["yvel<0"] = function (proID)
	local _,projectileVelY,_ = Spring.GetProjectileVelocity(proID)
	if projectileVelY < 0 then
		return true
	else
		return false
	end
end
applyingFunctions.split = function (proID)
	local projectilePosX, projectilePosY, projectilePosZ = Spring.GetProjectilePosition(proID)
	local projectileVelX, projectileVelY, projectileVelZ = Spring.GetProjectileVelocity(proID)
	local speed = sqrt(projectileVelX*projectileVelX + projectileVelY*projectileVelY + projectileVelZ*projectileVelZ)
	local ownerID = Spring.GetProjectileOwnerID(proID)
	local infos = projectiles[proID]
	for i = 1, tonumber(infos.number) do
		local projectileParams = {
			pos = {projectilePosX, projectilePosY, projectilePosZ},
			speed = {projectileVelX - speed*(math.random(-100,100)/880), projectileVelY - speed*(math.random(-100,100)/440), projectileVelZ - speed*(math.random(-100,100)/880)},
			owner = ownerID,
			ttl = 3000,
			gravity = -Game.gravity/900,
			model = infos.model,
			cegTag = infos.cegtag,
			}
		Spring.SpawnProjectile(weaponDefNamesID[infos.def], projectileParams)
	end
	Spring.SpawnCEG(infos.splitexplosionceg, projectilePosX, projectilePosY, projectilePosZ,0,0,0,0,0)
	Spring.DeleteProjectile(proID)
end

checkingFunctions.cannonwaterpen = {}
checkingFunctions.cannonwaterpen["ypos<0"] = function (proID)
	local _,projectilePosY,_ = Spring.GetProjectilePosition(proID)
	if projectilePosY <= 0 then
		return true
	else
		return false
	end
end
applyingFunctions.cannonwaterpen = function (proID)
	local projectilePosX, projectilePosY, projectilePosZ = Spring.GetProjectilePosition(proID)
	local projectileVelX, projectileVelY, projectileVelZ = Spring.GetProjectileVelocity(proID)
	local nvx, nvy, nvz = projectileVelX * 0.5, projectileVelY * 0.5, projectileVelZ * 0.5
	local ownerID = Spring.GetProjectileOwnerID(proID)
	local infos = projectiles[proID]
	local projectileParams = {
		pos = {projectilePosX, projectilePosY, projectilePosZ},
		speed = {nvx, nvy, nvz},
		owner = ownerID,
		ttl = 3000,
		gravity = -Game.gravity/3600,
		model = infos.model,
		cegTag = infos.cegtag,
	}
	Spring.SpawnProjectile(weaponDefNamesID[infos.def], projectileParams)
	Spring.SpawnCEG(infos.waterpenceg, projectilePosX, projectilePosY, projectilePosZ,0,0,0,0,0)
	Spring.DeleteProjectile(proID)
end

checkingFunctions.torpwaterpen = {}
checkingFunctions.torpwaterpen["ypos<0"] = function (proID)
	local _,projectilePosY,_ = Spring.GetProjectilePosition(proID)
	if projectilePosY <= 0 then
		return true
	else
		return false
	end
end
applyingFunctions.torpwaterpen = function (proID)
	local projectileVelX, projectileVelY, projectileVelZ = Spring.GetProjectileVelocity(proID)
	--if target is close under the shooter, however, this resetting makes the torp always miss, unless it has amazing tracking
	--needs special case handling (and there's no point having it visually on top of water for an UW target anyway)
	
	local bypass = false
	local targetType, targetID = Spring.GetProjectileTarget(proID)
	
	if (targetType ~= nil) and (targetID ~= nil) and (targetType ~= 103) then--ground attack borks it; skip
		local unitPosX, unitPosY, unitPosZ = Spring.GetUnitPosition(targetID)
		if (unitPosY ~= nil) and unitPosY<-10 then
			bypass = true
			Spring.SetProjectileVelocity(proID,projectileVelX/1.3,projectileVelY/6,projectileVelZ/1.3)--apply brake without fully halting, otherwise it will overshoot very close targets before tracking can reorient it
		end
	end
	
	if not bypass then
		Spring.SetProjectileVelocity(proID,projectileVelX,0,projectileVelZ)
	end
end

--a Hornet special, mangle different two things into working as one (they're otherwise mutually exclusive)
checkingFunctions.torpwaterpenretarget = {}
checkingFunctions.torpwaterpenretarget["ypos<0"] = function (proID)

	checkingFunctions.retarget["always"](proID)--subcontract that part

	local _,projectilePosY,_ = Spring.GetProjectilePosition(proID)
	if projectilePosY <= 0 then
		--and delegate that too
		applyingFunctions.torpwaterpen(proID)
	else
		return false
	end
end
--fake function
applyingFunctions.torpwaterpenretarget = function (proID)
	return false
end

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	if specialWeaponCustomDefs[weaponDefID] then
		projectiles[proID] = specialWeaponCustomDefs[weaponDefID]
		projectilesData[proID] = nil
	end
end

function gadget:ProjectileDestroyed(proID)
	projectiles[proID] = nil
	projectilesData[proID] = nil
end

function gadget:GameFrame(f)
	for proID, infos in pairs(projectiles) do
		if checkingFunctions[infos.speceffect][infos.when](proID) == true then
			applyingFunctions[infos.speceffect](proID)
			projectiles[proID] = nil
			projectilesData[proID] = nil
		end
	end
end
