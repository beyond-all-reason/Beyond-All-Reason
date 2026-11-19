local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Tweakdefs Custom Unit Names",
		desc = "Allow tweakdefs to override I18N entries for units",
		author = "Centrifugal",
		date = "Dec 20, 2024",
		license = "GNU GPL, v2 or later",
		layer = -1000000, -- must run before gui_language
		enabled = true,
	}
end

local function updateTranslations()
	local currentLanguage = Spring.GetConfigString("language", "en")
	-- English too: unit names are looked up in English when language_english_unit_names is on,
	-- and English is the fallback for missing keys
	local languages = currentLanguage == "en" and { "en" } or { currentLanguage, "en" }
	local anySet = false

	for unitDefName, unitDef in pairs(UnitDefNames) do
		local customParams = unitDef.customParams -- the engine builds a new table on every read
		for _, language in ipairs(languages) do
			--Naming convention for language overrides
			local customHumanName = customParams["i18n_" .. language .. "_humanname"]
			local customTooltip = customParams["i18n_" .. language .. "_tooltip"]

			if customHumanName then
				BAR.I18N.set(language .. ".units.names." .. unitDefName, customHumanName)
				anySet = true
			end

			if customTooltip then
				BAR.I18N.set(language .. ".units.descriptions." .. unitDefName, customTooltip)
				anySet = true
			end
		end
	end

	return anySet
end

function widget:Initialize()
	-- setupdefs.lua translated the defs before these overrides were set
	if updateTranslations() then
		require("luaui/i18nhelpers").RefreshDefs()
	end
end

function widget:LanguageChanged()
	-- gui_language refreshes the defs after this
	updateTranslations()
end
