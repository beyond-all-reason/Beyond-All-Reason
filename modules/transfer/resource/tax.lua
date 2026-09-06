local ModuleHandler = VFS.Include("modules/module_handler.lua")
local state = VFS.Include("modules/transfer/state.lua") ---@type TransferState
local Contract = VFS.Include("modules/transfer/contract.lua") ---@type TransferContract

local TAX_KEY = "tax_resource_sharing_amount"

-- Refreshed by the resource controller, read by the assist tax from the
-- controller and the construction-terms policy file alike: one table.
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
	-- a live provider that answered nil has declined; the modoption is the floor
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

---The team's rate as of the last refresh: a table read, cheap enough for a
---build-step callin. A team never refreshed is resolved live, not stored.
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

---Re-resolve every listed team's rate through the enrichers. The controller
---calls this when the policy cache refreshes, so a tier change reaches the
---assist tax on the next economy tick rather than being decided at load.
---@param teamIds integer[]
---@param springRepo Spring?
---@param opts table? modoptions
function Tax.Refresh(teamIds, springRepo, opts)
	for _, teamId in ipairs(teamIds) do
		rateByTeam[teamId] = Tax.GetTaxRate(teamId, opts, springRepo)
	end
end

return Tax
