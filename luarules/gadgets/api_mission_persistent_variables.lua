local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Mission persistent variables",
		desc = "Records the Mission API's persistent variables into the replay",
		date = "2026-10-05",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	return false
end

local SYNC_ACTION = "MissionPersistentVariables"

local function savePersistentVariablesToDemo(_, payload)
	if Spring.IsReplay() then
		return
	end
	-- The replay records everything we send over the network, so the client can read this after the game.
	Spring.SendLuaRulesMsg(SYNC_ACTION .. ":" .. payload)
end

function gadget:Initialize()
	gadgetHandler:AddSyncAction(SYNC_ACTION, savePersistentVariablesToDemo)
end

function gadget:Shutdown()
	gadgetHandler:RemoveSyncAction(SYNC_ACTION)
end
