---
--- Countdown timers, ticked down once per second by api_missions_triggers.lua.
---

-- timeRemaining stays a whole number of seconds and never goes negative.
local function sanitizeSeconds(seconds)
	return math.max(0, math.floor(seconds + 0.5))
end

local function addCountdown(countdownID, seconds)
	GG["MissionAPI"].Countdowns[countdownID] = {
		id = countdownID,
		timeRemaining = sanitizeSeconds(seconds),
		paused = false,
		buffered = true, -- see Decrement()
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

local function decrement()
	local countdowns = GG["MissionAPI"].Countdowns
	local endedIDs = {}

	for countdownID, countdown in pairs(countdowns) do
		if not countdown.paused then
			if countdown.buffered then
				-- All countdowns tick on the same global second, so their displayed
				-- times change simultaneously instead of cascading by creation frame.
				-- A countdown created just before a tick would then lose its first
				-- second almost immediately, so each one is held through its first
				-- tick. This also gives the player a moment to notice the new timer.
				countdown.buffered = false
			else
				countdown.timeRemaining = countdown.timeRemaining - 1
				if countdown.timeRemaining <= 0 then
					endedIDs[#endedIDs + 1] = countdownID
				end
			end
		end
	end

	for _, countdownID in ipairs(endedIDs) do
		countdowns[countdownID] = nil
	end

	return endedIDs
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
