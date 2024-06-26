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

local actions = {}

local function prevalidateActions()
	for actionID, action in pairs(actions) do
		if not action.type then
			Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Action missing type: " .. actionID)
		end

		for _, parameter in pairs(parameters[action.type]) do
			local value = action.parameters[parameter.name]
			local parameterType = type(value)

			if value == nil and parameter.required then
				Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Action missing required parameter. Action: " .. actionID .. ", Parameter: " .. parameter.name)
			end

			-- Custom Types
			if value ~= nil and GG['MissionAPI'].Types[parameter.type] then
				if value.__name ~= parameter.type then
					local actualType = value.__name or type(value)
					Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Unexpected parameter type, expected " .. parameter.type .. ", got " .. actualType .. ". Action: " .. actionID .. ", Parameter: " .. parameter.name)
				elseif value.validate then 
					value.validate('actions_loader.lua', 'Mission API') 
				end

			-- Lua Types
			elseif value ~= nil and parameterType ~= parameter.type then
				Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Unexpected parameter type, expected " .. parameter.type .. ", got " .. parameterType .. ". Action: " .. actionID .. ", Parameter: " .. parameter.name)
			end
		end
	end
end

local function preprocessRawActions(rawActions)
	for actionID, rawAction in pairs(rawActions) do	
		actions[actionID] = table.copy(rawAction)
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