--------------------------------------------------------------------------------
-- IceUI build menu - unit categories
--------------------------------------------------------------------------------
-- Sorts every buildable unit into one of four build-menu categories, based on
-- its `customParams.unitgroup` (the same grouping FlowUI's grid menu uses).
--
-- Returns:
--   categoryOf[unitDefID]  -> 1..4  (the category index, never nil)
--   categoryKeys           -> { "econ", "combat", "utility", "production" }
--                             i18n key suffixes for ui.buildMenu.category_*
--   CAT_ECON / CAT_COMBAT / CAT_UTILITY / CAT_PRODUCTION  -> the indices
--
-- A unit whose unitgroup is unknown falls back to the Utility category.
--------------------------------------------------------------------------------

local CAT_ECON       = 1
local CAT_COMBAT     = 2
local CAT_UTILITY    = 3
local CAT_PRODUCTION = 4

-- unitgroup string -> category index (mirrors gridmenu_config.lua mapping)
local groupToCategory = {
	energy    = CAT_ECON,
	metal     = CAT_ECON,
	builder   = CAT_PRODUCTION,
	buildert2 = CAT_PRODUCTION,
	buildert3 = CAT_PRODUCTION,
	buildert4 = CAT_PRODUCTION,
	util      = CAT_UTILITY,
	weapon    = CAT_COMBAT,
	explo     = CAT_COMBAT,
	weaponaa  = CAT_COMBAT,
	weaponsub = CAT_COMBAT,
	aa        = CAT_COMBAT,
	emp       = CAT_COMBAT,
	sub       = CAT_COMBAT,
	nuke      = CAT_COMBAT,
	antinuke  = CAT_COMBAT,
}

-- Group icon folder + which icon file a unitgroup uses. The files in
-- LuaUI/Images/groupicons/ are mostly named after the unitgroup; a couple
-- need remapping (e.g. unitgroup "explo" -> weaponexplo.png).
local GROUPICON_DIR = "LuaUI/Images/groupicons/"
local groupIconFile = {
	energy    = "energy.png",
	metal     = "metal.png",
	builder   = "builder.png",
	buildert2 = "buildert2.png",
	buildert3 = "buildert3.png",
	buildert4 = "buildert4.png",
	util      = "util.png",
	weapon    = "weapon.png",
	explo     = "weaponexplo.png",
	weaponaa  = "weaponaa.png",
	weaponsub = "weaponsub.png",
	aa        = "aa.png",
	emp       = "emp.png",
	sub       = "sub.png",
	nuke      = "nuke.png",
	antinuke  = "antinuke.png",
}

-- precompute the category + group-icon path of every unit def
local categoryOf  = {}
local groupIconOf = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	local group = unitDef.customParams and unitDef.customParams.unitgroup
	categoryOf[unitDefID] = groupToCategory[group] or CAT_UTILITY
	local file = group and groupIconFile[group]
	if file then
		groupIconOf[unitDefID] = GROUPICON_DIR .. file
	end
end

return {
	categoryOf      = categoryOf,
	groupIconOf     = groupIconOf,   -- unitDefID -> group icon file path (or nil)
	categoryKeys    = { "econ", "combat", "utility", "production" },
	CAT_ECON        = CAT_ECON,
	CAT_COMBAT      = CAT_COMBAT,
	CAT_UTILITY     = CAT_UTILITY,
	CAT_PRODUCTION  = CAT_PRODUCTION,
}
