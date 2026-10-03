local TechEnums = VFS.Include("modules/tech/enums.lua")
local TransferEnums = VFS.Include("modules/transfer/enums.lua")

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
}
