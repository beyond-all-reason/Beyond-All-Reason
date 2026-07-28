local ConstructionContract = VFS.Include("modules/construction/contract.lua") ---@type ConstructionContract
local AssistTax = VFS.Include("modules/transfer/lib/assist_tax.lua")
local Contract = VFS.Include("modules/transfer/contract.lua") ---@type TransferContract
local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local ConstructionEnums = VFS.Include("modules/construction/enums.lua")
local UnitCategories = VFS.Include("modules/construction/lib/unit_categories.lua")

Policies.On(ConstructionContract.Build).Unless(Contract.Build.UnaffordableAssistTax, function(ctx)
	local quote = AssistTax.Quote(ctx, Spring)
	return quote ~= nil and not quote.affordable
end)

Policies.On(ConstructionContract.PlacementFacts)
	.Provide(ConstructionContract.PlacementFacts.UtilitySharing, function(ctx)
		local mode = ctx.modOptions[TransferEnums.ModOptions.UnitSharingMode]
		return table.contains(UnitCategories.TypesFor(mode), ConstructionEnums.UnitType.Utility)
	end)
