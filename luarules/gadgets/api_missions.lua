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
	---The unsynced half exists only to relay moments to LuaUI. State must not come
	---through here: It is published as rules params which survive a /luaui reload.
	local function forwardMissionMessage(_, textKey)
		if Script.LuaUI("MissionMessage") then
			Script.LuaUI.MissionMessage(textKey)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("MissionMessage", forwardMissionMessage)
	end

	return
end

local objectivesController, stagesController, triggersController, actionsController

local function loadMission(scriptPath)
	local mission = VFS.Include("singleplayer/" .. scriptPath)
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

	local validation = VFS.Include("luarules/mission_api/validation.lua")
	validation.ValidateStages(GG["MissionAPI"].Stages)
	validation.ValidateObjectives(GG["MissionAPI"].Objectives)
	validation.ValidateInitialStage(initialStage)
	validation.ValidateTriggers(GG["MissionAPI"].Triggers, rawActions)
	validation.ValidateActions(GG["MissionAPI"].Actions)
	validation.ValidateReferences()

	if GG["MissionAPI"].HasValidationErrors then
		GG["MissionAPI"] = nil -- stops gadget api_missions_triggers from loading
		gadgetHandler:RemoveGadget()
		return
	end

	-- TODO: refactor loaders after merging loadouts
	local parameterProcessing = VFS.Include("luarules/mission_api/parameter_processing.lua")
	parameterProcessing.ProcessActionParameters(GG["MissionAPI"].Actions)
	parameterProcessing.ProcessTriggerParameters(GG["MissionAPI"].Triggers)
end

function gadget:Initialize()
	local scriptPath = nil -- relative to `singleplayer`, e.g.: 'mission-api-tests/filename.lua'.
	if not scriptPath then
		gadgetHandler:RemoveGadget()
		return
	end

	GG["MissionAPI"] = {}
	GG["MissionAPI"].Difficulty = 0
	GG["MissionAPI"].trackedUnitIDs = {}
	GG["MissionAPI"].trackedUnitNames = {}
	GG["MissionAPI"].trackedFeatureIDs = {}
	GG["MissionAPI"].trackedFeatureNames = {}
	GG["MissionAPI"].markerNames = {}
	GG["MissionAPI"].soundFiles = {}
	GG["MissionAPI"].soundQueue = {}
	GG["MissionAPI"].ManagedObjectives = {}
	GG["MissionAPI"].Modules = {}
	GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")
	GG["MissionAPI"].Modules.Tracking = VFS.Include("luarules/mission_api/tracking.lua")
	GG["MissionAPI"].Modules.Loadout = VFS.Include("luarules/mission_api/loadout.lua")
	GG["MissionAPI"].Modules.Sounds = VFS.Include("luarules/mission_api/sounds.lua")
	GG["MissionAPI"].Modules.Objectives = VFS.Include("luarules/mission_api/objectives.lua")
	GG["MissionAPI"].Modules.Presentation = VFS.Include("luarules/mission_api/presentation.lua")
	GG["MissionAPI"].Modules.SeismicContacts = VFS.Include("luarules/mission_api/seismic_contacts.lua")
	GG["MissionAPI"].Modules.DetectionLevels = VFS.Include("luarules/mission_api/detection_levels.lua")

	objectivesController = VFS.Include("luarules/mission_api/objectives_loader.lua")
	stagesController = VFS.Include("luarules/mission_api/stages_loader.lua")

	actionsController = VFS.Include("luarules/mission_api/actions_loader.lua")
	GG["MissionAPI"].ActionDefinitions = actionsController.LoadActionDefinitions()

	triggersController = VFS.Include("luarules/mission_api/triggers_loader.lua")
	GG["MissionAPI"].TriggerDefinitions = triggersController.LoadTriggerDefinitions()

	loadMission(scriptPath)
end

function gadget:GamePreload()
	local loadoutModule = GG["MissionAPI"].Modules.Loadout
	loadoutModule.SpawnUnitLoadout(GG["MissionAPI"].UnitLoadout)
	loadoutModule.SpawnFeatureLoadout(GG["MissionAPI"].FeatureLoadout)

	if GG["MissionAPI"].CurrentStageID then
		Spring.Echo("Stage set to: " .. GG["MissionAPI"].CurrentStageID)
	end
end

function gadget:GameFrame(frameNumber)
	GG["MissionAPI"].Modules.Sounds.ProcessSoundQueue(frameNumber)
end

function gadget:RecvLuaMsg(msg, playerID)
	local interactionID, choice = msg:match("^mission:choose:(%d+):(%d+)$")
	if not interactionID then
		interactionID = msg:match("^mission:ack:(%d+)$")
	end
	if not interactionID then
		return
	end

	local missionAPI = GG["MissionAPI"]
	if not missionAPI or not missionAPI.Modules.Presentation then
		return
	end

	missionAPI.Modules.Presentation.EndInteraction(tonumber(interactionID), playerID, tonumber(choice))
end

function gadget:Shutdown()
	GG["MissionAPI"] = nil
end
