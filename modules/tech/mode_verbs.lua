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

return {
	category = TransferEnums.ModeCategories.Transfer,
	verbs = {
		Gate = techVerb("Gate", true),
		Open = techVerb("Open", false),
	},
}
