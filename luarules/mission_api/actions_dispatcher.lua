local actionDefinitions = GG["MissionAPI"].ActionDefinitions
local actionFunctions = actionDefinitions.Functions
local parameterSchema = actionDefinitions.Parameters
local actions = GG["MissionAPI"].Actions

-- unpack() does not handle optional parameters, as it cannot pass a value as nil
local function unpackActionParameters(actionId, i)
	local type = actions[actionId].type
	local schema = parameterSchema[type]

	i = i or 1

	if i <= #schema then
		-- valueKey is ID resolved from the name the author wrote, i.e. (ally)teamID
		local parameterValue = actions[actionId].parameters[schema[i].valueKey]
		return parameterValue, unpackActionParameters(actionId, i + 1)
	end
end

local function invoke(actionId)
	local type = actions[actionId].type
	local actionFunction = actionFunctions[type]

	actionFunction(unpackActionParameters(actionId))
end

return {
	Invoke = invoke,
}
