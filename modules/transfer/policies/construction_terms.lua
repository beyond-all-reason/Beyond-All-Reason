local ConstructionContract = VFS.Include("modules/construction/contract.lua") ---@type ConstructionContract
local AssistTax = VFS.Include("modules/transfer/lib/assist_tax.lua")

Policies.Pipeline(ConstructionContract.Build).Unless("UnaffordableAssistTax", function(ctx)
	local quote = AssistTax.Quote(ctx, Spring.GetModOptions(), Spring)
	return quote ~= nil and not quote.affordable
end)
