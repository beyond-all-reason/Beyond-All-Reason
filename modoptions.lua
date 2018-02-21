--see engineoptions.lua for explanantion
local options={
	{
	   key    = "StartingResources",
	   name   = "Starting Resources",
	   desc   = "Sets storage and amount of resources that players will start with",
	   type   = "section",
	},
    {
       key="ba_modes",
       name="Balanced Annihilation - Game Modes",
       desc="Balanced Annihilation - Game Modes",
       type="section",
    },
    {
       key="ba_options",
       name="Balanced Annihilation - Options",
       desc="Balanced Annihilation - Options",
       type="section",
    },
	{
		key    = "barmodels",
		name   = "Remodelled units",
		desc   = "Activate BAR unit model integration",
		type   = "bool",
		section= 'ba_enhancements_misc',
		def = false,
	},
	{
		key="deathmode",
		name="Game End Mode",
		desc="What it takes to eliminate a team",
		type="list",
		def="com",
		section="ba_modes",
		items={
			{key="neverend", name="None", desc="Teams are never eliminated"},
			{key="com", name="Kill all enemy Commanders", desc="When a team has no Commanders left, it loses"},
			{key="killall", name="Kill everything", desc="Every last unit must be eliminated, no exceptions!"},
		}
	},
    {
        key    = 'mo_armageddontime',
        name   = 'Armageddon time (minutes)',
        desc   = 'At armageddon every immobile unit is destroyed and you fight to the death with what\'s left! (0=off)',
        type   = 'number',
        section= 'ba_modes',
        def    = 0,
        min    = 0,
        max    = 120,
        step   = 1,
    },
    {
		key    = "mo_ffa",
		name   = "FFA Mode",
		desc   = "Units with no player control are removed/destroyed \nUse FFA spawning mode",
		type   = "bool",
		def    = false,
		section= "ba_modes",
    },
	
	{
		key="mo_unba",
		name="Unbalanced Commanders",
		desc="Defines if commanders level up with xp and gain more power or not",
		type="list",
		def="disabled",
		section="ba_modes",
		items={
			{key="disabled", name="Disabled", desc="Disable Unbalanced Commanders"},
			{key="enabled", name="Enabled", desc="Enable Unbalanced Commanders"},
		}
	},	
	
	{
		key="seamex",
		name="Sea Metal Extractors",
		desc="Defines the use of either surface or underwater mexes",
		type="list",
		def="underwater",
		section="ba_modes",
		items={
			{key="underwater", name="Underwater", desc="Use underwater mexes"},
			{key="surface", name="Surface", desc="Use surface mexes"},
		}
	},	
	
	{
		key="map_terraintype",
		name="Map TerrainTypes",
		desc="Allows to cancel the TerrainType movespeed buffs of a map.",
		type="list",
		def="enabled",
		section="ba_options",
		items={
			{key="disabled", name="Disabled", desc="Disable TerrainTypes related MoveSpeed Buffs"},
			{key="enabled", name="Enabled", desc="Enable TerrainTypes related MoveSpeed Buffs"},
		}
	},	
	
	{
		key="map_waterlevel",
		name="Water Level",
		desc="-1 = Dry, 0 = Unchanged, 1-100 = Waterlevel in % of max height",
		type="number",
        def    = 0,
        min    = -1,
        max    = 100,
        step   = 1,
		section="ba_options",
	},	
	
	{
		key="map_tidal",
		name="Tidal Strength",
		desc="Unchanged = map setting, low = 13e/sec, medium = 18e/sec, high = 23e/sec.",
		type="list",
		def="unchanged",
		section="ba_options",
		items={
			{key="unchanged", name="Unchanged", desc="Use map settings"},
			{key="low", name="Low", desc="Set tidal incomes to 13 energy per second"},
			{key="medium", name="Medium", desc="Set tidal incomes to 18 energy per second"},
			{key="high", name="High", desc="Set tidal incomes to 23 energy per second"},
		}
	},
	
    {
        key    = 'mo_coop',
        name   = 'Cooperative mode',
        desc   = 'Adds extra commanders to id-sharing teams, 1 com per player',
        type   = 'bool',
        def    = false,
        section= 'ba_modes',
    },
    {
      key    = "shareddynamicalliancevictory",
      name   = "Dynamic Ally Victory",
      desc   = "Ingame alliance should count for game over condition.",
      type   = "bool",
	  section= 'ba_modes',
      def    = false,
    },
    {
		key    = "mo_preventcombomb",
		name   = "1v1 Mode (Prevent Combombs)",
		desc   = "Commanders survive DGuns and other commanders explosions",
		type   = "bool",
		def    = false,
		section= "ba_modes",
    },
    {
		key="mo_transportenemy",
		name="Enemy Transporting",
		desc="Toggle which enemy units you can kidnap with an air transport",
		type="list",
		def="notcoms",
		section="ba_options",
		items={
			{key="notcoms", name="All But Commanders", desc="Only commanders are immune to napping"},
			{key="none", name="Disallow All", desc="No enemy units can be napped"},
		}
	},
    {
        key    = "mo_enemycomcount",
        name   = "Enemy Com Counter",
        desc   = "Tells each team the total number of commanders alive in enemy teams",
        type   = "bool",
        def    = true,
        section= "ba_others",
    },
    {
        key    = 'FixedAllies',
        name   = 'Fixed ingame alliances',
        desc   = 'Disables the possibility of players to dynamically change alliances ingame',
        type   = 'bool',
        def    = true,
        section= "ba_others",
    },
    {
		key    = "mo_no_close_spawns",
		name   = "No close spawns",
		desc   = "Prevents players startpoints being placed close together (on large enough maps)",
		type   = "bool",
		def    = true,
		section= "ba_options",
    },
    {
        key    = "mo_heatmap",
        name   = "HeatMap",
        desc   = "Attemps to prevents unit paths to cross",
        type   = "bool",
        def    = true,
        section= "ba_options",
    },
    {
		key    = "mo_newbie_placer",
		name   = "Newbie Placer",
		desc   = "Chooses a startpoint and a random faction for all rank 1 accounts (online only)",
		type   = "bool",
		def    = false,
		section= "ba_options",
    },
	{
		key    = "critters",
		name   = 'Enable cute animals?',
		desc   = "On some maps critters will they wiggle and wubble around\nkey: critters",
		type   = "bool",
		def    = true,
		section= "ba_others",
	},
    {
        key    = 'critters_multiplier',
        name   = 'How many cute amimals?)',
        desc   = 'This multiplier will be applied on the amount of critters a map will end up with',
        type   = 'number',
        section= 'ba_others',
        def    = 0.5,
        min    = 0.2,
        max    = 2,
        step   = 0.2,
    },
	
    {
       key="ba_enhancements_misc",
       name="Balanced Annihilation - Gameplay Enhancements: Miscellaneous",
       desc="Balanced Annihilation - Gameplay Enhancements: Miscellaneous",
       type="section",
    },
	
    --{ 
		--key    = "logicalbuildtime",
		--name   = "Logical and meaningful buildtimes",
		--desc   = "Changes the default meaningless buildtimes to be in seconds, so that when a unit's buildtime is shown, that buildtime is representative of seconds taken to build that unit.",
		--type="list",
		--def="disabled",
		--section= "ba_enhancements_misc",
		--items={
		--	{key="disabled", name="Disabled", desc=""},
		--	{key="enabled", name="Enabled", desc="Changes the default meaningless buildtimes to be in seconds, so that when a unit's buildtime is shown, that buildtime is representative of seconds taken to build that unit."},
		--}
    --},

    {
        key    = "firethroughfriendly",
        name   = "Fire Through Friendly Units",
        desc   = "Causes weapons not to collide with nor avoid friendly units resulting in very TA style gameplay. Also fixes unit hitspheres. *Note* Balanced Annihilation is one of very few games that cause friendly units to block fire.",
        type="list",
        def="disabled",
        section= "ba_enhancements_misc",
        items={
            {key="disabled", name="Disabled", desc=""},
            {key="enabled", name="Enabled", desc="Causes weapons not to collide with nor avoid friendly units, resulting in very TA style gameplay and promotes unit/group micro."},
        }
    },

    {
        key    = "smallfeaturenoblock",
        name   = "Set small features to non-blocking status",
        desc   = "Small rocks/trees/unit wrecks will no longer block unit pathing",
        type="list",
        def="disabled",
        section= "ba_enhancements_misc",
        items={
            {key="disabled", name="Disabled", desc=""},
            {key="enabled", name="Enabled", desc="Small 2x2 rocks/trees/unit wrecks will no longer block unit pathing"},
        }
    },
	
-- Control Victory Options	
	{
		key    = 'controlvictoryoptions',
		name   = 'Control Victory Options',
		desc   = 'Allows you to control at a granular level the individual options for Control Point Victory',
		type   = 'section',
	},
	{
		key="scoremode",
		name="Scoring Mode (Control Victory Points)",
		desc="Defines how the game is played",
		type="list",
		def="disabled",
		section="controlvictoryoptions",
		items={
			{key="disabled", name="Disabled", desc="Disable Control Points as a victory condition."},
			{key="countdown", name="Countdown", desc="A Control Point decreases all opponents' scores, zero means defeat."},
			{key="tugofwar", name="Tug of War", desc="A Control Point steals enemy score, zero means defeat."},
			{key="domination", name="Domination", desc="Holding all Control Points will grant 1000 score, first to reach the score limit wins."},
		}
	},	
	{
		key    = 'limitscore',
		name   = 'Total Score',
		desc   = 'Total score amount available.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 3500,
		min    = 500,
		max    = 5000,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = "numberofcontrolpoints",
		name   = "Set number of Control Points on the map",
		desc   = "Sets the number of control points on the map and scales the total score amount to match. Has no effect if Preset map configs are enabled.",		
		section= "controlvictoryoptions",
		type="list",
		def="7",
		section= "controlvictoryoptions",
		items={
			{key="7", name="7", desc=""},
			{key="13", name="13", desc=""},
			{key="19", name="19", desc=""},
			{key="25", name="25", desc=""},
		}
    },
	{
		key    = "usemapconfig",
		name   = "Use preset map-specific Control Point locations?",
		desc   = "Should the control point config for this map be used instead of autogenerated control points?",		
		type="list",
		def="disabled",
		section= "controlvictoryoptions",
		items={
			{key="disabled", name="Disabled", desc="This will tell the game to use autogenerated control points."},
			{key="enabled", name="Enabled", desc="This will tell the game to use preset map control points (Set via map config)."},
		}
    },
	{
		key    = 'captureradius',
		name   = 'Capture Radius',
		desc   = 'Radius around a point in which to capture it.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 500,
		min    = 100,
		max    = 1000,
		step   = 25,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
		{
		key    = 'capturetime',
		name   = 'Capture Time',
		desc   = 'Time to capture a point.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 30,
		min    = 1,
		max    = 60,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
		{
		key    = 'capturebonus',
		name   = 'Capture Bonus',
		desc   = 'Percentage of how much faster capture takes place by adding more units.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 5,
		min    = 1,
		max    = 100,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
		{
		key    = 'decapspeed',
		name   = 'De-Cap Speed',
		desc   = 'Speed multiplier for neutralizing an enemy point.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 2,
		min    = 1,
		max    = 3,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
		{
		key    = 'starttime',
		name   = 'Start Time',
		desc   = 'The time when capturing can start.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 0,
		min    = 0,
		max    = 300,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
		{
		key    = 'metalperpoint',
		name   = 'Metal given to each player per captured point',
		desc   = 'Each player on an allyteam that has captured a point will receive this amount of resources per point captured per second',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 0,
		min    = 0,
		max    = 20,
		step   = 0.1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
		{
		key    = 'energyperpoint',
		name   = 'Energy given to each player per captured point',
		desc   = 'Each player on an allyteam that has captured a point will receive this amount of resources per point captured per second',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 0,
		min    = 0,
		max    = 20,
		step   = 0.1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
		{
		key    = 'dominationscoretime',
		name   = 'Domination Score Time',
		desc   = 'Time needed holding all points to score in multi domination.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 30,
		min    = 1,
		max    = 60,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
		{
		key    = 'tugofwarmodifier',
		name   = 'Tug of War Modifier',
		desc   = 'The amount of score transfered between opponents when points are captured is multiplied by this amount.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 2,
		min    = 0,
		max    = 6,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = 'dominationscore',
		name   = 'Score awarded for Domination',
		desc   = 'The amount of score awarded when you have scored a domination.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 1000,
		min    = 500,
		max    = 1000,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = 'comm_wreck_metal',
		name   = 'Commander Wreck Metal',
		desc   = 'Sets the amount of metal left by a destroyed Commander.',
		type   = 'number',
		section= 'ba_enhancements_misc',
		def    = 2500,
		min    = 0,
		max    = 5000,
		step   = 1,
	},
	{
		key    = 'reclaimunitefficiency',
		name   = 'Reclaim Unit Efficiency',
		desc   = 'Set how much metal a reclaimed unit should give back (1 = max, 0.5 = half)',
		type   = 'number',
		section= 'ba_enhancements_misc',
		def    = 1,
		min    = 0.5,
		max    = 1,
		step   = 0.05,
	},
	{
        key    = 'mm_diminish_factor',
        name   = 'Diminishing return rate of metal makers',
        desc   = 'The strength of diminishing returns from metal makers. 0 = off, 1 = very strong diminish effect.',
        type   = 'number',
        section= 'ba_enhancements_misc',
        def    = 0,
        min    = 0,
        max    = 1,
        step   = 0.05,
    },	
-- End Control Victory Options

-- Chicken Defense Options
	{
		key    = 'chicken_defense_options',
		name   = 'Chicken Defense Options',
		desc   = 'Various gameplay options that will change how the Chicken Defense is played.',
		type   = 'section',
	},
	{
		key="mo_chickenstart",
		name="Burrow Placement",
		desc="Control where burrows spawn",
		type="list",
		def="alwaysbox",
		section="chicken_defense_options",
		items={
			{key="anywhere", name="Anywhere", desc="Burrows can spawn anywhere"},
			{key="avoid", name="Avoid Players", desc="Burrows do not spawn on player units"},
			{key="initialbox", name="Initial Start Box", desc="First wave spawns in chicken start box, following burrows avoid players"},
			{key="alwaysbox", name="Always Start Box", desc="Burrows always spawn in chicken start box"},
		}
	},
	{
		key="mo_queendifficulty",
		name="Queen Difficulty",
		desc="How hard doth the Chicken Queen",
		type="list",
		def="n_chickenq",
		section="chicken_defense_options",
		items={
			{key="ve_chickenq", name="Very Easy", desc="Cakewalk"},
			{key="e_chickenq", name="Easy", desc="Somewhat Challenging"},
			{key="n_chickenq", name="Normal", desc="A Good Challenge"},
			{key="h_chickenq", name="Hard", desc="Serious Business"},
			{key="vh_chickenq", name="Very Hard", desc="Extreme Challenge"},
			{key="epic_chickenq", name="Epic!", desc="Impossible!"},
			{key="asc", name="Ascending", desc="Each difficulty after the next"},
		}
	},
	{
		key    = "mo_queentime",
		name   = "Max Queen Arrival (Minutes)",
		desc   = "Queen will spawn after given time.",
		type   = "number",
		def    = 40,
		min    = 1,
		max    = 90,
		step   = 1,
		section= "chicken_defense_options",
	},
	{
		key    = "mo_maxchicken",
		name   = "Chicken Limit",
		desc   = "Maximum number of chickens on map.",
		type   = "number",
		def    = 300,
		min    = 50,
		max    = 5000,
		step   = 25,
		section= "chicken_defense_options",
	},
	{
		key    = "mo_graceperiod",
		name   = "Grace Period (Seconds)",
		desc   = "Time before chickens become active.",
		type   = "number",
		def    = 300,
		min    = 5,
		max    = 900,
		step   = 5,
		section= "chicken_defense_options",
	},
	{
		key    = "mo_queenanger",
		name   = "Add Queen Anger",
		desc   = "Killing burrows adds to queen anger.",
		type   = "bool",
		def    = true,
		section= "chicken_defense_options",
    },
	
-- Chicken Defense Custom Difficulty Settings
	{
		key    = 'chicken_defense_custom_difficulty_settings',
		name   = 'Chicken Defense Custom Difficulty Settings',
		desc   = 'Use these settings to adjust the difficulty of Chicken Defense',
		type   = 'section',
	},
	{
		key    = "mo_custom_burrowspawn",
		name   = "Burrow Spawn Rate (Seconds)",
		desc   = "Time between burrow spawns.",
		type   = "number",
		def    = 120,
		min    = 1,
		max    = 600,
		step   = 1,
		section= "chicken_defense_custom_difficulty_settings",
	},
	{
		key    = "mo_custom_chickenspawn",
		name   = "Wave Spawn Rate (Seconds)",
		desc   = "Time between chicken waves.",
		type   = "number",
		def    = 90,
		min    = 10,
		max    = 600,
		step   = 1,
		section= "chicken_defense_custom_difficulty_settings",
	},
	{
		key    = "mo_custom_minchicken",
		name   = "Min Chickens Per Player",
		desc   = "Minimum Number of chickens before spawn chance kicks in",
		type   = "number",
		def    = 8,
		min    = 1,
		max    = 250,
		step   = 1,
		section= "chicken_defense_custom_difficulty_settings",
	},
	{
		key    = "mo_custom_spawnchance",
		name   = "Spawn Chance (Percent)",
		desc   = "Percent chance of each chicken spawn once greater thwn the min chickens per player limit",
		type   = "number",
		def    = 33,
		min    = 0,
		max    = 100,
		step   = 1,
		section= "chicken_defense_custom_difficulty_settings",
	},
	{
		key    = "mo_custom_angerbonus",
		name   = "Burrow Kill Anger (Percent)",
		desc   = "Seconds added per burrow kill.",
		type   = "number",
		def    = 0.15,
		min    = 0,
		max    = 100,
		step   = 0.01,
		section= "chicken_defense_custom_difficulty_settings",
	},
	{
		key    = "mo_custom_queenspawnmult",
		name   = "Queen Wave Size Mod",
		desc   = "Number of squads spawned by the queen at once.",
		type   = "number",
		def    = 1,
		min    = 0,
		max    = 5,
		step   = 1,
		section= "chicken_defense_custom_difficulty_settings",
	},
	{
		key    = "mo_custom_expstep",
		name   = "Bonus Experience",
		desc   = "Exp each chicken will receive by the end of the game",
		type   = "number",
		def    = 1.5,
		min    = 0,
		max    = 2.5,
		step   = 0.1,
		section= "chicken_defense_custom_difficulty_settings",
	},
	{
		key    = "mo_custom_lobberemp",
		name   = "Lobber EMP Duration",
		desc   = "Max duration of Lobber EMP artillery",
		type   = "number",
		def    = 4,
		min    = 0,
		max    = 30,
		step   = 0.5,
		section= "chicken_defense_custom_difficulty_settings",
	},
	{
		key    = "mo_custom_damagemod",
		name   = "Damage Mod",
		desc   = "Percent modifier for chicken damage",
		type   = "number",
		def    = 100,
		min    = 5,
		max    = 250,
		step   = 1,
		section= "chicken_defense_custom_difficulty_settings",
	},
-- End Chicken Defense Settings
}
return options
