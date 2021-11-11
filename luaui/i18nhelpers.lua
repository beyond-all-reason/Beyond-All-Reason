local unitI18Nfile = VFS.Include('language/units_en.lua')
local i18nDescriptionEntries = unitI18Nfile.en.units.descriptions

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

local function refreshFeatureDefs()
	for _, unitDef in pairs(UnitDefs) do
		local corpseDef = FeatureDefNames[unitDef.wreckName]
		if corpseDef then
			corpseDef.translatedDescription = Spring.I18N('units.dead', { name = unitDef.translatedHumanName })

			local heapDef = FeatureDefs[corpseDef.deathFeatureID]
			if heapDef then
				heapDef.translatedDescription = Spring.I18N('units.heap', { name = unitDef.translatedHumanName })
			end
		end
	end

	for name, featureDef in pairs(FeatureDefNames) do
		if not featureDef.translatedDescription then
			local proxyName = featureDef.customParams.i18nfrom or name
			featureDef.translatedDescription = Spring.I18N('features.names.' .. proxyName)
		end
	end
end

local function refreshDefs()
	refreshUnitDefs()
	refreshFeatureDefs()
end

return {
	RefreshDefs = refreshDefs,
}