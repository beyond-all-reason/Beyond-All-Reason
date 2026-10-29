---
--- Post-validation parameter processing for Mission API actions and triggers.
---

VFS.Include("common/wav.lua")

local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types
local enumSets = GG["MissionAPI"].Modules.ParameterTypes.EnumSets
local actionDefinitions = GG["MissionAPI"].ActionDefinitions
local actionsSchemaParameters = actionDefinitions.Parameters
local triggersSchemaParameters = GG["MissionAPI"].TriggerDefinitions.Parameters

----------------------------------------------------------------
--- Parameter processors:
----------------------------------------------------------------

local function processPosition(position)
	position.y = position.y or Spring.GetGroundHeight(position.x, position.z)
end

local function processPositions(positions)
	for _, position in ipairs(positions) do
		processPosition(position)
	end
end

local function processDirection(position)
	if position.x and position.z then
		position.y = position.y or Spring.GetGroundHeight(position.x, position.z)
	end
end

local function processOrders(orders)
	for _, order in ipairs(orders) do
		local commandIndex = order[1] == CMD.INSERT and 3 or 1
		local commandID = order[commandIndex]
		if type(commandID) == "string" then
			-- A build order names the unit to build, which the engine takes as a negative ID.
			order[commandIndex] = -UnitDefNames[commandID].id
		end
	end
end

local function processCommand(command)
	if command == CMD.ANY or command == CMD.BUILD then
		return
	end
	if type(command) == "string" then
		local unitDef = UnitDefNames[command]
		if unitDef then
			return -unitDef.id
		end
	end
end

local function processSoundFile(soundfile)
	GG["MissionAPI"].soundFiles[soundfile] = ReadWAV(soundfile).Length
end

local function processEnumSet(values)
	local valueSet = {}
	for _, value in ipairs(values) do
		valueSet[value] = true
	end
	return valueSet
end

-- The engine's {r, g, b}
local function processColor(color)
	return { color.r, color.g, color.b }
end

local processors = {
	[ParameterTypes.Position] = processPosition,
	[ParameterTypes.Positions] = processPositions,
	[ParameterTypes.Direction] = processDirection,
	[ParameterTypes.Orders] = processOrders,
	[ParameterTypes.Command] = processCommand,
	[ParameterTypes.SoundFile] = processSoundFile,
	[ParameterTypes.Color] = processColor,
}
for enumSetType in pairs(enumSets) do
	processors[enumSetType] = processEnumSet
end

----------------------------------------------------------------
--- Public processing functions:
----------------------------------------------------------------

local function processValue(parameterType, value)
	local processor = processors[parameterType]
	if processor == nil then
		return value
	end
	local result = processor(value)
	if result ~= nil then
		return result
	end
	return value
end

local function processParameters(actionsOrTriggers, schemaParameters)
	for _, actionOrTrigger in pairs(actionsOrTriggers) do
		local parameters = actionOrTrigger.parameters or {}
		local schema = schemaParameters[actionOrTrigger.type] or {}
		for _, parameter in ipairs(schema) do
			local value = parameters[parameter.name]
			if value ~= nil then
				parameters[parameter.name] = processValue(parameter.type, value)
			end
		end
	end
end

local function processActionParameters(actions)
	processParameters(actions, actionsSchemaParameters)
end

local function processTriggerParameters(triggers)
	processParameters(triggers, triggersSchemaParameters)
end

return {
	ProcessValue = processValue,
	ProcessActionParameters = processActionParameters,
	ProcessTriggerParameters = processTriggerParameters,
}
