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

	local PRIORITY_BOMBERS = 1
	local PRIORITY_VTOLS = 10
	local PRIORITY_FIGHTERS = 20
	local PRIORITY_SCOUTS = 1000

	local isAirCategory = {
		vtol = true,
		mobile = true,
		nothover = true,
		notship = true,
		notsub = true,
	}

	local nonAntiAirTypes = {
		AircraftBomb    = true,
		Shield          = true,
		TorpedoLauncher = true,
	}

	local function hasAntiAirPriority(weapon)
		local weaponDef = WeaponDefs[weapon.weaponDef]
		if nonAntiAirTypes[weaponDef.type] or weaponDef.manualFire or weaponDef.range < 100 then
			return false
		end
		if not table.any(weapon.onlyTargets, function(v, k) return isAirCategory[k] end) then
			return false
		end
		if table.any(weapon.badTargets, function(v, k) return isAirCategory[k] end) then
			return false
		end
		local damages = weaponDef.damages
		if damages[Game.armorTypes.vtol] <= damages[Game.armorTypes.default] * 0.5 then
			return false
		end
		return true
	end

	-- Pre-compute direct unitDefID → priority multiplier for all air units
	local airPriorityMultiplier = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		local weapons = unitDef.weapons
		if unitDef.isAirUnit then
			local mult = PRIORITY_SCOUTS
			if unitDef.isTransport or unitDef.isBuilder then
				mult = PRIORITY_VTOLS
			else
				for i = 1, #weapons do
					local weaponDef = WeaponDefs[weapons[i].weaponDef]
					if weaponDef.type == 'AircraftBomb' or weaponDef.type == 'TorpedoLauncher' or stringFind(weaponDef.name, 'arm_pidr', 1, true) then
						mult = PRIORITY_BOMBERS
					elseif weapons[i].onlyTargets.vtol then
						mult = PRIORITY_FIGHTERS
					else
						mult = PRIORITY_VTOLS
					end
				end
			end
			airPriorityMultiplier[unitDefID] = mult
		end

		-- Set watch on vtol-targeting weapons so AllowWeaponTarget gets called
		for i = 1, #weapons do
			local weapon = weapons[i]
			if weapon.slavedTo == 0 and hasAntiAirPriority(weapon) then
				Script.SetWatchAllowTarget(weapon.weaponDef, true)
			end
		end
	end

	-- AllowWeaponTarget is only called for weapons with SetWatchAllowTarget (vtol-targeting),
	-- so the attacker always has AA priority — no need to check hasPriorityAir or call
	-- spGetUnitDefID on the attacker.
	function gadget:AllowWeaponTarget(unitID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority)
		local mult = airPriorityMultiplier[spGetUnitDefID(targetID)]
		if mult then
			return true, (defPriority or 1.0) * mult
		end
		return true, defPriority or 1.0
	end
end
