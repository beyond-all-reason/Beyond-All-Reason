local currentDirectory = "modules/i18n/"
I18N_PATH = currentDirectory .. "i18nlib/i18n/" -- I18N_PATH is expected to be global inside the i18n module
local i18n = VFS.Include(I18N_PATH .. "init.lua", nil, VFS.ZIP)

local asianFont = 'SourceHanSans-Regular.ttc'
local translationDirs = VFS.SubDirs('language')

for _, languageDir in ipairs(translationDirs) do
	local translationFiles = VFS.DirList(languageDir, '*.json')
	local languageCode = table.remove( string.split(languageDir, '/') )

	for _, file in ipairs(translationFiles) do
		local i18nJson = VFS.LoadFile(file)
		local i18nLua = { [languageCode] = Json.decode(i18nJson) }
		i18n.load(i18nLua)
	end
end

i18n.loadFile('language/test_french.lua')
i18n.loadFile('language/test_unicode.lua')

i18n.languages = {
	en = "English",
	fr = "Français",
	de = 'Deutsch',
	zh = "中文",
	test_unicode = "test_unicode"
}

function i18n.setLanguage(language)
	i18n.setLocale(language)

	-- Font substitution is handled at the OS level, meaning we cannot control which fallback font is used
	-- Manually switching fonts is requred until Spring handles font substitution at the engine level
	-- LuaUI reload must be invoked for widgets to refresh all their font objects
	local asianLanguage = language == 'zh'
	local currentFont = Spring.GetConfigString('bar_font')

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