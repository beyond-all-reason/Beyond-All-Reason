local ModuleHandler = VFS.Include("modules/module_handler.lua")
local state = VFS.Include("modules/transfer/state.lua") ---@type TransferState
local Contract = VFS.Include("modules/transfer/contract.lua") ---@type TransferContract

local TAX_KEY = "tax_resource_sharing_amount"

local rateByTeam = state.taxRateByTeam

local Tax = {}

---@param teamId integer
---@param opts table? modoptions (defaults to springRepo.GetModOptions())
---@param springRepo Spring? defaults to Spring (pass a repo to stay testable)
---@return number
function Tax.GetTaxRate(teamId, opts, springRepo)
	springRepo = springRepo or Spring
	opts = opts or springRepo.GetModOptions()
	---@cast opts table<string, string|number|boolean>
	---@type TransferTeamContext
	local ctx = { teamId = teamId, opts = opts, springRepo = springRepo }
	local terms = ModuleHandler.Enrich(Contract.TeamTerms, opts, ctx)
	local rate = tonumber(terms[Contract.TeamTerms.TaxRate]) ---@type number?
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

---@param teamId integer
---@param springRepo Spring?
---@return number
function Tax.RateOf(teamId, springRepo)
	local cached = rateByTeam[teamId]
	if cached ~= nil then
		return cached --[[@as number]]
	end
	return Tax.GetTaxRate(teamId, nil, springRepo)
end

---@param teamIds integer[]
---@param springRepo Spring?
---@param opts table? modoptions
function Tax.Refresh(teamIds, springRepo, opts)
	for _, teamId in ipairs(teamIds) do
		rateByTeam[teamId] = Tax.GetTaxRate(teamId, opts, springRepo)
	end
end

return Tax
