local TRIGGERS_DIR = 'luarules/mission_api/triggers/'
local TRIGGER_FILES_PATTERN = '*.lua'

-- Statistics triggers (TotalUnits*, UnitsOwned) declare no callins; their
-- evaluation is centralised in api_missions_triggers.lua (shared bookkeeping).
local function loadTriggerDefinitions()
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

	return {
		Types      = types,
		Parameters = parameters,
		Callins    = callins,
	}
end

local function processRawTriggers(rawTriggers)
	local triggers = {}

	-- Apply defaults:
	for triggerID, rawTrigger in pairs(rawTriggers) do
		local settings = rawTrigger.settings or {}
		settings.prerequisites = settings.prerequisites or {}
		settings.repeating = settings.repeating or false
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
