local function setup()
	Test.clearMap()
	assert(select(1, Spring.GetTeamInfo(1, false)) ~= nil, "test requires enemy team 1")
end

local function cleanup()
	Test.clearMap()
end

local function createScenario()
	local x, y, z
	for candidateX = 512, Game.mapSizeX - 512, 512 do
		for candidateZ = 512, Game.mapSizeZ - 512, 512 do
			local height = Spring.GetGroundHeight(candidateX, candidateZ)
			if height > 0 then
				x, y, z = candidateX, height, candidateZ
				break
			end
		end
		if x then
			break
		end
	end
	assert(x, "test requires land for the flak turret")
	local sourceID = assert(Spring.CreateUnit("armflak", x, y, z, 0, 0))
	local targetA = assert(Spring.CreateUnit("corhurc", x + 200, y + 200, z, 0, 1))
	local targetB = assert(Spring.CreateUnit("corhurc", x + 300, y + 200, z, 0, 1))
	Spring.GiveOrderToUnitArray({ targetA, targetB }, CMD.MOVE, { x + 600, y + 200, z }, 0)
	Spring.GiveOrderToUnit(sourceID, CMD.FIRE_STATE, { 0 }, 0)
	return sourceID, targetA, targetB
end

local function test()
	local sourceID, targetA, targetB = SyncedRun(createScenario)
	-- Let units initialize before issuing player orders.
	Test.waitFrames(30)
	local setTarget = Game.CustomCommands.GetCommandCode("UNIT_SET_TARGET")
	Spring.GiveOrderToUnit(sourceID, setTarget, { targetA }, 0)
	Spring.GiveOrderToUnit(sourceID, setTarget, { targetB }, CMD.OPT_SHIFT)

	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceID, "unitTargetID") == targetA
	end, 60)

	SyncedRun(function(locals)
		-- Exercise the actual damage/controller path, which publishes shared membership.
		Spring.AddUnitDamage(locals.targetA, Spring.GetUnitHealth(locals.targetA) + 1, 0, locals.sourceID)
		assert(Spring.GetUnitIsDead(locals.targetA) == false, "crashing target must still exist")
		assert(Spring.GetUnitMoveTypeData(locals.targetA).aircraftState == "crashing")
	end)
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceID, "unitTargetID") == targetB
	end, 10)
	SyncedRun(function(locals)
		Spring.DestroyUnit(locals.targetB, false, true)
	end)
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceID, "hasPriorityTarget") == nil
	end, 10)
end

return { setup = setup, test = test, cleanup = cleanup }
