---
--- The parameter validators: one per parameter type.
---
--- A validator takes a value and returns a list of results, or nil when the value is valid.
--- A result is { message, parameterNameSuffix }, where the suffix names the part of the
--- parameter the message is about, e.g. "[2].unitDefName", if any.
---

VFS.Include('common/wav.lua')

--------------------------------------------------------------------------------
-- Helper functions
--------------------------------------------------------------------------------

local function validateLuaType(value, expectedType)
	local actualType = type(value)
	if value ~= nil and actualType ~= expectedType then
		return "Unexpected parameter type, expected " .. expectedType .. ", got " .. actualType
	end
end

--- Validates a named field of a value, e.g. the x of a position.
local function validateField(value, fieldName, expectedType)
	if value == nil then
		return { message = "Missing required parameter", parameterNameSuffix = "." .. fieldName }
	end
	if type(value) ~= expectedType then
		return { message = "Unexpected parameter type, expected " .. expectedType .. ", got " .. type(value), parameterNameSuffix = "." .. fieldName }
	end
end

--- Adds results to a result list, naming each one after the part it came from,
--- e.g. the index of a list element or the name of a field.
local function appendResults(results, addedResults, parameterNamePrefix)
	for _, addedResult in ipairs(addedResults or {}) do
		results[#results + 1] = {
			message = addedResult.message,
			parameterNameSuffix = (parameterNamePrefix or '') .. (addedResult.parameterNameSuffix or ''),
			isWarning = addedResult.isWarning,
		}
	end
	return results
end

-- Wraps validateLuaType as a validator, which returns a list of results
local function getLuaTypeValidator(expectedType)
	return function(value)
		local luaTypeResult = validateLuaType(value, expectedType)
		return luaTypeResult and { { message = luaTypeResult } } or nil
	end
end

local validateTableType = getLuaTypeValidator('table')

--- Validates that a value of a valid type also exists, e.g. a stage ID or a unit def name.
--- The lookup is a function, so engine def tables are read when the value is validated.
local function getLookupValidator(typeValidator, valueName, lookup)
	return function(value)
		local typeResult = typeValidator(value)
		if typeResult then
			return typeResult
		end

		if not lookup(value) then
			return { { message = "Invalid " .. valueName .. ": " .. value } }
		end
	end
end

--- Validates list elements with provided validator, naming results after the index.
--- Pass emptyMessage for lists that must not be empty.
local function getListValidator(elementValidator, emptyMessage)
	return function(values)
		local luaTypeResult = validateTableType(values)
		if luaTypeResult then
			return luaTypeResult
		end

		if emptyMessage and table.isNilOrEmpty(values) then
			return { { message = emptyMessage } }
		end

		local results = {}
		for index, value in pairs(values) do
			appendResults(results, elementValidator(value), "[" .. index .. "]")
		end
		return results
	end
end

--------------------------------------------------------------------------------
-- Value validators: Lua types, strings, numbers and enum sets
--------------------------------------------------------------------------------

local function getEnumSetValidator(enums, enumSetName, enumSetList)
	local valueSet = enums[enumSetName]
	local allowedList = "'" .. table.concat(enumSetList, "', '") .. "'"

	return function(values)
		local luaTypeResult = validateTableType(values)
		if luaTypeResult then
			return luaTypeResult
		end
		if #values == 0 then
			return -- Empty table matches the empty set and is permissive.
		end

		local results = {}
		for index, value in ipairs(values) do
			if not valueSet[value] then
				results[#results + 1] = {
					message = "Invalid " .. enumSetName .. ": '" .. tostring(value) .. "'. Must be one of: " .. allowedList,
					parameterNameSuffix = "[" .. index .. "]",
				}
			end
		end
		if #results > 0 then
			return results
		end
	end
end

