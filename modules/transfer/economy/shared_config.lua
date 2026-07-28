local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local MOD_OPTIONS = TransferEnums.ModOptions
local Tax = VFS.Include("modules/transfer/resource/tax.lua")

local M = {}

---@type number?
local cachedTax = nil
---@type boolean?
local cachedSharingEnabled = nil

function M.resetCache()
	cachedTax = nil
	cachedSharingEnabled = nil
end

---@param springRepo Spring
---@return boolean
function M.isResourceSharingEnabled(springRepo)
	if cachedSharingEnabled ~= nil then
		return cachedSharingEnabled
	end
	local v = springRepo.GetModOptions()[MOD_OPTIONS.ResourceSharingEnabled]
	cachedSharingEnabled = not (v == false or v == "0")
	return cachedSharingEnabled
end

---@param springRepo Spring
---@return number tax Base tax rate
function M.getTaxConfig(springRepo)
	if cachedTax then
		return cachedTax
	end

	local modOpts = springRepo.GetModOptions()
	local tax = tonumber(modOpts[MOD_OPTIONS.TaxResourceSharingAmount]) or 0
	if tax < 0 then
		tax = 0
	end
	if tax > 1 then
		tax = 1
	end

	cachedTax = tax

	return tax
end

---@param springRepo Spring
---@param teamId number
---@return number
function M.getTeamTaxRate(springRepo, teamId)
	return Tax.GetTaxRate(teamId, nil, springRepo)
end

return M
