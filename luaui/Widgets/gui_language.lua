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

local i18nHelper = VFS.Include("luaui/i18nhelpers.lua")

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
	i18nHelper.RefreshDefs()

	widgetHandler:RegisterGlobal("GadgetMessageProxy", getMessageProxy)

	WG.language = {}

	---Switches the UI language, persists it, and notifies every widget.
	---@param language string Language code, e.g. `"en"`.
	WG.language.setLanguage = function(language)
		Spring.SetConfigString("language", language)
		BAR.I18N.setLanguage(language)

		if Script.LuaUI("LanguageChanged") then
			Script.LuaUI.LanguageChanged()
		end
	end

	---Keeps unit names in English regardless of UI language, and notifies every widget.
	---@param value boolean
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
