-- Spring logging mocks
_G.LOG = _G.LOG or {
	ERROR = "ERROR",
	WARNING = "WARNING",
	INFO = "INFO",
	DEBUG = "DEBUG",
}

-- Log level hierarchy for filtering
local LOG_LEVELS = {
	[_G.LOG.DEBUG] = 1,
	[_G.LOG.INFO] = 2,
	[_G.LOG.WARNING] = 3,
	[_G.LOG.ERROR] = 4,
}

-- Current log level - only log messages at this level or higher
_G.CURRENT_LOG_LEVEL = _G.LOG.WARNING

local function isLogged(level)
	local levelValue = LOG_LEVELS[level]
	return levelValue ~= nil and levelValue >= (LOG_LEVELS[_G.CURRENT_LOG_LEVEL] or 0)
end

_G.Spring = _G.Spring
	or {
		Log = function(tag, level, message)
			-- If only one argument provided, treat it as a simple message
			if message == nil then
				message = tag
				tag = "Spring"
				level = _G.LOG.INFO
			end

			-- Only log if the message level meets or exceeds the current log level
			if isLogged(level) then
				print(string.format("[%s] %s: %s", tag, level, message))
			end
		end,
	}

-- Game code echoes while it runs, which would bury the spec output, so an echo counts as
-- INFO: set CURRENT_LOG_LEVEL to LOG.INFO to see echoes while debugging a spec.
_G.Spring.Echo = _G.Spring.Echo or function(...)
	if isLogged(_G.LOG.INFO) then
		print(...)
	end
end

_G.Game = _G.Game or {}

-- alldefs_post divides by this to work out the collision speed threshold, so leaving it
-- nil takes down the whole def post pass and every def arrives raw.
_G.Game.gameSpeed = _G.Game.gameSpeed or 30

_G.Game.envDamageTypes = _G.Game.envDamageTypes
	or {
		Debris = -1,
		GroundCollision = -2,
		ObjectCollision = -3,
		Fire = -4,
		Water = -5,
		Killed = -6,
		Crushed = -7,
		AircraftCrashed = -8,
		SetNegativeHealth = -9,
		SelfD = -10,
		KilledByCheat = -11,
		Reclaimed = -12,
		OutOfBounds = -13,
		TransportKilled = -14,
		FactoryKilled = -15,
		FactoryCancel = -16,
		UnitScript = -17,
		Kamikaze = -18,
		ConstructionDecay = -19,
		TurnedIntoFeature = -20,
		KilledByLua = -21,
		-- More are added via code for our lua-scripted damages.
	}

_G.CMD = _G.CMD or {}
_G.GameCMD = _G.GameCMD or {}
_G.GG = _G.GG or {}

_G.unpack = _G.unpack
	or table.unpack
	or function(t, i, j)
		i = i or 1
		j = j or #t
		if i > j then
			return
		end
		return t[i], _G.unpack(t, i + 1, j)
	end

-- Shared by every spec file, which is safe: neither depends on which file is running.
local fileCache
local sources = {}

-- VFS.Include mock for testing
_G.VFS = _G.VFS or {}

_G.VFS.FileExists = function(path)
	-- First try the exact path provided
	local file = io.open(path, "r")
	if file then
		file:close()
		return true
	end

	-- Fallback: Case-insensitive check using cached file list
	if not fileCache then
		fileCache = {}
		-- Find all files, excluding .git directory
		local handle = io.popen("find . -name '.git' -prune -o -type f -print")
		if handle then
			for line in handle:lines() do
				-- Strip leading ./
				local p = line:gsub("^%./", "")
				fileCache[p:lower()] = p
			end
			handle:close()
		end
	end

	local cleanPath = path:gsub("^%./", "")
	return fileCache[cleanPath:lower()] ~= nil
end

-- require -> VFS.Include stub for Lua files.
local realRequire = require
_G.require = function(path, env, mode)
	if type(path) == "string" then
		local ok, callerEnv = pcall(getfenv, 3) -- pcall, this function, the caller
		if not ok then
			error(
				"require(" .. path .. "): called as a tail call; pass an env, or assign the result before returning it",
				2
			)
		end
		-- env stays as given: the stub runs the file in _G unless a spec hands it a sandbox. Busted's own env
		-- carries luassert's assert, whose errors carry a position, and included game code must not see it
		local vfs = callerEnv.VFS or _G.VFS
		local file = path:find("%.lua$") and path or (path .. ".lua")
		if (vfs.FileExists or _G.VFS.FileExists)(file) then
			return (vfs.Include or _G.VFS.Include)(file, env, mode)
		end
	end
	return realRequire(path)
