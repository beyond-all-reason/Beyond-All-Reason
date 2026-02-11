---
--- Validators for Mission API actions and triggers loaded from missions.
---

local function logError(message)
	Spring.Log('validation.lua', LOG.ERROR, "[Mission API] " .. message)
end


----------------------------------------------------------------
--- Parameter Type Validators:
----------------------------------------------------------------

local function validateLuaType(value, expectedType)
	local actualType = type(value)
	if value ~= nil and actualType ~= expectedType then
		return "Unexpected parameter type, expected " .. expectedType .. ", got " .. actualType
	end
end

local function validateField(value, fieldName, expectedType)
	if not value then
		return { message = "Missing required parameter. ", "." .. fieldName }

	end
	if type(value) ~= expectedType then
		return { message = "Unexpected parameter type, expected " .. expectedType .. ", got " .. type(value), parameterNameSuffix = "." .. fieldName }
	end
end

local Types = VFS.Include('luarules/mission_api/parameter_types.lua').Types

local function validateSimpleTypeCurried(expectedType)
	return function(value)
		local luaTypeResult = validateLuaType(value, expectedType)
		return luaTypeResult and { { message = luaTypeResult } } or nil
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
			return { { message = "allyTeamIDs table is empty. " } }
		end

		local result = {}
		for i, allyTeamID in pairs(allyTeamIDs) do
			local fieldResult = validateField(allyTeamID, "allyTeamID #" .. i, 'number')
			if fieldResult then
				result[#result + 1] = fieldResult
			elseif not Spring.GetAllyTeamInfo(allyTeamID) then
				result[#result + 1] = { message = "Invalid allyTeamID: " .. allyTeamID }
			end
		end

		return result
	end,

	[Types.Orders] = function(orders)

		local result = {}

		local function validateOrderCommandAndParams(order, orderNumber)
			local commandID = order[1]
			local params = order[2]
			local function validateNumberArrayCurried(sizes, message)
				return function()
					local luaTypeResult = validateLuaType(params, 'table')
					if luaTypeResult then
						result[#result + 1] = { message = luaTypeResult, parameterNameSuffix = '[' .. orderNumber .. '][2]' }
						return
					end
					if not table.contains(sizes, #(params or {})) then
						result[#result + 1] = { message = "Parameter must be an array of " .. message, parameterNameSuffix = '[' .. orderNumber .. '][2]' }
						return
					end
					for i, param in ipairs(params or {}) do
						local luaTypeRes = validateLuaType(param, 'number')
						if luaTypeRes then
							result[#result + 1] = { message = luaTypeRes, parameterNameSuffix = '[' .. orderNumber .. '][2][' .. i .. ']' }
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
					result[#result + 1] = { message = luaTypeResult, parameterNameSuffix = '[' .. orderNumber .. '][2]' }
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
			elseif type(commandID) == 'string' then
				-- build command: See https://springrts.com/wiki/Lua_CMDs#CMD.INTERNAL
				-- commandID is a unitDefName string, and must be converted to a negative unitDefID for the actual order
				local unitDef = UnitDefNames[commandID]
				if unitDef then
					order[1] = -unitDef.id
				else
					result[#result + 1] = { message = "Invalid build order unitDefName: " .. commandID, parameterNameSuffix = '[' .. orderNumber .. '][1]' }
				end

				-- parameters must be 3 or 4 numbers {x, y, z, optional facing}, or empty for factories
				validateNumberArrayCurried({ 0, 3, 4 }, "3 or 4 numbers {x, y, z, optional facing}, or no parameters for factories")()
				if #(params or {}) == 4 then
					local validFacings = { [0] = true, [1] = true, [2] = true, [3] = true }
					if not validFacings[params[4]] then
						result[#result + 1] = { message = "Invalid build order facing: " .. params[4] .. ". Must be one of 0, 1, 2, 3", parameterNameSuffix = '[' .. orderNumber .. '][2][4]' }
					end
				end
			end
		end

		local function validateOrderOptions(options, orderNumber)
			local validOptions = { right = true, alt = true, ctrl = true, shift = true, meta = true }
			if options then
				local luaTypeResult = validateLuaType(options, 'table')
				if luaTypeResult then
					result[#result + 1] = { message = luaTypeResult, parameterNameSuffix = "[" .. orderNumber .. "][3]" }
					return
				end

				for _, optionName in pairs(options) do
					if not validOptions[optionName] then
						result[#result + 1] = { message = "Invalid order option: " .. optionName, parameterNameSuffix = "[" .. orderNumber .. "][3]" }
					end
				end
			end
		end

		local luaTypeResult = luaTypeValidators[Types.Table](orders)
		if luaTypeResult then
			return luaTypeResult
		end

		if #orders == 0 then
			return { { message = "Orders table is empty. " } }
		end

		for i, order in pairs(orders) do
			local fieldResult = validateField(order, "order #" .. i, 'table')
			if fieldResult then
				result[#result + 1] = fieldResult
			else
				validateOrderCommandAndParams(order, i)
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

		local isRectangle = area.x1 and area.z1 and area.x2 and area.z2
		local isCircle = area.x and area.z and area.radius
		if not isRectangle and not isCircle then
			return { { message = "Invalid area parameter, must be either rectangle { x1, z1, x2, z2 } with x1 < x2 and z1 < z2, or circle { x, z, radius }. " } }
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
				result[#result + 1] = { message = "Invalid area rectangle parameter, x1 must be less than x2. " }
			end
			if area.z1 >= area.z2 then
				result[#result + 1] = { message = "Invalid area rectangle parameter, z1 must be less than z2. " }
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
			return { { message = "Invalid triggerID: " .. triggerID } }
		end
	end,

	[Types.UnitDefName] = function(unitDefName)
		local luaTypeResult = luaTypeValidators[Types.String](unitDefName)
		if luaTypeResult then
			return luaTypeResult
		end

		if not UnitDefNames[unitDefName] then
			return { { message = "Invalid unitDefName: " .. unitDefName } }
		end
	end,

	[Types.Facing] = function(facing)
		local expectedTypes = { string = true, number = true }
		local actualType = type(facing)
		if not expectedTypes[actualType] then
			return { { message = "Unexpected parameter type, expected string or number, got " .. actualType } }
		end

		local validFacings = { [0] = true, [1] = true, [2] = true, [3] = true, n = true, s = true, e = true, w = true, north = true, south = true, east = true, west = true }
		if not validFacings[facing] then
			return { { message = "Invalid facing: " .. facing .. ". Must be one of 'n', 's', 'e', 'w', 'north', 'south', 'east', 'west'." } }
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

		if not Spring.GetTeamAllyTeamID(teamID) then
			return { { message = "Invalid teamID: " .. teamID } }
		end
	end,
}

local validators = table.merge(customValidators, luaTypeValidators)


----------------------------------------------------------------
--- Trigger/Action Validation Functions:
----------------------------------------------------------------

local triggersSchema = VFS.Include('luarules/mission_api/triggers_schema.lua')
local triggersSchemaSettings = triggersSchema.Settings
local triggersSchemaParameters = triggersSchema.Parameters
local actionsSchemaParameters = VFS.Include('luarules/mission_api/actions_schema.lua').Parameters

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
			if value == nil then
				if parameter.required then
					logError(actionOrTrigger .. " missing required parameter. " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameter.name)
				else
					-- Optional parameter not provided, no need to validate
				end
			else
				local validationResults = validators[parameter.type](value, actionOrTrigger, actionOrTriggerID, parameter.name) or {}
				for _, validationResult in pairs(validationResults) do
					logError(validationResult.message .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameter.name .. (validationResult.parameterNameSuffix or ''))
				end
			end
		end
	end
end

local function validateTriggerSetting(trigger, triggerID, triggers)
	-- Validate types of settings:
	for schemaSetting, schemaType in pairs(triggersSchemaSettings) do
		local luaTypeResult = validateLuaType(trigger.settings[schemaSetting], string.lower(schemaType))
		if luaTypeResult then
			logError(luaTypeResult .. ". Trigger: " .. triggerID .. ", Setting: " .. schemaSetting)
		end
	end

	-- Validate prerequisites triggerIDs exist:
	for _, prerequisiteTriggerID in pairs(trigger.settings.prerequisites) do
		if not triggers[prerequisiteTriggerID] then
			logError("Trigger prerequisite does not exist. Trigger: " .. triggerID .. ", Prerequisite triggerID: " .. prerequisiteTriggerID)
		end
	end
end

local function validateTriggers(triggers, rawActions)
	for triggerID, trigger in pairs(triggers) do
		if table.isNilOrEmpty(trigger.actions) then
			logError("Trigger has no actions: " .. triggerID)
		else
			for _, action in pairs(trigger.actions) do
				if action == nil or action == '' then
					logError("Trigger has empty action ID: " .. triggerID)
				elseif not rawActions[action] then
					logError("Trigger has invalid action ID: " .. triggerID .. ", Action: " .. action)
				end
			end
		end
		validateTriggerSetting(trigger, triggerID, triggers)
		validate(triggersSchemaParameters, trigger.type, trigger.parameters, 'Trigger', triggerID)
	end
end

local function getAllActionIDsReferencedByTriggers()
	local allActionIDsReferencedByTriggers = {}
	for _, trigger in pairs(GG['MissionAPI'].Triggers) do
		if not table.isNilOrEmpty(trigger.actions) then
			for _, actionID in pairs(trigger.actions) do
				allActionIDsReferencedByTriggers[actionID] = true
			end
		end
	end
	return allActionIDsReferencedByTriggers
end

local function validateActions(actions)
	local allActionIDsReferencedByTriggers = getAllActionIDsReferencedByTriggers()

	local unreferencedActionIDs = {}
	for actionID, action in pairs(actions) do
		if not allActionIDsReferencedByTriggers[actionID] then
			unreferencedActionIDs[#unreferencedActionIDs + 1] = actionID
		end
		validate(actionsSchemaParameters, action.type, action.parameters, 'Action', actionID)
	end
	if not table.isEmpty(unreferencedActionIDs) then
		logError("Actions not referenced by any trigger: " .. table.concat(unreferencedActionIDs, ", "))
	end
end

local function validateUnitNameReferences()
	local createdUnitNames = {}
	local referencedUnitNames = {}
	local function recordUnitNameCreationsAndReferences(actionsOrTriggers, label)
		for actionOrTriggerID, actionOrTrigger in pairs(actionsOrTriggers) do
			local unitNameToGive = (actionOrTrigger.parameters or {}).unitNameToGive
			if unitNameToGive then
				createdUnitNames[unitNameToGive] = createdUnitNames[unitNameToGive] or {}
				createdUnitNames[unitNameToGive][#createdUnitNames[unitNameToGive] + 1] = label .. actionOrTriggerID
			end
			local unitNameRequired = (actionOrTrigger.parameters or {}).unitNameRequired
			if unitNameRequired then
				referencedUnitNames[unitNameRequired] = referencedUnitNames[unitNameRequired] or {}
				referencedUnitNames[unitNameRequired][#referencedUnitNames[unitNameRequired] + 1] = label .. actionOrTriggerID
			end
		end
	end

	recordUnitNameCreationsAndReferences(GG['MissionAPI'].Triggers, "trigger ")
	recordUnitNameCreationsAndReferences(GG['MissionAPI'].Actions, "action ")

	for unitName, labels in pairs(referencedUnitNames) do
		if not createdUnitNames[unitName] then
			logError("Unit name '" .. unitName .. "' not created in any trigger or action. Referenced in: " .. table.concat(labels, ", "))
		end
	end
	for unitName, labels in pairs(createdUnitNames) do
		if not referencedUnitNames[unitName] then
			logError("Unit name '" .. unitName .. "' created, but not referenced by any trigger or action. Created in: " .. table.concat(labels, ", "))
		end
	end
end

return {
	ValidateTriggers = validateTriggers,
	ValidateActions = validateActions,
	ValidateUnitNameReferences = validateUnitNameReferences
}
