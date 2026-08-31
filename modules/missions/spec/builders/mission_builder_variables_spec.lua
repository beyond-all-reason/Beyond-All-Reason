---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")

local VARIABLES = [[
local waves = Variable("waves_survived").Number(0)
local alarmed = Variable("alarmed").Boolean(false)
return { waves = waves, alarmed = alarmed }
]]

local function mission(triggers)
	return Builders.Mission.new():WithSources("t", { ["variables.lua"] = VARIABLES, ["triggers/a.lua"] = triggers })
end

describe("variables.lua declares typed slots", function()
	it("starts at its default, Add accumulates, AtLeast gates", function()
		local m = mission([[
local V = VFS.Include("modules/missions/t/variables.lua")
When(Team.Player.Has(UnitDef("armpw"), 1)).Every(1).Do(V.waves.Add(1))
When(V.waves.AtLeast(2)).Do(V.alarmed.Set(true))
When(V.alarmed.Is(true)).Do(MatchFlow.Victory(Team.Player))
]]):Arm()
		assert.are.equal(0, m:Param("mission_var_waves_survived"))
		assert.are.equal(0, m:Param("mission_var_alarmed"))
		m:WithUnits(0, "armpw", 1):Step()
		assert.are.equal(1, m:Param("mission_var_waves_survived"))
		m:Frame(15 + 30):Step()
		assert.are.equal(2, m:Param("mission_var_waves_survived"))
		assert.are.equal(1, m:Param("mission_var_alarmed"))
		m:Step()
		assert.are.equal("Victory", m:Calls("matchflow")[1].method)
	end)

	it("restart resets to defaults; a preserving reload keeps the value", function()
		local m = mission([[
local V = VFS.Include("modules/missions/t/variables.lua")
When(Team.Player.Has(UnitDef("armpw"), 1)).Do(V.waves.Set(7))
]])
			:WithUnits(0, "armpw", 1)
			:Arm()
			:Step()
		assert.are.equal(7, m:Param("mission_var_waves_survived"))
		m:Reload()
		assert.are.equal(7, m:Param("mission_var_waves_survived"))
		m:Restart()
		assert.are.equal(0, m:Param("mission_var_waves_survived"))
	end)

	it("a variable without a type is a load error", function()
		local m = Builders.Mission.new():WithSources("t", {
			["variables.lua"] = 'local x = Variable("x")\nreturn { x = x }\n',
			["triggers/a.lua"] = 'When(Team.Player.Has(UnitDef("armpw"), 1)).Do(MatchFlow.Victory(Team.Player))\n',
		})
		assert.is_true(pcall(m.Arm, m))
		assert.is_nil(m:Param("mission_active"))
		assert.is_true(m:Logged("has no type"))
	end)
end)