local function registerValueValidators(parameterValidators, context)
	local Types = context.Types
	local enums = context.Enums

	--- Lua type validators:
	parameterValidators[Types.Table] = validateTableType
	parameterValidators[Types.String] = getLuaTypeValidator('string')
	parameterValidators[Types.Number] = getLuaTypeValidator('number')
	parameterValidators[Types.Boolean] = getLuaTypeValidator('boolean')
	parameterValidators[Types.Function] = getLuaTypeValidator('function')

	--- Enum set validators:
	for enumSetName, valuesList in pairs(context.EnumSets) do
		parameterValidators[enumSetName] = getEnumSetValidator(enums, enumSetName, valuesList)
	end

	--- String validators:
	local validateString = parameterValidators[Types.String]

	parameterValidators[Types.StageID] = getLookupValidator(validateString, 'stageID',
		function(stageID) return context.Stages[stageID] end)
	parameterValidators[Types.ObjectiveID] = getLookupValidator(validateString, 'objectiveID',
		function(objectiveID) return context.Objectives[objectiveID] end)
	parameterValidators[Types.TriggerID] = getLookupValidator(validateString, 'triggerID',
		function(triggerID) return context.Triggers[triggerID] end)

	parameterValidators[Types.UnitDefName] = getLookupValidator(validateString, 'unitDefName',
		function(unitDefName) return UnitDefNames[unitDefName] end)
	parameterValidators[Types.WeaponDefName] = getLookupValidator(validateString, 'weaponDefName',
		function(weaponDefName) return WeaponDefNames[weaponDefName] end)
	parameterValidators[Types.FeatureDefName] = getLookupValidator(validateString, 'featureDefName',
		function(featureDefName) return FeatureDefNames[featureDefName] end)

	parameterValidators[Types.UnitName] = validateString
	parameterValidators[Types.FeatureName] = validateString

	--- List validators, checking each element with its own type's validator:
	parameterValidators[Types.StageIDs] = getListValidator(parameterValidators[Types.StageID])
	parameterValidators[Types.TriggerIDs] = getListValidator(parameterValidators[Types.TriggerID])

	parameterValidators[Types.Facing] = function(facing)
		local expectedTypes = { string = true, number = true }
		local actualType = type(facing)
		if not expectedTypes[actualType] then
			return { { message = "Unexpected parameter type, expected string or number, got " .. actualType } }
		end

		if not enums[Types.Facing][facing] then
			return { { message = "Invalid facing: " .. facing .. ". Must be one of 'n', 's', 'e', 'w', 'north', 'south', 'east', 'west'" } }
		end
	end

	parameterValidators[Types.SoundFile] = function(soundfile)
		local luaTypeResult = validateString(soundfile)
		if luaTypeResult then
			return luaTypeResult
		end

		if not VFS.FileExists(soundfile) then
			return { { message = "Invalid soundfile: " .. soundfile .. ". File does not exist" } }
		end

		if not ReadWAV(soundfile) then
			return { { message = "Invalid soundfile: " .. soundfile .. ". File is not a RIFF .wav file" } }
		end
	end

	--- Number validators:
	parameterValidators[Types.Quantity] = function(quantity)
		local luaTypeResult = parameterValidators[Types.Number](quantity)
		if luaTypeResult then
			return luaTypeResult
		end

		if quantity < 0 then
			return { { message = "Quantity must be >= 0, got " .. quantity } }
		end
	end

	parameterValidators[Types.Fraction] = function(fraction)
		local luaTypeResult = parameterValidators[Types.Number](fraction)
		if luaTypeResult then
			return luaTypeResult
		end

		if fraction < 0.0 or fraction > 1.0 then
			return { { message = "Fraction must be between 0 and 1, got " .. fraction } }
		end
	end
end

--------------------------------------------------------------------------------
-- Spatial validators: Position, Positions, Area and Direction
--------------------------------------------------------------------------------

-- Height is optional, so a position without y is only checked for x and z.
local positionFields = { "x", "z" }
local positionFieldsWithHeight = { "x", "y", "z" }

