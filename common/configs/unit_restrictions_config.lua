local unitRestrictions = {}

local isWind = {}
local isWaterUnit = {}
local isGeothermal = {}
local isLandGeothermal = {}
local isSeaGeothermal = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.windGenerator > 0 then
		isWind[unitDefID] = true
	end

	if unitDef.needGeo then
		isGeothermal[unitDefID] = true
		if unitDef.maxWaterDepth >= 100 then
			isSeaGeothermal[unitDefID] = true
		else
			isLandGeothermal[unitDefID] = true
		end
	end

	if (unitDef.minWaterDepth > 0 or unitDef.modCategories['ship']) and not unitDef.customParams.enabled_on_no_sea_maps then
		isWaterUnit[unitDefID] = true
	end
end

local function isWindDisabled()
	return ((Game.windMin + Game.windMax) / 2) < 5
end

local function shouldShowWaterUnits()
	local voidWater = false
	local success, mapinfo = pcall(VFS.Include,"mapinfo.lua")
	if success and mapinfo then
		voidWater = mapinfo.voidwater
	end

	if voidWater then
		return false
	end

	local _, _, mapMinWater, _ = Spring.GetGroundExtremes()
	return mapMinWater <= -11 -- units.minWaterUnitDepth
end

local function hasGeothermalFeatures()
	local hasLandGeo = false
	local hasSeaGeo = false
	local geoFeatureDefs = {}
	for defID, def in pairs(FeatureDefs) do
		if def.geoThermal then
			geoFeatureDefs[defID] = true
		end
	end
	local features = Spring.GetAllFeatures()
	for i = 1, #features do
		local featureID = features[i]
		if geoFeatureDefs[Spring.GetFeatureDefID(featureID)] then
			local _, y, _ = Spring.GetFeaturePosition(featureID)
			if y < 0 then
				hasSeaGeo = true
			else
				hasLandGeo = true
			end
		end
	end

	return hasLandGeo, hasSeaGeo
end

unitRestrictions.isWind = isWind
unitRestrictions.isWaterUnit = isWaterUnit
unitRestrictions.isGeothermal = isGeothermal
unitRestrictions.isLandGeothermal = isLandGeothermal
unitRestrictions.isSeaGeothermal = isSeaGeothermal
unitRestrictions.isWindDisabled = isWindDisabled
unitRestrictions.shouldShowWaterUnits = shouldShowWaterUnits
unitRestrictions.hasGeothermalFeatures = hasGeothermalFeatures

return unitRestrictions
