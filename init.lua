-- This file includes common functionality that should be available globally

-- Universal Lua functions applicable to any Lua code
-- These add missing base lua functionality
BAR = BAR or {} -- detached module namespace; must precede any BAR.X consumer

-- Recoil shim: require("path/to/file") is VFS.Include("path/to/file.lua"), spelled so EmmyLua can follow it
-- and type the result without a decorator. Same semantics: the file runs in the caller's env, every call.
-- That env is read off the stack, so no `return require(...)` (a tail call has no frame). LuaIntro has an
-- engine require, called with the ".lua" on; those calls go to it.
local engineRequire = require ---@type (fun(name: string): any)|nil nil in every game state but LuaIntro
---@param path string a repo path without its ".lua"
---@param env table|nil the environment the file runs in; the caller's when absent
---@param mode string|nil as VFS.Include takes it
---@return any what the file returns
function require(path, env, mode)
	if engineRequire and path:sub(-4) == ".lua" then
		return engineRequire(path) -- LuaIntro's own require, by the engine's convention: a file named in full
	end
	if env == nil then
		-- the env of the caller is at level 3:
		--    - level 1  pcall (the C function that invoked getfenv)
		--    - level 2  require (our wrapper, which invoked pcall)
		--    - level 3  the file that called require   <- the env we want
		local ok, callerEnv = pcall(getfenv, 3)
		if not ok then
			error("require(" .. path .. "): called as a tail call; assign the result before returning it", 2)
		end
		env = callerEnv
	end
	return VFS.Include(path .. ".lua", env, mode)
end

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
	BAR.Utilities = BAR.Utilities or springFunctions.Utilities
	BAR.Debug = BAR.Debug or springFunctions.Debug
	VFS.Include("common/platformFunctions.lua")
	VFS.Include("common/constants.lua")
end

if commonFunctions.i18n[environment] then
	BAR.I18N = BAR.I18N or VFS.Include("modules/i18n/i18n.lua")
end

if commonFunctions.cmd[environment] then
	Game.Commands = VFS.Include("modules/commands.lua")
	Game.CustomCommands = VFS.Include("modules/customcommands.lua")
end

if commonFunctions.map[environment] then
	BAR.Lava = VFS.Include("modules/lava.lua")
end

if commonFunctions.graphics[environment] then
	VFS.Include("modules/graphics/init.lua").Init(gl)
end

-- we don't want them to run these tests for end users
-- uncomment this only when working on functions in `common/tablefunctions.lua`
-- VFS.Include('common/tableFunctionsTests.lua')
