local AssistTax = require("modules/transfer/lib/assist_tax")
local Construction = require("modules/construction/api")
local ConstructionEnums = require("modules/construction/enums")
local Modules = require("modules/enums").Modules
local Policy = require("modules/policy")
local TransferEnums = require("modules/transfer/enums")

---@type ConstructionContract
local ConstructionContract = Policies.Contract(Modules.Construction)

-- A build step an ally helps with is taxed, and one the helper cannot pay for does not happen
--
local Build = Policy.Contributes(ConstructionContract.Build, { UnaffordableAssistTax = "UnaffordableAssistTax" })

Policies.On(Build).Unless(Build.UnaffordableAssistTax, function(ctx)
	local quote = AssistTax.Quote(ctx, ctx.springRepo)
	return quote ~= nil and not quote.affordable
end)

-- Utility buildings may change hands between allies when the sharing mode says so
--
Policies.For(ConstructionContract.PlacementFacts)
	.Provide(ConstructionContract.PlacementFacts.UtilitySharing, function(ctx)
		local mode = tostring(ctx.modOptions[TransferEnums.ModOptions.UnitSharingMode])
		return table.contains(Construction.UnitTypesFor(mode), ConstructionEnums.UnitType.Utility)
	end)

---@class (partial) TransferContract
local Contract = {}
Contract.Build = Build

return Contract
