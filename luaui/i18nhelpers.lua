local unitNameNamespace = 'units.names.'
local unitDescriptionNamespace = 'units.descriptions.'
local unitDeadDef = 'units.dead'
local unitHeapDef ='units.heap'
local unitScavengerDef = 'units.scavenger'

local function getTranslatedUnitName(unitDefName)
    return Spring.I18N(unitNameNamespace .. unitDefName)
end

local function getTranslatedTooltip(unitDefName)
    return Spring.I18N(unitDescriptionNamespace .. unitDefName)
end

local function getTranslatedCorpseName(unitHumanName)
    return Spring.I18N(unitDeadDef, { name = unitHumanName })
end

local function getTranslatedHeapName(unitHumanName)
    return Spring.I18N(unitHeapDef, { name = unitHumanName })
end

local function applyScavengerPrefix(proxyHumanName)
    return Spring.I18N(unitScavengerDef, { name = proxyHumanName })
end

local function getCurrentLanguage()
    return Spring.GetConfigString("Language", "en") -- Defaults to "en" if not set
end

local function getTranslatedUnitDef(unitDefName, unitDef)
	local humanName, tooltip, namespace
	local proxyUnitDefName = unitDef.customParams.i18nfromunit or unitDefName
	
	humanName = getTranslatedUnitName(proxyUnitDefName)
    tooltip = getTranslatedTooltip(proxyUnitDefName)
	
    return {
        humanName = humanName,
        tooltip = tooltip,
    }
end


local function refreshUnitDefs()
    for unitDefName, unitDef in pairs(UnitDefNames) do
        local humanName, tooltip, namespace
        local isScavenger = unitDef.customParams.isscavenger
		local unitTranslations = getTranslatedUnitDef(unitDefName, unitDef)
		
        if isScavenger then
			
            local proxyUnitDefName = unitDef.customParams.fromunit
            local proxyUnitDef = UnitDefNames[proxyUnitDefName]
	
			local proxyUnitTranslations = getTranslatedUnitDef(proxyUnitDefName, proxyUnitDef)

			-- Rename to "Scavenger %name%"
			humanName = applyScavengerPrefix(proxyUnitTranslations.humanName)

			--In case unit has no tooltip(Like units inserted via TweakDefs), default to proxy
			tooltip = unitTranslations.tooltip or proxyUnitTranslations.tooltip
        else
			local i18HumanNameOverride, i18TooltipOverride
			local currentLanguage = getCurrentLanguage()
			
			-- Naming convention for language overrides
			local humanNameKey = "i18n_" .. currentLanguage .. "_humanname"
			local tooltipKey = "i18n_" .. currentLanguage .. "_tooltip"
			
			if unitDef.customParams then
				--Look for overrides specific to players language
				local customHumanName = unitDef.customParams[humanNameKey]
				local customTooltip = unitDef.customParams[tooltipKey]
				
				if customHumanName then
					i18HumanNameOverride = customHumanName
				end
				
				if customTooltip then
					i18TooltipOverride = customTooltip
				end
			end
				
			-- Use overrides if defined, otherwise default to standard translations
            humanName = i18HumanNameOverride or unitTranslations.humanName
            tooltip = i18TooltipOverride or unitTranslations.tooltip
			
        end

		unitDef.translatedHumanName = humanName
        unitDef.translatedTooltip = tooltip
    end
end

local function setCorpseDescription(unitHumanName, featureDef)
    if featureDef.customParams.category == 'corpses' then
        featureDef.translatedDescription = getTranslatedCorpseName(unitHumanName)
    elseif featureDef.customParams.category == 'heaps' then
        featureDef.translatedDescription = getTranslatedHeapName(unitHumanName)
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
    --     if not featureDef.customParams.fromunit and featureDef.translatedDescription == 'features.names.' .. featureDef.name then
    --         Spring.Log("LuaUI", LOG.ERROR, "Missing I18N for map feature: " .. name .. ", " .. featureDef.tooltip .. ", Map: " .. Game.mapName)
    --     end
    -- end
end

return {
    RefreshDefs = refreshDefs,
}