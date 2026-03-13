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
local missionUnitLoadout, missionFeatureLoadout

local function loadMission(scriptPath)
	local mission = VFS.Include("singleplayer/" .. scriptPath)
	local rawTriggers = mission.Triggers
	local rawActions = mission.Actions

	GG['MissionAPI'].Triggers = triggersController.ProcessRawTriggers(rawTriggers, rawActions)
	GG['MissionAPI'].Actions = actionsController.ProcessRawActions(rawActions)

	local validation   = VFS.Include('luarules/mission_api/validation.lua')
	local triggerTypes = GG['MissionAPI'].TriggerTypes
	local actionTypes  = GG['MissionAPI'].ActionTypes
	local triggers     = GG['MissionAPI'].Triggers
	local actions      = GG['MissionAPI'].Actions

	missionUnitLoadout    = mission.UnitLoadout
	missionFeatureLoadout = mission.FeatureLoadout

	validation.ValidateLoadouts(missionUnitLoadout, missionFeatureLoadout)
	validation.ValidateUnitNameReferences(triggerTypes, actionTypes, triggers, actions, missionUnitLoadout)
	validation.ValidateFeatureNameReferences(triggerTypes, actionTypes, triggers, actions, missionFeatureLoadout)
end

function gadget:Initialize()
	-- TODO: Actually pass script path
	local scriptPath = 'mission-api-tests/validation_test.lua'
	--local scriptPath = 'mission-api-tests/test_mission.lua'
	--local scriptPath = 'mission-api-tests/unit_triggers_test.lua'
	--local scriptPath = 'mission-api-tests/feature_triggers_test.lua'
	--local scriptPath = 'mission-api-tests/loadout_test.lua'

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

	triggersController = VFS.Include('luarules/mission_api/triggers_loader.lua')
	actionsController = VFS.Include('luarules/mission_api/actions_loader.lua')

	loadMission(scriptPath)
end

function gadget:GamePreload()
	if Spring.GetGameRulesParam("loadedGame") == 1 then
		Spring.Echo("Mission API: Loading saved game, skipping loadout")
		return
	end

	if missionUnitLoadout then
		Spring.Echo("Mission API: Creating unit loadout")
	end
	if missionFeatureLoadout then
		Spring.Echo("Mission API: Creating feature loadout")
	end

	local tracking = VFS.Include('luarules/mission_api/tracking.lua')
	tracking.InitializeTracking()

	local loadoutModule = VFS.Include('luarules/mission_api/loadout.lua')
	loadoutModule.SpawnUnitLoadout(missionUnitLoadout, tracking.TrackUnit)
	loadoutModule.SpawnFeatureLoadout(missionFeatureLoadout, tracking.TrackFeature)
end

function gadget:Shutdown()
	GG['MissionAPI'] = nil
end
