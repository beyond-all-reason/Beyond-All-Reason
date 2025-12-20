---
--- Unit Restrictions Configuration
--- Defines which units should be restricted based on terrain/map conditions
--- Used by api_tech_blocking.lua for terrain-based unit blocking
---

local unitRestrictions = {}

-- Terrain-based unit classifications
local isWind = {} ---@type table<number, true> Units that require wind
local isWaterUnit = {} ---@type table<number, true> Units that require water/naval access
local isGeothermal = {} ---@type table<number, true> Units that require geothermal features

-- Populate terrain-based unit classifications
for unitDefID, unitDef in pairs(UnitDefs) do
	-- Wind generator units (restricted when average wind < 5)
	if unitDef.windGenerator > 0 then
		isWind[unitDefID] = true
	end

	-- Geothermal units (restricted when no geothermal features present)
	if unitDef.needGeo then
		isGeothermal[unitDefID] = true
	end

	-- Water/naval units (restricted on maps without sufficient water)
	if unitDef.minWaterDepth > 0 or unitDef.modCategories['ship'] then
		isWaterUnit[unitDefID] = true
	end
	if unitDef.customParams.enabled_on_no_sea_maps then
		isWaterUnit[unitDefID] = nil
	end
end

-- Terrain condition detection functions
local function isWindDisabled()
	---Check if wind is disabled/low for UI purposes (average < 5)
	return ((Game.windMin + Game.windMax) / 2) < 5
end

local function shouldShowWaterUnits()
	---Check if map has sufficient water depth for naval units
	local mapMinWater = select(2, Spring.GetGroundExtremes())
	return mapMinWater <= -11 -- units.minWaterUnitDepth
end

local function hasGeothermalFeatures()
	---Check if map has geothermal features
	local geoThermalFeatures = {}
	for defID, def in pairs(FeatureDefs) do
		if def.geoThermal then
			geoThermalFeatures[defID] = true
		end
	end
	local features = Spring.GetAllFeatures()
	for i = 1, #features do
		if geoThermalFeatures[Spring.GetFeatureDefID(features[i])] then
			return true
		end
	end
	return false
end

-- Export the configuration
unitRestrictions.isWind = isWind
unitRestrictions.isWaterUnit = isWaterUnit
unitRestrictions.isGeothermal = isGeothermal
unitRestrictions.isWindDisabled = isWindDisabled
unitRestrictions.shouldShowWaterUnits = shouldShowWaterUnits
unitRestrictions.hasGeothermalFeatures = hasGeothermalFeatures

return unitRestrictions
