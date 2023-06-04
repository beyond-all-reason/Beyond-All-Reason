

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

for unitDefID, unitDef in pairs(UnitDefs) do
	unitCategories[unitDefID] = categoryGroupMapping[unitDef.customParams.unitgroup] or BUILDCAT_UTILITY
end

return {
	unitGridPos = unitGridPos,
	gridPosUnit = gridPosUnit,
	hasUnitGrid = hasUnitGrid,
	unitCategories = unitCategories,
	uncategorizedGridPos = uncategorizedGridPos,
}
