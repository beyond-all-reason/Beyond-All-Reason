---
--- Gather waits in mission orders. The engine runs them only for a player's selected units, on that
--- player's client, so a mission's units wait for each other here.
---

local table_keys = table.keys
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand

-- As often as the engine checks a player's gather waits.
local UPDATE_INTERVAL_FRAMES = 3

---@type table<integer, boolean> Factories hand their orders to the units they build.
local canGatherByUnitDefID = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	canGatherByUnitDefID[unitDefID] = unitDef.canMove and not unitDef.isFactory
end

-- Keys count down, since a player's wait keys are positive when they are read as a float.
local lastGatherKey = 0

---@type table<number, table<integer, true>>
local unitIDsByGatherKey = {}

---@return table gatherOrders the orders with each GATHERWAIT as a CMD.WAIT tagged for the engine
---@return number[] gatherKeys
local function tagGatherWaits(orders)
	local gatherOrders, gatherKeys = {}, {}
	for index, order in ipairs(orders) do
		if order[1] == CMD.GATHERWAIT then
			lastGatherKey = lastGatherKey - 1
			gatherKeys[#gatherKeys + 1] = lastGatherKey
			gatherOrders[index] = { CMD.WAIT, { CMD.WAITCODE_GATHER, lastGatherKey }, order[3] }
		else
			gatherOrders[index] = order
		end
	end
	return gatherOrders, gatherKeys
end

---@return integer? queueIndex nil when the unit is gone or has lost the wait
local function getGatherWaitQueueIndex(unitID, gatherKey)
	local queueIndex = 0
	repeat
		queueIndex = queueIndex + 1
		local commandID, _, _, waitCode, waitKey = spGetUnitCurrentCommand(unitID, queueIndex)
		if commandID == CMD.WAIT and waitCode == CMD.WAITCODE_GATHER and waitKey == gatherKey then
			return queueIndex
		end
	until commandID == nil
end

--- At each GATHERWAIT, the units wait until all of them have reached it. Units that cannot gather
--- skip it.
---@param unitIDs table<integer, true>
---@param orders table
local function giveOrdersWithGatherWaits(unitIDs, orders)
	local gatherOrders, gatherKeys = tagGatherWaits(orders)
	if #gatherKeys == 0 then
		Spring.GiveOrderArrayToUnitMap(unitIDs, orders)
		return
	end

	local gatheringUnitIDs, otherUnitIDs = {}, {}
	for unitID in pairs(unitIDs) do
		if canGatherByUnitDefID[Spring.GetUnitDefID(unitID)] then
			gatheringUnitIDs[unitID] = true
		else
			otherUnitIDs[unitID] = true
		end
	end

	Spring.GiveOrderArrayToUnitMap(gatheringUnitIDs, gatherOrders)
	Spring.GiveOrderArrayToUnitMap(otherUnitIDs, orders)

	for _, gatherKey in ipairs(gatherKeys) do
		unitIDsByGatherKey[gatherKey] = table.copy(gatheringUnitIDs)
	end
end

local function updateGatherWaits(frameNumber)
	if frameNumber % UPDATE_INTERVAL_FRAMES ~= 0 then
		return
	end

	-- Releasing units can fire triggers that give new gather waits.
	for _, gatherKey in ipairs(table_keys(unitIDsByGatherKey)) do
		local unitIDs = unitIDsByGatherKey[gatherKey]
		local isGathered = true
		for unitID in pairs(unitIDs) do
			local queueIndex = getGatherWaitQueueIndex(unitID, gatherKey)
			if queueIndex == nil then
				unitIDs[unitID] = nil
			elseif queueIndex > 1 then
				isGathered = false
				break
			end
		end

		if isGathered then
			unitIDsByGatherKey[gatherKey] = nil
			-- Fence around mission-issued orders for UnitOrdered triggers using `ignoreMissionActions`.
			GG["MissionAPI"].issuingOrders = true
			-- Without shift, this lifts the wait that each unit is holding at.
			Spring.GiveOrderToUnitMap(unitIDs, CMD.WAIT, {}, {})
			GG["MissionAPI"].issuingOrders = nil
		end
	end
end

return {
	GiveOrdersWithGatherWaits = giveOrdersWithGatherWaits,
	UpdateGatherWaits = updateGatherWaits,
}
