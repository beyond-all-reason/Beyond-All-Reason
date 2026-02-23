local validateTriggers = VFS.Include('luarules/mission_api/validation.lua').ValidateTriggers

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
