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

local triggersController, actionsController

local function loadMission(scriptPath)
	local mission = VFS.Include("singleplayer/" .. scriptPath)
	local rawTriggers = mission.Triggers
	local rawActions = mission.Actions

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
	--local scriptPath = 'mission-api-tests/validation_test.lua'
	--local scriptPath = 'mission-api-tests/test_mission.lua'
	--local scriptPath = 'mission-api-tests/markers_test.lua'
	--local scriptPath = 'mission-api-tests/sound_test.lua'
	--local scriptPath = 'mission-api-tests/issue_orders_test.lua'
	--local scriptPath = 'mission-api-tests/unit_triggers_test.lua'
	--local scriptPath = 'mission-api-tests/feature_triggers_test.lua'
	--local scriptPath = 'mission-api-tests/statistics_triggers_test.lua'
	--local scriptPath = 'mission-api-tests/resource_test.lua'
	local scriptPath = 'mission-api-tests/loadout_test.lua'

	if not scriptPath then
		gadgetHandler:RemoveGadget()
		return
	end

	GG['MissionAPI'] = {}
	GG['MissionAPI'].Difficulty             = 0
	GG['MissionAPI'].trackedUnitIDs         = {}
	GG['MissionAPI'].trackedUnitNames       = {}
	GG['MissionAPI'].trackedFeatureIDs      = {}
	GG['MissionAPI'].trackedFeatureNames    = {}
	GG['MissionAPI'].markerNames            = {}
	GG['MissionAPI'].soundFiles             = {}
	GG['MissionAPI'].soundQueue             = {}
	GG['MissionAPI'].Modules                = {}
	GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')
	GG['MissionAPI'].Modules.Tracking       = VFS.Include('luarules/mission_api/tracking.lua')
	GG['MissionAPI'].Modules.Loadout        = VFS.Include('luarules/mission_api/loadout.lua')
	GG['MissionAPI'].Modules.Sounds         = VFS.Include('luarules/mission_api/sounds.lua')

	actionsController = VFS.Include('luarules/mission_api/actions_loader.lua')
	GG['MissionAPI'].ActionDefinitions = actionsController.LoadActionDefinitions()

	local triggersSchema = VFS.Include('luarules/mission_api/triggers_schema.lua')
	triggersController = VFS.Include('luarules/mission_api/triggers_loader.lua')
	GG['MissionAPI'].TriggerTypes = triggersSchema.Types

	loadMission(scriptPath)
end

function gadget:GamePreload()
	local loadoutModule = GG['MissionAPI'].Modules.Loadout
	loadoutModule.SpawnUnitLoadout(GG['MissionAPI'].UnitLoadout)
	loadoutModule.SpawnFeatureLoadout(GG['MissionAPI'].FeatureLoadout)
end

function gadget:GameFrame(frameNumber)
	GG['MissionAPI'].Modules.Sounds.ProcessSoundQueue(frameNumber)
end

function gadget:Shutdown()
	GG['MissionAPI'] = nil
end
