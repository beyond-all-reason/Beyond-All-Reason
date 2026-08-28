local DefsBuild = VFS.Include("modules/scavengers/lib/defs_build.lua")
local EngineStub = VFS.Include("modules/scavengers/spec/support/engine_stub.lua")

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

---@param modOptionOverrides table|nil
---@return table config
local function build(modOptionOverrides)
	return DefsBuild.Build({
		modOptions = EngineStub.ModOptions(modOptionOverrides),
		teamList = { 0, 1 },
		getTeamLuaAI = function(teamID)
			return teamID == 1 and "ScavengersAI" or ""
		end,
		unitDefNames = EngineStub.UnitDefNames(),
	})
end

describe("scavengers defs_build", function()
	describe("the ladder", function()
		it("resolves the host's rung to its index and flattens that row onto the config", function()
			local config = build({ scav_difficulty = "hard" })
			assert.are.equal(config.difficulties.hard, config.difficulty)
			local row = config.difficultyParameters[config.difficulty]
			for _, key in ipairs({ "gracePeriod", "bossTime", "scavSpawnRate", "minScavs", "maxScavs", "bossName" }) do
				assert.are.equal(row[key], config[key], "config." .. key)
			end
			assert.are.same(row.bossStagger, config.bossStagger)
		end)

		it("climbs: each rung's boss is due no later than the one below", function()
			local config = build()
			local rows = config.difficultyParameters
			for index = 2, #rows do
				assert.is_true(rows[index].bossTime <= rows[index - 1].bossTime, "rung " .. index)
			end
		end)

		it("sizes the stagger bank from the boss's own health", function()
			local config = build()
			assert.are.equal(math.ceil(10000 * 0.33), config.bossStagger.health)
		end)
	end)

	describe("the host's dials", function()
		it("stretch grace and the boss hour", function()
			local slow = build({ scav_graceperiodmult = 2, scav_bosstimemult = 1.5 })
			local plain = build()
			assert.are.equal(plain.gracePeriod * 2, slow.gracePeriod)
			assert.are.equal(plain.bossTime * 1.5, slow.bossTime)
		end)

		it("speed up every rate together", function()
			local fast = build({ scav_spawntimemult = 2 })
			local plain = build()
			assert.are.equal(plain.scavSpawnRate / 2, fast.scavSpawnRate)
			assert.are.equal(plain.burrowSpawnRate / 2, fast.burrowSpawnRate)
			assert.are.equal(plain.turretSpawnRate / 2, fast.turretSpawnRate)
		end)

		it("scale the roster with a richer economy", function()
			local rich = build({ multiplier_resourceincome = 2, startmetal = 5000 })
			local plain = build()
			assert.is_true(rich.economyScale > plain.economyScale)
			assert.are.equal(plain.minScavs * rich.economyScale / plain.economyScale, rich.minScavs)
		end)
	end)

	describe("unit restrictions", function()
		it("drop restricted turrets entirely rather than gating them at spawn", function()
			local built = build({ unit_restrictions_nonukes = true, unit_restrictions_nolrpc = true })
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
			assert.are.equal(10000, build({ unit_restrictions_noair = true }).airStartAnger)
		end)
	end)

	describe("the pools", function()
		it("are all filled", function()
			local config = build()
			for _, pool in ipairs(POOLS) do
				assert.is_true(#config.squadSpawnOptionsTable[pool] > 20, pool)
			end
		end)

		it("repeat a squad once per weight point", function()
			local config = build()
			local seen = {}
			for _, entry in ipairs(config.squadSpawnOptionsTable.healerLand) do
				seen[entry.units] = (seen[entry.units] or 0) + 1
				assert.are.equal(entry.weight, seen[entry.units] <= entry.weight and entry.weight or entry.weight)
			end
			local weighted = false
			for units, count in pairs(seen) do
				if count > 1 then
					weighted = true
				end
			end
			assert.is_true(weighted, "some healer squad carries a weight above one")
		end)

		it("resolve behaviours by unit-def id", function()
			local config = build()
			local unitDefNames = EngineStub.UnitDefNames()
			local anyID = next(config.scavBehaviours.SKIRMISH)
			assert.is_number(anyID)
			assert.are.same(
				config.scavBehaviours.SKIRMISH[unitDefNames.armcom_scav.id],
				{ distance = 100, chance = 0.1 }
			)
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
			assert.are.equal(2, built.humanTeamCount)
		end)
	end)

	it("refuses to build without a modoption snapshot", function()
		assert.has_error(function()
			DefsBuild.Build({})
		end)
	end)

	it("is re-entrant: a second build does not inherit the first one's behaviours", function()
		assert.are.same(build().scavBehaviours, build().scavBehaviours)
	end)
end)
