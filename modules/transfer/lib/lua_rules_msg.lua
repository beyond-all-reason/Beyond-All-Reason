
local LuaRulesMsg = {}

local RESOURCE_SHARE_PREFIX = "share:resource:"

---`share:resource:0:1:metal:100` — team 0 gives team 1 100 metal.
---@param senderTeamID number
---@param targetTeamID number
---@param resourceType string
---@param amount number
---@return string
function LuaRulesMsg.SerializeResourceShare(senderTeamID, targetTeamID, resourceType, amount)
	return RESOURCE_SHARE_PREFIX .. senderTeamID .. ":" .. targetTeamID .. ":" .. resourceType .. ":" .. amount
end

---The inverse of SerializeResourceShare: `share:resource:0:1:metal:100`
---becomes { senderTeamID = 0, targetTeamID = 1, resourceType = "metal",
---amount = 100 }. Split on every colon, the prefix is parts 1 and 2.
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
		amount = amount,
	}
end

local UNIT_TRANSFER_PREFIX = "share:units:"

---@class UnitTransferParams
---@field targetTeamID number
---@field unitIDs number[]

---`share:units:1:1043,1044,1051` — give units 1043, 1044 and 1051 to team 1.
---@param targetTeamID number
---@param unitIDs number[]
---@return string
function LuaRulesMsg.SerializeUnitTransfer(targetTeamID, unitIDs)
	return UNIT_TRANSFER_PREFIX .. targetTeamID .. ":" .. table.concat(unitIDs, ",")
end

---The inverse of SerializeUnitTransfer: `share:units:1:1043,1044,1051`
---becomes { targetTeamID = 1, unitIDs = { 1043, 1044, 1051 } }.
---@param msg string
---@return UnitTransferParams|nil params nil if not a unit transfer message or invalid
function LuaRulesMsg.ParseUnitTransfer(msg)
	if msg:sub(1, #UNIT_TRANSFER_PREFIX) ~= UNIT_TRANSFER_PREFIX then
		return nil
	end

	local rest = msg:sub(#UNIT_TRANSFER_PREFIX + 1)
	local colonPos = rest:find(":")
	if not colonPos then
		return nil
	end

	local targetTeamID = tonumber(rest:sub(1, colonPos - 1))
	if not targetTeamID then
		return nil
	end

	local unitIDsStr = rest:sub(colonPos + 1)
	local unitIDs = {}
	for idStr in unitIDsStr:gmatch("[^,]+") do
		local id = tonumber(idStr)
		if id then
			unitIDs[#unitIDs + 1] = id
		end
	end

	if #unitIDs == 0 then
		return nil
	end

	return {
		targetTeamID = targetTeamID,
		unitIDs = unitIDs,
	}
end

return LuaRulesMsg
