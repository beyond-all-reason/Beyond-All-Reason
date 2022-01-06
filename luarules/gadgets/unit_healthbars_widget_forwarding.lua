function gadget:GetInfo()
	return {
		name			= "Healthbars Widget Forwarding",
		desc			= "Notifies widgets that a feature reclaim or resurrect action has begun, updates GL Uniforms, and also notifies on capture start, emp damage, reload",
		author		= "Beherith", -- ty Sprung
		date			= "2021.11.25",
		license	 = "GNU GPL, v2 or later",
		layer		 = -1,
		enabled	 = true	--	loaded by default?
	}
end



local function MinEngineVersion(minver)
	local engineversion = Engine.versionFull -- this is "" in synced
	if engineversion == "" then 
		Spring.Echo("unable to fetch synced engine version")
		return true
	end
	Spring.Echo(engineversion)
	engineversion = string.sub(engineversion, 9) -- 105.1.1-670-
	Spring.Echo(engineversion)
	engineversion = string.sub(engineversion, 1, string.find(engineversion, '-', nil, true) -1)
	Spring.Echo(engineversion)
	if tonumber(engineversion) ~= nil and tonumber(engineversion) >= minver then 
		return true
	else return false end
end

if MinEngineVersion(670) then 
	--Spring.Echo("Engine version is sufficient")
else
	--Spring.Echo("Engine version is too old")
	return
end
	

if gadgetHandler:IsSyncedCode() then
	
	local forwardedFeatureIDs = {} -- so we only forward the start event once
	local forwardedCaptureUnitIDs = {}
	
	local weapondefsreload = {}
	local minReloadTime = 5 -- in concerto with healthbars widget

	function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, step)
		-- VERY IMPORTANT: This also gets called on resurrect!, but its very hard to tell if its a reclaim, but we can make the mother of all assumptions: 
		-- features die at 100% metal value
		-- step is negative if 'reclaiming'
		-- step is large positive if refilling
		-- step is small positive if rezzing
		
		local gf = Spring.GetGameFrame()
		--Spring.Echo("AllowFeatureBuildStep",gf,builderID, builderTeam, featureID, featureDefID, step)
		if forwardedFeatureIDs[featureID] == nil or forwardedFeatureIDs[featureID] < gf then 
			 forwardedFeatureIDs[featureID] = gf
			 SendToUnsynced("featureReclaimFrame", featureID, step)
		end
		return true
	end
	
	function gadget:AllowUnitCaptureStep(builderID, builderTeam, unitID, unitDefID, part)
		if forwardedCaptureUnitIDs[unitID] == nil then 
			forwardedCaptureUnitIDs[unitID] = true
			SendToUnsynced("unitCaptureFrame", unitID, part)
		end
		return true
	end
	
	function gadget:FeatureDestroyed(featureID, allyTeamID)
		forwardedFeatureIDs[featureID] = nil
	end
	
	function gadget:UnitDestroyed(unitID)
		forwardedCaptureUnitIDs[unitID] = nil
	end
	
	function gadget:Initialize()
		for udefID, unitDef in pairs(UnitDefs) do
			local weapons = unitDef.weapons
			local watchweaponID = nil
			local longestreloadtime = -1
			for i = 1, #weapons do
				local WeaponDefID = weapons[i].weaponDef
				local WeaponDef = WeaponDefs[WeaponDefID]
				if WeaponDef.reload and WeaponDef.reload >0 and WeaponDef.reload >= longestreloadtime then
					longestreloadtime = WeaponDef.reload
					watchweaponID = WeaponDefID
				end
			end
			if watchweaponID and longestreloadtime > minReloadTime then 
				--Spring.Echo("Unit with watched reload time:", unitDef.name, longestreloadtime)
				weapondefsreload[udefID] = myreloadTime
				Script.SetWatchProjectile(watchweaponID, true)
			end
		end
	end
	
	function gadget:ProjectileCreated(projectileID, ownerID, weaponID)		-- needs: Script.SetWatchProjectile(weaponDefID, true)
		--Spring.Echo("gadget:ProjectileCreated(",projectileID, ownerID, weaponID,")")
		SendToUnsynced("projetileCreatedReload", projectileID, ownerID, weaponID)
	end
