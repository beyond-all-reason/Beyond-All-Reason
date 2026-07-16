--- Public contract of the economy module. Reach it through the module handler:
---
---   local Economy = VFS.Include("modules/module_handler.lua").Get("economy")
---   local results = Economy.WaterfillSolver.SolveToResults(springRepo, teams, getTeamTaxRate)
---
--- The solver is tax-agnostic: callers with a tax policy (the sharing module)
--- pass their own resolver; the default is tax-free. State-agnostic contract
--- (plain `provides` path): everything here is safe in both Lua states, so
--- it stays a plain eager table.

return {
	WaterfillSolver = VFS.Include("modules/economy/waterfill_solver.lua"),
	ShareStats = VFS.Include("modules/economy/share_stats.lua"),
	ManualShareLedger = VFS.Include("modules/economy/manual_share_ledger.lua"),
}
