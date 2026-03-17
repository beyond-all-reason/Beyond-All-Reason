local gadget = gadget ---@type Gadget

local doesUnitHaveName
local untrackUnitID
local doesFeatureHaveName
local untrackFeatureID

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

local actionsDispatcher
local types, triggers


----------------------------------------------------------------
--- Utility Functions:
----------------------------------------------------------------

local function processTriggersOfType(triggerType, func)
	for triggerID, trigger in pairs(triggers) do
		if trigger.type == triggerType then
			func(trigger, triggerID)
		end
	end
end

local function isTriggerValid(trigger)
	if not trigger.settings.active then return false end

	for _, prerequisiteTriggerID in pairs(trigger.settings.prerequisites) do
		if not triggers[prerequisiteTriggerID].triggered then return false end
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
	if not isTriggerValid(trigger) then
		return false
	end

	trigger.triggered = true
	trigger.repeatCount = trigger.repeatCount + 1

	for _, actionID in ipairs(trigger.actions) do
		actionsDispatcher.Invoke(actionID)
	end

	return true
end

local function getUnitsInArea(trigger)
	local area = trigger.parameters.area
	local teamID = trigger.parameters.teamID
	local unitsInArea = {}

	if area.x1 and area.z1 and area.x2 and area.z2 then
		unitsInArea = Spring.GetUnitsInRectangle(area.x1, area.z1, area.x2, area.z2, teamID)
	elseif area.x and area.z and area.radius then
		unitsInArea = Spring.GetUnitsInCylinder(area.x, area.z, area.radius, teamID)
	end

	return unitsInArea
end


----------------------------------------------------------------
--- Trigger Checks:
----------------------------------------------------------------

local function checkTimeElapsed(trigger, gameframe)
	local targetframe = trigger.parameters.gameFrame
	local interval = trigger.parameters.interval

	if gameframe == targetframe or (trigger.settings.repeating and gameframe > targetframe and (gameframe - targetframe) % interval == 0) then
		activateTrigger(trigger)
	end
end

local function checkUnitExists(trigger, unitDefID, teamID)
	if trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return
	end

	local requiredTeamID = trigger.parameters.teamID
	local requiredQuantity = trigger.parameters.quantity
	if requiredTeamID then
		if requiredTeamID ~= teamID then
			return
		elseif Spring.GetTeamUnitDefCount(requiredTeamID, unitDefID) < (requiredQuantity or 1) then
			return
		end
	end

	if requiredQuantity then
		local count = 0
		for _, allyTeamID in pairs(Spring.GetAllyTeamList()) do
			for _, teamIDForAllyTeam in pairs(Spring.GetTeamList(allyTeamID)) do
				count = count + Spring.GetTeamUnitDefCount(teamIDForAllyTeam, unitDefID)
			end
		end
		if count < requiredQuantity then
			return
		end
	end

	activateTrigger(trigger)
end

local function checkUnitRemoved(trigger, unitID, unitDefID, unitTeam)
	if trigger.parameters.unitName and not doesUnitHaveName(unitID, trigger.parameters.unitName) then
		return
	end
	if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return
	end
	if trigger.parameters.teamID and unitTeam ~= trigger.parameters.teamID then
		return
	end
	activateTrigger(trigger)
end

local function checkUnitCaptured(trigger, unitID, unitDefID, oldTeam, newTeam)
	if trigger.parameters.unitName and not doesUnitHaveName(unitID, trigger.parameters.unitName) then
		return
	end
	if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return
	end
	if trigger.parameters.oldTeamID and oldTeam ~= trigger.parameters.oldTeamID then
		return
	end
	if trigger.parameters.newTeamID and newTeam ~= trigger.parameters.newTeamID then
		return
	end
	activateTrigger(trigger)
end

local function checkUnitResurrected(trigger, unitDefID, unitTeam, builderID)
	if not builderID then
		return
	end

	local cmdID, featureID = Spring.GetUnitWorkerTask(builderID)
	if cmdID ~= CMD.RESURRECT then
		return
	end
	if not Engine.FeatureSupport.noOffsetForFeatureID then
		featureID = featureID - Game.maxUnits
	end

	if trigger.parameters.featureName and not doesFeatureHaveName(featureID, trigger.parameters.featureName) then
		return
	end
	if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return
	end
	if trigger.parameters.teamID and unitTeam ~= trigger.parameters.teamID then
		return
	end
	activateTrigger(trigger)