end

_G.VFS.Include = function(path, env, mode)
	-- Try direct path first
	local realPath = path
	local file = io.open(path, "r")
	if file then
		file:close()
	else
		-- Check case-insensitive cache
		if not fileCache then
			-- Force cache population by calling FileExists with a dummy path
			_G.VFS.FileExists("___dummy_path___")
		end

		local cleanPath = path:gsub("^%./", "")
		local cachedPath = fileCache[cleanPath:lower()]
		if cachedPath then
			realPath = cachedPath
		end
	end

	-- Use loadfile/dofile instead of require to better simulate VFS and handle case-insensitive paths
	-- The engine re-executes an included file on every call, so only the source
	-- text is reused: caching the result hands two defs the same table when one
	-- unit file includes another, and whichever loads second mutates the first.
	-- Each call compiles its own chunk, so a nested include of a path already on
	-- the include stack cannot retarget the environment of the outer one.
	local source = sources[realPath]
	if source == nil then
		local sourceFile = io.open(realPath, "r")
		source = sourceFile and sourceFile:read("*a") or false
		if sourceFile then
			sourceFile:close()
		end
		sources[realPath] = source
	end

	-- Missing source is a real error. Larger feature tests will try to fallback and
	-- tend to throw confusing "index a nil value" or etc. in code long after loading.
	if source then
		local chunk, compileError = loadstring(source, "@" .. realPath)
		if not chunk then
			error(string.format("VFS.Include failed to compile '%s': %s", path, tostring(compileError)), 0)
		end

		setfenv(chunk, env or _G)

		local success, result = pcall(chunk)
		if not success then
			error(string.format("VFS.Include failed to run '%s': %s", path, tostring(result)), 0)
		end
		return result
	end

	-- Fallback to old require method if file not found on disk (e.g. standard libs)
	-- Convert filesystem-like path to module name for require
	local mod = path:gsub("^%./", ""):gsub("%.lua$", ""):gsub("/", ".")

	local success, result = pcall(require, mod)
	if success then
		return result
	else
		-- Instead of erroring, return an empty table for missing files
		-- This allows unitdefs.lua and other files to continue loading even if some dependencies are missing
		return {}
	end
end

-- we have to do this after VFS.Include is declared
-- if we used `require("common/tablefunction")` above here, it could potentially cause "The same file is required with different names." linter errors when `require("common/tablefunctions")` is called
require("common/tablefunctions")
require("common/numberfunctions")
require("common/stringFunctions")

_G.VFS.SubDirs = function(path)
	-- Check case-insensitive cache for correct directory path
	if not fileCache then
		-- Force cache population
		_G.VFS.FileExists("___dummy_path___")
	end

	-- Currently the cache only has files. We need directories too or just assume 'find' works if we fix the path.
	-- But for SubDirs we want to list subdirectories.
	-- Let's assume the input path might be wrong casing.

	-- Simple heuristic: try to find the directory case-insensitively if it doesn't exist
	local searchPath = path
	local handle = io.open(path)
	if handle then
		handle:close()
	else
		-- Try to find matching directory
		local parent = path:match("(.+)/[^/]+$") or "."
		local base = path:match("([^/]+)$")
		if base then
			local pHandle = io.popen(string.format("find %s -maxdepth 1 -type d -iname '%s'", parent, base))
			if pHandle then
				local match = pHandle:read("*l")
				if match then
					searchPath = match
				end
				pHandle:close()
			end
		end
	end

	local dirs = {}
	local handle = io.popen(string.format("find %s -maxdepth 1 -type d", searchPath))
	if handle then
		for line in handle:lines() do
			if line ~= searchPath then
				table.insert(dirs, line)
			end
		end
		handle:close()
	end
	return dirs
end

_G.VFS.DirList = function(directory, pattern, mode, recursive)
	-- Returns relative paths with directory prefix, just like native VFS.DirList
	local files = {}
	local cmd

	-- Fix directory path case-sensitivity
	local searchDir = directory
	local handle = io.open(directory)
	if handle then
		handle:close()
	else
		-- Try to find matching directory case-insensitively
		local parent = directory:match("(.+)/[^/]+$") or "."
		local base = directory:match("([^/]+)$")
		if base then
			local pHandle = io.popen(string.format("find %s -maxdepth 1 -type d -iname '%s'", parent, base))
			if pHandle then
				local match = pHandle:read("*l")
				if match then
					searchDir = match
				end
				pHandle:close()
			end
		end
	end

	-- Use find command with pattern matching
	-- Use -iname for case-insensitive pattern matching
	-- -maxdepth is a global option, so it has to come before -iname
	local name_pattern = pattern and pattern ~= "*" and string.format("-iname '%s'", pattern) or ""
	if recursive then
		cmd = string.format("find %s %s -type f", searchDir, name_pattern)
	else
		cmd = string.format("find %s -maxdepth 1 %s -type f", searchDir, name_pattern)
	end

	local handle = io.popen(cmd)
	if handle then
		for line in handle:lines() do
			table.insert(files, line)
		end
		handle:close()
	end

	return files
