---
--- Order list parameter validator: checks command IDs, their parameters, and their options.
---
--- An order is { commandID, parameters, options }, so results are named after the position
--- they came from, e.g. "[2][4]" for the fourth parameter. The index of the order itself is
--- added by the list validator.
---

local validatorUtils = VFS.Include('luarules/mission_api/validation/parameter_validators/validator_utils.lua')
local validateLuaType = validatorUtils.ValidateLuaType
local validateTableType = validatorUtils.ValidateTableType
local getListValidator = validatorUtils.GetListValidator

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

local function register(parameterValidators, context)
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

return {
	Register = register,
}
