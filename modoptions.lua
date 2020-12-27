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
	{
		key="modes",
		name="Game Modes",
		desc="Game Modes",
		type="section",
	},
	{
		key="deathmode",
		name="Game End Mode",
		desc="What it takes to eliminate a team",
		type="list",
		def="com",
		section="modes",
		items={
			{key="neverend", name="None", desc="Teams are never eliminated"},
			{key="com", name="Kill all enemy Commanders", desc="When a team has no Commanders left, it loses"},
			{key="killall", name="Kill everything", desc="Every last unit must be eliminated, no exceptions!"},
		}
	},
	{
		key    = "ffa_mode",
		name   = "FFA Mode",
		desc   = "Units with no player control are removed/destroyed \nUse FFA spawning mode",
		type   = "bool",
		def    = false,
		section= "modes",
	},
	{
		key    = 'armageddontime',
		name   = 'Armageddon time (minutes)',
		desc   = 'At armageddon every immobile unit is destroyed and you fight to the death with what\'s left! (0=off)',
		type   = 'number',
		section= 'modes',
		def    = 0,
		min    = 0,
		max    = 120,
		step   = 1,
	},

	--{
	--	key		= "unba",
	--	name	= "Unbalanced Commanders",
	--	desc	= "Defines if commanders level up with xp and gain more power or not",
	--	type	= "list",
	--	def		= "disabled",
	--	section	= "modes",
	--	items	= {
	--		{key="disabled", name="Disabled", desc="Disable Unbalanced Commanders"},
	--		{key="enabled", name="Enabled", desc="Enable Unbalanced Commanders"},
	--	}
	--},

	{
		key    = 'coop',
		name   = 'Cooperative mode',
		desc   = 'Adds extra commanders to id-sharing teams, 1 com per player',
		type   = 'bool',
		def    = false,
		section= 'modes',
	},
	{
		key    = "shareddynamicalliancevictory",
		name   = "Dynamic Ally Victory",
		desc   = "Ingame alliance should count for game over condition.",
		type   = "bool",
		section= 'modes',
		def    = false,
	},


	{
		key="options",
		name="Options",
		desc="Options",
		type="section",
	},
	{
		key    = "startmetal",
		name   = "Starting metal",
		desc   = "Determines amount of metal and metal storage that each player will start with",
		type   = "number",
		section= "options",
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
		section= "options",
		def    = 1000,
		min    = 0,
		max    = 10000,
		step   = 1,
	},
	{
		key    = 'MaxUnits',
		name   = 'Max units',
		desc   = 'Maximum number of units (including buildings) for each team allowed at the same time',
		type   = 'number',
		def    = 2000,
		min    = 1,
		max    = 10000, --- engine caps at lower limit if more than 3 team are ingame
		step   = 1,  -- quantization is aligned to the def value, (step <= 0) means that there is no quantization
		section= "options",
	},
	--{
	--	key    = 'ai_incomemultiplier',
	--	name   = 'AI Income Multiplier',
	--	desc   = 'Multiplies AI resource income',
	--	type   = 'number',
	--	section= 'options',
	--	def    = 1,
	--	min    = 1,
	--	max    = 10,
	--	step   = 0.1,
	--},
	{
		key="map_tidal",
		name="Tidal Strength",
		desc="Unchanged = map setting, low = 13e/sec, medium = 18e/sec, high = 23e/sec.",
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
		key="map_terraintype",
		name="Map TerrainTypes",
		desc="Allows to cancel the TerrainType movespeed buffs of a map.",
		type="list",
		def="enabled",
		section="options",
		items={
			{key="disabled", name="Disabled", desc="Disable TerrainTypes related MoveSpeed Buffs"},
			{key="enabled", name="Enabled", desc="Enable TerrainTypes related MoveSpeed Buffs"},
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
		key    = 'critters',
		name   = 'Animal amount',
		desc   = 'This multiplier will be applied on the amount of critters a map will end up with',
		type   = 'number',
		section= 'options',
		def    = 1,
		min    = 0,
		max    = 2,
		step   = 0.2,
	},
	-- {
		-- key    = 'scavengers',
		-- name   = 'Scavenger Difficulty',
		-- desc   = 'This multiplier will be applied on the amount of civilians a map will end up with',
		-- type   = 'number',
		-- section= 'options',
		-- def    = 0.5,
		-- min    = 0.1,
		-- max    = 5,
		-- step   = 0.1,
	-- },
	--{
	--	key    = 'airrebalance',
	--	name   = 'Heavier but more expensive air',
	--	desc   = 'placeholder-description',
	--	type   = 'number',
	--	section= 'options',
	--	def    = 1,
	--	min    = 0,
	--	max    = 1,
	--	step   = 1,
	--},
	-- {
		-- key    = 'night',
		-- name   = 'Day-Night Cycle',
		-- desc   = 'Hello darkness my old friend',
		-- type   = 'number',
		-- section= 'options',
		-- def    = 0,
		-- min    = 0,
		-- max    = 1,
		-- step   = 1,
	-- },
	{
		key    = "newbie_placer",
		name   = "Newbie Placer",
		desc   = "Chooses a startpoint and a random faction for all rank 1 accounts (online only)",
		type   = "bool",
		def    = false,
		section= "options",
	},

	{
		key    = 'restrictions',
		name   = 'Restrictions',
		desc   = '',
		type   = 'section',
	},
	{
		key    = 'MinSpeed',
		name   = 'Minimum game speed',
		desc   = 'Sets the minimum speed that the players will be allowed to change to',
		type   = 'number',
		section= 'restrictions',
		def    = 0.3,
		min    = 0.1,
		max    = 1,
		step   = 0.1,
	},
	{
		key    = 'MaxSpeed',
		name   = 'Maximum game speed',
		desc   = 'Sets the maximum speed that the players will be allowed to change to',
		type   = 'number',
		section= 'restrictions',
		def    = 10,
		min    = 0.1,
		max    = 50,
		step   = 0.1,
	},
	{
		key    = 'DisableMapDamage',
		name   = 'Undeformable map',
		desc   = 'Prevents the map shape from being changed by weapons',
		type   = 'bool',
		def    = false,
		section= "restrictions",
	},
	{
		key    = "allowuserwidgets",
		name   = "Allow user widgets",
		desc   = "Allow custom user widgets or disallow them",
		type   = "bool",
		def    = true,
		section= 'restrictions',
	},
	{
		key    = "allowmapmutators",
		name   = "Allow map mutators",
		desc   = "Allows maps to overwrite files from the game",
		type   = "bool",
		def    = true,
		section= 'restrictions',
	},
	{
		key    = 'FixedAllies',
		name   = 'Fixed ingame alliances',
		desc   = 'Disables the possibility of players to dynamically change alliances ingame',
		type   = 'bool',
		def    = true,
		section= "restrictions",
	},
	{
		key="transportenemy",
		name="Enemy Transporting",
		desc="Toggle which enemy units you can kidnap with an air transport",
		type="list",
		def="notcoms",
		section="restrictions",
		items={
			{key="notcoms", name="All But Commanders", desc="Only commanders are immune to napping"},
			{key="none", name="Disallow All", desc="No enemy units can be napped"},
		}
	},
	-----------------------------------------------------------------------------------------------------------------------------------------
	{
		key="options_scavengers",
		name="Scavengers",
		desc="Gameplay options for Scavengers gamemode",
		type="section",
	},
	
	{
		key    = 'scavdifficulty',
		name   = 'Difficulty',
		desc   = 'Scavengers Difficulty Level',
		type   = 'list',
		section = 'options_scavengers',
		def  = "easy",
		items={
			{key="noob", name="Noob", desc="Noob"},
			{key="easy", name="Easy", desc="Easy"},
			{key="medium", name="Medium", desc="Medium"},
			{key="hard", name="Hard", desc="Hard"},
			{key="veryhard", name="Very Hard", desc="Very Hard"},
			{key="brutal", name="Brutal", desc="You'll die"},
			{key="insane", name="Insane", desc="You'll die, but harder."},
			{key="impossible", name="Impossible", desc="You can't win this... seriously."},
		}
	},
	
	-- {
		-- key    = 'scavtechdifficulty',
		-- name   = 'Scavengers Tech Difficulty',
		-- desc   = 'Determines how fast scav tech ramps up. Adaptive will adjust to players skill',
		-- type   = 'list',
		-- section = 'options_scavengers',
		-- def  = "adaptive",
		-- items={
			-- {key="adaptive", name="Adaptive", desc="Adapts to players skill"},
			-- {key="easy", name="Easy", desc="Slow ramp up for newbies and noobs"},
			-- {key="medium", name="Medium", desc="Normal ramp up for slightly experienced players"},
			-- {key="hard", name="Hard", desc="Hard ramp up for experienced players"},
			-- {key="brutal", name="Brutal", desc="You'll die"},
		-- }
	-- },
	
	{
		key    = 'scavtechcurve',
		name   = 'Tech Curve',
		desc   = 'Modifies how fast Scavengers tech up',
		type   = 'list',
		section = 'options_scavengers',
		def  = "normal",
		items={
			{key="normal", name="Normal", desc="x1"},
			{key="fast", name="Fast", desc="x0.5"},
			{key="slow", name="Slow", desc="x1.5"},
		}
	},
	
	{
		key    = 'scavendless',
		name   = 'Endless Mode',
		desc   = 'Disables final boss fight, turning Scavengers into an endless survival mode',
		type   = 'list',
		section = 'options_scavengers',
		def  = "disabled",
		items={
			{key="disabled", name="Disabled", desc="Final Boss Enabled"},
			{key="enabled", name="Enabled", desc="Final Boss Disabled"},
		}
	},
	
	{
		key    = 'scavbosshealth',
		name   = 'Boss Health Modifier',
		desc   = 'Modifies Final Boss maximum health points',
		type   = 'list',
		section = 'options_scavengers',
		def  = "normal",
		items={
			{key="normal", name="Normal", desc="x1"},
			{key="lower", name="Lower", desc="x0.5"},
			{key="higher", name="Higher", desc="x1.5"},
			{key="high", name="High", desc="x2"},
		}
	},
	
	{
		key    = 'scavevents',
		name   = 'Random Events',
		desc   = 'Random Events System',
		type   = 'list',
		section = 'options_scavengers',
		def  = "enabled",
		items={
			{key="enabled", name="Enabled", desc="Random Events Enabled"},
			{key="disabled", name="Disabled", desc="Random Events Disabled"},
		}
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
		key    = 'ruins',
		name   = 'Random Ruins',
		desc   = 'description',
		type   = 'list',
		section = 'options',
		def  = "disabled",
		items={
			{key="enabled", name="Enabled", desc="description"},
			{key="disabled", name="Disabled", desc="description"},
		}
	},
	{
		key    = 'scavonlyruins',
		name   = 'Random Ruins (ScavMode)',
		desc   = 'description',
		type   = 'list',
		section = 'options_scavengers',
		def  = "enabled",
		items={
			{key="enabled", name="Enabled", desc="description"},
			{key="disabled", name="Disabled", desc="description"},
		}
	},
	{
		key    = 'lootboxes',
		name   = 'Lootboxes',
		desc   = '1 to enable, 0 to disable',
		type   = 'list',
		section= 'options',
		def  = "disabled",
		items={
			{key="enabled", name="Enabled", desc="description"},
			{key="disabled", name="Disabled", desc="description"},
		}
	},
	{
		key    = 'scavonlylootboxes',
		name   = 'Lootboxes (ScavMode)',
		desc   = '1 to enable, 0 to disable',
		type   = 'list',
		section= 'options_scavengers',
		def  = "enabled",
		items={
			{key="enabled", name="Enabled", desc="description"},
			{key="disabled", name="Disabled", desc="description"},
		}
	},
	
	-----------------------------------------------------------------------------------------------------------------------------------------

-- Chicken Defense Options
	{
		key    = 'chicken_defense_options',
		name   = 'Chicken Defense Options',
		desc   = 'Various gameplay options that will change how the Chicken Defense is played.',
		type   = 'section',
	},
	{
		key="chicken_chickenstart",
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
		key="chicken_queendifficulty",
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
		key    = "chicken_queentime",
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
		key    = "chicken_maxchicken",
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
		key    = "chicken_graceperiod",
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
		key    = "chicken_queenanger",
		name   = "Add Queen Anger",
		desc   = "Killing burrows adds to queen anger.",
		type   = "bool",
		def    = true,
		section= "chicken_defense_options",
    },

-- Chicken Defense Custom Difficulty Settings
	{
		key    = 'chicken_defense_custom_settings',
		name   = 'Chicken Defense Custom Settings',
		desc   = 'Use these settings to adjust the difficulty of Chicken Defense',
		type   = 'section',
	},
	{
		key    = "chicken_custom_burrowspawn",
		name   = "Burrow Spawn Rate (Seconds)",
		desc   = "Time between burrow spawns.",
		type   = "number",
		def    = 120,
		min    = 1,
		max    = 600,
		step   = 1,
		section= "chicken_defense_custom_settings",
	},
	{
		key    = "chicken_custom_chickenspawn",
		name   = "Wave Spawn Rate (Seconds)",
		desc   = "Time between chicken waves.",
		type   = "number",
		def    = 90,
		min    = 10,
		max    = 600,
		step   = 1,
		section= "chicken_defense_custom_settings",
	},
	{
		key    = "chicken_custom_minchicken",
		name   = "Min Chickens Per Player",
		desc   = "Minimum Number of chickens before spawn chance kicks in",
		type   = "number",
		def    = 8,
		min    = 1,
		max    = 250,
		step   = 1,
		section= "chicken_defense_custom_settings",
	},
	{
		key    = "chicken_custom_spawnchance",
		name   = "Spawn Chance (Percent)",
		desc   = "Percent chance of each chicken spawn once greater than the min chickens per player limit",
		type   = "number",
		def    = 33,
		min    = 0,
		max    = 100,
		step   = 1,
		section= "chicken_defense_custom_settings",
	},
	{
		key    = "chicken_custom_angerbonus",
		name   = "Burrow Kill Anger (Percent)",
		desc   = "Seconds added per burrow kill.",
		type   = "number",
		def    = 0.15,
		min    = 0,
		max    = 100,
		step   = 0.01,
		section= "chicken_defense_custom_settings",
	},
	{
		key    = "chicken_custom_queenspawnmult",
		name   = "Queen Wave Size Mod",
		desc   = "Number of squads spawned by the queen at once.",
		type   = "number",
		def    = 1,
		min    = 0,
		max    = 5,
		step   = 1,
		section= "chicken_defense_custom_settings",
	},
	{
		key    = "custom_expstep",
		name   = "Bonus Experience",
		desc   = "Exp each chicken will receive by the end of the game",
		type   = "number",
		def    = 1.5,
		min    = 0,
		max    = 2.5,
		step   = 0.1,
		section= "chicken_defense_custom_settings",
	},
	{
		key    = "chicken_custom_lobberemp",
		name   = "Lobber EMP Duration",
		desc   = "Max duration of Lobber EMP artillery",
		type   = "number",
		def    = 4,
		min    = 0,
		max    = 30,
		step   = 0.5,
		section= "chicken_defense_custom_settings",
	},
	{
		key    = "chicken_custom_damagemod",
		name   = "Damage Mod",
		desc   = "Percent modifier for chicken damage",
		type   = "number",
		def    = 100,
		min    = 5,
		max    = 250,
		step   = 1,
		section= "chicken_defense_custom_settings",
	},
-- End Chicken Defense Settings
}
return options
