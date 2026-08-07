--- Fluent builder that emits ModeConfigs — no runtime of its own.
---
--- The canonical mode format is the preset file (see types/modules.lua):
--- modules/<name>/modes/<key>.lua returns a ModeConfig — a surrogate mode;
--- ModuleHandler.ModeDirs aggregates the preset dirs. Grammar() binds a
--- module's vocabulary — nouns carrying domains, verbs mapping nouns to policy
--- refs, serializers keyed by policy identity — and returns the Mode chain
--- entry those files read as:
---
---   Mode("Scripted")
---       .Desc("Triggers own the verdict.")
---       .Own(Match.End)
---
--- The chain IS the ModeConfig: dot-only, closure-free authoring; every verb
--- returns the chain; modifiers apply to the most recent policy; modOptions
--- stay re-derived from the policy bundle after every step, so consumers read
--- a plain preset table. Structural choices lock by default (.Unlocked()
--- opens them); numeric dials stay host-tunable (.Locked() pins them).

local ModeBuilder = {}

---Serialize a policy bundle through a serializer registry. Each policy
---serializes only the options it owns — a second owner is an error.
---@param serializers table<string, fun(params: table, lock: { structure: boolean, dial: boolean }): table<string, ModOptionConfig>>
---@param bundle ModePolicyRef[]
---@return table<string, ModOptionConfig>
function ModeBuilder.ToModOptions(serializers, bundle)
	local options = {}
	for _, entry in ipairs(bundle) do
		local name, params
		if type(entry) == "table" then
			name, params = entry[1], entry
		else
			name, params = entry, {}
		end
		local serialize = serializers[name]
		if not serialize then
			error("unknown mode policy: " .. tostring(name))
		end
		local lock = { structure = params.locked ~= false, dial = params.locked == true }
		for key, option in pairs(serialize(params, lock)) do
			if options[key] ~= nil then
				error("two policies own modoption " .. key)
			end
			options[key] = option
		end
	end
	return options
end

---Domain guard for vocabulary verbs.
---@param modeName string for error messages
---@param verb string
---@param noun table
---@param domains table<string, boolean> domains the verb accepts
---@param hint string noun spelling for the error message
---@return string domain
function ModeBuilder.DomainOf(modeName, verb, noun, domains, hint)
	assert(type(noun) == "table" and type(noun.domain) == "string",
		modeName .. ": ." .. verb .. " expects a noun (" .. hint .. ")")
	assert(domains[noun.domain], modeName .. ": ." .. verb .. " does not apply to " .. noun.domain)
	return noun.domain
end

---Bind a module's vocabulary; returns the Mode chain entry for its preset files.
---Verbs receive (modeName, ...) and return a policy ref { "<identity>", ... }.
---@param grammar { category: string, serializers: table, verbs: table<string, fun(modeName: string, ...): table> }
---@return fun(name: string): ModeConfig
function ModeBuilder.Grammar(grammar)
	---Start a mode chain; the key is the name's snake_case.
	---@param name string
	---@return ModeConfig
	return function(name)
		local chain = {
			key = name:lower():gsub("%s+", "_"),
			category = grammar.category,
			name = name,
			desc = "",
			allowRanked = false,
			policies = {}, ---@type ModePolicyRef[]
			modOptions = {}, ---@type table<string, ModOptionConfig>
		}

		local function reserialize()
			chain.modOptions = ModeBuilder.ToModOptions(grammar.serializers, chain.policies)
			return chain
		end

		---@param modifier string
		---@return table ref the most recent policy ref
		local function lastPolicy(modifier)
			local ref = chain.policies[#chain.policies]
			assert(ref, name .. ": ." .. modifier .. " before any policy")
			return ref
		end

		---@param desc string
		chain.Desc = function(desc)
			chain.desc = desc
			return chain
		end

		---Allowed in ranked games.
		chain.Ranked = function()
			chain.allowRanked = true
			return chain
		end

		---Non-sticky preset: entries expose/unlock options, current values are kept.
		chain.RetainValues = function()
			chain.retainValues = true
			return chain
		end

		---The most recent policy's option stays out of the lobby UI.
		chain.Hidden = function()
			lastPolicy("Hidden").ui = "hidden"
			return reserialize()
		end

		---The most recent policy unlocks entirely (structure and dials).
		chain.Unlocked = function()
			lastPolicy("Unlocked").locked = false
			return reserialize()
		end

		---The most recent policy locks entirely, dials included.
		chain.Locked = function()
			lastPolicy("Locked").locked = true
			return reserialize()
		end

		for verbName, toRef in pairs(grammar.verbs) do
			assert(chain[verbName] == nil, "ModeBuilder.Grammar: verb collides with a chain field: " .. verbName)
			chain[verbName] = function(...)
				chain.policies[#chain.policies + 1] = toRef(name, ...)
				return reserialize()
			end
		end

		-- Chain verbs say something about the PRESET rather than about a
		-- policy: not "pin this option" but "a game in this mode also needs
		-- that". They write on the chain directly and serialize nothing.
		for verbName, apply in pairs(grammar.chainVerbs or {}) do
			assert(chain[verbName] == nil, "ModeBuilder.Grammar: chain verb collides with a chain field: " .. verbName)
			chain[verbName] = function(...)
				apply(chain, name, ...)
				return chain
			end
		end

		return chain
	end
end

return ModeBuilder
