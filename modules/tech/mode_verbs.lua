local ConstructionEnums = require("modules/construction/enums")
local ModeBuilder = require("modules/mode_builder")
local TechEnums = require("modules/tech/enums")
local TransferEnums = require("modules/transfer/enums")

local Opt = TechEnums.ModOptions

---@class TransferModeChain
---@field Gate fun(noun: TransferGrant, t2: number, t3: number): TransferModeChain Tech levels gate construction; keystones per player for tier 2 and tier 3.
---@field Open fun(noun: TransferGrant, t2: number, t3: number): TransferModeChain The tech dials, open: blocking off, the thresholds as a starting point.

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

---@param verb string
---@param blocking boolean
---@return ModeVerb
local function techVerb(verb, blocking)
	return ModeBuilder.Verb(function(name, noun, t2, t3)
		ModeBuilder.DomainOf(name, verb, noun, { tech = true }, "Tech")
		return { t2 = t2, t3 = t3, lock = "locked" }
	end, function(p, lock)
		return techGate(p.t2, p.t3, blocking, lock)
	end)
end

-- A transfer grant varied by tier: the same grant, written to the option tech reads once the team reaches the tier
---@param grant TransferGrant
---@param optionsByTier table<integer, string>
local function withTiers(grant, optionsByTier)
	for tier, option in pairs(optionsByTier) do
		grant["AtT" .. tier] = { domain = grant.domain, category = grant.category, option = option }
	end
end

local UNIT_BY_TIER = { [2] = Opt.UnitSharingModeAtT2, [3] = Opt.UnitSharingModeAtT3 }
local TAX_BY_TIER = { [2] = Opt.TaxResourceSharingAmountAtT2, [3] = Opt.TaxResourceSharingAmountAtT3 }

return {
	category = TransferEnums.ModeCategories.Transfer,
	verbs = {
		Gate = techVerb("Gate", true),
		Open = techVerb("Open", false),
	},
	-- Tech is a noun of the axis, and transfer's unit and resource grants gain a tier: Transfer.Units.Constructors.AtT2
	nouns = function(nouns)
		nouns.Tech = { domain = "tech" }
		local units, resources = nouns.Transfer.Units, nouns.Transfer.Resources
		withTiers(units, UNIT_BY_TIER)
		for _, category in pairs(ConstructionEnums.UnitCategory) do
			for field, grant in pairs(units) do
				if type(grant) == "table" and grant.category == category and grant.domain == units.domain then
					withTiers(grant, UNIT_BY_TIER)
					break
				end
			end
		end
		withTiers(resources, TAX_BY_TIER)
	end,
	-- The tech dials at their starting point: blocking off, the thresholds as the lobby shows them, nothing more
	-- shared by tier, the tier taxes unset
	expose = function()
		return {
			{
				verb = "Open",
				write = function(_p, lock)
					return techGate(1, 1.5, false, lock)
				end,
			},
			{
				verb = "Expose",
				write = function(_p, lock)
					local none = ConstructionEnums.UnitFilterCategory.None
					return {
						[Opt.UnitSharingModeAtT2] = { value = none, locked = lock.noun },
						[Opt.UnitSharingModeAtT3] = { value = none, locked = lock.noun },
						[Opt.TaxResourceSharingAmountAtT2] = { value = -1, locked = lock.dial },
						[Opt.TaxResourceSharingAmountAtT3] = { value = -1, locked = lock.dial },
					}
				end,
			},
		}
	end,
}
