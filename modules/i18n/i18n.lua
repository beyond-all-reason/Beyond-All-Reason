local currentDirectory = "modules/i18n/"
I18N_PATH = currentDirectory .. "i18nlib/i18n/"
Spring.I18N = VFS.Include(I18N_PATH .. "init.lua", nil, VFS.ZIP)

local translationFiles = VFS.DirList('language/', '*.json')

for _, file in ipairs(translationFiles) do
	local i18nJson = VFS.LoadFile(file)
	local i18nLua = Spring.Utilities.json.decode(i18nJson)
	Spring.I18N.load(i18nLua)
end

Spring.I18N.loadFile('language/test_french.lua')

Spring.I18N.languages = {
	en = "English",
	fr = "Français",
}

function Spring.I18N.setLanguage(language)
	--TODO: set font file for Latin vs Asian glyphs here
	Spring.I18N.setLocale(language)
end