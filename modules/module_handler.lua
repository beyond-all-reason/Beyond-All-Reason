local root = GG or WG or _G
if root.__moduleHandler then
	return root.__moduleHandler
end

local LOG_TAG = "module_handler.lua"

local MODULES_DIR = "modules/"

local LAYOUT = {
	manifest = "manifest.lua",
	widgets = "widgets/",
	rmlWidgets = "rml_widgets/",
	gadgets = "gadgets/",
	scripts = "scripts/",
	modOptions = "modoptions.lua",
	state = "state.lua",
}

local ModuleHandler = {}

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

---@param dir string
---@return string
local function ensureSlash(dir)
	if dir:sub(-1) ~= "/" then
		return dir .. "/"
	end
	return dir
end

---@param t table
---@return string[] keys sorted
local function sortedKeys(t)
	local keys = {}
	for key in pairs(t) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

---@generic A, T
---@param list T[]
---@param step fun(acc: A, item: T): A
---@param acc A
---@return A
local function reduce(list, step, acc)
	for _, item in ipairs(list) do
		acc = step(acc, item)
	end
	return acc
end

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
	manifestsCache = ModuleHandler.Resolve(manifests, logError)
	return manifestsCache
end

---@param manifests table<string, ModuleManifest> discovered, keyed by name
---@param refuse fun(message: string) told once per refusal
---@return table<string, ModuleManifest> the ones that load
function ModuleHandler.Resolve(manifests, refuse)
	local verdict = {}

	local function judge(name)
		if verdict[name] == nil then
			verdict[name] = true
			for _, required in ipairs(manifests[name].requires) do
				if not manifests[required] then
					verdict[name] = string.format("Module %q requires missing module %q; not loaded", name, required)
					break
				elseif judge(required) ~= true then
					verdict[name] = string.format("Module %q requires %q, which is not loaded", name, required)
					break
				end
			end
		end
		return verdict[name]
	end

	local categories = reduce(sortedKeys(manifests), function(acc, name)
		local v = judge(name)
		if v == true then
			acc.loadable[name] = manifests[name]
		else
			acc.refused[name] = v
		end
		return acc
	end, { loadable = {}, refused = {} })

	for _, name in ipairs(sortedKeys(categories.refused)) do
		refuse(categories.refused[name])
	end
	return categories.loadable
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
