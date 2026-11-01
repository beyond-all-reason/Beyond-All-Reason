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
GG["MissionAPI"].TriggerDefinitions = MissionSpecEnv.include(env, "luarules/mission_api/triggers_loader.lua")
	.LoadTriggerDefinitions()

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
local triggersController = MissionSpecEnv.include(env, "luarules/mission_api/triggers_loader.lua")
local actionsController = MissionSpecEnv.include(env, "luarules/mission_api/actions_loader.lua")
local difficulty = GG["MissionAPI"].Modules.Difficulty

local actionDefinitions = GG["MissionAPI"].ActionDefinitions
local triggerDefinitions = GG["MissionAPI"].TriggerDefinitions
local triggerTypes = triggerDefinitions.Types
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
			-- The named teams and alliances of tools/StartScripts/startscript_mission_api_test_quicksilver.txt.
			Teams = { player = 0, enemy = 1, [0] = "player", [1] = "enemy" },
			Alliances = { players = 0, enemies = 1, [0] = "players", [1] = "enemies" },
			Modules = GG["MissionAPI"].Modules,
			ActionDefinitions = actionDefinitions,
			TriggerDefinitions = triggerDefinitions,
			ManagedObjectives = {},
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
				s1 = { objectives = { "surviveTimer", "killBots" } },
				s2 = { objectives = { "surviveTimer" } },
			},
			Objectives = {
				surviveTimer = {
					textKey = "survive",
					amount = { difficulties = { Easy = 2, Hard = 4 } },
					trigger = {
						type = triggerTypes.TimeElapsed,
						parameters = { seconds = { difficulties = { Easy = 90, Hard = 45 } } },
					},
				},
				killBots = {
					textKey = "kill",
					amount = { difficulties = { Easy = 3, Hard = 6 } },
					nextStage = { difficulties = { Easy = "s1", Hard = "s2" } },
					trigger = {
						type = triggerTypes.TotalUnitsKilled,
						parameters = { teamName = "player", unitName = "bot" },
					},
				},
			},
			Triggers = {
				wave = {
					type = triggerTypes.TimeElapsed,
					parameters = { seconds = { difficulties = { Easy = 120, Hard = 60 } } },
					settings = { difficulties = { "Medium", "Hard" } },
					actions = { "spawnBots", "announce" },
				},
				anyDifficulty = {
					type = triggerTypes.TimeElapsed,
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
								Easy = {
									{ unitDefName = "armwar", x = 0, z = 0, teamName = "player", unitName = "bot" },
								},
								Hard = {
									{ unitDefName = "armwar", x = 0, z = 0, teamName = "player", unitName = "bot" },
									{ unitDefName = "armwar", x = 10, z = 0, teamName = "player", unitName = "bot" },
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

	it("resolves objective fields, the synthesized trigger, and managed metadata", function()
		local missionApi = loadMission(wrappedMission(), HARD)

		assert.are.equal(4, missionApi.Objectives.surviveTimer.amount)
		assert.are.equal(6, missionApi.Objectives.killBots.amount)
		assert.are.equal("s2", missionApi.Objectives.killBots.nextStage)

		---@type { settings: { repeating: boolean, maxRepeats: number }, parameters: { seconds: number } }
		local synthesized = missionApi.Triggers.__objective_surviveTimer
		assert.is_true(synthesized.settings.repeating)
		assert.are.equal(3, synthesized.settings.maxRepeats)
		assert.are.equal(45, synthesized.parameters.seconds)

		---@type { amount: number, nextStage: string, parameters: table }
		local metadata = missionApi.ManagedObjectives[triggerTypes.TotalUnitsKilled][1]
		assert.are.equal(6, metadata.amount)
		assert.are.equal("s2", metadata.nextStage)
		assert.are.equal(missionApi.Objectives.killBots.trigger.parameters, metadata.parameters)
	end)

	it("resolves the same mission differently on another difficulty", function()
		local missionApi = loadMission(wrappedMission(), EASY)
		assert.are.equal(120, missionApi.Triggers.wave.parameters.seconds)
		assert.are.equal(1, #missionApi.Actions.spawnBots.parameters.unitLoadout)
		assert.are.equal(2, missionApi.Objectives.surviveTimer.amount)
		assert.are.equal(1, missionApi.Triggers.__objective_surviveTimer.settings.maxRepeats)
		---@type { nextStage: string }
		local metadata = missionApi.ManagedObjectives[triggerTypes.TotalUnitsKilled][1]
		assert.are.equal("s1", metadata.nextStage)
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
					type = triggerTypes.TimeElapsed,
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
