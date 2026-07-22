local DSL = VFS.Include("modules/missions/lib/dsl.lua")
local Verbs = VFS.Include("modules/missions/lib/verbs.lua")

local alwaysTrue = { evaluate = function() return true end }
local anEffect = { execute = function() end }

describe("mission DSL", function()
	local registered ---@type TriggerDescriptor[]
	local When
	local Finalize

	before_each(function()
		registered = {}
		local file = DSL.ForFile("triggers/win.lua", function(descriptor)
			registered[#registered + 1] = descriptor
		end)
		When = file.When
		Finalize = file.Finalize
	end)

	it("builds a descriptor from a terminator-free chain at Finalize", function()
		When(alwaysTrue).Do(anEffect)
		assert.are.equal(0, #registered) -- nothing arms before the commit point
		Finalize()

		assert.are.equal(1, #registered)
		local descriptor = registered[1]
		assert.are.equal("triggers/win.lua:1", descriptor.id)
		assert.are.equal("triggers/win.lua", descriptor.filename)
		assert.are.equal(1, descriptor.order)
		assert.are.equal(alwaysTrue, descriptor.condition)
		assert.are.same({ anEffect }, descriptor.effects)
		assert.is_true(descriptor.once)
	end)

	it("stamps declaration order by When-call order", function()
		When(alwaysTrue).Do(anEffect)
		When(alwaysTrue).Do(anEffect)
		Finalize()
		assert.are.equal("triggers/win.lua:1", registered[1].id)
		assert.are.equal("triggers/win.lua:2", registered[2].id)
	end)

	it("accumulates multiple Do effects in order", function()
		local first = { execute = function() end }
		local second = { execute = function() end }
		When(alwaysTrue).Do(first).Do(second)
		Finalize()
		assert.are.same({ first, second }, registered[1].effects)
	end)

	it("defaults Once to true and honors Once(false)", function()
		When(alwaysTrue).Do(anEffect).Once(false)
		Finalize()
		assert.is_false(registered[1].once)
	end)

	it("a statement without a Do fails the load, naming the statement", function()
		When(alwaysTrue).Do(anEffect)
		When(alwaysTrue) -- half-finished
		assert.has_error(function()
			Finalize()
		end)
		assert.are.equal(0, #registered) -- the failed load arms nothing
	end)

	it("rejects a bare function in Do (closure-free surface)", function()
		assert.has_error(function()
			When(alwaysTrue).Do(function() end)
		end)
	end)

	it("rejects a condition without evaluate", function()
		assert.has_error(function()
			When({})
		end)
	end)

	it("rejects chain calls after Finalize", function()
		local chain = When(alwaysTrue).Do(anEffect)
		Finalize()
		assert.has_error(function()
			chain.Do(anEffect)
		end)
	end)

	it("rejects Finalize twice", function()
		Finalize()
		assert.has_error(function()
			Finalize()
		end)
	end)
end)

describe("repeated When (AND composition)", function()
	local registered
	local When
	local Finalize

	before_each(function()
		registered = {}
		local file = DSL.ForFile("triggers/win.lua", function(descriptor)
			registered[#registered + 1] = descriptor
		end)
		When = file.When
		Finalize = file.Finalize
	end)

	local function cond(result, inputs)
		return { inputs = inputs, evaluate = function() return result end }
	end

	it("fires only when every condition holds", function()
		When(cond(true)).When(cond(false)).Do(anEffect)
		When(cond(true)).When(cond(true)).Do(anEffect)
		Finalize()
		assert.is_false(registered[1].condition.evaluate({}))
		assert.is_true(registered[2].condition.evaluate({}))
	end)

	it("composes inputs as the union of the parts'", function()
		When(cond(true, { "A", "B" })).When(cond(true, { "B", "C" })).Do(anEffect)
		Finalize()
		local inputs = registered[1].condition.inputs
		table.sort(inputs)
		assert.are.same({ "A", "B", "C" }, inputs)
	end)

	it("a poll-only part makes the whole trigger poll", function()
		When(cond(true, { "A" })).When(cond(true, nil)).Do(anEffect)
		Finalize()
		assert.is_nil(registered[1].condition.inputs)
	end)

	it("single-condition statements keep their original condition object", function()
		local only = cond(true, { "A" })
		When(only).Do(anEffect)
		Finalize()
		assert.are.equal(only, registered[1].condition)
	end)

	it("rejects a non-condition", function()
		assert.has_error(function()
			When(cond(true)).When(function() end)
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
			IsObjectiveComplete = function()
				return false
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

describe("AndWhen composition", function()
	local registered
	local T

	before_each(function()
		registered = {}
		T = VFS.Include("modules/missions/lib/dsl.lua").ForFile("triggers/win.lua", function(descriptor)
			registered[#registered + 1] = descriptor
		end)
	end)

	local function cond(result)
		return { evaluate = function() return result end }
	end

	it("fires only when every condition holds", function()
		T.When(cond(true)).AndWhen(cond(false)).Do({ execute = function() end }).Register()
		assert.is_false(registered[1].condition.evaluate({}))
	end)

	it("fires when all conditions hold", function()
		T.When(cond(true)).AndWhen(cond(true)).AndWhen(cond(true)).Do({ execute = function() end }).Register()
		assert.is_true(registered[1].condition.evaluate({}))
	end)

	it("single-condition triggers keep their original condition object", function()
		local only = cond(true)
		T.When(only).Do({ execute = function() end }).Register()
		assert.are.equal(only, registered[1].condition)
	end)

	it("rejects a non-condition", function()
		assert.has_error(function()
			T.When(cond(true)).AndWhen(function() end)
		end)
	end)
end)
