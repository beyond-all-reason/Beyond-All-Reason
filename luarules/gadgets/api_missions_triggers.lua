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

local INCOME_ON_FULL_UNIT_RECLAIM = Game.reclaimUnitMethod == 1 and Game.reclaimUnitDrainHealth
local RECLAIM_UNIT_EFFICIENCY = Game.reclaimUnitEfficiency

local conditionTypes, triggers, triggersByType, conditionContext ---@type table, table<string, table>, table, table

local callins ---@type table
local unitsEnteredAreaHandlers ---@type table<string, function?>
local unitsLeftAreaHandlers ---@type table<string, function?>
local needsBuildOwnerMap = false
local needsBuildStartSet = false

local actionsDispatcher
local batch
local startBatch, endBatch ---@type function, function
local statistics
local countdowns
local detectionLevels
local seismicContacts
local seismicIntervalFrames ---@type integer

local trackedUnitNames
local doesUnitHaveName
local doesUnitMatch ---@type function
local untrackUnitID
local doesFeatureHaveName
local untrackFeatureID

-- Shared trigger state (exposed to per-trigger handlers via conditionContext):
local constructionState = {}
local stockpileState = {}
local dwellingUnitsInAreas = {}
local revealedLocations = {}
local gatheredUnitsInAreas = {}
local wasUnderConstruction = {}

-- Local bookkeeping for various concerns: build, reclaim, detection, transfer.
local teamReclaimIncome = {}
local teamReclaimIncomeSnapshot = {}
local reclaimedFeatures = {}
local buildPlacements = {}
local buildFrameOwners = {}
local constructionStarts = {}
local detections = {}
local detectionCount = 0
local undetectedUnits = {}
local capturedUnits = {}

local refusedMetricTriggers = {}
local refusedMetricTriggerList = {}
local reevaluateRefusedMetricTriggers

----------------------------------------------------------------
--- Trigger Functions:
----------------------------------------------------------------

-- Iterates only the triggers of the given type, using the load-time index so
-- that per-frame call-ins do not scan every trigger in the mission.
local function processTriggersOfType(conditionType, func)
	local ofType = triggersByType[conditionType]
	if not ofType then
		return
	end
	for i = 1, #ofType do
		local entry = ofType[i]
		func(entry.trigger, entry.id)
	end
end

local function isTriggerValid(trigger)
	local settings = trigger.settings

	if not settings.active then
		return false
	end

	for _, prerequisiteTriggerID in pairs(settings.prerequisites) do
		if not triggers[prerequisiteTriggerID].triggered then
			return false
		end
	end

	if
		next(settings.stages)
		and not table.contains(settings.stages, GG["MissionAPI"].Modules.Stages.GetCurrentStageID())
	then
		return false
	end

	if trigger.triggered and not settings.repeating then
		return false
	end
	if settings.repeating and settings.maxRepeats ~= nil and trigger.repeatCount > settings.maxRepeats then
		return false
	end
	if
		settings.difficulties ~= nil
		and next(settings.difficulties)
		and not table.contains(settings.difficulties, GG["MissionAPI"].Difficulty)
	then
		return false
	end

	--[[
	--TODO: co-op check
	if trigger.coop and not ??? then return false end
	]]

	return true
end

local function activateTrigger(trigger)
	-- Event conditions tally occurrences and fire once per `count` of them, so
	-- `count = 4` fires on the 4th, then the 8th when repeating. `count` is nil
	-- or 1 for the common "every occurrence" case.
	-- The tally runs even while the trigger is blocked by its stage or
	-- prerequisites, so what the player already did still counts once it opens.
	local count = trigger.count
	local isTallied = count and count > 1
	if isTallied then
		trigger.occurrences = (trigger.occurrences or 0) + 1
	end

	if not isTriggerValid(trigger) then
		return false
	end

	if isTallied then
		if trigger.occurrences < (trigger.repeatCount + 1) * count then
			if trigger.onProgress then
				trigger.onProgress(trigger.occurrences)
			end
			return false
		end
	end

	trigger.triggered = true
	trigger.repeatCount = trigger.repeatCount + 1

	startBatch()
	-- Objective conditions carry onActivate instead of actions: activation
	-- completes the objective rather than invoking mission actions.
	if trigger.onActivate then
		trigger.onActivate(trigger)
	else
		for _, actionID in ipairs(trigger.actions) do
			actionsDispatcher.Invoke(actionID)
		end
	end
	endBatch()
	if next(refusedMetricTriggers) then
		batch.DeferNetValue(reevaluateRefusedMetricTriggers, refusedMetricTriggers)
	end

	return true
