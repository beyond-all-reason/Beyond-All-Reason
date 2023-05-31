---
--- Created by Hobo Joe.
--- DateTime: 4/26/2023 8:48 PM
---


local configs = VFS.Include('luaui/configs/gridmenu_layouts.lua')
local labGrids = configs.LabGrids
local unitGrids = configs.UnitGrids

local unitName = {}
local unitEnergyCost = {}
local unitMetalCost = {}
local unitGroup = {}
local unitRestricted = {}
local isBuilder = {}
local isFactory = {}
local unitIconType = {}
local isMex = {}
local isWind = {}
local isWaterUnit = {}
local isGeothermal = {}
local unitMaxWeaponRange = {}

local unitGridPos = { }
local gridPosUnit = { }
local hasUnitGrid = { }

local unitCategories = {}

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

local unbaStartBuildoptions = {}
if Spring.GetModOptions().unba then
	VFS.Include("unbaconfigs/buildoptions.lua")
	for unitname,level in pairs(ArmBuildOptions) do
		if level == 1 then
			unbaStartBuildoptions[UnitDefNames[unitname].id] = unitname
		end
	end
	ArmBuildOptions = nil
	for unitname,level in pairs(CorBuildOptions) do
		if level == 1 then
			unbaStartBuildoptions[UnitDefNames[unitname].id] = unitname
		end
	end
	CorBuildOptions = nil
	ArmDefsBuildOptions = nil
	CorDefsBuildOptions = nil
	ArmBuildOptionsStop = nil
	CorBuildOptionsStop = nil
else
	unbaStartBuildoptions = nil
end

function processUnits()
	for uname, ugrid in pairs(unitGrids) do
		local builder = UnitDefNames[uname]
		local uid = builder.id

		unitGridPos[uid] = {{},{},{},{}}
		gridPosUnit[uid] = {}
		hasUnitGrid[uid] = {}
		local uCanBuild = {}

		local uBuilds = builder.buildOptions
		for i = 1, #uBuilds do
			uCanBuild[uBuilds[i]] = true
		end

		for cat=1,4 do
			for r=1,3 do
				for c=1,4 do
					local ugdefname = ugrid[cat] and ugrid[cat][r] and ugrid[cat][r][c]

					if ugdefname then
						local ugdef = UnitDefNames[ugdefname]

						if ugdef and ugdef.id and uCanBuild[ugdef.id] then
							gridPosUnit[uid][cat .. r .. c] = ugdef.id
							unitGridPos[uid][cat][ugdef.id] = cat .. r .. c
							hasUnitGrid[uid][ugdef.id] = true
						end
					end
				end
			end
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
		unitName[unitDefID] = unitDef.name
		unitGroup[unitDefID] = unitDef.customParams.unitgroup
		unitCategories[unitDefID] = categoryGroupMapping[unitDef.customParams.unitgroup] or BUILDCAT_UTILITY

		if unitDef.name == 'armdl' or unitDef.name == 'cordl' or unitDef.name == 'armlance' or unitDef.name == 'cortitan'	-- or unitDef.name == 'armbeaver' or unitDef.name == 'cormuskrat'
			or (unitDef.minWaterDepth > 0 or unitDef.modCategories['ship']) then
			isWaterUnit[unitDefID] = true
		end
		if unitDef.name == 'armthovr' or unitDef.name == 'corintr' then
			isWaterUnit[unitDefID] = nil
		end

		if unitDef.needGeo then
			isGeothermal[unitDefID] = true
		end

		if unitDef.maxWeaponRange > 16 then
			unitMaxWeaponRange[unitDefID] = unitDef.maxWeaponRange
		end

		unitIconType[unitDefID] = unitDef.iconType
		unitEnergyCost[unitDefID] = unitDef.energyCost
		unitMetalCost[unitDefID] = unitDef.metalCost

		if unitDef.maxThisUnit == 0 then
			unitRestricted[unitDefID] = true
		end

		if unitDef.buildSpeed > 0 and unitDef.buildOptions[1] then
			isBuilder[unitDefID] = unitDef.buildOptions
		end

		if unitDef.isFactory and #unitDef.buildOptions > 0 then
			isFactory[unitDefID] = true
		end

		if unitDef.extractsMetal > 0 then
			isMex[unitDefID] = true
		end

		if unitDef.windGenerator > 0 then
			isWind[unitDefID] = true
		end
	end
