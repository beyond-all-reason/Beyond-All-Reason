---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")

describe("objectives.lua exports its handles", function()
	local OBJECTIVES = [[
local first = Objective("first").CompletedWhen(Team.Player.Has(UnitDef("armpw"), 3))
local second = Objective("second").CompletedWhen(Team.Player.Has(UnitDef("armcom"), 1)).When(first.IsComplete())
return { first = first, second = second }
]]

	it("trigger files reference them as Objectives.<key>, no string in sight", function()
		local m = Builders.Mission
			.new()
			:WithSources("t", {
				["objectives.lua"] = OBJECTIVES,
				["triggers/win.lua"] = 'local Objectives = VFS.Include("modules/missions/t/objectives.lua")\nWhen(Objectives.second.IsComplete()).Do(MatchFlow.Victory(Team.Player))\n',
			})
			:WithUnits(0, "armcom", 1)
			:Arm()
		local fromFile = 0
		for _, trigger in ipairs(m:Triggers()) do
			if trigger.filename == "t/triggers/win.lua" then
				fromFile = fromFile + 1
			end
		end
		assert.are.equal(1, fromFile)
		m:WithUnits(0, "armpw", 3):Step():Step()
		assert.are.equal(1, m:Param("objective_second"))
		assert.are.equal("Victory", m:Calls("matchflow")[1].method)
	end)

	it("a key nothing exported is a load error naming the file", function()
		local m = Builders.Mission.new():WithSources("t", {
			["objectives.lua"] = OBJECTIVES,
			["triggers/win.lua"] = 'local Objectives = VFS.Include("modules/missions/t/objectives.lua")\nWhen(Objectives.third.IsComplete()).Do(MatchFlow.Victory(Team.Player))\n',
		})
		assert.is_true(pcall(m.Arm, m))
		assert.is_nil(m:Param("mission_active"))
		assert.is_true(m:Logged("win.lua"))
	end)

	it("only the mission's own definition files can be included", function()
		local m = Builders.Mission.new():WithSources("t", {
			["objectives.lua"] = OBJECTIVES,
			["triggers/a.lua"] = 'local X = VFS.Include("modules/missions/u/objectives.lua")\n',
		})
		assert.is_true(pcall(m.Arm, m))
		assert.is_nil(m:Param("mission_active"))
		assert.is_true(m:Logged("only include its own files"))
	end)

	it("a trigger file cannot be included — it returns nothing", function()
		local m = Builders.Mission.new():WithSources("t", {
			["triggers/a.lua"] = 'When(Team.Player.Has(UnitDef("armpw"), 1)).Do(MatchFlow.Victory(Team.Player))\n',
			["triggers/b.lua"] = 'local A = VFS.Include("modules/missions/t/triggers/a.lua")\n',
		})
		assert.is_true(pcall(m.Arm, m))
		assert.is_nil(m:Param("mission_active"))
		assert.is_true(m:Logged("not a definition file"))
	end)

	it("anything exports — a value reads on the other side as what it is", function()
		local m = Builders.Mission
			.new()
			:WithSources("t", {
				["objectives.lua"] = 'local armed = Objective("armed").CompletedWhen(Team.Player.Has(UnitDef("armpw"), 2))\nreturn { armed = armed, enough = 2 }\n',
				["triggers/win.lua"] = 'local Objectives = VFS.Include("modules/missions/t/objectives.lua")\nWhen(Objectives.armed.IsComplete()).When(Team.Player.Has(UnitDef("armpw"), Objectives.enough)).Do(MatchFlow.Victory(Team.Player))\n',
			})
			:Arm()
			:Step()
		assert.is_nil(m:Param("objective_armed"))
		m:WithUnits(0, "armpw", 2):Step():Step()
		assert.are.equal(1, m:Param("objective_armed"))
		assert.are.equal("Victory", m:Calls("matchflow")[1].method)
	end)
end)
