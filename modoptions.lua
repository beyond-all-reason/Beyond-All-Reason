--  Custom Options Definition Table format
--  NOTES:
--  using an enumerated table lets you specify the options order
--
--  These keywords must be lowercase for LuaParser to read them.
--
--  key:      the string used in the script.txt
--  name:     the displayed name
--  desc:     the description (could be used as a tooltip)
--  hint:     greyed out text that appears in input field when empty
--  type:     the option type ('list','string','number','bool','subheader','separator')
--  def:      the default value
--  min:      minimum value for number options
--  max:      maximum value for number options
--  step:     quantization step, aligned to the def value
--  maxlen:   the maximum string length for string options
--  items:    array of item strings for list options
--  section:  so lobbies can order options in categories/panels
--  scope:    'all', 'player', 'team', 'allyteam'      <<< not supported yet >>>
--  collumn:  moves the option 1 row up if value is greater than the preivous row's one, default: 1
--         |  negative value forces new row, absolute value is used
--         |  zero moves to the left, 1 is default, 2 is half way to the right
--         |  recommened values: for 2 columns: 1 and 2, for 3 columns 1, 1.66, and 2.33
--
--  lock:     if type is bool: hides the table of keys when set to TRUE     <<< can not hide separators >>>
--      |     if type is list: add under each item what it should SHOW when set to
--  unlock:   if type is bool: hides the table of keys when set to FALSE    <<< can not hide separators >>>
--        |   if type is list: add under each item what it should HIDE when set to
--  bitmask:  int (1|2|4|8...etc), for when multiple options can hide an item

