-- The environment a module file runs in.
--
-- A file under a module directory does not run in the environment of whoever required it. It runs in a fresh table
-- of its own. While the file loads, that table hands out the engine's globals (Spring, VFS, GG, UnitDefs, ...) and
-- the language's (pairs, string, table, error, ...). Once the file has returned, only the language is left: whatever
-- the file's functions need from the engine, the file imported at the top, `local Spring = Spring`. A read of
-- anything else, before or after load, is an error naming the file and the global. So is a write to a global.
--
-- Spring arrives as a proxy for the handle the file is declared for (HandleOf, the rule module_handler.lua states
-- above LAYOUT): api_synced.lua may not call what the engine offers to the unsynced handle only, api_unsynced.lua the
-- reverse, and a file that runs in any handle neither. The sets are modules/engine_handles.lua, generated from the
-- recoil-lua-library listings.
--
-- Files run through here: everything `require`d from under a module directory (init.lua's shim), and the files the
-- loader includes itself (manifests, policies, modes, modoptions, mode verbs). Gadgets, widgets and unit scripts are
-- loaded by their handlers and are not module files in this sense. The framework files at modules/ root are not
-- run through here yet.
-- One instance per Lua state: VFS.Include runs a file afresh on every include, and the table of module envs to their
-- handle env below has to be the same table for init.lua's shim and for the loader, so it lives on BAR.
if BAR ~= nil and BAR.ModuleEnv ~= nil then
	return BAR.ModuleEnv
end

local EngineHandles = require("modules/engine_handles")

---@class ModuleEnv
local ModuleEnv = {}
if BAR ~= nil then
	BAR.ModuleEnv = ModuleEnv
end

---@alias LuaHandle "synced"|"unsynced"|"both" both: a gadget, with a half for each

-- The language, offered for the life of the file.
local LANGUAGE = {}
for _, name in ipairs({
	"assert",
	"error",
	"pcall",
	"xpcall",
	"select",
	"type",
	"tostring",
	"tonumber",
	"pairs",
	"ipairs",
	"next",
	"unpack",
	"rawget",
	"rawset",
	"rawequal",
	"setmetatable",
	"getmetatable",
	"collectgarbage",
	"print",
	"require",
	"_VERSION",
	"string",
	"table",
	"math",
	"coroutine",
	"bit",
	"debug",
}) do
	LANGUAGE[name] = true
end

-- The engine and the game, offered while the file loads. Spring is in here by way of its proxy.
local ENGINE = {}
for _, name in ipairs({
	"Spring",
	"VFS",
	"Script",
	"Game",
	"GG",
	"WG",
	"SYNCED",
	"UnitDefs",
	"UnitDefNames",
	"WeaponDefs",
	"WeaponDefNames",
	"FeatureDefs",
	"FeatureDefNames",
	"CMD",
	"CMDTYPE",
	"COB",
	"gl",
	"GL",
	"Engine",
	"Platform",
	"Json",
	"i18n",
	"tracy",
	"RmlUi",
	"BAR",
	"LOG",
	"SendToUnsynced",
	"loadstring",
	"os",
	"io",
	"include",
}) do
	ENGINE[name] = true
end

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
---@param root table the handle's environment; Spring is read off it on every call, so a harness may swap it
---@return table proxy
local function springProxy(path, handle, root)
	return setmetatable({}, {
		__index = function(_, name)
			local only = ONLY_ON[name]
			if only ~= nil and only ~= handle then
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

-- Runs a module file in an environment of its own and returns what it returned.
---@param path string the file, with its .lua
---@param outer table the environment of whoever is including it; a module env resolves to the handle env under it
---@param mode string|nil as VFS.Include takes it
---@param injected table|nil names the file sees as globals for its whole life (the loader's Policies)
---@return any
function ModuleEnv.Include(path, outer, mode, injected)
	local root = roots[outer] or outer
	local handle = ModuleEnv.HandleOf(path)
	local env = {}
	for name, value in pairs(injected or {}) do
		env[name] = value
	end
	-- The language is copied in up front (synced Lua has no rawset to cache it on the way), so its names are plain
	-- hits for the life of the file and the metatable below only sees the rest.
	for name in pairs(LANGUAGE) do
		if env[name] == nil then
			env[name] = root[name]
		end
	end
	local proxy = nil
	local meta = {}
	meta.__index = function(_, name)
		if LANGUAGE[name] then
			return root[name]
		end
		if name == "Spring" then
			proxy = proxy or springProxy(path, handle, root)
			return proxy
		end
		if ENGINE[name] then
			return root[name]
		end
		error(string.format("%s reads global '%s', which module files are not offered", path, name), 2)
	end
	meta.__newindex = function(_, name)
		error(string.format("%s writes global '%s'; declare it local", path, name), 2)
	end
	setmetatable(env, meta)
	roots[env] = root
	local returned = VFS.Include(path, env, mode)
	meta.__index = function(_, name)
		if LANGUAGE[name] then
			return root[name]
		end
		if ENGINE[name] then
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
