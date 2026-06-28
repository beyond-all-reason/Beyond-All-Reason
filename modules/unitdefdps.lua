local math_floor = math.floor
local math_min = math.min
local math_max = math.max

local DEFAULT_WEAPON_GROUPS = { ["0"] = true, ["1"] = true }

local armorIndex

local function getArmorIndex()
	if not armorIndex then
		armorIndex = {}
		for ii = 1, #Game.armorTypes do
			armorIndex[Game.armorTypes[ii]] = ii
		end
	end
	return armorIndex
end

local function calculateLaserDPS(def, damage)
	local minIntensity = math_max(def.minIntensity, 0.5)
	local mindps = minIntensity * (damage * def.salvoSize / def.reload)
	local maxdps = damage * def.salvoSize / def.reload
	return mindps, maxdps
end

local function calculateWeaponDPS(def, damage)
	local reloadDPS = damage * (def.salvoSize * def.projectiles) / def.reload
	local stockpileDPS = damage * (def.salvoSize * def.projectiles) / (def.stockpile and def.stockpileTime / 30 or def.reload)
	return math_min(reloadDPS, stockpileDPS), math_max(reloadDPS, stockpileDPS)
end

local function calculateClusterDPS(unitDef, def, damage)
	local munition = unitDef.name .. '_' .. def.customParams.cluster_def
	local cmNumber = def.customParams.cluster_number
	local cmDamage = WeaponDefNames[munition].damages[0]

	local mainDps = (def.salvoSize * def.projectiles) / def.reload * damage
	local cmunDps = (def.salvoSize * def.projectiles) / def.reload * (cmNumber * cmDamage)
	return mainDps, mainDps + cmunDps
end

local function calculateAreaDPS(def, damage)
	local burst = def.salvoSize * def.projectiles
	local impactDps = damage * burst / def.reload
	local areaDps = def.customParams.area_onhit_damage
	local damageMax = math_max(impactDps + areaDps, areaDps * burst * def.customParams.area_onhit_time / def.reload)
	return impactDps, damageMax
end

local function addPrimaryDPS(state, minDPS, maxDPS)
	state.mindps = (state.mindps or 0) + minDPS
	state.maxdps = (state.maxdps or 0) + maxDPS
end

local function addSecondaryDPS(state, minDPS, maxDPS)
	state.maxdps = (state.maxdps or 0) + maxDPS
end

