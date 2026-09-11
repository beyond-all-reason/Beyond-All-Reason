local root = GG or WG or _G
if root.__moduleHandler then
	return root.__moduleHandler
end

local LOG_TAG = "module_handler.lua"

local PolicyBuilder = VFS.Include("modules/policy_builder.lua")

local MODULES_DIR = "modules/"

local LAYOUT = {
	manifest = "manifest.lua",
	contract = "contract.lua",
	widgets = "widgets/",
	rmlWidgets = "rml_widgets/",
	gadgets = "gadgets/",
	scripts = "scripts/",
	modes = "modes/",
	modeVerbs = "mode_verbs.lua",
	actions = "actions/",
	policies = "policies/",
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

---@param vfsMode string?
---@return string[]
function ModuleHandler.ModeDirs(vfsMode)
	return moduleSubdirs(LAYOUT.modes, vfsMode)
end

---@param filePath string
---@return string
local function nameFromFile(filePath)
	return filePath:match("([^/]+)%.lua$") --[[@as string]]
end

---@type table
local CHUNK_ENV = _G
if CHUNK_ENV == nil or CHUNK_ENV.VFS == nil then
	local ok, env = pcall(getfenv, 1)
	if ok and env ~= nil then
		CHUNK_ENV = env
	end
end

---@param filePath string
---@param injected table
---@param vfsMode string?
---@return any returned whatever the file returned (must be nil)
local function includeRegistrationFile(filePath, injected, vfsMode)
	local env = setmetatable(injected, { __index = CHUNK_ENV })
	return VFS.Include(filePath, env, vfsMode)
end

local actionsCache = {}

---@param filePath string
---@param vfsMode string?
---@return ActionDescriptor
local function loadAction(filePath, vfsMode)
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
		error(
			filePath
				.. ": action files register and return nothing; a returned value would be cached and the registration lost"
		)
	end
	if entry.execute == nil then
		error(filePath .. ": no Actions.RegisterExecute — every action must register execute")
	end
	return entry
end

---@param name string module name
---@param vfsMode string?
---@return {byName: table<string, ActionDescriptor>, list: ActionDescriptor[]}
function ModuleHandler.LoadActions(name, vfsMode)
	if actionsCache[name] then
		return actionsCache[name]
	end
	local manifest = ModuleHandler.Discover(vfsMode)[name]
	local registry = { byName = {}, list = {} }
	local files = VFS.DirList(manifest.dir .. LAYOUT.actions, "*.lua", vfsMode)
	table.sort(files)
	for _, filePath in ipairs(files) do
		local entry = loadAction(filePath, vfsMode)
		registry.byName[entry.name] = entry
		registry.list[#registry.list + 1] = entry
	end
	actionsCache[name] = registry
	return registry
end

local policiesCache = {}
local enrichersCache = {}
local presetsCache = nil
local policyFiles = nil ---@type { chains: table, enrichments: table }|nil every module's policy chains and enrichments, read once

---@param map table<string, table<string, table[]>>
---@param owner string
---@param category string
---@return table[]
local function bucket(map, owner, category)
	map[owner] = map[owner] or {}
	local list = map[owner][category] or {}
	map[owner][category] = list
	return list
end

---@param name string module name
---@param contract table the included contract.lua
---@param facts table<string, table<string, string[]>> facts[owner][category] = declared names
---@param contributions table<string, table<string, { module: string, names: string[] }[]>> keyed by the TARGET's owner and category
local function indexContract(name, contract, facts, contributions)
	for _, declared in pairs(contract) do
		local identity = PolicyBuilder.IdentityOf(declared)
		if identity then
			local names = {}
			for _, field in pairs(declared) do
				names[#names + 1] = field
			end
			if identity.facts then
				facts[identity.owner] = facts[identity.owner] or {}
				facts[identity.owner][identity.category] = names
			elseif identity.contributes then
				local target = identity.contributes
				local list = bucket(contributions, target.owner, target.category)
				list[#list + 1] = { module = name, names = names }
			end
		end
	end
end

---@class LoadedChain
---@field module string the module whose file built it
---@field identity PolicyIdentity the pipeline it builds against
---@field stages table the target's stage enum
---@field ops PolicyOp[]
---@field file string

---@class LoadedEnrichment
---@field module string
---@field identity PolicyIdentity the facts it provides for
---@field ops PolicyProvision[]
---@field file string

---@param name string module name
---@param source string the file, for messages
---@param run fun(facade: table): any hands the registrar to the source
---@return LoadedChain[] chains, LoadedEnrichment[] enrichments
local function collectPolicies(name, source, run)
	local filePath = source
	local built = {} ---@type { kind: "pipeline"|"enrichment", chain: table }[]
	local facade = {
		On = function(target)
			local identity = PolicyBuilder.IdentityOf(target)
			if identity and identity.facts then
				local chain = PolicyBuilder.Enrichment(target)
				built[#built + 1] = { kind = "enrichment", chain = chain }
				return chain
			end
			local chain = PolicyBuilder.Pipeline(target)
			built[#built + 1] = { kind = "pipeline", chain = chain }
			return chain
		end,
	}
	local returned = run(facade)
	if returned ~= nil then
		error(
			filePath
				.. ": policy files build pipelines and return nothing; a returned value would be cached and the registration lost"
		)
	end
	if #built == 0 then
		error(filePath .. ": builds no pipeline and no enrichment")
	end
	local chains, enrichments = {}, {}
	for _, entry in ipairs(built) do
		local chain = entry.chain
		if entry.kind == "pipeline" then
			local identity = PolicyBuilder.IdentityOf(chain.stages)
			if identity == nil then
				error(
					filePath
						.. ": Policies.On needs a pipeline's stages or a contract's facts, a table from a module's contract.lua"
				)
			end
			if identity.facts then
				error(filePath .. ": " .. identity.category .. " is facts, not a pipeline")
			end
			local ops = chain.Build()
			if #ops == 0 then
				error(filePath .. ": an empty chain")
			end
			chains[#chains + 1] =
				{ module = name, identity = identity, stages = chain.stages, ops = ops, file = filePath }
		else
			local identity = PolicyBuilder.IdentityOf(chain.facts)
			if identity == nil or not identity.facts then
				error(
					filePath
						.. ": Policies.On needs a pipeline's stages or a contract's facts, a table from a module's contract.lua"
				)
			end
			local ops = chain.Build()
			if #ops == 0 then
				error(filePath .. ": an empty enrichment")
			end
			enrichments[#enrichments + 1] = { module = name, identity = identity, ops = ops, file = filePath }
		end
	end
	return chains, enrichments
end

---@param name string module name
---@param filePath string
---@param vfsMode string?
---@return LoadedChain[] chains, LoadedEnrichment[] enrichments
local function loadPolicyFile(name, filePath, vfsMode)
	return collectPolicies(name, filePath, function(facade)
		return includeRegistrationFile(filePath, { Policies = facade }, vfsMode)
	end)
end

---@param name string module name
---@param contractPath string
---@param inline fun(Policies: table)
---@return LoadedChain[] chains, LoadedEnrichment[] enrichments
local function loadInlinePolicies(name, contractPath, inline)
	return collectPolicies(name, contractPath, function(facade)
		return inline(facade)
	end)
end

---@param vfsMode string?
---@return { chains: table<string, table<string, LoadedChain[]>>, enrichments: table<string, table<string, LoadedEnrichment[]>>, contributions: table, facts: table }
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

	local chains, enrichments = {}, {}
	local function keep(fileChains, fileEnrichments)
		for _, chain in ipairs(fileChains) do
			local list = bucket(chains, chain.identity.owner, chain.identity.category)
			list[#list + 1] = chain
		end
		for _, enrichment in ipairs(fileEnrichments) do
			local list = bucket(enrichments, enrichment.identity.owner, enrichment.identity.category)
			list[#list + 1] = enrichment
		end
	end

	local facts, contributions = {}, {}
	local inlines = {} ---@type { name: string, path: string, run: fun(Policies: table) }[]
	for _, name in ipairs(names) do
		local contractPath = manifests[name].dir .. LAYOUT.contract
		if VFS.FileExists(contractPath, vfsMode) then
			local contract = VFS.Include(contractPath, nil, vfsMode)
			indexContract(name, type(contract) == "table" and contract or {}, facts, contributions)
			local inline = PolicyBuilder.InlinePolicies(contract)
			if inline then
				inlines[#inlines + 1] = { name = name, path = contractPath, run = inline }
			end
		end
	end

	for _, entry in ipairs(inlines) do
		keep(loadInlinePolicies(entry.name, entry.path, entry.run))
	end
	for _, name in ipairs(names) do
		local files = VFS.DirList(manifests[name].dir .. LAYOUT.policies, "*.lua", vfsMode)
		table.sort(files)
		for _, filePath in ipairs(files) do
			keep(loadPolicyFile(name, filePath, vfsMode))
		end
	end
	policyFiles = { chains = chains, enrichments = enrichments, contributions = contributions, facts = facts }
	return policyFiles
end

---@param ops PolicyOp[]
---@param declared table<string, boolean> the names this module may add
---@return string|nil
function ModuleHandler.UndeclaredStep(ops, declared)
	for _, op in ipairs(ops) do
		if op.op == "add" and not declared[op.name] then
			return op.name
		end
	end
	return nil
end

---@param names table<any, string> a contract's stage enum, or a contribution's names
---@param landed table<string, boolean> the names on the assembled pipeline
---@return string|nil
function ModuleHandler.UnbuiltStage(names, landed)
	local missing = nil
	for _, stageName in pairs(names) do
		if not landed[stageName] and (missing == nil or stageName < missing) then
			missing = stageName
		end
	end
	return missing
end

---@param name string a Modules entry (modules/enums.lua)
---@param vfsMode string?
---@return table<string, PolicyDescriptor[]> pipelines keyed by category, contributions applied
function ModuleHandler.LoadPolicies(name, vfsMode)
	if policiesCache[name] then
		return policiesCache[name]
	end
	local byCategory = {}
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
		local contributions = (loadPolicyFiles(vfsMode).contributions[name] or {})[category] or {}
		local pipeline = { result = list[1].identity.result }
		for _, chain in ipairs(ordered) do
			local declared = {}
			if chain.module == name then
				for _, stageName in pairs(chain.stages) do
					declared[stageName] = true
				end
			else
				for _, contribution in ipairs(contributions) do
					if contribution.module == chain.module then
						for _, stageName in ipairs(contribution.names) do
							declared[stageName] = true
						end
					end
				end
			end
			local undeclared = ModuleHandler.UndeclaredStep(chain.ops, declared)
			if undeclared then
				error(
					chain.file
						.. ": adds a "
						.. undeclared
						.. " stage to "
						.. name
						.. "."
						.. category
						.. " that no contract declares; "
						.. (
							chain.module == name and "name it in the pipeline's stages in contract.lua"
							or "declare it with PolicyBuilder.Contributes in " .. chain.module .. "'s contract.lua"
						)
				)
			end
			PolicyBuilder.Assemble(pipeline, chain.ops, chain.file)
		end
		for _, stage in ipairs(pipeline) do
			stage.category = category
		end
		PolicyBuilder.Validate(pipeline, pipeline.result, name .. "." .. category)
		local landed = {}
		for _, stage in ipairs(pipeline) do
			landed[stage.name] = true
		end
		local unbuilt = ModuleHandler.UnbuiltStage(ordered[1].stages, landed)
		if unbuilt then
			error(
				ordered[1].file
					.. ": "
					.. name
					.. "'s contract declares a "
					.. unbuilt
					.. " stage on "
					.. category
					.. " but never builds it"
			)
		end
		for _, declared in ipairs(contributions) do
			local missing = ModuleHandler.UnbuiltStage(declared.names, landed)
			if missing then
				error(
					declared.module
						.. " declares a "
						.. missing
						.. " stage on "
						.. name
						.. "."
						.. category
						.. " but never builds it"
				)
			end
		end
		byCategory[category] = pipeline
	end
	policiesCache[name] = byCategory
	return byCategory
end

---@param name string a Modules entry (modules/enums.lua)
---@return table
function ModuleHandler.State(name)
	local root = GG or WG or _G
	root.__moduleState = root.__moduleState or {}
	root.__moduleState[name] = root.__moduleState[name] or {}
	return root.__moduleState[name]
end

---@param facts table the Facts table from the owner's contract.lua
---@param vfsMode string?
---@return PolicyProvision[]
---@class ModulePreset
---@field key string
---@field category string
---@field module string the module whose modes/ holds it
---@field uses string[] modules the preset makes live besides its own

local modeVerbsCache = {} ---@type table<string, table<string, ModeVerb>>

---@param category string the axis, e.g. "game"
---@param vfsMode string?
---@return table<string, ModeVerb> verbs by name
function ModuleHandler.ModeVerbs(category, vfsMode)
	if modeVerbsCache[category] then
		return modeVerbsCache[category]
	end
	local verbs = {} ---@type table<string, ModeVerb>
	local shippedBy = {} ---@type table<string, string>
	local names = {}
	for name in pairs(ModuleHandler.Discover(vfsMode)) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local filePath = ModuleHandler.Discover(vfsMode)[name].dir .. LAYOUT.modeVerbs
		if VFS.FileExists(filePath, vfsMode) then
			local fragment = VFS.Include(filePath, nil, vfsMode)
			if type(fragment) ~= "table" or type(fragment.category) ~= "string" or type(fragment.verbs) ~= "table" then
				error(
					filePath
						.. ": mode_verbs.lua must return { category = <axis>, verbs = { Name = ModeBuilder.Verb(...) } }"
				)
			end
			if fragment.category == category then
				for verbName, verb in pairs(fragment.verbs) do
					if shippedBy[verbName] then
						error(
							filePath
								.. ": verb "
								.. verbName
								.. " for axis "
								.. category
								.. " is already shipped by "
								.. shippedBy[verbName]
						)
					end
					shippedBy[verbName] = name
					verbs[verbName] = verb
				end
			end
		end
	end
	modeVerbsCache[category] = verbs
	return verbs
end

---@param vfsMode string?
---@return table<string, table<string, ModulePreset>> presets by category, by key
---@return table<string, boolean> modules that ship no presets: always live
function ModuleHandler.Presets(vfsMode)
	if presetsCache then
		return presetsCache.byCategory, presetsCache.alwaysLive
	end
	local manifests = ModuleHandler.Discover(vfsMode)
	local byCategory = {} ---@type table<string, table<string, ModulePreset>>
	local alwaysLive = {} ---@type table<string, boolean>
	for name, manifest in pairs(manifests) do
		local dir = manifest.dir .. LAYOUT.modes
		local files = VFS.DirList(dir, "*.lua", vfsMode)
		local shipped = false
		for _, filePath in ipairs(files) do
			local ok, mode = pcall(VFS.Include, filePath, nil, vfsMode)
			if ok and type(mode) == "table" and mode.key and mode.category then
				shipped = true
				byCategory[mode.category] = byCategory[mode.category] or {}
				byCategory[mode.category][mode.key] = {
					key = mode.key,
					category = mode.category,
					module = name,
					uses = mode.uses or {},
				}
			end
		end
		if not shipped then
			alwaysLive[name] = true
		end
	end
	presetsCache = { byCategory = byCategory, alwaysLive = alwaysLive }
	return byCategory, alwaysLive
end

---@param vfsMode string?
---@return table<string, string> category -> default preset key
local function defaultSelection(vfsMode)
	local defaults = {}
	for _, option in ipairs(ModuleHandler.ModOptions(vfsMode)) do
		local category = type(option.key) == "string" and option.key:match("^(.+)_mode$")
		if category and option.def ~= nil then
			defaults[category] = tostring(option.def)
		end
	end
	return defaults
end

---@param byCategory table<string, table<string, ModulePreset>>
---@param alwaysLive table<string, boolean>
---@param selection table<string, string> category -> preset key
---@return table<string, boolean>
function ModuleHandler.LiveModules(byCategory, alwaysLive, selection)
	local live = {}
	for name in pairs(alwaysLive) do
		live[name] = true
	end
	for category, presets in pairs(byCategory) do
		local preset = selection[category] and presets[selection[category]]
		if preset then
			live[preset.module] = true
			for _, used in ipairs(preset.uses) do
				live[used] = true
			end
		end
	end
	return live
end

---@param modOptions table<string, any>
---@param vfsMode string?
---@return table<string, boolean>
function ModuleHandler.LiveModulesFor(modOptions, vfsMode)
	local byCategory, alwaysLive = ModuleHandler.Presets(vfsMode)
	local selection = defaultSelection(vfsMode)
	for category in pairs(byCategory) do
		local picked = modOptions and modOptions[category .. "_mode"]
		if picked ~= nil then
			selection[category] = tostring(picked)
		end
	end
	return ModuleHandler.LiveModules(byCategory, alwaysLive, selection)
end

---@class ResolvedProvisions
---@field providers { op: PolicyProvision, module: string, file: string }[] every module's, in module order; the live set decides who answers
---@field defaults table<string, PolicyProvision> the owner's answer per declared slot
---@field slots string[]

---@param key string owner.category, for messages
---@param owner string the facts' module
---@param slots string[] the facts the contract declares
---@param list { module: string, ops: PolicyProvision[], file: string }[]
---@return ResolvedProvisions
function ModuleHandler.ResolveProvisions(key, owner, slots, list)
	local providers = {}
	local defaults = {} ---@type table<string, PolicyProvision>
	local defaultFile = {}
	local declared = {}
	for _, field in ipairs(slots) do
		declared[field] = true
	end
	for _, enrichment in ipairs(list) do
		for _, op in ipairs(enrichment.ops) do
			if op.default then
				local field = op.names[1]
				if enrichment.module ~= owner then
					error(enrichment.file .. ": only " .. owner .. " may Default " .. field .. " on " .. key)
				end
				if not declared[field] then
					error(enrichment.file .. ": " .. key .. " declares no slot named " .. field .. " to Default")
				end
				if defaults[field] then
					error(
						enrichment.file
							.. ": "
							.. field
							.. " on "
							.. key
							.. " already has a Default in "
							.. defaultFile[field]
					)
				end
				defaults[field] = op
				defaultFile[field] = enrichment.file
			else
				providers[#providers + 1] = { op = op, module = enrichment.module, file = enrichment.file }
			end
		end
	end
	local missing = {}
	for _, field in ipairs(slots) do
		if not defaults[field] then
			missing[#missing + 1] = field
		end
	end
	if #missing > 0 then
		table.sort(missing)
		error(
			key
				.. " declares "
				.. table.concat(missing, ", ")
				.. " without a Default; "
				.. owner
				.. " must say what the slot means when nobody provides it"
		)
	end
	return { providers = providers, defaults = defaults, slots = slots }
end

---@param byCategory table<string, table<string, ModulePreset>>
---@param alwaysLive table<string, boolean>
---@param providers { op: PolicyProvision, module: string, file: string }[]
---@return string[] conflicts, one line each; empty when the modes isolate every slot
function ModuleHandler.IsolationConflicts(byCategory, alwaysLive, providers)
	local categories = {}
	for category in pairs(byCategory) do
		categories[#categories + 1] = category
	end
	table.sort(categories)
	local conflicts = {}
	local function check(selection)
		local live = ModuleHandler.LiveModules(byCategory, alwaysLive, selection)
		local seen = {} ---@type table<string, string>
		for _, provider in ipairs(providers) do
			if live[provider.module] then
				for _, field in ipairs(provider.op.names) do
					if seen[field] and seen[field] ~= provider.file then
						local picks = {}
						for _, category in ipairs(categories) do
							picks[#picks + 1] = category .. "=" .. tostring(selection[category])
						end
						conflicts[#conflicts + 1] = field
							.. " is provided by both "
							.. seen[field]
							.. " and "
							.. provider.file
							.. " under "
							.. table.concat(picks, ", ")
					end
					seen[field] = seen[field] or provider.file
				end
			end
		end
	end
	local function walk(i, selection)
		if i > #categories then
			return check(selection)
		end
		local category = categories[i]
		for key in pairs(byCategory[category]) do
			selection[category] = key
			walk(i + 1, selection)
		end
		selection[category] = nil
	end
	walk(1, {})
	table.sort(conflicts)
	return conflicts
end

---@param owner string
---@param category string
---@param vfsMode string?
---@return ResolvedProvisions
function ModuleHandler.LoadEnrichers(facts, vfsMode)
	local identity = PolicyBuilder.IdentityOf(facts)
	assert(identity and identity.facts, "LoadEnrichers(facts): expects a Facts table from a module's contract.lua")
	local owner, category = identity.owner, identity.category
	local key = owner .. "." .. category
	if enrichersCache[key] then
		return enrichersCache[key]
	end
	local list = (loadPolicyFiles(vfsMode).enrichments[owner] or {})[category] or {}
	table.sort(list, function(a, b)
		return a.module < b.module
	end)
	local slots = (loadPolicyFiles(vfsMode).facts[owner] or {})[category] or {}
	local resolved = ModuleHandler.ResolveProvisions(key, owner, slots, list)
	local byCategory, alwaysLive = ModuleHandler.Presets(vfsMode)
	local conflicts = ModuleHandler.IsolationConflicts(byCategory, alwaysLive, resolved.providers)
	if #conflicts > 0 then
		error(key .. ": a mode leaves two providers live for one fact\n" .. table.concat(conflicts, "\n"))
	end
	enrichersCache[key] = resolved
	return resolved
end

---@param resolved ResolvedProvisions|PolicyProvision[] a flat list is a test seam: every entry live, no defaults
---@param live table<string, boolean>|nil nil means every provider is live
---@param ctx table
---@param ... any extra producer arguments
---@return table<string, any>
function ModuleHandler.EnrichWith(resolved, live, ctx, ...)
	local out = {}
	local answeredBy = {} ---@type table<string, string>
	local providers = resolved.providers
	if providers == nil then
		providers = {}
		for i, op in ipairs(resolved) do
			providers[i] = { op = op, module = "?", file = "seam" }
		end
	end
	for _, provider in ipairs(providers) do
		if live == nil or live[provider.module] then
			local results = { provider.op.evaluate(ctx, ...) }
			for i, field in ipairs(provider.op.names) do
				if results[i] ~= nil then
					if answeredBy[field] and answeredBy[field] ~= provider.file then
						error(
							field
								.. " answered by both "
								.. answeredBy[field]
								.. " and "
								.. provider.file
								.. " in one ask: the mode leaves both live"
						)
					end
					answeredBy[field] = provider.file
					out[field] = results[i]
				end
			end
		end
	end
	for _, field in ipairs(resolved.slots or {}) do
		if out[field] == nil and resolved.defaults and resolved.defaults[field] then
			out[field] = resolved.defaults[field].evaluate(ctx, ...)
		end
	end
	return out
end

---@param facts table the Facts table from the owner's contract.lua
---@param modOptions table<string, any>
---@param ctx table
---@param ... any extra producer arguments
---@return table<string, any>
function ModuleHandler.Enrich(facts, modOptions, ctx, ...)
	local resolved = ModuleHandler.LoadEnrichers(facts)
	return ModuleHandler.EnrichWith(resolved, ModuleHandler.LiveModulesFor(modOptions), ctx, ...)
end

---@param policies AssembledPipeline
---@param ctx table
---@param ... any
---@return any
function ModuleHandler.Evaluate(policies, ctx, ...)
	if policies.result == "fold" then
		for _, policy in ipairs(policies) do
			policy.evaluate(ctx, ...)
		end
		return ctx
	end
	if policies.result == "product" then
		local product = nil
		for _, policy in ipairs(policies) do
			local factor = policy.evaluate(ctx, ...)
			if factor ~= nil then
				product = (product or 1) * factor
			end
		end
		if product == nil then
			local last = policies[#policies]
			error(
				(last and last.category or "?")
					.. ": no stage gave a factor; the owner's "
					.. (last and last.name or "?")
					.. " must"
			)
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
	return policies.refusal ~= nil and policies.refusal(ctx, ...) or false
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
	presetsCache = nil
	modeVerbsCache = {}
	actionsCache = {}
	policiesCache = {}
	enrichersCache = {}
	policyFiles = nil
end

root.__moduleHandler = ModuleHandler
return ModuleHandler
