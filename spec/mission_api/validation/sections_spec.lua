---
--- Validation of the mission's sections: stages, objectives, triggers, actions
--- and loadouts, and the schema driven parameter validation they share.
---

local V = require("mission_api.validation.validation_spec_helper")

--- Validates objective 'o', the one under test.
local function validateObjective(objective)
	return V.validate(V.mission():WithObjective("o", objective))
end

--- Validates objective 'o' with the inline trigger under test.
local function validateObjectiveTrigger(trigger)
	return validateObjective({ textKey = "ok", trigger = trigger })
end

describe("mission_api.validation.sections", function()
	before_each(V.mockEngineGlobals)

	describe("stages", function()
		it("passes for well-formed stages", function()
			V.assertValid(
				V.validate(
					V.mission()
						:WithStage("stageA", { objectives = { "obj1" } })
						:WithStage("stageB", { objectives = { "obj1", "obj2" } })
						:WithObjective("obj1", { textKey = "ok" })
						:WithObjective("obj2", { textKey = "ok" })
						:WithInitialStage("stageA")
				)
			)
		end)

		it("reports a stage ID that is not a string", function()
			local result = V.validate(
				V.mission()
					:WithInitialStageDefinition(123, { objectives = { "obj1" } })
					:WithObjective("obj1", { textKey = "ok" })
			)

			V.assertMessage(result, "Unexpected parameter type, expected string, got number. Stage: 123, Field: ID")
		end)

		it("reports stage data that is not a table", function()
			local result = V.validate(V.mission():WithInitialStageDefinition("badStage", "notATable"))

			V.assertMessage(
				result,
				"Unexpected parameter type, expected table, got string. Stage: badStage, Field: data"
			)
		end)

		it("reports a stage missing the 'objectives' field", function()
			local result = V.validate(V.mission():WithInitialStageDefinition("noObjectives", {}))

			V.assertMessage(result, "Stage missing 'objectives' field. Stage: noObjectives")
		end)

		it("reports an 'objectives' field that is not a table", function()
			local result =
				V.validate(V.mission():WithInitialStageDefinition("badObjectives", { objectives = "notATable" }))

			V.assertMessage(
				result,
				"Unexpected parameter type, expected table, got string. Stage: badObjectives, Field: objectives"
			)
		end)

		it("reports an objective ID that is not a string", function()
			local result = V.validate(
				V.mission()
					:WithInitialStageDefinition("badEntry", { objectives = { "obj1", 123 } })
					:WithObjective("obj1", { textKey = "ok" })
			)

			V.assertMessage(
				result,
				"Unexpected parameter type, expected string, got number. Stage: badEntry, Field: objectives[2]"
			)
		end)

		it("reports an objective that does not exist", function()
			local result = V.validate(
				V.mission()
					:WithInitialStageDefinition("badStage", { objectives = { "obj1", "nonExistent" } })
					:WithObjective("obj1", { textKey = "ok" })
			)

			V.assertMessage(result, "Invalid objectiveID: nonExistent. Stage: badStage, Field: objectives[2]")
		end)

		it("accepts an empty 'objectives' table, which a decoy or terminal stage may have", function()
			V.assertValid(V.validate(V.mission():WithInitialStageDefinition("empty", { objectives = {} })))
		end)
	end)

	describe("initial stage", function()
		it("passes when stages are defined and initialStage matches", function()
			V.assertValid(
				V.validate(
					V.mission()
						:WithInitialStageDefinition("stageA", { objectives = { "obj" } })
						:WithObjective("obj", { textKey = "ok" })
				)
			)
		end)

		it("passes when no stages are defined and no initialStage is set", function()
			V.assertValid(V.validate(V.mission()))
		end)

		it("reports stages defined without an initialStage", function()
			local result = V.validate(
				V.mission():WithStage("stageA", { objectives = { "obj" } }):WithObjective("obj", { textKey = "ok" })
			)

			V.assertMessage(result, "Stages are defined, but initialStage is not provided")
		end)

		it("reports an initialStage that does not exist", function()
			local result = V.validate(
				V.mission()
					:WithStage("stageA", { objectives = { "obj" } })
					:WithObjective("obj", { textKey = "ok" })
					:WithInitialStage("stageB")
			)

			V.assertMessage(result, "Initial stage does not exist in stages. Stage: stageB")
		end)

		it("warns when initialStage is set but no stages are defined", function()
			local result = V.validate(V.mission():WithInitialStage("stageA"))

			V.assertMessage(result, "initialStage is set, but no stages are defined. Stage: stageA")
		end)
	end)

	describe("objective fields", function()
		it("passes for a well-formed objective without a trigger", function()
			V.assertValid(validateObjective({ textKey = "Do the thing." }))
		end)

		it("reports an objective ID that is not a string", function()
			local result = V.validate(V.mission():WithObjective(123, { textKey = "ok" }))

			V.assertMessage(result, "Unexpected parameter type, expected string, got number. Objective: 123, Field: ID")
		end)

		it("reports objective data that is not a table", function()
			local result = V.validate(V.mission():WithObjective("o", "notATable"))

			V.assertMessage(result, "Unexpected parameter type, expected table, got string. Objective: o, Field: data")
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
				amount = "notANumber",
				coop = "notABoolean",
			})

			V.assertMessage(
				result,
				"Unexpected parameter type, expected number, got string. Objective: o, Field: amount"
			)
			V.assertMessage(
				result,
				"Unexpected parameter type, expected boolean, got string. Objective: o, Field: coop"
			)
		end)

		it("reports a nextStage that does not exist", function()
			local result = V.validate(
				V.mission()
					:WithObjective("badNext", { textKey = "ok", nextStage = "nonExistentStage" })
					:WithInitialStageDefinition("validStage", { objectives = { "badNext" } })
			)

			V.assertMessage(result, "Invalid stageID: nonExistentStage. Objective: badNext, Field: nextStage")
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

		it("accepts difficulty-wrapped fields and inline trigger parameters", function()
			V.assertValid(validateObjective({
				textKey = "ok",
				amount = { difficulties = { Easy = 2, Hard = 5 } },
				trigger = {
					type = V.triggerTypes.TimeElapsed,
					parameters = { seconds = { difficulties = { Easy = 60, Hard = 30 } } },
				},
			}))
		end)

		it("reports an invalid value in a wrapped field", function()
			local result = validateObjective({ textKey = "ok", amount = { difficulties = { Easy = "x" } } })

			V.assertMessage(
				result,
				"Unexpected parameter type, expected number, got string. Objective: o, Field: amount.difficulties.Easy"
			)
		end)

		-- The inline trigger is registered before the difficulty is known.
		it("reports a difficulty-wrapped trigger field", function()
			local result = validateObjectiveTrigger({ difficulties = { Easy = { type = V.triggerTypes.TimeElapsed } } })

			V.assertMessage(
				result,
				"Objective 'trigger' field does not support difficulties. Objective: o, Field: trigger"
			)
		end)

		it("accepts a difficulty-wrapped nextStage naming existing stages", function()
			V.assertValid(
				V.validate(
					V.mission()
						:WithObjective(
							"o",
							{ textKey = "ok", nextStage = { difficulties = { Easy = "s1", Hard = "s2" } } }
						)
						:WithInitialStageDefinition("s1", { objectives = { "o" } })
						:WithStage("s2", { objectives = { "o" } })
				)
			)
		end)

		it("reports a wrapped nextStage naming a stage that does not exist", function()
			local result = V.validate(
				V.mission()
					:WithObjective("o", { textKey = "ok", nextStage = { difficulties = { Easy = "nowhere" } } })
					:WithInitialStageDefinition("validStage", { objectives = { "o" } })
			)

			V.assertMessage(result, "Invalid stageID: nowhere. Objective: o, Field: nextStage.difficulties.Easy")
		end)
	end)

	describe("inline trigger", function()
		it("passes for a valid inline trigger", function()
			V.assertValid(validateObjectiveTrigger({
				type = V.triggerTypes.TimeElapsed,
				parameters = { seconds = 90 },
			}))
		end)

		it("reports a 'settings' field", function()
			local result = validateObjectiveTrigger({
				settings = { repeating = true },
				type = V.triggerTypes.TimeElapsed,
				parameters = { seconds = 1 },
			})

			V.assertMessage(result, "Objective trigger must not have a 'settings' field. Objective: o")
		end)

		it("reports an 'actions' field", function()
			local result = validateObjectiveTrigger({
				type = V.triggerTypes.TimeElapsed,
				parameters = { seconds = 1 },
				actions = { "someAction" },
			})

			V.assertMessage(result, "Objective trigger must not have an 'actions' field. Objective: o")
		end)

		it("reports a missing type", function()
			local result = validateObjectiveTrigger({ parameters = { seconds = 1 } })

			V.assertMessage(result, "Objective trigger missing type. Objective: o")
		end)

		it("reports an invalid type", function()
			local result = validateObjectiveTrigger({ type = "notAType" })

			V.assertMessage(result, "Objective trigger has invalid type. Objective: o")
		end)

		it("reports a missing required parameter", function()
			local result = validateObjectiveTrigger({
				type = V.triggerTypes.TimeElapsed,
				parameters = {},
			})

			V.assertMessage(result, "Objective trigger missing required parameter. Objective: o, Parameter: seconds")
		end)

		-- Objective triggers take their quantity from the objective's own amount.
		it("warns when a statistics trigger specifies quantity", function()
			local result = validateObjectiveTrigger({
				type = V.triggerTypes.UnitsOwned,
				parameters = { teamName = "player", quantity = 5, unitDefName = "armwar" },
			})

			V.assertMessage(result, "Objective trigger 'quantity' is not supported and will be ignored. Objective: o")
		end)
	end)

	--- Validates trigger 't' with the settings under test.
	local function validateSettings(settings)
		return V.validate(V.mission()
			:WithTrigger("t", {
				type = V.triggerTypes.TimeElapsed,
				parameters = { seconds = 1 },
				settings = settings,
				actions = { "ok" },
			})
			:WithAction("ok", { type = V.actionTypes.SendMessage, parameters = { messageKey = "ok" } }))
	end

	describe("trigger shape", function()
		it("passes for a well-formed trigger", function()
			V.assertValid(V.validateTrigger(V.trigger(V.triggerTypes.TimeElapsed, { seconds = 1 })))
		end)

		it("reports a missing type", function()
			local result = V.validateTrigger({ actions = { "ok" } })

			V.assertMessage(result, "Trigger missing type. Trigger: t")
		end)

		it("reports an invalid type", function()
			local result = V.validateTrigger({ type = "notAType", actions = { "ok" } })

			V.assertMessage(result, "Trigger has invalid type. Trigger: t")
		end)

		it("reports a trigger ID that is not a string", function()
			local result =
				V.validate(V.mission():WithTrigger(123, V.trigger(V.triggerTypes.TimeElapsed, { seconds = 1 })))

			V.assertMessage(result, "Unexpected parameter type, expected string, got number. Trigger: 123, Field: ID")
		end)

		it("reports trigger data that is not a table", function()
			local result = V.validate(V.mission():WithTrigger("t", "notATable"))

			V.assertMessage(result, "Unexpected parameter type, expected table, got string. Trigger: t, Field: data")
		end)
	end)

	describe("actions", function()
		it("reports a trigger without actions", function()
			local result = V.validate(
				V.mission():WithTrigger("t", { type = V.triggerTypes.TimeElapsed, parameters = { seconds = 1 } })
			)

			V.assertMessage(result, "Trigger has no actions. Trigger: t")
		end)

		it("reports an 'actions' field that is not a table", function()
			local result = V.validateTrigger({
				type = V.triggerTypes.TimeElapsed,
				parameters = { seconds = 1 },
				actions = "notATable",
			})

			V.assertMessage(result, "Trigger 'actions' field must be a table, got string. Trigger: t")
		end)

		it("reports an action ID that does not exist", function()
			local result = V.validateTrigger({
				type = V.triggerTypes.TimeElapsed,
				parameters = { seconds = 1 },
				actions = { "doesNotExist" },
			})

			V.assertMessage(result, "Trigger has invalid action ID. Trigger: t, Action: doesNotExist")
		end)
	end)

	describe("cutscenes", function()
		--- Validates a mission whose cutscenes are all started, so only the cutscene checks report.
		local function validateCutscenes(cutscenes)
			local mission = V.mission():WithTrigger("t", {
				type = V.triggerTypes.TimeElapsed,
				parameters = { seconds = 1 },
				actions = {},
			})
			local actions = mission.fields.Triggers.t.actions
			for cutsceneID, cutscene in pairs(cutscenes) do
				mission:WithCutscene(cutsceneID, cutscene)
				mission:WithAction(
					"play_" .. cutsceneID,
					{ type = V.actionTypes.StartCutscene, parameters = { cutsceneID = cutsceneID } }
				)
				actions[#actions + 1] = "play_" .. cutsceneID
			end
			return V.validate(mission)
		end

		local originalFileExists

		before_each(function()
			originalFileExists = V.env.VFS.FileExists
			V.env.VFS.FileExists = function(path)
				return path:find("^videos/") ~= nil
			end
		end)

		after_each(function()
			V.env.VFS.FileExists = originalFileExists
		end)

		it("passes for a video cutscene and a scripted cutscene", function()
			V.assertValid(validateCutscenes({
				intro = { videoFile = "videos/intro.mp4" },
				landing = { script = "landingParty" },
			}))
		end)

		it("reports a cutscene with neither a videoFile nor a script", function()
			V.assertMessage(
				validateCutscenes({ intro = {} }),
				"Cutscene must have either a videoFile or a script, but not both. Cutscene: intro"
			)
		end)

		it("reports a cutscene with both a videoFile and a script", function()
			V.assertMessage(
				validateCutscenes({ intro = { videoFile = "videos/intro.mp4", script = "landingParty" } }),
				"Cutscene must have either a videoFile or a script, but not both. Cutscene: intro"
			)
		end)

		it("reports a script that is not a string", function()
			V.assertMessage(
				validateCutscenes({ landing = { script = 7 } }),
				"Unexpected parameter type, expected string, got number. Cutscene: landing, Field: script"
			)
		end)

		it("accepts video file types in any case", function()
			V.assertValid(validateCutscenes({ intro = { videoFile = "videos/intro.WebM" } }))
		end)

		it("reports a video file type that is not supported", function()
			V.assertMessage(
				validateCutscenes({ intro = { videoFile = "videos/intro.mov" } }),
				"Invalid videoFile: videos/intro.mov. Expected a file of type: mp4, webm. Cutscene: intro, Field: videoFile"
			)
		end)

		it("reports a video file without a type", function()
			V.assertMessage(
				validateCutscenes({ intro = { videoFile = "videos.mp4/intro" } }),
				"Invalid videoFile: videos.mp4/intro. Expected a file of type: mp4, webm. Cutscene: intro, Field: videoFile"
			)
		end)

		it("reports a video file that does not exist", function()
			V.assertMessage(
				validateCutscenes({ intro = { videoFile = "missing/intro.mp4" } }),
				"Invalid videoFile: missing/intro.mp4. File does not exist. Cutscene: intro, Field: videoFile"
			)
		end)

		it("validates the video file for every difficulty", function()
			local result = validateCutscenes({
				intro = { videoFile = { difficulties = { Easy = "videos/easy.mp4", Hard = "missing/hard.mp4" } } },
			})

			assert.are.same({
				"Invalid videoFile: missing/hard.mp4. File does not exist. Cutscene: intro, Field: videoFile.difficulties.Hard",
			}, result.messages)
		end)
	end)

	describe("ChangeTeam actions", function()
		local originalGetTeamInfo

		before_each(function()
			originalGetTeamInfo = V.env.Spring.GetTeamInfo
			V.missionAPI().Teams = { rebels = 0, [0] = "rebels", loyalists = 1, [1] = "loyalists" }
			V.env.Spring.GetTeamInfo = function(teamID)
				return teamID, 0, false, teamID == 1
			end
		end)

		after_each(function()
			V.env.Spring.GetTeamInfo = originalGetTeamInfo
		end)

		it("warns that the AI of the old team stays", function()
			local result = V.validate(V.mission():WithAction("defect", {
				type = V.actionTypes.ChangeTeam,
				parameters = { oldTeamName = "loyalists", newTeamName = "rebels" },
			}))

			V.assertMessage(result, "ChangeTeam moves players only, the AI of team 'loyalists' stays. Action: defect")
			assert.are.same({}, result.errors)
		end)

		it("checks every difficulty's old team", function()
			V.assertMessage(
				V.validate(V.mission():WithAction("defect", {
					type = V.actionTypes.ChangeTeam,
					parameters = {
						oldTeamName = { difficulties = { Easy = "rebels", Hard = "loyalists" } },
						newTeamName = "rebels",
					},
				})),
				"ChangeTeam moves players only, the AI of team 'loyalists' stays. Action: defect"
			)
		end)

		it("does not warn for a team without an AI", function()
			V.assertNoMessageContaining(
				V.validate(V.mission():WithAction("defect", {
					type = V.actionTypes.ChangeTeam,
					parameters = { oldTeamName = "rebels", newTeamName = "loyalists" },
				})),
				"ChangeTeam"
			)
		end)
	end)

	describe("IssueFormationOrders actions", function()
		local function validateFormation(parameters)
			parameters.unitName = "squad"
			return V.validateAction({ type = V.actionTypes.IssueFormationOrders, parameters = parameters })
		end

		local position = { x = 100, z = 100 }
		local positions = { { x = 0, z = 0 }, { x = 200, z = 0 } }

		it("passes a position with a direction", function()
			local result = validateFormation({ position = position, direction = { angle = 90 } })
			V.assertNoMessageContaining(result, "position")
			V.assertNoMessageContaining(result, "direction")
		end)

		it("reports both a position and positions", function()
			V.assertMessage(
				validateFormation({ position = position, positions = positions }),
				"IssueFormationOrders takes position or positions, not both. Action: a"
			)
		end)

		it("reports a direction with positions", function()
			V.assertMessage(
				validateFormation({ positions = positions, direction = { angle = 90 } }),
				"Parameter 'direction' needs position, not positions. Action: a, Parameter: direction"
			)
		end)
	end)

	describe("stockpile triggers", function()
		local originalWeaponDefs

		before_each(function()
			originalWeaponDefs = _G.WeaponDefs
			_G.WeaponDefs = { [1] = { stockpile = true }, [2] = { stockpile = false } }
			_G.UnitDefNames = {
				armmercury = { id = 1, weapons = { { weaponDef = 2 }, { weaponDef = 1 } } },
				armwar = { id = 2, weapons = { { weaponDef = 2 } } },
			}
		end)

		after_each(function()
			_G.WeaponDefs = originalWeaponDefs
		end)

		it("accepts any fractional progress value", function()
			for _, progress in ipairs({ 0, 0.5, 1 }) do
				V.assertValid(V.validateTrigger(V.trigger(V.triggerTypes.StockpileProgress, {
					progress = progress,
					unitDefName = "armmercury",
				})))
			end
		end)

		it("reports a unit def without a stockpiling weapon", function()
			V.assertMessage(
				V.validateTrigger(V.trigger(V.triggerTypes.StockpileCount, { count = 1, unitDefName = "armwar" })),
				"Unit 'armwar' has no stockpiling weapon. Trigger: t, Parameter: unitDefName"
			)
		end)

		it("checks every difficulty's unit def", function()
			V.assertMessage(
				V.validateTrigger(V.trigger(V.triggerTypes.StockpileProgress, {
					progress = 0.5,
					unitDefName = { difficulties = { Easy = "armmercury", Hard = "armwar" } },
				})),
				"Unit 'armwar' has no stockpiling weapon. Trigger: t, Parameter: unitDefName"
			)
		end)

		it("checks an objective's trigger", function()
			V.assertMessage(
				V.validate(V.mission():WithObjective("o", {
					textKey = "stockpile",
					trigger = {
						type = V.triggerTypes.StockpileCount,
						parameters = { count = 1, unitDefName = "armwar" },
					},
				})),
				"Unit 'armwar' has no stockpiling weapon. Objective: o, Parameter: unitDefName"
			)
		end)
	end)

	describe("settings", function()
		-- The loaders apply the setting defaults, and they run after validation.
		it("passes for a trigger without a settings table", function()
			V.assertValid(V.validateTrigger(V.trigger(V.triggerTypes.TimeElapsed, { seconds = 1 })))
		end)

		it("reports settings that are not a table", function()
			local result = validateSettings("notATable")

			V.assertMessage(
				result,
				"Unexpected parameter type, expected table, got string. Trigger: t, Setting: settings"
			)
		end)

		it("reports a setting of the wrong type", function()
			local result = validateSettings({ repeating = "notABoolean" })

			V.assertMessage(
				result,
				"Unexpected parameter type, expected boolean, got string. Trigger: t, Setting: repeating"
			)
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
				local result = validateSettings({ prerequisites = { "noSuchTrigger" } })

				V.assertMessage(result, "Invalid triggerID: noSuchTrigger. Trigger: t, Setting: prerequisites[1]")
			end)

			it("reports a prerequisite of the wrong type", function()
				local result = validateSettings({ prerequisites = { {} } })

				V.assertMessage(
					result,
					"Unexpected parameter type, expected string, got table. Trigger: t, Setting: prerequisites[1]"
				)
			end)
		end)

		describe("stages", function()
			it("reports a stage that does not exist", function()
				local result = validateSettings({ stages = { "noSuchStage" } })

				V.assertMessage(result, "Invalid stageID: noSuchStage. Trigger: t, Setting: stages[1]")
			end)

			it("reports a stage of the wrong type", function()
				local result = validateSettings({ stages = { 123 } })

				V.assertMessage(
					result,
					"Unexpected parameter type, expected string, got number. Trigger: t, Setting: stages[1]"
				)
			end)
		end)

		describe("difficulties", function()
			it("accepts an array of difficulty names", function()
				V.assertValid(validateSettings({ difficulties = { "Easy", "Hard" } }))
			end)

			it("accepts an empty array, which enables the trigger on every difficulty", function()
				V.assertValid(validateSettings({ difficulties = {} }))
			end)

			it("reports a difficulty that does not exist", function()
				local result = validateSettings({ difficulties = { "Bogus" } })

				V.assertMessage(result, "Invalid difficulty: Bogus. Trigger: t, Setting: difficulties[1]")
			end)

			-- The names are resolved with ipairs, so any other key would be silently skipped.
			it("reports a table that is not an array", function()
				local result = validateSettings({ difficulties = { Easy = true } })

				V.assertMessage(
					result,
					"Expected an array of difficulty names, got key: Easy. Trigger: t, Setting: difficulties"
				)
			end)
		end)
	end)

	it("passes for a valid action referenced by a trigger", function()
		V.assertValid(V.validateAction({ type = V.actionTypes.SendMessage, parameters = { messageKey = "ok" } }))
	end)

	it("reports a missing type", function()
		V.assertMessage(V.validateAction({}), "Action missing type. Action: a")
	end)

	it("reports an invalid type", function()
		V.assertMessage(V.validateAction({ type = "notAType" }), "Action has invalid type. Action: a")
	end)

	it("reports an action ID that is not a string", function()
		local result = V.validate(
			V.mission()
				:WithTrigger("t", V.trigger(V.triggerTypes.TimeElapsed, { seconds = 1 }))
				:WithAction(123, { type = V.actionTypes.SendMessage, parameters = { messageKey = "ok" } })
		)

		V.assertMessage(result, "Unexpected parameter type, expected string, got number. Action: 123, Field: ID")
	end)

	it("reports action data that is not a table", function()
		local result = V.validate(
			V.mission()
				:WithTrigger("t", V.trigger(V.triggerTypes.TimeElapsed, { seconds = 1 }))
				:WithAction("ok", "notATable")
		)

		V.assertMessage(result, "Unexpected parameter type, expected table, got string. Action: ok, Field: data")
	end)

	it("passes for a mission without loadouts", function()
		V.assertValid(V.validate(V.mission()))
	end)

	it("validates loadout entries", function()
		local result = V.validate(
			V.mission()
				:WithUnitLoadout({ { unitDefName = "noSuch", x = 0, z = 0, teamName = "player" } })
				:WithFeatureLoadout({ { featureDefName = "rockdef", z = 0 } })
		)

		V.assertMessage(result, "Invalid unitDefName: noSuch. Loadout: UnitLoadout[1].unitDefName")
		V.assertMessage(result, "Missing required parameter. Loadout: FeatureLoadout[1].x")
	end)

	it("reports loadouts that are not tables", function()
		local result = V.validate(V.mission():WithUnitLoadout("notATable"):WithFeatureLoadout(42))

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
		local result = V.validateAction({ type = V.actionTypes.SendMessage, parameters = "notATable" })

		V.assertMessage(
			result,
			"Unexpected parameter type, expected table, got string. Action: a, Parameter: parameters"
		)
	end)

	it("passes for an action whose parameters are all optional and omitted", function()
		V.assertValid(V.validateAction({ type = V.actionTypes.RemoveAllMapMarkers }))
	end)

	-- Each parameter is validated by the validator its schema names.
	it("validates a parameter using its declared type", function()
		local result = V.validateAction({ type = V.actionTypes.SendMessage, parameters = { messageKey = 123 } })

		V.assertMessage(
			result,
			"Unexpected parameter type, expected string, got number. Action: a, Parameter: messageKey"
		)
	end)

	describe("requiresOneOf", function()
		it("reports when none of the alternatives is present", function()
			local result = V.validateTrigger(V.trigger(V.triggerTypes.UnitKilled, {}))

			V.assertMessage(
				result,
				[[Trigger is missing required parameter, at least one of {"unitName","unitDefName"} is required. Trigger: t]]
			)
		end)

		it("passes when one of the alternatives is present", function()
			local result = V.validateTrigger(V.trigger(V.triggerTypes.UnitKilled, { unitDefName = "armwar" }))

			V.assertNoMessageContaining(result, "is missing required parameter")
		end)
	end)

	it("reports a DrawLines action without the lineName RemoveLine erases it by", function()
		local result = V.validateAction({
			type = V.actionTypes.DrawLines,
			parameters = { positions = { { x = 0, z = 0 }, { x = 1, z = 1 } } },
		})

		V.assertMessage(result, "Action missing required parameter. Action: a, Parameter: lineName")
	end)

	describe("difficulties parameters", function()
		local function validateSeconds(seconds)
			return V.validateTrigger(V.trigger(V.triggerTypes.TimeElapsed, { seconds = seconds }))
		end

		it("accepts a wrapped parameter with valid difficulties and values", function()
			V.assertValid(validateSeconds({ difficulties = { Easy = 60, Hard = 30 } }))
		end)

		it("satisfies the required-parameter check", function()
			V.assertValid(validateSeconds({ difficulties = { Medium = 45 } }))
		end)

		it("reports a difficulty that does not exist", function()
			local result = validateSeconds({ difficulties = { Bogus = 60, Easy = 1 } })

			V.assertMessage(result, "Invalid difficulty: Bogus. Trigger: t, Parameter: seconds.difficulties.Bogus")
		end)

		it("validates every value, including ones under a difficulty that does not exist", function()
			local result = validateSeconds({ difficulties = { Easy = "bad", Bogus = "worse" } })

			V.assertMessage(
				result,
				"Unexpected parameter type, expected number, got string. Trigger: t, Parameter: seconds.difficulties.Easy"
			)
			V.assertMessage(result, "Invalid difficulty: Bogus. Trigger: t, Parameter: seconds.difficulties.Bogus")
			V.assertMessage(
				result,
				"Unexpected parameter type, expected number, got string. Trigger: t, Parameter: seconds.difficulties.Bogus"
			)
		end)

		it("reports keys other than 'difficulties' in the wrapper", function()
			local result = validateSeconds({ difficulties = { Easy = 1 }, extra = 2 })

			V.assertMessage(
				result,
				"Difficulties parameter must have no keys other than 'difficulties', got: extra. Trigger: t, Parameter: seconds"
			)
		end)

		it("reports difficulties that are not a table", function()
			local result = validateSeconds({ difficulties = 5 })

			V.assertMessage(
				result,
				"Unexpected parameter type, expected table, got number. Trigger: t, Parameter: seconds.difficulties"
			)
		end)

		it("reports an empty difficulties table", function()
			local result = validateSeconds({ difficulties = {} })

			V.assertMessage(result, "Difficulties table is empty. Trigger: t, Parameter: seconds.difficulties")
		end)

		it("reports a nested difficulties table through the value's own validator", function()
			local result = validateSeconds({ difficulties = { Easy = { difficulties = { Easy = 1 } } } })

			V.assertMessage(
				result,
				"Unexpected parameter type, expected number, got table. Trigger: t, Parameter: seconds.difficulties.Easy"
			)
		end)

		it("accepts a wrapped action parameter", function()
			V.assertValid(V.validateAction({
				type = V.actionTypes.SendMessage,
				parameters = { messageKey = { difficulties = { Easy = "hi", Hard = "gl" } } },
			}))
		end)

		it("validates each difficulty's value of a table-typed parameter, with nested suffixes", function()
			local result = V.validateTrigger(V.trigger(V.triggerTypes.UnitEnteredLocation, {
				unitName = "x",
				area = {
					difficulties = {
						Easy = { x = 0, z = 0, radius = 10 },
						Hard = { x1 = 1, z1 = 0, x2 = 0, z2 = 1 },
					},
				},
			}))

			V.assertMessage(
				result,
				"Invalid area rectangle parameter, x1 must be less than x2. Trigger: t, Parameter: area.difficulties.Hard"
			)
		end)
	end)

	-- Whether an attribute suits the value, multiplier, weapon and unit def it is used with.
	describe("attribute actions", function()
		local armwar =
			{ id = 1, name = "armwar", isImmobile = false, isBuilder = false, weapons = { { weaponDef = 1 } } }

		local function validateAttributeAction(unitDefs, action)
			_G.UnitDefNames = unitDefs
			return V.validateAction(action)
		end

		it("reports a value whose type disagrees with the attribute", function()
			local result = validateAttributeAction({ armwar = armwar }, {
				type = V.actionTypes.SetUnitDefAttribute,
				parameters = { unitDefName = "armwar", attribute = "stealth", value = 1 },
			})

			V.assertMessage(result, "Unit attribute 'stealth' takes a boolean, got number. Action: a, Parameter: value")
		end)

		it("reports a negative value", function()
			local result = validateAttributeAction({ armwar = armwar }, {
				type = V.actionTypes.SetUnitDefAttribute,
				parameters = { unitDefName = "armwar", attribute = "losRadius", value = -1 },
			})

			V.assertMessage(result, "Unit attribute 'losRadius' must be >= 0, got -1. Action: a, Parameter: value")
		end)

		it("checks the value of every difficulty", function()
			local result = validateAttributeAction({ armwar = armwar }, {
				type = V.actionTypes.SetUnitDefAttribute,
				parameters = {
					unitDefName = "armwar",
					attribute = "losRadius",
					value = { difficulties = { Easy = 600, Hard = -1 } },
				},
			})

			V.assertMessage(result, "Unit attribute 'losRadius' must be >= 0, got -1. Action: a, Parameter: value")
		end)

		it("reports a unit state attribute set on a unit def", function()
			local result = validateAttributeAction({ armwar = armwar }, {
				type = V.actionTypes.SetUnitDefAttribute,
				parameters = { unitDefName = "armwar", attribute = "experience", value = 1 },
			})

			V.assertMessage(
				result,
				"Unit attribute 'experience' cannot be set on unitdefs. Action: a, Parameter: attribute"
			)
		end)

		it("accepts a unit state attribute set on units", function()
			V.assertValid(validateAttributeAction({ armwar = armwar }, {
				type = V.actionTypes.SetUnitAttribute,
				parameters = { unitDefName = "armwar", attribute = "experience", value = 1 },
			}))
		end)

		it("accepts clearing a source", function()
			V.assertValid(validateAttributeAction({ armwar = armwar }, {
				type = V.actionTypes.ClearUnitDefAttribute,
				parameters = { unitDefName = "armwar", attribute = "losRadius", source = "scouting" },
			}))
		end)

		it("warns, but does not error, when a movement attribute targets an immobile def", function()
			local result = validateAttributeAction(
				{ armllt = { id = 2, name = "armllt", isImmobile = true, isBuilder = false } },
				{
					type = V.actionTypes.SetUnitDefAttribute,
					parameters = { unitDefName = "armllt", attribute = "speed", value = 50 },
				}
			)

			V.assertMessage(result, "Unit attribute 'speed' has an inappropriate def (armllt). Action: a")
			assert.is_true(result.ok)
		end)

		it("warns, but does not error, when buildSpeed targets a def that cannot build", function()
			local result = validateAttributeAction(
				{ armpw = { id = 3, name = "armpw", isImmobile = false, isBuilder = false } },
				{
					type = V.actionTypes.SetUnitDefAttribute,
					parameters = { unitDefName = "armpw", attribute = "buildSpeed", value = 100 },
				}
			)

			V.assertMessage(result, "Unit attribute 'buildSpeed' has an inappropriate def (armpw). Action: a")
			assert.is_true(result.ok)
		end)

		it("accepts a matching attribute and value", function()
			V.assertValid(validateAttributeAction({ armwar = armwar }, {
				type = V.actionTypes.SetUnitDefAttribute,
				parameters = { unitDefName = "armwar", attribute = "losRadius", value = 600 },
			}))
		end)

		it("reports a negative multiplier", function()
			local result = validateAttributeAction({ armwar = armwar }, {
				type = V.actionTypes.SetUnitDefModifier,
				parameters = { unitDefName = "armwar", attribute = "losRadius", multiplier = -2 },
			})

			V.assertMessage(result, "Unit attribute 'losRadius' must be >= 0, got -2. Action: a, Parameter: multiplier")
		end)

		it("reports multiplying a unit state attribute", function()
			local result = validateAttributeAction({ armwar = armwar }, {
				type = V.actionTypes.SetUnitModifier,
				parameters = { unitDefName = "armwar", attribute = "health", multiplier = 2 },
			})

			V.assertMessage(result, "Unit attribute 'health' cannot be multiplied. Action: a, Parameter: attribute")
		end)

		it("reports multiplying a boolean attribute", function()
			local result = validateAttributeAction({ armwar = armwar }, {
				type = V.actionTypes.SetUnitDefModifier,
				parameters = { unitDefName = "armwar", attribute = "stealth", multiplier = 2 },
			})

			V.assertMessage(result, "Unit attribute 'stealth' cannot be multiplied. Action: a, Parameter: attribute")
		end)

		it("accepts clearing a modifier's source", function()
			V.assertValid(validateAttributeAction({ armwar = armwar }, {
				type = V.actionTypes.ClearUnitModifier,
				parameters = { unitDefName = "armwar", attribute = "speed", source = "haste" },
			}))
		end)

		it("reports an explosion on an attribute not written per explosion", function()
			local result = validateAttributeAction({ armwar = armwar }, {
				type = V.actionTypes.SetUnitDefWeaponModifier,
				parameters = { unitDefName = "armwar", weapon = "explode", attribute = "reloadTime", multiplier = 2 },
			})

			V.assertMessage(
				result,
				"Weapon attribute 'reloadTime' is not written per explosion. Action: a, Parameter: weapon"
			)
		end)

		it("reports a weapon the unit def does not have", function()
			local result = validateAttributeAction({ armwar = armwar }, {
				type = V.actionTypes.SetUnitDefWeaponAttribute,
				parameters = { unitDefName = "armwar", weapon = 2, attribute = "maxWeaponRange", value = 800 },
			})

			V.assertMessage(
				result,
				"Weapon attribute 'maxWeaponRange' names a weapon the unitdef does not have. Action: a, Parameter: weapon"
			)
		end)

		-- The WeaponNumber validator reports it, so it must not be reported twice.
		it("leaves a malformed weapon to its parameter validator", function()
			local result = validateAttributeAction({ armwar = armwar }, {
				type = V.actionTypes.SetUnitDefWeaponAttribute,
				parameters = { unitDefName = "armwar", weapon = "death", attribute = "maxWeaponRange", value = 800 },
			})

			assert.are.same({
				"Expected a weapon number, 'explode' or 'selfDestruct', got death. Action: a, Parameter: weapon",
			}, result.messages)
		end)

		it("reports setting a multiplication-only weapon attribute", function()
			local result = validateAttributeAction({ armwar = armwar }, {
				type = V.actionTypes.SetUnitDefWeaponAttribute,
				parameters = { unitDefName = "armwar", attribute = "damage", value = 50 },
			})

			V.assertMessage(result, "Weapon attribute 'damage' is multiplication-only. Action: a, Parameter: attribute")
		end)

		it("accepts scaling the death explosion's damage", function()
			V.assertValid(validateAttributeAction({ armwar = armwar }, {
				type = V.actionTypes.SetUnitDefWeaponModifier,
				parameters = { unitDefName = "armwar", weapon = "explode", attribute = "damage", multiplier = 2 },
			}))
		end)

		it("finds the attribute actions through the schema, not by name", function()
			local actionParameters = V.definitions.ActionDefinitions.Parameters
			local parameterTypes = V.definitions.ParameterTypes.Types
			actionParameters.syntheticAttributeAction = {
				{ name = "attribute", required = true, type = parameterTypes.UnitAttribute },
				{ name = "value", required = true, type = parameterTypes.AttributeValue },
			}
			finally(function()
				actionParameters.syntheticAttributeAction = nil
			end)

			local result = validateAttributeAction({ armwar = armwar }, {
				type = "syntheticAttributeAction",
				parameters = { attribute = "stealth", value = 1 },
			})

			V.assertMessage(result, "Unit attribute 'stealth' takes a boolean, got number. Action: a, Parameter: value")
		end)
	end)
	describe("variable references", function()
		before_each(function()
			V.missionAPI().Variables = { waveSize = 3, wrongType = "three", stage = "s1" }
		end)

		local function waitFor(quantity)
			return V.validateTrigger(V.trigger(V.triggerTypes.TimeElapsed, { seconds = quantity }))
		end

		it("checks a parameter against the variable's value at the start of the mission", function()
			V.assertValid(waitFor({ variable = "waveSize" }))
			V.assertMessage(
				waitFor({ variable = "wrongType" }),
				"Unexpected parameter type, expected number, got string. Trigger: t, Parameter: seconds"
			)
		end)

		it("does not check a parameter while its variable is unset", function()
			V.assertNoMessageContaining(waitFor({ variable = "unset" }), "Parameter: seconds")
		end)

		it("reports a variable key that is not a string", function()
			V.assertMessage(
				waitFor({ variable = 1 }),
				"Variable key must be a string, got number. Trigger: t, Parameter: seconds"
			)
		end)

		it("checks variables in every difficulty's value", function()
			V.assertMessage(
				waitFor({ difficulties = { Easy = 1, Hard = { variable = "wrongType" } } }),
				"Unexpected parameter type, expected number, got string. Trigger: t, Parameter: seconds.difficulties.Hard"
			)
		end)

		it("checks an objective field against the variable's value", function()
			V.assertValid(
				V.validate(
					V.mission()
						:WithStage("s1", { objectives = { "o" } })
						:WithInitialStage("s1")
						:WithObjective("o", { textKey = "ok", nextStage = { variable = "stage" } })
				)
			)
			V.assertMessage(
				V.validate(V.mission():WithObjective("o", { textKey = "ok", amount = { variable = "wrongType" } })),
				"Unexpected parameter type, expected number, got string. Objective: o, Field: amount"
			)
		end)

		it("reports an objective trigger that is a variable", function()
			V.assertMessage(
				V.validate(V.mission():WithObjective("o", { textKey = "ok", trigger = { variable = "waveSize" } })),
				"Objective 'trigger' field does not support variables. Objective: o, Field: trigger"
			)
		end)
	end)
end)
