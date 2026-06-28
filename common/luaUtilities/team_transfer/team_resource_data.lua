local TeamResourceData = {}

-- assemble a ResourceData snapshot from Spring.GetTeamResources (backs the GG.GetTeamResourceData synthetic call)
---@param springRepo SpringSynced
---@param teamID number
---@param resourceType ResourceName
---@return ResourceData
function TeamResourceData.Get(springRepo, teamID, resourceType)
  local current, storage, pull, income, expense, shareSlider, sent, received = springRepo.GetTeamResources(teamID, resourceType)
  return {
    resourceType = resourceType,
    current = current or 0,
    storage = storage or 0,
    pull = pull or 0,
    income = income or 0,
    expense = expense or 0,
    shareSlider = shareSlider or 0,
    sent = sent or 0,
    received = received or 0,
  }
end

return TeamResourceData
