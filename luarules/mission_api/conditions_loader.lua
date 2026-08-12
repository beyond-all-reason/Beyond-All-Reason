local CONDITIONS_DIR = 'luarules/mission_api/conditions/'
local CONDITION_FILES_PATTERN = '*.lua'

local KINDS = { event = true, metric = true }

-- Every condition declares a `kind`:
--   'event'  an occurrence, tallied upwards. Threshold is `count`.
--   'metric' a value sampled now, which can move either way.
--            Threshold is `atLeast` / `atMost`.
-- Statistics conditions (TotalUnits*, UnitsOwned) declare no callins; their
-- evaluation is centralised in api_missions_triggers.lua (shared bookkeeping).
local function loadConditionDefinitions()
	local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

	local triggerFiles = VFS.DirList(CONDITIONS_DIR, CONDITION_FILES_PATTERN)

	local types = {}
	local eventTypes = {}
	local metricTypes = {}
	local kinds = {}
	local parameters = {}
	local callins = {}

	for typeID, filePath in ipairs(triggerFiles) do
		local triggerDefinition = VFS.Include(filePath)
		local triggerType = triggerDefinition.type
		local kind = triggerDefinition.kind

		if not KINDS[kind] then
			Spring.Log('triggers_loader', LOG.ERROR,
				"[Mission API] Condition '" .. tostring(triggerType) .. "' has invalid kind: " .. tostring(kind)
				.. ". Must be 'event' or 'metric'.")
		end

		types[triggerType] = typeID
		kinds[typeID] = kind
		parameters[typeID] = triggerDefinition.parameters or {}

		-- Author-facing views over the same registry, so a mission picking from
		-- metricTypes already knows to write atLeast/atMost rather than count.
		if kind == 'metric' then
			metricTypes[triggerType] = typeID
		else
			eventTypes[triggerType] = typeID
		end

		for callinName, handler in pairs(triggerDefinition.callins or {}) do
			callins[callinName] = callins[callinName] or {}
			callins[callinName][typeID] = handler
		end
	end

	-- Shared trigger settings schema (global, not per-trigger).
	local settings = {
		prerequisites = ParameterTypes.Table,
		repeating     = ParameterTypes.Boolean,
		maxRepeats    = ParameterTypes.Number,
		difficulties  = ParameterTypes.Table,
		coop          = ParameterTypes.Boolean,
		active        = ParameterTypes.Boolean,
		stages        = ParameterTypes.Table,
	}

	return {
		Types       = types,
		EventTypes  = eventTypes,
		MetricTypes = metricTypes,
		Kinds       = kinds,
		Settings    = settings,
		Parameters  = parameters,
		Callins     = callins,
	}
end

local function processRawTriggers(rawTriggers)
	local triggers = {}

	for triggerID, rawTrigger in pairs(rawTriggers) do
		local settings = rawTrigger.settings or {}
		settings.prerequisites = settings.prerequisites or {}
		settings.repeating = settings.repeating or false
		settings.maxRepeats = settings.maxRepeats or nil
		settings.difficulties = settings.difficulties or nil
		settings.coop = settings.coop or false
		settings.active = settings.active == nil and true or settings.active
		settings.stages = settings.stages or {}

		rawTrigger.settings = settings
		rawTrigger.triggered = false
		rawTrigger.repeatCount = 0
		-- Threshold bookkeeping: `occurrences` tallies event conditions towards
		-- `count`; `metricSatisfied` edge-triggers metric conditions.
		rawTrigger.occurrences = 0
		rawTrigger.metricSatisfied = false

		triggers[triggerID] = table.copy(rawTrigger)
	end

	return triggers
end

--- Groups triggers by type once at load, so per-frame call-in dispatch does not
--- have to scan every trigger for every type registered on that call-in.
local function indexTriggersByType(triggers)
	local byType = {}

	for triggerID, trigger in pairs(triggers) do
		local ofType = byType[trigger.type]
		if not ofType then
			ofType = {}
			byType[trigger.type] = ofType
		end
		ofType[#ofType + 1] = { id = triggerID, trigger = trigger }
	end

	return byType
end

return {
	LoadConditionDefinitions = loadConditionDefinitions,
	ProcessRawTriggers = processRawTriggers,
	IndexTriggersByType = indexTriggersByType,
}
