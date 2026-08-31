---
--- The validation entrypoint: mission shape, the returned result, and message grouping.
---

local V = require("mission_api.validation.validation_spec_helper")

local validation = VFS.Include("luarules/mission_api/validation.lua")

describe("mission_api.validation", function()
	before_each(V.mockEngineGlobals)

	describe("mission shape", function()
		it("passes for an empty mission", function()
			V.assertValid(V.validate({}))
		end)

		it("passes for a mission with only empty tables", function()
			V.assertValid(V.validate(V.mission()))
		end)

		-- Every mission table is normalised by the validation context, so a misdeclared
		-- one is reported instead of breaking the validators that walk it.
		for _, field in ipairs({ "Stages", "Objectives", "Triggers", "Actions", "UnitLoadout", "FeatureLoadout" }) do
			it("reports a non-table " .. field, function()
				local result = V.validate(V.mission():WithField(field, "notATable"))

				V.assertMessage(result, field .. " must be a table, got string")
				V.assertNoMessageContaining(result, "Validation failed unexpectedly")
				assert.is_false(result.ok)
			end)
		end
	end)

	describe("result", function()
		it("is ok when the mission only produces warnings", function()
			local result = V.validate(
				V.mission():WithTrigger("t", V.trigger(V.triggerTypes.TimeElapsed, { seconds = 1 })):WithAction(
					"ok",
					{ type = V.actionTypes.NameUnits, parameters = { unitName = "unreferenced", teamID = 0 } }
				)
			)

			assert.is_true(result.ok)
			assert.are.same({}, result.errors)
			assert.is_true(#result.warnings > 0)
		end)

		it("is not ok and reports the failure when validation errors out internally", function()
			local result = validation.ValidateMission({}, { ParameterTypes = V.definitions.ParameterTypes })

			assert.is_false(result.ok)
			assert.is_true(#result.errors > 0)
			assert.is_true(result.errors[#result.errors]:find("Validation failed unexpectedly", 1, true) ~= nil)
		end)
	end)

	describe("message grouping", function()
		it("sorts messages alphabetically by entity ID within a section", function()
			local result = V.validate(
				V.mission()
					:WithTrigger("zTrigger", { type = "invalidType", actions = { "ok" } })
					:WithTrigger("aTrigger", { type = "invalidType", actions = { "ok" } })
					:WithAction("ok", { type = V.actionTypes.SendMessage, parameters = { message = "ok" } })
			)

			assert.are.same({
				"Trigger has invalid type. Trigger: aTrigger",
				"Trigger has invalid type. Trigger: zTrigger",
			}, result.errors)
		end)

		it("emits one group per validated part of the mission, in a fixed order", function()
			-- One error per section, so the section order itself is asserted.
			local result = V.validate(
				V.mission()
					:WithInitialStageDefinition("s", "notATable")
					:WithObjective("o1", {})
					:WithObjective("o2", { textKey = "ok", nextStage = "nope" })
					:WithTrigger("t", { type = "invalidType", actions = { "a" } })
					:WithAction("a", { type = V.actionTypes.SendMessage, parameters = {} })
					:WithUnitLoadout({ { unitDefName = "noSuch", x = 0, z = 0, team = 0 } })
			)

			assert.are.same({
				"Stage data must be a table, got string. Stage: s",
				"Objective missing textKey. Objective: o1",
				"Trigger has invalid type. Trigger: t",
				"Action missing required parameter. Action: a, Parameter: message",
				"Invalid unitDefName: noSuch. Loadout: UnitLoadout[1].unitDefName",
				"Objective references non-existent nextStage. Objective: o2, Stage: nope",
			}, result.errors)
		end)
	end)

	describe("LogResult", function()
		local originalLog
		local logged

		before_each(function()
			logged = {}
			originalLog = Spring.Log
			Spring.Log = function(tag, level, message)
				logged[#logged + 1] = { tag = tag, level = level, message = message }
			end
		end)

		after_each(function()
			Spring.Log = originalLog
		end)

		it("logs errors before warnings, tagged and prefixed", function()
			validation.LogResult({ errors = { "an error" }, warnings = { "a warning" } })

			assert.are.same({
				{ tag = "MissionAPI", level = LOG.ERROR, message = "[Mission API] an error" },
				{ tag = "MissionAPI", level = LOG.WARNING, message = "[Mission API] a warning" },
			}, logged)
		end)

		it("logs nothing for a mission without messages", function()
			validation.LogResult(V.validate(V.mission()))

			assert.are.same({}, logged)
		end)
	end)
end)
