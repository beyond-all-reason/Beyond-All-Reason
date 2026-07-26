--- Manifest for the context module: the facts a proposed action is judged on.
--- Assembled once per decision and enriched by whichever module knows something
--- relevant, so registrar and consumer never live in separate registries.
---@type ModuleManifestFile
return {
	name = "context",
	description = "Context factory and the shared policy vocabulary modules enrich",
}
