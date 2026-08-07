--- Mod options owned by the modes module: the game axis. A match is exactly
--- one way of playing — standard multiplayer, a mission, a PvE flavor — so
--- there is exactly one selector, and it belongs to mode infrastructure, not
--- to any one flavor.
---
--- Flavor modules register themselves here: each appends its preset's key to
--- the selector's items in its own commit (SPADS and unitsync accept only
--- listed values; the lobby enriches items from modes/ discovery). A flavor's
--- own option section declares `mode_category = "game"` to say the game axis
--- governs it — the section keeps its dials, the axis owns the choice.

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
		def = "standard",
		items = {
			{ key = "standard", name = "Standard", desc = "An ordinary game: no scripted mission, no PvE swarm." },
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
		},
	},
}
