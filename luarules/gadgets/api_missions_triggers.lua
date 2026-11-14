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

local RECLAIM_UNIT_EFFICIENCY = Game.reclaimUnitEfficiency -- Engine default is 1.0 metal and 0.0 energy.
local INCOME_ON_FULL_UNIT_RECLAIM = true
	and Game.reclaimUnitMethod == 1 -- ModInfo.h: 0 = Revert to wireframe and gradual reclaim, 1 = Subtract HP and give full metal at end, default 1
	and Game.reclaimUnitDrainHealth -- ModInfo.h: Does wireframe reclaim drain health? default true

local triggerTypes, triggers, triggerContext ---@type table, table<string, table>, table

local callins ---@type table
local unitsEnteredAreaHandlers ---@type table<string, function?>
local unitsLeftAreaHandlers ---@type table<string, function?>
local needsBuildOwnerMap = false
local needsBuildStartSet = false

local actionsDispatcher
local statistics
local countdowns
local detectionLevels
local seismicContacts
local seismicIntervalFrames ---@type integer

local trackedUnitNames
local doesUnitHaveName
local untrackUnitID
local doesFeatureHaveName
local untrackFeatureID

-- Shared trigger state (exposed to per-trigger handlers via triggerContext):
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
local undetected = {}
local capturedUnits = {}

----------------------------------------------------------------
--- Trigger Functions:
----------------------------------------------------------------

local function processTriggersOfType(triggerType, func)
	for triggerID, trigger in pairs(triggers) do
		if trigger.type == triggerType then
			func(trigger, triggerID)
		end
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

	if next(settings.stages) and not table.contains(settings.stages, GG["MissionAPI"].CurrentStageID) then
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

-- Location triggers are dispatched through area tracking instead of by polling with GameFrame.
-- Each has its own tracker. Callbacks then act on the units that crossed a tracking boundary.

---@param triggerID string
local function onUnitsEnteredArea(unitIDs, triggerID)
	local trigger = triggers[triggerID]
	local handler = unitsEnteredAreaHandlers[trigger.type]
	if handler then
		handler(trigger, triggerID, triggerContext, unitIDs)
	end
end

---@param triggerID string
local function onUnitsLeftArea(unitIDs, triggerID)
	local trigger = triggers[triggerID]
	local handler = unitsLeftAreaHandlers[trigger.type]
	if handler then
		handler(trigger, triggerID, triggerContext, unitIDs)
	end
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

-- Attempt at single-assigning a construction task owner to each buildee.
-- When multiple constructors place the same buildDefID, any can become an
-- "owner" in some technical sense, since only factories own build frames.
local function isBuildFrameOwner(buildeeID, builderName, builderDefName)
	if not builderName and not builderDefName then
		return true
	end
	local builder = buildFrameOwners[buildeeID]
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
--- Call-ins:
----------------------------------------------------------------

function gadget:GameStart()
	dispatchTriggerCallin("GameStart")
end

function gadget:GameFrame(frameNumber)
	if frameNumber % Game.gameSpeed == 0 then
		-- Reset reclaim income counters (read by ResourceIncome handlers):
		teamReclaimIncomeSnapshot = teamReclaimIncome
		teamReclaimIncome = {}
	end

	-- Displayed countdowns tick together on whole seconds, non-displayed ones
	-- relative to their creation frame (see Decrement() in countdowns.lua):
	local endedCountdownIDs, countdownTicks = countdowns.Decrement(frameNumber)
	for i = 1, #countdownTicks do
		dispatchTriggerCallin("CountdownTick", countdownTicks[i].id, countdownTicks[i].timeRemaining)
	end
	for i = 1, #endedCountdownIDs do
		dispatchTriggerCallin("CountdownEnded", endedCountdownIDs[i])
	end

	dispatchTriggerCallin("GameFrame", frameNumber)

	if frameNumber % seismicIntervalFrames == 0 then
		local n = seismicContacts.UpdateContacts(undetected)
		for i = 1, n do
			markDetectionDirty(undetected[i])
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

	if next(buildPlacements) ~= nil then
		for builderID, unitDefID in pairs(buildPlacements) do
			local buildeeID = Spring.GetUnitIsBuilding(builderID)
			if buildeeID and Spring.GetUnitIsBeingBuilt(buildeeID) and Spring.GetUnitDefID(buildeeID) == unitDefID then
				dispatchTriggerCallin("BuildAssisted", buildeeID, unitDefID, Spring.GetUnitTeam(buildeeID), builderID)
			end
		end
		buildPlacements = {}
	end
end

function gadget:TeamDied(teamID)
	dispatchTriggerCallin("TeamDied", teamID)
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

-- AllowUnitTransfer can tell captured units from shared ones; UnitGiven, UnitTaken cannot.
function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
	capturedUnits[unitID] = capture or nil
	return true
end

