local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Video Playback",
		desc = "Lets synced code play video files and determine when they end",
		date = "2026-10",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- provides GG.VideoPlayback.Play(videoFile, onFinished)
-- onFinished runs once per Play: when the video ends, or when another Play replaces it.
-- TODO: Playback is a stub. There is no player yet.

local SYNC_ACTION = "VideoPlayback"
local MESSAGE_FINISHED = SYNC_ACTION .. "Finished:"

-- Only the pause controller's report counts; it arrives after its own pause request.
local getPauseControllerID = VFS.Include("luarules/gadgets/include/pause_controller.lua").GetPauseControllerID

if gadgetHandler:IsSyncedCode() then
	local playbackCount = 0
	local onPlaybackFinished

	local function play(videoFile, onFinished)
		local replacedOnFinished = onPlaybackFinished
		playbackCount = playbackCount + 1
		onPlaybackFinished = onFinished
		SendToUnsynced(SYNC_ACTION, playbackCount, videoFile)
		if replacedOnFinished ~= nil then
			replacedOnFinished()
		end
	end

	GG.VideoPlayback = {
		Play = play,
	}

	function gadget:RecvLuaMsg(message, playerID)
		if message:sub(1, #MESSAGE_FINISHED) ~= MESSAGE_FINISHED then
			return
		end
		if playerID ~= getPauseControllerID() then
			return true
		end

		local playbackID = tonumber(message:sub(#MESSAGE_FINISHED + 1))
		if playbackID == playbackCount and onPlaybackFinished ~= nil then
			local onFinished = onPlaybackFinished
			onPlaybackFinished = nil
			onFinished()
		end
		return true
	end

	function gadget:Shutdown()
		GG.VideoPlayback = nil
	end
else
	local spSendLuaRulesMsg = Spring.SendLuaRulesMsg
	local spGetMyPlayerID = Spring.GetMyPlayerID

	local function play(_, playbackID, videoFile)
		Spring.Log("Video playback", LOG.WARNING, "Video playback is not implemented, skipping: " .. videoFile)
		if getPauseControllerID() == spGetMyPlayerID() and not Spring.IsReplay() then
			spSendLuaRulesMsg(MESSAGE_FINISHED .. playbackID)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction(SYNC_ACTION, play)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction(SYNC_ACTION)
	end
end