end

local previousUnitsInAreas = {}
local function checkUnitEnteredLocation(trigger, triggerID)
	local unitsInArea = getUnitsInArea(trigger)

	local unitsEnteredArea = table.filterArray(unitsInArea, function(unitID)
		return not table.contains(previousUnitsInAreas[triggerID] or {}, unitID)
			and (not trigger.parameters.unitName or doesUnitHaveName(unitID, trigger.parameters.unitName))
			and (not trigger.parameters.unitDefName or UnitDefs[Spring.GetUnitDefID(unitID)].name == trigger.parameters.unitDefName)
	end)
	previousUnitsInAreas[triggerID] = unitsInArea

	for _, unitID in ipairs(unitsEnteredArea) do
		activateTrigger(trigger)
	end
end

local function checkUnitLeftLocation(trigger, triggerID)
	local unitsInArea = getUnitsInArea(trigger)

	local unitsLeftArea = table.filterArray(previousUnitsInAreas[triggerID] or {}, function(unitID)
		return not table.contains(unitsInArea, unitID)
			and (not trigger.parameters.unitName or doesUnitHaveName(unitID, trigger.parameters.unitName))
			and (not trigger.parameters.unitDefName or UnitDefs[Spring.GetUnitDefID(unitID)].name == trigger.parameters.unitDefName)
	end)
	previousUnitsInAreas[triggerID] = unitsInArea

	for _, unitID in ipairs(unitsLeftArea) do
		activateTrigger(trigger)
	end
end