end

local function isMetricSatisfied(trigger, value)
	return (trigger.atLeast == nil or value >= trigger.atLeast)
		and (trigger.atMost == nil or value <= trigger.atMost)
		and (trigger.equals == nil or value == trigger.equals)
end

-- Metric conditions compare a sampled value against `atLeast`, `atMost`, or
-- `equals`. They are edge triggered: firing once when the value enters the
-- satisfied range, and re-arming only once it leaves again, so a condition that
-- stays true does not fire every sample.
--
-- The edge is only consumed once the condition actually fires. A trigger that is
-- satisfied but currently blocked -- by an unmet prerequisite, the wrong stage or
-- difficulty -- keeps its edge and fires as soon as it becomes valid. Otherwise
-- "energy >= 3500 once metal >= 1800" would silently never fire when energy
-- happened to arrive first.
local function evaluateMetric(trigger, value)
	trigger.lastValue = value

	if not isMetricSatisfied(trigger, value) then
		trigger.metricSatisfied = false
		if trigger.onProgress and isTriggerValid(trigger) then
			trigger.onProgress(value)
		end
		return false
	end

	if trigger.metricSatisfied then
		return false
	end

	-- Marked first, so that the trigger's actions cannot activate it again.
	trigger.metricSatisfied = true
	local activated = activateTrigger(trigger)
	if not activated then
		trigger.metricSatisfied = false
		refusedMetricTriggers[trigger] = true
	end
	return activated
end

reevaluateRefusedMetricTriggers = function()
	local count = 0
	for trigger in pairs(refusedMetricTriggers) do
		count = count + 1
		refusedMetricTriggerList[count] = trigger
	end
	for i = 1, count do
		local trigger = refusedMetricTriggerList[i]
		refusedMetricTriggerList[i] = nil
		refusedMetricTriggers[trigger] = nil
		evaluateMetric(trigger, trigger.lastValue)
	end
end

local function activateTriggerAndReport(trigger, onActivationAttempted, triggerID, argument)
	local activated = activateTrigger(trigger)
	onActivationAttempted(trigger, triggerID, conditionContext, argument, activated)
end

---Activates the trigger when the batch ends, and returns nothing.
---A condition that needs the outcome passes onActivationAttempted(trigger, triggerID, context, argument, activated).
local function deferActivation(trigger, onActivationAttempted, triggerID, argument)
	if onActivationAttempted then
		batch.Defer(activateTriggerAndReport, trigger, onActivationAttempted, triggerID, argument)
	else
		batch.Defer(activateTrigger, trigger)
	end
end

local function evaluateLastValue(trigger)
	evaluateMetric(trigger, trigger.lastValue)
end

---Evaluates the metric against its net value when the batch ends.
local function deferEvaluation(trigger, value)
	local satisfied = isMetricSatisfied(trigger, value)
	if not satisfied and not trigger.metricSatisfied then
		evaluateMetric(trigger, value)
	else
		trigger.lastValue = value
		if satisfied ~= trigger.metricSatisfied then
			batch.DeferNetValue(evaluateLastValue, trigger)
		end
	end
end

----------------------------------------------------------------
--- Trigger Call-in Dispatch:
----------------------------------------------------------------

-- unpack() does not handle optional parameters, as it cannot pass a value as nil
local function unpackCallinArgs(args, i)
	i = i or 1

	if i <= args.n then
		return args[i], unpackCallinArgs(args, i + 1)
	end
end

