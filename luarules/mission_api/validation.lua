---
--- Validators for Mission API action and trigger parameters loaded from missions.
---

local function logError(message)
	Spring.Log('validation.lua', LOG.ERROR, "[Mission API] " .. message)
end

local function validateLuaType(value, expectedType)
	local actualType = type(value)
	if value ~= nil and actualType ~= expectedType then
		return { "Unexpected parameter type, expected " .. expectedType .. ", got " .. actualType }
	end
	return
end

local function validateField(value, fieldName, expectedType)
	if not value then
		return { "Missing required parameter. ", "." .. fieldName }

	end
	if type(value) ~= expectedType then
		return { "Unexpected parameter type, expected " .. expectedType .. ", got " .. type(value), "." .. fieldName }
	end
	return
end

local Types = VFS.Include('luarules/mission_api/parameter_types.lua').Types

local function validateSimpleTypeCurried(expectedType)
	return function(value)
		local luaTypeResult = validateLuaType(value, expectedType)
		return luaTypeResult and { luaTypeResult } or nil
	end
end
local luaTypeValidators = {
	-- These need to be here to be available in customValidators below
	[Types.Table] = validateSimpleTypeCurried('table'),
	[Types.String] = validateSimpleTypeCurried('string'),
	[Types.Number] = validateSimpleTypeCurried('number'),
	[Types.Boolean] = validateSimpleTypeCurried('boolean'),
	[Types.Function] = validateSimpleTypeCurried('function'),
}

