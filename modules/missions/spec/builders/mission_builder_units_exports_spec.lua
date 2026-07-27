---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")

describe("units.lua exports its handles", function()
	it("an unnamed handle takes its export key as its name; a Named one keeps its name", function()
		local m = Builders.Mission
			.new()
			:WithSources("t", {
				["units.lua"] = [[
local tower = Spawn(UnitDef("corllt"), "gaia").At(0.4, 0.4).Neutral()
local boss = Claim(UnitDef("armcom"), "enemy").Named("armada_commander").OrSpawnAt(0.8, 0.8)
return { tower = tower, boss = boss }
]],
				["triggers/a.lua"] = 'local Units = VFS.Include("modules/missions/t/units.lua")\nWhen(Units.boss.IsDestroyed()).Do(MatchFlow.Victory(Team.Player))\n',
			})
			:Arm()
		assert.is_number(m:UnitOf("tower"))
		assert.is_number(m:UnitOf("armada_commander"))
		assert.is_nil(m:UnitOf("boss"), "the wire identity is the Named name, the key is only the Lua name")
		m:Kill("armada_commander", 0):Step()
		assert.are.equal("Victory", m:Calls("matchflow")[1].method)
	end)

	it("objectives.lua can include units.lua", function()
		local m = Builders.Mission
			.new()
			:WithSources("t", {
				["units.lua"] = 'local hub = Spawn(UnitDef("corlab"), "gaia").At(0.4, 0.4).Neutral()\nreturn { hub = hub }\n',
				["objectives.lua"] = 'local Units = VFS.Include("modules/missions/t/units.lua")\nlocal found = Objective("found").CompletedWhen(Units.hub.IsSpotted(Team.Player))\nreturn { found = found }\n',
				["triggers/a.lua"] = 'local Objectives = VFS.Include("modules/missions/t/objectives.lua")\nWhen(Objectives.found.IsComplete()).Do(MatchFlow.Victory(Team.Player))\n',
			})
			:Arm()
			:Step()
		assert.is_nil(m:Param("objective_found"))
		m:Spot("hub"):Step()
		assert.are.equal(1, m:Param("objective_found"))
	end)

	it("an exported objective handle is its own effect side", function()
		local m = Builders.Mission
			.new()
			:WithSources("t", {
				["objectives.lua"] = 'local found = Objective("found").CompletedWhen(Team.Player.Has(UnitDef("armcom"), 9))\nreturn { found = found }\n',
				["triggers/a.lua"] = 'local O = VFS.Include("modules/missions/t/objectives.lua")\nWhen(MatchFlow.Started()).Do(O.found.Reveal())\nWhen(Team.Player.Has(UnitDef("armpw"), 1)).Do(O.found.Complete())\n',
			})
			:Arm()
			:Step()
		assert.are.equal(1, m:Param("objective_revealed_found"))
		assert.is_nil(m:Param("objective_found"))
		m:WithUnits(0, "armpw", 1):Step()
		assert.are.equal(1, m:Param("objective_found"))
	end)

	it("Combat.Protect takes the exported handle", function()
		local m = Builders.Mission
			.new()
			:WithSources("t", {
				["units.lua"] = 'local hub = Spawn(UnitDef("corlab"), "gaia").At(0.4, 0.4)\nreturn { hub = hub }\n',
				["triggers/a.lua"] = 'local Units = VFS.Include("modules/missions/t/units.lua")\nWhen(MatchFlow.Started()).Do(Combat.Protect(Units.hub))\n',
			})
			:Arm()
			:Step()
		local protect = m:Calls("combat")[1]
		assert.are.equal("Protect", protect.method)
		assert.are.equal(m:UnitOf("hub"), protect.args[1])
	end)
end)
