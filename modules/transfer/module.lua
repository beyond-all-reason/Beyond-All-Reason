--- Manifest for the transfer module: what may pass between allied teams.
--- Units, resources and an empty team's assets all move through one pipeline,
--- so a transfer is validated, priced and announced in one place regardless of
--- what is moving or who asked for it.
---@type ModuleManifestFile
return {
	name = "transfer",
	description = "Allied transfer: units, resources, take, and the tax on what flows",
	requires = { "context", "tech" },
}
