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

-- provides:
--   GG.VideoPlayback.Play(videoFile, onFinished, skippable)
--   GG.VideoPlayback.Stop()
-- onFinished runs once per Play: when the video ends, when another Play starts, or when the game unpauses.
-- LuaUI: register VideoPlayback(playbackID, videoFile, skippable); send "VideoPlaybackFinished:<playbackID>" when done.
-- LuaUI: register VideoPlaybackStop(playbackID): The video is over (for any reason), so stop showing it.
-- LuaUI: send "VideoPlaybackSkip:<playbackID>" to skip a skippable video.
-- TODO: Playback is a stub. There is no player yet.

local SYNC_ACTION = "VideoPlayback"
local SYNC_ACTION_STOP = SYNC_ACTION .. "Stop"
local MESSAGE_FINISHED = SYNC_ACTION .. "Finished:"
local MESSAGE_TRY_SKIP = SYNC_ACTION .. "Skip:"

if gadgetHandler:IsSyncedCode() then
	local playbackCount = 0
	local onPlaybackFinished ---@type fun()?
	local playbackVideoFile ---@type string
	local playbackSkippable = false
	local playbackShown = false
	local gamePaused = false

	local function showPlayback()
		playbackShown = true
		SendToUnsynced(SYNC_ACTION, playbackCount, playbackVideoFile, playbackSkippable)
	end

	local function play(videoFile, onFinished, skippable)
		local replacedOnFinished = onPlaybackFinished
		if replacedOnFinished ~= nil then
			SendToUnsynced(SYNC_ACTION_STOP, playbackCount)
		end
		playbackCount = playbackCount + 1
		onPlaybackFinished = onFinished
		playbackVideoFile = videoFile
		playbackSkippable = skippable == true
		playbackShown = false
		if gamePaused then
			showPlayback()
		end
		if replacedOnFinished ~= nil then
			replacedOnFinished()
		end
	end

	local function finishPlayback(playbackID)
		if playbackID ~= playbackCount or onPlaybackFinished == nil then
			return false
		end
		local onFinished = onPlaybackFinished
		onPlaybackFinished = nil
		SendToUnsynced(SYNC_ACTION_STOP, playbackID)
		onFinished()
		return true
	end

	local function stop()
		finishPlayback(playbackCount)
	end

	GG.VideoPlayback = {
		Play = play,
		Stop = stop,
	}

	local function isSpectator(playerID)
		return select(3, Spring.GetPlayerInfo(playerID, false)) == true
	end

	function gadget:GamePaused(playerID, paused)
		gamePaused = paused
		if onPlaybackFinished == nil then
			return
		elseif paused and not playbackShown then
			showPlayback()
		elseif not paused and playbackShown then
			finishPlayback(playbackCount)
		end
	end

	function gadget:RecvLuaMsg(message, playerID)
		if message:sub(1, #SYNC_ACTION) ~= SYNC_ACTION then
			return
		end

		if message:sub(1, #MESSAGE_FINISHED) == MESSAGE_FINISHED then
			if not isSpectator(playerID) then
				finishPlayback(tonumber(message:sub(#MESSAGE_FINISHED + 1)))
			end
			return true
		elseif message:sub(1, #MESSAGE_TRY_SKIP) == MESSAGE_TRY_SKIP then
			if playbackSkippable and not isSpectator(playerID) then
				finishPlayback(tonumber(message:sub(#MESSAGE_TRY_SKIP + 1)))
			end
			return true
		end
	end

	function gadget:Shutdown()
		GG.VideoPlayback = nil
	end
else
	local function play(_, playbackID, videoFile, skippable)
		if Script.LuaUI(SYNC_ACTION) then
			Script.LuaUI[SYNC_ACTION](playbackID, videoFile, skippable)
		else
			Spring.Log("Video playback", LOG.WARNING, "No widget plays videos, skipping: " .. videoFile)
			Spring.SendLuaRulesMsg(MESSAGE_FINISHED .. playbackID)
		end
	end

	local function stop(_, playbackID)
		if Script.LuaUI(SYNC_ACTION_STOP) then
			Script.LuaUI[SYNC_ACTION_STOP](playbackID)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction(SYNC_ACTION, play)
		gadgetHandler:AddSyncAction(SYNC_ACTION_STOP, stop)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction(SYNC_ACTION)
		gadgetHandler:RemoveSyncAction(SYNC_ACTION_STOP)
	end
end
