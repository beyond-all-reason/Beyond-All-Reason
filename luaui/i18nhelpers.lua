-- With a default, a missing key is not logged.
local function hasEnglishDescription(unitDefName)
	return BAR.I18N("units.descriptions." .. unitDefName, { locale = "en", default = "" }) ~= ""
end

local function refreshUnitDefs()
	for unitDefName, unitDef in pairs(UnitDefNames) do
		local humanName, tooltip
		local customParams = unitDef.customParams -- the engine builds a new table on every read
		local isScavenger = customParams.isscavenger

		if isScavenger then
			local proxyUnitDefName = customParams.fromunit
			local proxyUnitDef = UnitDefNames[proxyUnitDefName]
			proxyUnitDefName = proxyUnitDef and proxyUnitDef.customParams.i18nfromunit or proxyUnitDefName

			local fromUnitHumanName = BAR.I18N("units.names." .. proxyUnitDefName)
			humanName = BAR.I18N("units.scavenger", { name = fromUnitHumanName })

			if hasEnglishDescription(unitDefName) then
				tooltip = BAR.I18N("units.descriptions." .. unitDefName)
			else
				tooltip = BAR.I18N("units.descriptions." .. proxyUnitDefName)
			end
		else
			local proxyUnitDefName = customParams.i18nfromunit or unitDefName
			humanName = BAR.I18N("units.names." .. proxyUnitDefName)
			tooltip = BAR.I18N("units.descriptions." .. proxyUnitDefName)
		end

		unitDef.translatedHumanName = humanName
		unitDef.translatedTooltip = tooltip
	end
end

local function setCorpseDescription(unitHumanName, featureDef)
	local category = featureDef.customParams.category
	if category == "corpses" then
		featureDef.translatedDescription = BAR.I18N("units.dead", { name = unitHumanName })
	elseif category == "heaps" then
		featureDef.translatedDescription = BAR.I18N("units.heap", { name = unitHumanName })
	end
end

local function refreshFeatureDefs()
	local processedFeatureDefs = {}

	for _, unitDef in pairs(UnitDefs) do
		local corpseDef = FeatureDefNames[unitDef.corpse]

		while corpseDef ~= nil do
			setCorpseDescription(unitDef.translatedHumanName, corpseDef)
			processedFeatureDefs[corpseDef.id] = true
			corpseDef = FeatureDefs[corpseDef.deathFeatureID]
		end
	end

	for name, featureDef in pairs(FeatureDefNames) do
		if not processedFeatureDefs[featureDef.id] then
			local proxyName = featureDef.customParams.i18nfrom or name
			featureDef.translatedDescription = BAR.I18N("features.names." .. proxyName)
		end
	end
end

local function refreshDefs()
	refreshUnitDefs()
	refreshFeatureDefs()

	-- Logging missing map feature I18N entries disabled for now, as it is capturing unofficial maps
	-- for name, featureDef in pairs(FeatureDefNames) do
	-- 	if not featureDef.customParams.fromunit and featureDef.translatedDescription == 'features.names.' .. featureDef.name then
	-- 		Spring.Log("LuaUI", LOG.ERROR, "Missing I18N for map feature: " .. name .. ", " .. featureDef.tooltip .. ", Map: " .. Game.mapName)
	-- 	end
	-- end
end

return {
	RefreshDefs = refreshDefs,
}
