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
local i18nDecriptionEntries = unitI18Nfile.en.units.descriptions

local function refreshDefs()
	for unitDefName, unitDef in pairs(UnitDefNames) do
		local humanName, tooltip
		local isScavenger = unitDef.customParams.isscavenger

		if not isScavenger then
			humanName = Spring.I18N('units.names.' .. unitDefName)
			tooltip = Spring.I18N('units.descriptions.' .. unitDefName)
		else
			local fromUnitName = Spring.I18N('units.names.' .. unitDef.customParams.fromunit)
			humanName = Spring.I18N('units.scavenger', { name = fromUnitName })

			if (i18nDecriptionEntries[unitDefName]) then
				tooltip = Spring.I18N('units.descriptions.' .. unitDefName)
			else
				tooltip = Spring.I18N('units.descriptions.' .. unitDef.customParams.fromunit)
			end
		end

		unitDef.translatedHumanName = humanName
		unitDef.translatedTooltip = tooltip
	end
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
	Spring.Echo("foo")
	for _, ud in pairs(UnitDefs) do
		Spring.Echo(ud.translatedHumanName, ud.translatedTooltip)
	end
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
