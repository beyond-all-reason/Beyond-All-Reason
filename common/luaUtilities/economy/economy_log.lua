--------------------------------------------------------------------------------
-- Economy Audit Logger
-- Structured logging for economy analysis via C++ EconomyAudit system.
-- Logs output as: [EconomyAudit] <event_type> <json_data>
--
-- source_path, frame, and game_time are auto-injected by C++.
--
-- Enable via springsettings.cfg: LogSections = EconomyAudit:30
--------------------------------------------------------------------------------

local EconomyLog = {}

local cachedEnabled = nil

local function IsEnabled()
  if cachedEnabled == nil then
    cachedEnabled = Spring.IsEconomyAuditEnabled()
  end
  return cachedEnabled
end

local activeZoneStack = {}
local tracyAvailable = tracy and tracy.ZoneBeginN and tracy.ZoneEnd

--------------------------------------------------------------------------------
-- Structured Log Events (require active audit context)
--------------------------------------------------------------------------------

function EconomyLog.FrameStart(taxRate, metalThreshold, energyThreshold, teamCount)
  if not IsEnabled() then return end
  Spring.EconomyAuditLog("frame_start",
    "tax_rate", taxRate,
    "metal_threshold", metalThreshold,
    "energy_threshold", energyThreshold,
    "team_count", teamCount
  )
end

function EconomyLog.TeamInput(teamId, allyTeam, resourceType, current, storage, shareSlider, cumulativeSent, shareCursor)
  if not IsEnabled() then return end
  Spring.EconomyAuditLog("team_input",
    "team_id", teamId,
    "ally_team", allyTeam,
    "resource", resourceType,
    "current", current,
    "storage", storage,
    "share_slider", shareSlider,
    "cumulative_sent", cumulativeSent,
    "share_cursor", shareCursor
  )
end

function EconomyLog.GroupLift(allyTeam, resourceType, lift, memberCount, totalSupply, totalDemand, senderCount, receiverCount)
  if not IsEnabled() then return end
  Spring.EconomyAuditLog("group_lift",
    "ally_team", allyTeam,
    "resource", resourceType,
    "lift", lift,
    "member_count", memberCount,
    "total_supply", totalSupply,
    "total_demand", totalDemand,
    "sender_count", senderCount or 0,
    "receiver_count", receiverCount or 0
  )
end

--------------------------------------------------------------------------------
-- Transfer: Can be called outside ProcessEconomy context (e.g., manual transfers)
-- Uses EconomyAuditLogRaw since it doesn't require active context
--------------------------------------------------------------------------------
function EconomyLog.Transfer(senderTeamId, receiverTeamId, resourceType, amount, untaxed, taxed, transferType)
  if not IsEnabled() then return end
  local frame = Spring.GetGameFrame()
  Spring.EconomyAuditLogRaw("transfer",
    "frame", frame,
    "game_time", frame / 30.0,
    "sender_team_id", senderTeamId,
    "receiver_team_id", receiverTeamId,
    "resource", resourceType,
    "amount", amount,
    "untaxed", untaxed,
    "taxed", taxed,
    "transfer_type", transferType or "active"
  )
end

function EconomyLog.TeamWaterfill(teamId, allyTeam, resourceType, current, target, role, delta)
  if not IsEnabled() then return end
  Spring.EconomyAuditLog("team_waterfill",
    "team_id", teamId,
    "ally_team", allyTeam,
    "resource", resourceType,
    "current", current,
    "target", target,
    "role", role,
    "delta", delta
  )
end

function EconomyLog.TeamOutput(teamId, resourceType, current, sent, received)
  if not IsEnabled() then return end
  Spring.EconomyAuditLog("team_output",
    "team_id", teamId,
    "resource", resourceType,
    "current", current,
    "sent", sent,
    "received", received
  )
end

function EconomyLog.FrameEnd(solverTimeUs, totalTimeUs)
  if not IsEnabled() then return end
  Spring.EconomyAuditLog("frame_end",
    "solver_time_us", solverTimeUs,
    "total_time_us", totalTimeUs
  )
end

function EconomyLog.StorageCapped(teamId, resourceType, current, storage)
  if not IsEnabled() then return end
  Spring.EconomyAuditLog("storage_capped",
    "team_id", teamId,
    "resource", resourceType,
    "current", current,
    "storage", storage
  )
end

function EconomyLog.Breakpoint(name)
  if tracyAvailable then
    tracy.ZoneBeginN("Eco:" .. name)
    activeZoneStack[#activeZoneStack + 1] = name
  end
  -- TODO: delete me, this is emulating tracy
  if IsEnabled() then
    Spring.EconomyAuditBreakpoint(name)
  end
end

function EconomyLog.BreakpointEnd()
  if tracyAvailable and #activeZoneStack > 0 then
    Spring.Echo("BreakpointEnd: " .. activeZoneStack[#activeZoneStack])
    tracy.ZoneEnd()
    activeZoneStack[#activeZoneStack] = nil
  end
end

--------------------------------------------------------------------------------
-- TeamInfo: Called from Initialize(), NOT inside ProcessEconomy context
-- Uses EconomyAuditLogRaw since it doesn't require active context
--------------------------------------------------------------------------------

function EconomyLog.TeamInfo(teamId, name, isAI, allyTeam, isGaia)
  if not IsEnabled() then return end
  Spring.EconomyAuditLogRaw("team_info",
    "team_id", teamId,
    "name", tostring(name),
    "is_ai", isAI,
    "ally_team", allyTeam,
    "is_gaia", isGaia
  )
end

return EconomyLog
