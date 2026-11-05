local MAP_SIZE = 4096

_G.CMD = { MOVE = 10, PATROL = 15, FIGHT = 16, ATTACK = 20, REPAIR = 40, RECLAIM = 90, RESURRECT = 125, CAPTURE = 130 } ---@diagnostic disable-line: global-in-non-module

local FormationOrders = require("modules/formation_orders")

describe("modules.formation_orders", function()
	---@type table<integer, table>
	local units
	---@type table<integer, table>
	local given
	---@type table<integer, table>
	local givenAsWritten

	-- units: unitID -> { x, z, heading (radians), queue, def, dead, beingBuilt, transporter }
	local function setUnits(newUnits)
		units = newUnits
	end

	local function unitIDs()
		local ids = {}
		for unitID in pairs(units) do
			ids[#ids + 1] = unitID
		end
		return ids
	end

	before_each(function()
		given, givenAsWritten = {}, {}
		_G.CMD = {
			MOVE = 10,
			PATROL = 15,
			FIGHT = 16,
			ATTACK = 20,
			REPAIR = 40,
			RECLAIM = 90,
			RESURRECT = 125,
			CAPTURE = 130,
		} ---@diagnostic disable-line: global-in-non-module
		_G.Game = { mapSizeX = MAP_SIZE, mapSizeZ = MAP_SIZE, squareSize = 8 } ---@diagnostic disable-line: global-in-non-module
		---@diagnostic disable-next-line: global-in-non-module
		_G.UnitDefs = {
			[1] = { canMove = true, speed = 60 },
			[2] = { canMove = false, speed = 0 },
			[3] = { canMove = true, speed = 0 },
		} ---@diagnostic disable-line: global-in-non-module
		_G.Spring = { ---@diagnostic disable-line: global-in-non-module
			GetUnitDefID = function(unitID)
				return units[unitID].def or 1
			end,
			GetUnitIsDead = function(unitID)
				return units[unitID].dead == true
			end,
			GetUnitIsBeingBuilt = function(unitID)
				return units[unitID].beingBuilt == true
			end,
			GetUnitTransporter = function(unitID)
				return units[unitID].transporter
			end,
			GetUnitPosition = function(unitID)
				return units[unitID].x, 0, units[unitID].z
			end,
			GetUnitHeading = function(unitID, radians)
				assert.is_true(radians)
				return units[unitID].heading or 0
			end,
			GetUnitCommands = function(unitID)
				return units[unitID].queue or {}
			end,
			GetGroundHeight = function()
				return 0
			end,
			-- As the engine does: shift adds to the queue, anything else replaces it.
			GiveOrderToUnit = function(unitID, command, params, options)
				local unit = units[unitID]
				local queued = { id = command, params = params }
				if table.contains(options, "shift") then
					unit.queue = unit.queue or {}
					unit.queue[#unit.queue + 1] = queued
				else
					unit.queue = { queued }
				end
				given[#given + 1] = { unitID = unitID, command = command, params = params, options = options }
			end,
			GiveOrderArrayToUnit = function(unitID, orders)
				givenAsWritten[#givenAsWritten + 1] = { unitID = unitID, orders = orders }
			end,
		}
	end)

	-- The last order each unit was given.
	local function ordersByUnit()
		local orders = {}
		for _, order in ipairs(given) do
			orders[order.unitID] =
				{ command = order.command, x = order.params[1], z = order.params[3], options = order.options }
		end
		return orders
	end

	local function issue(orders, options)
		FormationOrders.GiveFormationOrders(unitIDs(), orders, options or {})
	end

	local function moveTo(x, z, options)
		return { CMD.MOVE, { x, 0, z }, options or {} }
	end

	local function near(expected, actual)
		return math.abs(expected - actual) < 0.001
	end

	it("keeps the shape around the order's point, one move order per unit", function()
		setUnits({ [1] = { x = 100, z = 100 }, [2] = { x = 200, z = 100 } })
		issue({ moveTo(1000, 1000) })
		local orders = ordersByUnit()
		assert.are.equal(2, #given)
		assert.are.equal(950, orders[1].x)
		assert.are.equal(1050, orders[2].x)
		assert.are.equal(1000, orders[1].z)
		assert.are.equal(CMD.MOVE, orders[1].command)
		assert.are.same({}, orders[1].options)
	end)

	it("gives FIGHT and PATROL the same way, with their options", function()
		setUnits({ [1] = { x = 100, z = 100 } })
		issue({ { CMD.FIGHT, { 1000, 0, 1000 }, { "alt" } } })
		assert.are.equal(CMD.FIGHT, given[1].command)
		assert.are.same({ "alt" }, given[1].options)
	end)

	it("spreads the units along a line when the order has several points, matched at the lowest total cost", function()
		setUnits({ [1] = { x = 100, z = 0 }, [2] = { x = 300, z = 0 }, [3] = { x = 200, z = 0 } })
		issue({ { CMD.MOVE, { 100, 0, 500, 500, 0, 500 }, {} } })
		local orders = ordersByUnit()
		assert.are.equal(100, orders[1].x)
		assert.are.equal(300, orders[3].x)
		assert.are.equal(500, orders[2].x)
		assert.are.equal(500, orders[2].z)
	end)

	it("gives an order that is not a move to each unit as written", function()
		setUnits({ [1] = { x = 100, z = 100 }, [2] = { x = 200, z = 100 } })
		issue({ { CMD.ATTACK, { 77 }, {} } })
		assert.are.equal(2, #given)
		assert.are.same({ 77 }, given[1].params)
		assert.are.same({ 77 }, given[2].params)
	end)

	describe("facing", function()
		-- Side by side along x, both facing south.
		local function sideBySide()
			setUnits({ [1] = { x = 1000, z = 1000, heading = 0 }, [2] = { x = 1100, z = 1000, heading = 0 } })
		end

		it("turns the shape to a heading", function()
			sideBySide()
			issue({ moveTo(3000, 1000) }, { facing = math.pi / 2 })
			local orders = ordersByUnit()
			assert.is_true(near(3000, orders[1].x) and near(3000, orders[2].x))
			assert.is_true(near(100, math.abs(orders[1].z - orders[2].z)))
		end)

		it("does not turn the shape for the way it already faces", function()
			sideBySide()
			issue({ moveTo(3000, 1000) }, { facing = 0 })
			local orders = ordersByUnit()
			assert.is_true(near(2950, orders[1].x) and near(3050, orders[2].x))
		end)

		it("turns the shape to face a point from the order's point", function()
			sideBySide()
			issue({ moveTo(3000, 1000) }, { facing = { x = 4000, z = 1000 } })
			local orders = ordersByUnit()
			assert.is_true(near(3000, orders[1].x) and near(3000, orders[2].x))
			assert.is_true(near(100, math.abs(orders[1].z - orders[2].z)))
		end)

		it("turns from the way to the point when the units face opposite ways", function()
			setUnits({ [1] = { x = 1000, z = 1000, heading = 0 }, [2] = { x = 1100, z = 1000, heading = math.pi } })
			issue({ moveTo(3000, 1000) }, { facing = 0 })
			local orders = ordersByUnit()
			assert.is_true(near(3000, orders[1].x) and near(3000, orders[2].x))
			assert.is_true(near(100, math.abs(orders[1].z - orders[2].z)))
		end)
	end)

	describe("queue", function()
		local function queued(x, z)
			return { { id = CMD.MOVE, params = { x, 0, z } } }
		end

		it("starts a shift order from where each unit's queue ends", function()
			setUnits({
				[1] = { x = 0, z = 0, queue = queued(500, 500) },
				[2] = { x = 0, z = 0, queue = queued(600, 500) },
			})
			issue({ moveTo(2000, 2000, { "shift" }) })
			local orders = ordersByUnit()
			assert.are.same({ "shift" }, orders[1].options)
			assert.are.equal(1950, orders[1].x)
			assert.are.equal(2050, orders[2].x)
		end)

		it("chains the orders of one action, each starting where the one before it ends", function()
			setUnits({ [1] = { x = 100, z = 100 }, [2] = { x = 200, z = 100 } })
			issue({ moveTo(1000, 1000), moveTo(1000, 2000, { "shift" }) })
			assert.are.equal(4, #given)
			local orders = ordersByUnit()
			assert.are.equal(950, orders[1].x)
			assert.are.equal(1050, orders[2].x)
			assert.are.equal(2000, orders[1].z)
		end)

		it("reads the position of a repair, reclaim or capture on a unit inside an area", function()
			setUnits({
				[1] = { x = 0, z = 0, queue = { { id = CMD.REPAIR, params = { 77, 500, 0, 500, 100 } } } },
				[2] = { x = 0, z = 0, queue = queued(600, 500) },
			})
			issue({ moveTo(2000, 2000, { "shift" }) })
			local orders = ordersByUnit()
			assert.are.equal(1950, orders[1].x)
			assert.are.equal(2050, orders[2].x)
		end)

		it("reads the position of a resurrect on a wreck inside an area", function()
			setUnits({
				[1] = { x = 0, z = 0, queue = { { id = CMD.RESURRECT, params = { 32077, 500, 0, 500, 100 } } } },
				[2] = { x = 0, z = 0, queue = queued(600, 500) },
			})
			issue({ moveTo(2000, 2000, { "shift" }) })
			local orders = ordersByUnit()
			assert.are.equal(1950, orders[1].x)
			assert.are.equal(2050, orders[2].x)
		end)

		it("starts from where the unit stands when nothing queued has a position", function()
			setUnits({
				[1] = { x = 500, z = 500, queue = { { id = CMD.REPAIR, params = { 77 } } } },
				[2] = { x = 600, z = 500 },
			})
			issue({ moveTo(2000, 2000, { "shift" }) })
			local orders = ordersByUnit()
			assert.are.equal(1950, orders[1].x)
			assert.are.equal(2050, orders[2].x)
		end)
	end)

	it(
		"gives units that cannot move, factories, units under construction and transported units the orders as written, dead units none",
		function()
			setUnits({
				[1] = { x = 0, z = 0 },
				[2] = { x = 50, z = 0, def = 2 },
				[3] = { x = 100, z = 0, dead = true },
				[4] = { x = 150, z = 0, beingBuilt = true },
				[5] = { x = 200, z = 0, transporter = 2 },
				[6] = { x = 250, z = 0, def = 3 },
			})
			local orders = { moveTo(1000, 1000) }
			issue(orders)
			assert.are.equal(1, #given)
			assert.are.equal(1, given[1].unitID)
			assert.are.equal(4, #givenAsWritten)
			assert.are.same(orders, givenAsWritten[1].orders)
		end
	)

	it("gives a line to a unit that is not spread as its first point", function()
		setUnits({ [1] = { x = 0, z = 0, def = 2 } })
		issue({ { CMD.FIGHT, { 100, 0, 500, 500, 0, 500 }, { "shift" } } })
		assert.are.same({ { CMD.FIGHT, { 100, 0, 500 }, { "shift" } } }, givenAsWritten[1].orders)
	end)

	it("keeps the targets on the map", function()
		setUnits({ [1] = { x = 0, z = 0 }, [2] = { x = 400, z = 0 } })
		issue({ moveTo(MAP_SIZE - 10, 10) })
		for _, order in ipairs(given) do
			assert.is_true(order.params[1] <= MAP_SIZE - Game.squareSize)
			assert.is_true(order.params[3] >= Game.squareSize)
		end
		assert.are.equal(MAP_SIZE - Game.squareSize, ordersByUnit()[2].x)
	end)

	it("orders the units by unitID", function()
		setUnits({ [30] = { x = 0, z = 0 }, [10] = { x = 100, z = 0 }, [20] = { x = 200, z = 0 } })
		issue({ moveTo(1000, 1000) })
		assert.are.same({ 10, 20, 30 }, { given[1].unitID, given[2].unitID, given[3].unitID })
	end)
end)
