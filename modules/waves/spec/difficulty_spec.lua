local Difficulty = VFS.Include("modules/waves/lib/difficulty.lua")

local BOUNDS = { min = 0.85, max = 1.05, lower = 1 / 6, upper = 1 / 2 }

local function row(overrides)
	local r = {
		bossName = "boss_normal",
		bossTime = 3300,
		spawnRate = 180,
		burrowSpawnRate = 180,
		turretSpawnRate = 380,
		spawnChance = 0.3,
		minScavs = 15,
		maxScavs = 45,
		maxBurrows = 1000,
		maxXP = 0.3,
		angerBonus = 0.2,
		bossResistanceMult = 2,
		damageMod = 1,
		healthMod = 1,
	}
	for key, value in pairs(overrides or {}) do
		r[key] = value
	end
	return r
end

local function params(overrides)
	local p = {
		gracePeriod = 180,
		gracePeriodRamped = 180,
		graceRamp = true,
		bossTime = 3480,
		bossTimeSpan = 3300,
		techAngerBossTime = 3480,
		perPlayerMultiplier = 0.25,
		teamCount = 4,
		spawnMultiplier = 1,
		spawnChance = 0.3,
		maxXP = 0.3,
		angerBonus = 0.2,
		bossResistanceMult = 2,
		damageMod = 1,
		healthMod = 1,
		minWaveSize = 15,
		maxWaveSize = 45,
		maxBurrows = 1000,
		difficultyIndex = 3,
		difficultyRows = {
			row({ bossName = "boss_veryeasy" }),
			row({ bossName = "boss_easy" }),
			row({ bossName = "boss_normal" }),
			row({ bossName = "boss_hard", bossResistanceMult = 2.5, damageMod = 1, healthMod = 1 }),
		},
		dynamicDifficulty = BOUNDS,
	}
	for key, value in pairs(overrides or {}) do
		p[key] = value
	end
	return p
end

describe("waves difficulty", function()
	describe("per-player scaling", function()
		it("is the plain number for one team", function()
			assert.are.equal(45, Difficulty.PerPlayer(45, 0.25, 1, 1))
		end)

		it("adds only the scaling share per extra team", function()
			-- 45*(0.75) + 45*0.25*4 = 33.75 + 45
			assert.are.equal(78.75, Difficulty.PerPlayer(45, 0.25, 4, 1))
		end)

		it("multiplies through the spawn multiplier", function()
			assert.are.equal(90, Difficulty.PerPlayer(45, 0.25, 1, 2))
		end)

		it("caps team count where a cap is given — burrows stop scaling at eight", function()
			assert.are.equal(
				Difficulty.PerPlayer(1000, 0.25, 8, 1, 8),
				Difficulty.PerPlayer(1000, 0.25, 40, 1, 8)
			)
		end)
	end)

	describe("dynamic difficulty", function()
		it("gives the full bonus when the director is badly outgunned", function()
			assert.are.equal(1.05, Difficulty.Multiplier(1, 100, BOUNDS))
		end)

		it("gives the penalty when the director is winning", function()
			assert.are.equal(0.85, Difficulty.Multiplier(100, 100, BOUNDS))
		end)

		it("interpolates between the two ratios", function()
			-- ratio 1/3 sits midway between 1/6 and 1/2.
			assert.is.near(0.95, Difficulty.Multiplier(100, 300, BOUNDS), 1e-9)
		end)

		it("answers nil when either side reports no power — unknown is not easy", function()
			assert.is_nil(Difficulty.Multiplier(0, 100, BOUNDS))
			assert.is_nil(Difficulty.Multiplier(100, 0, BOUNDS))
			assert.is_nil(Difficulty.Multiplier(nil, 100, BOUNDS))
			assert.is_nil(Difficulty.Multiplier(100, nil, BOUNDS))
		end)
	end)

	describe("the endless reloop", function()
		it("returns a FRESH table — the source params are untouched", function()
			local before = params()
			local after = Difficulty.NextCycle(before, 2, 4000)
			assert.are_not.equal(before, after)
			assert.are.equal(180, before.gracePeriod)
			assert.are.equal(3999, after.gracePeriod)
			assert.are.equal(3, before.difficultyIndex)
			assert.are.equal(4, after.difficultyIndex)
		end)

		it("climbs the ladder a rung", function()
			local after = Difficulty.NextCycle(params(), 2, 4000)
			assert.are.equal("boss_hard", after.bossName)
			assert.are.equal(2.5, after.bossResistanceMult)
		end)

		it("compounds past the top of the ladder instead of falling off it", function()
			local top = params({ difficultyIndex = 4 })
			local after = Difficulty.NextCycle(top, 2, 4000)
			assert.are.equal(4, after.difficultyIndex, "stays on the last rung")
			assert.are.equal(2, after.spawnMultiplier)
			assert.are.equal(2.5, after.bossResistanceMult)
			assert.are.equal(1.25, after.damageMod)
			assert.are.equal(1.25, after.healthMod)
		end)

		it("compounds again on every further cycle", function()
			local p = params({ difficultyIndex = 4 })
			p = Difficulty.NextCycle(p, 2, 4000)
			p = Difficulty.NextCycle(p, 3, 8000)
			assert.are.equal(3, p.spawnMultiplier)
			assert.are.equal(3, p.bossResistanceMult)
			assert.are.equal(1.5, p.damageMod)
		end)

		it("brings the boss in faster every cycle", function()
			local second = Difficulty.NextCycle(params(), 2, 4000)
			local third = Difficulty.NextCycle(params(), 3, 4000)
			assert.are.equal(3300, second.bossTimeSpan)
			assert.are.equal(2200, third.bossTimeSpan)
			assert.is_true(third.bossTime < second.bossTime)
		end)

		it("restarts grace one second back, so the tech clock is already live", function()
			local after = Difficulty.NextCycle(params(), 2, 4000)
			assert.are.equal(3999, after.gracePeriod)
			assert.are.equal(3999, after.gracePeriodRamped)
			assert.is_false(after.graceRamp)
		end)

		it("re-derives the wave envelope through the new spawn multiplier", function()
			local top = Difficulty.NextCycle(params({ difficultyIndex = 4 }), 2, 4000)
			-- (45*0.75 + 45*0.25*4) * 2
			assert.are.equal(157.5, top.maxWaveSize)
			assert.are.equal(52.5, top.minWaveSize)
		end)

		it("is a no-op when the spec ships no ladder", function()
			local flat = params()
			flat.difficultyRows = nil
			local after = Difficulty.NextCycle(flat, 2, 4000)
			assert.are.equal(180, after.gracePeriod)
			assert.are.equal(3, after.difficultyIndex)
		end)
	end)
end)
