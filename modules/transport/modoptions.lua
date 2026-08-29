--- Keys, defaults and items are wire values a lobby, SPADS and saved setups address; they cannot be renamed.
local ModeEnums = VFS.Include("modules/context/mode_enums.lua")

return {
	{
		key = "transport",
		name = "Transport",
		desc = "What a transport may carry, and how it flies when it does",
		type = "section",
		weight = 5,
		mode_category = ModeEnums.ModeCategories.Game,
	},
	{
		key = ModeEnums.ModOptions.TransportEnemy,
		name = "Enemy Transporting",
		desc = "Which enemy units an air transport may pick up; your own units are always allowed",
		type = "list",
		def = ModeEnums.TransportEnemy.NotCommanders,
		section = "transport",
		items = {
			{
				key = ModeEnums.TransportEnemy.NotCommanders,
				name = "All But Commanders",
				desc = "Only commanders are immune to napping",
			},
			{ key = ModeEnums.TransportEnemy.None, name = "Disallow All", desc = "No enemy units can be napped" },
		},
	},
	{
		key = ModeEnums.ModOptions.CommanderTransportSlow,
		name = "Own Commander Slows Transport",
		desc = "A T2 transport carrying your own Commander flies at speed 120. Enemy commanders are governed by Enemy Transporting.",
		type = "bool",
		section = "transport",
		def = false,
	},
}
