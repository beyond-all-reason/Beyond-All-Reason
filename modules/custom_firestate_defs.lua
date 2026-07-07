local customFirestateDefs = {
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
	[0] = customFirestateDefs.HOLD_FIRE,
	[1] = customFirestateDefs.DEFEND,
	[2] = customFirestateDefs.AGGRESSIVE,
}

local displayIndexByState = {
	[customFirestateDefs.HOLD_FIRE] = 0,
	[customFirestateDefs.DEFEND] = 1,
	[customFirestateDefs.AGGRESSIVE] = 2,
}

local engineFirestateByState = {
	[customFirestateDefs.HOLD_FIRE] = customFirestateDefs.ENGINE_HOLD_FIRE,
	[customFirestateDefs.DEFEND] = customFirestateDefs.ENGINE_FIRE_AT_WILL,
	[customFirestateDefs.RETURN_FIRE] = customFirestateDefs.ENGINE_RETURN_FIRE,
	[customFirestateDefs.AGGRESSIVE] = customFirestateDefs.ENGINE_FIRE_AT_WILL,
	[customFirestateDefs.FIRE_AT_ALL] = customFirestateDefs.ENGINE_FIRE_AT_ALL,
}

local stateByEngineFirestate = {
	[customFirestateDefs.ENGINE_HOLD_FIRE] = customFirestateDefs.HOLD_FIRE,
	[customFirestateDefs.ENGINE_RETURN_FIRE] = customFirestateDefs.RETURN_FIRE,
	[customFirestateDefs.ENGINE_FIRE_AT_WILL] = customFirestateDefs.AGGRESSIVE,
	[customFirestateDefs.ENGINE_FIRE_AT_ALL] = customFirestateDefs.FIRE_AT_ALL,
}

function customFirestateDefs.isUserFacing(state)
	return displayIndexByState[state] ~= nil
end

function customFirestateDefs.displayIndex(state)
	return displayIndexByState[state]
end

function customFirestateDefs.stateFromDisplayIndex(displayIndex)
	return stateByDisplayIndex[displayIndex]
end

function customFirestateDefs.toEngineFirestate(state)
	return engineFirestateByState[state]
end

function customFirestateDefs.fromEngineFirestate(engineFirestate)
	return stateByEngineFirestate[tonumber(engineFirestate)] or customFirestateDefs.AGGRESSIVE
end

function customFirestateDefs.buildUserFirestateParams(userState, userInitiated)
	return { userState, userInitiated and 1 or 0 }
end

function customFirestateDefs.parseUserFirestateParams(cmdParams)
	if not cmdParams then
		return nil, false
	end
	local userState = tonumber(cmdParams[1])
	if userState == nil then
		return nil, false
	end
	local userInitiatedParam = cmdParams[customFirestateDefs.PARAM_USER_INITIATED]
	local userInitiated = true
	if userInitiatedParam ~= nil then
		userInitiated = tonumber(userInitiatedParam) ~= 0
	end
	return userState, userInitiated
end

function customFirestateDefs.getUnitUserFirestate(unitID)
	if not Spring.ValidUnitID(unitID) then
		return nil
	end
	if Spring.GetModOptions().experimental_defend_firestate then
		local rulesState = Spring.GetUnitRulesParam(unitID, customFirestateDefs.RULES_PARAM)
		if rulesState ~= nil then
			return rulesState
		end
	end
	return customFirestateDefs.fromEngineFirestate(select(1, Spring.GetUnitStates(unitID, false)))
end

function customFirestateDefs.stateLabel(cmd)
	local currentStateIndex = tonumber(cmd.params[1])
	if currentStateIndex == nil then
		return nil
	end
	return cmd.params[currentStateIndex + 2]
end

function customFirestateDefs.orderMenuCmdDesc(command, userFirestate)
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
	if userFirestate == customFirestateDefs.RETURN_FIRE then
		cmdDesc.params[1] = 1
		cmdDesc.params[3] = "Return fire"
		cmdDesc.pipFillMin = 2
		cmdDesc.pipFillMax = 3
	elseif userFirestate == customFirestateDefs.FIRE_AT_ALL then
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

return customFirestateDefs
