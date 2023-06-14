local schema = VFS.Include('luarules/mission_api/actions_schema.lua')
local parameters = schema.Parameters

--[[
	actionId = {
		type = actionTypes.EnableTrigger,
		parameters = {
			triggerId = 'triggerId'
		}
	}
]]

local actions = {}

local function prevalidateActions()
	for actionId, action in pairs(actions) do
		if not action.type then
			Spring.Log('actions.lua', LOG.ERROR, "[Mission API] Action missing type: " .. actionId)
		end

		for _, parameter in pairs(parameters[action.type]) do
			local value = action.parameters[parameter.name]
			local type = type(value)

			if value == nil and parameter.required then
				Spring.Log('actopms.lua', LOG.ERROR, "[Mission API] Action missing required parameter. Action: " .. actionId .. ", Parameter: " .. parameter.name)
			end

			if value ~= nil and type ~= parameter.type then
				Spring.Log('actopms.lua', LOG.ERROR, "[Mission API] Unexpected parameter type, expected " .. parameter.type .. ", got " .. type .. ". Action: " .. actionId .. ", Parameter: " .. parameter.name)
			end
		end
	end
end

local function preprocessRawActions(rawActions)
	for actionId, rawAction in pairs(rawActions) do	
		actions[actionId] = table.copy(rawAction)
	end

	prevalidateActions()
end

local function getActions()
	return actions
end

return {
	GetActions = getActions,
	PreprocessRawActions = preprocessRawActions,
}