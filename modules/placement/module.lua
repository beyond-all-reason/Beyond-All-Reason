--- Manifest for the placement module: where a thing can legally stand.
---
--- Every system that puts a unit on the map answers the same question — is
--- this ground I can put something on, and if not, where is the nearest ground
--- that is? A wave director asks it for burrows, a mission roster asks it for
--- its opening world state, and a mission action asks it when it moves a unit.
--- Before this, each answered it separately or not at all: the spawner had a
--- careful cascade, the roster had none, and the move action teleported blind.
---
--- The answer is DETERMINISTIC by construction. No random sampling: the search
--- walks outward from the requested point in a fixed order and takes the first
--- spot that passes, so the same request gives the same answer on every client,
--- in a replay, and in a spec that asserts exact coordinates. That is also why
--- it is the closest possible match — a caller gets where they asked for, or
--- the nearest place the terrain allows, rather than somewhere random that
--- happened to be legal.
---@type ModuleManifestFile
return {
	name = "placement",
	description = "Where a unit can legally stand: deterministic nearest-valid ground",
	requires = {},
}
