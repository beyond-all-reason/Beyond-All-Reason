local CONDITIONS_DIR = "luarules/mission_api/conditions/"
local CONDITION_FILES_PATTERN = "*.lua"

-- Some triggers declare no callins and are activated elsewhere:
-- - statistics triggers (TotalUnits*, UnitsOwned) by statistics.lua
-- - event-type triggers by whatever owns the trigger (objectives.lua)
local function loadConditionDefinitions()
	local conditionFiles = VFS.DirList(CONDITIONS_DIR, CONDITION_FILES_PATTERN)

	local types = {}
	local parameters = {}
	local callins = {}

	for typeID, filePath in ipairs(conditionFiles) do
		local conditionDefinition = VFS.Include(filePath)
		local conditionType = conditionDefinition.type

		types[conditionType] = typeID
		parameters[typeID] = conditionDefinition.parameters or {}

		for callinName, handler in pairs(conditionDefinition.callins or {}) do
			callins[callinName] = callins[callinName] or {}
			callins[callinName][typeID] = handler
		end
	end

	return {
		Types = types,
		Parameters = parameters,
		Callins = callins,
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
	LoadConditionDefinitions = loadConditionDefinitions,
	ProcessRawTriggers = processRawTriggers,
}
