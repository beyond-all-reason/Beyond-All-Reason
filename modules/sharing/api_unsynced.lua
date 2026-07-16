--- Unsynced contract of the sharing module — the widget-facing surface,
--- merged over api.lua by ModuleHandler.Get. Per-state contracts stay plain
--- eager tables: this file only ever loads in the unsynced state, so nothing
--- here needs lazy-loading guards.

local ModuleHandler = VFS.Include("modules/module_handler.lua")

local PolicyEvaluation = ModuleHandler.Include("modules/sharing/policy_evaluation.lua")

local Resources = ModuleHandler.Include("modules/sharing/resource/shared.lua")
Resources.GetCachedPolicyResult = PolicyEvaluation.CalcResourcePolicyCached

local Units = ModuleHandler.Include("modules/sharing/unit/shared.lua")
Units.GetCachedPolicyResult = PolicyEvaluation.GetUnitPolicyCached
-- widget-side verb grafted onto the unit surface (selection -> synced controller)
Units.ShareUnits = ModuleHandler.Include("modules/sharing/unit/unsynced.lua").ShareUnits

return {
	Resources = Resources,
	Units = Units,
	PolicyViews = {
		Helpers = ModuleHandler.Include("modules/sharing/policy_views/helpers.lua"),
		ApiExtensions = ModuleHandler.Include("modules/sharing/policy_views/api_extensions.lua"),
	},
}
