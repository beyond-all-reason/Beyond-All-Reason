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
local triggerTypes, triggers, triggersByType, callins, triggerContext
local trackedUnitNames
local statistics
local seismicContacts
local SEISMIC_INTERVAL_FRAMES
local detectionLevels
local needsBuildPlacements
local needsBuildOwnerMap
local needsBuildStartSet

-- Shared trigger state (exposed to per-trigger handlers via triggerContext):
local previousUnitsInAreas = {}
local constructionState = {}
local dwellingUnitsInAreas = {}
local teamReclaimIncome = {}
local teamReclaimIncomeSnapshot = {}
local reclaimedFeatures = {}
local buildPlacements = {}
local buildFrameOwners = {}
local constructionStarts = {}
local underConstruction = {}
local detections = {}
local detectionCount = 0

----------------------------------------------------------------
--- Utility Functions:
----------------------------------------------------------------

-- Iterates only the triggers of the given type, using the load-time index so
-- that per-frame call-ins do not scan every trigger in the mission.
local function processTriggersOfType(triggerType, func)
	local ofType = triggersByType[triggerType]
	if not ofType then
		return
	end
	for i = 1, #ofType do
		local entry = ofType[i]
		func(entry.trigger, entry.id)
	end
end

local function isTriggerValid(trigger)
	if not trigger.settings.active then
		return false
	end

	for _, prerequisiteTriggerID in pairs(trigger.settings.prerequisites) do
		if not triggers[prerequisiteTriggerID].triggered then
			return false
		end
	end

	if
		next(trigger.settings.stages) and not table.contains(trigger.settings.stages, GG["MissionAPI"].CurrentStageID)
	then
		return false
	end

	if trigger.triggered and not trigger.settings.repeating then
		return false
	end
	if
		trigger.settings.repeating
		and trigger.settings.maxRepeats ~= nil
		and trigger.repeatCount > trigger.settings.maxRepeats
	then
		return false
	end
	if trigger.settings.difficulties ~= nil and not trigger.settings.difficulties[GG["MissionAPI"].Difficulty] then
		return false
	end

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

	-- Event conditions tally occurrences and fire once per `count` of them, so
	-- `count = 4` fires on the 4th, then the 8th when repeating. `count` is nil
	-- or 1 for the common "every occurrence" case.
	local count = trigger.count
	if count and count > 1 then
		trigger.occurrences = (trigger.occurrences or 0) + 1
		if trigger.occurrences < (trigger.repeatCount + 1) * count then
			if trigger.onProgress then
				trigger.onProgress(trigger.occurrences)
			end
			return false
		end
	end

	trigger.triggered = true
	trigger.repeatCount = trigger.repeatCount + 1

	-- Objective conditions carry onActivate instead of actions: activation
	-- completes the objective rather than invoking mission actions.
	if trigger.onActivate then
		trigger.onActivate(trigger)
	else
		for _, actionID in ipairs(trigger.actions) do
			actionsDispatcher.Invoke(actionID)
		end
	end

	return true
end

-- Metric conditions compare a sampled value against `atLeast`/`atMost`. They are
-- edge triggered: firing once when the value enters the satisfied range, and
-- re-arming only once it leaves again, so a condition that stays true does not
-- fire every sample.
--
-- The edge is only consumed once the condition actually fires. A trigger that is
-- satisfied but currently blocked -- by an unmet prerequisite, the wrong stage or
-- difficulty -- keeps its edge and fires as soon as it becomes valid. Otherwise
-- "energy >= 3500 once metal >= 1800" would silently never fire when energy
-- happened to arrive first.
local function evaluateMetric(trigger, value)
	trigger.lastValue = value

	local satisfied = (trigger.atLeast == nil or value >= trigger.atLeast)
		and (trigger.atMost == nil or value <= trigger.atMost)

	if not satisfied then
		trigger.metricSatisfied = false
		-- Progress is user-facing, so it is gated the same way activation is: an
		-- objective outside the current stage, or behind an unmet prerequisite,
		-- has nothing to report yet. The edge bookkeeping above stays
		-- unconditional so a blocked condition still fires once it unblocks.
		if trigger.onProgress and isTriggerValid(trigger) then
			trigger.onProgress(value)
		end
		return false
	end

	if trigger.metricSatisfied then
		return false
	end

	local fired = activateTrigger(trigger)
	if fired then
		trigger.metricSatisfied = true
	end
	return fired
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

