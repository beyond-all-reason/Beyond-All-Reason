local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")

local M = {}

--- Resolve a modOption value that varies by tech level.
--- Checks _at_t3 then _at_t2 overrides before falling back to the base key.
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
	{ key = ModeEnums.UnitCategory.Combat, name = "Combat", desc = "Combat units" },
	{ key = ModeEnums.UnitCategory.CombatT2Cons, name = "Combat + T2 Constructors", desc = "Combat units and T2 constructors" },
	{ key = ModeEnums.UnitCategory.Production, name = "Production", desc = "Factories and constructors" },
	{ key = ModeEnums.UnitCategory.ProductionResource, name = "Production + Resource", desc = "Factories, constructors, metal extractors, and energy producers" },
	{ key = ModeEnums.UnitCategory.ProductionResourceUtility, name = "Production + Resource + Utility", desc = "Factories, constructors, resource and support buildings" },
	{ key = ModeEnums.UnitCategory.ProductionUtility, name = "Production + Utility", desc = "Factories, constructors, and support buildings" },
	{ key = ModeEnums.UnitCategory.Resource, name = "Resource", desc = "Metal extractors and energy producers" },
	{ key = ModeEnums.UnitCategory.T2Cons, name = "T2 Constructors", desc = "T2 constructor units" },
	{ key = ModeEnums.UnitCategory.Transport, name = "Transport", desc = "T1 air transports" },
	{ key = ModeEnums.UnitCategory.Utility, name = "Utility", desc = "Radar, storage, and support buildings" },
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

M.unitSharingModeItems = {
	{ key = ModeEnums.UnitFilterCategory.None, name = "Disabled", desc = "No unit sharing allowed" },
	{ key = ModeEnums.UnitFilterCategory.All, name = "Enabled", desc = "All unit sharing allowed" },
}
for _, item in ipairs(M.unitSharingCategories) do
	M.unitSharingModeItems[#M.unitSharingModeItems + 1] = item
end

return M