end

function restrictWindUnits(disable)
	for unitDefID,_ in pairs(isWind) do
		unitRestricted[unitDefID] = disable
	end
end

function restrictGeothermalUnits(disable)
	for unitDefID,_ in pairs(isGeothermal) do
		unitRestricted[unitDefID] = disable
	end
end

function restrictWaterUnits(disable)
	for unitDefID,_ in pairs(isWaterUnit) do
		unitRestricted[unitDefID] = disable
	end
end


processUnits()

------------------------------------
-- UNIT ORDER ----------------------
------------------------------------

local unitOrder = {}
local unitOrderManualOverrideTable = VFS.Include("luaui/configs/buildmenu_sorting.lua")

for unitDefID, _ in pairs(UnitDefs) do
	if unitOrderManualOverrideTable[unitDefID] then
		unitOrder[unitDefID] = -unitOrderManualOverrideTable[unitDefID]
	else
		unitOrder[unitDefID] = 9999999
	end
end

local function getHighestOrderedUnit()
	local highest = { 0, 0, false }
	local firstOrderTest = true
	local newSortingUnit = {}
	for unitDefID, orderValue in pairs(unitOrder) do

		if unitOrderManualOverrideTable[unitDefID] then
			newSortingUnit[unitDefID] = true
		else
			newSortingUnit[unitDefID] = false
		end

		if firstOrderTest == true then
			firstOrderTest = false
			highest = { unitDefID, orderValue, newSortingUnit[unitDefID]}
			--elseif orderValue > highest[2] then
		elseif highest[3] == false and newSortingUnit[unitDefID] == true then
			highest = { unitDefID, orderValue, newSortingUnit[unitDefID]}
		elseif highest[3] == false and newSortingUnit[unitDefID] == false then
			if orderValue > highest[2] then
				highest = { unitDefID, orderValue, newSortingUnit[unitDefID]}
			end
		elseif highest[3] == true and newSortingUnit[unitDefID] == true then
			if orderValue > highest[2] then
				highest = { unitDefID, orderValue, newSortingUnit[unitDefID]}
			end
		end
	end
	return highest[1]
end

local unitsOrdered = {}
for _, _ in pairs(UnitDefs) do
	local uDefID = getHighestOrderedUnit()
	unitsOrdered[#unitsOrdered + 1] = uDefID
	unitOrder[uDefID] = nil
end

unitOrder = unitsOrdered
unitsOrdered = nil

local voidWater = false
local success, mapinfo = pcall(VFS.Include,"mapinfo.lua") -- load mapinfo.lua confs
if success and mapinfo then
	voidWater = mapinfo.voidwater
end

local minWaterUnitDepth = -11


------------------------------------
-- /UNIT ORDER ----------------------
------------------------------------

return {
	unitGrids = unitGrids,
	labGrids = labGrids,

	unbaStartBuildoptions = unbaStartBuildoptions,

	unitName = unitName,
	unitEnergyCost = unitEnergyCost,
	unitMetalCost = unitMetalCost,
	unitGroup = unitGroup,
	unitRestricted = unitRestricted,
	isBuilder = isBuilder,
	isFactory = isFactory,
	unitIconType = unitIconType,
	isMex = isMex,
	isWind = isWind,
	isWaterUnit = isWaterUnit,
	isGeothermal = isGeothermal,
	unitMaxWeaponRange = unitMaxWeaponRange,
	unitGridPos = unitGridPos,
	gridPosUnit = gridPosUnit,
	hasUnitGrid = hasUnitGrid,
	unitCategories = unitCategories,

	minWaterUnitDepth = minWaterUnitDepth,
	unitOrder = unitOrder,

	restrictGeothermalUnits = restrictGeothermalUnits,
	restrictWindUnits = restrictWindUnits,
	restrictWaterUnits = restrictWaterUnits,
}
