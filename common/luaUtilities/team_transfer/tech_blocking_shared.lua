local TechBlockingShared = {}

local TAX_KEY = "tax_resource_sharing_amount"

-- Resolve a tech-level-varying modOption: _at_t3, then _at_t2, then base key.
---@param opts table modoptions
---@param baseKey string
---@param techLevel number
function TechBlockingShared.resolveByTechLevel(opts, baseKey, techLevel)
  if techLevel >= 3 then
    local v = opts[baseKey .. "_at_t3"]
    if v ~= nil and v ~= "" then return v end
  end
  if techLevel >= 2 then
    local v = opts[baseKey .. "_at_t2"]
    if v ~= nil and v ~= "" then return v end
  end
  return opts[baseKey]
end

-- Effective resource-sharing tax rate [0,1] for a team's tech level; _at_tN sentinel (<0/empty) falls back to base.
---@param teamId number
---@param opts table? modoptions (defaults to springRepo.GetModOptions())
---@param springRepo table? defaults to Spring (pass a repo to stay testable)
---@return number
function TechBlockingShared.GetTaxRate(teamId, opts, springRepo)
  springRepo = springRepo or Spring
  opts = opts or springRepo.GetModOptions()
  local base = tonumber(opts[TAX_KEY]) or 0
  local level = tonumber(springRepo.GetTeamRulesParam(teamId, "tech_level") or 1) or 1
  local rate = tonumber(TechBlockingShared.resolveByTechLevel(opts, TAX_KEY, level))
  if not rate or rate < 0 then rate = base end
  if rate < 0 then rate = 0 elseif rate > 1 then rate = 1 end
  return rate
end

-- True if any tier (base, _at_t2, _at_t3) configures a positive tax.
---@param opts table? modoptions
---@return boolean
function TechBlockingShared.AnyTaxConfigured(opts)
  opts = opts or Spring.GetModOptions()
  return (tonumber(opts[TAX_KEY]) or 0) > 0
    or (tonumber(opts[TAX_KEY .. "_at_t2"]) or 0) > 0
    or (tonumber(opts[TAX_KEY .. "_at_t3"]) or 0) > 0
end

return TechBlockingShared
