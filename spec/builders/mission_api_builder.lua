-- Mocks GG['MissionAPI'] using the shape from api_missions.lua:Initialize().
-- Install() must be called on the result.

local PARAMETER_TYPES_PATH = "luarules/mission_api/parameter_types.lua"

---@class MissionApiMock
---@field Difficulty number
---@field trackedUnitIDs table<string, table<number, boolean>>
---@field trackedUnitNames table<number, table<string, boolean>>
---@field trackedFeatureIDs table<string, table<number, boolean>>
---@field trackedFeatureNames table<number, table<string, boolean>>
---@field markerNames table
---@field soundFiles table<string, number>
---@field soundQueue table
---@field ManagedObjectives table
---@field Countdowns table
---@field Objectives table
---@field Stages table
---@field Triggers table
---@field Actions table
---@field CurrentStageID string?
---@field UnitLoadout table
---@field FeatureLoadout table
---@field ActionDefinitions table
---@field TriggerDefinitions table
---@field Modules table
---@field ProcessTriggersOfType fun(triggerType: any, func: fun(trigger: table, triggerID: any))
---@field ActivateTrigger fun(trigger: table): boolean
---@field calls MissionApiMockCalls
---@field clearCalls fun()

--- Recorded calls, keyed by the module stub that produced them.
---@class MissionApiMockCalls
---@field spawnUnitLoadout table
---@field spawnFeatureLoadout table
---@field convertOrdersTargetingNames table
---@field playSound table
---@field enqueueSound table
---@field processSoundQueue table
---@field changeStage table
---@field tryAdvanceStage table
---@field onObjectiveCompleted table
---@field updateObjectiveProgress table
---@field echoObjectiveUpdate table
---@field activateTrigger table

---@class MissionApiBuilder
local MB = {}
MB.__index = MB

local function ensureTable(tbl, key)
	local value = tbl[key]
	if value == nil then
		value = {}
		tbl[key] = value
	end
	return value
end

local function isNilOrEmpty(tbl)
	return tbl == nil or next(tbl) == nil
end

---@return MissionApiBuilder
function MB.new()
	return setmetatable({
		difficulty = 0,
		trackedUnits = {}, -- array of { name, id }
		trackedFeatures = {}, -- array of { name, id }
		markerNames = {},
		soundFiles = {},
		soundQueue = {},
		managedObjectives = {},
		countdowns = {},
		objectives = {},
		stages = {},
		triggers = {},
		actions = {},
		unitLoadout = {},
		featureLoadout = {},
		actionDefinitions = {},
		triggerDefinitions = {},
		currentStageID = nil,
		moduleOverrides = {},
		realParameterTypes = true,
	}, MB)
end

---@param self MissionApiBuilder
---@param difficulty number
---@return MissionApiBuilder
function MB:WithDifficulty(difficulty)
	self.difficulty = difficulty
	return self
end

