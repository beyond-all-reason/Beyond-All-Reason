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
	GG['c5b27dc'] = {}
	GG['c5b27dc'].TriggersController = VFS.Include('luarules/configs/scenarioscripts/API/triggers.lua')
	GG['c5b27dc'].ActionsController = VFS.Include('luarules/configs/scenarioscripts/API/actions.lua')
	GG['c5b27dc'].ActionsDispatcher = VFS.Include('luarules/configs/scenarioscripts/API/actions_dispatcher.lua')
	GG['c5b27dc'].Difficulty = Spring.GetModOptions().mission_difficulty --TODO: add mission difficulty modoption

	loadMission();
	-- loading the mission script needs to populate the global triggers and actions tables

	-- load triggers into table(s)
	GG['c5b27dc'].Triggers = GG['c5b27dc'].TriggersController.GetTriggers()
	GG['c5b27dc'].Actions = GG['c5b27dc'].ActionsController.GetActions()
end

function gadget:Shutdown()
	GG['c5b27dc'] = nil
end