local function processWeapon(state, unitDef, weapons, weaponIndex, weaponDef, isPrimaryWeapon, armorTypes)
	local addDPS = isPrimaryWeapon and addPrimaryDPS or addSecondaryDPS

	if weaponDef.interceptor ~= 0 and weaponDef.coverageRange then
		return
	end

	if weaponDef.shieldRadius and weaponDef.shieldRadius > 0 then
		return
	end

	if unitDef.name == 'armamb' or unitDef.name == 'cortoast' then
		state.unitExempt = true
		if weaponIndex == 1 then
			addDPS(state, calculateWeaponDPS(weaponDef, weaponDef.damages[0]))
		end

	elseif
		unitDef.customParams.evocomlvl or
		unitDef.name == 'armcom' or
		unitDef.name == 'corcom' or
		unitDef.name == 'legcom' or
		unitDef.name == 'corkarg' or
		unitDef.name == 'armguard' or
		unitDef.name == 'corpun' or
		unitDef.name == 'legcluster' or
		unitDef.name == 'leglob' or
		unitDef.name == 'legnavyfrigate' or
		unitDef.name == 'armamb' or
		unitDef.name == 'cortoast' or
		unitDef.name == 'armvang'
	then
		state.unitExempt = true
		if weaponIndex == 1 then
			if weaponDef.type == "BeamLaser" then
				addDPS(state, calculateLaserDPS(weaponDef, weaponDef.damages[0]))
			elseif weaponDef.customParams.cluster then
				addDPS(state, calculateClusterDPS(unitDef, weaponDef, weaponDef.damages[0]))
			elseif weapons[weaponIndex].onlyTargets['vtol'] ~= nil then
				addDPS(state, calculateWeaponDPS(weaponDef, weaponDef.damages[armorTypes.vtol]))
			else
				addDPS(state, calculateWeaponDPS(weaponDef, weaponDef.damages[0]))
			end
		end

	elseif unitDef.name == 'corkorg' then
		state.unitExempt = true
		if weaponIndex == 1 then
			addDPS(state, calculateWeaponDPS(weaponDef, weaponDef.damages[0]))
		end
		if weaponIndex == 2 then
			addDPS(state, calculateLaserDPS(weaponDef, weaponDef.damages[0]))
		end
		if weaponIndex == 3 then
			addDPS(state, calculateWeaponDPS(weaponDef, weaponDef.damages[0]))
		end

	elseif weaponDef.customParams.area_onhit_damage and weaponDef.customParams.area_onhit_time then
		state.unitExempt = true
		addDPS(state, calculateAreaDPS(weaponDef, weaponDef.damages[0]))
	elseif weaponDef.customParams.cluster then
		state.unitExempt = true
		addDPS(state, calculateClusterDPS(unitDef, weaponDef, weaponDef.damages[0]))
	elseif weaponDef.customParams.speceffect == "split" then
		state.unitExempt = true
		local splitd = WeaponDefNames[weaponDef.customParams.speceffect_def].damages[0]
		local splitn = weaponDef.customParams.number or 1
		addDPS(state, calculateWeaponDPS(weaponDef, splitd * splitn))
	elseif weaponDef.customParams.spark_forkdamage then
		state.unitExempt = true
		addDPS(state, calculateWeaponDPS(weaponDef, weaponDef.damages[0]))
		local forkDamageRate = weaponDef.customParams.spark_forkdamage
		addSecondaryDPS(state, calculateWeaponDPS(weaponDef, weaponDef.damages[0] * forkDamageRate))
		if state.unitExempt and weaponDef.paralyzer then
			state.minemp = state.mindps
			state.maxemp = state.maxdps
			state.mindps = nil
			state.maxdps = nil
		end
	end

	if weaponDef.type == "BeamLaser" and not state.unitExempt then
		local defDmg
		if weapons[1].onlyTargets['vtol'] ~= nil then
			defDmg = weaponDef.damages[armorTypes.vtol]
		else
			defDmg = weaponDef.damages[0]
		end

		if weaponDef.paralyzer ~= true then
			if weaponDef.customParams then
				if weaponDef.customParams.sweepfire then
					state.maxdps = (weaponDef.damages[0] * weaponDef.customParams.sweepfire) / math_max(weaponDef.minIntensity, 0.5)
					state.mindps = weaponDef.damages[0] * weaponDef.customParams.sweepfire
				else
					addDPS(state, calculateLaserDPS(weaponDef, defDmg))
				end
			else
				addDPS(state, calculateLaserDPS(weaponDef, defDmg))
			end
		else
			local minIntensity = math_max(weaponDef.minIntensity, 0.5)
			local prevMinDps = state.minemp or 0
			local prevMaxDps = state.maxemp or 0
			local mindps = minIntensity * (weaponDef.damages[0] * weaponDef.salvoSize / weaponDef.reload)
			local maxdps = weaponDef.damages[0] * weaponDef.salvoSize / weaponDef.reload
			state.minemp = mindps + prevMinDps
			state.maxemp = maxdps + prevMaxDps
		end
	elseif weaponDef.paralyzer == true and unitDef.name ~= 'armthor' then
		local defDmg = weaponDef.damages[0]
		local emp = math_floor(defDmg * weaponDef.salvoSize / weaponDef.reload)
		state.minemp = emp
		state.maxemp = emp
	end

	if weaponDef.type ~= "BeamLaser" and weaponDef.paralyzer ~= true and not state.unitExempt then
		local defDmg
		if weapons[1].onlyTargets['vtol'] ~= nil then
			defDmg = weaponDef.damages[armorTypes.vtol]
		else
			defDmg = weaponDef.damages[0]
		end

		if defDmg > 0 then
			addDPS(state, calculateWeaponDPS(weaponDef, defDmg))
		end
	end
end

local function applyDeathExplosion(state, unitDef)
	if unitDef.customParams.unitgroup and unitDef.customParams.unitgroup == 'explo' and unitDef.deathExplosion and WeaponDefNames[unitDef.deathExplosion] then
		local weapon = WeaponDefs[WeaponDefNames[unitDef.deathExplosion].id]
		if weapon then
			local dmg = weapon.damages[Game.armorTypes["default"]]
			state.mindps = dmg
			state.maxdps = dmg
		end
	end
