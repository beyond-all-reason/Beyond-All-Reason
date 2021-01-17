local function GetDirectory(filepath)
	return filepath and filepath:gsub("(.*/)(.*)", "%1")
end

assert(debug)
local source = debug and debug.getinfo(1).source
local currentDirectory = GetDirectory(source)


local i18nPath = currentDirectory .. "i18nlib/i18n/"
Spring.I18N = VFS.Include(i18nPath .. "init.lua", nil, VFS.ZIP)