local function isFeatureInArea(featureID, area)
	local featureX, _, featureZ = Spring.GetFeaturePosition(featureID)
	return math.isPointInArea(featureX, featureZ, area)
end

-- Attempt at single-assigning a construction task owner to each buildee.
-- When multiple constructors place the same buildDefID, any can become an
-- "owner" in some technical sense, since only factories own build frames.
local function isBuildFrameOwner(unbuiltID, builderName, builderDefName)
	if not builderName and not builderDefName then
		return true
	end
	local builder = buildFrameOwners[unbuiltID]
	if not builder then
		return false
	end
	if builderDefName and builderDefName ~= UnitDefs[builder.defID].name then
		return false
	end
	if builderName and not doesUnitHaveName(builder.id, builderName) then
		return false
	end
	return true
end

local function inFactory(buildeeID)
	local builder = buildFrameOwners[buildeeID]
	return builder and builder.isFactory
end

-- ConstructionStarted gets buildees from two call-ins. Only one can claim.
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
-- Each handler receives (trigger, triggerID, triggerContext, ...call-in args).
local function dispatchTriggerCallin(callinName, ...)
	local handlersByType = callins[callinName]
	if not handlersByType then
		return
	end
	local args = table.pack(...)
	for triggerType, handler in pairs(handlersByType) do
		processTriggersOfType(triggerType, function(trigger, triggerID)
			handler(trigger, triggerID, triggerContext, unpackCallinArgs(args))
		end)
	end
end

-- Detection events are hot paths with complicated routing at M^2 routing cost.
-- Their updates combine in `DetectionUpdate` following a per-event dirty mark.
local function markDetectionDirty(unitID)
	if not detections[unitID] then
		detections[unitID] = true
		detectionCount = detectionCount + 1
	end
end
local inactiveSeismicContacts = {}

----------------------------------------------------------------
--- Call-ins:
----------------------------------------------------------------

