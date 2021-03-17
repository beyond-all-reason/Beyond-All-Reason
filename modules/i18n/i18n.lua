local currentDirectory = "modules/i18n/"
I18N_PATH = currentDirectory .. "i18nlib/i18n/"
Spring.I18N = VFS.Include(I18N_PATH .. "init.lua", nil, VFS.ZIP)

Spring.I18N.loadFile('language/interface_en.lua')
Spring.I18N.loadFile('language/units_en.lua')
Spring.I18N.loadFile('language/tips_en.lua')

local languages = {
	en = {
		name = "English"
	}
}

function Spring.I18N.getLanguages()
	return languages
end