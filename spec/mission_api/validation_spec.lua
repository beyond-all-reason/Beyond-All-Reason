require("spec_helper")

local RegisterMissionApiModules = require("mission_api.spec_helper")

-- mirror eager module loading in api_missions.lua
GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")
RegisterMissionApiModules() -- handles some load order
GG["MissionAPI"].ActionDefinitions = VFS.Include("luarules/mission_api/actions_loader.lua").LoadActionDefinitions()
GG["MissionAPI"].TriggerDefinitions = VFS.Include("luarules/mission_api/triggers_loader.lua").LoadTriggerDefinitions()

-- Reinstall the same command IDs per-test (see Command) so we
-- can run multiple tests without interfering with other specs.
local function withCommandIDs(names, firstID)
	local commands = {}
	for offset, name in ipairs(names) do
		local id = firstID + offset
		commands[name] = id
		commands[id] = name
	end
	return commands
end

local function installCommandTables()
	_G.CMD = withCommandIDs({ "STOP", "MOVE", "ATTACK", "RECLAIM", "GUARD", "REPAIR", "FIGHT", "CLOAK" }, 0)
	_G.GameCMD = withCommandIDs({ "AREA_ATTACK_GROUND" }, 1000)
	_G.CMD.ANY, _G.CMD.BUILD = "a", "b" -- filter sentinels (see common/constants.lua)
end

local savedCMD, savedGameCMD = _G.CMD, _G.GameCMD
installCommandTables()
local validation = VFS.Include("luarules/mission_api/validation.lua") -- Wrap in safety code and restore.
_G.CMD, _G.GameCMD = savedCMD, savedGameCMD
savedCMD, savedGameCMD = nil, nil

local actionDefinitions = GG["MissionAPI"].ActionDefinitions
local triggerDefinitions = GG["MissionAPI"].TriggerDefinitions

local triggerTypes = triggerDefinitions.Types
local actionTypes = actionDefinitions.Types

-- Mirrors the normalisation done by triggers_loader before calling ValidateTriggers.
local function normalizeTrigger(raw)
	local s = raw.settings or {}
	s.prerequisites = s.prerequisites or {}
	s.repeating = s.repeating or false
	s.maxRepeats = s.maxRepeats or nil
	s.difficulties = s.difficulties or nil
	s.coop = s.coop or false
	s.active = s.active == nil and true or s.active
	raw.settings = s
	raw.triggered = false
	raw.repeatCount = 0
	return raw
end

