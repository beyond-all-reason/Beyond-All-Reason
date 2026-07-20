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
		local effect = function() end
		T.When(alwaysTrue).Then(effect).Register()

		assert.are.equal(1, #registered)
		local descriptor = registered[1]
		assert.are.equal("triggers/win.lua:1", descriptor.id)
		assert.are.equal("triggers/win.lua", descriptor.filename)
		assert.are.equal(1, descriptor.order)
		assert.are.equal(alwaysTrue, descriptor.condition)
		assert.are.equal(effect, descriptor.effect)
		assert.is_true(descriptor.once)
	end)

	it("stamps declaration order per file", function()
		T.When(alwaysTrue).Then(function() end).Register()
		T.When(alwaysTrue).Then(function() end).Register()
		assert.are.equal("triggers/win.lua:1", registered[1].id)
		assert.are.equal("triggers/win.lua:2", registered[2].id)
	end)

	it("defaults Once to true and honors Once(false)", function()
		T.When(alwaysTrue).Then(function() end).Once(false).Register()
		assert.is_false(registered[1].once)
	end)

	it("requires a Then before Register", function()
		assert.has_error(function()
			T.When(alwaysTrue).Register()
		end)
	end)

	it("rejects a second Register on the same chain", function()
		local chain = T.When(alwaysTrue).Then(function() end)
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
