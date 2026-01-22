local schema = VFS.Include('luarules/mission_api/actions_schema.lua')
local parameters = schema.Parameters

--[[
	actionID = {
		type = actionTypes.EnableTrigger,
		parameters = {
			triggerID = 'triggerID'
		}
	}
]]

local function validateActions(actions)
	for actionID, action in pairs(actions) do
		if not action.type then
			Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Action missing type: " .. actionID)
		end

		for _, parameter in pairs(parameters[action.type]) do
			local value = action.parameters[parameter.name]

			if value == nil and parameter.required then
				Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Action missing required parameter. Action: " ..actionID .. ", Parameter: " .. parameter.name)
			end

			if value ~= nil then
				local expectedType = parameter.type
				local actualType = type(value)

				if actualType ~= expectedType then
					Spring.Log('actions_loader.lua', LOG.ERROR,"[Mission API] Unexpected parameter type, expected " ..parameter.type ..", got " .. actualType .. ". Action: " .. actionID .. ", Parameter: " .. parameter.name)
				end
			end

			if parameter.validator then
				parameter.validator(value, 'Action', actionID, parameter.name)
			end
		end
	end
end

local function processRawActions(rawActions)
	local actions = table.map(rawActions, table.copy)
	validateActions(actions)
	return actions
end

return {
	ProcessRawActions = processRawActions,
}
