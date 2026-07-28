--- Always a record with a mode, never an early nil: callers need the delay terms to explain a refusal.

local ConstructionEnums = VFS.Include("modules/construction/enums.lua")
local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local Contract = VFS.Include("modules/transfer/contract.lua") ---@type TransferContract
local take = Contract.Take

Policies.On(take).Answer(take.TakeTerms, function(ctx)
	local modOptions = (ctx and ctx.modOptions) or Spring.GetModOptions()
	return {
		mode = modOptions[TransferEnums.ModOptions.TakeMode] or TransferEnums.TakeMode.Enabled,
		delaySeconds = tonumber(modOptions[TransferEnums.ModOptions.TakeDelaySeconds]) or 30,
		delayCategory = modOptions[TransferEnums.ModOptions.TakeDelayCategory]
			or ConstructionEnums.UnitCategory.Resource,
	}
end)