else
	local glSetFeatureBufferUniforms = gl.SetFeatureBufferUniforms
	local GetFeatureResources = Spring.GetFeatureResources
	local FeatureResurrectUniform = 1
	local FeatureReclaimUniform = 2
	local rezreclaim = {0.0, 1.0} -- this is just a small table cache, so we dont allocate a new table for every update
	local forwardedFeatureIDsResurrect = {} -- so we only forward the start event once
	local forwardedFeatureIDsReclaim = {} -- so we only forward the start event once
	local myTeamID = Spring.GetMyTeamID()
	local _, fullview = Spring.GetSpectatingState()
	local IsUnitInView = Spring.IsUnitInView
	local GetFeatureHealth = Spring.GetFeatureHealth 
	local CMD_CAPTURE = CMD.CAPTURE
	local forwardedCaptureTargets = {} -- unitID: gameFrame
	
	function gadget:PlayerChanged(playerID)
	myTeamID = Spring.GetMyTeamID()
	_, fullview = Spring.GetSpectatingState()
	end
	
	function featureReclaimFrame(cmd, featureID, step)
		--Spring.Echo("HandleFeatureReclaimStarted", featureID)
		rezreclaim[1] = select(3, GetFeatureHealth( featureID )) -- resurrect progress
		rezreclaim[2] = select(5, GetFeatureResources(featureID)) -- reclaim percent
		
		--Spring.Echo('rezreclaim', rezreclaim[1], rezreclaim[2])
		
		glSetFeatureBufferUniforms(featureID, rezreclaim, 1) -- update GL, at offset of 1
		
		if step > 0 and forwardedFeatureIDsResurrect[featureID] == nil and Script.LuaUI("FeatureReclaimStartedHealthbars") then 
				forwardedFeatureIDsResurrect[featureID] = true			
				--Spring.Echo("HandleFeatureReclaimStartedHealthbars", featureID, step)
				Script.LuaUI.FeatureReclaimStartedHealthbars(featureID, step)
		end
		
		if step < 0 and forwardedFeatureIDsReclaim[featureID] == nil and Script.LuaUI("FeatureReclaimStartedHealthbars") then 
				forwardedFeatureIDsReclaim[featureID] = true			
				--Spring.Echo("HandleFeatureReclaimStartedHealthbars", featureID, step)
				Script.LuaUI.FeatureReclaimStartedHealthbars(featureID, step)
		end
	end
	
	function unitCaptureFrame(cmd, unitID, step)
		if Script.LuaUI("UnitCaptureStartedHealthbars") then
			--Spring.Echo("UnitCaptureStartedHealthbars", unitID, step)
			Script.LuaUI.UnitCaptureStartedHealthbars(unitID, step)
		end
	end
	
	function projetileCreatedReload(cmd, projectileID, ownerID, weaponID)
		--Spring.Echo("unsynced projetileCreatedReload", projectileID, ownerID, weaponID, fullview, Spring.GetUnitTeam(ownerID))
		if fullview or Spring.GetUnitTeam(ownerID) == myTeamID then
			if Script.LuaUI("ProjectileCreatedReloadHB") then
				--Spring.Echo("G:ProjectileCreatedReloadHB", projectileID, ownerID, weaponID)
				Script.LuaUI.ProjectileCreatedReloadHB(projectileID, ownerID, weaponID)
			end
		end
	end
	
	function gadget:FeatureDestroyed(featureID, allyTeamID)
		forwardedFeatureIDsResurrect[featureID] = nil
		forwardedFeatureIDsReclaim[featureID] = nil
	end
	
	function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
		--Spring.Echo("gadget:UnitDamaged",unitID, unitDefID, unitTeam, damage, paralyzer)
		if paralyzer then
			if not fullview and not CallAsTeam(myTeamID, IsUnitInView, unitID) then return end
			
			if damage > 0 then
				if Script.LuaUI("UnitParalyzeDamageHealthbars") then 
					--Spring.Echo("UnitParalyzeDamageHealthbars", unitID, step)
					Script.LuaUI.UnitParalyzeDamageHealthbars(unitID, unitDefID, damage)
				end
				if Script.LuaUI("UnitParalyzeDamageEffect") then 
					--Spring.Echo("UnitParalyzeDamageHealthbars", unitID, step)
					Script.LuaUI.UnitParalyzeDamageEffect(unitID, unitDefID, damage)
				end
			end
		end
	end
	
	function gadget:Initialize()
		gadgetHandler:AddSyncAction("featureReclaimFrame", featureReclaimFrame)
		gadgetHandler:AddSyncAction("unitCaptureFrame", unitCaptureFrame)
		gadgetHandler:AddSyncAction("projetileCreatedReload", projetileCreatedReload)
	end
	
	
	function gadget:ShutDown()
		gadgetHandler:RemoveSyncAction("featureReclaimFrame")
		gadgetHandler:RemoveSyncAction("unitCaptureFrame")
		gadgetHandler:RemoveSyncAction("projetileCreatedReload")
	end
end