local ConstructionEnums = require("modules/construction/enums")
local Policy = require("modules/policy")
local TransferEnums = require("modules/transfer/enums")

-- The terms a team may take a leaver's units on
--
---@class TransferTakeContext: PolicyContext

---@class TakeTerms
---@field mode string
---@field delaySeconds number
---@field delayCategory string

---@class TransferTakePolicy: PolicySteps<TransferTakeContext, TakeTerms>
---@field TakeTerms "TakeTerms"

---@type TransferTakePolicy
local Take = {
	TakeTerms = "TakeTerms",
}
Policy.Single(Take)

Policies.On(Take).Answer(Take.TakeTerms, function(ctx)
	local modOptions = ctx.modOptions
	return {
		mode = modOptions[TransferEnums.ModOptions.TakeMode] or TransferEnums.TakeMode.Enabled,
		delaySeconds = tonumber(modOptions[TransferEnums.ModOptions.TakeDelaySeconds]) or 30,
		delayCategory = modOptions[TransferEnums.ModOptions.TakeDelayCategory]
			or ConstructionEnums.UnitCategory.Resource,
	}
end)

---@class (partial) TransferContract
local Contract = {}
Contract.Take = Take

return Contract
