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
			Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Action missing type: " .. actionId)
		end

		for _, parameter in pairs(parameters[action.type]) do
			local value = action.parameters[parameter.name]
			local parameterType = type(value)

			if value == nil and parameter.required then
				Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Action missing required parameter. Action: " .. actionId .. ", Parameter: " .. parameter.name)
			end

			-- Unit
			if value ~= nil and parameter.type == 'unit' then
				if parameterType ~= 'table' then
					Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Unexpected parameter type, expected 'table', got " .. parameterType .. ". Action: " .. actionId .. ", Parameter: " .. parameter.name)
				else
					local fieldType = type(value.type)
					if value.type == nil then
						Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Parameter missing field 'type'. Expected 'number'. Action: " .. actionId .. ", Parameter: " .. parameter.name)
					elseif fieldType ~= 'number' then
						Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Unexpected type in action parameter field 'type'. Expected 'number', got " .. fieldType .. ". Action: " .. actionId .. ", Parameter: " .. parameter.name)
					end

					fieldType = type(value.unit)
					if value.unit == nil then
						Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Parameter missing field 'unit'. Action: " .. actionId .. ", Parameter: " .. parameter.name)
					elseif (value.type == 0 or value.type == 3) and fieldType ~= 'string' then
						Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Unexpected type in action parameter field 'unit'. Expected 'string', got " .. fieldType .. ". Action: " .. actionId .. ", Parameter: " .. parameter.name)
					elseif (value.type == 1 or value.type == 2) and fieldType ~= 'number' then
						Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Unexpected type in action parameter field 'unit'. Expected 'number', got " .. fieldType .. ". Action: " .. actionId .. ", Parameter: " .. parameter.name)
					end

					fieldType = type(value.team)
					if value.team ~= nil and fieldType ~= 'number' then
						Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Unexpected type in action parameter field 'team'. Expected 'number', got " .. fieldType .. ". Action: " .. actionId .. ", Parameter: " .. parameter.name)
					end
				end

			-- UnitDef
			elseif value ~= nil and parameter.type == 'unitDef' then
				if parameterType ~= 'table' then
					Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Unexpected parameter type, expected 'table', got " .. parameterType .. ". Action: " .. actionId .. ", Parameter: " .. parameter.name)
				else
					local fieldType = type(value.type)
					if value.type == nil then
						Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Parameter missing field 'type'. Expected 'number'. Action: " .. actionId .. ", Parameter: " .. parameter.name)
					elseif fieldType ~= 'number' then
						Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Unexpected type in action parameter field 'type'. Expected 'number', got " .. fieldType .. ". Action: " .. actionId .. ", Parameter: " .. parameter.name)
					end

					fieldType = type(value.unitDef)
					if value.unitDef == nil then
						Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Parameter missing field 'unitDef'. Action: " .. actionId .. ", Parameter: " .. parameter.name)
					elseif value.type == 0 and fieldType ~= 'string' then
						Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Unexpected type in action parameter field 'unitDef'. Exptected 'string', got " .. fieldType .. ". Action: " .. actionId .. ", Parameter: " .. parameter.name)
					elseif value.type == 1 and fieldType ~= 'number' then
						Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Unexpected type in action parameter field 'unitDef'. Expected 'number', got " .. fieldType .. ". Action: " .. actionId .. ", Parameter: " .. parameter.name)
					end

					fieldType = type(value.team)
					if value.team ~= nil and fieldType ~= 'number' then
						Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Unexpected type in action parameter field 'team'. Expected 'number', got " .. fieldType .. ". Action: " .. actionId .. ", Parameter: " .. parameter.name)
					end
				end

			-- Vec3
			elseif value ~= nil and parameter.type == 'vec3' then
				if parameterType ~= 'table' then
					Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Unexpected parameter type, expected 'table', got " .. parameterType .. ". Action: " .. actionId .. ", Parameter: ", parameter.name)
				elseif #value ~= 3 then
					Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Unexpected array length in 'vec3', expected 3, got " .. #value .. ". Action: " .. actionId .. ", Parameter: " .. parameter.name)
				end

			-- Direction
			elseif value ~= nil and parameter.type == 'direction' then
				if parameterType ~= 'string' then
					Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Unexpected parameter type, expected 'direction'(string), got " .. parameterType .. ". Action: " .. actionId .. ", Parameter: ", parameter.name)
				elseif value ~= 'north' and value ~= 'south' and value ~= 'east' and value ~= 'west' then
					Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Unexpected value '" .. value .. "'' in 'direction'. Valid values are 'north', 'south', 'east', 'west'. Action: " .. actionId .. ", Parameter: ", parameter.name)
				end

			-- Lua Types
			elseif value ~= nil and parameterType ~= parameter.type then
				Spring.Log('actions_loader.lua', LOG.ERROR, "[Mission API] Unexpected parameter type, expected " .. parameter.type .. ", got " .. parameterType .. ". Action: " .. actionId .. ", Parameter: " .. parameter.name)
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