-- Dispatches a logical call-in to every per-trigger handler registered for it.
-- Each handler receives (trigger, triggerID, conditionContext, ...call-in args).
local function dispatchConditionCallin(callinName, ...)
	local handlersByType = callins[callinName]
	if not handlersByType then
		return
	end
	local args = table.pack(...)
	startBatch()
	for conditionType, handler in pairs(handlersByType) do
		processTriggersOfType(conditionType, function(trigger, triggerID)
			handler(trigger, triggerID, conditionContext, unpackCallinArgs(args))
		end)
	end
	endBatch()
end

-- Location triggers share area tracking's per-frame poll, one per distinct area and team,
-- and handlers receive only the units that crossed a tracking boundary.

---@param triggerID string
local function onUnitsEnteredArea(unitIDs, triggerID)
	local trigger = triggers[triggerID]
	local handler = unitsEnteredAreaHandlers[trigger.type]
	if handler then
		startBatch()
		handler(trigger, triggerID, conditionContext, unitIDs)
		endBatch()
	end
end

---@param triggerID string
local function onUnitsLeftArea(unitIDs, triggerID)
	local trigger = triggers[triggerID]
	local handler = unitsLeftAreaHandlers[trigger.type]
	if handler then
		startBatch()
		handler(trigger, triggerID, conditionContext, unitIDs)
		endBatch()
	end
end

local function dispatchVariableWritten(key)
	dispatchConditionCallin("VariableWritten", key)
end

local function onVariableWritten(key)
	batch.DeferNetValue(dispatchVariableWritten, key)
end

local function markDetectionDirty(unitID)
	if not detections[unitID] then
		detections[unitID] = true
		detectionCount = detectionCount + 1
	end
end

----------------------------------------------------------------
--- Utility Functions:
----------------------------------------------------------------

local function isFeatureInArea(featureID, area)
	local featureX, _, featureZ = Spring.GetFeaturePosition(featureID)
	return math.isPointInArea(featureX, featureZ, area)
end

-- The owner is the builder that created the frame. Assisting builders never own it.
local function isBuildFrameOwner(buildeeID, builderName, builderDefName)
	if not builderName and not builderDefName then
		return true
	end
	local builder = buildFrameOwners[buildeeID] ---@as table?
	return builder ~= nil and doesUnitMatch(builder.id, builderName, builderDefName)
end

local function inFactory(buildeeID)
	local builder = buildFrameOwners[buildeeID]
	return builder and builder.isFactory
end

-- ConstructionStarted sees a buildee from both UnitCreated and BuildAssisted.
-- Each trigger fires once per buildee from the callin that first activates it.
local function claimConstructionStart(buildeeID, triggerID)
	local claims = constructionStarts[buildeeID]
	if claims then
		claims[triggerID] = true
		return
	end
	constructionStarts[buildeeID] = { [triggerID] = true }
end

local function hasConstructionStarted(buildeeID, triggerID)
	local claims = constructionStarts[buildeeID]
	return claims and claims[triggerID]
end

----------------------------------------------------------------
--- Call-ins:
----------------------------------------------------------------

function gadget:GameStart()
	dispatchConditionCallin("VariablesInitialized")
	dispatchConditionCallin("GameStart")
end

function gadget:GameFrame(frameNumber)
	batch.Reset()

	if frameNumber % Game.gameSpeed == 0 then
		-- Reset reclaim income counters (read by ResourceIncome handlers):
		teamReclaimIncomeSnapshot = teamReclaimIncome
		teamReclaimIncome = {}
	end

	-- Displayed countdowns tick together on whole seconds, non-displayed ones
	-- relative to their creation frame (see Decrement() in countdowns.lua):
	local endedCountdownIDs, countdownTicks = countdowns.Decrement(frameNumber)
	for i = 1, #countdownTicks do
		dispatchConditionCallin("CountdownTick", countdownTicks[i].id, countdownTicks[i].timeRemaining)
	end
	for i = 1, #endedCountdownIDs do
		dispatchConditionCallin("CountdownEnded", endedCountdownIDs[i])
	end

	dispatchConditionCallin("GameFrame", frameNumber)

	if frameNumber % seismicIntervalFrames == 0 then
		local n = seismicContacts.UpdateContacts(undetectedUnits)
		for i = 1, n do
			markDetectionDirty(undetectedUnits[i])
		end
	end
