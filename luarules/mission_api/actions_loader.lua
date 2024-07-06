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

-- Custom Types & validation logic for Vec2 and Direction
if value ~= nil and GG['MissionAPI'].Types[parameter.type] then
    local expectedType = GG['MissionAPI'].Types[parameter.type].__name

    local valueType = type(value)

    if valueType == 'table' then
        if expectedType == 'Vec2' then
            if value.x and value.z then
                Spring.Log('actions_loader.lua', LOG.INFO, "[Mission API] Expected parameter type: " .. expectedType .. ", successfully detected Vec2.")
            else
                Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Vec2 object missing x and z properties. Action: " .. actionID .. ", Parameter: " .. parameter.name)
            end
		elseif expectedType == 'Direction' then
			if value.north == 'n' or value.south == 's' or value.west == 'w' or value.east == 'e' then
				Spring.Log('actions_loader.lua', LOG.INFO, "[Mission API] Expected parameter type: " .. expectedType .. ", successfully detected Direction.")
			else
				Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Direction object missing valid properties (n, s, w, e). Action: " .. actionID .. ", Parameter: " .. parameter.name)
			end
		else
			Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Unexpected parameter type, expected " .. parameter.type .. ", got unknown type. Action: " .. actionID .. ", Parameter: " .. parameter.name)
		end
		else
			Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Invalid value or type for parameter: " .. parameter.name .. ". Action: " .. actionID)
		end

			-- Lua Types
			elseif value ~= nil and parameterType ~= parameter.type then
				Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Unexpected parameter type3, expected " .. parameter.type .. ", got " .. parameterType .. ". Action: " .. actionID .. ", Parameter: " .. parameter.name)
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