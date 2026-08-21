---
--- Utility module for playing sounds in a queue.
---

local nextSoundAt = 0

local function enqueueSound(soundfile, volume, position)
	local soundQueue = GG['MissionAPI'].soundQueue
	soundQueue[#soundQueue + 1] = {
		soundfile = soundfile,
		volume = volume,
		position = position,
		length = GG['MissionAPI'].soundFiles[soundfile]
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
	local soundQueue = GG['MissionAPI'].soundQueue

	if frameNumber < nextSoundAt or #soundQueue == 0 then
		return
	end

	local sound = table.remove(soundQueue, 1)
	Spring.SendLuaUIMsg("suspendNotifications " .. sound.length)
	nextSoundAt = frameNumber + (sound.length * Game.gameSpeed)
	playSound(sound.soundfile, sound.volume, sound.position)
end

return {
	EnqueueSound = enqueueSound,
	PlaySound = playSound,
	ProcessSoundQueue = processSoundQueue,
}
