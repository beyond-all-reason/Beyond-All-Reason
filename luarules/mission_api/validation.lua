--
-- Validators for Mission API action and trigger parameters loaded from missions.
--

local function logError(message)
	Spring.Log('validation.lua', LOG.ERROR, "[Mission API] " .. message)
end

local function validateLuaType(value, expectedType, actionOrTrigger, actionOrTriggerID, parameterName)
	local actualType = type(value)
	if value ~= nil and actualType ~= expectedType then
		logError("Unexpected parameter type, expected " ..expectedType ..", got " .. actualType .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameterName)
		return false
	end
	return true
end

local function validateField(value, fieldName, expectedType, actionOrTrigger, actionOrTriggerID, parameterName)
	if not value then
		logError(actionOrTrigger .. " missing required parameter. " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameterName .. "." .. fieldName)
		return false
	end
	if type(value) ~= expectedType then
		logError("Unexpected parameter type, expected " .. expectedType .. ", got " .. type(value) .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameterName .. "." .. fieldName)
		return false
	end
	return true
end

local Types = VFS.Include('luarules/mission_api/parameter_types.lua').Types

local function validateSimpleTypeCurried(expectedType)
	return function(value, actionOrTrigger, actionOrTriggerID, parameterName)
		return validateLuaType(value, expectedType, actionOrTrigger, actionOrTriggerID, parameterName)
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

	[Types.Position] = function(position, actionOrTrigger, actionOrTriggerID, parameterName)
		if not luaTypeValidators[Types.Table](position, actionOrTrigger, actionOrTriggerID, parameterName) then
			return
		end

		for _, field in pairs({ "x", "z"}) do
			if not validateField(position[field], field, 'number', actionOrTrigger, actionOrTriggerID, parameterName) then
				return
			end
		end

		position.y = position.y or Spring.GetGroundHeight(position.x, position.z)
		validateField(position.y, 'y', 'number', actionOrTriggerID, parameterName)
	end,

	[Types.AllyTeamIDs] = function(allyTeamIDs, actionOrTrigger, actionOrTriggerID, parameterName)
		if not luaTypeValidators[Types.Table](allyTeamIDs, actionOrTrigger, actionOrTriggerID, parameterName) then
			return
		end

		if table.isNilOrEmpty(allyTeamIDs) then
			logError("allyTeamIDs table is empty. " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameterName)
			return
		end

		for i, allyTeamID in pairs(allyTeamIDs) do
			if validateField(allyTeamID, "allyTeamID #" .. i, 'number', actionOrTrigger, actionOrTriggerID, parameterName)
				and not Spring.GetAllyTeamInfo(allyTeamID) then
				logError("Invalid allyTeamID: " .. allyTeamID .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameterName)
			end
		end
	end,

	[Types.Orders] = function(orders, actionOrTrigger, actionOrTriggerID, parameterName)

		local function validateOrderCommandAndParams(commandID, params, orderNumber)
			local function validateNumberArrayCurried(sizes, message)
				return function()
					if not validateLuaType(params, 'table', actionOrTrigger, actionOrTriggerID, parameterName .. '[' .. orderNumber .. ']' .. '[2]') then
						return
					end
					if not table.contains(sizes, #(params or {})) then
						logError("Parameter must be an array of " .. message .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameterName .. '[' .. orderNumber .. ']' .. '[2]')
						return
					end
					for i = 1, 3 do
						validateLuaType(params[i], 'number', actionOrTrigger, actionOrTriggerID, parameterName .. '[' .. orderNumber .. ']' .. '[2][' .. i .. ']')
					end
				end
			end
			local validate3 = validateNumberArrayCurried({ 3 }, "3 numbers {x, y, z}")
			local validate4 = validateNumberArrayCurried({ 4 }, "4 numbers {x, y, z, radius}")
			local validate3or4 = validateNumberArrayCurried({ 3, 4 }, "3 or 4 numbers {x, y, z, optional radius}")
			local function validateNumber()
				validateLuaType(params, 'number', actionOrTrigger, actionOrTriggerID, parameterName .. '[' .. orderNumber .. ']' .. '[2]')
			end
			local commandValidators = {
				[CMD.STOP] = false, [CMD.SELFD] = false, [CMD.GUARD] = false,
				[CMD.DGUN] = validate3, [CMD.MOVE] = validate3, [CMD.FIGHT] = validate3, [CMD.PATROL] = validate3,
				[CMD.RECLAIM] = validate4, [CMD.RESURRECT] = validate4, [CMD.CAPTURE] = validate4, [CMD.AREA_ATTACK] = validate4, [CMD.RESTORE] = validate4,
				[CMD.ATTACK] = validate3or4, [CMD.REPAIR] = validate3or4, [CMD.UNLOAD_UNITS] = validate3or4, [CMD.LOAD_UNITS] = validate3or4,
				[CMD.CLOAK] = validateNumber, [CMD.ONOFF] = validateNumber, [CMD.FIRE_STATE] = validateNumber, [CMD.MOVE_STATE] = validateNumber,
			}
			if commandValidators[commandID] then
				commandValidators[commandID]()
			end
		end

		local function validateOrderOptions(options, orderNumber)
			local validOptions = { right = true, alt = true, ctrl = true, shift = true, meta = true }
			if options and luaTypeValidators[Types.Table](options, actionOrTrigger, actionOrTriggerID, parameterName .. '[3]') then
				for _, optionName in pairs(options) do
					if not validOptions[optionName] then
						logError("Invalid order option: " .. optionName .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameterName .. ", Order #" .. orderNumber)
					end
				end
			end
		end

		if not luaTypeValidators[Types.Table](orders, actionOrTrigger, actionOrTriggerID, parameterName) then
			return
		end

		if #orders == 0 then
			logError("Orders table is empty. " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameterName)
			return
		end

		for i, order in pairs(orders) do
			if validateField(order, "order #" .. i, 'table', actionOrTrigger, actionOrTriggerID, parameterName) then
				validateOrderCommandAndParams(order[1], order[2], i)
				validateOrderOptions(order[3], i)
			end
		end
	end,

	[Types.Area] = function(area, actionOrTrigger, actionOrTriggerID, parameterName)
		if not luaTypeValidators[Types.Table](area, actionOrTrigger, actionOrTriggerID, parameterName) then
			return
		end
		if not area then
			return
		end

		local isRectangle = area.x1 and area.z1 and area.x2 and area.z2
		local isCircle = area.x and area.z and area.radius
		if not isRectangle and not isCircle then
			logError("Invalid area parameter, must be rectangle { x1, z1, x2, z2 } or circle { x, z, radius }. " .. actionOrTrigger .. ": " .. actionOrTriggerID)
		else
			for key, value in pairs(area) do
				validateField(value, key, 'number', actionOrTrigger, actionOrTriggerID, parameterName)
			end
		end
	end,

	----------------------------------------------------------------
	--- String Validators:
	----------------------------------------------------------------

	[Types.TriggerID] = function(triggerID, actionOrTrigger, actionOrTriggerID, parameterName)
		if not luaTypeValidators[Types.String](triggerID, actionOrTrigger, actionOrTriggerID, parameterName) then
			return
		end

		if not GG['MissionAPI'].Triggers[triggerID] then
			logError("Invalid triggerID: " .. triggerID .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID)
		end
	end,

	[Types.UnitDefName] = function(unitDefName, actionOrTrigger, actionOrTriggerID, parameterName)
		if not luaTypeValidators[Types.String](unitDefName, actionOrTrigger, actionOrTriggerID, parameterName) then
			return
		end

		if not UnitDefNames[unitDefName] then
			logError("Invalid unitDefName: " .. unitDefName .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID)
		end
	end,

	[Types.Facing] = function(facing, actionOrTrigger, actionOrTriggerID, _)
		local validFacings = { n = true, s = true, e = true, w = true }
		if facing and not validFacings[facing] then
			logError("Invalid facing: " .. facing .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID)
		end
	end,

	----------------------------------------------------------------
	--- Number Validators:
	----------------------------------------------------------------

	[Types.TeamID] = function(teamID, actionOrTrigger, actionOrTriggerID, parameterName)
		if not luaTypeValidators[Types.Number](teamID, actionOrTrigger, actionOrTriggerID, parameterName) then
			return
		end

		if not Spring.GetTeamAllyTeamID(teamID) then
			logError("Invalid teamID: " .. teamID .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameterName)
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
		-- For NameUnits action, at least one of teamID, unitDefName, or area is required:
		if actionOrTrigger == 'Action' and actionOrTriggerType == GG['MissionAPI'].ActionTypes.NameUnits and not actionOrTriggerParameters.teamID and not actionOrTriggerParameters.unitDefName and not actionOrTriggerParameters.area then
			logError("NameUnits action '" .. actionOrTriggerID .. "' is missing required parameter. At least one of teamID, unitDefName, and area is required.")
		end
		for _, parameter in pairs(schemaParameters[actionOrTriggerType]) do
			local value = actionOrTriggerParameters[parameter.name]

			if value == nil and parameter.required then
				logError(actionOrTrigger .. " missing required parameter. " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameter.name)
			else
				validators[parameter.type](value, actionOrTrigger, actionOrTriggerID, parameter.name)
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
		[actionTypes.SpawnUnits] = true, [actionTypes.NameUnits] = true,
	}
	local actionsTypesReferencingUnitNames = {
		[actionTypes.IssueOrders] = true, [actionTypes.UnnameUnits] = true, [actionTypes.TransferUnits] = true,
		[actionTypes.DespawnUnits] = true, [actionTypes.TransferUnits] = true,
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
