local currentDirectory = "modules/i18n/"
I18N_PATH = currentDirectory .. "i18nlib/i18n/" -- I18N_PATH is expected to be global inside the i18n module
local i18n = VFS.Include(I18N_PATH .. "init.lua", nil, VFS.ZIP)

local translationFiles = VFS.DirList('language/', '*.json')

for _, file in ipairs(translationFiles) do
	local i18nJson = VFS.LoadFile(file)
	local i18nLua = Spring.Utilities.json.decode(i18nJson)
	i18n.load(i18nLua)
end

i18n.loadFile('language/test_french.lua')

i18n.languages = {
	en = "English",
	fr = "Français",
}

function i18n.setLanguage(language)
	--TODO: set font file for Latin vs Asian glyphs here
	i18n.setLocale(language)
end

return i18n