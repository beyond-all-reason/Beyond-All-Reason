---
--- Countdown timers, ticked down globally once per second.
---
--- A single Decrement() call ticks every unpaused countdown at once, rather
--- than each countdown ticking relative to its own creation frame, so that all
--- displayed times change their values simultaneously. A newly added countdown
--- could then lose its first second almost immediately (a 10 second countdown
--- created just before a tick would show 9 after one frame), so it is held for
--- one tick before it starts counting down. This also gives the player a
--- moment to notice the newly added UI element.
---
--- A countdown ends when it ticks down to 0. Decrement() removes it and
--- returns its ID, so the caller (api_missions_triggers.lua) can activate
--- countdown triggers. CancelCountdown() removes a countdown without it
--- triggering any triggers.
---

local function logWarning(operation, message)
	Spring.Log("countdowns.lua", LOG.WARNING, "[Mission API] " .. operation .. ": " .. message)
end

local function getCountdown(operation, countdownID)
	local countdown = GG["MissionAPI"].Countdowns[countdownID]
	if not countdown then
		logWarning(operation, "no countdown with ID: " .. tostring(countdownID))
	end
	return countdown
end

-- These functions are also called directly (Custom actions, other gadgets),
-- bypassing mission validation, so bad arguments must not raise synced errors.
local function validSeconds(operation, seconds)
	if type(seconds) ~= "number" then
		logWarning(operation, "seconds must be a number, got " .. type(seconds))
		return false
	end
	return true
end

-- timeRemaining stays a whole number of seconds and never goes negative.
local function sanitizeSeconds(seconds)
	return math.max(0, math.floor(seconds + 0.5))
end

local function addCountdown(countdownID, seconds)
	if type(countdownID) ~= "string" then
		logWarning("AddCountdown", "countdownID must be a string, got " .. type(countdownID))
		return
	end
	if not validSeconds("AddCountdown", seconds) then
		return
	end
	if GG["MissionAPI"].Countdowns[countdownID] then
		logWarning("AddCountdown", "replacing existing countdown: " .. countdownID)
	end

	GG["MissionAPI"].Countdowns[countdownID] = {
		id = countdownID,
		timeRemaining = sanitizeSeconds(seconds),
		paused = false,
		buffered = true, -- held through its first tick; see header
	}
end

local function cancelCountdown(countdownID)
	if getCountdown("CancelCountdown", countdownID) then
		GG["MissionAPI"].Countdowns[countdownID] = nil
	end
end

local function pauseCountdown(countdownID)
	local countdown = getCountdown("PauseCountdown", countdownID)
	if countdown then
		countdown.paused = true
	end
end

local function unpauseCountdown(countdownID)
	local countdown = getCountdown("UnpauseCountdown", countdownID)
	if countdown then
		countdown.paused = false
	end
end

local function setTime(countdownID, seconds)
	local countdown = getCountdown("SetTime", countdownID)
	if countdown and validSeconds("SetTime", seconds) then
		countdown.timeRemaining = sanitizeSeconds(seconds)
	end
end

local function addTime(countdownID, seconds)
	local countdown = getCountdown("AddTime", countdownID)
	if countdown and validSeconds("AddTime", seconds) then
		countdown.timeRemaining = sanitizeSeconds(countdown.timeRemaining + seconds)
	end
end

local function removeTime(countdownID, seconds)
	local countdown = getCountdown("RemoveTime", countdownID)
	if countdown and validSeconds("RemoveTime", seconds) then
		countdown.timeRemaining = sanitizeSeconds(countdown.timeRemaining - seconds)
	end
end

--- Subtract 1 second from every countdown that is not paused. Countdowns that
--- reach 0 are removed, and their IDs returned for triggering.
local function decrement()
	local countdowns = GG["MissionAPI"].Countdowns
	local endedIDs = {}

	for countdownID, countdown in pairs(countdowns) do
		if not countdown.paused then
			if countdown.buffered then
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
