local Policy = require("modules/policy")

-- What extraction pays each team this tick: what its extractors made, unless a mode answers otherwise
--
---@class EconomyExtractionContext: PolicyContext
---@field springRepo Spring
---@field teams table<integer, EconomyTeamResources>
---@field seconds number
---@field income table<integer, table<ResourceName, number>> what each team's extractors made over the tick

---@class EconomyExtractionFacts: PolicyFacts<EconomyExtractionContext>
---@field Income "income"

---@type EconomyExtractionFacts
local Extraction = {
	Income = "income",
}
Policy.Facts(Extraction)

---@class (partial) EconomyContract
local Contract = {}
Contract.Extraction = Extraction

return Contract
