return {
	-- Drop eggs (requires the egg features).
	useEggs = true,

	-- Needs the scum gadget: scum is where turrets may spawn.
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

	-- Tester unit for picking viable spawn positions; some medium sized unit.
	probeUnit = "raptor_land_swarmer_basic_t4_v1",

	-- Zero means from the start; defs_build raises it out of reach (10000) when air is restricted.
	airStartAnger = 0,

	-- Empty on purpose: the legacy table body was entirely commented out.
	ecoBuildingsPenalty = {},
}
