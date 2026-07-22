local DSL = VFS.Include("modules/missions/lib/dsl.lua")
local Verbs = VFS.Include("modules/missions/lib/verbs.lua")

local alwaysTrue = { evaluate = function() return true end }

describe("mission DSL", function()
	local registered ---@type TriggerDescriptor[]
	local T ---@type TriggerDSL

	before_each(function()
		registered = {}
		T = DSL.ForFile("triggers/win.lua", function(descriptor)
			registered[#registered + 1] = descriptor
		end)
	end)

	it("builds a descriptor from a dot-only chain", function()
		local effect = { execute = function() end }
		T.When(alwaysTrue).Do(effect).Register()

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
		T.When(alwaysTrue).Do(first).Do(second).Register()
		assert.are.same({ first, second }, registered[1].effects)
	end)

	it("rejects a bare function in Do (closure-free surface)", function()
		assert.has_error(function()
			T.When(alwaysTrue).Do(function() end)
		end)
	end)

	it("stamps declaration order per file", function()
		T.When(alwaysTrue).Do({ execute = function() end }).Register()
		T.When(alwaysTrue).Do({ execute = function() end }).Register()
		assert.are.equal("triggers/win.lua:1", registered[1].id)
		assert.are.equal("triggers/win.lua:2", registered[2].id)
	end)

	it("defaults Once to true and honors Once(false)", function()
		T.When(alwaysTrue).Do({ execute = function() end }).Once(false).Register()
		assert.is_false(registered[1].once)
	end)

	it("requires a Do before Register", function()
		assert.has_error(function()
			T.When(alwaysTrue).Register()
		end)
	end)

	it("rejects Do after Register (no mutating a registered trigger)", function()
		local chain = T.When(alwaysTrue).Do({ execute = function() end })
		chain.Register()
		assert.has_error(function()
			chain.Do({ execute = function() end })
		end)
	end)

	it("rejects a second Register on the same chain", function()
		local chain = T.When(alwaysTrue).Do({ execute = function() end })
		chain.Register()
		assert.has_error(function()
			chain.Register()
		end)
	end)

	it("rejects a condition without evaluate", function()
		assert.has_error(function()
			T.When({})
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

	it("Team carries teamID and allyTeam for MatchFlow calls", function()
		local team = Verbs.MakeTeam(2, 1)
		assert.are.equal(2, team.teamID)
		assert.are.equal(1, team.allyTeam)
	end)
end)

describe("AndWhen composition", function()
	local registered
	local T

	before_each(function()
		registered = {}
		T = DSL.ForFile("triggers/win.lua", function(descriptor)
			registered[#registered + 1] = descriptor
		end)
	end)

	local function cond(result)
		return { evaluate = function() return result end }
	end

	local anEffect = { execute = function() end }

	it("fires only when every condition holds", function()
		T.When(cond(true)).AndWhen(cond(false)).Do(anEffect).Register()
		assert.is_false(registered[1].condition.evaluate({}))
		T.When(cond(true)).AndWhen(cond(true)).Do(anEffect).Register()
		assert.is_true(registered[2].condition.evaluate({}))
	end)

	it("single-condition triggers keep their original condition object", function()
		local only = cond(true)
		T.When(only).Do(anEffect).Register()
		assert.are.equal(only, registered[1].condition)
	end)

	it("rejects a non-condition", function()
		assert.has_error(function()
			T.When(cond(true)).AndWhen(function() end)
		end)
	end)
end)
