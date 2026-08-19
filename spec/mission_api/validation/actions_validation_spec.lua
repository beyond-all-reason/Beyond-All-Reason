---
--- Action validation: action shape and trigger references.
---

local V = require("mission_api.validation.validation_spec_helper")

describe("mission_api.validation.actions_validation", function()
	before_each(V.mockEngineGlobals)

	it("passes for a valid action referenced by a trigger", function()
		V.assertValid(V.validateAction({ type = V.actionTypes.SendMessage, parameters = { message = "ok" } }))
	end)

	it("reports a missing type", function()
		V.assertMessage(V.validateAction({}), "Action missing type. Action: a")
	end)

	it("reports an invalid type", function()
		V.assertMessage(V.validateAction({ type = 'notAType' }), "Action has invalid type. Action: a")
	end)

	it("reports action data that is not a table", function()
		local result = V.validate(V.mission()
			:WithTrigger('t', V.trigger(V.triggerTypes.TimeElapsed, { seconds = 1 }))
			:WithAction('ok', 'notATable'))

		V.assertMessage(result, "Action data must be a table, got string. Action: ok")
	end)

	describe("trigger references", function()
		it("reports actions that no trigger references", function()
			local result = V.validate(V.mission()
				:WithTrigger('t', V.trigger(V.triggerTypes.TimeElapsed, { seconds = 1 }))
				:WithAction('ok', { type = V.actionTypes.SendMessage, parameters = { message = "ok" } })
				:WithAction('unused', { type = V.actionTypes.SendMessage, parameters = { message = "unused" } }))

			V.assertMessage(result, "Actions not referenced by any trigger: unused")
		end)

		it("lists unreferenced actions in sorted order", function()
			local result = V.validate(V.mission()
				:WithTrigger('t', V.trigger(V.triggerTypes.TimeElapsed, { seconds = 1 }))
				:WithAction('ok', { type = V.actionTypes.SendMessage, parameters = { message = "ok" } })
				:WithAction('zzz', { type = V.actionTypes.SendMessage, parameters = { message = "zzz" } })
				:WithAction('aaa', { type = V.actionTypes.SendMessage, parameters = { message = "aaa" } }))

			V.assertMessage(result, "Actions not referenced by any trigger: aaa, zzz")
		end)
	end)
end)
