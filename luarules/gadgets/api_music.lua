local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Music API for Gadgets",
		desc = "Allows gadgets to communicate with the music player",
		date = "2026",
		layer = 1,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	function gadget:Initialize()
		gadgetHandler:AddSyncAction("GadgetPlayMusicTrack", BroadcastEvent)
	end

	function BroadcastEvent(_, trackFilePath)
		if Script.LuaUI("GadgetPlayMusicTrack") then
			Script.LuaUI.GadgetPlayMusicTrack(trackFilePath)
		end
	end
end

GG.music = {}

---@param trackFilePath string Full Path to music track
GG.music.GadgetPlayMusicTrack = function(trackFilePath)
	if gadgetHandler:IsSyncedCode() then
		SendToUnsynced("GadgetPlayMusicTrack", trackFilePath)
	else
		BroadcastEvent("GadgetPlayMusicTrack", trackFilePath)
	end
end
