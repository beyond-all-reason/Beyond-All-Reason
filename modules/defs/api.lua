local Base = VFS.Include("modules/defs/lib/base.lua")

-- What the def post files ask of the base game besides the folds: the steps
-- alldefs_post runs once over all defs rather than per def.
---@class DefsApi
local M = {}

---Runs before any unit def is post-processed.
function M.PrebakeUnitDefs()
	Base.Base().PrebakeUnitDefs()
end

---Runs once every def has been post-processed, over the whole tables.
---@param unitDefs table
---@param weaponDefs table
function M.ModOptionsPost(unitDefs, weaponDefs)
	Base.Base().ModOptions_Post(unitDefs, weaponDefs)
end

return M
