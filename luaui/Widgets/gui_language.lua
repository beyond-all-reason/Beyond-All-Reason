local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Language",
		desc      = "Handle functions related to translations",
		date      = "November 2023",
		layer     = -999999,
		enabled   = true,
	}
end

local i18nHelper = VFS.Include('luaui/i18nhelpers.lua')

local customMessageProxies = {
	['ui.chickens.queenResistant'] = function (data) return { unit = UnitDefs[data.unitDefId].translatedHumanName } end,
}

local function notifyLanguageChanged()
	if Script.LuaUI('LanguageChanged') then
		Script.LuaUI.LanguageChanged()
	end
	if Script.LuaRules('LanguageChanged') then
		Script.LuaRules.LanguageChanged()
	end
end

local function getMessageProxy(messageKey, parameters)
	if customMessageProxies[messageKey] then
		return Spring.I18N( messageKey, customMessageProxies[messageKey](parameters) )
	else
		return Spring.I18N(messageKey, parameters)
	end
end

function widget:LanguageChanged()
	i18nHelper.RefreshDefs()
end

function widget:Initialize()
	i18nHelper.RefreshDefs()

	widgetHandler:RegisterGlobal('GadgetMessageProxy', getMessageProxy)

	WG['language'] = {}

	WG['language'].setLanguage = function(language)
		Spring.SetConfigString('language', language)
		Spring.I18N.setLanguage(language)
		Spring.I18N.loadWidgetLanguage(language)

		local asianFont = 'fallbacks/SourceHanSans-Regular.ttc'
		local currentFont = Spring.GetConfigString('bar_font')
		if language == 'zh' and currentFont ~= asianFont then
			Spring.SetConfigString("bar_font", asianFont)
			Spring.SetConfigString("bar_font2", asianFont)
			Spring.SendCommands("luarules reloadluaui")
		elseif language ~= 'zh' and currentFont == asianFont then
			Spring.SetConfigString("bar_font", "Poppins-Regular.otf")
			Spring.SetConfigString("bar_font2", "Exo2-SemiBold.otf")
			Spring.SendCommands("luarules reloadluaui")
		end

		notifyLanguageChanged()
	end

	WG['language'].setEnglishUnitNames = function(value)
		Spring.SetConfigInt("language_english_unit_names", value and 1 or 0)

		notifyLanguageChanged()
	end
end

function widget:Shutdown()
	WG['lang'] = nil
end
