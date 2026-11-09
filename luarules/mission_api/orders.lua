---
--- Gives mission orders. Orders may use GATHERWAIT, which makes the units given the orders wait for each other.
---

local table_keys = table.keys
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand

local UPDATE_INTERVAL_FRAMES = 3 -- matches `updatePeriod` in WaitCommandsAI.cpp

---@type table<integer, boolean>
local canGatherByUnitDefID = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	-- Factories hand their orders on to the units they build, so they never hold at a wait.
	canGatherByUnitDefID[unitDefID] = unitDef.canMove and not unitDef.isFactory
end

-- Negative keys can never equal a player's own wait keys.
local lastGatherKey = 0

---@type table<number, table<integer, true>>
local unitIDsByGatherKey = {}

---@param orders CreateCommand[]
---@return CreateCommand[] gatherOrders the orders, with each GATHERWAIT replaced by a keyed CMD.WAIT
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

--- At each GATHERWAIT, the units wait until all of them have reached it. Factories and units that
--- cannot move skip it.
---@param unitIDs table<integer, true>
---@param orders CreateCommand[]
local function giveOrders(unitIDs, orders)
	-- Fence around mission-issued orders for UnitOrdered triggers using `ignoreMissionActions`.
	GG["MissionAPI"].issuingOrders = true

	local gatherOrders, gatherKeys = tagGatherWaits(orders)
	if #gatherKeys == 0 then
		Spring.GiveOrderArrayToUnitMap(unitIDs, orders)
		GG["MissionAPI"].issuingOrders = nil
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
	GG["MissionAPI"].issuingOrders = nil

	for _, gatherKey in ipairs(gatherKeys) do
		unitIDsByGatherKey[gatherKey] = table.copy(gatheringUnitIDs)
	end
end

local function updateWaits(frameNumber)
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
			-- Triggers using `ignoreMissionActions` must not react to this mission order.
			GG["MissionAPI"].issuingOrders = true
			-- A second WAIT cancels the first, which releases the units.
			Spring.GiveOrderToUnitMap(unitIDs, CMD.WAIT, {}, {})
			GG["MissionAPI"].issuingOrders = nil
		end
	end
end

return {
	GiveOrders = giveOrders,
	UpdateWaits = updateWaits,
}
