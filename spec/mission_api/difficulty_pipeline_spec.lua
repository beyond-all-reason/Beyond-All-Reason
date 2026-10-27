local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- The full loadMission sequence from api_missions.lua, with difficulty-wrapped parameters:
-- validation of the raw mission (wrappers intact), loaders, then in-place resolution.

GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = MissionSpecEnv.include(env, "luarules/mission_api/parameter_types.lua")
MissionSpecEnv.registerModules(env)
GG["MissionAPI"].ActionDefinitions = MissionSpecEnv.include(env, "luarules/mission_api/actions_loader.lua")
	.LoadActionDefinitions()
GG["MissionAPI"].ConditionDefinitions = MissionSpecEnv.include(env, "luarules/mission_api/conditions_loader.lua")
	.LoadConditionDefinitions()

local function withCommandIDs(names, firstID)
	local commands = {}
	for offset, name in ipairs(names) do
		local id = firstID + offset
		commands[name] = id
		commands[id] = name
	end
	return commands
end

local savedCMD, savedGameCMD = env.CMD, env.GameCMD
env.CMD = withCommandIDs({ "STOP", "MOVE", "ATTACK" }, 0)
env.GameCMD = withCommandIDs({ "AREA_ATTACK_GROUND" }, 1000)
env.CMD.ANY, env.CMD.BUILD = "a", "b"
local validation = MissionSpecEnv.include(env, "luarules/mission_api/validation.lua")
env.CMD, env.GameCMD = savedCMD, savedGameCMD

-- Def-name globals the validators read, set at module scope for every test in this file.
_G.UnitDefNames = { armwar = { id = 1 }, armpw = { id = 2 } }
_G.FeatureDefNames = {}
_G.WeaponDefNames = {}

local originalLog = env.Spring.Log

local stagesController = MissionSpecEnv.include(env, "luarules/mission_api/stages_loader.lua")
local objectivesController = MissionSpecEnv.include(env, "luarules/mission_api/objectives_loader.lua")
local triggersController = MissionSpecEnv.include(env, "luarules/mission_api/conditions_loader.lua")
local actionsController = MissionSpecEnv.include(env, "luarules/mission_api/actions_loader.lua")
local difficulty = GG["MissionAPI"].Modules.Difficulty

local actionDefinitions = GG["MissionAPI"].ActionDefinitions
local triggerDefinitions = GG["MissionAPI"].ConditionDefinitions
local eventTypes = triggerDefinitions.EventTypes
local metricTypes = triggerDefinitions.MetricTypes
local actionTypes = actionDefinitions.Types

-- Difficulties from luarules/mission_api/difficulties.json.
local EASY, MEDIUM, HARD = 2, 3, 4

