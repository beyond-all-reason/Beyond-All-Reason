function gadget:GetInfo()
	return {
		name = 'AA Targeting Priority',
		desc = '',
		author = 'Doo', --additions wilkubyk
		version = 'v1.0',
		date = 'May 2018',
		license = 'GNU GPL, v2 or later',
		layer = -1, --must run before game_initial_spawn, because game_initial_spawn must control the return of GameSteup
		enabled = true
	}
end

if gadgetHandler:IsSyncedCode() then

	local airCategories = {
		[UnitDefNames.armatlas.id] = "Vtols",
		[UnitDefNames.armca.id] = "Vtols",
		[UnitDefNames.armkam.id] = "Vtols",
		[UnitDefNames.armthund.id] = "Bombers",
		[UnitDefNames.armaca.id] = "Vtols",
		[UnitDefNames.armblade.id] = "Vtols",
		[UnitDefNames.armbrawl.id] = "Vtols",
		[UnitDefNames.armdfly.id] = "Vtols",
		[UnitDefNames.armlance.id] = "Bombers",
		[UnitDefNames.armliche.id] = "Bombers",
		[UnitDefNames.armpnix.id] = "Bombers",
		[UnitDefNames.armstil.id] = "Bombers",
		[UnitDefNames.armcsa.id] = "Vtols",
		[UnitDefNames.armsaber.id] = "Vtols",
		[UnitDefNames.armsb.id] = "Bombers",
		[UnitDefNames.armseap.id] = "Bombers",
		[UnitDefNames.corbw.id] = "Vtols",
		[UnitDefNames.corca.id] = "Vtols",
		[UnitDefNames.corvalk.id] = "Vtols",
		[UnitDefNames.corshad.id] = "Bombers",
		[UnitDefNames.coraca.id] = "Vtols",
		[UnitDefNames.corape.id] = "Vtols",
		[UnitDefNames.corcrw.id] = "Vtols",
		[UnitDefNames.corhurc.id] = "Bombers",
		[UnitDefNames.corseah.id] = "Vtols",
		[UnitDefNames.cortitan.id] = "Bombers",
		[UnitDefNames.corcsa.id] = "Vtols",
		[UnitDefNames.corcut.id] = "Vtols",
		[UnitDefNames.corsb.id] = "Bombers",
		[UnitDefNames.corseap.id] = "Bombers",
		[UnitDefNames.armfig.id] = "Fighters",
		[UnitDefNames.armhawk.id] = "Fighters",
		[UnitDefNames.armsfig.id] = "Fighters",
		[UnitDefNames.corveng.id] = "Fighters",
		[UnitDefNames.corvamp.id] = "Fighters",
		[UnitDefNames.corsfig.id] = "Fighters",
		[UnitDefNames.armpeep.id] = "Scouts",
		[UnitDefNames.armawac.id] = "Scouts",
		[UnitDefNames.armsehak.id] = "Scouts",
		[UnitDefNames.corfink.id] = "Scouts",
		[UnitDefNames.corawac.id] = "Scouts",
		[UnitDefNames.corhunt.id] = "Scouts",
	}
	for udid, ud in pairs(UnitDefs) do
		for unitname, category in pairs(airCategories) do
			if string.find(ud.name, unitname) then
				airCategories[udid] = category
			end
		end
	end

	local hasPriorityAir = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.customParams.prioritytarget and unitDef.customParams.prioritytarget == "air" then
			hasPriorityAir[unitDefID] = true
		end

		-- do Script.SetWatchWeapon so AllowWeaponTarget gets called
		for wid, weapon in ipairs(unitDef.weapons) do
			if weapon.onlyTargets then
				for category, _ in pairs(weapon.onlyTargets) do
					if category == 'vtol' then
						Script.SetWatchWeapon(weapon.weaponDef, true) -- watch weapon so AllowWeaponTarget works
					end
				end
			end
		end
	end

	local spSetUnitRulesParam = Spring.SetUnitRulesParam
	local spGetUnitRulesParam = Spring.GetUnitRulesParam

	function gadget:Initialize()
		for _, unitID in ipairs(Spring.GetAllUnits()) do
			local unitDefID = Spring.GetUnitDefID(unitID)
			gadget:UnitCreated(unitID, unitDefID)
		end
	end

	function gadget:UnitCreated(unitID, unitDefID)
		if hasPriorityAir[unitDefID] then
			spSetUnitRulesParam(unitID, "targetPriorityBombers", 1) -- so we got bombers only (t1&t2 and all torpedo)
			spSetUnitRulesParam(unitID, "targetPriorityVtols", 10) -- so we got the rest cons,all strafe etc but non bomber class
			spSetUnitRulesParam(unitID, "targetPriorityFighters", 20) -- so we got fighters only
			spSetUnitRulesParam(unitID, "targetPriorityScouts", 1000) -- no priortiy
		end
	end

	function gadget:AllowWeaponTarget(unitID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority)
		if targetID == -1 and attackerWeaponNum == -1 then
			return true, defPriority
		end
		local unitDefID = Spring.GetUnitDefID(targetID)
		if unitDefID then
			local priority = defPriority or 1.0
			if airCategories[unitDefID] and spGetUnitRulesParam(unitID, "targetPriorityFighters") then
				-- and spGetUnitRulesParam(unitID, "targetPriorityBombers") and spGetUnitRulesParam(unitID, "targetPriorityScouts"))
				priority = priority * spGetUnitRulesParam(unitID, ("targetPriority" .. airCategories[unitDefID]))
			end
			return true, priority
		end
	end
end
