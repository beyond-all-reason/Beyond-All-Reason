local DefsBuild = VFS.Include("modules/scavengers/lib/defs_build.lua")
local EngineStub = VFS.Include("modules/scavengers/spec/support/engine_stub.lua")
local Packs = VFS.Include("modules/scavengers/lib/packs.lua")
local SpecBuild = VFS.Include("modules/scavengers/lib/spec_build.lua")

local function build(modOptionOverrides, specOverrides)
	local modOptions = EngineStub.ModOptions(modOptionOverrides)
	local config = DefsBuild.Build({
		modOptions = modOptions,
		teamList = { 0, 1 },
		getTeamLuaAI = function(teamID)
			return teamID == 1 and "ScavengersAI" or ""
		end,
		unitDefNames = EngineStub.UnitDefNames(),
	})
	return SpecBuild.Build({
		name = "scavengers",
		config = config,
		modOptions = modOptions,
		teamID = 3,
		allyTeamID = 1,
		teamCount = config.humanTeamCount,
		unitCap = 4000,
		overrides = specOverrides,
	}),
		config
end

describe("scavengers spec_build", function()
	describe("the clocks", function()
		it("makes the boss time absolute — the countdown starts after grace, not at zero", function()
			local spec, config = build()
			assert.are.equal(config.bossTime + config.gracePeriod, spec.params.bossTime)
			assert.are.equal(config.bossTime, spec.params.bossTimeSpan)
		end)

		it("divides the boss hour by the boss dial", function()
			-- legacy quirk kept: the config's boss time ALREADY has the host's multiplier
			-- in it and the tech clock divides by it again, so the two cancel over the
			-- ramp and a host who halves the boss time gets a marginally SLOWER clock
			local config = select(2, build())
			local ramp = 55 * 60
			for _, multiplier in ipairs({ 0.5, 1, 2 }) do
				local spec = build({ scav_bosstimemult = multiplier })
				assert.is.near(ramp + (config.gracePeriod / multiplier), spec.params.techAngerBossTime, 1e-6)
			end
			assert.is_true(
				build({ scav_bosstimemult = 0.5 }).params.techAngerBossTime
					> build({ scav_bosstimemult = 2 }).params.techAngerBossTime
			)
		end)

		it("ramps grace only while a host has stretched it", function()
			local plain = build()
			assert.is_false(plain.params.graceRamp)
			assert.are.equal(plain.params.gracePeriod, plain.params.gracePeriodRamped)

			local stretched = build({ scav_graceperiodmult = 3 })
			assert.is_true(stretched.params.graceRamp)
			assert.are.equal(stretched.params.gracePeriod / 3, stretched.params.gracePeriodRamped)
		end)
	end)

	describe("the wave envelope", function()
		it("scales with team count", function()
			local single = build()
			assert.are.equal(single.params.minWaveSize, single.params.minWaveSize)

			local spec = SpecBuild.Build({
				name = "n",
				config = select(2, build()),
				modOptions = EngineStub.ModOptions(),
				teamID = 3,
				allyTeamID = 1,
				teamCount = 8,
				unitCap = 4000,
			})
			assert.is_true(spec.params.maxWaveSize > single.params.maxWaveSize)
		end)

		it("caps beacon scaling at eight teams and does not cap wave size", function()
			local config = select(2, build())
			local function at(teamCount)
				return SpecBuild.Build({
					name = "n",
					config = config,
					modOptions = EngineStub.ModOptions(),
					teamID = 3,
					allyTeamID = 1,
					teamCount = teamCount,
					unitCap = 4000,
				})
			end
			assert.are.equal(at(8).burrows.maxBurrows, at(40).burrows.maxBurrows)
			assert.is_true(at(40).params.maxWaveSize > at(8).params.maxWaveSize)
		end)
	end)

	describe("the buckets", function()
		it("carry every pool, renamed into the director's vocabulary", function()
			local spec, config = build()
			for _, name in ipairs({
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
			}) do
				assert.are.equal(#config.squadSpawnOptionsTable[name], #spec.buckets[name], name)
				assert.is_string(spec.buckets[name][1].units[1].def)
				assert.is_number(spec.buckets[name][1].units[1].count)
			end
		end)

		it("does not mistake the populations for pools", function()
			local spec = build()
			assert.is_nil(spec.buckets.commanders)
			assert.is_nil(spec.buckets.decoyCommanders)
			assert.is_table(spec.populations.commanders)
			assert.is_table(spec.populations.decoyCommanders)
		end)

		it("shares one translated unit list per squad, not one per weight point", function()
			local spec = build()
			local pool = spec.buckets.basicLand
			-- translating per entry instead of per squad would allocate thousands of duplicate tables at every Start
			local distinct = {}
			for _, entry in ipairs(pool) do
				distinct[entry.units] = true
			end
			local count = 0
			for _ in pairs(distinct) do
				count = count + 1
			end
			assert.is_true(
				count < #pool,
				"expected shared unit tables, got " .. count .. " for " .. #pool .. " entries"
			)
		end)
	end)

	describe("behaviours", function()
		it("fold the roster's categories into one record per unit", function()
			local behaviours = SpecBuild.Behaviours({
				HEALER = { [10] = true },
				ARTILLERY = { [11] = true },
				KAMIKAZE = { [12] = true },
				ALWAYSMOVE = { [13] = true },
				ALWAYSFIGHT = { [14] = true },
				SKIRMISH = { [15] = { distance = 500 } },
				COWARD = {},
				BERSERK = { [16] = {} },
			})
			assert.are.equal("healer", behaviours[10].role)
			assert.are.equal(20, behaviours[10].minLife)
			assert.is_false(behaviours[10].regroup)
			assert.are.equal("artillery", behaviours[11].role)
			assert.are.equal("kamikaze", behaviours[12].role)
			assert.are.equal(100, behaviours[12].minLife)
			assert.are.equal("move", behaviours[13].order)
			assert.are.equal("fight", behaviours[14].order)
			assert.is_true(behaviours[15].prefersFight)
			assert.is_nil(behaviours[16])
		end)

		it("gives a healer both a role and a fight preference", function()
			local behaviours = SpecBuild.Behaviours({ HEALER = { [10] = true } })
			assert.are.equal("healer", behaviours[10].role)
			assert.is_true(behaviours[10].prefersFight)
		end)
	end)

	describe("the boss", function()
		it("is there by default", function()
			local spec = build()
			assert.is_table(spec.boss)
			assert.are.equal(1, spec.boss.count)
			assert.is_string(spec.boss.defName)
		end)

		it("is ABSENT at a count of zero — pressure with no ending of its own", function()
			local spec = build({ scav_boss_count = 0 })
			assert.is_nil(spec.boss)
		end)

		it("takes the host's count", function()
			assert.are.equal(5, build({ scav_boss_count = 5 }).boss.count)
		end)
	end)

	describe("the rest of the seam", function()
		it("keeps the legacy rulesParam namespace", function()
			assert.are.equal("scav", build().rulesParamPrefix)
		end)

		it("carries the endless ladder in the director's shape", function()
			local spec, config = build()
			assert.are.equal(#config.difficultyParameters, #spec.params.difficultyRows)
			assert.are.equal(config.difficultyParameters[1].scavSpawnRate, spec.params.difficultyRows[1].spawnRate)
			assert.are.equal(config.difficultyParameters[1].bossName, spec.params.difficultyRows[1].bossName)
		end)

		it("turns the turret table into structures", function()
			local spec, config = build()
			local name = next(config.scavTurrets)
			assert.are.equal(config.scavTurrets[name].minBossAnger, spec.structures[name].minAnger)
			assert.are.equal(config.scavTurrets[name].surfaceType, spec.structures[name].surface)
		end)

		it("names the priority targets so the director does not need its own list", function()
			local spec, config = build()
			assert.are.same(config.highValueTargets, spec.targets.highValue)
		end)

		it("asks the director to capture what stands in the creep, at the director's defaults", function()
			assert.are.same({}, build().capture)
		end)

		it("records how to rebuild itself after a load", function()
			local spec = build()
			assert.are.equal("scavengers", spec.specRef.module)
		end)

		it("lets a caller pin params over the roster's", function()
			local spec = build(nil, { spawnChance = 0.9, unitCap = 12 })
			assert.are.equal(0.9, spec.params.spawnChance)
			assert.are.equal(12, spec.params.unitCap)
		end)
	end)

	describe("packs", function()
		it("name a director and a way back to this module", function()
			for _, noun in pairs(Packs.Nouns) do
				assert.are.equal("scavengers", noun.module)
				assert.are.equal("waves", noun.domain)
				assert.are.equal("scavengers." .. noun.pack, noun.name)
				assert.is_table(Packs.Presets[noun.pack])
			end
		end)

		it("resolve by pack name", function()
			assert.are.equal(Packs.Nouns.Horde, Packs.Ref("horde"))
			assert.is_nil(Packs.Ref("nosuchpack"))
		end)

		it("pin the roster by rewriting the snapshot, not by patching the result", function()
			local snapshot = Packs.ModOptions("skirmish", EngineStub.ModOptions())
			assert.are.equal("easy", snapshot.scav_difficulty)
			assert.are.equal("avoid", snapshot.scav_scavstart)
			assert.are.equal(0, snapshot.scav_boss_count)
			assert.is_false(snapshot.scav_endless)
		end)

		it("leave the host's choices alone for the multiplayer pack", function()
			local host = EngineStub.ModOptions({ scav_difficulty = "veryhard", scav_endless = true })
			local snapshot = Packs.ModOptions("horde", host)
			assert.are.equal("veryhard", snapshot.scav_difficulty)
			assert.is_true(snapshot.scav_endless)
			assert.are.equal(1, snapshot.scav_boss_count)
		end)

		it("never mutate the snapshot they were given", function()
			local host = EngineStub.ModOptions()
			Packs.ModOptions("skirmish", host)
			assert.are.equal("normal", host.scav_difficulty)
		end)

		it("build a bossless skirmish and a boss-bearing horde from the same roster", function()
			local function specFor(packName)
				local modOptions = Packs.ModOptions(packName, EngineStub.ModOptions())
				local config = DefsBuild.Build({
					modOptions = modOptions,
					teamList = { 0, 1 },
					getTeamLuaAI = function()
						return ""
					end,
					unitDefNames = EngineStub.UnitDefNames(),
				})
				return SpecBuild.Build({
					name = "scavengers." .. packName,
					config = config,
					modOptions = modOptions,
					teamID = 3,
					allyTeamID = 1,
					teamCount = 1,
					unitCap = 4000,
				})
			end
			assert.is_nil(specFor("skirmish").boss)
			assert.is_table(specFor("horde").boss)
			assert.are.equal("avoid", specFor("skirmish").burrows.placement)
			assert.are.equal("initialbox", specFor("horde").burrows.placement)
		end)
	end)
end)