end

_G.VFS.MAP = 1
_G.VFS.MOD = 2
_G.VFS.BASE = 4
_G.VFS_MODES = _G.VFS.MAP + _G.VFS.MOD + _G.VFS.BASE

-- The engine sets Json up globally in init.lua, so game code uses it without including it.
_G.Json = _G.Json or require("common/luaUtilities/json")

-- Stand-in for the engine's zlib, which is not available to plain Lua. Only the contract
-- game code depends on is modelled: a round trip, and a raise (not a nil) when handed
-- anything that is not a compressed payload.
local ZLIB_MARKER = "\120\156spec"

_G.VFS.ZlibCompress = _G.VFS.ZlibCompress or function(data)
	return ZLIB_MARKER .. data
end

_G.VFS.ZlibDecompress = _G.VFS.ZlibDecompress
	or function(data)
		if type(data) ~= "string" or data:sub(1, #ZLIB_MARKER) ~= ZLIB_MARKER then
			error("not a zlib stream", 0)
		end
		return data:sub(#ZLIB_MARKER + 1)
	end

-- to enable, `luarocks install inspect`
_G.inspect = (function()
	local ok, mod = pcall(require, "inspect")
	if ok and mod then
		return mod
	end
	-- fallback: no-op string (won't break prints/concats)
	return function(_)
		return _
	end
end)()

_G.VFS.LoadFile = function(path)
	local file = assert(io.open(path, "rb"))
	local contents = file:read("*a")
	file:close()
	return contents
end

-- Every spec file shares these tables, so a write to one would reach every file after it.
-- Proxies stay empty because __newindex never fires for a key the table already has.
local seals = {}

local SEAL = { __metatable = "sealed" }

function SEAL.__index(proxy, key)
	local sealed = seals[proxy]
	local nested = sealed.nested[key]
	if nested ~= nil then
		return nested
	end

	return sealed.backing[key]
end

-- common/tablefunctions.lua assigns table.pack to itself on every include.
function SEAL.__newindex(proxy, key, value)
	local sealed = seals[proxy]
	if rawequal(sealed.backing[key], value) or rawequal(sealed.nested[key], value) then
		return
	end

	error(
		("spec: %s.%s is shared by every spec file and cannot be assigned. Build an env with SpecEnv.new and write to its copy instead."):format(
			sealed.name,
			tostring(key)
		),
		2
	)
end

function SEAL.backing(proxy)
	return seals[proxy].backing
end

local function seal(name, backing)
	local nested = {}
	for key, value in pairs(backing) do
		if type(value) == "table" then
			nested[key] = seal(name .. "." .. tostring(key), value)
		end
	end

	local proxy = setmetatable({}, SEAL)
	seals[proxy] = { name = name, backing = backing, nested = nested }

	return proxy
end

local SHARED = { "Spring", "VFS", "Game", "io", "CMD", "GameCMD", "LOG", "Json", "string", "table", "math", "os" }

for _, name in ipairs(SHARED) do
	_G[name] = seal(name, _G[name])
end

-- Lua 5.1 has no __pairs, so enumerating a proxy would quietly find nothing.
local realPairs, realNext, realIpairs = pairs, next, ipairs

local function refuseSealed(value)
	local sealed = seals[value]
	if sealed then
		error(
			("spec: %s is sealed and cannot be enumerated. Load the code under test through SpecEnv, which hands it real tables."):format(
				sealed.name
			),
			3
		)
	end
end

_G.pairs = function(t)
	refuseSealed(t)

	return realPairs(t)
end

_G.next = function(t, key)
	refuseSealed(t)

	return realNext(t, key)
end

_G.ipairs = function(t)
	refuseSealed(t)

	return realIpairs(t)
end

-- busted passes itself to the function a helper returns.
return function(busted)
	-- Game code writes GG and def loading draws on math.random, so each file starts over.
	busted.subscribe({ "file", "start" }, function()
		_G.GG = {}
		math.randomseed(12345)

		-- Without true as the second return value, busted skips every subscriber after this one.
		return nil, true
	end)

	return true
end
