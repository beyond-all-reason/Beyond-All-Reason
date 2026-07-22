---@type ModuleManifestFile
return {
	name = "sharing",
	version = "0.1.0",
	description = "Team resource & unit sharing: transfer runtime, policies, tech blocking, and the sharing tab UI",
	requires = { "economy" },
	provides = {
		shared = "modules/sharing/api.lua",
		unsynced = "modules/sharing/api_unsynced.lua",
	},
}
