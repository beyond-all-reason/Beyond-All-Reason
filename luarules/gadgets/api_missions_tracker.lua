--============================================================--

function gadget:GetInfo()
	return {
		name = "Mission API tracker",
		desc = "Tracks time, collisions, events etc. for the mission API",
		date = "2024.01",
		layer = 0,
		enabled = true,
	}
end

--============================================================--

if not gadgetHandler:IsSyncedCode() then
	return false
end

--============================================================--

local trackedUnits, trackedTimers, trackedColliders

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

-- COLLIDERS

----------------------------------------------------------------

local function addCollider(name, collider)
	if collider.__name ~= 'Collider' then
		Spring.Log('api_missions_tracker.lua', LOG.ERROR, string.format("[Mission API] Collider '%s' is not valid collider object", name))
		return
	end

	if not collider.validate or not collider.validate() then
		Spring.Log('api_missions_tracker.lua', LOG.ERROR, string.format("[Mission API] Collider '%s' failed validation", name))
		return
	end

	if trackedColliders[name] then
		Spring.Log('api_missions_tracker.lua', LOG.WARNING, string.format("[Mission API] Collider '%s' already exists. Overwriting..", name))
	end

	trackedColliders[name] = collider
end

----------------------------------------------------------------

local function removeCollider(name)
	trackedColliders[name] = nil
end

--============================================================--

local function pollTimers()
	for name, timer in pairs(trackedTimers) do
		timer.poll()
	end
end

----------------------------------------------------------------

local function pollColliders()
	for name, collider in pairs(trackedColliders) do
		collider.poll()
	end
end

--============================================================--

function gadget:Initialize()
	if not GG['MissionAPI'] then
		gadgetHandler:RemoveGadget()
		return
	end

	GG['MissionAPI'].tracker = {}

	GG['MissionAPI'].tracker.addTimer = addTimer
	GG['MissionAPI'].tracker.removeTimer = removeTimer

	GG['MissionAPI'].tracker.addCollider = addCollider
	GG['MissionAPI'].tracker.removeCollider = removeCollider

	GG['MissionAPI'].tracker.units = trackedUnits
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