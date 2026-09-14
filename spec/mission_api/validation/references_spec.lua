---
--- References between mission entities: stages and objectives,
--- unit, feature and marker names, and countdown IDs.
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

	-- A trigger can name several units at once, e.g. a passenger and its transport,
	-- so every parameter of the name's type counts, not just the conventional one.
	it("counts every parameter taking a unitName as referencing it", function()
		V.assertValid(V.validate(V.mission()
			:WithTrigger("t", {
				type = V.triggerTypes.TransportLoaded,
				parameters = { transportName = "dropship", passengerName = "bot" },
				actions = { "ok" },
			})
			:WithTrigger("start", {
				type = V.triggerTypes.TimeElapsed,
				parameters = { seconds = 1 },
				actions = { "spawnDropship", "spawnBot" },
			})
			:WithAction("spawnDropship", spawnUnits("dropship"))
			:WithAction("spawnBot", spawnUnits("bot"))
			:WithAction("ok", { type = V.actionTypes.SendMessage, parameters = { message = "ok" } })))
	end)

	it("warns about names that are only created, or only referenced", function()
		local result = V.validate(V.mission()
			:WithAction("spawnUnused", spawnUnits("unusedUnit"))
			:WithAction("useUnknown", { type = V.actionTypes.DespawnUnits, parameters = { unitName = "unknownUnit" } })
			:WithAction("createUnused", createFeatures("unusedRock"))
			:WithAction(
				"deleteUnknown",
				{ type = V.actionTypes.DestroyFeatures, parameters = { featureName = "unknownRock" } }
			)
			:WithAction("addUnused", {
				type = V.actionTypes.AddMarker,
				parameters = { position = { x = 0, z = 0 }, name = "unusedFlag" },
			})
			:WithAction("eraseUnknown", { type = V.actionTypes.EraseMarker, parameters = { name = "unknownFlag" } }))

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

	describe("countdown IDs", function()
		it("passes countdowns that are added, including ones left to run out", function()
			V.assertValid(
				V.validate(
					V.mission()
						:WithObjective("surviveBomb", {
							textKey = "survive",
							trigger = { type = V.triggerTypes.CountdownFinished, parameters = { countdownID = "bomb" } },
						})
						:WithTrigger("start", {
							type = V.triggerTypes.TimeElapsed,
							parameters = { seconds = 1 },
							actions = { "addBomb", "addLone" },
						})
						:WithTrigger("bombDone", {
							type = V.triggerTypes.CountdownFinished,
							parameters = { countdownID = "bomb" },
							actions = { "pauseBomb" },
						})
						:WithAction(
							"addBomb",
							{ type = V.actionTypes.AddCountdown, parameters = { countdownID = "bomb", seconds = 60 } }
						)
						:WithAction(
							"pauseBomb",
							{ type = V.actionTypes.PauseCountdown, parameters = { countdownID = "bomb" } }
						)
						:WithAction(
							"addLone",
							{ type = V.actionTypes.AddCountdown, parameters = { countdownID = "lone", seconds = 10 } }
						)
				)
			)
		end)

		it("warns about a countdown an action refers to, but no action adds", function()
			local result = V.validate(
				V.mission():WithAction(
					"cancelGhost",
					{ type = V.actionTypes.CancelCountdown, parameters = { countdownID = "ghost" } }
				)
			)

			V.assertMessage(
				result,
				"Countdown is referenced, but never added. Countdown: ghost, Referenced in: action cancelGhost"
			)
		end)

		-- Every action taking a countdownID counts, straight from the action schema.
		it("warns about time adjustments on countdowns that are never added", function()
			local result = V.validate(
				V.mission()
					:WithAction(
						"setGhost",
						{ type = V.actionTypes.SetTime, parameters = { countdownID = "setID", seconds = 5 } }
					)
					:WithAction(
						"addGhost",
						{ type = V.actionTypes.AddTime, parameters = { countdownID = "addID", seconds = 5 } }
					)
					:WithAction(
						"removeGhost",
						{ type = V.actionTypes.RemoveTime, parameters = { countdownID = "removeID", seconds = 5 } }
					)
			)

			V.assertMessage(
				result,
				"Countdown is referenced, but never added. Countdown: setID, Referenced in: action setGhost"
			)
			V.assertMessage(
				result,
				"Countdown is referenced, but never added. Countdown: addID, Referenced in: action addGhost"
			)
			V.assertMessage(
				result,
				"Countdown is referenced, but never added. Countdown: removeID, Referenced in: action removeGhost"
			)
		end)

		it("warns about a countdown a trigger refers to, but no action adds", function()
			local result = V.validate(V.mission()
				:WithTrigger("watchGhost", {
					type = V.triggerTypes.CountdownReached,
					parameters = { countdownID = "ghost", timeRemaining = 10 },
					actions = { "ok" },
				})
				:WithAction("ok", { type = V.actionTypes.SendMessage, parameters = { message = "ok" } }))

			V.assertMessage(
				result,
				"Countdown is referenced, but never added. Countdown: ghost, Referenced in: trigger watchGhost"
			)
		end)

		it("warns about a countdown an inline objective trigger refers to, but no action adds", function()
			local result = V.validate(V.mission():WithObjective("surviveGhost", {
				textKey = "survive",
				trigger = { type = V.triggerTypes.CountdownFinished, parameters = { countdownID = "ghost" } },
			}))

			V.assertMessage(
				result,
				"Countdown is referenced, but never added. Countdown: ghost, "
					.. "Referenced in: objective surviveGhost (trigger)"
			)
		end)
	end)

	-- The on* fields name an Event trigger, raised when the objective reaches that state.
	-- sections.lua checks the trigger exists; these checks cover the Event-specific rules.
	describe("objective events", function()
		for _, fieldName in ipairs({ "onActivated", "onCanceled", "onProgress", "onCompleted", "onFailed" }) do
			it("accepts " .. fieldName .. " naming an Event trigger", function()
				local result = V.validate(
					V.mission()
						:WithObjective("obj", { textKey = "ok", [fieldName] = "raised" })
						:WithTrigger("raised", { type = V.triggerTypes.Event, actions = { "act" } })
						:WithAction("act", { type = V.actionTypes.SendMessage, parameters = { message = "ok" } })
						:WithInitialStageDefinition("stage", { objectives = { "obj" } })
				)

				V.assertValid(result)
			end)

			it("reports " .. fieldName .. " naming a trigger that is not an Event", function()
				local result = V.validate(V.mission()
					:WithObjective("obj", { textKey = "ok", [fieldName] = "timer" })
					:WithTrigger("timer", {
						type = V.triggerTypes.TimeElapsed,
						parameters = { seconds = 1 },
						actions = { "act" },
					})
					:WithAction("act", { type = V.actionTypes.SendMessage, parameters = { message = "ok" } })
					:WithInitialStageDefinition("stage", { objectives = { "obj" } }))

				V.assertMessage(
					result,
					"Objective event must name an Event trigger. Objective: obj, Field: "
						.. fieldName
						.. ", Trigger: timer"
				)
			end)
		end

		-- An unowned Event trigger is inert: nothing declares a callin that can fire it.
		it("warns about an Event trigger no objective names", function()
			local result = V.validate(
				V.mission()
					:WithTrigger("orphan", { type = V.triggerTypes.Event, actions = { "act" } })
					:WithAction("act", { type = V.actionTypes.SendMessage, parameters = { message = "ok" } })
			)

			V.assertMessage(result, "Event trigger has no owners, so it can never fire. Trigger: orphan")
		end)

		it("does not warn about an Event trigger an objective names", function()
			local result = V.validate(
				V.mission()
					:WithObjective("obj", { textKey = "ok", onCompleted = "raised" })
					:WithTrigger("raised", { type = V.triggerTypes.Event, actions = { "act" } })
					:WithAction("act", { type = V.actionTypes.SendMessage, parameters = { message = "ok" } })
					:WithInitialStageDefinition("stage", { objectives = { "obj" } })
			)

			V.assertNoMessageContaining(result, "Event trigger has no owners")
		end)

		-- The existence check belongs to sections.lua, so this must not double report.
		it("leaves a nonexistent trigger to the objective field validation", function()
			local result = V.validate(
				V.mission()
					:WithObjective("obj", { textKey = "ok", onCompleted = "nowhere" })
					:WithInitialStageDefinition("stage", { objectives = { "obj" } })
			)

			V.assertMessage(result, "Invalid triggerID: nowhere. Objective: obj, Field: onCompleted")
			V.assertNoMessageContaining(result, "must name an Event trigger")
		end)
	end)
end)
