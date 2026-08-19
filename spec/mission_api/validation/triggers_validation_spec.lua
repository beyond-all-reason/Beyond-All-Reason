---
--- Trigger validation: trigger shape, actions and settings.
---

local V = require("mission_api.validation.validation_spec_helper")

describe("mission_api.validation.triggers_validation", function()
	before_each(V.mockEngineGlobals)

	--- Validates trigger 't' with the settings under test.
	local function validateSettings(settings)
		return V.validate(V.mission()
			:WithTrigger('t', {
				type       = V.triggerTypes.TimeElapsed,
				parameters = { seconds = 1 },
				settings   = settings,
				actions    = { 'ok' },
			})
			:WithAction('ok', { type = V.actionTypes.SendMessage, parameters = { message = 'ok' } }))
	end

	describe("trigger shape", function()
		it("passes for a well-formed trigger", function()
			V.assertValid(V.validateTrigger(V.trigger(V.triggerTypes.TimeElapsed, { seconds = 1 })))
		end)

		it("reports a missing type", function()
			local result = V.validateTrigger({ actions = { 'ok' } })

			V.assertMessage(result, "Trigger missing type. Trigger: t")
		end)

		it("reports an invalid type", function()
			local result = V.validateTrigger({ type = 'notAType', actions = { 'ok' } })

			V.assertMessage(result, "Trigger has invalid type. Trigger: t")
		end)

		it("reports trigger data that is not a table", function()
			local result = V.validate(V.mission():WithTrigger('t', 'notATable'))

			V.assertMessage(result, "Trigger data must be a table, got string. Trigger: t")
		end)
	end)

	describe("actions", function()
		it("reports a trigger without actions", function()
			local result = V.validate(V.mission()
				:WithTrigger('t', { type = V.triggerTypes.TimeElapsed, parameters = { seconds = 1 } }))

			V.assertMessage(result, "Trigger has no actions. Trigger: t")
		end)

		it("reports an 'actions' field that is not a table", function()
			local result = V.validateTrigger({
				type       = V.triggerTypes.TimeElapsed,
				parameters = { seconds = 1 },
				actions    = 'notATable',
			})

			V.assertMessage(result, "Trigger 'actions' field must be a table, got string. Trigger: t")
		end)

		it("reports an action ID that does not exist", function()
			local result = V.validateTrigger({
				type       = V.triggerTypes.TimeElapsed,
				parameters = { seconds = 1 },
				actions    = { 'doesNotExist' },
			})

			V.assertMessage(result, "Trigger has invalid action ID. Trigger: t, Action: doesNotExist")
		end)
	end)

	describe("settings", function()
		-- The loaders apply the setting defaults, and they run after validation.
		it("passes for a trigger without a settings table", function()
			V.assertValid(V.validateTrigger(V.trigger(V.triggerTypes.TimeElapsed, { seconds = 1 })))
		end)

		it("reports settings that are not a table", function()
			local result = validateSettings('notATable')

			V.assertMessage(result, "Unexpected parameter type, expected table, got string. Trigger: t, Setting: settings")
		end)

		it("reports a setting of the wrong type", function()
			local result = validateSettings({ repeating = 'notABoolean' })

			V.assertMessage(result, "Unexpected parameter type, expected boolean, got string. Trigger: t, Setting: repeating")
		end)

		it("reports maxRepeats without repeating", function()
			local result = validateSettings({ maxRepeats = 3 })

			V.assertMessage(result, "Trigger has maxRepeats setting but is not set to repeating. Trigger: t")
		end)

		it("reports a negative maxRepeats", function()
			local result = validateSettings({ repeating = true, maxRepeats = -1 })

			V.assertMessage(result, "Quantity must be >= 0, got -1. Trigger: t, Setting: maxRepeats")
		end)

		describe("prerequisites", function()
			it("reports a prerequisite trigger that does not exist", function()
				local result = validateSettings({ prerequisites = { 'noSuchTrigger' } })

				V.assertMessage(result, "Invalid triggerID: noSuchTrigger. Trigger: t, Setting: prerequisites[1]")
			end)

			it("reports a prerequisite of the wrong type", function()
				local result = validateSettings({ prerequisites = { {} } })

				V.assertMessage(result, "Unexpected parameter type, expected string, got table. Trigger: t, Setting: prerequisites[1]")
			end)
		end)

		describe("stages", function()
			it("reports a stage that does not exist", function()
				local result = validateSettings({ stages = { 'noSuchStage' } })

				V.assertMessage(result, "Invalid stageID: noSuchStage. Trigger: t, Setting: stages[1]")
			end)

			it("reports a stage of the wrong type", function()
				local result = validateSettings({ stages = { 123 } })

				V.assertMessage(result, "Unexpected parameter type, expected string, got number. Trigger: t, Setting: stages[1]")
			end)
		end)
	end)
end)
