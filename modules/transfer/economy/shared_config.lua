local TransferEnums = require("modules/transfer/enums")
local MOD_OPTIONS = TransferEnums.ModOptions
local Tax = require("modules/transfer/resource/tax")

local M = {}

-- The modoptions do not change within a match, so each answer is read once per Spring: in the game that is the one
-- engine table, in a spec each mock is its own.
---@type table<table, number>
local cachedTax = setmetatable({}, { __mode = "k" })
---@type table<table, boolean>
local cachedSharingEnabled = setmetatable({}, { __mode = "k" })

function M.resetCache()
	cachedTax = setmetatable({}, { __mode = "k" })
	cachedSharingEnabled = setmetatable({}, { __mode = "k" })
end

---@param springRepo Spring
---@return boolean
function M.isResourceSharingEnabled(springRepo)
	local cached = cachedSharingEnabled[springRepo]
	if cached ~= nil then
		return cached
	end
	local v = springRepo.GetModOptions()[MOD_OPTIONS.ResourceSharingEnabled]
	cached = not (v == false or v == "0")
	cachedSharingEnabled[springRepo] = cached
	return cached
end

---@param springRepo Spring
---@return number tax Base tax rate
function M.getTaxConfig(springRepo)
	local cached = cachedTax[springRepo]
	if cached then
		return cached
	end

	local modOpts = springRepo.GetModOptions()
	local tax = tonumber(modOpts[MOD_OPTIONS.TaxResourceSharingAmount]) or 0
	if tax < 0 then
		tax = 0
	end
	if tax > 1 then
		tax = 1
	end
	cachedTax[springRepo] = tax
	return tax
end

---@param springRepo Spring
---@param teamId number
---@return number
function M.getTeamTaxRate(springRepo, teamId)
	return Tax.GetTaxRate(teamId, nil, springRepo)
end

return M
