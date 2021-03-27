function gadget:GetInfo()
	return {
		name      = "Custom weapon behaviours",
		desc      = "Handler for special weapon behaviours",
		author    = "Doo",
		date      = "Sept 19th 2017",
		layer     = 0,
		enabled   = true  --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then

	local specialIDs = {}
	local projectiles = {}
	local checkingFunctions = {}
	local applyingFunctions = {}
	local math_sqrt = math.sqrt

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
				speed = {vx - vw*(math.random(-100,100)/500), vy - vw*(math.random(-100,100)/250), vz - vw*(math.random(-100,100)/500)},
				owner = ownerID,
				ttl = 3000,
				gravity = -Game.gravity/900,
				model = infos.model,
				cegTag = infos.cegtag,
				}
			Spring.SpawnProjectile(WeaponDefNames[infos.def].id, projectileParams)
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
			Spring.SpawnProjectile(WeaponDefNames[infos.def].id, projectileParams)
		Spring.SpawnCEG(infos.waterpenceg, px, py, pz,0,0,0,0,0)
		Spring.DeleteProjectile(proID)
	end

	for id, def in pairs(WeaponDefs) do
		if def.customParams and def.customParams.speceffect then
			local cp = def.customParams
			specialIDs[id] = cp
		end
	end

	function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
		local wDefID = Spring.GetProjectileDefID(proID)
		if specialIDs[wDefID] then
			projectiles[proID] = specialIDs[wDefID]
		end
	end

	function gadget:ProjectileDestroyed(proID)
		projectiles[proID] = nil
	end

	function gadget:GameFrame(f)
		for proID, infos in pairs(projectiles) do
			if checkingFunctions[infos.speceffect][infos.when](proID) == true then
				applyingFunctions[infos.speceffect](proID)
				projectiles[proID] = nil
			end
		end
	end
end