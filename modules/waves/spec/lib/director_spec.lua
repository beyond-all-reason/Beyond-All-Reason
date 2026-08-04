local Director = VFS.Include("modules/waves/lib/director.lua")
local SeededRng = VFS.Include("modules/waves/spec/support/seeded_rng.lua")

local function squad(minAnger, maxAnger, def, count)
	return { minAnger = minAnger, maxAnger = maxAnger, weight = 1, units = { { def = def, count = count } } }
end

local function makeSpec(overrides)
	local spec = {
		name = "testwaves",
		teamID = 3,
		allyTeamID = 1,
		rulesParamPrefix = "test",
		params = {
			gracePeriod = 180,
			gracePeriodRamped = 180,
			graceRamp = false,
			bossTime = 1180,
			bossTimeSpan = 1000,
			techAngerBossTime = 1180,
			spawnRate = 60,
			turretSpawnRate = 300,
			minWaveSize = 4,
			maxWaveSize = 20,
			bossFightWaveSizeScale = 100,
			economyScale = 1,
			perPlayerMultiplier = 0.25,
			spawnMultiplier = 1,
			spawnChance = 1,
			angerBonus = 0.2,
			maxXP = 0.3,
			airStartAnger = 10000,
			tier2MinAnger = 5,
			teamCount = 1,
			unitCap = 5000,
			endless = false,
		},
		buckets = { basicLand = { squad(0, 1000, "grunt", 4) } },
		populations = {},
		burrows = {
			defs = { burrow_t1 = { minAnger = 0, maxAnger = 1000 } },
			placement = "initialbox",
			size = 144,
			spawnSquare = 90,
			spawnSquareIncrement = 2,
			useScum = false,
			maxBurrows = 20,
			spawnRate = 90,
		},
		structures = nil,
		boss = { defName = "bigboss", count = 1, minHealthFraction = 0.2 },
		aggression = { burrowKilled = 0.2, ecoPenalty = {} },
		events = { toLuaUI = "TestEvent", useWaveMsg = true },
		hooks = {},
	}
	for key, value in pairs(overrides or {}) do
		spec[key] = value
	end
	return spec
end

local function makeWorld(overrides)
	local world = {
		frame = 0,
		time = 0,
		random = SeededRng.New(4242),
		burrows = { 11, 12 },
		surfaceOf = function()
			return "land"
		end,
		unitDefCount = function()
			return 0
		end,
		teamUnitCount = 0,
		peakPower = 100,
		playerPower = 400,
	}
	for key, value in pairs(overrides or {}) do
		world[key] = value
	end
	return world
end

