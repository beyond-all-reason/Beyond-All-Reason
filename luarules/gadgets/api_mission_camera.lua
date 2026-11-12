local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Mission camera",
		desc = "Passes the Mission API's camera actions on to LuaUI",
		date = "October 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	return false
end

local SYNC_ACTIONS = {
	"MissionCameraPlay",
	"MissionCameraFollow",
	"MissionCameraOrbit",
	"MissionCameraShake",
	"MissionCameraSave",
	"MissionCameraRestore",
	"MissionCameraStop",
}

function gadget:Initialize()
	for _, syncAction in ipairs(SYNC_ACTIONS) do
		gadgetHandler:AddSyncAction(syncAction, function(_, params)
			if Script.LuaUI(syncAction) then
				Script.LuaUI[syncAction](params)
			end
			return true
		end)
	end
end

function gadget:Shutdown()
	for _, syncAction in ipairs(SYNC_ACTIONS) do
		gadgetHandler:RemoveSyncAction(syncAction)
	end
end
