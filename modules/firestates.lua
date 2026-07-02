local firestates = {
	RULES_PARAM = "user_firestate",

	PASSIVE = 0,
	DEFEND = 1,
	RETURN_FIRE = 2,
	AGGRESSIVE = 3,
	FIRE_AT_ALL = 4,

	ENGINE_HOLD_FIRE = 0,
	ENGINE_RETURN_FIRE = 1,
	ENGINE_FIRE_AT_WILL = 2,
	ENGINE_FIRE_AT_ALL = 3,
}

local stateByDisplayIndex = {
	[0] = firestates.PASSIVE,
	[1] = firestates.DEFEND,
	[2] = firestates.AGGRESSIVE,
}

local displayIndexByState = {
	[firestates.PASSIVE] = 0,
	[firestates.DEFEND] = 1,
	[firestates.AGGRESSIVE] = 2,
}

local engineFirestateByState = {
	[firestates.PASSIVE] = firestates.ENGINE_HOLD_FIRE,
	[firestates.DEFEND] = firestates.ENGINE_FIRE_AT_WILL,
	[firestates.RETURN_FIRE] = firestates.ENGINE_RETURN_FIRE,
	[firestates.AGGRESSIVE] = firestates.ENGINE_FIRE_AT_WILL,
	[firestates.FIRE_AT_ALL] = firestates.ENGINE_FIRE_AT_ALL,
}

local stateByEngineFirestate = {
	[firestates.ENGINE_HOLD_FIRE] = firestates.PASSIVE,
	[firestates.ENGINE_RETURN_FIRE] = firestates.RETURN_FIRE,
	[firestates.ENGINE_FIRE_AT_WILL] = firestates.AGGRESSIVE,
	[firestates.ENGINE_FIRE_AT_ALL] = firestates.FIRE_AT_ALL,
}

function firestates.isUserFacing(state)
	return displayIndexByState[state] ~= nil
end

function firestates.displayIndex(state)
	return displayIndexByState[state]
end

function firestates.stateFromDisplayIndex(displayIndex)
	return stateByDisplayIndex[displayIndex]
end

function firestates.toEngineFirestate(state)
	return engineFirestateByState[state]
end

function firestates.fromEngineFirestate(engineFirestate)
	return stateByEngineFirestate[engineFirestate] or firestates.AGGRESSIVE
end

return firestates
