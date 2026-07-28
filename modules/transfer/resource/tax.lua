local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Contract = VFS.Include("modules/transfer/contract.lua") ---@type TransferContract

local TAX_KEY = "tax_resource_sharing_amount"

local Tax = {}

---@param teamId integer
---@param opts table? modoptions (defaults to springRepo.GetModOptions())
---@param springRepo Spring? defaults to Spring (pass a repo to stay testable)
---@return number
function Tax.GetTaxRate(teamId, opts, springRepo)
	springRepo = springRepo or Spring
	opts = opts or springRepo.GetModOptions()
	---@type TransferTeamContext
	local ctx = { teamId = teamId, opts = opts, springRepo = springRepo }
	local rate
	for _, provision in ipairs(ModuleHandler.LoadEnrichers("transfer", "team_terms")) do
		local results = { provision.evaluate(ctx) }
		for i, field in ipairs(provision.names) do
			if field == Contract.TeamTerms.TaxRate and results[i] ~= nil then
				rate = tonumber(results[i])
			end
		end
	end
	if not rate or rate < 0 then
		rate = tonumber(opts[TAX_KEY]) or 0
	end
	if rate < 0 then
		rate = 0
	elseif rate > 1 then
		rate = 1
	end
	return rate
end

---@param opts table? modoptions
---@return boolean
function Tax.AnyTaxConfigured(opts)
	opts = opts or Spring.GetModOptions()
	return (tonumber(opts[TAX_KEY]) or 0) > 0
		or (tonumber(opts[TAX_KEY .. "_at_t2"]) or 0) > 0
		or (tonumber(opts[TAX_KEY .. "_at_t3"]) or 0) > 0
end

return Tax
