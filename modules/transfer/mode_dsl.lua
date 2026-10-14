local Actions = require("modules/transfer/lib/actions")
local ConstructionEnums = require("modules/construction/enums")
local ModeBuilder = require("modules/mode_builder")
local ModuleHandler = require("modules/module_handler")
local TransferEnums = require("modules/transfer/enums")

---@class TransferModeDSL
---@field Mode fun(name: string): TransferModeChain Start a preset. The category is not a parameter: the grammar binds every chain from this module to "transfer" — the name only names it.
---@field Transfer TransferGrant
---@field Construction TransferGrant
---@field Take TransferGrant
---@field [string] TransferGrant a noun another module adds to the axis

local M = {}
---@cast M TransferModeDSL

for name, action in pairs(Actions) do
	M[name] = action
end
-- Other modules on the axis bring their own nouns, and may decorate these
for _, decorate in ipairs(ModuleHandler.ModeNouns(TransferEnums.ModeCategories.Transfer)) do
	decorate(M)
end

local Opt = TransferEnums.ModOptions
local ConstructionOpt = ConstructionEnums.ModOptions
local Verb = ModeBuilder.Verb
local DomainOf = ModeBuilder.DomainOf

local HINT = "Transfer.*, Construction.*, Take"
local ALLOW_DENY = { unit = true, resource = true, assist = true, reclaim = true, resurrect = true, take = true }
local STUN = { unit = true, take = true }
local DELAY = { build = true, take = true }

---@param key string
---@param value string|number|boolean
---@param locked boolean
---@return table<string, ModOptionConfig>
local function option(key, value, locked)
	return { [key] = { value = value, locked = locked } }
end

local allow = {
	unit = function(p, lock)
		return option(
			p.option or Opt.UnitSharingMode,
			p.category or ConstructionEnums.UnitFilterCategory.All,
			lock.noun
		)
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
		return option(p.option or Opt.UnitSharingMode, ConstructionEnums.UnitFilterCategory.None, lock.noun)
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
		return {
			domain = DomainOf(name, "Allow", noun, ALLOW_DENY, HINT),
			category = noun.category,
			option = noun.option,
		}
	end, function(p, lock)
		return allow[p.domain](p, lock)
	end),

	Deny = rule(function(name, noun)
		return { domain = DomainOf(name, "Deny", noun, ALLOW_DENY, HINT), option = noun.option }
	end, function(p, lock)
		return deny[p.domain](p, lock)
	end),

	Tax = rule(function(name, noun, rate)
		DomainOf(name, "Tax", noun, { resource = true }, "Transfer.Resources")
		return { rate = rate, option = noun.option, category = noun.category }
	end, function(p, lock)
		assert(
			p.category == nil,
			".Tax(Transfer.Resources."
				.. tostring(p.category)
				.. ", ...) cannot be serialized yet:"
				.. " the tax modoption is not per resource. Tax Transfer.Resources for now."
		)
		return { [p.option or Opt.TaxResourceSharingAmount] = { value = p.rate, locked = lock.dial, ui = p.ui } }
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

	-- Every other module's dials on this axis, open at their starting point: what a preset that lets the
	-- player tweak everything says, without naming the modules
	Expose = Verb(function(name)
		local refs = {}
		for _, expose in ipairs(ModuleHandler.ModeExposures(TransferEnums.ModeCategories.Transfer)) do
			for _, ref in ipairs(expose(name)) do
				refs[#refs + 1] = ref
			end
		end
		return { refs = refs, lock = "open" }
	end, function(p, lock)
		local options = {}
		for _, ref in ipairs(p.refs) do
			for key, config in pairs(ref.write(ref, lock)) do
				assert(options[key] == nil, "two modules expose modoption " .. key)
				options[key] = config
			end
		end
		return options
	end),
}

M.Mode = ModeBuilder.Grammar({
	category = TransferEnums.ModeCategories.Transfer,
	verbs = ModeBuilder.Verbs(verbs, ModuleHandler.ModeVerbs(TransferEnums.ModeCategories.Transfer)),
}) --[[@as fun(name: string): TransferModeChain]]

return M
