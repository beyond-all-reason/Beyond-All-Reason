local TechBlockingComms = {}

---Build tech blocking context from TeamRulesParams (works in both synced and unsynced)
---@param teamId number
---@return TechBlockingContext?
function TechBlockingComms.fromTeamRules(teamId)
  local rawLevel = Spring.GetTeamRulesParam(teamId, "tech_level")
  if not rawLevel then return nil end
  local rawPoints = Spring.GetTeamRulesParam(teamId, "tech_points")
  local rawT2 = Spring.GetTeamRulesParam(teamId, "tech_t2_threshold")
  local rawT3 = Spring.GetTeamRulesParam(teamId, "tech_t3_threshold")
  local level = tonumber(rawLevel or 1) or 1
  return {
    level = level,
    points = tonumber(rawPoints or 0) or 0,
    t2Threshold = tonumber(rawT2 or 0) or 0,
    t3Threshold = tonumber(rawT3 or 0) or 0,
    nextLevel = level < 2 and 2 or 3,
    nextThreshold = level < 2 and (tonumber(rawT2 or 0) or 0) or (tonumber(rawT3 or 0) or 0),
  }
end

---@param policy {senderTeamId: number, techBlocking: TechBlockingContext?}
---@return TechBlockingContext?
function TechBlockingComms.fromPolicy(policy)
  if policy.techBlocking then return policy.techBlocking end
  return TechBlockingComms.fromTeamRules(policy.senderTeamId)
end

return TechBlockingComms
