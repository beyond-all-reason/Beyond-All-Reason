--- The dials that are not per-difficulty: they are the same on every rung.

return {
	-- Tech anger below which air waves never fire. Zero means "from the
	-- start"; defs_build raises it out of reach when air is restricted.
	airStartAnger = 0,

	-- Creep is the director's territory: beacons prefer to land on it and
	-- structures may only be built on it. Needs the scum gadget.
	useScum = true,

	-- The dropdown a wave announces itself with.
	useWaveMsg = true,

	-- Half-width of the box units spawn in around a beacon, and how much it
	-- grows per failed probe — the reason a wave pours out instead of
	-- stacking on one tile.
	spawnSquare = 90,
	spawnSquareIncrement = 2,

	-- Beacon footprint, used by every placement check.
	burrowSize = 144,

	-- Percent of the normal wave envelope during a boss fight. At 100 the
	-- swarm does not let up while the boss is out.
	bossFightWaveSizeScale = 100,

	-- 0 hold fire, 1 return fire, 2 fire at will, 3 fire at everything.
	-- Scavengers shoot at everything, including features.
	defaultScavFirestate = 3,

	-- Extra boss anger per second from the players' eco footprint, by unit
	-- name, normalised to a sixty-minute boss. Currently empty: the mechanism
	-- is live and priced at zero, which is the state the monolith left it in
	-- after the numbers were commented out.
	ecoBuildingsPenalty = {},

	-- Dynamic difficulty: a live comparison of the director's peak power to
	-- the players'. Below the lower ratio it is losing and gets the full
	-- bonus; above the upper it is winning and gets the penalty.
	dynamicDifficulty = { min = 0.85, max = 1.05, lower = 1 / 6, upper = 1 / 2 },
}
