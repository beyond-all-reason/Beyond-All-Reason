local currentDirectory = "modules/i18n/"
I18N_PATH = currentDirectory .. "i18nlib/i18n/" -- I18N_PATH is expected to be global inside the i18n module
local i18n = VFS.Include(I18N_PATH .. "init.lua", nil, VFS.ZIP)
local WidgetLocalizations = VFS.Include("modules/i18n/widget_localizations.lua", nil, VFS.ZIP)

local asianFont = "fallbacks/SourceHanSans-Regular.ttc"
local translationDirs = VFS.SubDirs("language")

-- map of languageCode -> map of translation key -> translation string
local languageTranslations = {}

local function loadTranslationTable(languageCode, currentContext, data)
	local composedKey
	for k, v in pairs(data) do
		composedKey = (currentContext and (currentContext .. ".") or "") .. tostring(k)
		if type(v) == "string" then
			languageTranslations[languageCode][composedKey] = v
		elseif type(v) == "table" then
			loadTranslationTable(languageCode, composedKey, v)
		end
	end
end

local function loadRmlTranslations(languageCode)
	RmlUi.ClearTranslations()
	for k, v in pairs(languageTranslations[languageCode]) do
		RmlUi.AddTranslationString("!!" .. k, v)
	end
end

local WIDGET_KEY_ROOT = "widgets"

local widgetLocalizations = {}

local function loadWidgetLocalization(languageCode, id)
	local strings = widgetLocalizations[id][languageCode]
	if not strings then
		return
	end

	local namespaced = { [WIDGET_KEY_ROOT] = { [id] = strings } }
	loadTranslationTable(languageCode, nil, namespaced)
	i18n.load({ [languageCode] = namespaced })
end

-- Construct a map of
-- languageCode -> list of translation files associated with that language.
local languageFiles = {}
for _, languageDir in ipairs(translationDirs) do
	local translationFiles = VFS.DirList(languageDir, "*.json")
	local languageCode = table.remove(string.split(languageDir, "/"))
	languageFiles[languageCode] = translationFiles
end

-- Loads all language translation files associated with languageCode.
local function loadLanguageFiles(languageCode)
	if languageFiles[languageCode] == nil then
		return
	end

	languageTranslations[languageCode] = {}
	for _, file in ipairs(languageFiles[languageCode]) do
		local i18nJson = VFS.LoadFile(file)
		local i18nLua = { [languageCode] = Json.decode(i18nJson) }
		loadTranslationTable(languageCode, nil, i18nLua[languageCode])
		i18n.load(i18nLua)
	end

	for id in pairs(widgetLocalizations) do
		loadWidgetLocalization(languageCode, id)
	end
end

-- Map of language code -> whether or not the language files are loaded.
local languageLoaded = {}

-- Ensures that language translation files associated with languageCode are
-- loaded (if any).
local function ensureLanguageLoaded(languageCode)
	if languageLoaded[languageCode] then
		return
	end

	loadLanguageFiles(languageCode)
	languageLoaded[languageCode] = true
end

i18n.loadFile("language/test_unicode.lua")

i18n.languages = {
	en = "English",
	fr = "Français",
	de = "Deutsch",
	ru = "Русский",
	zh = "中文",
	es = "Español",
	test_unicode = "test_unicode",
}

-- Some initialization routines requires english translations prior to the first
-- i18n.setLanguage call.
ensureLanguageLoaded("en")

function i18n.setLanguage(language)
	ensureLanguageLoaded(language)
	i18n.setLocale(language)
	loadRmlTranslations(language)

	if gl.AddFallbackFont then
		return
	end

	-- Font substitution is handled at the OS level, meaning we cannot control which fallback font is used
	-- Manually switching fonts is required until Spring handles font substitution at the engine level
	-- LuaUI reload must be invoked for widgets to refresh all their font objects
	local asianLanguage = language == "zh"
	local currentFont = Spring.GetConfigString("bar_font")

	if asianLanguage and currentFont ~= asianFont then
		Spring.SetConfigString("bar_font", asianFont)
		Spring.SetConfigString("bar_font2", asianFont)
		Spring.SendCommands("luarules reloadluaui")
	elseif not asianLanguage and currentFont == asianFont then
		Spring.SetConfigString("bar_font", "Poppins-Regular.otf")
		Spring.SetConfigString("bar_font2", "Exo2-SemiBold.otf")
		Spring.SendCommands("luarules reloadluaui")
	end
end

function i18n.loadWidgetLocalizations(widgets, vfsMode)
	local discovered, warnings = WidgetLocalizations.Read(widgets, vfsMode)

	for _, warning in ipairs(warnings) do
		Spring.Log("i18n", LOG.WARNING, warning)
	end

	local added = {}
	for id, byLanguage in pairs(discovered) do
		if widgetLocalizations[id] then
			Spring.Log("i18n", LOG.WARNING, string.format("Widget id %s already provided localizations; skipped", id))
		else
			widgetLocalizations[id] = byLanguage
			added[#added + 1] = id
		end
	end

	if #added == 0 then
		return
	end

	for languageCode in pairs(languageTranslations) do
		for _, id in ipairs(added) do
			loadWidgetLocalization(languageCode, id)
		end
	end

	local locale = i18n.getLocale()
	if languageTranslations[locale] then
		loadRmlTranslations(locale)
	end
end

return i18n
