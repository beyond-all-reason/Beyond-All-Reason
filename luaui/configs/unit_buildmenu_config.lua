---
--- Created by Hobo Joe.
--- DateTime: 4/26/2023 8:48 PM
---


local unitEnergyCost = {} ---@type table<number, number>
local unitMetalCost = {} ---@type table<number, number>
local unitGroup = {} ---@type table<number, number>
local unitRestricted = {} ---@type table<number, true>
local manualUnitRestricted = {} ---@type table<number, true>
local isBuilder = {} ---@type table<number, true>
local isFactory = {} ---@type table<number, true>
local unitIconType = {} ---@type table<number, number>
local isMex = {} ---@type table<number, true>
local isWind = {} ---@type table<number, true>
local isWaterUnit = {} ---@type table<number, true>
local isGeothermal = {} ---@type table<number, true>
local unitMaxWeaponRange = {} ---@type table<number, number>

for unitDefID, unitDef in pairs(UnitDefs) do

	unitGroup[unitDefID] = unitDef.customParams.unitgroup

	if unitDef.name == 'armdl' or unitDef.name == 'cordl' or unitDef.name == 'armlance' or unitDef.name == 'cortitan' or unitDef.name == 'legatorpbomber'	-- or unitDef.name == 'armbeaver' or unitDef.name == 'cormuskrat'
		or (unitDef.minWaterDepth > 0 or unitDef.modCategories['ship']) then
		isWaterUnit[unitDefID] = true
	end
	if unitDef.name == 'armthovr' or unitDef.name == 'corintr' then
		isWaterUnit[unitDefID] = nil
	end
	if unitDef.customParams.enabled_on_no_sea_maps then
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
		manualUnitRestricted[unitDefID] = true
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

---@param disable boolean
local function restrictWindUnits(disable)
	for unitDefID,_ in pairs(isWind) do
		unitRestricted[unitDefID] = manualUnitRestricted[unitDefID] or disable
	end
end

---@param disable boolean
local function restrictGeothermalUnits(disable)
	for unitDefID,_ in pairs(isGeothermal) do
		unitRestricted[unitDefID] = manualUnitRestricted[unitDefID] or disable
	end
end

---@param disable boolean
local function restrictWaterUnits(disable)
	for unitDefID,_ in pairs(isWaterUnit) do
		unitRestricted[unitDefID] = manualUnitRestricted[unitDefID] or disable
	end
end

---Sets geothermal unit restriction based on the presence of geothermal
---features.
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

---At the end of this 'UNIT ORDER' section, unitOrder is an array with unitIDs
---sorted by their value specified in unitOrderManualOverrideTable. If no
---value is specified, the unit will be placed at the end of the array.
---@type number[]
local unitOrder = {}

local unitOrderManualOverrideTable = VFS.Include("luaui/configs/buildmenu_sorting.lua")

-- Populate unitOrder with unit IDs.
local count = 1
for id, _ in pairs(UnitDefs) do
	unitOrder[count] = id
	count = count + 1
end

-- maxOrder is the largest order value found in unitOrderManualOverrideTable.
-- Units with no value in unitOrderManualOverrideTable will implicitly take the
-- maxOrder value when sorting unitOrder below.
local maxOrder = 0
for _, order in pairs(unitOrderManualOverrideTable) do
	if order > maxOrder then
		maxOrder = order
	end
end
maxOrder = maxOrder + 1

-- Sorts unitIDs by their order value (if one exists) specified in
-- unitOrderManualOverrideTable. All units who do not have an order value
-- specified in unitOrderManualOverrideTable are considered to have an order
-- value of maxOrder.
-- For units who have the same order value we compare the unit's IDs.
-- This sort is always stable, as no two units should have the same ID.
table.sort(unitOrder, function(aID, bID)
	local aOrder = unitOrderManualOverrideTable[aID] or maxOrder
	local bOrder = unitOrderManualOverrideTable[bID] or maxOrder

	if (aOrder == bOrder) then
		return aID < bID
	end
	return aOrder < bOrder
end)


local units = {
	unitEnergyCost = unitEnergyCost,
	unitMetalCost = unitMetalCost,
	unitGroup = unitGroup,
	unitRestricted = unitRestricted,
	unitIconType = unitIconType,
	unitMaxWeaponRange = unitMaxWeaponRange,
	---Set of unit IDs that are factories.
	isFactory = isFactory,
	---Set of unit IDs that have build options.
	isBuilder = isBuilder,
	---Set of unit IDs that require metal.
	isMex = isMex,
	---Set of unit IDs that require wind.
	isWind = isWind,
	---Set of unit IDs that require water.
	isWaterUnit = isWaterUnit,
	---Set of unit IDs that require geothermal.
	isGeothermal = isGeothermal,
	minWaterUnitDepth = -11,
	---An array with unitIDs sorted by their value specified in
	---`unitOrderManualOverrideTable`. If no value is specified, the unit will be
	---placed at the end of the array.
	unitOrder = unitOrder,

	checkGeothermalFeatures = checkGeothermalFeatures,
	restrictGeothermalUnits = restrictGeothermalUnits,
	restrictWindUnits = restrictWindUnits,
	restrictWaterUnits = restrictWaterUnits,
}

return units
