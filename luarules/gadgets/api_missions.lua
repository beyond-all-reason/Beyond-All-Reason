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
local rawTriggers, rawActions

local function loadMission()
	local mission = VFS.Include("singleplayer/" .. scriptPath)
	rawTriggers = mission.Triggers
	rawActions = mission.Actions

	GG['MissionAPI'].TriggersController.PreprocessRawTriggers(rawTriggers)
	GG['MissionAPI'].ActionsController.PreprocessRawActions(rawActions)

	GG['MissionAPI'].Triggers = GG['MissionAPI'].TriggersController.GetTriggers()
	GG['MissionAPI'].Actions = GG['MissionAPI'].ActionsController.GetActions()

	GG['MissionAPI'].TriggersController.PostprocessTriggers()
end

function gadget:Initialize()
	-- TODO: Actually pass script path in modoptions
	scriptPath = 'test_mission.lua'-- Spring.GetModOptions().mission_path

	if not scriptPath then
		gadgetHandler:RemoveGadget()
	end

	GG['MissionAPI'] = {}
	GG['MissionAPI'].Difficulty = Spring.GetModOptions().mission_difficulty --TODO: add mission difficulty modoption
	GG['MissionAPI'].TriggersController = VFS.Include('luarules/mission_api/triggers.lua')
	GG['MissionAPI'].ActionsController = VFS.Include('luarules/mission_api/actions.lua')

	loadMission();

	GG['MissionAPI'].ActionsDispatcher = VFS.Include('luarules/mission_api/actions_dispatcher.lua')
end

function gadget:Shutdown()
	GG['MissionAPI'] = nil
end