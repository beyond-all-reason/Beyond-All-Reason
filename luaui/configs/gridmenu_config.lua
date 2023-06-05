

local configs = VFS.Include('luaui/configs/gridmenu_layouts.lua')
local labGrids = configs.LabGrids
local unitGrids = configs.UnitGrids

local unitGridPos = { }
local gridPosUnit = { }
local hasUnitGrid = { }
local uncategorizedGridPos = { }

local unitCategories = {}

local BUILDCAT_ECONOMY = "Economy"
local BUILDCAT_COMBAT = "Combat"
local BUILDCAT_UTILITY = "Utility"
local BUILDCAT_PRODUCTION = "Build"

local rows = 3
local columns = 4

local categoryGroupMapping = {
	energy = BUILDCAT_ECONOMY,
	metal = BUILDCAT_ECONOMY,
	builder = BUILDCAT_PRODUCTION,
	buildert2 = BUILDCAT_PRODUCTION,
	buildert3 = BUILDCAT_PRODUCTION,
	buildert4 = BUILDCAT_PRODUCTION,
	util = BUILDCAT_UTILITY,
	weapon = BUILDCAT_COMBAT,
	explo = BUILDCAT_COMBAT,
	weaponaa = BUILDCAT_COMBAT,
	weaponsub = BUILDCAT_COMBAT,
	aa = BUILDCAT_COMBAT,
	emp = BUILDCAT_COMBAT,
	sub = BUILDCAT_COMBAT,
	nuke = BUILDCAT_COMBAT,
	antinuke = BUILDCAT_COMBAT,
}

for uname, ugrid in pairs(unitGrids) do
	local builder = UnitDefNames[uname]
	local builderId = builder.id

	unitGridPos[builderId] = { {}, {}, {}, {}}
	gridPosUnit[builderId] = {}
	hasUnitGrid[builderId] = {}
	uncategorizedGridPos[builderId] = { {}, {}, {}, {} }
	local builderCanBuild = {}

	local uBuilds = builder.buildOptions
	for i = 1, #uBuilds do
		builderCanBuild[uBuilds[i]] = true
	end

	local uncategorizedCount = 0;
	for cat=1,4 do
		for row =1,3 do
			for col =1,4 do
				local unitAtPos = ugrid[cat] and ugrid[cat][row] and ugrid[cat][row][col]

				if unitAtPos then
					local unit = UnitDefNames[unitAtPos]

					if unit and unit.id and builderCanBuild[unit.id] then
						gridPosUnit[builderId][cat .. row .. col] = unit.id
						unitGridPos[builderId][cat][unit.id] = cat .. row .. col
						hasUnitGrid[builderId][unit.id] = true
						uncategorizedCount = uncategorizedCount + 1
						uncategorizedGridPos[builderId][cat][uncategorizedCount] = unit.id
					end
				end
			end
		end
		uncategorizedCount = 0;
	end
end

for uname, ugrid in pairs(labGrids) do
	local udef = UnitDefNames[uname]
	local uid = udef.id

	unitGridPos[uid] = {}
	gridPosUnit[uid] = {}
	local uCanBuild = {}

	local uBuilds = udef.buildOptions
	for i = 1, #uBuilds do
		uCanBuild[uBuilds[i]] = true
	end

	for r=1,3 do
		for c=1,4 do
			local index = (r - 1) * 4 + c
			local ugdefname = ugrid[index]

			if ugdefname then
				local ugdef = UnitDefNames[ugdefname]

				if ugdef and ugdef.id and uCanBuild[ugdef.id] then
					gridPosUnit[uid][r .. c] = ugdef.id
					unitGridPos[uid][ugdef.id] = r .. c
				end
			end
		end
	end
end

function dump(o)
	if type(o) == 'table' then
		local s = '{ '
		for k,v in pairs(o) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = ' .. dump(v) .. ','
		end
		return s .. '} '
	else
		return tostring(o)
	end
end

for unitDefID, unitDef in pairs(UnitDefs) do
	unitCategories[unitDefID] = categoryGroupMapping[unitDef.customParams.unitgroup] or BUILDCAT_UTILITY
end

function getCategoryIndex(category)
	if category == BUILDCAT_ECONOMY then return 1
	elseif category == BUILDCAT_COMBAT then return 2
	elseif category == BUILDCAT_UTILITY then return 3
	elseif category == BUILDCAT_PRODUCTION then return 4
	else return nil end
end

function constructBuildOption(uDefID, cmd)
	if not cmd then
		cmd = {
			id = -uDefID,
			name = UnitDefs[uDefID].name,
			params = {}
		}
	end
	return cmd
end


function homeOptionsForBuilder(builderId)
	local options = {}
	local uncategorizedOpts = uncategorizedGridPos[builderId]

	if uncategorizedOpts then
		local optionsInRow = 0
		for cat = 1, #uncategorizedOpts do
			for _, uDefID in pairs(uncategorizedOpts[cat]) do
				if optionsInRow >= 3 then
					break
				end
				optionsInRow = optionsInRow + 1
				-- The grid is sorted by row, starting at the bottom. We want to order these items by column, so we switch their positions by changing the index
				local index = (cat) + ((optionsInRow - 1) * columns)
				options[index] = constructBuildOption(uDefID)
			end
			optionsInRow = 0
		end
	end
	return options
end


function getSortedGridForBuilder(builderId, currentCategory, cmds)
	if not builderId then
		return
	end

	local options = {}

	local isFactory = UnitDefs[builderId] and UnitDefs[builderId].isFactory or false

	-- If it's not a factory and no category is selected, we fill out the "home page"
	if not currentCategory and not isFactory then
		return homeOptionsForBuilder(builderId)
	end

	-- lay out the category
	if currentCategory and not isFactory then
		-- start with preset positions

	end
end

return {
	unitGridPos = unitGridPos,
	gridPosUnit = gridPosUnit,
	hasUnitGrid = hasUnitGrid,
	unitCategories = unitCategories,
	uncategorizedGridPos = uncategorizedGridPos,
	getSortedGridForBuilder = getSortedGridForBuilder,
}
