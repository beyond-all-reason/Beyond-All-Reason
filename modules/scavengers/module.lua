--- Manifest for the scavengers module: the flavor pack over waves.
---
--- What lives here is everything a wave director cannot know — which units
--- exist, how they behave, what a beacon is called, what the boss is, and how
--- the six difficulty rungs are shaped. The director is in `waves`; this is
--- the roster it draws from and the mechanics only scavengers have.
---@type ModuleManifestFile
return {
	name = "scavengers",
	description = "Scavengers: the roster, the difficulty ladder, and the flavor over the wave director",
	requires = { "context", "waves", "combat" },
}
