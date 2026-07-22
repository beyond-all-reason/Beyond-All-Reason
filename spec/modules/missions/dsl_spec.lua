local DSL = VFS.Include("modules/missions/lib/dsl.lua")
local Verbs = VFS.Include("modules/missions/lib/verbs.lua")

local alwaysTrue = { evaluate = function() return true end }

describe("mission DSL", function()
	local registered ---@type TriggerDescriptor[]
	local When

	before_each(function()
		registered = {}
		When = DSL.ForFile("triggers/win.lua", function(descriptor)
			registered[#registered + 1] = descriptor
		end)
	end)

	it("builds a descriptor from a dot-only chain", function()
		local effect = { execute = function() end }
		When(alwaysTrue).Do(effect).Register()

		assert.are.equal(1, #registered)
		local descriptor = registered[1]
		assert.are.equal("triggers/win.lua:1", descriptor.id)
		assert.are.equal("triggers/win.lua", descriptor.filename)
		assert.are.equal(1, descriptor.order)
		assert.are.equal(alwaysTrue, descriptor.condition)
		assert.are.same({ effect }, descriptor.effects)
		assert.is_true(descriptor.once)
	end)

	it("accumulates multiple Do effects in order", function()
		local first = { execute = function() end }
		local second = { execute = function() end }
		When(alwaysTrue).Do(first).Do(second).Register()
		assert.are.same({ first, second }, registered[1].effects)
	end)

	it("rejects a bare function in Do (closure-free surface)", function()
		assert.has_error(function()
			When(alwaysTrue).Do(function() end)
		end)
	end)

	it("stamps declaration order per file", function()
		When(alwaysTrue).Do({ execute = function() end }).Register()
		When(alwaysTrue).Do({ execute = function() end }).Register()
		assert.are.equal("triggers/win.lua:1", registered[1].id)
		assert.are.equal("triggers/win.lua:2", registered[2].id)
	end)

	it("defaults Once to true and honors Once(false)", function()
		When(alwaysTrue).Do({ execute = function() end }).Once(false).Register()
		assert.is_false(registered[1].once)
	end)

	it("requires a Do before Register", function()
		assert.has_error(function()
			When(alwaysTrue).Register()
		end)
	end)

	it("rejects Do after Register (no mutating a registered trigger)", function()
		local chain = When(alwaysTrue).Do({ execute = function() end })
		chain.Register()
		assert.has_error(function()
			chain.Do({ execute = function() end })
		end)
	end)

	it("rejects a second Register on the same chain", function()
		local chain = When(alwaysTrue).Do({ execute = function() end })
		chain.Register()
		assert.has_error(function()
			chain.Register()
		end)
	end)

	it("rejects a condition without evaluate", function()
		assert.has_error(function()
			When({})
		end)
	end)
end)

describe("AndWhen composition", function()
	local registered
	local When

	before_each(function()
		registered = {}
		When = DSL.ForFile("triggers/win.lua", function(descriptor)
			registered[#registered + 1] = descriptor
		end)
	end)

	local function cond(result, inputs)
		return { inputs = inputs, evaluate = function() return result end }
	end

	local anEffect = { execute = function() end }

	it("fires only when every condition holds", function()
		When(cond(true)).AndWhen(cond(false)).Do(anEffect).Register()
		assert.is_false(registered[1].condition.evaluate({}))
		When(cond(true)).AndWhen(cond(true)).Do(anEffect).Register()
		assert.is_true(registered[2].condition.evaluate({}))
	end)

	it("composes inputs as the union of the parts'", function()
		When(cond(true, { "A", "B" })).AndWhen(cond(true, { "B", "C" })).Do(anEffect).Register()
		local inputs = registered[1].condition.inputs
		table.sort(inputs)
		assert.are.same({ "A", "B", "C" }, inputs)
	end)

	it("a poll-only part makes the whole trigger poll", function()
		When(cond(true, { "A" })).AndWhen(cond(true, nil)).Do(anEffect).Register()
		assert.is_nil(registered[1].condition.inputs)
	end)

	it("single-condition triggers keep their original condition object", function()
		local only = cond(true, { "A" })
		When(only).Do(anEffect).Register()
		assert.are.equal(only, registered[1].condition)
	end)

	it("rejects a non-condition", function()
		assert.has_error(function()
			When(cond(true)).AndWhen(function() end)
		end)
	end)
end)

describe("mission verbs", function()
	it("UnitDef carries the name", function()
		assert.are.same({ name = "armpw" }, Verbs.UnitDef("armpw"))
	end)

	it("Team.Has evaluates against ctx counts", function()
		local team = Verbs.MakeTeam(0, 0)
		local condition = team.Has(Verbs.UnitDef("armpw"), 3)

		local counts = { [0] = { armpw = 2 } }
		local ctx = {
			frame = 0,
			GetUnitDefCount = function(teamID, defName)
				return (counts[teamID] or {})[defName] or 0
			end,
		}
		assert.is_false(condition.evaluate(ctx))
		counts[0].armpw = 3
		assert.is_true(condition.evaluate(ctx))
	end)

	it("Has declares its engine-callin inputs", function()
		local team = Verbs.MakeTeam(0, 0)
		local condition = team.Has(Verbs.UnitDef("armpw"), 3)
		assert.are.same({ "UnitFinished", "UnitDestroyed", "UnitGiven", "UnitTaken" }, condition.inputs)
	end)

	it("Team carries teamID and allyTeam for MatchFlow calls", function()
		local team = Verbs.MakeTeam(2, 1)
		assert.are.equal(2, team.teamID)
		assert.are.equal(1, team.allyTeam)
	end)
end)
