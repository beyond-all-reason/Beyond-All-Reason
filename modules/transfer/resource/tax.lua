local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local state = require("modules/transfer/state")

local TAX_KEY = "tax_resource_sharing_amount"

local rateByTeam = state.taxRateByTeam

local Tax = {}

---@param opts table<string, string|number|boolean>
---@return number the modoption's tax rate, clamped to 0..1
function Tax.ModOption(opts)
	local rate = tonumber(opts[TAX_KEY]) or 0
	if rate < 0 then
		return 0
	elseif rate > 1 then
		return 1
	end
	return rate
end

---@param teamId integer
---@param opts table? modoptions (defaults to springRepo.GetModOptions())
---@param springRepo Spring? defaults to Spring (pass a repo to stay testable)
---@return number
function Tax.GetTaxRate(teamId, opts, springRepo)
	---@type TransferContract
	local Transfer = ModuleHandler.Contract(Modules.Transfer)
	springRepo = springRepo or Spring
	opts = opts or springRepo.GetModOptions()
	---@cast opts table<string, string|number|boolean>
	---@type TransferTeamContext
	local ctx = { teamId = teamId, modOptions = opts, springRepo = springRepo }
	local terms = ModuleHandler.Enrich(Transfer.TeamTerms, ctx)
	local rate = tonumber(terms[Transfer.TeamTerms.TaxRate]) ---@type number?
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
