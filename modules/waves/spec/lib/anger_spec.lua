local Anger = VFS.Include("modules/waves/lib/anger.lua")

local function params(overrides)
	local p = {
		gracePeriod = 180,
		gracePeriodRamped = 180,
		graceRamp = false,
		bossTime = 3480, -- 55 minutes of ramp plus the 180s grace
		bossTimeSpan = 3300,
		techAngerBossTime = 3480,
		economyScale = 1,
		teamCount = 1,
		minWaveSize = 15,
		maxWaveSize = 45,
		bossFightWaveSizeScale = 100,
		angerBonus = 0.2,
		spawnMultiplier = 1,
		maxXP = 0.3,
		endless = false,
	}
	for key, value in pairs(overrides or {}) do
		p[key] = value
	end
	return p
end

describe("waves anger", function()
	describe("the roster clock", function()
		it("reads zero through the grace period", function()
			local p = params()
			assert.are.equal(0, Anger.Tech(p, 0, false))
			assert.are.equal(0, Anger.Tech(p, 179, false))
		end)

		it("climbs linearly from grace to the boss hour", function()
			local p = params()
			assert.are.equal(50, Anger.Tech(p, 1830, false))
			assert.are.equal(100, Anger.Tech(p, 3480, false))
		end)

		it("keeps climbing past the boss — the roster does not stop at 100", function()
			local p = params()
			assert.is_true(Anger.Tech(p, 5000, false) > 100)
		end)

		it("caps at 999 so a very long game cannot walk off the roster", function()
			assert.are.equal(999, Anger.Tech(params(), 999999, false))
		end)

		it("scales with the economy: a richer game techs faster", function()
			local rich = Anger.Tech(params({ economyScale = 3 }), 1830, false)
			local plain = Anger.Tech(params(), 1830, false)
			assert.is_true(rich > plain)
			assert.are.equal(100, rich)
		end)

		it("measures against the RAMPED grace until the first boss, then against grace", function()
			local p = params({ gracePeriod = 540, gracePeriodRamped = 180, graceRamp = true })
			assert.is_true(Anger.Tech(p, 400, false) > 0)
			assert.are.equal(0, Anger.Tech(p, 400, true))
		end)
	end)

	describe("the boss countdown", function()
		it("is flat zero during grace, and ramps the burrow floor in", function()
			local p, state = params(), Anger.NewState()
			local anger, minBurrows = Anger.Boss(p, state, 90, 0)
			assert.are.equal(0, anger)
			assert.are.equal(2, minBurrows)
		end)

		it("reaches 100 at the boss hour with no aggression at all", function()
			local p, state = params(), Anger.NewState()
			local anger = Anger.Boss(p, state, 3480, 0)
			assert.are.equal(100, anger)
		end)

		it("pins at 100 once a boss is on the field", function()
			local p, state = params(), Anger.NewState()
			local anger, minBurrows = Anger.Boss(p, state, 400, 1)
			assert.are.equal(100, anger)
			assert.are.equal(1, minBurrows)
		end)

		it("keeps four burrows alive between endless bosses", function()
			local p, state = params({ endless = true }), Anger.NewState()
			local _, minBurrows = Anger.Boss(p, state, 400, 1)
			assert.are.equal(4, minBurrows)
		end)

		it("integrates aggression, so razing burrows pulls the boss in", function()
			local p, quiet = params(), Anger.NewState()
			local angry = Anger.NewState()
			angry.aggression = 100

			for _ = 1, 50 do
				Anger.Boss(p, quiet, 1000, 0)
				Anger.Boss(p, angry, 1000, 0)
			end
			assert.is_true(angry.aggressionLevel > quiet.aggressionLevel)
			assert.are.equal(0, quiet.aggressionLevel)
			assert.is_true(Anger.Boss(p, angry, 1000, 0) > Anger.Boss(p, quiet, 1000, 0))
		end)

		it("never reports a negative countdown", function()
			local p, state = params(), Anger.NewState()
			state.aggressionLevel = -500
			assert.are.equal(0, Anger.Boss(p, state, 400, 0))
		end)
	end)

	describe("aggression", function()
		it("decays, so a quiet stretch forgives an early rampage", function()
			local state = Anger.NewState()
			state.aggression = 100
			Anger.Decay(state)
			assert.are.equal(99.5, state.aggression)
		end)

		it("spikes when a burrow dies, and drifts the veterancy ceiling up", function()
			local p, state = params(), Anger.NewState()
			Anger.OnBurrowKilled(p, state)
			assert.are.equal(0.2, state.aggression)
			assert.is_true(p.maxXP > 0.3)
		end)

		it("divides the burrow bonus by the spawn multiplier — more burrows, cheaper each", function()
			local p, state = params({ spawnMultiplier = 4 }), Anger.NewState()
			Anger.OnBurrowKilled(p, state)
			assert.are.equal(0.05, state.aggression)
		end)

		it("takes eco structures in both directions, normalised to the boss hour", function()
			local p, state = params(), Anger.NewState()
			Anger.OnEcoStructure(p, state, 0.0005, 1)
			local built = state.ecoValue
			assert.is_true(built > 0)
			Anger.OnEcoStructure(p, state, 0.0005, -1)
			assert.is_true(math.abs(state.ecoValue) < 1e-12)
		end)

		it("reports both gain sources for the UI", function()
			local p, state = params(), Anger.NewState()
			state.aggression = 100
			state.ecoValue = 0.5
			local fromAggression, fromEco = Anger.Gains(p, state)
			assert.is_true(fromAggression > 0)
			assert.are.equal(0.5, fromEco)
		end)
	end)

	describe("the wave envelope", function()
		it("is the minimum at zero anger and the maximum at a hundred", function()
			local p = params()
			assert.are.equal(15, Anger.WaveCeiling(p, 0, 0))
			assert.are.equal(45, Anger.WaveCeiling(p, 100, 0))
		end)

		it("scales back during a boss fight so the boss is the fight", function()
			local p = params({ bossFightWaveSizeScale = 50 })
			assert.are.equal(45, Anger.WaveCeiling(p, 100, 0))
			assert.are.equal(23, Anger.WaveCeiling(p, 100, 1))
		end)
	end)

	it("resets the clocks for the next cycle but remembers the first boss is past", function()
		local state = Anger.NewState()
		state.techAnger, state.bossAnger, state.aggression, state.aggressionLevel = 500, 100, 40, 12
		Anger.Reset(state)
		assert.are.equal(0, state.techAnger)
		assert.are.equal(0, state.bossAnger)
		assert.are.equal(0, state.aggression)
		assert.are.equal(0, state.aggressionLevel)
		assert.is_true(state.pastFirstBoss)
	end)
end)
