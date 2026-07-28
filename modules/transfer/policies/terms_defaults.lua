local Contract = VFS.Include("modules/transfer/contract.lua") ---@type TransferContract
local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local ConstructionEnums = VFS.Include("modules/construction/enums.lua")

-- What transfer's slots mean when no live module fills them: the flat
-- modoption tax, the modoption sharing mode, no tech blocking and no notes.
-- A preset that makes tech live (Tech Core, or Customize through .Uses)
-- gets tiered answers instead.

---@param opts table<string, string|number|boolean>
---@return number
local function modOptionTax(opts)
	local rate = tonumber(opts[TransferEnums.ModOptions.TaxResourceSharingAmount]) or 0
	if rate < 0 then
		return 0
	elseif rate > 1 then
		return 1
	end
	return rate
end

Policies.On(Contract.TeamTerms).Default(Contract.TeamTerms.TaxRate, function(ctx)
	return modOptionTax(ctx.opts)
end)

Policies.On(Contract.TeamPairing)
	.Default(Contract.TeamPairing.TechBlocking, function()
		return nil
	end)
	.Default(Contract.TeamPairing.UnitSharingModes, function(_, springRepo)
		local mode = springRepo.GetModOptions()[TransferEnums.ModOptions.UnitSharingMode]
		return { mode or ConstructionEnums.UnitFilterCategory.None }
	end)
	.Default(Contract.TeamPairing.TaxRate, function(_, springRepo)
		return modOptionTax(springRepo.GetModOptions())
	end)

Policies.On(Contract.UnitTermsNotes)
	.Default(Contract.UnitTermsNotes.FutureUnlock, function()
		return false
	end)
	.Default(Contract.UnitTermsNotes.TechData, function()
		return nil
	end)

Policies.On(Contract.ResourceTermsNotes).Default(Contract.ResourceTermsNotes.TaxUnlock, function()
	return nil
end)
