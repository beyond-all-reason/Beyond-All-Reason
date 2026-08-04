local WavesVerbs = VFS.Include("modules/waves/lib/mission_verbs.lua")

local PACK = { name = "scavengers.skirmish", module = "scavengers", pack = "skirmish" }

local function makeCtx(status)
	local calls = {}
	return {
		calls = calls,
		StartWaves = function(request)
			calls[#calls + 1] = { "start", request }
		end,
		StopWaves = function(name)
			calls[#calls + 1] = { "stop", name }
		end,
		SetWaveIntensity = function(name, intensity)
			calls[#calls + 1] = { "intensity", name, intensity }
		end,
		SurgeWaves = function(name)
			calls[#calls + 1] = { "surge", name }
		end,
		WaveStatus = function()
			return status
		end,
		SpawnWaveUnits = function(name, defName, count)
			calls[#calls + 1] = { "spawn", name, defName, count }
		end,
		SpawnWaveOffWave = function(name)
			calls[#calls + 1] = { "offwave", name }
		end,
		SpawnWaveStructures = function(name)
			calls[#calls + 1] = { "structures", name }
		end,
		AddWaveAggression = function(name, amount)
			calls[#calls + 1] = { "aggression", name, amount }
		end,
	}
end

describe("waves mission verbs", function()
	local pack

	before_each(function()
		pack = WavesVerbs.Pack(PACK)
	end)

	it("the handle keeps the ref's identity, so a mode or a director reads it as before", function()
		assert.are.equal("scavengers.skirmish", pack.name)
		assert.are.equal("scavengers", pack.module)
		assert.are.equal("skirmish", pack.pack)
	end)

	it("refuses anything that is not a pack ref", function()
		assert.has_error(function()
			WavesVerbs.Pack("scavengers.skirmish")
		end)
		assert.has_error(function()
			WavesVerbs.Pack({ name = "x" })
		end)
	end)

	describe("Begin", function()
		it("starts the named pack against the named team", function()
			local ctx = makeCtx()
			pack.Begin().Against({ teamID = 1, allyTeam = 0 }).execute(ctx)
			assert.are.equal("start", ctx.calls[1][1])
			local request = ctx.calls[1][2]
			assert.are.equal("scavengers.skirmish", request.pack)
			assert.are.equal("scavengers", request.module)
			assert.are.equal("skirmish", request.builder)
			assert.are.equal(1, request.against)
			assert.are.equal(0, request.againstAllyTeam)
		end)

		it("carries the origin as map fractions, so a mission never names pixels", function()
			local ctx = makeCtx()
			pack.Begin().Against({ teamID = 1, allyTeam = 0 }).From(0.85, 0.15).execute(ctx)
			assert.are.same({ fx = 0.85, fz = 0.15 }, ctx.calls[1][2].origin)
		end)

		it("defaults the dial to full and takes an override", function()
			local ctx = makeCtx()
			pack.Begin().Against({ teamID = 1, allyTeam = 0 }).execute(ctx)
			assert.are.equal(1, ctx.calls[1][2].intensity)

			ctx = makeCtx()
			pack.Begin().Against({ teamID = 1, allyTeam = 0 }).Intensity(0.3).execute(ctx)
			assert.are.equal(0.3, ctx.calls[1][2].intensity)
		end)

		it("reads in any link order — the chain is dot-only, not sequential", function()
			local ctx = makeCtx()
			pack.Begin().Intensity(0.5).From(0.1, 0.2).Against({ teamID = 2, allyTeam = 1 }).execute(ctx)
			local request = ctx.calls[1][2]
			assert.are.equal(2, request.against)
			assert.are.equal(0.5, request.intensity)
		end)

		it("fails loudly at execution when nobody was named as the target", function()
			local ctx = makeCtx()
			assert.has_error(function()
				pack.Begin().execute(ctx)
			end)
		end)

		it("refuses a target that is not a Team handle", function()
			assert.has_error(function()
				pack.Begin().Against("player")
			end)
		end)

		it("refuses a negative dial", function()
			assert.has_error(function()
				pack.Begin().Intensity(-1)
			end)
		end)
	end)

	describe("the running dials", function()
		it("Intensify turns the dial on the named pack", function()
			local ctx = makeCtx()
			pack.Intensify(0.6).execute(ctx)
			assert.are.same({ "intensity", "scavengers.skirmish", 0.6 }, ctx.calls[1])
		end)

		it("Surge asks for one wave now", function()
			local ctx = makeCtx()
			pack.Surge().execute(ctx)
			assert.are.same({ "surge", "scavengers.skirmish" }, ctx.calls[1])
		end)

		it("End stops the spawner and says nothing about what is already fighting", function()
			local ctx = makeCtx()
			pack.End().execute(ctx)
			assert.are.same({ "stop", "scavengers.skirmish" }, ctx.calls[1])
		end)

		it("Intensify refuses a negative dial", function()
			assert.has_error(function()
				pack.Intensify(-1)
			end)
		end)
	end)

	describe("the director's other entry points", function()
		it("Spawn asks for a named squad out of any live burrow", function()
			local ctx = makeCtx()
			pack.Spawn("corak", 4).execute(ctx)
			assert.are.same({ "spawn", "scavengers.skirmish", "corak", 4 }, ctx.calls[1])
		end)

		it("Spawn refuses a nameless def or an empty squad", function()
			assert.has_error(function()
				pack.Spawn("", 4)
			end)
			assert.has_error(function()
				pack.Spawn("corak", 0)
			end)
		end)

		it("OffWave and Structures fire once, now", function()
			local ctx = makeCtx()
			pack.OffWave().execute(ctx)
			pack.Structures().execute(ctx)
			assert.are.same({ "offwave", "scavengers.skirmish" }, ctx.calls[1])
			assert.are.same({ "structures", "scavengers.skirmish" }, ctx.calls[2])
		end)

		it("Aggression adds to the boss clock's sources, and only adds", function()
			local ctx = makeCtx()
			pack.Aggression(5).execute(ctx)
			assert.are.same({ "aggression", "scavengers.skirmish", 5 }, ctx.calls[1])
			assert.has_error(function()
				pack.Aggression(-5)
			end)
		end)
	end)

	describe("conditions", function()
		it("declare the bus events that can change their answer", function()
			assert.are.same({ "waves.wave_spawned" }, pack.Spawned().inputs)
			assert.are.same({ "waves.wave_cleared" }, pack.Cleared().inputs)
			assert.are.same({ "waves.boss_defeated" }, pack.BossDefeated().inputs)
		end)

		it("read the monotonic counters, so the answer is latched by construction", function()
			local spawned = pack.Spawned()
			assert.is_false(spawned.evaluate(makeCtx({ waveNumber = 0 })))
			assert.is_true(spawned.evaluate(makeCtx({ waveNumber = 1 })))
			assert.is_true(spawned.evaluate(makeCtx({ waveNumber = 40 })))
		end)

		it("take a count, for a mission that wants the third wave and not the first", function()
			local cleared = pack.Cleared(3)
			assert.is_false(cleared.evaluate(makeCtx({ wavesCleared = 2 })))
			assert.is_true(cleared.evaluate(makeCtx({ wavesCleared = 3 })))
		end)

		it("answer false, not an error, before the director exists", function()
			assert.is_false(pack.Spawned().evaluate(makeCtx(nil)))
			assert.is_false(pack.BossDefeated().evaluate(makeCtx(nil)))
		end)

		it("AngerAtLeast reads the roster clock, and is polled — no event marks the moment", function()
			local anger = pack.AngerAtLeast(50)
			assert.is_nil(anger.inputs)
			assert.is_false(anger.evaluate(makeCtx({ techAnger = 49 })))
			assert.is_true(anger.evaluate(makeCtx({ techAnger = 50 })))
			assert.is_false(anger.evaluate(makeCtx(nil)))
		end)

		it("count bosses down the same way", function()
			local defeated = pack.BossDefeated()
			assert.is_false(defeated.evaluate(makeCtx({ bossesKilled = 0 })))
			assert.is_true(defeated.evaluate(makeCtx({ bossesKilled = 1 })))
		end)
	end)
end)
