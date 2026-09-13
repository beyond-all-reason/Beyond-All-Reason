local ConstructionEnums = VFS.Include("modules/construction/enums.lua")
local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local Actions = VFS.Include("modules/transfer/lib/actions.lua")
local ModeBuilder = VFS.Include("modules/mode_builder.lua")

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

local Opt = TransferEnums.ModOptions
local ConstructionOpt = ConstructionEnums.ModOptions
local Verb = ModeBuilder.Verb
local DomainOf = ModeBuilder.DomainOf

local HINT = "Transfer.*, Construction.*, Take, Tech"
local ALLOW_DENY = { unit = true, resource = true, assist = true, reclaim = true, resurrect = true, take = true }
local STUN = { unit = true, take = true }
local DELAY = { build = true, take = true }

local UNIT_KEY = { [0] = Opt.UnitSharingMode, [2] = Opt.UnitSharingModeAtT2, [3] = Opt.UnitSharingModeAtT3 }
local TAX_KEY = {
	[0] = Opt.TaxResourceSharingAmount,
	[2] = Opt.TaxResourceSharingAmountAtT2,
	[3] = Opt.TaxResourceSharingAmountAtT3,
}

---@param key string
---@param value string|number|boolean
---@param locked boolean
---@return table<string, ModOptionConfig>
local function option(key, value, locked)
	return { [key] = { value = value, locked = locked } }
end

local allow = {
	unit = function(p, lock)
		return option(UNIT_KEY[p.tier or 0], p.category or ConstructionEnums.UnitFilterCategory.All, lock.noun)
	end,
	resource = function(_p, lock)
		return option(Opt.ResourceSharingEnabled, true, lock.noun)
	end,
	assist = function(_p, lock)
		return option(ConstructionOpt.AlliedAssistMode, ConstructionEnums.AlliedAssistMode.Enabled, lock.noun)
	end,
	reclaim = function(_p, lock)
		return option(ConstructionOpt.AlliedUnitReclaimMode, ConstructionEnums.AlliedUnitReclaimMode.Enabled, lock.noun)
	end,
	resurrect = function(_p, lock)
		return option(
			ConstructionOpt.AllowPartialResurrection,
			ConstructionEnums.AllowPartialResurrection.Enabled,
			lock.noun
		)
	end,
	take = function(_p, lock)
		return option(Opt.TakeMode, TransferEnums.TakeMode.Enabled, lock.noun)
	end,
}
local deny = {
	unit = function(p, lock)
		return option(UNIT_KEY[p.tier or 0], ConstructionEnums.UnitFilterCategory.None, lock.noun)
	end,
	resource = function(_p, lock)
		return option(Opt.ResourceSharingEnabled, false, lock.noun)
	end,
	assist = function(_p, lock)
		return option(ConstructionOpt.AlliedAssistMode, ConstructionEnums.AlliedAssistMode.Disabled, lock.noun)
	end,
	reclaim = function(_p, lock)
		return option(
			ConstructionOpt.AlliedUnitReclaimMode,
			ConstructionEnums.AlliedUnitReclaimMode.Disabled,
			lock.noun
		)
	end,
	resurrect = function(_p, lock)
		return option(
			ConstructionOpt.AllowPartialResurrection,
			ConstructionEnums.AllowPartialResurrection.Disabled,
			lock.noun
		)
	end,
	take = function(_p, lock)
		return option(Opt.TakeMode, TransferEnums.TakeMode.Disabled, lock.noun)
	end,
}

---@param t2 number
---@param t3 number
---@param blocking boolean
---@param lock { noun: boolean, dial: boolean }
---@return table<string, ModOptionConfig>
local function techGate(t2, t3, blocking, lock)
	return {
		[Opt.TechBlocking] = { value = blocking, locked = lock.noun },
		[Opt.T2TechThreshold] = { value = t2, locked = lock.dial },
		[Opt.T3TechThreshold] = { value = t3, locked = lock.dial },
	}
end

