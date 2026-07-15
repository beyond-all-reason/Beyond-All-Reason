--- Public contract of the economy module. Reach it through the module handler:
---
---   local Economy = VFS.Include("modules/module_handler.lua").Get("economy")
---   local results = Economy.WaterfillSolver.SolveToResults(springRepo, teams, getTeamTaxRate)
---
--- The solver is tax-agnostic: callers with a tax policy (the sharing module)
--- pass their own resolver; the default is tax-free. Entries resolve lazily
--- and load once per Lua state.

local ModuleHandler = VFS.Include("modules/module_handler.lua")

local exports = {
	WaterfillSolver = "modules/economy/waterfill_solver.lua",
	ShareStats = "modules/economy/share_stats.lua",
	ManualShareLedger = "modules/economy/manual_share_ledger.lua",
}

return setmetatable({}, {
	__index = function(api, key)
		local path = exports[key]
		if not path then
			return nil
		end
		local value = ModuleHandler.Include(path)
		api[key] = value
		return value
	end,
})
