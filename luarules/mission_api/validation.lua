---
--- Validators for Mission API stages, objectives, actions, and triggers loaded from missions.
---

VFS.Include('common/wav.lua')

local function logError(message)
	GG['MissionAPI'].HasValidationErrors = true
	Spring.Log('validation.lua', LOG.ERROR, "[Mission API] " .. message)
end
local function logWarn(message)
	Spring.Log('validation.lua', LOG.WARNING, "[Mission API] " .. message)
end


----------------------------------------------------------------
--- Parameter Type Validators:
----------------------------------------------------------------

-- Set of command IDs from CMD and GameCMD:
local knownCMDs = {}
for cmdID in pairs(CMD) do
	knownCMDs[cmdID] = true
end
for cmdID in pairs(GameCMD) do
	knownCMDs[cmdID] = true
end

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

local parameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')
local Types = parameterTypes.Types
local parameterTypeEnums = parameterTypes.Enums

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
		local fields = position.y ~= nil and { "x", "y", "z" } or { "x", "z" }
		for _, field in pairs(fields) do
			local fieldResult = validateField(position[field], field, 'number')
			if fieldResult then
				result[#result + 1] = fieldResult
			end
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
						result[#result + 1] = {
							message = validationResult.message,
							parameterNameSuffix = "[" .. i .. "]" .. (validationResult.parameterNameSuffix or ''),
						}
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
		local function validateNumberArrayCurried(sizes, message, nameKeys)
			return function()
				local luaTypeResult = validateLuaType(params, 'table')
				if luaTypeResult then
					result[#result + 1] = { message = luaTypeResult, parameterNameSuffix = '[' .. orderNumber .. '][2]' }
					return
				end

				if nameKeys and table.any(nameKeys, function(nameKey) return params[nameKey] ~= nil end) then
					-- params has a nameKey field, so it's a unit or feature name parameter
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

		local function validateNumber()
			local luaTypeResult = validateLuaType(params, 'number')
			if luaTypeResult then
				result[#result + 1] = { message = luaTypeResult, parameterNameSuffix = '[' .. orderNumber .. '][2]' }
			end
		end

		local validateUnitName = validateNumberArrayCurried({ -1 }, "{ unitName = 'aUnitName' }", { 'unitName' })
		local validate3 = validateNumberArrayCurried({ 3 }, "3 numbers {x, y, z}")
		local validate3orUnitName = validateNumberArrayCurried({ 3 }, "3 numbers {x, y, z}, or a unit name", { 'unitName' })
		local validate3or4 = validateNumberArrayCurried({ 3, 4 }, "3 or 4 numbers {x, y, z, optional radius}")
		local validate4 = validateNumberArrayCurried({ 4 }, "4 numbers {x, y, z, radius}")
		local validate4orUnitName = validateNumberArrayCurried({ 4 }, "4 numbers {x, y, z, radius}, or a unit name", { 'unitName' })
		local validate4orFeatureName = validateNumberArrayCurried({ 4 }, "4 numbers {x, y, z, radius}, or a feature name", { 'featureName' })
		local validate4orEitherName = validateNumberArrayCurried({ 4 }, "4 numbers {x, y, z, radius}, or a unit/feature name", { 'unitName', 'featureName' })

		local commandValidators = {
			-- No parameters:
			[CMD.STOP] = false,
			[CMD.SELFD] = false,
			-- Unit name parameter:
			[CMD.GUARD] = validateUnitName,
			-- 3 number parameters:
			[CMD.DGUN] = validate3,
			[CMD.MOVE] = validate3,
			[CMD.FIGHT] = validate3,
			[CMD.PATROL] = validate3,
			-- 3 or 4 number parameters:
			[CMD.UNLOAD_UNITS] = validate3or4,
			-- 4 number parameters:
			[CMD.AREA_ATTACK] = false,        -- currently broken in engine
			[GameCMD.AREA_ATTACK_GROUND] = validate4, -- Only artillery units (customParams.canareaattack = 1) support this
			[CMD.RESTORE] = validate4,
			-- 3 number parameters, or unit name:
			[CMD.ATTACK] = validate3orUnitName,
			-- 4 number parameters, or unit name:
			[CMD.CAPTURE] = validate4orUnitName,
			[CMD.REPAIR] = validate4orUnitName,
			[CMD.LOAD_UNITS] = validate4orUnitName,
			-- 4 number parameters, or feature name:
			[CMD.RESURRECT] = validate4orFeatureName,
			-- 4 number parameters, or either unit or feature name:
			[CMD.RECLAIM] = validate4orEitherName,
			-- Single number parameter:
			[CMD.CLOAK] = validateNumber,
			[CMD.ONOFF] = validateNumber,
			[CMD.FIRE_STATE] = validateNumber,
			[CMD.MOVE_STATE] = validateNumber,
		}
		if commandID == nil then
			result[#result + 1] = { message = "Order is missing a command ID", parameterNameSuffix = '[' .. orderNumber .. ']' }
		elseif commandValidators[commandID] then
			commandValidators[commandID]()
		elseif type(commandID) == 'string' then
			-- build command: See https://springrts.com/wiki/Lua_CMDs#CMD.INTERNAL
			-- commandID is a unitDefName string
			local unitDef = UnitDefNames[commandID]
			if not unitDef then
				result[#result + 1] = { message = "Invalid build order unitDefName: " .. commandID, parameterNameSuffix = '[' .. orderNumber .. '][1]' }
			end

			-- parameters must be 3 or 4 numbers {x, y, z, optional facing}, or empty for factories
			validateNumberArrayCurried({ 0, 3, 4 }, "3 or 4 numbers {x, y, z, optional facing}, or no parameters for factories")()
			if #(params or {}) == 4 then
				if not parameterTypeEnums[Types.Facing][params[4]] then
					result[#result + 1] = { message = "Invalid build order facing: " .. params[4] .. ". Must be one of 0, 1, 2, 3", parameterNameSuffix = '[' .. orderNumber .. '][2][4]' }
				end
			end
		elseif not knownCMDs[commandID] then
			result[#result + 1] = { message = "Unknown command ID: " .. tostring(commandID), parameterNameSuffix = '[' .. orderNumber .. '][1]' }
		else
			logWarn("No validator implemented for orders with command ID: " .. tostring(commandID))
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

validators[Types.ResourceIncomeSources] = function(sources)
	local luaTypeResult = validators[Types.Table](sources)
	if luaTypeResult then return luaTypeResult end
	if #sources == 0 then
		return { { message = "Resource income sources table must not be empty" } }
	end

	local result = {}
	for i, source in ipairs(sources) do
		if not parameterTypeEnums[Types.ResourceIncomeSources][source] then
			result[#result + 1] = { message = "Invalid resource income source [" .. i .. "]: '" .. tostring(source) .. "'. Must be one of: 'extractor', 'production', 'reclaim', 'transfer'" }
		end
	end
	if #result > 0 then return result end
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

validators[Types.UnitName] = validators[Types.String]
validators[Types.FeatureName] = validators[Types.String]

validators[Types.UnitDefName] = function(unitDefName)
		local luaTypeResult = validators[Types.String](unitDefName)
		if luaTypeResult then
			return luaTypeResult
		end

		if not UnitDefNames[unitDefName] then
			return { { message = "Invalid unitDefName: " .. unitDefName } }
		end
	end

validators[Types.WeaponDefName] = function(weaponDefName)
	local luaTypeResult = validators[Types.String](weaponDefName)
	if luaTypeResult then
		return luaTypeResult
	end

	if not WeaponDefNames[weaponDefName] then
		return { { message = "Invalid weaponDefName: " .. weaponDefName } }
	end
end

validators[Types.FeatureDefName] = function(featureDefName)
	local luaTypeResult = validators[Types.String](featureDefName)
	if luaTypeResult then
		return luaTypeResult
	end

	if not FeatureDefNames[featureDefName] then
		return { { message = "Invalid featureDefName: " .. featureDefName } }
	end
end

validators[Types.Facing] = function(facing)
		local expectedTypes = { string = true, number = true }
		local actualType = type(facing)
		if not expectedTypes[actualType] then
			return { { message = "Unexpected parameter type, expected string or number, got " .. actualType } }
		end

		if not parameterTypeEnums[Types.Facing][facing] then
			return { { message = "Invalid facing: " .. facing .. ". Must be one of 'n', 's', 'e', 'w', 'north', 'south', 'east', 'west'." } }
		end
	end

validators[Types.SoundFile] = function(soundfile)
	local luaTypeResult = validators[Types.String](soundfile)
	if luaTypeResult then
		return luaTypeResult
	end

	if not VFS.FileExists(soundfile) then
		return { { message = "Invalid soundfile: " .. soundfile .. ". File does not exist" } }
	end

	local wavData = ReadWAV(soundfile)
	if not wavData then
		return { { message = "Invalid soundfile: " .. soundfile .. ". File is not a RIFF .wav file" } }
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

validators[Types.AllyTeamID] = function(allyTeamID)
	local luaTypeResult = validators[Types.Number](allyTeamID)
	if luaTypeResult then
		return luaTypeResult
	end

	if not table.contains(Spring.GetAllyTeamList(), allyTeamID) then
		return { { message = "Invalid allyTeamID: " .. allyTeamID } }
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
				end
			else
				local validationResults = validators[parameter.type](value) or {}
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
		elseif string.find(objective.text, '|') then
			logError("Objective text cannot contain the | character: " .. objectiveID)
		end
	end
end

local function validateStages(stages, initialStage)
	if not stages[initialStage] then
		logError("Initial stage does not exist in stages: " .. initialStage)
	end

	for stageID, stage in pairs(stages) do
		if not stage.title then
			logError("Stage missing title: " .. stageID)
		elseif stage.title == '' then
			logError("Stage has empty title: " .. stageID)
		elseif string.find(stage.title, '|') then
			logError("Stage title cannot contain the | character: " .. stageID)
		end
		for _, objectiveID in pairs(stage.objectives or {}) do
			if not GG['MissionAPI'].Objectives[objectiveID] then
				logError("Stage refers to non-existent objective. Stage: " .. stageID .. ", Objective: " .. objectiveID)
			end
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

----------------------------------------------------------------
--- Loadout Validation:
----------------------------------------------------------------

local function validateUnitLoadoutEntry(entry, index, context)
	local prefix = (context or "UnitLoadout") .. " entry #" .. index

	if type(entry) ~= 'table' then
		logError(prefix .. ": entry must be a table, got " .. type(entry))
		return
	end

	-- Required fields
	if entry.unitDefName == nil then
		logError(prefix .. ": missing required field 'unitDefName'")
	else
		local nameResult = validators[Types.UnitDefName](entry.unitDefName)
		if nameResult and not table.isEmpty(nameResult) then
			logError(prefix .. ", field 'unitDefName': " .. (nameResult[1] and nameResult[1].message or "invalid"))
		end
	end

	local positionResult = validators[Types.Position](entry)
	for _, positionError in ipairs(positionResult or {}) do
		logError(prefix .. ", " .. positionError.message .. (positionError.parameterNameSuffix or ""))
	end

	if entry.team == nil then
		logError(prefix .. ": missing required field 'team'")
	else
		local teamResult = validators[Types.TeamID](entry.team)
		if teamResult and not table.isEmpty(teamResult) then
			logError(prefix .. ", field 'team': " .. (teamResult[1] and teamResult[1].message or "invalid"))
		end
	end

	-- Optional fields
	if entry.facing ~= nil then
		local facingResult = validators[Types.Facing](entry.facing)
		if facingResult and not table.isEmpty(facingResult) then
			logError(prefix .. ", field 'facing': " .. (facingResult[1] and facingResult[1].message or "invalid"))
		end
	end

	if entry.unitName ~= nil then
		local unitNameResult = validators[Types.String](entry.unitName)
		if unitNameResult and not table.isEmpty(unitNameResult) then
			logError(prefix .. ", field 'unitName': " .. (unitNameResult[1] and unitNameResult[1].message or "invalid"))
		end
	end

	if entry.construction ~= nil then
		local constructionResult = validators[Types.Boolean](entry.construction)
		if constructionResult and not table.isEmpty(constructionResult) then
			logError(prefix .. ", field 'construction': " .. (constructionResult[1] and constructionResult[1].message or "invalid"))
		end
	end

	if entry.quantity ~= nil then
		local quantityResult = validators[Types.Number](entry.quantity)
		if quantityResult and not table.isEmpty(quantityResult) then
			logError(prefix .. ", field 'quantity': " .. (quantityResult[1] and quantityResult[1].message or "invalid"))
		end
	end

	if entry.spacing ~= nil then
		local spacingResult = validators[Types.Number](entry.spacing)
		if spacingResult and not table.isEmpty(spacingResult) then
			logError(prefix .. ", field 'spacing': " .. (spacingResult[1] and spacingResult[1].message or "invalid"))
		end
	end

	if entry.neutral ~= nil then
		local neutralResult = validators[Types.Boolean](entry.neutral)
		if neutralResult and not table.isEmpty(neutralResult) then
			logError(prefix .. ", field 'neutral': " .. (neutralResult[1] and neutralResult[1].message or "invalid"))
		end
	end

	if entry.orders ~= nil then
		local ordersResult = validators[Types.Orders](entry.orders)
		if ordersResult and not table.isEmpty(ordersResult) then
			for _, err in ipairs(ordersResult) do
				logError(prefix .. ", field 'orders'" .. (err.parameterNameSuffix or "") .. ": " .. (err.message or "invalid"))
			end
		end
	end
end

local function validateFeatureLoadoutEntry(entry, index, context)
	local prefix = (context or "FeatureLoadout") .. " entry #" .. index

	if type(entry) ~= 'table' then
		logError(prefix .. ": entry must be a table, got " .. type(entry))
		return
	end

	-- Required fields
	if entry.featureDefName == nil then
		logError(prefix .. ": missing required field 'featureDefName'")
	else
		local nameResult = validators[Types.FeatureDefName](entry.featureDefName)
		if nameResult and not table.isEmpty(nameResult) then
			logError(prefix .. ", field 'featureDefName': " .. (nameResult[1] and nameResult[1].message or "invalid"))
		end
	end

	local positionResult = validators[Types.Position](entry)
	for _, positionError in ipairs(positionResult or {}) do
		logError(prefix .. ", " .. positionError.message .. (positionError.parameterNameSuffix or ""))
	end

	-- Optional fields
	if entry.facing ~= nil then
		local facingResult = validators[Types.Facing](entry.facing)
		if facingResult and not table.isEmpty(facingResult) then
			logError(prefix .. ", field 'facing': " .. (facingResult[1] and facingResult[1].message or "invalid"))
		end
	end

	if entry.featureName ~= nil then
		local featureNameResult = validators[Types.String](entry.featureName)
		if featureNameResult and not table.isEmpty(featureNameResult) then
			logError(prefix .. ", field 'featureName': " .. (featureNameResult[1] and featureNameResult[1].message or "invalid"))
		end
	end
end

--- Validator for a unitLoadout table (array of unit entries).
--- Errors are logged directly by the entry helper; this returns {} so the
--- generic validate() machinery has nothing extra to report.
local function validateUnitLoadout(unitLoadout, actionOrTrigger, actionOrTriggerID, parameterName)
	if type(unitLoadout) ~= 'table' then
		return { { message = "UnitLoadout must be a table, got " .. type(unitLoadout) } }
	end
	local context = actionOrTriggerID and (actionOrTrigger .. " '" .. actionOrTriggerID .. "' " .. (parameterName or "unitLoadout"))
	for i, entry in ipairs(unitLoadout) do
		validateUnitLoadoutEntry(entry, i, context)
	end
	return {}
end

--- Validator for a featureLoadout table (array of feature entries).
local function validateFeatureLoadout(featureLoadout, actionOrTrigger, actionOrTriggerID, parameterName)
	if type(featureLoadout) ~= 'table' then
		return { { message = "FeatureLoadout must be a table, got " .. type(featureLoadout) } }
	end
	local context = actionOrTriggerID and (actionOrTrigger .. " '" .. actionOrTriggerID .. "' " .. (parameterName or "featureLoadout"))
	for i, entry in ipairs(featureLoadout) do
		validateFeatureLoadoutEntry(entry, i, context)
	end
	return {}
end

-- Patch the new types into the validators table now that the functions exist.
validators[Types.UnitLoadout]    = validateUnitLoadout
validators[Types.FeatureLoadout] = validateFeatureLoadout

local function validateLoadouts(unitLoadout, featureLoadout)
	if unitLoadout ~= nil then
		validateUnitLoadout(unitLoadout)
	end
	if featureLoadout ~= nil then
		validateFeatureLoadout(featureLoadout)
	end
end

local function getTypesWithParameterType(schemaParameters, parameterType)
	local typesWithParameter = {}

	for actionOrTriggerType, parameters in pairs(schemaParameters) do
		for _, parameter in ipairs(parameters) do
			if parameter.type == parameterType then
				typesWithParameter[actionOrTriggerType] = true
				break
			end
		end
	end

	return typesWithParameter
end

local function validateUnitNameReferences(triggerTypes, actionTypes, triggers, actions, unitLoadout)
	local triggerTypesReferencingUnitNames = getTypesWithParameterType(triggersSchemaParameters, Types.UnitName)
	local actionTypesNamingUnits = {
		[actionTypes.SpawnUnits] = true,
		[actionTypes.NameUnits] = true,
	}
	local actionTypesReferencingUnitNames = {
		[actionTypes.IssueOrders] = true,
		[actionTypes.UnnameUnits] = true,
		[actionTypes.TransferUnits] = true,
		[actionTypes.DespawnUnits] = true,
		[actionTypes.UpdateObjective] = true,
	}

	local createdUnitNames = {}
	local referencedUnitNames = {}

	-- Loadout entries with a unitName count as creating that name.
	for i, entry in ipairs(unitLoadout or {}) do
		if type(entry) == 'table' and entry.unitName then
			createdUnitNames[entry.unitName] = createdUnitNames[entry.unitName] or {}
			createdUnitNames[entry.unitName][#createdUnitNames[entry.unitName] + 1] = "UnitLoadout entry #" .. i
		end
	end

	-- SpawnUnits actions with inline unitLoadout entries also create names.
	for actionID, action in pairs(actions) do
		if action.type == actionTypes.SpawnUnits and action.parameters and action.parameters.unitLoadout then
			for i, entry in ipairs(action.parameters.unitLoadout) do
				if type(entry) == 'table' and entry.unitName then
					createdUnitNames[entry.unitName] = createdUnitNames[entry.unitName] or {}
					createdUnitNames[entry.unitName][#createdUnitNames[entry.unitName] + 1] = "action " .. actionID .. ", unitLoadout entry #" .. i
				end
			end
		end
	end

	-- Orders on IssueOrders actions can also refer to unit names:
	for actionID, action in pairs(actions) do
		if action.type == actionTypes.IssueOrders then
			for _, order in ipairs(action.parameters.orders) do
				local params = order[2]
				if type(params) == 'table' and params.unitName then
					local refsToUnitName = table.ensureTable(referencedUnitNames, params.unitName)
					refsToUnitName[#refsToUnitName + 1] = "action " .. actionID .. " (orders)"
				end
			end
		end
	end

	local function recordUnitNameCreationsAndReferences(typesNamingUnits, typesReferencingUnitNames, actionsOrTriggers, label)
		for actionOrTriggerID, actionOrTrigger in pairs(actionsOrTriggers) do
			local unitName = (actionOrTrigger.parameters or {}).unitName
			if unitName then
				if typesNamingUnits[actionOrTrigger.type] then
					local creatorsOfUnitName = table.ensureTable(createdUnitNames, unitName)
					creatorsOfUnitName[#creatorsOfUnitName + 1] = label .. actionOrTriggerID
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
			logWarn("Unit name '" .. unitName .. "' not created in any trigger or action. Referenced in: " .. table.concat(labels, ", "))
		end
	end
	for unitName, labels in pairs(createdUnitNames) do
		if not referencedUnitNames[unitName] then
			logWarn("Unit name '" .. unitName .. "' created, but not referenced by any trigger or action. Created in: " .. table.concat(labels, ", "))
		end
	end
end

local function validateFeatureNameReferences(triggerTypes, actionTypes, triggers, actions, featureLoadout)
	local triggerTypesReferencingFeatureNames = getTypesWithParameterType(triggersSchemaParameters, Types.FeatureName)
	local actionTypesNamingFeatures = {
		[actionTypes.CreateFeatures] = true,
	}
	local actionTypesReferencingFeatureNames = {
		[actionTypes.DestroyFeatures] = true,
	}

	local createdFeatureNames = {}
	local referencedFeatureNames = {}

	-- Loadout entries with a featureName count as creating that name.
	for i, entry in ipairs(featureLoadout or {}) do
		if type(entry) == 'table' and entry.featureName then
			createdFeatureNames[entry.featureName] = createdFeatureNames[entry.featureName] or {}
			createdFeatureNames[entry.featureName][#createdFeatureNames[entry.featureName] + 1] = "FeatureLoadout entry #" .. i
		end
	end

	-- SpawnLoadout actions with inline featureLoadout entries also create names.
	for actionID, action in pairs(actions) do
		if action.type == actionTypes.CreateFeatures and action.parameters and action.parameters.featureLoadout then
			for i, entry in ipairs(action.parameters.featureLoadout) do
				if type(entry) == 'table' and entry.featureName then
					createdFeatureNames[entry.featureName] = createdFeatureNames[entry.featureName] or {}
					createdFeatureNames[entry.featureName][#createdFeatureNames[entry.featureName] + 1] = "action " .. actionID .. ", featureLoadout entry #" .. i
				end
			end
		end
	end

	-- Orders on IssueOrders actions can also refer to feature names:
	for actionID, action in pairs(actions) do
		if action.type == actionTypes.IssueOrders then
			for _, order in ipairs(action.parameters.orders) do
				local params = order[2]
				if type(params) == 'table' and params.featureName then
					local refsToFeatureName = table.ensureTable(referencedFeatureNames, params.featureName)
					refsToFeatureName[#refsToFeatureName + 1] = "action " .. actionID .. " (orders)"
				end
			end
		end
	end

	local function recordFeatureNameCreationsAndReferences(typesNamingFeatures, typesReferencingFeatureNames, actionsOrTriggers, label)
		for actionOrTriggerID, actionOrTrigger in pairs(actionsOrTriggers) do
			local featureName = (actionOrTrigger.parameters or {}).featureName
			if featureName then
				if typesNamingFeatures[actionOrTrigger.type] then
					local creatorsOfFeatureName = table.ensureTable(createdFeatureNames, featureName)
					creatorsOfFeatureName[#creatorsOfFeatureName + 1] = label .. actionOrTriggerID
				elseif typesReferencingFeatureNames[actionOrTrigger.type] then
					local refsToFeatureName = table.ensureTable(referencedFeatureNames, featureName)
					refsToFeatureName[#refsToFeatureName + 1] = label .. actionOrTriggerID
				end
			end
		end
	end

	recordFeatureNameCreationsAndReferences({}, triggerTypesReferencingFeatureNames, triggers, "trigger ")
	recordFeatureNameCreationsAndReferences(actionTypesNamingFeatures, actionTypesReferencingFeatureNames, actions, "action ")

	for featureName, labels in pairs(referencedFeatureNames) do
		if not createdFeatureNames[featureName] then
			logWarn("Feature name '" .. featureName .. "' not created in any trigger or action. Referenced in: " .. table.concat(labels, ", "))
		end
	end
	for featureName, labels in pairs(createdFeatureNames) do
		if not referencedFeatureNames[featureName] then
			logWarn("Feature name '" .. featureName .. "' created, but not referenced by any trigger or action. Created in: " .. table.concat(labels, ", "))
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
			logWarn("Marker name '" .. markerName .. "' is not created in any action. Referenced in: " .. table.concat(actionIDs, ", "))
		end
	end
	for markerName, actionIDs in pairs(createdMarkerNames) do
		if not referencedMarkerNames[markerName] then
			logWarn("Marker name '" .. markerName .. "' is not referenced by any action. Referenced in: " .. table.concat(actionIDs, ", "))
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
	local unitLoadout = GG['MissionAPI'].UnitLoadout
	local featureLoadout = GG['MissionAPI'].FeatureLoadout
	validateObjectiveReferences(objectives)
	validateUnitNameReferences(triggerTypes, actionTypes, triggers, actions, unitLoadout)
	validateFeatureNameReferences(triggerTypes, actionTypes, triggers, actions, featureLoadout)
	validateMarkerNameReferences(actionTypes, actions)
	validateLoadouts(unitLoadout, featureLoadout)
end

return {
	ValidateObjectives = validateObjectives,
	ValidateStages = validateStages,
	ValidateTriggers = validateTriggers,
	ValidateActions = validateActions,
	ValidateReferences = validateReferences,
}
