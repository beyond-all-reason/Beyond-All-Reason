local MissionSpecEnv = require("mission_api.spec_helper")

local MAP_SIZE = 4096
local CMD = { MOVE = 10, PATROL = 15, FIGHT = 16, ATTACK = 20 }

local env = MissionSpecEnv.new({
	CMD = CMD,
	Game = { mapSizeX = MAP_SIZE, mapSizeZ = MAP_SIZE, squareSize = 8 },
	UnitDefs = { [1] = { speed = 60 }, [2] = { speed = 0 } },
	math = {
		clamp = function(value, low, high)
			return math.max(low, math.min(high, value))
		end,
	},
	BAR = { Utilities = VFS.Include("common/springUtilities/facingFunctions.lua") },
})
local Marching = MissionSpecEnv.include(env, "luarules/mission_api/marching.lua")

describe("mission_api.marching", function()
	---@type table<integer, table>
	local units
	---@type table<integer, table>
	local given

	-- units: unitID -> { x, z, heading (radians), def, beingBuilt, transporter }
	local function march(newUnits, orders, direction)
		units, given = newUnits, {}
		local unitMap = {}
		for unitID in pairs(units) do
			unitMap[unitID] = true
		end
		given = Marching.GetMarchingOrders(unitMap, orders, direction)
	end

	before_each(function()
		env.Spring = {
			GetUnitDefID = function(unitID)
				return units[unitID].def or 1
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
			GetUnitDirection = function(unitID)
				local heading = units[unitID].heading or 0
				return math.sin(heading), 0, math.cos(heading)
			end,
			GetUnitArrayCentroid = function(unitIDs)
				local x, z = 0, 0
				for _, unitID in ipairs(unitIDs) do
					x, z = x + units[unitID].x, z + units[unitID].z
				end
				return x / #unitIDs, 0, z / #unitIDs
			end,
			GetGroundHeight = function()
				return 0
			end,
		}
	end)

	local function moveTo(x, z, options)
		return { CMD.MOVE, { x, 0, z }, options }
	end

	-- Where the unit's last order, or its order at index, sends it.
	local function spot(unitID, index)
		local orders = given[unitID]
		local params = orders[index or #orders][2]
		return params[1], params[3]
	end

	local function near(expected, actual)
		return math.abs(expected - actual) < 0.001
	end

	-- Side by side along x, both facing south.
	local function sideBySide()
		return { [1] = { x = 1000, z = 1000 }, [2] = { x = 1100, z = 1000 } }
	end

	it("keeps the group's shape around the order's point", function()
		march({ [1] = { x = 100, z = 100 }, [2] = { x = 200, z = 100 }, [3] = { x = 150, z = 190 } }, {
			moveTo(1000, 1000),
		})
		local x1, z1 = spot(1)
		local x3, z3 = spot(3)
		assert.are.equal(950, x1)
		assert.are.equal(970, z1)
		assert.are.equal(1000, x3)
		assert.are.equal(1060, z3)
	end)

	it("gives FIGHT and PATROL the same way, with their options", function()
		march(
			sideBySide(),
			{ { CMD.FIGHT, { 3000, 0, 1000 }, { "alt" } }, { CMD.PATROL, { 3000, 0, 2000 }, { "shift" } } }
		)
		assert.are.same({ CMD.FIGHT, { 2950, 0, 1000 }, { "alt" } }, given[1][1])
		assert.are.same({ CMD.PATROL, { 3050, 0, 2000 }, { "shift" } }, given[2][2])
	end)

	it("gives an order on a target to each unit as written, in its place in the list", function()
		local attack = { CMD.ATTACK, { 77 }, {} }
		march(sideBySide(), { moveTo(3000, 1000), attack })
		assert.are.equal(attack, given[1][2])
		assert.are.equal(attack, given[2][2])
	end)

	it("gives factories, nanoframes and transported units the orders as written", function()
		local orders = { moveTo(3000, 1000) }
		march({
			[1] = { x = 0, z = 0 },
			[2] = { x = 50, z = 0, def = 2 },
			[3] = { x = 100, z = 0, beingBuilt = true },
			[4] = { x = 150, z = 0, transporter = 9 },
		}, orders)
		for unitID = 2, 4 do
			assert.are.equal(orders, given[unitID])
		end
		assert.are.same({ 3000, 1000 }, { spot(1) })
	end)

	it("keeps the spots on the map", function()
		march({ [1] = { x = 0, z = 0 }, [2] = { x = 400, z = 0 } }, { moveTo(MAP_SIZE - 10, 10) })
		local x2 = spot(2)
		local _, z1 = spot(1)
		assert.are.equal(MAP_SIZE - 8, x2)
		assert.are.equal(10, z1)
	end)

	describe("direction", function()
		it("turns the group to a compass angle", function()
			march(sideBySide(), { moveTo(3000, 1000) }, { angle = 90 })
			local x1, z1 = spot(1)
			local x2, z2 = spot(2)
			assert.is_true(near(3000, x1) and near(3000, x2))
			assert.is_true(near(1050, z1) and near(950, z2))
		end)

		it("does not turn the group for the way it already faces", function()
			march(sideBySide(), { moveTo(3000, 1000) }, { angle = 180 })
			local x1, z1 = spot(1)
			assert.is_true(near(2950, x1) and near(1000, z1))
		end)

		it("turns the group to face a point from each order's point", function()
			march(sideBySide(), { moveTo(3000, 1000), moveTo(3000, 2000, { "shift" }) }, { x = 3000, z = 5000 })
			assert.is_true(near(2950, spot(1, 2)))
			march(sideBySide(), { moveTo(3000, 1000) }, { x = 4000, z = 1000 })
			local x1, z1 = spot(1)
			assert.is_true(near(3000, x1) and near(1050, z1))
		end)

		it("keeps the shape when the units face opposite ways", function()
			local opposite = sideBySide()
			opposite[2].heading = math.pi
			march(opposite, { moveTo(3000, 1000) }, { angle = 90 })
			local x1, z1 = spot(1)
			assert.is_true(near(2950, x1) and near(1000, z1))
		end)
	end)
end)
