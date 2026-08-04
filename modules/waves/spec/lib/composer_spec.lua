local Composer = VFS.Include("modules/waves/lib/composer.lua")
local SeededRng = VFS.Include("modules/waves/spec/support/seeded_rng.lua")

local function entry(minAnger, maxAnger, def, count)
	return { minAnger = minAnger, maxAnger = maxAnger, weight = 1, units = { { def = def, count = count or 1 } } }
end

local function composeInput(overrides)
	local input = {
		buckets = {
			basicLand = { entry(0, 100, "grunt", 4) },
			basicSea = { entry(0, 100, "boat", 4) },
			specialLand = { entry(0, 100, "special", 2) },
			basicAirLand = { entry(0, 100, "plane", 2) },
			healerLand = { entry(0, 100, "medic", 1) },
		},
		populations = {},
		burrows = { 11 },
		surfaceOf = function()
			return "land"
		end,
		unitDefCount = function()
			return 0
		end,
		shape = { sizeMultiplier = 1, timeMultiplier = 1, airPercentage = 0, specialPercentage = 0, techAnger = 50 },
		ceiling = 8,
		spawnChance = 1,
		spawnMultiplier = 1,
		airStartAnger = 0,
		techAnger = 50,
		teamCount = 1,
		teamID = 3,
		wave = 7,
		rng = SeededRng.New(42),
		populationCounts = {},
		capScale = 1,
	}
	for key, value in pairs(overrides or {}) do
		input[key] = value
	end
	return input
end

