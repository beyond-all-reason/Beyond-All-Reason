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

	local airCategories = {}
	local hasPriorityAir = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		local weapons = unitDef.weapons
		if unitDef.isAirUnit then
			airCategories[unitDefID] = "Scouts"
			if unitDef.isTransport then
				airCategories[unitDefID] = "Vtols"
			elseif unitDef.isBuilder then
				airCategories[unitDefID] = "Vtols"
			end
			for i = 1, #weapons do
				local weaponDef = WeaponDefs[weapons[i].weaponDef]
				if weaponDef.type == 'AircraftBomb' then
					airCategories[unitDefID] = "Bombers"
				elseif weapons[i].onlyTargets.vtol then
					airCategories[unitDefID] = "Fighters"
				else
					airCategories[unitDefID] = "Vtols"
				end
			end
		end

		for i = 1, #weapons do
			local weaponDef = WeaponDefs[weapons[i].weaponDef]
			if weapons[i].onlyTargets.vtol then
				hasPriorityAir[unitDefID] = true

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
