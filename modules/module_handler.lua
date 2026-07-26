--- Deliberately NO include cache: VFS.Include is uncached in the engine, and this file is itself re-included per consumer.

local LOG_TAG = "module_handler.lua"

local PolicyBuilder = VFS.Include("modules/policy_builder.lua")

local MODULES_DIR = "modules/"

local MODULE_MARKERS = { "widgets", "rml_widgets", "gadgets", "actions", "policies" }

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
	---@type ModuleManifestFile
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
		manifest = { name = name }
	else
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

---Only the synced LuaRules/LuaGaia VM has SendToUnsynced.
---@return "synced"|"unsynced"
local function currentState()
	return (SendToUnsynced ~= nil) and "synced" or "unsynced"
end

local apiCache = {}

---State keys win over shared, so wrong-state access is nil at the first index, not a crash later.
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

---@param vfsMode string?
---@return string[]
function ModuleHandler.ModeDirs(vfsMode)
	return moduleSubdirs("modes/", vfsMode)
end

---@param filePath string
---@return string
local function nameFromFile(filePath)
	return filePath:match("([^/]+)%.lua$") --[[@as string]]
end

-- The synced state defines _G; unsynced widget sandboxes may not, so fall back
-- to getfenv: __index = _G alone left action files without VFS in the widget path.
---@type table
local CHUNK_ENV = _G
if CHUNK_ENV == nil or CHUNK_ENV.VFS == nil then
	local ok, env = pcall(getfenv, 1)
	if ok and env ~= nil then
		CHUNK_ENV = env
	end
end

---Deliberately UNCACHED: the busted shim only caches truthy returns, and
---registration files return nothing, so registration must re-fire per include.
---@param filePath string
---@param injected table
---@param vfsMode string?
---@return any returned whatever the file returned (must be nil)
local function includeRegistrationFile(filePath, injected, vfsMode)
	local env = setmetatable(injected, { __index = CHUNK_ENV })
	return VFS.Include(filePath, env, vfsMode)
end

local actionsCache = {}

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
		local entry = { name = actionName }
		---@cast entry ActionDescriptor -- execute arrives via RegisterExecute; enforced below
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

local policiesCache = {}
local enrichersCache = {}
local policyFiles = nil ---@type { chains: table, enrichments: table }|nil every module's policy chains and enrichments, read once

