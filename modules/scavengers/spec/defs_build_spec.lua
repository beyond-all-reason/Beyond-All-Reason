local DefsBuild = VFS.Include("modules/scavengers/lib/defs_build.lua")
local EngineStub = VFS.Include("modules/scavengers/spec/support/engine_stub.lua")

local LEGACY = "modules/scavengers/spec/fixtures/legacy_scav_spawn_defs.lua"

--- The golden test for the extraction: 2,971 lines of roster moved into
--- data/ and a builder, proved against a frozen copy of what they replaced.
---
--- Both sides run under one stubbed engine, so anything they disagree about
--- is a difference in the port.

---Stable text for one squad entry, so pools can be compared as multisets.
---
---Pool ORDER is the one thing deliberately not preserved: the old file built
---its pools by walking tables with pairs, so the order was whatever the hash
---happened to give and differed between runs of the same game. The builder
---sorts. Contents must match exactly.
---@param entry table
---@return string
local function squadKey(entry)
	local units = {}
	for _, slot in ipairs(entry.units) do
		units[#units + 1] = slot.unit .. "x" .. tostring(slot.count)
	end
	table.sort(units)
	return table.concat({
		tostring(entry.minAnger),
		tostring(entry.maxAnger),
		tostring(entry.weight),
		table.concat(units, ","),
	}, "|")
end

---@param pool table[]
---@return table<string, integer>
local function multiset(pool)
	local counts = {}
	for _, entry in ipairs(pool) do
		local key = squadKey(entry)
		counts[key] = (counts[key] or 0) + 1
	end
	return counts
end

---@param modOptionOverrides table|nil
---@return table legacy, table built
local function bothConfigs(modOptionOverrides)
	local unitDefNames = EngineStub.UnitDefNames()
	local modOptions = EngineStub.ModOptions(modOptionOverrides)
	local legacy = EngineStub.Load(LEGACY, EngineStub.Env(modOptions, unitDefNames))
	local built = DefsBuild.Build({
		modOptions = modOptions,
		teamList = { 0, 1 },
		getTeamLuaAI = function(teamID)
			return teamID == 1 and "ScavengersAI" or ""
		end,
		unitDefNames = unitDefNames,
	})
	return legacy, built
end

local POOLS = {
	"basicLand",
	"basicSea",
	"basicAirLand",
	"basicAirSea",
	"specialLand",
	"specialSea",
	"specialAirLand",
	"specialAirSea",
	"healerLand",
	"healerSea",
}

describe("scavengers defs_build", function()
	for _, difficulty in ipairs({ "normal", "epic" }) do
		describe("against the frozen roster on " .. difficulty, function()
			local legacy, built

			setup(function()
				legacy, built = bothConfigs({ scav_difficulty = difficulty })
			end)

			it("resolves the same difficulty index and the same live rung", function()
				assert.are.equal(legacy.difficulty, built.difficulty)
				assert.are.same(legacy.difficulties, built.difficulties)
				assert.are.same(legacy.difficultyParameters, built.difficultyParameters)
			end)

			it("flattens the same live values onto the config", function()
				for _, key in ipairs({
					"gracePeriod",
					"bossTime",
					"scavSpawnRate",
					"burrowSpawnRate",
					"turretSpawnRate",
					"bossSpawnMult",
					"angerBonus",
					"maxXP",
					"spawnChance",
					"damageMod",
					"healthMod",
					"maxBurrows",
					"minScavs",
					"maxScavs",
					"scavPerPlayerMultiplier",
					"bossName",
					"bossResistanceMult",
				}) do
					assert.are.equal(legacy[key], built[key], "config." .. key)
				end
				assert.are.same(legacy.bossStagger, built.bossStagger)
			end)

			it("computes the same economy scale", function()
				assert.are.equal(legacy.economyScale, built.economyScale)
			end)

			it("resolves the same behaviours, by unit-def id", function()
				assert.are.same(legacy.scavBehaviours, built.scavBehaviours)
			end)

			it("resolves the same turrets, processed and unprocessed", function()
				assert.are.same(legacy.scavTurrets, built.scavTurrets)
				assert.are.same(legacy.unprocessedScavTurrets, built.unprocessedScavTurrets)
			end)

			it("resolves the same burrow list, tiers and targets", function()
				assert.are.same(legacy.burrowUnitsList, built.burrowUnitsList)
				assert.are.same(legacy.tierConfiguration, built.tierConfiguration)
				assert.are.same(legacy.highValueTargets, built.highValueTargets)
			end)

			it("carries the same commander populations", function()
				assert.are.same(legacy.squadSpawnOptionsTable.commanders, built.squadSpawnOptionsTable.commanders)
				assert.are.same(
					legacy.squadSpawnOptionsTable.decoyCommanders,
					built.squadSpawnOptionsTable.decoyCommanders
				)
			end)

			it("carries the same scalar settings", function()
				for _, key in ipairs({
					"useScum",
					"useWaveMsg",
					"spawnSquare",
					"spawnSquareIncrement",
					"burrowSize",
					"bossFightWaveSizeScale",
					"defaultScavFirestate",
					"airStartAnger",
					"scavSpawnMultiplier",
					"burrowSpawnType",
				}) do
					assert.are.equal(legacy[key], built[key], "config." .. key)
				end
				assert.are.same(legacy.scavMinions, built.scavMinions)
				assert.are.same(legacy.ecoBuildingsPenalty, built.ecoBuildingsPenalty)
			end)

			it("fills every pool — an empty pool would make the comparisons below vacuous", function()
				for _, pool in ipairs(POOLS) do
					assert.is_true(
						#legacy.squadSpawnOptionsTable[pool] > 20,
						pool .. " should be a real pool, got " .. #legacy.squadSpawnOptionsTable[pool]
					)
				end
			end)

			for _, pool in ipairs(POOLS) do
				it("draws the same " .. pool .. " pool", function()
					local expected = legacy.squadSpawnOptionsTable[pool]
					local actual = built.squadSpawnOptionsTable[pool]
					assert.are.equal(#expected, #actual, pool .. " size")
					assert.are.same(multiset(expected), multiset(actual), pool .. " contents")
				end)
			end
		end)
	end

	describe("the host's dials", function()
		it("stretch grace and the boss hour", function()
			local _, slow = bothConfigs({ scav_graceperiodmult = 2, scav_bosstimemult = 1.5 })
			local _, plain = bothConfigs()
			assert.are.equal(plain.gracePeriod * 2, slow.gracePeriod)
			assert.are.equal(plain.bossTime * 1.5, slow.bossTime)
		end)

		it("speed up every rate together", function()
			local _, fast = bothConfigs({ scav_spawntimemult = 2 })
			local _, plain = bothConfigs()
			assert.are.equal(plain.scavSpawnRate / 2, fast.scavSpawnRate)
			assert.are.equal(plain.burrowSpawnRate / 2, fast.burrowSpawnRate)
			assert.are.equal(plain.turretSpawnRate / 2, fast.turretSpawnRate)
		end)

		it("agree with the frozen roster on a stretched game too", function()
			local legacy, built = bothConfigs({
				scav_graceperiodmult = 2.5,
				scav_bosstimemult = 0.5,
				scav_spawntimemult = 3,
				multiplier_resourceincome = 2,
				startmetal = 5000,
			})
			assert.are.equal(legacy.economyScale, built.economyScale)
			assert.are.same(legacy.difficultyParameters, built.difficultyParameters)
		end)
	end)

	describe("unit restrictions", function()
		it("drop restricted turrets entirely rather than gating them at spawn", function()
			local legacy, built = bothConfigs({ unit_restrictions_nonukes = true, unit_restrictions_nolrpc = true })
			assert.are.same(legacy.scavTurrets, built.scavTurrets)
			for name in pairs(built.scavTurrets) do
				local kind
				for _, tier in pairs(built.unprocessedScavTurrets) do
					if tier[name] then
						kind = tier[name].type
					end
				end
				assert.are_not.equal("nuke", kind)
				assert.are_not.equal("lrpc", kind)
			end
		end)

		it("put the air floor out of the anger clock's reach when air is banned", function()
			local legacy, built = bothConfigs({ unit_restrictions_noair = true })
			assert.are.equal(10000, built.airStartAnger)
			assert.are.equal(legacy.airStartAnger, built.airStartAnger)
		end)
	end)

	describe("the human team count", function()
		it("discounts gaia and the director's own AI team", function()
			local built = DefsBuild.Build({
				modOptions = EngineStub.ModOptions(),
				teamList = { 0, 1, 2, 3 },
				getTeamLuaAI = function(teamID)
					return teamID == 3 and "ScavengersAI" or ""
				end,
				unitDefNames = EngineStub.UnitDefNames(),
			})
			-- Teams 0, 1, 2 pass the AI test; one of them is Gaia.
			assert.are.equal(2, built.humanTeamCount)
		end)
	end)

	it("refuses to build without a modoption snapshot", function()
		assert.has_error(function()
			DefsBuild.Build({})
		end)
	end)

	it("is re-entrant: a second build does not inherit the first one's behaviours", function()
		local first = select(2, bothConfigs())
		local second = select(2, bothConfigs())
		assert.are.same(first.scavBehaviours, second.scavBehaviours)
	end)
end)