describe("waves composer", function()
	describe("picking a squad", function()
		local bucket = { entry(0, 20, "early"), entry(30, 60, "mid"), entry(70, 100, "late") }

		it("only ever returns a squad whose bracket contains the anger", function()
			for _ = 1, 50 do
				local picked = Composer.Pick(bucket, 45, false, SeededRng.New(math.random(1, 1e6)))
				assert.are.equal("mid", picked.units[1].def)
			end
		end)

		it("answers nil immediately when the bracket is empty, instead of burning rolls", function()
			assert.is_nil(Composer.Pick(bucket, 25, false, SeededRng.New(1)))
			assert.is_nil(Composer.Pick({}, 45, false, SeededRng.New(1)))
			assert.is_nil(Composer.Pick(nil, 45, false, SeededRng.New(1)))
		end)

		it("reaches thirty points ahead on the super-squad roll", function()
			-- 45 is below "late"'s bracket, but within thirty of it.
			assert.is_nil(Composer.Pick({ entry(70, 100, "late") }, 45, false, SeededRng.New(1)))
			local picked = Composer.Pick({ entry(70, 100, "late") }, 45, true, SeededRng.New(1))
			assert.are.equal("late", picked.units[1].def)
		end)

		it("floors the super-squad window, so it never reaches into the opening", function()
			-- max(10, 20-30) = 10: an entry starting at 20 stays out at anger 5.
			assert.is_nil(Composer.Pick({ entry(20, 40, "tier2") }, 5, true, SeededRng.New(1)))
		end)

		it("draws weighted, because a bucket repeats an entry once per weight point", function()
			local heavy = entry(0, 100, "heavy")
			local light = entry(0, 100, "light")
			local weighted = { heavy, heavy, heavy, heavy, heavy, heavy, heavy, heavy, heavy, light }
			local rng = SeededRng.New(7)
			local heavyCount = 0
			for _ = 1, 500 do
				if Composer.Pick(weighted, 50, false, rng).units[1].def == "heavy" then
					heavyCount = heavyCount + 1
				end
			end
			assert.is_true(heavyCount > 400, "expected roughly 9 in 10 heavies, got " .. heavyCount)
		end)
	end)

	describe("choosing a bucket", function()
		it("routes by surface, air roll and special roll", function()
			assert.are.equal("basicLand", Composer.BucketFor("land", false, false))
			assert.are.equal("basicSea", Composer.BucketFor("sea", false, false))
			assert.are.equal("specialLand", Composer.BucketFor("land", false, true))
			assert.are.equal("basicAirSea", Composer.BucketFor("sea", true, false))
			assert.are.equal("specialAirSea", Composer.BucketFor("sea", true, true))
		end)

		it("has no pool for ground that is neither land nor sea", function()
			assert.is_nil(Composer.BucketFor("mixed", false, false))
			assert.is_nil(Composer.BucketFor("death", true, true))
		end)
	end)

	describe("expanding a squad", function()
		it("emits the legacy queue shape, plus the wave tag", function()
			local entries = {}
			Composer.Expand(entries, entry(0, 100, "grunt", 2), {
				burrow = 11,
				team = 3,
				spawnChance = 1,
				wave = 7,
				rng = SeededRng.New(1),
			})
			assert.are.same({
				{ burrow = 11, unitName = "grunt", team = 3, squadID = 1, wave = 7 },
				{ burrow = 11, unitName = "grunt", team = 3, squadID = 2, wave = 7 },
			}, entries)
		end)

		it("always places the first unit, whatever the spawn chance", function()
			local entries = {}
			local added = Composer.Expand(entries, entry(0, 100, "grunt", 10), {
				burrow = 11,
				team = 3,
				spawnChance = 0,
				wave = 1,
				rng = SeededRng.New(1),
			})
			assert.are.equal(1, added)
			assert.are.equal(1, #entries)
		end)

		it("restarts squadID per squad, so the drain knows where squads begin", function()
			local entries = {}
			local ctx = { burrow = 11, team = 3, spawnChance = 1, wave = 1, rng = SeededRng.New(1) }
			Composer.Expand(entries, entry(0, 100, "a", 2), ctx)
			Composer.Expand(entries, entry(0, 100, "b", 2), ctx)
			assert.are.same({ 1, 2, 1, 2 }, {
				entries[1].squadID,
				entries[2].squadID,
				entries[3].squadID,
				entries[4].squadID,
			})
		end)
	end)

	describe("composing a wave", function()
		it("fills to the envelope and stops", function()
			local composed = Composer.ComposeWave(composeInput({ ceiling = 8 }))
			assert.is_true(composed.count > 8)
			assert.is_true(composed.count < 20, "the loop should stop just past the ceiling")
		end)

		it("tags every entry with the wave it belongs to", function()
			local composed = Composer.ComposeWave(composeInput())
			for _, e in ipairs(composed.entries) do
				assert.are.equal(7, e.wave)
				assert.are.equal(3, e.team)
			end
		end)

		it("terminates on ground with no pool instead of spinning", function()
			local composed = Composer.ComposeWave(composeInput({
				surfaceOf = function()
					return "death"
				end,
				spawnMultiplier = 1,
			}))
			assert.are.equal(0, composed.count)
			assert.are.equal(0, #composed.entries)
		end)

		it("sends healers with the first pass only", function()
			local composed = Composer.ComposeWave(composeInput({ ceiling = 100, spawnMultiplier = 0.05 }))
			local medics = 0
			for _, e in ipairs(composed.entries) do
				if e.unitName == "medic" then
					medics = medics + 1
				end
			end
			assert.is_true(medics <= 1, "one healer escort per burrow per wave, got " .. medics)
		end)

		it("draws from the sea pool for a sea burrow", function()
			local composed = Composer.ComposeWave(composeInput({
				surfaceOf = function()
					return "sea"
				end,
			}))
			for _, e in ipairs(composed.entries) do
				assert.are_not.equal("grunt", e.unitName)
			end
		end)
	end)

	describe("population singletons", function()
		local function withCommanders(overrides)
			local base = {
				populations = {
					commanders = { { def = "com", minAnger = 0, maxAnger = 100, maxAlive = 1 } },
				},
				populationCounts = { commanders = 0 },
				buckets = {},
				techAnger = 100,
				teamCount = 8,
				ceiling = 0,
			}
			for key, value in pairs(overrides or {}) do
				base[key] = value
			end
			return composeInput(base)
		end

		local function commandersIn(composed)
			local n = 0
			for _, e in ipairs(composed.entries) do
				if e.unitName == "com" then
					n = n + 1
				end
			end
			return n
		end

		it("never exceeds the def's own alive cap", function()
			local composed = Composer.ComposeWave(withCommanders({
				unitDefCount = function()
					return 1
				end,
			}))
			assert.are.equal(0, commandersIn(composed))
		end)

		it("stays out of the early game: the population ceiling opens with anger", function()
			local composed = Composer.ComposeWave(withCommanders({
				techAnger = 0,
				shape = {
					sizeMultiplier = 1,
					timeMultiplier = 1,
					airPercentage = 0,
					specialPercentage = 0,
					techAnger = 0,
				},
			}))
			assert.are.equal(0, commandersIn(composed))
		end)

		it("claims a def at most once per wave, however many burrows there are", function()
			local composed = Composer.ComposeWave(withCommanders({ burrows = { 11, 12, 13, 14 } }))
			assert.is_true(commandersIn(composed) <= 1)
		end)
	end)

	it("composes a named spawn straight to the queue", function()
		local entries = Composer.ComposeNamed(11, "minion", 4, 3, 1, 2, SeededRng.New(1))
		assert.are.equal(4, #entries)
		assert.are.equal("minion", entries[1].unitName)
		assert.are.equal(2, entries[1].wave)
		assert.are.equal(4, entries[4].squadID)
	end)
end)
