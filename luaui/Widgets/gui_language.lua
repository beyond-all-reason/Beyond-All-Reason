function widget:GetInfo()
	return {
		name      = "Language",
		desc      = "API to handle translations",
		author    = "Floris",
		date      = "December 2020",
		license   = "",
		layer     = -math.huge,
		enabled   = true,
	}
end

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
		local proxyFeatureDef = featureDef.customParams.i18nfromfeature or featureDef

		if not proxyFeatureDef.translatedDescription then
			-- Disabled for now to avoid excessive infolog errors
			proxyFeatureDef.translatedDescription = Spring.I18N('features.names.' .. name)
		end
	end
end

local function refreshDefs()
	refreshUnitDefs()
	refreshFeatureDefs()
end

local function languageChanged(language)
	Spring.I18N.setLanguage(language)
	refreshDefs()
end

local noTranslationText = '---'

local languageContent = {}
local defaultLanguage = 'en'
local language = Spring.GetConfigString('language', defaultLanguage)


local languages = {}
local files = VFS.DirList('language', '*')
for k, file in ipairs(files) do
	local name = string.sub(file, 10)
	local ext = string.sub(name, string.len(name) - 2)
	if ext == 'lua' then
		name = string.sub(name, 1, string.len(name) - 4)
		languages[name] = true
	end
end

local function loadLanguage()
	-- load base language file (english)
	local file = "language/"..defaultLanguage..".lua"
	local s = assert(VFS.LoadFile(file, VFS.RAW_FIRST))
	local func = loadstring(s, file)
	local defaultLanguageContent = func()

	if language == defaultLanguage then
		languageContent = defaultLanguageContent
	else
		file = "language/"..language..".lua"
		s = assert(VFS.LoadFile(file, VFS.RAW_FIRST))
		func = loadstring(s, file)
		-- merge default base file with custom language
		languageContent = table.merge(defaultLanguageContent, func())
	end
end

function widget:Initialize()
	refreshDefs()
	loadLanguage()

	WG['lang'] = {}
	WG['lang'].getLanguage = function()
		return language
	end
	WG['lang'].setLanguage = function(value)
		if value ~= language and languages[value] then
			Spring.SetConfigString('language', language)
			language = value
			loadLanguage()
		end
	end
	WG['lang'].getLanguages = function()
		return languages
	end
	WG['lang'].getText = function(id, subId)
		if subId then
			if languageContent[id] and languageContent[subId] then
				return languageContent[id][subId]
			else
				return noTranslationText
			end
		else
			if languageContent[id] then
				return languageContent[id]
			else
				return noTranslationText
			end
		end
	end
end

function widget:Shutdown()
	WG['lang'] = nil
end


function widget:GetConfigData(data)
	return {

	}
end

function widget:SetConfigData(data)

end
