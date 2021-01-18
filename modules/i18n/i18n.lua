local function GetDirectory(filepath)
	return filepath and filepath:gsub("(.*/)(.*)", "%1")
end

assert(debug)
local source = debug and debug.getinfo(1).source
local currentDirectory = GetDirectory(source)


I18N_PATH = currentDirectory .. "i18nlib/i18n/"
Spring.I18N = VFS.Include(I18N_PATH .. "init.lua", nil, VFS.ZIP)