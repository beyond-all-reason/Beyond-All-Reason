-- This file includes common functionality that should be available globally

-- Backwards-compat aliases for the Spring API type split. The engine PR
-- (RecoilEngine LuaSpringContext::SetupAliases) creates these as globals in
-- every Lua sandbox, but engines without that commit only expose `Spring`.
-- This shim lets the spring-split codemod output (Spring.X → SpringShared.X
-- etc.) run on both old and new engine builds. Once the engine PR is merged
-- into mainline this block becomes a harmless no-op (the globals already
-- exist and `or Spring` never fires).
SpringShared   = SpringShared   or Spring
SpringSynced   = SpringSynced   or Spring
SpringUnsynced = SpringUnsynced or Spring

-- Universal Lua functions applicable to any Lua code
-- These add missing base lua functionality
VFS.Include("common/numberfunctions.lua")
VFS.Include("common/stringFunctions.lua")
VFS.Include("common/tablefunctions.lua")
Json = Json or VFS.Include("common/luaUtilities/json.lua")

VFS.Include("common/springOverrides.lua")

local environment = Script.GetName and Script.GetName() or "LuaParser"

local commonFunctions = {
	spring = {
		LuaMenu = true,
		LuaIntro = true,
		LuaParser = true,
		LuaRules = true,
		LuaGaia = true,
		LuaUI = true,
	},

	i18n = {
		LuaMenu = true,
		LuaIntro = true,
		LuaUI = true,
	},

	cmd = {
		LuaRules = true,
		LuaUI = true,
	},

	map = {
		LuaRules = true,
		LuaUI = true,
	},

	graphics = {
		LuaRules = true,
		LuaUI = true,
	},
}

if commonFunctions.spring[environment] then
	local springFunctions = VFS.Include("common/springFunctions.lua")
	Utilities = Utilities or springFunctions.Utilities
	Debug = Debug or springFunctions.Debug
	VFS.Include("common/platformFunctions.lua")
	VFS.Include("common/constants.lua")
end

if commonFunctions.i18n[environment] then
	I18N = I18N or VFS.Include("modules/i18n/i18n.lua")
end

if commonFunctions.cmd[environment] then
	Game.Commands = VFS.Include("modules/commands.lua")
	Game.CustomCommands = VFS.Include("modules/customcommands.lua")
end

if commonFunctions.map[environment] then
	Lava = VFS.Include("modules/lava.lua")
end

if commonFunctions.graphics[environment] then
	VFS.Include("modules/graphics/init.lua").Init(gl)
end

-- we don't want them to run these tests for end users
-- uncomment this only when working on functions in `common/tablefunctions.lua`
-- VFS.Include('common/tableFunctionsTests.lua')