function gadget:Initialize()
	if not GG["MissionAPI"] then
		gadgetHandler:RemoveGadget()
		return
	end

	triggerTypes = GG["MissionAPI"].ConditionDefinitions.Types
	callins = GG["MissionAPI"].ConditionDefinitions.Callins
	triggers = GG["MissionAPI"].Triggers
	triggersByType = VFS.Include("luarules/mission_api/conditions_loader.lua").IndexTriggersByType(triggers)
	trackedUnitNames = GG["MissionAPI"].trackedUnitNames

	actionsDispatcher = GG["MissionAPI"].Modules.ActionsDispatcher

	seismicContacts = GG["MissionAPI"].Modules.SeismicContacts
	SEISMIC_INTERVAL_FRAMES = seismicContacts.UpdateInterval
	detectionLevels = GG["MissionAPI"].Modules.DetectionLevels

	statistics = VFS.Include("luarules/mission_api/statistics.lua")
	statistics.Init({
		processTriggersOfType = processTriggersOfType,
		activateTrigger = activateTrigger,
		evaluateMetric = evaluateMetric,
		conditionKinds = GG["MissionAPI"].ConditionDefinitions.Kinds,
	})

	local tracking = GG["MissionAPI"].Modules.Tracking
	doesUnitHaveName = tracking.DoesUnitHaveName
	untrackUnitID = tracking.UntrackUnitID
	doesFeatureHaveName = tracking.DoesFeatureHaveName
	untrackFeatureID = tracking.UntrackFeatureID

	triggerContext = {
		ActivateTrigger = activateTrigger,
		EvaluateMetric = evaluateMetric,
		DoesUnitHaveName = doesUnitHaveName,
		DoesFeatureHaveName = doesFeatureHaveName,
		IsBuildFrameOwner = isBuildFrameOwner,
		InFactory = inFactory,
		ClaimConstructionStart = claimConstructionStart,
		HasConstructionStarted = hasConstructionStarted,
		WasUnderConstruction = underConstruction,
		GetUnitsInArea = getUnitsInArea,
		IsFeatureInArea = isFeatureInArea,
		PreviousUnitsInAreas = previousUnitsInAreas,
		ConstructionState = constructionState,
		DwellingUnitsInAreas = dwellingUnitsInAreas,
		GetReclaimIncomeSnapshot = function(teamID)
			return teamReclaimIncomeSnapshot[teamID]
		end,
	}

	-- AllowFeatureBuildStep / AllowUnitBuildStep fire on every builder's build or
	-- reclaim step (among the hottest call-ins in the game), so only stay subscribed
	-- to them when the loaded mission actually needs the reclaim bookkeeping they do:
	--   * AllowUnitBuildStep accumulates unit reclaim income -> only ResourceIncome.
	--   * AllowFeatureBuildStep accumulates feature reclaim income (ResourceIncome)
	--     AND marks reclaimedFeatures, which FeatureReclaimed needs to fire and
	--     FeatureDestroyed needs to suppress reclaims (avoid firing "destroyed").
	local needsReclaimIncome = table.any(triggers, function(trigger)
		return trigger.type == triggerTypes.ResourceIncome
	end)

	if not needsReclaimIncome then
		gadgetHandler:RemoveCallIn("AllowUnitBuildStep")
	end

	-- Summary view over the *BuildStep callins behave similarly so we unhook them.
	local needsConstructionProgress = table.any(triggers, function(trigger)
		return trigger.type == triggerTypes.ConstructionProgress
	end)

	if not needsConstructionProgress then
		gadgetHandler:RemoveCallIn("UnitBuildStepPost")
	end

	local needsFeatureReclaimTracking = table.any(triggers, function(trigger)
		return trigger.type == triggerTypes.FeatureReclaimed or trigger.type == triggerTypes.FeatureDestroyed
	end)

	if not needsReclaimIncome and not needsFeatureReclaimTracking then
		gadgetHandler:RemoveCallIn("AllowFeatureBuildStep")
	end

	-- ConstructionStarted accepts some orders that assist an existing build frame.
	needsBuildPlacements = table.any(triggers, function(trigger)
		return trigger.type == triggerTypes.ConstructionStarted
	end)

	-- ConstructionFinished can't read beingBuilt at UnitFinished (always false).
	needsBuildStartSet = table.any(triggers, function(trigger)
		return trigger.type == triggerTypes.ConstructionFinished
	end)

	-- We tell apart factory and constructor ownership via the build owner map.
	needsBuildOwnerMap = table.any(triggers, function(trigger)
		return (trigger.type == triggerTypes.ConstructionCanceled or trigger.type == triggerTypes.ProductionCanceled)
			or (trigger.parameters and (trigger.parameters.builderName or trigger.parameters.builderDefName))
			or (trigger.parameters and (trigger.parameters.factoryName or trigger.parameters.factoryDefName))
	end)
end

function gadget:GameFrame(frameNumber)
	if frameNumber % Game.gameSpeed == 0 then
		-- Reset reclaim income counters (read by ResourceIncome handlers):
		teamReclaimIncomeSnapshot = teamReclaimIncome
		teamReclaimIncome = {}
	end

	dispatchTriggerCallin("GameFrame", frameNumber)

	if frameNumber % SEISMIC_INTERVAL_FRAMES == 0 then
		local n = seismicContacts.UpdateContacts(inactiveSeismicContacts)
		for i = 1, n do
			markDetectionDirty(inactiveSeismicContacts[i])
		end
	end
end

