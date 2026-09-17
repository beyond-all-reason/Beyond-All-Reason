local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

---@class TransferState
---@field taxRateByTeam table<integer, number> refreshed by the resource controller
---@field mexRegions MexRegion[]|nil the map's mex regions in elmos, once a layout has been found
---@field mexDeal MexRegionsDeal|nil who holds what, once the deal has run
---@field mexRegionsSource string|nil where the layout came from, for the log
---@field mexTeams MexRegionsTeamStart[]|nil the teams the deal went round
---@field mexGifted table<integer, integer>|nil how many regions departing teams have left each team
---@field manualShareLedger table<integer, table<ResourceName, { sent: number, received: number }>> recorded by the controller, folded in by economy_terms
local state = ModuleHandler.State(Modules.Transfer) ---@type TransferState
state.taxRateByTeam = state.taxRateByTeam or {}
state.manualShareLedger = state.manualShareLedger or {}

return state
