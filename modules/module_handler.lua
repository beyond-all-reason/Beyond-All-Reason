--- Encapsulated game modules: discovery, contracts, and auto-registration.
---
--- A module is a directory under modules/ with opinionated subdirectories:
---   widgets/               unsynced widgets, auto-loaded (luaui/barwidgets.lua)
---   rml_widgets/           RmlUi widgets, auto-loaded (luaui/barwidgets.lua)
---   gadgets/               gadgets, auto-loaded (luarules/gadgets.lua)
---   actions/               one file per action returning an ActionDescriptor
---   policies/<category>/   one file per policy returning a PolicyDescriptor;
---                          evaluated in filename order (use numeric prefixes)
---   modes/                 declarative ModeConfig presets
---   lib/                   shared pure code
---   economy/, types/, spec/ ...
---
--- An optional module.lua manifest (ModuleManifest) declares version, requires
--- and provides; a directory with any auto-loaded subdirectory is discovered as
--- a module even without one. Plain shared-lib directories (modules/i18n,
--- modules/graphics) have none of those subdirectories and are left alone.
---
--- Game-side loading is the shim for engine-native module loading (Recoil RFC);
--- the layout is the contract, this file is the reference implementation.
--- There is deliberately NO game-side include cache: VFS.Include is uncached in
--- the engine, and a per-handler cache would only pretend otherwise (this file
--- is itself re-included per consumer). Registries and contracts are memoized
--- per handler; true load-once-per-state is the engine RFC's require().

local LOG_TAG = "module_handler.lua"

local PolicyBuilder = VFS.Include("modules/policy_builder.lua")

local MODULES_DIR = "modules/"

-- Subdirectories that mark a directory as a module even without a manifest.
local MODULE_MARKERS = { "widgets", "rml_widgets", "gadgets", "actions", "policies" }

local ModuleHandler = {}

---Log an error via Spring when available; modoptions.lua pulls this file into
---lobby/unitsync LuaParser contexts where the Spring global does not exist.
---@param message string
local function logError(message)
	if Spring and Spring.Log then
		Spring.Log(LOG_TAG, LOG and LOG.ERROR or "error", message)
	else
		print("[" .. LOG_TAG .. "] ERROR: " .. message)
	end
end

--------------------------------------------------------------------------------
-- Discovery
--------------------------------------------------------------------------------

---@param dir string directory with trailing slash
---@return string name
local function dirBasename(dir)
	return dir:gsub("/+$", ""):match("([^/]+)$")
end

---Native VFS.SubDirs returns entries with a trailing slash; keep any source normalized.
---@param dir string
---@return string
local function ensureSlash(dir)
	if dir:sub(-1) ~= "/" then
		return dir .. "/"
	end
	return dir
end

---@param moduleDir string
---@param vfsMode string?
---@return boolean
local function hasModuleMarker(moduleDir, vfsMode)
	for _, marker in ipairs(MODULE_MARKERS) do
		local sub = moduleDir .. marker .. "/"
		if #VFS.DirList(sub, "*", vfsMode) > 0 or #VFS.SubDirs(sub, "*", vfsMode) > 0 then
			return true
		end
	end
	return false
end

---@param moduleDir string
---@param vfsMode string?
---@return ModuleManifest|nil
local function loadManifest(moduleDir, vfsMode)
	local name = dirBasename(moduleDir)
	local manifestPath = moduleDir .. "module.lua"
	---@type ModuleManifest
	local manifest
	if VFS.FileExists(manifestPath, vfsMode) then
		manifest = VFS.Include(manifestPath, nil, vfsMode)
		if type(manifest) ~= "table" or type(manifest.name) ~= "string" then
			logError("Invalid module manifest (missing name): " .. manifestPath)
			return nil
		end
		if manifest.name ~= name then
			logError(string.format("Module manifest name %q does not match directory %q", manifest.name, name))
			return nil
		end
	elseif hasModuleMarker(moduleDir, vfsMode) then
		-- Implicit manifest: a bare directory with auto-loaded subdirectories.
		manifest = { name = name }
	else
		return nil
	end
	manifest.dir = moduleDir
	manifest.requires = manifest.requires or {}
	return manifest
