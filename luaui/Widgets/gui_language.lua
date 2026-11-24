local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Language",
		desc = "Handle functions related to translations",
		date = "November 2023",
		layer = -999999,
		enabled = true,
	}
end

local i18nHelper = require("luaui/i18nhelpers")

local customMessageProxies = {
	["ui.chickens.queenResistant"] = function(data)
		return { unit = UnitDefs[data.unitDefId].translatedHumanName }
	end,
}

local function getMessageProxy(messageKey, parameters)
	if customMessageProxies[messageKey] then
		return BAR.I18N(messageKey, customMessageProxies[messageKey](parameters))
	else
		return BAR.I18N(messageKey, parameters)
	end
end

function widget:LanguageChanged()
	i18nHelper.RefreshDefs()
end

function widget:Initialize()
	-- setupdefs.lua refreshed the defs as LuaUI loaded. WG.language is left over only when this widget
	-- was on before, and the language can have changed through it while this widget was off.
	local previous = WG.language ---@type table?
	if previous ~= nil then
		i18nHelper.RefreshDefs()
	end

	widgetHandler:RegisterGlobal("GadgetMessageProxy", getMessageProxy)

	WG.language = {}

	WG.language.setLanguage = function(language)
		Spring.SetConfigString("language", language)
		BAR.I18N.setLanguage(language)

		if Script.LuaUI("LanguageChanged") then
			Script.LuaUI.LanguageChanged()
		end
	end

	WG.language.setEnglishUnitNames = function(value)
		Spring.SetConfigInt("language_english_unit_names", value and 1 or 0)

		if Script.LuaUI("LanguageChanged") then
			Script.LuaUI.LanguageChanged()
		end
	end
end

function widget:Shutdown()
	WG.lang = nil
end
