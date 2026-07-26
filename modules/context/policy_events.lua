local PolicyEvents = {}

local lastSignature = {}

---@param teamId number
---@param domain PolicyType the policy domain that changed (TransferEnums.PolicyType value)
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
		return false
	end

	local send = sendToUnsynced or SendToUnsynced ---@type function? absent outside the synced gadget context
	if send then
		send("SharePolicyChanged", teamId, domain)
	end
	return true
end

---@param unitID number
---@param startFrame number
---@param expireFrame number
---@param sendToUnsynced function? defaults to the synced SendToUnsynced global (injectable for tests)
function PolicyEvents.NotifyBuildDelay(unitID, startFrame, expireFrame, sendToUnsynced)
	local send = sendToUnsynced or SendToUnsynced ---@type function? absent outside the synced gadget context
	if send then
		send("UnitBuildDelayStarted", unitID, startFrame, expireFrame)
	end
end

---@param unitID number
---@param sendToUnsynced function? defaults to the synced SendToUnsynced global (injectable for tests)
function PolicyEvents.NotifyBuildDelayEnd(unitID, sendToUnsynced)
	local send = sendToUnsynced or SendToUnsynced ---@type function? absent outside the synced gadget context
	if send then
		send("UnitBuildDelayEnded", unitID)
	end
end

return PolicyEvents