end

function gadget:GameFramePost(frameNumber)
	if detectionCount > 0 then
		detectionLevels.BeginUpdate()
		dispatchConditionCallin("DetectionUpdate", detections)
		for unitID in pairs(detections) do
			detections[unitID] = nil
		end
		detectionCount = 0
	end

	if next(buildPlacements) ~= nil then
		for builderID, unitDefID in pairs(buildPlacements) do
			local buildeeID = Spring.GetUnitIsBuilding(builderID)
			if buildeeID and Spring.GetUnitIsBeingBuilt(buildeeID) and Spring.GetUnitDefID(buildeeID) == unitDefID then
				dispatchConditionCallin("BuildAssisted", buildeeID, unitDefID, Spring.GetUnitTeam(buildeeID), builderID)
			end
		end
		buildPlacements = {}
	end
end

function gadget:TeamDied(teamID)
	dispatchConditionCallin("TeamDied", teamID)
end

function gadget:MetaUnitAdded(unitID, unitDefID, unitTeam)
	-- Other gadgets may create units within a spawn action. Assign loadout names only to loadout units.
	local mapi = GG.MissionAPI
	if mapi.nameOfUnitBeingSpawned and mapi.unitIDBeingSpawned == nil then
		mapi.unitIDBeingSpawned = unitID
	end

	startBatch()
	dispatchConditionCallin("MetaUnitAdded", unitID, unitDefID, unitTeam)

	local unitDefName = UnitDefs[unitDefID].name
	local unitNames = table.copy(trackedUnitNames[unitID] or {})

	if mapi.unitIDBeingSpawned == unitID then
		unitNames[mapi.nameOfUnitBeingSpawned] = true
	end
	statistics.Increment(conditionTypes.UnitsOwned, unitTeam, unitDefName, unitNames)
	endBatch()
end

function gadget:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	startBatch()
	dispatchConditionCallin("MetaUnitRemoved", unitID, unitDefID, unitTeam)

	local unitDefName = UnitDefs[unitDefID].name
	local unitNames = trackedUnitNames[unitID] or {}
	statistics.Decrement(conditionTypes.UnitsOwned, unitTeam, unitDefName, unitNames)
	endBatch()

	-- Don't untrack unit here, as other call-ins run after this one (UnitDestroyed, UnitTaken, ...)
end

-- AllowUnitTransfer can tell captured units from shared ones; UnitGiven, UnitTaken cannot.
function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
	capturedUnits[unitID] = capture or nil
	return true
end

function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	startBatch()
	dispatchConditionCallin("UnitTaken", unitID, unitDefID, oldTeam, newTeam, capturedUnits[unitID] == true)

	local unitDefName = UnitDefs[unitDefID].name
	local unitNames = trackedUnitNames[unitID] or {}
	statistics.Increment(conditionTypes.TotalUnitsCaptured, newTeam, unitDefName, unitNames)
	endBatch()
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	dispatchConditionCallin("UnitGiven", unitID, unitDefID, newTeam, oldTeam, capturedUnits[unitID] == true)
	capturedUnits[unitID] = nil
end

function gadget:AllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z, facing)
	if x then
		buildPlacements[builderID] = unitDefID
	end
	return true
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	dispatchConditionCallin("UnitCreated", unitID, unitDefID, unitTeam, builderID)

	if builderID then
		buildPlacements[builderID] = nil
	end

	local beingBuilt = Spring.GetUnitIsBeingBuilt(unitID)
	if beingBuilt then
		if needsBuildStartSet then
			wasUnderConstruction[unitID] = true
		end
		if needsBuildOwnerMap and builderID then
			local builderDefID = Spring.GetUnitDefID(builderID)
			buildFrameOwners[unitID] = {
				id = builderID,
				defID = builderDefID,
				isFactory = UnitDefs[builderDefID].isFactory,
			}
		end
	end
end

