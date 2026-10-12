---@diagnostic disable: undefined-field

local GADGET_PATH = "luarules/gadgets/api_game_pause.lua"

local GAME_SPEED = 30
local CATCH_UP_FRAMES = 11 * GAME_SPEED
local CONTROLLER_ID = 0
local OTHER_PLAYER_ID = 1

-- Runs the gadget file against the world table, which the stubs read from and record into.
local function loadGadget(synced, world)
	local env
	env = {
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return synced
			end,
			AddSyncAction = function(_, name, callback)
				world.syncActions[name] = callback
			end,
			RemoveSyncAction = function(_, name)
				world.syncActions[name] = nil
			end,
		},
		GG = {},
		Game = { gameSpeed = GAME_SPEED },
		Json = Json,
		-- The pause controller include has to see this env's Spring.
		VFS = {
			Include = function(path)
				return _G.VFS.Include(path, env)
			end,
		},
		Script = {
			LuaUI = setmetatable({}, {
				__call = function(_, name)
					return world.luaUI[name] ~= nil
				end,
				__index = function(_, name)
					return world.luaUI[name]
				end,
			}),
		},
		SendToUnsynced = function(...)
			world.sent[#world.sent + 1] = { ... }
		end,
		Spring = {
			GetPlayerList = function()
				return { world.controllerID }
			end,
			GetPlayerInfo = function()
				return "player", true, false
			end,
			GetMyPlayerID = function()
				return world.myPlayerID
			end,
			GetGameFrame = function()
				return world.gameFrame
			end,
			GetGameSpeed = function()
				return 1, 1, world.paused
			end,
			GetGameRulesParam = function(name)
				return world.rulesParams[name]
			end,
			SetGameRulesParam = function(name, value)
				world.rulesParams[name] = value
			end,
			SendCommands = function(command)
				world.commands[#world.commands + 1] = command
			end,
		},
	}
	setmetatable(env, { __index = _G })

	local chunk = assert(loadfile(GADGET_PATH))
	setfenv(chunk, env)
	chunk()

	return env.gadget, env
end

describe("api_game_pause", function()
	describe("synced", function()
		local world, gadget, gamePause

		before_each(function()
			world = {
				controllerID = CONTROLLER_ID,
				rulesParams = {},
				sent = {},
				syncActions = {},
			}
			local env
			gadget, env = loadGadget(true, world)
			gadget:Initialize()
			gamePause = env.GG.GamePause
		end)

		it("pauses once for the first source and not again for a second", function()
			gamePause.Pause("first")
			assert.equals(1, world.rulesParams.gamePaused)
			assert.same({ { "GamePause", true } }, world.sent)

			gamePause.Pause("second")
			assert.equals(1, world.rulesParams.gamePaused)
			assert.same({ { "GamePause", true } }, world.sent)
		end)

		it("unpauses when the last source leaves and ignores unknown sources", function()
			gamePause.Pause("first")
			gamePause.Pause("second")

			gamePause.Unpause("unknown")
			gamePause.Unpause("first")
			assert.equals(1, world.rulesParams.gamePaused)
			assert.same({ { "GamePause", true } }, world.sent)

			gamePause.Unpause("second")
			assert.equals(0, world.rulesParams.gamePaused)
			assert.same({ { "GamePause", true }, { "GamePause", false } }, world.sent)

			gamePause.Unpause("unknown")
			assert.equals(0, world.rulesParams.gamePaused)
			assert.equals(2, #world.sent)
		end)

		it("publishes only the sources paused with publish", function()
			assert.same({}, Json.decode(world.rulesParams.gamePausePublished))

			gamePause.Pause("zeta", true)
			gamePause.Pause("hidden")
			gamePause.Pause("alpha", true)
			gamePause.Pause("other", false)
			assert.same({ "alpha", "zeta" }, Json.decode(world.rulesParams.gamePausePublished))

			gamePause.Unpause("zeta")
			assert.same({ "alpha" }, Json.decode(world.rulesParams.gamePausePublished))
		end)

		it("unpauses a published source only for the pause controller's message", function()
			gamePause.Pause("published", true)
			gamePause.Pause("unpublished")

			assert.is_true(gadget:RecvLuaMsg("GamePauseUnpause:published", OTHER_PLAYER_ID))
			assert.same({ "published" }, Json.decode(world.rulesParams.gamePausePublished))

			assert.is_true(gadget:RecvLuaMsg("GamePauseUnpause:unpublished", CONTROLLER_ID))
			assert.is_true(gadget:RecvLuaMsg("GamePauseUnpause:published", CONTROLLER_ID))
			assert.same({}, Json.decode(world.rulesParams.gamePausePublished))
			assert.equals(1, world.rulesParams.gamePaused)

			gamePause.Unpause("unpublished")
			assert.equals(0, world.rulesParams.gamePaused)

			assert.is_nil(gadget:RecvLuaMsg("SomethingElse:published", CONTROLLER_ID))
		end)

		it("forwards a widgets unpause only while a source holds the pause", function()
			assert.is_true(gadget:RecvLuaMsg("GamePauseWidgetsUnpaused", CONTROLLER_ID))
			assert.same({}, world.sent)

			gamePause.Pause("first")
			assert.is_true(gadget:RecvLuaMsg("GamePauseWidgetsUnpaused", CONTROLLER_ID))
			assert.same({ { "GamePause", true }, { "GamePauseWidgetsUnpaused" } }, world.sent)
		end)
	end)

	describe("unsynced", function()
		local world, gadget

		-- The sync actions receive their own name first, as the gadget handler passes it.
		local function gadgetsPause()
			world.syncActions.GamePause("GamePause", true)
		end
		local function gadgetsUnpause()
			world.syncActions.GamePause("GamePause", false)
		end
		local function widgetsUnpaused()
			world.syncActions.GamePauseWidgetsUnpaused("GamePauseWidgetsUnpaused")
		end

		before_each(function()
			world = {
				controllerID = CONTROLLER_ID,
				myPlayerID = CONTROLLER_ID,
				paused = false,
				gameFrame = 0,
				luaUI = {},
				rulesParams = { gamePaused = 0 },
				commands = {},
				syncActions = {},
			}
			gadget = loadGadget(false, world)
			gadget:Initialize()
		end)

		it("sends a pause from the pause controller when the gadgets pause", function()
			gadgetsPause()

			assert.same({ "pause 1" }, world.commands)
		end)

		it("sends no pause from a client that is not the pause controller", function()
			world.myPlayerID = OTHER_PLAYER_ID

			gadgetsPause()

			assert.same({}, world.commands)
		end)

		it("pauses again when a player unpauses during a gadget pause", function()
			gadgetsPause()
			world.paused = true
			gadget:GamePaused(CONTROLLER_ID, true)

			world.paused = false
			gadget:GamePaused(OTHER_PLAYER_ID, false)

			assert.same({ "pause 1", "pause 1" }, world.commands)
		end)

		it("resumes a game that was running before the gadgets paused it", function()
			gadgetsPause()
			world.paused = true
			gadget:GamePaused(CONTROLLER_ID, true)

			gadgetsUnpause()

			assert.same({ "pause 1", "pause 0" }, world.commands)
		end)

		it("leaves a player's earlier pause in place when the gadgets unpause", function()
			world.paused = true

			gadgetsPause()
			gadgetsUnpause()

			assert.same({}, world.commands)
		end)

		it("resumes after a player's earlier pause once someone unpaused during the gadget pause", function()
			world.paused = true
			gadgetsPause()

			world.paused = false
			gadget:GamePaused(OTHER_PLAYER_ID, false)
			world.paused = true
			gadget:GamePaused(CONTROLLER_ID, true)
			gadgetsUnpause()

			assert.same({ "pause 1", "pause 0" }, world.commands)
		end)

		it("resumes after a player's earlier pause once widgets report they unpaused", function()
			world.paused = true
			gadgetsPause()

			widgetsUnpaused()
			gadgetsUnpause()

			assert.same({ "pause 0" }, world.commands)
		end)

		it("does not take its own pending resume for a player's pause", function()
			gadgetsPause()
			world.paused = true
			gadget:GamePaused(CONTROLLER_ID, true)
			gadgetsUnpause()

			gadgetsPause()
			gadgetsUnpause()

			-- Its resume is still in flight, so pausing again needs a new pause.
			assert.same({ "pause 1", "pause 0", "pause 1", "pause 0" }, world.commands)
		end)

		it("resumes when the gadgets unpause before their pause reaches the server", function()
			gadgetsPause()
			gadgetsUnpause()
			world.paused = true
			gadget:GamePaused(CONTROLLER_ID, true)

			assert.same({ "pause 1", "pause 0" }, world.commands)

			world.paused = false
			gadget:GamePaused(CONTROLLER_ID, false)
			gadget:PlayerChanged()

			assert.same({ "pause 1", "pause 0" }, world.commands)
		end)

		it("sends no duplicate resume when players change while it is in flight", function()
			gadgetsPause()
			world.paused = true
			gadget:GamePaused(CONTROLLER_ID, true)
			gadgetsUnpause()

			gadget:PlayerChanged()

			assert.same({ "pause 1", "pause 0" }, world.commands)
		end)

		it("leaves the resume to widgets that handle GameUnpausing", function()
			world.luaUI.GameUnpausing = function()
				return true
			end
			gadgetsPause()
			world.paused = true
			gadget:GamePaused(CONTROLLER_ID, true)

			gadgetsUnpause()

			assert.same({ "pause 1" }, world.commands)
		end)

		it("holds its pauses while catching up and sends them once it is live", function()
			local serverFrame = 1000
			world.gameFrame = 100
			gadget:GameProgress(serverFrame)

			gadgetsPause()
			gadget:GameFrame(serverFrame - CATCH_UP_FRAMES - 1)
			assert.same({}, world.commands)

			gadget:GameFrame(serverFrame - CATCH_UP_FRAMES)
			gadget:GameFrame(serverFrame - CATCH_UP_FRAMES + 1)
			assert.same({ "pause 1" }, world.commands)
		end)

		it("sends the held pause when it becomes the pause controller", function()
			world.myPlayerID = OTHER_PLAYER_ID
			gadgetsPause()
			assert.same({}, world.commands)

			world.controllerID = OTHER_PLAYER_ID
			gadget:PlayerChanged()

			assert.same({ "pause 1" }, world.commands)
		end)

		it("sends a pending resume when it becomes the pause controller", function()
			world.myPlayerID = OTHER_PLAYER_ID
			gadgetsPause()
			world.paused = true
			gadgetsUnpause()
			assert.same({}, world.commands)

			world.controllerID = OTHER_PLAYER_ID
			gadget:PlayerChanged()

			assert.same({ "pause 0" }, world.commands)
		end)
	end)
end)
