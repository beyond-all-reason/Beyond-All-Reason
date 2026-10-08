-- This file includes common functionality that should be available globally

-- Universal Lua functions applicable to any Lua code
-- These add missing base lua functionality
BAR = BAR or {} -- detached module namespace; must precede any BAR.X consumer

-- Recoil shim: require("path/to/file") is VFS.Include("path/to/file.lua")
-- Used instead of VFS.Include so EmmyLua can follow it and type the result without a decorator.
local engineRequire = require ---@type (fun(name: string): any)|nil nil in every game state but LuaIntro
---@param path string a repo path without its ".lua"
---@param env table|nil the environment the file runs in; the caller's when absent
---@param mode string|nil as VFS.Include takes it, e.g. VFS.ZIP
---@return any what the file returns
function require(path, env, mode)
	if engineRequire and path:sub(-4) == ".lua" then
		-- LuaIntro has an engine require, called with the ".lua" on; those calls go to it.
		return engineRequire(path)
	end
	if env == nil then
		-- the env of the caller is at level 3:
		--    - level 1  pcall (the C function that invoked getfenv)
		--    - level 2  require (our wrapper, which invoked pcall)
		--    - level 3  the file that called require   <- the env we want
		local ok, callerEnv = pcall(getfenv, 3)
		if not ok then
			-- the file runs in the caller's env, every call.
			-- That env is read off the stack, so no `return require(...)` (a tail call has no frame).
			error("require(" .. path .. "): called as a tail call; assign the result before returning it", 2)
		end
		env = callerEnv
	end
	return VFS.Include(path .. ".lua", env, mode)
end

-- FIXME: Unsynced Lua reads raw-first, so a file in the write dir would replace the game's. Fix in the engine.
if Script.GetName then
	-- Local copies, so nothing loaded later can swap what the wrapper calls.
	local vfsInclude = VFS.Include
	local zip = VFS.ZIP
	---@param path string
	---@param env table|nil the environment to run in, nil uses the caller's
	---@param mode string|nil VFS.ZIP when absent
	---@return any
	function VFS.Include(path, env, mode)
		if env == nil then
			-- level 1 pcall, level 2 this function, level 3 the caller
			local ok, callerEnv = pcall(getfenv, 3)
			-- A tail call gives no caller so we use our own env.
			env = ok and callerEnv or getfenv(0)
		end
		return vfsInclude(path, env, mode or zip)
	end
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
