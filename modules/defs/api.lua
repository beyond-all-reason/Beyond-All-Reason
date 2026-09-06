local Base = VFS.Include("modules/defs/lib/base.lua")

---@class DefsApi
local M = {}

function M.PrebakeUnitDefs()
	Base.Base().PrebakeUnitDefs()
end

---@param unitDefs table
---@param weaponDefs table
function M.ModOptionsPost(unitDefs, weaponDefs)
	Base.Base().ModOptions_Post(unitDefs, weaponDefs)
end

return M
