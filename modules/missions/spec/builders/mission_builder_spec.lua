---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")

local BUILD = [[
When(Team.Player.Has(UnitDef("armpw"), 3))
	.Do(Objective("build_pawns").Complete())
]]
local WIN = [[
When(Objective("build_pawns").IsComplete())
	.Do(MatchFlow.Victory(Team.Player))
]]

describe("the mission builder", function()
	it("arms an inline mission through the real load action", function()
		local m = Builders.Mission.new():WithSources("t", { ["triggers/win.lua"] = BUILD }):Arm()
		assert.are.equal(1, m:Echoed("mission armed: t"))
		assert.are.equal(1, #m:Triggers())
		assert.are.equal("t/triggers/win.lua:1", m:Triggers()[1].id)
	end)

	it("drives objectives from the unit counts the runtime reads", function()
		local m = Builders.Mission.new():WithSources("t", { ["triggers/win.lua"] = BUILD }):Arm()
		m:Step()
		assert.is_nil(m:Param("objective_build_pawns"))
		m:WithUnits(0, "armpw", 3):Step()
		assert.are.equal(1, m:Param("objective_build_pawns"))
	end)

	it("records what a mission asks of another module, with the real verbs", function()
		local m = Builders.Mission
			.new()
			:WithSources("t", { ["triggers/a.lua"] = BUILD, ["triggers/z.lua"] = WIN })
			:WithUnits(0, "armpw", 3)
			:Arm()
		m:Step():Step()
		local matchflow = m:Calls("matchflow")
		assert.are.equal("Victory", matchflow[1].method)
		assert.are.equal(0, matchflow[1].args[1])
	end)

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

	it("a mission file is real Lua: a local names a value and is used later", function()
		local m = Builders.Mission
			.new()
			:WithSources("t", {
				["triggers/a.lua"] = [[
local pawn = UnitDef("armpw")
local scouted = Objective("scouted")
When(Team.Player.Has(pawn, 3)).Do(scouted.Complete())
When(scouted.IsComplete()).Do(MatchFlow.Victory(Team.Player))
]],
			})
			:WithUnits(0, "armpw", 3)
			:Arm()
		m:Step():Step()
		assert.are.equal(1, m:Param("objective_scouted"))
		assert.are.equal("Victory", m:Calls("matchflow")[1].method)
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

	it("reload keeps progress and restart is the fresh run", function()
		local m =
			Builders.Mission.new():WithSources("t", { ["triggers/win.lua"] = BUILD }):WithUnits(0, "armpw", 3):Arm()
		m:Step()
		assert.are.equal(1, m:Param("objective_build_pawns"))
		m:WithUnits(0, "armpw", 0):Reload()
		assert.are.equal(1, m:Param("objective_build_pawns"))
		m:Restart()
		assert.is_nil(m:Param("objective_build_pawns"))
	end)
end)
