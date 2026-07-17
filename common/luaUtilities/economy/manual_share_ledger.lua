local M = {}

local ledger = {} ---@type table<number, table<ResourceName, {sent: number, received: number}>>

local function entry(teamId, resourceType)
	local perTeam = ledger[teamId]
	if not perTeam then
		perTeam = {}
		ledger[teamId] = perTeam
	end
	local e = perTeam[resourceType]
	if not e then
		e = { sent = 0, received = 0 }
		perTeam[resourceType] = e
	end
	return e
end

---@param senderTeamId number
---@param receiverTeamId number
---@param resourceType ResourceName
---@param sent number
---@param received number
function M.Record(senderTeamId, receiverTeamId, resourceType, sent, received)
	local s = entry(senderTeamId, resourceType)
	s.sent = s.sent + sent
	local r = entry(receiverTeamId, resourceType)
	r.received = r.received + received
end

--- Fold accumulated manual-share stats into the redistribution result entries, then clear.
---@param results EconomyTeamResult[]
function M.FoldInto(results)
	if not next(ledger) then
		return results
	end
	for i = 1, #results do
		local result = results[i]
		local perTeam = ledger[result.teamId] ---@type table<ResourceName, {sent: number, received: number}>? sparse per-team ledger
		local e = perTeam and perTeam[result.resourceType]
		if e then
			result.sent = result.sent + e.sent
			result.received = result.received + e.received
			e.sent = 0
			e.received = 0
		end
	end
	return results
end

function M.Clear()
	for teamId, perTeam in pairs(ledger) do
		for resourceType, e in pairs(perTeam) do
			e.sent = 0
			e.received = 0
		end
	end
end

return M