describe("mission_api difficulty pipeline", function()
	local logged

	-- Team layout and lookups come from the mission env's stubs; only the log capture
	-- is swapped per test, and restored after it.
	before_each(function()
		logged = {}
		env.Spring.Log = function(_, _, msg)
			logged[#logged + 1] = msg
		end
	end)

	after_each(function()
		env.Spring.Log = originalLog
	end)

	-- Mirrors loadMission() in api_missions.lua up to (not including) parameter_processing.
	local function loadMission(mission, currentDifficulty)
		GG["MissionAPI"] = {
			Difficulty = currentDifficulty,
			Modules = GG["MissionAPI"].Modules,
			ActionDefinitions = actionDefinitions,
			ConditionDefinitions = triggerDefinitions,
			ObjectiveTriggers = {},
			ObjectiveStages = {},
		}

		local result = validation.ValidateMission(mission)
		validation.LogResult(result)
		if not result.ok then
			return GG["MissionAPI"], result
		end

		local rawTriggers = mission.Triggers or {}
		local rawActions = mission.Actions or {}
		GG["MissionAPI"].CurrentStageID = mission.InitialStage
		GG["MissionAPI"].Stages = stagesController.ProcessRawStages(mission.Stages or {})
		GG["MissionAPI"].Objectives =
			objectivesController.ProcessRawObjectives(mission.Objectives or {}, rawTriggers, rawActions, mission.Stages)
		GG["MissionAPI"].Triggers = triggersController.ProcessRawTriggers(rawTriggers)
		GG["MissionAPI"].Actions = actionsController.ProcessRawActions(rawActions)
		GG["MissionAPI"].Cutscenes = mission.Cutscenes or {}

		difficulty.ResolveTriggers(GG["MissionAPI"].Triggers)
		difficulty.ResolveActions(GG["MissionAPI"].Actions)
		difficulty.ResolveObjectives(GG["MissionAPI"].Objectives)
		difficulty.ResolveCutscenes(GG["MissionAPI"].Cutscenes)

		return GG["MissionAPI"], result
	end

	local function wrappedMission()
		return {
			InitialStage = "s1",
			Stages = {
				s1 = { objectives = { "surviveTimer", "killBots", "holdBots" } },
				s2 = { objectives = { "surviveTimer" } },
			},
			Objectives = {
				surviveTimer = {
					textKey = "survive",
					amount = { difficulties = { Easy = 2, Hard = 4 } },
					trigger = {
						type = eventTypes.TimeElapsed,
						parameters = { seconds = { difficulties = { Easy = 90, Hard = 45 } } },
					},
				},
				killBots = {
					textKey = "kill",
					amount = { difficulties = { Easy = 3, Hard = 6 } },
					nextStage = { difficulties = { Easy = "s1", Hard = "s2" } },
					trigger = {
						type = eventTypes.TotalUnitsKilled,
						parameters = { teamID = 0, unitName = "bot" },
					},
				},
				holdBots = {
					textKey = "hold",
					amount = { difficulties = { Easy = 1, Hard = 2 } },
					trigger = {
						type = metricTypes.UnitsOwned,
						parameters = { teamID = 0, unitName = "bot" },
					},
				},
			},
			Triggers = {
				wave = {
					type = eventTypes.TimeElapsed,
					parameters = { seconds = { difficulties = { Easy = 120, Hard = 60 } } },
					settings = { difficulties = { "Medium", "Hard" } },
					actions = { "spawnBots", "announce" },
				},
				anyDifficulty = {
					type = eventTypes.TimeElapsed,
					parameters = { seconds = 5 },
					settings = { difficulties = {} },
					actions = { "announce" },
				},
			},
			Actions = {
				spawnBots = {
					type = actionTypes.SpawnUnits,
					parameters = {
						unitLoadout = {
							difficulties = {
								Easy = { { unitDefName = "armwar", x = 0, z = 0, team = 0, unitName = "bot" } },
								Hard = {
									{ unitDefName = "armwar", x = 0, z = 0, team = 0, unitName = "bot" },
									{ unitDefName = "armwar", x = 10, z = 0, team = 0, unitName = "bot" },
								},
							},
						},
					},
				},
				announce = {
					type = actionTypes.SendMessage,
					parameters = { messageKey = { difficulties = { Easy = "incoming", Hard = "INCOMING" } } },
				},
			},
		}
	end

	it("validates a fully wrapped mission without errors or warnings", function()
		loadMission(wrappedMission(), HARD)
		assert.are.same({}, logged)
	end)

	it("resolves trigger parameters and converts the settings gate names to difficulty values", function()
		local missionApi = loadMission(wrappedMission(), HARD)
		assert.are.equal(60, missionApi.Triggers.wave.parameters.seconds)
		assert.are.same({ MEDIUM, HARD }, missionApi.Triggers.wave.settings.difficulties)
		assert.are.same({}, missionApi.Triggers.anyDifficulty.settings.difficulties)
	end)

	it("resolves action parameters, including a wrapped loadout", function()
		local missionApi = loadMission(wrappedMission(), HARD)
		assert.are.equal("INCOMING", missionApi.Actions.announce.parameters.messageKey)
		assert.are.equal(2, #missionApi.Actions.spawnBots.parameters.unitLoadout)
	end)

	it("resolves objective fields and copies the amount onto the condition records", function()
		local missionApi = loadMission(wrappedMission(), HARD)

		assert.are.equal(4, missionApi.Objectives.surviveTimer.amount)
		assert.are.equal(4, missionApi.Objectives.surviveTimer.target)
		assert.are.equal(6, missionApi.Objectives.killBots.target)
		assert.are.equal("s2", missionApi.Objectives.killBots.nextStage)
		assert.are.equal(2, missionApi.Objectives.holdBots.target)

		---@type { count: number, settings: { repeating: boolean }, parameters: { seconds: number } }
		local surviveRecord = missionApi.Triggers.__objective_surviveTimer
		assert.are.equal(4, surviveRecord.count)
		assert.is_falsy(surviveRecord.settings.repeating)
		assert.are.equal(45, surviveRecord.parameters.seconds)
		assert.are.equal(6, missionApi.Triggers.__objective_killBots.count)
		assert.are.equal(2, missionApi.Triggers.__objective_holdBots.atLeast)
		assert.is_nil(missionApi.Triggers.__objective_holdBots.count)
	end)

	it("resolves the same mission differently on another difficulty", function()
		local missionApi = loadMission(wrappedMission(), EASY)
		assert.are.equal(120, missionApi.Triggers.wave.parameters.seconds)
		assert.are.equal(1, #missionApi.Actions.spawnBots.parameters.unitLoadout)
		assert.are.equal(2, missionApi.Objectives.surviveTimer.target)
		assert.are.equal(2, missionApi.Triggers.__objective_surviveTimer.count)
		assert.are.equal("s1", missionApi.Objectives.killBots.nextStage)
		assert.are.equal(1, missionApi.Triggers.__objective_holdBots.atLeast)
	end)

	it("validates and resolves the difficulties_test dev mission cleanly", function()
		local mission = VFS.Include("singleplayer/mission-api-tests/difficulties_test.lua")

		local missionApi = loadMission(mission, HARD)

		assert.are.same({}, logged)
		assert.are.equal(8, missionApi.Triggers.spawnWave.parameters.seconds)
		assert.are.equal(4, missionApi.Objectives.surviveWaves.amount)
		assert.are.same({ MEDIUM, HARD }, missionApi.Triggers.hardOnly.settings.difficulties)
	end)

	it("aborts on an invalid difficulty value even when the played difficulty is valid", function()
		local _, result = loadMission({
			Triggers = {
				wave = {
					type = eventTypes.TimeElapsed,
					parameters = { seconds = { difficulties = { Easy = 120, Hard = "soon" } } },
					actions = { "announce" },
				},
			},
			Actions = {
				announce = {
					type = actionTypes.SendMessage,
					parameters = { messageKey = "incoming" },
				},
			},
		}, EASY)
		assert.is_false(result.ok)
	end)
end)
