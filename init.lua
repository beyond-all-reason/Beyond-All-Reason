-- This file includes common functionality that should be available globally

-- Universal Lua functions applicable to any Lua code
-- These add missing base lua functionality
VFS.Include('common/numberfunctions.lua')
VFS.Include('common/stringFunctions.lua')
VFS.Include('common/tablefunctions.lua')
Json = Json or VFS.Include('common/luaUtilities/json.lua')

VFS.Include('common/springOverrides.lua')

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
	},

	cmd = {
		LuaRules  = true,
		LuaUI     = true,
	},

	map = {
		LuaRules  = true,
		LuaUI     = true,
	},

	graphics = {
		LuaRules  = true,
		LuaUI     = true,
	},
}

if commonFunctions.spring[environment] then
	local springFunctions = VFS.Include('common/springFunctions.lua')
	Spring.Utilities = Spring.Utilities or springFunctions.Utilities
	Spring.Debug = Spring.Debug or springFunctions.Debug
	-- extend platform
	VFS.Include('common/platformFunctions.lua')
end

if commonFunctions.i18n[environment] then
	Spring.I18N = Spring.I18N or VFS.Include("modules/i18n/i18n.lua")
end

if commonFunctions.cmd[environment] then
	Game.CustomCommands = VFS.Include("modules/customcommands.lua")
end

if commonFunctions.map[environment] then
	Spring.Lava = VFS.Include("modules/lava.lua")
end

if commonFunctions.graphics[environment] then
	VFS.Include("modules/graphics/init.lua").Init(gl)
end

-- we don't want them to run these tests for end users
-- uncomment this only when working on functions in `common/tablefunctions.lua`
-- VFS.Include('common/tableFunctionsTests.lua')
