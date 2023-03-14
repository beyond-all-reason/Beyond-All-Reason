function gadget:GetInfo()
	return {
		name = "Mission API triggers",
		desc = "Load and poll mission triggers, and dispatch actions",
		date = "2023.03.14",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local function loadMission()
	-- TODO: Actually pass script path in scenariooptions modoption
	local missionSettings = Spring.GetModOptions().scenariooptions
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

	loadMission();
	-- loading the mission sciprt needs to populate the global triggers and actions tables
	-- may be confusing if GG['MissionAPI'] is declared here but modified elsewhere

	-- load triggers into table(s)
end

function gadget:Shutdown()
	GG['MissionAPI'] = nil
end