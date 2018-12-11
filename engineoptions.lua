--  Custom Options Definition Table format

--  NOTES:
--  - using an enumerated table lets you specify the options order

--
--  These keywords must be lowercase for LuaParser to read them.
--
--  key:      the string used in the script.txt, must be lower case
--  name:     the displayed name
--  desc:     the description (could be used as a tooltip)
--  type:     the option type
--  def:      the default value
--  min:      minimum value for number options
--  max:      maximum value for number options
--  step:     quantization step, aligned to the def value
--  maxlen:   the maximum string length for string options
--  items:    array of item strings for list options
--  scope:    'global', 'player', 'team', 'allyteam'
--

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Example EngineOptions.lua
--

local options =
{
  {
    key="ba_others",
    name="Balanced Annihilation - Other Settings",
    name="Balanced Annihilation - Other Settings",
    type="section",
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
    section= "ba_options",

  },
  {
    key     = "pathfinder",
    name    = "Pathfinder",
    desc    = "Switch Pathfinding System",
    type    = "list",
    def     = "normal",
    section = "ba_others",
	items={
	  {key="normal", name="Normal", desc="Spring vanilla pathfinder"},
	  {key="qtpfs", name="QuadTree", desc="Experimental quadtree based pathfinder"},
	},
  },
  {
    key    = "startmetal",
    name   = "Starting metal",
    desc   = "Determines amount of metal and metal storage that each player will start with",
    type   = "number",
    section= "StartingResources",
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
    section= "StartingResources",
    def    = 1000,
    min    = 0,
    max    = 10000,
    step   = 1,
  },  
  {
    key    = 'LimitSpeed',
    name   = 'Speed Restriction',
    desc   = 'Limits maximum and minimum speed that the players will be allowed to change to',
    type   = 'section',
  },
  {
    key    = 'MaxSpeed',
    name   = 'Maximum game speed',
    desc   = 'Sets the maximum speed that the players will be allowed to change to',
    type   = 'number',
    section= 'LimitSpeed',
    def    = 5,
    min    = 0.1,
    max    = 100,
    step   = 0.1,

  },

  {
    key    = 'MinSpeed',
    name   = 'Minimum game speed',
    desc   = 'Sets the minimum speed that the players will be allowed to change to',
    type   = 'number',
    section= 'LimitSpeed',
    def    = 0.3,
    min    = 0.1,
    max    = 100,
    step   = 0.1,  
  },
  {
    key    = 'DisableMapDamage',
    name   = 'Undeformable map',
    desc   = 'Prevents the map shape from being changed by weapons',
    type   = 'bool',
    def    = false,
    section= "ba_options",

  },
--[[
-- the following options can create problems and were never used by interface programs, thus are commented out for the moment

  {
    key    = 'NoHelperAIs',
    name   = 'Disable helper AIs',
    desc   = 'Disables luaui ai usage for all players',
    type   = 'bool',
    def    = false,
  },
--]]
}

return options
