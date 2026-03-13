local TeamResourceData = {}

-- Temporary compatibility shim for CI headless engines that do not expose
-- Spring.GetTeamResourceData yet. Once the engine rollout is complete, delete
-- this shim and replace call sites with direct springRepo.GetTeamResourceData.
function TeamResourceData.Get(springRepo, teamID, resourceType)
  local getTeamResourceDataFn = springRepo.GetTeamResourceData
  if getTeamResourceDataFn then
    return getTeamResourceDataFn(teamID, resourceType)
  end

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