describe("mission_api.validation", function()
	local logged

	local function hasError(msg)
		return table.any(logged, function(m)
			return m == "[Mission API] " .. msg
		end)
	end

	before_each(function()
		logged = {}
		Spring.Log = function(_, _, msg)
			logged[#logged + 1] = msg
		end
		Spring.GetTeamAllyTeamID = function()
			return true
		end
		Spring.GetAllyTeamList = function()
			return { 0 }
		end
		_G.UnitDefNames = { armwar = { id = 1 } }
		_G.FeatureDefNames = {}
		_G.WeaponDefNames = {}
		GG["MissionAPI"] = {
			TriggerDefinitions = triggerDefinitions,
			Modules = {},
			ActionDefinitions = actionDefinitions,
			Objectives        = {},
			Stages            = {},
			Triggers          = {},
			Actions           = {},
			Teams             = { teamA = 0 },
			AllyTeams         = { allyA = 0 },
		}
	end)

	after_each(function()
		GG["MissionAPI"] = nil
	end)

	-- ── ValidateTriggers ──────────────────────────────────────────────────────

	describe("ValidateTriggers", function()
		local rawActions

		before_each(function()
			rawActions = {
				ok = { type = actionTypes.SendMessage, parameters = { message = "ok" } },
			}
		end)

		it("passes for a well-formed trigger", function()
			validation.ValidateTriggers({
				t = normalizeTrigger({
					type = triggerTypes.TimeElapsed,
					parameters = { seconds = 1 },
					actions = { "ok" },
				}),
			}, rawActions)

			assert.are.same({}, logged)
		end)

		it(
			"logs errors for missing type, invalid type, missing required parameter, invalid action ID, and invalid prerequisite",
			function()
				validation.ValidateTriggers({
					noType = normalizeTrigger({
						actions = { "ok" },
					}),
					badType = normalizeTrigger({
						type = "notAType",
						actions = { "ok" },
					}),
					missingParam = normalizeTrigger({
						type = triggerTypes.TimeElapsed,
						parameters = {},
						actions = { "ok" },
					}),
					badActionID = normalizeTrigger({
						type = triggerTypes.TimeElapsed,
						parameters = { seconds = 1 },
						actions = { "doesNotExist" },
					}),
					badPrereq = normalizeTrigger({
						type = triggerTypes.TimeElapsed,
						parameters = { seconds = 1 },
						settings = { prerequisites = { "noSuchTrigger" } },
						actions = { "ok" },
					}),
				}, rawActions)

				assert.is_true(hasError("Trigger missing type. Trigger: noType"))
				assert.is_true(hasError("Trigger has invalid type. Trigger: badType"))
				assert.is_true(
					hasError("Trigger missing required parameter. Trigger: missingParam, Parameter: seconds")
				)
				assert.is_true(hasError("Trigger has invalid action ID: badActionID, Action: doesNotExist"))
				assert.is_true(
					hasError(
						"Trigger prerequisite does not exist. Trigger: badPrereq, Prerequisite triggerID: noSuchTrigger"
					)
				)
			end
		)
	end)

	-- ── ValidateActions ───────────────────────────────────────────────────────

	describe("ValidateActions", function()
		it("passes for a valid action referenced by a trigger", function()
			GG["MissionAPI"].Triggers = {
				t = normalizeTrigger({
					type = triggerTypes.TimeElapsed,
					parameters = { seconds = 1 },
					actions = { "ok" },
				}),
			}

			validation.ValidateActions({
				ok = { type = actionTypes.SendMessage, parameters = { message = "ok" } },
			})

			assert.are.same({}, logged)
		end)

		it("logs errors for missing type, missing required parameter, and unreferenced actions", function()
			GG["MissionAPI"].Triggers = {
				t = normalizeTrigger({
					type = triggerTypes.TimeElapsed,
					parameters = { seconds = 1 },
					actions = { "ok", "noType", "missingParam" },
				}),
			}

			validation.ValidateActions({
				ok = { type = actionTypes.SendMessage, parameters = { message = "ok" } },
				noType = {},
				missingParam = { type = actionTypes.EnableTrigger, parameters = {} },
				unused = { type = actionTypes.SendMessage, parameters = { message = "unused" } },
			})

			assert.is_true(hasError("Action missing type. Action: noType"))
			assert.is_true(hasError("Action missing required parameter. Action: missingParam, Parameter: triggerID"))
			assert.is_true(hasError("Actions not referenced by any trigger: unused"))
		end)

		it("logs unreferenced actions in sorted order", function()
			GG["MissionAPI"].Triggers = {
				t = normalizeTrigger({
					type = triggerTypes.TimeElapsed,
					parameters = { seconds = 1 },
					actions = { "ok" },
				}),
			}

			validation.ValidateActions({
				ok = { type = actionTypes.SendMessage, parameters = { message = "ok" } },
				zzz = { type = actionTypes.SendMessage, parameters = { message = "zzz" } },
				aaa = { type = actionTypes.SendMessage, parameters = { message = "aaa" } },
			})

			assert.is_true(hasError("Actions not referenced by any trigger: aaa, zzz"))
		end)
	end)

	-- ── ValidateObjectives ────────────────────────────────────────────────────

	describe("ValidateObjectives", function()
		it("passes for a well-formed objective without a trigger", function()
			validation.ValidateObjectives({
				basic = { textKey = "Do the thing." },
			})
			assert.are.same({}, logged)
		end)

		it("passes for an objective with a valid inline trigger", function()
			validation.ValidateObjectives({
				withTrigger = {
					textKey = "Do the thing.",
					trigger = {
						type = triggerTypes.TimeElapsed,
						parameters = { seconds = 90 },
					},
				},
			})
			assert.are.same({}, logged)
		end)

		it("logs an error for missing textKey", function()
			validation.ValidateObjectives({ noText = {} })
			assert.is_true(hasError("Objective missing textKey: noText"))
		end)

		it("logs an error for empty textKey", function()
			validation.ValidateObjectives({ emptyText = { textKey = "" } })
			assert.is_true(hasError("Objective has empty textKey: emptyText"))
		end)

		it("logs errors for incorrect schema field types", function()
			validation.ValidateObjectives({
				badTypes = {
					textKey = "ok",
					amount = "notANumber",
					coop = "notABoolean",
				},
			})
			assert.is_true(
				hasError("Unexpected parameter type, expected number, got string. Objective: badTypes, Field: amount")
			)
			assert.is_true(
				hasError("Unexpected parameter type, expected boolean, got string. Objective: badTypes, Field: coop")
			)
		end)

		it("logs an error when the inline trigger has a 'settings' field", function()
			validation.ValidateObjectives({
				withSettings = {
					textKey = "ok",
					trigger = {
						settings = { repeating = true },
						type = triggerTypes.TimeElapsed,
						parameters = { seconds = 1 },
					},
				},
			})
			assert.is_true(hasError("Objective trigger must not have a 'settings' field. Objective: withSettings"))
		end)

		it("logs an error when the inline trigger has an 'actions' field", function()
			validation.ValidateObjectives({
				withActions = {
					textKey = "ok",
					trigger = {
						type = triggerTypes.TimeElapsed,
						parameters = { seconds = 1 },
						actions = { "someAction" },
					},
				},
			})
			assert.is_true(hasError("Objective trigger must not have an 'actions' field. Objective: withActions"))
		end)

		it("logs an error for an inline trigger with a missing type", function()
			validation.ValidateObjectives({
				noTypeTrigger = {
					textKey = "ok",
					trigger = { parameters = { seconds = 1 } },
				},
			})
			assert.is_true(hasError("Objective trigger missing type. Objective trigger: noTypeTrigger"))
		end)

		it("logs an error for an inline trigger with an invalid type", function()
			validation.ValidateObjectives({
				badTypeTrigger = {
					textKey = "ok",
					trigger = { type = "notAType" },
				},
			})
			assert.is_true(hasError("Objective trigger has invalid type. Objective trigger: badTypeTrigger"))
		end)

		it("logs an error for a missing required inline trigger parameter", function()
			validation.ValidateObjectives({
				missingParam = {
					textKey = "ok",
					trigger = {
						type = triggerTypes.TimeElapsed,
						parameters = {},
					},
				},
			})
			assert.is_true(
				hasError(
					"Objective trigger missing required parameter. Objective trigger: missingParam, Parameter: seconds"
				)
			)
		end)
	end)

	-- ── ValidateInitialStage ──────────────────────────────────────────────────

	describe("ValidateInitialStage", function()
		it("passes when stages are defined and initialStage matches", function()
			GG["MissionAPI"].Stages = { stageA = { objectives = { "obj" } } }
			validation.ValidateInitialStage("stageA")
			assert.are.same({}, logged)
		end)

		it("passes when no stages are defined and no initialStage is set", function()
			GG["MissionAPI"].Stages = {}
			validation.ValidateInitialStage(nil)
			assert.are.same({}, logged)
		end)

		it("logs an error when stages are defined but initialStage is not provided", function()
			GG["MissionAPI"].Stages = { stageA = { objectives = { "obj" } } }
			validation.ValidateInitialStage(nil)
			assert.is_true(hasError("Stages are defined, but initialStage is not provided."))
		end)

		it("logs an error when initialStage does not exist in any stage", function()
			GG["MissionAPI"].Stages = { stageA = { objectives = { "obj" } } }
			validation.ValidateInitialStage("stageB")
			assert.is_true(hasError("Initial stage does not exist in stages: stageB"))
		end)

		it("logs a warning when no stages are defined but initialStage is set", function()
			GG["MissionAPI"].Stages = {}
			validation.ValidateInitialStage("stageA")
			assert.is_true(hasError("initialStage 'stageA' is set, but no stages are defined."))
		end)
	end)

	-- ── ValidateStages ────────────────────────────────────────────────────────

	describe("ValidateStages", function()
		it("logs an error when stage ID is not a string", function()
			validation.ValidateStages({
				[123] = { objectives = { "obj1" } },
			})
			assert.is_true(hasError("Stage ID must be a string, got number"))
		end)

		it("passes for well-formed stages", function()
			validation.ValidateStages({
				stageA = { objectives = { "obj1" } },
				stageB = { objectives = { "obj1", "obj2" } },
			})
			assert.are.same({}, logged)
		end)

		it("logs an error when stage data is not a table", function()
			validation.ValidateStages({
				badStage = "notATable",
			})
			assert.is_true(hasError("Stage data must be a table, got string. Stage: badStage"))
		end)

		it("logs an error when a stage is missing the 'objectives' field", function()
			validation.ValidateStages({
				noObjectives = {},
			})
			assert.is_true(hasError("Stage missing 'objectives' field. Stage: noObjectives"))
		end)

		it("logs an error when 'objectives' field is not a table", function()
			validation.ValidateStages({
				badObjectives = { objectives = "notATable" },
			})
			assert.is_true(hasError("Stage 'objectives' field must be a table, got string. Stage: badObjectives"))
		end)

		it("logs an error when an objective ID in stage is not a string", function()
			validation.ValidateStages({
				badEntry = { objectives = { "obj1", 123 } },
			})
			assert.is_true(hasError("Stage 'objectives' entry #2 must be a string, got number. Stage: badEntry"))
		end)

		it("logs a warning when a stage has an empty 'objectives' table", function()
			validation.ValidateStages({
				empty = { objectives = {} },
			})
			assert.is_true(hasError("Stage has empty 'objectives' table. Stage: empty"))
		end)
	end)

	-- ── Parameter Validators ─────────────────────────────────────────────────

	describe("parameter validators", function()
		-- Calls ValidateActions with action 'a' referenced by a simple trigger.
		local function actionErrors(action)
			GG["MissionAPI"].Triggers = {
				t = normalizeTrigger({
					type = triggerTypes.TimeElapsed,
					parameters = { seconds = 1 },
					actions = { "a" },
				}),
			}
			validation.ValidateActions({ a = action })
		end

		-- Calls ValidateTriggers with trigger 't' backed by a valid 'ok' action.
		local function triggerErrors(trigger)
			validation.ValidateTriggers(
				{ t = normalizeTrigger(trigger) },
				{ ok = { type = actionTypes.SendMessage, parameters = { message = "ok" } } }
			)
		end

		describe("String", function()
			it("rejects wrong type", function()
				actionErrors({ type = actionTypes.SendMessage, parameters = { message = 123 } })
				assert.is_true(
					hasError("Unexpected parameter type, expected string, got number. Action: a, Parameter: message")
				)
			end)
		end)

		describe("Number", function()
			it("rejects wrong type", function()
				triggerErrors({
					type = triggerTypes.TimeElapsed,
					parameters = { seconds = "bad" },
					actions = { "ok" },
				})
				assert.is_true(
					hasError("Unexpected parameter type, expected number, got string. Trigger: t, Parameter: seconds")
				)
			end)
		end)

		describe("Fraction", function()
			it("rejects wrong type", function()
				triggerErrors({
					type = triggerTypes.ConstructionProgress,
					parameters = { teamName = "teamA", unitDefName = "armwar", progress = "bad" },
					actions = { "ok" },
				})
				assert.is_true(
					hasError("Unexpected parameter type, expected number, got string. Trigger: t, Parameter: progress")
				)
			end)

			it("rejects a value greater than 1", function()
				triggerErrors({
					type = triggerTypes.ConstructionProgress,
					parameters = { teamName = "teamA", unitDefName = "armwar", progress = 5.0 },
					actions = { "ok" },
				})
				assert.is_true(hasError("Fraction must be between 0 and 1, got 5. Trigger: t, Parameter: progress"))
			end)

			it("rejects a negative value", function()
				triggerErrors({
					type = triggerTypes.ConstructionProgress,
					parameters = { teamName = "teamA", unitDefName = "armwar", progress = -0.5 },
					actions = { "ok" },
				})
				assert.is_true(hasError("Fraction must be between 0 and 1, got -0.5. Trigger: t, Parameter: progress"))
			end)
		end)

		describe("Boolean", function()
			it("rejects wrong type", function()
				actionErrors({ type = actionTypes.PlaySound, parameters = { soundfile = "x", enqueue = "bad" } })
				assert.is_true(
					hasError("Unexpected parameter type, expected boolean, got string. Action: a, Parameter: enqueue")
				)
			end)
		end)

		describe("Function", function()
			it("rejects wrong type", function()
				actionErrors({ type = actionTypes.Custom, parameters = { ["function"] = "bad" } })
				assert.is_true(
					hasError("Unexpected parameter type, expected function, got string. Action: a, Parameter: function")
				)
			end)
		end)

		describe("TriggerID", function()
			it("rejects wrong type", function()
				actionErrors({ type = actionTypes.EnableTrigger, parameters = { triggerID = 123 } })
				assert.is_true(
					hasError("Unexpected parameter type, expected string, got number. Action: a, Parameter: triggerID")
				)
			end)

			it("rejects unknown trigger ID", function()
				actionErrors({ type = actionTypes.EnableTrigger, parameters = { triggerID = "noSuch" } })
				assert.is_true(hasError("Invalid triggerID: noSuch. Action: a, Parameter: triggerID"))
			end)
		end)

		describe("UnitDefName", function()
			it("rejects wrong type", function()
				actionErrors({
					type       = actionTypes.SpawnUnits,
					parameters = { unitLoadout = { { unitDefName = 123, teamName = 'teamA', x = 0, z = 0 } } },
				})
				assert.is_true(
					hasError(
						"Action 'a' unitLoadout entry #1, field 'unitDefName': Unexpected parameter type, expected string, got number"
					)
				)
			end)

			it("rejects unknown unit def name", function()
				actionErrors({
					type       = actionTypes.SpawnUnits,
					parameters = { unitLoadout = { { unitDefName = 'noSuch', teamName = 'teamA', x = 0, z = 0 } } },
				})
				assert.is_true(
					hasError("Action 'a' unitLoadout entry #1, field 'unitDefName': Invalid unitDefName: noSuch")
				)
			end)
		end)

		describe("FeatureDefName", function()
			it("rejects wrong type", function()
				actionErrors({
					type = actionTypes.CreateFeatures,
					parameters = { featureLoadout = { { featureDefName = 123, x = 0, z = 0 } } },
				})
				assert.is_true(
					hasError(
						"Action 'a' featureLoadout entry #1, field 'featureDefName': Unexpected parameter type, expected string, got number"
					)
				)
			end)

			it("rejects unknown feature def name", function()
				actionErrors({
					type = actionTypes.CreateFeatures,
					parameters = { featureLoadout = { { featureDefName = "noSuch", x = 0, z = 0 } } },
				})
				assert.is_true(
					hasError(
						"Action 'a' featureLoadout entry #1, field 'featureDefName': Invalid featureDefName: noSuch"
					)
				)
			end)
		end)

		describe("loadout entry required fields", function()
			it("reports a missing position coordinate in a unitLoadout entry", function()
				actionErrors({
					type = actionTypes.SpawnUnits,
					parameters = { unitLoadout = { { unitDefName = "armwar", teamName = "teamA", x = 0 } } }, -- missing z
				})
				assert.is_true(hasError("Action 'a' unitLoadout entry #1: missing required field 'z'"))
			end)

			it("reports a missing required field in a unitLoadout entry", function()
				actionErrors({
					type       = actionTypes.SpawnUnits,
					parameters = { unitLoadout = { { unitDefName = 'armwar', x = 0, z = 0 } } }, -- missing teamName
				})
				assert.is_true(hasError("Action 'a' unitLoadout entry #1: missing required field 'teamName'"))
			end)

			it("reports a missing position coordinate in a featureLoadout entry", function()
				actionErrors({
					type = actionTypes.CreateFeatures,
					parameters = { featureLoadout = { { featureDefName = "rockdef", z = 0 } } }, -- missing x
				})
				assert.is_true(hasError("Action 'a' featureLoadout entry #1: missing required field 'x'"))
			end)
		end)

		describe("WeaponDefName", function()
			it("rejects wrong type", function()
				actionErrors({
					type = actionTypes.SpawnExplosion,
					parameters = { weaponDefName = 123, position = { x = 0, z = 0 } },
				})
				assert.is_true(
					hasError(
						"Unexpected parameter type, expected string, got number. Action: a, Parameter: weaponDefName"
					)
				)
			end)

			it("rejects unknown weapon def name", function()
				actionErrors({
					type = actionTypes.SpawnExplosion,
					parameters = { weaponDefName = "noSuch", position = { x = 0, z = 0 } },
				})
				assert.is_true(hasError("Invalid weaponDefName: noSuch. Action: a, Parameter: weaponDefName"))
			end)
		end)

		describe("Facing", function()
			it("rejects non-string non-number type", function()
				actionErrors({
					type       = actionTypes.SpawnUnits,
					parameters = { unitLoadout = { { unitDefName = 'armwar', teamName = 'teamA', x = 0, z = 0, facing = {} } } },
				})
				assert.is_true(
					hasError(
						"Action 'a' unitLoadout entry #1, field 'facing': Unexpected parameter type, expected string or number, got table"
					)
				)
			end)

			it("rejects invalid facing value", function()
				actionErrors({
					type       = actionTypes.SpawnUnits,
					parameters = { unitLoadout = { { unitDefName = 'armwar', teamName = 'teamA', x = 0, z = 0, facing = 'diagonal' } } },
				})
				assert.is_true(
					hasError(
						"Action 'a' unitLoadout entry #1, field 'facing': Invalid facing: diagonal. Must be one of 'n', 's', 'e', 'w', 'north', 'south', 'east', 'west'."
					)
				)
			end)
		end)

		describe("SoundFile", function()
			it("rejects wrong type", function()
				actionErrors({ type = actionTypes.PlaySound, parameters = { soundfile = 123 } })
				assert.is_true(
					hasError("Unexpected parameter type, expected string, got number. Action: a, Parameter: soundfile")
				)
			end)

			it("rejects non-existent file", function()
				actionErrors({ type = actionTypes.PlaySound, parameters = { soundfile = "nonexistent/file.wav" } })
				assert.is_true(
					hasError(
						"Invalid soundfile: nonexistent/file.wav. File does not exist. Action: a, Parameter: soundfile"
					)
				)
			end)

			it("rejects file that is not a RIFF .wav", function()
				local origFileExists = VFS.FileExists
				local origReadWAV = _G.ReadWAV
				VFS.FileExists = function(p)
					return p == "dummy.wav"
				end
				_G.ReadWAV = function()
					return nil
				end

				actionErrors({ type = actionTypes.PlaySound, parameters = { soundfile = "dummy.wav" } })

				VFS.FileExists = origFileExists
				_G.ReadWAV = origReadWAV
				assert.is_true(
					hasError(
						"Invalid soundfile: dummy.wav. File is not a RIFF .wav file. Action: a, Parameter: soundfile"
					)
				)
			end)
		end)

		describe("TeamName", function()
			it("rejects wrong type", function()
				actionErrors({
					type       = actionTypes.AddResources,
					parameters = { teamName = 123, metal = 1 },
				})
				assert.is_true(hasError("Unexpected parameter type, expected string, got number. Action: a, Parameter: teamName"))
			end)

			it("rejects invalid team name", function()
				actionErrors({
					type       = actionTypes.AddResources,
					parameters = { teamName = 'noSuchTeam', metal = 1 },
				})
				assert.is_true(hasError("Invalid teamName: noSuchTeam. Action: a, Parameter: teamName"))
			end)
		end)

		describe("AllyTeamName", function()
			it("rejects wrong type", function()
				triggerErrors({
					type       = triggerTypes.UnitDetected,
					parameters = { unitName = 'x', sensorAllyTeamName = 123 },
					actions    = { 'ok' },
				})
				assert.is_true(hasError("Unexpected parameter type, expected string, got number. Trigger: t, Parameter: sensorAllyTeamName"))
			end)

			it("rejects invalid ally team name", function()
				triggerErrors({
					type       = triggerTypes.UnitDetected,
					parameters = { unitName = 'x', sensorAllyTeamName = 'noSuchAllyTeam' },
					actions    = { 'ok' },
				})
				assert.is_true(hasError("Invalid allyTeamName: noSuchAllyTeam. Trigger: t, Parameter: sensorAllyName"))
			end)
		end)

		describe("AllyTeamNames", function()
			it("rejects wrong type", function()
				actionErrors({ type = actionTypes.Victory, parameters = { allyTeamNames = 'bad' } })
				assert.is_true(hasError("Unexpected parameter type, expected table, got string. Action: a, Parameter: allyTeamNames"))
			end)

			it("rejects empty table", function()
				actionErrors({ type = actionTypes.Victory, parameters = { allyTeamNames = {} } })
				assert.is_true(hasError("allyTeamNames table is empty. Action: a, Parameter: allyTeamNames"))
			end)

			it("rejects non-string element", function()
				actionErrors({ type = actionTypes.Victory, parameters = { allyTeamNames = { 123 } } })
				assert.is_true(hasError("Unexpected parameter type, expected string, got number. Action: a, Parameter: allyTeamNames.allyTeamName #1"))
			end)

			it("rejects invalid ally team name element", function()
				actionErrors({ type = actionTypes.Victory, parameters = { allyTeamNames = { 'noSuchAllyTeam' } } })
				assert.is_true(hasError("Invalid allyTeamName: noSuchAllyTeam. Action: a, Parameter: allyTeamNames"))
			end)
		end)

		describe("Position", function()
			it("rejects wrong type", function()
				actionErrors({ type = actionTypes.AddMarker, parameters = { position = "bad" } })
				assert.is_true(
					hasError("Unexpected parameter type, expected table, got string. Action: a, Parameter: position")
				)
			end)

			it("rejects missing coordinate", function()
				actionErrors({ type = actionTypes.AddMarker, parameters = { position = { z = 0 } } })
				assert.is_true(hasError("Missing required parameter. Action: a, Parameter: position.x"))
			end)

			it("rejects non-number coordinate", function()
				actionErrors({ type = actionTypes.AddMarker, parameters = { position = { x = "bad", z = 0 } } })
				assert.is_true(
					hasError("Unexpected parameter type, expected number, got string. Action: a, Parameter: position.x")
				)
			end)
		end)

		describe("Positions", function()
			it("rejects wrong type", function()
				actionErrors({ type = actionTypes.DrawLines, parameters = { positions = "bad" } })
				assert.is_true(
					hasError("Unexpected parameter type, expected table, got string. Action: a, Parameter: positions")
				)
			end)

			it("rejects fewer than two positions", function()
				actionErrors({ type = actionTypes.DrawLines, parameters = { positions = { { x = 0, z = 0 } } } })
				assert.is_true(
					hasError("Positions table needs at least two positions. Action: a, Parameter: positions")
				)
			end)

			it("rejects non-table position element", function()
				actionErrors({
					type = actionTypes.DrawLines,
					parameters = { positions = { "bad", { x = 0, z = 0 } } },
				})
				assert.is_true(
					hasError(
						"Unexpected parameter type, expected table, got string. Action: a, Parameter: positions.position #1"
					)
				)
			end)

			it("rejects position element with a missing coordinate", function()
				actionErrors({
					type = actionTypes.DrawLines,
					parameters = { positions = { { z = 0 }, { x = 0, z = 0 } } },
				})
				assert.is_true(hasError("Missing required parameter. Action: a, Parameter: positions[1].x"))
			end)
		end)

		describe("Area", function()
			it("rejects wrong type", function()
				triggerErrors({
					type = triggerTypes.UnitEnteredLocation,
					parameters = { area = "bad", unitName = "x" },
					actions = { "ok" },
				})
				assert.is_true(
					hasError("Unexpected parameter type, expected table, got string. Trigger: t, Parameter: area")
				)
			end)

			it("rejects table that is neither rectangle nor circle", function()
				triggerErrors({
					type = triggerTypes.UnitEnteredLocation,
					parameters = { area = {}, unitName = "x" },
					actions = { "ok" },
				})
				assert.is_true(
					hasError(
						"Invalid area parameter, must be either rectangle { x1, z1, x2, z2 } with x1 < x2 and z1 < z2, or circle { x, z, radius }. Trigger: t, Parameter: area"
					)
				)
			end)

			it("rejects non-number field in an area", function()
				triggerErrors({
					type = triggerTypes.UnitEnteredLocation,
					parameters = { area = { x1 = "bad", z1 = 0, x2 = 1, z2 = 1 }, unitName = "x" },
					actions = { "ok" },
				})
				assert.is_true(
					hasError("Unexpected parameter type, expected number, got string. Trigger: t, Parameter: area.x1")
				)
			end)

			it("rejects rectangle where x1 is not less than x2", function()
				triggerErrors({
					type = triggerTypes.UnitEnteredLocation,
					parameters = { area = { x1 = 1, z1 = 0, x2 = 0, z2 = 1 }, unitName = "x" },
					actions = { "ok" },
				})
				assert.is_true(
					hasError("Invalid area rectangle parameter, x1 must be less than x2. Trigger: t, Parameter: area")
				)
			end)

			it("rejects rectangle where z1 is not less than z2", function()
				triggerErrors({
					type = triggerTypes.UnitEnteredLocation,
					parameters = { area = { x1 = 0, z1 = 1, x2 = 1, z2 = 0 }, unitName = "x" },
					actions = { "ok" },
				})
				assert.is_true(
					hasError("Invalid area rectangle parameter, z1 must be less than z2. Trigger: t, Parameter: area")
				)
			end)
		end)

		describe("Orders", function()
			before_each(function()
				_G.CMD = {}
				for i, name in ipairs({
					"STOP",
					"SELFD",
					"GUARD",
					"DGUN",
					"MOVE",
					"FIGHT",
					"PATROL",
					"UNLOAD_UNITS",
					"AREA_ATTACK",
					"RESTORE",
					"ATTACK",
					"CAPTURE",
					"REPAIR",
					"LOAD_UNITS",
					"RESURRECT",
					"RECLAIM",
					"CLOAK",
					"ONOFF",
					"FIRE_STATE",
					"MOVE_STATE",
				}) do
					CMD[name] = i
				end
				_G.GameCMD = { AREA_ATTACK_GROUND = table.count(CMD) + 1 }
			end)

			after_each(function()
				_G.CMD = nil
				_G.GameCMD = nil
			end)

			it("rejects wrong type", function()
				actionErrors({ type = actionTypes.IssueOrders, parameters = { unitName = "x", orders = "bad" } })
				assert.is_true(
					hasError("Unexpected parameter type, expected table, got string. Action: a, Parameter: orders")
				)
			end)

			it("rejects empty orders table", function()
				actionErrors({ type = actionTypes.IssueOrders, parameters = { unitName = "x", orders = {} } })
				assert.is_true(hasError("Orders table is empty. Action: a, Parameter: orders"))
			end)

			it("rejects non-table order entry", function()
				actionErrors({
					type = actionTypes.IssueOrders,
					parameters = { unitName = "x", orders = { "notanorder" } },
				})
				assert.is_true(
					hasError(
						"Unexpected parameter type, expected table, got string. Action: a, Parameter: orders.order #1"
					)
				)
			end)

			it("rejects invalid build order unit def name", function()
				actionErrors({
					type = actionTypes.IssueOrders,
					parameters = { unitName = "x", orders = { { "notAUnit", { 0, 0, 0 } } } },
				})
				assert.is_true(
					hasError("Invalid build order unitDefName: notAUnit. Action: a, Parameter: orders[1][1]")
				)
			end)

			it("rejects invalid order option", function()
				actionErrors({
					type = actionTypes.IssueOrders,
					parameters = { unitName = "x", orders = { { CMD.STOP, nil, { "diagonal" } } } },
				})
				assert.is_true(hasError("Invalid order option: diagonal. Action: a, Parameter: orders[1][3]"))
			end)

			it("rejects wrong number of parameters for a move command", function()
				actionErrors({
					type = actionTypes.IssueOrders,
					parameters = { unitName = "x", orders = { { CMD.MOVE, {} } } },
				})
				assert.is_true(
					hasError("Parameter must be an array of 3 numbers {x, y, z}. Action: a, Parameter: orders[1][2]")
				)
			end)
		end)

		describe("Command", function()
			before_each(function()
				installCommandTables()
				_G.UnitDefNames = { armwar = { id = 1 }, armsolar = { id = 42 } }
			end)

			after_each(function()
				_G.CMD = nil
				_G.GameCMD = nil
			end)

			-- Validation errors land in `logged` which is itself reset by the outer before_each.
			local function validateCommand(command)
				triggerErrors({
					type = triggerTypes.UnitOrdered,
					parameters = { command = command, unitDefName = "armwar" },
					actions = { "ok" },
				})
			end

			it("accepts a known command id", function()
				validateCommand(CMD.MOVE)
				assert.are.same({}, logged)
			end)

			it("accepts a build order authored as a unitDefName", function()
				validateCommand("armsolar")
				assert.are.same({}, logged)
			end)

			it("accepts the ANY qualifier", function()
				validateCommand(CMD.ANY)
				assert.are.same({}, logged)
			end)

			it("accepts the BUILD qualifier", function()
				validateCommand(CMD.BUILD)
				assert.are.same({}, logged)
			end)

			it("warns (without erroring) for a command consumed in AllowCommand", function()
				validateCommand(CMD.CLOAK)
				assert.is_true(
					hasError(
						"Command " .. "CLOAK" .. " may fail to trigger in UnitOrdered. Trigger: t, Parameter: command"
					)
				)
				assert.is_falsy(GG["MissionAPI"].HasValidationErrors)
			end)

			it("rejects an unknown command id", function()
				validateCommand(4242)
				assert.is_true(hasError("Unknown command ID: 4242. Trigger: t, Parameter: command"))
			end)

			it("rejects a build order with an unknown unitDefName", function()
				validateCommand("notAUnit")
				assert.is_true(hasError("Invalid unitDefName: notAUnit. Trigger: t, Parameter: command"))
			end)

			it("rejects a command that is neither a number nor a string", function()
				validateCommand(true)
				assert.is_true(
					hasError(
						"Unexpected parameter type, expected number or string, got boolean. Trigger: t, Parameter: command"
					)
				)
			end)

			it("requires a unit scope (unitName or unitDefName) alongside command", function()
				triggerErrors({
					type = triggerTypes.UnitOrdered,
					parameters = { command = CMD.MOVE },
					actions = { "ok" },
				})
				assert.is_true(
					hasError(
						[[Trigger 't' is missing required parameter. At least one of {"unitName","unitDefName"} is required.]]
					)
				)
			end)
		end)

		describe("requiresOneOf", function()
			it("logs an error when none of the required alternatives is present", function()
				triggerErrors({
					type = triggerTypes.UnitKilled,
					parameters = {},
					actions = { "ok" },
				})
				assert.is_true(
					hasError(
						[[Trigger 't' is missing required parameter. At least one of {"unitName","unitDefName"} is required.]]
					)
				)
			end)
		end)
	end)

	-- ── ValidateReferences ────────────────────────────────────────────────────

	describe("ValidateReferences", function()
		it("passes for valid unit, feature, and marker references", function()
			GG["MissionAPI"].Triggers = {
				statsKill = {
				type       = triggerTypes.TotalUnitsKilled,
				parameters = { teamName = 'teamA', quantity = 1, unitName = 'bot' },
			},
			}
			GG['MissionAPI'].Actions = {
				spawn  = { type = actionTypes.SpawnUnits, parameters = { unitLoadout = { { unitDefName = 'armwar', x = 0, z = 0, teamName = 'teamA', unitName = 'bot' } } } },
				create = { type = actionTypes.CreateFeatures, parameters = { featureLoadout = { { featureDefName = 'rockdef', x = 0, z = 0, featureName = 'rock' } } } },
				delete = { type = actionTypes.DestroyFeatures, parameters = { featureName = 'rock' } },
				add    = { type = actionTypes.AddMarker, parameters = { name = 'flag' } },
				erase  = { type = actionTypes.EraseMarker, parameters = { name = 'flag' } },
			}

			validation.ValidateReferences()

			assert.are.same({}, logged)
		end)

		it("treats inline objective triggers as unit and feature name references", function()
			GG["MissionAPI"].Objectives = {
				watchBot = {
					textKey = "watch bot",
					trigger = {
						type = triggerTypes.UnitsOwned,
						parameters = { teamName = 'teamA', unitName = 'bot' },
					},
				},
				watchRock = {
					textKey = "watch rock",
					trigger = {
						type = triggerTypes.FeatureDestroyed,
						parameters = { featureName = "rock" },
					},
				},
			}
			GG['MissionAPI'].Actions = {
				spawn  = { type = actionTypes.SpawnUnits, parameters = { unitLoadout = { { unitDefName = 'armwar', x = 0, z = 0, teamName = 'teamA', unitName = 'bot' } } } },
				create = { type = actionTypes.CreateFeatures, parameters = { featureLoadout = { { featureDefName = 'rockdef', x = 0, z = 0, featureName = 'rock' } } } },
			}

			validation.ValidateReferences()

			assert.are.same({}, logged)
		end)

		it(
			"logs errors for unit, feature, and marker names that are created-but-not-referenced or referenced-but-not-created",
			function()
			GG['MissionAPI'].Actions = {
				spawnUnused  = { type = actionTypes.SpawnUnits, parameters = { unitLoadout = { { unitDefName = 'armwar', x = 0, z = 0, teamName = 'teamA', unitName = 'unusedUnit' } } } },
				useUnknown   = { type = actionTypes.DespawnUnits, parameters = { unitName = 'unknownUnit' } },
				createUnused = { type = actionTypes.CreateFeatures, parameters = { featureLoadout = { { featureDefName = 'rockdef', x = 0, z = 0, featureName = 'unusedRock' } } } },
				deleteUnknown = { type = actionTypes.DestroyFeatures, parameters = { featureName = 'unknownRock' } },
				addUnused    = { type = actionTypes.AddMarker, parameters = { name = 'unusedFlag' } },
				eraseUnknown = { type = actionTypes.EraseMarker, parameters = { name = 'unknownFlag' } },
			}

				validation.ValidateReferences()

				assert.is_true(
					hasError(
						"Unit name 'unusedUnit' created, but not referenced by any trigger or action. Created in: action spawnUnused, unitLoadout entry #1"
					)
				)
				assert.is_true(
					hasError(
						"Unit name 'unknownUnit' not created in any trigger or action. Referenced in: action useUnknown"
					)
				)
				assert.is_true(
					hasError(
						"Feature name 'unusedRock' created, but not referenced by any trigger or action. Created in: action createUnused, featureLoadout entry #1"
					)
				)
				assert.is_true(
					hasError(
						"Feature name 'unknownRock' not created in any trigger or action. Referenced in: action deleteUnknown"
					)
				)
				assert.is_true(
					hasError("Marker name 'unusedFlag' is not referenced by any action. Referenced in: addUnused")
				)
				assert.is_true(
					hasError("Marker name 'unknownFlag' is not created in any action. Referenced in: eraseUnknown")
				)
			end
		)

		it("logs an error when a stage refers to a non-existent objective", function()
			GG["MissionAPI"].Objectives = {
				obj1 = { textKey = "ok" },
			}
			GG["MissionAPI"].Stages = {
				validStage = { objectives = { "obj1" } },
				badStage = { objectives = { "obj1", "nonExistent" } },
			}
			validation.ValidateReferences()
			assert.is_true(hasError("Stage refers to non-existent objective. Stage: badStage, Objective: nonExistent"))
		end)

		it("logs an error when nextStage references a non-existent stage", function()
			GG["MissionAPI"].Objectives = {
				badNext = { nextStage = "nonExistentStage" },
			}
			GG["MissionAPI"].Stages = { validStage = { objectives = { "badNext" } } }
			validation.ValidateReferences()
			assert.is_true(
				hasError("Objective references non-existent nextStage. Objective: badNext, Stage: nonExistentStage")
			)
		end)

		it("logs a nextStage type error for non-string nextStage", function()
			GG["MissionAPI"].Objectives = {
				badNextType = { nextStage = 123 },
			}
			GG["MissionAPI"].Stages = { validStage = { objectives = { "badNextType" } } }
			validation.ValidateReferences()
			assert.is_true(
				hasError(
					"Unexpected parameter type, expected string, got number. Objective: badNextType, Field: nextStage"
				)
			)
		end)

		it("does not log non-existent objective for non-string stage objective entries", function()
			GG["MissionAPI"].Objectives = {
				obj1 = { textKey = "ok" },
			}
			GG["MissionAPI"].Stages = {
				badStage = { objectives = { "obj1", 123 } },
			}
			validation.ValidateReferences()
			assert.is_false(hasError("Stage refers to non-existent objective. Stage: badStage, Objective: 123"))
		end)
	end)
end)
