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

local LOG_TAG = "module_handler.lua"

local MODULES_DIR = "modules/"

-- Subdirectories that mark a directory as a module even without a manifest.
local MODULE_MARKERS = { "widgets", "rml_widgets", "gadgets", "actions", "policies" }

local ModuleHandler = {}

--------------------------------------------------------------------------------
-- Include-once cache
--------------------------------------------------------------------------------

local includeCache = {}

---Include a file exactly once per Lua state, caching its return value.
---Synced and unsynced are separate Lua states, so isolation is preserved.
---@param path string
---@param vfsMode string?
---@return any
function ModuleHandler.Include(path, vfsMode)
	local cached = includeCache[path]
	if cached == nil then
		cached = VFS.Include(path, nil, vfsMode)
		includeCache[path] = cached
	end
	return cached
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
			Spring.Log(LOG_TAG, LOG.ERROR, "Invalid module manifest (missing name): " .. manifestPath)
			return nil
		end
		if manifest.name ~= name then
			Spring.Log(LOG_TAG, LOG.ERROR, string.format("Module manifest name %q does not match directory %q", manifest.name, name))
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
				Spring.Log(LOG_TAG, LOG.ERROR, string.format("Module %q requires missing module %q", name, required))
			end
		end
	end
	manifestsCache = manifests
	return manifests
end

---Resolve a module's public contract (its provides file, default api.lua).
---@param name string
---@param vfsMode string?
---@return table|nil api
function ModuleHandler.Get(name, vfsMode)
	local manifest = ModuleHandler.Discover(vfsMode)[name]
	if not manifest then
		Spring.Log(LOG_TAG, LOG.ERROR, "Unknown module: " .. tostring(name))
		return nil
	end
	local providesPath = manifest.provides or (manifest.dir .. "api.lua")
	if not VFS.FileExists(providesPath, vfsMode) then
		Spring.Log(LOG_TAG, LOG.ERROR, string.format("Module %q provides nothing (%s not found)", name, providesPath))
		return nil
	end
	return ModuleHandler.Include(providesPath, vfsMode)
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

--------------------------------------------------------------------------------
-- Actions: one file per action, declarative descriptor (shape shared with
-- luarules/mission_api/actions_loader.lua and PR #8226)
--------------------------------------------------------------------------------

---@param descriptor any
---@param filePath string
---@return ActionDescriptor|nil
local function validateAction(descriptor, filePath)
	if type(descriptor) ~= "table" or type(descriptor.name) ~= "string" or type(descriptor.execute) ~= "function" then
		Spring.Log(LOG_TAG, LOG.ERROR, "Invalid action descriptor (need name + execute): " .. filePath)
		return nil
	end
	for _, parameter in ipairs(descriptor.parameters or {}) do
		if type(parameter.name) ~= "string" or type(parameter.type) ~= "string" then
			Spring.Log(LOG_TAG, LOG.ERROR, string.format("Invalid parameter schema in action %q: %s", descriptor.name, filePath))
			return nil
		end
	end
	return descriptor
end

---Load and register a module's actions/ directory.
---@param name string module name
---@param vfsMode string?
---@return {byName: table<string, ActionDescriptor>, list: ActionDescriptor[]}
function ModuleHandler.LoadActions(name, vfsMode)
	local manifest = ModuleHandler.Discover(vfsMode)[name]
	local registry = { byName = {}, list = {} }
	if not manifest then
		Spring.Log(LOG_TAG, LOG.ERROR, "LoadActions: unknown module " .. tostring(name))
		return registry
	end
	local files = VFS.DirList(manifest.dir .. "actions/", "*.lua", vfsMode)
	table.sort(files)
	for _, filePath in ipairs(files) do
		local descriptor = validateAction(ModuleHandler.Include(filePath, vfsMode), filePath)
		if descriptor then
			if registry.byName[descriptor.name] then
				Spring.Log(LOG_TAG, LOG.ERROR, string.format("Duplicate action %q in module %q: %s", descriptor.name, name, filePath))
			else
				registry.byName[descriptor.name] = descriptor
				registry.list[#registry.list + 1] = descriptor
			end
		end
	end
	return registry
end

---Prevalidate call arguments against an action's declared parameter schema.
---@param action ActionDescriptor
---@param args table<string, any>
---@return boolean ok
function ModuleHandler.ValidateActionArgs(action, args)
	local ok = true
	for _, parameter in ipairs(action.parameters or {}) do
		local value = args[parameter.name]
		if value == nil and parameter.required then
			Spring.Log(LOG_TAG, LOG.ERROR, string.format("Action %q missing required parameter %q", action.name, parameter.name))
			ok = false
		end
		if value ~= nil and parameter.type ~= "any" and type(value) ~= parameter.type then
			Spring.Log(LOG_TAG, LOG.ERROR, string.format("Action %q parameter %q: expected %s, got %s", action.name, parameter.name, parameter.type, type(value)))
			ok = false
		end
	end
	return ok
end

--------------------------------------------------------------------------------
-- Policies: one file per policy under policies/<category>/, pure functions in
-- a declarative descriptor, evaluated in filename order
--------------------------------------------------------------------------------

---@param descriptor any
---@param filePath string
---@param category string
---@return PolicyDescriptor|nil
local function validatePolicy(descriptor, filePath, category)
	if type(descriptor) ~= "table" or type(descriptor.name) ~= "string" or type(descriptor.evaluate) ~= "function" then
		Spring.Log(LOG_TAG, LOG.ERROR, "Invalid policy descriptor (need name + evaluate): " .. filePath)
		return nil
	end
	descriptor.category = descriptor.category or category
	return descriptor
end

---Load a module's policies/ directory into per-category ordered lists.
---@param name string module name
---@param vfsMode string?
---@return table<string, PolicyDescriptor[]> policies keyed by category, in evaluation order
function ModuleHandler.LoadPolicies(name, vfsMode)
	local manifest = ModuleHandler.Discover(vfsMode)[name]
	local byCategory = {}
	if not manifest then
		Spring.Log(LOG_TAG, LOG.ERROR, "LoadPolicies: unknown module " .. tostring(name))
		return byCategory
	end
	for _, categoryDir in ipairs(VFS.SubDirs(manifest.dir .. "policies/", "*", vfsMode)) do
		local category = dirBasename(categoryDir)
		local files = VFS.DirList(ensureSlash(categoryDir), "*.lua", vfsMode)
		table.sort(files)
		local policies = {}
		for _, filePath in ipairs(files) do
			local descriptor = validatePolicy(ModuleHandler.Include(filePath, vfsMode), filePath, category)
			if descriptor then
				policies[#policies + 1] = descriptor
			end
		end
		byCategory[category] = policies
	end
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

---Testing hook: reset discovery + include caches.
function ModuleHandler.ResetCaches()
	includeCache = {}
	manifestsCache = nil
end

return ModuleHandler