function gadget:GameFramePost(frameNumber)
	if detectionCount > 0 then
		detectionLevels.BeginUpdate()
		dispatchTriggerCallin("DetectionUpdate", detections)
		for unitID in pairs(detections) do
			detections[unitID] = nil
		end
		detectionCount = 0
	end

	if not next(buildPlacements) then
		return
	end

	for builderID, unitDefID in pairs(buildPlacements) do
		local buildeeID = Spring.GetUnitIsBuilding(builderID)
		if buildeeID and Spring.GetUnitIsBeingBuilt(buildeeID) and Spring.GetUnitDefID(buildeeID) == unitDefID then
			dispatchTriggerCallin("BuildAssisted", buildeeID, unitDefID, Spring.GetUnitTeam(buildeeID), builderID)
		end
	end

	buildPlacements = {}
end

function gadget:MetaUnitAdded(unitID, unitDefID, unitTeam)
	dispatchTriggerCallin("MetaUnitAdded", unitID, unitDefID, unitTeam)

	local unitDefName = UnitDefs[unitDefID].name
	local unitNames = table.copy(trackedUnitNames[unitID] or {})

	-- Set in spawnUnit() in loadout.lua
	local nameOfUnitBeingSpawned = GG["MissionAPI"].nameOfUnitBeingSpawned
	if nameOfUnitBeingSpawned then
		unitNames[nameOfUnitBeingSpawned] = true
	end
	statistics.Increment(triggerTypes.UnitsOwned, unitTeam, unitDefName, unitNames)
end

function gadget:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	dispatchTriggerCallin("MetaUnitRemoved", unitID, unitDefID, unitTeam)

	local unitDefName = UnitDefs[unitDefID].name
	local unitNames = trackedUnitNames[unitID] or {}
	statistics.Decrement(triggerTypes.UnitsOwned, unitTeam, unitDefName, unitNames)

	-- Don't untrack unit here, as other call-ins run after this one (UnitDestroyed, UnitTaken, ...)
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	dispatchTriggerCallin("UnitCreated", unitID, unitDefID, unitTeam, builderID)

	if builderID then
		buildPlacements[builderID] = nil
	end

	local beingBuilt = Spring.GetUnitIsBeingBuilt(unitID)
	if beingBuilt then
		if needsBuildStartSet then
			underConstruction[unitID] = true
		end
		if needsBuildOwnerMap and builderID then
			local builderDefID = Spring.GetUnitDefID(builderID)
			buildFrameOwners[unitID] =
				{ id = builderID, defID = builderDefID, isFactory = UnitDefs[builderDefID].isFactory }
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	dispatchTriggerCallin(
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
	statistics.Increment(triggerTypes.TotalUnitsLost, unitTeam, unitDefName, unitNames)

	-- The attacker's team kills an enemy unit:
	if attackerTeam and not Spring.AreTeamsAllied(attackerTeam, unitTeam) then
		statistics.Increment(triggerTypes.TotalUnitsKilled, attackerTeam, unitDefName, unitNames)
	end

	buildFrameOwners[unitID] = nil
	constructionStarts[unitID] = nil
	underConstruction[unitID] = nil

	untrackUnitID(unitID)
end

function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	dispatchTriggerCallin("UnitTaken", unitID, unitDefID, oldTeam, newTeam)

	local unitDefName = UnitDefs[unitDefID].name
	local unitNames = trackedUnitNames[unitID] or {}
	statistics.Increment(triggerTypes.TotalUnitsCaptured, newTeam, unitDefName, unitNames)
end

-- Sensor callins are relatively hot and require complicated routing.
-- They are replaced with one mark-and-sweep and an update per frame.

function gadget:UnitEnteredLos(unitID, unitTeam, losAllyTeamID, unitDefID)
	markDetectionDirty(unitID)
end

function gadget:UnitLeftLos(unitID, unitTeam, losAllyTeamID, unitDefID)
	markDetectionDirty(unitID)
end

function gadget:UnitEnteredRadar(unitID, unitTeam, radarAllyTeamID, unitDefID)
	markDetectionDirty(unitID)
end

function gadget:UnitSeismicPing(x, y, z, strength, seismicAllyTeamID, unitID, unitDefID)
	seismicContacts.RecordPing(seismicAllyTeamID, unitID)
	markDetectionDirty(unitID)
end

function gadget:UnitLeftRadar(unitID, unitTeam, radarAllyTeamID, unitDefID)
	markDetectionDirty(unitID)
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	dispatchTriggerCallin("UnitFinished", unitID, unitDefID, unitTeam)

	buildFrameOwners[unitID] = nil
	constructionStarts[unitID] = nil
	underConstruction[unitID] = nil

	-- Don't count units spawned by SpawnUnits action
	if GG["MissionAPI"].spawningUnit then
		return
	end
	-- Don't count starting commanders, initial loadout, wildlife, etc.
	if Spring.GetGameFrame() <= 0 then
		return
	end

	local unitDefName = UnitDefs[unitDefID].name
	statistics.Increment(triggerTypes.TotalUnitsBuilt, unitTeam, unitDefName)
end

function gadget:TeamDied(teamID)
	dispatchTriggerCallin("TeamDied", teamID)
end

function gadget:AllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z, facing)
	if x and needsBuildPlacements then
		buildPlacements[builderID] = unitDefID
	end
	return true
