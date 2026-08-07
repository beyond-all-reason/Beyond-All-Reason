--- Flavors append their preset key to the items in their own commit: SPADS and unitsync accept only listed values.

local ModeEnums = VFS.Include("modules/context/mode_enums.lua")

return {
	{
		key = ModeEnums.ModeCategories.Game,
		name = "Game",
		desc = "Which game this is: one choice, everything else follows from it.",
		type = "section",
		weight = 8,
	},

	{
		key = "game_mode",
		name = "Game Mode",
		desc = "How this match is played. Picking a mode sets everything the mode needs and locks what it depends on.",
		type = "list",
		section = ModeEnums.ModeCategories.Game,
		def = ModeEnums.Modes.Standard,
		items = {
			{
				key = ModeEnums.Modes.Standard,
				name = "Standard",
				desc = "An ordinary game: no scripted mission, no PvE swarm.",
			},
			{ key = "ffa", name = "FFA", desc = "Free for all: every player for themselves." },
			{ key = "team_ffa", name = "Team FFA", desc = "Several teams, every team for itself." },
			{
				key = "territorial_domination",
				name = "Territorial Domination",
				desc = "Teams earn points by capturing territory to stay in the game.",
			},
			{
				key = "scavengers",
				name = "Scavengers",
				desc = "Hold out against the scavenger swarm, then kill the boss.",
			},
			{ key = "raptors", name = "Raptors", desc = "Hold out against the raptor swarm, then kill the queen." },
			{
				key = "mission",
				name = "Mission",
				desc = "Run the chosen mission. The mission decides when it is won or lost, and every unit is loaded.",
			},
		},
	},
}
