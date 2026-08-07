return {
	useEggs = true,

	useScum = true,

	useWaveMsg = true,

	-- Growth per unit spawned is the reason a wave pours out instead of stacking on one tile.
	spawnSquare = 90,
	spawnSquareIncrement = 2,

	burrowSize = 144,

	-- Percentage.
	bossFightWaveSizeScale = 10,

	-- 3 = fire at everything, including features.
	defaultRaptorFirestate = 3,

	probeUnit = "raptor_land_swarmer_basic_t4_v1",

	-- zero means from the start
	airStartAnger = 0,

	-- Empty on purpose: the legacy table body was entirely commented out.
	ecoBuildingsPenalty = {},
}