---@param vfsMode string?
---@return { chains: table<string, table<string, { module: string, identity: PolicyIdentity, ops: PolicyOp[], file: string }[]>>, enrichments: table<string, table<string, { module: string, ops: PolicyProvision[], file: string }[]>> }
local function loadPolicyFiles(vfsMode)
	if policyFiles then
		return policyFiles
	end
	local manifests = ModuleHandler.Discover(vfsMode)
	local names = {}
	for name in pairs(manifests) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local stagesPath = manifests[name].dir .. "contract.lua"
		if VFS.FileExists(stagesPath, vfsMode) then
			VFS.Include(stagesPath, nil, vfsMode)
		end
	end

	local chains, enrichments = {}, {}
	for _, name in ipairs(names) do
		local files = VFS.DirList(manifests[name].dir .. "policies/", "*.lua", vfsMode)
		table.sort(files)
		for _, filePath in ipairs(files) do
			local built = {} ---@type { kind: "pipeline"|"enrichment", chain: table }[]
			local facade = {
				Pipeline = function(stages)
					local chain = PolicyBuilder.Pipeline(stages)
					built[#built + 1] = { kind = "pipeline", chain = chain }
					return chain
				end,
				Enrich = function(token)
					local chain = PolicyBuilder.Enrichment(token)
					built[#built + 1] = { kind = "enrichment", chain = chain }
					return chain
				end,
			}
			local returned = includeRegistrationFile(filePath, { Policies = facade }, vfsMode)
			if returned ~= nil then
				error(filePath .. ": policy files build pipelines, they do not return")
			end
			if #built == 0 then
				error(filePath .. ": builds no pipeline and no enrichment")
			end
			for _, entry in ipairs(built) do
				if entry.kind == "pipeline" then
					local chain = entry.chain
					local identity = PolicyBuilder.IdentityOf(chain.stages)
					if identity == nil then
						error(
							filePath
								.. ": Policies.Pipeline needs the stages of a pipeline — a table from a module's contract.lua"
						)
					end
					if identity.context then
						error(filePath .. ": " .. identity.category .. " is a context, not a pipeline")
					end
					local ops = chain.Build()
					if #ops == 0 then
						error(filePath .. ": an empty chain")
					end
					chains[identity.owner] = chains[identity.owner] or {}
					local list = chains[identity.owner][identity.category] or {}
					chains[identity.owner][identity.category] = list
					list[#list + 1] = { module = name, identity = identity, ops = ops, file = filePath }
				else
					local chain = entry.chain
					local identity = PolicyBuilder.IdentityOf(chain.token)
					if identity == nil or not identity.context then
						error(
							filePath
								.. ": Policies.Enrich needs a context token — a Context(...) table from a module's contract.lua"
						)
					end
					local ops = chain.Build()
					if #ops == 0 then
						error(filePath .. ": an empty enrichment")
					end
					local known = {}
					for _, field in pairs(chain.token) do
						known[field] = true
					end
					for _, op in ipairs(ops) do
						for _, field in ipairs(op.names) do
							if not known[field] then
								error(
									filePath
										.. ": no provision named "
										.. field
										.. " on "
										.. identity.owner
										.. "."
										.. identity.category
								)
							end
						end
					end
					enrichments[identity.owner] = enrichments[identity.owner] or {}
					local list = enrichments[identity.owner][identity.category] or {}
					enrichments[identity.owner][identity.category] = list
					list[#list + 1] = { module = name, ops = ops, file = filePath }
				end
			end
		end
	end
	policyFiles = { chains = chains, enrichments = enrichments }
	return policyFiles
end

---@param name string module name
---@param vfsMode string?
---@return table<string, PolicyDescriptor[]> pipelines keyed by category, contributions applied
function ModuleHandler.LoadPolicies(name, vfsMode)
	if policiesCache[name] then
		return policiesCache[name]
	end
	if not ModuleHandler.Discover(vfsMode)[name] then
		logError("LoadPolicies: unknown module " .. tostring(name))
		return {}
	end
	local byCategory = {}
	-- The owner's chains open the pipeline, in file order; everyone else's
	-- follow in module-name order, so the outcome does not depend on archive
	-- scan order.
	for category, list in pairs(loadPolicyFiles(vfsMode).chains[name] or {}) do
		local ordered = {}
		for _, chain in ipairs(list) do
			if chain.module == name then
				ordered[#ordered + 1] = chain
			end
		end
		if #ordered == 0 then
			error(list[1].file .. ": " .. name .. " has no " .. category .. " pipeline of its own")
		end
		local others = {}
		for _, chain in ipairs(list) do
			if chain.module ~= name then
				others[#others + 1] = chain
			end
		end
		table.sort(others, function(a, b)
			return a.module < b.module
		end)
		for _, chain in ipairs(others) do
			ordered[#ordered + 1] = chain
		end
		local pipeline = { result = list[1].identity.result }
		for _, chain in ipairs(ordered) do
			PolicyBuilder.Apply(pipeline, chain.ops, chain.file)
		end
		for _, stage in ipairs(pipeline) do
			stage.category = category
		end
		PolicyBuilder.Validate(pipeline, pipeline.result, name .. "." .. category)
		byCategory[category] = pipeline
	end
	policiesCache[name] = byCategory
	return byCategory
end

---One table per module that every include instance in this Lua state
---shares: the anchor for state a module's files must see alike, so no
---module hand-rolls a global for it.
---@param name string module name
---@return table
function ModuleHandler.Shared(name)
	local root = GG or WG or _G
	root.__moduleShared = root.__moduleShared or {}
	root.__moduleShared[name] = root.__moduleShared[name] or {}
	return root.__moduleShared[name]
end

---A context's provisions, every module's merged: each field name provided
---exactly once, or the second provider is a load error naming both files.
---@param owner string module name
---@param category string the context token's name in the owner's contract.lua
---@param vfsMode string?
---@return PolicyProvision[]
function ModuleHandler.LoadEnrichers(owner, category, vfsMode)
	local key = owner .. "." .. category
	if enrichersCache[key] then
		return enrichersCache[key]
	end
	local list = (loadPolicyFiles(vfsMode).enrichments[owner] or {})[category] or {}
	table.sort(list, function(a, b)
		return a.module < b.module
	end)
	local provisions = {} ---@type PolicyProvision[]
	local providerOf = {}
	for _, enrichment in ipairs(list) do
		for _, op in ipairs(enrichment.ops) do
			for _, field in ipairs(op.names) do
				if providerOf[field] then
					error(
						enrichment.file
							.. ": "
							.. field
							.. " on "
							.. key
							.. " is already provided by "
							.. providerOf[field]
					)
				end
				providerOf[field] = enrichment.file
			end
			provisions[#provisions + 1] = op
		end
	end
	enrichersCache[key] = provisions
	return provisions
end

---Single-result pipelines answer with the first result a stage produces —
---a guard that fails (an Unless whose condition holds, an If whose condition
---does not) answers with the pipeline's Refusal (false when none is declared). Product pipelines multiply every factor produced.
---@generic C, T
---@param policies AssembledPipeline<C, T>
---@param ctx C
---@param ... any further arguments passed to each policy's evaluate
---@return T|nil result nil only if no policy produced a result
function ModuleHandler.Evaluate(policies, ctx, ...)
	if policies.result == "product" then
		local product = nil
		for _, policy in ipairs(policies) do
			local factor = policy.evaluate(ctx, ...)
			if factor ~= nil then
				product = (product or 1) * factor
			end
		end
		return product
	end
	for _, policy in ipairs(policies) do
		if policy.kind == "unless" then
			if policy.evaluate(ctx, ...) then
				return policies.refusal ~= nil and policies.refusal(ctx, ...) or false
			end
		elseif policy.kind == "if" then
			if not policy.evaluate(ctx, ...) then
				return policies.refusal ~= nil and policies.refusal(ctx, ...) or false
			end
		else
			local result = policy.evaluate(ctx, ...)
			if result ~= nil then
				return result
			end
		end
	end
	return nil
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

function ModuleHandler.ResetCaches()
	manifestsCache = nil
	apiCache = {}
	actionsCache = {}
	policiesCache = {}
	enrichersCache = {}
	policyFiles = nil
end

return ModuleHandler
