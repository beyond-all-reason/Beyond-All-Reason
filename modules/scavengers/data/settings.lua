return {
	-- Zero means from the start; defs_build raises it out of reach when air is restricted.
	airStartAnger = 0,

	useScum = true,

	useWaveMsg = true,

	-- Growth per failed probe is the reason a wave pours out instead of stacking on one tile.
	spawnSquare = 90,
	spawnSquareIncrement = 2,

	burrowSize = 144,

	bossFightWaveSizeScale = 100,

	-- 3 = fire at everything, including features.
	defaultScavFirestate = 3,

	-- Empty on purpose: the monolith left the mechanism live and priced at zero.
	ecoBuildingsPenalty = {},

	dynamicDifficulty = { min = 0.85, max = 1.05, lower = 1 / 6, upper = 1 / 2 },
}
