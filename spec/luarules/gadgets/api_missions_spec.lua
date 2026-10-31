---@diagnostic disable: undefined-field

local GADGET_PATH = "luarules/gadgets/api_missions.lua"
local REPORT_PATH = "luarules/mission_api/validation/report.lua"
local ENTRY_POINT = "singleplayer/test_mission.lua"

local function readFile(path)
	local file = assert(io.open(path, "rb"))
	local source = file:read("*a")
	file:close()
	return source
end

local function noop() end

-- Runs the gadget file against stand-ins for its includes. options.crash names the code that raises,
-- options.refuse makes validation fail, options.missionSource replaces the mission file with Lua source,
-- and options.noDebug empties the debug library, as synced Lua does outside dev mode.
local function loadGadget(options, world)
	local function crashes(name)
		if options.crash == name then
			error("boom in " .. name)
		end
	end

	local includes = {
		-- The real report, so the logged line is the one a game writes.
		[REPORT_PATH] = readFile(REPORT_PATH),
		["luarules/mission_api/game_setup.lua"] = { entryPoint = ENTRY_POINT, difficulty = "Normal" },
		[ENTRY_POINT] = options.missionSource or function()
			crashes("mission")
			return { InitialStage = "s1", Stages = { s1 = {} } }
		end,
		["luarules/mission_api/validation.lua"] = {
			ValidateMission = function()
				crashes("validation")
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
		["luarules/mission_api/triggers_loader.lua"] = {
			LoadTriggerDefinitions = function()
				crashes("definitions")
			end,
			ProcessRawTriggers = noop,
		},
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
		["luarules/mission_api/area_tracking.lua"] = { UpdateTrackedAreas = noop },
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
	}, { __index = _G })

	if options.noDebug then
		env.debug = {}
	end

	-- Like the engine's VFS.Include: the file runs in its own pcall, and an error comes back as a new message
	-- naming the file, without the stack inside it. Paths not listed stand in as empty modules.
	env.VFS = {
		Include = function(path)
			local include = includes[path]
			if type(include) == "string" then
				local chunk, syntaxError = loadstring(include, path)
				if not chunk then
					error(("[LuaVFS::Include(synced=true)][loadbuf] file=%s error=3 (%s)"):format(path, syntaxError), 0)
				end
				include = setfenv(chunk, env)
			end
			if type(include) ~= "function" then
				return include or {}
			end
			local ok, result = pcall(include)
			if not ok then
				error(("[LuaVFS::Include(synced=true)][pcall] file=%s error=2 (%s)"):format(path, tostring(result)), 0)
			end
			return result
		end,
	}

	local chunk = assert(loadfile(GADGET_PATH))
	setfenv(chunk, env)
	chunk()

	return env.gadget, env
end

describe("api_missions load guard", function()
	---@type table
	local world

	local function start(options)
		world = { logged = {}, echoed = {} }
		---@type table
		local gadget, env = loadGadget(options or {}, world)
		gadget:Initialize()
		gadget:GamePreload()
		gadget:GameFrame(1)
		return env
	end

	-- The error is logged in full and echoed as one line that names the step it came from.
	local function assertEndedWith(env, step, errorText)
		local reason = "Lua error while " .. step .. ": "
		assert.is_nil(env.GG.MissionAPI)
		assert.are.equal(1, #world.logged)
		assert.are.equal("MissionAPI", world.logged[1].section)
		assert.are.equal(1, world.logged[1].text:find("[Mission API] " .. reason, 1, true))
		assert.is_truthy(world.logged[1].text:find(errorText, 1, true))
		assert.is_nil(world.spawned)
		assert.is_true(world.gameOver)
		assert.is_true(world.removed)
		assert.are.equal(1, #world.echoed)
		assert.are.equal(1, world.echoed[1]:find("[Mission API] Mission not loaded: " .. reason, 1, true))
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

	it("blames the mission file when it raises while loading", function()
		assertEndedWith(start({ crash = "mission" }), "loading " .. ENTRY_POINT, "boom in mission")
	end)

	it("blames the mission file for a syntax error, with its line", function()
		local env = start({ missionSource = "return {" })

		assertEndedWith(env, "loading " .. ENTRY_POINT, '[string "' .. ENTRY_POINT .. '"]:1:')
	end)

	it("names the Mission API module that fails to load by its path, not the mission", function()
		local env = start({ crash = "module" })

		assertEndedWith(env, "loading luarules/mission_api/loadout.lua", "boom in module")
		assert.is_nil(world.echoed[1]:find(ENTRY_POINT, 1, true))
	end)

	it("names the step when the Mission API raises outside an include", function()
		assertEndedWith(start({ crash = "definitions" }), "loading the Mission API", "boom in definitions")
	end)

	-- A crash inside the validators never gets here: ValidateMission catches it and reports a validation error.
	it("names validating as the step when the validation entry point itself raises", function()
		local env = start({ crash = "validation" })

		assertEndedWith(env, "validating " .. ENTRY_POINT, "boom in validation")
		assert.is_nil(world.echoed[1]:find("validation errors", 1, true))
	end)

	it("blames processing the mission when it fails after validation passed", function()
		assertEndedWith(start({ crash = "parameters" }), "processing " .. ENTRY_POINT, "boom in parameters")
	end)

	it("logs the error either way, and a traceback only in dev mode", function()
		start({ crash = "parameters" })
		assert.is_truthy(world.logged[1].text:find("stack traceback", 1, true))

		local env = start({ crash = "parameters", noDebug = true })
		assertEndedWith(env, "processing " .. ENTRY_POINT, "boom in parameters")
		assert.is_nil(world.logged[1].text:find("stack traceback", 1, true))
	end)

	it("leaves a refused mission to the validation message, echoed once", function()
		local env = start({ refuse = true })

		assert.is_nil(env.GG.MissionAPI)
		assert.are.equal(0, #world.logged)
		assert.is_true(world.gameOver)
		assert.are.equal(1, #world.echoed)
		assert.are.equal(
			"[Mission API] Mission not loaded: 1 validation errors in " .. ENTRY_POINT .. " (see infolog)",
			world.echoed[1]
		)
	end)
end)
