require("spec_helper")

local SpringUnsyncedBuilder = VFS.Include("spec/builders/spring_unsynced_builder.lua")

local WIDGET_PATH = "luaui/Widgets/api_mission_camera.lua"

describe("luaui.Widgets.api_mission_camera", function()
	---@type table[]
	local calls

	local function spy(name)
		return function(...)
			calls[#calls + 1] = { name, ... }
		end
	end

	local function loadWidget()
		local loaded = SpringUnsyncedBuilder.new():LoadWidget(WIDGET_PATH)
		loaded.WG.cinematicCamera = {
			Play = spy("Play"),
			Follow = spy("Follow"),
			Orbit = spy("Orbit"),
			Shake = spy("Shake"),
			Save = spy("Save"),
			Restore = spy("Restore"),
			Stop = spy("Stop"),
		}
		return loaded
	end

	before_each(function()
		calls = {}
	end)

	it("passes each camera action to the Cinematic Camera API", function()
		local env = loadWidget().env
		local keyframes = { { position = { x = 0, y = 0, z = 0 } } }

		env.MissionCameraPlay({ keyframes = keyframes, onEnd = "hold" })
		env.MissionCameraFollow({ target = { unitIDs = { 1 } } })
		env.MissionCameraOrbit({ target = { x = 0, y = 0, z = 0 } })
		env.MissionCameraShake({ magnitude = 10 })
		env.MissionCameraSave({ slot = "intro" })
		env.MissionCameraRestore({ slot = "intro", duration = 2, easing = "linear" })
		env.MissionCameraStop()

		assert.are.same({
			{ "Play", { keyframes = keyframes, onEnd = "hold" } },
			{ "Follow", { target = { unitIDs = { 1 } } } },
			{ "Orbit", { target = { x = 0, y = 0, z = 0 } } },
			{ "Shake", { magnitude = 10 } },
			{ "Save", "intro" },
			{ "Restore", "intro", 2, "linear" },
			{ "Stop" },
		}, calls)
	end)

	it("does nothing without the Cinematic Camera API", function()
		local loaded = loadWidget()
		loaded.WG.cinematicCamera = nil
		loaded.env.MissionCameraPlay({})
		loaded.env.MissionCameraStop()
		assert.are.same({}, calls)
	end)

	it("removes its globals on shutdown", function()
		local loaded = loadWidget()
		loaded.env.widget:Shutdown()
		assert.is_nil(loaded.env.MissionCameraPlay)
		assert.is_nil(loaded.env.MissionCameraStop)
	end)
end)
