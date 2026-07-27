---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")

local UNITS = [[
Spawn(UnitDef("corllt"), "gaia").At(0.4, 0.4).Named("tower").Grouped("base").Neutral()
Spawn(UnitDef("corlab"), "gaia").At(0.42, 0.4).Grouped("base").Neutral()
Claim(UnitDef("armcom"), "enemy").Named("boss").OrSpawnAt(0.8, 0.8)
]]
local HANDOVER = [[
When(Unit("tower").IsSpotted(Team.Player)).Do(Transfer.Give("base", Team.Player))
When(MatchFlow.Started()).Do(Combat.Protect(Unit("tower")).Until(Unit("boss").IsDestroyed()))
]]

local function mission()
	return Builders.Mission.new():WithSources("t", { ["units.lua"] = UNITS, ["triggers/a.lua"] = HANDOVER })
end

describe("the mission builder's unit world", function()
	it("spawns the roster inert", function()
		local m = mission():Arm()
		local tower = m:Units()[m:UnitOf("tower")]
		assert.are.equal(2, tower.team)
		assert.is_true(tower.neutral)
		assert.are.same({ cmd = 45, params = { 0 } }, tower.orders[1])
	end)

	it("a claim binds to what is standing, or builds at OrSpawnAt", function()
		local m = mission()
		local incumbent = m:WithExistingUnit(1, "armcom")
		m:Arm()
		assert.are.equal(incumbent, m:UnitOf("boss"))

		local fresh = mission():Arm()
		assert.are.equal("armcom", fresh:Units()[fresh:UnitOf("boss")].def)
	end)

	it("Spot drives the real latch, and the handover is recorded against transfer", function()
		local m = mission():Arm():Step()
		assert.are.equal(0, #m:Calls("transfer"))
		m:Spot("tower"):Step()
		local give = m:Calls("transfer")[1]
		assert.are.equal("Give", give.method)
		assert.are.equal(2, #give.args[1])
		assert.are.equal(0, give.args[2])
	end)

	it("Protect ... Until releases on the real death latch", function()
		local m = mission():Arm():Step()
		local combat = m:Calls("combat")
		assert.are.equal("Protect", combat[1].method)
		assert.are.equal(m:UnitOf("tower"), combat[1].args[1])
		m:Kill("boss", 0):Step()
		combat = m:Calls("combat")
		assert.are.equal("Unprotect", combat[#combat].method)
	end)

	it("a mission file is real Lua: a local names a value and is used later", function()
		local m = Builders.Mission
			.new()
			:WithSources("t", {
				["units.lua"] = [[
local pawn = UnitDef("armpw")
Spawn(pawn, "player").At(0.5, 0.5).Named("scout")
]],
				["triggers/a.lua"] = [[
local pawn = UnitDef("armpw")
local scouted = Objective("scouted")
When(Team.Player.Has(pawn, 3)).Do(scouted.Complete())
When(scouted.IsComplete()).Do(MatchFlow.Victory(Team.Player))
]],
			})
			:Arm()
		assert.are.equal("armpw", m:Units()[m:UnitOf("scout")].def)
		m:WithUnits(0, "armpw", 3):Step():Step()
		assert.are.equal(1, m:Param("objective_scouted"))
		assert.are.equal("Victory", m:Calls("matchflow")[1].method)
	end)

	it("a spec speaks the roster by its handles, and reads the world by role", function()
		local m = Builders.Mission
			.new()
			:WithSources("t", {
				["units.lua"] = 'local hub = Spawn(UnitDef("corlab"), "gaia").At(0.4, 0.4).Neutral()\nlocal boss = Claim(UnitDef("armcom"), "enemy").Named("armada_commander").OrSpawnAt(0.8, 0.8)\nreturn { hub = hub, boss = boss }\n',
				["triggers/a.lua"] = 'local Units = VFS.Include("modules/missions/t/units.lua")\nWhen(Units.hub.IsSpotted(Team.Player)).When(Units.boss.IsDestroyed()).Do(MatchFlow.Victory(Team.Player))\n',
			})
			:Arm()
		local Units = m:Includes()
		assert.are.equal("hub", Units.hub.name)
		assert.are.equal("armada_commander", Units.boss.name)
		assert.are.equal(m:UnitOf("hub"), m:UnitOf(Units.hub))
		assert.are.equal(0.8, m:Entry(Units.boss).fx)
		local gaia = m:TeamUnits("gaia")
		assert.are.equal(1, #gaia)
		assert.is_true(gaia[1].neutral)
		assert.is_true(gaia[1].holdsFire)
		assert.is_true(m:HoldsFire(Units.hub))
		assert.is_false(m:HoldsFire(Units.boss))
		m:Spot(Units.hub):Kill(Units.boss, 0):Step()
		assert.are.equal("Victory", m:Calls("matchflow")[1].method)
	end)
end)
