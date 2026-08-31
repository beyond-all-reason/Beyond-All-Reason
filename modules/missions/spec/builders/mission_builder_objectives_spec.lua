---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")

describe("the mission builder's objective board", function()
	it("publishes the objective board a mission declares", function()
		local m = Builders.Mission
			.new()
			:WithSources("t", {
				["objectives.lua"] = [[
Objective("first").Title("The First Step").CompletedWhen(Team.Player.Has(UnitDef("armpw"), 3))
Objective("second").CompletedWhen(Team.Player.Has(UnitDef("armcom"), 1)).When(Objective("first").IsComplete())
]],
				["triggers/quiet.lua"] = [[
When(Team.Player.Has(UnitDef("armcom"), 5)).Do(Objective("first").Complete())
]],
			})
			:Arm()
		assert.are.same({ "first", "second" }, m:ObjectiveOrder())
		assert.are.equal("The First Step", m:Param("objective_title_first"))
		assert.are.equal(2, #m:Objectives())
		assert.are.equal(1, m:Param("objective_revealed_first"))
		assert.is_nil(m:Param("objective_revealed_second"))
	end)

	it("a spec reads the board by the mission's own handles", function()
		local m = Builders.Mission
			.new()
			:WithSources("t", {
				["objectives.lua"] = 'local armed = Objective("armed").Title("Arm up").CompletedWhen(Team.Player.Has(UnitDef("armpw"), 2))\nlocal won = Objective("won").CompletedWhen(armed.IsComplete())\nreturn { armed = armed, won = won }\n',
				["triggers/win.lua"] = 'local Objectives = VFS.Include("modules/missions/t/objectives.lua")\nWhen(Objectives.won.IsComplete()).Do(MatchFlow.Victory(Team.Player))\n',
			})
			:Arm()
			:Step()
		local _, Objectives = m:Includes()
		assert.are.equal("armed", Objectives.armed.id)
		assert.are.equal("Arm up", m:TitleOf(Objectives.armed))
		assert.is_true(m:IsRevealed(Objectives.armed))
		assert.is_false(m:IsRevealed(Objectives.won))
		assert.is_false(m:IsComplete(Objectives.armed))
		m:WithUnits(0, "armpw", 2):Step():Step()
		assert.is_true(m:IsComplete(Objectives.armed))
		assert.is_true(m:IsRevealed(Objectives.won))
	end)
end)
