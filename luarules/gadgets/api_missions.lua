local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Mission API loader",
		desc = "Load and populate global mission table",
		date = "2023.03.14",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local objectivesController, stagesController, triggersController, actionsController

-- Used in GameFrame.
local missionValidationFailure

-- Runs on the raw mission data
local function validateMission(mission)
	local validation = VFS.Include("luarules/mission_api/validation.lua")
	local result = validation.ValidateMission(mission)
	validation.LogResult(result)

	return result
end

local function loadMission(gameSetup)
	local mission = VFS.Include(gameSetup.entryPoint)
	local validationResult = validateMission(mission)

	if not validationResult.ok then
		GG["MissionAPI"] = nil -- stops gadget api_missions_triggers from loading
		missionValidationFailure = "[Mission API] Mission not loaded: "
			.. #validationResult.errors
			.. " validation errors in "
			.. gameSetup.entryPoint
			.. " (see infolog)"
		return
	end

	local initialStage = mission.InitialStage
	local stages = mission.Stages or {}
	local rawObjectives = mission.Objectives or {}
	local rawTriggers = mission.Triggers or {}
	local rawActions = mission.Actions or {}

	GG["MissionAPI"].CurrentStageID = initialStage
	GG["MissionAPI"].Stages = stagesController.ProcessRawStages(stages)
	GG["MissionAPI"].Objectives =
		objectivesController.ProcessRawObjectives(rawObjectives, rawTriggers, rawActions, stages)
	GG["MissionAPI"].Triggers = triggersController.ProcessRawTriggers(rawTriggers)
	GG["MissionAPI"].Actions = actionsController.ProcessRawActions(rawActions)
	GG["MissionAPI"].UnitLoadout = mission.UnitLoadout
	GG["MissionAPI"].FeatureLoadout = mission.FeatureLoadout
	GG["MissionAPI"].Cutscenes = mission.Cutscenes or {}

	-- Difficulties tables stay unresolved through validation so every difficulty's value is checked.
	local difficultyController = GG["MissionAPI"].Modules.Difficulty
	GG["MissionAPI"].Difficulty = difficultyController.FromName(gameSetup.difficulty)
	difficultyController.ResolveTriggers(GG["MissionAPI"].Triggers)
	difficultyController.ResolveActions(GG["MissionAPI"].Actions)
	difficultyController.ResolveObjectives(GG["MissionAPI"].Objectives)
	difficultyController.ResolveCutscenes(GG["MissionAPI"].Cutscenes)

	-- TODO: refactor loaders after merging loadouts
	local parameterProcessing = VFS.Include("luarules/mission_api/parameter_processing.lua")
	GG["MissionAPI"].Modules.Variables.ResolveReferences(
		GG["MissionAPI"].Triggers,
		GG["MissionAPI"].Actions,
		GG["MissionAPI"].Objectives,
		parameterProcessing.ProcessValue
	)
	parameterProcessing.ProcessActionParameters(GG["MissionAPI"].Actions)
	parameterProcessing.ProcessTriggerParameters(GG["MissionAPI"].Triggers)
end

