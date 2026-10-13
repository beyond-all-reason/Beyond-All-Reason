local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Mission client actions",
		desc = "Hands the Mission API's camera and input-lock actions to LuaUI",
		date = "October 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	return false
end

local SYNC_ACTION = "MissionClientAction"

local function onClientAction(_, command)
	if Script.LuaUI("MissionClientAction") then
		Script.LuaUI.MissionClientAction(command)
	end
	return true
end

function gadget:Initialize()
	gadgetHandler:AddSyncAction(SYNC_ACTION, onClientAction)
end

function gadget:Shutdown()
	gadgetHandler:RemoveSyncAction(SYNC_ACTION)
end
