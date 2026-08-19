local actionDefinitions = GG['MissionAPI'].ActionDefinitions
local actionFunctions = actionDefinitions.Functions
local parameterSchema = actionDefinitions.Parameters
local actions = GG['MissionAPI'].Actions


-- unpack() does not handle optional parameters, as it cannot pass a value as nil
local function unpackActionParameters(action, mappedValues, i)
	local schema = parameterSchema[action.type]

	i = i or 1

	if i <= #schema then
		local parameterName = schema[i].name
		local parameterValue = action.parameters[parameterName] or mappedValues[parameterName]
		return parameterValue, unpackActionParameters(action, mappedValues, i + 1)
	end
end

local function invoke(actionId, providedValues)
	local action = actions[actionId]
	local actionFunction = actionFunctions[action.type]

	local mappedValues = {}
	if action.provided then
		for k, value in pairs(providedValues or {}) do
			if action.provided[k] then
				mappedValues[action.provided[k]] = value
			end
		end
	end

	actionFunction(unpackActionParameters(action, mappedValues))
end

return {
	Invoke = invoke,
}
