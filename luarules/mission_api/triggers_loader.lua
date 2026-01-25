local schema = VFS.Include('luarules/mission_api/triggers_schema.lua')
local parameters = schema.Parameters

-- Example trigger
--[[
	myTriggerName = {
		type = triggerTypes.TimeElapsed,
		settings = { -- all individual settings, and settings table itself, are optional
			prerequisites = {},
			repeating = false,
			maxRepeats = nil,
			difficulties = {},
			coop = false,
			active = true,
		},
		parameters = {
			gameFrame = 123,
			interval = 300,
		},
		actions = { 'actionID1', 'actionID2' },
	}
]]

local function validateTriggers(triggers, rawActions)
	for triggerID, trigger in pairs(triggers) do
		if table.isNilOrEmpty(trigger.actions) then
			Spring.Log('triggers_loader.lua', LOG.ERROR, "[Mission API] Trigger has no actions: " .. triggerID)
		else
			for _, action in pairs(trigger.actions) do
				if action == nil or action == '' then
					Spring.Log('triggers_loader.lua', LOG.ERROR, "[Mission API] Trigger has empty action ID: " .. triggerID)
				elseif not rawActions[action] then
					Spring.Log('triggers_loader.lua', LOG.ERROR, "[Mission API] Trigger has invalid action. Trigger: " .. triggerID .. ", Action: " .. action)
				end
			end
		end

		validateParameters(parameters, trigger.type, trigger.parameters, 'Trigger', triggerID)
	end
end

local function processRawTriggers(rawTriggers, rawActions)
	local triggers = {}

	for triggerID, rawTrigger in pairs(rawTriggers) do
		local settings = rawTrigger.settings or {}
		settings.prerequisites = settings.prerequisites or {}
		settings.repeating = settings.repeating or false
		settings.maxRepeats = settings.maxRepeats or nil
		settings.difficulties = settings.difficulties or nil
		settings.coop = settings.coop or false
		settings.active = settings.active or true

		rawTrigger.settings = settings
		rawTrigger.triggered = false
		rawTrigger.repeatCount = 0

		triggers[triggerID] = table.copy(rawTrigger)
	end

	validateTriggers(triggers, rawActions)
	return triggers
end

return {
	ProcessRawTriggers = processRawTriggers,
}
