--
-- Validators for Mission API action and trigger parameters loaded from missions.
--

local function logError(message)
	Spring.Log('validation.lua', LOG.ERROR, "[Mission API] " .. message)
end

function validateParameters(schemaParameters, actionOrTriggerType, actionOrTriggerParameters, actionOrTrigger, actionOrTriggerID)
	if not actionOrTriggerType then
		logError(actionOrTrigger .. " missing type. " .. actionOrTrigger .. ": " .. actionOrTriggerID)
	elseif not schemaParameters[actionOrTriggerType] then
		logError(actionOrTrigger .. " has invalid type. " .. actionOrTrigger .. ": " .. actionOrTriggerID)
	else
		for _, parameter in pairs(schemaParameters[actionOrTriggerType]) do
			local value = actionOrTriggerParameters[parameter.name]

			if value == nil and parameter.required then
				logError(actionOrTrigger .. " missing required parameter. " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameter.name)
			else
				parameter.type(value, 'Action', actionOrTriggerID, parameter.name)
			end
		end
	end
end

local function validateLuaType(value, expectedType, actionOrTrigger, actionOrTriggerID, parameterName)
	local actualType = type(value)
	if value ~= nil and actualType ~= expectedType then
		logError("Unexpected parameter type, expected " ..expectedType ..", got " .. actualType .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameterName)
		return false
	end
	return true
end

local function validateField(value, fieldName, expectedType, actionOrTrigger, actionOrTriggerID, parameterName)
	if not value then
		logError("Action missing required parameter. " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameterName .. "." .. fieldName)
		return false
	end
	if type(value) ~= expectedType then
		logError("Unexpected parameter type, expected " .. expectedType .. ", got " .. type(value) .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameterName .. "." .. fieldName)
		return false
	end
	return true
end

Types = {

	----------------------------------------------------------------
	--- Table Validators:
	----------------------------------------------------------------

	table = function(table, actionOrTrigger, actionOrTriggerID, parameterName)
		return validateLuaType(table, 'table', actionOrTrigger, actionOrTriggerID, parameterName)
	end,

	position = function(position, actionOrTrigger, actionOrTriggerID, parameterName)
		if not Types.table(position, actionOrTrigger, actionOrTriggerID, parameterName) then
			return false
		end

		for _, parm in pairs({"x", "z"}) do
			if not validateField(position[parm], parm, 'number', actionOrTrigger, actionOrTriggerID, parameterName) then
				return false
			end
		end

		position.y = position.y or Spring.GetGroundHeight(position.x, position.z)

		if not validateField(position.y, 'y', 'number', actionOrTriggerID, parameterName) then
			return false
		end

		return true
	end,

	allyTeamIDs = function(allyTeamIDs, actionOrTrigger, actionOrTriggerID, parameterName)
		if not Types.table(allyTeamIDs, actionOrTrigger, actionOrTriggerID, parameterName) then
			return false
		end

		if table.isNilOrEmpty(allyTeamIDs) then
			logError("allyTeamIDs table is empty. " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameterName)
			return false
		end

		for i, allyTeamID in pairs(allyTeamIDs) do
			if not validateField(allyTeamID, "allyTeamID #" .. i, 'number', actionOrTrigger, actionOrTriggerID, parameterName) then
				return false
			end

			if not Spring.GetAllyTeamInfo(allyTeamID) then
				logError("Invalid allyTeamID: " .. allyTeamID .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameterName)
				return false
			end
		end

		return true
	end,

	----------------------------------------------------------------
	--- String Validators:
	----------------------------------------------------------------

	string = function(string, actionOrTrigger, actionOrTriggerID, parameterName)
		return validateLuaType(string, 'string', actionOrTrigger, actionOrTriggerID, parameterName)
	end,

	triggerID = function(triggerID, actionOrTrigger, actionOrTriggerID, parameterName)
		if not Types.string(triggerID, actionOrTrigger, actionOrTriggerID, parameterName) then
			return false
		end

		if not GG['MissionAPI'].Triggers[triggerID] then
			logError("Invalid triggerID: " .. triggerID .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID)
			return false
		end
	end,

	unitDefName = function(unitDefName, actionOrTrigger, actionOrTriggerID, parameterName)
		if not Types.string(unitDefName, actionOrTrigger, actionOrTriggerID, parameterName) then
			return false
		end

		if not UnitDefNames[unitDefName] then
			logError("Invalid unitDefName: " .. unitDefName .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID)
			return false
		end
	end,

	facing = function(facing, actionOrTrigger, actionOrTriggerID, _)
		local validFacings = { n = true, s = true, e = true, w = true }
		if not validFacings[facing] then
			logError("Invalid facing: " .. facing .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID)
			return false
		end
	end,

	----------------------------------------------------------------
	--- Number Validators:
	----------------------------------------------------------------

	number = function(number, actionOrTrigger, actionOrTriggerID, parameterName)
		return validateLuaType(number, 'number', actionOrTrigger, actionOrTriggerID, parameterName)
	end,

	teamID = function(teamID, actionOrTrigger, actionOrTriggerID, parameterName)
		if not Types.number(teamID, actionOrTrigger, actionOrTriggerID, parameterName) then
			return false
		end

		if not Spring.GetTeamAllyTeamID(teamID) then
			logError("Invalid teamID: " .. teamID .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameterName)
			return false
		end
	end,

	----------------------------------------------------------------
	--- Boolean Validators:
	----------------------------------------------------------------

	boolean = function(boolean, actionOrTrigger, actionOrTriggerID, parameterName)
		return validateLuaType(boolean, 'boolean', actionOrTrigger, actionOrTriggerID, parameterName)
	end,

	----------------------------------------------------------------
	--- Function Validators:
	----------------------------------------------------------------

	customFunction = function(func, actionOrTrigger, actionOrTriggerID, parameterName)
		return validateLuaType(func, 'function', actionOrTrigger, actionOrTriggerID, parameterName)
	end,
}
