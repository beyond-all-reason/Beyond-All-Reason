local timers = GG['MissionAPI'].timers

local function setTimer(name)
	timers[name] = {
		frames = 0,
		paused = false,
	}
end

local function pauseTimer(name, paused)
	local timer = timers[name]
	if not timer then
		return
	end

	timer.paused = paused == nil or paused
end

local function removeTimer(name)
	timers[name] = nil
end

local function updateTimers()	-- called by GameFrame in the triggers gadget
	for _, timer in pairs(timers) do
		if not timer.paused then
			timer.frames = timer.frames + 1
		end
	end
end

local function getTimerFrames(name)
	local timer = timers[name]
	return timer and timer.frames
end

return {
	SetTimer       = setTimer,
	PauseTimer     = pauseTimer,
	RemoveTimer    = removeTimer,
	UpdateTimers   = updateTimers,
	GetTimerFrames = getTimerFrames,
}
