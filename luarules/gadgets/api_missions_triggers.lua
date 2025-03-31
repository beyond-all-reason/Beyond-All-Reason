local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Mission API triggers",
		desc = "Monitor and activate triggers, and dispatch actions",
		date = "2023.03.16",
		layer = 1, -- MUST be loaded after api_missions
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local actionsDispatcher, trackedUnits

local types, timeTypes, unitTypes, featureTypes, gameTypes
local triggers, timeTriggers, unitTriggers, featureTriggers, gameTriggers

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

local function triggerValid(trigger)
	if not trigger.settings.active then return false end

	for _, prerequisiteTrigger in pairs(trigger.settings.prerequisites) do
		if not prerequisiteTrigger.triggered then return false end
	end

	if trigger.triggered and not trigger.settings.repeating then return false end
	if trigger.settings.repeating and trigger.settings.maxRepeats ~= nil and trigger.repeatCount > trigger.settings.maxRepeats then return false end
	if trigger.settings.difficulties ~= nil and not trigger.settings.difficulties[GG['MissionAPI'].Difficulty] then return false end

	--[[
	--TODO: co-op check
	if trigger.coop and not ??? then return false end
	]]

	return true
end

local function activateTrigger(trigger)
	if not triggerValid(trigger) then
		return
	end

	trigger.triggered = true
	trigger.repeatCount = trigger.repeatCount + 1

	for _, actionId in ipairs(trigger.actions) do
		actionsDispatcher.Invoke(actionId)
	end
end

function gadget:Initialize()
	if not GG['MissionAPI'] then
		gadgetHandler:RemoveGadget()
		return
	end

	actionsDispatcher = VFS.Include('luarules/mission_api/actions_dispatcher.lua')
	types = GG['MissionAPI'].TriggerTypes
	triggers = GG['MissionAPI'].Triggers
	trackedUnits = GG['MissionAPI'].TrackedUnits
end

function gadget:GameFrame(n)
	for triggerId, trigger in pairs(triggers) do
		if trigger.type == types.TimeElapsed then
			local gameframe = trigger.parameters.gameFrame
			local interval = trigger.parameters.interval

			if n == gameframe or (trigger.settings.repeating and n > gameframe and (n - gameframe) % interval == 0) then
				activateTrigger(trigger)
			end
		end
	end
end

function gadget:MetaUnitAdded(unitId, unitDefId, unitTeam)
	for triggerId, trigger in pairs(triggers) do
		if trigger.type == types.UnitExists then
			local unitName = trigger.parameters.unitName
			local unitDefName = trigger.parameters.unitDefName

			if unitName and unitName == trackedUnits[unitId] then
				activateTrigger(trigger)
			elseif unitDefName == unitDefId.name then
				activateTrigger(trigger)
			end
		end
	end
end