local actionsSchema = VFS.Include('luarules/mission_api/actions_schema.lua')
local actionFunctions = VFS.Include('luarules/mission_api/actions.lua')
local parameterSchema = actionsSchema.Parameters
local types = GG['MissionAPI'].ActionTypes
local actions = GG['MissionAPI'].Actions

local typeMapping = {}
for name, typeId in pairs(types) do
	if actionFunctions[name] then
		typeMapping[typeId] = actionFunctions[name]
	end
end

-- unpack() does not handle optional parameters, as it cannot pass a value as nil
local function unpackActionParameters(actionId, i)
	local type = actions[actionId].type
	local schema = parameterSchema[type]

	i = i or 1

	if i <= #schema then
		local parameterValue = actions[actionId].parameters[schema[i].name]
		return parameterValue, unpackActionParameters(actionId, i + 1)
	end
end

local function invoke(actionId)
	local type = actions[actionId].type
	local actionFunction = typeMapping[type]

	actionFunction(unpackActionParameters(actionId))
end

return {
	Invoke = invoke,
}
