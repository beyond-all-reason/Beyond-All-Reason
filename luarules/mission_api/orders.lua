---
--- Gives mission orders. Orders may be reissued in different or encoded forms from their authored specification.
---

local table_keys = table.keys

local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitIsDead = Spring.GetUnitIsDead

local trackedUnitIDs = GG.MissionAPI.trackedUnitIDs
local trackedFeatureIDs = GG.MissionAPI.trackedFeatureIDs

local UPDATE_INTERVAL_FRAMES = 3 -- matches `updatePeriod` in WaitCommandsAI.cpp

local canGather = {} ---@type table<UnitDefID, true?>
local isFactory = {} ---@type table<UnitDefID, true?>
for unitDefID, unitDef in pairs(UnitDefs) do
	canGather[unitDefID] = unitDef.canMove and not unitDef.isFactory or nil
	isFactory[unitDefID] = unitDef.isFactory or nil
end

-- Name conversions ------------------------------------------------------------

local commandTargetsNames = {
	[CMD.GUARD] = true,
	[CMD.REPAIR] = true,
	[CMD.CAPTURE] = true,
	[CMD.ATTACK] = true,
	[CMD.LOAD_UNITS] = true,
	[CMD.RECLAIM] = true,
	[CMD.RESURRECT] = true,
}

