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

local sounds = VFS.Include('luarules/mission_api/sounds.lua')

local stagesController, objectivesController, triggersController, actionsController

local function loadMission(scriptPath)
	local mission = VFS.Include("singleplayer/" .. scriptPath)
	local initialStage = mission.InitialStage or "initialStage"
	local rawObjectives = mission.Objectives or {}
	local rawStages = mission.Stages or {}
	local rawTriggers = mission.Triggers or {}
	local rawActions = mission.Actions or {}

	GG['MissionAPI'].CurrentStageID = initialStage
	GG['MissionAPI'].Objectives = objectivesController.ProcessRawObjectives(rawObjectives)
	GG['MissionAPI'].Stages = stagesController.ProcessRawStages(rawStages, initialStage)
	GG['MissionAPI'].Triggers = triggersController.ProcessRawTriggers(rawTriggers, rawActions)
	GG['MissionAPI'].Actions = actionsController.ProcessRawActions(rawActions)
	GG['MissionAPI'].UnitLoadout = mission.UnitLoadout
	GG['MissionAPI'].FeatureLoadout = mission.FeatureLoadout

	local validateReferences = VFS.Include('luarules/mission_api/validation.lua').ValidateReferences
	validateReferences()

	if GG['MissionAPI'].HasValidationErrors then
		GG['MissionAPI'] = nil -- stops gadget api_missions_triggers from loading
		gadgetHandler:RemoveGadget()
		return
	end

	-- TODO: refactor loaders after merging loadouts
	local parameterProcessing = VFS.Include('luarules/mission_api/parameter_processing.lua')
	parameterProcessing.ProcessActionParameters(GG['MissionAPI'].Actions)
	parameterProcessing.ProcessTriggerParameters(GG['MissionAPI'].Triggers)
end

function gadget:Initialize()
	-- TODO: Actually pass script path
	--local scriptPath = 'mission-api-tests/validation_test.lua'
	--local scriptPath = 'mission-api-tests/test_mission.lua'
	--local scriptPath = 'mission-api-tests/markers_test.lua'
	--local scriptPath = 'mission-api-tests/sound_test.lua'
	--local scriptPath = 'mission-api-tests/issue_orders_test.lua'
	--local scriptPath = 'mission-api-tests/unit_triggers_test.lua'
	--local scriptPath = 'mission-api-tests/feature_triggers_test.lua'
	--local scriptPath = 'mission-api-tests/statistics_triggers_test.lua'
	--local scriptPath = 'mission-api-tests/resource_test.lua'
	--local scriptPath = 'mission-api-tests/loadout_test.lua'
	local scriptPath = 'mission-api-tests/stages_and_objectives_test.lua'

	if not scriptPath then
		gadgetHandler:RemoveGadget()
		return
	end

	GG['MissionAPI'] = {}
	GG['MissionAPI'].Difficulty = 0 --TODO: implement mission difficulties

	local triggersSchema = VFS.Include('luarules/mission_api/triggers_schema.lua')
	local actionsSchema = VFS.Include('luarules/mission_api/actions_schema.lua')
	GG['MissionAPI'].TriggerTypes = triggersSchema.Types
	GG['MissionAPI'].ActionTypes = actionsSchema.Types
	GG['MissionAPI'].trackedUnitIDs      = {}
	GG['MissionAPI'].trackedUnitNames    = {}
	GG['MissionAPI'].trackedFeatureIDs   = {}
	GG['MissionAPI'].trackedFeatureNames = {}
	GG['MissionAPI'].soundFiles          = {}
	GG['MissionAPI'].soundQueue          = {}

	objectivesController = VFS.Include('luarules/mission_api/objectives_loader.lua')
	stagesController = VFS.Include('luarules/mission_api/stages_loader.lua')
	triggersController = VFS.Include('luarules/mission_api/triggers_loader.lua')
	actionsController = VFS.Include('luarules/mission_api/actions_loader.lua')

	loadMission(scriptPath)
end

function gadget:GamePreload()
	local loadoutModule = VFS.Include('luarules/mission_api/loadout.lua')
	loadoutModule.SpawnUnitLoadout(GG['MissionAPI'].UnitLoadout)
	loadoutModule.SpawnFeatureLoadout(GG['MissionAPI'].FeatureLoadout)

	if next(GG['MissionAPI'].Stages) then
		Spring.Echo("Stage set to: " .. GG['MissionAPI'].CurrentStageID)
	end
end

function gadget:GameFrame(frameNumber)
	sounds.ProcessSoundQueue(frameNumber)
end

function gadget:Shutdown()
	GG['MissionAPI'] = nil
end
