require("spec_helper")

local validation    = VFS.Include('luarules/mission_api/validation.lua')
local triggerSchema = VFS.Include('luarules/mission_api/triggers_schema.lua')
local actionSchema  = VFS.Include('luarules/mission_api/actions_schema.lua')

local triggerTypes  = triggerSchema.Types
local actionTypes   = actionSchema.Types

-- Mirrors the normalisation done by triggers_loader before calling ValidateTriggers.
local function normalizeTrigger(raw)
	local s         = raw.settings or {}
	s.prerequisites = s.prerequisites or {}
	s.repeating     = s.repeating or false
	s.maxRepeats    = s.maxRepeats or nil
	s.difficulties  = s.difficulties or nil
	s.coop          = s.coop or false
	s.active        = s.active or true
	raw.settings    = s
	raw.triggered   = false
	raw.repeatCount = 0
	return raw
end

describe("mission_api.validation", function()
	local logged

	local function hasError(msg)
		return table.any(logged, function(m) return m == "[Mission API] " .. msg end)
	end

	before_each(function()
		logged                   = {}
		Spring.Log               = function(_, _, msg) logged[#logged + 1] = msg end
		Spring.GetTeamAllyTeamID = function() return true end
		Spring.GetAllyTeamList   = function() return { 0 } end
		_G.UnitDefNames          = { armwar = { id = 1 } }
		_G.FeatureDefNames       = {}
		_G.WeaponDefNames        = {}
		GG['MissionAPI']         = {
			TriggerTypes = triggerTypes,
			ActionTypes  = actionTypes,
			Triggers     = {},
			Actions      = {},
		}
	end)

	after_each(function()
		GG['MissionAPI'] = nil
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
					type       = triggerTypes.TimeElapsed,
					parameters = { gameFrame = 1 },
					actions    = { 'ok' },
				}),
			}, rawActions)

			assert.are.same({}, logged)
		end)

		it(
			"logs errors for missing type, invalid type, missing required parameter, invalid action ID, and invalid prerequisite",
			function()
				validation.ValidateTriggers({
					noType = normalizeTrigger({
						actions = { 'ok' },
					}),
					badType = normalizeTrigger({
						type    = 'notAType',
						actions = { 'ok' },
					}),
					missingParam = normalizeTrigger({
						type       = triggerTypes.TimeElapsed,
						parameters = {},
						actions    = { 'ok' },
					}),
					badActionID = normalizeTrigger({
						type       = triggerTypes.TimeElapsed,
						parameters = { gameFrame = 1 },
						actions    = { 'doesNotExist' },
					}),
					badPrereq = normalizeTrigger({
						type       = triggerTypes.TimeElapsed,
						parameters = { gameFrame = 1 },
						settings   = { prerequisites = { 'noSuchTrigger' } },
						actions    = { 'ok' },
					}),
				}, rawActions)

				assert.is_true(hasError("Trigger missing type. Trigger: noType"))
				assert.is_true(hasError("Trigger has invalid type. Trigger: badType"))
				assert.is_true(hasError("Trigger missing required parameter. Trigger: missingParam, Parameter: gameFrame"))
				assert.is_true(hasError("Trigger has invalid action ID: badActionID, Action: doesNotExist"))
				assert.is_true(hasError("Trigger prerequisite does not exist. Trigger: badPrereq, Prerequisite triggerID: noSuchTrigger"))
			end)
	end)

	-- ── ValidateActions ───────────────────────────────────────────────────────

	describe("ValidateActions", function()
		it("passes for a valid action referenced by a trigger", function()
			GG['MissionAPI'].Triggers = {
				t = normalizeTrigger({
					type       = triggerTypes.TimeElapsed,
					parameters = { gameFrame = 1 },
					actions    = { 'ok' },
				}),
			}

			validation.ValidateActions({
				ok = { type = actionTypes.SendMessage, parameters = { message = "ok" } },
			})

			assert.are.same({}, logged)
		end)

		it("logs errors for missing type, missing required parameter, and unreferenced actions", function()
			GG['MissionAPI'].Triggers = {
				t = normalizeTrigger({
					type       = triggerTypes.TimeElapsed,
					parameters = { gameFrame = 1 },
					actions    = { 'ok', 'noType', 'missingParam' },
				}),
			}

			validation.ValidateActions({
				ok           = { type = actionTypes.SendMessage, parameters = { message = "ok" } },
				noType       = {},
				missingParam = { type = actionTypes.EnableTrigger, parameters = {} },
				unused       = { type = actionTypes.SendMessage, parameters = { message = "unused" } },
			})

			assert.is_true(hasError("Action missing type. Action: noType"))
			assert.is_true(hasError("Action missing required parameter. Action: missingParam, Parameter: triggerID"))
			assert.is_true(hasError("Actions not referenced by any trigger: unused"))
		end)
	end)

	-- ── Parameter Validators ─────────────────────────────────────────────────

	describe("parameter validators", function()
		-- Calls ValidateActions with action 'a' referenced by a simple trigger.
		local function actionErrors(action)
			GG['MissionAPI'].Triggers = {
				t = normalizeTrigger({
					type       = triggerTypes.TimeElapsed,
					parameters = { gameFrame = 1 },
					actions    = { 'a' },
				}),
			}
			validation.ValidateActions({ a = action })
		end

		-- Calls ValidateTriggers with trigger 't' backed by a valid 'ok' action.
		local function triggerErrors(trigger)
			validation.ValidateTriggers(
				{ t = normalizeTrigger(trigger) },
				{ ok = { type = actionTypes.SendMessage, parameters = { message = 'ok' } } }
			)
		end

		describe("String", function()
			it("rejects wrong type", function()
				actionErrors({ type = actionTypes.SendMessage, parameters = { message = 123 } })
				assert.is_true(hasError("Unexpected parameter type, expected string, got number. Action: a, Parameter: message"))
			end)
		end)

		describe("Number", function()
			it("rejects wrong type", function()
				triggerErrors({
					type       = triggerTypes.TimeElapsed,
					parameters = { gameFrame = 'bad' },
					actions    = { 'ok' },
				})
				assert.is_true(hasError("Unexpected parameter type, expected number, got string. Trigger: t, Parameter: gameFrame"))
			end)
		end)

		describe("Boolean", function()
			it("rejects wrong type", function()
				actionErrors({ type = actionTypes.DespawnUnits, parameters = { unitName = 'x', selfDestruct = 'bad' } })
				assert.is_true(hasError("Unexpected parameter type, expected boolean, got string. Action: a, Parameter: selfDestruct"))
			end)
		end)

		describe("Function", function()
			it("rejects wrong type", function()
				actionErrors({ type = actionTypes.Custom, parameters = { ['function'] = 'bad' } })
				assert.is_true(hasError("Unexpected parameter type, expected function, got string. Action: a, Parameter: function"))
			end)
		end)

		describe("TriggerID", function()
			it("rejects wrong type", function()
				actionErrors({ type = actionTypes.EnableTrigger, parameters = { triggerID = 123 } })
				assert.is_true(hasError("Unexpected parameter type, expected string, got number. Action: a, Parameter: triggerID"))
			end)

			it("rejects unknown trigger ID", function()
				actionErrors({ type = actionTypes.EnableTrigger, parameters = { triggerID = 'noSuch' } })
				assert.is_true(hasError("Invalid triggerID: noSuch. Action: a, Parameter: triggerID"))
			end)
		end)

		describe("UnitDefName", function()
			it("rejects wrong type", function()
				actionErrors({
					type       = actionTypes.SpawnUnits,
					parameters = { unitDefName = 123, teamID = 0, position = { x = 0, z = 0 } },
				})
				assert.is_true(hasError("Unexpected parameter type, expected string, got number. Action: a, Parameter: unitDefName"))
			end)

			it("rejects unknown unit def name", function()
				actionErrors({
					type       = actionTypes.SpawnUnits,
					parameters = { unitDefName = 'noSuch', teamID = 0, position = { x = 0, z = 0 } },
				})
				assert.is_true(hasError("Invalid unitDefName: noSuch. Action: a, Parameter: unitDefName"))
			end)
		end)

		describe("FeatureDefName", function()
			it("rejects wrong type", function()
				actionErrors({
					type       = actionTypes.CreateFeature,
					parameters = { featureDefName = 123, position = { x = 0, z = 0 } },
				})
				assert.is_true(hasError("Unexpected parameter type, expected string, got number. Action: a, Parameter: featureDefName"))
			end)

			it("rejects unknown feature def name", function()
				actionErrors({
					type       = actionTypes.CreateFeature,
					parameters = { featureDefName = 'noSuch', position = { x = 0, z = 0 } },
				})
				assert.is_true(hasError("Invalid featureDefName: noSuch. Action: a, Parameter: featureDefName"))
			end)
		end)

		describe("WeaponDefName", function()
			it("rejects wrong type", function()
				actionErrors({
					type       = actionTypes.SpawnExplosion,
					parameters = { weaponDefName = 123, position = { x = 0, z = 0 } },
				})
				assert.is_true(hasError("Unexpected parameter type, expected string, got number. Action: a, Parameter: weaponDefName"))
			end)

			it("rejects unknown weapon def name", function()
				actionErrors({
					type       = actionTypes.SpawnExplosion,
					parameters = { weaponDefName = 'noSuch', position = { x = 0, z = 0 } },
				})
				assert.is_true(hasError("Invalid weaponDefName: noSuch. Action: a, Parameter: weaponDefName"))
			end)
		end)

		describe("Facing", function()
			it("rejects non-string non-number type", function()
				actionErrors({
					type       = actionTypes.SpawnUnits,
					parameters = { unitDefName = 'armwar', teamID = 0, position = { x = 0, z = 0 }, facing = {} },
				})
				assert.is_true(hasError("Unexpected parameter type, expected string or number, got table. Action: a, Parameter: facing"))
			end)

			it("rejects invalid facing value", function()
				actionErrors({
					type       = actionTypes.SpawnUnits,
					parameters = { unitDefName = 'armwar', teamID = 0, position = { x = 0, z = 0 }, facing = 'diagonal' },
				})
				assert.is_true(hasError("Invalid facing: diagonal. Must be one of 'n', 's', 'e', 'w', 'north', 'south', 'east', 'west'.. Action: a, Parameter: facing"))
			end)
		end)

		describe("SoundFile", function()
			it("rejects wrong type", function()
				actionErrors({ type = actionTypes.PlaySound, parameters = { soundfile = 123 } })
				assert.is_true(hasError("Unexpected parameter type, expected string, got number. Action: a, Parameter: soundfile"))
			end)

			it("rejects non-existent file", function()
				actionErrors({ type = actionTypes.PlaySound, parameters = { soundfile = 'nonexistent/file.wav' } })
				assert.is_true(hasError("Invalid soundfile: nonexistent/file.wav. File does not exist. Action: a, Parameter: soundfile"))
			end)

			it("rejects file that is not a RIFF .wav", function()
				local origFileExists = VFS.FileExists
				local origReadWAV    = _G.ReadWAV
				VFS.FileExists = function(p) return p == 'dummy.wav' end
				_G.ReadWAV     = function() return nil end

				actionErrors({ type = actionTypes.PlaySound, parameters = { soundfile = 'dummy.wav' } })

				VFS.FileExists = origFileExists
				_G.ReadWAV     = origReadWAV
				assert.is_true(hasError("Invalid soundfile: dummy.wav. File is not a RIFF .wav file. Action: a, Parameter: soundfile"))
			end)
		end)

		describe("TeamID", function()
			it("rejects wrong type", function()
				actionErrors({
					type       = actionTypes.SpawnUnits,
					parameters = { unitDefName = 'armwar', teamID = 'bad', position = { x = 0, z = 0 } },
				})
				assert.is_true(hasError("Unexpected parameter type, expected number, got string. Action: a, Parameter: teamID"))
			end)

			it("rejects invalid team ID", function()
				Spring.GetTeamAllyTeamID = function() return nil end
				actionErrors({
					type       = actionTypes.SpawnUnits,
					parameters = { unitDefName = 'armwar', teamID = 99, position = { x = 0, z = 0 } },
				})
				assert.is_true(hasError("Invalid teamID: 99. Action: a, Parameter: teamID"))
			end)
		end)

		describe("AllyTeamID", function()
			it("rejects wrong type", function()
				triggerErrors({
					type       = triggerTypes.UnitSpotted,
					parameters = { unitName = 'x', spottingAllyTeamID = 'bad' },
					actions    = { 'ok' },
				})
				assert.is_true(hasError("Unexpected parameter type, expected number, got string. Trigger: t, Parameter: spottingAllyTeamID"))
			end)

			it("rejects invalid ally team ID", function()
				triggerErrors({
					type       = triggerTypes.UnitSpotted,
					parameters = { unitName = 'x', spottingAllyTeamID = 99 },
					actions    = { 'ok' },
				})
				assert.is_true(hasError("Invalid allyTeamID: 99. Trigger: t, Parameter: spottingAllyTeamID"))
			end)
		end)

		describe("AllyTeamIDs", function()
			before_each(function()
				Spring.GetAllyTeamInfo = function(id) return id == 0 end
			end)

			it("rejects wrong type", function()
				actionErrors({ type = actionTypes.Victory, parameters = { allyTeamIDs = 'bad' } })
				assert.is_true(hasError("Unexpected parameter type, expected table, got string. Action: a, Parameter: allyTeamIDs"))
			end)

			it("rejects empty table", function()
				actionErrors({ type = actionTypes.Victory, parameters = { allyTeamIDs = {} } })
				assert.is_true(hasError("allyTeamIDs table is empty. Action: a, Parameter: allyTeamIDs"))
			end)

			it("rejects non-number element", function()
				actionErrors({ type = actionTypes.Victory, parameters = { allyTeamIDs = { 'bad' } } })
				assert.is_true(hasError("Unexpected parameter type, expected number, got string. Action: a, Parameter: allyTeamIDs.allyTeamID #1"))
			end)

			it("rejects invalid ally team ID element", function()
				actionErrors({ type = actionTypes.Victory, parameters = { allyTeamIDs = { 99 } } })
				assert.is_true(hasError("Invalid allyTeamID: 99. Action: a, Parameter: allyTeamIDs"))
			end)
		end)

		describe("Position", function()
			it("rejects wrong type", function()
				actionErrors({ type = actionTypes.AddMarker, parameters = { position = 'bad' } })
				assert.is_true(hasError("Unexpected parameter type, expected table, got string. Action: a, Parameter: position"))
			end)

			it("rejects missing coordinate", function()
				actionErrors({ type = actionTypes.AddMarker, parameters = { position = { z = 0 } } })
				assert.is_true(hasError("Missing required parameter. Action: a, Parameter: position.x"))
			end)

			it("rejects non-number coordinate", function()
				actionErrors({ type = actionTypes.AddMarker, parameters = { position = { x = 'bad', z = 0 } } })
				assert.is_true(hasError("Unexpected parameter type, expected number, got string. Action: a, Parameter: position.x"))
			end)
		end)

		describe("Positions", function()
			it("rejects wrong type", function()
				actionErrors({ type = actionTypes.DrawLines, parameters = { positions = 'bad' } })
				assert.is_true(hasError("Unexpected parameter type, expected table, got string. Action: a, Parameter: positions"))
			end)

			it("rejects fewer than two positions", function()
				actionErrors({ type = actionTypes.DrawLines, parameters = { positions = { { x = 0, z = 0 } } } })
				assert.is_true(hasError("Positions table needs at least two positions. Action: a, Parameter: positions"))
			end)

			it("rejects non-table position element", function()
				actionErrors({
					type       = actionTypes.DrawLines,
					parameters = { positions = { 'bad', { x = 0, z = 0 } } },
				})
				assert.is_true(hasError("Unexpected parameter type, expected table, got string. Action: a, Parameter: positions.position #1"))
			end)

			it("rejects position element with a missing coordinate", function()
				actionErrors({
					type       = actionTypes.DrawLines,
					parameters = { positions = { { z = 0 }, { x = 0, z = 0 } } },
				})
				assert.is_true(hasError("Missing required parameter. Action: a, Parameter: positions[1].x"))
			end)
		end)

		describe("Area", function()
			it("rejects wrong type", function()
				triggerErrors({
					type       = triggerTypes.UnitEnteredLocation,
					parameters = { area = 'bad', unitName = 'x' },
					actions    = { 'ok' },
				})
				assert.is_true(hasError("Unexpected parameter type, expected table, got string. Trigger: t, Parameter: area"))
			end)

			it("rejects table that is neither rectangle nor circle", function()
				triggerErrors({
					type       = triggerTypes.UnitEnteredLocation,
					parameters = { area = {}, unitName = 'x' },
					actions    = { 'ok' },
				})
				assert.is_true(hasError("Invalid area parameter, must be either rectangle { x1, z1, x2, z2 } with x1 < x2 and z1 < z2, or circle { x, z, radius }. Trigger: t, Parameter: area"))
			end)

			it("rejects non-number field in an area", function()
				triggerErrors({
					type       = triggerTypes.UnitEnteredLocation,
					parameters = { area = { x1 = 'bad', z1 = 0, x2 = 1, z2 = 1 }, unitName = 'x' },
					actions    = { 'ok' },
				})
				assert.is_true(hasError("Unexpected parameter type, expected number, got string. Trigger: t, Parameter: area.x1"))
			end)

			it("rejects rectangle where x1 is not less than x2", function()
				triggerErrors({
					type       = triggerTypes.UnitEnteredLocation,
					parameters = { area = { x1 = 1, z1 = 0, x2 = 0, z2 = 1 }, unitName = 'x' },
					actions    = { 'ok' },
				})
				assert.is_true(hasError("Invalid area rectangle parameter, x1 must be less than x2. Trigger: t, Parameter: area"))
			end)

			it("rejects rectangle where z1 is not less than z2", function()
				triggerErrors({
					type       = triggerTypes.UnitEnteredLocation,
					parameters = { area = { x1 = 0, z1 = 1, x2 = 1, z2 = 0 }, unitName = 'x' },
					actions    = { 'ok' },
				})
				assert.is_true(hasError("Invalid area rectangle parameter, z1 must be less than z2. Trigger: t, Parameter: area"))
			end)
		end)

		describe("Orders", function()
			before_each(function()
				_G.CMD = {}
				for i, name in ipairs({
					'STOP', 'SELFD', 'GUARD', 'DGUN', 'MOVE', 'FIGHT', 'PATROL',
					'UNLOAD_UNITS', 'AREA_ATTACK', 'RESTORE', 'ATTACK', 'CAPTURE',
					'REPAIR', 'LOAD_UNITS', 'RESURRECT', 'RECLAIM', 'CLOAK', 'ONOFF',
					'FIRE_STATE', 'MOVE_STATE',
				}) do CMD[name] = i end
				_G.GameCMD = { AREA_ATTACK_GROUND = table.count(CMD) + 1 }
			end)

			after_each(function()
				_G.CMD     = nil
				_G.GameCMD = nil
			end)

			it("rejects wrong type", function()
				actionErrors({ type = actionTypes.IssueOrders, parameters = { unitName = 'x', orders = 'bad' } })
				assert.is_true(hasError("Unexpected parameter type, expected table, got string. Action: a, Parameter: orders"))
			end)

			it("rejects empty orders table", function()
				actionErrors({ type = actionTypes.IssueOrders, parameters = { unitName = 'x', orders = {} } })
				assert.is_true(hasError("Orders table is empty. Action: a, Parameter: orders"))
			end)

			it("rejects non-table order entry", function()
				actionErrors({ type = actionTypes.IssueOrders, parameters = { unitName = 'x', orders = { 'notanorder' } } })
				assert.is_true(hasError("Unexpected parameter type, expected table, got string. Action: a, Parameter: orders.order #1"))
			end)

			it("rejects invalid build order unit def name", function()
				actionErrors({
					type       = actionTypes.IssueOrders,
					parameters = { unitName = 'x', orders = { { 'notAUnit', { 0, 0, 0 } } } },
				})
				assert.is_true(hasError("Invalid build order unitDefName: notAUnit. Action: a, Parameter: orders[1][1]"))
			end)

			it("rejects invalid order option", function()
				actionErrors({
					type       = actionTypes.IssueOrders,
					parameters = { unitName = 'x', orders = { { CMD.STOP, nil, { 'diagonal' } } } },
				})
				assert.is_true(hasError("Invalid order option: diagonal. Action: a, Parameter: orders[1][3]"))
			end)

			it("rejects wrong number of parameters for a move command", function()
				actionErrors({
					type       = actionTypes.IssueOrders,
					parameters = { unitName = 'x', orders = { { CMD.MOVE, {} } } },
				})
				assert.is_true(hasError("Parameter must be an array of 3 numbers {x, y, z}. Action: a, Parameter: orders[1][2]"))
			end)
		end)

		describe("requiresOneOf", function()
			it("logs an error when none of the required alternatives is present", function()
				triggerErrors({
					type       = triggerTypes.UnitKilled,
					parameters = {},
					actions    = { 'ok' },
				})
				assert.is_true(hasError(
					[[Trigger 't' is missing required parameter. At least one of {"unitName","unitDefName"} is required.]]
				))
			end)
		end)
	end)

	-- ── ValidateReferences ────────────────────────────────────────────────────

	describe("ValidateReferences", function()
		it("passes for valid unit, feature, and marker references", function()
			GG['MissionAPI'].Triggers = {
				statsKill = {
					type       = triggerTypes.TotalUnitsKilled,
					parameters = { teamID = 0, quantity = 1, unitName = 'bot' },
				},
			}
			GG['MissionAPI'].Actions = {
				spawn  = { type = actionTypes.SpawnUnits, parameters = { unitName = 'bot' } },
				create = { type = actionTypes.CreateFeature, parameters = { featureName = 'rock' } },
				delete = { type = actionTypes.DestroyFeature, parameters = { featureName = 'rock' } },
				add    = { type = actionTypes.AddMarker, parameters = { name = 'flag' } },
				erase  = { type = actionTypes.EraseMarker, parameters = { name = 'flag' } },
			}

			validation.ValidateReferences()

			assert.are.same({}, logged)
		end)

		it("logs errors for unit, feature, and marker names that are created-but-not-referenced or referenced-but-not-created",
			function()
			GG['MissionAPI'].Actions = {
				spawnUnused  = { type = actionTypes.SpawnUnits, parameters = { unitName = 'unusedUnit' } },
				useUnknown   = { type = actionTypes.DespawnUnits, parameters = { unitName = 'unknownUnit' } },
				createUnused = { type = actionTypes.CreateFeature, parameters = { featureName = 'unusedRock' } },
				deleteUnknown = { type = actionTypes.DestroyFeature, parameters = { featureName = 'unknownRock' } },
				addUnused    = { type = actionTypes.AddMarker, parameters = { name = 'unusedFlag' } },
				eraseUnknown = { type = actionTypes.EraseMarker, parameters = { name = 'unknownFlag' } },
			}

			validation.ValidateReferences()

			assert.is_true(hasError("Unit name 'unusedUnit' created, but not referenced by any trigger or action. Created in: action spawnUnused"))
			assert.is_true(hasError("Unit name 'unknownUnit' not created in any trigger or action. Referenced in: action useUnknown"))
			assert.is_true(hasError("Feature name 'unusedRock' created, but not referenced by any trigger or action. Created in: action createUnused"))
			assert.is_true(hasError("Feature name 'unknownRock' not created in any trigger or action. Referenced in: action deleteUnknown"))
			assert.is_true(hasError("Marker name 'unusedFlag' is not referenced by any action. Referenced in: addUnused"))
			assert.is_true(hasError("Marker name 'unknownFlag' is not created in any action. Referenced in: eraseUnknown"))
			end)
	end)
end)
