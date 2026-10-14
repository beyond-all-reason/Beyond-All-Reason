local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Mission input lock",
		desc = "Passes the Mission API's LockPlayerInput and UnlockPlayerInput actions on to LuaUI",
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
	"MissionLockPlayerInput",
	"MissionUnlockPlayerInput",
}

function gadget:Initialize()
	for _, syncAction in ipairs(SYNC_ACTIONS) do
		gadgetHandler:AddSyncAction(syncAction, function()
			if Script.LuaUI(syncAction) then
				Script.LuaUI[syncAction]()
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