function gadget:UnitBuildStepPost(unitID)
	dispatchConditionCallin("UnitBuildStepPost", unitID)
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	startBatch()
	dispatchConditionCallin("UnitFinished", unitID, unitDefID, unitTeam)

	buildFrameOwners[unitID] = nil
	constructionStarts[unitID] = nil
	wasUnderConstruction[unitID] = nil

	-- Don't count units spawned by SpawnUnits action, nor starting commanders, initial loadout, wildlife, etc.
	if not GG["MissionAPI"].spawningUnit and Spring.GetGameFrame() > 0 then
		local unitDefName = UnitDefs[unitDefID].name
		statistics.Increment(conditionTypes.TotalUnitsBuilt, unitTeam, unitDefName)
	end
	endBatch()
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	startBatch()
	dispatchConditionCallin(
		"UnitDestroyed",
		unitID,
		unitDefID,
		unitTeam,
		attackerID,
		attackerDefID,
		attackerTeam,
		weaponDefID
	)

	local unitDefName = UnitDefs[unitDefID].name
	local unitNames = trackedUnitNames[unitID] or {}

	-- The unit's team lost a unit:
	statistics.Increment(conditionTypes.TotalUnitsLost, unitTeam, unitDefName, unitNames)

	-- The attacker's team kills an enemy unit:
	if attackerTeam and not Spring.AreTeamsAllied(attackerTeam, unitTeam) then
		statistics.Increment(conditionTypes.TotalUnitsKilled, attackerTeam, unitDefName, unitNames)
	end

	buildFrameOwners[unitID] = nil
	constructionStarts[unitID] = nil
	wasUnderConstruction[unitID] = nil

	-- TODO: Will become a general method for informing presentation layer that a unit is gone.
	GG["MissionAPI"].Modules.UnitMarkers.RemoveUnitMarkers(unitID)
	untrackUnitID(unitID)
	endBatch()
end

