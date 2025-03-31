local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Tweakdefs Custom Unit Names",
		desc = "Allow tweakdefs to override I18N entries for units",
		author = "Centrifugal",
		date = "Dec 20, 2024",
		license = "GNU GPL, v2 or later",
		layer = -1000000, -- must run before gui_language
		enabled = true
	}
end

local function updateTranslations()
	local currentLanguage = Spring.GetConfigString("language", "en")

	for unitDefName, unitDef in pairs(UnitDefNames) do
		--Naming convention for language overrides
		local nameKey = "i18n_" .. currentLanguage .. "_humanname"
		local tooltipKey = "i18n_" .. currentLanguage .. "_tooltip"

		local customHumanName = unitDef.customParams[nameKey]
		local customTooltip = unitDef.customParams[tooltipKey]

		if customHumanName then
			Spring.I18N.set(currentLanguage .. '.units.names.' .. unitDefName, customHumanName)
		end

		if customTooltip then
			Spring.I18N.set(currentLanguage .. '.units.descriptions.' .. unitDefName, customTooltip)
		end
	end
end

function widget:Initialize()
	updateTranslations()
end

function widget:LanguageChanged()
	updateTranslations()
end