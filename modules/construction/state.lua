local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

---What construction keeps in memory, one table per Lua state.
---@class ConstructionState
---@field creationBlocked table<integer, table<integer, boolean>> per team, the defs construction has blocked through GG.BuildBlocking, so it removes only its own
local state = ModuleHandler.State(Modules.Construction) ---@type ConstructionState
state.creationBlocked = state.creationBlocked or {}

return state
