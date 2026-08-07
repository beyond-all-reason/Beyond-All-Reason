--- BASE numbers, deliberately: defs_build applies the host's multipliers. The legacy file stored
--- them pre-multiplied, so the ladder could only exist inside a running game. Legacy factors:
---   gracePeriod        = minutes * raptor_graceperiodmult * 60
---   bossMinutes        = queenTime minutes (* raptor_queentimemult * 60 -> seconds)
---   waveRate           = raptorSpawnRate / raptor_spawntimemult / economyScale
---   burrowRate         = burrowSpawnRate / raptor_spawntimemult / economyScale
---   turretRate         = turretSpawnRate / raptor_spawntimemult / economyScale
---   maxXP              = * economyScale
---   minUnits, maxUnits = minRaptors, maxRaptors * economyScale
---   bossResistanceMult = queenResistanceMult * economyScale
---   bossStagger.health = ceil(UnitDefNames[bossName].health * healthFraction), built from the engine
---   (bossSpawnMult, angerBonus, spawnChance, damageMod, healthMod, maxBurrows, perPlayerMultiplier: unscaled)

return {
	-- The order IS the ladder; the index is what the raptor_difficulty modoption resolves to.
	order = { "veryeasy", "easy", "normal", "hard", "veryhard", "epic" },

	rows = {
		veryeasy = {
			gracePeriod = 9,
			bossMinutes = 55,
			waveRate = 120,
			burrowRate = 240,
			turretRate = 120,
			bossSpawnMult = 1,
			angerBonus = 0.1,
			maxXP = 0.5,
			spawnChance = 0.1,
			damageMod = 0.4,
			healthMod = 0.5,
			maxBurrows = 1000,
			minUnits = 5,
			maxUnits = 25,
			perPlayerMultiplier = 0.25,
			bossName = "raptor_queen_veryeasy",
			bossResistanceMult = 0.5,
			bossStagger = { healthFraction = 0.33, time = 40 },
		},

		easy = {
			gracePeriod = 8,
			bossMinutes = 50,
			waveRate = 90,
			burrowRate = 210,
			turretRate = 100,
			bossSpawnMult = 1,
			angerBonus = 0.15,
			maxXP = 1,
			spawnChance = 0.2,
			damageMod = 0.6,
			healthMod = 0.75,
			maxBurrows = 1000,
			minUnits = 5,
			maxUnits = 30,
			perPlayerMultiplier = 0.25,
			bossName = "raptor_queen_easy",
			bossResistanceMult = 0.75,
			bossStagger = { healthFraction = 0.33, time = 35 },
		},

		normal = {
			gracePeriod = 7,
			bossMinutes = 45,
			waveRate = 60,
			burrowRate = 180,
			turretRate = 80,
			bossSpawnMult = 3,
			angerBonus = 0.2,
			maxXP = 1.5,
			spawnChance = 0.3,
			damageMod = 0.8,
			healthMod = 1,
			maxBurrows = 1000,
			minUnits = 5,
			maxUnits = 35,
			perPlayerMultiplier = 0.25,
			bossName = "raptor_queen_normal",
			bossResistanceMult = 1,
			bossStagger = { healthFraction = 0.33, time = 30 },
		},

		hard = {
			gracePeriod = 6,
			bossMinutes = 40,
			waveRate = 50,
			burrowRate = 150,
			turretRate = 60,
			bossSpawnMult = 3,
			angerBonus = 0.25,
			maxXP = 2,
			spawnChance = 0.4,
			damageMod = 1,
			healthMod = 1.1,
			maxBurrows = 1000,
			minUnits = 5,
			maxUnits = 40,
			perPlayerMultiplier = 0.25,
			bossName = "raptor_queen_hard",
			bossResistanceMult = 1.33,
			bossStagger = { healthFraction = 0.33, time = 30 },
		},

		veryhard = {
			gracePeriod = 5,
			bossMinutes = 35,
			waveRate = 40,
			burrowRate = 120,
			turretRate = 40,
			bossSpawnMult = 3,
			angerBonus = 0.3,
			maxXP = 2.5,
			spawnChance = 0.5,
			damageMod = 1.2,
			healthMod = 1.25,
			maxBurrows = 1000,
			minUnits = 5,
			maxUnits = 45,
			perPlayerMultiplier = 0.25,
			bossName = "raptor_queen_veryhard",
			bossResistanceMult = 1.67,
			bossStagger = { healthFraction = 0.33, time = 30 },
		},

		epic = {
			gracePeriod = 4,
			bossMinutes = 30,
			waveRate = 30,
			burrowRate = 90,
			turretRate = 20,
			bossSpawnMult = 3,
			angerBonus = 0.35,
			maxXP = 3,
			spawnChance = 0.6,
			damageMod = 1.4,
			healthMod = 1.5,
			maxBurrows = 1000,
			minUnits = 5,
			maxUnits = 50,
			perPlayerMultiplier = 0.25,
			bossName = "raptor_queen_epic",
			bossResistanceMult = 2,
			bossStagger = { healthFraction = 0.33, time = 30 },
		},
	},
}
