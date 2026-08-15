--- What a transfer costs. The rate varies by the sender's tech tier, so
--- this reads the tier tech owns and prices it here, where the transfer is.

local TechTier = VFS.Include("modules/tech/tier.lua")

local TAX_KEY = "tax_resource_sharing_amount"

local Tax = {}

---@param teamId integer
---@param opts table? modoptions (defaults to springRepo.GetModOptions())
---@param springRepo Spring? defaults to Spring (pass a repo to stay testable)
---@return number
function Tax.GetTaxRate(teamId, opts, springRepo)
	springRepo = springRepo or Spring
	opts = opts or springRepo.GetModOptions()
	local base = tonumber(opts[TAX_KEY]) or 0
	local level = tonumber(springRepo.GetTeamRulesParam(teamId, "tech_level") or 1) or 1
	local rate = tonumber(TechTier.resolveByTechLevel(opts, TAX_KEY, level))
	if not rate or rate < 0 then
		rate = base
	end
	if rate < 0 then
		rate = 0
	elseif rate > 1 then
		rate = 1
	end
	return rate
end

-- True if any tier (base, _at_t2, _at_t3) configures a positive tax.
---@param opts table? modoptions
---@return boolean
function Tax.AnyTaxConfigured(opts)
	opts = opts or Spring.GetModOptions()
	return (tonumber(opts[TAX_KEY]) or 0) > 0
		or (tonumber(opts[TAX_KEY .. "_at_t2"]) or 0) > 0
		or (tonumber(opts[TAX_KEY .. "_at_t3"]) or 0) > 0
end

return Tax
