local VFS = VFS

local ConstructionEnums = VFS.Include("modules/construction/enums.lua")
local TechEnums = VFS.Include("modules/tech/enums.lua")
local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local TransferModeHelpers = VFS.Include("modules/transfer/mode_helpers.lua")

-- The unit categories a tier may add to what the base mode shares
local unitSharingCategoriesWithNoneAndAll = {
	{
		key = ConstructionEnums.UnitFilterCategory.None,
		name = "None",
		desc = "No additional unit sharing at this tech level",
	},
}
for _, item in ipairs(TransferModeHelpers.unitSharingCategories) do
	unitSharingCategoriesWithNoneAndAll[#unitSharingCategoriesWithNoneAndAll + 1] = item
end
unitSharingCategoriesWithNoneAndAll[#unitSharingCategoriesWithNoneAndAll + 1] = {
	key = ConstructionEnums.UnitFilterCategory.All,
	name = "All",
	desc = "All units",
}

return {
	{
		key = "sub_header",
		name = "-- Tech",
		type = "subheader",
		section = TransferEnums.ModeCategories.Transfer,
		def = true,
	},
	{
		key = TechEnums.ModOptions.TechBlocking,
		name = "Tech Blocking",
		desc = "Build Keystone buildings to accumulate tech points and unlock T2/T3 units.",
		type = "bool",
		section = TransferEnums.ModeCategories.Transfer,
		def = false,
	},
	{
		key = TechEnums.ModOptions.T2TechThreshold,
		name = "Keystones per Player for Tech 2",
		desc = "Keystones each player needs to unlock Tech 2. Multiplied by team size automatically.",
		type = "number",
		section = TransferEnums.ModeCategories.Transfer,
		def = 1,
		min = 0.5,
		max = 20,
		step = 0.5,
	},
	{
		key = TechEnums.ModOptions.T3TechThreshold,
		name = "Keystones per Player for Tech 3",
		desc = "Keystones each player needs to unlock Tech 3. Multiplied by team size automatically.",
		type = "number",
		section = TransferEnums.ModeCategories.Transfer,
		def = 1.5,
		min = 0.5,
		max = 20,
		step = 0.5,
	},
	{
		key = TechEnums.ModOptions.UnitSharingModeAtT2,
		name = "Unit Sharing activated by Tech 2",
		desc = "Unit sharing mode that activates when team reaches Tech 2 (requires Tech Blocking)",
		type = "list",
		section = TransferEnums.ModeCategories.Transfer,
		def = ConstructionEnums.UnitFilterCategory.None,
		items = unitSharingCategoriesWithNoneAndAll,
	},
	{
		key = TechEnums.ModOptions.UnitSharingModeAtT3,
		name = "Unit Sharing activated by Tech 3",
		desc = "Unit sharing mode that activates when team reaches Tech 3 (requires Tech Blocking)",
		type = "list",
		section = TransferEnums.ModeCategories.Transfer,
		def = ConstructionEnums.UnitFilterCategory.None,
		items = unitSharingCategoriesWithNoneAndAll,
	},
	{
		key = TechEnums.ModOptions.TaxResourceSharingAmountAtT2,
		name = "Tax Rate activated by Tech 2",
		desc = "Tax rate when team reaches Tech 2. -1 means no override. (requires Tech Blocking)",
		type = "number",
		section = TransferEnums.ModeCategories.Transfer,
		def = -1,
		min = -1,
		max = 1.0,
		step = 0.01,
	},
	{
		key = TechEnums.ModOptions.TaxResourceSharingAmountAtT3,
		name = "Tax Rate activated by Tech 3",
		desc = "Tax rate when team reaches Tech 3. -1 means no override. (requires Tech Blocking)",
		type = "number",
		section = TransferEnums.ModeCategories.Transfer,
		def = -1,
		min = -1,
		max = 1.0,
		step = 0.01,
	},
}
