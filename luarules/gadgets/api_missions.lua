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

local scriptPath
local triggersController, actionsController

local function loadMission()
	local mission = VFS.Include("singleplayer/" .. scriptPath)
	local rawTriggers = mission.Triggers
	local rawActions = mission.Actions

	GG['MissionAPI'].Triggers = triggersController.ProcessRawTriggers(rawTriggers, rawActions)
	GG['MissionAPI'].Actions = actionsController.ProcessRawActions(rawActions)

	local validateUnitNameReferences = VFS.Include('luarules/mission_api/validation.lua').ValidateUnitNameReferences
	validateUnitNameReferences()
end

function gadget:Initialize()
	-- TODO: Actually pass script path
	scriptPath = 'mission-api-tests/validation_test.lua'
	--scriptPath = 'mission-api-tests/test_mission.lua'

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
	GG['MissionAPI'].trackedUnitIDs = {}
	GG['MissionAPI'].trackedUnitNames = {}

	triggersController = VFS.Include('luarules/mission_api/triggers_loader.lua')
	actionsController = VFS.Include('luarules/mission_api/actions_loader.lua')

	loadMission();
end

function gadget:Shutdown()
	GG['MissionAPI'] = nil
end
