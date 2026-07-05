local firestates = {
	RULES_PARAM = "user_firestate",
	PARAM_USER_INITIATED = 2,

	HOLD_FIRE = 0,
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
	[0] = firestates.HOLD_FIRE,
	[1] = firestates.DEFEND,
	[2] = firestates.AGGRESSIVE,
}

local displayIndexByState = {
	[firestates.HOLD_FIRE] = 0,
	[firestates.DEFEND] = 1,
	[firestates.AGGRESSIVE] = 2,
}

local engineFirestateByState = {
	[firestates.HOLD_FIRE] = firestates.ENGINE_HOLD_FIRE,
	[firestates.DEFEND] = firestates.ENGINE_FIRE_AT_WILL,
	[firestates.RETURN_FIRE] = firestates.ENGINE_RETURN_FIRE,
	[firestates.AGGRESSIVE] = firestates.ENGINE_FIRE_AT_WILL,
	[firestates.FIRE_AT_ALL] = firestates.ENGINE_FIRE_AT_ALL,
}

local stateByEngineFirestate = {
	[firestates.ENGINE_HOLD_FIRE] = firestates.HOLD_FIRE,
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
	return stateByEngineFirestate[tonumber(engineFirestate)] or firestates.AGGRESSIVE
end

function firestates.buildUserFirestateParams(userState, userInitiated)
	return { userState, userInitiated and 1 or 0 }
end

function firestates.parseUserFirestateParams(cmdParams)
	if not cmdParams then
		return nil, false
	end
	local userState = tonumber(cmdParams[1])
	if userState == nil then
		return nil, false
	end
	local userInitiatedParam = cmdParams[firestates.PARAM_USER_INITIATED]
	local userInitiated = true
	if userInitiatedParam ~= nil then
		userInitiated = tonumber(userInitiatedParam) ~= 0
	end
	return userState, userInitiated
end

function firestates.resolveUserFirestate(unitID)
	if not Spring.ValidUnitID(unitID) then
		return nil
	end
	if Spring.GetModOptions().experimental_defend_firestate then
		local rulesState = Spring.GetUnitRulesParam(unitID, firestates.RULES_PARAM)
		if rulesState ~= nil then
			return rulesState
		end
	end
	return firestates.fromEngineFirestate(select(1, Spring.GetUnitStates(unitID, false)))
end

function firestates.stateLabel(cmd)
	local currentStateIndex = tonumber(cmd.params[1])
	if currentStateIndex == nil then
		return nil
	end
	return cmd.params[currentStateIndex + 2]
end

function firestates.orderMenuCmdDesc(command, userFirestate)
	if userFirestate == nil then
		return nil
	end
	local cmdDesc = table.copy(command)
	local middleLabel = Spring.GetModOptions().experimental_defend_firestate and "Defend" or "Return fire"
	cmdDesc.params = {
		0,
		"Hold fire",
		middleLabel,
		"Fire at will",
	}
	cmdDesc.pipFillMin = nil
	cmdDesc.pipFillMax = nil
	if userFirestate == firestates.RETURN_FIRE then
		cmdDesc.params[1] = 1
		cmdDesc.params[3] = "Return fire"
		cmdDesc.pipFillMin = 2
		cmdDesc.pipFillMax = 3
	elseif userFirestate == firestates.FIRE_AT_ALL then
		cmdDesc.params[1] = 2
		cmdDesc.params[4] = "Fire at all"
		cmdDesc.pipFillMin = 1
		cmdDesc.pipFillMax = 3
	else
		local displayIndex = displayIndexByState[userFirestate]
		if displayIndex == nil then
			return nil
		end
		cmdDesc.params[1] = displayIndex
	end
	return cmdDesc
end

return firestates
