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
	-- UNSYNCED
	-- Mirror of the synced untargetable state, used to suppress the attack
	-- cursor when hovering a unit made untargetable by the Unit Targetable
	-- action (the order itself is refused in synced AllowCommand).
	local CMD_ATTACK = CMD.ATTACK
	local CMD_MANUALFIRE = CMD.MANUALFIRE
	local CMD_MOVE = CMD.MOVE

	local untargetableUnitIDs = {}
	local untargetableCount = 0

	local function handleUnitTargetableEvent(_, unitID, untargetable)
		if untargetable then
			if not untargetableUnitIDs[unitID] then
				untargetableUnitIDs[unitID] = true
				untargetableCount = untargetableCount + 1
			end
		elseif untargetableUnitIDs[unitID] then
			untargetableUnitIDs[unitID] = nil
			untargetableCount = untargetableCount - 1
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction('MissionAPI_UnitTargetable', handleUnitTargetableEvent)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction('MissionAPI_UnitTargetable')
	end

	function gadget:DefaultCommand(type, id, cmd)
		if
			untargetableCount > 0
			and type == 'unit'
			and untargetableUnitIDs[id]
			and (cmd == CMD_ATTACK or cmd == CMD_MANUALFIRE)
		then
			return CMD_MOVE
		end
	end

	return true
end

local actionsDispatcher
local triggerTypes, triggers, callins, triggerContext
local trackedUnitNames
local untargetableUnitIDs = {}
local untargetableCount = 0
local statistics

-- Shared trigger state (exposed to per-trigger handlers via triggerContext):
local previousUnitsInAreas      = {}
local dwellingUnitsInAreas      = {}
local teamReclaimIncome         = {}
local teamReclaimIncomeSnapshot = {}
local reclaimedFeatures         = {}


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

	if next(trigger.settings.stages) and not table.contains(trigger.settings.stages, GG['MissionAPI'].CurrentStageID) then return false end

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

local function isFeatureInArea(featureID, area)
	local featureX, _, featureZ = Spring.GetFeaturePosition(featureID)
	return math.isPointInArea(featureX, featureZ, area)
end

----------------------------------------------------------------
--- Unit Targetable:
----------------------------------------------------------------