local dwellingUnitsInAreas = {}
local function checkUnitDwellLocation(trigger, triggerID)
	local unitsInArea = getUnitsInArea(trigger)

	for _, unitID in pairs(unitsInArea) do
		-- If unit already dwelling in area, increase dwelling time:
		if dwellingUnitsInAreas[triggerID] and dwellingUnitsInAreas[triggerID][unitID] ~= nil and dwellingUnitsInAreas[triggerID][unitID] >= 0 then
			dwellingUnitsInAreas[triggerID][unitID] = dwellingUnitsInAreas[triggerID][unitID] + 1

			-- Check duration, and if unit still has required name:
			if dwellingUnitsInAreas[triggerID][unitID] >= trigger.parameters.duration and
				(not trigger.parameters.unitName or doesUnitHaveName(unitID, trigger.parameters.unitName)) then
				local wasInvoked = activateTrigger(trigger)
				if wasInvoked then
					dwellingUnitsInAreas[triggerID][unitID] = -1 -- Prevent multiple activations for the same unit
				end
			end

		-- If unit just entered area (and hasn't already triggered), start counting:
		elseif (dwellingUnitsInAreas[triggerID] == nil or dwellingUnitsInAreas[triggerID][unitID] == nil)
			and (not trigger.parameters.unitName or doesUnitHaveName(unitID, trigger.parameters.unitName))
			and (not trigger.parameters.unitDefName or UnitDefs[Spring.GetUnitDefID(unitID)].name == trigger.parameters.unitDefName) then
			if not dwellingUnitsInAreas[triggerID] then
				dwellingUnitsInAreas[triggerID] = {}
			end
			dwellingUnitsInAreas[triggerID][unitID] = 0
		end
	end

	-- Remove units that left area:
	for unitID, _ in pairs(dwellingUnitsInAreas[triggerID] or {}) do
		if not table.contains(unitsInArea, unitID) then
			dwellingUnitsInAreas[triggerID][unitID] = nil
		end
	end
end

local function checkUnitEnteredOrLeftLos(trigger, unitID, unitTeam, losAllyTeamID, unitDefID)
	if trigger.parameters.unitName and not doesUnitHaveName(unitID, trigger.parameters.unitName) then
		return
	end
	if trigger.parameters.owningTeamID and unitTeam ~= trigger.parameters.owningTeamID then
		return
	end
	if trigger.parameters.spottingAllyTeamID and losAllyTeamID ~= trigger.parameters.spottingAllyTeamID then
		return
	end
	if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return
	end
	activateTrigger(trigger)
end

local function checkConstructionStarted(trigger, unitID, unitDefID, unitTeam)
	if not Spring.GetUnitIsBeingBuilt(unitID) then
		return
	end
	if trigger.parameters.teamID and unitTeam ~= trigger.parameters.teamID then
		return
	end
	if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return
	end
	activateTrigger(trigger)
end

local function checkConstructionFinished(trigger, unitID, unitDefID, unitTeam)
	if trigger.parameters.unitName and not doesUnitHaveName(unitID, trigger.parameters.unitName) then
		return
	end
	if trigger.parameters.teamID and unitTeam ~= trigger.parameters.teamID then
		return
	end
	if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return
	end
	activateTrigger(trigger)
end

local function checkTeamDestroyed(trigger, teamID)
	if teamID == trigger.parameters.teamID then
		activateTrigger(trigger)
	end
end

local function isFeatureInArea(featureID, area)
	local featureX, _, featureZ = Spring.GetFeaturePosition(featureID)
	if area.x1 then
		return featureX >= area.x1 and featureX <= area.x2 and featureZ >= area.z1 and featureZ <= area.z2
	else
		local dx, dz = featureX - area.x, featureZ - area.z
		return dx * dx + dz * dz <= area.radius * area.radius
	end
end

local function checkFeatureCreated(trigger, featureID, featureDefID)
	if trigger.parameters.featureDefName and trigger.parameters.featureDefName ~= FeatureDefs[featureDefID].name then
		return
	end
	if trigger.parameters.area and not isFeatureInArea(featureID, trigger.parameters.area) then
		return
	end
	activateTrigger(trigger)
end

local function checkFeatureReclaimed(trigger, featureID, featureDefID, teamID)
	if trigger.parameters.featureName and not doesFeatureHaveName(featureID, trigger.parameters.featureName) then
		return
	end
	if trigger.parameters.featureDefName and trigger.parameters.featureDefName ~= FeatureDefs[featureDefID].name then
		return
	end
	if trigger.parameters.teamID and teamID ~= trigger.parameters.teamID then
		return
	end
	if trigger.parameters.area and not isFeatureInArea(featureID, trigger.parameters.area) then
		return
	end
	activateTrigger(trigger)
end

local function checkFeatureDestroyed(trigger, featureID, featureDefID, attackerAllyTeamID)
	if trigger.parameters.featureName and not doesFeatureHaveName(featureID, trigger.parameters.featureName) then
		return
	end
	if trigger.parameters.featureDefName and trigger.parameters.featureDefName ~= FeatureDefs[featureDefID].name then
		return
	end
	if trigger.parameters.allyTeamID and attackerAllyTeamID ~= trigger.parameters.allyTeamID then
		return
	end
	if trigger.parameters.area and not isFeatureInArea(featureID, trigger.parameters.area) then
		return
	end
	activateTrigger(trigger)
end


----------------------------------------------------------------
--- Call-ins:
----------------------------------------------------------------


----------------------------------------------------------------
--- Call-ins:
----------------------------------------------------------------

function gadget:Initialize()
	if not GG['MissionAPI'] then
		gadgetHandler:RemoveGadget()
		return
	end

	types = GG['MissionAPI'].TriggerTypes
	triggers = GG['MissionAPI'].Triggers
	actionsDispatcher = VFS.Include('luarules/mission_api/actions_dispatcher.lua')

	local tracking = VFS.Include('luarules/mission_api/tracking.lua')
	doesUnitHaveName = tracking.DoesUnitHaveName
	untrackUnitID = tracking.UntrackUnitID
	doesFeatureHaveName = tracking.DoesFeatureHaveName
	untrackFeatureID    = tracking.UntrackFeatureID
end

function gadget:GameFrame(frameNumber)
	processTriggersOfType(types.TimeElapsed, function(trigger, _)
		checkTimeElapsed(trigger, frameNumber)
	end)

	processTriggersOfType(types.UnitEnteredLocation, function(trigger, triggerID)
		checkUnitEnteredLocation(trigger, triggerID)
	end)

	processTriggersOfType(types.UnitLeftLocation, function(trigger, triggerID)
		checkUnitLeftLocation(trigger, triggerID)
	end)

	processTriggersOfType(types.UnitDwellLocation, function(trigger, triggerID)
		checkUnitDwellLocation(trigger, triggerID)
	end)
end

function gadget:MetaUnitAdded(_, unitDefID, unitTeam)
	processTriggersOfType(types.UnitExists, function(trigger, _)
		checkUnitExists(trigger, unitDefID, unitTeam)
	end)
end

function gadget:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	processTriggersOfType(types.UnitNotExists, function(trigger, _)
		checkUnitRemoved(trigger, unitID, unitDefID, unitTeam)
	end)
	-- Don't untrack unit here, as other call-ins run after this one (UnitDestroyed, UnitTaken, ...)
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	processTriggersOfType(types.UnitResurrected, function(trigger, _)
		checkUnitResurrected(trigger, unitDefID, unitTeam, builderID)
	end)

	processTriggersOfType(types.ConstructionStarted, function(trigger, _)
		checkConstructionStarted(trigger, unitID, unitDefID, unitTeam)
	end)
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, _, _, _)
	processTriggersOfType(types.UnitKilled, function(trigger, _)
		checkUnitRemoved(trigger, unitID, unitDefID, unitTeam)
	end)

	untrackUnitID(unitID)
