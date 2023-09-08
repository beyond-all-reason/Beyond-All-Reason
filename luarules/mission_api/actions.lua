local trackedUnits = GG['MissionAPI'].TrackedUnits

local function sendMessage(message)
	Spring.Echo(message)
end

local function spawnUnits(name, unitDefName, quantity, x, y, z)
	y = y or Spring.GetGroundHeight(x, z)

	local unitId = Spring.CreateUnit(unitDefName, x, y, z, "south", 0)

	if unitId and name then
		trackedUnits[name] = unitId
		trackedUnits[unitId] = name
	end
end

local function despawnUnits(name)
	local unitId = trackedUnits[name]

	if unitId then
		trackedUnits[name] = nil
		trackedUnits[unitId] = nil

		Spring.DestroyUnit(unitId, false, true)
	end
end

return {
	SendMessage = sendMessage,
	SpawnUnits = spawnUnits,
	DespawnUnits = despawnUnits,
}