function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	dispatchTriggerCallin("UnitTaken", unitID, unitDefID, oldTeam, newTeam, capturedUnits[unitID] == true)

	local unitDefName = UnitDefs[unitDefID].name
	local unitNames = trackedUnitNames[unitID] or {}
	statistics.Increment(triggerTypes.TotalUnitsCaptured, newTeam, unitDefName, unitNames)
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	dispatchTriggerCallin("UnitGiven", unitID, unitDefID, newTeam, oldTeam, capturedUnits[unitID] == true)
	capturedUnits[unitID] = nil
end

function gadget:AllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z, facing)
	if x then
		buildPlacements[builderID] = unitDefID
	end
	return true
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	dispatchTriggerCallin("UnitCreated", unitID, unitDefID, unitTeam, builderID)

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
	dispatchTriggerCallin("UnitBuildStepPost", unitID)
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	dispatchTriggerCallin("UnitFinished", unitID, unitDefID, unitTeam)

	buildFrameOwners[unitID] = nil
	constructionStarts[unitID] = nil
	wasUnderConstruction[unitID] = nil

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
	wasUnderConstruction[unitID] = nil

	-- TODO: Will become a general method for informing presentation layer that a unit is gone.
	GG["MissionAPI"].Modules.UnitMarkers.RemoveUnitMarkers(unitID)
	untrackUnitID(unitID)
end

function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
	dispatchTriggerCallin("UnitCommand", unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
end

function gadget:UnitIdlePost(unitID, idled)
	dispatchTriggerCallin("UnitIdlePost", unitID, idled)
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
	dispatchTriggerCallin("UnitLoaded", unitID, unitDefID, unitTeam, transportID, transportDefID, transportTeam)
end

function gadget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	local transportDefID = Spring.GetUnitDefID(transportID)
	dispatchTriggerCallin("UnitUnloaded", unitID, unitDefID, unitTeam, transportID, transportDefID, transportTeam)
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
	dispatchTriggerCallin(
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
	dispatchTriggerCallin("StockpileChanged", unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount)
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

function gadget:Initialize()
	if not Spring.GetGameRulesParam("inMission") then
		gadgetHandler:RemoveGadget()
		return
	end

	triggerTypes = GG["MissionAPI"].TriggerDefinitions.Types
	callins = GG["MissionAPI"].TriggerDefinitions.Callins
	triggers = GG["MissionAPI"].Triggers
	trackedUnitNames = GG["MissionAPI"].trackedUnitNames

	actionsDispatcher = VFS.Include("luarules/mission_api/actions_dispatcher.lua")

	seismicContacts = GG["MissionAPI"].Modules.SeismicContacts
	seismicIntervalFrames = seismicContacts.UpdateInterval
	detectionLevels = GG["MissionAPI"].Modules.DetectionLevels
	countdowns = GG["MissionAPI"].Modules.Countdowns

	statistics = VFS.Include("luarules/mission_api/statistics.lua")
	statistics.Init({ processTriggersOfType = processTriggersOfType, activateTrigger = activateTrigger })
	-- TODO: Resolve flat globals vs imports vs the DI pattern (above).
	GG["MissionAPI"].ActivateTrigger = activateTrigger

	local tracking = GG["MissionAPI"].Modules.Tracking
	doesUnitHaveName = tracking.DoesUnitHaveName
	untrackUnitID = tracking.UntrackUnitID
	doesFeatureHaveName = tracking.DoesFeatureHaveName
	untrackFeatureID = tracking.UntrackFeatureID

	triggerContext = {
		ActivateTrigger = activateTrigger,
		DoesUnitHaveName = doesUnitHaveName,
		DoesUnitMatch = GG["MissionAPI"].Modules.UnitQuery.DoesUnitMatch,
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

	local hasTriggerType = {}
	for _, typeID in pairs(triggerTypes) do
		hasTriggerType[typeID] = false
	end
	for _, trigger in pairs(triggers) do
		hasTriggerType[trigger.type] = true
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
		or hasTriggerType[triggerTypes.ConstructionCanceled]
		or hasTriggerType[triggerTypes.ProductionCanceled]
	needsBuildStartSet = hasTriggerType[triggerTypes.ConstructionFinished]

	-- Check support for hot callins. These tend to be heavy in bursts not on average.
	-- Only remain subscribed to these when the loaded mission actually requires them.
	for callinName, needed in pairs({
		AllowUnitCreation = hasTriggerType[triggerTypes.ConstructionStarted],
		AllowUnitBuildStep = hasTriggerType[triggerTypes.ResourceIncome] and INCOME_ON_FULL_UNIT_RECLAIM,
		AllowFeatureBuildStep = hasTriggerType[triggerTypes.ResourceIncome]
			or hasTriggerType[triggerTypes.FeatureReclaimed]
			or hasTriggerType[triggerTypes.FeatureDestroyed],
		UnitBuildStepPost = hasTriggerType[triggerTypes.ConstructionProgress],
		UnitDamaged = hasTriggerType[triggerTypes.UnitAttacked],
		StockpileChanged = hasTriggerType[triggerTypes.StockpileCount]
			or hasTriggerType[triggerTypes.StockpileProgress],
	}) do
		if not needed then
			gadgetHandler:RemoveCallIn(callinName)
		end
	end
end
