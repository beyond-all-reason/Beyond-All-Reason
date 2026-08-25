---
--- Validation of the mission's sections: stages, objectives, triggers, actions
--- and loadouts, and the schema driven parameter validation they share.
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

describe("mission_api.validation.sections", function()
	before_each(V.mockEngineGlobals)

	describe("stages", function()
		it("passes for well-formed stages", function()
			V.assertValid(V.validate(V.mission()
				:WithStage('stageA', { objectives = { 'obj1' } })
				:WithStage('stageB', { objectives = { 'obj1', 'obj2' } })
				:WithObjective('obj1', { textKey = "ok" })
				:WithObjective('obj2', { textKey = "ok" })
				:WithInitialStage('stageA')))
		end)

		it("reports a stage ID that is not a string", function()
			local result = V.validate(V.mission()
				:WithInitialStageDefinition(123, { objectives = { 'obj1' } })
				:WithObjective('obj1', { textKey = "ok" }))

			V.assertMessage(result, "Stage ID must be a string, got number. Stage: 123")
		end)

		it("reports stage data that is not a table", function()
			local result = V.validate(V.mission():WithInitialStageDefinition('badStage', 'notATable'))

			V.assertMessage(result, "Stage data must be a table, got string. Stage: badStage")
		end)

		it("reports a stage missing the 'objectives' field", function()
			local result = V.validate(V.mission():WithInitialStageDefinition('noObjectives', {}))

			V.assertMessage(result, "Stage missing 'objectives' field. Stage: noObjectives")
		end)

		it("reports an 'objectives' field that is not a table", function()
			local result = V.validate(V.mission()
				:WithInitialStageDefinition('badObjectives', { objectives = 'notATable' }))

			V.assertMessage(result, "Stage 'objectives' field must be a table, got string. Stage: badObjectives")
		end)

		it("reports an objective ID that is not a string", function()
			local result = V.validate(V.mission()
				:WithInitialStageDefinition('badEntry', { objectives = { 'obj1', 123 } })
				:WithObjective('obj1', { textKey = "ok" }))

			V.assertMessage(result, "Stage 'objectives' entry must be a string, got number. Stage: badEntry, Entry: 2")
		end)

		it("warns about an empty 'objectives' table", function()
			local result = V.validate(V.mission():WithInitialStageDefinition('empty', { objectives = {} }))

			V.assertMessage(result, "Stage has empty 'objectives' table. Stage: empty")
		end)
	end)

	describe("initial stage", function()
		it("passes when stages are defined and initialStage matches", function()
			V.assertValid(V.validate(V.mission()
				:WithInitialStageDefinition('stageA', { objectives = { 'obj' } })
				:WithObjective('obj', { textKey = "ok" })))
		end)

		it("passes when no stages are defined and no initialStage is set", function()
			V.assertValid(V.validate(V.mission()))
		end)

		it("reports stages defined without an initialStage", function()
			local result = V.validate(V.mission()
				:WithStage('stageA', { objectives = { 'obj' } })
				:WithObjective('obj', { textKey = "ok" }))

			V.assertMessage(result, "Stages are defined, but initialStage is not provided")
		end)

		it("reports an initialStage that does not exist", function()
			local result = V.validate(V.mission()
				:WithStage('stageA', { objectives = { 'obj' } })
				:WithObjective('obj', { textKey = "ok" })
				:WithInitialStage('stageB'))

			V.assertMessage(result, "Initial stage does not exist in stages. Stage: stageB")
		end)

		it("warns when initialStage is set but no stages are defined", function()
			local result = V.validate(V.mission():WithInitialStage('stageA'))

			V.assertMessage(result, "initialStage is set, but no stages are defined. Stage: stageA")
		end)
	end)

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

	it("passes for a mission without loadouts", function()
		V.assertValid(V.validate(V.mission()))
	end)

	it("validates loadout entries", function()
		local result = V.validate(V.mission()
			:WithUnitLoadout({ { unitDefName = 'noSuch', x = 0, z = 0, team = 0 } })
			:WithFeatureLoadout({ { featureDefName = 'rockdef', z = 0 } }))

		V.assertMessage(result, "Invalid unitDefName: noSuch. Loadout: UnitLoadout[1].unitDefName")
		V.assertMessage(result, "Missing required parameter. Loadout: FeatureLoadout[1].x")
	end)

	it("reports loadouts that are not tables", function()
		local result = V.validate(V.mission()
			:WithUnitLoadout('notATable')
			:WithFeatureLoadout(42))

		V.assertMessage(result, "UnitLoadout must be a table, got string")
		V.assertMessage(result, "FeatureLoadout must be a table, got number")
	end)

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
