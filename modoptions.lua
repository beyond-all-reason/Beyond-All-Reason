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
        def    = 1,
        min    = 0.2,
        max    = 2,
        step   = 0.2,
    },
    
    {
		key    = "betterunitmovement",
		name   = "Advanced Unit Movement and Pathing",
		desc   = "Adds some presets to units that allow for better pathing and more agile movement",		
		type="list",
		def="disabled",
		section= "ba_options",
		items={
			{key="disabled", name="Disabled", desc=""},
			{key="enabled", name="Enabled", desc="Adds some presets to units that allow for better pathing and more agile movement"},
		}
    },
	
	{
		key    = "firethroughfriendly",
		name   = "Fire Through Friendly Units",
		desc   = "Causes weapons not to collide with nor avoid friendly units resulting in very TA style gameplay. *Note* Balanced Annihilation is one of very few games that cause friendly units to block fire.",		
		type="list",
		def="disabled",
		section= "ba_options",
		items={
			{key="disabled", name="Disabled", desc=""},
			{key="enabled", name="Enabled", desc="Causes weapons not to collide with nor avoid friendly units resulting in very TA style gameplay."},
		}
    },
	
	{
		key    = "fixedhitspheres",
		name   = "Fix unit hitspheres (Requires Fire Through Friendly Units Enabled)",
		desc   = "Fixes the wonky and inconsistent hitboxes used when units cannot fire through one another.",		
		type="list",
		def="disabled",
		section= "ba_options",
		items={
			{key="disabled", name="Disabled", desc=""},
			{key="enabled", name="Enabled", desc="Fixes the wonky and inconsistent hitboxes used when units cannot fire through one another."},
		}
    },
	
	{
		key    = "smallfeaturenoblock",
		name   = "Set small features to non-blocking status",
		desc   = "Small rocks/trees/unit wrecks will no longer block unit pathing",		
		type="list",
		def="disabled",
		section= "ba_options",
		items={
			{key="disabled", name="Disabled", desc=""},
			{key="enabled", name="Enabled", desc="Small rocks/trees/unit wrecks will no longer block unit pathing"},
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
		def    = 2500,
		min    = 500,
		max    = 5000,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
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
		desc   = 'How much faster capture takes place by adding more units.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 0.5,
		min    = 0,
		max    = 10,
		step   = 0.1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
		{
		key    = 'decapspeed',
		name   = 'De-Cap Speed',
		desc   = 'Speed multiplier for neutralizing an enemy point.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 3,
		min    = 0.1,
		max    = 10,
		step   = 0.1,  -- quantization is aligned to the def value
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
		def    = 5,
		min    = 0,
		max    = 20,
		step   = 1,  -- quantization is aligned to the def value
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
		step   = 1,  -- quantization is aligned to the def value
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
-- End Control Victory Options
}
return options
