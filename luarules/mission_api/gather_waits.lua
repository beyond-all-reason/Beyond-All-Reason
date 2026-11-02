---
--- GATHERWAIT in mission orders. A player's gather wait runs on their own client (WaitCommandsAI): each
--- unit gets a CMD.WAIT tagged with the gather code and a key, and once every unit is waiting on it, a
--- plain CMD.WAIT lifts them all. Orders a mission gives never pass a client, so this does the same here.
---

-- Every 3 frames, as the engine checks a player's waits.
local UPDATE_PERIOD = 3

-- Keys count down from -1. A client builds its keys from a counter with its player number in the low
-- byte, which read as a float is never negative, so a mission's wait never shares a key with a player's.
local nextKey = -1

---@type table<number, table<integer, true>> each key, and the units given a wait with it
local gathers = {}

--- Copies the orders with every GATHERWAIT turned into a tagged CMD.WAIT, queued behind the orders
--- before it, and returns the keys it used. The orders given are not changed.
---@return table orders
---@return number[] keys
local function tagOrders(orders)
	local tagged, keys = {}, {}
	for index, order in ipairs(orders or {}) do
		if order[1] == CMD.GATHERWAIT then
			local key = nextKey
			nextKey = nextKey - 1
			keys[#keys + 1] = key
			tagged[index] = { CMD.WAIT, { CMD.WAITCODE_GATHER, key }, { "shift" } }
		else
			tagged[index] = order
		end
	end
	return tagged, keys
end

--- As for a player's gather (WaitCommandsAI.cpp), a factory or a unit that cannot move takes no part:
--- it would never get to its wait, and a factory would hand the wait on to every unit it builds.
---@param unitDef table
---@return boolean
local function canGather(unitDef)
	return unitDef.canMove and not unitDef.isFactory
end

--- The units given the tagged orders, as a set of unitIDs: they wait for each other at each key.
---@param keys number[]
---@param unitIDs table<integer, true>
local function add(keys, unitIDs)
	for _, key in ipairs(keys) do
		local units = gathers[key] or {}
		for unitID in pairs(unitIDs) do
			units[unitID] = true
		end
		gathers[key] = units
	end
end

local function isGatherWait(command, key)
	return command.id == CMD.WAIT and command.params[1] == CMD.WAITCODE_GATHER and command.params[2] == key
end

-- Where the wait is in the unit's queue, 1 when the unit is waiting on it; nil when the unit is gone or
-- no longer has it.
local function findWait(unitID, key)
	if not Spring.ValidUnitID(unitID) or Spring.GetUnitIsDead(unitID) then
		return nil
	end
	for index, command in ipairs(Spring.GetUnitCommands(unitID, -1)) do
		if isGatherWait(command, key) then
			return index
		end
	end
	return nil
end

local function release(units)
	-- Fence around mission-issued orders for UnitOrdered triggers using `ignoreMissionActions`.
	GG["MissionAPI"].issuingOrders = true
	for unitID in pairs(units) do
		-- Without shift, a WAIT given to a waiting unit takes its wait away.
		Spring.GiveOrderToUnit(unitID, CMD.WAIT, {}, 0)
	end
	GG["MissionAPI"].issuingOrders = nil
end

local function update(frameNumber)
	if frameNumber % UPDATE_PERIOD ~= 0 then
		return
	end
	for key, units in pairs(gathers) do
		local allWaiting = true
		for unitID in pairs(units) do
			local index = findWait(unitID, key)
			if index == nil then
				units[unitID] = nil
			elseif index > 1 then
				allWaiting = false
			end
		end
		if next(units) == nil then
			gathers[key] = nil
		elseif allWaiting then
			release(units)
			gathers[key] = nil
		end
	end
end

return {
	TagOrders = tagOrders,
	CanGather = canGather,
	Add = add,
	Update = update,
}
