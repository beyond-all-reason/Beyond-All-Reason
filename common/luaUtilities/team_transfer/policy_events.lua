-- Emits a generic "SharePolicyChanged" event when a team's cached sharing policy changes,
-- forwarded to widgets via game_share_policy_forwarding.lua -> widget:SharePolicyChanged.
local PolicyEvents = {}

PolicyEvents.Domain = {
  Unit = "unit",
  Metal = "metal",
  Energy = "energy",
}

-- domain -> (teamId -> last signature seen). Lives for the synced state's lifetime.
local lastSignature = {}

---Emit SharePolicyChanged(teamId, domain) when the signature changes; first observation is silent.
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

return PolicyEvents
