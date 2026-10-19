---
--- Cutscenes: a game pause while a video plays, or a scripted control session.
---

-- STUB: Scripted control where units act out a script under Lua control is not implemented.
local function startScriptedControl(scriptID)
	Spring.Log(
		"cutscenes.lua",
		LOG.WARNING,
		"[Mission API] Scripted control is not implemented, skipping: " .. scriptID
	)
end

-- A replaced video still calls onVideoFinished, so count the videos and unpause after the last one ends.
local playingVideoCount = 0

local function onVideoFinished()
	playingVideoCount = playingVideoCount - 1
	if playingVideoCount == 0 then
		GG.GamePause.Unpause("cutscene")
	end
end

local function startCutscene(cutsceneID, skippable)
	local cutscene = GG["MissionAPI"].Cutscenes[cutsceneID]
	if cutscene.videoFile ~= nil then
		if not GG.VideoPlayback then
			error(
				"[Mission API] Video playback unavailable (api_video_playback.lua gadget not loaded), cannot play: "
					.. cutscene.videoFile
			)
		end

		playingVideoCount = playingVideoCount + 1
		GG.GamePause.Pause("cutscene")
		GG.VideoPlayback.Play(cutscene.videoFile, onVideoFinished, skippable)
	else
		startScriptedControl(cutscene.script)
	end
end

local function skipCutscene()
	if playingVideoCount > 0 then
		GG.VideoPlayback.Stop()
	end
end

return {
	StartCutscene = startCutscene,
	SkipCutscene = skipCutscene,
}
