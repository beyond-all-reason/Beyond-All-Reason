local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

---What transfer keeps in memory, one table per Lua state: the controller
---writes, the policy files and the assist tax read, all through this file.
---@class TransferState
---@field taxRateByTeam table<integer, number> refreshed by the resource controller
---@field manualShareLedger table<integer, table<ResourceName, { sent: number, received: number }>> recorded by the controller, folded in by economy_terms
local state = ModuleHandler.State(Modules.Transfer) ---@type TransferState
state.taxRateByTeam = state.taxRateByTeam or {}
state.manualShareLedger = state.manualShareLedger or {}

return state
