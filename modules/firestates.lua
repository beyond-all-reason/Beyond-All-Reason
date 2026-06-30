local firestates = {
	RULES_PARAM = "user_firestate",

	PASSIVE = 0,
	DEFENSIVE = 1,
	RETURN_FIRE = 2,
	AGGRESSIVE = 3,
	FIRE_AT_ALL = 4,

	ENGINE_HOLD_FIRE = 0,
	ENGINE_RETURN_FIRE = 1,
	ENGINE_FIRE_AT_WILL = 2,
	ENGINE_FIRE_AT_ALL = 3,
}

local userFacingStateByDisplayIndex = {
	[0] = firestates.PASSIVE,
	[1] = firestates.DEFENSIVE,
	[2] = firestates.AGGRESSIVE,
}

local displayIndexByUserFacingState = {
	[firestates.PASSIVE] = 0,
	[firestates.DEFENSIVE] = 1,
	[firestates.AGGRESSIVE] = 2,
}

local engineFirestateByState = {
	[firestates.PASSIVE] = firestates.ENGINE_HOLD_FIRE,
	[firestates.DEFENSIVE] = firestates.ENGINE_FIRE_AT_WILL,
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
	return displayIndexByUserFacingState[state] ~= nil
end

function firestates.userFacingDisplayIndex(state)
	return displayIndexByUserFacingState[state]
end

function firestates.userFacingStateFromDisplayIndex(displayIndex)
	return userFacingStateByDisplayIndex[displayIndex]
end

function firestates.nextUserFacing(state, direction)
	local displayIndex = displayIndexByUserFacingState[state]
	if not displayIndex then
		displayIndex = 0
	end
	direction = direction or 1
	displayIndex = displayIndex + direction
	if displayIndex > 2 then
		displayIndex = 0
	elseif displayIndex < 0 then
		displayIndex = 2
	end
	return userFacingStateByDisplayIndex[displayIndex]
end

function firestates.engineFirestateFor(state)
	return engineFirestateByState[state]
end

function firestates.logicalFromEngineFirestate(engineFirestate)
	return stateByEngineFirestate[engineFirestate] or firestates.AGGRESSIVE
end

--DEFEND FIRESTATE REWORK: Remove isDefendFirestateEnabled(); assume Defend mode always on
function firestates.isDefendFirestateEnabled()
	return Spring.GetModOptions().experimental_defend_firestate
end

return firestates
