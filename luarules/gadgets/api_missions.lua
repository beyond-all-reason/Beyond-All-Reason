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
local validation = VFS.Include('luarules/mission_api/validation.lua')

local objectivesController, stagesController, triggersController, actionsController

local function loadMission(scriptPath)
	local mission = VFS.Include(scriptPath)
	local initialStage = mission.InitialStage
	local stages = mission.Stages or {}
	local rawObjectives = mission.Objectives or {}
	local rawTriggers = mission.Triggers or {}
	local rawActions = mission.Actions or {}

	GG['MissionAPI'].CurrentStageID = initialStage
	GG['MissionAPI'].Stages = stagesController.ProcessRawStages(stages)
	GG['MissionAPI'].Objectives = objectivesController.ProcessRawObjectives(rawObjectives, rawTriggers, rawActions, stages)
	GG['MissionAPI'].Triggers = triggersController.ProcessRawTriggers(rawTriggers)
	GG['MissionAPI'].Actions = actionsController.ProcessRawActions(rawActions)
	GG['MissionAPI'].UnitLoadout = mission.UnitLoadout
	GG['MissionAPI'].FeatureLoadout = mission.FeatureLoadout

	validation.ValidateStages(GG['MissionAPI'].Stages)
	validation.ValidateObjectives(GG['MissionAPI'].Objectives)
	validation.ValidateInitialStage(initialStage)
	validation.ValidateTriggers(GG['MissionAPI'].Triggers, rawActions)
	validation.ValidateActions(GG['MissionAPI'].Actions)
	validation.ValidateReferences()

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

local function setAiNames(ais)
	for i, name in pairs(ais) do
		Spring.SetGameRulesParam('ainame_' .. i, name)
	end
end

function gadget:Initialize()
	local missionOptions = Spring.GetModOptions().missionoptions
	if not missionOptions then
		gadgetHandler:RemoveGadget()
		return
	end
	missionOptions = Json.decode(string.base64Decode(missionOptions))

	setAiNames(missionOptions.ais)

	GG['MissionAPI'] = {}
	GG['MissionAPI'].Difficulty = missionOptions.difficulty or 0
	GG['MissionAPI'].AllyTeams  = missionOptions.allyTeams or {}
	GG['MissionAPI'].Teams      = missionOptions.teams or {}
	GG['MissionAPI'].AIs        = missionOptions.ais or {}
	GG['MissionAPI'].Players    = missionOptions.players or {}

	local triggersSchema = VFS.Include('luarules/mission_api/triggers_schema.lua')
	local actionsSchema = VFS.Include('luarules/mission_api/actions_schema.lua')
	GG['MissionAPI'].TriggerTypes = triggersSchema.Types
	GG['MissionAPI'].ActionTypes = actionsSchema.Types
	GG['MissionAPI'].trackedUnitIDs                 = {}
	GG['MissionAPI'].trackedUnitNames               = {}
	GG['MissionAPI'].trackedFeatureIDs              = {}
	GG['MissionAPI'].trackedFeatureNames            = {}
	GG['MissionAPI'].soundFiles                     = {}
	GG['MissionAPI'].soundQueue                     = {}
	GG['MissionAPI'].ManagedObjectives = {}

	objectivesController = VFS.Include('luarules/mission_api/objectives_loader.lua')
	stagesController = VFS.Include('luarules/mission_api/stages_loader.lua')
	triggersController = VFS.Include('luarules/mission_api/triggers_loader.lua')
	actionsController = VFS.Include('luarules/mission_api/actions_loader.lua')

	loadMission(missionOptions.missionScriptPath);
end

function gadget:GamePreload()
	local loadoutModule = VFS.Include('luarules/mission_api/loadout.lua')
	loadoutModule.SpawnUnitLoadout(GG['MissionAPI'].UnitLoadout)
	loadoutModule.SpawnFeatureLoadout(GG['MissionAPI'].FeatureLoadout)

	if GG['MissionAPI'].CurrentStageID then
		Spring.Echo("Stage set to: " .. GG['MissionAPI'].CurrentStageID)
	end
end

function gadget:GameFrame(frameNumber)
	sounds.ProcessSoundQueue(frameNumber)
end

function gadget:Shutdown()
	GG['MissionAPI'] = nil
end
