local BuildEvents = {}

---@param unitID number
---@param startFrame number
---@param expireFrame number
---@param sendToUnsynced function? defaults to the synced SendToUnsynced global (injectable for tests)
function BuildEvents.NotifyBuildDelay(unitID, startFrame, expireFrame, sendToUnsynced)
	local send = sendToUnsynced or SendToUnsynced ---@type function? absent outside the synced gadget context
	if send then
		send("UnitBuildDelayStarted", unitID, startFrame, expireFrame)
	end
end

---@param unitID number
---@param sendToUnsynced function? defaults to the synced SendToUnsynced global (injectable for tests)
function BuildEvents.NotifyBuildDelayEnd(unitID, sendToUnsynced)
	local send = sendToUnsynced or SendToUnsynced ---@type function? absent outside the synced gadget context
	if send then
		send("UnitBuildDelayEnded", unitID)
	end
end

return BuildEvents
