local PolicyBuilder = VFS.Include("modules/policy_builder.lua")

---@class ModOptionConfig
---@field value string|number|boolean
---@field locked boolean
---@field ui "hidden"|nil kept out of the lobby UI when hidden

---@alias ModeLock

---@class ModeVerb a preset verb: how to read what the preset wrote, and how to write the modoptions it claims
---@field parse fun(modeName: string, ...): table the claim's parameters, checked
---@field write fun(params: table, lock: { noun: boolean, dial: boolean }): table<string, ModOptionConfig>

---@class ModePolicyRef one claim a preset made: the verb's parameters, carrying the verb's writer
---@field verb string the verb's name, for error messages
---@field write fun(params: table, lock: { noun: boolean, dial: boolean }): table<string, ModOptionConfig>
---@field lock ModeLock|nil nil is open
---@field ui string|nil
---@field implicit boolean|nil added by the builder, not said by the preset

---@class ModeConfig
---@field key string the name's snake_case
---@field category string bound by the grammar, never by the preset
---@field name string
---@field desc string
---@field allowRanked boolean
---@field retainValues boolean|nil non-sticky preset: expose, keep current values
---@field bots string[]|nil AI short names the lobby fields
---@field uses string[]|nil modules this preset makes live besides its own
---@field policies ModePolicyRef[]
---@field modOptions table<string, ModOptionConfig>

local ModeBuilder = {}

---@param parse fun(modeName: string, ...): table
---@param write fun(params: table, lock: { noun: boolean, dial: boolean }): table<string, ModOptionConfig>
---@return ModeVerb
function ModeBuilder.Verb(parse, write)
	assert(type(parse) == "function" and type(write) == "function", "ModeBuilder.Verb(parse, write)")
	return { parse = parse, write = write }
end

---@param ... table<string, ModeVerb>
---@return table<string, ModeVerb>
function ModeBuilder.Verbs(...)
	local merged = {}
	for _, verbs in ipairs({ ... }) do
		for name, verb in pairs(verbs) do
			assert(merged[name] == nil, "ModeBuilder.Verbs: two modules ship a verb named " .. name)
			merged[name] = verb
		end
	end
	return merged
end

