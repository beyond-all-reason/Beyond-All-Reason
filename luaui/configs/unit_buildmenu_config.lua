---
--- Created by Hobo Joe.
--- DateTime: 4/26/2023 8:48 PM
---


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

local showWaterUnits = false

for unitDefID, unitDef in pairs(UnitDefs) do

	unitGroup[unitDefID] = unitDef.customParams.unitgroup

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

local function restrictWindUnits(disable)
	for unitDefID,_ in pairs(isWind) do
		unitRestricted[unitDefID] = disable
	end
end

local function restrictGeothermalUnits(disable)
	Spring.Echo("restricting geo units", disable)
	for unitDefID,_ in pairs(isGeothermal) do
		unitRestricted[unitDefID] = disable
	end
end

local function restrictWaterUnits(disable)
	for unitDefID,_ in pairs(isWaterUnit) do
		unitRestricted[unitDefID] = disable
	end
end

local function checkGeothermalFeatures()
	local hideGeoUnits = true
	local geoThermalFeatures = {}
	for defID, def in pairs(FeatureDefs) do
		if def.geoThermal then
			geoThermalFeatures[defID] = true
		end
	end
	local features = Spring.GetAllFeatures()
	for i = 1, #features do
		if geoThermalFeatures[Spring.GetFeatureDefID(features[i])] then
			hideGeoUnits = false
			break
		end
	end
	restrictGeothermalUnits(hideGeoUnits)
end


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

	minWaterUnitDepth = minWaterUnitDepth,
	unitOrder = unitOrder,

	showWaterUnits = showWaterUnits,

	checkGeothermalFeatures = checkGeothermalFeatures,
	restrictGeothermalUnits = restrictGeothermalUnits,
	restrictWindUnits = restrictWindUnits,
	restrictWaterUnits = restrictWaterUnits,
}
