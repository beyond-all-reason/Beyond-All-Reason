local gadget = gadget ---@type Gadget

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
	local spGetUnitDefID = Spring.GetUnitDefID
	local stringFind = string.find
	local targetPriority = {
		Bombers = 1,
		Vtols = 10,
		Fighters = 20,
		Scouts = 1000,
	}

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
				if weaponDef.type == 'AircraftBomb' or weaponDef.type == 'TorpedoLauncher' or stringFind(weaponDef.name, 'arm_pidr', 1, true) then
					airCategories[unitDefID] = "Bombers"
				elseif weapons[i].onlyTargets.vtol then
					airCategories[unitDefID] = "Fighters"
				else
					airCategories[unitDefID] = "Vtols"
				end
			end
		end

		for i = 1, #weapons do
			if weapons[i].onlyTargets.vtol then
				hasPriorityAir[unitDefID] = true

				-- do Script.SetWatchWeapon so AllowWeaponTarget gets called
				for wid, weapon in ipairs(unitDef.weapons) do
					if weapon.onlyTargets then
						for category, _ in pairs(weapon.onlyTargets) do
							if category == 'vtol' then
								Script.SetWatchAllowTarget(weapon.weaponDef, true) -- watch so AllowWeaponTarget works
							end
						end
					end
				end
			end
		end
	end

	local targetCheckStats = {} -- unitDefID : count
	function gadget:AllowWeaponTarget(unitID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority)
		if targetID == -1 and attackerWeaponNum == -1 then
			return true, defPriority
		end
		local unitDefID = spGetUnitDefID(targetID)
		if unitDefID then
			targetCheckStats[unitDefID] = (targetCheckStats[unitDefID] or 0) + 1
			local priority = defPriority or 1.0
			local airCategory = airCategories[unitDefID]
			if airCategory then
				if hasPriorityAir[spGetUnitDefID(unitID)] then
					priority = priority * targetPriority[airCategory]
				end
			end
			return true, priority
		end
	end
	function gadget:Shutdown()
		local totalChecks = 0 
		local totalunitDefs = 1
		for unitDefID, count in pairs(targetCheckStats) do
			totalChecks = totalChecks + count
			totalunitDefs = totalunitDefs + 1
		end
		-- Find outliers with more checks than average
		local averageChecks = totalChecks / totalunitDefs
		local resultStr = string.format("AA Targeting Priority Stats: total = %d, unitDefs = %d, average = %.2f; Above average:", totalChecks, totalunitDefs, averageChecks)
		for unitDefID, count in pairs(targetCheckStats) do
			if count > averageChecks then
				local unitDef = UnitDefs[unitDefID]
				resultStr = resultStr .. unitDef.name .. ": " .. tostring(count) .. ", "
			end
		end
		Spring.Echo(resultStr)
	end
end