end

function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	processTriggersOfType(types.UnitCaptured, function(trigger, _)
		checkUnitCaptured(trigger, unitID, unitDefID, oldTeam, newTeam)
	end)
end

function gadget:UnitEnteredLos(unitID, unitTeam, losAllyTeamID, unitDefID)
	processTriggersOfType(types.UnitSpotted, function(trigger, _)
		checkUnitEnteredOrLeftLos(trigger, unitID, unitTeam, losAllyTeamID, unitDefID)
	end)
end

function gadget:UnitLeftLos(unitID, unitTeam, losAllyTeamID, unitDefID)
	processTriggersOfType(types.UnitUnspotted, function(trigger, _)
		checkUnitEnteredOrLeftLos(trigger, unitID, unitTeam, losAllyTeamID, unitDefID)
	end)
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	processTriggersOfType(types.ConstructionFinished, function(trigger, _)
		checkConstructionFinished(trigger, unitID, unitDefID, unitTeam)
	end)
end

function gadget:TeamDied(teamID)
	processTriggersOfType(types.TeamDestroyed, function(trigger, _)
		checkTeamDestroyed(trigger, teamID)
	end)
end

local reclaimedFeatures = {}
function gadget:AllowFeatureBuildStep(builderID, builderTeamID, featureID, featureDefID, buildStep)
	if buildStep < 0 then
		-- Negative buildStep means reclaim
		reclaimedFeatures[featureID] = builderTeamID
	end
	return true
end

function gadget:FeatureCreated(featureID, allyTeamID, userID)
	local featureDefID = Spring.GetFeatureDefID(featureID)
	processTriggersOfType(types.FeatureCreated, function(trigger, _)
		checkFeatureCreated(trigger, featureID, featureDefID)
	end)
end

function gadget:FeatureDestroyed(featureID, attackerAllyTeamID)
	local featureDefID = Spring.GetFeatureDefID(featureID)
	local reclaimerTeamID = reclaimedFeatures[featureID]

	if reclaimerTeamID then
		-- Feature was fully reclaimed
		reclaimedFeatures[featureID] = nil
		processTriggersOfType(types.FeatureReclaimed, function(trigger, _)
			checkFeatureReclaimed(trigger, featureID, featureDefID, reclaimerTeamID)
		end)
	else
		-- Feature was destroyed, allyTeamID is the attacker's ally team.
		processTriggersOfType(types.FeatureDestroyed, function(trigger, _)
			checkFeatureDestroyed(trigger, featureID, featureDefID, attackerAllyTeamID)
		end)
	end

	untrackFeatureID(featureID)
end
