-- List of stateful commands and their states, because command descriptions do not exist outside of
-- a unit existing, and are mutable per unit, thus this data cannot be derived
-- A state is a CMD constant by name, or its number where CMD names none.
return {
	-- Engine
	FIRE_STATE = {
		"FIRESTATE_HOLDFIRE",
		"FIRESTATE_RETURNFIRE",
		"FIRESTATE_FIREATWILL",
		"FIRESTATE_FIREATNEUTRAL",
	},
	MOVE_STATE = {
		"MOVESTATE_HOLDPOS",
		"MOVESTATE_MANEUVER",
		"MOVESTATE_ROAM",
	},
	ONOFF = { 0, 1 },
	REPEAT = { 0, 1 },
	CLOAK = { 0, 1 },
	TRAJECTORY = { 0, 1 }, -- low, high
	IDLEMODE = { 0, 1 }, -- fly, land
	AUTOREPAIRLEVEL = { 0, 1, 2, 3 }, -- find a repair pad below 0, 30, 50, 80% health
	-- Game
	USER_FIRESTATE = { 0, 1, 2, 3, 4 }, -- hold fire, defend, return fire, fire at will, fire at all
	WANT_CLOAK = { 0, 1 },
	PRIORITY = { 0, 1 }, -- low, high
	FACTORY_GUARD = { 0, 1 },
	QUOTA_BUILD_TOGGLE = { 0, 1 }, -- normal queue, quota
	CARRIER_SPAWN_ONOFF = { 0, 1 },
	SMART_TOGGLE = { 0, 1, 2 }, -- low, high, auto trajectory
}