end

local function calculateUnitDefDPS(unitDef, showWeaponGroups)
	local armorTypes = getArmorIndex()
	local state = {
		mindps = nil,
		maxdps = nil,
		minemp = nil,
		maxemp = nil,
		unitExempt = false,
	}
	local weapons = unitDef.weapons
	local hasQualifyingWeapons = false

	for weaponIndex = 1, #weapons do
		local weaponDef = WeaponDefs[weapons[weaponIndex].weaponDef]
		if showWeaponGroups[weaponDef.customParams.weapons_group] and weaponDef.customParams.bogus ~= "1" then
			if not hasQualifyingWeapons then
				state.mindps = 0
				state.maxdps = 0
				hasQualifyingWeapons = true
			end
			processWeapon(
				state,
				unitDef,
				weapons,
				weaponIndex,
				weaponDef,
				weaponDef.customParams.weapons_role ~= "secondary",
				armorTypes
			)
		end
	end

	applyDeathExplosion(state, unitDef)
	return state
end

local function applyCarriedUnits(unitDefInfoTable)
	local mins = { "mindps", "minemp" }
	local maxs = { "maxdps", "maxemp" }
	for unitDefID, unitDef in pairs(UnitDefs) do
		local unitInfo = unitDefInfoTable[unitDefID]
		if unitInfo then
			for _, weapon in ipairs(unitDef.weapons) do
				local weaponDef = WeaponDefs[weapon.weaponDef]
				if weaponDef.customParams.carried_unit and UnitDefNames[weaponDef.customParams.carried_unit] then
					local droneCount = weaponDef.customParams.maxunits or 1
					local droneDef = UnitDefNames[weaponDef.customParams.carried_unit]
					local droneInfo = unitDefInfoTable[droneDef.id]

					if droneInfo then
						for _, key in ipairs(mins) do
							if droneInfo[key] then
								unitInfo[key] = (unitInfo[key] or 0)
							end
						end

						for _, key in ipairs(maxs) do
							if droneInfo[key] then
								unitInfo[key] = (unitInfo[key] or 0) + (droneInfo[key] * droneCount)
							end
						end
					end
				end
			end
		end
	end
end

local function floorValues(unitDefInfoTable)
	local summedKeys = { "mindps", "maxdps", "minemp", "maxemp" }
	for _, unitInfo in pairs(unitDefInfoTable) do
		for _, key in pairs(summedKeys) do
			if type(unitInfo[key]) == "number" then
				unitInfo[key] = math_floor(unitInfo[key])
			end
		end
	end
end

local UnitDefDPS = {}

UnitDefDPS.DEFAULT_WEAPON_GROUPS = DEFAULT_WEAPON_GROUPS

function UnitDefDPS.newState()
	return {
		mindps = nil,
		maxdps = nil,
		minemp = nil,
		maxemp = nil,
		unitExempt = false,
	}
end

function UnitDefDPS.processWeapon(state, unitDef, weapons, weaponIndex, weaponDef, isPrimaryWeapon)
	processWeapon(state, unitDef, weapons, weaponIndex, weaponDef, isPrimaryWeapon, getArmorIndex())
end

function UnitDefDPS.applyDeathExplosion(state, unitDef)
	applyDeathExplosion(state, unitDef)
end

function UnitDefDPS.applyCarriedUnits(unitDefInfoTable)
	applyCarriedUnits(unitDefInfoTable)
end

function UnitDefDPS.floorValues(unitDefInfoTable)
	floorValues(unitDefInfoTable)
end

function UnitDefDPS.calculateAll(showWeaponGroups)
	showWeaponGroups = showWeaponGroups or DEFAULT_WEAPON_GROUPS
	local results = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		results[unitDefID] = calculateUnitDefDPS(unitDef, showWeaponGroups)
	end
	applyCarriedUnits(results)
	floorValues(results)
	return results
end

function UnitDefDPS.getEffectiveDPS(unitDef, dpsState)
	return dpsState.maxdps or dpsState.mindps or 0
end

return UnitDefDPS