end

function gadget:AllowFeatureBuildStep(builderID, builderTeamID, featureID, featureDefID, buildStep)
	-- Negative buildStep means reclaim
	if buildStep < 0 then
		local featureDef = FeatureDefs[featureDefID]
		if not featureDef then
			return true
		end

		reclaimedFeatures[featureID] = builderTeamID

		-- Accumulate reclaim incomes - buildStep is fraction of feature's total reclaim
		local t = table.ensureTable(teamReclaimIncome, builderTeamID)
		t.metal = (t.metal or 0) + math.abs(buildStep) * featureDef.metal
		t.energy = (t.energy or 0) + math.abs(buildStep) * featureDef.energy
	end
	return true
end

local RECLAIM_UNIT_EFFICIENCY = Game.reclaimUnitEfficiency -- Engine default is 1.0 metal and 0.0 energy
local RECLAIM_UNIT_IS_BAR_STYLE = Game.reclaimUnitMethod == 1 -- From SSkirmishAICallback.h: 0 = Revert to wireframe, gradual reclaim, 1 = Subtract HP, give full metal at end, default 1
	and Game.reclaimUnitDrainHealth -- default true in engine
function gadget:AllowUnitBuildStep(builderID, builderTeamID, unitID, unitDefID, buildStep)
	if buildStep < 0 and RECLAIM_UNIT_IS_BAR_STYLE then
		local health, maxHealth, _, _, buildProgress = Spring.GetUnitHealth(unitID)
		if health and maxHealth and (health + maxHealth * buildStep) <= 0 then
			local unitDef = UnitDefs[unitDefID]
			if unitDef then
				local reclaimMetal = unitDef.metalCost * (buildProgress or 1) * RECLAIM_UNIT_EFFICIENCY

				local t = table.ensureTable(teamReclaimIncome, builderTeamID)
				t.metal = (t.metal or 0) + reclaimMetal
			end
		end
	end
	return true
end

function gadget:UnitBuildStepPost(unitID)
	dispatchTriggerCallin("UnitBuildStepPost", unitID)
end

function gadget:FeatureCreated(featureID, allyTeamID)
	local featureDefID = Spring.GetFeatureDefID(featureID)
	dispatchTriggerCallin("FeatureCreated", featureID, featureDefID)
end

function gadget:FeatureDestroyed(featureID, attackerAllyTeamID)
	local featureDefID = Spring.GetFeatureDefID(featureID)
	local _, _, _, _, reclaimLeft = Spring.GetFeatureResources(featureID)
	local reclaimerTeamID = reclaimedFeatures[featureID]

	-- FeatureReclaimed / FeatureDestroyed handlers self-guard on reclaimerTeamID + reclaimLeft.
	dispatchTriggerCallin("FeatureDestroyed", featureID, featureDefID, attackerAllyTeamID, reclaimerTeamID, reclaimLeft)

	reclaimedFeatures[featureID] = nil
	untrackFeatureID(featureID)
end
