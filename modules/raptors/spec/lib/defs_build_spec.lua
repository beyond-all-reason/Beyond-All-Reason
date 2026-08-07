local DefsBuild = VFS.Include("modules/raptors/lib/defs_build.lua")
local EngineStub = VFS.Include("modules/raptors/spec/support/engine_stub.lua")

local POOLS = { "basic", "special", "basicAir", "specialAir", "healer" }

---@param modOptionOverrides table|nil
---@return table config
local function build(modOptionOverrides)
	return DefsBuild.Build({
		modOptions = EngineStub.ModOptions(modOptionOverrides),
		teamList = { 0, 1 },
		getTeamLuaAI = function(teamID)
			return teamID == 1 and "RaptorsAI" or ""
		end,
		unitDefNames = EngineStub.UnitDefNames(),
	})
end

describe("raptors defs_build", function()
	describe("the ladder", function()
		it("resolves the host's rung to its index and flattens that row onto the config", function()
			local config = build({ raptor_difficulty = "hard" })
			assert.are.equal(config.difficulties.hard, config.difficulty)
			local row = config.difficultyParameters[config.difficulty]
			for _, key in ipairs({
				"gracePeriod",
				"queenTime",
				"raptorSpawnRate",
				"minRaptors",
				"maxRaptors",
				"queenName",
			}) do
				assert.are.equal(row[key], config[key], "config." .. key)
			end
			assert.are.same(row.queenStagger, config.queenStagger)
		end)

		it("climbs: each rung's queen is due no later than the one below", function()
			local rows = build().difficultyParameters
			for index = 2, #rows do
				assert.is_true(rows[index].queenTime <= rows[index - 1].queenTime, "rung " .. index)
			end
		end)

		it("sizes the stagger bank from the queen's own health, and names her by rung", function()
			local config = build({ raptor_difficulty = "epic" })
			assert.are.equal(math.ceil(10000 * 0.33), config.queenStagger.health)
			assert.are.equal("raptor_queen_epic", config.queenName)
		end)
	end)

	describe("the host's dials", function()
		it("stretch grace and the queen hour", function()
			local slow = build({ raptor_graceperiodmult = 2, raptor_queentimemult = 1.5 })
			local plain = build()
			assert.are.equal(plain.gracePeriod * 2, slow.gracePeriod)
			assert.are.equal(plain.queenTime * 1.5, slow.queenTime)
		end)

		it("speed up every rate together", function()
			local fast = build({ raptor_spawntimemult = 2 })
			local plain = build()
			assert.are.equal(plain.raptorSpawnRate / 2, fast.raptorSpawnRate)
			assert.are.equal(plain.burrowSpawnRate / 2, fast.burrowSpawnRate)
			assert.are.equal(plain.turretSpawnRate / 2, fast.turretSpawnRate)
		end)

		it("scale the roster with a richer economy", function()
			local rich = build({ multiplier_resourceincome = 2, startmetal = 5000 })
			local plain = build()
			assert.is_true(rich.economyScale > plain.economyScale)
			assert.are.equal(plain.minRaptors * rich.economyScale / plain.economyScale, rich.minRaptors)
		end)
	end)

	describe("unit restrictions", function()
		it("drop the restricted turrets entirely", function()
			local built = build({ unit_restrictions_noair = true, unit_restrictions_nonukes = true })
			assert.is_nil(built.raptorTurrets.raptor_turret_antiair_t2_v1)
			assert.is_nil(built.raptorTurrets.raptor_turret_antinuke_t2_v1)
			assert.is_not_nil(built.raptorTurrets.raptor_turret_basic_t2_v1)
			assert.is_not_nil(build().raptorTurrets.raptor_turret_antiair_t2_v1)
		end)

		it("put the air floor out of the anger clock's reach when air is banned", function()
			assert.are.equal(10000, build({ unit_restrictions_noair = true }).airStartAnger)
		end)
	end)

	describe("the pools", function()
		it("are all filled, in the legacy pool names", function()
			local config = build()
			for _, pool in ipairs(POOLS) do
				assert.is_true(#config.squadSpawnOptionsTable[pool] > 10, pool)
			end
		end)

		it("repeat a squad once per weight point", function()
			local first = build().squadSpawnOptionsTable.basic[1]
			assert.are.equal(10, first.weight)
			local copies = 0
			for _, entry in ipairs(build().squadSpawnOptionsTable.basic) do
				if entry.units == first.units then
					copies = copies + 1
				end
			end
			assert.are.equal(10, copies)
		end)

		it("resolve behaviours by unit-def id, and the probe unit with them", function()
			local config = build()
			local unitDefNames = EngineStub.UnitDefNames()
			assert.are.same(
				{ distance = 300, chance = 1 },
				config.raptorBehaviours.SKIRMISH[unitDefNames.raptor_land_swarmer_emp_t2_v1.id]
			)
			assert.are.equal(unitDefNames.raptor_land_swarmer_basic_t4_v1.id, config.raptorBehaviours.PROBE_UNIT)
		end)

		it("carry the hive, the eggs and the queen's brood", function()
			local config = build()
			assert.are.equal("raptor_hive", config.burrowName)
			assert.are.equal(EngineStub.UnitDefNames().raptor_hive.id, config.burrowDef)
			assert.are.equal("purple", config.raptorEggs.raptor_land_swarmer_basic_t1_v1)
			assert.is_true(#config.miniBosses > 0)
			assert.is_not_nil(config.raptorMinions.raptor_matriarch_electric)
		end)
	end)

	it("discounts gaia and the director's own AI team", function()
		assert.are.equal(0, build().humanTeamCount)
	end)

	it("refuses to build without a modoption snapshot", function()
		assert.has_error(function()
			DefsBuild.Build({})
		end)
	end)

	it("is re-entrant: a second build does not inherit the first one's behaviours", function()
		assert.are.same(build().raptorBehaviours, build().raptorBehaviours)
	end)
end)
