--============================================================--

function gadget:GetInfo()
	return {
		name = "Mission API tracker",
		desc = "Tracks time, collisions, events etc. for the mission API",
		date = "2024.01",
		layer = 1,
		enabled = true,
	}
end

--============================================================--

if not gadgetHandler:IsSyncedCode() then
	return false
end

--============================================================--

local trackedUnits, trackedTimers, trackedProximityMonitors

local currentFrame = 0

--============================================================--

-- TIMERS

----------------------------------------------------------------

local function addTimer(name, timer, start)
	if timer.__name ~= 'Timer' then
		Spring.Log('api_missions_tracker.lua', LOG.ERROR, string.format("[Mission API] Timer '%s' is not a valid timer", name))
		return
	end

	if not timer.validate or not timer.validate('api_missions_tracker.lua') then
		Spring.Log('api_missions_tracker.lua', LOG.ERROR, string.format("[Mission API] Timer '%s' failed validation", name))
		return
	end

	if trackedTimers[name] then
		Spring.Log('api_missions_tracker.lua', LOG.WARNING, string.format("[Mission API] Timer '%s' already exists. Overwriting..", name))
	end

	if start then timer.start() end

	trackedTimers[name] = timer
end

----------------------------------------------------------------

local function removeTimer(name)
	trackedTimers[name] = nil
end

----------------------------------------------------------------

local function startTimer(name)
	if not trackedTimers[name] then
		Spring.Log('api_missions_tracker.lua', LOG.WARNING, string.format("[Mission API] Attempted to start timer '%s' which doesn't exist", name))
		return
	end

	trackedTimers[name].start()
end

----------------------------------------------------------------

local function pauseTimer(name)
	if not trackedTimers[name] then
		Spring.Log('api_missions_tracker.lua', LOG.WARNING, string.format("[Mission API] Attempted to pause timer '%s' which doesn't exist", name))
		return
	end

	trackedTimers[name].pause()
end

----------------------------------------------------------------

local function stopTimer(name)
	if not trackedTimers[name] then
		Spring.Log('api_missions_tracker.lua', LOG.WARNING, string.format("[Mission API] Attempted to stop timer '%s' which doesn't exist", name))
		return
	end

	trackedTimers[name].stop()
end

----------------------------------------------------------------

-- PROXIMITY MONITORS

----------------------------------------------------------------

local function addProximityMonitor(name, proximityMonitor)
	if proximityMonitor.__name ~= 'Proximity Monitor' then
		Spring.Log('api_missions_tracker.lua', LOG.ERROR, string.format("[Mission API] Proximity Monitor '%s' is not a valid proximity monitor object", name))
		return
	end

	if not proximityMonitor.validate or not proximityMonitor.validate() then
		Spring.Log('api_missions_tracker.lua', LOG.ERROR, string.format("[Mission API] Proximity Monitor '%s' failed validation", name))
		return
	end

	if trackedProximityMonitors[name] then
		Spring.Log('api_missions_tracker.lua', LOG.WARNING, string.format("[Mission API] Proximity Monitor '%s' already exists. Overwriting..", name))
	end

	trackedProximityMonitors[name] = proximityMonitor
end

----------------------------------------------------------------

local function removeProximityMonitor(name)
	trackedProximityMonitors[name] = nil
end

--============================================================--

local function pollTimers()
	for name, timer in pairs(trackedTimers) do
		timer.poll()
	end
end

----------------------------------------------------------------

local function pollProximityMonitors()
	for name, proximityMonitor in pairs(trackedProximityMonitors) do
		proximityMonitor.poll()
	end
end

--============================================================--

function gadget:Initialize()
	if not GG['MissionAPI'] then
		gadgetHandler:RemoveGadget()
		return
	end

	GG['MissionAPI'].Tracker = {}

	GG['MissionAPI'].Tracker.addTimer = addTimer
	GG['MissionAPI'].Tracker.removeTimer = removeTimer

	GG['MissionAPI'].Tracker.addProximityMonitor = addProximityMonitor
	GG['MissionAPI'].Tracker.removeProximityMonitor = removeProximityMonitor

	--GG['MissionAPI'].Tracker.units = trackedUnits
end

----------------------------------------------------------------

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if GG['MissionAPI'].Types.Unit.teamIsTeam(unitTeam, Spring.ALLY_UNITS) then
		statistics.lost = statistics.lost + 1
	else
		statistics.killed = statistics.killed + 1
	end
end

--============================================================--