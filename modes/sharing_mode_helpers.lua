local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")

local M = {}

--- Resolve a tech-level-varying modOption: _at_t3, then _at_t2, then baseKey.
function M.resolveByTechLevel(opts, baseKey, techLevel)
	if techLevel >= 3 then
		local v = opts[baseKey .. "_at_t3"]
		if v ~= nil and v ~= "" then return v end
	end
	if techLevel >= 2 then
		local v = opts[baseKey .. "_at_t2"]
		if v ~= nil and v ~= "" then return v end
	end
	return opts[baseKey]
end

M.unitSharingCategories = {
	{ key = ModeEnums.UnitCategory.Combat, name = "Combat", desc = "Combat units, commanders, and transports" },
	{ key = ModeEnums.UnitCategory.Buildings, name = "Buildings", desc = "Factories, resource, and utility buildings" },
	{ key = ModeEnums.UnitCategory.Constructors, name = "Constructors", desc = "Constructors and con turrets" },
	{ key = ModeEnums.UnitCategory.Resource, name = "Resource", desc = "Metal extractors and energy producers" },
	{ key = ModeEnums.UnitCategory.NonCombat, name = "Non-combat", desc = "Everything except combat units" },
}

M.unitSharingCategoriesWithAll = {}
for _, item in ipairs(M.unitSharingCategories) do
	M.unitSharingCategoriesWithAll[#M.unitSharingCategoriesWithAll + 1] = item
end
M.unitSharingCategoriesWithAll[#M.unitSharingCategoriesWithAll + 1] = {
	key = ModeEnums.UnitFilterCategory.All, name = "All", desc = "All units"
}

M.unitSharingCategoriesWithNone = {
	{ key = "", name = "None", desc = "Use the base unit sharing mode" },
}
for _, item in ipairs(M.unitSharingCategories) do
	M.unitSharingCategoriesWithNone[#M.unitSharingCategoriesWithNone + 1] = item
end

-- tech-level overrides (_at_t2 / _at_t3): None, All, plus individual categories.
M.unitSharingCategoriesWithNoneAndAll = {
	{ key = ModeEnums.UnitFilterCategory.None, name = "None", desc = "No additional unit sharing at this tech level" },
}
for _, item in ipairs(M.unitSharingCategories) do
	M.unitSharingCategoriesWithNoneAndAll[#M.unitSharingCategoriesWithNoneAndAll + 1] = item
end
M.unitSharingCategoriesWithNoneAndAll[#M.unitSharingCategoriesWithNoneAndAll + 1] = {
	key = ModeEnums.UnitFilterCategory.All, name = "All", desc = "All units"
}

-- None/All wording (not Disabled/Enabled) to match the tech-level selectors.
M.unitSharingModeItems = {
	{ key = ModeEnums.UnitFilterCategory.None, name = "None", desc = "No unit sharing allowed" },
	{ key = ModeEnums.UnitFilterCategory.All, name = "All", desc = "All unit sharing allowed" },
}
for _, item in ipairs(M.unitSharingCategories) do
	M.unitSharingModeItems[#M.unitSharingModeItems + 1] = item
end

return M
