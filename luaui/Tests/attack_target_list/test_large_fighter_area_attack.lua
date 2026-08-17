local areaAttackWidgetName = "Area Command Filter"

function skip()
	return CMD.ATTACK_TARGETS == nil or GameCMD.UNIT_SET_TARGETS == nil or select(1, Spring.GetTeamInfo(1, false)) == nil
end

function setup()
	Test.clearMap()
end

function cleanup()
	Spring.SelectUnitArray({})
	Test.clearMap()
end

function test()
	local sourceCount = 600
	local enemyFighterCount = 400
	local bomberCount = 200
	local centerX = Game.mapSizeX / 2
	local centerZ = Game.mapSizeZ / 2
	local sourceX = Game.mapSizeX * 0.2
	local bomberX = centerX + 350
	local enemyFighterX = bomberX + 1200
	local areaRadius = 1800
	local cancelTargetCommand = GameCMD.UNIT_CANCEL_TARGET
	local stopCommand = CMD.STOP

	local sourceIDs, enemyFighterIDs, bomberIDs = SyncedRun(function(locals)
		local function createGrid(unitName, count, centerX, centerZ, columns, spacing, teamID)
			local unitIDs = {}
			local rows = math.ceil(count / columns)
			local startX = centerX - (columns - 1) * spacing / 2
			local startZ = centerZ - (rows - 1) * spacing / 2

			for i = 1, count do
				local column = (i - 1) % columns
				local row = math.floor((i - 1) / columns)
				local x = startX + column * spacing
				local z = startZ + row * spacing
				local y = Spring.GetGroundHeight(x, z) + 450
				unitIDs[i] = assert(Spring.CreateUnit(unitName, x, y, z, "south", teamID))
			end

			return unitIDs
		end

		local sourceIDs = createGrid(
			"armfig", locals.sourceCount, locals.sourceX, locals.centerZ, 30, 32, 0
		)
		for i = 1, #sourceIDs do
			local x, _, z = Spring.GetUnitPosition(sourceIDs[i])
			Spring.GiveOrderToUnit(sourceIDs[i], CMD.IDLEMODE, { 0 }, 0)
			Spring.GiveOrderToUnit(sourceIDs[i], CMD.MOVE, { x + 300, Spring.GetGroundHeight(x + 300, z) + 450, z }, 0)
		end
		local enemyFighterIDs = createGrid(
			"corveng", locals.enemyFighterCount, locals.enemyFighterX, locals.centerZ, 20, 32, 1
		)
		for i = 1, #enemyFighterIDs do
			local x, _, z = Spring.GetUnitPosition(enemyFighterIDs[i])
			Spring.GiveOrderToUnit(enemyFighterIDs[i], CMD.IDLEMODE, { 0 }, 0)
			Spring.GiveOrderToUnit(enemyFighterIDs[i], CMD.FIRE_STATE, { 0 }, 0)
			Spring.GiveOrderToUnit(enemyFighterIDs[i], CMD.MOVE, { x + 100, Spring.GetGroundHeight(x + 100, z) + 450, z }, 0)
		end
		local bomberIDs = createGrid(
			"corhurc", locals.bomberCount, locals.bomberX, locals.centerZ, 20, 64, 1
		)
		for i = 1, #bomberIDs do
			local x, _, z = Spring.GetUnitPosition(bomberIDs[i])
			Spring.SetUnitArmored(bomberIDs[i], true, 0)
			Spring.GiveOrderToUnit(bomberIDs[i], CMD.IDLEMODE, { 0 }, 0)
			Spring.GiveOrderToUnit(bomberIDs[i], CMD.PATROL, { x + 100, Spring.GetGroundHeight(x + 100, z) + 500, z }, 0)
		end

		return sourceIDs, enemyFighterIDs, bomberIDs
	end)

	assertEqual(#sourceIDs, sourceCount, "team 0 fighter count")
	assertEqual(#enemyFighterIDs, enemyFighterCount, "team 1 fighter count")
	assertEqual(#bomberIDs, bomberCount, "team 1 bomber count")
	assertEqual(#Spring.GetTeamUnits(0), sourceCount, "team 0 total unit count")
	assertEqual(#Spring.GetTeamUnits(1), enemyFighterCount + bomberCount, "team 1 total unit count")

	Test.waitFrames(600)
	local flightStates = SyncedRun(function(locals)
		local states = { sources = {}, bombers = {} }
		for i = 1, #locals.sourceIDs do
			local state = Spring.GetUnitMoveTypeData(locals.sourceIDs[i]).aircraftState
			states.sources[state] = (states.sources[state] or 0) + 1
		end
		for i = 1, #locals.bomberIDs do
			local state = Spring.GetUnitMoveTypeData(locals.bomberIDs[i]).aircraftState
			states.bombers[state] = (states.bombers[state] or 0) + 1
		end
		return states
	end)
	assertEqual(flightStates.sources.flying, sourceCount, "source flight states: " .. table.toString(flightStates.sources))
	assertEqual(
		(flightStates.bombers.flying or 0) + (flightStates.bombers.landed or 0),
		bomberCount,
		"bomber flight states: " .. table.toString(flightStates.bombers)
	)
	assert((flightStates.bombers.flying or 0) >= 190, "expected the bomber formation to be airborne: " .. table.toString(flightStates.bombers))
	Spring.SelectUnitArray(sourceIDs)
	Test.waitFrames(1)
	local realTraceScreenRay = Spring.TraceScreenRay
	Spring.TraceScreenRay = function()
		return "unit", bomberIDs[1]
	end
	areaAttackWidget = Test.prepareWidget(areaAttackWidgetName)
	Spring.TraceScreenRay = realTraceScreenRay
	assert(areaAttackWidget)
	assert(Spring.FindUnitCmdDesc(sourceIDs[1], GameCMD.UNIT_SET_TARGETS), "source fighter has no set-target-list command descriptor")

	local handled = areaAttackWidget:CommandNotify(
		GameCMD.UNIT_SET_TARGET,
		{ bomberX, Spring.GetGroundHeight(bomberX, centerZ), centerZ, areaRadius },
		{ alt = true }
	)
	assertEqual(handled, true, "area set target should be replaced with a target-list command")
	Test.waitFrames(10)

	local bomberSet = {}
	for i = 1, #bomberIDs do
		bomberSet[bomberIDs[i]] = true
	end

	local setTargetsValid, setTargetsError = SyncedRun(function(locals)
		local expectedTargets = {}
		for i = 1, #locals.bomberIDs do
			expectedTargets[locals.bomberIDs[i]] = true
		end

		for i = 1, #locals.sourceIDs do
			local targetList = GetUnitSetTargetList(locals.sourceIDs[i])
			if not targetList then
				return false, "source fighter " .. i .. " has no set-target list"
			end
			if #targetList ~= locals.bomberCount then
				return false, "source fighter " .. i .. " set-target count: expected " .. locals.bomberCount .. ", got " .. #targetList
			end

			local seenTargets = {}
			for j = 1, #targetList do
				local targetID = targetList[j].target
				if not expectedTargets[targetID] then
					return false, "source fighter " .. i .. " received a non-bomber set target"
				end
				if seenTargets[targetID] then
					return false, "source fighter " .. i .. " received a duplicate set target"
				end
				seenTargets[targetID] = true
			end
		end

		return true
	end)
	assert(setTargetsValid, setTargetsError)

	-- Set Target only controls weapon targeting. Drive the fighters toward the
	-- selected bombers with a separate move order and verify the target list
	-- survives while that order is being executed.
	local moveOffsetX = bomberX - 300 - sourceX
	for i = 1, #sourceIDs do
		local x, _, z = Spring.GetUnitPosition(sourceIDs[i])
		local moveX = x + moveOffsetX
		Spring.GiveOrderToUnit(sourceIDs[i], CMD.MOVE, { moveX, Spring.GetGroundHeight(moveX, z) + 450, z }, 0)
	end
	Test.waitUntil(function()
		local queue = Spring.GetUnitCommands(sourceIDs[1], 1)
		return #queue == 1 and queue[1].id == CMD.MOVE
	end)
	Test.waitFrames(450)

	local setTargetsSurvivedMove, setTargetsMoveError = SyncedRun(function(locals)
		for i = 1, #locals.sourceIDs do
			local targetList = GetUnitSetTargetList(locals.sourceIDs[i])
			if not targetList or #targetList ~= locals.bomberCount then
				return false, "source fighter " .. i .. " lost its set-target list while moving"
			end
		end
		return true
	end)
	assert(setTargetsSurvivedMove, setTargetsMoveError)

	SyncedRun(function(locals)
		for i = 1, #locals.sourceIDs do
			Spring.GiveOrderToUnit(locals.sourceIDs[i], locals.cancelTargetCommand, {}, 0)
			Spring.GiveOrderToUnit(locals.sourceIDs[i], locals.stopCommand, {}, 0)
		end
	end)
	Test.waitFrames(30)
	local targetsCleared, targetsClearError = SyncedRun(function(locals)
		for i = 1, #locals.sourceIDs do
			local targetList = GetUnitSetTargetList(locals.sourceIDs[i])
			if targetList and #targetList > 0 then
				return false, "source fighter " .. i .. " retained set targets after cancel"
			end
		end
		return true
	end)
	assert(targetsCleared, targetsClearError)
	Test.waitFrames(15)

	handled = areaAttackWidget:CommandNotify(
		CMD.ATTACK,
		{ bomberX, Spring.GetGroundHeight(bomberX, centerZ), centerZ, areaRadius },
		{ alt = true }
	)
	assertEqual(handled, true, "area attack should be replaced with a target-list command")

	Test.waitUntil(function()
		local queue = Spring.GetUnitCommands(sourceIDs[1], -1)
		return queue and #queue == 1 and queue[1].id == CMD.ATTACK_TARGETS
	end)

	local queue = Spring.GetUnitCommands(sourceIDs[1], -1)
	assertEqual(#queue, 1, "representative source fighter command count")
	assertEqual(queue[1].id, CMD.ATTACK_TARGETS, "representative source fighter command ID")
	assertEqual(#queue[1].params, bomberCount, "representative source fighter target count")
	local seenTargets = {}
	for j = 1, #queue[1].params do
		local targetID = queue[1].params[j]
		assert(bomberSet[targetID], "representative source fighter received a non-bomber target")
		assert(not seenTargets[targetID], "representative source fighter received a duplicate target")
		seenTargets[targetID] = true
	end
	SyncedRun(function(locals)
		for i = 1, #locals.bomberIDs do
			Spring.SetUnitArmored(locals.bomberIDs[i], false, 1)
		end
	end)
	Test.waitFrames(1)

	local function countAlive(unitIDs)
		local alive = 0
		for i = 1, #unitIDs do
			if Spring.ValidUnitID(unitIDs[i]) and not Spring.GetUnitIsDead(unitIDs[i]) then
				alive = alive + 1
			end
		end
		return alive
	end

	for _ = 1, 18 do
		if countAlive(bomberIDs) == 0 or countAlive(sourceIDs) == 0 then
			break
		end
		Test.waitFrames(300)
	end
	local bombersAlive = countAlive(bomberIDs)
	local sourcesAlive = countAlive(sourceIDs)
	assertEqual(
		bombersAlive,
		0,
		"all explicitly targeted bombers should be destroyed before the fighter force is gone"
			.. " (bombers alive: " .. bombersAlive .. ", fighters alive: " .. sourcesAlive .. ")"
	)
end
