--------------------------------------------------------------------------------
-- Economy Audit Logger
-- Outputs structured logs for parsing into SQLite for bulk analysis
-- Format: [EconomyAudit] <table_name> <json_row>
--------------------------------------------------------------------------------

local AuditLog = {}

local ENABLED = true
local LOG_PREFIX = "[EconomyAudit]"

--------------------------------------------------------------------------------
-- Audit Log Modes
-- The mode is controlled at the engine level via modrules.lua economy_audit_mode
-- These functions query the engine to determine which path should be active
--------------------------------------------------------------------------------

---Get the configured audit mode from the engine
---@return string "off" | "process_economy" | "resource_excess" | "alternate"
function AuditLog.GetMode()
  return Game.economyAuditMode or "off"
end

---Check if ProcessEconomy path should be active
---Delegates to the engine's Spring.IsProcessEconomyActive()
---@param frame number? Optional frame number (defaults to current frame)
---@return boolean
function AuditLog.IsProcessEconomyActive(frame)
  return Spring.IsProcessEconomyActive(frame)
end

---Check if ResourceExcess path should be active  
---Delegates to the engine's Spring.IsResourceExcessActive()
---@param frame number? Optional frame number (defaults to current frame)
---@return boolean
function AuditLog.IsResourceExcessActive(frame)
  return Spring.IsResourceExcessActive(frame)
end

---@param value any
---@return string
local function toJson(value)
  local t = type(value)
  if t == "nil" then
    return "null"
  elseif t == "boolean" then
    return value and "true" or "false"
  elseif t == "number" then
    if value ~= value then return "null" end -- NaN
    if value == math.huge or value == -math.huge then return "null" end
    return string.format("%.4f", value)
  elseif t == "string" then
    return '"' .. value:gsub('"', '\\"') .. '"'
  elseif t == "table" then
    local isArray = #value > 0
    if isArray then
      local parts = {}
      for i, v in ipairs(value) do
        parts[i] = toJson(v)
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      local parts = {}
      for k, v in pairs(value) do
        parts[#parts + 1] = '"' .. tostring(k) .. '":' .. toJson(v)
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end
  return "null"
end

---@param tableName string SQL table name
---@param row table Row data as key-value pairs
local function logRow(tableName, row)
  if not ENABLED then return end
  Spring.Echo(LOG_PREFIX .. " " .. tableName .. " " .. toJson(row))
end

--------------------------------------------------------------------------------
-- Audit Tables
--------------------------------------------------------------------------------

---Log frame start with config
---@param frame number
---@param taxRate number
---@param metalThreshold number
---@param energyThreshold number
---@param teamCount number
function AuditLog.FrameStart(frame, taxRate, metalThreshold, energyThreshold, teamCount)
  logRow("frame_start", {
    frame = frame,
    tax_rate = taxRate,
    metal_threshold = metalThreshold,
    energy_threshold = energyThreshold,
    team_count = teamCount
  })
end

---Log input team state before processing
---@param frame number
---@param teamId number
---@param allyTeam number
---@param resourceType string
---@param current number
---@param storage number
---@param shareSlider number
---@param cumulativeSent number
---@param shareCursor number? The computed share threshold (storage * shareSlider)
function AuditLog.TeamInput(frame, teamId, allyTeam, resourceType, current, storage, shareSlider, cumulativeSent, shareCursor)
  logRow("team_input", {
    frame = frame,
    team_id = teamId,
    ally_team = allyTeam,
    resource = resourceType,
    current = current,
    storage = storage,
    share_slider = shareSlider,
    cumulative_sent = cumulativeSent,
    share_cursor = shareCursor or (storage * shareSlider)
  })
end

---Log waterfill lift calculation per ally group
---@param frame number
---@param allyTeam number
---@param resourceType string
---@param lift number
---@param memberCount number
---@param totalSupply number
---@param totalDemand number
function AuditLog.GroupLift(frame, allyTeam, resourceType, lift, memberCount, totalSupply, totalDemand)
  logRow("group_lift", {
    frame = frame,
    ally_team = allyTeam,
    resource = resourceType,
    lift = lift,
    member_count = memberCount,
    total_supply = totalSupply,
    total_demand = totalDemand
  })
end

---Log individual transfer
---@param frame number
---@param senderTeamId number
---@param receiverTeamId number
---@param resourceType string
---@param amount number
---@param untaxed number
---@param taxed number
function AuditLog.Transfer(frame, senderTeamId, receiverTeamId, resourceType, amount, untaxed, taxed)
  logRow("transfer", {
    frame = frame,
    sender_team_id = senderTeamId,
    receiver_team_id = receiverTeamId,
    resource = resourceType,
    amount = amount,
    untaxed = untaxed,
    taxed = taxed
  })
end

---Log per-team waterfill state after lift resolution
---@param frame number
---@param teamId number
---@param allyTeam number
---@param resourceType string
---@param current number Current resource level
---@param target number Computed target (shareCursor + lift, capped at storage)
---@param role string "sender", "receiver", or "neutral"
---@param delta number Amount to send (positive) or receive (negative)
function AuditLog.TeamWaterfill(frame, teamId, allyTeam, resourceType, current, target, role, delta)
  logRow("team_waterfill", {
    frame = frame,
    team_id = teamId,
    ally_team = allyTeam,
    resource = resourceType,
    current = current,
    target = target,
    role = role,
    delta = delta
  })
end

---Log output team state after processing
---@param frame number
---@param teamId number
---@param resourceType string
---@param current number
---@param sent number
---@param received number
function AuditLog.TeamOutput(frame, teamId, resourceType, current, sent, received)
  logRow("team_output", {
    frame = frame,
    team_id = teamId,
    resource = resourceType,
    current = current,
    sent = sent,
    received = received
  })
end

---Log frame timing summary
---@param frame number
---@param solverTimeUs number
---@param totalTimeUs number
function AuditLog.FrameEnd(frame, solverTimeUs, totalTimeUs)
  logRow("frame_end", {
    frame = frame,
    solver_time_us = solverTimeUs,
    total_time_us = totalTimeUs
  })
end

---Enable or disable audit logging
---@param enabled boolean
function AuditLog.SetEnabled(enabled)
  ENABLED = enabled
end

---Check if audit logging is enabled
---@return boolean
function AuditLog.IsEnabled()
  return ENABLED
end

return AuditLog

