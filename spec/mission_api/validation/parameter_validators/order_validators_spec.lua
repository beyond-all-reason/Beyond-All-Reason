---
--- Order parameter validators, for the orders issued by IssueOrders actions.
---

local V = require("mission_api.validation.validation_spec_helper")

describe("mission_api.validation.order_validators", function()
	--- Validates the orders parameter of the action under test.
	local function validateOrders(orders)
		return V.validateAction({
			type       = V.actionTypes.IssueOrders,
			parameters = { unitName = 'x', orders = orders },
		})
	end

	before_each(function()
		V.mockEngineGlobals()

		-- The engine's CMD table maps both ways (name -> id and id -> name),
		-- which is what the known-command lookup relies on.
		_G.CMD = {}
		for i, name in ipairs({
			'STOP', 'SELFD', 'GUARD', 'DGUN', 'MOVE', 'FIGHT', 'PATROL',
			'UNLOAD_UNITS', 'AREA_ATTACK', 'RESTORE', 'ATTACK', 'CAPTURE',
			'REPAIR', 'LOAD_UNITS', 'RESURRECT', 'RECLAIM', 'CLOAK', 'ONOFF',
			'FIRE_STATE', 'MOVE_STATE',
		}) do
			CMD[name] = i
			CMD[i] = name
		end
		_G.GameCMD = { AREA_ATTACK_GROUND = 21, [21] = 'AREA_ATTACK_GROUND' }
	end)

	after_each(function()
		_G.CMD     = {}
		_G.GameCMD = {}
	end)

	it("rejects the wrong type", function()
		V.assertMessage(validateOrders('bad'),
			"Unexpected parameter type, expected table, got string. Action: a, Parameter: orders")
	end)

	it("rejects an empty orders table", function()
		V.assertMessage(validateOrders({}), "Orders table is empty. Action: a, Parameter: orders")
	end)

	it("rejects an order that is not a table", function()
		V.assertMessage(validateOrders({ 'notanorder' }),
			"Unexpected parameter type, expected table, got string. Action: a, Parameter: orders[1]")
	end)

	it("rejects a build order for a unit that does not exist", function()
		V.assertMessage(validateOrders({ { 'notAUnit', { 0, 0, 0 } } }),
			"Invalid build order unitDefName: notAUnit. Action: a, Parameter: orders[1][1]")
	end)

	it("rejects an unknown order option", function()
		V.assertMessage(validateOrders({ { CMD.STOP, nil, { 'diagonal' } } }),
			"Invalid order option: diagonal. Action: a, Parameter: orders[1][3]")
	end)

	it("rejects the wrong number of parameters for a move command", function()
		V.assertMessage(validateOrders({ { CMD.MOVE, {} } }),
			"Parameter must be an array of 3 numbers {x, y, z}. Action: a, Parameter: orders[1][2]")
	end)

	it("accepts a unit name instead of coordinates, for commands that allow it", function()
		V.assertNoMessageContaining(validateOrders({ { CMD.ATTACK, { unitName = 'x' } } }), "Parameter must be")
	end)

	it("rejects coordinates for a command that only takes a unit name", function()
		V.assertMessage(validateOrders({ { CMD.GUARD, { 0, 0, 0 } } }),
			"Parameter must be { unitName = 'aUnitName' }. Action: a, Parameter: orders[1][2]")
	end)

	it("accepts a unit name for a command that only takes a unit name", function()
		V.assertNoMessageContaining(validateOrders({ { CMD.GUARD, { unitName = 'x' } } }), "Parameter must be")
	end)

	it("reports every invalid order, named after its position in the list", function()
		local result = validateOrders({ { CMD.MOVE, { 0, 0, 0 } }, { CMD.MOVE, {} }, { 99999 } })

		V.assertMessage(result, "Parameter must be an array of 3 numbers {x, y, z}. Action: a, Parameter: orders[2][2]")
		V.assertMessage(result, "Unknown command ID: 99999. Action: a, Parameter: orders[3][1]")
	end)

	-- Commands that take no parameters are known, they just have nothing to validate.
	it("accepts a command that takes no parameters", function()
		V.assertNoMessage(validateOrders({ { CMD.STOP } }),
			"No validator implemented for orders with command ID: " .. CMD.STOP)
	end)

	it("rejects an unknown command ID", function()
		V.assertMessage(validateOrders({ { 99999, { 0, 0, 0 } } }),
			"Unknown command ID: 99999. Action: a, Parameter: orders[1][1]")
	end)
end)
