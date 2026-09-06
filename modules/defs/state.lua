local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

---What the defs module keeps in memory, one table per Lua state.
---@class DefsState
---@field alldefs { UnitDef_Post: fun(name: string, def: table), WeaponDef_Post: fun(name: string, def: table), ExplosionDef_Post: fun(name: string, def: table), ModOptions_Post: fun(unitDefs: table, weaponDefs: table), PrebakeUnitDefs: fun() }|nil gamedata/alldefs_post.lua, included on first use
local state = ModuleHandler.State(Modules.Defs) ---@type DefsState

return state
