local TRIGGERS_DIR = "luarules/mission_api/triggers/"
local TRIGGER_FILES_PATTERN = "*.lua"

-- Statistics triggers (TotalUnits*, UnitsOwned) declare no callins; their
-- evaluation is centralised in api_missions_triggers.lua (shared bookkeeping).
local function loadTriggerDefinitions()
	local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

	local triggerFiles = VFS.DirList(TRIGGERS_DIR, TRIGGER_FILES_PATTERN)

	local types = {}
	local parameters = {}
	local callins = {}

	for typeID, filePath in ipairs(triggerFiles) do
		local triggerDefinition = VFS.Include(filePath)
		local triggerType = triggerDefinition.type

		types[triggerType] = typeID
		parameters[typeID] = triggerDefinition.parameters or {}

		for callinName, handler in pairs(triggerDefinition.callins or {}) do
			callins[callinName] = callins[callinName] or {}
			callins[callinName][typeID] = handler
		end
	end

	-- Shared trigger settings schema (global, not per-trigger).
	local settings = {
		prerequisites = ParameterTypes.Table,
		repeating = ParameterTypes.Boolean,
		maxRepeats = ParameterTypes.Number,
		difficulties = ParameterTypes.Table,
		coop = ParameterTypes.Boolean,
		active = ParameterTypes.Boolean,
		stages = ParameterTypes.Table,
	}

	return {
		Types = types,
		Settings = settings,
		Parameters = parameters,
		Callins = callins,
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

		triggers[triggerID] = table.copy(rawTrigger)
	end

	return triggers
end

return {
	LoadTriggerDefinitions = loadTriggerDefinitions,
	ProcessRawTriggers = processRawTriggers,
}
