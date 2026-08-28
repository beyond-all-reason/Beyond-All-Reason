---
--- References between mission entities: stages and objectives,
--- and unit, feature and marker names.
---

local V = require("mission_api.validation.validation_spec_helper")

local function spawnUnits(unitName)
	return {
		type = V.actionTypes.SpawnUnits,
		parameters = { unitLoadout = { { unitDefName = "armwar", x = 0, z = 0, team = 0, unitName = unitName } } },
	}
end

local function createFeatures(featureName)
	return {
		type = V.actionTypes.CreateFeatures,
		parameters = { featureLoadout = { { featureDefName = "rockdef", x = 0, z = 0, featureName = featureName } } },
	}
end

describe("mission_api.validation.references", function()
	before_each(V.mockEngineGlobals)

	it("reports a stage referring to an objective that does not exist", function()
		local result = V.validate(
			V.mission()
				:WithObjective("obj1", { textKey = "ok" })
				:WithInitialStageDefinition("validStage", { objectives = { "obj1" } })
				:WithStage("badStage", { objectives = { "obj1", "nonExistent" } })
		)

		V.assertMessage(result, "Stage refers to non-existent objective. Stage: badStage, Objective: nonExistent")
	end)

	it("skips non-string objective entries, which the stage validation reports", function()
		local result = V.validate(
			V.mission()
				:WithObjective("obj1", { textKey = "ok" })
				:WithInitialStageDefinition("badStage", { objectives = { "obj1", 123 } })
		)

		V.assertNoMessage(result, "Stage refers to non-existent objective. Stage: badStage, Objective: 123")
	end)

	it("reports a nextStage that does not exist", function()
		local result = V.validate(
			V.mission()
				:WithObjective("badNext", { textKey = "ok", nextStage = "nonExistentStage" })
				:WithInitialStageDefinition("validStage", { objectives = { "badNext" } })
		)

		V.assertMessage(
			result,
			"Objective references non-existent nextStage. Objective: badNext, Stage: nonExistentStage"
		)
	end)

	it("reports a nextStage that is not a string", function()
		local result = V.validate(
			V.mission()
				:WithObjective("badNextType", { textKey = "ok", nextStage = 123 })
				:WithInitialStageDefinition("validStage", { objectives = { "badNextType" } })
		)

		V.assertMessage(
			result,
			"Unexpected parameter type, expected string, got number. Objective: badNextType, Field: nextStage"
		)
	end)

	it("passes when every name is both created and referenced", function()
		V.assertValid(V.validate(V.mission()
			:WithTrigger("t", {
				type = V.triggerTypes.TotalUnitsKilled,
				parameters = { teamID = 0, quantity = 1, unitName = "bot" },
				actions = { "spawn", "create", "delete", "add", "erase" },
			})
			:WithAction("spawn", spawnUnits("bot"))
			:WithAction("create", createFeatures("rock"))
			:WithAction("delete", { type = V.actionTypes.DestroyFeatures, parameters = { featureName = "rock" } })
			:WithAction(
				"add",
				{ type = V.actionTypes.AddMarker, parameters = { position = { x = 0, z = 0 }, name = "flag" } }
			)
			:WithAction("erase", { type = V.actionTypes.EraseMarker, parameters = { name = "flag" } })))
	end)

	it("counts mission loadout entries as creating names", function()
		V.assertValid(V.validate(V.mission()
			:WithTrigger("t", {
				type = V.triggerTypes.TimeElapsed,
				parameters = { seconds = 1 },
				actions = { "destroyUnit", "destroyFeature" },
			})
			:WithAction("destroyUnit", { type = V.actionTypes.DespawnUnits, parameters = { unitName = "loadoutBot" } })
			:WithAction(
				"destroyFeature",
				{ type = V.actionTypes.DestroyFeatures, parameters = { featureName = "loadoutRock" } }
			)
			:WithUnitLoadout({ { unitDefName = "armwar", x = 0, z = 0, team = 0, unitName = "loadoutBot" } })
			:WithFeatureLoadout({ { featureDefName = "rockdef", x = 0, z = 0, featureName = "loadoutRock" } })))
	end)

	it("treats inline objective triggers as name references", function()
		V.assertValid(V.validate(V.mission()
			:WithObjective("watchBot", {
				textKey = "watch bot",
				trigger = { type = V.triggerTypes.UnitsOwned, parameters = { teamID = 0, unitName = "bot" } },
			})
			:WithObjective("watchRock", {
				textKey = "watch rock",
				trigger = { type = V.triggerTypes.FeatureDestroyed, parameters = { featureName = "rock" } },
			})
			:WithTrigger("t", {
				type = V.triggerTypes.TimeElapsed,
				parameters = { seconds = 1 },
				actions = { "spawn", "create" },
			})
			:WithAction("spawn", spawnUnits("bot"))
			:WithAction("create", createFeatures("rock"))))
	end)

	it("treats the orders of an action as name references", function()
		_G.CMD = { GUARD = 25, [25] = "GUARD" }

		V.assertValid(V.validate(V.mission()
			:WithTrigger("t", {
				type = V.triggerTypes.TimeElapsed,
				parameters = { seconds = 1 },
				actions = { "spawn", "order" },
			})
			:WithAction("spawn", spawnUnits("bot"))
			:WithAction("order", {
				type = V.actionTypes.IssueOrders,
				parameters = { unitName = "bot", orders = { { CMD.GUARD, { unitName = "bot" } } } },
			})))

		_G.CMD = {}
	end)

	-- Referencing action types come from the action schema, so actions like
	-- DestroyUnits and ReclaimUnits count without being listed by hand.
	it("counts every action taking a unitName as referencing it", function()
		V.assertValid(V.validate(V.mission()
			:WithTrigger("t", {
				type = V.triggerTypes.TimeElapsed,
				parameters = { seconds = 1 },
				actions = { "name", "destroy", "reclaim" },
			})
			:WithAction("name", { type = V.actionTypes.NameUnits, parameters = { unitName = "bot", teamID = 0 } })
			:WithAction("destroy", { type = V.actionTypes.DestroyUnits, parameters = { unitName = "bot" } })
			:WithAction("reclaim", { type = V.actionTypes.ReclaimUnits, parameters = { unitName = "bot" } })))
	end)

	it("warns about names that are only created, or only referenced", function()
		local result = V.validate(
			V.mission()
				:WithAction("spawnUnused", spawnUnits("unusedUnit"))
				:WithAction(
					"useUnknown",
					{ type = V.actionTypes.DespawnUnits, parameters = { unitName = "unknownUnit" } }
				)
				:WithAction("createUnused", createFeatures("unusedRock"))
				:WithAction(
					"deleteUnknown",
					{ type = V.actionTypes.DestroyFeatures, parameters = { featureName = "unknownRock" } }
				)
				:WithAction(
					"addUnused",
					{ type = V.actionTypes.AddMarker, parameters = { position = { x = 0, z = 0 }, name = "unusedFlag" } }
				)
				:WithAction("eraseUnknown", { type = V.actionTypes.EraseMarker, parameters = { name = "unknownFlag" } })
		)

		V.assertMessage(
			result,
			"Unit name is created, but never referenced. Unit name: unusedUnit, Created in: action spawnUnused (unitLoadout[1])"
		)
		V.assertMessage(
			result,
			"Unit name is referenced, but never created. Unit name: unknownUnit, Referenced in: action useUnknown"
		)
		V.assertMessage(
			result,
			"Feature name is created, but never referenced. Feature name: unusedRock, Created in: action createUnused (featureLoadout[1])"
		)
		V.assertMessage(
			result,
			"Feature name is referenced, but never created. Feature name: unknownRock, Referenced in: action deleteUnknown"
		)
		V.assertMessage(
			result,
			"Marker name is created, but never referenced. Marker name: unusedFlag, Created in: action addUnused"
		)
		V.assertMessage(
			result,
			"Marker name is referenced, but never created. Marker name: unknownFlag, Referenced in: action eraseUnknown"
		)
	end)

	-- Sources are comma separated, so a source must not contain a comma itself,
	-- and they are sorted so the message does not depend on table iteration order.
	it("names every source of a name separately, in a stable order", function()
		local result = V.validate(
			V.mission():WithAction("spawnUnused", spawnUnits("unusedUnit")):WithAction(
				"nameUnused",
				{ type = V.actionTypes.NameUnits, parameters = { unitName = "unusedUnit", teamID = 0 } }
			)
		)

		V.assertMessage(
			result,
			"Unit name is created, but never referenced. Unit name: unusedUnit, "
				.. "Created in: action nameUnused, action spawnUnused (unitLoadout[1])"
		)
	end)
end)
