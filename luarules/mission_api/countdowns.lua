---
--- Countdown timers, ticked down by api_missions_triggers.lua every game frame.
---

-- timeRemaining stays a whole number of seconds and never goes negative.
local function sanitizeSeconds(seconds)
	return math.max(0, math.floor(seconds + 0.5))
end

---A live countdown, as it is held in GG['MissionAPI'].Countdowns.
---@class MissionCountdown
---@field id string
---@field timeRemaining integer whole seconds, never negative
---@field paused boolean
---@field displayed boolean
---@field buffered boolean? displayed only; held through its first tick
---@field tickPhase integer? non-displayed only; the frame % gameSpeed it ticks on

-- Displayed countdowns (the default) tick on the shared whole-second cadence;
-- non-displayed ones tick relative to their creation frame. See Decrement().
local function addCountdown(countdownID, seconds, displayed)
	displayed = displayed ~= false
	GG["MissionAPI"].Countdowns[countdownID] = {
		id = countdownID,
		timeRemaining = sanitizeSeconds(seconds),
		paused = false,
		displayed = displayed,
		buffered = displayed or nil, -- see Decrement()
		tickPhase = not displayed and Spring.GetGameFrame() % Game.gameSpeed or nil,
	}
end

local function cancelCountdown(countdownID)
	GG["MissionAPI"].Countdowns[countdownID] = nil
end

-- A countdown may already have ended or been cancelled by the time an action
-- fires, so operations on missing IDs are silent no-ops.
local function pauseCountdown(countdownID)
	local countdown = GG["MissionAPI"].Countdowns[countdownID]
	if countdown then
		countdown.paused = true
	end
end

local function unpauseCountdown(countdownID)
	local countdown = GG["MissionAPI"].Countdowns[countdownID]
	if countdown then
		countdown.paused = false
	end
end

local function setTime(countdownID, seconds)
	local countdown = GG["MissionAPI"].Countdowns[countdownID]
	if countdown then
		countdown.timeRemaining = sanitizeSeconds(seconds)
		-- A set time restarts the countdown: a displayed one is held through its
		-- first tick again, a non-displayed one restarts its cadence from now.
		-- The relative AddTime and RemoveTime keep the current cadence instead.
		if countdown.displayed then
			countdown.buffered = true
		else
			countdown.tickPhase = Spring.GetGameFrame() % Game.gameSpeed
		end
	end
end

local function addTime(countdownID, seconds)
	local countdown = GG["MissionAPI"].Countdowns[countdownID]
	if countdown then
		countdown.timeRemaining = sanitizeSeconds(countdown.timeRemaining + seconds)
	end
end

local function removeTime(countdownID, seconds)
	local countdown = GG["MissionAPI"].Countdowns[countdownID]
	if countdown then
		countdown.timeRemaining = sanitizeSeconds(countdown.timeRemaining - seconds)
	end
end

-- Displayed countdowns tick on the same whole second, so their displayed times
-- change simultaneously instead of cascading by creation frame. A countdown
-- created just before a tick would then lose its first second almost
-- immediately, so each one is held through its first tick; this also gives the
-- player a moment to notice the new timer. Non-displayed countdowns have
-- nothing to synchronise, so they skip the hold and tick relative to their
-- creation frame, which makes their duration exact.
local function decrement(frameNumber)
	local countdowns = GG["MissionAPI"].Countdowns
	local gameSpeed = Game.gameSpeed
	local onWholeSecond = frameNumber % gameSpeed == 0
	local endedIDs = {}
	-- Each tick carries its new time, since ended countdowns are removed below
	-- before the caller can read them.
	local ticks = {}

	for countdownID, countdown in pairs(countdowns) do
		local dueToTick
		if countdown.displayed then
			dueToTick = onWholeSecond
		else
			dueToTick = frameNumber % gameSpeed == countdown.tickPhase
		end

		if dueToTick and not countdown.paused then
			if countdown.buffered then
				countdown.buffered = false
			else
				countdown.timeRemaining = countdown.timeRemaining - 1
				ticks[#ticks + 1] = { id = countdownID, timeRemaining = math.max(0, countdown.timeRemaining) }
				if countdown.timeRemaining <= 0 then
					endedIDs[#endedIDs + 1] = countdownID
				end
			end
		end
	end

	for _, countdownID in ipairs(endedIDs) do
		countdowns[countdownID] = nil
	end

	return endedIDs, ticks
end

return {
	AddCountdown = addCountdown,
	CancelCountdown = cancelCountdown,
	PauseCountdown = pauseCountdown,
	UnpauseCountdown = unpauseCountdown,
	SetTime = setTime,
	AddTime = addTime,
	RemoveTime = removeTime,
	Decrement = decrement,
}