-- Purge queued attack orders aimed at a unit that just became untargetable
-- (new ones are refused in AllowCommand).
local function removeAttackOrdersTargeting(targetID)
	for _, attackerID in ipairs(Spring.GetAllUnits()) do
		if Spring.GetUnitCommandCount(attackerID) > 0 then
			local commands = Spring.GetUnitCommands(attackerID, -1)
			local removeTags = {}
			for i = 1, #commands do
				local command = commands[i]
				if (command.id == CMD.ATTACK or command.id == CMD.MANUALFIRE)
					and command.params[2] == nil
					and command.params[1] == targetID
				then
					removeTags[#removeTags + 1] = command.tag
				end
			end
			if #removeTags > 0 then
				Spring.GiveOrderToUnit(attackerID, CMD.REMOVE, removeTags, 0)
			end
		end
	end
end

-- Central switch behind the Unit Targetable action (exposed on GG['MissionAPI']
-- in Initialize). AllowWeaponTarget is checked per candidate in every weapon
-- and CAI target search, so it only stays subscribed while at least one unit
-- is untargetable. The state is also mirrored to unsynced to suppress the
-- attack cursor on hover.
local function setUnitTargetable(unitID, targetable)
	if not unitID then return end

	local untargetable = not targetable and true or nil
	if untargetableUnitIDs[unitID] == untargetable then return end

	untargetableUnitIDs[unitID] = untargetable
	untargetableCount = untargetableCount + (untargetable and 1 or -1)

	if untargetable then
		removeAttackOrdersTargeting(unitID)
		if untargetableCount == 1 then
			gadgetHandler:UpdateCallIn('AllowWeaponTarget')
		end
	elseif untargetableCount == 0 then
		gadgetHandler:RemoveCallIn('AllowWeaponTarget')
	end

	SendToUnsynced('MissionAPI_UnitTargetable', unitID, not targetable)
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


----------------------------------------------------------------
--- Call-ins:
----------------------------------------------------------------

function gadget:Initialize()
	-- Register before the MissionAPI check: RemoveGadget is deferred, and a
	-- gadget defining AllowCommand without registrations gets auto-registered
	-- for ALL commands by the gadget handler.
	gadgetHandler:RegisterAllowCommand(CMD.ATTACK)
	gadgetHandler:RegisterAllowCommand(CMD.MANUALFIRE)

	if not GG['MissionAPI'] then
		gadgetHandler:RemoveGadget()
		return
	end

	triggerTypes            = GG['MissionAPI'].TriggerDefinitions.Types
	callins                 = GG['MissionAPI'].TriggerDefinitions.Callins
	triggers                = GG['MissionAPI'].Triggers
	trackedUnitNames        = GG['MissionAPI'].trackedUnitNames
	untargetableUnitIDs     = GG['MissionAPI'].untargetableUnitIDs

	GG['MissionAPI'].SetUnitTargetable = setUnitTargetable

	actionsDispatcher       = VFS.Include('luarules/mission_api/actions_dispatcher.lua')

	statistics              = VFS.Include('luarules/mission_api/statistics.lua')
	statistics.Init({ processTriggersOfType = processTriggersOfType, activateTrigger = activateTrigger })

	local tracking          = GG['MissionAPI'].Modules.Tracking
	doesUnitHaveName        = tracking.DoesUnitHaveName
	untrackUnitID           = tracking.UntrackUnitID
	doesFeatureHaveName     = tracking.DoesFeatureHaveName
	untrackFeatureID        = tracking.UntrackFeatureID

	triggerContext = {
		ActivateTrigger          = activateTrigger,
		DoesUnitHaveName         = doesUnitHaveName,
		DoesFeatureHaveName      = doesFeatureHaveName,
		GetUnitsInArea           = getUnitsInArea,
		IsFeatureInArea          = isFeatureInArea,
		PreviousUnitsInAreas     = previousUnitsInAreas,
		DwellingUnitsInAreas     = dwellingUnitsInAreas,
		GetReclaimIncomeSnapshot = function(teamID) return teamReclaimIncomeSnapshot[teamID] end,
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
		gadgetHandler:RemoveCallIn('AllowUnitBuildStep')
	end

	local needsFeatureReclaimTracking = table.any(triggers, function(trigger)
		return trigger.type == triggerTypes.FeatureReclaimed
			or trigger.type == triggerTypes.FeatureDestroyed
	end)

	if not needsReclaimIncome and not needsFeatureReclaimTracking then
		gadgetHandler:RemoveCallIn('AllowFeatureBuildStep')
	end

	-- AllowWeaponTarget is checked per candidate in every weapon and CAI target
	-- search, so only stay subscribed while some unit is actually untargetable
	-- (toggled in setUnitTargetable):
	gadgetHandler:RemoveCallIn('AllowWeaponTarget')
end

function gadget:GameFrame(frameNumber)
	if frameNumber % Game.gameSpeed == 0 then
		-- Reset reclaim income counters (read by ResourceIncome handlers):
		teamReclaimIncomeSnapshot = teamReclaimIncome
		teamReclaimIncome = {}
	end

	dispatchTriggerCallin('GameFrame', frameNumber)
end

function gadget:MetaUnitAdded(unitID, unitDefID, unitTeam)
	dispatchTriggerCallin('MetaUnitAdded', unitID, unitDefID, unitTeam)

	local unitDefName = UnitDefs[unitDefID].name
	local unitNames = table.copy(trackedUnitNames[unitID] or {})

	-- Set in spawnUnit() in loadout.lua
	local nameOfUnitBeingSpawned = GG['MissionAPI'].nameOfUnitBeingSpawned
	if nameOfUnitBeingSpawned then
		unitNames[nameOfUnitBeingSpawned] = true
	end
	statistics.Increment(triggerTypes.UnitsOwned, unitTeam, unitDefName, unitNames)
end

function gadget:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	dispatchTriggerCallin('MetaUnitRemoved', unitID, unitDefID, unitTeam)

	local unitDefName = UnitDefs[unitDefID].name
	local unitNames = trackedUnitNames[unitID] or {}
	statistics.Decrement(triggerTypes.UnitsOwned, unitTeam, unitDefName, unitNames)

	-- Don't untrack unit here, as other call-ins run after this one (UnitDestroyed, UnitTaken, ...)
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	dispatchTriggerCallin('UnitCreated', unitID, unitDefID, unitTeam, builderID)
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	dispatchTriggerCallin('UnitDestroyed', unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)

	local unitDefName = UnitDefs[unitDefID].name
	local unitNames = trackedUnitNames[unitID] or {}

	-- The unit's team lost a unit:
	statistics.Increment(triggerTypes.TotalUnitsLost, unitTeam, unitDefName, unitNames)

	-- The attacker's team kills an enemy unit:
	if attackerTeam and not Spring.AreTeamsAllied(attackerTeam, unitTeam) then
		statistics.Increment(triggerTypes.TotalUnitsKilled, attackerTeam, unitDefName, unitNames)
	end

	if untargetableUnitIDs[unitID] then
		setUnitTargetable(unitID, true)
	end

	untrackUnitID(unitID)
end

function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	dispatchTriggerCallin('UnitTaken', unitID, unitDefID, oldTeam, newTeam)

	local unitDefName = UnitDefs[unitDefID].name
	local unitNames = trackedUnitNames[unitID] or {}
	statistics.Increment(triggerTypes.TotalUnitsCaptured, newTeam, unitDefName, unitNames)
end

function gadget:UnitEnteredLos(unitID, unitTeam, losAllyTeamID, unitDefID)
	dispatchTriggerCallin('UnitEnteredLos', unitID, unitTeam, losAllyTeamID, unitDefID)
end

function gadget:UnitLeftLos(unitID, unitTeam, losAllyTeamID, unitDefID)
	dispatchTriggerCallin('UnitLeftLos', unitID, unitTeam, losAllyTeamID, unitDefID)
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	dispatchTriggerCallin('UnitFinished', unitID, unitDefID, unitTeam)

	-- Don't count units spawned by SpawnUnits action
	if GG['MissionAPI'].spawningUnit then return end
	-- Don't count starting commanders, initial loadout, wildlife, etc.
	if Spring.GetGameFrame() <= 0 then return end

	local unitDefName = UnitDefs[unitDefID].name
	statistics.Increment(triggerTypes.TotalUnitsBuilt, unitTeam, unitDefName)
end

function gadget:TeamDied(teamID)
	dispatchTriggerCallin('TeamDied', teamID)
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
		t.metal  = (t.metal  or 0) + math.abs(buildStep) * featureDef.metal
		t.energy = (t.energy or 0) + math.abs(buildStep) * featureDef.energy
	end
	return true
end

local RECLAIM_UNIT_EFFICIENCY = Game.reclaimUnitEfficiency -- Engine default is 1.0 metal and 0.0 energy
local RECLAIM_UNIT_IS_BAR_STYLE =
	Game.reclaimUnitMethod == 1 and                        -- From SSkirmishAICallback.h: 0 = Revert to wireframe, gradual reclaim, 1 = Subtract HP, give full metal at end, default 1
	Game.reclaimUnitDrainHealth                            -- default true in engine
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

-- Only subscribed while some unit is untargetable (see setUnitTargetable).
function gadget:AllowWeaponTarget(attackerID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority)
	if untargetableUnitIDs[targetID] then
		return false, defPriority
	end

	return true, defPriority
end

-- Registered for CMD.ATTACK and CMD.MANUALFIRE (see Initialize). Refuses
-- unit-targeted orders (single param) on untargetable units; ground and area
-- attacks stay allowed, as area target selection already goes through
-- AllowWeaponTarget engine-side.
function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if cmdParams[2] == nil and untargetableUnitIDs[cmdParams[1]] then
		return false
	end

	return true
end

function gadget:FeatureCreated(featureID, allyTeamID)
	local featureDefID = Spring.GetFeatureDefID(featureID)
	dispatchTriggerCallin('FeatureCreated', featureID, featureDefID)
end

function gadget:FeatureDestroyed(featureID, attackerAllyTeamID)
	local featureDefID = Spring.GetFeatureDefID(featureID)
	local _, _, _, _, reclaimLeft = Spring.GetFeatureResources(featureID)
	local reclaimerTeamID = reclaimedFeatures[featureID]

	-- FeatureReclaimed / FeatureDestroyed handlers self-guard on reclaimerTeamID + reclaimLeft.
	dispatchTriggerCallin('FeatureDestroyed', featureID, featureDefID, attackerAllyTeamID, reclaimerTeamID, reclaimLeft)

	reclaimedFeatures[featureID] = nil
	untrackFeatureID(featureID)
end
