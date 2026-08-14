---
--- Post-validation parameter processing for Mission API actions and triggers.
---

VFS.Include('common/wav.lua')

local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local enumSets = GG['MissionAPI'].Modules.ParameterTypes.EnumSets
local actionDefinitions = GG['MissionAPI'].ActionDefinitions
local actionsSchemaParameters = actionDefinitions.Parameters
local triggersSchemaParameters = GG['MissionAPI'].TriggerDefinitions.Parameters

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

local function processOrders(orders)
	for _, order in ipairs(orders) do
		local commandID = order[1]
		local commandIndex = 1
		if commandID == CMD.INSERT then
			commandIndex = 3 -- The rolled array shifts commandParams[2] => [3].
			commandID = order[3]
		end
		if type(commandID) == 'string' then
			local unitDef = UnitDefNames[commandID]
			if unitDef then
				order[commandIndex] = -unitDef.id
			end
		end
	end
end

local function processCommand(command)
	if command == CMD.ANY or command == CMD.BUILD then
		return
	end
	if type(command) == 'string' then
		local unitDef = UnitDefNames[command]
		if unitDef then
			return -unitDef.id
		end
	end
end

local function processSoundFile(soundfile)
	local wavData = ReadWAV(soundfile)
	if wavData then
		GG['MissionAPI'].soundFiles[soundfile] = wavData.Length
	end
end

local function processEnumSet(values)
	local valueSet = {}
	for _, value in ipairs(values) do
		valueSet[value] = true
	end
	return valueSet
end

local processors = {
	[ParameterTypes.Position]              = processPosition,
	[ParameterTypes.Positions]             = processPositions,
	[ParameterTypes.Orders]                = processOrders,
	[ParameterTypes.Command]               = processCommand,
	[ParameterTypes.SoundFile]             = processSoundFile,
	[ParameterTypes.ResourceIncomeSources] = processResourceIncomeSources,
}
for enumSetType in pairs(enumSets) do
	processors[enumSetType]    = processEnumSet
end

----------------------------------------------------------------
--- Public processing functions:
----------------------------------------------------------------

local function processParameters(actionsOrTriggers, schemaParameters)
	for _, actionOrTrigger in pairs(actionsOrTriggers) do
		local parameters = actionOrTrigger.parameters or {}
		local schema = schemaParameters[actionOrTrigger.type] or {}
		for _, parameter in ipairs(schema) do
			local value = parameters[parameter.name]
			local processor = processors[parameter.type]
			if value ~= nil and processor then
				local result = processor(value)
				if result ~= nil then
					parameters[parameter.name] = result
				end
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
	ProcessActionParameters  = processActionParameters,
	ProcessTriggerParameters = processTriggerParameters,
}
