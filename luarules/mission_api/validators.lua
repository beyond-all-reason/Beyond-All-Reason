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

	----------------------------------------------------------------
	--- String Validators:
	----------------------------------------------------------------

	triggerID = function(triggerID, actionOrTrigger, actionOrTriggerID, parameterName)
		if not GG['MissionAPI'].Triggers[triggerID] then
			logError("Invalid triggerID: " .. triggerID .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID)
			return false
		end
	end,
}
