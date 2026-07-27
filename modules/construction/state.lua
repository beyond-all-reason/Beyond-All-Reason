local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules

---@class ConstructionState
---@field creationBlocked table<integer, table<integer, boolean>> per team, the defs construction has blocked through GG.BuildBlocking, so it removes only its own
local state = ModuleHandler.State(Modules.Construction) ---@type ConstructionState
state.creationBlocked = state.creationBlocked or {}

return state
