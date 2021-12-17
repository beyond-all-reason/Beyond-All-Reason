-- This file includes common functionality that should be available globally
if Spring.CommonFunctionsInitialized then
	return
end

-- Universal Lua functions applicable to any Lua code
-- These add missing base lua functionality
VFS.Include('common/numberfunctions.lua')
VFS.Include('common/stringFunctions.lua')
VFS.Include('common/tablefunctions.lua')

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

if commonFunctions.spring[environment] then
	local springFunctions = VFS.Include('common/springFunctions.lua')
	Spring.Utilities = Spring.Utilities or springFunctions.Utilities
	Spring.Utilities.json = Spring.Utilities.json or springFunctions.json
	Spring.Debug = Spring.Debug or springFunctions.Debug
end

if commonFunctions.i18n[environment] then
	Spring.I18N = Spring.I18N or VFS.Include("modules/i18n/i18n.lua")
end

Spring.CommonFunctionsInitialized = true