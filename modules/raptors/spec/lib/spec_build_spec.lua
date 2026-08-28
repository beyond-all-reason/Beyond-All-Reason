local DefsBuild = VFS.Include("modules/raptors/lib/defs_build.lua")
local EngineStub = VFS.Include("modules/raptors/spec/support/engine_stub.lua")
local Packs = VFS.Include("modules/raptors/lib/packs.lua")
local SpecBuild = VFS.Include("modules/raptors/lib/spec_build.lua")

local function build(modOptionOverrides, specOverrides)
	local modOptions = EngineStub.ModOptions(modOptionOverrides)
	local config = DefsBuild.Build({
		modOptions = modOptions,
		teamList = { 0, 1 },
		getTeamLuaAI = function(teamID)
			return teamID == 1 and "RaptorsAI" or ""
		end,
		unitDefNames = EngineStub.UnitDefNames(),
	})
	return SpecBuild.Build({
		name = "raptors",
		config = config,
		modOptions = modOptions,
		teamID = 3,
		allyTeamID = 1,
		teamCount = 2,
		unitCap = 4000,
		overrides = specOverrides,
	}),
		config
end

describe("raptors spec_build", function()
	it("makes the queen time absolute, after grace, and divides it by the queen dial", function()
		local spec, config = build({ raptor_queentimemult = 2 })
		assert.are.equal(config.queenTime + config.gracePeriod, spec.params.bossTime)
		assert.are.equal(spec.params.bossTime / 2, spec.params.techAngerBossTime)
	end)

	it("keeps the legacy rulesparam names the panel reads", function()
		local spec = build()
		assert.are.equal("raptor", spec.rulesParamPrefix)
		assert.are.equal("raptorQueenAnger", spec.rulesNames.bossAnger)
		assert.are.equal("raptorQueenTime", spec.rulesNames.bossTime)
		assert.are.equal("raptorQueensKilled", spec.rulesNames.bossesKilled)
		assert.are.equal("RaptorQueenAngerGain_Base", spec.rulesNames.angerGainBase)
	end)

	it("announces a queen as a queen", function()
		local spec = build()
		assert.are.equal("RaptorEvent", spec.events.toLuaUI)
		assert.are.equal("queen", spec.events.bossKind)
	end)

	it("targets by economic value, so a wave goes for what feeds the enemy", function()
		assert.are.equal("eco", build().targets.policy)
	end)

	it("hands the director the reactions, keyed by def name", function()
		local spec, config = build()
		local name, record = next(config.raptorReactions.skirmish)
		assert.are.equal(record.chance, spec.reactions.skirmish[name].chance)
		assert.are.equal(record.distance, spec.reactions.skirmish[name].distance)
		assert.is_not_nil(next(spec.reactions.coward))
		assert.is_not_nil(next(spec.reactions.berserk))
	end)

	it("carries the first-waves boost", function()
		assert.are.equal(3, build({ raptor_firstwavesboost = 3 }).params.firstWavesBoost)
	end)

	it("renames the legacy pools into the director's land buckets", function()
		local spec, config = build()
		assert.are.equal(#config.squadSpawnOptionsTable.basic, #spec.buckets.basicLand)
		assert.are.equal(#config.squadSpawnOptionsTable.basicAir, #spec.buckets.basicAirLand)
		assert.are.equal(#config.squadSpawnOptionsTable.healer, #spec.buckets.healerLand)
		assert.is_nil(spec.buckets.basicSea)
		assert.are.equal("raptor_land_swarmer_basic_t1_v1", spec.buckets.basicLand[1].units[1].def)
	end)

	it("keeps every specialist for a hundred waves", function()
		local _, config = build()
		local byID = SpecBuild.Behaviours(config.raptorBehaviours)
		local healer = next(config.raptorBehaviours.HEALER)
		assert.are.equal("healer", byID[healer].role)
		assert.are.equal(100, byID[healer].minLife)
		assert.is_true(byID[healer].prefersFight)
	end)

	it("takes the host's queen count, and no queen at zero", function()
		assert.are.equal(2, build({ raptor_queen_count = 2 }).boss.count)
		assert.is_nil(build({ raptor_queen_count = 0 }).boss)
	end)

	it("turns the turret table into land structures", function()
		local spec, config = build()
		local turret = spec.structures.raptor_turret_basic_t2_v1
		assert.are.equal(config.raptorTurrets.raptor_turret_basic_t2_v1.minQueenAnger, turret.minAnger)
		assert.are.equal("land", turret.surface)
	end)

	it("records how to rebuild itself after a load", function()
		assert.are.same({ module = "raptors", builder = "default", overrides = {} }, build().specRef)
	end)

	describe("packs", function()
		it("name a director and a way back to this module", function()
			assert.are.equal("raptors.swarm", Packs.Nouns.Swarm.name)
			assert.are.equal("raptors", Packs.Nouns.Swarm.module)
			assert.are.equal(Packs.Nouns.Skirmish, Packs.Ref("skirmish"))
		end)

		it("pin the roster by rewriting the snapshot", function()
			local snapshot = Packs.ModOptions("skirmish", EngineStub.ModOptions())
			assert.are.equal("easy", snapshot.raptor_difficulty)
			assert.are.equal(0, snapshot.raptor_queen_count)
			assert.are.equal("avoid", snapshot.raptor_raptorstart)
			assert.are.equal(1, EngineStub.ModOptions().raptor_queen_count, "the host's snapshot is untouched")
		end)
	end)
end)
