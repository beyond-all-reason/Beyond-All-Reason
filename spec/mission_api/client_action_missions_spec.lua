require("spec_helper")

local RegisterMissionApiModules = require("mission_api.spec_helper")

-- The camera and input-lock test missions, run through the loaders and validation the way
-- loadMission() in api_missions.lua does, so an authoring slip shows up here and not in game.

GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")
RegisterMissionApiModules()
GG["MissionAPI"].ActionDefinitions = VFS.Include("luarules/mission_api/actions_loader.lua").LoadActionDefinitions()
GG["MissionAPI"].TriggerDefinitions = VFS.Include("luarules/mission_api/triggers_loader.lua").LoadTriggerDefinitions()

local validation = VFS.Include("luarules/mission_api/validation.lua")
local stagesController = VFS.Include("luarules/mission_api/stages_loader.lua")
local objectivesController = VFS.Include("luarules/mission_api/objectives_loader.lua")
local triggersController = VFS.Include("luarules/mission_api/triggers_loader.lua")
local actionsController = VFS.Include("luarules/mission_api/actions_loader.lua")

local actionDefinitions = GG["MissionAPI"].ActionDefinitions
local triggerDefinitions = GG["MissionAPI"].TriggerDefinitions
local originalLog = Spring.Log

local MISSIONS = {
	"singleplayer/mission-api-tests/camera_test.lua",
	"singleplayer/mission-api-tests/player_input_lock_test.lua",
}

-- The order validator keys a table by these, so every one of them needs an id.
local COMMAND_NAMES = {
	"STOP",
	"INSERT",
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
	"INTERNAL",
}

describe("mission-api-tests client action missions", function()
	local logged ---@type string[]
	local savedCMD, savedGameCMD

	before_each(function()
		logged = {}
		Spring.Log = function(_, _, msg)
			logged[#logged + 1] = msg
		end
		_G.UnitDefNames = { armstump = { id = 1 }, armpw = { id = 2 } } ---@diagnostic disable-line: global-in-non-module
		_G.FeatureDefNames = {} ---@diagnostic disable-line: global-in-non-module
		_G.WeaponDefNames = { armsilo_nuclear_missile = {} } ---@diagnostic disable-line: global-in-non-module
		savedCMD, savedGameCMD = _G.CMD, _G.GameCMD
		local commands =
			{ OPT_META = 4, OPT_INTERNAL = 8, OPT_RIGHT = 16, OPT_SHIFT = 32, OPT_CTRL = 64, OPT_ALT = 128 }
		for i, name in ipairs(COMMAND_NAMES) do
			commands[name] = i
		end
		_G.CMD = commands ---@diagnostic disable-line: global-in-non-module
		_G.GameCMD = { AREA_ATTACK_GROUND = #COMMAND_NAMES + 1 } ---@diagnostic disable-line: global-in-non-module
	end)

	after_each(function()
		Spring.Log = originalLog
		_G.CMD, _G.GameCMD = savedCMD, savedGameCMD ---@diagnostic disable-line: global-in-non-module
	end)

	local function loadMission(mission)
		GG["MissionAPI"] = {
			Difficulty = 2,
			Modules = GG["MissionAPI"].Modules,
			ActionDefinitions = actionDefinitions,
			TriggerDefinitions = triggerDefinitions,
			ManagedObjectives = {},
			ObjectiveTriggers = {},
			ObjectiveStages = {},
		}
		local rawTriggers = mission.Triggers or {}
		local rawActions = mission.Actions or {}
		GG["MissionAPI"].Stages = stagesController.ProcessRawStages(mission.Stages or {})
		GG["MissionAPI"].Objectives =
			objectivesController.ProcessRawObjectives(mission.Objectives or {}, rawTriggers, rawActions, mission.Stages)
		GG["MissionAPI"].Triggers = triggersController.ProcessRawTriggers(rawTriggers)
		GG["MissionAPI"].Actions = actionsController.ProcessRawActions(rawActions)

		validation.ValidateTriggers(GG["MissionAPI"].Triggers, rawActions)
		validation.ValidateActions(GG["MissionAPI"].Actions)
		validation.ValidateReferences()
	end

	for _, path in ipairs(MISSIONS) do
		it(path .. " validates without errors or warnings", function()
			GG["MissionAPI"].ActionDefinitions = actionDefinitions
			GG["MissionAPI"].TriggerDefinitions = triggerDefinitions
			local mission = VFS.Include(path)

			loadMission(mission)

			assert.are.same({}, logged)
			assert.is_nil(GG["MissionAPI"].HasValidationErrors)
		end)
	end
end)
