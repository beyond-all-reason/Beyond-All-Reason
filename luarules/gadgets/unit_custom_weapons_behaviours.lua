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

local random = math.random

local SpSetProjectileVelocity = Spring.SetProjectileVelocity
local SpSetProjectileTarget = Spring.SetProjectileTarget

local SpGetProjectileVelocity = Spring.GetProjectileVelocity
local SpGetProjectileOwnerID = Spring.GetProjectileOwnerID
local SpGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local SpGetUnitWeaponTarget = Spring.GetUnitWeaponTarget
local SpGetProjectileTarget = Spring.GetProjectileTarget
local SpGetUnitIsDead = Spring.GetUnitIsDead

if gadgetHandler:IsSyncedCode() then

	local projectiles = {}
	local active_projectiles = {}
	local checkingFunctions = {}
	local applyingFunctions = {}
	local math_sqrt = math.sqrt
	local mathCos = math.cos
	local mathSin = math.sin
	local mathPi = math.pi

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
		--Spring.Echo()

		if Spring.GetProjectileTimeToLive(proID) <= 0 then
			return true
		end
		local targetTypeInt,target = Spring.GetProjectileTarget(proID)
		local xx,yy,zz
		local xxv,yyv,zzv
		if targetTypeInt == string.byte('g') then
			xx = target[1]
			yy = target[2]
			zz = target[3]
		end
		if targetTypeInt == string.byte('u') then
			_,_,_,_,_,_,xx,yy,zz = Spring.GetUnitPosition(target,true,true)
		end
		local xp,yp,zp = Spring.GetProjectilePosition(proID)
		local vxp,vyp,vzp = Spring.GetProjectileVelocity(proID)
		local mag = math_sqrt(vxp*vxp+vyp*vyp+vzp*vzp)
		local infos = projectiles[proID]
		if math_sqrt((xp-xx)^2 + (yp-yy)^2 + (zp-zz)^2) > tonumber(infos.lockon_dist) then
			yg = Spring.GetGroundHeight(xp,zp)
			nx,ny,nz,slope= Spring.GetGroundNormal(xp,zp)
			--Spring.Echo(Spring.GetGroundNormal(xp,zp))
			--Spring.Echo(tonumber(infos.cruise_height)*slope)
			if yp < yg + tonumber(infos.cruise_min_height) then
				active_projectiles[proID] = true
				Spring.SetProjectilePosition(proID,xp,yg + tonumber(infos.cruise_min_height),zp)
				local norm = (vxp*nx+vyp*ny+vzp*nz)
				xxv = vxp - norm*nx*0
				yyv = vyp - norm*ny
				zzv = vzp - norm*nz*0
				Spring.SetProjectileVelocity(proID,xxv,yyv,zzv)
			end
			if yp > yg + tonumber(infos.cruise_max_height) and active_projectiles[proID] and vyp > -mag*.25 then
				-- do not clamp to max height if
				-- vertical velocity downward is more than 1/4 of current speed
				-- probably just went off lip of steep cliff
				Spring.SetProjectilePosition(proID,xp,yg + tonumber(infos.cruise_max_height),zp)
				local norm = (vxp*nx+vyp*ny+vzp*nz)
				xxv = vxp - norm*nx*0
				yyv = vyp - norm*ny
				zzv = vzp - norm*nz*0
				Spring.SetProjectileVelocity(proID,xxv,yyv,zzv)
			end
			return false
		else
			return true
		end
	end

	applyingFunctions.cruise = function (proID)
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
		local vx, vy, vz = SpGetProjectileVelocity(proID)
		
		local spread_angle = tonumber(infos.spread_angle)
		local max_range_reduction = tonumber(infos.max_range_reduction)
		
		local angle_factor = (spread_angle * (random() - 0.5)) * mathPi / 180
		local cos_angle = mathCos(angle_factor)
		local sin_angle = mathSin(angle_factor)
		
		local vx_new = vx * cos_angle - vz * sin_angle
		local vz_new = vx * sin_angle + vz * cos_angle
		
		local velocity_factor = 1 - (random() ^ (1 + max_range_reduction)) * max_range_reduction
		
		vx = vx_new * velocity_factor
		vz = vz_new * velocity_factor
		
		SpSetProjectileVelocity(proID, vx, vy, vz)
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
		if SpGetProjectileTimeToLive(proID) <= 0 then
			-- stop missile retargeting when it runs out of fuel
			return true
		end
		local targetTypeInt, targetID = SpGetProjectileTarget(proID)
		-- if the missile is heading towards a unit
		if targetTypeInt == string.byte('u') then
			--check if the target unit is dead or dying
			local dead_state = SpGetUnitIsDead(targetID)
			if dead_state == nil or dead_state == true then
				--hardcoded to assume the retarget weapon is the primary weapon.
				--TODO, make this more general
				local target_type,_,owner_target = SpGetUnitWeaponTarget(SpGetProjectileOwnerID(proID),1)
				if target_type == 1 then
					--hardcoded to assume the retarget weapon does not target features or intercept projectiles, only targets units if not shooting ground.
					--TODO, make this more general
					 SpSetProjectileTarget(proID,owner_target,string.byte('u'))
				end
				if target_type == 2 then
					SpSetProjectileTarget(proID,owner_target[1],owner_target[2],owner_target[3])
				end
			end
		end

		return false
	end

	applyingFunctions.retarget = function (proID)
		return false
    end

	checkingFunctions.cannonwaterpen = {}
	checkingFunctions.cannonwaterpen["ypos<0"] = function (proID)
		local _,y,_ = Spring.GetProjectilePosition(proID)
		if y <= 0 then
			return true
		else
			return false
		end
	end

	checkingFunctions.split = {}
	checkingFunctions.split["yvel<0"] = function (proID)
		local _,vy,_ = Spring.GetProjectileVelocity(proID)
		if vy < 0 then
			return true
		else
			return false
		end
	end

	checkingFunctions.torpwaterpen = {}
    checkingFunctions.torpwaterpen["ypos<0"] = function (proID)
        local _,py,_ = Spring.GetProjectilePosition(proID)
        if py <= 0 then
            return true
        else
            return false
        end
    end
	
	
	--a Hornet special, mangle different two things into working as one (they're otherwise mutually exclusive)
	checkingFunctions.torpwaterpenretarget = {}
    checkingFunctions.torpwaterpenretarget["ypos<0"] = function (proID)
	
		checkingFunctions.retarget["always"](proID)--subcontract that part
	
        local _,py,_ = Spring.GetProjectilePosition(proID)
        if py <= 0 then
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

	

	applyingFunctions.split = function (proID)
		local px, py, pz = Spring.GetProjectilePosition(proID)
		local vx, vy, vz = Spring.GetProjectileVelocity(proID)
		local vw = math_sqrt(vx*vx + vy*vy + vz*vz)
		local ownerID = Spring.GetProjectileOwnerID(proID)
		local infos = projectiles[proID]
		for i = 1, tonumber(infos.number) do
			local projectileParams = {
				pos = {px, py, pz},
				speed = {vx - vw*(math.random(-100,100)/880), vy - vw*(math.random(-100,100)/440), vz - vw*(math.random(-100,100)/880)},
				owner = ownerID,
				ttl = 3000,
				gravity = -Game.gravity/900,
				model = infos.model,
				cegTag = infos.cegtag,
				}
			Spring.SpawnProjectile(weaponDefNamesID[infos.def], projectileParams)
		end
		Spring.SpawnCEG(infos.splitexplosionceg, px, py, pz,0,0,0,0,0)
		Spring.DeleteProjectile(proID)
	end

	applyingFunctions.torpwaterpen = function (proID)
		local vx, vy, vz = Spring.GetProjectileVelocity(proID)
		--if target is close under the shooter, however, this resetting makes the torp always miss, unless it has amazing tracking
		--needs special case handling (and there's no point having it visually on top of water for an UW target anyway)
		
		local bypass = false
		local targetType, targetID = Spring.GetProjectileTarget(proID)
		
		if (targetType ~= nil) and (targetID ~= nil) and (targetType ~= 103) then--ground attack borks it; skip
			local unitPosX, unitPosY, unitPosZ = Spring.GetUnitPosition(targetID)
			if (unitPosY ~= nil) and unitPosY<-10 then
				bypass = true
				Spring.SetProjectileVelocity(proID,vx/1.3,vy/6,vz/1.3)--apply brake without fully halting, otherwise it will overshoot very close targets before tracking can reorient it
			end
		end
		
		if not bypass then
			Spring.SetProjectileVelocity(proID,vx,0,vz)
		end
    end




















	applyingFunctions.cannonwaterpen = function (proID)
		local px, py, pz = Spring.GetProjectilePosition(proID)
		local vx, vy, vz = Spring.GetProjectileVelocity(proID)
		local nvx, nvy, nvz = vx * 0.5, vy * 0.5, vz * 0.5
		local ownerID = Spring.GetProjectileOwnerID(proID)
		local infos = projectiles[proID]
		local projectileParams = {
			pos = {px, py, pz},
			speed = {nvx, nvy, nvz},
			owner = ownerID,
			ttl = 3000,
			gravity = -Game.gravity/3600,
			model = infos.model,
			cegTag = infos.cegtag,
		}
		Spring.SpawnProjectile(weaponDefNamesID[infos.def], projectileParams)
		Spring.SpawnCEG(infos.waterpenceg, px, py, pz,0,0,0,0,0)
		Spring.DeleteProjectile(proID)
	end

	function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
		if specialWeaponCustomDefs[weaponDefID] then
			projectiles[proID] = specialWeaponCustomDefs[weaponDefID]
			active_projectiles[proID] = nil
		end
	end

	function gadget:ProjectileDestroyed(proID)
		projectiles[proID] = nil
		active_projectiles[proID] = nil
	end

	function gadget:GameFrame(f)
		for proID, infos in pairs(projectiles) do
			if checkingFunctions[infos.speceffect][infos.when](proID) == true then
				applyingFunctions[infos.speceffect](proID)
				projectiles[proID] = nil
				active_projectiles[proID] = nil
			end
		end
	end
end
