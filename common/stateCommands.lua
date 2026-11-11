-- The commands that set a unit state, by their CMD or GameCMD name, and the values each takes.
-- Command descriptions differ per unit and can change, so the engine has no list to read; this one
-- is kept by hand. Add a new state command of the game here.
return {
	-- Engine
	FIRE_STATE = { 0, 1, 2, 3 }, -- hold fire, return fire, fire at will, fire at neutral
	MOVE_STATE = { 0, 1, 2 }, -- hold position, maneuver, roam
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
