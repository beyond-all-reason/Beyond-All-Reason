-- $Id: ModOptions.lua 4642 2009-05-22 05:32:36Z carrepairer $


--  Custom Options Definition Table format
--  NOTES:
--  - using an enumerated table lets you specify the options order

--
--  These keywords must be lowercase for LuaParser to read them.
--
--  key:      the string used in the script.txt
--  name:     the displayed name
--  desc:     the description (could be used as a tooltip)
--  type:     the option type ('list','string','number','bool')
--  def:      the default value
--  min:      minimum value for number options
--  max:      maximum value for number options
--  step:     quantization step, aligned to the def value
--  maxlen:   the maximum string length for string options
--  items:    array of item strings for list options
--  section:  so lobbies can order options in categories/panels
--  scope:    'all', 'player', 'team', 'allyteam'      <<< not supported yet >>>
--


local options={
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Resources
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	{
		key		= "resources_options",
		name	= "Resources",
		desc	= "Resources",
		type	= "section",
	},

	{
		key    = "startmetal",
		name   = "Starting metal",
		desc   = "Determines amount of metal and metal storage that each player will start with",
		type   = "number",
		section= "resources_options",
		def    = 1000,
		min    = 0,
		max    = 10000,
		step   = 1,
	},

	{
		key    = "startenergy",
		name   = "Starting energy",
		desc   = "Determines amount of energy and energy storage that each player will start with",
		type   = "number",
		section= "resources_options",
		def    = 1000,
		min    = 0,
		max    = 10000,
		step   = 1,
	},
	{
		key="map_tidal",
		name="Tidal Strength",
		desc="Unchanged = map setting, low = 13e/sec, medium = 18e/sec, high = 23e/sec.",
		hidden = true,
		type="list",
		def="unchanged",
		section="resources_options",
		items={
			{key="unchanged", name="Unchanged", desc="Use map settings"},
			{key="low", name="Low", desc="Set tidal incomes to 13 energy per second"},
			{key="medium", name="Medium", desc="Set tidal incomes to 18 energy per second"},
			{key="high", name="High", desc="Set tidal incomes to 23 energy per second"},
		}
	},

	{
		key    = 'resourceincomemultiplier',
		name   = 'Resource Income Multiplier',
		desc   = 'Resource Income Multiplier',
		type   =  "number",
		section = 'resources_options',
		def    = 1,
		min    = 0.01,
		max    = 100,
		step   = 0.01,
	},
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Restrictions
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	{
		key		= 'restrictions',
		name	= 'Restrictions',
		desc   	= '',
		type   	= 'section',
	},
	{
		key    = 'maxunits',
		name   = 'Max units',
		desc   = 'Maximum number of units (including buildings) for each team allowed at the same time',
		type   = 'number',
		def    = 2000,
		min    = 500,
		max    = 10000, --- engine caps at lower limit if more than 3 team are ingame
		step   = 1,  -- quantization is aligned to the def value, (step <= 0) means that there is no quantization
		section= "restrictions",
	},
	{
		key="transportenemy",
		name="Enemy Transporting",
		desc="Toggle which enemy units you can kidnap with an air transport",
		hidden = true,
		type="list",
		def="notcoms",
		section="restrictions",
		items={
			{key="notcoms", name="All But Commanders", desc="Only commanders are immune to napping"},
			{key="none", name="Disallow All", desc="No enemy units can be napped"},
		}
	},
	{
		key    		= "allowuserwidgets",
		name   		= "Allow custom widgets",
		desc   		= "Allow custom user widgets or disallow them",
		type   		= "bool",
		def    		= true,
		section		= 'restrictions',
	},
	{
		key    		= 'fixedallies',
		name   		= 'Disabled dynamic alliances',
		desc   		= 'Disables the possibility of players to dynamically change alliances ingame',
		type   		= 'bool',
		def    		= true,
		section		= "restrictions",
	},
	{
		key    		= 'norushmode',
		name   		= 'NoRush Mode',
		desc   		= 'Disallows moving out of your startbox area for a set amount of time',
		type   		= "bool",
		section		= 'restrictions',
		def    		= false,
	},
	{
		key    		= 'norushtime',
		name   		= 'NoRush Time',
		desc   		= 'After how many minutes NoRush protection disappears',
		type   		= "number",
		section 	= 'restrictions',
		def    		= 10,
		min    		= 1,
		max    		= 60,
		step   		= 1,
	},
	{
		key    		= 'disable_fogofwar',
		name   		= 'Disable Fog of War',
		desc   		= 'Disable Fog of War',
		type   		= "bool",
		section		= 'restrictions',
		def    		= false,
	},
	{
		key    		= 'unit_restrictions_notech2',
		name   		= 'Disable Tech 2',
		desc   		= 'Disable Tech 2',
		type   		= "bool",
		section		= 'restrictions',
		def    		= false,
	},
	{
		key    		= 'unit_restrictions_notech3',
		name   		= 'Disable Tech 3',
		desc   		= 'Disable Tech 3',
		type   		= "bool",
		section		= 'restrictions',
		def    		= false,
	},
	{
		key    		= 'unit_restrictions_noair',
		name   		= 'Disable Air Units',
		desc   		= 'Disable Air Units',
		type   		= "bool",
		section		= 'restrictions',
		def    		= false,
	},
	{
		key    		= 'unit_restrictions_noextractors',
		name   		= 'Disable Metal Extractors',
		desc   		= 'Disable Metal Extractors',
		type   		= "bool",
		section		= 'restrictions',
		def    		= false,
	},
	{
		key    		= 'unit_restrictions_noconverters',
		name   		= 'Disable Energy Converters',
		desc   		= 'Disable Energy Converters',
		type   		= "bool",
		section		= 'restrictions',
		def    		= false,
	},
	{
		key    		= 'unit_restrictions_nonukes',
		name   		= 'Disable Nuclear Missiles',
		desc   		= 'Disable Nuclear Missiles',
		type   		= "bool",
		section		= 'restrictions',
		def    		= false,
	},
	{
		key    		= 'unit_restrictions_notacnukes',
		name   		= 'Disable Tactical Nukes and EMPs',
		desc   		= 'Disable Tactical Nukes and EMPs',
		type   		= "bool",
		section		= 'restrictions',
		def    		= false,
	},
	{
		key    		= 'unit_restrictions_nolrpc',
		name   		= 'Disable Long Range Artilery (LRPC) structures',
		desc   		= 'Disable Long Range Artilery (LRPC) structures',
		type   		= "bool",
		section		= 'restrictions',
		def    		= false,
	},

	{
		key    = 'map_restrictions_shrinknorth',
		name   = 'Map Shrink Percentage North',
		desc   = 'Set a percentage of map area to cut from playable area from the north',
		type   = 'number',
		def    = 0,
		min    = 0,
		max    = 100,
		step   = 1,
		section= "restrictions",
	},
	{
		key    = 'map_restrictions_shrinksouth',
		name   = 'Map Shrink Percentage South',
		desc   = 'Set a percentage of map area to cut from playable area from the south',
		type   = 'number',
		def    = 0,
		min    = 0,
		max    = 100,
		step   = 1,
		section= "restrictions",
	},
	{
		key    = 'map_restrictions_shrinkwest',
		name   = 'Map Shrink Percentage West',
		desc   = 'Set a percentage of map area to cut from playable area from the west',
		type   = 'number',
		def    = 0,
		min    = 0,
		max    = 100,
		step   = 1,
		section= "restrictions",
	},
	{
		key    = 'map_restrictions_shrinkeast',
		name   = 'Map Shrink Percentage East',
		desc   = 'Set a percentage of map area to cut from playable area from the east',
		type   = 'number',
		def    = 0,
		min    = 0,
		max    = 100,
		step   = 1,
		section= "restrictions",
	},
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Scavengers
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	{
		key		= "options_scavengers",
		name	= "Scavengers",
		desc	= "Gameplay options for Scavengers gamemode",
		type	= "section",
	},
	{
		key    = 'scavdifficulty',
		name   = 'Base Difficulty',
		desc   = 'Scavengers Base Difficulty Level',
		type   = 'list',
		section = 'options_scavengers',
		def  = "veryeasy",
		items={
			{key="noob", name="Noob", desc="Noob"},
			{key="veryeasy", name="Very Easy", desc="Very Easy"},
			{key="easy", name="Easy", desc="Easy"},
			{key="medium", name="Medium", desc="Medium"},
			{key="hard", name="Hard", desc="Hard"},
			{key="veryhard", name="Very Hard", desc="Very Hard"},
			{key="expert", name="Expert", desc="Expert"},
			{key="brutal", name="Brutal", desc="You'll die"},
		}
	},
	{
		key    = 'scavgraceperiod',
		name   = 'Grace Period',
		desc   = 'Time before Scavengers start sending attacks (in minutes).',
		type   = 'number',
		section= 'options_scavengers',
		def    = 5,
		min    = 1,
		max    = 20,
		step   = 1,
	},
	{
		key    = 'scavmaxtechlevel',
		name   = 'Maximum Scavengers Tech Level',
		desc   = 'Caps Scav tech level at specific point.',
		type   = 'list',
		section = 'options_scavengers',
		def  = "tech4",
		items={
			{key="tech4", name="Tech 4", desc="Tech 4"},
			{key="tech3", name="Tech 3", desc="Tech 3"},
			{key="tech2", name="Tech 2", desc="Tech 2"},
			{key="tech1", name="Tech 1", desc="Tech 1"},
		}
	},
	{
		key    = 'scavendless',
		name   = 'Endless Mode',
		desc   = 'Disables final boss fight, turning Scavengers into an endless survival mode',
		type   = 'bool',
		section = 'options_scavengers',
		def  = false,
	},
	{
		key    = 'scavtechcurve',
		name   = 'Game Lenght Multiplier',
		desc   = 'Higher than 1 - Longer, Lower than 1 - Shorter',
		type   = 'number',
		section= 'options_scavengers',
		def    = 1,
		min    = 0.01,
		max    = 10,
		step   = 0.01,
	},
	{
		key    = 'scavbosshealth',
		name   = 'Final Boss Health Multiplier',
		--desc   = '',
		type   = 'number',
		section= 'options_scavengers',
		hidden = true,
		def    = 1,
		min    = 0.01,
		max    = 10,
		step   = 0.01,
	},
	{
		key    = 'scavevents',
		name   = 'Random Events',
		desc   = 'Random Events System',
		type   = 'bool',
		section = 'options_scavengers',
		def  = true,
	},
	{
		key    = 'scaveventsamount',
		name   = 'Random Events Amount',
		desc   = 'Modifies frequency of random events',
		type   = 'list',
		section = 'options_scavengers',
		def  = "normal",
		items={
			{key="normal", name="Normal", desc="Normal"},
			{key="lower", name="Lower", desc="Halved"},
			{key="higher", name="Higher", desc="Doubled"},
		}
	},
	{
		key    = 'scavconstructors',
		name   = 'Scavenger Commanders',
		desc   = "When disabled, Scavengers won't build bases but will spawn more unit waves to balance it out.",
		type   = 'bool',
		section = 'options_scavengers',
		def  = true,
	},
	{
		key    = 'scavstartboxcloud',
		name   = 'Scavenger Startbox Cloud (Requires Startbox for Scavenger team)',
		desc   = "Spawns purple cloud in Scav startbox area, giving them safe space.",
		type   = 'bool',
		section = 'options_scavengers',
		def  = true,
	},
	{
		key    = 'scavspawnarea',
		name   = 'Scavenger Spawn Area (Requires Startbox for Scavenger team)',
		desc   = "When enabled, Scavengers will only spawn beacons within an area that starts in their startbox and grows up with time. When disabled, they will spawn freely around the map",
		type   = 'bool',
		section = 'options_scavengers',
		def  = true,
	},
    {
		key    = 'scavbosstoggle',
		name   = 'Scavenger Boss',
		desc   = "When enabled, final scavenger boss will spawn",
		type   = 'bool',
		section = 'options_scavengers',
		def  = true,
	},
	-- Hidden
	{
		key    = 'scavunitcountmultiplier',
		name   = 'Spawn Wave Size Multiplier',
		desc   = '',
		type   = 'number',
		section= 'options_scavengers',
		def    = 1,
		min    = 0.01,
		max    = 10,
		step   = 0.01,
		hidden = true,
	},
	{
		key    = 'scavunitspawnmultiplier',
		name   = 'Frequency of Spawn Waves Multiplier',
		desc   = '',
		type   = 'number',
		section= 'options_scavengers',
		def    = 1,
		min    = 0.01,
		max    = 10,
		step   = 0.01,
		hidden = true,
	},
	{
		key    = 'scavbuildspeedmultiplier',
		name   = 'Scavenger Build Speed Multiplier',
		desc   = '',
		type   = 'number',
		section= 'options_scavengers',
		def    = 1,
		min    = 0.01,
		max    = 10,
		step   = 0.01,
		hidden = true,
	},
	{
		key    = 'scavunitveterancymultiplier',
		name   = 'Scavenger Unit Experience Level Multiplier',
		desc   = 'Higher means stronger Scav units',
		type   = 'number',
		section= 'options_scavengers',
		def    = 1,
		min    = 0.01,
		max    = 10,
		step   = 0.01,
		hidden = true,
	},
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Chickens
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	{
		key 	= 'chicken_defense_options',
		name 	= 'Raptors',
		desc 	= 'Various gameplay options that will change how the Raptor Defense is played.',
		type 	= 'section',
	},
	{
		key="chicken_difficulty",
		name="Difficulty",
		desc="Raptors difficulty",
		type="list",
		def="normal",
		section="chicken_defense_options",
		items={
			{key="veryeasy", name="Very Easy", desc="Very Easy"},
			{key="easy", name="Easy", desc="Easy"},
			{key="normal", name="Medium", desc="Medium"},
			{key="hard", name="Hard", desc="Hard"},
			{key="veryhard", name="Very Hard", desc="Very Hard"},
			{key="epic", name="Epic", desc="Epic"},
			{key="survival", name="Endless", desc="Endless Mode"}
		}
	},
	{
		key="chicken_chickenstart",
		name="Burrow Placement",
		desc="Control where burrows spawn",
		type="list",
		def="initialbox",
		section="chicken_defense_options",
		items={
			--{key="anywhere", name="Anywhere", desc="Burrows can spawn anywhere"},
			{key="avoid", name="Avoid Players", desc="Burrows do not spawn on player units"},
			{key="initialbox", name="Initial Start Box", desc="First wave spawns in chicken start box, following burrows avoid players"},
			{key="alwaysbox", name="Always Start Box", desc="Burrows always spawn in chicken start box"},
		}
	},
	{
		key    = "chicken_queentime",
		name   = "Max Queen Arrival (Minutes)",
		desc   = "Queen will spawn after given time.",
		type   = "number",
		def    = 40,
		min    = 1,
		max    = 1440,
		step   = 1,
		section= "chicken_defense_options",
	},
	{
		key    = "chicken_maxchicken",
		name   = "Chicken Limit",
		desc   = "Maximum number of chickens on map.",
		type   = "number",
		def    = 300,
		min    = 50,
		max    = 5000,
		step   = 25,
		section= "chicken_defense_options",
		hidden = true,
	},
	{
		key    = "chicken_spawncountmult",
		name   = "Raptor Spawn Multiplier",
		desc   = "How many times more raptors spawn than normal.",
		type   = "number",
		def    = 1,
		min    = 1,
		max    = 20,
		step   = 1,
		section= "chicken_defense_options",
	},
	{
		key    = "chicken_swarmmode",
		name   = "Swarm Mode",
		desc   = "Waves spawn 10 times faster but for every 2 minutes of waves you get 4 minutes of grace period",
		type   = "bool",
		def    = false,
		section= "chicken_defense_options",
    },
	{
		key    = "chicken_graceperiod",
		name   = "Grace Period (Minutes)",
		desc   = "Time before Raptors become active.",
		type   = "number",
		def    = 5,
		min    = 1,
		max    = 20,
		step   = 1,
		section= "chicken_defense_options",
	},
	{
		key    = "chicken_queenanger",
		name   = "Killing burrows adds to queen anger.",
		desc   = "Killing burrows adds to queen anger.",
		type   = "bool",
		def    = true,
		section= "chicken_defense_options",
    },

	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TeamColoring
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	{
		key		= "teamcoloring_options",
		name	= "TeamColors",
		desc	= "TeamColors",
		type	= "section",
	},
	{
		key    = 'teamcolors_anonymous_mode',
		name   = 'Anonymous Mode',
		desc   = 'All your enemies are colored with the same color so you cannot recognize them. Forces Dynamic TeamColors to be enabled',
		type   = 'bool',
		section = 'teamcoloring_options',
		def  = false,
	},
	{
		key    = 'teamcolors_icon_dev_mode',
		name   = "Icon Dev Mode (Don't use in normal games)",
		desc   = 'Forces teamcolors to be an specific one, for all teams',
		type   = 'list',
		section = 'teamcoloring_options',
		def  = "disabled",
		items={
			{key="disabled", name="Disabled", desc="description"},
			{key="armblue", name="Armada Blue", desc="description"},
			{key="corred", name="Cortex Red", desc="description"},
			{key="scavpurp", name="Scavenger Purple", desc="description"},
			{key="chickenorange", name="Chicken Orange", desc="description"},
			{key="gaiagray", name="Gaia Gray", desc="description"},
		}
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
		key    = 'critters',
		name   = 'Animal amount',
		desc   = 'This multiplier will be applied on the amount of critters a map will end up with',
		hidden = true,
		type   = 'number',
		section= 'options',
		def    = 1,
		min    = 0,
		max    = 2,
		step   = 0.2,
	},
	{
		key="deathmode",
		name="Game End Mode",
		desc="What it takes to eliminate a team",
		type="list",
		def="com",
		section="options",
		items={
			{key="neverend", 	name="Never ending", desc="Teams are never eliminated"},
			{key="com", 		name="Kill all enemy Commanders", desc="When a team has no Commanders left, it loses"},
			{key="builders", 	name="Kill all Builders"},
			{key="killall", 	name="Kill everything", desc="Every last unit must be eliminated, no exceptions!"},
			{key="own_com", 	name="Player resign on Com death", desc="When player commander dies, you auto-resign."},
		}
	},
	{
		key="map_waterlevel",
		name="Water Level",
		desc=" <0 = Decrease water level, >0 = Increase water level",
		type="number",
		def    = 0,
		min    = -10000,
		max    = 10000,
		step   = 1,
		section="options",
	},
	{
		key    = "ffa_mode",
		name   = "FFA Mode",
		desc   = "Units with no player control are removed/destroyed \nUse FFA spawning mode",
		hidden = true,
		type   = "bool",
		def    = false,
		section= "options",
	},
	{
		key    = "ffa_wreckage",
		name   = "FFA Mode Wreckage",
		desc   = "Killed players will blow up but leave wreckages",
		hidden = true,
		type   = "bool",
		def    = false,
		section= "options",
	},

	{
		key    = 'coop',
		name   = 'Cooperative mode',
		desc   = 'Adds extra commanders to id-sharing teams, 1 com per player',
		type   = 'bool',
		def    = false,
		section= 'options',
	},

	{
		key    = 'disablemapdamage',
		name   = 'Undeformable map',
		desc   = 'Prevents the map shape from being changed by weapons',
		type   = 'bool',
		def    = false,
		section= "options",
	},

	{
		key="ruins",
		name="Ruins",
		type="list",
		def="scav_only",
		section="options",
		items={
			{key="enabled", name="Enabled"},
			{key="scav_only", name="Enabled for Scavengers only"},
			{key="disabled", name="Disabled"},
		}
	},

	{
		key="ruins_density",
		name="Ruins: Density",
		type="list",
		def="normal",
		section="options",
		items={
			{key="veryrare", name="Very Rare"},
			{key="rarer", name="Rare"},
			{key="normal", name="Normal"},
			{key="dense", name="Dense"},
			{key="verydense", name="Very Dense"},
		}
	},

	{
		key    = 'ruins_only_t1',
		name   = 'Ruins: Only T1',
		type   = 'bool',
		def    = false,
		section= "options",
	},

	{
		key    = 'ruins_civilian_disable',
		name   = 'Ruins: Disable Civilian (Not Implemented Yet)',
		type   = 'bool',
		def    = false,
		section= "options",
		hidden = true,
	},

	{
		key="lootboxes",
		name="Lootboxes",
		type="list",
		def="scav_only",
		section="options",
		items={
			{key="enabled", name="Enabled"},
			{key="scav_only", name="Enabled for Scavengers only"},
			{key="disabled", name="Disabled"},
		}
	},

	{
		key="lootboxes_density",
		name="Lootboxes: Density",
		type="list",
		def="normal",
		section="options",
		items={
			{key="veryrare", name="Very Rare"},
			{key="rarer", name="Rare"},
			{key="normal", name="Normal"},
			{key="dense", name="Dense"},
			{key="verydense", name="Very Dense"},
		}
	},

	{
		key="assistdronesenabled",
		name="Assist Drones",
		type="list",
		def="pve_only",
		section="options",
		items={
			{key="enabled", name="Enabled"},
			{key="pve_only", name="Enabled for PvE only"},
			{key="disabled", name="Disabled"},
		}
	},

	{
		key    = 'assistdronescount',
		name   = 'Assist Drones: Count',
		desc   = 'How many assist drones per commander should be spawned',
		type   = 'number',
		section= 'options',
		def    = 4,
		min    = 1,
		max    = 30,
		step   = 1,
	},

	{
		key="commanderbuildersenabled",
		name="Base Construction Turret",
		type="list",
		def="pve_only",
		section="options",
		items={
			{key="enabled", name="Enabled"},
			{key="pve_only", name="Enabled for PvE only"},
			{key="disabled", name="Disabled"},
		}
	},

	{
		key    = 'commanderbuildersrange',
		name   = 'Base Construction Turret: Range',
		type   = 'number',
		section= 'options',
		def    = 1500,
		min    = 100,
		max    = 5000,
		step   = 1,
	},

	{
		key    = 'commanderbuildersbuildpower',
		name   = 'Base Construction Turret: Buildpower',
		type   = 'number',
		section= 'options',
		def    = 500,
		min    = 100,
		max    = 5000,
		step   = 1,
	},





	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Control Victory Options
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	{
		key    = 'controlvictoryoptions',
		name   = 'Control',
		desc   = 'Allows you to control at a granular level the individual options for Control Point Victory',
		type   = 'section',
	},
	{
		key="scoremode",
		name="Scoring Mode",
		desc="Defines how the game is played",
		type="list",
		def="disabled",
		section="controlvictoryoptions",
		items={
			{key="disabled", name="Disabled", desc="Disable Control Points as a victory condition."},
			{key="countdown", name="Countdown", desc="A Control Point decreases all opponents' scores, zero means defeat."},
			{key="tugofwar", name="Tug of War", desc="A Control Point steals enemy score, zero means defeat."},
			--{key="domination", name="Domination", desc="Holding all Control Points will grant 1000 score, first to reach the score limit wins."},
		}
	},
	{
		key    = 'scoremode_chess',
		name   = 'Chess Mode',
		desc   = 'No basebuilding',
		type   = 'bool',
		section= 'controlvictoryoptions',
		def  = true,
	},
	{
		key    = 'scoremode_chess_unbalanced',
		name   = 'Chess: Unbalanced',
		desc   = 'Each player gets diffrent set of units',
		type   = 'bool',
		section= 'controlvictoryoptions',
		def  = false,
	},
	{
		key    = 'scoremode_chess_adduptime',
		name   = 'Chess: Minutes Between New Units Add-up.',
		desc   = 'Time Between New Units Add-up.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 4,
		min    = 1,
		max    = 10,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = 'scoremode_chess_spawnsperphase',
		name   = 'Chess: Number of spawns in each phase.',
		desc   = 'Number of spawns in each phase.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 1,
		min    = 1,
		max    = 10,
		step   = 1,  -- quantization is aligned to the def value
		hidden = true,
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = 'limitscore',
		name   = 'Initial Score Per Control Point',
		desc   = 'Initial score amount available.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 300,
		min    = 100,
		max    = 10000,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = "numberofcontrolpoints",
		name   = "Number of control points (affects initial score)",
		desc   = "Sets the number of control points on the map and scales the total score amount to match. Has no effect if Preset map configs are enabled.",
		section= "controlvictoryoptions",
		type="list",
		def="13",
		items={
			{key="7", name="7", desc=""},
			{key="13", name="13", desc=""},
			{key="19", name="19", desc=""},
			{key="25", name="25", desc=""},
		},
		hidden = true,
    },
	{
		key    = "usemapconfig",
		name   = "Use preset map-specific Control Point locations?",
		desc   = "Should the control point config for this map be used instead of autogenerated control points?",
		hidden = true,
		type   = 'bool',
		def    = true,
		section= "controlvictoryoptions",
    },
	{
		key    = "usemexconfig",
		name   = "Use metal spots as point locations?",
		hidden = true,
		type   = 'bool',
		def    = true,
		section= "controlvictoryoptions",
    },
	{
		key    = 'captureradius',
		name   = 'Capture points size',
		desc   = 'Radius around a point in which to capture it.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 200,
		min    = 100,
		max    = 1000,
		step   = 25,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
		hidden = true,
	},
	{
		key    = 'capturetime',
		name   = 'Capture Time',
		desc   = 'Time to capture a point.',
		hidden = true,
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 30,
		min    = 1,
		max    = 120,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},

		{
		key    = 'capturebonus',
		name   = 'Capture Bonus',
		desc   = 'Percentage of how much faster capture takes place by adding more units.',
		hidden = true,
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 100,
		min    = 1,
		max    = 100,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},

		{
		key    = 'decapspeed',
		name   = 'De-Cap Speed',
		desc   = 'Speed multiplier for neutralizing an enemy point.',
		hidden = true,
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
		desc   = 'Number of seconds until control points can be captured.',
		hidden = true,
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
		name   = 'Metal given per point',
		desc   = 'Each player on an allyteam that has captured a point will receive this amount of resources per point captured per second',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 1,
		min    = 0,
		max    = 5,
		step   = 0.1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
		hidden = true,
	},
		{
		key    = 'energyperpoint',
		name   = 'Energy given per point',
		desc   = 'Each player on an allyteam that has captured a point will receive this amount of resources per point captured per second',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 75,
		min    = 0,
		max    = 500,
		step   = 0.1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
		hidden = true,
	},
	{
		key    = 'dominationscoretime',
		name   = 'Domination Score Time',
		desc   = 'Time needed holding all points to score in multi domination.',
		hidden = true,
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
		hidden = true,
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 1,
		min    = 0,
		max    = 6,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},
	{
		key    = 'dominationscore',
		name   = 'Score awarded for Domination',
		desc   = 'The amount of score awarded when you have scored a domination.',
		hidden = true,
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 1000,
		min    = 500,
		max    = 1000,
		step   = 1,  -- quantization is aligned to the def value
		-- (step <= 0) means that there is no quantization
	},

	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Multiplier Options
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	{
		key		= "options_multipliers",
		name	= "Multipliers",
		desc	= "Multipliers options",
		type	= "section",
	},

	{
		key    = 'multiplier_maxdamage',
		name   = 'Health Multiplier',
		desc   = 'Health Multiplier',
		type   ="number",
		section = 'options_multipliers',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'multiplier_maxvelocity',
		name   = 'Unit MaxSpeed Multiplier',
		desc   = 'Unit MaxSpeed Multiplier',
		type   ="number",
		section = 'options_multipliers',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'multiplier_turnrate',
		name   = 'Unit TurnSpeed Multiplier',
		desc   = 'Unit TurnSpeed Multiplier',
		type   ="number",
		section = 'options_multipliers',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'multiplier_builddistance',
		name   = 'Build Range Multiplier',
		desc   = 'Build Range Multiplier',
		type   ="number",
		section = 'options_multipliers',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'multiplier_buildpower',
		name   = 'Build Power Multiplier',
		desc   = 'Build Power Multiplier',
		type   ="number",
		section = 'options_multipliers',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'multiplier_metalcost',
		name   = 'Unit Cost Multiplier - Metal',
		desc   = 'Unit Cost Multiplier - Metal',
		type   ="number",
		section = 'options_multipliers',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'multiplier_energycost',
		name   = 'Unit Cost Multiplier - Energy',
		desc   = 'Unit Cost Multiplier - Energy',
		type   ="number",
		section = 'options_multipliers',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'multiplier_buildtimecost',
		name   = 'Unit Cost Multiplier - Time',
		desc   = 'Unit Cost Multiplier - Time',
		type   ="number",
		section = 'options_multipliers',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'multiplier_losrange',
		name   = 'Vision Range Multiplier',
		desc   = 'Vision Range Multiplier',
		type   ="number",
		section = 'options_multipliers',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'multiplier_radarrange',
		name   = 'Radar and Sonar Range Multiplier',
		desc   = 'Radar and Sonar Range Multiplier',
		type   ="number",
		section = 'options_multipliers',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'multiplier_weaponrange',
		name   = 'Weapon Range Multiplier',
		desc   = 'Weapon Range Multiplier',
		type   ="number",
		section = 'options_multipliers',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'multiplier_weapondamage',
		name   = 'Weapon Damage Multiplier',
		desc   = 'Weapon Damage Multiplier (Also affects unit death explosions)',
		type   ="number",
		section = 'options_multipliers',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
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
	},

	{
		key    = 'experimentalnoaircollisions',
		name   = 'Aircraft Collisions Override',
		desc   = 'Aircraft Collisions Override',
		hidden = true,
		type   = 'bool',
		section = 'options_experimental',
		def  = false,
	},

	{
		key    = 'experimentalshields',
		name   = 'Shield Override',
		desc   = 'Shield Override',
		type   = 'list',
		section = 'options_experimental',
		def  = "unchanged",
		items={
			{key="unchanged", name="Unchanged", desc="Unchanged"},
			{key="absorbplasma", name="Absorb Plasma", desc="Collisions Disabled"},
			{key="absorbeverything", name="Absorb Everything", desc="Collisions Enabled"},
			{key="bounceeverything", name="Deflect Everything", desc="Collisions Enabled"},
		}
	},

	{
		key    = 'experimentalshieldpower',
		name   = 'Shield Power Multiplier',
		desc   = 'Shield Power Multiplier',
		type   ="number",
		section = 'options_experimental',
		def    = 1,
		min    = 0.01,
		max    = 100,
		step   = 0.01,
	},


	{
		key    = 'experimentalxpgain',
		name   = 'XP Gain Multiplier',
		desc   = 'XP Gain Multiplier',
		hidden = true,
		type   ="number",
		section = 'options_experimental',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'experimentalscavuniqueunits',
		name   = 'Scavenger Units Buildable by Players',
		desc   = 'Scavenger Units Buildable by Players',
		type   = 'bool',
		section = 'options_experimental',
		def  = false,
	},

	{
		key    = 'experimentallegionfaction',
		name   = 'Legion Faction',
		desc   = '3rd experimental faction',
		type   = 'bool',
		section = 'options_experimental',
		def  = false,
	},

	{
		key = 'newdgun',
		name = 'New D-Gun Mechanics',
		desc = 'New D-Gun Mechanics',
		type = 'bool',
		section = 'options_experimental',
		def = false,

	},

	{
		key    = 'experimentalmorphs',
		name   = 'Upgradeable Units',
		desc   = 'Upgradeable Units',
		type   = 'bool',
		section = 'options_experimental',
		def  = false,
		hidden = true,
	},

	{
		key    = 'experimentalimprovedtransports',
		name   = 'Transport Units Rework',
		desc   = 'Transport Units Rework',
		hidden = true,
		type   = 'bool',
		section = 'options_experimental',
		def  = false,
	},

	{
		key    = 'mapatmospherics',
		name   = 'Map Atmospherics',
		desc   = 'Map Atmospherics',
		hidden = true,
		type   = 'bool',
		section = 'options_experimental',
		def  = true,
	},

	{
		key    = 'experimentalmassoverride',
		name   = 'Mass Override',
		desc   = 'Mass Override',
		hidden = true,
		type   = 'bool',
		section = 'options_experimental',
		def  = false,
	},

	{
		key    = 'experimentalflankingbonusmode',
		name   = 'Flanking Bonus Mode (between 0 and 3, read tooltip)',
		desc   = "Additional damage applied to units when they're surrounded. 0 - No flanking bonus, 1 - Dynamic direction, world dimension, 2 - Dynamic direction, unit dimension, 3 - Static direction, front armor = best armor. If 3 is chosen, 2 is used for buildings.",
		type   ="number",
		section = 'options_experimental',
		def    = 1,
		min    = 0,
		max    = 3,
		step   = 1,
	},

	{
		key    = 'experimentalflankingbonusmin',
		name   = 'Flanking Bonus Minimum Damage Percentage (Default 90%)',
		desc   = 'How much damage weapons deal at hardest point of flanking armor',
		type   ="number",
		section = 'options_experimental',
		def    = 90,
		min    = 1,
		max    = 1000,
		step   = 1,
	},

	{
		key    = 'experimentalflankingbonusmax',
		name   = 'Flanking Bonus Maximum Damage Percentage (Default 190%)',
		desc   = 'How much damage weapons deal at hardest point of flanking armor',
		type   ="number",
		section = 'options_experimental',
		def    = 190,
		min    = 1,
		max    = 1000,
		step   = 1,
	},

	{
		key    = 'experimentalrebalancet2labs',
		name   = 'Rebalance Candidate: Cheaper T2 Factories',
		desc   = '',
		type   = 'bool',
		section = 'options_experimental',
		def  = false,
	},

	{
		key    = 'experimentalrebalancet2metalextractors',
		name   = 'Rebalance Candidate: Cheaper T2 Metal Extractors (Metal Extraction x4 -> x2)',
		desc   = '',
		type   = 'bool',
		section = 'options_experimental',
		def  = false,
	},

	{
		key    = 'experimentalrebalancet2energy',
		name   = 'Rebalance Candidate: T2 Energy rebalance (Currently only adds T2 wind generator)',
		desc   = '',
		type   = 'bool',
		section = 'options_experimental',
		def  = false,
	},

	{
		key    = 'experimentalrebalancehovercrafttech',
		name   = 'Rebalance Candidate: Hovercraft rebalance - Cheaper lab with buildpower 200 -> 100, can Tech2 into Vehicles and Ships',
		desc   = '',
		type   = 'bool',
		section = 'options_experimental',
		def  = false,
	},

	{
		key		= "experimentalreversegear",
		name	= "Reverse gear - Allows units to move backwards over short distances",
		desc	= "Allows units to move backwards over short distances",
		type	= "bool",
		def		= false,
		section	= "options_experimental",
	},

	{
		key		= "unba",
		name	= "UnbaCom - Reworked Commanders",
		desc	= "Commander levels up with XP, gaining better weapons, more health and higher tech buildlist.",
		type	= "bool",
		def		= false,
		section	= "options_experimental",
	},

	{
		key		= "unbatech",
		name	= "UnbaTech - Reworked Tech Progression (Requires UnbaCom)",
		desc	= "Constructors cannot build Tech2 factories. In order to reach Tech2 you have to level up your commander.",
		type	= "bool",
		def		= false,
		section	= "options_experimental",
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
		hidden = true,
		type	= "section",
	},


	{
		key    = "shareddynamicalliancevictory",
		name   = "Dynamic Ally Victory",
		desc   = "Ingame alliance should count for game over condition.",
		hidden = true,
		type   = "bool",
		section= 'options',
		def    = false,
	},

	{
		key    = 'ai_incomemultiplier',
		name   = 'AI Income Multiplier',
		desc   = 'Multiplies AI resource income',
		hidden = true,
		type   = 'number',
		section= 'options',
		def    = 1,
		min    = 1,
		max    = 10,
		step   = 0.1,
	},

	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- End Options
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

}
return options
