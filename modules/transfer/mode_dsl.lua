--- Sharing mode vocabulary over modules/mode_builder.lua: nouns for the
--- sharing domains, verbs mapping them onto the pipeline's policy identities.
--- Chain mechanics, lock model, and the bundle contract live in the builder;
--- preset files read as:
---
---     Mode("Disabled")
---         .Desc("Disable all sharing.")
---         .Deny(Transfer.Resources)
---         .Tax(Transfer.Resources, 0.30).Hidden().Unlocked()

local ModeEnums = VFS.Include("modules/context/mode_enums.lua")
local Actions = VFS.Include("modules/transfer/lib/actions.lua")
local Bundle = VFS.Include("modules/transfer/policy_bundle.lua")
local ModeBuilder = VFS.Include("modules/mode_builder.lua")

local M = {}

-- The nouns ARE the module's actions: a grant is written against the same
-- table entry a mission calls. Declared in lib/actions.lua, once.
for name, action in pairs(Actions) do
	M[name] = action
end

local HINT = "Transfer.*, Construction.*, Take, Tech"
local ALLOW_DENY = { unit = true, resource = true, assist = true, reclaim = true, resurrect = true, take = true }
local STUN = { unit = true, take = true }
local DELAY = { build = true, take = true }

M.Mode = ModeBuilder.Grammar({
	category = ModeEnums.ModeCategories.Sharing,
	serializers = Bundle.Serializers,
	verbs = {
		---Allow the noun's domain (a category sub-noun narrows unit sharing).
		Allow = function(name, noun)
			local domain = ModeBuilder.DomainOf(name, "Allow", noun, ALLOW_DENY, HINT)
			return { domain .. ".allow", category = noun.category, tier = noun.tier }
		end,
		---Deny the noun's domain outright.
		Deny = function(name, noun)
			return { ModeBuilder.DomainOf(name, "Deny", noun, ALLOW_DENY, HINT) .. ".deny", tier = noun.tier }
		end,
		---Tax resource sharing at a rate in [0,1].
		Tax = function(name, noun, rate)
			ModeBuilder.DomainOf(name, "Tax", noun, { resource = true }, "Transfer.Resources[.AtT2/.AtT3]")
			return { "resource.tax", rate = rate, tier = noun.tier, category = noun.category }
		end,
		---Stun shared units of the noun's category for seconds (Transfer.Units.*),
		---or stun taken units for the take delay (Take).
		Stun = function(name, noun, seconds)
			local domain = ModeBuilder.DomainOf(name, "Stun", noun, STUN, "Transfer.Units.<Category> or Take")
			if domain == "take" then
				return { "take.stun" }
			end
			assert(noun.category, name .. ": .Stun(Transfer.Units.<Category>, seconds)")
			return { "unit.stun", seconds = seconds, category = noun.category }
		end,
		---Take arrives only after the delay.
		Defer = function(name, noun)
			ModeBuilder.DomainOf(name, "Defer", noun, { take = true }, "Take")
			return { "take.defer" }
		end,
		---Delay dial: constructor build delay (Build.Constructors) or the take
		---delay and its category (Take.<Category>).
		Delay = function(name, noun, seconds)
			local domain = ModeBuilder.DomainOf(name, "Delay", noun, DELAY, "Build.Constructors or Take.<Category>")
			if domain == "build" then
				return { "build.delay", seconds = seconds }
			end
			assert(noun.category, name .. ": .Delay(Take.<Category>, seconds)")
			return { "take.delay", seconds = seconds, category = noun.category }
		end,
		---Tech levels gate construction; thresholds are the pacing dials.
		Gate = function(name, noun, t2, t3)
			ModeBuilder.DomainOf(name, "Gate", noun, { tech = true }, "Tech")
			return { "tech.gate", t2 = t2, t3 = t3 }
		end,
		---Tech open (no gating); thresholds stay exposed as dials.
		Open = function(name, noun, t2, t3)
			ModeBuilder.DomainOf(name, "Open", noun, { tech = true }, "Tech")
			return { "tech.open", t2 = t2, t3 = t3 }
		end,
	},
})

return M
