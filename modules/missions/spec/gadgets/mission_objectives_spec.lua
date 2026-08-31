---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")

local BUILD = [[
When(Team.Player.Has(UnitDef("armpw"), 3))
	.Do(Objective("build_pawns").Complete())
]]

local function armed(m)
	return m:Param("mission_active") == 1 and #m:Triggers() or nil
end

describe("mission objectives", function()
	describe("objective declarations", function()
		local DECLS = [[
Objective("first")
	.Title("The First Step")
	.CompletedWhen(Team.Player.Has(UnitDef("armpw"), 3))

Objective("second")
	.Foreshadow()
	.CompletedWhen(Team.Player.Has(UnitDef("armcom"), 1))
	.When(Objective("first").IsComplete())
]]
		local QUIET = [[
When(Team.Player.Has(UnitDef("armcom"), 5))
	.Do(Objective("first").Complete())
]]

		it("publishes the board and reveals the opening line at arm", function()
			local m = Builders.Mission
				.new()
				:WithSources("t", { ["objectives.lua"] = DECLS, ["triggers/quiet.lua"] = QUIET })
				:Arm()
			assert.are.same({ "first", "second" }, m:ObjectiveOrder())
			assert.are.equal("The First Step", m:Param("objective_title_first"))
			assert.are.equal("second", m:Param("objective_title_second"))
			assert.are.equal(1, m:Param("objective_foreshadow_second"))
			assert.is_nil(m:Param("objective_foreshadow_first"))
			assert.are.equal(1, m:Param("objective_revealed_first"))
			assert.is_nil(m:Param("objective_revealed_second"))
		end)

		it("declarations compile to triggers: completion, gate and cadence", function()
			local m =
				Builders.Mission.new():WithSources("t", { ["objectives.lua"] = DECLS, ["triggers/quiet.lua"] = QUIET })
			m:WithUnits(0, "armcom", 1):Arm():Frame(15)
			assert.is_nil(m:Param("objective_second"))
			assert.is_nil(m:Param("objective_revealed_second"))

			m:WithUnits(0, "armpw", 3):Frame(30)
			assert.are.equal(1, m:Param("objective_first"))
			assert.are.equal(1, m:Param("objective_revealed_second"))
			assert.are.equal(1, m:Param("objective_second"))
		end)

		it("RevealedWhen replaces the cadence, for the opening line too", function()
			local m = Builders.Mission
				.new()
				:WithSources("t", {
					["objectives.lua"] = [[
Objective("first")
	.RevealedWhen(Team.Player.Has(UnitDef("armpw"), 1))
	.CompletedWhen(Team.Player.Has(UnitDef("armpw"), 3))
]],
					["triggers/quiet.lua"] = QUIET,
				})
				:Arm()
			assert.is_nil(m:Param("objective_revealed_first"))
			m:WithUnits(0, "armpw", 1):Frame(15)
			assert.are.equal(1, m:Param("objective_revealed_first"))
			assert.is_nil(m:Param("objective_first"))
		end)

		it("a standing objective does not dam the reveal cadence", function()
			local m = Builders.Mission
				.new()
				:WithSources("t", {
					["objectives.lua"] = [[
Objective("standing")
	.RevealedWhen(Team.Player.Has(UnitDef("armcom"), 5))

Objective("first")
	.Title("The First Step")
	.CompletedWhen(Team.Player.Has(UnitDef("armpw"), 3))
]],
					["triggers/quiet.lua"] = QUIET,
				})
				:Arm()
			assert.are.equal(1, m:Param("objective_revealed_first"))
			assert.is_nil(m:Param("objective_revealed_standing"))
		end)

		it("a second CompletedWhen is another way to complete", function()
			local m = Builders.Mission.new():WithSources("t", {
				["objectives.lua"] = [[
Objective("found")
	.CompletedWhen(Team.Player.Has(UnitDef("armpw"), 3))
	.CompletedWhen(Team.Player.Has(UnitDef("armcom"), 1))
]],
				["triggers/quiet.lua"] = [[
When(Team.Player.Has(UnitDef("armcom"), 5))
	.Do(Objective("found").Complete())
]],
			})
			m:WithUnits(0, "armcom", 1):Arm():Frame(15)
			assert.are.equal(1, m:Param("objective_found"))
		end)

		it("a trigger speaking an undeclared id is a load error", function()
			local m = Builders.Mission.new():WithSources("t", {
				["objectives.lua"] = DECLS,
				["triggers/typo.lua"] = [[
When(Team.Player.Has(UnitDef("armpw"), 1))
	.Do(Objective("ghost").Complete())
]],
			})
			assert.is_true(pcall(m.Arm, m))
			assert.is_nil(armed(m))
			assert.is_true(m:Logged("ghost"))
			assert.is_true(m:Logged("no such objective"))
		end)

		it("a mission without a definition site stays unvalidated", function()
			local m = Builders.Mission.new():WithSources("t", { ["triggers/win.lua"] = BUILD }):Arm()
			assert.is_nil(m:Param("objective_display_order"))
			assert.are.equal(1, armed(m))
		end)
	end)
end)
