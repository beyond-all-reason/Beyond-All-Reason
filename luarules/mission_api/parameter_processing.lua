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
	for index, order in ipairs(orders) do
		local commandID = order[1]
		if type(commandID) == 'string' then
			-- A build order names the unit to build, which the engine takes as a negative ID.
			orders[index] = { -UnitDefNames[commandID].id, order[2], order[3] }
		end
	end
end

local function processSoundFile(soundfile)
	GG['MissionAPI'].soundFiles[soundfile] = ReadWAV(soundfile).Length
end

local function processEnumSet(values)
	local valueSet = {}
	for _, value in ipairs(values) do
		valueSet[value] = true
	end
	return valueSet
end

local processors = {
	[ParameterTypes.Position]  = processPosition,
	[ParameterTypes.Positions] = processPositions,
	[ParameterTypes.Orders]    = processOrders,
	[ParameterTypes.SoundFile] = processSoundFile,
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
		for _, parameter in ipairs(schemaParameters[actionOrTrigger.type]) do
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
