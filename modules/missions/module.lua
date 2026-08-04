--- Manifest for the mission-runtime module (the CampaignAPI home).
---@type ModuleManifestFile
return {
	name = "missions",
	description = "Mission runtime: trigger engine, authoring DSL, mission loader",
	-- The requires list IS the vocabulary whitelist: what a mission file may
	-- say is exactly what these modules contribute. waves brings the verbs,
	-- scavengers brings the packs those verbs take.
	requires = { "matchflow", "combat", "transfer", "waves", "scavengers", "placement" },
}