local options = {

    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Main + Restrictions
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    {
        key		= "options_main",
        name	= "Main",
        desc   	= "",
        type   	= "section",
        weight  = 7,
    },

    {
        key     = "sub_header",
        name    = "Options for changing base game settings.",
        desc    = "",
        section = "options_main",
        type    = "subheader",
        def     =  true,
    },

    {
        key     = "sub_header",
        section = "options_main",
        type    = "separator",
    },

    {
        key		= "ranked_game",
        name   	= "Ranked Game",
        desc   	= "Should game results affect OpenSkill. Note that games with AI or games that are not balanced are always unranked.",
        type   	= "bool",
        section	= "options_main",
        def    	= true,
    },


    {
        key    	= "allowuserwidgets",
        name   	= "Allow Custom Widgets",
        desc   	= "Allow custom user widgets or disallow them",
        type   	= "bool",
        def    	= true,
        section	= "options_main",
    },

    {
        key    	= "allowpausegameplay",
        name   	= "Allow Commands While Paused",
        desc   	= "Allow giving unit commands while paused",
        type   	= "bool",
        def    	= true,
        section	= "options_main",
    },

    {
        key     = "sub_header",
        section = "options_main",
        type    = "separator",
    },

    {
        key     = "sub_header",
        name    = "-- Gameplay Settings",
        desc    = "",
        section = "options_main",
        type    = "subheader",
        def     =  true,
    },

    {
        key    	= "maxunits",
        name   	= "Max Units Per Player",
        desc   	= "Keep in mind there is an absolute limit of units, 32000, divided between each team. If you set this value higher than possible it will force itself down to the maximum it can be.",
        type   	= "number",
        def    	= 2000,
        min    	= 500,
        max    	= 32000,
        step   	= 1,  -- quantization is aligned to the def value, (step <= 0) means that there is no quantization
        section	= "options_main",
    },

    {
        key		= "deathmode",
        name	= "Game End Mode",
        desc	= "What it takes to eliminate a team",
        type	= "list",
        def		= "com",
        section	= "options_main",
        items	= {
            { key= "neverend", 	name= "Never ending", 				desc="Teams are never eliminated"},
            { key= "com", 		name= "Kill all enemy Commanders", 	desc="When a team has no Commanders left, it loses"},
            { key= "builders", 	name= "Kill all Builders",			desc="When a team has no builders left, it loses" },
            { key= "killall", 	name= "Kill everything", 			desc="Every last unit must be eliminated, no exceptions!"},
            { key= "own_com", 	name= "Player resign on Com death", desc="When player commander dies, you auto-resign."},
        }
    },

    {
        key     = "draft_mode",
        name    = "Draft Spawn Order Mode",
        desc    = "Random/Captain/Skill/Fair based startPosType modes. Default: Random.",
        type    = "list",
        section = "options_main",
        def     = "random",
        items 	= {
            { key = "disabled", name = "Disabled",                      desc = "Disable draft mod. Fast-PC place first." },
            { key = "random",   name = "Random Order",                  desc = "Players get to pick a start position with a delay in a random order." },
            { key = "captain",  name = "Captains First",                desc = "Captain picks first, then everyone else in a random order." },
            { key = "skill",    name = "Skill Order",                   desc = "Skill-based order, instead of random." },
            { key = "fair",     name = "After full team has loaded",    desc = "Everyone must join the game first - after that (+2sec delay) everyone can place." }
        },
    },

    {
        key     = "teamcolors_anonymous_mode",
        name    = "Anonymous Mode",
        desc    = "Anonymize players by changing colors (based on chosen mode) and replacing names with question marks, making it harder to know who's who.",
        type    = "list",
        section = "options_main",
        def     = "disabled",
        items 	= {
            { key = "disabled", name = "Disabled" },
            { key = "global",   name = "Shuffle Globally",               desc = "You can distinguish different players and everyone sees the same colors globally. Diplomacy is the same as usual except using colors instead of names (e.g. \"Red, let's ally against Blue\")." },
            { key = "local",    name = "Shuffle Locally",                desc = "You can distinguish different players but everyone sees different colors locally. Diplomacy is harder but possible using positions (e.g. \"Southeast, let's ally against Northeast\")." },
            { key = "disco",    name = "Shuffle Locally (Continiously)", desc = "Same as local shuffle, except that colors are reshuffled every 2 mins for extra spicyness." },
            { key = "allred",   name = "Everyone Is Red",                desc = "You cannot distinguish different players, they all have the same color (red by default, can be changed in accessibility settings). Diplomacy is very hard." },
        },
    },

    {
        key		= "transportenemy",
        name	= "Enemy Transporting",
        desc	= "Toggle which enemy units you can kidnap with an air transport",
        hidden	= true,
        type	= "list",
        def		= "notcoms",
        section	= "options_main",
        items	= {
            { key= "notcoms", 	name= "All But Commanders", desc= "Only commanders are immune to napping" },
            { key= "none", 		name= "Disallow All", 		desc= "No enemy units can be napped" },
        }
    },

    {
        key     = "teamffa_start_boxes_shuffle",
        name    = "Shuffle TeamFFA Start Boxes",
        desc    = "In TeamFFA games (more than 2 teams, excluding Raptors / Scavengers), start boxes will be randomly assigned to each team: team 1 might be assigned any start box rather than team 1 always being assigned start box 1.",
        type    = "bool",
        section = "options_main",
        def     = true,
    },

    {
        key    	= "fixedallies",
        name   	= "Disabled Dynamic Alliances",
        desc   	= "Disables the possibility of players to dynamically change alliances ingame",
        type   	= "bool",
        def    	= true,
        hidden 	= true,
        section	= "options_main",
    },

    {
        key    	= "disablemapdamage",
        name   	= "Disable Map Deformation",
        desc   	= "Prevents the map shape from being changed by weapons",
        type   	= "bool",
        def    	= false,
        section	= "options_main",
    },

    {
        key    	= "disable_fogofwar",
        name   	= "Disable Fog of War",
        desc   	= "Disable Fog of War",
        type   	= "bool",
        section	= "options_main",
        def    	= false,
    },

    {
        key    	= "norushtimer",
        name   	= "No Rush Time".."\255\128\128\128".." [minutes]",
        desc   	= "Set timer in which players cannot get out of their startbox, so you have time to prepare before fighting.\n"..
			"PLEASE NOTE: For this to work, the game needs to have set startboxes.\n"..
			-- tabs don't do much in chobby
			"                          It won't work in FFA mode without boxes.\n"..
			"                          Also, it does not affect Scavengers and Raptors.",
        type   	= "number",
        section	= "options_main",
        def    	= 0,
        min    	= 0,
        max    	= 30,
        step   	= 1,
    },

	{
		key		= "sub_header",
		section	= "options_main",
		type	= "separator",
	},
	{
		key		= "sub_header",
		name	= "-- Sharing and Taxes",
		section	= "options_main",
		type	= "subheader",
		def		=  true,
	},
	{
		key		= "tax_resource_sharing_amount",
		name	= "Resource Sharing Tax",
		desc	=	"Taxes resource sharing".."\255\128\128\128".." and overflow (engine TODO:)\n"..
					"Set to [0] to turn off. Recommended: [0.4]. (Ranges: 0 - 0.99)",
		type	= "number",
		def		= 0,
		min		= 0,
		max		= 0.99,
		step	= 0.01,
		section	= "options_main",
		column	= 1,
	},
	{
		key		= "disable_unit_sharing",
		name	= "Disable Unit Sharing",
		desc	= "Disable sharing units and structures to allies",
		type	= "bool",
		section	= "options_main",
		def		= false,
	},
	{
		key		= "disable_assist_ally_construction",
		name	= "Disable Assist Ally Construction",
		desc	= "Disables assisting allied blueprints and labs.",
		type	= "bool",
		section	= "options_main",
		def		=  false,
		column	= 1.76,
	},
	{
		key		= "unit_market",
		name	= "Unit Market",
		desc	= "Allow players to trade units. (Select unit, press 'For Sale' in order window or say /sell_unit in chat to mark the unit for sale. Double-click to buy from allies. T2cons show up in shop window!)",
		type	= "bool",
		def		= false,
		section	= "options_main",
	},


    {
        key     = "sub_header",
        section = "options_main",
        type    = "separator",
    },

    {
        key     = "sub_header",
        name    = "-- Unit Restrictions",
        desc    = "",
        section = "options_main",
        type    = "subheader",
        def     =  true,
    },

	{
		key		= "unit_restrictions_notech15",
		name	= "Disable Tech 1.5",
		desc	= "Disables: Sea Plane Labs, Hovercraft labs, and Amphibious labs. (Considered Tier 1.5)",
		type	= "bool",
		section	= "options_main",
		def		= false,
		column	= 1,
	},

    {
        key    	= "unit_restrictions_notech2",
        name   	= "Disable Tech 2",
        desc   	= "Disable Tech 2",
        type   	= "bool",
        section	= "options_main",
        def    	= false,
        column  = 1.66,
    },

    {
        key    	= "unit_restrictions_notech3",
        name   	= "Disable Tech 3",
        desc   	= "Disable Tech 3",
        type   	= "bool",
        section	= "options_main",
        def    	= false,
        column  = 2.33,
    },

    {
        key    	= "unit_restrictions_noair",
        name   	= "Disable Air Units",
        desc   	= "Disable Air Units",
        type   	= "bool",
        section	= "options_main",
        def    	= false,
        column  = 1,
    },

	{
		key		= "unit_restrictions_nodefence",
		name	= "Disable Defences",
		desc	= "Disables Defensive Structures, apart from basic LLTs and basic AA",
		type	= "bool",
		section	= "options_main",
		def		= false,
		column	= 1.66,
	},

    {
        key    	= "unit_restrictions_noextractors",
        name   	= "Disable Metal Extractors",
        desc   	= "Disable Metal Extractors",
        type   	= "bool",
        section	= "options_main",
        def    	= false,
        column  = 1,
    },

    {
        key    	= "unit_restrictions_noconverters",
        name   	= "Disable Energy Converters",
        desc   	= "Disable Energy Converters",
        type   	= "bool",
        section	= "options_main",
        def    	= false,
        column  = 1.66,
    },

	{
		key		= "unit_restrictions_nofusion",
		name	= "Disable Fusion Generators",
		desc	= "Disables Normal and Advanced Fusion Energy Generators",
		type	= "bool",
		section	= "options_main",
		def		= false,
		column	= 2.33,
	},

    {
        key    	= "unit_restrictions_notacnukes",
        name   	= "Disable Tactical Missiles/EMPs",
        desc   	= "Disables Cortex Tactical Missile Launcher and Armada EMP Missile Launcher",
        type   	= "bool",
        section	= "options_main",
        def    	= false,
        column  = 1,
    },

    {
        key    	= "unit_restrictions_nonukes",
        name   	= "Disable Nuclear Missiles",
        desc   	= "Disable Nuclear Missiles",
        type   	= "bool",
        section	= "options_main",
        def    	= false,
        column  = 1.66,
    },

	{
		key		= "unit_restrictions_noantinuke",
		name	= "Disable Anti-Nuke Defence",
		desc	= "Disables Nuke Interceptor Units and Structures.",
		type	= "bool",
		section	= "options_main",
		def		= false,
		column	= 2.33,
	},

    {
        key    	= "unit_restrictions_nolrpc",
        name   	= "Disable Long Range Artilery (LRPC)",
        desc   	= "Disable Long Range Plasma Artilery (LRPC) structures",
        type   	= "bool",
        section	= "options_main",
        def    	= false,
        column  = 1,
    },

    {
        key    	= "unit_restrictions_noendgamelrpc",
        name   	= "Disable Endgame Artilery (LRPC)",
        desc   	= "Disable Endgame Long Range Plasma Artilery (LRPC) structures (AKA lolcannons)",
        type   	= "bool",
        section	= "options_main",
        def    	= false,
        column  = 1.66,
    },


    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Other Options
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    {
        key		= "options",
        name	= "Other",
        desc	= "Options",
        type	= "section",
    },

    {
        key		= "map_tidal",
        name	= "Tidal Strength",
        desc	= "Unchanged = map setting, low = 13e/sec, medium = 18e/sec, high = 23e/sec.",
        hidden 	= true,
        type	= "list",
        def		= "unchanged",
        section	= "options",
        items	= {
            { key = "unchanged", 	name = "Unchanged", desc = "Use map settings" },
            { key = "low", 			name = "Low", 		desc = "Set tidal incomes to 13 energy per second" },
            { key = "medium", 		name = "Medium", 	desc = "Set tidal incomes to 18 energy per second" },
            { key = "high", 		name = "High", 		desc = "Set tidal incomes to 23 energy per second" },
        }
    },

    {
        key		= "critters",
        name	= "Animal amount",
        desc	= "This multiplier will be applied on the amount of critters a map will end up with",
        hidden	= true,
        type	= "number",
        section	= "options",
        def		= 1,
        min		= 0,
        max		= 2,
        step	= 0.2,
    },

    {
        key		= "map_atmosphere",
        name	= "Map Atmosphere and Ambient Sounds",
        desc	= "",
        type	= "bool",
        def		= true,
        hidden	= true,
        section	= "options",
    },

    {
        key		= "ffa_wreckage",
        name	= "FFA Mode Wreckage",
        desc	= "Killed players will blow up but leave wreckages",
        hidden 	= true,
        type	= "bool",
        def		= false,
        section	= "options",
    },

    {
        key		= "coop",
        name	= "Cooperative mode",
        desc	= "Adds extra commanders to id-sharing teams, 1 com per player",
        type	= "bool",
        hidden 	= true,
        def		= false,
        section	= "options",
    },

    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Multiplier Options
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Raptors
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    {
        key 	= "raptor_defense_options",
        name 	= "Raptors",
        desc 	= "Various gameplay options that will change how the Raptor Defense is played.",
        type 	= "section",
        weight  = 4,
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
		key		= "sub_header",
		name	= "To Play Add a Raptors AI to the enemy Team: [Add AI], [RaptorsDefense AI]",
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
        desc	= "(Range: 1 - 20). Number of queens that will spawn.",
        type	= "number",
        def		= 1,
        min		= 1,
        max		= 20,
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


    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Scavengers
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    {
        key		= "scav_defense_options",
        name	= "Scavengers",
        desc	= "Gameplay options for Scavengers gamemode",
        type	= "section",
        weight  = 3,
    },

    {
        key     = "sub_header",
        name    = "Scavengers Gamemode Options.",
        desc    = "",
        section = "scav_defense_options",
        type    = "subheader",
        def     =  true,
    },

	{
		key		= "sub_header",
		name	= "To Play Add a Scavangers AI to the enemy Team: [Add AI], [ScavengersDefense AI]",
		desc	= "",
		section	= "scav_defense_options",
		type	= "subheader",
	},


    {
        key     = "sub_header",
        section = "scav_defense_options",
        type    = "separator",
    },

    {
        key		= "scav_difficulty",
        name	= "Base Difficulty",
        desc	= "Scavs difficulty",
        type	= "list",
        def		= "normal",
        section	= "scav_defense_options",
        items	= {
            { key = "veryeasy", name = "Very Easy", desc = "Very Easy" },
            { key = "easy", 	name = "Easy", 		desc = "Easy" },
            { key = "normal", 	name = "Normal", 	desc = "Normal" },
            { key = "hard", 	name = "Hard", 		desc = "Hard" },
            { key = "veryhard", name = "Very Hard", desc = "Very Hard" },
            { key = "epic", 	name = "Epic", 		desc = "Epic" },
        }
    },

    {
        key     = "sub_header",
        section = "scav_defense_options",
        type    = "separator",
    },

    {
        key		= "scav_scavstart",
        name	= "Spawn Beacons Placement",
        desc	= "Control where spawners appear",
        type	= "list",
        def		= "initialbox",
        section	= "scav_defense_options",
        items	= {
            { key = "avoid", 		name = "Spawn Anywhere", 	desc="Beacons avoid player units" },
            { key = "initialbox",	name = "Growing Spawn Box", desc="Beacons spawn in limited area that increases over time" },
            --{ key = "alwaysbox", 	name =  "Always Start Box", desc="Beacons always spawn in scav start box" },
        }
    },

    {
        key		= "scav_endless",
        name	= "Endless Mode",
        desc	= "When you kill the boss, the game doesn't end, but loops around at higher difficulty instead, infinitely.",
        type	= "bool",
        def		= false,
        section	= "scav_defense_options",
    },

    {
        key     = "sub_header",
        section = "scav_defense_options",
        type    = "separator",
    },

    {
        key     = "sub_header",
        name    = "-- Advanced Options, Change at your own risk.",
        desc    = "",
        section = "scav_defense_options",
        type    = "subheader",
        def     =  true,
    },

    {
        key		= "scav_bosstimemult",
        name	= "Boss Preparation Time Multiplier",
        desc	= "(Range: 0.1 - 2). How quickly Boss Anger goes from 0 to 100%.",
        type	= "number",
        def		= 1,
        min		= 0.1,
        max		= 2,
        step	= 0.1,
        section	= "scav_defense_options",
    },

    {
        key		= "scav_boss_count",
        name	= "Scavengers Boss Count",
        desc	= "(Range: 1 - 20). Number of bosses that will spawn.",
        type	= "number",
        def		= 1,
        min		= 1,
        max		= 20,
        step	= 1,
        section	= "scav_defense_options",
    },

    {
        key		= "scav_spawncountmult",
        name	= "Unit Spawn Per Wave Multiplier",
        desc	= "(Range: 1 - 5). How many times more scavs will spawn per wave.",
        type	= "number",
        def		= 1,
        min		= 1,
        max		= 5,
        step	= 1,
        section	= "scav_defense_options",
    },

    {
        key		= "scav_spawntimemult",
        name	= "Waves Amount Multiplier",
        desc	= "(Range: 1 - 5). How often new waves will spawn. Bigger Number = More Waves",
        type	= "number",
        def		= 1,
        min		= 1,
        max		= 5,
        step	= 0.1,
        section	= "scav_defense_options",
    },

    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Extra Options
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    {
        key		= "options_extra",
        name	= "Extras",
        desc	= "Extra options",
        type	= "section",
        weight  = 2,
    },


    {
        key     = "sub_header",
        name    = "Extra options for shaking up the gameplay or balancing. Not intended for ranked games.",
        desc    = "",
        section = "options_extra",
        type    = "subheader",
        def     =  true,
    },

    {
        key     = "sub_header",
        section = "options_extra",
        type    = "separator",
    },

    --{
    --	key    	= "xmas",
    --	name   	= "Holiday decorations",
    --	desc   	= "Various  holiday decorations",
    --	type   	= "bool",
    --	def    	= true,
    --	section	= "options_extra",
    --},

	-- {
	-- 	key		= "unithats",
	-- 	name	= "Unit Hats",
	-- 	desc	= "Unit Hats, for the current season",
	-- 	type	= "list",
	-- 	def		= "disabled",
	-- 	items	= {
	-- 		{ key = "disabled",	name = "Disabled" },
	-- 		{ key = "april", 	name = "Silly", 		desc = "An assortment of foolish and silly hats >:3" },
	-- 	},
	-- 	section	= "options_extra",
	-- },
	--{
	--	key		= "easter_egg_hunt",
	--	name	= "Easter Eggs Hunt",
	--	desc	= "Easter Eggs are spawned around the map! Time to go on an Easter Egg hunt! (5 metal 50 energy per)",
	--	type	= "bool",
	--	def		= false,
	--	section	= "options_extra",
	--},


    {
        key    	= "experimentalextraunits",
        name   	= "Extra Units Pack",
        desc   	= "Pack of units that didn't make it to the main game roster. Balanced for PvP",
        type   	= "bool",
        section = "options_extra",
        def  	= false,
    },
	
    {
        key    	= "scavunitsforplayers",
        name   	= "Scavengers Units Pack",
        desc   	= "Units made for Scavengers, mostly silly and unbalanced for PvP.",
        type   	= "bool",
        section = "options_extra",
        def  	= false,
    },

    {
        key     = "sub_header",
        section = "options_extra",
        type    = "separator",
    },


    {
        key 	= "map_waterlevel",
        name 	= "Water Level",
        desc 	= "Doesn't work if Map Deformation is disabled! <0 = Decrease water level, >0 = Increase water level",
        type 	= "number",
        def 	= 0,
        min 	= -10000,
        max 	= 10000,
        step 	= 1,
        section = "options_extra",
    },

    {
        key    	= "map_waterislava",
        name   	= "Water Is Lava",
        desc   	= "Turns water into Lava",
        type   	= "bool",
        def    	= false,
        section	= "options_extra",
        unlock  = {"map_lavatiderhythm", "map_lavatidemode", "map_lavahighlevel", "map_lavahighdwell", "map_lavalowlevel", "map_lavalowdwell","map_tweaklava"},
        lock    = {"sub_header_lava3", "sub_header_lava4"},
        bitmask = 1,
    },

    {
        key    	= "map_lavatiderhythm",
        name   	= "Lava Tides",
        desc   	= "Lava level periodicially cycles height when tides are present",
        type   	= "list",
        def    	= "default",
        section	= "options_extra",
        column	= 1,
        items	= {
            { key= "default", 	name= "Default", desc= "Map Settings",
                lock = 
                {"map_lavatidemode", "map_lavahighlevel", "map_lavahighdwell", "map_lavalowlevel", "map_lavalowdwell","map_tweaklava", "sub_header_lava3", "sub_header_lava4"},
                unlock =
                    { "sub_header_lava1", "sub_header_lava2"}},
            { key= "enabled",	name= "Enable/Override",desc= "Lava tides will use these settings over the map defaults",
                unlock = 
                {"map_lavatidemode", "map_lavahighlevel", "map_lavahighdwell", "map_lavalowlevel", "map_lavalowdwell","map_tweaklava", "sub_header_lava3", "sub_header_lava4"},
                lock =
                    { "sub_header_lava1", "sub_header_lava2"}},
            { key= "disabled",	name= "Disable",desc= "Lava will not have tides, even on maps that normally have it",
                lock = 
                {"map_lavatidemode", "map_lavahighlevel", "map_lavahighdwell", "map_lavalowlevel", "map_lavalowdwell","map_tweaklava", "sub_header_lava3", "sub_header_lava4"},
                unlock =
                    { "sub_header_lava1", "sub_header_lava2"}},
        },
        bitmask = 2,
    },

    {
        key     = "map_lavatidemode",
        name	= "Lava Tide Mode",
        desc	= "Toggle whether lava starts at high or low tide.",
        hidden	= false,
        type	= "list",
        def		= "lavastartlow",
        section	= "options_extra",
        items	= {
            { key= "lavastartlow", 	name= "Start Low", desc= "Lava starts at low tide" },
            { key= "lavastarthigh",	name= "Start High",desc= "Lava starts at high tide" },
        }
    },

    {
        key 	= "map_lavahighlevel",
        name 	= "Lava High Tide Level",
        desc 	= "Lava level at high tide",
        type 	= "number",
        def 	= 0,
        min 	= 0,
        max 	= 10000,
        step 	= 1,
        section = "options_extra",
        column	= 1,
    },

    {
        key 	= "map_lavahighdwell",
        name 	= "Lava High Tide Time",
        desc 	= "Time in seconds lava waits at high tide",
        type 	= "number",
        def 	= 60,
        min 	= 1,
        max 	= 30000,
        step 	= 1,
        section = "options_extra",
        column	= 2.0,
    },

    {
        key 	= "map_lavalowlevel",
        name 	= "Lava Low Tide Level",
        desc 	= "Lava level at low tide",
        type 	= "number",
        def 	= 0,
        min 	= 0,
        max 	= 10000,
        step 	= 1,
        section = "options_extra",
        column	= 1,
    },  

    {
        key 	= "map_lavalowdwell",
        name 	= "Lava Low Tide Time",
        desc 	= "Time in seconds lava waits at low tide",
        type 	= "number",
        def 	= 300,
        min 	= 1,
        max 	= 30000,
        step 	= 1,
        section = "options_extra",
        column	= 2.0,
    },

    {
        key 	= "map_tweaklava",
        name 	= "Advanced Tide Rhythm",
        desc 	= "Table with format {MapHeight (elmo), Rate (elmo/s), Dwell Time (s)}, e.g. {0, 6, 60},{100, 3, 20}",
        hidden 	= true,
        hint    = "{Lava Height, Rise/Fall Rate, Dwell Time}",
        type 	= "string",
        def 	= "",
        section = "options_extra",
    },

    { key = "sub_header_lava1", section = "options_extra", type    = "subheader", name = "",},
    { key = "sub_header_lava2", section = "options_extra", type    = "subheader", name = "",},
    { key = "sub_header_lava3", section = "options_extra", type    = "subheader", name = "",},
    { key = "sub_header_lava4", section = "options_extra", type    = "subheader", name = "",},
 
    
    {
        key     = "sub_header",
        section = "options_extra",
        type    = "separator",
    },

    {
        key 	= "ruins",
        name 	= "Ruins",
        desc 	= "Remains of the battles once fought",
        type 	= "list",
        def 	= "scav_only",
        section = "options_extra",
        items 	= {
            { key = "enabled", 		name = "Enabled", unlock = {"ruins_density", "ruins_only_t1"} },
            { key = "scav_only", 	name = "Enabled for Scavengers only", unlock = {"ruins_density", "ruins_only_t1"} },
            { key = "disabled", 	name = "Disabled", lock = {"ruins_density", "ruins_only_t1"} },
        }
    },

    {
        key 	= "ruins_density",
        name 	= "Ruins: Density",
        type 	= "list",
        def 	= "normal",
        section = "options_extra",
        items 	= {
            { key = "verydense", name = "Very Dense" },
            { key = "dense",     name = "Dense" },
            { key = "normal",    name = "Normal" },
            { key = "rare",     name = "Rare" },
            { key = "veryrare",  name = "Very Rare" },
        }
    },

    {
        key    	= "ruins_only_t1",
        name   	= "Ruins: Only Tech 1",
        type   	= "bool",
        def    	= false,
        section	= "options_extra",
    },

    {
        key   	= "ruins_civilian_disable",
        name   	= "Ruins: Disable Civilian (Not Implemented Yet)",
        type   	= "bool",
        def    	= false,
        section	= "options",
        hidden 	= true,
    },

    {
        key     = "sub_header",
        section = "options_extra",
        type    = "separator",
    },


    {
        key 	= "lootboxes",
        name 	= "Lootboxes",
        desc 	= "Random drops of valuable stuff.",
        type 	= "list",
        def 	= "scav_only",
        section = "options_extra",
        items 	= {
            { key = "enabled", 		name = "Enabled", unlock = {"lootboxes_density"} },
            { key = "scav_only", 	name = "Enabled for Scavengers only", unlock = {"lootboxes_density"} },
            { key = "disabled", 	name = "Disabled", lock = {"lootboxes_density"} },
        }
    },

    {
        key 	= "lootboxes_density",
        name 	= "Lootboxes: Density",
        type 	= "list",
        def 	= "normal",
        section = "options_extra",
        items 	= {
            { key = "normal", 	name = "Normal" },
            { key = "rare", 	name = "Rare" },
            { key = "veryrare", name = "Very Rare" },
        }
    },

    {
        key     = "sub_header",
        section = "options_extra",
        type    = "separator",
    },


    {
        key 	= "evocom",
        name 	= "Evolving Commanders",
        desc   	= "Commanders evolve, gaining new weapons and abilities.",
        type 	= "bool",
        def 	= false,
        section = "options_extra",
        bitmask = 1,
        unlock  = {"evocomlevelupmethod","evocomlevelcap","evocomxpmultiplier", "evocomleveluptime", "evocomlevelupmultiplier"},
        --lock    = {"buffer_fix"},
    },

    {
        key 	= "evocomlevelupmethod",
        name 	= "EvoCom: Leveling Method",
        desc   	= "Dynamic: Commanders evolve to keep up with the highest power player. Timed: Static Evolution Rate",
        type 	= "list",
        def 	= "dynamic",
        section = "options_extra",
        bitmask = 2,
        items 	= {
            { key = "dynamic", 	name = "Dynamic", lock = {"evocomleveluptime"}, unlock = {"evocomlevelupmultiplier"}},
            { key = "timed", name = "Timed", lock = {"evocomlevelupmultiplier"}, unlock = {"evocomleveluptime"}},
        }
    },


    {
        key    	= "evocomlevelupmultiplier",
        name   	= "EvoCom: Evolution Mult.",
        desc   	= "(Range 0.1x - 3x Multiplier) Adjusts the thresholds at which Dynamic evolutions occur",
        type   	= "number",
        section	= "options_extra",
        def    	= 1,
        min    	= 0.1,
        max    	= 3,
        step   	= 0.1,
    },

    {
        key    	= "evocomleveluptime",
        name   	= "EvoCom: Evolution Time ",
        desc   	= "(Range 0.1 - 20 Minutes) Rate at which commanders will evolve if Timed method is selected.",
        type   	= "number",
        section	= "options_extra",
        def    	= 5,
        min    	= 0.1,
        max    	= 20,
        step   	= 0.1,
    },

    {
        key    	= "evocomlevelcap",
        name   	= "EvoCom: Max Level",
        desc   	= "(Range 2 - 10) Changes the Evolving Commanders maximum level",
        type   	= "number",
        section	= "options_extra",
        def    	= 10,
        min    	= 2,
        max    	= 10,
        step   	= 1,
    },

    {
        key    	= "evocomxpmultiplier",
        name   	= "EvoCom: Commander XP Multiplier",
        desc   	= "(Range 0.1 - 10) Does not affect leveling! Changes the rate at which Evolving Commanders gain Experience.",
        type   	= "number",
        section	= "options_extra",
        def    	= 1,
        min    	= 0.1,
        max    	= 10,
        step   	= 0.1,
    },

    {
        key     = "sub_header",
        section = "options_extra",
        type    = "separator",
    },


    {
        key 	= "comrespawn",
        name 	= "Commander Respawning",
        desc   	= "Commanders can build one Effigy. The first one is free and given for you at the start. When the commander dies, the Effigy is sacrificed in its place.",
        type 	= "list",
        def 	= "evocom",
        section = "options_extra",
        items 	= {
            { key = "evocom", 	name = "Evolving Commanders Only" },
            { key = "all", name = "All Commanders" },
            { key = "disabled", name = "Disabled" },
        }
    },

    {
        key     = "sub_header",
        section = "options_extra",
        type    = "separator",
    },


    {
        key 	= "assistdronesenabled", -- TODO, turn this into booleam modoption
        name 	= "Commander Drones",
        type 	= "list",
        def 	= "disabled",
        section = "options_extra",
        items 	= {
            { key = "enabled", 	name = "Enabled", unlock = {"assistdronesbuildpowermultiplier", "assistdronescount", "assistdronesair"} },
            { key = "disabled", name = "Disabled", lock = {"assistdronesbuildpowermultiplier", "assistdronescount", "assistdronesair"} },
        }
    },

    {
        key    	= "assistdronesbuildpowermultiplier",
        name   	= "ComDrones: Buildpower Multiplier",
        desc   	= "(Range 0.5 - 5). How much buildpower commander drones should have",
        type   	= "number",
        section	= "options_extra",
        def    	= 1,
        min    	= 0.5,
        max    	= 5,
        step   	= 1,
    },

    {
        key    	= "assistdronescount",
        name   	= "ComDrones: Count",
        desc   	= "How many assist drones per commander should be spawned",
        type   	= "number",
        section	= "options_extra",
        def    	= 10,
        min    	= 1,
        max    	= 30,
        step   	= 1,
    },

    {
        key    	= "assistdronesair",
        name   	= "ComDrones: Use Air Drones",
        desc   	= "Switch between aircraft drones and amphibious vehicle drones.",
        type   	= "bool",
        def    	= true,
        section	= "options_extra",
    },

    {
        key     = "sub_header",
        section = "options_extra",
        type    = "separator",
    },


    {
        key 	= "commanderbuildersenabled", -- TODO, turn this into boolean modoption
        name 	= "Base Builder Turret",
        type 	= "list",
        def 	= "disabled",
        section = "options_extra",
        items 	= {
            { key = "enabled", 	name = "Enabled", unlock = {"commanderbuildersrange", "commanderbuildersbuildpower"} },
            { key = "disabled", name = "Disabled", lock = {"commanderbuildersrange", "commanderbuildersbuildpower"} },
        }
    },

    {
        key    	= "commanderbuildersrange",
        name   	= "Base Builder Turret: Range",
        desc   	= "(Range 500 - 2000).",
        type   	= "number",
        section	= "options_extra",
        def    	= 1000,
        min    	= 500,
        max    	= 2000,
        step   	= 1,
    },

    {
        key    	= "commanderbuildersbuildpower",
        name   	= "Base Builder Turret: Buildpower",
        desc   	= "(Range 100 - 1000).",
        type   	= "number",
        section	= "options_extra",
        def    	= 400,
        min    	= 100,
        max    	= 1000,
        step   	= 1,
    },


    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Experimental Options
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    {
        key		= "options_experimental",
        name	= "Experimental",
        desc	= "Experimental options",
        type	= "section",
        weight  = 1,
    },

    {
        key     = "sub_header",
        name    = "Options for testing various new and unfinished features. Not intended for ranked games.",
        desc    = "",
        section = "options_experimental",
        type    = "subheader",
        def     =  true,
    },

    {
        key     = "sub_header",
        name    = "When any of these options are changed, there is no guarantee they will work properly, especially when combined.",
        desc    = "",
        section = "options_experimental",
        type    = "subheader",
        def     =  true,
    },

    {
        key     = "sub_header",
        section = "options_experimental",
        type    = "separator",
    },

    {
        key    	= "experimentallegionfaction",
        name   	= "Legion Faction",
        desc   	= "3rd experimental faction",
        type   	= "bool",
        section = "options_experimental",
        def  	= false,
    },

    -- Hidden Tests
	
	{
        key   	= "splittiers",
        name   	= "Split T2",
        desc   	= "Splits T2 into two tiers moving experimental to T4.",
        type   	= "bool",
        section = "options_experimental",
        def  	= false,
        hidden 	= true,
	},
	
    {
        key    	= "shieldsrework",
        name   	= "Shields Rework v2.0",
        desc   	= "Shields block plasma. Overkill damage is absorbed. Shield is down for the duration required to recharge the overkill damage at normal energy cost.",
        type   	= "bool",
        hidden 	= false,
        section = "options_experimental",
        def  	= false,
    },

    {
        key 	= "lategame_rebalance",
        name 	= "Lategame Rebalance",
        desc 	= "T2 defenses and anti-air is weaker, giving more time for late T2 strategies to be effective.  Early T3 unit prices increased. Increased price of calamity/ragnarock by 20% so late T3 has more time to be effective.",
        type 	= "bool",
        section = "options_experimental",
        def 	= false,
        hidden 	= true,
    },

    {
        key 	= "air_rework",
        name 	= "Air Rework",
        desc 	= "Prototype version with more maneuverable, slower air units and more differentiation between them.",
        hidden 	= true,
        type 	= "bool",
        section = "options_experimental",
        def 	= false,
    },

    {
        key 	= "skyshift",
        name 	= "Skyshift: Air Rework",
        desc 	= "A complete overhaul of air units and mechanics",
        type 	= "bool",
        def 	= false,
        section = "options_experimental",
        hidden 	= true,
    },

    {
        key 	= "emprework",
        name 	= "EMP Rework",
        desc 	= "EMP is changed to slow units movement and firerate, before eventually stunning.",
        type 	= "bool",
        hidden 	= true,
        section = "options_experimental",

        def 	= false,
    },

    {
        key 	= "junorework",
        name 	= "Juno Rework",
        desc 	= "Juno stuns certain units (such as radars and jammers) rather than magically deleting them",
        type 	= "bool",
        hidden 	= true,
        section = "options_experimental",
        def 	= false,
    },

    {
        key   	= "releasecandidates",
        name   	= "Release Candidate Units",
        desc   	= "Adds additional units to the game which are being considered for mainline integration and are balanced, or in end tuning stages.  Currently adds Printer, Siegebreaker, Phantom (Core T2 veh), Shockwave (Arm T2 EMP Mex), and Drone Carriers for armada and cortex",
        type   	= "bool",
        hidden 	= true,
        section = "options_experimental",
        def  	= false,
    },

    {
        key 	= "proposed_unit_reworks",
        name 	= "Proposed Unit Reworks",
        desc 	= "Modoption used to test and balance unit reworks that are being considered for the base game.",
        type 	= "bool",
        --hidden 	= true,
        section = "options_experimental",
        def 	= false,
    },

    {
        key 	= "factory_costs",
        name 	= "Factory Costs Test Patch",
        desc 	= "Cheaper and more efficient factories, more expensive nanos, and slower to build higher-tech units. Experimental, not expected to be balanced by itself - a test to try how the game plays if each player is more able to afford their own T2 factory, while making assisting them less efficient.",
        type 	= "bool",
        --hidden 	= true,
        section = "options_experimental",
        def 	= false,
    },

    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Unused Options
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


    {
        key		= "modes",
        name	= "GameModes",
        desc	= "Game Modes",
        hidden 	= true,
        type	= "section",
    },


    {
        key    	= "shareddynamicalliancevictory",
        name   	= "Dynamic Ally Victory",
        desc   	= "Ingame alliance should count for game over condition.",
        hidden 	= true,
        type   	= "bool",
        section	= "options",
        def    	= false,
    },

    {
        key    	= "ai_incomemultiplier",
        name   	= "AI Income Multiplier",
        desc   	= "Multiplies AI resource income",
        hidden 	= true,
        type   	= "number",
        section	= "options",
        def    	= 1,
        min    	= 1,
        max    	= 10,
        step   	= 0.1,
    },


    {
        key     = "defaultdecals",
        name    = "Default Decals",
        desc    = "Use the default explosion decals instead of Decals GL4",
        section = "options_experimental",
        type    = "bool",
        def     =  true,
        hidden 	= true,
    },

    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- DEV mode only mod option otherwise hidden by chobby
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    {
        key		= "dev",
        name	= "_DEV",
        desc	= "tab that should be hidden by chobby",
        hidden 	= true,
        type	= "section",
    },
    {
        key    	= "teamcolors_icon_dev_mode",
        name   	= "Icon Dev Mode ",
        desc   	= "(Don't use in normal games) Forces teamcolors to be an specific one, for all teams",
        type   	= "list",
        section = "dev",
        def  	= "disabled",
        items 	= {
            { key = "disabled", 	name = "Disabled", 			desc = "description" },
            { key = "armblue", 		name = "Armada Blue", 		desc = "description" },
            { key = "corred", 		name = "Cortex Red", 		desc = "description" },
            { key = "scavpurp", 	name = "Scavenger Purple", 	desc = "description" },
            { key = "raptororange", name = "Raptor Orange", 	desc = "description" },
			{ key = "gaiagray", 	name = "Gaia Gray", 		desc = "description" },
			{ key = "leggren",		name = "Legion Green", 		desc = "description" },
        }
    },
    {
        key     = "debugcommands",
        name    = "Debug Commands",
        desc    = "A pipe separated list of commands to execute at [gameframe]:luarules fightertest|100:forcequit...", -- example: debugcommands=150:cheat 1|200:luarules fightertest|600:quitforce;
        section = "dev",
        type    = "string",
        def     = "",
    },
    {
        key     = "animationcleanup",
        name    = "Animation Cleanup",
        desc    = "Use animations from the BOSCleanup branch", -- example: debugcommands=150:cheat 1|200:luarules fightertest|600:quitforce;
        section = "dev",
        type    = "bool",
        def     =  false,
    },
    {
        key     = "pushresistant",
        name    = "Pushresistance",
        desc    = "Enable to do desync test by the use of pushresistance",
        section = "dev",
        type    = "bool",
        def     =  false,
    },
    {
        key     = "dummyboolfeelfreetotouch",
        name    = "dummy to hide the faction limiter",
        desc    = "This is a dummy to hide the faction limiter from the text field, it needs to exploit or work around some flaws to hide it...",
        section = "dev",
        type    = "bool",
        unlock  = {"dummyboolfeelfreetotouch", "factionlimiter"},
    },
    {
        key     = "factionlimiter",
        name    = "Faction Limiter:".."\255\255\191\76".." ON\n".."\255\125\125\125".."BITMASK",
        desc    = [[BITMASK to be used via custom ui, only visible when boss
Set to [0] To disable.
Otherwise: 0th, 1st and 2nd bit are armada, cortex and legion respectively.
Offset by 3 for each consecutive team.
If a team's bitmask is 0, All are Enabled.
Example: Armada VS Cortex VS Legion: 273 or 100 010 001 or 256 + 16 + 1]],
        section = "dev",
        type    = "number",
        def     =  0,
        min    	= 0,
        max    	= 16777215,-- math hard, 24 bit limitish?
        step   	= 1,
    },

    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Map Metadata options
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    --
    -- The modoptions below are intended to be set automatically by lobby/spads based on the selected
    -- map name. They are used for a dynamic map configuration where the configruation values are not
    -- tied to either game version or reside inside of the map file, allowing for independent distribution
    -- from the maps metadata source of truth: https://github.com/beyond-all-reason/maps-metadata
    {
        key     = "mapmetadata",
        name    = "MapMetadata",
        desc    = "mapmetadata tab that should be hidden by chobby, which would have ideally been achieved by just not listing it and the following options here in the first place, but then SPADS refuses to set the modoption",
        hidden  = true,
        type    = "section",
    },
    {
        key     = "sub_header",
        name    = "Hidden map metadata options that are supposed to be set automatically by lobby/spads based on the map name.",
        desc    = "",
        section = "mapmetadata",
        type    = "subheader",
        hidden  = true,
        def     = true,
    },
    {
        key     = "mapmetadata_startpos",
        name    = "Map Metadata: StartPos",
        desc    = "StartPos configuration. Format is: base64url(zlib(json))",
        hidden  = true,
        section = "mapmetadata",
        type    = "string",
        def     = "",
    },
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Cheats
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    {
        key		= "options_cheats",
        name	= "Cheats",
        desc   	= "Options that alter the game balance in unintended way, Use at your own risk.",
        type   	= "section",
        weight  = -1,
    },

    {
        key     = "sub_header",
        name    = "Warning: changing these options will alter the intended game experience and may have bad results. Proceed at your own risk!",
        desc    = "",
        section = "options_cheats",
        type    = "subheader",
        def     =  true,
    },

    {
        key     = "sub_header",
        name    = "When any of these options are changed, there is no guarantee they will work properly, especially when combined.",
        desc    = "",
        section = "options_cheats",
        type    = "subheader",
        def     =  true,
    },

    {
        key     = "sub_header",
        section = "options_cheats",
        type    = "separator",
    },

    {
        key     = "sub_header",
        name    = "-- AI Cheats",
        desc    = "",
        section = "options_cheats",
        type    = "subheader",
        def     =  true,
    },

    {
        key 	= "dynamiccheats",
        name 	= "Dynamic Cheats",
        desc   	= "Cheats marked as [Dynamic] react to the game state and are suspended when the opposition is losing",
        type 	= "bool",
        def 	= true,
        section = "options_cheats",
    },

    {
        key		= "nowasting",
        name	= "No Resource Wasting",
        desc	= "[Dynamic] Increases Buildpower for the affected team's builders and factories to prevent resource",
        type	= "list",
        def		= "default",
        section	= "options_cheats",
        items	= {
            { key= "default", 	name= "Default", 		desc="Disabled, unless other features use it"},
            { key= "disabled", 	name= "Disabled", 		desc="Disabled"},
            { key= "ai", 		name= "AI Only", 	    desc="All AI except Scavengers and Raptors"},
            { key= "all", 	    name= "All",			desc="AI and Player Teams both excluding Scavengers and Raptors" },
        }
    },

    {
        key     = "sub_header",
        section = "options_cheats",
        type    = "separator",
    },

    {
        key     = "sub_header",
        name    = "-- Starting Resources",
        desc    = "",
        section = "options_cheats",
        type    = "subheader",
        def     =  true,
    },

    {
        key		= "startmetal",
        name	= "Starting Metal",
        desc	= "(Range 0 - 10000). Determines amount of metal and metal storage that each player will start with",
        type	= "number",
        section	= "options_cheats",
        def		= 1000,
        min		= 0,
        max		= 10000,
        step	= 1,
    },

    {
        key		= "startmetalstorage",
        name	= "Starting Metal Storage",
        desc	= "(Range 1000 - 20000). Only works if it's higher than Starting metal. Determines amount of metal and metal storage that each player will start with",
        type	= "number",
        section	= "options_cheats",
        def		= 1000,
        min		= 1000,
        max		= 20000,
        step	= 1,
    },

    {
        key		= "startenergy",
        name	= "Starting Energy",
        desc	= "(Range 0 - 10000). Determines amount of energy and energy storage that each player will start with",
        type	= "number",
        section	= "options_cheats",
        def		= 1000,
        min		= 0,
        max		= 10000,
        step	= 1,
    },

    {
        key		= "startenergystorage",
        name	= "Starting Energy Storage",
        desc	= "(Range 1000 - 20000). Only works if it's higher than Starting energy. Determines amount of energy and energy storage that each player will start with",
        type	= "number",
        section	= "options_cheats",
        def		= 1000,
        min		= 1000,
        max		= 20000,
        step	= 1,
    },

    {
        key     = "sub_header",
        section = "options_cheats",
        type    = "separator",
    },

    {
        key     = "sub_header",
        name    = "-- Resource Multipliers",
        desc    = "",
        section = "options_cheats",
        type    = "subheader",
        def     =  true,
    },

    {
        key		= "multiplier_resourceincome",
        name	= "Overall Resource Income",
        desc	= "(Range 0.1 - 10). Stacks up with the three options below.",
        type	= "number",
        section = "options_cheats",
        def		= 1,
        min		= 0.1,
        max		= 10,
        step	= 0.1,
    },

    {
        key		= "multiplier_metalextraction",
        name	= "Metal Extraction ",
        desc	= "(Range 0.1 - 10).",
        type	= "number",
        section = "options_cheats",
        def		= 1,
        min		= 0.1,
        max		= 10,
        step	= 0.1,
    },

    {
        key		= "multiplier_energyconversion",
        name	= "Energy Conversion Efficiency",
        desc	= "(Range 0.1 - 2). lower means you get less metal per energy converted",
        type	= "number",
        section = "options_cheats",
        def		= 1,
        min		= 0.1,
        max		= 2,
        step	= 0.1,
    },

    {
        key 	= "multiplier_energyproduction",
        name 	= "Energy Production",
        desc 	= "(Range 0.1 - 10).",
        type 	= "number",
        section = "options_cheats",
        def 	= 1,
        min 	= 0.1,
        max 	= 10,
        step 	= 0.1,
    },

    {
        key     = "sub_header",
        section = "options_cheats",
        type    = "separator",
    },

    {
        key     = "cheatsdescription7",
        name    = "-- Unit Parameter Multipliers",
        desc    = "",
        section = "options_cheats",
        type    = "subheader",
        def     =  true,
    },

    {
        key		= "multiplier_maxvelocity",
        name	= "Unit Max Velocity",
        desc	= "(Range 0.1 - 10).",
        type	= "number",
        section = "options_cheats",
        def		= 1,
        min		= 0.1,
        max		= 10,
        step	= 0.1,
    },

    {
        key	= "multiplier_turnrate",
        name	= "Unit Turn Rate",
        desc	= "(Range 0.1 - 10).",
        type	= "number",
        section = "options_cheats",
        def		= 1,
        min		= 0.1,
        max		= 10,
        step	= 0.1,
    },

    {
        key		= "multiplier_builddistance",
        name	= "Build Range",
        desc	= "(Range 0.5 - 10).",
        type	= "number",
        section = "options_cheats",
        def		= 1,
        min		= 0.5,
        max		= 10,
        step	= 0.1,
    },

    {
        key		= "multiplier_buildpower",
        name	= "Build Power",
        desc	= "(Range 0.1 - 10).",
        type	= "number",
        section = "options_cheats",
        def		= 1,
        min		= 0.1,
        max		= 10,
        step	= 0.1,
    },

    {
        key		= "multiplier_losrange",
        name	= "Vision Range",
        desc	= "(Range 0.5 - 10).",
        type	= "number",
        section = "options_cheats",
        def		= 1,
        min		= 0.5,
        max		= 10,
        step	= 0.1,
    },

    {
        key		= "multiplier_radarrange",
        name	= "Radar And Sonar Range",
        desc	= "(Range 0.5 - 10).",
        type	= "number",
        section = "options_cheats",
        def		= 1,
        min		= 0.5,
        max		= 10,
        step	= 0.1,
    },

    {
        key		= "multiplier_weaponrange",
        name	= "Weapon Range",
        desc	= "(Range 0.5 - 10).",
        type	= "number",
        section = "options_cheats",
        def    	= 1,
        min    	= 0.5,
        max    	= 10,
        step   	= 0.1,
    },

    {
        key		= "multiplier_weapondamage",
        name	= "Weapon Damage",
        desc	= "(Range 0.1 - 10). Also affects unit death explosions.",
        type	= "number",
        section = "options_cheats",
        def		= 1,
        min		= 0.1,
        max		= 10,
        step	= 0.1,
    },

    {
        key		= "multiplier_shieldpower",
        name	= "Shield Power",
        desc	= "(Range 0.1 - 10)",
        type	= "number",
        section = "options_cheats",
        def		= 1,
        min		= 0.1,
        max		= 10,
        step	= 0.1,
    },

    {
        key     = "sub_header",
        section = "options_cheats",
        type    = "separator",
    },

    {
        key     = "cheatsdescription7",
        name    = "-- Other",
        desc    = "",
        section = "options_cheats",
        type    = "subheader",
        def     =  true,
    },

    {
        key    	= "experimentalshields",
        name   	= "Shield Type Override",
        desc   	= "Shield Type Override",
        type   	= "list",
        section = "options_cheats",
        def  	= "unchanged",
        hidden  = true,
        items	= {
            { key = "unchanged", 		name = "Unchanged", 			desc = "Unchanged" },
            { key = "absorbplasma", 	name = "Absorb Plasma", 		desc = "Collisions Disabled" },
            { key = "absorbeverything", name = "Absorb Everything", 	desc = "Collisions Enabled" },
            { key = "bounceeverything", name = "Deflect Everything", 	desc = "Collisions Enabled" },
        }
    },

    {
        key		= "tweakunits",
        name	= "Tweak Units",
        desc	= "For advanced users!!! A base64 encoded lua table of unit parameters to change.",
        hint    = "Input must be base64",
        section = "options_cheats",
        type    = "string",
        def     = "",
    },

    {
        key     = "tweakdefs",
        name    = "Tweak Defs",
        desc    = "For advanced users!!! A base64 encoded snippet of code that modifies game definitions.",
        hint    = "Input must be base64",
        section = "options_cheats",
        type    = "string",
        def     = "",
    },

    {
		key		= "forceallunits",
		name	= "Force Load All Units (Dev/Modding)",
		desc	= "Load all UnitDefs even if ais or options for them aren't enabled",
		section = "options_cheats",
		type	= "bool",
		def		= false,
	},

}
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- End Options
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

for i = 1, 9 do
    options[#options + 1] = {
        key     = "tweakunits" .. i,
        name    = "Tweak Units " .. i,
        desc    = "A base64 encoded lua table of unit parameters to change.",
        section = "options_extra",
        type    = "string",
        def     = "",
        hidden 	= true,
    }
end

for i = 1, 9 do
    options[#options + 1] = {
        key     = "tweakdefs" .. i,
        name    = "Tweak Defs " .. i,
        desc    = "A base64 encoded snippet of code that modifies game definitions.",
        section = "options_extra",
        type    = "string",
        def     = "",
        hidden = true,
    }
end

return options
