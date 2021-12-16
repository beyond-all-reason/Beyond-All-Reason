-- This file includes common functionality that should be available globally
if Spring.CommonFunctionsInitialized then
	return
end

local environment = Script.GetName and Script.GetName() or "LuaParser"

local commonFunctions = {
	spring = {
		LuaMenu   = true,
		LuaIntro  = true,
		LuaParser = true,
		LuaRules  = true,
		LuaGaia   = true,
		LuaUI     = true,
	},

	i18n = {
		LuaMenu   = true,
		LuaIntro  = true,
		LuaUI     = true,

		LuaParser = true, -- will be removed once I18N calls are removed from defs
	},
}

-- Generic Lua functions applicable to any Lua code
VFS.Include('common/numberfunctions.lua')
VFS.Include('common/stringFunctions.lua')
VFS.Include('common/tablefunctions.lua')

if commonFunctions.spring[environment] then
	VFS.Include('common/springFunctions.lua')
end

if commonFunctions.i18n[environment] then
	VFS.Include("modules/i18n/i18n.lua")
end

Spring.CommonFunctionsInitialized = true