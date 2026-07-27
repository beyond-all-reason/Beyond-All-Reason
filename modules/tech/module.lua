--- Manifest for the tech module: what a team may build at its tech tier.
--- Transfer reads a team's tier to price a transfer; nothing here reads back.
---@type ModuleManifestFile
return {
	name = "tech",
	description = "Tech tiers: build gating by tier and the tech points UI",
	requires = { "context" },
}
