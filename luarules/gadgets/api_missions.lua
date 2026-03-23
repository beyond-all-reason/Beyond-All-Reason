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
	local scriptPath = 'mission-api-tests/loadout_test.lua'

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

	triggersController = VFS.Include('luarules/mission_api/triggers_loader.lua')
	actionsController = VFS.Include('luarules/mission_api/actions_loader.lua')

	loadMission(scriptPath)
end

function gadget:GamePreload()
	if Spring.GetGameRulesParam("loadedGame") == 1 then
		Spring.Echo("Mission API: Loading saved game, skipping loadout")
		return
	end

	if GG['MissionAPI'].UnitLoadout then
		Spring.Echo("Mission API: Creating unit loadout")
	end
	if GG['MissionAPI'].FeatureLoadout then
		Spring.Echo("Mission API: Creating feature loadout")
	end

	local tracking = VFS.Include('luarules/mission_api/tracking.lua')
	tracking.InitializeTracking()

	local loadoutModule = VFS.Include('luarules/mission_api/loadout.lua')
	loadoutModule.SpawnUnitLoadout(GG['MissionAPI'].UnitLoadout, tracking.TrackUnit)
	loadoutModule.SpawnFeatureLoadout(GG['MissionAPI'].FeatureLoadout, tracking.TrackFeature)
end

function gadget:GameFrame(frameNumber)
	sounds.ProcessSoundQueue(frameNumber)
end

function gadget:Shutdown()
	GG['MissionAPI'] = nil
end
