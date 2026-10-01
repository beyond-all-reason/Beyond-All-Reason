local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Mission battle log",
		desc = "Tells LuaUI when the Mission API's battle log has a new message",
		date = "2026-10-01",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	return false
end

local SYNC_ACTION = "MissionBattleLogChanged"

local function onBattleLogChanged()
	if Script.LuaUI("MissionBattleLogChanged") then
		Script.LuaUI.MissionBattleLogChanged()
	end
	return true
end

function gadget:Initialize()
	gadgetHandler:AddSyncAction(SYNC_ACTION, onBattleLogChanged)
end

function gadget:Shutdown()
	gadgetHandler:RemoveSyncAction(SYNC_ACTION)
end
