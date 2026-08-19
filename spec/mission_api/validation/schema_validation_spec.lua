---
--- Schema driven parameter validation, shared by triggers, actions and objective triggers.
---

local V = require("mission_api.validation.validation_spec_helper")

describe("mission_api.validation.schema_validation", function()
	before_each(V.mockEngineGlobals)

	it("reports a missing required action parameter", function()
		local result = V.validateAction({ type = V.actionTypes.EnableTrigger, parameters = {} })

		V.assertMessage(result, "Action missing required parameter. Action: a, Parameter: triggerID")
	end)

	it("reports a missing required trigger parameter", function()
		local result = V.validateTrigger(V.trigger(V.triggerTypes.TimeElapsed, {}))

		V.assertMessage(result, "Trigger missing required parameter. Trigger: t, Parameter: seconds")
	end)

	it("reports parameters that are not a table", function()
		local result = V.validateAction({ type = V.actionTypes.SendMessage, parameters = 'notATable' })

		V.assertMessage(result, "Unexpected parameter type, expected table, got string. Action: a, Parameter: parameters")
	end)

	it("passes for an action whose parameters are all optional and omitted", function()
		V.assertValid(V.validateAction({ type = V.actionTypes.ClearAllMarkers }))
	end)

	-- Each parameter is validated by the validator its schema names.
	it("validates a parameter using its declared type", function()
		local result = V.validateAction({ type = V.actionTypes.SendMessage, parameters = { message = 123 } })

		V.assertMessage(result, "Unexpected parameter type, expected string, got number. Action: a, Parameter: message")
	end)

	describe("requiresOneOf", function()
		it("reports when none of the alternatives is present", function()
			local result = V.validateTrigger(V.trigger(V.triggerTypes.UnitKilled, {}))

			V.assertMessage(result,
				[[Trigger is missing required parameter, at least one of {"unitName","unitDefName"} is required. Trigger: t]])
		end)

		it("passes when one of the alternatives is present", function()
			local result = V.validateTrigger(V.trigger(V.triggerTypes.UnitKilled, { unitDefName = 'armwar' }))

			V.assertNoMessageContaining(result, "is missing required parameter")
		end)
	end)
end)
