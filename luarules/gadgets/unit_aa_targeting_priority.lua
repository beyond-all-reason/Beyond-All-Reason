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
	local spSetUnitDefAutoTargetPriority = Spring.SetUnitDefAutoTargetPriority
	local spSetWeaponAutoTargetPriorityEnabled = Spring.SetWeaponAutoTargetPriorityEnabled
	local stringFind = string.find

	local PRIORITY_BOMBERS = 0.1
	local PRIORITY_VTOLS = 1
	local PRIORITY_FIGHTERS = 2
	local PRIORITY_SCOUTS = 100

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

	-- Register the per-target-unitDef priority multiplier and opt-in the AA weapons that should
	-- apply it. The engine then multiplies target priority by these factors directly in C++
	-- (see Spring.SetUnitDefAutoTargetPriority), so no per-candidate AllowWeaponTarget Lua
	-- callout is needed — which is the whole point: that callout was O(weapons × candidates)
	-- and dominated furball CPU time.
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
			spSetUnitDefAutoTargetPriority(unitDefID, mult)
		end

		-- Opt vtol-targeting weapons into the engine-side priority table
		for i = 1, #weapons do
			local weapon = weapons[i]
			if weapon.slavedTo == 0 and hasAntiAirPriority(weapon) then
				spSetWeaponAutoTargetPriorityEnabled(weapon.weaponDef, true)
			end
		end
	end
end
