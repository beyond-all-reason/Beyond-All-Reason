local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Mission hint",
		desc = "Tells LuaUI when the Mission API's hint changes",
		date = "2026-11-12",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	return false
end

local SYNC_ACTION = "MissionHintChanged"

local function onHintChanged()
	if Script.LuaUI("MissionHintChanged") then
		Script.LuaUI.MissionHintChanged()
	end
	return true
end

function gadget:Initialize()
	if not Spring.GetGameRulesParam("inMission") then
		gadgetHandler:RemoveGadget()
		return
	end
	gadgetHandler:AddSyncAction(SYNC_ACTION, onHintChanged)
end

function gadget:Shutdown()
	gadgetHandler:RemoveSyncAction(SYNC_ACTION)
end
