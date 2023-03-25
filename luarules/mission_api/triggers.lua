local triggerTypes = {
	TimeElapsed = 1,
	UnitExists = 2,
	UnitNotExists = 3,
	ConstructionStarted = 4,
	ConstructionFinished = 5,
	UnitKilled = 6,
	UnitCaptured = 7,
	UnitResurrected = 8,
	UnitEnteredLocation = 9,
	UnitLeftLocation = 10,
	UnitDwellLocation = 11,
	UnitSpotted = 12,
	UnitUnspotted = 13,
	FeatureNotExists = 14,
	FeatureReclaimed = 15,
	FeatureDestroyed = 16,
	ResourceStored = 17,
	ResourceProduction = 18,
	TotalUnitsLost = 19,
	TotalUnitsBuilt = 20,
	TotalUnitsKilled = 21,
	TotalUnitsCaptured = 22,
	TeamDestroyed = 23,
	Victory = 24,
	Defeat = 25,
}

local parameters = {
	[triggerTypes.TimeElapsed] = { 'GameFrame', 'Offset' },
	[triggerTypes.UnitExists] = {  },
	[triggerTypes.UnitNotExists] = {  },
	[triggerTypes.ConstructionStarted] = {  },
	[triggerTypes.ConstructionFinished] = {  },
	[triggerTypes.UnitKilled] = {  },
	[triggerTypes.UnitCaptured] = {  },
	[triggerTypes.UnitResurrected] = {  },
	[triggerTypes.UnitEnteredLocation] = {  },
	[triggerTypes.UnitLeftLocation] = {  },
	[triggerTypes.UnitDwellLocation] = {  },
	[triggerTypes.UnitSpotted] = {  },
	[triggerTypes.UnitUnspotted] = {  },
	[triggerTypes.FeatureNotExists] = {  },
	[triggerTypes.FeatureReclaimed] = {  },
	[triggerTypes.FeatureDestroyed] = {  },
	[triggerTypes.ResourceStored] = {  },
	[triggerTypes.ResourceProduction] = {  },
	[triggerTypes.TotalUnitsLost] = {  },
	[triggerTypes.TotalUnitsBuilt] = {  },
	[triggerTypes.TotalUnitsKilled] = {  },
	[triggerTypes.TotalUnitsCaptured] = {  },
	[triggerTypes.TeamDestroyed] = {  },
	[triggerTypes.Victory] = {  },
	[triggerTypes.Defeat] = {  },
}

--[[
	triggerId = {
		type = triggerTypes.TimeElapsed,
		settings = { -- all individual settings, and settings table itself, are optional
			prerequisites = {},
			repeating = false,
			maxRepeats = nil,
			difficulties = {},
			coop = false,
			active = true,
			type = triggerTypes.foo,
			parameters = {},
			actionIds = {},
		},
		parameters = {
			gameFrame = 123,
			offset = 300,
		},
		actions = { 'actionId1', 'actionId2' },
	}
]]

local triggers = {}

local function prevalidateTriggers()
	for triggerId, trigger in pairs(triggers) do
		if not trigger.type then
			Spring.Log('triggers.lua', LOG.ERROR, "[Mission API] Trigger missing type: " .. triggerId)
		end

		if not trigger.actions or next(trigger.actions) == nil then
			Spring.Log('triggers.lua', LOG.ERROR, "[Mission API] Trigger has no actions: " .. triggerId)
		end

		for _, parameter in pairs(parameters[trigger.type]) do
			if trigger.parameters[parameter] == nil then
				Spring.Log('triggers.lua', LOG.ERROR, "[Mission API] Trigger missing required parameter. Trigger: " .. triggerId .. ", Parameter: " .. parameter)
			end
		end
	end
end

local function preprocessRawTriggers(rawTriggers)
	Spring.Echo("[Mission API] Processing mission triggers")

	for triggerId, rawTrigger in pairs(rawTriggers) do
		local settings = rawTrigger.settings or {}
		settings.prerequisites = settings.prerequisites or {}
		settings.repeating = settings.repeating or false
		settings.maxRepeats = settings.maxRepeats or nil
		settings.difficulties = settings.difficulties or nil
		settings.coop = settings.coop or false
		settings.active = settings.active or true

		rawTrigger.triggered = false

		triggers[triggerId] = table.copy(rawTrigger)
	end

	prevalidateTriggers()
end

local function postvalidateTriggers()
	local actions = GG['MissionAPI'].Actions
	for triggerId, trigger in pairs(triggers) do
		for _, actionId in pairs(trigger.actions) do
			if not actions[actionId] then
				Spring.Log('triggers.lua', LOG.ERROR, "[Mission API] Trigger has action that does not exist. Trigger: " .. triggerId .. ", Action: " .. actionId)
			end
		end
	end
end

local function postprocessTriggers()
	postvalidateTriggers()
end

local function getTriggers()
	return triggers
end

return {
	Types = triggerTypes,
	GetTriggers = getTriggers,
	PreprocessRawTriggers = preprocessRawTriggers,
	PostprocessTriggers = postprocessTriggers,
}
