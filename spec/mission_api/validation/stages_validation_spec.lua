---
--- Stage validation: stage shape and the mission's initial stage.
---

local V = require("mission_api.validation.validation_spec_helper")

describe("mission_api.validation.stages_validation", function()
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
end)
