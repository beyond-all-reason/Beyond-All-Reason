local ConstructionEnums = require("modules/construction/enums")
local ResourceTypes = require("gamedata/resource_types")

local UnitType = ConstructionEnums.UnitType
local Category = ConstructionEnums.UnitFilterCategory

local ALL = {
	UnitType.Combat,
	UnitType.Commander,
	UnitType.Constructor,
	UnitType.Factory,
	UnitType.Resource,
	UnitType.Utility,
}

local BY_CATEGORY = {
	[Category.None] = {},
	[Category.All] = ALL,
	[Category.Combat] = { UnitType.Combat, UnitType.Commander },
	[Category.Buildings] = { UnitType.Factory, UnitType.Resource, UnitType.Utility },
	[Category.Constructors] = { UnitType.Constructor },
	[Category.Resource] = { UnitType.Resource },
	[Category.NonCombat] = { UnitType.Constructor, UnitType.Factory, UnitType.Resource, UnitType.Utility },
}

local EMPTY = {}

local UnitCategories = {}

---@param category string a UnitFilterCategory value
---@return string[] unit types the category covers; empty for an unknown one
function UnitCategories.TypesFor(category)
	return BY_CATEGORY[category] or EMPTY
end

-- Which type a unit def is, read off the def: the one rule every category above is a list of.
local combatGroupBuilders = {
	corfast = true,
	armfark = true,
	armconsul = true,
}

---@param unitDef table Unit definition from UnitDefs
---@return string unitType One of ConstructionEnums.UnitType values
function UnitCategories.ClassifyUnitDef(unitDef)
	if UnitCategories.IsCommanderDef(unitDef) then
		return ConstructionEnums.UnitType.Commander
	end

	if
		UnitCategories.IsCombatUnitDef(unitDef)
		or UnitCategories.IsTransportDef(unitDef)
		or UnitCategories.IsCombatGroupBuilderDef(unitDef)
	then
		return ConstructionEnums.UnitType.Combat
	end

	if UnitCategories.IsConstructorDef(unitDef) then
		return ConstructionEnums.UnitType.Constructor
	end

	if UnitCategories.IsFactoryDef(unitDef) then
		return ConstructionEnums.UnitType.Factory
	end

	if UnitCategories.IsResourceUnitDef(unitDef) then
		return ConstructionEnums.UnitType.Resource
	end

	if UnitCategories.IsUtilityUnitDef(unitDef) then
		return ConstructionEnums.UnitType.Utility
	end

	return ConstructionEnums.UnitType.Combat
end

---@param unitDef table
---@return boolean
function UnitCategories.IsCommanderDef(unitDef)
	return unitDef.customParams and unitDef.customParams.iscommander ~= nil
end

---@param unitDef table
---@return boolean
function UnitCategories.IsTransportDef(unitDef)
	return unitDef.canFly == true and unitDef.transportCapacity ~= nil and unitDef.transportCapacity > 0
end

---@param unitDef table
---@return boolean
function UnitCategories.IsCombatGroupBuilderDef(unitDef)
	return unitDef.name ~= nil and combatGroupBuilders[unitDef.name] == true
end

---@param unitDef table
---@return boolean
function UnitCategories.IsConstructorDef(unitDef)
	if unitDef.isFactory then
		return false
	end
	return unitDef.isBuilder == true or unitDef.canAssist == true
end

---@param unitDef table
---@return boolean
function UnitCategories.IsMobileBuilderDef(unitDef)
	return unitDef ~= nil and unitDef.isBuilder == true and not unitDef.isImmobile and not unitDef.isFactory
end

---@param unitDef table
---@return boolean
function UnitCategories.IsFactoryDef(unitDef)
	return unitDef.isFactory == true
end

---@param unitDef table Unit definition from UnitDefs
---@return boolean isCombat True if the unit is combat-focused
function UnitCategories.IsCombatUnitDef(unitDef)
	if
		unitDef.customParams
		and (
			unitDef.customParams.unitgroup == "weapon"
			or unitDef.customParams.unitgroup == "aa"
			or unitDef.customParams.unitgroup == "sub"
			or unitDef.customParams.unitgroup == "weaponaa"
			or unitDef.customParams.unitgroup == "weaponsub"
			or unitDef.customParams.unitgroup == "emp"
			or unitDef.customParams.unitgroup == "nuke"
			or unitDef.customParams.unitgroup == "antinuke"
			or unitDef.customParams.unitgroup == "explo"
		)
	then
		return true
	end

	if unitDef.weapons and #unitDef.weapons > 0 then
		return true
	end

	return false
end

---@param unitDef table Unit definition from UnitDefs
---@return boolean
function UnitCategories.IsResourceUnitDef(unitDef)
	if
		unitDef.customParams
		and (
			unitDef.customParams.unitgroup == ResourceTypes.ENERGY
			or unitDef.customParams.unitgroup == ResourceTypes.METAL
		)
	then
		return true
	end

	return false
end

---@param unitDef table Unit definition from UnitDefs
---@return boolean
function UnitCategories.IsUtilityUnitDef(unitDef)
	if unitDef.customParams and unitDef.customParams.unitgroup == "util" then
		return true
	end

	return false
end

return UnitCategories
