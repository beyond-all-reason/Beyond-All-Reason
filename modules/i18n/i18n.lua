local currentDirectory = "modules/i18n/"
I18N_PATH = currentDirectory .. "i18nlib/i18n/"
Spring.I18N = VFS.Include(I18N_PATH .. "init.lua", nil, VFS.ZIP)

Spring.I18N.loadFile('language/interface_en.lua')
Spring.I18N.loadFile('language/units_en.lua')
Spring.I18N.loadFile('language/tips_en.lua')
Spring.I18N.loadFile('language/scavengers_en.lua')

Spring.I18N.languages = {
	en = "English",
}

function Spring.I18N.setLanguage(language)
	--TODO: set font file for Latin vs Asian glyphs here
	Spring.I18N.setLocale(language)
end