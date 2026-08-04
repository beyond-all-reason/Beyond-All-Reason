--- Every key, default, item and section weight is EXACTLY what it was in the root file: they are
--- wire values a lobby, SPADS and saved setups address the scavengers by; the move cannot rename them.

local ModeEnums = VFS.Include("modules/context/mode_enums.lua")

return {
	{
		key = "scav_defense_options",
		name = "Scavengers",
		desc = "Gameplay options for Scavengers gamemode",
		type = "section",
		weight = 3,
		mode_category = ModeEnums.ModeCategories.Game,
	},

	{
		key = "sub_header",
		name = "Scavengers Gamemode Options.",
		desc = "",
		section = "scav_defense_options",
		type = "subheader",
		def = true,
	},

	{
		key = "scavengers_dev_channel_link",
		name = "Development Discussion",
		desc = "Scavengers development discussion.",
		section = "scav_defense_options",
		type = "link",
		link = "https://discord.com/channels/549281623154229250/659550298653589504",
		width = 275,
		column = 1.65,
		linkheight = 325,
		linkwidth = 350,
	},

	{
		key = "sub_header",
		name = "To Play: pick the Scavengers game mode, or add a ScavengersAI to the enemy team: [Add AI], [ScavengersDefense AI]",
		desc = "",
		section = "scav_defense_options",
		type = "subheader",
	},

	{
		key = "sub_header",
		section = "scav_defense_options",
		type = "separator",
	},

	{
		key = "scav_difficulty",
		name = "Base Difficulty",
		desc = "Scavs difficulty",
		type = "list",
		def = "normal",
		section = "scav_defense_options",
		items = {
			{ key = "veryeasy", name = "Very Easy", desc = "Very Easy" },
			{ key = "easy", name = "Easy", desc = "Easy" },
			{ key = "normal", name = "Normal", desc = "Normal" },
			{ key = "hard", name = "Hard", desc = "Hard" },
			{ key = "veryhard", name = "Very Hard", desc = "Very Hard" },
			{ key = "epic", name = "Epic", desc = "Epic" },
		},
	},

	{
		key = "sub_header",
		section = "scav_defense_options",
		type = "separator",
	},

	{
		key = "scav_scavstart",
		name = "Spawn Beacons Placement",
		desc = "Control where spawners appear",
		type = "list",
		def = "initialbox",
		section = "scav_defense_options",
		items = {
			{ key = "avoid", name = "Spawn Anywhere", desc = "Beacons avoid player units" },
			{
				key = "initialbox",
				name = "Growing Spawn Box",
				desc = "Beacons spawn in limited area that increases over time",
			},
		},
	},

	{
		key = "scav_endless",
		name = "Endless Mode",
		desc = "When you kill the boss, the game doesn't end, but loops around at higher difficulty instead, infinitely.",
		type = "bool",
		def = false,
		section = "scav_defense_options",
	},

	{
		key = "sub_header",
		section = "scav_defense_options",
		type = "separator",
	},

	{
		key = "sub_header",
		name = "-- Advanced Options, Change at your own risk.",
		desc = "",
		section = "scav_defense_options",
		type = "subheader",
		def = true,
	},

	{
		key = "scav_bosstimemult",
		name = "Boss Preparation Time Multiplier",
		desc = "How quickly Boss Anger goes from 0 to 100%.",
		type = "number",
		def = 1,
		min = 0.1,
		max = 2,
		step = 0.1,
		section = "scav_defense_options",
	},

	{
		key = "scav_boss_count",
		name = "Scavengers Boss Count",
		desc = "Number of bosses that will spawn.",
		type = "number",
		def = 1,
		min = 1,
		max = 20,
		step = 1,
		section = "scav_defense_options",
	},

	{
		key = "scav_spawncountmult",
		name = "Unit Spawn Per Wave Multiplier",
		desc = "How many times more scavs will spawn per wave.",
		type = "number",
		def = 1,
		min = 1,
		max = 5,
		step = 1,
		section = "scav_defense_options",
	},

	{
		key = "scav_spawntimemult",
		name = "Waves Amount Multiplier",
		desc = "How often new waves will spawn. Bigger Number = More Waves",
		type = "number",
		def = 1,
		min = 1,
		max = 5,
		step = 0.1,
		section = "scav_defense_options",
	},

	{
		key = "scav_graceperiodmult",
		name = "Grace Period Time Multiplier",
		desc = "Time before Scavs become active.",
		type = "number",
		def = 1,
		min = 0.1,
		max = 3,
		step = 0.1,
		section = "scav_defense_options",
	},
}
