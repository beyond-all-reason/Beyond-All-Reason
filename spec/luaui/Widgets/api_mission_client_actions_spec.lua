require("spec_helper")

local SpringUnsyncedBuilder = VFS.Include("spec/builders/spring_unsynced_builder.lua")

local WIDGET_PATH = "luaui/Widgets/api_mission_client_actions.lua"

describe("luaui.Widgets.api_mission_client_actions", function()
	local myTeamID
	local spectating
	---@type table[]
	local calls

	local function spy(name)
		return function(...)
			calls[#calls + 1] = { name, ... }
		end
	end

	local function loadWidget()
		local loaded = SpringUnsyncedBuilder.new()
			:WithSpringFn("GetMyTeamID", function()
				return myTeamID
			end)
			:WithSpringFn("GetSpectatingState", function()
				return spectating
			end)
			:LoadWidget(WIDGET_PATH)
		loaded.WG.cinematicCamera = {
			Play = spy("Play"),
			Follow = spy("Follow"),
			Orbit = spy("Orbit"),
			Shake = spy("Shake"),
			Save = spy("Save"),
			Restore = spy("Restore"),
			Stop = spy("Stop"),
		}
		loaded.WG.playerInputLock = { Lock = spy("Lock"), Unlock = spy("Unlock") }
		return loaded
	end

	before_each(function()
		myTeamID = 0
		spectating = false
		calls = {}
	end)

	it("hands each kind to its service", function()
		local loaded = loadWidget()
		local act = loaded.env.MissionClientAction
		local keyframes = { { position = { x = 0, y = 0, z = 0 } } }

		act({ kind = "play", params = { keyframes = keyframes, onEnd = "hold" } })
		act({ kind = "follow", params = { target = { unitIDs = { 1 } } } })
		act({ kind = "orbit", params = { target = { x = 0, y = 0, z = 0 } } })
		act({ kind = "shake", params = { magnitude = 10 } })
		act({ kind = "save", params = { slot = "intro" } })
		act({ kind = "restore", params = { slot = "intro", duration = 2, easing = "linear" } })
		act({ kind = "stop", params = {} })
		act({ kind = "lock", params = {} })
		act({ kind = "unlock", params = {} })

		assert.are.same({
			{ "Play", { keyframes = keyframes, onEnd = "hold" } },
			{ "Follow", { target = { unitIDs = { 1 } } } },
			{ "Orbit", { target = { x = 0, y = 0, z = 0 } } },
			{ "Shake", { magnitude = 10 } },
			{ "Save", "intro" },
			{ "Restore", "intro", 2, "linear" },
			{ "Stop" },
			{ "Lock" },
			{ "Unlock" },
		}, calls)
	end)

	it("acts only for the addressed team, and never as a spectator", function()
		local loaded = loadWidget()
		loaded.env.MissionClientAction({ kind = "stop", teamID = 1, params = {} })
		assert.are.same({}, calls)

		loaded.env.MissionClientAction({ kind = "stop", teamID = 0, params = {} })
		assert.are.same({ { "Stop" } }, calls)

		spectating = true
		loaded.env.MissionClientAction({ kind = "stop", teamID = 0, params = {} })
		assert.are.same({ { "Stop" } }, calls)
	end)

	it("ignores a command when its service widget is missing", function()
		local loaded = loadWidget()
		loaded.WG.cinematicCamera = nil
		loaded.WG.playerInputLock = nil
		loaded.env.MissionClientAction({ kind = "play", params = {} })
		loaded.env.MissionClientAction({ kind = "lock", params = {} })
		loaded.env.MissionClientAction({ kind = "nonsense", params = {} })
		assert.are.same({}, calls)
	end)

	it("lets go of its global on shutdown", function()
		local loaded = loadWidget()
		loaded.env.widget:Shutdown()
		assert.is_nil(loaded.env.MissionClientAction)
	end)
end)
