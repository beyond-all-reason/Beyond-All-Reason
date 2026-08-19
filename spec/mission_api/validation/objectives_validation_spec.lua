---
--- Objective validation: objective fields and inline objective triggers.
---

local V = require("mission_api.validation.validation_spec_helper")

--- Validates objective 'o', the one under test.
local function validateObjective(objective)
	return V.validate(V.mission():WithObjective('o', objective))
end

--- Validates objective 'o' with the inline trigger under test.
local function validateObjectiveTrigger(trigger)
	return validateObjective({ textKey = "ok", trigger = trigger })
end

describe("mission_api.validation.objectives_validation", function()
	before_each(V.mockEngineGlobals)

	describe("objective fields", function()
		it("passes for a well-formed objective without a trigger", function()
			V.assertValid(validateObjective({ textKey = "Do the thing." }))
		end)

		it("reports a missing textKey", function()
			V.assertMessage(validateObjective({}), "Objective missing textKey. Objective: o")
		end)

		it("reports an empty textKey", function()
			V.assertMessage(validateObjective({ textKey = "" }), "Objective has empty textKey. Objective: o")
		end)

		it("reports incorrect field types", function()
			local result = validateObjective({
				textKey = "ok",
				amount  = 'notANumber',
				coop    = 'notABoolean',
			})

			V.assertMessage(result, "Unexpected parameter type, expected number, got string. Objective: o, Field: amount")
			V.assertMessage(result, "Unexpected parameter type, expected boolean, got string. Objective: o, Field: coop")
		end)
	end)

	describe("inline trigger", function()
		it("passes for a valid inline trigger", function()
			V.assertValid(validateObjectiveTrigger({
				type       = V.triggerTypes.TimeElapsed,
				parameters = { seconds = 90 },
			}))
		end)

		it("reports a 'settings' field", function()
			local result = validateObjectiveTrigger({
				settings   = { repeating = true },
				type       = V.triggerTypes.TimeElapsed,
				parameters = { seconds = 1 },
			})

			V.assertMessage(result, "Objective trigger must not have a 'settings' field. Objective: o")
		end)

		it("reports an 'actions' field", function()
			local result = validateObjectiveTrigger({
				type       = V.triggerTypes.TimeElapsed,
				parameters = { seconds = 1 },
				actions    = { 'someAction' },
			})

			V.assertMessage(result, "Objective trigger must not have an 'actions' field. Objective: o")
		end)

		it("reports a missing type", function()
			local result = validateObjectiveTrigger({ parameters = { seconds = 1 } })

			V.assertMessage(result, "Objective trigger missing type. Objective: o")
		end)

		it("reports an invalid type", function()
			local result = validateObjectiveTrigger({ type = 'notAType' })

			V.assertMessage(result, "Objective trigger has invalid type. Objective: o")
		end)

		it("reports a missing required parameter", function()
			local result = validateObjectiveTrigger({
				type       = V.triggerTypes.TimeElapsed,
				parameters = {},
			})

			V.assertMessage(result, "Objective trigger missing required parameter. Objective: o, Parameter: seconds")
		end)

		-- Objective triggers take their quantity from the objective's own amount.
		it("warns when a statistics trigger specifies quantity", function()
			local result = validateObjectiveTrigger({
				type       = V.triggerTypes.UnitsOwned,
				parameters = { teamID = 0, quantity = 5, unitDefName = 'armwar' },
			})

			V.assertMessage(result, "Objective trigger 'quantity' is not supported and will be ignored. Objective: o")
		end)
	end)
end)
