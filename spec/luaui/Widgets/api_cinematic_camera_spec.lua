local SpringUnsyncedBuilder = VFS.Include("spec/builders/spring_unsynced_builder.lua")
local CameraMath = require("common/camera_math")

local WIDGET_PATH = "luaui/Widgets/api_cinematic_camera.lua"
local HALFPI = math.pi * 0.5
local EPS = 1e-3

local function near(expected, actual, tolerance)
	assert.is_true(
		math.abs(expected - actual) <= (tolerance or EPS),
		string.format(
			"expected %s to be within %s of %s",
			tostring(actual),
			tostring(tolerance or EPS),
			tostring(expected)
		)
	)
end

describe("luaui.Widgets.api_cinematic_camera", function()
	-- The player's camera: a spring camera resting on (100, 0, 100), rendered level at height 100.
	local playerState ---@type table
	local rendered ---@type { x: number, y: number, z: number, rx: number, ry: number }
	local units ---@type table<integer, table> unitID -> { x, y, z, heading? }
	local config ---@type table<string, integer>
	local setStates ---@type table<integer, { state: table, time: number }> every Spring.SetCameraState call
	local offsets ---@type table<integer, { n: integer, [integer]: number }> every Spring.SetCameraOffset call
	local configWrites ---@type table<integer, { key: string, value: integer, overlay: boolean }>
	local windowOpen ---@type boolean

	local function lastState()
		return setStates[#setStates].state
	end

	local function loadWidget()
		local loaded = SpringUnsyncedBuilder.new()
			:WithSpringFn("GetCameraState", function()
				return table.copy(playerState)
			end)
			:WithSpringFn("SetCameraState", function(state, time)
				setStates[#setStates + 1] = { state = state, time = time }
			end)
			:WithSpringFn("GetCameraPosition", function()
				return rendered.x, rendered.y, rendered.z
			end)
			:WithSpringFn("GetCameraRotation", function()
				return rendered.rx, rendered.ry, 0
			end)
			:WithSpringFn("GetCameraFOV", function()
				return 45, 60
			end)
			:WithSpringFn("SetCameraOffset", function(...)
				local count = select("#", ...)
				---@cast count integer
				offsets[#offsets + 1] = { n = count, ... }
			end)
			:WithSpringFn("GetUnitPosition", function(unitID)
				local unit = units[unitID] ---@type table?
				if unit then
					return unit.x, unit.y, unit.z
				end
			end)
			:WithSpringFn("GetUnitHeading", function(unitID)
				local unit = units[unitID] ---@type table?
				return unit and unit.heading or 0
			end)
			:WithSpringFn("GetGroundHeight", function()
				return 0
			end)
			:WithSpringFn("GetConfigInt", function(key, default)
				return config[key] or default
			end)
			:WithSpringFn("SetConfigInt", function(key, value, overlay)
				config[key] = value
				configWrites[#configWrites + 1] = { key = key, value = value, overlay = overlay }
			end)
			:LoadWidget(WIDGET_PATH)
		loaded.env.widgetHandler.IsAnyWindowOpen = function()
			return windowOpen
		end
		return loaded
	end

	before_each(function()
		playerState =
			{ mode = 2, name = "spring", px = 100, py = 0, pz = 100, dist = 141, rx = 2.6, ry = 0.4, fov = 45 }
		rendered = { x = 0, y = 100, z = 0, rx = HALFPI, ry = 0 }
		units = {}
		config = {}
		setStates = {}
		offsets = {}
		configWrites = {}
		windowOpen = false
	end)

	describe("Play", function()
		it("drives the fps camera along a linear move with the clamp lifted", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = { { position = { x = 200, y = 100, z = 0 }, duration = 2, easing = "linear" } },
			})
			assert.is_true(loaded.WG.cinematicCamera.IsActive())
			assert.are.same({ key = "FPSClampPos", value = 0, overlay = true }, configWrites[1])

			loaded.env.widget:Update(1)

			local state = lastState()
			assert.are.equal(0, setStates[#setStates].time)
			assert.are.equal(0, state.mode)
			near(100, state.px)
			near(100, state.py)
			near(0, state.pz)
			near(HALFPI, state.rx) -- rotation inherited from the player's view
			near(45, state.fov)
		end)

		it("samples the path a sequence would fly without taking the camera over", function()
			units[7] = { x = 500, y = 0, z = 500 }
			local loaded = loadWidget()
			local path = loaded.WG.cinematicCamera.SamplePath({
				keyframes = {
					{ position = { x = 200, y = 100, z = 0 }, duration = 2, easing = "linear", hold = 1 },
					{ position = { x = 200, y = 100, z = 400 }, lookAt = { unitIDs = { 7 } }, duration = 0 },
				},
			}, 2)

			assert.are.equal(4, #path.points) -- the start, two samples, then the cut
			near(0, path.points[1].x) -- from the rendered camera
			near(100, path.points[2].x)
			near(1, path.points[2].t)
			near(200, path.points[3].x)
			near(400, path.points[4].z)
			near(3, path.points[4].t) -- after the 1 s hold
			assert.are.equal(2, #path.keyframes)
			near(2, path.keyframes[1].t)
			assert.are.same({ x = 500, y = 0, z = 500 }, path.keyframes[2].lookAt)
			assert.is_false(loaded.WG.cinematicCamera.IsActive())
			assert.are.same({}, setStates)
		end)

		it("releases in place in the player's camera mode when the sequence ends", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = { { position = { x = 0, y = 100, z = 0 }, pitch = 45, duration = 1 } },
				releaseDuration = 0,
			})

			loaded.env.widget:Update(1.5)

			assert.is_false(loaded.WG.cinematicCamera.IsActive())
			local state = lastState()
			assert.are.equal(2, state.mode) -- back to the spring camera
			near(0, state.px, 1)
			near(-100, state.pz, 1) -- 45 degrees down from height 100 looking toward -z
			near(100 * math.sqrt(2), state.dist, 1)
			assert.are.same({ key = "FPSClampPos", value = 1, overlay = true }, configWrites[#configWrites])
		end)

		it("eases roll and fov out before handing the camera back", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = { { position = { x = 0, y = 100, z = 0 }, pitch = 45, roll = 10, fov = 65, duration = 0 } },
				releaseDuration = 1,
				releaseEasing = "linear",
			})

			loaded.env.widget:Update(0.5)
			assert.is_true(loaded.WG.cinematicCamera.IsActive())
			local midway = lastState()
			assert.are.equal(0, midway.mode)
			near(55, midway.fov) -- halfway from 65 back to the player's 45
			assert.is_true(midway.rz > 0 and midway.rz < CameraMath.CompensatedRoll(math.rad(10), midway.rx))

			loaded.env.widget:Update(0.6)
			assert.is_false(loaded.WG.cinematicCamera.IsActive())
			assert.are.equal(2, lastState().mode)
			near(45, lastState().fov)
		end)

		it("cuts and then pans between two look-at targets", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = {
					{ position = { x = 0, y = 100, z = 0 }, lookAt = { x = 0, y = 0, z = 100 }, duration = 0 },
					{
						position = { x = 0, y = 100, z = 0 },
						lookAt = { x = 100, y = 0, z = 0 },
						duration = 2,
						easing = "linear",
					},
				},
				onEnd = "hold",
			})

			loaded.env.widget:Update(1)

			local state = lastState()
			local rx, ry = CameraMath.LookAtRotation(0, 100, 0, 50, 0, 50)
			near(rx, state.rx)
			near(ry, state.ry)
		end)

		it("rides along with a unit, offset in its heading frame", function()
			units[7] = { x = 500, y = 0, z = 500, heading = HALFPI }
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = {
					{
						position = { unitIDs = { 7 }, offset = { x = 100, y = 50, z = 100 }, relativeToHeading = true },
						duration = 0,
					},
				},
				onEnd = "hold",
			})

			loaded.env.widget:Update(0.1)

			local state = lastState()
			near(600, state.px) -- the unit faces +x: its front is +x
			near(50, state.py)
			near(600, state.pz) -- and its right is +z
		end)

		it("holds the last pose while a window is open", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = { { position = { x = 200, y = 100, z = 0 }, duration = 2, easing = "linear" } },
			})
			loaded.env.widget:Update(0.5)
			local before = lastState().px

			windowOpen = true
			loaded.env.widget:Update(5)

			near(before, lastState().px)
			assert.is_true(loaded.WG.cinematicCamera.IsActive())
		end)

		it("blends back to the saved camera when the sequence ends with restore", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = { { position = { x = 400, y = 300, z = 0 }, duration = 1 } },
				onEnd = "restore",
				restoreDuration = 1,
				restoreEasing = "linear",
			})

			loaded.env.widget:Update(1.5)
			local midway = lastState()
			assert.are.equal(0, midway.mode)
			near(200, midway.px) -- halfway from (400, 300, 0) back to the rendered (0, 100, 0)
			near(200, midway.py)

			loaded.env.widget:Update(0.6)
			assert.is_false(loaded.WG.cinematicCamera.IsActive())
			assert.are.same(playerState, lastState())
		end)
	end)

	describe("Follow", function()
		it("keeps the eye above a moving unit and stays where it was last seen", function()
			units[3] = { x = 10, y = 0, z = 20 }
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Follow({
				target = { unitIDs = { 3 } },
				distance = 100,
				pitch = 90,
				transitionDuration = 0,
				smoothing = 0,
			})

			loaded.env.widget:Update(0.1)
			near(10, lastState().px)
			near(100, lastState().py)
			near(20, lastState().pz)
			near(math.pi, lastState().rx)

			units[3] = { x = 30, y = 0, z = 20 }
			loaded.env.widget:Update(0.1)
			near(30, lastState().px)

			units[3] = nil
			loaded.env.widget:Update(0.1)
			near(30, lastState().px)
			assert.is_true(loaded.WG.cinematicCamera.IsActive()) -- duration 0: until stopped
		end)

		it("starts from where the mission last saw a unit that is out of view", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Follow({
				target = { unitIDs = { 9 }, lastX = 700, lastY = 0, lastZ = 900 },
				distance = 100,
				pitch = 90,
				transitionDuration = 0,
			})
			loaded.env.widget:Update(0.1)
			near(700, lastState().px)
			near(900, lastState().pz)
		end)

		it("uses its easing for the lead-in blend", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Follow({
				target = { x = 500, y = 0, z = 500 },
				transitionDuration = 2,
				easing = "cut",
			})

			loaded.env.widget:Update(1.9)
			near(0, lastState().px) -- a cut shows the entry pose until the blend is over
			loaded.env.widget:Update(0.2)
			assert.is_true(math.abs(lastState().px) > 1) -- and then the shot
		end)

		it("holds the view when the target was never seen at all", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Follow({ target = { unitIDs = { 9 } }, transitionDuration = 0 })
			loaded.env.widget:Update(0.1)
			near(rendered.x, lastState().px)
			near(rendered.y, lastState().py)
			near(rendered.z, lastState().pz)
		end)
	end)

	describe("Orbit", function()
		it("circles the target at a steady rate", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Orbit({
				target = { x = 0, y = 0, z = 0 },
				distance = 100,
				pitch = 0,
				startYaw = 0,
				degrees = 360,
				duration = 4,
				transitionDuration = 0,
				easing = "linear",
			})

			loaded.env.widget:Update(0.0001)
			near(0, lastState().px, 0.1)
			near(100, lastState().pz, 0.1) -- yaw 0 looks toward -z, so the eye sits at +z

			loaded.env.widget:Update(1)
			near(-100, lastState().px, 0.1) -- a quarter turn later
			near(0, lastState().pz, 0.1)
		end)

		it("is already turning when the lead-in blend ends", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Orbit({
				target = { x = 0, y = 0, z = 0 },
				distance = 100,
				pitch = 0,
				startYaw = 0,
				degrees = 360,
				duration = 4,
				transitionDuration = 1,
				easing = "linear",
			})

			loaded.env.widget:Update(1)
			near(-100, lastState().px, 0.1) -- the orbit did not wait for the blend
			near(0, lastState().pz, 0.1)

			loaded.env.widget:Update(3.5)
			assert.is_true(loaded.WG.cinematicCamera.IsActive()) -- 4.5 s in: the sweep is over, the release blend runs
			loaded.env.widget:Update(1.5)
			assert.is_false(loaded.WG.cinematicCamera.IsActive()) -- sweep plus the default 1.5 s release
		end)
	end)

	describe("Shake", function()
		it("ramps up, stays bounded, and resets the offset once when done", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Shake({ magnitude = 10, duration = 1, rampUp = 0.25, falloff = 0.25 })
			assert.is_true(loaded.WG.cinematicCamera.IsShaking())

			loaded.env.widget:Update(0.001)
			assert.are.equal(5, offsets[1].n)
			assert.is_true(math.abs(offsets[1][1]) < 0.1) -- barely started

			for _ = 1, 50 do
				loaded.env.widget:Update(0.01)
			end
			for _, call in ipairs(offsets) do
				for axis = 1, 3 do
					assert.is_true(math.abs(call[axis] or 0) <= 10)
				end
			end

			loaded.env.widget:Update(1)
			assert.is_false(loaded.WG.cinematicCamera.IsShaking())
			assert.are.equal(0, offsets[#offsets].n) -- a bare SetCameraOffset() resets it
			local resets = #offsets
			loaded.env.widget:Update(1)
			assert.are.equal(resets, #offsets)
		end)

		it("adds concurrent shakes", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Shake({ magnitude = 10, duration = 1 })
			loaded.WG.cinematicCamera.Shake({ magnitude = 10, duration = 3 })
			loaded.env.widget:Update(2)
			assert.is_true(loaded.WG.cinematicCamera.IsShaking())
			loaded.env.widget:Update(2)
			assert.is_false(loaded.WG.cinematicCamera.IsShaking())
		end)
	end)

	describe("Save and Restore", function()
		it("snaps straight back to a saved camera", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Save("intro")
			playerState.px = 900 -- the player moved on; the slot keeps the old camera
			loaded.WG.cinematicCamera.Play({
				keyframes = { { position = { x = 400, y = 300, z = 0 }, duration = 1 } },
				onEnd = "hold",
			})
			loaded.env.widget:Update(0.5)

			loaded.WG.cinematicCamera.Restore("intro", 0)
			loaded.env.widget:Update(0.016)

			assert.is_false(loaded.WG.cinematicCamera.IsActive())
			assert.are.equal(100, lastState().px)
			assert.are.equal(2, lastState().mode)
		end)

		it("warns instead of restoring an unknown slot", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Restore("nothing")
			assert.is_false(loaded.WG.cinematicCamera.IsActive())
		end)

		it("saves the player's camera, not the shot, while a sequence plays", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = { { position = { x = 400, y = 300, z = 0 }, duration = 1 } },
				onEnd = "hold",
			})
			loaded.env.widget:Update(0.5)
			assert.are.same(playerState, loaded.WG.cinematicCamera.GetPlayerCameraState())

			loaded.WG.cinematicCamera.Save()
			loaded.WG.cinematicCamera.Restore(nil, 0)
			loaded.env.widget:Update(0.016)
			assert.are.same(playerState, lastState())
		end)
	end)

	describe("Stop and Shutdown", function()
		it("stops in place and clears shakes", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = { { position = { x = 0, y = 100, z = 0 }, pitch = 45, duration = 0 } },
				onEnd = "hold",
			})
			loaded.WG.cinematicCamera.Shake({ magnitude = 5 })
			loaded.env.widget:Update(0.1)

			loaded.WG.cinematicCamera.Stop()

			assert.is_false(loaded.WG.cinematicCamera.IsActive())
			assert.is_false(loaded.WG.cinematicCamera.IsShaking())
			assert.are.equal(2, lastState().mode)
			assert.are.equal(0, offsets[#offsets].n)
		end)

		it("leaves no roll behind when stopped during a rolled shot", function()
			playerState = { mode = 0, name = "fps", px = 0, py = 100, pz = 0, rx = HALFPI, ry = 0, rz = 0, fov = 45 }
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = { { position = { x = 0, y = 100, z = 0 }, pitch = 45, roll = 15, duration = 0 } },
				onEnd = "hold",
			})
			loaded.env.widget:Update(0.1)
			assert.is_true(math.abs(lastState().rz) > 0.1)

			loaded.WG.cinematicCamera.Stop()

			assert.are.equal(0, lastState().mode)
			assert.are.equal(0, lastState().rz)
		end)

		it("gives the player's camera back on shutdown", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = { { position = { x = 400, y = 300, z = 0 }, duration = 2 } },
			})
			loaded.env.widget:Update(0.5)

			loaded.env.widget:Shutdown()

			assert.are.same(playerState, lastState())
			assert.are.same({ key = "FPSClampPos", value = 1, overlay = true }, configWrites[#configWrites])
			assert.is_nil(loaded.WG.cinematicCamera)
		end)
	end)
end)
