local configs   = VFS.Include('luaui/configs/gridmenu_layouts.lua')
local labGrids  = configs.LabGrids
local unitGrids = configs.UnitGrids

local unitGridPos  = {}
local gridPosUnit  = {}
local hasUnitGrid  = {}
local homeGridPos  = {}
local unitCategories = {}

--------------------------------------------------------------------- constants
local BUILDCAT_ECONOMY    = Spring.I18N("ui.buildMenu.category_econ")
local BUILDCAT_COMBAT     = Spring.I18N("ui.buildMenu.category_combat")
local BUILDCAT_UTILITY    = Spring.I18N("ui.buildMenu.category_utility")
local BUILDCAT_PRODUCTION = Spring.I18N("ui.buildMenu.category_production")

local categories = {
	BUILDCAT_ECONOMY,
	BUILDCAT_COMBAT,
	BUILDCAT_UTILITY,
	BUILDCAT_PRODUCTION
}

local rows, columns = 3, 4          -- 12 cells per “page”

local categoryGroupMapping = {
	energy     = BUILDCAT_ECONOMY,
	metal      = BUILDCAT_ECONOMY,
	builder    = BUILDCAT_PRODUCTION,
	buildert2  = BUILDCAT_PRODUCTION,
	buildert3  = BUILDCAT_PRODUCTION,
	buildert4  = BUILDCAT_PRODUCTION,
	util       = BUILDCAT_UTILITY,
	weapon     = BUILDCAT_COMBAT,
	explo      = BUILDCAT_COMBAT,
	weaponaa   = BUILDCAT_COMBAT,
	weaponsub  = BUILDCAT_COMBAT,
	aa         = BUILDCAT_COMBAT,
	emp        = BUILDCAT_COMBAT,
	sub        = BUILDCAT_COMBAT,
	nuke       = BUILDCAT_COMBAT,
	antinuke   = BUILDCAT_COMBAT,
}

---------------------------------------------------------------- helper: fillUndefined
--  Fills empty indices in `options` with items from `list`, continuing
--  past 24 so we can have as many pages as needed (12 items each).
local function fillUndefined(options, list, ctor)
	local index = 1
	while #list > 0 do
		if not options[index] then
			options[index] = ctor(table.remove(list, 1))
		end
		index = index + 1
	end
end

---------------------------------------------------------------- pre-compute tables
for uname, ugrid in pairs(unitGrids) do
	local builder = UnitDefNames[uname]
	if not builder then
		Spring.Echo('gridmenu config: no unitdefname found for: ' .. uname)
	else
		local builderId = builder.id

		unitGridPos [builderId] = { {}, {}, {}, {} }
		gridPosUnit [builderId] = {}
		hasUnitGrid [builderId] = {}
		homeGridPos [builderId] = { {}, {}, {}, {} }

		local builderCanBuild = {}
		for _, u in ipairs(builder.buildOptions) do
			builderCanBuild[u] = true
		end

		local uncategorizedCount = 0
		for cat = 1, 4 do
			for row = 1, 3 do
				for col = 1, 4 do
					local unitAtPos = ugrid[cat] and ugrid[cat][row] and ugrid[cat][row][col]
					if unitAtPos then
						local unit = UnitDefNames[unitAtPos]
						if unit and unit.id and builderCanBuild[unit.id] then
							gridPosUnit [builderId][cat .. row .. col] = unit.id
							unitGridPos [builderId][cat][unit.id] = cat .. row .. col
							hasUnitGrid [builderId][unit.id] = true
							uncategorizedCount            = uncategorizedCount + 1
							homeGridPos  [builderId][cat][uncategorizedCount] = unit.id
						end
					end
				end
			end
			uncategorizedCount = 0
		end
	end
end

for uname, ugrid in pairs(labGrids) do
	local udef = UnitDefNames[uname]
	if not udef then
		Spring.Echo('gridmenu config: no unitdefname found for: ' .. uname)
	else
		local uid = udef.id

		unitGridPos[uid] = {}
		gridPosUnit[uid] = {}

		local uCanBuild = {}
		for _, u in ipairs(udef.buildOptions) do
			uCanBuild[u] = true
		end

		for r = 1, 3 do
			for c = 1, 4 do
				local index = (r - 1) * 4 + c
				local ugdefName  = ugrid[index]
				if ugdefName then
					local ugDef = UnitDefNames[ugdefName]
					if ugDef and ugDef.id and uCanBuild[ugDef.id] then
						gridPosUnit [uid][r .. c]  = ugDef.id
						unitGridPos [uid][ugDef.id] = r .. c
					end
				end
			end
		end
	end
