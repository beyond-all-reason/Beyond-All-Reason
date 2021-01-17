--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name      = "i18n",
		desc      = "Internationalization library for Spring",
		author    = "gajop",
		date      = "WIP",
		license   = "GPLv2",
		version   = "0.1",
		layer     = -1000,
		enabled   = true,  --  loaded by default?
		handler   = true,
		api       = true,
		hidden    = true,
	}
end

local function GetDirectory(filepath)
	return filepath and filepath:gsub("(.*/)(.*)", "%1")
end

assert(debug)
local source = debug and debug.getinfo(1).source
local DIR = GetDirectory(source)


I18N_PATH = DIR .. "i18nlib/i18n/"

function widget:Initialize()
	WG.i18n = VFS.Include(I18N_PATH .. "init.lua", nil, VFS.ZIP)
end
