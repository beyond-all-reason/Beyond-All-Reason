local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local MOD_OPTIONS = SharedEnums.ModOptions
local ResourceType = SharedEnums.ResourceType

local M = {}

---@type number?
local cachedTax = nil
---@type table<ResourceType, number>?
local cachedThresholds = nil

---@param springRepo ISpring
---@return number tax
---@return table<ResourceType, number> thresholds
function M.getTaxConfig(springRepo)
  if cachedTax and cachedThresholds then
    return cachedTax, cachedThresholds
  end

  local modOpts = springRepo.GetModOptions()
  local tax = tonumber(modOpts[MOD_OPTIONS.TaxResourceSharingAmount]) or 0
  if tax < 0 then tax = 0 end
  if tax > 1 then tax = 1 end
  local thresholds = {
    [ResourceType.METAL] = math.max(0, tonumber(modOpts[MOD_OPTIONS.PlayerMetalSendThreshold]) or 0),
    [ResourceType.ENERGY] = math.max(0, tonumber(modOpts[MOD_OPTIONS.PlayerEnergySendThreshold]) or 0),
  }
  
  cachedTax = tax
  cachedThresholds = thresholds
  
  return tax, thresholds
end

return M
