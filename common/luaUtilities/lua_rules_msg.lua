--------------------------------------------------------------------------------
-- LuaRulesMsg serialization/parsing for widget↔gadget communication
-- Keeps the wire format in one place
--------------------------------------------------------------------------------

local LuaRulesMsg = {}

--------------------------------------------------------------------------------
-- Resource Share Messages
--------------------------------------------------------------------------------

local RESOURCE_SHARE_PREFIX = "share:resource:"

---Serialize a resource share request for SendLuaRulesMsg
---@param senderTeamID number
---@param targetTeamID number
---@param resourceType string
---@param amount number
---@return string
function LuaRulesMsg.SerializeResourceShare(senderTeamID, targetTeamID, resourceType, amount)
  return RESOURCE_SHARE_PREFIX .. senderTeamID .. ":" .. targetTeamID .. ":" .. resourceType .. ":" .. amount
end

---Parse a resource share message from RecvLuaMsg
---@param msg string
---@return ResourceShareParams|nil params nil if not a resource share message or invalid
function LuaRulesMsg.ParseResourceShare(msg)
  if msg:sub(1, #RESOURCE_SHARE_PREFIX) ~= RESOURCE_SHARE_PREFIX then
    return nil
  end

  local parts = {}
  for part in msg:gmatch("[^:]+") do
    parts[#parts + 1] = part
  end

  if #parts < 6 then
    return nil
  end

  local senderTeamID = tonumber(parts[3])
  local targetTeamID = tonumber(parts[4])
  local resourceType = parts[5]
  local amount = tonumber(parts[6])

  if not senderTeamID or not targetTeamID or not resourceType or not amount or amount <= 0 then
    return nil
  end

  return {
    senderTeamID = senderTeamID,
    targetTeamID = targetTeamID,
    resourceType = resourceType,
    amount = amount
  }
end

return LuaRulesMsg


