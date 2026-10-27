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

	describe("action references", function()
		it("warns about an action that no trigger references", function()
			local result = V.validate(
				V.mission()
					:WithTrigger("t", V.trigger(V.triggerTypes.TimeElapsed, { seconds = 1 }))
					:WithAction("ok", { type = V.actionTypes.SendMessage, parameters = { messageKey = "ok" } })
					:WithAction("unused", { type = V.actionTypes.SendMessage, parameters = { messageKey = "unused" } })
			)

			assert.are.same({ "Actions not referenced by any trigger: unused" }, result.warnings)
			assert.is_true(result.ok)
		end)

		it("reports every unreferenced action, in sorted order", function()
			local result = V.validate(
				V.mission()
					:WithTrigger("t", V.trigger(V.triggerTypes.TimeElapsed, { seconds = 1 }))
					:WithAction("ok", { type = V.actionTypes.SendMessage, parameters = { messageKey = "ok" } })
					:WithAction("zzz", { type = V.actionTypes.SendMessage, parameters = { messageKey = "zzz" } })
					:WithAction("aaa", { type = V.actionTypes.SendMessage, parameters = { messageKey = "aaa" } })
			)

			assert.are.same({ "Actions not referenced by any trigger: aaa, zzz" }, result.warnings)
		end)
	end)

	it("passes when every name is both created and referenced", function()
		V.assertValid(V.validate(V.mission()
			:WithTrigger("t", {
				type = V.triggerTypes.TotalUnitsKilled,
				parameters = { teamID = 0, unitName = "bot" },
				count = 1,
				actions = { "spawn", "create", "delete", "add", "remove" },
			})
			:WithAction("spawn", spawnUnits("bot"))
			:WithAction("create", createFeatures("rock"))
			:WithAction("delete", { type = V.actionTypes.DestroyFeatures, parameters = { featureName = "rock" } })
			:WithAction(
				"add",
				{ type = V.actionTypes.AddMapMarker, parameters = { position = { x = 0, z = 0 }, markerName = "flag" } }
			)
			:WithAction("remove", { type = V.actionTypes.RemoveMapMarker, parameters = { markerName = "flag" } })))
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

	it("treats objective conditions as name references", function()
		V.assertValid(V.validate(V.mission()
			:WithObjective("watchBot", {
				textKey = "watch bot",
				type = V.triggerTypes.UnitsOwned,
				parameters = { teamID = 0, unitName = "bot" },
				atLeast = 1,
			})
			:WithObjective("watchRock", {
				textKey = "watch rock",
				type = V.triggerTypes.FeatureDestroyed,
				parameters = { featureName = "rock" },
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
		V.env.CMD = { GUARD = 25, [25] = "GUARD" }

		V.assertValid(V.validate(V.mission()
			:WithTrigger("t", {
				type = V.triggerTypes.TimeElapsed,
				parameters = { seconds = 1 },
				actions = { "spawn", "order" },
			})
			:WithAction("spawn", spawnUnits("bot"))
			:WithAction("order", {
				type = V.actionTypes.IssueOrders,
				parameters = { unitName = "bot", orders = { { V.env.CMD.GUARD, { unitName = "bot" } } } },
			})))

		V.env.CMD = {}
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
			:WithAction("ok", { type = V.actionTypes.SendMessage, parameters = { messageKey = "ok" } })))
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

	describe("map marker names", function()
		-- A marker left standing for the rest of the mission is ordinary, so only the
		-- removing side is checked.
		it("passes a marker that is added and never removed", function()
			V.assertValid(V.validate(V.mission()
				:WithTrigger("t", {
					type = V.triggerTypes.TimeElapsed,
					parameters = { seconds = 1 },
					actions = { "addPermanent" },
				})
				:WithAction("addPermanent", {
					type = V.actionTypes.AddMapMarker,
					parameters = { markerName = "beacon", position = { x = 0, z = 0 } },
				})))
		end)

		it("warns about removing a marker that no action adds", function()
			local result = V.validate(
				V.mission()
					:WithAction("addPermanent", {
						type = V.actionTypes.AddMapMarker,
						parameters = { markerName = "beacon", position = { x = 0, z = 0 } },
					})
					:WithAction(
						"removeUnknown",
						{ type = V.actionTypes.RemoveMapMarker, parameters = { markerName = "noSuchBeacon" } }
					)
			)

			V.assertMessage(
				result,
				"Marker name is referenced, but never created. Marker name: noSuchBeacon, Referenced in: action removeUnknown"
			)
		end)
	end)

	describe("line names", function()
		-- Like markers, a line left drawn for the rest of the mission is ordinary.
		it("passes a line that is drawn and never removed", function()
			V.assertValid(V.validate(V.mission()
				:WithTrigger("t", {
					type = V.triggerTypes.TimeElapsed,
					parameters = { seconds = 1 },
					actions = { "drawWall" },
				})
				:WithAction("drawWall", {
					type = V.actionTypes.DrawLines,
					parameters = { lineName = "wall", positions = { { x = 0, z = 0 }, { x = 1, z = 1 } } },
				})))
		end)

		it("warns about removing a line that no action draws", function()
			local result = V.validate(
				V.mission()
					:WithAction("drawWall", {
						type = V.actionTypes.DrawLines,
						parameters = { lineName = "wall", positions = { { x = 0, z = 0 }, { x = 1, z = 1 } } },
					})
					:WithAction(
						"removeUnknown",
						{ type = V.actionTypes.RemoveLine, parameters = { lineName = "noSuchLine" } }
					)
			)

			V.assertMessage(
				result,
				"Line name is referenced, but never created. Line name: noSuchLine, Referenced in: action removeUnknown"
			)
			V.assertNoMessageContaining(result, "Line name: wall")
		end)
	end)

	describe("cutscene IDs", function()
		--- A mission whose trigger 't' starts the given actions.
		local function startedBy(actions)
			local mission = V.mission()
			local actionIDs = {}
			for actionID, action in pairs(actions) do
				mission:WithAction(actionID, action)
				actionIDs[#actionIDs + 1] = actionID
			end
			return mission:WithTrigger(
				"t",
				{ type = V.triggerTypes.TimeElapsed, parameters = { seconds = 1 }, actions = actionIDs }
			)
		end

		local function startCutscene(cutsceneID)
			return { type = V.actionTypes.StartCutscene, parameters = { cutsceneID = cutsceneID } }
		end

		it("passes cutscenes that are defined and started", function()
			V.assertValid(V.validate(startedBy({
					playIntro = startCutscene("intro"),
					playOutro = startCutscene({ difficulties = { Easy = "outro", Hard = "intro" } }),
				})
				:WithCutscene("intro", { script = "landingParty" })
				:WithCutscene("outro", { script = "farewell" })))
		end)

		it("reports a cutscene that is not defined", function()
			local result = V.validate(startedBy({ playGhost = startCutscene("ghost") }))

			V.assertMessage(
				result,
				"Cutscene is referenced, but not defined in Cutscenes. Cutscene: ghost, Referenced in: action playGhost"
			)
			assert.is_false(result.ok)
		end)

		it("checks every difficulty's cutscene", function()
			V.assertMessage(
				V.validate(startedBy({
					play = startCutscene({ difficulties = { Easy = "intro", Hard = "ghost" } }),
				}):WithCutscene("intro", { script = "landingParty" })),
				"Cutscene is referenced, but not defined in Cutscenes. Cutscene: ghost, Referenced in: action play"
			)
		end)

		it("warns about a cutscene that nothing starts", function()
			local result = V.validate(V.mission():WithCutscene("unused", { script = "landingParty" }))

			assert.are.same({ "Cutscene is defined, but never referenced. Cutscene: unused" }, result.warnings)
			assert.is_true(result.ok)
		end)
	end)

	describe("countdown IDs", function()
		it("passes countdowns that are added, including ones left to run out", function()
			V.assertValid(
				V.validate(
					V.mission()
						:WithObjective("surviveBomb", {
							textKey = "survive",
							type = V.triggerTypes.CountdownFinished,
							parameters = { countdownID = "bomb" },
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
				"Countdown is referenced, but never created. Countdown: ghost, Referenced in: action cancelGhost"
			)
		end)

		-- Every action taking a countdownID counts, straight from the action schema.
		it("warns about time adjustments on countdowns that are never created", function()
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
				"Countdown is referenced, but never created. Countdown: setID, Referenced in: action setGhost"
			)
			V.assertMessage(
				result,
				"Countdown is referenced, but never created. Countdown: addID, Referenced in: action addGhost"
			)
			V.assertMessage(
				result,
				"Countdown is referenced, but never created. Countdown: removeID, Referenced in: action removeGhost"
			)
		end)

		it("warns about a countdown a trigger refers to, but no action adds", function()
			local result = V.validate(V.mission()
				:WithTrigger("watchGhost", {
					type = V.triggerTypes.CountdownReached,
					parameters = { countdownID = "ghost", timeRemaining = 10 },
					actions = { "ok" },
				})
				:WithAction("ok", { type = V.actionTypes.SendMessage, parameters = { messageKey = "ok" } }))

			V.assertMessage(
				result,
				"Countdown is referenced, but never created. Countdown: ghost, Referenced in: trigger watchGhost"
			)
		end)

		it("warns about a countdown an objective condition refers to, but no action adds", function()
			local result = V.validate(V.mission():WithObjective("surviveGhost", {
				textKey = "survive",
				type = V.triggerTypes.CountdownFinished,
				parameters = { countdownID = "ghost" },
			}))

			V.assertMessage(
				result,
				"Countdown is referenced, but never created. Countdown: ghost, "
					.. "Referenced in: objective surviveGhost (condition)"
			)
		end)
	end)

	-- The on* fields name an Event trigger, raised when the objective reaches that state.
	-- sections.lua checks the trigger exists; these checks cover the Event-specific rules.
	describe("objective events", function()
		for _, fieldName in ipairs({
			"onActivated",
			"onCanceled",
			"onProgress",
			"onCompleted",
			"onFailed",
			"onHidden",
			"onShown",
		}) do
			it("accepts " .. fieldName .. " naming an Event trigger", function()
				local result = V.validate(
					V.mission()
						:WithObjective("obj", { textKey = "ok", [fieldName] = "raised" })
						:WithTrigger("raised", { type = V.triggerTypes.Event, actions = { "act" } })
						:WithAction("act", { type = V.actionTypes.SendMessage, parameters = { messageKey = "ok" } })
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
					:WithAction("act", { type = V.actionTypes.SendMessage, parameters = { messageKey = "ok" } })
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
					:WithAction("act", { type = V.actionTypes.SendMessage, parameters = { messageKey = "ok" } })
			)

			V.assertMessage(result, "Event trigger has no owners, so it can never fire. Trigger: orphan")
		end)

		it("does not warn about an Event trigger an objective names", function()
			local result = V.validate(
				V.mission()
					:WithObjective("obj", { textKey = "ok", onCompleted = "raised" })
					:WithTrigger("raised", { type = V.triggerTypes.Event, actions = { "act" } })
					:WithAction("act", { type = V.actionTypes.SendMessage, parameters = { messageKey = "ok" } })
					:WithInitialStageDefinition("stage", { objectives = { "obj" } })
			)

			V.assertNoMessageContaining(result, "Event trigger has no owners")
		end)

		-- Any difficulty's trigger may be the one raised, so each is checked.
		it("reports a wrapped field naming a trigger that is not an Event for one difficulty", function()
			local result = V.validate(V.mission()
				:WithObjective("obj", {
					textKey = "ok",
					onCompleted = { difficulties = { Easy = "doneEasy", Hard = "timer" } },
				})
				:WithTrigger("doneEasy", { type = V.triggerTypes.Event, actions = { "act" } })
				:WithTrigger("timer", {
					type = V.triggerTypes.TimeElapsed,
					parameters = { seconds = 1 },
					actions = { "act" },
				})
				:WithAction("act", { type = V.actionTypes.SendMessage, parameters = { messageKey = "ok" } })
				:WithInitialStageDefinition("stage", { objectives = { "obj" } }))

			V.assertMessage(
				result,
				"Objective event must name an Event trigger. Objective: obj, Field: onCompleted, Trigger: timer"
			)
		end)

		it("accepts a wrapped field naming an Event trigger for every difficulty", function()
			local result = V.validate(V.mission()
				:WithObjective("obj", {
					textKey = "ok",
					onCompleted = { difficulties = { Easy = "doneEasy", Hard = "doneHard" } },
				})
				:WithTrigger("doneEasy", { type = V.triggerTypes.Event, actions = { "act" } })
				:WithTrigger("doneHard", { type = V.triggerTypes.Event, actions = { "act" } })
				:WithAction("act", { type = V.actionTypes.SendMessage, parameters = { messageKey = "ok" } })
				:WithInitialStageDefinition("stage", { objectives = { "obj" } }))

			V.assertValid(result)
		end)

		it("does not warn about an Event trigger named only through a wrapped field", function()
			local result = V.validate(
				V.mission()
					:WithObjective("obj", { textKey = "ok", onCompleted = { difficulties = { Easy = "raised" } } })
					:WithTrigger("raised", { type = V.triggerTypes.Event, actions = { "act" } })
					:WithAction("act", { type = V.actionTypes.SendMessage, parameters = { messageKey = "ok" } })
					:WithInitialStageDefinition("stage", { objectives = { "obj" } })
			)

			V.assertValid(result)
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
	describe("variables", function()
		it("warns about a variable with no value at the start of the mission", function()
			V.missionAPI().Variables = { waveSize = 3 }
			local result = V.validate(V.mission()
				:WithTrigger("t", {
					type = V.triggerTypes.TimeElapsed,
					parameters = { seconds = { variable = "delay" } },
					actions = { "a" },
				})
				:WithAction("a", {
					type = V.actionTypes.SendMessage,
					parameters = { messageKey = "ok" },
				})
				:WithObjective("o", { textKey = "ok", count = { variable = "delay" } }))

			assert.are.same({
				"Variable has no value at the start of the mission. Variable: delay, "
					.. "Referenced in: objective o (count), trigger t (seconds)",
			}, result.warnings)
			assert.is_true(result.ok)
		end)
	end)
end)
