---
--- Utility module for playing sounds in a queue.
---

local nextSoundAt = 0
local playingQueuedSoundfile

local function enqueueSound(soundfile, volume, position)
	local soundQueue = GG["MissionAPI"].soundQueue
	soundQueue[#soundQueue + 1] = {
		soundfile = soundfile,
		volume = volume,
		position = position,
		length = GG["MissionAPI"].soundFiles[soundfile],
	}
end

local function playSound(soundfile, volume, position)
	volume = volume or 1.0
	if position then
		Spring.PlaySoundFile(soundfile, volume, position.x, position.y, position.z)
	else
		Spring.PlaySoundFile(soundfile, volume)
	end
end

local function processSoundQueue(frameNumber)
	local soundQueue = GG["MissionAPI"].soundQueue

	if frameNumber < nextSoundAt then
		return
	end
	playingQueuedSoundfile = nil
	if #soundQueue == 0 then
		return
	end

	local sound = table.remove(soundQueue, 1)
	Spring.SendLuaUIMsg("suspendNotifications " .. sound.length)
	nextSoundAt = frameNumber + (sound.length * Game.gameSpeed)
	playingQueuedSoundfile = sound.soundfile
	playSound(sound.soundfile, sound.volume, sound.position)
end

-- Stops the sound while it plays; queued ones still play. Older engines cannot stop a sample.
local function stopSound(soundfile)
	if not Spring.StopSoundByFilename then
		return
	end
	Spring.StopSoundByFilename(soundfile)
	if playingQueuedSoundfile == soundfile then
		playingQueuedSoundfile = nil
		nextSoundAt = 0
	end
end

return {
	EnqueueSound = enqueueSound,
	PlaySound = playSound,
	ProcessSoundQueue = processSoundQueue,
	StopSound = stopSound,
}