end

local manifestsCache = nil ---@type table<string, ModuleManifest>|nil

---Discover all modules. Cached after the first call.
---@param vfsMode string?
---@return table<string, ModuleManifest> manifests keyed by module name
function ModuleHandler.Discover(vfsMode)
	if manifestsCache then
		return manifestsCache
	end
	local manifests = {}
	for _, moduleDir in ipairs(VFS.SubDirs(MODULES_DIR, "*", vfsMode)) do
		local manifest = loadManifest(ensureSlash(moduleDir), vfsMode)
		if manifest then
			manifests[manifest.name] = manifest
		end
	end
	for name, manifest in pairs(manifests) do
		for _, required in ipairs(manifest.requires) do
			if not manifests[required] then
				logError(string.format("Module %q requires missing module %q", name, required))
			end
		end
	end
	manifestsCache = manifests
	return manifests
end

---The current Lua state. Only the synced LuaRules/LuaGaia VM has SendToUnsynced;
---LuaUI/LuaMenu and the unsynced gadget state resolve as "unsynced".
---@return "synced"|"unsynced"
local function currentState()
	return (SendToUnsynced ~= nil) and "synced" or "unsynced"
end

local apiCache = {}

---Resolve a module's public contract for the current Lua state.
---
---The manifest declares the partition explicitly — provides as a plain path
---(state-agnostic) or { shared = path, synced = path, unsynced = path } —
---and resolution merges implicitly: consumers hold one flat api holding
---exactly the surface that exists where they stand (state keys win over
---shared on collision). A widget never sees synced-only keys, and vice
---versa; wrong-state access is nil at the first index, not a crash later.
---@param name string
---@param vfsMode string?
---@return table|nil api
function ModuleHandler.Get(name, vfsMode)
	local state = currentState()
	local cacheKey = name .. "|" .. state
	if apiCache[cacheKey] then
		return apiCache[cacheKey]
	end

	local manifest = ModuleHandler.Discover(vfsMode)[name]
	if not manifest then
		logError("Unknown module: " .. tostring(name))
		return nil
	end

	local provides = manifest.provides
	local parts = {}
	if type(provides) == "table" then
		parts[#parts + 1] = provides.shared
		parts[#parts + 1] = provides[state]
	else
		parts[1] = provides or (manifest.dir .. "api.lua")
	end

	local api = {}
	local resolved = 0
	for _, path in ipairs(parts) do
		if VFS.FileExists(path, vfsMode) then
			local part = VFS.Include(path, nil, vfsMode)
			if type(part) ~= "table" then
				logError(string.format("Module %q contract must return a table: %s", name, path))
			else
				for key, value in pairs(part) do
					api[key] = value
				end
				resolved = resolved + 1
			end
		else
			logError(string.format("Module %q contract file not found: %s", name, path))
		end
	end
	if resolved == 0 then
		logError(string.format("Module %q provides nothing in %s state", name, state))
		return nil
	end

	apiCache[cacheKey] = api
	return api
end

--------------------------------------------------------------------------------
-- Auto-loaded subdirectories (consumed by luarules/gadgets.lua, luaui/barwidgets.lua)
--------------------------------------------------------------------------------

---@param subdir string e.g. "widgets/"
---@param vfsMode string?
---@return string[] dirs
local function moduleSubdirs(subdir, vfsMode)
	local dirs = {}
	for _, manifest in pairs(ModuleHandler.Discover(vfsMode)) do
		local dir = manifest.dir .. subdir
		if #VFS.DirList(dir, "*.lua", vfsMode) > 0 or #VFS.SubDirs(dir, "*", vfsMode) > 0 then
			dirs[#dirs + 1] = dir
		end
	end
	table.sort(dirs)
	return dirs
end

---@param vfsMode string?
---@return string[]
function ModuleHandler.WidgetDirs(vfsMode)
	return moduleSubdirs("widgets/", vfsMode)
end

---@param vfsMode string?
---@return string[]
function ModuleHandler.RmlWidgetDirs(vfsMode)
	return moduleSubdirs("rml_widgets/", vfsMode)
end

---@param vfsMode string?
---@return string[]
function ModuleHandler.GadgetDirs(vfsMode)
	return moduleSubdirs("gadgets/", vfsMode)
end

---Mode-preset directories contributed by modules ("surrogate modes": presets
---travel with the module that owns the modoptions they lock; the root modes/
---system aggregates them).
---@param vfsMode string?
---@return string[]
function ModuleHandler.ModeDirs(vfsMode)
	return moduleSubdirs("modes/", vfsMode)
end

--------------------------------------------------------------------------------
-- Actions: registration-style, one file per action, identity = filename.
-- The loader injects `Actions` into each file's environment (the widget-handler
-- idiom: an explicit named Register call on an explicit local — NOT anonymous
-- setfenv globals, which is the fragility dbg_test_runner migrated away from).
-- Files register and return nothing; the runtime descriptor is assembled here,
-- never hand-authored. Runtime parameter schemas return, derived from the
-- LuaCATS annotations (single-sourced), if/when a data-driven dispatcher
-- (mission_api, CampaignAPI) creates a boundary the type checker cannot see.
--------------------------------------------------------------------------------

---@param filePath string
---@return string
local function nameFromFile(filePath)
	return filePath:match("([^/]+)%.lua$")
end

-- Base environment for registration files: this chunk's own environment, so
-- injected files see exactly what this file sees (VFS, Spring, ...). The
-- synced state defines _G; unsynced widget sandboxes may not, so fall back
-- to getfenv (kept in unsynced). Discovered via headless smoke: __index = _G
-- alone left action files without VFS in the widget path.
local CHUNK_ENV = _G
if CHUNK_ENV == nil or CHUNK_ENV.VFS == nil then
	local ok, env = pcall(getfenv, 1)
	if ok and env ~= nil then
		CHUNK_ENV = env
	end
end

---Include a registration file with names injected into its environment.
---Deliberately UNCACHED: registration must re-fire per include. The engine's
---VFS.Include is uncached by nature; the busted shim only caches truthy
---returns, and registration files return nothing.
---@param filePath string
---@param injected table
---@param vfsMode string?
---@return any returned whatever the file returned (must be nil)
local function includeRegistrationFile(filePath, injected, vfsMode)
	local env = setmetatable(injected, { __index = CHUNK_ENV })
	return VFS.Include(filePath, env, vfsMode)
end

local actionsCache = {}

---Load a module's actions/ directory: bracketed registration per file.
---@param name string module name
---@param vfsMode string?
---@return {byName: table<string, ActionDescriptor>, list: ActionDescriptor[]}
function ModuleHandler.LoadActions(name, vfsMode)
	if actionsCache[name] then
		return actionsCache[name]
	end
	local manifest = ModuleHandler.Discover(vfsMode)[name]
	local registry = { byName = {}, list = {} }
	if not manifest then
		logError("LoadActions: unknown module " .. tostring(name))
		return registry
	end
	local files = VFS.DirList(manifest.dir .. "actions/", "*.lua", vfsMode)
	table.sort(files)
	for _, filePath in ipairs(files) do
		local actionName = nameFromFile(filePath)
		---@type ActionDescriptor
		local entry = { name = actionName }
		local registrar = {
			---@param fn function pure precondition; must precede RegisterExecute
			RegisterValidate = function(fn)
				if type(fn) ~= "function" then
					error(filePath .. ": Actions.RegisterValidate expects a function")
				end
				if entry.execute ~= nil then
					error(filePath .. ": RegisterValidate must precede RegisterExecute")
				end
				if entry.validate ~= nil then
					error(filePath .. ": duplicate RegisterValidate")
				end
				entry.validate = fn
			end,
			---@param fn function the only effectful code; exactly one per file
			RegisterExecute = function(fn)
				if type(fn) ~= "function" then
					error(filePath .. ": Actions.RegisterExecute expects a function")
				end
				if entry.execute ~= nil then
					error(filePath .. ": duplicate RegisterExecute — exactly one per action file")
				end
				entry.execute = fn
			end,
		}
		local returned = includeRegistrationFile(filePath, { Actions = registrar }, vfsMode)
		if returned ~= nil then
			error(filePath .. ": action files register, they do not return (old descriptor style?)")
		end
		if entry.execute == nil then
			error(filePath .. ": no Actions.RegisterExecute — every action must register execute")
		end
		registry.byName[actionName] = entry
		registry.list[#registry.list + 1] = entry
	end
	actionsCache[name] = registry
	return registry
end

--------------------------------------------------------------------------------
-- Policies: registration-style, one pipeline per category, identity = filename.
-- The loader injects `Policies` (a Pipeline facade bound to this file's sink);
-- files end with :Register() and return nothing. Stage order is declaration
-- order; the first non-nil result wins; the Compute terminal always returns.
--------------------------------------------------------------------------------

local policiesCache = {}

---Load a module's policies/ directory into per-category ordered stage lists.
---@param name string module name
---@param vfsMode string?
---@return table<string, PolicyDescriptor[]> pipelines keyed by category (filename)
function ModuleHandler.LoadPolicies(name, vfsMode)
	if policiesCache[name] then
		return policiesCache[name]
	end
	local manifest = ModuleHandler.Discover(vfsMode)[name]
	local byCategory = {}
	if not manifest then
		logError("LoadPolicies: unknown module " .. tostring(name))
		return byCategory
	end
	local files = VFS.DirList(manifest.dir .. "policies/", "*.lua", vfsMode)
	table.sort(files)
	for _, filePath in ipairs(files) do
		local category = nameFromFile(filePath)
		local registered = nil
		local facade = {
			Pipeline = function()
				local builder = PolicyBuilder.Pipeline()
				builder._sink = function(stages)
					if registered ~= nil then
						error(filePath .. ": duplicate pipeline registration")
					end
					for _, stage in ipairs(stages) do
						stage.category = stage.category or category
					end
					registered = stages
				end
				return builder
			end,
		}
		local returned = includeRegistrationFile(filePath, { Policies = facade }, vfsMode)
		if returned ~= nil then
			error(filePath .. ": policy files register, they do not return (end with :Register())")
		end
		if registered == nil then
			error(filePath .. ": no pipeline registered — end with :Register()")
		end
		byCategory[category] = registered
	end
	policiesCache[name] = byCategory
	return byCategory
end

---Evaluate an ordered policy list: the first non-nil result wins.
---By convention the last policy (the 1xx_compute_* file) always returns.
---@generic R
---@param policies PolicyDescriptor[]
---@param ... any arguments passed to each policy's evaluate
---@return R|nil result nil only if no policy produced a result
function ModuleHandler.Evaluate(policies, ...)
	for _, policy in ipairs(policies) do
		local result = policy.evaluate(...)
		if result ~= nil then
			return result
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Mod options: modules ship their own modoptions.lua fragment, merged into the
-- game's modoptions.lua (same entry format; append order = module-name order)
--------------------------------------------------------------------------------

---Collect module-contributed modoption entries.
---@param vfsMode string?
---@return table[] options
function ModuleHandler.ModOptions(vfsMode)
	local names = {}
	for name in pairs(ModuleHandler.Discover(vfsMode)) do
		names[#names + 1] = name
	end
	table.sort(names)

	local options = {}
	for _, name in ipairs(names) do
		local manifest = ModuleHandler.Discover(vfsMode)[name]
		local fragmentPath = manifest.dir .. "modoptions.lua"
		if VFS.FileExists(fragmentPath, vfsMode) then
			local fragment = VFS.Include(fragmentPath, nil, vfsMode)
			if type(fragment) ~= "table" then
				logError("Module modoptions fragment must return a list: " .. fragmentPath)
			else
				for _, option in ipairs(fragment) do
					options[#options + 1] = option
				end
			end
		end
	end
	return options
end

--------------------------------------------------------------------------------

---Testing hook: reset discovery + include caches.
function ModuleHandler.ResetCaches()
	manifestsCache = nil
	apiCache = {}
	actionsCache = {}
	policiesCache = {}
end

return ModuleHandler