local customValidators = {

	----------------------------------------------------------------
	--- Table Validators:
	----------------------------------------------------------------

	[Types.Position] = function(position)
		local luaTypeResult = luaTypeValidators[Types.Table](position)
		if luaTypeResult then
			return luaTypeResult
		end

		local result = {}
		for _, field in pairs({ "x", "z"}) do
			local fieldResult = validateField(position[field], field, 'number')
			if fieldResult then
				result[#result + 1] = fieldResult
			end
		end

		if not table.isEmpty(result) then
			return result
		end

		position.y = position.y or Spring.GetGroundHeight(position.x, position.z)
		local fieldResult = validateField(position.y, 'y', 'number')
		if fieldResult then
			result[#result + 1] = fieldResult
		end

		return result
	end,

	[Types.AllyTeamIDs] = function(allyTeamIDs)
		local luaTypeResult = luaTypeValidators[Types.Table](allyTeamIDs)
		if luaTypeResult then
			return luaTypeResult
		end

		if table.isNilOrEmpty(allyTeamIDs) then
			return { { "allyTeamIDs table is empty. " } }
		end

		local result = {}
		for i, allyTeamID in pairs(allyTeamIDs) do
			local fieldResult = validateField(allyTeamID, "allyTeamID #" .. i, 'number')
			if fieldResult then
				result[#result + 1] = fieldResult
			elseif not Spring.GetAllyTeamInfo(allyTeamID) then
				result[#result + 1] = { "Invalid allyTeamID: " .. allyTeamID }
			end
		end

		return result
	end,

	[Types.Orders] = function(orders)

		local result = {}

		local function validateOrderCommandAndParams(commandID, params, orderNumber)
			local function validateNumberArrayCurried(sizes, message)
				return function()
					local luaTypeResult = validateLuaType(params, 'table')
					if luaTypeResult then
						result[#result + 1] = { luaTypeResult[1], '[' .. orderNumber .. '][2]' }
						return
					end
					if not table.contains(sizes, #(params or {})) then
						result[#result + 1] = { "Parameter must be an array of " .. message, '[' .. orderNumber .. '][2]' }
						return
					end
					for i = 1, 3 do
						local luaTypeRes = validateLuaType(params[i], 'number')
						if luaTypeRes then
							result[#result + 1] = { luaTypeRes[1], '[' .. orderNumber .. '][2][' .. i .. ']' }
							return
						end
					end
				end
			end
			local validate3 = validateNumberArrayCurried({ 3 }, "3 numbers {x, y, z}")
			local validate4 = validateNumberArrayCurried({ 4 }, "4 numbers {x, y, z, radius}")
			local validate3or4 = validateNumberArrayCurried({ 3, 4 }, "3 or 4 numbers {x, y, z, optional radius}")
			local function validateNumber()
				local luaTypeResult = validateLuaType(params, 'number')
				if luaTypeResult then
					result[#result + 1] = { luaTypeResult[1], '[' .. orderNumber .. '][2]' }
				end
			end
			local commandValidators = {
				-- No parameters:SpawnUnits:
				[CMD.STOP] = false,
				[CMD.SELFD] = false,
				[CMD.GUARD] = false,
				-- 3 number parameters:
				[CMD.DGUN] = validate3,
				[CMD.MOVE] = validate3,
				[CMD.FIGHT] = validate3,
				[CMD.PATROL] = validate3,
				-- 4 number parameters:
				[CMD.RECLAIM] = validate4,
				[CMD.RESURRECT] = validate4,
				[CMD.CAPTURE] = validate4,
				[CMD.AREA_ATTACK] = validate4,
				[CMD.RESTORE] = validate4,
				-- 3 or 4 number parameters:
				[CMD.ATTACK] = validate3or4,
				[CMD.REPAIR] = validate3or4,
				[CMD.UNLOAD_UNITS] = validate3or4,
				[CMD.LOAD_UNITS] = validate3or4,
				-- Single number parameter:
				[CMD.CLOAK] = validateNumber,
				[CMD.ONOFF] = validateNumber,
				[CMD.FIRE_STATE] = validateNumber,
				[CMD.MOVE_STATE] = validateNumber,
			}
			if commandValidators[commandID] then
				commandValidators[commandID]()
			end
		end

		local function validateOrderOptions(options, orderNumber)
			local validOptions = { right = true, alt = true, ctrl = true, shift = true, meta = true }
			if options then
				local luaTypeResult = validateLuaType(options, 'table')
				if luaTypeResult then
					result[#result + 1] = { luaTypeResult[1], "[" .. orderNumber .. "][3]" }
					return
				end

				for _, optionName in pairs(options) do
					if not validOptions[optionName] then
						result[#result + 1] = { "Invalid order option: " .. optionName, "[" .. orderNumber .. "][3]" }
					end
				end
			end
		end

		local luaTypeResult = luaTypeValidators[Types.Table](orders)
		if luaTypeResult then
			return luaTypeResult
		end

		if #orders == 0 then
			return { { "Orders table is empty. " } }
		end

		for i, order in pairs(orders) do
			local fieldResult = validateField(order, "order #" .. i, 'table')
			if fieldResult then
				result[#result + 1] = fieldResult
			else
				validateOrderCommandAndParams(order[1], order[2], i)
				validateOrderOptions(order[3], i)
			end
		end

		return result
	end,

	[Types.Area] = function(area)
		local luaTypeResult = luaTypeValidators[Types.Table](area)
		if luaTypeResult then
			return luaTypeResult
		end
		if not area then
			return
		end

		local isRectangle = area.x1 and area.z1 and area.x2 and area.z2
		local isCircle = area.x and area.z and area.radius
		if not isRectangle and not isCircle then
			return { { "Invalid area parameter, must be either rectangle { x1, z1, x2, z2 } with x1 < x2 and z1 < z2, or circle { x, z, radius }. " } }
		else
			local result = {}
			for key, value in pairs(area) do
				local fieldResult = validateField(value, key, 'number')
				if fieldResult then
					result[#result + 1] = fieldResult
				end
			end
			if not table.isNilOrEmpty(result) then
				return result
			end
		end
		if isRectangle then
			local result = {}
			if area.x1 >= area.x2 then
				result[#result + 1] = { "Invalid area rectangle parameter, x1 must be less than x2. " }
			end
			if area.z1 >= area.z2 then
				result[#result + 1] = { "Invalid area rectangle parameter, z1 must be less than z2. " }
			end
			return result
		end
	end,

	----------------------------------------------------------------
	--- String Validators:
	----------------------------------------------------------------

	[Types.TriggerID] = function(triggerID)
		local luaTypeResult = luaTypeValidators[Types.String](triggerID)
		if luaTypeResult then
			return luaTypeResult
		end

		if not GG['MissionAPI'].Triggers[triggerID] then
			return { { "Invalid triggerID: " .. triggerID } }
		end
	end,

	[Types.UnitDefName] = function(unitDefName)
		local luaTypeResult = luaTypeValidators[Types.String](unitDefName)
		if luaTypeResult then
			return luaTypeResult
		end
		if not unitDefName then
			return
		end

		if not UnitDefNames[unitDefName] then
			return { { "Invalid unitDefName: " .. unitDefName } }
		end
	end,

	[Types.Facing] = function(facing)
		if not facing then
			return
		end

		local expectedTypes = { string = true, number = true }
		local actualType = type(facing)
		if not expectedTypes[actualType] then
			return { { "Unexpected parameter type, expected string or number, got " .. actualType } }
		end

		if actualType == 'number' then
			local validNumericalFacings = { true, true, true, true }
			if not validNumericalFacings[facing + 1] then
				return { { "Invalid facing number: " .. facing .. ". Must be between 0 and 3." } }
			end
		else
			local validStringFacings = { n = true, s = true, e = true, w = true, north = true, south = true, east = true, west = true }
			if facing and not validStringFacings[facing] then
				return { { "Invalid facing: " .. facing .. ". Must be one of 'n', 's', 'e', 'w', 'north', 'south', 'east', 'west'." } }
			end
		end
	end,

	----------------------------------------------------------------
	--- Number Validators:
	----------------------------------------------------------------

	[Types.TeamID] = function(teamID)
		local luaTypeResult = luaTypeValidators[Types.Number](teamID)
		if luaTypeResult then
			return luaTypeResult
		end
		if not teamID then
			return
		end

		if not Spring.GetTeamAllyTeamID(teamID) then
			return { { "Invalid teamID: " .. teamID } }
		end
	end,
}

local validators = table.merge(customValidators, luaTypeValidators)

local function validate(schemaParameters, actionOrTriggerType, actionOrTriggerParameters, actionOrTrigger, actionOrTriggerID)
	if not actionOrTriggerType then
		logError(actionOrTrigger .. " missing type. " .. actionOrTrigger .. ": " .. actionOrTriggerID)
	elseif not schemaParameters[actionOrTriggerType] then
		logError(actionOrTrigger .. " has invalid type. " .. actionOrTrigger .. ": " .. actionOrTriggerID)
	else
		actionOrTriggerParameters = actionOrTriggerParameters or {}
		-- Check for requiresOneOf parameters:
		local requiresOneOf = schemaParameters[actionOrTriggerType].requiresOneOf
		if requiresOneOf and table.all(requiresOneOf, function(paramName) return actionOrTriggerParameters[paramName] == nil end) then
			logError(actionOrTrigger .." '" .. actionOrTriggerID .. "' is missing required parameter. At least one of " .. table.toString(requiresOneOf) .. " is required.")
		end
		-- Validate each parameter:
		for _, parameter in ipairs(schemaParameters[actionOrTriggerType]) do
			local value = actionOrTriggerParameters[parameter.name]
			if value == nil and parameter.required then
				logError(actionOrTrigger .. " missing required parameter. " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameter.name)
			else
				for _, messageWithSuffix in pairs(validators[parameter.type](value, actionOrTrigger, actionOrTriggerID, parameter.name) or {}) do
					local message = messageWithSuffix[1]
					local parameterNameSuffix = messageWithSuffix[2] or ""
					logError(message .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameter.name .. parameterNameSuffix)
				end
			end
		end
	end
end

local triggersSchemaParameter = VFS.Include('luarules/mission_api/triggers_schema.lua').Parameters
local function validateTrigger(triggerID, trigger)
	validate(triggersSchemaParameter, trigger.type, trigger.parameters, 'Trigger', triggerID)
end

local actionsSchemaParameters = VFS.Include('luarules/mission_api/actions_schema.lua').Parameters
local function validateAction(actionID, action)
	validate(actionsSchemaParameters, action.type, action.parameters, 'Action', actionID)
end

local function validateUnitNameReferences()
	-- Types need to be fetched here to avoid circular dependency
	local triggerTypes = GG['MissionAPI'].TriggerTypes
	local actionTypes = GG['MissionAPI'].ActionTypes

	local triggersTypesNamingUnits = { }
	local triggersTypesReferencingUnitNames = { }
	local actionsTypesNamingUnits = {
		[actionTypes.SpawnUnits] = true,
		[actionTypes.NameUnits] = true,
	}
	local actionsTypesReferencingUnitNames = {
		[actionTypes.IssueOrders] = true,
		[actionTypes.UnnameUnits] = true,
		[actionTypes.TransferUnits] = true,
		[actionTypes.DespawnUnits] = true,
		[actionTypes.TransferUnits] = true,
	}

	local createdUnitNames = {}
	local referencedUnitNames = {}
	local function recordUnitNameCreationsAndReferences(typesNamingUnits, typesReferencingUnitNames, actionsOrTriggers, label)
		for actionOrTriggerID, actionOrTrigger in pairs(actionsOrTriggers) do
			local unitName = (actionOrTrigger.parameters or {}).name
			if unitName then
				if typesNamingUnits[actionOrTrigger.type] then
					createdUnitNames[unitName] = true
				elseif typesReferencingUnitNames[actionOrTrigger.type] then
					referencedUnitNames[unitName] = referencedUnitNames[unitName] or {}
					referencedUnitNames[unitName][#referencedUnitNames[unitName] + 1] = label .. actionOrTriggerID
				end
			end
		end
	end

	recordUnitNameCreationsAndReferences(triggersTypesNamingUnits, triggersTypesReferencingUnitNames, GG['MissionAPI'].Triggers, "trigger ")
	recordUnitNameCreationsAndReferences(actionsTypesNamingUnits, actionsTypesReferencingUnitNames, GG['MissionAPI'].Actions, "action ")

	for unitName, labels in pairs(referencedUnitNames) do
		if not createdUnitNames[unitName] then
			logError("Unit name '" .. unitName .. "' not created in any trigger or action. Referenced in: " .. table.concat(labels, ", "))
		end
	end
end

return {
	ValidateTrigger = validateTrigger,
	ValidateAction = validateAction,
	ValidateUnitNameReferences = validateUnitNameReferences
}
