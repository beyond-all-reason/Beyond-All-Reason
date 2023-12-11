local unitI18Nfile = VFS.LoadFile('language/en/units.json')
local unitI18Nlua = Json.decode(unitI18Nfile)
local i18nDescriptionEntries = unitI18Nlua.units.descriptions

local function refreshUnitDefs()
	for unitDefName, unitDef in pairs(UnitDefNames) do
		local humanName, tooltip
		local isScavenger = unitDef.customParams.isscavenger

		if isScavenger then
			local proxyUnitDefName = unitDef.customParams.fromunit
			local proxyUnitDef = UnitDefNames[proxyUnitDefName]
			proxyUnitDefName = proxyUnitDef.customParams.i18nfromunit or proxyUnitDefName

			local fromUnitHumanName = Spring.I18N('units.names.' .. proxyUnitDefName)
			humanName = Spring.I18N('units.scavenger', { name = fromUnitHumanName })

			if (i18nDescriptionEntries[unitDefName]) then
				tooltip = Spring.I18N('units.descriptions.' .. unitDefName)
			else
				tooltip = Spring.I18N('units.descriptions.' .. proxyUnitDefName)
			end
		else
			local proxyUnitDefName = unitDef.customParams.i18nfromunit or unitDefName
			humanName = Spring.I18N('units.names.' .. proxyUnitDefName)
			tooltip = Spring.I18N('units.descriptions.' .. proxyUnitDefName)
		end

		unitDef.translatedHumanName = humanName
		unitDef.translatedTooltip = tooltip
	end
end

local function setCorpseDescription(unitHumanName, featureDef)
	if featureDef.customParams.category == 'corpses' then
		featureDef.translatedDescription = Spring.I18N('units.dead', { name = unitHumanName })
	elseif featureDef.customParams.category == 'heaps' then
		featureDef.translatedDescription = Spring.I18N('units.heap', { name = unitHumanName })
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
			featureDef.translatedDescription = Spring.I18N('features.names.' .. proxyName)
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