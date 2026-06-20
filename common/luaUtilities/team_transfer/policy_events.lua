-- Synced-side surface for sharing-policy events forwarded to widgets via
-- game_share_policy_forwarding.lua. Covers team policy changes (SharePolicyChanged)
-- and the per-unit build-delay debuff that the constructor-build-delay policy applies.
local PolicyEvents = {}

PolicyEvents.Domain = {
  Unit = "unit",
  Metal = "metal",
  Energy = "energy",
}

-- domain -> (teamId -> last signature seen). Lives for the synced state's lifetime.
local lastSignature = {}

---Emit SharePolicyChanged(teamId, domain) when this team's signature changes; the first
---observation is recorded silently so game start does not spam widgets.
---@param teamId number
---@param domain string one of PolicyEvents.Domain
---@param signature string policy-relevant signature; identical strings count as no change
---@param sendToUnsynced function? defaults to the synced SendToUnsynced global (injectable for tests)
---@return boolean changed
function PolicyEvents.NotifyIfChanged(teamId, domain, signature, sendToUnsynced)
  local byTeam = lastSignature[domain]
  if not byTeam then
    byTeam = {}
    lastSignature[domain] = byTeam
  end

  local previous = byTeam[teamId]
  if previous == signature then
    return false
  end
  byTeam[teamId] = signature

  if previous == nil then
    return false -- first observation: record baseline without emitting
  end

  local send = sendToUnsynced or SendToUnsynced
  if send then
    send("SharePolicyChanged", teamId, domain)
  end
  return true
end

---Per-unit manifestation of the constructor-build-delay policy: a builder gained the
---buildspeed debuff for [startFrame, expireFrame).
---@param unitID number
---@param startFrame number
---@param expireFrame number
---@param sendToUnsynced function? defaults to the synced SendToUnsynced global (injectable for tests)
function PolicyEvents.NotifyBuildDelay(unitID, startFrame, expireFrame, sendToUnsynced)
  local send = sendToUnsynced or SendToUnsynced
  if send then
    send("UnitBuildDelayStarted", unitID, startFrame, expireFrame)
  end
end

---The build-delay debuff on a unit ended (expired or unit gone).
---@param unitID number
---@param sendToUnsynced function? defaults to the synced SendToUnsynced global (injectable for tests)
function PolicyEvents.NotifyBuildDelayEnd(unitID, sendToUnsynced)
  local send = sendToUnsynced or SendToUnsynced
  if send then
    send("UnitBuildDelayEnded", unitID)
  end
end

return PolicyEvents
