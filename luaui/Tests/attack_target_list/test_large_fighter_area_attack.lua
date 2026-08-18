local areaAttackWidgetName = "Area Command Filter"

function skip()
	return (CMD.ATTACK_TARGETS == nil and GameCMD.ATTACK_TARGETS == nil)
		or select(1, Spring.GetTeamInfo(1, false)) == nil
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
	local centerZ = Game.mapSizeZ / 2
	local sourceX = Game.mapSizeX * 0.2
	local bomberX = Game.mapSizeX / 2 + 350
	local enemyFighterX = bomberX + 1200
	local areaRadius = 1800
	local listCommandID = CMD.ATTACK_TARGETS or GameCMD.ATTACK_TARGETS
	local nativeTargetList = CMD.ATTACK_TARGETS ~= nil

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

		local function launchFormation(unitIDs, commandID, xOffset, altitude)
			Spring.GiveOrderToUnitArray(unitIDs, CMD.IDLEMODE, { 0 }, 0)
			for i = 1, #unitIDs do
				local x, _, z = Spring.GetUnitPosition(unitIDs[i])
				local destinationX = x + xOffset
				Spring.GiveOrderToUnit(
					unitIDs[i],
					commandID,
					{ destinationX, Spring.GetGroundHeight(destinationX, z) + altitude, z },
					0
				)
			end
		end

		local sourceIDs = createGrid("armfig", locals.sourceCount, locals.sourceX, locals.centerZ, 30, 32, 0)
		launchFormation(sourceIDs, CMD.MOVE, 300, 450)

		local enemyFighterIDs = createGrid(
			"corveng", locals.enemyFighterCount, locals.enemyFighterX, locals.centerZ, 20, 32, 1
		)
		Spring.GiveOrderToUnitArray(enemyFighterIDs, CMD.FIRE_STATE, { 0 }, 0)
		launchFormation(enemyFighterIDs, CMD.MOVE, 100, 450)

		local bomberIDs = createGrid("corhurc", locals.bomberCount, locals.bomberX, locals.centerZ, 20, 64, 1)
		for i = 1, #bomberIDs do
			Spring.SetUnitArmored(bomberIDs[i], true, 0)
		end
		launchFormation(bomberIDs, CMD.PATROL, 100, 500)

		return sourceIDs, enemyFighterIDs, bomberIDs
	end)

	assertEqual(#sourceIDs, sourceCount, "team 0 fighter count")
	assertEqual(#enemyFighterIDs, enemyFighterCount, "team 1 fighter count")
	assertEqual(#bomberIDs, bomberCount, "team 1 bomber count")
	assertEqual(#Spring.GetTeamUnits(0), sourceCount, "team 0 total unit count")
	assertEqual(#Spring.GetTeamUnits(1), enemyFighterCount + bomberCount, "team 1 total unit count")

	Test.waitFrames(600)
	local flightStates = SyncedRun(function(locals)
		local states = { bombers = {}, sources = {} }
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
	assert(
		(flightStates.bombers.flying or 0) >= 190,
		"expected the bomber formation to be airborne: " .. table.toString(flightStates.bombers)
	)

	Spring.SelectUnitArray(sourceIDs)
	Test.waitFrames(1)
	local realTraceScreenRay = Spring.TraceScreenRay
	Spring.TraceScreenRay = function()
		return "unit", bomberIDs[1]
	end
	areaAttackWidget = Test.prepareWidget(areaAttackWidgetName)
	Spring.TraceScreenRay = realTraceScreenRay
	assert(areaAttackWidget)

	local bomberSet = {}
	for i = 1, #bomberIDs do
		bomberSet[bomberIDs[i]] = true
	end

	local function issueAreaAttack()
		local handled = areaAttackWidget:CommandNotify(
			CMD.ATTACK,
			{ bomberX, Spring.GetGroundHeight(bomberX, centerZ), centerZ, areaRadius },
			{ alt = true }
		)
		assertEqual(handled, true, "area attack should be replaced with a target-list command")
	end

	local function getRepresentativeTargets()
		local queue = Spring.GetUnitCommands(sourceIDs[1], -1)
		if nativeTargetList then
			if #queue ~= 1 or queue[1].id ~= listCommandID or #queue[1].params ~= bomberCount then
				return nil
			end
			return queue[1].params, queue
		end

		if #queue ~= 2 or queue[1].id ~= CMD.ATTACK or queue[2].id ~= listCommandID then
			return nil
		end
		if #queue[1].params ~= 1 or #queue[2].params ~= bomberCount then
			return nil
		end
		if queue[1].params[1] ~= queue[2].params[1] then
			return nil
		end
		return queue[2].params, queue
	end

	issueAreaAttack()
	Test.waitUntil(function()
		return getRepresentativeTargets() ~= nil
	end, 600)
	local representativeTargets, representativeQueue = getRepresentativeTargets()
	local seenTargets = {}
	for i = 1, #representativeTargets do
		local targetID = representativeTargets[i]
		assert(bomberSet[targetID], "representative source fighter received a non-bomber target")
		assert(not seenTargets[targetID], "representative source fighter received a duplicate target")
		seenTargets[targetID] = true
	end
	Spring.Echo(
		"[Attack Targets Test] queue mode="
			.. (nativeTargetList and "native" or "lua-stepped")
			.. ", representative commands="
			.. #representativeQueue
	)

	local function attackQueuesCleared()
		for i = 1, #sourceIDs do
			local sourceID = sourceIDs[i]
			if Spring.ValidUnitID(sourceID) and not Spring.GetUnitIsDead(sourceID) then
				local commands = Spring.GetUnitCommands(sourceID, -1)
				for j = 1, #commands do
					if commands[j].id == CMD.ATTACK or commands[j].id == listCommandID then
						return false
					end
				end
			end
		end
		return true
	end

	local cancelStartFrame = Spring.GetGameFrame()
	Spring.GiveOrderToUnitArray(sourceIDs, CMD.STOP, {}, 0)
	local cancelCompletedFrame = nil
	for _ = 1, 600 do
		if attackQueuesCleared() then
			cancelCompletedFrame = Spring.GetGameFrame()
			break
		end
		Test.waitFrames(1)
	end
	Spring.Echo(
		"[Attack Targets Test] cancel frames="
			.. (cancelCompletedFrame and tostring(cancelCompletedFrame - cancelStartFrame) or ">600")
	)

	representativeTargets = nil
	representativeQueue = nil
	seenTargets = nil
	SyncedRun(function(locals)
		for i = 1, #locals.bomberIDs do
			Spring.SetUnitArmored(locals.bomberIDs[i], false, 1)
		end
	end, 600)
	local combatStartFrame = Spring.GetGameFrame()
	issueAreaAttack()
	Test.waitFrames(nativeTargetList and 1 or 60)

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
	Spring.Echo(
		"[Attack Targets Test] combat frames="
			.. (Spring.GetGameFrame() - combatStartFrame)
			.. ", bombers alive="
			.. bombersAlive
			.. ", fighters alive="
			.. sourcesAlive
	)
	assertEqual(
		bombersAlive,
		0,
		"all explicitly targeted bombers should be destroyed before the fighter force is gone"
			.. " (bombers alive: "
			.. bombersAlive
			.. ", fighters alive: "
			.. sourcesAlive
			.. ")"
	)
end
