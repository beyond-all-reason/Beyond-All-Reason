function scenario_arguments()
	return {
		{ sourceCount = 1000 },
		{ targetCount = 200 },
		{ observationFrames = 300 },
	}
end

function skip()
	return Spring.GetGameFrame() <= 0
		or GameCMD.UNIT_SET_TARGET == nil
		or select(1, Spring.GetTeamInfo(1, false)) == nil
end

function setup()
	Test.clearMap()
end

function cleanup()
	Spring.SelectUnitArray({})
	Test.clearMap()
end

local function createScenario(locals)
	local function createGrid(unitName, count, centerX, centerZ, columns, spacing, altitude, teamID)
		local unitIDs = {}
		local rows = math.ceil(count / columns)
		local startX = centerX - (columns - 1) * spacing / 2
		local startZ = centerZ - (rows - 1) * spacing / 2
		for index = 1, count do
			local column = (index - 1) % columns
			local row = math.floor((index - 1) / columns)
			local x = startX + column * spacing
			local z = startZ + row * spacing
			local y = Spring.GetGroundHeight(x, z) + altitude
			unitIDs[index] = assert(Spring.CreateUnit(unitName, x, y, z, "south", teamID))
		end
		return unitIDs
	end

	local centerZ = Game.mapSizeZ / 2
	local targetX = Game.mapSizeX * 0.65
	local sourceIDs = createGrid("armfig", locals.sourceCount, Game.mapSizeX * 0.25, centerZ, 40, 30, 450, 0)
	local targetIDs = createGrid("corhurc", locals.targetCount, targetX, centerZ, 20, 48, 500, 1)
	Spring.GiveOrderToUnitArray(sourceIDs, CMD.FIRE_STATE, { 0 }, 0)
	Spring.GiveOrderToUnitArray(sourceIDs, CMD.MOVE_STATE, { 0 }, 0)
	Spring.GiveOrderToUnitArray(targetIDs, CMD.FIRE_STATE, { 0 }, 0)
	Spring.GiveOrderToUnitArray(targetIDs, CMD.MOVE_STATE, { 0 }, 0)
	Spring.CreateUnit("armarad", targetX, Spring.GetGroundHeight(targetX, centerZ), centerZ, 0, 0)
	return sourceIDs, targetIDs, targetX, centerZ
end

local function issueSetTarget(locals)
	Spring.GiveOrderToUnitArray(
		locals.sourceIDs,
		locals.setTargetCommandID,
		{ locals.targetX, Spring.GetGroundHeight(locals.targetX, locals.targetZ), locals.targetZ, 1000 },
		0
	)
	local queuedCommands = 0
	for index = 1, #locals.sourceIDs do
		queuedCommands = queuedCommands + #(Spring.GetUnitCommands(locals.sourceIDs[index], -1) or {})
	end
	return queuedCommands
end

function test()
	local sourceCount = Scenario.sourceCount
	local targetCount = Scenario.targetCount
	local setTargetCommandID = GameCMD.UNIT_SET_TARGET
	local sourceIDs, targetIDs, targetX, targetZ = SyncedRun(createScenario)
	assertEqual(#sourceIDs, sourceCount, "source fighter count")
	assertEqual(#targetIDs, targetCount, "target bomber count")

	Test.waitFrames(1)
	local _, _, _, _, _, _, syncedMemoryBefore = Spring.GetLuaMemUsage()
	local issueTimer = Spring.GetTimerMicros()
	local queuedCommands = SyncedRun(issueSetTarget)
	local issueMilliseconds = Spring.DiffTimers(Spring.GetTimerMicros(), issueTimer, nil, true) * 1000
	Test.waitFrames(1)
	local _, _, _, _, _, _, syncedMemoryAfter = Spring.GetLuaMemUsage()

	Spring.Echo(
		string.format(
			"[Shared Target List] sources=%d targets=%d call_ms=%.3f queued_commands=%d synced_lua_delta_kb=%.1f",
			#sourceIDs,
			#targetIDs,
			issueMilliseconds,
			queuedCommands,
			syncedMemoryAfter - syncedMemoryBefore
		)
	)
	assertEqual(queuedCommands, 0, "Set Target should remain state rather than queued engine commands")

	local observationTimer = Spring.GetTimerMicros()
	Test.waitFrames(Scenario.observationFrames)
	local observationMilliseconds = Spring.DiffTimers(Spring.GetTimerMicros(), observationTimer, nil, true) * 1000
	Spring.Echo(
		string.format(
			"[Shared Target List] observation frames=%d wall_ms=%.1f frame=%d",
			Scenario.observationFrames,
			observationMilliseconds,
			Spring.GetGameFrame()
		)
	)
end

return {
	skip = skip,
	setup = setup,
	test = test,
	cleanup = cleanup,
	scenario_arguments = scenario_arguments,
}