function gadget:Initialize()
	local gameSetup = VFS.Include("luarules/mission_api/game_setup.lua")
	if not gameSetup then
		gadgetHandler:RemoveGadget()
		return
	end

	GG["MissionAPI"] = {}
	GG["MissionAPI"].Options = gameSetup.options
	GG["MissionAPI"].Variables = gameSetup.variables
	GG["MissionAPI"].PersistentVariables = gameSetup.persistentVariables
	GG["MissionAPI"].Teams = gameSetup.teams
	GG["MissionAPI"].AllyTeams = gameSetup.allyTeams
	GG["MissionAPI"].DummyTeams = gameSetup.dummyTeams
	GG["MissionAPI"].trackedUnitIDs = {}
	GG["MissionAPI"].trackedUnitNames = {}
	GG["MissionAPI"].trackedFeatureIDs = {}
	GG["MissionAPI"].trackedFeatureNames = {}
	GG["MissionAPI"].markerNames = {}
	GG["MissionAPI"].lineNames = {}
	GG["MissionAPI"].unitMarkers = {}
	GG["MissionAPI"].soundFiles = {}
	GG["MissionAPI"].soundQueue = {}
	GG["MissionAPI"].ManagedObjectives = {}
	GG["MissionAPI"].ObjectiveTriggers = {}
	GG["MissionAPI"].ObjectiveStages = {}
	GG["MissionAPI"].Countdowns = {}
	GG["MissionAPI"].BattleLogRaw = {}
	GG["MissionAPI"].Modules = {}
	GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")
	GG["MissionAPI"].Modules.Difficulty = VFS.Include("luarules/mission_api/difficulty.lua")
	GG["MissionAPI"].Modules.Variables = VFS.Include("luarules/mission_api/variables.lua")
	GG["MissionAPI"].Modules.PersistentVariables = VFS.Include("luarules/mission_api/persistent_variables.lua")
	GG["MissionAPI"].Modules.Tracking = VFS.Include("luarules/mission_api/tracking.lua")
	GG["MissionAPI"].Modules.UnitQuery = VFS.Include("luarules/mission_api/unit_query.lua")
	GG["MissionAPI"].Modules.Loadout = VFS.Include("luarules/mission_api/loadout.lua")
	GG["MissionAPI"].Modules.Sounds = VFS.Include("luarules/mission_api/sounds.lua")
	GG["MissionAPI"].Modules.Objectives = VFS.Include("luarules/mission_api/objectives.lua")
	GG["MissionAPI"].Modules.Countdowns = VFS.Include("luarules/mission_api/countdowns.lua")
	GG["MissionAPI"].Modules.BattleLog = VFS.Include("luarules/mission_api/battle_log.lua")
	GG["MissionAPI"].Modules.Cutscenes = VFS.Include("luarules/mission_api/cutscenes.lua")
	GG["MissionAPI"].Modules.MapLines = VFS.Include("luarules/mission_api/map_lines.lua")
	GG["MissionAPI"].Modules.UnitMarkers = VFS.Include("luarules/mission_api/unit_markers.lua")
	GG["MissionAPI"].Modules.SeismicContacts = VFS.Include("luarules/mission_api/seismic_contacts.lua")
	GG["MissionAPI"].Modules.DetectionLevels = VFS.Include("luarules/mission_api/detection_levels.lua")
	GG["MissionAPI"].Modules.AreaTracking = VFS.Include("luarules/mission_api/area_tracking.lua")

	objectivesController = VFS.Include("luarules/mission_api/objectives_loader.lua")
	stagesController = VFS.Include("luarules/mission_api/stages_loader.lua")

	actionsController = VFS.Include("luarules/mission_api/actions_loader.lua")
	GG["MissionAPI"].ActionDefinitions = actionsController.LoadActionDefinitions()

	triggersController = VFS.Include("luarules/mission_api/triggers_loader.lua")
	GG["MissionAPI"].TriggerDefinitions = triggersController.LoadTriggerDefinitions()

	GG["MissionAPI"].CollateSchemas = VFS.Include("luarules/mission_api/schema_utils.lua").CollateSchemas

	loadMission(gameSetup)
end

function gadget:GamePreload()
	if missionValidationFailure then
		return
	end

	local loadoutModule = GG["MissionAPI"].Modules.Loadout
	loadoutModule.SpawnUnitLoadout(GG["MissionAPI"].UnitLoadout)
	loadoutModule.SpawnFeatureLoadout(GG["MissionAPI"].FeatureLoadout)

	GG["MissionAPI"].Modules.Objectives.ActivateStage(GG["MissionAPI"].CurrentStageID)
end

function gadget:GameFrame(frameNumber)
	-- Invalid mission ends the game
	if missionValidationFailure then
		Spring.GameOver({}) -- This logs 2 lines and UI shows only 2 lines, so we Echo missionValidationFailure after this
		Spring.Echo(missionValidationFailure)
		gadgetHandler:RemoveGadget()
		return
	end

	GG["MissionAPI"].Modules.Sounds.ProcessSoundQueue(frameNumber)
	GG["MissionAPI"].Modules.AreaTracking.UpdateTrackedAreas()
end

function gadget:GameOver()
	if missionValidationFailure then
		return
	end

	SendToUnsynced("MissionPersistentVariables", GG["MissionAPI"].Modules.PersistentVariables.Encode())
end

function gadget:Shutdown()
	GG["MissionAPI"] = nil
end
