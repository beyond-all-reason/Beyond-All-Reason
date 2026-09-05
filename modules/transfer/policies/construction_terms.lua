local ConstructionContract = VFS.Include("modules/construction/contract.lua") ---@type ConstructionContract
local AssistTax = VFS.Include("modules/transfer/lib/assist_tax.lua")
local Contract = VFS.Include("modules/transfer/contract.lua") ---@type TransferContract

Policies.Pipeline(ConstructionContract.Build).Unless(Contract.Build.UnaffordableAssistTax, function(ctx)
	local quote = AssistTax.Quote(ctx, Spring)
	return quote ~= nil and not quote.affordable
end)
