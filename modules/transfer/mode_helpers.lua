local ConstructionEnums = VFS.Include("modules/construction/enums.lua")

local M = {}

M.unitSharingCategories = {
	{ key = ConstructionEnums.UnitCategory.Combat, name = "Combat", desc = "Combat units, commanders, and transports" },
	{
		key = ConstructionEnums.UnitCategory.Buildings,
		name = "Buildings",
		desc = "Factories, resource, and utility buildings",
	},
	{ key = ConstructionEnums.UnitCategory.Constructors, name = "Constructors", desc = "Constructors and con turrets" },
	{
		key = ConstructionEnums.UnitCategory.Resource,
		name = "Resource",
		desc = "Metal extractors and energy producers",
	},
	{ key = ConstructionEnums.UnitCategory.NonCombat, name = "Non-combat", desc = "Everything except combat units" },
}

M.unitSharingCategoriesWithAll = {}
for _, item in ipairs(M.unitSharingCategories) do
	M.unitSharingCategoriesWithAll[#M.unitSharingCategoriesWithAll + 1] = item
end
M.unitSharingCategoriesWithAll[#M.unitSharingCategoriesWithAll + 1] = {
	key = ConstructionEnums.UnitFilterCategory.All,
	name = "All",
	desc = "All units",
}

M.unitSharingCategoriesWithNone = {
	{ key = "", name = "None", desc = "Use the base unit sharing mode" },
}
for _, item in ipairs(M.unitSharingCategories) do
	M.unitSharingCategoriesWithNone[#M.unitSharingCategoriesWithNone + 1] = item
end

M.unitSharingCategoriesWithNoneAndAll = {
	{
		key = ConstructionEnums.UnitFilterCategory.None,
		name = "None",
		desc = "No additional unit sharing at this tech level",
	},
}
for _, item in ipairs(M.unitSharingCategories) do
	M.unitSharingCategoriesWithNoneAndAll[#M.unitSharingCategoriesWithNoneAndAll + 1] = item
end
M.unitSharingCategoriesWithNoneAndAll[#M.unitSharingCategoriesWithNoneAndAll + 1] = {
	key = ConstructionEnums.UnitFilterCategory.All,
	name = "All",
	desc = "All units",
}

-- None/All wording (not Disabled/Enabled) to match the tech-level selectors.
M.unitSharingModeItems = {
	{ key = ConstructionEnums.UnitFilterCategory.None, name = "None", desc = "No unit sharing allowed" },
	{ key = ConstructionEnums.UnitFilterCategory.All, name = "All", desc = "All unit sharing allowed" },
}
for _, item in ipairs(M.unitSharingCategories) do
	M.unitSharingModeItems[#M.unitSharingModeItems + 1] = item
end

return M
