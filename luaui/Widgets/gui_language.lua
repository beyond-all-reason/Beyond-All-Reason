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

local i18nHelper = VFS.Include('luaui/i18nhelpers.lua')

local customMessageProxies = {
	['ui.chickens.queenResistant'] = function (data) return { unit = UnitDefs[data.unitDefId].translatedHumanName } end,
	['scav.messages.reinforcements'] = function (data) return { player = data.player, unit = UnitDefNames[data.unitDefName].translatedHumanName } end,
}

local function getMessageProxy(messageKey, parameters)
	if customMessageProxies[messageKey] then
		return Spring.I18N( messageKey, customMessageProxies[messageKey](parameters) )
	else
		return Spring.I18N(messageKey, parameters)
	end
end

local noTranslationText = '---'

local languageContent = {}

local function loadLanguage()
	-- load base language file (english)
	local defaultLanguage = 'en'
	local file = "language/"..defaultLanguage..".lua"
	local s = assert(VFS.LoadFile(file, VFS.RAW_FIRST))
	local func = loadstring(s, file)
	languageContent = func()
end

function widget:LanguageChanged()
	i18nHelper.RefreshDefs()
end

function widget:Initialize()
	widgetHandler:RegisterGlobal('GadgetMessageProxy', getMessageProxy)

	WG['language'] = {}

	WG['language'].setLanguage = function(language)
		Spring.SetConfigString('language', language)
		Spring.I18N.setLanguage(language)

		if Script.LuaUI('LanguageChanged') then
			Script.LuaUI.LanguageChanged()
		end
	end

	loadLanguage()

	WG['lang'] = {}

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
