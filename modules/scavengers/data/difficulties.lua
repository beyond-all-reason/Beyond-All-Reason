--- The difficulty ladder: six rungs of base numbers.
---
--- BASE numbers, deliberately. The monolith wrote these already multiplied by
--- the host's modoptions and the economy scale, which meant the whole table
--- could only exist inside a running game and the ladder could not be read
--- anywhere else. Here a rung says 360 seconds of grace; defs_build applies
--- the host's grace multiplier, and endless mode walks the same rungs a
--- second time.
---
--- Reading a rung: gracePeriod is quiet time. bossMinutes is when the boss is
--- due. The three rates are seconds between waves, between beacons, and
--- between structure waves — all divided by the pace dials, so a bigger
--- number is a slower game. spawnChance is the coin every optional spawn
--- takes, which is why it doubles as the game's overall density.

return {
	-- The order IS the ladder: endless mode climbs it in this order, and the
	-- index is what the scav_difficulty modoption resolves to.
	order = { "veryeasy", "easy", "normal", "hard", "veryhard", "epic" },

	rows = {
		veryeasy = {
			gracePeriod = 360,
			bossMinutes = 65,
			waveRate = 240,
			burrowRate = 240,
			turretRate = 500,
			bossSpawnMult = 1,
			angerBonus = 0.1,
			maxXP = 0.1,
			spawnChance = 0.1,
			damageMod = 0.5,
			healthMod = 0.5,
			maxBurrows = 1000,
			minScavs = 15,
			maxScavs = 45,
			perPlayerMultiplier = 0.25,
			bossName = "scavengerbossv4_veryeasy_scav",
			bossResistanceMult = 1,
			bossStagger = { healthFraction = 0.33, time = 40 },
		},

		easy = {
			gracePeriod = 240,
			bossMinutes = 60,
			waveRate = 200,
			burrowRate = 210,
			turretRate = 420,
			bossSpawnMult = 1,
			angerBonus = 0.15,
			maxXP = 0.2,
			spawnChance = 0.2,
			damageMod = 0.75,
			healthMod = 0.75,
			maxBurrows = 1000,
			minScavs = 15,
			maxScavs = 45,
			perPlayerMultiplier = 0.25,
			bossName = "scavengerbossv4_easy_scav",
			bossResistanceMult = 1.5,
			bossStagger = { healthFraction = 0.33, time = 35 },
		},

		normal = {
			gracePeriod = 180,
			bossMinutes = 55,
			waveRate = 180,
			burrowRate = 180,
			turretRate = 380,
			bossSpawnMult = 3,
			angerBonus = 0.2,
			maxXP = 0.3,
			spawnChance = 0.3,
			damageMod = 1,
			healthMod = 1,
			maxBurrows = 1000,
			minScavs = 15,
			maxScavs = 45,
			perPlayerMultiplier = 0.25,
			bossName = "scavengerbossv4_normal_scav",
			bossResistanceMult = 2,
			bossStagger = { healthFraction = 0.33, time = 30 },
		},

		hard = {
			gracePeriod = 160,
			bossMinutes = 50,
			waveRate = 160,
			burrowRate = 150,
			turretRate = 340,
			bossSpawnMult = 3,
			angerBonus = 0.25,
			maxXP = 0.4,
			spawnChance = 0.4,
			damageMod = 1,
			healthMod = 1,
			maxBurrows = 1000,
			minScavs = 20,
			maxScavs = 60,
			perPlayerMultiplier = 0.25,
			bossName = "scavengerbossv4_hard_scav",
			bossResistanceMult = 2.5,
			bossStagger = { healthFraction = 0.33, time = 30 },
		},

		veryhard = {
			gracePeriod = 140,
			bossMinutes = 45,
			waveRate = 140,
			burrowRate = 120,
			turretRate = 320,
			bossSpawnMult = 3,
			angerBonus = 0.30,
			maxXP = 0.5,
			spawnChance = 0.5,
			damageMod = 1,
			healthMod = 1,
			maxBurrows = 1000,
			minScavs = 25,
			maxScavs = 75,
			perPlayerMultiplier = 0.25,
			bossName = "scavengerbossv4_veryhard_scav",
			bossResistanceMult = 3,
			bossStagger = { healthFraction = 0.33, time = 30 },
		},

		epic = {
			gracePeriod = 120,
			bossMinutes = 40,
			waveRate = 120,
			burrowRate = 90,
			turretRate = 260,
			bossSpawnMult = 3,
			angerBonus = 0.35,
			maxXP = 0.6,
			spawnChance = 0.6,
			damageMod = 1,
			healthMod = 1,
			maxBurrows = 1000,
			minScavs = 30,
			maxScavs = 90,
			perPlayerMultiplier = 0.25,
			bossName = "scavengerbossv4_epic_scav",
			bossResistanceMult = 3.5,
			bossStagger = { healthFraction = 0.33, time = 30 },
		},
	},
}
