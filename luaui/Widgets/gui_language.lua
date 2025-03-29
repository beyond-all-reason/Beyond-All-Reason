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

		if Script.LuaUI('LanguageChanged') then
			Script.LuaUI.LanguageChanged()
		end
	end

	WG['language'].setEnglishUnitNames = function(value)
		Spring.SetConfigInt("language_english_unit_names", value and 1 or 0)

		if Script.LuaUI('LanguageChanged') then
			Script.LuaUI.LanguageChanged()
		end
	end
end

function widget:Shutdown()
	WG['lang'] = nil
end
