local state = require("modules/defs/state")

local M = {}

---@return { UnitDef_Post: fun(name: string, def: table), WeaponDef_Post: fun(name: string, def: table), ExplosionDef_Post: fun(name: string, def: table), ModOptions_Post: fun(unitDefs: table, weaponDefs: table), PrebakeUnitDefs: fun() }
function M.Base()
	if state.alldefs == nil then
		state.alldefs = require("gamedata/alldefs_post")
	end
	return state.alldefs
end

return M
