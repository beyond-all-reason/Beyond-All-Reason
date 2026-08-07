--- Mod options owned by the raptors module, merged into the game's
--- modoptions.lua by ModuleHandler.ModOptions (same entry format; the section
--- entry ships here too).
---
--- Every key, default, item and section weight below is EXACTLY what it was
--- when these lived in the root file. They are wire values: a lobby, a SPADS
--- config and every saved game setup address the raptors by these names, and
--- the module moving does not get to rename them.
---
--- The one addition is `mode_category`: the section hands its governance to
--- the game axis (modules/modes/modoptions.lua), whose game_mode selector is
--- where a lobby writes the choice. The panel is a whitelist — these dials
--- show exactly when the Raptors preset claims them, which it does. Nothing in the game reads the
--- selector: raptors activate on a RaptorsAI being present, which is what
--- keeps every existing lobby and startscript working.

local ModeEnums = VFS.Include("modules/context/mode_enums.lua")

return {
    {
        key 	= "raptor_defense_options",
        name 	= "Raptors",
        desc 	= "Various gameplay options that will change how the Raptor Defense is played.",
        type 	= "section",
        weight  = 4,
        mode_category = ModeEnums.ModeCategories.Game,
    },

    {
        key     = "sub_header",
        name    = "Raptors Gamemode Options.",
        desc    = "",
        section = "raptor_defense_options",
        type    = "subheader",
        def     =  true,
    },

    {
        key     = "raptors_dev_channel_link",
        name    = "Development Discussion",
        desc    = "Raptors development discussion.",
        section = "raptor_defense_options",
        type    = "link",
        link    = "https://discord.com/channels/549281623154229250/781097030692110346",
        width   = 275,
        column  = 1.65,
        linkheight = 325,
        linkwidth = 350,
    },

	{
		key		= "sub_header",
		name	= "To Play: pick the Raptors game mode, or add a RaptorsAI to the enemy team: [Add AI], [RaptorsDefense AI]",
		desc	= "",
		section	= "raptor_defense_options",
		type	= "subheader",
	},

    {
        key     = "sub_header",
        section = "raptor_defense_options",
        type    = "separator",
    },

    {
        key		= "raptor_difficulty",
        name	= "Base Difficulty",
        desc	= "Raptors difficulty",
        type	= "list",
        def		= "normal",
        section	= "raptor_defense_options",
        items	= {
            { key = "veryeasy", name = "Very Easy", desc="Very Easy" },
            { key = "easy", 	name = "Easy", 		desc="Easy" },
            { key = "normal", 	name = "Normal", 	desc="Normal" },
            { key = "hard", 	name = "Hard", 		desc="Hard" },
            { key = "veryhard", name = "Very Hard", desc="Very Hard" },
            { key = "epic", 	name = "Epic", 		desc="Epic" },
        }
    },

    {
        key     = "sub_header",
        section = "raptor_defense_options",
        type    = "separator",
    },

    {
        key		= "raptor_raptorstart",
        name	= "Hives Placement",
        desc	= "Control where hives spawn",
        type	= "list",
        def		= "initialbox",
        section	= "raptor_defense_options",
        items	= {
            { key = "avoid", 		name = "Spawn Anywhere", 	desc = "Hives avoid player units" },
            { key = "initialbox", 	name = "Growing Spawn Box", desc = "Hives spawn in limited area that increases over time" },
            { key = "alwaysbox", 	name = "Always Start Box", 	desc = "Hives always spawn in raptor start box" },
        }
    },

    {
        key		= "raptor_endless",
        name	= "Endless Mode",
        desc	= "When you kill the queen, the game doesn't end, but loops around at higher difficulty instead, infinitely.",
        type	= "bool",
        def		= false,
        section = "raptor_defense_options",
    },

    {
        key     = "sub_header",
        section = "raptor_defense_options",
        type    = "separator",
    },

    {
        key     = "sub_header",
        name    = "-- Advanced Options, Change at your own risk.",
        desc    = "",
        section = "raptor_defense_options",
        type    = "subheader",
        def     =  true,
    },

    {
        key		= "raptor_queentimemult",
        name	= "Queen Hatching Time Multiplier",
        desc	= "(Range: 0.1 - 2). How quickly Queen Hatch goes from 0 to 100%",
        type	= "number",
        def		= 1,
        min		= 0.1,
        max		= 2,
        step	= 0.1,
        section = "raptor_defense_options",
    },

    {
        key		= "raptor_queen_count",
        name	= "Raptor Queen Count",
        desc	= "(Range: 1 - 100). Number of queens that will spawn.",
        type	= "number",
        def		= 1,
        min		= 1,
        max		= 100,
        step	= 1,
        section	= "raptor_defense_options",
    },

    {
        key		= "raptor_spawncountmult",
        name	= "Unit Spawn Per Wave Multiplier",
        desc	= "(Range: 1 - 5). How many times more raptors will spawn per wave.",
        type	= "number",
        def		= 1,
        min		= 1,
        max		= 5,
        step	= 1,
        section	= "raptor_defense_options",
    },

    {
        key		= "raptor_firstwavesboost",
        name	= "First Waves Size Boost",
        desc	= "(Range: 1 - 10). Intended to use with heavily modified settings. Makes first waves larger, the bigger the number the larger they are. Cools down within first few waves.",
        type	= "number",
        def		= 1,
        min		= 1,
        max		= 10,
        step	= 1,
        section	= "raptor_defense_options",
    },

    {
        key		= "raptor_spawntimemult",
        name	= "Waves Amount Multiplier",
        desc	= "(Range: 1 - 5). How often new waves will spawn. Bigger Number = More Waves",
        type	= "number",
        def		= 1,
        min		= 1,
        max		= 5,
        step	= 0.1,
        section	= "raptor_defense_options",
    },

    {
        key		= "raptor_graceperiodmult",
        name	= "Grace Period Time Multiplier",
        desc	= "(Range: 0.1 - 3). Time before Raptors become active. ",
        type	= "number",
        def		= 1,
        min		= 0.1,
        max		= 3,
        step	= 0.1,
        section	= "raptor_defense_options",
    },
}
