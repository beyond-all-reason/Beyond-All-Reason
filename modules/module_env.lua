-- The environment a module file runs in: a fresh table that hands out the engine's globals and the language while
-- the file loads, and the language alone after. Spring is a proxy for the file's handle (HandleOf) that refuses the
-- other handle's functions, read off common/recoil/names.lua (generated from the pinned recoil-lua-library). Any file
-- takes the same proxy, typed, with `local Spring = require("common/recoil/synced")` (ModuleEnv.Handle).
-- One instance per Lua state, on BAR: init.lua's shim and the loader share the env-to-root table below.
if BAR ~= nil and BAR.ModuleEnv ~= nil then
	return BAR.ModuleEnv
end

local EngineHandles = require("common/recoil/names")

---@class ModuleEnv
local ModuleEnv = {}
if BAR ~= nil then
	BAR.ModuleEnv = ModuleEnv
end

---@alias LuaHandle "synced"|"unsynced"|"both" both: a gadget, with a half for each

---@param ... string[]
---@return table<string, true>
local function set(...)
	local names = {}
	for _, list in ipairs({ ... }) do
		for _, name in ipairs(list) do
			names[name] = true
		end
	end
	return names
end

-- The game's own globals, beside the engine's: offered while a file loads, and `require` for its life.
local GAME = { "GG", "WG", "BAR", "Json", "i18n", "include", "UnitDefNames", "WeaponDefNames", "FeatureDefNames" }
local GAME_LANGUAGE = { "require" }

-- What a file is offered, by the handle it runs in ("any": what both handles have): the language for the life of
-- the file, the engine and the game while it loads, and Spring's members through the proxy.
local LANGUAGE = {
	synced = set(EngineHandles.sharedLanguage, EngineHandles.syncedOnlyLanguage, GAME_LANGUAGE),
	unsynced = set(EngineHandles.sharedLanguage, EngineHandles.unsyncedOnlyLanguage, GAME_LANGUAGE),
	any = set(EngineHandles.sharedLanguage, GAME_LANGUAGE),
}
local ENGINE = {
	synced = set(EngineHandles.sharedGlobals, EngineHandles.syncedOnlyGlobals, GAME),
	unsynced = set(EngineHandles.sharedGlobals, EngineHandles.unsyncedOnlyGlobals, GAME),
	any = set(EngineHandles.sharedGlobals, GAME),
}
local SPRING = {
	synced = set(EngineHandles.shared, EngineHandles.syncedOnly),
	unsynced = set(EngineHandles.shared, EngineHandles.unsyncedOnly),
	any = set(EngineHandles.shared),
}

---@param handle LuaHandle|nil
---@return "synced"|"unsynced"|"any"
local function sideOf(handle)
	if handle == "synced" or handle == "unsynced" then
		return handle
	end
	return "any"
end

-- Which handle alone has a Spring member, for the error that names it.
---@type table<string, "synced"|"unsynced">
local ONLY_ON = {}
for _, name in ipairs(EngineHandles.syncedOnly) do
	ONLY_ON[name] = "synced"
end
for _, name in ipairs(EngineHandles.unsyncedOnly) do
	ONLY_ON[name] = "unsynced"
end

-- Module envs to the handle env they were built over, so a file required from inside a module file still reads the
-- engine through the real environment and not through the requiring file's sealed one.
---@type table<table, table>
local roots = setmetatable({}, { __mode = "k" })

---@type table<string, boolean>
local ownedDirs = {}

---@param path string a file path under modules/
---@return LuaHandle|nil handle nil for code that runs in any
function ModuleEnv.HandleOf(path)
	local rest = path:match("^modules/[^/]+/(.*)$")
	if rest == nil then
		return nil
	end
	local base = rest:match("([^/]+)$")
	if rest:find("^gadgets/") then
		return "both"
	end
	if base == "api_synced.lua" or base == "synced.lua" then
		return "synced"
	end
	if base == "api_unsynced.lua" or base == "unsynced.lua" or rest:find("^widgets/") or rest:find("^rml_widgets/") then
		return "unsynced"
	end
	return nil
end

-- Whether a file is a module file: under a directory in modules/ that ships a manifest. A module's spec/ is the
-- harness's, not the module's.
---@param path string
---@param mode string|nil as VFS.Include takes it
---@return boolean
function ModuleEnv.Owns(path, mode)
	local dir = path:match("^modules/([^/]+)/")
	if dir == nil or path:find("^modules/[^/]+/spec/") then
		return false
	end
	if ownedDirs[dir] == nil then
		ownedDirs[dir] = VFS.FileExists("modules/" .. dir .. "/manifest.lua", mode) == true
	end
	return ownedDirs[dir]
end

-- The handle environment under a module env, or the env itself when it is not one. A file that is not a module
-- file, required from inside a module file, runs here and not in the requiring file's sealed environment.
---@param env table
---@return table
function ModuleEnv.RootOf(env)
	return roots[env] or env
