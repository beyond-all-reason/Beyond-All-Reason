local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Mission API loader",
		desc = "Load and populate global mission table",
		date = "2023.03.14",
		layer = 0,
		enabled = false,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local scriptPath
local triggersController, actionsController
local rawTriggers, rawActions

local function loadMission()
	local mission = VFS.Include("singleplayer/" .. scriptPath)
	rawTriggers = mission.Triggers
	rawActions = mission.Actions

	triggersController.PreprocessRawTriggers(rawTriggers)
	actionsController.PreprocessRawActions(rawActions)

	GG['MissionAPI'].Triggers = triggersController.GetTriggers()
	GG['MissionAPI'].Actions = actionsController.GetActions()

	triggersController.PostprocessTriggers()
end

function gadget:Initialize()
	-- TODO: Actually pass script path in modoptions
	scriptPath = 'test_mission.lua'-- Spring.GetModOptions().mission_path

	if not scriptPath then
		gadgetHandler:RemoveGadget()
		return
	end

	GG['MissionAPI'] = {}
	GG['MissionAPI'].Difficulty = Spring.GetModOptions().mission_difficulty --TODO: add mission difficulty modoption

	local triggersSchema = VFS.Include('luarules/mission_api/triggers_schema.lua')
	local actionsSchema = VFS.Include('luarules/mission_api/actions_schema.lua')
	GG['MissionAPI'].TriggerTypes = triggersSchema.Types
	GG['MissionAPI'].ActionTypes = actionsSchema.Types

	GG['MissionAPI'].TrackedUnits = {}

	triggersController = VFS.Include('luarules/mission_api/triggers_loader.lua')
	actionsController = VFS.Include('luarules/mission_api/actions_loader.lua')

	loadMission();
end

function gadget:Shutdown()
	GG['MissionAPI'] = nil
end