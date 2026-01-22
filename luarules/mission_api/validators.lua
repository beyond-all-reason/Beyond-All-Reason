local function logError(message)
	Spring.Log('validators.lua', LOG.ERROR, "[Mission API] " .. message)
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

validators = {

	----------------------------------------------------------------
	--- Table Validators:
	----------------------------------------------------------------

	position = function(position, actionOrTrigger, actionOrTriggerID, parameterName)

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

	triggerID = function(triggerID, actionOrTrigger, actionOrTriggerID, parameterName)
		if not GG['MissionAPI'].Triggers[triggerID] then
			logError("Invalid triggerID: " .. triggerID .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID)
			return false
		end
	end,

	unitDefName = function(unitDefName, actionOrTrigger, actionOrTriggerID, parameterName)
		if not UnitDefNames[unitDefName] then
			logError("Invalid unitDefName: " .. unitDefName .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID)
			return false
		end
	end,

	facing = function(facing, actionOrTrigger, actionOrTriggerID, parameterName)
		local validFacings = { n = true, s = true, e = true, w = true }
		if not validFacings[facing] then
			logError("Invalid facing: " .. facing .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID)
			return false
		end
	end,

	----------------------------------------------------------------
	--- Number Validators:
	----------------------------------------------------------------

	teamID = function(teamID, actionOrTrigger, actionOrTriggerID, parameterName)
		if not Spring.GetTeamAllyTeamID(teamID) then
			logError("Invalid teamID: " .. teamID .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameterName)
			return false
		end
	end,
}
