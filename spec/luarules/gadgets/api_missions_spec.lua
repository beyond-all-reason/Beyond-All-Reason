---@diagnostic disable: undefined-field

local GADGET_PATH = "luarules/gadgets/api_missions.lua"
local ENTRY_POINT = "singleplayer/test_mission.lua"

local function noop() end

-- Runs the gadget file against stand-ins for its includes. options.crash names the include
-- whose processing raises, and options.refuse makes validation fail.
local function loadGadget(options, world)
	local function crashes(name)
		if options.crash == name then
			error("boom in " .. name)
		end
	end

	local includes = {
		["luarules/mission_api/game_setup.lua"] = { entryPoint = ENTRY_POINT, difficulty = "Normal" },
		[ENTRY_POINT] = function()
			crashes("mission")
			return { InitialStage = "s1", Stages = { s1 = {} } }
		end,
		["luarules/mission_api/validation.lua"] = {
			ValidateMission = function()
				if options.refuse then
					return { ok = false, errors = { "an error" } }
				end
				return { ok = true, errors = {} }
			end,
			LogResult = noop,
		},
		["luarules/mission_api/stages_loader.lua"] = {
			ProcessRawStages = function(stages)
				return stages
			end,
		},
		["luarules/mission_api/objectives_loader.lua"] = {
			ProcessRawObjectives = function()
				return {}
			end,
		},
		["luarules/mission_api/actions_loader.lua"] = { LoadActionDefinitions = noop, ProcessRawActions = noop },
		["luarules/mission_api/triggers_loader.lua"] = { LoadTriggerDefinitions = noop, ProcessRawTriggers = noop },
		["luarules/mission_api/schema_utils.lua"] = { CollateSchemas = noop },
		["luarules/mission_api/difficulty.lua"] = {
			FromName = noop,
			ResolveTriggers = noop,
			ResolveActions = noop,
			ResolveObjectives = noop,
			ResolveCutscenes = noop,
		},
		["luarules/mission_api/variables.lua"] = { ResolveReferences = noop },
		["luarules/mission_api/parameter_processing.lua"] = {
			ProcessValue = noop,
			ProcessActionParameters = function()
				crashes("parameters")
			end,
			ProcessTriggerParameters = noop,
		},
		["luarules/mission_api/loadout.lua"] = function()
			crashes("module")
			return {
				SpawnUnitLoadout = function()
					world.spawned = true
				end,
				SpawnFeatureLoadout = noop,
			}
		end,
		["luarules/mission_api/objectives.lua"] = { ActivateStage = noop },
		["luarules/mission_api/sounds.lua"] = { ProcessSoundQueue = noop },
	}

	local env = setmetatable({
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
			RemoveGadget = function()
				world.removed = true
			end,
		},
		GG = {},
		LOG = { ERROR = "error" },
		Spring = {
			Log = function(section, level, text)
				world.logged[#world.logged + 1] = { section = section, level = level, text = text }
			end,
			GameOver = function()
				world.gameOver = true
			end,
			Echo = function(text)
				world.echoed[#world.echoed + 1] = text
			end,
		},
		VFS = {
			Include = function(path)
				local include = includes[path]
				if type(include) == "function" then
					return include()
				end
				return include or {}
			end,
		},
	}, { __index = _G })

	local chunk = assert(loadfile(GADGET_PATH))
	setfenv(chunk, env)
	chunk()

	return env.gadget, env
end

describe("api_missions load guard", function()
	local world

	local function start(options)
		world = { logged = {}, echoed = {} }
		local gadget, env = loadGadget(options or {}, world)
		gadget:Initialize()
		gadget:GamePreload()
		gadget:GameFrame(1)
		return env
	end

	local function assertEndedWith(env, errorText)
		assert.is_nil(env.GG.MissionAPI)
		assert.are.equal(1, #world.logged)
		assert.is_truthy(world.logged[1].text:find("[Mission API] ", 1, true))
		assert.is_truthy(world.logged[1].text:find(errorText, 1, true))
		assert.is_nil(world.spawned)
		assert.is_true(world.gameOver)
		assert.is_true(world.removed)
		assert.are.equal(1, #world.echoed)
		assert.is_truthy(
			world.echoed[1]:find("[Mission API] Mission not loaded: error in " .. ENTRY_POINT .. ": ", 1, true)
		)
		assert.is_truthy(world.echoed[1]:find(errorText, 1, true))
		assert.is_nil(world.echoed[1]:find("\n", 1, true))
	end

	it("loads and starts a valid mission", function()
		local env = start()

		assert.is_not_nil(env.GG.MissionAPI)
		assert.are.equal(0, #world.logged)
		assert.is_true(world.spawned)
		assert.is_nil(world.gameOver)
		assert.is_nil(world.removed)
	end)

	it("ends a mission whose file raises, instead of raising itself", function()
		assertEndedWith(start({ crash = "mission" }), "boom in mission")
	end)

	it("ends a mission whose processing failed after validation passed", function()
		assertEndedWith(start({ crash = "parameters" }), "boom in parameters")
	end)

	it("ends a mission when a Mission API module fails to load", function()
		assertEndedWith(start({ crash = "module" }), "boom in module")
	end)

	it("leaves a refused mission to the validation message", function()
		local env = start({ refuse = true })

		assert.is_nil(env.GG.MissionAPI)
		assert.are.equal(0, #world.logged)
		assert.is_true(world.gameOver)
		assert.are.equal(
			"[Mission API] Mission not loaded: 1 validation errors in " .. ENTRY_POINT .. " (see infolog)",
			world.echoed[1]
		)
	end)
end)
