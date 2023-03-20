function gadget:GetInfo()
	return {
		name = "Mission API triggers",
		desc = "Monitor and activate triggers, and dispatch actions",
		date = "2023.03.16",
		layer = 1, -- MUST be loaded after api_missions
		enabled = true,
	}
end

local types, timeTypes, unitTypes, featureTypes, gameTypes
local triggers, timeTriggers, unitTriggers, featureTriggers, gameTriggers

local populateParameters = {
	[types.TimeElapsed] = function (parameters) return { gameframe = parameters[1], offset = parameters[2] } end,
}
--[[

local function populateTriggerTypes()
	timeTypes = {
		[types.TimeElapsed] = true,
		[types.ResourceStored] = true,
		[types.ResourceProduction] = true,
		[types.UnitEnteredLocation] = true,
		[types.UnitLeftLocation] = true,
		[types.UnitDwellLocation] = true,
	}

	unitTypes = {
		[types.UnitExists] = true,
		[types.UnitNotExists] = true,
		[types.ConstructionStarted] = true,
		[types.ConstructionFinished] = true,
		[types.UnitKilled] = true,
		[types.UnitCaptured] = true,
		[types.UnitResurrected] = true,
		[types.UnitSpotted] = true,
		[types.UnitUnspotted] = true,
		[types.FeatureNotExists] = true,
		[types.FeatureReclaimed] = true,
		[types.FeatureDestroyed] = true,
		[types.TotalUnitsLost] = true,
		[types.TotalUnitsBuilt] = true,
		[types.TotalUnitsKilled] = true,
		[types.TotalUnitsCaptured] = true,
		[types.TeamDestroyed] = true,
		[types.Victory] = true,
		[types.Defeat] = true,
end

local function populateTriggerLists()
	for triggerId, trigger in pairs(triggers) do
		
	end
end
]]

local function triggerValid(triggerId)
	local trigger = triggers[triggerId]

	if not trigger.active then
		return false
	end

	for _, prerequisiteTrigger in pairs(trigger.prerequisites) do
		if not prerequisiteTrigger.triggered then
			return false
		end
	end

	if trigger.triggered and not trigger.repeating then
		return false
	end

	if trigger.repeating and trigger.repeatCount > trigger.maxRepeats then
		return false
	end

	if trigger.difficulties ~= nil and not trigger.difficulties[GG['MissionAPI'].Difficulty] then
		return false
	end

	--[[
	--TODO: co-op check
	if trigger.coop and not ??? then
	 	return false
	end
	]]

	return true
end

local function activateTrigger(triggerId)
	if not triggerValid(triggerId) then
		return
	end

	local trigger = triggers[triggerId]

	trigger.triggered = true
	trigger.repeatCount = trigger.repeatCount + 1

	for _, actionId in pairs(trigger.actionIds) do
		GG['MissionAPI'].ActionsDispatcher.Invoke(actionId)
	end
end

function gadget:Initialize()
	triggers = GG['MissionAPI'].Triggers
	types = GG['MissionAPI'].TriggersController.Types
end

function gadget:GameFrame(n)
	for triggerId, trigger in pairs(triggers) do
		if trigger.type == types.TimeElapsed then
			local parameters = populateParameters[trigger.type]

			if n == gameframe or (trigger.repeating and n > parameters.gameframe and parameters.offset % (n - gameframe) == 0) then
				activateTrigger(triggerId)
			end
		end
	end
end