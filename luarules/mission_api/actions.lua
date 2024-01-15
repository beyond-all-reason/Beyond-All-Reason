--============================================================--

local trackedUnits = GG['MissionAPI'].TrackedUnits
local triggers = GG['MissionAPI'].Triggers

--============================================================--

-- Triggers

--============================================================--

local function enableTrigger(triggerId)
	triggers[triggerId].settings.active = true
end

----------------------------------------------------------------

local function disableTrigger(triggerId)
	triggers[triggerId].settings.active = false
end

--============================================================--

-- Units

--============================================================--

local function spawnUnits(name, unitDefName, quantity, x, y, z)
	y = y or Spring.GetGroundHeight(x, z)

	local unitId = -1
	if quantity == 1 then
		unitId = Spring.CreateUnit(unitDefName, x, y, z, "south", 0)

		if unitId and name then
			trackedUnits[name] = unitId
			trackedUnits[unitId] = name
		end
	else
		trackedUnits[name] = {}
		for i = 1, quantity do
			unitId = Spring.CreateUnit(unitDefName, x, y, z, "south", 0)

			if unitId and name then
				trackedUnits[name][#trackedUnits[name] + 1] = unitId
				trackedUnits[unitId] = name
			end
		end
	end
end

----------------------------------------------------------------

local function despawnUnits(name)
	if type(trackedUnits[name] == 'number') then
		local unitId = trackedUnits[name]

		if unitId then
			trackedUnits[name] = nil
			trackedUnits[unitId] = nil

			Spring.DestroyUnit(unitId, false, true)
		end
	elseif type(trackedUnits[name] == 'table') then
		for _, id in ipairs(trackedUnits[name]) do
			Spring.DestroyUnit(id)
			trackedUnits[id] = nil
		end
		trackedUnits[name] = nil
	end
		
end

--============================================================--

-- Media

--============================================================--

local function sendMessage(message)
	Spring.Echo(message)
end

--============================================================--

return {
	-- Triggers
	EnableTrigger = enableTrigger,
	DisableTrigger = disableTrigger,

	-- Orders

	-- Build Options

	-- Units
	SpawnUnits = spawnUnits,
	DespawnUnits = despawnUnits,

	-- Map

	-- Media
	SendMessage = sendMessage,

	-- Win Condition
}

--============================================================--