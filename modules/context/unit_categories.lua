--- Which unit types a mode category covers.
---
--- The mode grammar slices units by category — combat, buildings,
--- constructors, resource, non-combat — and every module that gates on one
--- needs the same answer. It lives here because it is vocabulary, not
--- mechanism: transfer asks it to decide what may change hands, construction
--- asks it to decide what may build, and neither owns the other.

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

-- Shared, never mutated: callers read these lists, they do not own them.
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
