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

	[Types.FeatureDefName] = function(featureDefName)
		local luaTypeResult = luaTypeValidators[Types.String](featureDefName)
		if luaTypeResult then
			return luaTypeResult
		end

		if not FeatureDefNames[featureDefName] then
			return { { message = "Invalid featureDefName: " .. featureDefName } }
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

	[Types.AllyTeamID] = function(allyTeamID)
		local luaTypeResult = luaTypeValidators[Types.Number](allyTeamID)
		if luaTypeResult then
			return luaTypeResult
		end

		if not table.contains(Spring.GetAllyTeamList(), allyTeamID) then
			return { { message = "Invalid allyTeamID: " .. allyTeamID } }
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
	if entry.name == nil then
		logError(prefix .. ": missing required field 'name'")
	else
		local nameResult = validators[Types.UnitDefName](entry.name)
		if nameResult and not table.isEmpty(nameResult) then
			logError(prefix .. ", field 'name': " .. (nameResult[1] and nameResult[1].message or "invalid"))
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

	if entry.neutral ~= nil then
		local neutralResult = validators[Types.Boolean](entry.neutral)
		if neutralResult and not table.isEmpty(neutralResult) then
			logError(prefix .. ", field 'neutral': " .. (neutralResult[1] and neutralResult[1].message or "invalid"))
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
	if entry.name == nil then
		logError(prefix .. ": missing required field 'name'")
	else
		local nameResult = validators[Types.FeatureDefName](entry.name)
		if nameResult and not table.isEmpty(nameResult) then
			logError(prefix .. ", field 'name': " .. (nameResult[1] and nameResult[1].message or "invalid"))
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

	if entry.resurrectAs ~= nil then
		local resurrectAsResult = validators[Types.UnitDefName](entry.resurrectAs)
		if resurrectAsResult and not table.isEmpty(resurrectasResult) then
			logError(prefix .. ", field 'resurrectas': " .. (resurrectasResult[1] and resurrectasResult[1].message or "invalid"))
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

local function validateUnitNameReferences(triggerTypes, actionTypes, triggers, actions, unitLoadout)
	local triggerTypesReferencingUnitNames = {
		[triggerTypes.UnitNotExists] = true,
		[triggerTypes.UnitKilled] = true,
		[triggerTypes.UnitCaptured] = true,
		[triggerTypes.UnitEnteredLocation] = true,
		[triggerTypes.UnitLeftLocation] = true,
		[triggerTypes.UnitDwellLocation] = true,
		[triggerTypes.UnitSpotted] = true,
		[triggerTypes.UnitUnspotted] = true,
		[triggerTypes.ConstructionFinished] = true,
	}
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

	-- SpawnLoadout actions with inline unitLoadout entries also create names.
	for actionID, action in pairs(actions) do
		if action.type == actionTypes.SpawnLoadout and action.parameters and action.parameters.unitLoadout then
			for i, entry in ipairs(action.parameters.unitLoadout) do
				if type(entry) == 'table' and entry.unitName then
					createdUnitNames[entry.unitName] = createdUnitNames[entry.unitName] or {}
					createdUnitNames[entry.unitName][#createdUnitNames[entry.unitName] + 1] = "action " .. actionID .. ", unitLoadout entry #" .. i
				end
			end
		end
	end

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

local function validateFeatureNameReferences(triggerTypes, actionTypes, triggers, actions, featureLoadout)
	local triggerTypesReferencingFeatureNames = {
		[triggerTypes.FeatureCreated]   = true,
		[triggerTypes.FeatureReclaimed] = true,
		[triggerTypes.FeatureDestroyed] = true,
	}
	local actionTypesNamingFeatures = {
		[actionTypes.CreateFeature] = true,
	}
	local actionTypesReferencingFeatureNames = {
		[actionTypes.DestroyFeature] = true,
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
		if action.type == actionTypes.SpawnLoadout and action.parameters and action.parameters.featureLoadout then
			for i, entry in ipairs(action.parameters.featureLoadout) do
				if type(entry) == 'table' and entry.featureName then
					createdFeatureNames[entry.featureName] = createdFeatureNames[entry.featureName] or {}
					createdFeatureNames[entry.featureName][#createdFeatureNames[entry.featureName] + 1] = "action " .. actionID .. ", featureLoadout entry #" .. i
				end
			end
		end
	end

	local function recordFeatureNameCreationsAndReferences(typesNamingFeatures, typesReferencingFeatureNames, actionsOrTriggers, label)
		for actionOrTriggerID, actionOrTrigger in pairs(actionsOrTriggers) do
			local featureName = (actionOrTrigger.parameters or {}).featureName
			if featureName then
				if typesNamingFeatures[actionOrTrigger.type] then
					createdFeatureNames[featureName] = createdFeatureNames[featureName] or {}
					createdFeatureNames[featureName][#createdFeatureNames[featureName] + 1] = label .. actionOrTriggerID
				elseif typesReferencingFeatureNames[actionOrTrigger.type] then
					referencedFeatureNames[featureName] = referencedFeatureNames[featureName] or {}
					referencedFeatureNames[featureName][#referencedFeatureNames[featureName] + 1] = label .. actionOrTriggerID
				end
			end
		end
	end

	recordFeatureNameCreationsAndReferences({}, triggerTypesReferencingFeatureNames, triggers, "trigger ")
	recordFeatureNameCreationsAndReferences(actionTypesNamingFeatures, actionTypesReferencingFeatureNames, actions, "action ")

	for featureName, labels in pairs(referencedFeatureNames) do
		if not createdFeatureNames[featureName] then
			logError("Feature name '" .. featureName .. "' not created in any trigger or action. Referenced in: " .. table.concat(labels, ", "))
		end
	end
	for featureName, labels in pairs(createdFeatureNames) do
		if not referencedFeatureNames[featureName] then
			logError("Feature name '" .. featureName .. "' created, but not referenced by any trigger or action. Created in: " .. table.concat(labels, ", "))
		end
	end
end

return {
	ValidateTriggers              = validateTriggers,
	ValidateActions               = validateActions,
	ValidateLoadouts              = validateLoadouts,
	ValidateUnitNameReferences    = validateUnitNameReferences,
	ValidateFeatureNameReferences = validateFeatureNameReferences,
}
