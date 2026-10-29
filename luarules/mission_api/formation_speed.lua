---
--- Paces the ground units of a formation move so they arrive together.
--- Polled every half second from the action helper's GameFrame, so no callins are added to every game.
---

local Formation = VFS.Include("luarules/mission_api/formation_math.lua")

-- In elmos. How far a queued order's position may be from a unit's spot and still be its formation order.
local SAME_POSITION = 1

-- In elmos per second. A wanted speed further than this from ours was set by a player's move, a guard or a script:
-- leave it alone.
local SAME_SPEED = 0.01

-- In elmos, more than most units walk between two updates: a PATROL never leaves the queue, so arrival is checked by
-- distance.
local ARRIVED_DISTANCE = 64

local groups = {}
local groupOf = {}
-- Units let go under MoveCtrl get their speed back once it ends.
local pending = {}

local function getGroundMoveData(unitID)
	local data = Spring.GetUnitMoveTypeData(unitID)
	if data and data.name == "ground" then
		return data
	end
end

local function isOwnSpeed(data, speed)
	return math.abs(data.maxWantedSpeed - speed) < SAME_SPEED
end

-- False under MoveCtrl, to retry later.
local function restoreSpeed(unitID, speed)
	if Spring.GetUnitIsDead(unitID) ~= false then
		return true
	end
	local data = getGroundMoveData(unitID)
	if not data then
		return false
	end
	if isOwnSpeed(data, speed) then
		Spring.MoveCtrl.SetGroundMoveTypeData(unitID, { maxWantedSpeed = data.maxSpeed })
	end
	return true
end

local function release(member)
	groupOf[member.unitID] = nil
	if not restoreSpeed(member.unitID, member.speed) then
		pending[#pending + 1] = { unitID = member.unitID, speed = member.speed }
	end
end

local function retryPending()
	local waiting = {}
	for _, entry in ipairs(pending) do
		if not groupOf[entry.unitID] and not restoreSpeed(entry.unitID, entry.speed) then
			waiting[#waiting + 1] = entry
		end
	end
	pending = waiting
end

-- The whole queue, as an ATTACK can be pushed in front of a FIGHT.
local function hasCommandAt(unitID, commandID, spot)
	for index = 1, Spring.GetUnitCommandCount(unitID) do
		local id, _, _, x, _, z = Spring.GetUnitCurrentCommand(unitID, index)
		if id == commandID and z and math.abs(x - spot.x) < SAME_POSITION and math.abs(z - spot.z) < SAME_POSITION then
			return true
		end
	end
	return false
end

-- A PATROL never leaves the queue: the unit is on its way while the FIGHT to its point is queued, or before that
-- first appears.
local function isOnTheWay(member)
	if member.command ~= CMD.PATROL then
		return hasCommandAt(member.unitID, member.command, member.target)
	end
	if hasCommandAt(member.unitID, CMD.FIGHT, member.target) then
		member.legStarted = true
		return true
	end
	return not member.legStarted and hasCommandAt(member.unitID, CMD.PATROL, member.target)
end

local function getWay(member)
	local x, _, z = Spring.GetUnitPosition(member.unitID)
	return Formation.Distance({ x = x, z = z }, member.target)
end

local function isStillPaced(member)
	local unitID = member.unitID
	if Spring.GetUnitIsDead(unitID) ~= false or Spring.GetUnitTransporter(unitID) then
		return false
	end
	local data = getGroundMoveData(unitID)
	if not data or not isOwnSpeed(data, member.speed) then
		return false
	end
	return getWay(member) > ARRIVED_DISTANCE and isOnTheWay(member)
end

local function pace(group)
	local ways, slowest = {}, math.huge
	for i, member in ipairs(group.members) do
		ways[i] = getWay(member)
		slowest = math.min(slowest, getGroundMoveData(member.unitID).maxSpeed)
	end
	local speeds = Formation.ArrivalSpeeds(ways, slowest)
	for i, member in ipairs(group.members) do
		Spring.MoveCtrl.SetGroundMoveTypeData(member.unitID, { maxWantedSpeed = speeds[i] })
		member.speed = speeds[i]
	end
end

--- Paces the units on the formation orders they were just given. Units whose order was refused are skipped.
--- @param units integer[] unitIDs
--- @param targets table[] each unit's { x, z }, in the order of units
--- @param command number CMD.MOVE, CMD.FIGHT or CMD.PATROL
local function match(units, targets, command)
	local members = {}
	for i, unitID in ipairs(units) do
		local member = { unitID = unitID, target = targets[i], command = command }
		local data = getGroundMoveData(unitID)
		if data and data.maxSpeed > 0 and not Spring.GetUnitTransporter(unitID) and isOnTheWay(member) then
			members[#members + 1] = member
		end
	end
	if #members < 2 then
		return
	end

	local group = { members = members }
	for _, member in ipairs(members) do
		groupOf[member.unitID] = group
	end
	groups[#groups + 1] = group
	pace(group)
end

local function update()
	retryPending()

	local remaining = {}
	for _, group in ipairs(groups) do
		local members = {}
		for _, member in ipairs(group.members) do
			-- A unit given a newer formation order is paced by its new group.
			if groupOf[member.unitID] == group then
				if isStillPaced(member) then
					members[#members + 1] = member
				else
					release(member)
				end
			end
		end

		if #members < 2 then
			for _, member in ipairs(members) do
				release(member)
			end
		else
			group.members = members
			pace(group)
			remaining[#remaining + 1] = group
		end
	end
	groups = remaining
end

local function isActive()
	return #groups > 0 or #pending > 0
end

return {
	Match = match,
	Update = update,
	IsActive = isActive,
}