---@param parse fun(name: string, ...): table
---@param write fun(p: table, lock: { noun: boolean, dial: boolean }): table<string, ModOptionConfig>
---@return ModeVerb
local function rule(parse, write)
	return Verb(function(...)
		local ref = parse(...)
		if ref.lock == nil then
			ref.lock = "locked"
		end
		return ref
	end, write)
end

local verbs = {
	Allow = rule(function(name, noun)
		return { domain = DomainOf(name, "Allow", noun, ALLOW_DENY, HINT), category = noun.category, tier = noun.tier }
	end, function(p, lock)
		return allow[p.domain](p, lock)
	end),

	Deny = rule(function(name, noun)
		return { domain = DomainOf(name, "Deny", noun, ALLOW_DENY, HINT), tier = noun.tier }
	end, function(p, lock)
		return deny[p.domain](p, lock)
	end),

	Tax = rule(function(name, noun, rate)
		DomainOf(name, "Tax", noun, { resource = true }, "Transfer.Resources[.AtT2/.AtT3]")
		return { rate = rate, tier = noun.tier, category = noun.category }
	end, function(p, lock)
		assert(
			p.category == nil,
			".Tax(Transfer.Resources."
				.. tostring(p.category)
				.. ", ...) cannot be serialized yet:"
				.. " the tax modoptions are per tier, not per resource. Tax Transfer.Resources for now."
		)
		return { [TAX_KEY[p.tier or 0]] = { value = p.rate, locked = lock.dial, ui = p.ui } }
	end),

	Stun = rule(function(name, noun, seconds)
		local domain = DomainOf(name, "Stun", noun, STUN, "Transfer.Units.<Category> or Take")
		if domain == "take" then
			return { domain = domain }
		end
		assert(noun.category, name .. ": .Stun(Transfer.Units.<Category>, seconds)")
		return { domain = domain, seconds = seconds, category = noun.category }
	end, function(p, lock)
		if p.domain == "take" then
			return option(Opt.TakeMode, TransferEnums.TakeMode.StunDelay, lock.noun)
		end
		return {
			[Opt.UnitShareStunSeconds] = { value = p.seconds, locked = lock.dial },
			[Opt.UnitStunCategory] = { value = p.category, locked = lock.noun },
		}
	end),

	Defer = rule(function(name, noun)
		DomainOf(name, "Defer", noun, { take = true }, "Take")
		return {}
	end, function(_p, lock)
		return option(Opt.TakeMode, TransferEnums.TakeMode.TakeDelay, lock.noun)
	end),

	Delay = rule(function(name, noun, seconds)
		local domain = DomainOf(name, "Delay", noun, DELAY, "Build.Constructors or Take.<Category>")
		if domain == "build" then
			return { domain = domain, seconds = seconds }
		end
		assert(noun.category, name .. ": .Delay(Take.<Category>, seconds)")
		return { domain = domain, seconds = seconds, category = noun.category }
	end, function(p, lock)
		if p.domain == "build" then
			return option(ConstructionOpt.ConstructorBuildDelay, p.seconds, lock.dial)
		end
		return {
			[Opt.TakeDelaySeconds] = { value = p.seconds, locked = lock.dial },
			[Opt.TakeDelayCategory] = { value = p.category, locked = lock.noun },
		}
	end),

	Gate = rule(function(name, noun, t2, t3)
		DomainOf(name, "Gate", noun, { tech = true }, "Tech")
		return { t2 = t2, t3 = t3 }
	end, function(p, lock)
		return techGate(p.t2, p.t3, true, lock)
	end),

	Open = rule(function(name, noun, t2, t3)
		DomainOf(name, "Open", noun, { tech = true }, "Tech")
		return { t2 = t2, t3 = t3 }
	end, function(p, lock)
		return techGate(p.t2, p.t3, false, lock)
	end),
}

M.Mode = ModeBuilder.Grammar({
	category = TransferEnums.ModeCategories.Transfer,
	verbs = verbs,
}) --[[@as fun(name: string): TransferModeChain]]

return M
