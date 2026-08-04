local WavesVerbs = VFS.Include("modules/waves/lib/mission_verbs.lua")

local PACK = { name = "scavengers.skirmish", module = "scavengers", pack = "skirmish" }

---A ctx that records what a verb asked the engine to do, and answers Status
---from a table the spec sets.
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
	}
end

describe("waves mission verbs", function()
	local waves

	before_each(function()
		waves = WavesVerbs.MakeWaves()
	end)

	describe("Begin", function()
		it("starts the named pack against the named team", function()
			local ctx = makeCtx()
			waves.Begin(PACK).Against({ teamID = 1, allyTeam = 0 }).execute(ctx)
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
			waves.Begin(PACK).Against({ teamID = 1, allyTeam = 0 }).From(0.85, 0.15).execute(ctx)
			assert.are.same({ fx = 0.85, fz = 0.15 }, ctx.calls[1][2].origin)
		end)

		it("defaults the dial to full and takes an override", function()
			local ctx = makeCtx()
			waves.Begin(PACK).Against({ teamID = 1, allyTeam = 0 }).execute(ctx)
			assert.are.equal(1, ctx.calls[1][2].intensity)

			ctx = makeCtx()
			waves.Begin(PACK).Against({ teamID = 1, allyTeam = 0 }).Intensity(0.3).execute(ctx)
			assert.are.equal(0.3, ctx.calls[1][2].intensity)
		end)

		it("reads in any link order — the chain is dot-only, not sequential", function()
			local ctx = makeCtx()
			waves.Begin(PACK).Intensity(0.5).From(0.1, 0.2).Against({ teamID = 2, allyTeam = 1 }).execute(ctx)
			local request = ctx.calls[1][2]
			assert.are.equal(2, request.against)
			assert.are.equal(0.5, request.intensity)
		end)

		it("fails loudly at execution when nobody was named as the target", function()
			local ctx = makeCtx()
			assert.has_error(function()
				waves.Begin(PACK).execute(ctx)
			end)
		end)

		it("refuses anything that is not a pack", function()
			assert.has_error(function()
				waves.Begin("scavengers.skirmish")
			end)
			assert.has_error(function()
				waves.Begin({ name = "x" })
			end)
		end)

		it("refuses a target that is not a Team handle", function()
			assert.has_error(function()
				waves.Begin(PACK).Against("player")
			end)
		end)

		it("refuses a negative dial", function()
			assert.has_error(function()
				waves.Begin(PACK).Intensity(-1)
			end)
		end)
	end)

	describe("the running dials", function()
		it("Intensify turns the dial on the named pack", function()
			local ctx = makeCtx()
			waves.Intensify(PACK, 0.6).execute(ctx)
			assert.are.same({ "intensity", "scavengers.skirmish", 0.6 }, ctx.calls[1])
		end)

		it("Surge asks for one wave now", function()
			local ctx = makeCtx()
			waves.Surge(PACK).execute(ctx)
			assert.are.same({ "surge", "scavengers.skirmish" }, ctx.calls[1])
		end)

		it("End stops the spawner and says nothing about what is already fighting", function()
			local ctx = makeCtx()
			waves.End(PACK).execute(ctx)
			assert.are.same({ "stop", "scavengers.skirmish" }, ctx.calls[1])
		end)

		it("all of them refuse a non-pack", function()
			assert.has_error(function()
				waves.Intensify("x", 1)
			end)
			assert.has_error(function()
				waves.Surge("x")
			end)
			assert.has_error(function()
				waves.End("x")
			end)
		end)
	end)

	describe("conditions", function()
		it("declare the bus events that can change their answer", function()
			assert.are.same({ "waves.wave_spawned" }, waves.Spawned(PACK).inputs)
			assert.are.same({ "waves.wave_cleared" }, waves.Cleared(PACK).inputs)
			assert.are.same({ "waves.boss_defeated" }, waves.BossDefeated(PACK).inputs)
		end)

		it("read the monotonic counters, so the answer is latched by construction", function()
			local spawned = waves.Spawned(PACK)
			assert.is_false(spawned.evaluate(makeCtx({ waveNumber = 0 })))
			assert.is_true(spawned.evaluate(makeCtx({ waveNumber = 1 })))
			assert.is_true(spawned.evaluate(makeCtx({ waveNumber = 40 })))
		end)

		it("take a count, for a mission that wants the third wave and not the first", function()
			local cleared = waves.Cleared(PACK, 3)
			assert.is_false(cleared.evaluate(makeCtx({ wavesCleared = 2 })))
			assert.is_true(cleared.evaluate(makeCtx({ wavesCleared = 3 })))
		end)

		it("answer false, not an error, before the director exists", function()
			assert.is_false(waves.Spawned(PACK).evaluate(makeCtx(nil)))
			assert.is_false(waves.BossDefeated(PACK).evaluate(makeCtx(nil)))
		end)

		it("count bosses down the same way", function()
			local defeated = waves.BossDefeated(PACK)
			assert.is_false(defeated.evaluate(makeCtx({ bossesKilled = 0 })))
			assert.is_true(defeated.evaluate(makeCtx({ bossesKilled = 1 })))
		end)
	end)
end)
