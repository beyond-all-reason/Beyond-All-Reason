--- Manifest for the waves module: the PvE wave director as a library.
---
--- Generic by construction — the director knows anger clocks, archetype
--- cadence, squad composition, burrow and boss lifecycle, spawn drain and
--- squad AI, and nothing about scavengers or raptors. A flavor module hands
--- it a WaveSpec (plain data plus optional hooks) and the same machinery runs
--- the multiplayer mode and a mission's scripted pressure.
---@type ModuleManifestFile
return {
	name = "waves",
	description = "PvE wave director: anger clocks, wave composition, burrow/boss lifecycle, squad AI",
	-- placement, because the director asks it where a burrow can stand. The
	-- requires list is the dependency graph the loader and the editor read, so
	-- an undeclared include is a lie about what this module needs.
	requires = { "context", "placement" },
}