end

for unitDefID, unitDef in pairs(UnitDefs) do
	unitCategories[unitDefID] = categoryGroupMapping[unitDef.customParams.unitgroup] or BUILDCAT_UTILITY
end

---------------------------------------------------------------- small utilities
local function getCategoryIndex(category)
	if     category == BUILDCAT_ECONOMY    then return 1
	elseif category == BUILDCAT_COMBAT     then return 2
	elseif category == BUILDCAT_UTILITY    then return 3
	elseif category == BUILDCAT_PRODUCTION then return 4 end
end

local function constructBuildOption(uDefID, cmd)
	if not cmd then
		cmd = { id = -uDefID, name = UnitDefs[uDefID].name, params = {} }
	end
	return cmd
end

---------------------------------------------------------------- main builders
local function getGridForCategory(builderId, buildOptions, currentCategory)
	local options, undefinedOpts = {}, {}
	if not currentCategory then return options end

	local categoryIndex = getCategoryIndex(currentCategory)

	for _, opt in pairs(buildOptions) do
		if hasUnitGrid[builderId] and hasUnitGrid[builderId][opt] then
			local key  = unitGridPos[builderId][categoryIndex][opt]
			if key then
				local row = string.sub(key, 2, 2)
				local col = string.sub(key, 3, 3)
				local idx = col + ((row - 1) * columns)
				options[idx] = constructBuildOption(opt)
			end
		elseif unitCategories[opt] == currentCategory then
			table.insert(undefinedOpts, opt)
		end
	end

	fillUndefined(options, undefinedOpts, constructBuildOption)
	return options
end

-- grid indices
-- 9  10 11 12
-- 5   6  7  8
-- 1   2  3  4
function homeOptionsForBuilder(builderId, buildOptions)
	local options = {}
	local uncategorizedOpts = homeGridPos[builderId]

	if uncategorizedOpts then
		local optionsInRow = 0
		for cat = 1, #uncategorizedOpts do
			for _, uDefID in pairs(uncategorizedOpts[cat]) do
				if optionsInRow >= 3 then break end
				optionsInRow = optionsInRow + 1
				local index = cat + ((optionsInRow - 1) * columns)
				options[index] = constructBuildOption(uDefID)
			end
			optionsInRow = 0
		end
	else
		-- if the unit doesn't have a predefined grid we still want the "home" page to have units
		-- So we build all the categories and grab the first 3 items from each one
		local categoryOptions = {}
		for cat = 1, 4 do
			categoryOptions[cat] = getGridForCategory(builderId, buildOptions, categories[cat])
		end
		local optionsInRow = 0
		for cat = 1, 4 do
			for _, opt in pairs(categoryOptions[cat]) do
				if optionsInRow >= 3 then break end
				optionsInRow = optionsInRow + 1
				-- The grid is sorted by row, starting at the bottom. We want to order these items by column, so we switch their positions by changing the index
				local index = cat + ((optionsInRow - 1) * columns)
				options[index] = opt
			end
			optionsInRow = 0
		end
	end
	return options
end

local function getSortedGridForBuilder(builderId, buildOptions, currentCategory)
	if not builderId then return end
	if not currentCategory then
		return homeOptionsForBuilder(builderId, buildOptions)
	end
	return getGridForCategory(builderId, buildOptions, currentCategory)
end

---------------------------------------------------------------- factories / labs
-- labs use cmds instead of buildoptions because they need to have state information like current queue count
local function getSortedGridForLab(builderId, cmds)
	local options, undefinedCmds = {}, {}

	for _, cmd in pairs(cmds) do
		if type(cmd) == "table" and not cmd.disabled then
			local uDefID = -cmd.id
			if string.sub(cmd.action, 1, 10) == 'buildunit_' then
				if unitGridPos[builderId] and unitGridPos[builderId][uDefID] then
					local key  = unitGridPos[builderId][uDefID]
					local row  = string.sub(key, 1, 1)
					local col  = string.sub(key, 2, 2)
					local idx  = col + ((row - 1) * columns)
					options[idx] = constructBuildOption(uDefID, cmd)
				else
					table.insert(undefinedCmds, cmd)
				end
			end
		end
	end

	local function cmdCtor(c) return constructBuildOption(-c.id, c) end
	fillUndefined(options, undefinedCmds, cmdCtor)
	return options
end

--------------------------------------------------------------------- exports
return {
	getSortedGridForBuilder = getSortedGridForBuilder,
	getSortedGridForLab     = getSortedGridForLab,
}
