local function _findI18nBase()
	local luxDirs = VFS.SubDirs(".lux/5.1/", VFS.RAW_ONLY) or {}
	for _, dir in ipairs(luxDirs) do
		if dir:match("i18n@") then
			local initPath = dir .. "src/i18n/init.lua"
			if VFS.FileExists(initPath, VFS.RAW_ONLY) then
				return dir .. "src/"
			end
		end
	end
	error("i18n library not found. Run 'lx sync' to install dependencies.")
end

local _origRequire = require
do
	local _loaded = {}
	local _base = _findI18nBase()
	require = function(modname)
		if _loaded[modname] then
			return _loaded[modname]
		end
		local rel = modname:gsub("%.", "/")
		local path = _base .. rel .. "/init.lua"
		if not VFS.FileExists(path, VFS.RAW_FIRST) then
			path = _base .. rel .. ".lua"
		end
		local src = VFS.LoadFile(path, VFS.RAW_FIRST)
		if not src then
			error("module '" .. modname .. "' not found at " .. path)
		end
		local chunk = assert(loadstring(src, path))
		local result = chunk(modname)
		_loaded[modname] = result or true
		return _loaded[modname]
	end
end
local i18n = require("i18n")
require = _origRequire

function i18n.loadFile(path)
	local success, data = pcall(function()
		local chunk = VFS.LoadFile(path, VFS.ZIP_FIRST)
		return assert(loadstring(chunk))()
	end)
	if not success then
		Spring.Log("i18n", LOG.ERROR, "Failed to parse file " .. path)
		Spring.Log("i18n", LOG.ERROR, data)
		return nil
	end
	i18n.load(data)
end

local _translate = i18n.translate
local missingTranslations = {}
function i18n.translate(key, data)
	local result = _translate(key, data)
	if result ~= nil then
		return result
	end
	if not missingTranslations[key] then
		missingTranslations[key] = true
		Spring.Log("i18n", "notice", 'No translation found for "' .. key .. '"')
	end
	return (data and data.default) or key
end

function i18n.unitName(unitDefName, data)
	data = data or {}
	if Spring.GetConfigInt("language_english_unit_names", 1) == 1 then
		data.locale = "en"
	end
	return i18n.translate("units.names." .. unitDefName, data)
end

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
	-- Manually switching fonts is requred until Spring handles font substitution at the engine level
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

return i18n