---`drain` obeys the drain order the way the real gadget does; without it the
---cadence never advances, since a wave never starts while the last is queued.
---@param drain boolean|nil default true
local function run(director, world, from, to, drain)
	local seen = {}
	local nextUnitID = 1000
	for frame = from, to do
		world.frame = frame
		world.time = frame / 30
		for _, order in ipairs(director.Tick(world)) do
			seen[#seen + 1] = order
			if order.kind == "drain" and drain ~= false then
				local entry = table.remove(director.state.spawnQueue, 1)
				if entry ~= nil then
					nextUnitID = nextUnitID + 1
					director.OnUnitSpawned(nextUnitID, entry)
				end
			end
		end
	end
	return seen
end

local function ofKind(orders, kind)
	local out = {}
	for _, order in ipairs(orders) do
		if order.kind == kind then
			out[#out + 1] = order
		end
	end
	return out
end

describe("waves director", function()
	describe("start", function()
		it("copies the mutable dials out of the spec, leaving the spec alone", function()
			local spec = makeSpec()
			local director = Director.New(spec, SeededRng.New(1))
			director.state.params.spawnChance = 0.05
			director.state.params.placement = "initialbox_post"
			assert.are.equal(1, spec.params.spawnChance)
			assert.are.equal("initialbox", spec.burrows.placement)
			assert.are.equal(90, director.state.params.burrowSpawnRate)
			assert.are.equal(20, director.state.params.maxBurrows)
		end)

		it("refuses a spec with no name", function()
			assert.has_error(function()
				Director.New({ params = {} }, SeededRng.New(1))
			end)
		end)

		it("flattens populations into a stable order, because pairs order is not a wire value", function()
			local indexed = Director.IndexPopulations({
				commanders = {
					zeta = { minAnger = 1, maxAnger = 2, maxAlive = 1 },
					alpha = { minAnger = 3, maxAnger = 4, maxAlive = 2 },
					mid = { minAnger = 5, maxAnger = 6, maxAlive = 3 },
				},
			})
			assert.are.same({ "alpha", "mid", "zeta" }, {
				indexed.commanders[1].def,
				indexed.commanders[2].def,
				indexed.commanders[3].def,
			})
			assert.are.equal(2, indexed.commanders[1].maxAlive)
		end)
	end)

	describe("the grace period", function()
		it("composes no waves at all", function()
			local director = Director.New(makeSpec(), SeededRng.New(1))
			local orders = run(director, makeWorld(), 0, 180 * 30)
			assert.are.equal(0, #ofKind(orders, "wave"))
			assert.are.equal(0, director.Status().waveNumber)
		end)

		it("still spawns burrows, so the map is not empty when grace ends", function()
			local director = Director.New(makeSpec(), SeededRng.New(1))
			local orders = run(director, makeWorld({ burrows = {} }), 0, 120 * 30)
			assert.is_true(#ofKind(orders, "burrow") > 0)
		end)

		it("announces the first wave exactly once", function()
			local director = Director.New(makeSpec(), SeededRng.New(1))
			local orders = run(director, makeWorld(), 0, 400 * 30)
			local announcements = 0
			for _, order in ipairs(ofKind(orders, "event")) do
				if order.name == "firstWave" then
					announcements = announcements + 1
				end
			end
			assert.are.equal(1, announcements)
		end)
	end)

	describe("waves", function()
		it("keep the opening appointment whatever the intensity dial says", function()
			local function firstWaveTime(intensity)
				local director = Director.New(makeSpec(), SeededRng.New(1))
				director.SetIntensity(intensity)
				director.state.firstWaveDue = director.state.params.gracePeriod + 10
				local orders = run(director, makeWorld(), 0, 600 * 30)
				return ofKind(orders, "wave")[1]
			end
			assert.is_not_nil(firstWaveTime(0.2), "a quiet director still opens on time")
			assert.is_not_nil(firstWaveTime(1))
		end)

		it("start after grace and keep coming", function()
			local director = Director.New(makeSpec(), SeededRng.New(1))
			local orders = run(director, makeWorld(), 0, 600 * 30)
			local waves = ofKind(orders, "wave")
			assert.is_true(#waves >= 3, "expected several waves in seven minutes, got " .. #waves)
			assert.is_true(waves[1].count > 0)
		end)

		it("queues what it composed, in the drain's own shape", function()
			local director = Director.New(makeSpec(), SeededRng.New(1))
			run(director, makeWorld(), 0, 300 * 30, false)
			local queued = director.state.spawnQueue
			assert.is_true(#queued > 0)
			assert.are.equal("grunt", queued[1].unitName)
			assert.are.equal(3, queued[1].team)
			assert.are.equal(1, queued[1].wave)
		end)

		it("holds off while the previous wave is still queued", function()
			local director = Director.New(makeSpec(), SeededRng.New(1))
			run(director, makeWorld(), 0, 300 * 30, false)
			local before = director.Status().waveNumber
			assert.are.equal(1, before)
			run(director, makeWorld(), 300 * 30, 900 * 30, false)
			assert.are.equal(before, director.Status().waveNumber)
		end)

		it("skips the wave entirely when power is unknown, rather than calling it easy", function()
			local spec = makeSpec()
			spec.params.dynamicDifficulty = { min = 0.85, max = 1.05, lower = 1 / 6, upper = 1 / 2 }
			local director = Director.New(spec, SeededRng.New(1))
			local orders = run(director, makeWorld({ peakPower = 0 }), 0, 600 * 30)
			assert.are.equal(0, #ofKind(orders, "wave"))
		end)

		it("composes a bigger wave when the players are ahead on power", function()
			local function ceilingWith(peak)
				local spec = makeSpec()
				spec.params.dynamicDifficulty = { min = 0.85, max = 1.05, lower = 1 / 6, upper = 1 / 2 }
				local director = Director.New(spec, SeededRng.New(1))
				local orders = run(director, makeWorld({ peakPower = peak, playerPower = 400 }), 0, 400 * 30)
				return ofKind(orders, "wave")[1].ceiling
			end
			assert.is_true(ceilingWith(1) > ceilingWith(300))
		end)
	end)

	describe("the intensity dial", function()
		it("scales the envelope up and the gap down", function()
			local function firstWave(intensity)
				local director = Director.New(makeSpec(), SeededRng.New(1))
				director.SetIntensity(intensity)
				local orders = run(director, makeWorld(), 0, 600 * 30)
				return ofKind(orders, "wave")
			end
			local quiet = firstWave(0.3)
			local loud = firstWave(2)
			assert.is_true(loud[1].ceiling > quiet[1].ceiling)
			assert.is_true(#loud >= #quiet)
		end)

		it("is state, so it travels in the savegame", function()
			local director = Director.New(makeSpec(), SeededRng.New(1))
			director.SetIntensity(0.4)
			assert.are.equal(0.4, director.GetState().intensity)
			assert.are.equal(0.4, director.Status().intensity)
		end)

		it("refuses a negative dial", function()
			local director = Director.New(makeSpec(), SeededRng.New(1))
			assert.has_error(function()
				director.SetIntensity(-1)
			end)
		end)
	end)

	describe("surge", function()
		it("brings the next wave forward and makes it bigger", function()
			local director = Director.New(makeSpec(), SeededRng.New(1))
			run(director, makeWorld(), 0, 200 * 30)
			director.state.spawnQueue = {}
			director.Surge()
			local orders = run(director, makeWorld(), 200 * 30, 202 * 30)
			local waves = ofKind(orders, "wave")
			assert.are.equal(1, #waves)
			assert.are.equal(3, director.state.shape.sizeMultiplier)
		end)

		it("is consumed by exactly one wave", function()
			local director = Director.New(makeSpec(), SeededRng.New(1))
			director.Surge()
			assert.is_not_nil(director.state.surge)
			run(director, makeWorld(), 0, 400 * 30)
			assert.is_nil(director.state.surge)
		end)

		it("takes overrides", function()
			local director = Director.New(makeSpec(), SeededRng.New(1))
			director.Surge({ sizeMultiplier = 9 })
			assert.are.equal(9, director.state.surge.sizeMultiplier)
		end)
	end)

	describe("the first-waves boost", function()
		it("multiplies the opening waves and decays by one per wave", function()
			-- Squads of one from one burrow, so the composed count follows the
			-- ceiling instead of landing in whole squads.
			local function bigSpec(boost)
				local spec = makeSpec({ buckets = { basicLand = { squad(0, 1000, "grunt", 1) } } })
				spec.params.minWaveSize = 40
				spec.params.maxWaveSize = 80
				spec.params.firstWavesBoost = boost
				return spec
			end
			local world = makeWorld({ burrows = { 11 } })
			local director = Director.New(bigSpec(3), SeededRng.New(1))
			local waves = ofKind(run(director, world, 0, 600 * 30), "wave")
			assert.is_true(#waves >= 3, "expected several waves, got " .. #waves)
			local baseline = ofKind(
				run(Director.New(bigSpec(1), SeededRng.New(1)), makeWorld({ burrows = { 11 } }), 0, 600 * 30),
				"wave"
			)
			assert.is_true(waves[1].ceiling > 2 * baseline[1].ceiling, "the first ceiling should be tripled")
			assert.is_true(waves[1].count > baseline[1].count, "the first wave should be boosted")
			assert.are.equal(1, director.state.params.firstWavesBoost)
		end)

		it("drains every frame while it lasts", function()
			local spec = makeSpec()
			spec.params.firstWavesBoost = 2
			local director = Director.New(spec, SeededRng.New(1))
			local orders = director.Tick(makeWorld({ frame = 1 }))
			assert.are.equal(1, #ofKind(orders, "drain"))
			spec.params.firstWavesBoost = 1
			director.state.params.firstWavesBoost = 1
			orders = director.Tick(makeWorld({ frame = 1 }))
			assert.are.equal(0, #ofKind(orders, "drain"))
		end)
	end)

	describe("the boss", function()
		it("is ordered once the countdown lands", function()
			local director = Director.New(makeSpec(), SeededRng.New(1))
			local orders = run(director, makeWorld(), 0, 1200 * 30)
			assert.is_true(#ofKind(orders, "boss") > 0)
		end)

		it("stops being ordered once the spec's count is out", function()
			local director = Director.New(makeSpec(), SeededRng.New(1))
			run(director, makeWorld(), 0, 1190 * 30)
			director.OnBossSpawned(500, 10000)
			local orders = run(director, makeWorld(), 1190 * 30, 1300 * 30)
			assert.are.equal(0, #ofKind(orders, "boss"))
		end)

		it("reports the cycle complete only when the last one dies", function()
			local spec = makeSpec()
			spec.boss.count = 2
			local director = Director.New(spec, SeededRng.New(1))
			director.OnBossSpawned(500, 10000)
			director.OnBossSpawned(501, 10000)
			assert.is_false(director.OnBossKilled(500))
			assert.is_true(director.OnBossKilled(501))
			assert.are.equal(2, director.Status().bossesKilled)
		end)

		it("ignores a death that was not one of its bosses", function()
			local director = Director.New(makeSpec(), SeededRng.New(1))
			assert.is_false(director.OnBossKilled(999))
			assert.are.equal(0, director.Status().bossesKilled)
		end)
	end)

	describe("wave clearing", function()
		it("counts a wave cleared when its last unit dies", function()
			local director = Director.New(makeSpec(), SeededRng.New(1))
			director.state.waveNumber = 1
			director.OnUnitSpawned(21, { wave = 1, unitName = "grunt" })
			director.OnUnitSpawned(22, { wave = 1, unitName = "grunt" })
			assert.is_false(director.OnUnitDestroyed(21))
			assert.are.equal(0, director.Status().wavesCleared)
			assert.is_true(director.OnUnitDestroyed(22))
			assert.are.equal(1, director.Status().wavesCleared)
		end)

		it("ignores deaths of units that never came from a wave", function()
			local director = Director.New(makeSpec(), SeededRng.New(1))
			assert.is_false(director.OnUnitDestroyed(77))
			assert.are.equal(0, director.Status().wavesCleared)
		end)

		it("never double-counts a wave", function()
			local director = Director.New(makeSpec(), SeededRng.New(1))
			director.OnUnitSpawned(21, { wave = 4, unitName = "grunt" })
			assert.is_true(director.OnUnitDestroyed(21))
			assert.is_false(director.OnUnitDestroyed(21))
			assert.are.equal(1, director.Status().wavesCleared)
		end)
	end)

	describe("the endless reloop", function()
		it("resets the clocks and replaces the params table", function()
			local director = Director.New(makeSpec({ params = nil }), SeededRng.New(1))
			run(director, makeWorld(), 0, 600 * 30)
			local before = director.state.params
			director.state.anger.aggressionLevel = 42
			director.NextCycle(600)
			assert.are_not.equal(before, director.state.params)
			assert.are.equal(0, director.state.anger.aggressionLevel)
			assert.are.equal(2, director.Status().cycle)
			assert.is_true(director.state.anger.pastFirstBoss)
			assert.are.equal(0, #director.state.spawnQueue)
		end)

		it("does not re-announce the first wave", function()
			local director = Director.New(makeSpec(), SeededRng.New(1))
			director.NextCycle(600)
			local orders = run(director, makeWorld(), 600 * 30, 900 * 30)
			for _, order in ipairs(ofKind(orders, "event")) do
				assert.are_not.equal("firstWave", order.name)
			end
		end)
	end)

	describe("aggression", function()
		it("rises when a burrow is razed and drifts the veterancy ceiling", function()
			local director = Director.New(makeSpec(), SeededRng.New(1))
			local xpBefore = director.state.params.maxXP
			director.OnBurrowKilled()
			assert.are.equal(0.2, director.state.anger.aggression)
			assert.is_true(director.state.params.maxXP > xpBefore)
		end)

		it("takes an eco structure only when the spec prices that def", function()
			local spec = makeSpec()
			spec.aggression.ecoPenalty = { [77] = 0.0005 }
			local director = Director.New(spec, SeededRng.New(1))
			director.OnEcoStructure(88, 1)
			assert.are.equal(0, director.state.anger.ecoValue)
			director.OnEcoStructure(77, 1)
			assert.is_true(director.state.anger.ecoValue > 0)
		end)
	end)

	describe("stop", function()
		it("silences the director without unwinding anything", function()
			local director = Director.New(makeSpec(), SeededRng.New(1))
			run(director, makeWorld(), 0, 300 * 30)
			local waves = director.Status().waveNumber
			director.Stop()
			local orders = run(director, makeWorld(), 300 * 30, 900 * 30)
			assert.are.equal(0, #orders)
			assert.are.equal(waves, director.Status().waveNumber)
			assert.is_false(director.Status().active)
		end)
	end)

	describe("hooks", function()
		it("tells the flavor module what a wave composed", function()
			local seen
			local spec = makeSpec()
			spec.hooks.onWaveComposed = function(_, count)
				seen = count
			end
			local director = Director.New(spec, SeededRng.New(1))
			run(director, makeWorld(), 0, 300 * 30)
			assert.is_number(seen)
			assert.is_true(seen > 0)
		end)

		it("plays fine with no hooks at all", function()
			local director = Director.New(makeSpec(), SeededRng.New(1))
			assert.has_no.errors(function()
				run(director, makeWorld(), 0, 400 * 30)
				director.OnBossSpawned(1, 100)
				director.OnBossKilled(1)
			end)
		end)
	end)

	it("lays saved progress back over a freshly built spec", function()
		local director = Director.New(makeSpec(), SeededRng.New(1))
		run(director, makeWorld(), 0, 400 * 30)
		local saved = director.GetState()

		local reloaded = Director.New(makeSpec(), SeededRng.New(1))
		reloaded.SetState(saved)
		assert.are.same(director.Status(), reloaded.Status())
	end)
end)

--- Box widening is pure geometry, so it specs without a map.
describe("waves box widening", function()
	local Placement = VFS.Include("modules/waves/spring/placement.lua")
	local placement = Placement.New({
		positionChecks = {},
		enemyLib = {},
		mapSizeX = 4096,
		mapSizeZ = 4096,
	})

	local ORIGIN = { x1 = 2969, z1 = 102, x2 = 3993, z2 = 1126 }

	it("keeps the centre for a box with room to grow", function()
		local middle = { x1 = 1800, z1 = 1800, x2 = 2300, z2 = 2300 }
		local wider = placement.WidenBox(middle, 3)
		assert.is.near(2050, (wider.x1 + wider.x2) / 2, 1e-6)
		assert.is.near(2050, (wider.z1 + wider.z2) / 2, 1e-6)
	end)

	it("always still contains the box it grew from — the author's corner stays in", function()
		for _, multiplier in ipairs({ 2, 3, 5, 40 }) do
			local wider = placement.WidenBox(ORIGIN, multiplier)
			assert.is_true(
				wider.x1 <= ORIGIN.x1 and wider.x2 >= ORIGIN.x2,
				"round " .. multiplier .. " dropped the origin on x"
			)
			assert.is_true(
				wider.z1 <= ORIGIN.z1 and wider.z2 >= ORIGIN.z2,
				"round " .. multiplier .. " dropped the origin on z"
			)
		end
	end)

	it("grows with the retry round, up to the point the direction stops reading", function()
		local first = placement.WidenBox(ORIGIN, 3)
		assert.is_true((first.x2 - first.x1) > (ORIGIN.x2 - ORIGIN.x1))

		-- Unbounded, this reached the whole map in six rounds, and a compressed grace
		-- period spends six rounds in seconds: "from the northeast" meant "next to the player".
		local far = placement.WidenBox(ORIGIN, 40)
		assert.is_true(
			(far.x2 - far.x1) <= 4096 * 0.5 + 1e-6,
			"widened past half the map on x: " .. tostring(far.x2 - far.x1)
		)
		assert.is_true(
			(far.z2 - far.z1) <= 4096 * 0.5 + 1e-6,
			"widened past half the map on z: " .. tostring(far.z2 - far.z1)
		)
	end)

	it("keeps the far side of the map out of a named corner's reach, forever", function()
		for _, multiplier in ipairs({ 3, 4, 8, 40, 400 }) do
			local wider = placement.WidenBox(ORIGIN, multiplier)
			assert.is_true(wider.x1 > 2048 - 1024 - 1e-6, "round " .. multiplier .. " reached west of centre")
			assert.is_true(wider.z2 < 2048 + 1024 + 1e-6, "round " .. multiplier .. " reached south of centre")
		end
	end)

	it("clamps to the map instead of probing off the edge", function()
		local huge = placement.WidenBox(ORIGIN, 40)
		assert.is_true(huge.x1 >= 0 and huge.z1 >= 0)
		assert.is_true(huge.x2 <= 4096 and huge.z2 <= 4096)
	end)

	it("never shrinks below the box it was given", function()
		local same = placement.WidenBox(ORIGIN, 2)
		assert.is_true((same.x2 - same.x1) >= (ORIGIN.x2 - ORIGIN.x1) - 1e-6)
	end)
end)
