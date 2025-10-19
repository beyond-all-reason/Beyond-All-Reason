local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")

local sharing = {}

---Classify a unit definition by type
---Each unit def resolves to exactly 1 category
---@param unitDef table Unit definition from UnitDefs
---@return string unitType One of SharedEnums.UnitType values
function sharing.classifyUnitDef(unitDef)
	-- Economic units include T2 constructors, so check economic first
	if sharing.isEconomicUnitDef(unitDef) then
		-- T2 constructors are a special subset of economic units
		if sharing.isT2ConstructorDef(unitDef) then
			return SharedEnums.UnitType.T2Constructor
		end
		return SharedEnums.UnitType.Economic
	end

	if sharing.isUtilityUnitDef(unitDef) then
		return SharedEnums.UnitType.Utility
	end

	if sharing.isCombatUnitDef(unitDef) then
		return SharedEnums.UnitType.Combat
	end

	-- Default to combat for unclassified units
	return SharedEnums.UnitType.Combat
end

---Check if a unit definition is a T2 constructor
---@param unitDef table Unit definition from UnitDefs
---@return boolean isT2Con True if the unit is a T2 constructor
function sharing.isT2ConstructorDef(unitDef)
	return not unitDef.isFactory
			and #(unitDef.buildOptions or {}) > 0
			and unitDef.customParams.techlevel == "2"
end

---Check if a unit definition is combat-oriented (weapons, defense, offense)
---@param unitDef table Unit definition from UnitDefs
---@return boolean isCombat True if the unit is combat-focused
function sharing.isCombatUnitDef(unitDef)
	if unitDef.customParams and (
				unitDef.customParams.unitgroup == "weapon" or
				unitDef.customParams.unitgroup == "aa" or
				unitDef.customParams.unitgroup == "sub" or
				unitDef.customParams.unitgroup == "weaponaa" or
				unitDef.customParams.unitgroup == "weaponsub" or
				unitDef.customParams.unitgroup == "emp" or
				unitDef.customParams.unitgroup == "nuke" or
				unitDef.customParams.unitgroup == "antinuke" or
				unitDef.customParams.unitgroup == "explo"
			) then
		return true
	end

	if unitDef.weapons and #unitDef.weapons > 0 then
		return true
	end

	return false
end

-- Economic units: builders, factories, assist units (construction-focused)
---@param unitDef table Unit definition from UnitDefs
---@return boolean isEconomic True if the unit is for construction/building
function sharing.isEconomicUnitDef(unitDef)
	if unitDef.canAssist or unitDef.isFactory or unitDef.builder then
		return true
	end

	return false
end

---Check if a unit definition is a utility building (resource generation, storage, etc.)
---@param unitDef table Unit definition from UnitDefs
---@return boolean isUtility True if the unit is a utility building
function sharing.isUtilityUnitDef(unitDef)
	-- Resource generation units: energy and metal producers/extractors
	if unitDef.customParams and (
				unitDef.customParams.unitgroup == SharedEnums.ResourceType.ENERGY or
				unitDef.customParams.unitgroup == SharedEnums.ResourceType.METAL
			) then
		return true
	end

	-- Utility buildings that support economy (not combat)
	if unitDef.customParams and unitDef.customParams.unitgroup == "util" then
		return true
	end

	return false
end

return sharing
