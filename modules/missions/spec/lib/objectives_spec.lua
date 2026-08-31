local Objectives = VFS.Include("modules/missions/lib/objectives.lua")

local function condition()
	return {
		evaluate = function()
			return false
		end,
	}
end

describe("objectives DSL", function()
	it("declaration order is the board order; a title defaults to the id", function()
		local file = Objectives.ForFile("t/objectives.lua")
		file.Objective("first_step").Title("The First Step").CompletedWhen(condition())
		file.Objective("second_step").CompletedWhen(condition())
		local decls = file.Finalize()
		assert.are.equal(2, #decls)
		assert.are.equal("first_step", decls[1].id)
		assert.are.equal("The First Step", decls[1].title)
		assert.are.equal("second step", decls[2].title)
	end)

	it("a second declaration of the same id is a load error", function()
		local file = Objectives.ForFile("t/objectives.lua")
		file.Objective("twice").Title("Once")
		local ok, err = pcall(function()
			file.Objective("twice").Title("Again")
		end)
		assert.is_false(ok)
		assert.matches("declared twice", tostring(err))
	end)

	it("When gates the whole objective, wherever it sits in the chain", function()
		local file = Objectives.ForFile("t/objectives.lua")
		local gate = condition()
		file.Objective("gated").When(gate).CompletedWhen(condition()).CompletedWhen(condition())
		local decls = file.Finalize()
		assert.are.equal(2, #decls[1].completions)
		assert.are.same({ gate }, decls[1].gates)
	end)

	it("a reference no declaration backs fails Finalize", function()
		local file = Objectives.ForFile("t/objectives.lua")
		file.Objective("real").CompletedWhen(file.Objective("ghost").IsComplete())
		local ok, err = pcall(file.Finalize)
		assert.is_false(ok)
		assert.matches("ghost", tostring(err))
		assert.matches("no declaration backs", tostring(err))
	end)

	it("forward references are fine — order is display, not scoping", function()
		local file = Objectives.ForFile("t/objectives.lua")
		file.Objective("early").CompletedWhen(file.Objective("late").IsComplete())
		file.Objective("late").CompletedWhen(condition())
		assert.are.equal(2, #file.Finalize())
	end)

	it("a bare reference never declares", function()
		local file = Objectives.ForFile("t/objectives.lua")
		file.Objective("declared").CompletedWhen(file.Objective("declared").IsComplete())
		local decls = file.Finalize()
		assert.are.equal(1, #decls)
		assert.are.equal("declared", decls[1].id)
	end)

	it("gates, overrides and foreshadow ride the entry", function()
		local file = Objectives.ForFile("t/objectives.lua")
		local moment = condition()
		file.Objective("rich")
			.Title("Rich")
			.CompletedWhen(condition())
			.When(condition())
			.RevealedWhen(moment)
			.Foreshadow()
		local decls = file.Finalize()
		assert.are.equal(1, #decls[1].completions)
		assert.are.equal(1, #decls[1].gates)
		assert.are.equal(moment, decls[1].revealedWhen)
		assert.is_true(decls[1].foreshadow)
	end)

	it("a second CompletedWhen is another way, not another requirement", function()
		local file = Objectives.ForFile("t/objectives.lua")
		file.Objective("found").CompletedWhen(condition()).When(condition()).CompletedWhen(condition())
		local decls = file.Finalize()
		assert.are.equal(2, #decls[1].completions)
		assert.are.equal(1, #decls[1].completions[1])
		assert.are.equal(1, #decls[1].completions[2])
		assert.are.equal(1, #decls[1].gates)
	end)

	it("IsComplete builds the same condition shape triggers speak", function()
		local file = Objectives.ForFile("t/objectives.lua")
		local built = file.Objective("step").IsComplete()
		file.Objective("step").CompletedWhen(condition())
		file.Finalize()
		assert.are.same({ "mission.objective_changed" }, built.inputs)
		local completed = {}
		assert.is_false(built.evaluate({
			IsObjectiveComplete = function(id)
				return completed[id] == true
			end,
		}))
		completed.step = true
		assert.is_true(built.evaluate({
			IsObjectiveComplete = function(id)
				return completed[id] == true
			end,
		}))
	end)
end)
