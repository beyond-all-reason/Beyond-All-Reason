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

local function IsEnabled()
  return Spring.IsEconomyAuditEnabled and Spring.IsEconomyAuditEnabled()
end

--------------------------------------------------------------------------------
-- Structured Log Events (require active audit context)
--------------------------------------------------------------------------------

function EconomyLog.FrameStart(taxRate, metalThreshold, energyThreshold, teamCount)
  Spring.EconomyAuditLog("frame_start",
    "tax_rate", taxRate,
    "metal_threshold", metalThreshold,
    "energy_threshold", energyThreshold,
    "team_count", teamCount
  )
end

function EconomyLog.TeamInput(teamId, allyTeam, resourceType, current, storage, shareSlider, cumulativeSent, shareCursor)
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

function EconomyLog.GroupLift(allyTeam, resourceType, lift, memberCount, totalSupply, totalDemand)
  Spring.EconomyAuditLog("group_lift",
    "ally_team", allyTeam,
    "resource", resourceType,
    "lift", lift,
    "member_count", memberCount,
    "total_supply", totalSupply,
    "total_demand", totalDemand
  )
end

function EconomyLog.Transfer(senderTeamId, receiverTeamId, resourceType, amount, untaxed, taxed)
  Spring.EconomyAuditLog("transfer",
    "sender_team_id", senderTeamId,
    "receiver_team_id", receiverTeamId,
    "resource", resourceType,
    "amount", amount,
    "untaxed", untaxed,
    "taxed", taxed
  )
end

function EconomyLog.TeamWaterfill(teamId, allyTeam, resourceType, current, target, role, delta)
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
  Spring.EconomyAuditLog("team_output",
    "team_id", teamId,
    "resource", resourceType,
    "current", current,
    "sent", sent,
    "received", received
  )
end

function EconomyLog.FrameEnd(solverTimeUs, totalTimeUs)
  Spring.EconomyAuditLog("frame_end",
    "solver_time_us", solverTimeUs,
    "total_time_us", totalTimeUs
  )
end

function EconomyLog.StorageCapped(teamId, resourceType, current, storage)
  Spring.EconomyAuditLog("storage_capped",
    "team_id", teamId,
    "resource", resourceType,
    "current", current,
    "storage", storage
  )
end

function EconomyLog.Breakpoint(name)
  Spring.EconomyAuditBreakpoint(name)
end

--------------------------------------------------------------------------------
-- TeamInfo: Called from Initialize(), NOT inside ProcessEconomy context
-- Uses Spring.Log directly since EconomyAuditLog requires active context
--------------------------------------------------------------------------------

function EconomyLog.TeamInfo(teamId, name, isAI)
  if not IsEnabled() then return end
  local json = string.format('{"team_id":%d,"name":"%s","is_ai":%s}', 
    teamId, tostring(name):gsub('"', '\\"'), isAI and "true" or "false")
  Spring.Log("EconomyAudit", LOG.INFO, "team_info " .. json)
end

return EconomyLog
