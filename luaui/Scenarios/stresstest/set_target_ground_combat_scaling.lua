---@diagnostic disable: unnecessary-assert

function skip()
	return Spring.GetGameFrame() <= 0 or select(1, Spring.GetTeamInfo(1, false)) == nil
end

function setup()
	Test.clearMap()
end

function cleanup()
	Spring.SelectUnitArray({})
	Test.clearMap()
end

local function createScenario()
	local function createGrid(unitName, count, centerX, centerZ, columns, spacing, teamID)
		local unitIDs = {}
		local rows = math.ceil(count / columns)
		local startX = centerX - (columns - 1) * spacing / 2
		local startZ = centerZ - (rows - 1) * spacing / 2
		for index = 1, count do
			local column = (index - 1) % columns
			local row = math.floor((index - 1) / columns)
			local x = startX + column * spacing
			local z = startZ + row * spacing
			unitIDs[index] = assert(Spring.CreateUnit(unitName, x, Spring.GetGroundHeight(x, z), z, "south", teamID))
		end
		return unitIDs
	end

	local centerX = Game.mapSizeX / 2
	local centerZ = Game.mapSizeZ / 2
	local targetIDs = createGrid("corfort", 500, centerX, centerZ, 25, 24, 1)
	local sourceIDs = createGrid("corak", 600, centerX - 420, centerZ, 30, 20, 0)
	local marauders = createGrid("armmar", 200, centerX + 420, centerZ, 20, 28, 0)
	for index = 1, #marauders do
		sourceIDs[#sourceIDs + 1] = marauders[index]
	end
	Spring.GiveOrderToUnitArray(sourceIDs, CMD.MOVE_STATE, { 0 }, 0)
	Spring.GiveOrderToUnitArray(targetIDs, CMD.FIRE_STATE, { 0 }, 0)
	return sourceIDs, targetIDs
end

function test()
	local sourceIDs, targetIDs = SyncedRun(createScenario)
	Test.waitFrames(1)
	local _, _, _, _, _, _, syncedMemoryBefore = Spring.GetLuaMemUsage()
	local issueTimer = Spring.GetTimerMicros()
	for index = 1, #targetIDs do
		Spring.GiveOrderToUnitArray(sourceIDs, GameCMD.UNIT_SET_TARGET, { targetIDs[index] }, CMD.OPT_SHIFT)
	end
	local issueMilliseconds = Spring.DiffTimers(Spring.GetTimerMicros(), issueTimer, nil, true) * 1000
	Test.waitFrames(300)
	local _, _, _, _, _, _, syncedMemoryAfter = Spring.GetLuaMemUsage()
	Spring.Echo(
		string.format(
			"[Ground Shared Target List] sources=%d targets=%d call_ms=%.3f synced_lua_delta_kb=%.1f",
			#sourceIDs,
			#targetIDs,
			issueMilliseconds,
			syncedMemoryAfter - syncedMemoryBefore
		)
	)

	Spring.GiveOrderToUnitArray(sourceIDs, CMD.STOP, {}, 0)
	Test.waitFrames(5)
	Spring.SelectUnitArray(sourceIDs)
	local areaCommandFilter = Test.prepareWidget("Area Command Filter")
	assert(areaCommandFilter, "Area Command Filter should load")
	local centerX = Game.mapSizeX / 2
	local centerZ = Game.mapSizeZ / 2
	local handled = areaCommandFilter:CommandNotify(
		GameCMD.UNIT_SET_TARGET,
		{ centerX, Spring.GetGroundHeight(centerX, centerZ), centerZ, 1000 },
		{}
	)
	assertEqual(handled, true, "plain Set Target area should use the compact target-list command")
	Test.waitFrames(10)
end

return {
	skip = skip,
	setup = setup,
	test = test,
	cleanup = cleanup,
}
