local MissionSpecEnv = require("mission_api.spec_helper")

local CMD_WAIT, CMD_GATHERWAIT, WAITCODE_GATHER, CMD_MOVE = 5, 9, 4, 10

---@type table<integer, table[]> each unit's command queue, front first
local queues
---@type integer[]
local deadUnits
---@type table[]
local given

local env = MissionSpecEnv.new({
	Spring = {
		ValidUnitID = function(unitID)
			return queues[unitID] ~= nil
		end,
		GetUnitIsDead = function(unitID)
			return table.contains(deadUnits, unitID)
		end,
		GetUnitCommands = function(unitID)
			return queues[unitID]
		end,
		GiveOrderToUnit = function(unitID, commandID, params, options)
			given[#given + 1] = {
				unitID = unitID,
				commandID = commandID,
				params = params,
				options = options,
				fenced = GG["MissionAPI"].issuingOrders,
			}
		end,
	},
})
env.CMD.WAIT, env.CMD.GATHERWAIT, env.CMD.WAITCODE_GATHER = CMD_WAIT, CMD_GATHERWAIT, WAITCODE_GATHER

GG["MissionAPI"] = {}
local gatherWaits = MissionSpecEnv.include(env, "luarules/mission_api/gather_waits.lua")

local function wait(key)
	return { id = CMD_WAIT, params = { WAITCODE_GATHER, key } }
end

local function move()
	return { id = CMD_MOVE, params = { 0, 0, 0 } }
end

--- Tags one GATHERWAIT and hands it to the units; returns its key.
local function gather(unitIDs)
	local _, keys = gatherWaits.TagOrders({ { CMD_GATHERWAIT, {}, {} } })
	local unitSet = {}
	for _, unitID in ipairs(unitIDs) do
		unitSet[unitID] = true
	end
	gatherWaits.Add(keys, unitSet)
	return keys[1]
end

local function releasedUnitIDs()
	local unitIDs = {}
	for _, order in ipairs(given) do
		unitIDs[#unitIDs + 1] = order.unitID
	end
	table.sort(unitIDs)
	return unitIDs
end

describe("mission_api.gather_waits", function()
	before_each(function()
		queues, deadUnits, given = {}, {}, {}
	end)

	describe("TagOrders", function()
		it("turns each GATHERWAIT into a WAIT tagged with the gather code and its own key, queued", function()
			local orders = { { CMD_MOVE, { 1, 0, 1 }, {} }, { CMD_GATHERWAIT, {}, {} }, { CMD_GATHERWAIT, {}, {} } }
			local tagged, keys = gatherWaits.TagOrders(orders)

			assert.are.equal(2, #keys)
			assert.are_not.equal(keys[1], keys[2])
			assert.are.same(orders[1], tagged[1])
			assert.are.same({ CMD_WAIT, { WAITCODE_GATHER, keys[1] }, { "shift" } }, tagged[2])
			assert.are.same({ CMD_WAIT, { WAITCODE_GATHER, keys[2] }, { "shift" } }, tagged[3])
		end)

		it("leaves the mission's orders as they are", function()
			local orders = { { CMD_GATHERWAIT, {}, {} } }
			gatherWaits.TagOrders(orders)

			assert.are.same({ { CMD_GATHERWAIT, {}, {} } }, orders)
		end)

		it("takes keys below zero, which no player's client makes", function()
			local _, keys = gatherWaits.TagOrders({ { CMD_GATHERWAIT, {}, {} } })

			assert.is_true(keys[1] < 0)
		end)
	end)

	describe("CanGather", function()
		it("takes a unit that can move, and leaves out factories and units that cannot", function()
			assert.is_true(gatherWaits.CanGather({ canMove = true }))
			assert.is_false(gatherWaits.CanGather({ canMove = true, isFactory = true }))
			assert.is_false(gatherWaits.CanGather({ canMove = false }))
		end)
	end)

	describe("Update", function()
		it("lifts every unit's wait, inside the order fence, once all of them are waiting", function()
			local key = gather({ 1, 2 })
			queues[1] = { wait(key), move() }
			queues[2] = { wait(key) }

			gatherWaits.Update(3)

			assert.are.same({ 1, 2 }, releasedUnitIDs())
			assert.are.same({ unitID = 1, commandID = CMD_WAIT, params = {}, options = 0, fenced = true }, given[1])
		end)

		it("keeps them waiting while one is still on its way", function()
			local key = gather({ 1, 2 })
			queues[1] = { wait(key) }
			queues[2] = { move(), wait(key) }

			gatherWaits.Update(3)

			assert.are.same({}, given)
		end)

		it("lifts the gather only once", function()
			local key = gather({ 1, 2 })
			queues[1] = { wait(key) }
			queues[2] = { wait(key) }

			gatherWaits.Update(3)
			gatherWaits.Update(6)

			assert.are.equal(2, #given)
		end)

		it("stops waiting for a unit that died or lost the wait", function()
			local key = gather({ 1, 2, 3 })
			queues[1] = { wait(key) }
			queues[2] = { move(), wait(key) }
			queues[3] = { move() }
			deadUnits = { 2 }

			gatherWaits.Update(3)

			assert.are.same({ 1 }, releasedUnitIDs())
		end)

		it("lifts each gather on its own when a unit holds two", function()
			local first = gather({ 1, 2 })
			local second = gather({ 1, 2 })
			queues[1] = { wait(first), move(), wait(second) }
			queues[2] = { wait(first), move(), wait(second) }

			gatherWaits.Update(3)
			assert.are.same({ 1, 2 }, releasedUnitIDs())

			given = {}
			queues[1] = { move(), wait(second) }
			queues[2] = { wait(second) }
			gatherWaits.Update(6)
			assert.are.same({}, given)

			queues[1] = { wait(second) }
			gatherWaits.Update(9)
			assert.are.same({ 1, 2 }, releasedUnitIDs())
		end)

		it("looks only every third frame", function()
			local key = gather({ 1 })
			queues[1] = { wait(key) }

			gatherWaits.Update(4)
			assert.are.same({}, given)

			gatherWaits.Update(6)
			assert.are.same({ 1 }, releasedUnitIDs())
		end)
	end)
end)
