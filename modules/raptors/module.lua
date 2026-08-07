--- Manifest for the raptors module: today, only the lobby face of the
--- flavor. The spawner still lives in luarules and reads its raptor_* options
--- exactly as it always has; what moves here is the options themselves and
--- the mode that fields the RaptorsAI. The day raptors migrates onto the
--- wave director, the roster and mechanics land beside them — the same path
--- scavengers took, with the modoptions move as the first step.
---@type ModuleManifestFile
return {
	name = "raptors",
	description = "Raptors: the options and the game mode; the spawner migrates onto waves later",
	requires = { "context", "waves" },
}
