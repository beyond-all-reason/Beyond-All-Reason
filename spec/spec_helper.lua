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

-- Pure caches, so they are shared on purpose: the file listing shells out to find
-- over the whole repo, and re-reading every included file per spec file costs more
-- than the specs do. They live here rather than on VFS so nothing can reach them.
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
-- if we used `require("common/tablefunction")` above here, it could potentially cause "The same file is required with different names." linter errors when `VFS.Include("common/tablefunctions.lua")` is called
VFS.Include("common/tablefunctions.lua")

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
_G.Json = _G.Json or VFS.Include("common/luaUtilities/json.lua")

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
-- These tables are shared by every spec file, so a write to one reaches every file
-- that runs after it. Sealing turns that into an error where it happens.
--
-- The proxies hold nothing themselves: __newindex only fires for a key the table
-- does not already have, so a metatable on the real Spring would not catch an
-- assignment to Spring.Log.
local function sealed(name, backing)
	return setmetatable({}, {
		__index = backing,
		__newindex = function(_, key)
			error(
				("spec: %s.%s is shared by every spec file and cannot be assigned. Build an env instead: SpecEnv.new({ %s = { %s = ... } })"):format(
					name,
					tostring(key),
					name,
					tostring(key)
				),
				2
			)
		end,
		__metatable = false,
	})
end

-- The names have to be absent from _G itself for __newindex below to see a write
-- to one, so they are reached through __index instead.
local shared = {}
for _, name in ipairs({ "Spring", "VFS", "Game", "GG", "io" }) do
	shared[name] = sealed(name, _G[name])
	rawset(_G, name, nil)
end

local protected = {
	BAR = true,
	CMD = true,
	DEFS = true,
	FeatureDefs = true,
	GG = true,
	Game = true,
	GameCMD = true,
	Json = true,
	LOG = true,
	Shared = true,
	Spring = true,
	UnitDefNames = true,
	UnitDefs = true,
	VFS = true,
	WeaponDefNames = true,
	io = true,
}

setmetatable(_G, {
	__index = shared,
	__newindex = function(globals, key, value)
		if protected[key] then
			error(
				("spec: %s is shared by every spec file and cannot be assigned. Build an env instead: SpecEnv.new({ %s = ... })"):format(
					tostring(key),
					tostring(key)
				),
				2
			)
		end

		rawset(globals, key, value)
	end,
})