---Seed a tracked unit; bidirectional maps are built for you.
---@param self MissionApiBuilder
---@param name string
---@param unitID number
---@return MissionApiBuilder
function MB:WithTrackedUnit(name, unitID)
	self.trackedUnits[#self.trackedUnits + 1] = { name = name, id = unitID }
	return self
end

---@param self MissionApiBuilder
---@param name string
---@param featureID number
---@return MissionApiBuilder
function MB:WithTrackedFeature(name, featureID)
	self.trackedFeatures[#self.trackedFeatures + 1] = { name = name, id = featureID }
	return self
end

---@param self MissionApiBuilder
---@param name string
---@param position table
---@return MissionApiBuilder
function MB:WithMarker(name, position)
	self.markerNames[name] = position or true
	return self
end

---@param self MissionApiBuilder
---@param objectiveID string
---@param objective table
---@return MissionApiBuilder
function MB:WithObjective(objectiveID, objective)
	self.objectives[objectiveID] = objective or {}
	return self
end

---@param self MissionApiBuilder
---@param stageID string
---@param stage table
---@return MissionApiBuilder
function MB:WithStage(stageID, stage)
	self.stages[stageID] = stage or { objectives = {} }
	return self
end

---@param self MissionApiBuilder
---@param stageID string
---@return MissionApiBuilder
function MB:WithCurrentStage(stageID)
	self.currentStageID = stageID
	return self
end

---@param self MissionApiBuilder
---@param triggerID string
---@param trigger table
---@return MissionApiBuilder
function MB:WithTrigger(triggerID, trigger)
	self.triggers[triggerID] = trigger or {}
	return self
end

---@param self MissionApiBuilder
---@param actionID string
---@param action table
---@return MissionApiBuilder
function MB:WithAction(actionID, action)
	self.actions[actionID] = action or {}
	return self
end

---@param self MissionApiBuilder
---@param objectiveID string
---@param metadata table
---@return MissionApiBuilder
function MB:WithManagedObjective(objectiveID, metadata)
	self.managedObjectives[objectiveID] = metadata or {}
	return self
end

---Seed a countdown, shaped as countdowns.lua AddCountdown() creates them.
---@param self MissionApiBuilder
---@param countdownID string
---@param countdown table?
---@return MissionApiBuilder
function MB:WithCountdown(countdownID, countdown)
	self.countdowns[countdownID] = countdown or { id = countdownID, timeRemaining = 0, paused = false }
	return self
end

---@param self MissionApiBuilder
---@param soundfile string
---@param duration number
---@return MissionApiBuilder
function MB:WithSoundFile(soundfile, duration)
	self.soundFiles[soundfile] = duration or 0
	return self
end

---@param self MissionApiBuilder
---@param loadout table
---@return MissionApiBuilder
function MB:WithUnitLoadout(loadout)
	self.unitLoadout = loadout or {}
	return self
end

---@param self MissionApiBuilder
---@param loadout table
---@return MissionApiBuilder
function MB:WithFeatureLoadout(loadout)
	self.featureLoadout = loadout or {}
	return self
end

---@param self MissionApiBuilder
---@param definitions table
---@return MissionApiBuilder
function MB:WithActionDefinitions(definitions)
	self.actionDefinitions = definitions or {}
	return self
end

---@param self MissionApiBuilder
---@param definitions table
---@return MissionApiBuilder
function MB:WithTriggerDefinitions(definitions)
	self.triggerDefinitions = definitions or {}
	return self
end

---Replace a whole module, or merge individual functions into it.
---@param self MissionApiBuilder
---@param moduleName string e.g. 'Loadout', 'Sounds', 'Objectives', 'Tracking'
---@param moduleTable table
---@return MissionApiBuilder
function MB:WithModule(moduleName, moduleTable)
	local override = ensureTable(self.moduleOverrides, moduleName)
	for key, value in pairs(moduleTable or {}) do
		override[key] = value
	end
	return self
end

---Leave Modules.ParameterTypes unset instead of loading the real module.
---@param self MissionApiBuilder
---@return MissionApiBuilder
function MB:WithoutParameterTypes()
	self.realParameterTypes = false
	return self
end

---@param self MissionApiBuilder
---@return MissionApiMock
function MB:Build()
	local instance = self

	local trackedUnitIDs = {}
	local trackedUnitNames = {}
	local trackedFeatureIDs = {}
	local trackedFeatureNames = {}

	-- Mirrors luarules/mission_api/tracking.lua
	local function trackEntity(name, ID, trackedIDs, trackedNames)
		if not name or not ID then
			return
		end
		ensureTable(trackedIDs, name)
		ensureTable(trackedNames, ID)
		trackedIDs[name][ID] = true
		trackedNames[ID][name] = true
	end

	local function untrackID(ID, trackedIDs, trackedNames)
		if isNilOrEmpty(trackedNames[ID]) then
			return
		end
		for name in pairs(trackedNames[ID]) do
			trackedIDs[name][ID] = nil
			if next(trackedIDs[name]) == nil then
				trackedIDs[name] = nil
			end
		end
		trackedNames[ID] = nil
	end

	local function untrackName(name, trackedIDs, trackedNames)
		if isNilOrEmpty(trackedIDs[name]) then
			return
		end
		for ID in pairs(trackedIDs[name]) do
			trackedNames[ID][name] = nil
			if next(trackedNames[ID]) == nil then
				trackedNames[ID] = nil
			end
		end
		trackedIDs[name] = nil
	end

	for _, entry in ipairs(instance.trackedUnits) do
		trackEntity(entry.name, entry.id, trackedUnitIDs, trackedUnitNames)
	end
	for _, entry in ipairs(instance.trackedFeatures) do
		trackEntity(entry.name, entry.id, trackedFeatureIDs, trackedFeatureNames)
	end

	local spawnUnitCalls = {}
	local spawnFeatureCalls = {}
	local convertOrdersCalls = {}
	local playSoundCalls = {}
	local enqueueSoundCalls = {}
	local processSoundQueueCalls = {}
	local changeStageCalls = {}
	local tryAdvanceCalls = {}
	local onObjectiveCompletedCalls = {}
	local updateProgressCalls = {}
	local echoCalls = {}
	local activateTriggerCalls = {}

	local tracking = {
		TrackUnit = function(name, unitID)
			trackEntity(name, unitID, trackedUnitIDs, trackedUnitNames)
		end,
		IsUnitIDUntracked = function(unitID)
			return isNilOrEmpty(trackedUnitNames[unitID])
		end,
		IsUnitNameUntracked = function(name)
			return isNilOrEmpty(trackedUnitIDs[name])
		end,
		DoesUnitHaveName = function(unitID, name)
			return (trackedUnitIDs[name] or {})[unitID] == true
		end,
		UntrackUnitID = function(unitID)
			untrackID(unitID, trackedUnitIDs, trackedUnitNames)
		end,
		UntrackUnitName = function(name)
			untrackName(name, trackedUnitIDs, trackedUnitNames)
		end,
		TrackFeature = function(name, featureID)
			trackEntity(name, featureID, trackedFeatureIDs, trackedFeatureNames)
		end,
		IsFeatureIDUntracked = function(featureID)
			return isNilOrEmpty(trackedFeatureNames[featureID])
		end,
		IsFeatureNameUntracked = function(name)
			return isNilOrEmpty(trackedFeatureIDs[name])
		end,
		DoesFeatureHaveName = function(featureID, name)
			return (trackedFeatureIDs[name] or {})[featureID] == true
		end,
		UntrackFeatureID = function(featureID)
			untrackID(featureID, trackedFeatureIDs, trackedFeatureNames)
		end,
		UntrackFeatureName = function(name)
			untrackName(name, trackedFeatureIDs, trackedFeatureNames)
		end,
	}

	local loadout = {
		-- Identity by default, matching the no-op conversion case.
		ConvertOrdersTargetingNames = function(orders)
			convertOrdersCalls[#convertOrdersCalls + 1] = { orders = orders }
			return orders
		end,
		SpawnUnitLoadout = function(unitLoadout)
			spawnUnitCalls[#spawnUnitCalls + 1] = { loadout = unitLoadout }
		end,
		SpawnFeatureLoadout = function(featureLoadout)
			spawnFeatureCalls[#spawnFeatureCalls + 1] = { loadout = featureLoadout }
		end,
	}

	local sounds = {
		PlaySound = function(soundfile, volume, position)
			playSoundCalls[#playSoundCalls + 1] = { soundfile = soundfile, volume = volume, position = position }
		end,
		EnqueueSound = function(soundfile, volume, position)
			enqueueSoundCalls[#enqueueSoundCalls + 1] = { soundfile = soundfile, volume = volume, position = position }
		end,
		ProcessSoundQueue = function(frameNumber)
			processSoundQueueCalls[#processSoundQueueCalls + 1] = { frame = frameNumber }
		end,
	}

	local objectives = {
		ChangeStage = function(stageID)
			changeStageCalls[#changeStageCalls + 1] = { stageID = stageID }
		end,
		TryAdvanceStage = function(objective)
			tryAdvanceCalls[#tryAdvanceCalls + 1] = { objective = objective }
		end,
		OnObjectiveCompleted = function(objectiveID, objective)
			onObjectiveCompletedCalls[#onObjectiveCompletedCalls + 1] =
				{ objectiveID = objectiveID, objective = objective }
		end,
		UpdateObjectiveProgress = function(
			objectiveID,
			eventTeamID,
			eventUnitDefName,
			eventUnitNames,
			direction,
			managedObjMetadata
		)
			updateProgressCalls[#updateProgressCalls + 1] = {
				objectiveID = objectiveID,
				teamID = eventTeamID,
				unitDefName = eventUnitDefName,
				unitNames = eventUnitNames,
				direction = direction,
				metadata = managedObjMetadata,
			}
		end,
		EchoObjectiveUpdate = function(objectiveID, objective)
			echoCalls[#echoCalls + 1] = { objectiveID = objectiveID, objective = objective }
		end,
	}

	local modules = {
		Tracking = tracking,
		Loadout = loadout,
		Sounds = sounds,
		Objectives = objectives,
	}

	if instance.realParameterTypes then
		modules.ParameterTypes = VFS.Include(PARAMETER_TYPES_PATH)
	end

	for moduleName, override in pairs(instance.moduleOverrides) do
		local target = ensureTable(modules, moduleName)
		for key, value in pairs(override) do
			target[key] = value
		end
	end

	---@type MissionApiMock
	local mock = {
		Difficulty = instance.difficulty,
		trackedUnitIDs = trackedUnitIDs,
		trackedUnitNames = trackedUnitNames,
		trackedFeatureIDs = trackedFeatureIDs,
		trackedFeatureNames = trackedFeatureNames,
		markerNames = instance.markerNames,
		soundFiles = instance.soundFiles,
		soundQueue = instance.soundQueue,
		ManagedObjectives = instance.managedObjectives,
		Countdowns = instance.countdowns,
		Objectives = instance.objectives,
		Stages = instance.stages,
		Triggers = instance.triggers,
		Actions = instance.actions,
		CurrentStageID = instance.currentStageID,
		UnitLoadout = instance.unitLoadout,
		FeatureLoadout = instance.featureLoadout,
		ActionDefinitions = instance.actionDefinitions,
		TriggerDefinitions = instance.triggerDefinitions,
		Modules = modules,
		--- Published by api_missions_triggers.lua:Initialize() for objectives.lua.
		--- Both read GG['MissionAPI'] at call time, as the gadget's functions do;
		--- an activation records the stage that was current when it happened.
		ProcessTriggersOfType = function(triggerType, func)
			for triggerID, trigger in pairs(GG["MissionAPI"].Triggers) do
				if trigger.type == triggerType then
					func(trigger, triggerID)
				end
			end
		end,
		ActivateTrigger = function(trigger)
			activateTriggerCalls[#activateTriggerCalls + 1] =
				{ trigger = trigger, stageID = GG["MissionAPI"].CurrentStageID }
			return true
		end,
		--- Recorded module calls, keyed by the stub they came from:
		--- `calls.playSound` records `Modules.Sounds.PlaySound`.
		calls = {
			spawnUnitLoadout = spawnUnitCalls,
			spawnFeatureLoadout = spawnFeatureCalls,
			convertOrdersTargetingNames = convertOrdersCalls,
			playSound = playSoundCalls,
			enqueueSound = enqueueSoundCalls,
			processSoundQueue = processSoundQueueCalls,
			changeStage = changeStageCalls,
			tryAdvanceStage = tryAdvanceCalls,
			onObjectiveCompleted = onObjectiveCompletedCalls,
			updateObjectiveProgress = updateProgressCalls,
			echoObjectiveUpdate = echoCalls,
			activateTrigger = activateTriggerCalls,
		},
		clearCalls = function()
			local tracked = {
				spawnUnitCalls,
				spawnFeatureCalls,
				convertOrdersCalls,
				playSoundCalls,
				enqueueSoundCalls,
				processSoundQueueCalls,
				changeStageCalls,
				tryAdvanceCalls,
				onObjectiveCompletedCalls,
				updateProgressCalls,
				echoCalls,
				activateTriggerCalls,
			}
			for i = 1, #tracked do
				local list = tracked[i]
				for j = #list, 1, -1 do
					list[j] = nil
				end
			end
		end,
	}

	return mock
end

---The single table Install() writes into, so references captured once stay
---valid even if another spec replaces GG['MissionAPI'] with its own table.
local installedTable = nil

---Build the mock and install it as GG['MissionAPI'].
---@param self MissionApiBuilder
---@return MissionApiMock
function MB:Install()
	local mock = self:Build()

	_G.GG = _G.GG or {}

	local target = installedTable
	if type(target) ~= "table" then
		target = {}
		installedTable = target
	else
		for key in pairs(target) do
			target[key] = nil
		end
	end

	for key, value in pairs(mock) do
		target[key] = value
	end

	_G.GG["MissionAPI"] = target
	return target
end

-- Bootstrap a default, so action/trigger files can be included with no setup.
if type(_G.GG) ~= "table" or type(_G.GG["MissionAPI"]) ~= "table" then
	MB.new():Install()
end

return MB