local function registerSpatialValidators(parameterValidators, context)
	local Types = context.Types

	parameterValidators[Types.Position] = function(position)
		local luaTypeResult = validateTableType(position)
		if luaTypeResult then
			return luaTypeResult
		end

		local result = {}
		local fields = position.y ~= nil and positionFieldsWithHeight or positionFields
		for _, field in ipairs(fields) do
			local fieldResult = validateField(position[field], field, 'number')
			if fieldResult then
				result[#result + 1] = fieldResult
			end
		end

		return result
	end

	local validatePositionList = getListValidator(parameterValidators[Types.Position])

	parameterValidators[Types.Positions] = function(positions)
		local result = validatePositionList(positions)

		-- Counting only makes sense once the list validator has confirmed a table
		if type(positions) == 'table' and #positions < 2 then
			table.insert(result, 1, { message = "Positions table needs at least two positions" })
		end

		return result
	end

	parameterValidators[Types.Area] = function(area)
		local luaTypeResult = validateTableType(area)
		if luaTypeResult then
			return luaTypeResult
		end

		local isRectangle = area.x1 and area.z1 and area.x2 and area.z2
		local isCircle = area.x and area.z and area.radius
		if not isRectangle and not isCircle then
			return { { message = "Invalid area parameter, must be either rectangle { x1, z1, x2, z2 } with x1 < x2 and z1 < z2, or circle { x, z, radius }" } }
		end

		-- Every field of an area is a number, whether it is a rectangle or a circle.
		local result = {}
		for key, value in pairs(area) do
			local fieldResult = validateField(value, key, 'number')
			if fieldResult then
				result[#result + 1] = fieldResult
			end
		end
		if not table.isEmpty(result) then
			return result
		end

		-- Corners can only be compared once every field is known to be a number.
		if isRectangle then
			if area.x1 >= area.x2 then
				result[#result + 1] = { message = "Invalid area rectangle parameter, x1 must be less than x2" }
			end
			if area.z1 >= area.z2 then
				result[#result + 1] = { message = "Invalid area rectangle parameter, z1 must be less than z2" }
			end
		end

		return result
	end

	--- A direction is either an angle or a vector, which is validated as a position.
	parameterValidators[Types.Direction] = function(direction)
		local luaTypeResult = validateTableType(direction)
		if luaTypeResult then
			return luaTypeResult
		end

		local isAngle = direction.angle ~= nil
		local isVector = direction.x ~= nil and direction.z ~= nil
		if not isAngle and not isVector then
			return { { message = "Invalid direction parameter, must be either angle { angle }, or direction { x, z, optional y }" } }
		end
		if isAngle and isVector then
			return { { message = "Invalid direction parameter, must be either angle { angle }, or direction { x, z, optional y }, not both" } }
		end

		if isVector then
			return parameterValidators[Types.Position](direction)
		end

		local angleResult = validateField(direction.angle, 'angle', 'number')
		return angleResult and { angleResult } or nil
	end
end

--------------------------------------------------------------------------------
-- Team validators: TeamID, AllyTeamID and AllyTeamIDs
--------------------------------------------------------------------------------

local function registerTeamValidators(parameterValidators, context)
	local Types = context.Types
	local validateNumber = parameterValidators[Types.Number]

	parameterValidators[Types.TeamID] = getLookupValidator(validateNumber, 'teamID',
		function(teamID) return Spring.GetTeamAllyTeamID(teamID) end)

	parameterValidators[Types.AllyTeamID] = getLookupValidator(validateNumber, 'allyTeamID',
		function(allyTeamID) return table.contains(Spring.GetAllyTeamList(), allyTeamID) end)

	parameterValidators[Types.AllyTeamIDs] = getListValidator(parameterValidators[Types.AllyTeamID], "allyTeamIDs table is empty")
end

--------------------------------------------------------------------------------
-- Order validators: command IDs, their parameters, and their options
--
-- An order is { commandID, parameters, options }, so results are named after the position
-- they came from, e.g. "[2][4]" for the fourth parameter. The index of the order itself is
-- added by the list validator.
--------------------------------------------------------------------------------

local validOrderOptions = { right = true, alt = true, ctrl = true, shift = true, meta = true }

local function addResult(results, message, parameterNameSuffix, isWarning)
	results[#results + 1] = {
		message = message,
		parameterNameSuffix = parameterNameSuffix,
		isWarning = isWarning,
	}
end

--- Command parameter validators take (params, results), so they can be built once.
local function getNumberArrayValidator(sizes, message, nameKeys)
	return function(params, results)
		local luaTypeResult = validateLuaType(params, 'table')
		if luaTypeResult then
			return addResult(results, luaTypeResult, '[2]')
		end
		params = params or {}

		if nameKeys and table.any(nameKeys, function(nameKey) return params[nameKey] ~= nil end) then
			-- params names a unit or feature instead of giving coordinates
			return
		end

		if not table.contains(sizes, #params) then
			return addResult(results, "Parameter must be an array of " .. message, '[2]')
		end

		for index, param in ipairs(params) do
			local paramTypeResult = validateLuaType(param, 'number')
			if paramTypeResult then
				return addResult(results, paramTypeResult, '[2][' .. index .. ']')
			end
		end
	end
end

--- Commands like GUARD take the name of a unit or feature instead of coordinates.
local function getNameValidator(nameKey, message)
	return function(params, results)
		local luaTypeResult = validateLuaType(params, 'table')
		if luaTypeResult then
			addResult(results, luaTypeResult, '[2]')
		elseif params == nil or params[nameKey] == nil then
			addResult(results, "Parameter must be " .. message, '[2]')
		end
	end
end

local function validateNumberParam(params, results)
	local luaTypeResult = validateLuaType(params, 'number')
	if luaTypeResult then
		addResult(results, luaTypeResult, '[2]')
	end
end

local validateUnitNameParam = getNameValidator('unitName', "{ unitName = 'aUnitName' }")
local validate3 = getNumberArrayValidator({ 3 }, "3 numbers {x, y, z}")
local validate3orUnitName = getNumberArrayValidator({ 3 }, "3 numbers {x, y, z}, or a unit name", { 'unitName' })
local validate3or4 = getNumberArrayValidator({ 3, 4 }, "3 or 4 numbers {x, y, z, optional radius}")
local validate4 = getNumberArrayValidator({ 4 }, "4 numbers {x, y, z, radius}")
local validate4orUnitName = getNumberArrayValidator({ 4 }, "4 numbers {x, y, z, radius}, or a unit name", { 'unitName' })
local validate4orFeatureName = getNumberArrayValidator({ 4 }, "4 numbers {x, y, z, radius}, or a feature name", { 'featureName' })
local validate4orEitherName = getNumberArrayValidator({ 4 }, "4 numbers {x, y, z, radius}, or a unit/feature name", { 'unitName', 'featureName' })

-- Build commands are unitDefName strings, see https://springrts.com/wiki/Lua_CMDs#CMD.INTERNAL
local validateBuildOrder = getNumberArrayValidator({ 0, 3, 4 }, "3 or 4 numbers {x, y, z, optional facing}, or no parameters for factories")

--- Parameter validator per command name. false means the command takes no parameters.
local validatorsByCommandName = {
	-- No parameters:
	STOP = false,
	SELFD = false,
	AREA_ATTACK = false, -- currently broken in engine
	-- Unit name parameter:
	GUARD = validateUnitNameParam,
	-- 3 number parameters:
	DGUN = validate3,
	MOVE = validate3,
	FIGHT = validate3,
	PATROL = validate3,
	-- 3 or 4 number parameters:
	UNLOAD_UNITS = validate3or4,
	-- 4 number parameters:
	AREA_ATTACK_GROUND = validate4, -- Only artillery units (customParams.canareaattack = 1) support this
	RESTORE = validate4,
	-- 3 number parameters, or unit name:
	ATTACK = validate3orUnitName,
	-- 4 number parameters, or unit name:
	CAPTURE = validate4orUnitName,
	REPAIR = validate4orUnitName,
	LOAD_UNITS = validate4orUnitName,
	-- 4 number parameters, or feature name:
	RESURRECT = validate4orFeatureName,
	-- 4 number parameters, or either unit or feature name:
	RECLAIM = validate4orEitherName,
	-- Single number parameter:
	CLOAK = validateNumberParam,
	ONOFF = validateNumberParam,
	FIRE_STATE = validateNumberParam,
	MOVE_STATE = validateNumberParam,
}

local function validateOrderOptions(options, results)
	if not options then
		return
	end

	local luaTypeResult = validateLuaType(options, 'table')
	if luaTypeResult then
		return addResult(results, luaTypeResult, '[3]')
	end

	for _, optionName in pairs(options) do
		if not validOrderOptions[optionName] then
			addResult(results, "Invalid order option: " .. optionName, '[3]')
		end
	end
end

local function registerOrderValidators(parameterValidators, context)
	local Types = context.Types
	local facingEnum = context.Enums[Types.Facing]

	-- Set of command IDs from CMD and GameCMD:
	local knownCMDs = {}
	for cmdID in pairs(CMD) do
		knownCMDs[cmdID] = true
	end
	for cmdID in pairs(GameCMD) do
		knownCMDs[cmdID] = true
	end

	-- These commands use an allow-consume pattern that causes them never to reach :UnitCommand.
	-- Rather, the :AllowCommand callin catches them, executes their behavior and returns false.
	local consumedInAllowCommand = {}
	for _, entry in ipairs({
		{ command = CMD.CLOAK, reason = "unit_cloak (replaced by WANT_CLOAK)" },
		{ command = GameCMD.UNIT_SET_TARGET, reason = "unit_target_on_the_move" },
		{ command = GameCMD.UNIT_SET_TARGET_NO_GROUND, reason = "unit_target_on_the_move" },
		{ command = GameCMD.UNIT_SET_TARGET_RECTANGLE, reason = "unit_target_on_the_move" },
		{ command = GameCMD.UNIT_CANCEL_TARGET, reason = "unit_target_on_the_move" },
		{ command = GameCMD.PRIORITY, reason = "unit_builder_priority" },
		{ command = GameCMD.FACTORY_GUARD, reason = "unit_factory_guard" },
		{ command = GameCMD.STOP_PRODUCTION, reason = "cmd_factory_stop_production" },
		{ command = GameCMD.QUOTA_BUILD_TOGGLE, reason = "unit_factory_quota" },
		{ command = GameCMD.LAND_AT, reason = "unit_air_plants" },
		{ command = GameCMD.SMART_TOGGLE, reason = "unit_weapon_smart_select_helper" },
		{ command = GameCMD.CARRIER_SPAWN_ONOFF, reason = "unit_carrier_spawner" },
		{ command = GameCMD.MANUAL_LAUNCH, reason = "cmd_manual_launch (reissued as CMD.MANUALFIRE)" },
	}) do
		if entry.command then
			consumedInAllowCommand[entry.command] = entry.reason
		end
	end

	parameterValidators[Types.Command] = function(command)
		if command == CMD.ANY or command == CMD.BUILD then
			return
		end
		if type(command) == 'number' then
			local results = {}
			if not knownCMDs[command] then
				addResult(results, "Unknown command ID: " .. tostring(command))
				return results
			end
			if consumedInAllowCommand[command] then
				addResult(
					results,
					"Command " .. tostring(CMD[command] or GameCMD[command] or command) .. " may fail to trigger in UnitOrdered",
					nil, true)
				return results
			end
		elseif type(command) == 'string' then
			if not UnitDefNames[command] then
				return { { message = "Invalid unitDefName: " .. command } }
			end
		else
			return { { message = "Unexpected parameter type, expected number or string, got " .. type(command) } }
		end
	end

	-- Validators by command ID, skipping any command this engine version does not define.
	local commandValidators = {}
	for commandName, commandValidator in pairs(validatorsByCommandName) do
		local commandID = CMD[commandName] or GameCMD[commandName]
		if commandID ~= nil then
			commandValidators[commandID] = commandValidator
		end
	end

	local function validateCommandAndParams(order, results)
		local commandID = order[1]
		local params = order[2]
		local commandValidator = commandValidators[commandID]

		if commandID == nil then
			addResult(results, "Order is missing a command ID")
		elseif commandValidator ~= nil then
			-- `false` means the command takes no parameters, so there is nothing to check.
			if commandValidator then
				commandValidator(params, results)
			end
		elseif type(commandID) == 'string' then
			-- Build order: the command ID is a unitDefName.
			if not UnitDefNames[commandID] then
				addResult(results, "Invalid build order unitDefName: " .. commandID, '[1]')
			end

			validateBuildOrder(params, results)
			if #(params or {}) == 4 and not facingEnum[params[4]] then
				addResult(results, "Invalid build order facing: " .. params[4] .. ". Must be one of 0, 1, 2, 3", '[2][4]')
			end
		elseif not knownCMDs[commandID] then
			addResult(results, "Unknown command ID: " .. tostring(commandID), '[1]')
		else
			-- A command the engine knows, but this module does not check yet
			addResult(results, "No validator implemented for orders with command ID: " .. tostring(commandID), '[1]', true)
		end
	end

	local function validateOrder(order)
		local orderTypeResult = validateTableType(order)
		if orderTypeResult then
			return orderTypeResult
		end

		local results = {}
		validateCommandAndParams(order, results)
		validateOrderOptions(order[3], results)
		return results
	end

	parameterValidators[Types.Orders] = getListValidator(validateOrder, "Orders table is empty")
end

--------------------------------------------------------------------------------
-- Loadout validators: unit and feature loadout entries
--------------------------------------------------------------------------------

local function registerLoadoutValidators(parameterValidators, context)
	local Types = context.Types

	--- Named fields of a loadout entry, in the order they are reported. The position of an
	--- entry is not among them, since its x, y and z sit directly on the entry.
	local unitEntryFields = {
		{ name = 'unitDefName',  type = Types.UnitDefName, required = true },
		{ name = 'team',         type = Types.TeamID, required = true },
		{ name = 'facing',       type = Types.Facing },
		{ name = 'unitName',     type = Types.String },
		{ name = 'construction', type = Types.Boolean },
		{ name = 'quantity',     type = Types.Number },
		{ name = 'spacing',      type = Types.Number },
		{ name = 'neutral',      type = Types.Boolean },
		{ name = 'orders',       type = Types.Orders },
	}

	local featureEntryFields = {
		{ name = 'featureDefName', type = Types.FeatureDefName, required = true },
		{ name = 'facing',         type = Types.Facing },
		{ name = 'featureName',    type = Types.String },
	}

	local function getEntryValidator(fields)
		return function(entry)
			local entryTypeResult = validateTableType(entry)
			if entryTypeResult then
				return entryTypeResult
			end

			-- The entry itself is the position, since x, y and z are fields of the entry.
			local results = appendResults({}, parameterValidators[Types.Position](entry))

			for _, field in ipairs(fields) do
				local value = entry[field.name]
				if value == nil then
					if field.required then
						results[#results + 1] = { message = "Missing required parameter", parameterNameSuffix = "." .. field.name }
					end
				else
					appendResults(results, parameterValidators[field.type](value), "." .. field.name)
				end
			end

			return results
		end
	end

	parameterValidators[Types.UnitLoadout] = getListValidator(getEntryValidator(unitEntryFields))
	parameterValidators[Types.FeatureLoadout] = getListValidator(getEntryValidator(featureEntryFields))
end

--------------------------------------------------------------------------------

local function createParameterValidators(context)
	local parameterValidators = {}

	-- Registered in dependency order: later groups build on the earlier types.
	registerValueValidators(parameterValidators, context)
	registerSpatialValidators(parameterValidators, context)
	registerTeamValidators(parameterValidators, context)
	registerOrderValidators(parameterValidators, context)
	registerLoadoutValidators(parameterValidators, context)

	return parameterValidators
end

return {
	CreateParameterValidators = createParameterValidators,
}
