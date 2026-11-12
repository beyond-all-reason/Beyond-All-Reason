local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

-- Each unit's queue, as GetUnitCurrentCommand reads it, and the orders given to it.
local queues, deadUnitIDs, released = {}, {}, {}

local env
env = MissionSpecEnv.new({
	Game = { gameSpeed = 30 },
	Spring = {
		GetUnitAllyTeam = function()
			return 0
		end,
		GetUnitDefID = function()
			return 1
		end,
		GetUnitIsDead = function(unitID)
			return deadUnitIDs[unitID] == true
		end,
		GetUnitLosState = function()
			return 1
		end,
		GetUnitCurrentCommand = function(unitID, queueIndex)
			local command = (queues[unitID] or {})[queueIndex] ---@as table?
			if command then
				return command[1], nil, queueIndex, command[2][1], command[2][2]
			end
		end,
		GiveOrderArrayToUnitMap = function(unitIDs, orders)
			local queue = {}
			for index, order in ipairs(orders) do
				if order[1] == env.CMD.INSERT then
					queue[index] = { order[2][2], { order[2][4], order[2][5] } }
				else
					queue[index] = order
				end
			end
			for unitID in pairs(unitIDs) do
				queues[unitID] = queue
			end
		end,
		GiveOrderToUnit = function(unitID)
			released[#released + 1] = unitID
		end,
	},
})
env.UnitDefs = { [1] = { canMove = true, isFactory = false } }

-- orders.lua keeps the tracking tables it finds at load, and every Install() refills those same tables.
MissionApiBuilder.new():Install()
local missionOrders = MissionSpecEnv.include(env, "luarules/mission_api/orders.lua")

local function trackUnits(name, ...)
	local builder = MissionApiBuilder.new()
	for _, unitID in ipairs({ ... }) do
		builder:WithTrackedUnit(name, unitID)
	end
	return builder:Install()
end

describe("mission_api.orders DEATHWAIT on a unit name", function()
	before_each(function()
		queues, deadUnitIDs, released = {}, {}, {}
	end)

	it("holds the units until every unit with the name has died", function()
		trackUnits("bosses", 7, 8)
		missionOrders.GiveOrders({ [1] = true }, { { env.CMD.DEATHWAIT, { unitName = "bosses" } } })

		deadUnitIDs[7] = true
		missionOrders.UpdateWaits(3)
		assert.are.same({}, released)

		deadUnitIDs[8] = true
		missionOrders.UpdateWaits(6)
		assert.are.same({ 1 }, released)
	end)

	it("waits on a unit that gets the name after the order", function()
		trackUnits("bosses", 7)
		missionOrders.GiveOrders({ [1] = true }, { { env.CMD.DEATHWAIT, { unitName = "bosses" } } })

		trackUnits("bosses", 7, 9)
		deadUnitIDs[7] = true
		missionOrders.UpdateWaits(3)
		assert.are.same({}, released)

		deadUnitIDs[9] = true
		missionOrders.UpdateWaits(6)
		assert.are.same({ 1 }, released)
	end)

	it("leaves the units given the order out of its targets", function()
		trackUnits("squad", 1, 2)
		missionOrders.GiveOrders({ [1] = true, [2] = true }, { { env.CMD.DEATHWAIT, { unitName = "squad" } } })

		missionOrders.UpdateWaits(9)
		table.sort(released)
		assert.are.same({ 1, 2 }, released)
	end)
end)

describe("mission_api.orders DEATHWAIT inside an insert", function()
	before_each(function()
		queues, deadUnitIDs, released = {}, {}, {}
	end)

	it("holds the units until every unit with the name has died", function()
		trackUnits("bosses", 7, 8)
		missionOrders.GiveOrders(
			{ [1] = true },
			{ { env.CMD.INSERT, { 0, env.CMD.DEATHWAIT, 0, { unitName = "bosses" } } } }
		)

		deadUnitIDs[7] = true
		missionOrders.UpdateWaits(3)
		assert.are.same({}, released)

		deadUnitIDs[8] = true
		missionOrders.UpdateWaits(6)
		assert.are.same({ 1 }, released)
	end)

	it("holds the units until every other unit in the area has died", function()
		local area = { x1 = 0, z1 = 0, x2 = 100, z2 = 100 }
		MissionApiBuilder.new()
			:WithModule("AreaTracking", {
				GetUnitsInArea = function(givenArea)
					return givenArea == area and { 1, 7, 8 } or {}
				end,
			})
			:Install()
		missionOrders.GiveOrders({ [1] = true }, { { env.CMD.INSERT, { 0, env.CMD.DEATHWAIT, 0, area } } })

		deadUnitIDs[7] = true
		missionOrders.UpdateWaits(3)
		assert.are.same({}, released)

		deadUnitIDs[8] = true
		missionOrders.UpdateWaits(6)
		assert.are.same({ 1 }, released)
	end)
end)
