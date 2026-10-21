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
			unitIDs[index] =
				assert(Spring.CreateUnit(unitName, x, Spring.GetGroundHeight(x, z) + altitude, z, "east", teamID))
		end
		return unitIDs
	end

	local centerZ = Game.mapSizeZ / 2
	local sourceIDs = createGrid("armfig", 1000, Game.mapSizeX * 0.25, centerZ, 40, 30, 450, 0)
	local targetIDs = createGrid("armthund", 200, Game.mapSizeX * 0.55, centerZ, 20, 48, 500, 1)
	Spring.GiveOrderToUnitArray(targetIDs, CMD.FIRE_STATE, { 0 }, 0)
	Spring.GiveOrderToUnitArray(targetIDs, CMD.MOVE_STATE, { 0 }, 0)
	return sourceIDs, targetIDs
end

function test()
	local sourceIDs, targetIDs = SyncedRun(createScenario)
	local _, _, _, _, _, _, syncedMemoryBefore = Spring.GetLuaMemUsage()
	Spring.GiveOrderToUnitArray(sourceIDs, GameCMD.ATTACK_TARGETS, targetIDs, 0)
	Test.waitUntil(function()
		local queue = Spring.GetUnitCommands(sourceIDs[1], -1)
		return #queue == 2
			and queue[1].id == CMD.ATTACK
			and queue[2].id == GameCMD.ATTACK_TARGETS
			and #queue[2].params == 1
	end, 120)

	Test.waitFrames(1500)
	local _, _, _, _, _, _, syncedMemoryAfter = Spring.GetLuaMemUsage()
	local aliveTargets = 0
	for index = 1, #targetIDs do
		if Spring.ValidUnitID(targetIDs[index]) and not Spring.GetUnitIsDead(targetIDs[index]) then
			aliveTargets = aliveTargets + 1
		end
	end
	Spring.Echo(
		string.format(
			"[Shared Attack Targets Combat] sources=%d targets=%d alive_targets=%d frames=%d synced_lua_delta_kb=%.1f",
			#sourceIDs,
			#targetIDs,
			aliveTargets,
			1500,
			syncedMemoryAfter - syncedMemoryBefore
		)
	)
end

return {
	skip = skip,
	setup = setup,
	test = test,
	cleanup = cleanup,
}