---@param modeName string
---@param verb string
---@param enum table<string, string>
---@param value any
function ModeBuilder.OneOf(modeName, verb, enum, value)
	for _, allowed in pairs(enum) do
		if value == allowed then
			return
		end
	end
	local keys = {}
	for name in pairs(enum) do
		keys[#keys + 1] = name
	end
	table.sort(keys)
	error(
		modeName
			.. ": ."
			.. verb
			.. " expects one of "
			.. verb
			.. "Mode."
			.. table.concat(keys, ", " .. verb .. "Mode.")
	)
end

local RANKED = ModeBuilder.Verb(function()
	return {}
end, function(_p, lock)
	return { ranked_game = { value = false, locked = lock.noun } }
end)

---@param bundle ModePolicyRef[]
---@return table<string, ModOptionConfig>
function ModeBuilder.ToModOptions(bundle)
	local options = {}
	for _, ref in ipairs(bundle) do
		assert(
			type(ref) == "table" and type(ref.write) == "function",
			"a claim with no verb behind it: " .. tostring(ref.verb or ref)
		)
		local level = ref.lock
		local lock = { noun = level == "locked" or level == "sealed", dial = level == "sealed" }
		for key, option in pairs(ref.write(ref, lock)) do
			if options[key] ~= nil then
				error("two claims own modoption " .. key)
			end
			options[key] = option
		end
	end
	return options
end

---@param modeName string for error messages
---@param verb string
---@param noun table
---@param domains table<string, boolean> domains the verb accepts
---@param hint string noun spelling for the error message
---@return string domain
function ModeBuilder.DomainOf(modeName, verb, noun, domains, hint)
	assert(
		type(noun) == "table" and type(noun.domain) == "string",
		modeName .. ": ." .. verb .. " expects a noun (" .. hint .. ")"
	)
	assert(domains[noun.domain], modeName .. ": ." .. verb .. " does not apply to " .. noun.domain)
	return noun.domain
end

---@param grammar { category: string, verbs: table<string, ModeVerb>, chainVerbs: table|nil }
---@return fun(name: string): ModeConfig
function ModeBuilder.Grammar(grammar)
	---@param name string
	---@return ModeConfig
	return function(name)
		local chain = {
			key = name:lower():gsub("%s+", "_"),
			category = grammar.category,
			name = name,
			desc = "",
			allowRanked = false,
			policies = { { verb = "Ranked", write = RANKED.write, implicit = true } }, ---@type ModePolicyRef[]
			modOptions = {}, ---@type table<string, ModOptionConfig>
		}

		local function reserialize()
			chain.modOptions = ModeBuilder.ToModOptions(chain.policies)
			return chain
		end

		---@param modifier string
		---@return table ref the most recent policy ref
		local function lastPolicy(modifier)
			local ref = chain.policies[#chain.policies]
			assert(ref and not ref.implicit, name .. ": ." .. modifier .. " before any policy")
			return ref
		end

		---@param desc string
		chain.Desc = function(desc)
			chain.desc = desc
			return chain
		end

		---@param enabled boolean|nil nil means true
		chain.Ranked = function(enabled)
			enabled = enabled ~= false
			chain.allowRanked = enabled
			for i = #chain.policies, 1, -1 do
				if chain.policies[i].write == RANKED.write then
					table.remove(chain.policies, i)
				end
			end
			if not enabled then
				chain.policies[#chain.policies + 1] = { verb = "Ranked", write = RANKED.write }
			end
			return reserialize()
		end

		---@param aiName string
		chain.Bot = function(aiName)
			assert(type(aiName) == "string", "Mode(...).Bot expects an AI short name")
			chain.bots = chain.bots or {}
			chain.bots[#chain.bots + 1] = aiName
			return chain
		end

		---@param contract table the module's contract.lua
		chain.Uses = function(contract)
			local moduleName = PolicyBuilder.OwnerOf(contract)
			assert(moduleName ~= nil, name .. ": .Uses expects a module's contract (VFS.Include its contract.lua)")
			chain.uses = chain.uses or {}
			chain.uses[#chain.uses + 1] = moduleName
			return chain
		end

		chain.RetainValues = function()
			chain.retainValues = true
			return chain
		end

		chain.Hidden = function()
			lastPolicy("Hidden").ui = "hidden"
			return reserialize()
		end

		chain.Unlocked = function()
			lastPolicy("Unlocked").lock = "open"
			return reserialize()
		end

		chain.Locked = function()
			lastPolicy("Locked").lock = "locked"
			return reserialize()
		end

		chain.Sealed = function()
			lastPolicy("Sealed").lock = "sealed"
			return reserialize()
		end

		for verbName, verb in pairs(grammar.verbs) do
			assert(chain[verbName] == nil, "ModeBuilder.Grammar: verb collides with a chain field: " .. verbName)
			assert(
				type(verb) == "table" and verb.parse and verb.write,
				"ModeBuilder.Grammar: " .. verbName .. " is not a ModeBuilder.Verb"
			)
			chain[verbName] = function(...)
				local ref = verb.parse(name, ...)
				ref.verb = verbName
				ref.write = verb.write
				chain.policies[#chain.policies + 1] = ref
				return reserialize()
			end
		end

		for verbName, apply in pairs(grammar.chainVerbs or {}) do
			assert(chain[verbName] == nil, "ModeBuilder.Grammar: chain verb collides with a chain field: " .. verbName)
			chain[verbName] = function(...)
				apply(chain, name, ...)
				return chain
			end
		end

		return reserialize()
	end
end

return ModeBuilder
