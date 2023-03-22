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
	return
end

local function loadMission()
	-- TODO: Actually pass script path in modoptions
	local scriptPath = 'test_mission.lua'-- Spring.GetModOptions().mission_path

	if not scriptPath then
		gadgetHandler:RemoveGadget()
	end

	VFS.Include("singleplayer/" .. scriptPath)
end

-- monitor and dispatch triggers
-- when trigger invoked, set activated, count, etc.
-- disable trigger if appropriate
-- invoke actions

function gadget:Initialize()
	GG['MissionAPI'] = {}
	GG['MissionAPI'].TriggersController = VFS.Include('luarules/mission_api/triggers.lua')
	GG['MissionAPI'].ActionsController = VFS.Include('luarules/mission_api/actions.lua')
	GG['MissionAPI'].ActionsDispatcher = VFS.Include('luarules/mission_api/actions_dispatcher.lua')
	GG['MissionAPI'].Difficulty = Spring.GetModOptions().mission_difficulty --TODO: add mission difficulty modoption

	loadMission();
	-- loading the mission script needs to populate the global triggers and actions tables

	-- load triggers into table(s)
	GG['MissionAPI'].Triggers = GG['MissionAPI'].TriggersController.GetTriggers()
	GG['MissionAPI'].Actions = GG['MissionAPI'].ActionsController.GetActions()
end

function gadget:Shutdown()
	GG['MissionAPI'] = nil
end