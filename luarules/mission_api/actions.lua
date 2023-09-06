local trackedUnits = GG['MissionAPI'].TrackedUnits

local function sendMessage(message)
	Spring.Echo(message)
end

local function spawnUnits(nickname, unitDefName, quantity, x, y, z)
	y = y or Spring.GetGroundHeight(x, z)

	local unitId = Spring.CreateUnit(unitDefName, x, y, z, "south", 0)

	if unitId and nickname then
		trackedUnits[nickname] = unitId
		trackedUnits[unitId] = nickname
	end
end

local function despawnUnits(nickname, unitId)
	unitId = trackedUnits[nickname] or unitId
	nickname = trackedUnits[unitId]

	trackedUnits[nickname] = nil
	trackedUnits[unitId] = nil

	Spring.DestroyUnit(unitId, false, true)
end

return {
	SendMessage = sendMessage,
	SpawnUnits = spawnUnits,
	DespawnUnits = despawnUnits,
}