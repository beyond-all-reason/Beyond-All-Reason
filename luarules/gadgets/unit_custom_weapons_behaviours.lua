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


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then

	local specialIDs = {}
	local projectiles = {}
	local checkingFunctions = {}
	local applyingFunctions = {}

	checkingFunctions.split = {}
	checkingFunctions.split["yvel<0"] = function (proID)
		local _,vy,_ = Spring.GetProjectileVelocity(proID)
		if vy < 0 then
			return true
		else
			return false
		end
	end
	
	applyingFunctions.split = function (proID)
		local px, py, pz = Spring.GetProjectilePosition(proID)
		local vx, vy, vz = Spring.GetProjectileVelocity(proID)
		local vw = math.sqrt(vx^2+vy^2+vz^2)
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