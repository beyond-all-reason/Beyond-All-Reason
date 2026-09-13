local state = VFS.Include("modules/defs/state.lua") ---@type DefsState

local M = {}

---@return { UnitDef_Post: fun(name: string, def: table), WeaponDef_Post: fun(name: string, def: table), ExplosionDef_Post: fun(name: string, def: table), ModOptions_Post: fun(unitDefs: table, weaponDefs: table), PrebakeUnitDefs: fun() }
function M.Base()
	if state.alldefs == nil then
		state.alldefs = VFS.Include("gamedata/alldefs_post.lua")
	end
	return state.alldefs
end

return M
