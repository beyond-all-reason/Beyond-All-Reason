local PolicyBuilder = VFS.Include("modules/policy_builder.lua")

---@class ModOptionConfig
---@field value string|number|boolean
---@field locked boolean
---@field ui "hidden"|nil kept out of the lobby UI when hidden

---@class ModePolicyRef
---@field [1] string policy identity, e.g. "end.scripted"
---@field locked boolean|"sealed"|nil nil/false = open, true = structure pinned, "sealed" = dials too
---@field ui string|nil

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

local BuiltinSerializers = {
	-- ranked prohibition is enforced, not advisory: the option is pinned off
	["mode.ranked"] = function(_p, lock)
		return { ranked_game = { value = false, locked = lock.structure } }
	end,
}

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
		local serialize = serializers[name] or BuiltinSerializers[name]
		if not serialize then
			error("unknown mode policy: " .. tostring(name))
		end
		local locked = params.locked
		local lock = { structure = locked == true or locked == "sealed", dial = locked == "sealed" }
		for key, option in pairs(serialize(params, lock)) do
			if options[key] ~= nil then
				error("two policies own modoption " .. key)
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

---@param grammar { category: string, serializers: table, verbs: table<string, fun(modeName: string, ...): table> }
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
			-- Unranked until a preset says Ranked(): the pin is a claim like any
			-- other, so a mode that never mentions rating still carries it.
			policies = { { "mode.ranked", implicit = true } }, ---@type ModePolicyRef[]
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
			-- the implicit ranked pin is not something a preset has said yet
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
				if chain.policies[i][1] == "mode.ranked" then
					table.remove(chain.policies, i)
				end
			end
			if not enabled then
				chain.policies[#chain.policies + 1] = { "mode.ranked" }
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

		---A module whose providers this preset makes live, besides the one
		---that ships it. The mode, not the module, decides who answers a fact.
		---The module is named by its contract, never by a string.
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
			lastPolicy("Unlocked").locked = false
			return reserialize()
		end

		chain.Locked = function()
			lastPolicy("Locked").locked = true
			return reserialize()
		end

		chain.Sealed = function()
			lastPolicy("Sealed").locked = "sealed"
			return reserialize()
		end

		for verbName, toRef in pairs(grammar.verbs) do
			assert(chain[verbName] == nil, "ModeBuilder.Grammar: verb collides with a chain field: " .. verbName)
			chain[verbName] = function(...)
				chain.policies[#chain.policies + 1] = toRef(name, ...)
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
