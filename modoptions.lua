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
		key			="ranked_game",
		name   		= "Ranked Game",
		desc   		= "Should game results affect OpenSkill. Note that games with AI or games that are not balanced are always unranked.",
		type   		= "bool",
		section		="restrictions",
		def    		= true,
	},

	{
		key="deathmode",
		name="Game End Mode",
		desc="What it takes to eliminate a team",
		type="list",
		def="com",
		section="restrictions",
		items={
			{key="neverend", 	name="Never ending", desc="Teams are never eliminated"},
			{key="com", 		name="Kill all enemy Commanders", desc="When a team has no Commanders left, it loses"},
			{key="builders", 	name="Kill all Builders"},
			{key="killall", 	name="Kill everything", desc="Every last unit must be eliminated, no exceptions!"},
			{key="own_com", 	name="Player resign on Com death", desc="When player commander dies, you auto-resign."},
		}
	},

	{
		key    = 'maxunits',
		name   = 'Max units per player',
		desc   = 'Keep in mind there is an absolute limit of units, 32000, divided between each team. If you set this value higher than possible it will force itself down to the maximum it can be.',
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
		key    		= "allowpausegameplay",
		name   		= "Allow commands while paused",
		desc   		= "Allow giving unit commands while paused",
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
		hidden 		= true,
		section		= "restrictions",
	},

	{
		key    = 'disablemapdamage',
		name   = 'Disable Map Deformation',
		desc   = 'Prevents the map shape from being changed by weapons',
		type   = 'bool',
		def    = false,
		section= "restrictions",
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
	},
	{
		key="scav_difficulty",
		name="Base Difficulty",
		desc="Scavs difficulty",
		type="list",
		def="normal",
		section="scav_defense_options",
		items={
			{key="veryeasy", name="Very Easy", desc="Very Easy"},
			{key="easy", name="Easy", desc="Easy"},
			{key="normal", name="Normal", desc="Normal"},
			{key="hard", name="Hard", desc="Hard"},
			{key="veryhard", name="Very Hard", desc="Very Hard"},
			{key="epic", name="Epic", desc="Epic"},

			--{key="survival", name="Endless", desc="Endless Mode"}
		}
	},
	{
		key="scav_scavstart",
		name="Spawner Placement",
		desc="Control where spawners appear",
		type="list",
		def="initialbox",
		section="scav_defense_options",
		items={
			{key="avoid", name="Avoid Players", desc="Burrows avoid player units"},
			{key="initialbox", name="Initial Start Box", desc="First wave spawns in scav start box, following burrows avoid players"},
			{key="alwaysbox", name="Always Start Box", desc="Burrows always spawn in scav start box"},
		}
	},
	{
		key    = "scav_endless",
		name   = "Endless Mode",
		desc   = "When you kill the boss, the game doesn't end, but loops around at higher difficulty instead, infinitely.",
		type   = "bool",
		def    = false,
		section= "scav_defense_options",
	},
	{
		key    = "scav_bosstimemult",
		name   = "Boss Preparation Time Multiplier",
		desc   = "(Range: 0.1 - 3). How quickly Boss Anger goes from 0 to 100%.",
		type   = "number",
		def    = 1,
		min    = 0.1,
		max    = 3,
		step   = 0.1,
		section= "scav_defense_options",
	},
	{
		key    = "scav_spawncountmult",
		name   = "Unit Spawn Per Wave Multiplier",
		desc   = "(Range: 1 - 5). How many times more scavs will spawn per wave.",
		type   = "number",
		def    = 1,
		min    = 1,
		max    = 5,
		step   = 1,
		section= "scav_defense_options",
	},
	{
		key    = "scav_spawntimemult",
		name   = "Time Between Waves Multiplier",
		desc   = "(Range: 0.1 - 3). How often new waves will spawn.",
		type   = "number",
		def    = 1,
		min    = 0.1,
		max    = 3,
		step   = 0.1,
		section= "scav_defense_options",
	},
	{
		key    = "scav_graceperiodmult",
		name   = "Grace Period Time Multiplier",
		desc   = "(Range: 0.1 - 3). Time before Scavs become active.",
		type   = "number",
		def    = 1,
		min    = 0.1,
		max    = 3,
		step   = 0.1,
		section= "scav_defense_options",
	},
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Raptors
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	{
		key 	= 'raptor_defense_options',
		name 	= 'Raptors',
		desc 	= 'Various gameplay options that will change how the Raptor Defense is played.',
		type 	= 'section',
	},
	{
		key="raptor_difficulty",
		name="Base Difficulty",
		desc="Raptors difficulty",
		type="list",
		def="normal",
		section="raptor_defense_options",
		items={
			{key="veryeasy", name="Very Easy", desc="Very Easy"},
			{key="easy", name="Easy", desc="Easy"},
			{key="normal", name="Normal", desc="Normal"},
			{key="hard", name="Hard", desc="Hard"},
			{key="veryhard", name="Very Hard", desc="Very Hard"},
			{key="epic", name="Epic", desc="Epic"},

			--{key="survival", name="Endless", desc="Endless Mode"}
		}
	},
	{
		key="raptor_raptorstart",
		name="Burrow Placement",
		desc="Control where burrows spawn",
		type="list",
		def="initialbox",
		section="raptor_defense_options",
		items={
			{key="avoid", name="Avoid Players", desc="Burrows avoid player units"},
			{key="initialbox", name="Initial Start Box", desc="First wave spawns in raptor start box, following burrows avoid players"},
			{key="alwaysbox", name="Always Start Box", desc="Burrows always spawn in raptor start box"},
		}
	},
	{
		key    = "raptor_endless",
		name   = "Endless Mode",
		desc   = "When you kill the queen, the game doesn't end, but loops around at higher difficulty instead, infinitely.",
		type   = "bool",
		def    = false,
		section= "raptor_defense_options",
	},
	{
		key    = "raptor_queentimemult",
		name   = "Queen Hatching Time Multiplier",
		desc   = "(Range: 0.1 - 3). How quickly Queen Hatch goes from 0 to 100%",
		type   = "number",
		def    = 1,
		min    = 0.1,
		max    = 3,
		step   = 0.1,
		section= "raptor_defense_options",
	},
	{
		key    = "raptor_spawncountmult",
		name   = "Unit Spawn Per Wave Multiplier",
		desc   = "(Range: 1 - 5). How many times more raptors will spawn per wave.",
		type   = "number",
		def    = 1,
		min    = 1,
		max    = 5,
		step   = 1,
		section= "raptor_defense_options",
	},
	{
		key    = "raptor_firstwavesboost",
		name   = "First Waves Size Boost",
		desc   = "(Range: 1 - 10). Intended to use with heavily modified settings. Makes first waves larger, the bigger the number the larger they are. Cools down within first few waves.",
		type   = "number",
		def    = 1,
		min    = 1,
		max    = 10,
		step   = 0.1,
		section= "raptor_defense_options",
	},
	{
		key    = "raptor_spawntimemult",
		name   = "Time Between Waves Multiplier",
		desc   = "(Range: 0.1 - 3). How often new waves will spawn.",
		type   = "number",
		def    = 1,
		min    = 0.1,
		max    = 3,
		step   = 0.1,
		section= "raptor_defense_options",
	},
	{
		key    = "raptor_graceperiodmult",
		name   = "Grace Period Time Multiplier",
		desc   = "(Range: 0.1 - 5). Time before Raptors become active. ",
		type   = "number",
		def    = 1,
		min    = 0.1,
		max    = 5,
		step   = 0.1,
		section= "raptor_defense_options",
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
		key="map_tidal",
		name="Tidal Strength",
		desc="Unchanged = map setting, low = 13e/sec, medium = 18e/sec, high = 23e/sec.",
		hidden = true,
		type="list",
		def="unchanged",
		section="options",
		items={
			{key="unchanged", name="Unchanged", desc="Use map settings"},
			{key="low", name="Low", desc="Set tidal incomes to 13 energy per second"},
			{key="medium", name="Medium", desc="Set tidal incomes to 18 energy per second"},
			{key="high", name="High", desc="Set tidal incomes to 23 energy per second"},
		}
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
		key    = "map_atmosphere",
		name   = "Map Atmosphere and Ambient Sounds",
		desc   = "",
		type   = "bool",
		def    = true,
		hidden = true,
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
		hidden = true,
		def    = false,
		section= 'options',
	},


	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Resources
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	{
		key		= "options_resources",
		name	= "Resources",
		desc	= "Resource options",
		type	= "section",
	},

	{
		key    = "startmetal",
		name   = "Starting metal",
		desc   = "(Range 0 - 10000). Determines amount of metal and metal storage that each player will start with",
		type   = "number",
		section= "options_resources",
		def    = 1000,
		min    = 0,
		max    = 10000,
		step   = 1,
	},

	{
		key    = "startmetalstorage",
		name   = "Starting metal storage",
		desc   = "(Range 1000 - 20000). Only works if it's higher than Starting metal. Determines amount of metal and metal storage that each player will start with",
		type   = "number",
		section= "options_resources",
		def    = 1000,
		min    = 1000,
		max    = 20000,
		step   = 1,
	},

	{
		key    = "startenergy",
		name   = "Starting energy",
		desc   = "(Range 0 - 10000). Determines amount of energy and energy storage that each player will start with",
		type   = "number",
		section= "options_resources",
		def    = 1000,
		min    = 0,
		max    = 10000,
		step   = 1,
	},

	{
		key    = "startenergystorage",
		name   = "Starting energy storage",
		desc   = "(Range 1000 - 20000). Only works if it's higher than Starting energy. Determines amount of energy and energy storage that each player will start with",
		type   = "number",
		section= "options_resources",
		def    = 1000,
		min    = 1000,
		max    = 20000,
		step   = 1,
	},

	{
		key    = 'multiplier_resourceincome',
		name   = 'Overall Resource Income Multiplier',
		desc   = '(Range 0.1 - 10). Stacks up with the three options below.',
		type   =  "number",
		section = 'options_resources',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'multiplier_metalextraction',
		name   = 'Metal Extraction Multiplier ',
		desc   = '(Range 0.1 - 10).',
		type   =  "number",
		section = 'options_resources',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'multiplier_energyconversion',
		name   = 'Energy Conversion Efficiency Multiplier ',
		desc   = '(Range 0.1 - 1). lower means you get less metal per energy converted',
		type   =  "number",
		section = 'options_resources',
		def    = 1,
		min    = 0.1,
		max    = 1,
		step   = 0.1,
	},

	{
		key    = 'multiplier_energyproduction',
		name   = 'Energy Production Multiplier',
		desc   = '(Range 0.1 - 10).',
		type   =  "number",
		section = 'options_resources',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
	},

	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Multiplier Options
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	{
		key		= "options_unit_modifiers",
		name	= "Unit Modifiers",
		desc	= "Multipliers options",
		type	= "section",
	},


	{
		key    = 'multiplier_maxdamage',
		name   = 'Health Multiplier',
		desc   = '(Range 0.1 - 10).',
		type   ="number",
		section = 'options_unit_modifiers',
		hidden = true,
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'multiplier_maxvelocity',
		name   = 'Unit Max Velocity Multiplier',
		desc   = '(Range 0.1 - 10).',
		type   ="number",
		section = 'options_unit_modifiers',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'multiplier_turnrate',
		name   = 'Unit Turn Rate Multiplier',
		desc   = '(Range 0.1 - 10).',
		type   ="number",
		section = 'options_unit_modifiers',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'multiplier_builddistance',
		name   = 'Build Range Multiplier ',
		desc   = '(Range 0.5 - 10).',
		type   ="number",
		section = 'options_unit_modifiers',
		def    = 1,
		min    = 0.5,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'multiplier_buildpower',
		name   = 'Build Power Multiplier',
		desc   = '(Range 0.1 - 10).',
		type   ="number",
		section = 'options_unit_modifiers',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'multiplier_metalcost',
		name   = 'Unit Cost Multiplier - Metal',
		desc   = '(Range 0.1 - 10).',
		type   ="number",
		section = 'options_unit_modifiers',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
		hidden = true,
	},

	{
		key    = 'multiplier_energycost',
		name   = 'Unit Cost Multiplier - Energy',
		desc   = '(Range 0.1 - 10).',
		type   ="number",
		section = 'options_unit_modifiers',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
		hidden = true,
	},

	{
		key    = 'multiplier_buildtimecost',
		name   = 'Unit Cost Multiplier - Time',
		desc   = '(Range 0.1 - 10).',
		type   ="number",
		section = 'options_unit_modifiers',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
		hidden = true,
	},

	{
		key    = 'multiplier_losrange',
		name   = 'Vision Range Multiplier',
		desc   = '(Range 0.5 - 10).',
		type   ="number",
		section = 'options_unit_modifiers',
		def    = 1,
		min    = 0.5,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'multiplier_radarrange',
		name   = 'Radar and Sonar Range Multiplier',
		desc   = '(Range 0.5 - 10).',
		type   ="number",
		section = 'options_unit_modifiers',
		def    = 1,
		min    = 0.5,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'multiplier_weaponrange',
		name   = 'Weapon Range Multiplier',
		desc   = '(Range 0.5 - 10).',
		type   ="number",
		section = 'options_unit_modifiers',
		def    = 1,
		min    = 0.5,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'multiplier_weapondamage',
		name   = 'Weapon Damage Multiplier ',
		desc   = '(Range 0.1 - 10). Also affects unit death explosions.',
		type   ="number",
		section = 'options_unit_modifiers',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
	},

	{
		key    = 'multiplier_shieldpower',
		name   = 'Shield Power Multiplier',
		desc   = '(Range 0.1 - 10)',
		type   ="number",
		section = 'options_unit_modifiers',
		def    = 1,
		min    = 0.1,
		max    = 10,
		step   = 0.1,
	},

	{
		key		= "experimentalreversegear",
		name	= "Reverse gear",
		desc	= "Allows units to move backwards over short distances",
		type	= "bool",
		def		= false,
		section	= "options_unit_modifiers",
	},

	{
		key     = "tweakunits",
		name    = "Tweak Units",
		desc    = "For advanced users!!! A base64 encoded lua table of unit parameters to change.",
		section = 'options_unit_modifiers',
		type    = "string",
		def     = "",
	},

	{
		key     = "tweakdefs",
		name    = "Tweak Defs",
		desc    = "For advanced users!!! A base64 encoded snippet of code that modifies game definitions.",
		section = 'options_unit_modifiers',
		type    = "string",
		def     = "",
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
		name   = 'Shield Type Override',
		desc   = 'Shield Type Override',
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
		key    = 'experimentalstandardgravity',
		name   = 'Gravity Override',
		desc   = 'Override map gravity for weapons',
		type   = 'list',
		section = 'options_experimental',
		def  = "mapgravity",
		items={
			{key="mapgravity", name="Map Gravity", desc="Uses map defined gravity"},
			{key="low", name="Low Gravity", desc="80 gravity"},
			{key="standard", name="Standard Gravity", desc="120 gravity"},
			{key="high", name="High Gravity", desc="150 gravity"},
		}
	},

	{
		key    = 'releasecandidates',
		name   = 'Release Candidate Units',
		desc   = 'Adds additional units to the game which are being considered for mainline integration and are balanced, or in end tuning stages.  Currently, adds Printer, Demon, Salamander, and Shockwave (Arm T2 EMP Mex)',
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
		key = 'comtestchanges',
		name = 'Commander Test Changes',
		desc = 'Comupdate, but with health 4000->3700, regen 0->5, and T1 turrets deal 1.5x damage to commanders',
		type = 'bool',
		section = 'options_experimental',
		def = true,
		hidden = true,
	},

	{
		key = 'expandedt2sea',
		name = 'Expanded T2 Sea',
		desc = 'T2 sea is expanded to include a lightning ship for arm and a flamethrower ship for cor, and both factions get a drone carrier ship and an anti-nuke support ship to replace the aircraft carrier.  Cruisers rebalanced to be slower and lower range but higher health and dps for a more defensive role',
		type = 'bool',
		section = 'options_experimental',
		def = false,
	},


	{
		key = 'emprework',
		name = 'EMP Rework',
		desc = 'EMP is changed to slow units movement and firerate, before eventually stunning.',
		type = 'bool',
		section = 'options_experimental',
		def = false,
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
		key    = 'experimentalmassoverride',
		name   = 'Mass Override',
		desc   = 'Mass Override',
		hidden = true,
		type   = 'bool',
		section = 'options_experimental',
		def  = false,
	},

	{
		key    = 'experimentalrebalancet2labs',
		name   = 'Rebalance Candidate: Cheaper T2 Factories',
		desc   = '',
		type   = 'bool',
		section = 'options_experimental',
		def  = false,
		hidden = true,
	},

	{
		key    = 'experimentalrebalancet2metalextractors',
		name   = 'Rebalance Candidate: Cheaper T2 Metal Extractors (Metal Extraction x4 -> x2)',
		desc   = '',
		type   = 'bool',
		section = 'options_experimental',
		def  = false,
		hidden = true,
	},

	{
		key    = 'experimentalrebalancet2energy',
		name   = 'Rebalance Candidate: T2 Energy rebalance (Currently only adds T2 wind generator)',
		desc   = '',
		type   = 'bool',
		section = 'options_experimental',
		def  = false,
		hidden = true,
	},

	{
		key    = 'experimentalrebalancehovercrafttech',
		name   = 'Rebalance Candidate: Hovercraft rebalance - Cheaper lab with buildpower 200 -> 100, can Tech2 into Vehicles and Ships',
		desc   = '',
		type   = 'bool',
		section = 'options_experimental',
		def  = true,
		hidden = true,
	},

	{
		key    = 'experimentalrebalancewreckstandarization',
		name   = 'Rebalance Candidate: Standarized wreck metal values. *0.6 of metal cost for wreck, *0.25 for heap.',
		desc   = '',
		type   = 'bool',
		section = 'options_experimental',
		def  = true,
		hidden = true,
	},

	{
		key		= "unified_maxslope",
		name	= "Standardized land unit maxslope",
		desc	= "All land units have minimum maxslope of 36",
		type	= "bool",
		def		= false,
		section	= "options_experimental",
	},

	{
		key    		= 'norush',
		name   		= "No Rush mode",
		desc   		= "!UNFINISHED! - Missing visual indicators, Requires Startboxes (doesn't work in FFA or 1v1 preset)",
		type   		= "bool",
		section		= 'options_experimental',
		def    		= false,
	},

	{
		key    		= 'norushtimer',
		name   		= "No Rush Time",
		desc   		= '(Range: 5 - 30). Minutes',
		type   		= "number",
		section		= 'options_experimental',
		def    		= 5,
		min    		= 5,
		max    		= 30,
		step   		= 1,
	},

	{
		key    = 'teamcolors_icon_dev_mode',
		name   = "Icon Dev Mode ",
		desc   = "(Don't use in normal games) Forces teamcolors to be an specific one, for all teams",
		type   = 'list',
		section = 'options_experimental',
		def  = "disabled",
		items={
			{key="disabled", name="Disabled", desc="description"},
			{key="armblue", name="Armada Blue", desc="description"},
			{key="corred", name="Cortex Red", desc="description"},
			{key="scavpurp", name="Scavenger Purple", desc="description"},
			{key="raptororange", name="Raptor Orange", desc="description"},
			{key="gaiagray", name="Gaia Gray", desc="description"},
		}
	},

	{
		key    		= 'faction_limiter',
		name   		= 'Limit which factions a team can play.',
		desc   		= 'Input the factions a team should play, seperating teams by a comma, e.g. "armada cortex, legion" = cor/arm vs legion.',
		type   		= "string",
		section		= 'options_experimental',
		def			= "",
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
	},

	{
		key="map_waterlevel",
		name="Water Level",
		desc="Doesn't work if Map Deformation is disabled! <0 = Decrease water level, >0 = Increase water level",
		type="number",
		def    = 0,
		min    = -10000,
		max    = 10000,
		step   = 1,
		section="options_extra",
	},

	{
		key    = "map_waterislava",
		name   = "Water Is Lava",
		desc   = "Turns water into Lava",
		type   = "bool",
		def    = false,
		section= "options_extra",
	},

	{
		key    = 'experimentalextraunits',
		name   = 'Extra Units Pack',
		desc   = 'Formerly known as Scavenger units. Addon pack of units for Armada and Cortex, including various "fun" units',
		type   = 'bool',
		section = 'options_extra',
		def  = false,
	},

	{
		key		= "unba",
		name	= "UnbaCom",
		desc	= "Commanders gaining upgrades with experience! Commander levels up with XP, gaining better weapons, more health and higher tech buildlist.",
		type	= "bool",
		def		= false,
		section	= "options_extra",
	},

	{
		key		= "unbatech",
		name	= "UnbaTech",
		desc	= "(Requires UnbaCom) Constructors cannot build Tech2 factories. In order to reach Tech2 you have to level up your commander.",
		type	= "bool",
		def		= false,
		section	= "options_extra",
		hidden = true,
	},

	{
		key     = 'teamcolors_anonymous_mode',
		name    = 'Anonymous Mode',
		desc    = "Anonymize players by changing colors (based on chosen mode) and replacing names with question marks, making it harder to know who's who.",
		type    = 'list',
		section = 'options_extra',
		def     = "disabled",
		items   = {
			{key="disabled", name="Disabled"},
			{key="global", name="Global", desc="You can distinguish different players and everyone sees the same colors globally. Diplomacy is the same as usual except using colors instead of names (e.g. \"Red, let's ally against Blue\")."},
			{key="local", name="Local", desc="You can distinguish different players but everyone sees different colors locally. Diplomacy is harder but possible using positions (e.g. \"Southeast, let's ally against Northeast\")."},
			{key="disco", name="Local (Disco)", desc="Same as local, except that colors are reshuffled every 2 mins for extra spicyness."},
			{key="allred", name="All red", desc="You cannot distinguish different players, they all have the same color (red by default, can be changed in accessibility settings). Diplomacy is very hard."},
		},
	},

	{
		key="ruins",
		name="Ruins",
		desc = "Remains of the battles once fought",
		type="list",
		def="scav_only",
		section="options_extra",
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
		section="options_extra",
		hidden = true,
		items={
			{key="normal", name="Normal"},
			{key="rarer", name="Rare"},
			{key="veryrare", name="Very Rare"},
		}
	},

	{
		key    = 'ruins_only_t1',
		name   = 'Ruins: Only T1',
		type   = 'bool',
		def    = true,
		hidden = true,
		section= "options_extra",
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
		desc = "Random drops of valuable stuff.",
		type="list",
		def="scav_only",
		section="options_extra",
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
		section="options_extra",
		hidden = true,
		items={
			{key="normal", name="Normal"},
			{key="rarer", name="Rare"},
			{key="veryrare", name="Very Rare"},
		}
	},

	{
		key="assistdronesenabled",
		name="Construction Drones",
		type="list",
		def="disabled",
		section="options_extra",
		items={
			{key="enabled", name="Enabled"},
			--{key="pve_only", name="Enabled for PvE only"},
			{key="disabled", name="Disabled"},
		}
	},

	{
		key    = 'assistdronesbuildpowermultiplier',
		name   = 'Construction Drones: Buildpower Multiplier',
		desc   = '(Range 0.5 - 3). How many assist drones per commander should be spawned',
		type   = 'number',
		section= 'options_extra',
		def    = 1,
		min    = 0.5,
		max    = 5,
		step   = 1,
	},

	{
		key    = 'assistdronescount',
		name   = 'Assist Drones: Count',
		desc   = 'How many assist drones per commander should be spawned',
		type   = 'number',
		section= 'options_extra',
		hidden = true,
		def    = 10,
		min    = 1,
		max    = 30,
		step   = 1,
	},

	{
		key    = 'assistdronesair',
		name   = 'Assist Drones: Use Air Drones',
		type   = 'bool',
		def    = true,
		hidden = true,
		section= "options_extra",
	},

	{
		key="commanderbuildersenabled",
		name="Main Construction Turret",
		type="list",
		def="disabled",
		section="options_extra",
		items={
			{key="enabled", name="Enabled"},
			--{key="pve_only", name="Enabled for PvE only"},
			{key="disabled", name="Disabled"},
		}
	},

	{
		key    = 'commanderbuildersrange',
		name   = 'Main Construction Turret: Buildrange',
		desc   = "(Range 500 - 2000).",
		type   = 'number',
		section= 'options_extra',
		def    = 1000,
		min    = 500,
		max    = 2000,
		step   = 1,
	},

	{
		key    = 'commanderbuildersbuildpower',
		name   = 'Main Construction Turret: Buildpower',
		desc   = "(Range 100 - 1000).",
		type   = 'number',
		section= 'options_extra',
		def    = 400,
		min    = 100,
		max    = 1000,
		step   = 1,
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

	{
		key     = "debugcommands",
		name    = "Debug Commands",
		desc    = "A pipe separated list of commands to execute at [gameframe]:luarules fightertest|100:forcequit...", -- example: debugcommands=150:cheat 1|200:luarules fightertest|600:quitforce;
		section = 'options_experimental',
		type    = "string",
		def     = "",
	},

	{
		key     = "defaultdecals",
		name    = "Default Decals",
		desc    = "Use the default explosion decals instead of Decals GL4", -- example: debugcommands=150:cheat 1|200:luarules fightertest|600:quitforce;
		section = 'options_experimental',
		type    = "bool",
		def     =  true,
		hidden = true,
	},

	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Control Victory Options -- Unused gamemode
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
		hidden = true, -- Should NOT be hidden when we work on this again.
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
		hidden = true, -- Should NOT be hidden when we work on this again.
		def  = true,
	},
	{
		key    = 'scoremode_chess_unbalanced',
		name   = 'Chess: Unbalanced',
		desc   = 'Each player gets diffrent set of units',
		type   = 'bool',
		section= 'controlvictoryoptions',
		hidden = true, -- Should NOT be hidden when we work on this again.
		def  = false,
	},
	{
		key    = 'scoremode_chess_adduptime',
		name   = 'Chess: Minutes Between New Units Add-up.',
		desc   = 'Time Between New Units Add-up.',
		type   = 'number',
		section= 'controlvictoryoptions',
		hidden = true, -- Should NOT be hidden when we work on this again.
		def    = 1,
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
		hidden = true, -- Should NOT be hidden when we work on this again.
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
		name   = "Use metal spots as point locations",
		type   = 'bool',
		def    = false,
		section= "controlvictoryoptions",
		hidden = true, -- Should NOT be hidden when we work on this again.
    },
	{
		key    = 'captureradius',
		name   = 'Capture points size',
		desc   = 'Radius around a point in which to capture it.',
		type   = 'number',
		section= 'controlvictoryoptions',
		def    = 100,
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
		def    = 4,
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
	-- End Options
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

}

for i = 1, 9 do
	options[#options + 1] =  {
		key     = "tweakunits" .. i,
		name    = "Tweak Units " .. i,
		desc    = "A base64 encoded lua table of unit parameters to change.",
		section = 'options_extra',
		type    = "string",
		def     = "",
		hidden = true,
	}
end

for i = 1, 9 do
	options[#options + 1] =  {
		key     = "tweakdefs" .. i,
		name    = "Tweak Defs " .. i,
		desc    = "A base64 encoded snippet of code that modifies game definitions.",
		section = 'options_extra',
		type    = "string",
		def     = "",
		hidden = true,
	}
end

return options
