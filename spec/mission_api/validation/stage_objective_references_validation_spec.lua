---
--- References between stages and objectives: a stage's objectives, and an objective's nextStage.
---

local V = require("mission_api.validation.validation_spec_helper")

describe("mission_api.validation.stage_objective_references_validation", function()
	before_each(V.mockEngineGlobals)

	it("reports a stage referring to an objective that does not exist", function()
		local result = V.validate(V.mission()
			:WithObjective('obj1', { textKey = "ok" })
			:WithInitialStageDefinition('validStage', { objectives = { 'obj1' } })
			:WithStage('badStage', { objectives = { 'obj1', 'nonExistent' } }))

		V.assertMessage(result, "Stage refers to non-existent objective. Stage: badStage, Objective: nonExistent")
	end)

	it("skips non-string objective entries, which the stage validation reports", function()
		local result = V.validate(V.mission()
			:WithObjective('obj1', { textKey = "ok" })
			:WithInitialStageDefinition('badStage', { objectives = { 'obj1', 123 } }))

		V.assertNoMessage(result, "Stage refers to non-existent objective. Stage: badStage, Objective: 123")
	end)

	it("reports a nextStage that does not exist", function()
		local result = V.validate(V.mission()
			:WithObjective('badNext', { textKey = "ok", nextStage = 'nonExistentStage' })
			:WithInitialStageDefinition('validStage', { objectives = { 'badNext' } }))

		V.assertMessage(result, "Objective references non-existent nextStage. Objective: badNext, Stage: nonExistentStage")
	end)

	it("reports a nextStage that is not a string", function()
		local result = V.validate(V.mission()
			:WithObjective('badNextType', { textKey = "ok", nextStage = 123 })
			:WithInitialStageDefinition('validStage', { objectives = { 'badNextType' } }))

		V.assertMessage(result, "Unexpected parameter type, expected string, got number. Objective: badNextType, Field: nextStage")
	end)
end)