local function convertOrdersTargetingNames(orders)
	local newOrders = {}

	for _, order in ipairs(orders or {}) do
		local commandID = order[1]
		local params = order[2]

		if commandTargetsNames[commandID] and type(params) == "table" and (params.unitName or params.featureName) then
			local thingIDs
			local offset = 0
			if params.featureName then
				thingIDs = trackedFeatureIDs[params.featureName]
				if not Engine.FeatureSupport.noOffsetForFeatureID then
					offset = Game.maxUnits
				end
			elseif params.unitName then
				thingIDs = trackedUnitIDs[params.unitName]
			end

			local options = table.copy(order[3] or {})
			local queuedOptions = table.copy(options)
			if not table.contains(queuedOptions, "shift") then
				queuedOptions[#queuedOptions + 1] = "shift"
			end
			local targetOptions = options
			for thingID in pairs(thingIDs or {}) do
				newOrders[#newOrders + 1] = { commandID, thingID + offset, targetOptions }
				targetOptions = queuedOptions
			end
		else
			newOrders[#newOrders + 1] = order
		end
	end

	return newOrders
end

-- Command conversions ---------------------------------------------------------

---@alias MissionWait MissionTimeWait | MissionDeathWait | MissionSquadWait | MissionGatherWait

---@class MissionWaitBase
---@field unitIDs table<UnitID, true>
---@field factoryIDs table<UnitID, true>

---@class MissionTimeWait : MissionWaitBase
---@field code 1 CMD.WAITCODE_TIME
---@field duration integer frames
---@field startFrames table<UnitID, integer>

---@alias MissionDeathWait MissionDeathWaitInRectangle | MissionDeathWaitOnUnitName

---@class MissionDeathWaitInRectangle : MissionWaitBase
---@field code 2 CMD.WAITCODE_DEATH
---@field targetIDs table<integer, true>
---@field targetRectangle WorldRect

---@class MissionDeathWaitOnUnitName : MissionWaitBase
---@field code 2 CMD.WAITCODE_DEATH
---@field targetUnitName string
---@field orderedUnitIDs table<UnitID, true> excluded from being targets
---@field areTargetsDead boolean

---@class MissionSquadWait : MissionWaitBase
---@field code 3 CMD.WAITCODE_SQUAD
---@field squadSize integer

---@class MissionGatherWait : MissionWaitBase
---@field code 4 CMD.WAITCODE_GATHER

local waits = {} ---@type table<number, MissionWait?>
local factoryWaitKeys = {} ---@type table<UnitID, table<number, true>>
local lastWaitKey = 0 -- Uses negative keys, which never conflict with player-issued wait keys.

local commandWaitCode = {
	[CMD.TIMEWAIT] = CMD.WAITCODE_TIME,
	[CMD.DEATHWAIT] = CMD.WAITCODE_DEATH,
	[CMD.SQUADWAIT] = CMD.WAITCODE_SQUAD,
	[CMD.GATHERWAIT] = CMD.WAITCODE_GATHER,
}

---@param orders CreateCommand[]
---@param newWaits table<number, MissionWait>
---@param positionWaitKey table<integer, number>
---@return CreateCommand[] waitOrders
local function expandWaitOrders(orders, newWaits, positionWaitKey)
	local waitOrders, position = {}, 0

	for index, order in ipairs(orders) do
		local commandID, params = order[1], order[2] ---@as table
		local asInsert = commandID == CMD.INSERT and type(params) == "table"
		local code = commandWaitCode[asInsert and params[2] or commandID] ---@as 1|2|3|4?
		if code then
			local waitParams = params
			if asInsert then
				waitParams = {}
				for paramIndex = 4, #params do
					waitParams[#waitParams + 1] = params[paramIndex]
				end
			end

			position = position + 1
			local key = positionWaitKey[position]
			if key == nil or newWaits[key].code ~= code then
				lastWaitKey = lastWaitKey - 1
				key = lastWaitKey
				positionWaitKey[position] = positionWaitKey[position] or key
				local wait = { code = code, unitIDs = {}, factoryIDs = {} } ---@as MissionWait
				if code == CMD.WAITCODE_TIME then
					wait.duration = (waitParams[1] * Game.gameSpeed) ---@as integer
					wait.startFrames = {}
				elseif code == CMD.WAITCODE_DEATH and waitParams.unitName then
					wait.targetUnitName = waitParams.unitName
				elseif code == CMD.WAITCODE_DEATH then
					wait.targetRectangle = waitParams ---@as WorldRect
				elseif code == CMD.WAITCODE_SQUAD then
					wait.squadSize = waitParams[1]
				end
				newWaits[key] = wait
			end

			if asInsert then
				waitOrders[index] = { CMD.INSERT, { params[1], CMD.WAIT, params[3], code, key }, order[3] }
			else
				waitOrders[index] = { CMD.WAIT, { code, key }, order[3] }
			end
		else
			waitOrders[index] = order
		end
	end

	return waitOrders
end

local function canExecuteWait(unitDefID, code)
	if code == CMD.WAITCODE_GATHER then
		return canGather[unitDefID]
	end
	return true
end

---@return integer? queueIndex nil when the unit is gone or has lost the wait
---@return integer? commandTag
local function getWaitQueueIndex(unitID, code, key)
	local queueIndex = 0
	repeat
		queueIndex = queueIndex + 1
		local commandID, _, commandTag, waitCode, waitKey = spGetUnitCurrentCommand(unitID, queueIndex)
		if commandID == CMD.WAIT and waitCode == code and waitKey == key then
			return queueIndex, commandTag
		end
	until commandID == nil
end

---@param waitTags table<UnitID, integer>
local function releaseWaitingUnits(waitTags)
	GG.MissionAPI.issuingOrders = true
	for unitID, commandTag in pairs(waitTags) do
		Spring.GiveOrderToUnit(unitID, CMD.REMOVE, commandTag)
	end
	GG.MissionAPI.issuingOrders = nil
end

---@return number? waitKey
local function getOrderWaitKey(order, newWaits)
	local params = order[2]
	if type(params) ~= "table" then
		return
	elseif order[1] == CMD.WAIT and newWaits[params[2]] then
		return params[2]
	elseif order[1] == CMD.INSERT and params[2] == CMD.WAIT and newWaits[params[5]] then
		return params[5]
	end
end

---@return CreateCommand[] orders
local function removeUnexecutableWaits(orders, newWaits, unitDefID)
	local waitOrders = {}
	for _, order in ipairs(orders) do
		local key = getOrderWaitKey(order, newWaits)
		if not key or canExecuteWait(unitDefID, newWaits[key].code) then
			waitOrders[#waitOrders + 1] = order
		end
	end
	return waitOrders
end

local function getDeathWaitTargets(wait, unitOrders)
	local rectangle = wait.targetRectangle
	local x1, z1, x2, z2 = rectangle[1], rectangle[3], rectangle[4], rectangle[6]
	local unitIDs = Spring.GetUnitsInRectangle(math.min(x1, x2), math.min(z1, z2), math.max(x1, x2), math.max(z1, z2))
	local targetIDs = {}
	-- The client picks units so we have to match it.
	for _, unitID in ipairs(unitIDs) do
		if not unitOrders[unitID] then
			targetIDs[unitID] = true
		end
	end
	return targetIDs
end

local function trackWaits(newWaits, unitOrders)
	for key, wait in pairs(newWaits) do
		if wait.targetUnitName then
			wait.orderedUnitIDs = {}
			for unitID in pairs(unitOrders) do
				wait.orderedUnitIDs[unitID] = true
			end
		elseif wait.code == CMD.WAITCODE_DEATH then
			wait.targetIDs = getDeathWaitTargets(wait, unitOrders)
		end
		waits[key] = wait
	end
end

local function makeFactoryOrdersList(orders, newWaits)
	local factoryOrders = {}
	for index, order in ipairs(orders) do
		if order[1] == CMD.WAIT and getOrderWaitKey(order, newWaits) then
			local options = table.copy(order[3] or {})
			if not table.contains(options, "shift") then
				options[#options + 1] = "shift"
			end
			factoryOrders[index] = { order[1], order[2], options }
		elseif order[1] == CMD.INSERT and getOrderWaitKey(order, newWaits) then
			local options = {}
			for _, option in ipairs(order[3] or {}) do
				if option ~= "ctrl" then -- don't pass WAIT to the build queue
					options[#options + 1] = option
				end
			end
			factoryOrders[index] = { order[1], order[2], options }
		else
			factoryOrders[index] = order
		end
	end
	return factoryOrders
end

local function addFactoryWait(factoryID, key, wait)
	wait.factoryIDs[factoryID] = true
	local keys = factoryWaitKeys[factoryID] or {}
	keys[key] = true
	factoryWaitKeys[factoryID] = keys
end

-- Issuing orders --------------------------------------------------------------

--- Gives each unit its own orders.
---
--- The Nth coded wait in each list is one wait shared by all units in the list.
---@param unitOrders table<integer, CreateCommand[]> many units may have the same `orders` table
local function giveUnitOrders(unitOrders)
	local newWaits, positionWaitKey, preparedLists = {}, {}, {}
	local orderLists, listUnitIDs, waitLists, factoryLists = {}, {}, {}, {}

	for unitID, orders in pairs(unitOrders) do
		local list = preparedLists[orders]
		if list == nil then
			list = expandWaitOrders(convertOrdersTargetingNames(orders), newWaits, positionWaitKey)
			preparedLists[orders] = list
		end

		local unitDefID = Spring.GetUnitDefID(unitID) ---@as UnitDefID
		local unitIsFactory = isFactory[unitDefID]
		local mayIgnoreWait = false
		for _, order in ipairs(list) do
			local key = getOrderWaitKey(order, newWaits)
			if key and not canExecuteWait(unitDefID, newWaits[key].code) then
				mayIgnoreWait = true
			elseif key and unitIsFactory then
				addFactoryWait(unitID, key, newWaits[key])
			elseif key then
				newWaits[key].unitIDs[unitID] = true
			end
		end

		if unitIsFactory and next(newWaits) ~= nil then
			local factoryList = factoryLists[list]
			if factoryList == nil then
				factoryList = makeFactoryOrdersList(removeUnexecutableWaits(list, newWaits, unitDefID), newWaits)
				factoryLists[list] = factoryList
			end
			list = factoryList
		elseif mayIgnoreWait then
			local waitList = waitLists[list]
			if waitList == nil then
				waitList = removeUnexecutableWaits(list, newWaits, unitDefID)
				waitLists[list] = waitList
			end
			list = waitList
		end

		if not listUnitIDs[list] then
			orderLists[#orderLists + 1] = list
			listUnitIDs[list] = {}
		end
		listUnitIDs[list][unitID] = true
	end

	GG.MissionAPI.issuingOrders = true
	for _, orders in ipairs(orderLists) do
		Spring.GiveOrderArrayToUnitMap(listUnitIDs[orders], orders)
	end
	GG.MissionAPI.issuingOrders = nil

	trackWaits(newWaits, unitOrders)
end

--- Gives every unit the same orders.
---@param unitIDs table<integer, true>
---@param orders CreateCommand[]
local function giveOrders(unitIDs, orders)
	local unitOrders = {}
	for unitID in pairs(unitIDs) do
		unitOrders[unitID] = orders
	end
	giveUnitOrders(unitOrders)
end

-- Order state tracking --------------------------------------------------------

local function updateWaitingUnits(key, wait, isReleasing)
	local unitIDs = wait.unitIDs
	local releasedWaitTags = {}
	for unitID in pairs(unitIDs) do
		local queueIndex, commandTag = getWaitQueueIndex(unitID, wait.code, key)
		if queueIndex == nil then
			unitIDs[unitID] = nil
		elseif queueIndex == 1 and isReleasing then
			releasedWaitTags[unitID] = commandTag
			unitIDs[unitID] = nil
		end
	end

	if next(releasedWaitTags) ~= nil then
		releaseWaitingUnits(releasedWaitTags)
	end
end

local function updateGatherWait(key, wait)
	local unitIDs = wait.unitIDs
	for unitID in pairs(unitIDs) do
		local queueIndex = getWaitQueueIndex(unitID, wait.code, key)
		if queueIndex == nil then
			unitIDs[unitID] = nil
		elseif queueIndex > 1 then
			return
		end
	end
	updateWaitingUnits(key, wait, true)
end

local function updateTimeWait(key, wait, frameNumber)
	local unitIDs, startFrames = wait.unitIDs, wait.startFrames
	local releasedWaitTags = {}
	for unitID in pairs(unitIDs) do
		local queueIndex, commandTag = getWaitQueueIndex(unitID, wait.code, key)
		if queueIndex == nil then
			unitIDs[unitID] = nil
			startFrames[unitID] = nil
		elseif queueIndex == 1 then
			if not startFrames[unitID] then
				startFrames[unitID] = frameNumber
			elseif frameNumber >= startFrames[unitID] + wait.duration then
				releasedWaitTags[unitID] = commandTag
				unitIDs[unitID] = nil
				startFrames[unitID] = nil
			end
		end
	end

	if next(releasedWaitTags) ~= nil then
		releaseWaitingUnits(releasedWaitTags)
	end
end

local function hasWaitTargets(wait)
	local trackedUnits = trackedUnitIDs[wait.targetUnitName]
	if trackedUnits then
		local orderedUnitMap = wait.orderedUnitIDs
		for unitID in pairs(trackedUnits) do
			if not orderedUnitMap[unitID] and spGetUnitIsDead(unitID) == false then
				return true
			end
		end
	end
	return false
end

local function updateDeathWait(key, wait)
	if wait.targetUnitName then
		wait.areTargetsDead = wait.areTargetsDead or not hasWaitTargets(wait)
		updateWaitingUnits(key, wait, wait.areTargetsDead)
		return
	end

	local targetIDs = wait.targetIDs
	for targetID in pairs(targetIDs) do
		if spGetUnitIsDead(targetID) ~= false then
			targetIDs[targetID] = nil
		end
	end

	updateWaitingUnits(key, wait, next(targetIDs) == nil)
end

local function updateSquadWait(key, wait)
	local unitIDs = wait.unitIDs
	local squadList, waitTags, count = {}, {}, 0
	for unitID in pairs(unitIDs) do
		local queueIndex, tag = getWaitQueueIndex(unitID, wait.code, key)
		if queueIndex == nil then
			unitIDs[unitID] = nil
		else
			count = count + 1
			if queueIndex == 1 then
				squadList[#squadList + 1] = unitID
				waitTags[unitID] = tag
			end
		end
	end

	-- A squad that can no longer populate releases units immediately.
	if count < wait.squadSize and next(wait.factoryIDs) == nil then
		updateWaitingUnits(key, wait, true)
		return
	end

	local squadCount = math.floor(#squadList / wait.squadSize)
	if squadCount == 0 then
		return
	end
	local releasedWaitTags = {}
	for index = 1, squadCount * wait.squadSize do
		local unitID = squadList[index]
		releasedWaitTags[unitID] = waitTags[unitID]
		unitIDs[unitID] = nil
	end
	releaseWaitingUnits(releasedWaitTags)
end

local updateWait = {
	[CMD.WAITCODE_TIME] = updateTimeWait,
	[CMD.WAITCODE_DEATH] = updateDeathWait,
	[CMD.WAITCODE_SQUAD] = updateSquadWait,
	[CMD.WAITCODE_GATHER] = updateGatherWait,
}

local function updateRalliedWaits(key, wait)
	for factoryID in pairs(wait.factoryIDs) do
		if getWaitQueueIndex(factoryID, wait.code, key) == nil then
			wait.factoryIDs[factoryID] = nil
			local keys = factoryWaitKeys[factoryID]
			keys[key] = nil
			if next(keys) == nil then
				factoryWaitKeys[factoryID] = nil
			end
		end
	end
end

local function updateWaits(frameNumber)
	if frameNumber % UPDATE_INTERVAL_FRAMES ~= 0 then
		return
	end

	-- Releasing units can fire triggers that give new waits.
	for _, key in ipairs(table_keys(waits)) do
		local wait = waits[key]
		if wait then
			updateRalliedWaits(key, wait)
			updateWait[wait.code](key, wait, frameNumber)
			if next(wait.unitIDs) == nil and next(wait.factoryIDs) == nil then
				waits[key] = nil
			end
		end
	end
end

-- Callins and events ----------------------------------------------------------

local function onUnitFromFactory(unitID, factoryID)
	local keys = factoryWaitKeys[factoryID]
	if keys == nil then
		return
	end

	for key in pairs(keys) do
		local wait = waits[key]
		if wait and getWaitQueueIndex(unitID, wait.code, key) then
			wait.unitIDs[unitID] = true
		end
	end
end

-- Module export ---------------------------------------------------------------

return {
	GiveUnitOrders = giveUnitOrders,
	GiveOrders = giveOrders,
	UpdateWaits = updateWaits,
	OnUnitFromFactory = onUnitFromFactory,
}
