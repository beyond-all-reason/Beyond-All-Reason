--------------------------------------------------------------------------------
-- Economy Audit Logger
-- Structured logging for economy analysis via C++ EconomyAudit system.
-- Logs output as: [EconomyAudit] <event_type> <json_data>
--
-- source_path, frame, and game_time are auto-injected by C++.
--
-- Enable via springsettings.cfg: LogSections = EconomyAudit:30
--
-- NOTE: When disabled, all functions are no-ops (zero overhead).
-- NOTE: Passes flat key-value pairs to C++ to avoid Lua table/JSON overhead.
--------------------------------------------------------------------------------

local EconomyLog = {}

-- Check if audit is enabled at load time
-- If disabled, all functions become no-ops with zero overhead
local ENABLED = Spring.IsEconomyAuditEnabled and Spring.IsEconomyAuditEnabled() or false

if not ENABLED then
  -- No-op stubs - zero overhead in production
  local function noop() end
  EconomyLog.FrameStart = noop
  EconomyLog.TeamInput = noop
  EconomyLog.GroupLift = noop
  EconomyLog.Transfer = noop
  EconomyLog.TeamWaterfill = noop
  EconomyLog.TeamOutput = noop
  EconomyLog.FrameEnd = noop
  EconomyLog.TeamInfo = noop
  EconomyLog.StorageCapped = noop
  EconomyLog.Breakpoint = noop
  return EconomyLog
end

--------------------------------------------------------------------------------
-- Structured Log Events
-- C++ auto-injects: source_path, frame, game_time
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

function EconomyLog.TeamInfo(teamId, name, isAI)
  Spring.EconomyAuditLog("team_info",
    "team_id", teamId,
    "name", name,
    "is_ai", isAI
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

return EconomyLog
