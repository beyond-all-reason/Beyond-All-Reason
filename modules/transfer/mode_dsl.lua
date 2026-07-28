local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local Actions = VFS.Include("modules/transfer/lib/actions.lua")
local Bundle = VFS.Include("modules/transfer/policy_bundle.lua")
local ModeBuilder = VFS.Include("modules/mode_builder.lua")

--- The chain type lives in types/mode_policy.lua so the language server resolves
--- verbs the Grammar only builds at runtime.
---@class TransferModeDSL
---@field Mode fun(name: string): TransferModeChain Start a preset. The category is not a parameter: the grammar binds every chain from this module to "transfer" — the name only names it.
---@field Transfer TransferGrant
---@field Construction TransferGrant
---@field Take TransferGrant
---@field Tech TransferGrant

local M = {}
---@cast M TransferModeDSL

for name, action in pairs(Actions) do
	M[name] = action
end

local HINT = "Transfer.*, Construction.*, Take, Tech"
local ALLOW_DENY = { unit = true, resource = true, assist = true, reclaim = true, resurrect = true, take = true }
local STUN = { unit = true, take = true }
local DELAY = { build = true, take = true }

-- A transfer verb is a rule, not a suggestion: what it writes is pinned
-- unless the preset says .Unlocked(). Its dials stay open either way.
---@param verb fun(name: string, ...): table
local function rule(verb)
	return function(...)
		local ref = verb(...)
		if ref.locked == nil then
			ref.locked = true
		end
		return ref
	end
end

local verbs = {
	Allow = function(name, noun)
		local domain = ModeBuilder.DomainOf(name, "Allow", noun, ALLOW_DENY, HINT)
		return { domain .. ".allow", category = noun.category, tier = noun.tier }
	end,
	Deny = function(name, noun)
		return { ModeBuilder.DomainOf(name, "Deny", noun, ALLOW_DENY, HINT) .. ".deny", tier = noun.tier }
	end,
	Tax = function(name, noun, rate)
		ModeBuilder.DomainOf(name, "Tax", noun, { resource = true }, "Transfer.Resources[.AtT2/.AtT3]")
		return { "resource.tax", rate = rate, tier = noun.tier, category = noun.category }
	end,
	Stun = function(name, noun, seconds)
		local domain = ModeBuilder.DomainOf(name, "Stun", noun, STUN, "Transfer.Units.<Category> or Take")
		if domain == "take" then
			return { "take.stun" }
		end
		assert(noun.category, name .. ": .Stun(Transfer.Units.<Category>, seconds)")
		return { "unit.stun", seconds = seconds, category = noun.category }
	end,
	Defer = function(name, noun)
		ModeBuilder.DomainOf(name, "Defer", noun, { take = true }, "Take")
		return { "take.defer" }
	end,
	Delay = function(name, noun, seconds)
		local domain = ModeBuilder.DomainOf(name, "Delay", noun, DELAY, "Build.Constructors or Take.<Category>")
		if domain == "build" then
			return { "build.delay", seconds = seconds }
		end
		assert(noun.category, name .. ": .Delay(Take.<Category>, seconds)")
		return { "take.delay", seconds = seconds, category = noun.category }
	end,
	Gate = function(name, noun, t2, t3)
		ModeBuilder.DomainOf(name, "Gate", noun, { tech = true }, "Tech")
		return { "tech.gate", t2 = t2, t3 = t3 }
	end,
	Open = function(name, noun, t2, t3)
		ModeBuilder.DomainOf(name, "Open", noun, { tech = true }, "Tech")
		return { "tech.open", t2 = t2, t3 = t3 }
	end,
}
for verbName, verb in pairs(verbs) do
	verbs[verbName] = rule(verb)
end

M.Mode = ModeBuilder.Grammar({
	category = TransferEnums.ModeCategories.Transfer,
	serializers = Bundle.Serializers,
	verbs = verbs,
}) --[[@as fun(name: string): TransferModeChain]]

return M
