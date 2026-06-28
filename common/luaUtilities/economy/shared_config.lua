local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")
local MOD_OPTIONS = ModeEnums.ModOptions
local TechBlockingShared = VFS.Include("common/luaUtilities/team_transfer/tech_blocking_shared.lua")

local M = {}

---@type number?
local cachedTax = nil
---@type boolean?
local cachedSharingEnabled = nil

function M.resetCache()
  cachedTax = nil
  cachedSharingEnabled = nil
end

---@param springRepo SpringSynced
---@return boolean
function M.isResourceSharingEnabled(springRepo)
  if cachedSharingEnabled ~= nil then
    return cachedSharingEnabled
  end
  local v = springRepo.GetModOptions()[MOD_OPTIONS.ResourceSharingEnabled]
  cachedSharingEnabled = not (v == false or v == "0")
  return cachedSharingEnabled
end

---@param springRepo SpringSynced
---@return number tax Base tax rate
function M.getTaxConfig(springRepo)
  if cachedTax then
    return cachedTax
  end

  local modOpts = springRepo.GetModOptions()
  local tax = tonumber(modOpts[MOD_OPTIONS.TaxResourceSharingAmount]) or 0
  if tax < 0 then tax = 0 end
  if tax > 1 then tax = 1 end

  cachedTax = tax

  return tax
end

-- per-team tax rate by tech level; degrades to base rate when tech_blocking inactive
---@param springRepo SpringSynced
---@param teamId number
---@return number
function M.getTeamTaxRate(springRepo, teamId)
  return TechBlockingShared.GetTaxRate(teamId, nil, springRepo)
end

return M
