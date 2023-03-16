function gadget:GetInfo()
	return {
		name = "Mission API triggers",
		desc = "Load and poll mission triggers, and dispatch actions",
		date = "2023.03.14",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local actionDispatcher = VFS.Include('luarules/configs/scenarioscripts/API/actions_dispatcher.lua')

local function loadMission()
	-- TODO: Actually pass script path in modoptions
	local missionSettings = Spring.GetModOptions().mission_path
	local scriptPath = missionSettings.path

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
	GG['MissionAPI'].TriggersController = VFS.Include('luarules/configs/scenarioscripts/API/triggers.lua')
	GG['MissionAPI'].ActionsController = VFS.Include('luarules/configs/scenarioscripts/API/actions.lua')

	loadMission();
	-- loading the mission script needs to populate the global triggers and actions tables

	-- load triggers into table(s)
	GG['MissionAPI'].Triggers = GG['MissionAPI'].TriggersController.GetTriggers()
	GG['MissionAPI'].Actions = GG['MissionAPI'].ActionsController.GetActions()
end

function gadget:Shutdown()
	GG['MissionAPI'] = nil
end