function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
	dispatchConditionCallin("UnitCommand", unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
end

function gadget:UnitIdlePost(unitID, idled)
	dispatchConditionCallin("UnitIdlePost", unitID, idled)
end

function gadget:AllowUnitBuildStep(builderID, builderTeamID, unitID, unitDefID, buildStep)
	if buildStep < 0 then
		local health, maxHealth, _, _, buildProgress = Spring.GetUnitHealth(unitID)
		if health and maxHealth and (health + maxHealth * buildStep) <= 0 then
			local unitDef = UnitDefs[unitDefID] ---@as table
			local reclaimMetal = unitDef.metalCost * (buildProgress or 1) * RECLAIM_UNIT_EFFICIENCY

			local t = table.ensureTable(teamReclaimIncome, builderTeamID)
			t.metal = (t.metal or 0) + reclaimMetal
		end
	end
	return true
end

function gadget:AllowFeatureBuildStep(builderID, builderTeamID, featureID, featureDefID, buildStep)
	-- Negative buildStep means reclaim
	if buildStep < 0 then
		local featureDef = FeatureDefs[featureDefID] ---@as table
		reclaimedFeatures[featureID] = builderTeamID

		-- Accumulate reclaim incomes - buildStep is fraction of feature's total reclaim
		local t = table.ensureTable(teamReclaimIncome, builderTeamID)
		t.metal = (t.metal or 0) + math.abs(buildStep) * featureDef.metal
		t.energy = (t.energy or 0) + math.abs(buildStep) * featureDef.energy
	end
	return true
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	local transportDefID = Spring.GetUnitDefID(transportID)
	dispatchConditionCallin("UnitLoaded", unitID, unitDefID, unitTeam, transportID, transportDefID, transportTeam)
end

function gadget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	local transportDefID = Spring.GetUnitDefID(transportID)
	dispatchConditionCallin("UnitUnloaded", unitID, unitDefID, unitTeam, transportID, transportDefID, transportTeam)
end

function gadget:UnitDamaged(
	unitID,
	unitDefID,
	unitTeam,
	damage,
	paralyzer,
	weaponDefID,
	projectileID,
	attackerID,
	attackerDefID,
	attackerTeam
)
	dispatchConditionCallin(
		"UnitDamaged",
		unitID,
		unitDefID,
		unitTeam,
		damage,
		paralyzer,
		weaponDefID,
		projectileID,
		attackerID,
		attackerDefID,
		attackerTeam
	)
end

function gadget:StockpileChanged(unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount)
	dispatchConditionCallin("StockpileChanged", unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount)
end

function gadget:UnitEnteredLos(unitID, unitTeam, losAllyTeamID, unitDefID)
	markDetectionDirty(unitID)
end

function gadget:UnitLeftLos(unitID, unitTeam, losAllyTeamID, unitDefID)
	markDetectionDirty(unitID)
end

function gadget:UnitEnteredRadar(unitID, unitTeam, radarAllyTeamID, unitDefID)
	markDetectionDirty(unitID)
end

function gadget:UnitLeftRadar(unitID, unitTeam, radarAllyTeamID, unitDefID)
	markDetectionDirty(unitID)
end

function gadget:UnitSeismicPing(x, y, z, strength, seismicAllyTeamID, unitID, unitDefID)
	seismicContacts.RecordPing(seismicAllyTeamID, unitID)
	markDetectionDirty(unitID)
end

function gadget:FeatureCreated(featureID, allyTeamID)
	local featureDefID = Spring.GetFeatureDefID(featureID)
	dispatchConditionCallin("FeatureCreated", featureID, featureDefID)
end

function gadget:FeatureDestroyed(featureID, attackerAllyTeamID)
	local featureDefID = Spring.GetFeatureDefID(featureID)
	local _, _, _, _, reclaimLeft = Spring.GetFeatureResources(featureID)
	local reclaimerTeamID = reclaimedFeatures[featureID]

	-- FeatureReclaimed / FeatureDestroyed handlers self-guard on reclaimerTeamID + reclaimLeft.
	dispatchConditionCallin(
		"FeatureDestroyed",
		featureID,
		featureDefID,
		attackerAllyTeamID,
		reclaimerTeamID,
		reclaimLeft
	)

	reclaimedFeatures[featureID] = nil
	untrackFeatureID(featureID)
end

function gadget:Initialize()
	if not Spring.GetGameRulesParam("inMission") then
		gadgetHandler:RemoveGadget()
		return
	end

	triggers = GG["MissionAPI"].Triggers
	triggersByType = VFS.Include("luarules/mission_api/conditions_loader.lua").IndexTriggersByType(triggers)
	conditionTypes = GG["MissionAPI"].ConditionDefinitions.Types
	callins = {}
	for callinName, handlersByType in pairs(GG["MissionAPI"].ConditionDefinitions.Callins) do
		local handlersWithTriggers = {}
		for conditionType, handler in pairs(handlersByType) do
			if triggersByType[conditionType] then
				handlersWithTriggers[conditionType] = handler
			end
		end
		if next(handlersWithTriggers) then
			callins[callinName] = handlersWithTriggers
		end
	end

	actionsDispatcher = VFS.Include("luarules/mission_api/actions_dispatcher.lua")

	seismicContacts = GG["MissionAPI"].Modules.SeismicContacts
	seismicIntervalFrames = seismicContacts.UpdateInterval
	detectionLevels = GG["MissionAPI"].Modules.DetectionLevels
	countdowns = GG["MissionAPI"].Modules.Countdowns
	batch = GG["MissionAPI"].Modules.Batch
	startBatch, endBatch = batch.Start, batch.End

	statistics = VFS.Include("luarules/mission_api/statistics.lua")
	statistics.Init({
		processTriggersOfType = processTriggersOfType,
		activateTrigger = activateTrigger,
		evaluateMetric = evaluateMetric,
		conditionKinds = GG["MissionAPI"].ConditionDefinitions.Kinds,
		batch = batch,
	})
	-- TODO: Resolve flat globals vs imports vs the DI pattern (above).
	GG["MissionAPI"].ActivateTrigger = deferActivation
	GG["MissionAPI"].EvaluateMetric = deferEvaluation

	local tracking = GG["MissionAPI"].Modules.Tracking
	doesUnitHaveName = tracking.DoesUnitHaveName
	untrackUnitID = tracking.UntrackUnitID
	trackedUnitNames = GG["MissionAPI"].trackedUnitNames
	doesFeatureHaveName = tracking.DoesFeatureHaveName
	untrackFeatureID = tracking.UntrackFeatureID

	doesUnitMatch = GG["MissionAPI"].Modules.UnitQuery.DoesUnitMatch

	GG["MissionAPI"].Modules.Variables.ReportVariableWrites(onVariableWritten)

	conditionContext = {
		ActivateTrigger = deferActivation,
		EvaluateMetric = deferEvaluation,
		DoesUnitHaveName = doesUnitHaveName,
		DoesUnitMatch = doesUnitMatch,
		DoesFeatureHaveName = doesFeatureHaveName,
		IsBuildFrameOwner = isBuildFrameOwner,
		InFactory = inFactory,
		ClaimConstructionStart = claimConstructionStart,
		HasConstructionStarted = hasConstructionStarted,
		WasUnderConstruction = wasUnderConstruction,
		IsFeatureInArea = isFeatureInArea,
		ConstructionState = constructionState,
		StockpileState = stockpileState,
		DwellingUnitsInAreas = dwellingUnitsInAreas,
		RevealedLocations = revealedLocations,
		GatheredUnitsInAreas = gatheredUnitsInAreas,
		GetReclaimIncomeSnapshot = function(teamID)
			return teamReclaimIncomeSnapshot[teamID]
		end,
	}

	unitsEnteredAreaHandlers = callins.UnitsEnteredArea or {}
	unitsLeftAreaHandlers = callins.UnitsLeftArea or {}
	local areaTracking = GG["MissionAPI"].Modules.AreaTracking
	for triggerID, trigger in pairs(triggers) do
		if unitsEnteredAreaHandlers[trigger.type] or unitsLeftAreaHandlers[trigger.type] then
			local parameters = trigger.parameters
			areaTracking.TrackUnitsInArea(
				parameters.area,
				parameters.teamName,
				triggerID,
				onUnitsEnteredArea,
				onUnitsLeftArea
			)
		end
	end

	local hasConditionType = {}
	for _, typeID in pairs(conditionTypes) do
		hasConditionType[typeID] = false
	end
	for _, trigger in pairs(triggers) do
		hasConditionType[trigger.type] = true
		local parameters = trigger.parameters
		if
			parameters ~= nil
			and (
				parameters.builderName
				or parameters.builderDefName
				or parameters.factoryName
				or parameters.factoryDefName
			)
		then
			needsBuildOwnerMap = true
		end
	end

	needsBuildOwnerMap = needsBuildOwnerMap
		or hasConditionType[conditionTypes.ConstructionCanceled]
		or hasConditionType[conditionTypes.ProductionCanceled]
	needsBuildStartSet = hasConditionType[conditionTypes.ConstructionFinished]

	-- Check support for hot callins. These tend to be heavy in bursts not on average.
	-- Only remain subscribed to these when the loaded mission actually requires them.
	for callinName, needed in pairs({
		AllowUnitCreation = hasConditionType[conditionTypes.ConstructionStarted],
		AllowUnitBuildStep = hasConditionType[conditionTypes.ResourceIncome] and INCOME_ON_FULL_UNIT_RECLAIM,
		AllowFeatureBuildStep = hasConditionType[conditionTypes.ResourceIncome]
			or hasConditionType[conditionTypes.FeatureReclaimed]
			or hasConditionType[conditionTypes.FeatureDestroyed],
		UnitBuildStepPost = hasConditionType[conditionTypes.ConstructionProgress],
		UnitDamaged = hasConditionType[conditionTypes.UnitAttacked],
		StockpileChanged = hasConditionType[conditionTypes.StockpileCount]
			or hasConditionType[conditionTypes.StockpileProgress],
	}) do
		if not needed then
			gadgetHandler:RemoveCallIn(callinName)
		end
	end
end
