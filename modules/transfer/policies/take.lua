--- Always a record with a mode, never an early nil: callers need the delay terms to explain a refusal.

local ModeEnums = VFS.Include("modules/context/mode_enums.lua")
local Contract = VFS.Include("modules/transfer/contract.lua") ---@type TransferContract
local take = Contract.Take

Policies.Pipeline(take).Select(take.TakeTerms, function(ctx)
	local modOptions = (ctx and ctx.modOptions) or Spring.GetModOptions()
	return {
		mode = modOptions[ModeEnums.ModOptions.TakeMode] or ModeEnums.TakeMode.Enabled,
		delaySeconds = tonumber(modOptions[ModeEnums.ModOptions.TakeDelaySeconds]) or 30,
		delayCategory = modOptions[ModeEnums.ModOptions.TakeDelayCategory] or ModeEnums.UnitCategory.Resource,
	}
end)
