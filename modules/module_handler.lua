--- One instance per Lua state. VFS.Include is uncached, so without this every
--- gadget and widget that includes the handler would get its own copy and its
--- own caches, and the manifests would be read once per includer instead of
--- once per state. Anchored in the state's root the way State() anchors a
--- module's state; the spec harness resets that root between files.
local root = GG or WG or _G
if root.__moduleHandler then
	return root.__moduleHandler
end

local LOG_TAG = "module_handler.lua"

local MODULES_DIR = "modules/"

---What a module directory may contain; the loader knows nothing else.
local LAYOUT = {
	manifest = "module.lua",
	widgets = "widgets/",
	rmlWidgets = "rml_widgets/",
	gadgets = "gadgets/",
	scripts = "scripts/",
	modOptions = "modoptions.lua",
	state = "state.lua",
}

local ModuleHandler = {}

---modoptions.lua pulls this file into lobby/unitsync contexts where the Spring global does not exist.
---@param message string
local function logError(message)
	---@diagnostic disable-next-line: unnecessary-if -- Spring IS nil in lobby LuaParser; the analyzer can't know
	if Spring and Spring.Log then
		Spring.Log(LOG_TAG, LOG and LOG.ERROR or "error", message)
	else
		print("[" .. LOG_TAG .. "] ERROR: " .. message)
	end
end

---@param dir string directory with trailing slash
---@return string name
local function dirBasename(dir)
	return dir:gsub("/+$", ""):match("([^/]+)$") --[[@as string]]
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

---A directory under modules/ is a module only if it ships a module.lua that
---names itself; anything else there is ignored.
---@param moduleDir string
---@param vfsMode string?
---@return ModuleManifest|nil
local function loadManifest(moduleDir, vfsMode)
	local name = dirBasename(moduleDir)
	local manifestPath = moduleDir .. LAYOUT.manifest
	if not VFS.FileExists(manifestPath, vfsMode) then
		return nil
	end
	---@type ModuleManifestFile
	local manifest = VFS.Include(manifestPath, nil, vfsMode)
	if type(manifest) ~= "table" or type(manifest.name) ~= "string" then
		logError("Invalid module manifest (missing name): " .. manifestPath)
		return nil
	end
	if manifest.name ~= name then
		logError(string.format("Module manifest name %q does not match directory %q", manifest.name, name))
		return nil
	end
	---@cast manifest ModuleManifest
	manifest.dir = moduleDir
	manifest.requires = manifest.requires or {}
	return manifest
end

local manifestsCache = nil ---@type table<string, ModuleManifest>|nil

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
	return moduleSubdirs(LAYOUT.widgets, vfsMode)
end

---@param vfsMode string?
---@return string[]
function ModuleHandler.RmlWidgetDirs(vfsMode)
	return moduleSubdirs(LAYOUT.rmlWidgets, vfsMode)
end

---Lua unit scripts a module ships; the unit script loader lists these next
---to scripts/, and a def names one by its full modules/ path.
---@param vfsMode string?
---@return string[]
function ModuleHandler.ScriptDirs(vfsMode)
	return moduleSubdirs(LAYOUT.scripts, vfsMode)
end

---@param vfsMode string?
---@return string[]
function ModuleHandler.GadgetDirs(vfsMode)
	return moduleSubdirs(LAYOUT.gadgets, vfsMode)
end

---A module's in-memory state: one table per module that every include
---instance in this Lua state sees alike. Called from the module's state.lua
---and nowhere else; that file declares the table's class and returns it, so
---every reader is typed against one declaration. The convention: a file-level
---table that is written after load lives in state.lua, never in a `local`.
---VFS.Include is uncached, so a local is one copy per includer and a cache in
---one file becomes five caches in five. Constants and pure functions may stay
---local; copies of those are harmless.
---@param name string a Modules entry (modules/enums.lua)
---@return table
function ModuleHandler.State(name)
	local root = GG or WG or _G
	root.__moduleState = root.__moduleState or {}
	root.__moduleState[name] = root.__moduleState[name] or {}
	return root.__moduleState[name]
end

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
		local fragmentPath = manifest.dir .. LAYOUT.modOptions
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

function ModuleHandler.ResetCaches()
	manifestsCache = nil
end

root.__moduleHandler = ModuleHandler
return ModuleHandler
