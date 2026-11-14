-- Stateful commands and their states, each state by name with the number the command takes.
-- Command descriptions exist only on a living unit and change per unit, so this is not derived.
local userFirestate = require("modules/custom_firestate_defs")

local OFF_ON = { OFF = 0, ON = 1 }

return {
	-- Engine
	FIRE_STATE = { HOLD_FIRE = 0, RETURN_FIRE = 1, FIRE_AT_WILL = 2, FIRE_AT_NEUTRAL = 3 },
	MOVE_STATE = { HOLD_POSITION = 0, MANEUVER = 1, ROAM = 2 },
	ONOFF = OFF_ON,
	REPEAT = OFF_ON,
	CLOAK = OFF_ON,
	TRAJECTORY = { LOW = 0, HIGH = 1 },
	IDLEMODE = { FLY = 0, LAND = 1 },
	-- Health percent below which an aircraft lands for repair.
	AUTOREPAIRLEVEL = { LAND_AT_0 = 0, LAND_AT_30 = 1, LAND_AT_50 = 2, LAND_AT_80 = 3 },
	-- Game
	USER_FIRESTATE = {
		HOLD_FIRE = userFirestate.HOLD_FIRE,
		DEFEND = userFirestate.DEFEND,
		RETURN_FIRE = userFirestate.RETURN_FIRE,
		FIRE_AT_WILL = userFirestate.FIRE_AT_WILL,
		FIRE_AT_ALL = userFirestate.FIRE_AT_ALL,
	},
	WANT_CLOAK = OFF_ON,
	PRIORITY = { LOW = 0, HIGH = 1 },
	FACTORY_GUARD = OFF_ON,
	QUOTA_BUILD_TOGGLE = { NORMAL = 0, QUOTA = 1 },
	CARRIER_SPAWN_ONOFF = OFF_ON,
	SMART_TOGGLE = { LOW = 0, HIGH = 1, AUTO = 2 },
}
