---
--- Spatial parameter validators: Position, Positions and Area.
---

local V = require("mission_api.validation.validation_spec_helper")

describe("mission_api.validation.spatial_validators", function()
	before_each(V.mockEngineGlobals)

	--- Validates the area parameter of the trigger under test.
	local function validateArea(area)
		return V.validateTrigger(V.trigger(V.triggerTypes.UnitEnteredLocation, { area = area, unitName = 'x' }))
	end

	describe("Position", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({ type = V.actionTypes.AddMarker, parameters = { position = 'bad' } })

			V.assertMessage(result, "Unexpected parameter type, expected table, got string. Action: a, Parameter: position")
		end)

		it("rejects a missing coordinate", function()
			local result = V.validateAction({ type = V.actionTypes.AddMarker, parameters = { position = { z = 0 } } })

			V.assertMessage(result, "Missing required parameter. Action: a, Parameter: position.x")
		end)

		it("rejects a coordinate that is not a number", function()
			local result = V.validateAction({
				type       = V.actionTypes.AddMarker,
				parameters = { position = { x = 'bad', z = 0 } },
			})

			V.assertMessage(result, "Unexpected parameter type, expected number, got string. Action: a, Parameter: position.x")
		end)

		it("rejects a false coordinate as the wrong type, not as missing", function()
			local result = V.validateAction({
				type       = V.actionTypes.AddMarker,
				parameters = { position = { x = false, z = 0 } },
			})

			V.assertMessage(result, "Unexpected parameter type, expected number, got boolean. Action: a, Parameter: position.x")
			V.assertNoMessage(result, "Missing required parameter. Action: a, Parameter: position.x")
		end)

		it("accepts zero coordinates", function()
			local result = V.validateAction({
				type       = V.actionTypes.AddMarker,
				parameters = { position = { x = 0, y = 0, z = 0 }, name = 'flag' },
			})

			V.assertNoMessageContaining(result, "Parameter: position")
		end)
	end)

	describe("Positions", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({ type = V.actionTypes.DrawLines, parameters = { positions = 'bad' } })

			V.assertMessage(result, "Unexpected parameter type, expected table, got string. Action: a, Parameter: positions")
		end)

		it("rejects fewer than two positions", function()
			local result = V.validateAction({
				type       = V.actionTypes.DrawLines,
				parameters = { positions = { { x = 0, z = 0 } } },
			})

			V.assertMessage(result, "Positions table needs at least two positions. Action: a, Parameter: positions")
		end)

		it("rejects an entry that is not a table", function()
			local result = V.validateAction({
				type       = V.actionTypes.DrawLines,
				parameters = { positions = { 'bad', { x = 0, z = 0 } } },
			})

			V.assertMessage(result, "Unexpected parameter type, expected table, got string. Action: a, Parameter: positions[1]")
		end)

		it("rejects an entry with a missing coordinate", function()
			local result = V.validateAction({
				type       = V.actionTypes.DrawLines,
				parameters = { positions = { { z = 0 }, { x = 0, z = 0 } } },
			})

			V.assertMessage(result, "Missing required parameter. Action: a, Parameter: positions[1].x")
		end)
	end)

	describe("Area", function()
		it("rejects the wrong type", function()
			V.assertMessage(validateArea('bad'),
				"Unexpected parameter type, expected table, got string. Trigger: t, Parameter: area")
		end)

		it("rejects a table that is neither a rectangle nor a circle", function()
			V.assertMessage(validateArea({}),
				"Invalid area parameter, must be either rectangle { x1, z1, x2, z2 } with x1 < x2 and z1 < z2, or circle { x, z, radius }. Trigger: t, Parameter: area")
		end)

		it("rejects a field that is not a number", function()
			V.assertMessage(validateArea({ x1 = 'bad', z1 = 0, x2 = 1, z2 = 1 }),
				"Unexpected parameter type, expected number, got string. Trigger: t, Parameter: area.x1")
		end)

		it("rejects a rectangle whose x1 is not less than x2", function()
			V.assertMessage(validateArea({ x1 = 1, z1 = 0, x2 = 0, z2 = 1 }),
				"Invalid area rectangle parameter, x1 must be less than x2. Trigger: t, Parameter: area")
		end)

		it("rejects a rectangle whose z1 is not less than z2", function()
			V.assertMessage(validateArea({ x1 = 0, z1 = 1, x2 = 1, z2 = 0 }),
				"Invalid area rectangle parameter, z1 must be less than z2. Trigger: t, Parameter: area")
		end)

		it("accepts a circle", function()
			V.assertNoMessageContaining(validateArea({ x = 0, z = 0, radius = 10 }), "area")
		end)
	end)
end)
