---@diagnostic disable: need-check-nil, unnecessary-assert

local function setup()
	Test.clearMap()
end

local function cleanup()
	Test.clearMap()
end

local function createScenario()
	local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
	local source = assert(Spring.CreateUnit("armfig", x, 450, z, "east", 0))
	local a = assert(Spring.CreateUnit("corhurc", x + 2000, 500, z, "west", 1))
	local b = assert(Spring.CreateUnit("corhurc", x + 2400, 500, z, "west", 1))
	local unrelated = assert(Spring.CreateUnit("corhurc", x + 2800, 500, z, "west", 1))
	for _, id in ipairs({ source, a, b, unrelated }) do
		Spring.GiveOrderToUnit(id, CMD.FIRE_STATE, { 0 }, 0)
		Spring.SetUnitArmored(id, true, 0)
	end
	return source, a, b, unrelated
end

local function test()
	local source, a, b, unrelated = SyncedRun(createScenario)
	Spring.GiveOrderToUnit(source, GameCMD.ATTACK_TARGETS, { a, b }, 0)
	Test.waitUntil(function()
		return Spring.GetUnitCommands(source, -1)[2] ~= nil
	end, 120)
	SyncedRun(function(locals)
		Spring.DestroyUnit(locals.unrelated, false, true)
	end)
	Spring.GiveOrderToUnit(source, CMD.MOVE, { 100, 0, 100 }, CMD.OPT_SHIFT)
	Test.waitUntil(function()
		return #Spring.GetUnitCommands(source, -1) == 3
	end, 120)
	SyncedRun(function(locals)
		Spring.DestroyUnit(locals.b, false, true)
	end)
	Test.waitFrames(2)
	local queue = Spring.GetUnitCommands(source, -1)
	assertEqual(#queue, 2, "the exhausted controller must disappear ahead of a trailing Move")
	assertEqual(queue[1].id, CMD.ATTACK)
	assertEqual(queue[1].params[1], a)
	assertEqual(queue[2].id, CMD.MOVE)
end

return { setup = setup, test = test, cleanup = cleanup }
