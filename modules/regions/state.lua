local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules

---@class RegionsState
---@field regions Repository<Region>|nil
local state = ModuleHandler.State(Modules.Regions) ---@type RegionsState

return state