end

---@param handle LuaHandle|nil
---@return string
local function runsIn(handle)
	if handle == "synced" or handle == "unsynced" then
		return "this file runs in the " .. handle .. " handle"
	end
	return "this file runs in any handle"
end

---@param path string
---@param handle LuaHandle|nil
---@param root table the handle's environment; Recoil.Shared is read off it on every call, so a harness may swap it
---@return table proxy
local function springProxy(path, handle, root)
	local offered = SPRING[sideOf(handle)]
	return setmetatable({}, {
		__index = function(_, name)
			if not offered[name] then
				local only = ONLY_ON[name]
				if only == nil then
					error(string.format("%s calls Spring.%s, which the engine does not offer", path, name), 2)
				end
				error(
					string.format(
						"%s calls Spring.%s, which the engine offers in the %s handle only; %s",
						path,
						name,
						only,
						runsIn(handle)
					),
					2
				)
			end
			return root.Spring[name]
		end,
		__newindex = function(_, name)
			error(string.format("%s writes Spring.%s", path, name), 2)
		end,
	})
end

-- Whether the engine in this Lua state registers what one handle has alone: any of that handle's own names is set.
---@param spring table|nil
---@param handle "synced"|"unsynced"
---@return boolean
local function offers(spring, handle)
	if spring == nil then
		return false
	end
	for _, name in ipairs(handle == "synced" and EngineHandles.syncedOnly or EngineHandles.unsyncedOnly) do
		if spring[name] ~= nil then
			return true
		end
	end
	return false
end

-- Handle proxies by the environment Spring is read off, one per handle per Lua state.
---@type table<table, table<string, table>>
local handleProxies = setmetatable({}, { __mode = "k" })

-- The engine as one handle sees it, for a file of any kind: what common/recoil/{shared,synced,unsynced}.lua return,
-- so `local Spring = require("common/recoil/synced")` is the handle at check time (the file's return is cast) and at
-- run time (this proxy, the one a module file's Spring is). Requiring a handle's view in the other handle's state
-- is an error, not a Spring that comes up empty.
---@param handle "synced"|"unsynced"|nil nil for what both handles have
---@param root table|nil the environment Spring is read off; the state's globals when absent
---@return table Spring
function ModuleEnv.Handle(handle, root)
	root = root or _G
	local key = handle or "shared"
	local proxies = handleProxies[root]
	if proxies == nil then
		proxies = {}
		handleProxies[root] = proxies
	end
	if proxies[key] == nil then
		if handle ~= nil then
			local other = handle == "synced" and "unsynced" or "synced"
			if not offers(root.Spring, handle) and offers(root.Spring, other) then
				error(string.format("common/recoil/%s required in the %s handle", handle, other), 2)
			end
		end
		proxies[key] = springProxy(string.format('a file holding require("common/recoil/%s")', key), handle, root)
	end
	return proxies[key]
end

-- Runs a module file in an environment of its own and returns what it returned.
---@param path string the file, with its .lua
---@param outer table the environment of whoever is including it; a module env resolves to the handle env under it
---@param mode string|nil as VFS.Include takes it
---@param injected table|nil names the file sees as globals for its whole life (the loader's Policies)
---@return any
function ModuleEnv.Include(path, outer, mode, injected)
	local root = roots[outer] or outer
	local handle = ModuleEnv.HandleOf(path)
	local language, engine = LANGUAGE[sideOf(handle)], ENGINE[sideOf(handle)]
	local env = {}
	for name, value in pairs(injected or {}) do
		env[name] = value
	end
	-- The language is copied in up front (synced Lua has no rawset to cache it on the way), so its names are plain
	-- hits for the life of the file and the metatable below only sees the rest.
	for name in pairs(language) do
		if env[name] == nil then
			env[name] = root[name]
		end
	end
	local proxy = nil
	local meta = {}
	meta.__index = function(_, name)
		if language[name] then
			return root[name]
		end
		if name == "Spring" then
			proxy = proxy or springProxy(path, handle, root)
			return proxy
		end
		if engine[name] then
			return root[name]
		end
		error(string.format("%s reads global '%s', which module files are not offered", path, name), 2)
	end
	meta.__newindex = function(_, name)
		error(string.format("%s writes global '%s'; declare it local", path, name), 2)
	end
	setmetatable(env, meta)
	roots[env] = root
	-- the file is read through the handle env's VFS, so an env that serves files of its own serves this one too
	local vfs = root.VFS or VFS
	local returned = vfs.Include(path, env, mode)
	meta.__index = function(_, name)
		if language[name] then
			return root[name]
		end
		if engine[name] then
			error(
				string.format(
					"%s reads %s after load; import it at the top of the file: local %s = %s",
					path,
					name,
					name,
					name
				),
				2
			)
		end
		error(string.format("%s reads global '%s', which module files are not offered", path, name), 2)
	end
	return returned
end

return ModuleEnv
