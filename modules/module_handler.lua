local root = GG or WG or _G
if root.__moduleHandler then
	return root.__moduleHandler
end

local LOG_TAG = "module_handler.lua"

local Policy = require("modules/policy")

local MODULES_DIR = "modules/"

-- The engine runs Lua in handles, and every handle is synced or unsynced: LuaRules and LuaGaia are a pair, one of
-- each; LuaUI is unsynced. Some Spring functions exist in one kind of handle only, so a module file says by its
-- name and place which kind it runs in:
--   synced:    api_synced.lua, synced.lua
--   unsynced:  api_unsynced.lua, unsynced.lua, widgets/, rml_widgets/
--   both:      gadgets/, each saying for itself which half is which
--   any:       api.lua, policies/, lib/ and every other file, so they call only what every handle offers
-- units/ and modoptions.lua are not handle code: a LuaParser state reads them, with no Spring in it.
-- A file requires nothing declared for the other handle, and a file for any handle requires only files for any.
-- The loader cannot see a require, so it does not enforce this at run time; spec/modules/handles_spec.lua does.
local LAYOUT = {
	manifest = "manifest.lua",
	widgets = "widgets/",
	rmlWidgets = "rml_widgets/",
	gadgets = "gadgets/",
	scripts = "scripts/",
	units = "units/",
	language = "language/",
	tests = "tests/",
	policies = "policies/",
	modOptions = "modoptions.lua",
}

--- @class ModuleHandler
local ModuleHandler = {}

---@param message string
local function logError(message)
	---@diagnostic disable-next-line: unnecessary-if -- Recoil.Shared IS nil in lobby LuaParser; the analyzer can't know
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
			for _, reqMod in ipairs(manifests[name].requires or {}) do
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
---@return string[] the modules' unit def directories, read after units/
function ModuleHandler.UnitDefDirs(vfsMode)
	return moduleSubdirs(LAYOUT.units, vfsMode)
end

---@param vfsMode string?
---@return string[] the modules' language directories, each holding a directory per language code as language/ does
function ModuleHandler.LanguageDirs(vfsMode)
	return moduleSubdirs(LAYOUT.language, vfsMode)
end

---@param vfsMode string?
---@return string[] the modules' headless test directories
function ModuleHandler.TestDirs(vfsMode)
	return moduleSubdirs(LAYOUT.tests, vfsMode)
end

---@param vfsMode string?
---@return string[]
function ModuleHandler.GadgetDirs(vfsMode)
	return moduleSubdirs(LAYOUT.gadgets, vfsMode)
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

local policiesCache = {}
---@class PolicyLoad every module's policies, read once
---@field chains table<string, table<string, LoadedChain[]>> by the target's owner and category
---@field enrichments table<string, table<string, LoadedEnrichment[]>> by the facts' owner and category
---@field facts table<string, table<string, string[]>> facts[owner][category] = declared names
---@field contributions table<string, table<string, { module: string, names: string[] }[]>> by the TARGET's owner and category
---@field contracts table<string, table|nil> each module's contract: what its policy files return, one table
---@field manifests table<string, ModuleManifest>
---@field vfsMode string|nil
---@field stack string[] the modules being loaded, innermost last

local policyFiles = nil ---@type PolicyLoad|nil
local policyLoad = nil ---@type PolicyLoad|nil the load in progress, so a policy file can ask for another module's contract

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
---@param contract table what a policy file returned: the policies and facts it declares
---@param facts table<string, table<string, string[]>> facts[owner][category] = declared names
---@param contributions table<string, table<string, { module: string, names: string[] }[]>> keyed by the TARGET's owner and category
local function indexContract(name, contract, facts, contributions)
	for _, declared in pairs(contract) do
		local identity = Policy.IdentityOf(declared)
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
---@field identity PolicyIdentity the policy it builds against
---@field steps table the target's step enum
---@field ops PolicyOp[]
---@field file string

---@class LoadedEnrichment
---@field module string
---@field identity PolicyIdentity the facts it provides for
---@field ops PolicyProvision[]
---@field file string

local loadModulePolicies ---@type fun(load: PolicyLoad, name: string): table

