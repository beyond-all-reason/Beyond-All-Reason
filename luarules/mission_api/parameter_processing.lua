---
--- Post-validation parameter processing for Mission API actions and triggers.
---

VFS.Include('common/wav.lua')

local Types = VFS.Include('luarules/mission_api/parameter_types.lua').Types
local actionsSchemaParameters = VFS.Include('luarules/mission_api/actions_schema.lua').Parameters
local triggersSchemaParameters = VFS.Include('luarules/mission_api/triggers_schema.lua').Parameters

----------------------------------------------------------------
--- Parameter processors:
----------------------------------------------------------------

local function processPosition(position)
	position.y = position.y or Spring.GetGroundHeight(position.x, position.z)
end

local function processPositions(positions)
	for _, position in pairs(positions) do
		processPosition(position)
	end
end

local function processOrders(orders)
	for i, order in ipairs(orders) do
		local commandID = order[1]
		if type(commandID) == 'string' then
			local unitDef = UnitDefNames[commandID]
			if unitDef then
				orders[i] = { -unitDef.id, order[2], order[3] }
			end
		end
	end
end

local function processSoundFile(soundfile)
	local wavData = ReadWAV(soundfile)
	if wavData then
		GG['MissionAPI'].soundFiles[soundfile] = wavData.Length
	end
end

local function processResourceIncomeSources(sources)
	local sourcesAsSet = {}
	for _, source in ipairs(sources) do
		sourcesAsSet[source] = true
	end
	return sourcesAsSet
end

local processors = {
	[Types.Position]              = processPosition,
	[Types.Positions]             = processPositions,
	[Types.Orders]                = processOrders,
	[Types.SoundFile]             = processSoundFile,
	[Types.ResourceIncomeSources] = processResourceIncomeSources,
}

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
