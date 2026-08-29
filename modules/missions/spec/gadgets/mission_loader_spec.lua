
---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")

local MISSIONS = "modules/missions/"

local BUILD = [[
When(Team.Player.Has(UnitDef("armpw"), 3))
	.Do(Objective("build_pawns").Complete())
]]

local VICTORY = [[
When(Objective("build_pawns").IsComplete())
	.Do(Objective("win").Complete())
]]

local function armed(m)
	return m:Param("mission_active") == 1 and #m:Triggers() or nil
end

describe("mission loader reload", function()
	describe("stale triggers", function()
		it("arms a renamed trigger file once, not twice", function()
			local m = Builders.Mission.new():WithSources("t", { ["triggers/win.lua"] = BUILD }):WithUnits(0, "armpw", 3)
			m:Arm():Frame(15)
			assert.are.equal(1, armed(m))

			m.sources[MISSIONS .. "t/triggers/victory.lua"] = m.sources[MISSIONS .. "t/triggers/win.lua"]
			m.sources[MISSIONS .. "t/triggers/win.lua"] = nil
			m:ClearOutput():Arm()
			assert.are.equal(1, armed(m))
			m:Frame(30)
			assert.are.equal(1, m:Echoed("objective complete: build_pawns"))
		end)

		it("drops the previous mission's triggers on a switch", function()
			local m = Builders.Mission.new():WithSources("t", { ["triggers/win.lua"] = BUILD }):WithSources("u", {
				["triggers/other.lua"] = [[
When(Team.Player.Has(UnitDef("armpw"), 3))
	.Do(Objective("scout").Complete())
]],
			})
			m:Command("t"):ClearOutput():Command("u")
			assert.are.equal(1, armed(m))
			m:WithUnits(0, "armpw", 3):Frame(15)
			assert.are.equal(1, m:Param("objective_scout"))
			assert.is_nil(m:Param("objective_build_pawns"))
		end)
	end)

	describe("a preserving reload", function()
		it("keeps progress: the editor nudging a number is not a restart", function()
			local m = Builders.Mission
				.new()
				:WithSources("t", { ["triggers/a_build.lua"] = BUILD, ["triggers/z_win.lua"] = VICTORY })
				:WithUnits(0, "armpw", 3)
				:Arm()
				:Frame(15)
			assert.are.equal(1, m:Param("objective_build_pawns"))

			m:WithUnits(0, "armpw", 0):Reload()
			assert.are.equal(1, m:Param("objective_build_pawns"))
			assert.are.equal(1, m:Param("objective_win"))
		end)

		it("restart is a fresh run", function()
			local m = Builders.Mission
				.new()
				:WithSources("t", { ["triggers/a_build.lua"] = BUILD, ["triggers/z_win.lua"] = VICTORY })
				:WithUnits(0, "armpw", 3)
				:Arm()
				:Frame(15)
			assert.are.equal(1, m:Param("objective_build_pawns"))

			m:WithUnits(0, "armpw", 0):Restart()
			assert.is_nil(m:Param("objective_build_pawns"))
			m:Frame(30)
			assert.is_nil(m:Param("objective_win"))
		end)
	end)

	describe("objective progress", function()
		it("clears completed objectives so a reload is a fresh run", function()
			local m = Builders.Mission
				.new()
				:WithSources("t", { ["triggers/a_build.lua"] = BUILD, ["triggers/z_win.lua"] = VICTORY })
				:WithUnits(0, "armpw", 3)
				:Arm()
				:Frame(15)
			assert.are.equal(1, m:Param("objective_build_pawns"))
			assert.are.equal(1, m:Param("objective_win"))

			m:WithUnits(0, "armpw", 0):ClearOutput():Arm()
			assert.is_nil(m:Param("objective_build_pawns"))
			assert.is_nil(m:Param("objective_win"))
			m:Frame(30)
			assert.is_nil(m:Param("objective_win"))
		end)

		it("clears the objective prefix and nothing else", function()
			local m = Builders.Mission.new():WithSources("t", { ["triggers/a_build.lua"] = BUILD }):Arm()
			m.params.some_other_gadget = 7
			m.params.mission_unit_dead_ghost = 1
			m:Arm()
			assert.are.equal(7, m:Param("some_other_gadget"))
			assert.are.equal(1, m:Param("mission_unit_dead_ghost"))
		end)

		it("reveal marks the line drawn without completing it", function()
			local m = Builders.Mission
				.new()
				:WithSources("t", {
					["triggers/a_scout.lua"] = [[
When(Team.Player.Has(UnitDef("armpw"), 3))
	.Do(Objective("scout").Reveal())
]],
				})
				:WithUnits(0, "armpw", 3)
				:Arm()
				:Frame(15)
			assert.are.equal(1, m:Param("objective_revealed_scout"))
			assert.is_nil(m:Param("objective_scout"))
		end)

		it("complete implies reveal, and a fresh load sweeps both piles", function()
			local m = Builders.Mission
				.new()
				:WithSources("t", { ["triggers/a_build.lua"] = BUILD })
				:WithUnits(0, "armpw", 3)
				:Arm()
				:Frame(15)
			assert.are.equal(1, m:Param("objective_build_pawns"))
			assert.are.equal(1, m:Param("objective_revealed_build_pawns"))

			m:WithUnits(0, "armpw", 0):Arm()
			assert.is_nil(m:Param("objective_build_pawns"))
			assert.is_nil(m:Param("objective_revealed_build_pawns"))
		end)
	end)

	describe("a failed load", function()
		it("leaves the running mission armed when a trigger file fails", function()
			local m = Builders.Mission
				.new()
				:WithSources("t", { ["triggers/a_build.lua"] = BUILD, ["triggers/z_win.lua"] = VICTORY })
				:WithUnits(0, "armpw", 3)
				:Arm()
			assert.are.equal(2, armed(m))
			m:Frame(15)
			assert.are.equal(1, m:Param("objective_build_pawns"))

			m.sources[MISSIONS .. "t/triggers/z_win.lua"] = "NoSuchVerb()"
			m:ClearOutput()
			local ok, err = pcall(m.Arm, m)
			assert.is_true(ok, tostring(err))
			assert.is_true(m:Logged("z_win.lua"))
			assert.are.equal(1, m:Param("objective_build_pawns"))
			m:Frame(30)
			assert.are.equal(1, m:Param("objective_win"))
		end)

		it("keeps a half-parsed mission's triggers out of the armed set", function()
			local m = Builders.Mission.new():WithSources("t", {
				["triggers/a_build.lua"] = BUILD,
				["triggers/z_win.lua"] = "NoSuchVerb()",
			})
			assert.is_true(pcall(m.Arm, m))
			assert.is_nil(armed(m))
			m:WithUnits(0, "armpw", 3):Frame(15)
			assert.is_nil(m:Param("objective_build_pawns"))
			assert.is_nil(m:Param("mission_active"))
		end)
	end)
end)