---@param load PolicyLoad
---@param name string module name
---@param source string the file, for messages
---@param run fun(facade: table): any hands the registrar to the source
---@param onReturned fun(returned: table)|nil what to do with a table the source returns; without it a returned value is an error
---@return LoadedChain[] chains, LoadedEnrichment[] enrichments
local function collectPolicies(load, name, source, run, onReturned)
	local filePath = source
	local built = {} ---@type { kind: "policy"|"enrichment", chain: table }[]
	local facade = {
		On = function(target)
			if Policy.IsFacts(target) then
				error(filePath .. ": Policies.On opens a policy's steps; facts are opened with Policies.For")
			end
			local chain = Policy.Chain(target)
			built[#built + 1] = { kind = "policy", chain = chain }
			return chain
		end,
		For = function(facts)
			if not Policy.IsFacts(facts) then
				error(
					filePath .. ": Policies.For opens a contract's facts; a policy's steps are opened with Policies.On"
				)
			end
			local chain = Policy.Enrichment(facts)
			built[#built + 1] = { kind = "enrichment", chain = chain }
			return chain
		end,
		Contract = function(moduleName)
			return loadModulePolicies(load, moduleName)
		end,
	}
	local returned = run(facade)
	if returned ~= nil then
		if onReturned == nil or type(returned) ~= "table" then
			error(
				filePath
					.. ": returns "
					.. type(returned)
					.. "; a policy file returns the steps it declares, or nothing"
			)
		end
		onReturned(returned)
	end
	if #built == 0 and returned == nil then
		error(filePath .. ": builds no policy and no enrichment")
	end
	local chains, enrichments = {}, {}
	for _, entry in ipairs(built) do
		local chain = entry.chain
		if entry.kind == "policy" then
			local identity = Policy.IdentityOf(chain.steps)
			if identity and identity.contributes then
				identity = identity.contributes
			end
			if identity == nil then
				error(
					filePath
						.. ": Policies.On needs a policy's steps or a contract's facts: declared by this file and returned, or another module's through Policies.Contract"
				)
			end
			if identity.facts then
				error(filePath .. ": " .. identity.category .. " is facts, not a policy")
			end
			local ops = chain.Build()
			if #ops == 0 then
				error(filePath .. ": an empty chain")
			end
			chains[#chains + 1] =
				{ module = name, identity = identity, steps = chain.steps, ops = ops, file = filePath }
		else
			local identity = Policy.IdentityOf(chain.facts)
			if identity == nil or not identity.facts then
				error(
					filePath
						.. ": Policies.On needs a policy's steps or a contract's facts: declared by this file and returned, or another module's through Policies.Contract"
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

---@param load PolicyLoad
---@param chains LoadedChain[]
---@param enrichments LoadedEnrichment[]
local function keepPolicies(load, chains, enrichments)
	for _, chain in ipairs(chains) do
		local list = bucket(load.chains, chain.identity.owner, chain.identity.category)
		list[#list + 1] = chain
	end
	for _, enrichment in ipairs(enrichments) do
		local list = bucket(load.enrichments, enrichment.identity.owner, enrichment.identity.category)
		list[#list + 1] = enrichment
	end
end

---@param load PolicyLoad
---@param name string module name
---@return table contract
function loadModulePolicies(load, name)
	if load.contracts[name] then
		return load.contracts[name]
	end
	local manifest = load.manifests[name]
	if not manifest then
		error("Policies.Contract: no module named " .. tostring(name))
	end
	for depth, loading in ipairs(load.stack) do
		if loading == name then
			if depth == #load.stack then
				error(name .. ": a policy file asks for its own module's contract; declare the steps it needs")
			end
			error(table.concat(load.stack, " -> ", depth) .. " -> " .. name .. ": contracts that need each other")
		end
	end
	load.stack[#load.stack + 1] = name
	local contract = setmetatable({}, { __owner = name })
	local vfsMode = load.vfsMode

	---@param members table
	---@param file string
	local function declare(members, file)
		for member, declared in pairs(members) do
			if contract[member] ~= nil then
				error(file .. ": " .. name .. " already declares " .. tostring(member))
			end
			contract[member] = declared
		end
		indexContract(name, members, load.facts, load.contributions)
	end

	local files = VFS.DirList(manifest.dir .. LAYOUT.policies, "*.lua", vfsMode)
	table.sort(files)
	for _, filePath in ipairs(files) do
		local chains, enrichments = collectPolicies(load, name, filePath, function(facade)
			return includeRegistrationFile(filePath, { Policies = facade }, vfsMode)
		end, function(returned)
			Policy.Declare(name, returned, filePath)
			declare(returned, filePath)
		end)
		keepPolicies(load, chains, enrichments)
	end
	load.stack[#load.stack] = nil
	load.contracts[name] = contract
	return contract
end

---@param vfsMode string?
---@return PolicyLoad
local function loadPolicyFiles(vfsMode)
	if policyFiles then
		return policyFiles
	end
	if policyLoad then
		return policyLoad
	end
	local manifests = ModuleHandler.Manifests(vfsMode)
	local names = {}
	for name in pairs(manifests) do
		names[#names + 1] = name
	end
	table.sort(names)
	local load = {
		chains = {},
		enrichments = {},
		facts = {},
		contributions = {},
		contracts = {},
		manifests = manifests,
		vfsMode = vfsMode,
		stack = {},
	}
	policyLoad = load
	local ok, err = pcall(function()
		for _, name in ipairs(names) do
			loadModulePolicies(load, name)
		end
	end)
	policyLoad = nil
	if not ok then
		error(err, 0)
	end
	policyFiles = load
	return policyFiles
end

---@param name string a Modules entry (modules/enums.lua)
---@param vfsMode string?
---@return table the module's contract: what its policy files return, one table
function ModuleHandler.Contract(name, vfsMode)
	if policyLoad then
		return loadModulePolicies(policyLoad, name)
	end
	local contract = loadPolicyFiles(vfsMode).contracts[name]
	if not contract then
		error("ModuleHandler.Contract: no module named " .. tostring(name))
	end
	return contract
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

---@param names table<any, string> a contract's step enum, or a contribution's names
---@param landed table<string, boolean> the names on the assembled policy
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
---@return table<string, AssembledPolicy<any, any>> policies keyed by category, contributions applied
function ModuleHandler.LoadPolicies(name, vfsMode)
	if policiesCache[name] then
		return policiesCache[name]
	end
	local byCategory = {}
	for category, list in pairs(loadPolicyFiles(vfsMode).chains[name] or {}) do
		local first = list[1] --[[@as LoadedChain]]
		local ordered = {}
		for _, chain in ipairs(list) do
			if chain.module == name then
				ordered[#ordered + 1] = chain
			end
		end
		if #ordered == 0 then
			error(first.file .. ": " .. name .. " has no " .. category .. " policy of its own")
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
		---@type AssembledPolicy<any, any>
		local policy = {
			result = first.identity.result --[[@as PolicyResult]],
			shape = first.identity.shape,
		}
		for _, chain in ipairs(ordered) do
			local declared = {}
			if chain.module == name then
				for _, stageName in pairs(chain.steps) do
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
						.. " step to "
						.. name
						.. "."
						.. category
						.. " that no contract declares; "
						.. (
							chain.module == name and "name it in the policy's steps"
							or "declare it with Policy.Contributes in " .. chain.module .. "'s policies"
						)
				)
			end
			if chain.module ~= name then
				for _, op in ipairs(chain.ops) do
					if op.op == "refusal" then
						error(
							chain.file .. ": only " .. name .. " may shape the refusal of " .. name .. "." .. category
						)
					end
					if op.op == "form" then
						error(chain.file .. ": only " .. name .. " may form the context of " .. name .. "." .. category)
					end
				end
			end
			Policy.Assemble(policy, chain.ops, chain.file, chain.module ~= name)
		end
		for _, step in ipairs(policy) do
			step.category = category
		end
		Policy.Validate(policy, policy.result, name .. "." .. category)
		local landed = {}
		for _, step in ipairs(policy) do
			landed[step.name] = true
		end
		local unbuilt = ModuleHandler.UnbuiltStage(ordered[1].steps, landed)
		if unbuilt then
			error(
				ordered[1].file
					.. ": "
					.. name
					.. "'s contract declares a "
					.. unbuilt
					.. " step on "
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
						.. " step on "
						.. name
						.. "."
						.. category
						.. " but never builds it"
				)
			end
		end
		byCategory[category] = policy
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

---@generic C, T
---@param steps PolicySteps<C, T> a policy's step enum, from its owner's contract
---@param vfsMode string?
---@return AssembledPolicy<C, T>
function ModuleHandler.Steps(steps, vfsMode)
	local identity = Policy.IdentityOf(steps)
	assert(identity and not identity.facts, "ModuleHandler.Steps(steps): expects a policy's steps, from a contract")
	local policy = ModuleHandler.LoadPolicies(identity.owner, vfsMode)[identity.category]
	if policy == nil then
		error(identity.owner .. " builds no " .. identity.category .. " policy")
	end
	return policy
end

---@generic C, T
---@param policies PolicySteps<C, T>|AssembledPolicy<C, T> the policy's steps, or the policy the loader assembled from them
---@param ctx C
---@return T
function ModuleHandler.Evaluate(policies, ctx)
	local assembled = (
		Policy.IdentityOf(policies) ~= nil and ModuleHandler.Steps(policies --[[@as PolicySteps<any, any>]])
		or policies
	) --[[@as AssembledPolicy<any, any>]]
	if assembled.result == "fold" then
		for _, policy in ipairs(assembled) do
			policy.evaluate(ctx)
		end
		return ctx
	end
	if assembled.result == "product" then
		local product = nil
		for _, policy in ipairs(assembled) do
			local factor = policy.evaluate(ctx)
			if factor ~= nil then
				product = (product or 1) * factor
			end
		end
		if product == nil then
			local last = assembled[#assembled]
			error(
				(last and last.category or "?")
					.. ": no step gave a factor; the owner's "
					.. (last and last.name or "?")
					.. " must"
			)
		end
		return product
	end
	for _, policy in ipairs(assembled) do
		if policy.kind == "unless" then
			if policy.evaluate(ctx) then
				return assembled.refusal ~= nil and assembled.refusal(ctx) or false
			end
		elseif policy.kind == "if" then
			if not policy.evaluate(ctx) then
				return assembled.refusal ~= nil and assembled.refusal(ctx) or false
			end
		else
			local result = policy.evaluate(ctx)
			if result ~= nil then
				if assembled.shape ~= nil then
					Policy.CheckShape(assembled.shape, result, policy)
				end
				return result
			end
		end
	end
	return assembled.refusal ~= nil and assembled.refusal(ctx) or false
end

-- A policy asked by key: the owner's FormContext makes the context, Evaluate answers, and the answer is kept for the frame
-- it was made on. Every ask of the same key on the same frame is a lookup; the first ask of a new frame forms the
-- context again, into the same table, and evaluates once. One store per engine (or spec stand-in); the frame is its
-- clock. Entries nobody asked about for a while are swept. The key is the ask's arguments after the engine, in the
-- order the form's own parameters name them.
---@type table<Recoil.Shared, table> the engine -> { sweptAt, depth = { [AssembledPolicy] = key length }, [AssembledPolicy] = a tree keyed by the key's values, entries at the leaves }
local asked = setmetatable({}, { __mode = "k" })
local SWEEP_EVERY = 1800 -- frames between sweeps: a minute
local KEEP_FOR = 300 -- an entry not asked about for this many frames is dropped at the next sweep

---@param node table a tree node, or an entry when depth is 0
---@param depth integer how many key fields remain below this node
---@param cutoff number the frame before which an entry is stale
---@return boolean empty whether the node holds nothing any more
local function prune(node, depth, cutoff)
	if depth == 0 then
		return node.frame == nil or node.frame < cutoff
	end
	local empty = true
	for value, child in pairs(node) do
		if prune(child, depth - 1, cutoff) then
			node[value] = nil
		else
			empty = false
		end
	end
	return empty
end

---@param store table the engine's store
---@param frame number
local function sweep(store, frame)
	if frame - store.sweptAt < SWEEP_EVERY then
		return
	end
	store.sweptAt = frame
	local cutoff = frame - KEEP_FOR
	for policy, depth in pairs(store.depth) do
		if store[policy] ~= nil and prune(store[policy], depth, cutoff) then
			store[policy] = nil
			store.depth[policy] = nil
		end
	end
end

---@param policies table a policy's steps, or the assembled policy
---@return AssembledPolicy<any, any>
local function formed(policies)
	local policy = (
		Policy.IdentityOf(policies) ~= nil and ModuleHandler.Steps(policies --[[@as PolicySteps<any, any>]])
		or policies
	) --[[@as AssembledPolicy<any, any>]]
	if policy.form == nil then
		local last = policy[#policy]
		error(
			(last and last.category or "?")
				.. ": the owner declared no FormContext; a policy is Asked by key only with one"
		)
	end
	return policy
end

---@param policy AssembledPolicy<any, any>
---@param n integer how many key arguments the ask gave
local function checkArity(policy, n)
	if policy.arity ~= nil and n ~= policy.arity then
		error(
			(policy[#policy].category or "?")
				.. ": asked with "
				.. n
				.. " key argument"
				.. (n == 1 and "" or "s")
				.. "; its FormContext takes "
				.. policy.arity
		)
	end
end

---@param policy AssembledPolicy<any, any>
---@param spring Recoil.Shared
---@param create boolean make the path when it is not there
---@param ... any the key
---@return table|nil entry the leaf for that key
---@return table store the engine's store
local function entryFor(policy, spring, create, ...)
	local n = select("#", ...) --[[@as integer]]
	checkArity(policy, n)
	local store = asked[spring]
	if store == nil then
		if not create then
			return nil, {}
		end
		store = { sweptAt = 0, depth = {} }
		asked[spring] = store
	end
	local node = store[policy]
	if node == nil then
		if not create then
			return nil, store
		end
		node = {}
		store[policy] = node
		store.depth[policy] = n
	end
	for i = 1, n do
		local value = select(i, ...)
		if value == nil then
			error((policy[#policy].category or "?") .. ": asked with nil for key argument " .. i)
		end
		local child = node[value]
		if child == nil then
			if not create then
				return nil, store
			end
			child = {}
			node[value] = child
		end
		node = child
	end
	return node, store
end

---@generic C, T
---@param policies PolicySteps<C, T>|AssembledPolicy<C, T> the policy's steps, or the policy the loader assembled from them
---@param spring Recoil.Shared the engine, or a spec's stand-in: the store is per engine and its frame is the clock
---@param ... any the key, in the order the owner's form names it after ctx and spring
---@return T the answer for this frame: formed and evaluated on the frame's first ask, looked up after
function ModuleHandler.Ask(policies, spring, ...)
	local policy = formed(policies)
	local frame = spring.GetGameFrame()
	local entry, store = entryFor(policy, spring, true, ...)
	---@cast entry table
	if entry.frame ~= frame then
		local ctx = entry.ctx
		if ctx == nil then
			ctx = {}
			entry.ctx = ctx
		end
		entry.ctx = (policy.form --[[@as function]])(ctx, spring, ...) or ctx
		entry.answer = ModuleHandler.Evaluate(policy, entry.ctx)
		entry.frame = frame
		sweep(store, frame)
	end
	return entry.answer
end

-- The frame's answer for a key, dropped: the next Ask forms and evaluates again. For the one writer whose move
-- changes what the policy reads within the frame.
---@param policies table the policy's steps, or the assembled policy
---@param spring Recoil.Shared
---@param ... any the key
function ModuleHandler.Forget(policies, spring, ...)
	local entry = entryFor(formed(policies), spring, false, ...)
	if entry ~= nil then
		entry.frame = nil
	end
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
	policiesCache = {}
	policyFiles = nil
	asked = setmetatable({}, { __mode = "k" })
end

root.__moduleHandler = ModuleHandler
return ModuleHandler
