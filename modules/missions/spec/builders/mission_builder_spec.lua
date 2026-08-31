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
