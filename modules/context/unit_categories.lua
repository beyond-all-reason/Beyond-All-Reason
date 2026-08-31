
local Enums = VFS.Include("modules/context/enums.lua")
local ModeEnums = VFS.Include("modules/context/mode_enums.lua")

local UnitType = Enums.UnitType
local Category = ModeEnums.UnitFilterCategory

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

return UnitCategories
