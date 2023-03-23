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

--[[
		triggerOption = {
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
		...
	}
]]

local triggers = {}

local function AddTrigger(id, type, triggerOptions, actionIds, ...)
	triggerOptions = triggerOptions or {}
	triggerOptions.prerequisites = triggerOptions.prerequisites or {}
	triggerOptions.repeating = triggerOptions.repeating or false
	triggerOptions.maxRepeats = triggerOptions.maxRepeats or nil
	triggerOptions.difficulties = triggerOptions.difficulties or nil
	triggerOptions.coop = triggerOptions.coop or false
	triggerOptions.active = triggerOptions.active or true

	local trigger = {
		type = type,
		prerequisites = triggerOptions.prerequisites,
		repeating = triggerOptions.repeating,
		maxRepeats = triggerOptions.maxRepeats,
        repeatCount = 0,
		difficulties = triggerOptions.difficulties,
		coop = triggerOptions.coop,
		active = triggerOptions.active,
		parameters = ...,
		actionIds = actionIds,
        triggered = false,
	}

	triggers[id] = trigger
end

local function addTimeElapsedTrigger(id, triggerOptions, actionIds, gameFrame, offset)
	AddTrigger(id, triggerTypes.TimeElapsed, triggerOptions, actionIds, gameFrame, offset)
end

local function getTriggers()
	for triggerId, trigger in pairs(triggers) do
		if not trigger.type then
			error("[Mission API] Trigger missing type: " .. triggerId)
		end
	end

	return triggers
end

--example usage
--[[
local options = {
	prerequisites = { 'foundEnemyBase', 'builtRadar' },
	repeating = true,
}
local actionIds = { 'callReinforcements', }

AddTimeElapsedTrigger('intelCollected', options, actionIds, 0, 1800)
]]

return {
	Types = triggerTypes,
	GetTriggers = getTriggers,
	-- TODO: Return trigger creation functions
	AddTimeElapsedTrigger = addTimeElapsedTrigger,
}
