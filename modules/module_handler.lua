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
	actions = "actions/",
	policies = "policies/",
	modOptions = "modoptions.lua",
}

--- @class ModuleHandler
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
	-- strip trailing slashes
	local noSlash = dir:gsub("/+$", "")
	-- last path segment, "modules/<name>/" -> "<name>"
	return noSlash:match("([^/]+)$") --[[@as string]]
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
local function sortedKeysCopy(t)
	local keys = {}
	for key in pairs(t) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
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

local registered = nil ---@type table<string, ModuleManifest>|nil

---Reads every manifest under modules/ and decides which modules are in: a manifest that names its directory,
---whose requirements are all in. Each Lua state that loads module code (gadgets, widgets, unit scripts) calls
---this once as it initialises; the result is what the rest of the handler serves.
---@param vfsMode string?
---@return table<string, ModuleManifest> the registered modules' manifests, keyed by module name
function ModuleHandler.Register(vfsMode)
	local manifests = {}
	for _, moduleDir in ipairs(VFS.SubDirs(MODULES_DIR, "*", vfsMode)) do
		local manifest = loadManifest(ensureSlash(moduleDir), vfsMode)
		if manifest then
			manifests[manifest.name] = manifest
		end
	end
	registered = ModuleHandler.Resolve(manifests, logError)
	return registered
end

---@param vfsMode string?
---@return table<string, ModuleManifest> the registered modules' manifests; registers first when no entry point has yet (defs, modoptions and the lobby read the handler without one)
function ModuleHandler.Manifests(vfsMode)
	return registered or ModuleHandler.Register(vfsMode)
end

---@param manifests table<string, ModuleManifest> discovered, keyed by name
---@param onLoadFailed fun(message: string) called once per module that will not load, with the reason
---@return table<string, ModuleManifest> manifests of the modules whose requirements are met
function ModuleHandler.Resolve(manifests, onLoadFailed)
	---@type table<string, string|false> the error for each module that will not load; false when it will
	local errors = {}

	---@param name string
	---@return string|false errorMessage
	local function loadFailureFor(name)
		if errors[name] == nil then
			-- marked before descending so a requires-cycle terminates; its members stay loadable
			errors[name] = false
			for _, reqMod in ipairs(manifests[name].requires) do
				if not manifests[reqMod] then
					errors[name] = string.format("Module %q requires missing module %q; not loaded", name, reqMod)
					break
				elseif loadFailureFor(reqMod) then
					errors[name] = string.format("Module %q requires %q, which is not loaded", name, reqMod)
					break
				end
			end
		end
		return errors[name]
	end

	local loadable = {}
	for _, name in ipairs(sortedKeysCopy(manifests)) do
		local errorMessage = loadFailureFor(name)
		if errorMessage then
			onLoadFailed(errorMessage)
		else
			loadable[name] = manifests[name]
		end
	end
	return loadable
end

---@param subdir string e.g. "widgets/"
---@param vfsMode string?
---@return string[] dirs
local function moduleSubdirs(subdir, vfsMode)
	local dirs = {}
	for _, manifest in pairs(ModuleHandler.Manifests(vfsMode)) do
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
	local manifest = ModuleHandler.Manifests(vfsMode)[name]
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
	local manifests = ModuleHandler.Manifests(vfsMode)
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

---Per-module scratch table, created on first use and shared by everything in the same Lua state.
---@param name string a Modules entry (modules/enums.lua)
---@return table state
function ModuleHandler.State(name)
	local root = GG or WG or _G
	root.__moduleState = root.__moduleState or {}
	root.__moduleState[name] = root.__moduleState[name] or {}
	return root.__moduleState[name]
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
---@return table[] options modoptions.lua entries ({ key, name, type, def, ... }) from every module, in module name order
function ModuleHandler.ModOptions(vfsMode)
	local manifests = ModuleHandler.Manifests(vfsMode)

	local options = {}
	for _, name in ipairs(sortedKeysCopy(manifests)) do
		local modOptionsPath = manifests[name].dir .. LAYOUT.modOptions
		if VFS.FileExists(modOptionsPath, vfsMode) then
			local moduleOptions = VFS.Include(modOptionsPath, nil, vfsMode)
			if type(moduleOptions) ~= "table" then
				logError("Module modoptions file must return a list: " .. modOptionsPath)
			else
				for _, option in ipairs(moduleOptions) do
					options[#options + 1] = option
				end
			end
		end
	end
	return options
end

function ModuleHandler.ResetCaches()
	registered = nil
	actionsCache = {}
	policiesCache = {}
	policyFiles = nil
end

root.__moduleHandler = ModuleHandler
return ModuleHandler
