---
--- Validators for Mission API stages, objectives, actions, and triggers loaded from missions.
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
		return { message = "Missing required parameter", parameterNameSuffix = "." .. fieldName }
	end
	if type(value) ~= expectedType then
		return { message = "Unexpected parameter type, expected " .. expectedType .. ", got " .. type(value), parameterNameSuffix = "." .. fieldName }
	end
end

local Types = VFS.Include('luarules/mission_api/parameter_types.lua').Types

local validators = {}

--- Lua type validators:
local function validateLuaTypeCurried(expectedType)
	return function(value)
		local luaTypeResult = validateLuaType(value, expectedType)
		return luaTypeResult and { { message = luaTypeResult } } or nil
	end
end
validators[Types.Table] = validateLuaTypeCurried('table')
validators[Types.String] = validateLuaTypeCurried('string')
validators[Types.Number] = validateLuaTypeCurried('number')
validators[Types.Boolean] = validateLuaTypeCurried('boolean')
validators[Types.Function] = validateLuaTypeCurried('function')

--- Table Validators:

validators[Types.Position] = function(position)
		local luaTypeResult = validators[Types.Table](position)
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
	end

validators[Types.Positions] = function(positions)
		local luaTypeResult = validators[Types.Table](positions)
		if luaTypeResult then
			return luaTypeResult
		end

		local result = {}
		if not positions or #positions < 2 then
			result[#result + 1] = { message = "Positions table needs at least two positions" }
		end

		for i, position in pairs(positions) do
			local fieldResult = validateField(position, "position #" .. i, 'table')
			if fieldResult then
				result[#result + 1] = fieldResult
			else
				local positionResult = validators[Types.Position](position)
				if positionResult then
					for _, validationResult in pairs(positionResult) do
						validationResult.parameterNameSuffix = "[" .. i .. "]" .. (validationResult.parameterNameSuffix or '')
						result[#result + 1] = validationResult
					end
				end
			end
		end

		return result
	end

validators[Types.AllyTeamIDs] = function(allyTeamIDs)
		local luaTypeResult = validators[Types.Table](allyTeamIDs)
		if luaTypeResult then
			return luaTypeResult
		end

		if table.isNilOrEmpty(allyTeamIDs) then
			return { { message = "allyTeamIDs table is empty" } }
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
	end

validators[Types.Orders] = function(orders)

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

		local luaTypeResult = validators[Types.Table](orders)
		if luaTypeResult then
			return luaTypeResult
		end

		if #orders == 0 then
			return { { message = "Orders table is empty" } }
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
	end

validators[Types.Area] = function(area)
		local luaTypeResult = validators[Types.Table](area)
		if luaTypeResult then
			return luaTypeResult
		end

		local isRectangle = area.x1 and area.z1 and area.x2 and area.z2
		local isCircle = area.x and area.z and area.radius
		if not isRectangle and not isCircle then
			return { { message = "Invalid area parameter, must be either rectangle { x1, z1, x2, z2 } with x1 < x2 and z1 < z2, or circle { x, z, radius }" } }
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
				result[#result + 1] = { message = "Invalid area rectangle parameter, x1 must be less than x2" }
			end
			if area.z1 >= area.z2 then
				result[#result + 1] = { message = "Invalid area rectangle parameter, z1 must be less than z2" }
			end
			return result
		end
	end

--- String Validators:

validators[Types.StageID] = function(stageID)
	local luaTypeResult = validators[Types.String](stageID)
	if luaTypeResult then
		return luaTypeResult
	end

	if not GG['MissionAPI'].Stages[stageID] then
		return { { message = "Invalid stageID: " .. stageID } }
	end
end

validators[Types.ObjectiveID] = function(objectiveID)
	local luaTypeResult = validators[Types.String](objectiveID)
	if luaTypeResult then
		return luaTypeResult
	end

	if not GG['MissionAPI'].Objectives[objectiveID] then
		return { { message = "Invalid objectiveID: " .. objectiveID } }
	end
end

validators[Types.TriggerID] = function(triggerID)
		local luaTypeResult = validators[Types.String](triggerID)
		if luaTypeResult then
			return luaTypeResult
		end

		if not GG['MissionAPI'].Triggers[triggerID] then
			return { { message = "Invalid triggerID: " .. triggerID } }
		end
	end

validators[Types.UnitDefName] = function(unitDefName)
		local luaTypeResult = validators[Types.String](unitDefName)
		if luaTypeResult then
			return luaTypeResult
		end

		if not UnitDefNames[unitDefName] then
			return { { message = "Invalid unitDefName: " .. unitDefName } }
		end
	end

validators[Types.Facing] = function(facing)
		local expectedTypes = { string = true, number = true }
		local actualType = type(facing)
		if not expectedTypes[actualType] then
			return { { message = "Unexpected parameter type, expected string or number, got " .. actualType } }
		end

		local validFacings = { [0] = true, [1] = true, [2] = true, [3] = true, n = true, s = true, e = true, w = true, north = true, south = true, east = true, west = true }
		if not validFacings[facing] then
			return { { message = "Invalid facing: " .. facing .. ". Must be one of 'n', 's', 'e', 'w', 'north', 'south', 'east', 'west'." } }
		end
	end

--- Number Validators:

validators[Types.TeamID] = function(teamID)
		local luaTypeResult = validators[Types.Number](teamID)
		if luaTypeResult then
			return luaTypeResult
		end

		if not Spring.GetTeamAllyTeamID(teamID) then
			return { { message = "Invalid teamID: " .. teamID } }
		end
	end

validators[Types.PlayerID] = function(playerID)
		local luaTypeResult = validators[Types.Number](playerID)
		if luaTypeResult then
			return luaTypeResult
		end

		if not Spring.GetPlayerInfo(playerID) then
			return { { message = "Invalid playerID: " .. playerID } }
		end
	end


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

local function validateTriggerSettings(trigger, triggerID, triggers)
	-- Validate Lua types of settings:
	for schemaSetting, schemaType in pairs(triggersSchemaSettings) do
		local luaTypeResult = validateLuaType(trigger.settings[schemaSetting], string.lower(schemaType))
		if luaTypeResult then
			logError(luaTypeResult .. ". Trigger: " .. triggerID .. ", Setting: " .. schemaSetting)
		end
	end

	-- Validate maxRepeats is only set if repeating is true:
	if trigger.settings.maxRepeats and not trigger.settings.repeating then
		logError("Trigger has maxRepeats setting but is not set to repeating. Trigger: " .. triggerID)
	end

	-- Validate prerequisites triggerIDs exist:
	for _, prerequisiteTriggerID in pairs(trigger.settings.prerequisites) do
		if not triggers[prerequisiteTriggerID] then
			logError("Trigger prerequisite does not exist. Trigger: " .. triggerID .. ", Prerequisite triggerID: " .. prerequisiteTriggerID)
		end
	end

	-- Validate stages exist:
	if trigger.settings.stages then
		for _, stage in pairs(trigger.settings.stages) do
			if not GG['MissionAPI'].Stages[stage] then
				logError("Trigger refers to non-existent stage. Trigger: " .. triggerID .. ", Stage: " .. stage)
			end
		end
	end
end

local function validateObjectives(objectives)
	for objectiveID, objective in pairs(objectives) do
		if not objective.text then
			logError("Objective missing text: " .. objectiveID)
		elseif objective.text == '' then
			logError("Objective has empty text: " .. objectiveID)
		end
	end
end

local function validateStages(stages, initialStage)
	for stageID, stage in pairs(stages) do
		if not stage.title then
			logError("Stage missing title: " .. stageID)
		elseif stage.title == '' then
			logError("Stage has empty title: " .. stageID)
		end
		for _, objectiveID in pairs(stage.objectives or {}) do
			if not GG['MissionAPI'].Objectives[objectiveID] then
				logError("Stage refers to non-existent objective. Stage: " .. stageID .. ", Objective: " .. objectiveID)
			end
		end
	end
	if not stages[initialStage] then
		logError("Initial stage does not exist in stages: " .. initialStage)
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
		validateTriggerSettings(trigger, triggerID, triggers)
		validate(triggersSchemaParameters, trigger.type, trigger.parameters, 'Trigger', triggerID)
	end
end

local function getAllActionIDsReferencedByTriggers()
	local allActionIDsReferencedByTriggers = {}
	for _, trigger in pairs(GG['MissionAPI'].Triggers) do
		for _, actionID in pairs(trigger.actions or {}) do
			allActionIDsReferencedByTriggers[actionID] = true
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

local function getAllObjectiveIDsReferencedByStages()
	local allObjectiveIDsReferencedByStages = {}
	for _, stage in pairs(GG['MissionAPI'].Stages) do
		for _, objectiveID in pairs(stage.objectives or {}) do
			allObjectiveIDsReferencedByStages[objectiveID] = true
		end
	end
	return allObjectiveIDsReferencedByStages
end

local function validateObjectiveReferences(objectives)
	local allObjectiveIDsReferencedByStages = getAllObjectiveIDsReferencedByStages()

	local unreferencedObjectiveIDs = {}
	for objectiveID, _ in pairs(objectives) do
		if not allObjectiveIDsReferencedByStages[objectiveID] then
			unreferencedObjectiveIDs[#unreferencedObjectiveIDs + 1] = objectiveID
		end
	end
	if not table.isEmpty(unreferencedObjectiveIDs) then
		logError("Objectives not referenced by any stage: " .. table.concat(unreferencedObjectiveIDs, ", "))
	end
end

local function validateUnitNameReferences(triggerTypes, actionTypes, triggers, actions)
	local triggerTypesReferencingUnitNames = { }
	local actionTypesNamingUnits = {
		[actionTypes.SpawnUnits] = true,
		[actionTypes.NameUnits] = true,
	}
	local actionTypesReferencingUnitNames = {
		[actionTypes.IssueOrders] = true,
		[actionTypes.UnnameUnits] = true,
		[actionTypes.TransferUnits] = true,
		[actionTypes.DespawnUnits] = true,
		[actionTypes.TransferUnits] = true,
		[actionTypes.UpdateObjective] = true,
	}

	local createdUnitNames = {}
	local referencedUnitNames = {}
	local function recordUnitNameCreationsAndReferences(typesNamingUnits, typesReferencingUnitNames, actionsOrTriggers, label)
		for actionOrTriggerID, actionOrTrigger in pairs(actionsOrTriggers) do
			local unitName = (actionOrTrigger.parameters or {}).unitName
			if unitName then
				if typesNamingUnits[actionOrTrigger.type] then
					createdUnitNames[unitName] = createdUnitNames[unitName] or {}
					createdUnitNames[unitName][#createdUnitNames[unitName] + 1] = label .. actionOrTriggerID
				elseif typesReferencingUnitNames[actionOrTrigger.type] then
					referencedUnitNames[unitName] = referencedUnitNames[unitName] or {}
					referencedUnitNames[unitName][#referencedUnitNames[unitName] + 1] = label .. actionOrTriggerID
				end
			end
		end
	end

	recordUnitNameCreationsAndReferences({}, triggerTypesReferencingUnitNames, triggers, "trigger ")
	recordUnitNameCreationsAndReferences(actionTypesNamingUnits, actionTypesReferencingUnitNames, actions, "action ")

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

local function validateMarkerNameReferences(actionTypes, actions)
	local createdMarkerNames = {}
	local referencedMarkerNames = {}
	for actionID, action in pairs(actions) do
		if action.type == actionTypes.AddMarker then
			local markerName = action.parameters.name
			if markerName then
				createdMarkerNames[markerName] = createdMarkerNames[markerName] or {}
				createdMarkerNames[markerName][#createdMarkerNames[markerName] + 1] = actionID
			end
		elseif action.type == actionTypes.EraseMarker then
			local markerName = action.parameters.name
			if markerName then
				referencedMarkerNames[markerName] = referencedMarkerNames[markerName] or {}
				referencedMarkerNames[markerName][#referencedMarkerNames[markerName] + 1] = actionID
			end
		end
	end

	for markerName, actionIDs in pairs(referencedMarkerNames) do
		if not createdMarkerNames[markerName] then
			logError("Marker name '" .. markerName .. "' is not created in any action. Referenced in: " .. table.concat(actionIDs, ", "))
		end
	end
	for markerName, actionIDs in pairs(createdMarkerNames) do
		if not referencedMarkerNames[markerName] then
			logError("Marker name '" .. markerName .. "' is not referenced by any action. Referenced in: " .. table.concat(actionIDs, ", "))
		end
	end
end

local function validateReferences()
	-- Types need to be fetched here to avoid circular dependency
	local triggerTypes = GG['MissionAPI'].TriggerTypes
	local actionTypes = GG['MissionAPI'].ActionTypes
	local objectives = GG['MissionAPI'].Objectives
	local triggers = GG['MissionAPI'].Triggers
	local actions = GG['MissionAPI'].Actions
	validateObjectiveReferences(objectives)
	validateUnitNameReferences(triggerTypes, actionTypes, triggers, actions)
	validateMarkerNameReferences(actionTypes, actions)
end

return {
	ValidateObjectives = validateObjectives,
	ValidateStages = validateStages,
	ValidateTriggers = validateTriggers,
	ValidateActions = validateActions,
	ValidateReferences = validateReferences
}
