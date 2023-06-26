function gadget:GetInfo()
	return {
		name      = "Custom weapon behaviours",
		desc      = "Handler for special weapon behaviours",
		author    = "Doo",
		date      = "Sept 19th 2017",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true  --  loaded by default?
	}
end

local random = math.random
local SpGetProjectileVelocity = Spring.GetProjectileVelocity
local SpSetProjectileVelocity = Spring.SetProjectileVelocity
local SpGetProjectileOwnerID = Spring.GetProjectileOwnerID
local SpGetUnitStates = Spring.GetUnitStates

if gadgetHandler:IsSyncedCode() then

	local projectiles = {}
	local active_projectiles = {}
	local checkingFunctions = {}
	local applyingFunctions = {}
	local math_sqrt = math.sqrt

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

	checkingFunctions.siege = {}
	checkingFunctions.siege["state==true"] = function (proID)
		-- as soon as the siege projectile is created, pass true on the
		-- checking function, to go to applying function
		-- so the unit state is only checked when the projectile is created
		return true
	end

	applyingFunctions.siege = function (proID)
		local ownerID = SpGetProjectileOwnerID(proID)
		local ownerState = SpGetUnitStates(ownerID)
		if ownerState.active == true then
			local infos = projectiles[proID]
			factor = tonumber(infos.max_velocity_reduction)*random()
			local vx, vy, vz = SpGetProjectileVelocity(proID)
			vx = vx*(1-factor)
			vy = vy*(1-factor)
			vz = vz*(1-factor)
			SpSetProjectileVelocity(proID,vx,vy,vz)
		end
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
        Spring.SetProjectileVelocity(proID,vx,0,vz)
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
		local wDefID = Spring.GetProjectileDefID(proID)
		if specialWeaponCustomDefs[wDefID] then
			projectiles[proID] = specialWeaponCustomDefs[wDefID]
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
