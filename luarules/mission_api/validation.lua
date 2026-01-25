--
-- Validators for Mission API action and trigger parameters loaded from missions.
--

local function logError(message)
	Spring.Log('validation.lua', LOG.ERROR, "[Mission API] " .. message)
end

function validateParameters(schemaParameters, actionOrTriggerType, actionOrTriggerParameters, actionOrTrigger, actionOrTriggerID)
	if not actionOrTriggerType then
		logError(actionOrTrigger .. " missing type. " .. actionOrTrigger .. ": " .. actionOrTriggerID)
	elseif not schemaParameters[actionOrTriggerType] then
		logError(actionOrTrigger .. " has invalid type. " .. actionOrTrigger .. ": " .. actionOrTriggerID)
	else
		for _, parameter in pairs(schemaParameters[actionOrTriggerType]) do
			local value = actionOrTriggerParameters[parameter.name]

			if value == nil and parameter.required then
				logError(actionOrTrigger .. " missing required parameter. " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameter.name)
			else
				parameter.type(value, 'Action', actionOrTriggerID, parameter.name)
			end
		end
	end
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
		logError("Action missing required parameter. " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameterName .. "." .. fieldName)
		return false
	end
	if type(value) ~= expectedType then
		logError("Unexpected parameter type, expected " .. expectedType .. ", got " .. type(value) .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameterName .. "." .. fieldName)
		return false
	end
	return true
end

Types = {

	----------------------------------------------------------------
	--- Table Validators:
	----------------------------------------------------------------

	table = function(table, actionOrTrigger, actionOrTriggerID, parameterName)
		validateLuaType(table, 'table', actionOrTrigger, actionOrTriggerID, parameterName)
	end,

	position = function(position, actionOrTrigger, actionOrTriggerID, parameterName)
		if not Types.table(position, actionOrTrigger, actionOrTriggerID, parameterName) then
			return
		end

		for _, parm in pairs({"x", "z"}) do
			validateField(position[parm], parm, 'number', actionOrTrigger, actionOrTriggerID, parameterName)
		end

		position.y = position.y or Spring.GetGroundHeight(position.x, position.z)
		validateField(position.y, 'y', 'number', actionOrTriggerID, parameterName)
	end,

	allyTeamIDs = function(allyTeamIDs, actionOrTrigger, actionOrTriggerID, parameterName)
		if not Types.table(allyTeamIDs, actionOrTrigger, actionOrTriggerID, parameterName) then
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

	orders = function(orders, actionOrTrigger, actionOrTriggerID, parameterName)

		local function validateOrderCommandAndParams(commandID, params, orderNumber)
			local function validateNumberArrayCurried(sizes, message)
				return function()
					if not validateLuaType(params, 'table', actionOrTrigger, actionOrTriggerID, parameterName .. '[' .. orderNumber .. ']' .. '[2]') then
						return
					end
					if not table.contains(sizes, #params) then
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
			if options and Types.table(options, actionOrTrigger, actionOrTriggerID, parameterName .. '[3]') then
				for _, optionName in pairs(options) do
					if not validOptions[optionName] then
						logError("Invalid order option: " .. optionName .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameterName .. ", Order #" .. orderNumber)
					end
				end
			end
		end

		if not Types.table(orders, actionOrTrigger, actionOrTriggerID, parameterName) then
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

	area = function(area, actionOrTrigger, actionOrTriggerID, parameterName)
		if not Types.table(area, actionOrTrigger, actionOrTriggerID, parameterName) then
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

	string = function(string, actionOrTrigger, actionOrTriggerID, parameterName)
		validateLuaType(string, 'string', actionOrTrigger, actionOrTriggerID, parameterName)
	end,

	triggerID = function(triggerID, actionOrTrigger, actionOrTriggerID, parameterName)
		if not Types.string(triggerID, actionOrTrigger, actionOrTriggerID, parameterName) then
			return
		end

		if not GG['MissionAPI'].Triggers[triggerID] then
			logError("Invalid triggerID: " .. triggerID .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID)
		end
	end,

	unitDefName = function(unitDefName, actionOrTrigger, actionOrTriggerID, parameterName)
		if not Types.string(unitDefName, actionOrTrigger, actionOrTriggerID, parameterName) then
			return
		end

		if not UnitDefNames[unitDefName] then
			logError("Invalid unitDefName: " .. unitDefName .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID)
		end
	end,

	facing = function(facing, actionOrTrigger, actionOrTriggerID, _)
		local validFacings = { n = true, s = true, e = true, w = true }
		if not validFacings[facing] then
			logError("Invalid facing: " .. facing .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID)
		end
	end,

	----------------------------------------------------------------
	--- Number Validators:
	----------------------------------------------------------------

	number = function(number, actionOrTrigger, actionOrTriggerID, parameterName)
		validateLuaType(number, 'number', actionOrTrigger, actionOrTriggerID, parameterName)
	end,

	teamID = function(teamID, actionOrTrigger, actionOrTriggerID, parameterName)
		if not Types.number(teamID, actionOrTrigger, actionOrTriggerID, parameterName) then
			return
		end

		if not Spring.GetTeamAllyTeamID(teamID) then
			logError("Invalid teamID: " .. teamID .. ". " .. actionOrTrigger .. ": " .. actionOrTriggerID .. ", Parameter: " .. parameterName)
		end
	end,

	----------------------------------------------------------------
	--- Boolean Validators:
	----------------------------------------------------------------

	boolean = function(boolean, actionOrTrigger, actionOrTriggerID, parameterName)
		validateLuaType(boolean, 'boolean', actionOrTrigger, actionOrTriggerID, parameterName)
	end,

	----------------------------------------------------------------
	--- Function Validators:
	----------------------------------------------------------------

	customFunction = function(func, actionOrTrigger, actionOrTriggerID, parameterName)
		validateLuaType(func, 'function', actionOrTrigger, actionOrTriggerID, parameterName)
	end,
}
