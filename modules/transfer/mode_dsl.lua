--- Sharing mode vocabulary over modules/mode_builder.lua: nouns for the
--- sharing domains, verbs mapping them onto the pipeline's policy identities.
--- Chain mechanics, lock model, and the bundle contract live in the builder;
--- preset files read as:
---
---     Mode("Disabled")
---         .Desc("Disable all sharing.")
---         .Deny(Share.Resources)
---         .Tax(Share.Resources, 0.30).Hidden().Unlocked()

local ModeEnums = VFS.Include("modules/context/mode_enums.lua")
local Bundle = VFS.Include("modules/transfer/policy_bundle.lua")
local ModeBuilder = VFS.Include("modules/mode_builder.lua")

local M = {}

-- Nouns: each names the policy domain its verbs act on. Sub-nouns carry a unit
-- category (Share.Units.Constructors, Take.Resource, ...); .AtT2/.AtT3 variants
-- carry the tech tier (Share.Resources.AtT2, Share.Units.Constructors.AtT2).
local function withTiers(noun)
	noun.AtT2 = { domain = noun.domain, category = noun.category, tier = 2 }
	noun.AtT3 = { domain = noun.domain, category = noun.category, tier = 3 }
	return noun
end

local function withCategories(noun, tiers)
	for enumName, category in pairs(ModeEnums.UnitCategory) do
		noun[enumName] = { domain = noun.domain, category = category }
		if tiers then
			withTiers(noun[enumName])
		end
	end
	return noun
end

M.Share = {
	Units = withCategories(withTiers({ domain = "unit" }), true),
	Resources = withTiers({ domain = "resource" }),
}
M.Assist = {
	Allied = { domain = "assist" },
}
M.Reclaim = {
	AlliedUnits = { domain = "reclaim" },
}
M.Resurrect = {
	Partial = { domain = "resurrect" },
}
M.Build = {
	Constructors = { domain = "build" },
}
M.Take = withCategories({ domain = "take" })
M.Tech = { domain = "tech" }

local HINT = "Share.*, Assist.*, Reclaim.*, Resurrect.*, Build.*, Take, Tech"
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
			ModeBuilder.DomainOf(name, "Tax", noun, { resource = true }, "Share.Resources[.AtT2/.AtT3]")
			return { "resource.tax", rate = rate, tier = noun.tier }
		end,
		---Stun shared units of the noun's category for seconds (Share.Units.*),
		---or stun taken units for the take delay (Take).
		Stun = function(name, noun, seconds)
			local domain = ModeBuilder.DomainOf(name, "Stun", noun, STUN, "Share.Units.<Category> or Take")
			if domain == "take" then
				return { "take.stun" }
			end
			assert(noun.category, name .. ": .Stun(Share.Units.<Category>, seconds)")
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
