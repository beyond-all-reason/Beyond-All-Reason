local state = VFS.Include("modules/defs/state.lua") ---@type DefsState

-- The base game's post-processing, gamedata/alldefs_post.lua, included once
-- per Lua state and only on first use: its top level reads modoptions and
-- pulls in the tweak files, which is def-loading work no other state should
-- pay for. Module state, so the fold and the post files see one instance.

local M = {}

---@return { UnitDef_Post: fun(name: string, def: table), WeaponDef_Post: fun(name: string, def: table), ExplosionDef_Post: fun(name: string, def: table), ModOptions_Post: fun(unitDefs: table, weaponDefs: table), PrebakeUnitDefs: fun() }
function M.Base()
	if state.alldefs == nil then
		state.alldefs = VFS.Include("gamedata/alldefs_post.lua")
	end
	return state.alldefs
end

return M
