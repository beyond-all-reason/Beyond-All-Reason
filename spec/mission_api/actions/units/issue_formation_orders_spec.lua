local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes and .UnitQuery at load time.
Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/units/issue_formation_orders.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local MAP_SIZE = 4096

describe("mission_api.actions.issue_formation_orders", function()
	---@type table<integer, table>
	local units
	---@type table<integer, table>
	local given
	---@type table<integer, table>
	local matched

	-- units: unitID -> { x, z, heading (radians), queue, def, dead, beingBuilt, transporter }
	local function setUnits(newUnits)
		units = newUnits
		local builder = Builders.MissionApi.new()
		for unitID in pairs(units) do
			builder:WithTrackedUnit("squad", unitID)
		end
		builder:Install()
	end

	before_each(function()
		given, matched = {}, {}
		_G.CMD = { MOVE = 10, PATROL = 15, FIGHT = 16, REPAIR = 40, RECLAIM = 90, CAPTURE = 130 } ---@diagnostic disable-line: global-in-non-module
		_G.Game = { mapSizeX = MAP_SIZE, mapSizeZ = MAP_SIZE, squareSize = 8 } ---@diagnostic disable-line: global-in-non-module
		_G.UnitDefs = { [1] = { canMove = true }, [2] = { canMove = false } } ---@diagnostic disable-line: global-in-non-module
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
			GetUnitCommandCount = function(unitID)
				return #(units[unitID].queue or {})
			end,

			GetGroundHeight = function()
				return 0
			end,
			GiveOrderToUnit = function(unitID, command, params, options)
				given[#given + 1] = {
					unitID = unitID,
					command = command,
					x = params[1],
					z = params[3],
					options = options,
					fenced = GG["MissionAPI"].issuingOrders,
				}
			end,
		}
		GG["MissionAPIActionHelper"] = {
			matchFormationSpeed = function(unitIDs, targets, command)
				matched[#matched + 1] = { unitIDs = unitIDs, targets = targets, command = command }
			end,
		}
	end)

	local function ordersByUnit()
		local orders = {}
		for _, order in ipairs(given) do
			orders[order.unitID] = order
		end
		return orders
	end

	local function issue(parameters)
		action.actionFunction(
			parameters.unitName or "squad",
			parameters.command,
			parameters.position,
			parameters.positions,
			parameters.direction,
			parameters.queue,
			parameters.matchSpeed
		)
	end

	local function near(expected, actual)
		return math.abs(expected - actual) < 0.001
	end

	it("declares its type and parameters", function()
		assert.are.same({
			type = "IssueFormationOrders",
			unitName = "UnitName!",
			command = "MoveCommand",
			position = "Position",
			positions = "Positions",
			direction = "Direction",
			queue = "Boolean",
			matchSpeed = "Boolean",
			requiresOneOf = { "position", "positions" },
		}, summarizeSchema(action))
	end)

	it("declares its parameters in the order the action function takes them", function()
		local names = {}
		for i, parameter in ipairs(action.parameters) do
			names[i] = parameter.name
		end
		assert.are.same({ "unitName", "command", "position", "positions", "direction", "queue", "matchSpeed" }, names)
	end)

	it("is a no-op for an untracked unit name", function()
		setUnits({})
		issue({ unitName = "nobody", position = { x = 100, z = 100 } })
		assert.are.equal(0, #given)
	end)

	it("keeps the shape around the position, one move order per unit", function()
		setUnits({ [1] = { x = 100, z = 100 }, [2] = { x = 200, z = 100 } })
		issue({ position = { x = 1000, z = 1000 } })
		local orders = ordersByUnit()
		assert.are.equal(2, #given)
		assert.are.equal(950, orders[1].x)
		assert.are.equal(1050, orders[2].x)
		assert.are.equal(1000, orders[1].z)
		assert.are.equal(CMD.MOVE, orders[1].command)
		assert.are.same({}, orders[1].options)
	end)

	it("gives the command it was given, inside the issuingOrders fence", function()
		setUnits({ [1] = { x = 100, z = 100 } })
		issue({ command = CMD.FIGHT, position = { x = 1000, z = 1000 } })
		assert.are.equal(CMD.FIGHT, given[1].command)
		assert.is_true(given[1].fenced)
		assert.is_nil(GG["MissionAPI"].issuingOrders)
	end)

	it("spreads the units along a line, matched at the lowest total cost", function()
		setUnits({ [1] = { x = 100, z = 0 }, [2] = { x = 300, z = 0 }, [3] = { x = 200, z = 0 } })
		issue({ positions = { { x = 100, z = 500 }, { x = 500, z = 500 } } })
		local orders = ordersByUnit()
		assert.are.equal(100, orders[1].x)
		assert.are.equal(300, orders[3].x)
		assert.are.equal(500, orders[2].x)
		assert.are.equal(500, orders[2].z)
	end)

	describe("direction", function()
		-- Side by side along x, both facing south.
		local function sideBySide()
			setUnits({ [1] = { x = 1000, z = 1000, heading = 0 }, [2] = { x = 1100, z = 1000, heading = 0 } })
		end

		it("turns the shape to a compass angle", function()
			sideBySide()
			issue({ position = { x = 3000, z = 1000 }, direction = { angle = 90 } })
			local orders = ordersByUnit()
			assert.is_true(near(3000, orders[1].x) and near(3000, orders[2].x))
			assert.is_true(near(100, math.abs(orders[1].z - orders[2].z)))
		end)

		it("does not turn the shape for the way it already faces", function()
			sideBySide()
			issue({ position = { x = 3000, z = 1000 }, direction = { angle = 180 } })
			local orders = ordersByUnit()
			assert.is_true(near(2950, orders[1].x) and near(3050, orders[2].x))
		end)

		it("turns the shape to face a point from the position", function()
			sideBySide()
			issue({ position = { x = 3000, z = 1000 }, direction = { x = 4000, z = 1000 } })
			local orders = ordersByUnit()
			assert.is_true(near(3000, orders[1].x) and near(3000, orders[2].x))
			assert.is_true(near(100, math.abs(orders[1].z - orders[2].z)))
		end)

		it("turns from the way to the position when the units face opposite ways", function()
			setUnits({ [1] = { x = 1000, z = 1000, heading = 0 }, [2] = { x = 1100, z = 1000, heading = math.pi } })
			issue({ position = { x = 3000, z = 1000 }, direction = { angle = 180 } })
			local orders = ordersByUnit()
			assert.is_true(near(3000, orders[1].x) and near(3000, orders[2].x))
			assert.is_true(near(100, math.abs(orders[1].z - orders[2].z)))
		end)

	end)

	describe("queue", function()
		local function queued(x, z)
			return { { id = CMD.MOVE, params = { x, 0, z } } }
		end

		it("queues with the shift option, from where each unit's queue ends", function()
			setUnits({
				[1] = { x = 0, z = 0, queue = queued(500, 500) },
				[2] = { x = 0, z = 0, queue = queued(600, 500) },
			})
			issue({ position = { x = 2000, z = 2000 }, queue = true })
			local orders = ordersByUnit()
			assert.are.same({ "shift" }, orders[1].options)
			assert.are.equal(1950, orders[1].x)
			assert.are.equal(2050, orders[2].x)
		end)

		it("reads the position of a repair, reclaim or capture on a unit inside an area", function()
			setUnits({
				[1] = { x = 0, z = 0, queue = { { id = CMD.REPAIR, params = { 77, 500, 0, 500, 100 } } } },
				[2] = { x = 0, z = 0, queue = queued(600, 500) },
			})
			issue({ position = { x = 2000, z = 2000 }, queue = true })
			local orders = ordersByUnit()
			assert.are.equal(1950, orders[1].x)
			assert.are.equal(2050, orders[2].x)
		end)

		it("does not pace a unit with orders already queued", function()
			setUnits({
				[1] = { x = 0, z = 0, queue = queued(500, 500) },
				[2] = { x = 100, z = 0 },
				[3] = { x = 200, z = 0 },
			})
			issue({ position = { x = 2000, z = 2000 }, queue = true, matchSpeed = true })
			assert.are.same({ 2, 3 }, matched[1].unitIDs)
		end)

		it("starts from where the unit stands when nothing queued has a position", function()
			setUnits({
				[1] = { x = 500, z = 500, queue = { { id = CMD.REPAIR, params = { 77 } } } },
				[2] = { x = 600, z = 500 },
			})
			issue({ position = { x = 2000, z = 2000 }, queue = true })
			local orders = ordersByUnit()
			assert.are.equal(1950, orders[1].x)
			assert.are.equal(2050, orders[2].x)
		end)
	end)

	describe("matchSpeed", function()
		it("hands the units, their targets and the command to the helper", function()
			setUnits({ [1] = { x = 100, z = 100 }, [2] = { x = 200, z = 100 } })
			issue({ command = CMD.PATROL, position = { x = 1000, z = 1000 }, matchSpeed = true })
			assert.are.equal(1, #matched)
			assert.are.same({ 1, 2 }, matched[1].unitIDs)
			assert.are.same({ { x = 950, z = 1000 }, { x = 1050, z = 1000 } }, matched[1].targets)
			assert.are.equal(CMD.PATROL, matched[1].command)
		end)

		it("hands the targets kept on the map", function()
			setUnits({ [1] = { x = 0, z = 0 }, [2] = { x = 400, z = 0 } })
			issue({ position = { x = MAP_SIZE - 10, z = 10 }, matchSpeed = true })
			assert.are.equal(MAP_SIZE - Game.squareSize, matched[1].targets[2].x)
		end)

		it("does not match speeds unless asked", function()
			setUnits({ [1] = { x = 100, z = 100 }, [2] = { x = 200, z = 100 } })
			issue({ position = { x = 1000, z = 1000 } })
			assert.are.equal(0, #matched)
		end)
	end)

	it("leaves out dead units, units that cannot move, units under construction and transported units", function()
		setUnits({
			[1] = { x = 0, z = 0 },
			[2] = { x = 50, z = 0, def = 2 },
			[3] = { x = 100, z = 0, dead = true },
			[4] = { x = 150, z = 0, beingBuilt = true },
			[5] = { x = 200, z = 0, transporter = 2 },
		})
		issue({ position = { x = 1000, z = 1000 } })
		assert.are.equal(1, #given)
		assert.are.equal(1, given[1].unitID)
	end)

	it("keeps the targets on the map", function()
		setUnits({ [1] = { x = 0, z = 0 }, [2] = { x = 400, z = 0 } })
		issue({ position = { x = MAP_SIZE - 10, z = 10 } })
		for _, order in ipairs(given) do
			assert.is_true(order.x <= MAP_SIZE - Game.squareSize)
			assert.is_true(order.z >= Game.squareSize)
		end
		assert.are.equal(MAP_SIZE - Game.squareSize, ordersByUnit()[2].x)
	end)

	it("orders the units by unitID", function()
		setUnits({ [30] = { x = 0, z = 0 }, [10] = { x = 100, z = 0 }, [20] = { x = 200, z = 0 } })
		issue({ position = { x = 1000, z = 1000 } })
		assert.are.same({ 10, 20, 30 }, { given[1].unitID, given[2].unitID, given[3].unitID })
	end)
end)
