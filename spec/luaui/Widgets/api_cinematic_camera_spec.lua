local SpringUnsyncedBuilder = VFS.Include("spec/builders/spring_unsynced_builder.lua")
local CameraMath = require("common/camera_math")

local WIDGET_PATH = "luaui/Widgets/api_cinematic_camera.lua"
local HALFPI = math.pi * 0.5
local EPS = 1e-3

describe("luaui.Widgets.api_cinematic_camera", function()
	-- The player's camera: a spring camera resting on (100, 0, 100), rendered level at height 100.
	local playerState ---@type table
	local rendered ---@type { x: number, y: number, z: number, rx: number, ry: number }
	local units ---@type table<integer, table> unitID -> { x, y, z, heading? }
	local config ---@type table<string, number>
	local setStates ---@type table<integer, { state: table, time: number }> every Spring.SetCameraState call
	local offsets ---@type table<integer, { n: integer, [integer]: number }> every Spring.SetCameraOffset call
	local configWrites ---@type table<integer, { key: string, value: integer, overlay: boolean }>
	local commands ---@type string[] every Spring.SendCommands call
	local logs ---@type table<integer, { level: any, message: string }>
	local windowOpen ---@type boolean
	local gameSeconds ---@type number

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
				if unit then
					return unit.heading or 0
				end
			end)
			:WithSpringFn("GetGroundHeight", function()
				return 0
			end)
			:WithSpringFn("GetSmoothMeshHeight", function()
				return 0
			end)
			:WithSpringFn("GetConfigInt", function(key, default)
				return config[key] or default
			end)
			:WithSpringFn("GetConfigFloat", function(key, default)
				return config[key] or default
			end)
			:WithSpringFn("SetConfigInt", function(key, value, overlay)
				config[key] = value
				configWrites[#configWrites + 1] = { key = key, value = value, overlay = overlay }
			end)
			:WithSpringFn("SendCommands", function(command)
				commands[#commands + 1] = command
			end)
			:WithSpringFn("Log", function(_, level, message)
				logs[#logs + 1] = { level = level, message = message }
			end)
			:WithSpringFn("GetGameSecondsInterpolated", function()
				return gameSeconds
			end)
			:LoadWidget(WIDGET_PATH)
		loaded.env.Game.mapSizeX = 4096
		loaded.env.Game.mapSizeZ = 4096
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
		commands = {}
		logs = {}
		windowOpen = false
		gameSeconds = 0
	end)

	describe("Play", function()
		it("drives the fps camera along a linear move with the clamp lifted", function()
			local loaded = loadWidget()
			assert.is_true(loaded.WG.cinematicCamera.Play({
				keyframes = { { position = { x = 200, y = 100, z = 0 }, duration = 2, easing = "linear" } },
			}))
			assert.is_true(loaded.WG.cinematicCamera.IsActive())
			assert.are.same({ key = "FPSClampPos", value = 0, overlay = true }, configWrites[1])

			loaded.env.widget:Update(1)

			local state = lastState()
			assert.are.equal(0, setStates[#setStates].time)
			assert.are.equal(0, state.mode)
			assert.near(100, state.px, EPS)
			assert.near(100, state.py, EPS)
			assert.near(0, state.pz, EPS)
			assert.near(HALFPI, state.rx, EPS) -- rotation inherited from the player's view
			assert.near(45, state.fov, EPS)
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
			---@cast path -?

			assert.are.equal(4, #path.points) -- the start, two samples, then the cut
			assert.near(0, path.points[1].x, EPS) -- from the rendered camera
			assert.near(100, path.points[2].x, EPS)
			assert.near(1, path.points[2].t, EPS)
			assert.near(200, path.points[3].x, EPS)
			assert.near(400, path.points[4].z, EPS)
			assert.near(3, path.points[4].t, EPS) -- after the 1 s hold
			assert.are.equal(2, #path.keyframes)
			assert.near(2, path.keyframes[1].t, EPS)
			assert.are.same({ x = 500, y = 0, z = 500 }, path.keyframes[2].lookAt)
			assert.is_false(loaded.WG.cinematicCamera.IsActive())
			assert.are.same({}, setStates)
		end)

		it("releases in place in the player's camera mode when the sequence ends", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = { { position = { x = 1000, y = 100, z = 1100 }, pitch = 45, duration = 1 } },
				releaseDuration = 0,
			})

			loaded.env.widget:Update(1.5)

			assert.is_false(loaded.WG.cinematicCamera.IsActive())
			local state = lastState()
			assert.are.equal(2, state.mode) -- back to the spring camera
			assert.near(1000, state.px, 0.1)
			assert.near(1000, state.pz, 0.1) -- 45 degrees down from height 100 looking toward -z
			assert.near(100 * math.sqrt(2), state.dist, 0.1)
			assert.are.same({ key = "FPSClampPos", value = 1, overlay = true }, configWrites[#configWrites])
		end)

		it("eases roll and fov out before handing the camera back", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = {
					{ position = { x = 1000, y = 100, z = 1100 }, pitch = 45, roll = 10, fov = 65, duration = 0 },
				},
				releaseDuration = 1,
				releaseEasing = "linear",
			})

			loaded.env.widget:Update(0.5)
			assert.is_true(loaded.WG.cinematicCamera.IsActive())
			local midway = lastState()
			assert.are.equal(0, midway.mode)
			assert.near(55, midway.fov, EPS) -- halfway from 65 back to the player's 45
			assert.is_true(midway.rz > 0 and midway.rz < CameraMath.CompensatedRoll(math.rad(10), midway.rx))

			loaded.env.widget:Update(0.6)
			assert.is_false(loaded.WG.cinematicCamera.IsActive())
			assert.are.equal(2, lastState().mode)
			assert.near(45, lastState().fov, EPS)
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
				ending = "hold",
			})

			loaded.env.widget:Update(1)

			local state = lastState()
			local rx, ry = CameraMath.LookAtRotation(0, 100, 0, 50, 0, 50)
			assert.near(rx, state.rx, EPS)
			assert.near(ry, state.ry, EPS)
		end)

		it("pans the look-at point along the spline when the eye stays put", function()
			local eye = { x = 0, y = 100, z = 0 }
			local a, b, c = { x = 500, y = 0, z = 0 }, { x = 500, y = 0, z = 500 }, { x = 0, y = 0, z = 500 }
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = {
					{ position = eye, lookAt = a, duration = 0 },
					{ position = eye, lookAt = b, duration = 2, easing = "linear", path = "spline" },
					{ position = eye, lookAt = c, duration = 2, path = "spline" },
				},
				ending = "hold",
			})

			loaded.env.widget:Update(1)

			local lx, ly, lz = CameraMath.MoveEye(a, b, a, c, true, 0.5)
			local rx, ry = CameraMath.LookAtRotation(eye.x, eye.y, eye.z, lx, ly, lz)
			local state = lastState()
			assert.near(rx, state.rx, EPS)
			assert.near(ry, state.ry, EPS)
			local straightRx, straightRy = CameraMath.LookAtRotation(eye.x, eye.y, eye.z, 500, 0, 250)
			assert.is_true(math.abs(straightRy - state.ry) > 0.01 or math.abs(straightRx - state.rx) > 0.01)
		end)

		it("keeps the yaw it had when looking straight down at a target", function()
			rendered.ry = 1
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = {
					{ position = { x = 500, y = 500, z = 500 }, lookAt = { x = 500, y = 0, z = 500 }, duration = 0 },
				},
				ending = "hold",
			})

			loaded.env.widget:Update(0.1)

			assert.near(math.pi, lastState().rx, EPS)
			assert.near(1, lastState().ry, EPS) -- atan2 of a vertical direction would give pi
		end)

		it("samples the panned look-at point between two look-at keyframes", function()
			local loaded = loadWidget()
			local path = loaded.WG.cinematicCamera.SamplePath({
				keyframes = {
					{ position = { x = 0, y = 100, z = 0 }, lookAt = { x = 500, y = 0, z = 500 }, duration = 0 },
					{
						position = { x = 100, y = 100, z = 0 },
						lookAt = { x = 700, y = 0, z = 500 },
						duration = 1,
						easing = "linear",
					},
				},
			}, 2)
			---@cast path -?

			assert.is_nil(path.points[2].lookAt) -- the cut pans from nothing
			assert.are.same({ x = 600, y = 0, z = 500 }, path.points[3].lookAt)
			assert.are.same({ x = 700, y = 0, z = 500 }, path.points[4].lookAt)
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
				ending = "hold",
			})

			loaded.env.widget:Update(0.1)

			local state = lastState()
			assert.near(600, state.px, EPS) -- the unit faces +x: its front is +x
			assert.near(50, state.py, EPS)
			assert.near(600, state.pz, EPS) -- and its right is +z
		end)

		it("stays where a ridden unit died, offset in its last heading frame", function()
			units[7] = { x = 500, y = 0, z = 500, heading = HALFPI }
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = {
					{
						position = { unitIDs = { 7 }, offset = { x = 100, y = 50, z = 100 }, relativeToHeading = true },
						duration = 0,
					},
				},
				ending = "hold",
			})
			loaded.env.widget:Update(0.1)

			units[7] = nil
			loaded.env.widget:Update(0.1)

			local state = lastState()
			assert.near(600, state.px, EPS)
			assert.near(600, state.pz, EPS)
		end)

		it("keeps riding and looking at units through a hold and a hold ending", function()
			units[7] = { x = 500, y = 0, z = 500 }
			units[8] = { x = 500, y = 0, z = 1000 }
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = {
					{
						position = { unitIDs = { 7 }, offset = { x = 0, y = 100, z = 0 } },
						lookAt = { unitIDs = { 8 } },
						duration = 0,
						hold = 5,
					},
				},
				ending = "hold",
			})
			loaded.env.widget:Update(0.1)
			assert.near(500, lastState().px, EPS)

			units[7] = { x = 700, y = 0, z = 500 }
			units[8] = { x = 900, y = 0, z = 1000 }
			loaded.env.widget:Update(1) -- in the keyframe's hold
			assert.near(700, lastState().px, EPS)
			local _, ry = CameraMath.LookAtRotation(700, 100, 500, 900, 0, 1000)
			assert.near(0, math.sin(lastState().ry - ry), EPS)

			units[7] = { x = 900, y = 0, z = 500 }
			loaded.env.widget:Update(5) -- past it, in the hold ending
			assert.near(900, lastState().px, EPS)
		end)

		it("holds the last pose while a window is open", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = { { position = { x = 200, y = 100, z = 0 }, duration = 2, easing = "linear" } },
			})
			loaded.env.widget:Update(0.5)
			local before = lastState().px ---@type number

			windowOpen = true
			loaded.env.widget:Update(5)

			assert.near(before, lastState().px, EPS)
			assert.is_true(loaded.WG.cinematicCamera.IsActive())
		end)

		it("blends back to the saved camera when the sequence ends with restore", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = { { position = { x = 400, y = 300, z = 0 }, duration = 1 } },
				ending = "restore",
				restoreDuration = 1,
				restoreEasing = "linear",
			})

			loaded.env.widget:Update(1.5)
			local midway = lastState()
			assert.are.equal(0, midway.mode)
			assert.near(200, midway.px, EPS) -- halfway from (400, 300, 0) back to the rendered (0, 100, 0)
			assert.near(200, midway.py, EPS)

			loaded.env.widget:Update(0.6)
			assert.is_false(loaded.WG.cinematicCamera.IsActive())
			assert.are.same(playerState, lastState())
		end)
	end)

	describe("checks", function()
		it("leaves the camera alone for shots it cannot run", function()
			local loaded = loadWidget()
			local camera = loaded.WG.cinematicCamera
			local eye = { x = 0, y = 100, z = 0 }

			assert.is_false(camera.Play({ keyframes = {} }))
			assert.is_false(camera.Play({ keyframes = { { position = { x = 1, z = 2 } } } }))
			assert.is_false(camera.Play({ keyframes = { { position = eye, duration = -1 } } }))
			assert.is_false(camera.Play({ keyframes = { { position = eye, hold = math.huge } } }))
			assert.is_false(camera.Play({ keyframes = { { position = eye } }, ending = "loop" }))
			assert.is_false(camera.Play({ keyframes = { { position = eye } }, onEnd = "release" }))
			assert.is_false(camera.Follow({ distance = 100 }))
			assert.is_false(camera.Follow({ target = eye, smoothing = -1 }))
			assert.is_false(camera.Orbit({ target = { unitIDs = 5 } }))
			assert.is_false(camera.Restore("default"))
			assert.is_false(camera.Shake({ magnitude = 5, duration = 0 / 0 }))
			assert.is_nil(camera.SamplePath({ keyframes = {} }))

			assert.is_false(camera.IsActive())
			assert.is_false(camera.IsShaking())
			assert.are.same({}, configWrites)
			assert.are.same({}, commands)
			assert.are.equal(12, #logs)
			assert.are.equal(
				"Play: keyframes[1].position needs x, y and z, or unitIDs; the camera was left alone",
				logs[2].message
			)
		end)
	end)

	describe("callbacks", function()
		it("reports each keyframe reached, then the end once the camera is back", function()
			local events = {}
			local loaded = loadWidget()
			local camera = loaded.WG.cinematicCamera
			camera.Play({
				keyframes = {
					{ position = { x = 100, y = 100, z = 0 }, duration = 1 },
					{ position = { x = 200, y = 100, z = 0 }, duration = 0 }, -- a cut, reached on the same frame
					{ position = { x = 300, y = 100, z = 0 }, duration = 1 },
				},
				releaseDuration = 1,
				onKeyframe = function(index)
					events[#events + 1] = "keyframe " .. index
				end,
				onEnd = function(reason)
					events[#events + 1] = reason .. (camera.IsActive() and " while active" or "")
				end,
			})

			loaded.env.widget:Update(1.5)
			assert.are.same({ "keyframe 1", "keyframe 2" }, events)
			loaded.env.widget:Update(1)
			assert.are.same({ "keyframe 1", "keyframe 2", "keyframe 3" }, events)
			loaded.env.widget:Update(1)
			assert.are.same({ "keyframe 1", "keyframe 2", "keyframe 3", "finished" }, events)
		end)

		it("says when a hold ending begins and when a shot is replaced or stopped, once each", function()
			local reasons = {}
			local function record(name)
				return function(reason)
					reasons[#reasons + 1] = name .. ": " .. reason
				end
			end
			local loaded = loadWidget()
			local camera = loaded.WG.cinematicCamera
			local origin = { x = 0, y = 0, z = 0 }

			camera.Play({
				keyframes = { { position = { x = 0, y = 100, z = 0 }, duration = 1 } },
				ending = "hold",
				onEnd = record("sequence"),
			})
			loaded.env.widget:Update(1.5)
			camera.Follow({ target = origin, onEnd = record("follow") })
			camera.Orbit({ target = origin, onEnd = record("orbit") })
			camera.Stop()

			assert.are.same({ "sequence: held", "follow: replaced", "orbit: stopped" }, reasons)
		end)

		it("reports the end of a restore", function()
			local reasons = {}
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Save()
			loaded.WG.cinematicCamera.Restore({
				duration = 0,
				onEnd = function(reason)
					reasons[#reasons + 1] = reason
				end,
			})
			loaded.env.widget:Update(0.016)
			assert.are.same({ "finished" }, reasons)
		end)

		it("lets the end of one shot start the next", function()
			local loaded = loadWidget()
			local camera = loaded.WG.cinematicCamera
			camera.Play({
				keyframes = { { position = { x = 0, y = 100, z = 0 }, duration = 0 } },
				releaseDuration = 0,
				onEnd = function()
					camera.Play({
						keyframes = { { position = { x = 200, y = 100, z = 0 }, duration = 2, easing = "linear" } },
					})
				end,
			})

			loaded.env.widget:Update(0.1)
			assert.is_true(camera.IsActive())
			loaded.env.widget:Update(1)
			assert.near(100, lastState().px, EPS)
		end)

		it("logs a failing callback and carries on", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = { { position = { x = 0, y = 100, z = 0 }, duration = 1 } },
				onKeyframe = function()
					error("boom")
				end,
			})

			loaded.env.widget:Update(1.2)

			assert.is_true(loaded.WG.cinematicCamera.IsActive())
			assert.is_truthy(logs[#logs].message:find("boom", 1, true))
		end)
	end)

	describe("while in control", function()
		local function playHold(loaded)
			loaded.WG.cinematicCamera.Play({
				keyframes = { { position = { x = 0, y = 100, z = 0 }, duration = 0 } },
				ending = "hold",
			})
		end

		it("turns unit tracking off when it takes the camera", function()
			local loaded = loadWidget()
			playHold(loaded)
			loaded.WG.cinematicCamera.Follow({ target = { x = 0, y = 0, z = 0 } }) -- already in control
			assert.are.same({ "track off" }, commands)
		end)

		it("swallows the overview toggle and tracking keys, and nothing else", function()
			local loaded = loadWidget()
			local widget = loaded.env.widget
			local overview = { { command = "toggleoverview", extra = "" } }
			assert.is_false(widget:KeyPress(9, {}, false, "tab", 0, 43, overview)) -- not in control yet

			playHold(loaded)

			assert.is_true(widget:KeyPress(9, {}, false, "tab", 0, 43, overview))
			assert.is_true(widget:KeyPress(116, {}, false, "t", 0, 20, { { command = "track", extra = "" } }))
			assert.is_false(widget:KeyPress(32, {}, false, "space", 0, 44, { { command = "pause", extra = "" } }))
			assert.is_false(widget:KeyPress(32, {}, false, "space", 0, 44, nil))
		end)
	end)

	describe("handing back in place", function()
		---The eye the spring camera shows for a state (CSpringController::GetPos), cardinal lock on.
		local function springEye(state)
			local azimuth = CameraMath.GetRotationWithCardinalLock(state.ry)
			local fx, fy, fz = CameraMath.FwdFromRot(state.rx, azimuth)
			return state.px - fx * state.dist, state.py - fy * state.dist, state.pz - fz * state.dist
		end

		---Plays a cut to `keyframe`, then runs its linear one-second release to its last frame.
		---@return table midway the shot halfway through the release
		---@return table last the shot just before the hand-over
		---@return table handedBack the player's camera state after it
		local function release(keyframe)
			local loaded = loadWidget()
			keyframe.duration = 0
			loaded.WG.cinematicCamera.Play({ keyframes = { keyframe }, releaseDuration = 1, releaseEasing = "linear" })
			loaded.env.widget:Update(0.5)
			local midway = lastState()
			loaded.env.widget:Update(0.4999)
			local last = lastState()
			loaded.env.widget:Update(0.1)
			assert.is_false(loaded.WG.cinematicCamera.IsActive())
			return midway, last, lastState()
		end

		local function assertSameView(shot, handedBack)
			local x, y, z = springEye(handedBack)
			assert.near(shot.px, x, 0.1)
			assert.near(shot.py, y, 0.1)
			assert.near(shot.pz, z, 0.1)
			assert.near(shot.rx, handedBack.rx, 1e-3)
		end

		it("tips a view looking up down to 45 degrees around the eye before the spring camera takes over", function()
			local midway, last, handedBack =
				release({ position = { x = 1000, y = 300, z = 1300 }, pitch = -30, yaw = 0 })

			assert.are.equal(0, midway.mode)
			assert.near((HALFPI - math.rad(30) + 0.75 * math.pi) * 0.5, midway.rx, EPS)
			assert.near(300, midway.py, 0.1) -- the eye stays where it is
			assert.near(1300, midway.pz, 0.1)
			assert.are.equal(2, handedBack.mode)
			assert.near(0.75 * math.pi, handedBack.rx, EPS)
			assertSameView(last, handedBack)
		end)

		it("backs a close-up off to the player's minimum zoom distance before the spring camera takes over", function()
			config.CamSpringMinZoomDistance = 300
			local _, last, handedBack = release({ position = { x = 1000, y = 100, z = 1100 }, pitch = 45, yaw = 0 })

			assert.near(300, handedBack.dist, EPS)
			assert.near(300 / math.sqrt(2), last.py, 0.1) -- backed off along the view
			assertSameView(last, handedBack)
		end)

		it("eases back to the camera it took over when the player was in the overview", function()
			playerState = { mode = 5, name = "ov", px = 2048, py = 0, pz = 2048, fov = 45 }
			local midway, _, handedBack = release({ position = { x = 1000, y = 300, z = 1000 } })

			assert.near(500, midway.px, EPS) -- halfway back to the rendered (0, 100, 0)
			assert.are.same(playerState, handedBack)
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
			assert.near(10, lastState().px, EPS)
			assert.near(100, lastState().py, EPS)
			assert.near(20, lastState().pz, EPS)
			assert.near(math.pi, lastState().rx, EPS)

			units[3] = { x = 30, y = 0, z = 20 }
			loaded.env.widget:Update(0.1)
			assert.near(30, lastState().px, EPS)

			units[3] = nil
			loaded.env.widget:Update(0.1)
			assert.near(30, lastState().px, EPS)
			assert.is_true(loaded.WG.cinematicCamera.IsActive()) -- no duration: until stopped
		end)

		it("takes a duration of 0 as a shot with no length, not an endless one", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Follow({
				target = { x = 500, y = 0, z = 500 },
				duration = 0,
				transitionDuration = 0,
				releaseDuration = 0,
			})

			loaded.env.widget:Update(0.016)

			assert.is_false(loaded.WG.cinematicCamera.IsActive())
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
			assert.near(700, lastState().px, EPS)
			assert.near(900, lastState().pz, EPS)
		end)

		it("uses its easing for the lead-in blend", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Follow({
				target = { x = 500, y = 0, z = 500 },
				transitionDuration = 2,
				easing = "cut",
			})

			loaded.env.widget:Update(1.9)
			assert.near(0, lastState().px, EPS) -- a cut shows the entry pose until the blend is over
			loaded.env.widget:Update(0.2)
			assert.near(500, lastState().px, EPS) -- and then the shot, straight above the target's x
		end)

		it("holds the view when the target was never seen at all", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Follow({ target = { unitIDs = { 9 } }, transitionDuration = 0 })
			loaded.env.widget:Update(0.1)
			assert.near(rendered.x, lastState().px, EPS)
			assert.near(rendered.y, lastState().py, EPS)
			assert.near(rendered.z, lastState().pz, EPS)
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
			assert.near(0, lastState().px, 0.1)
			assert.near(100, lastState().pz, 0.1) -- yaw 0 looks toward -z, so the eye sits at +z

			loaded.env.widget:Update(1)
			assert.near(-100, lastState().px, 0.1) -- a quarter turn later
			assert.near(0, lastState().pz, 0.1)
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
			assert.near(-100, lastState().px, 0.1) -- the orbit did not wait for the blend
			assert.near(0, lastState().pz, 0.1)

			loaded.env.widget:Update(3.5)
			assert.is_true(loaded.WG.cinematicCamera.IsActive()) -- 4.5 s in: the sweep is over, the release blend runs
			loaded.env.widget:Update(1.5)
			assert.is_false(loaded.WG.cinematicCamera.IsActive()) -- sweep plus the default 1.5 s release
		end)
	end)

	describe("Shake", function()
		it("ramps up, stays bounded, and resets the offset once when done", function()
			local loaded = loadWidget()
			assert.is_true(
				loaded.WG.cinematicCamera.Shake({ magnitude = 10, duration = 1, rampUp = 0.25, falloff = 0.25 })
			)
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
				ending = "hold",
			})
			loaded.env.widget:Update(0.5)

			assert.is_true(loaded.WG.cinematicCamera.Restore({ slot = "intro", duration = 0 }))
			loaded.env.widget:Update(0.016)

			assert.is_false(loaded.WG.cinematicCamera.IsActive())
			assert.are.equal(100, lastState().px)
			assert.are.equal(2, lastState().mode)
		end)

		it("warns instead of restoring an unknown slot", function()
			local loaded = loadWidget()
			assert.is_false(loaded.WG.cinematicCamera.Restore({ slot = "nothing" }))
			assert.is_false(loaded.WG.cinematicCamera.IsActive())
			assert.are.equal("No camera saved as 'nothing'", logs[1].message)
		end)

		it("saves the player's camera, not the shot, while a sequence plays", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = { { position = { x = 400, y = 300, z = 0 }, duration = 1 } },
				ending = "hold",
			})
			loaded.env.widget:Update(0.5)
			assert.are.same(playerState, loaded.WG.cinematicCamera.GetPlayerCameraState())

			loaded.WG.cinematicCamera.Save()
			loaded.WG.cinematicCamera.Restore({ duration = 0 })
			loaded.env.widget:Update(0.016)
			assert.are.same(playerState, lastState())
		end)
	end)

	describe("clock", function()
		local function playOnGameTime(loaded, sequence)
			sequence.clock = "game"
			loaded.WG.cinematicCamera.Play(sequence)
			loaded.env.widget:Update(0.016) -- the first frame only reads the game time
		end

		local function twoSecondMove()
			return { keyframes = { { position = { x = 200, y = 100, z = 0 }, duration = 2, easing = "linear" } } }
		end

		it("runs a sequence on game time, standing still while the game is paused", function()
			local loaded = loadWidget()
			playOnGameTime(loaded, twoSecondMove())

			gameSeconds = 1
			loaded.env.widget:Update(0.016)
			assert.near(100, lastState().px, EPS)

			loaded.env.widget:Update(5) -- real time passes, game time does not
			assert.near(100, lastState().px, EPS)
			assert.is_true(loaded.WG.cinematicCamera.IsActive())
		end)

		it("keeps a game-time shot moving with the game while a window is open", function()
			local loaded = loadWidget()
			playOnGameTime(loaded, twoSecondMove())

			windowOpen = true
			gameSeconds = 1
			loaded.env.widget:Update(0.016)

			assert.near(100, lastState().px, EPS)
		end)

		it("runs the ending on the same clock", function()
			local loaded = loadWidget()
			playOnGameTime(loaded, { keyframes = { { position = { x = 0, y = 100, z = 0 }, duration = 0 } } })

			loaded.env.widget:Update(5)
			assert.is_true(loaded.WG.cinematicCamera.IsActive()) -- the release waits for game time

			gameSeconds = 2
			loaded.env.widget:Update(0.016)
			assert.is_false(loaded.WG.cinematicCamera.IsActive())
		end)

		it("restores on the clock it is given", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Save()
			loaded.WG.cinematicCamera.Restore({ duration = 2, easing = "linear", clock = "game" })

			loaded.env.widget:Update(5)
			assert.is_true(loaded.WG.cinematicCamera.IsActive())

			gameSeconds = 3
			loaded.env.widget:Update(0.016)
			assert.is_false(loaded.WG.cinematicCamera.IsActive())
		end)

		it("runs a game-time shake on game time", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Shake({ magnitude = 5, duration = 1, clock = "game" })

			loaded.env.widget:Update(5)
			assert.is_true(loaded.WG.cinematicCamera.IsShaking())

			gameSeconds = 1.5
			loaded.env.widget:Update(0.016)
			assert.is_false(loaded.WG.cinematicCamera.IsShaking())
		end)
	end)

	describe("GameOver", function()
		local function assertHandedBackAfterGameOver(loaded)
			loaded.env.widget:Update(0.1)
			loaded.env.widget:GameOver({ 0 })

			loaded.env.widget:Update(0.1)
			assert.is_true(loaded.WG.cinematicCamera.IsActive()) -- easing out as a release
			loaded.env.widget:Update(2)

			assert.is_false(loaded.WG.cinematicCamera.IsActive())
			assert.are.equal(2, lastState().mode)
		end

		it("hands back an endless follow", function()
			units[3] = { x = 10, y = 0, z = 20 }
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Follow({ target = { unitIDs = { 3 } }, transitionDuration = 0 })

			assertHandedBackAfterGameOver(loaded)
		end)

		it("hands back a hold ending", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = { { position = { x = 0, y = 100, z = 0 }, duration = 0 } },
				ending = "hold",
			})

			assertHandedBackAfterGameOver(loaded)
		end)

		it("lets a shot with an end play out", function()
			local loaded = loadWidget()
			loaded.env.widget:GameOver({ 0 })
			loaded.WG.cinematicCamera.Play({
				keyframes = { { position = { x = 200, y = 100, z = 0 }, duration = 2, easing = "linear" } },
			})

			loaded.env.widget:Update(1)

			assert.is_true(loaded.WG.cinematicCamera.IsActive())
			assert.near(100, lastState().px, EPS)
		end)
	end)

	describe("Stop and Shutdown", function()
		it("stops in place and clears shakes", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = { { position = { x = 0, y = 100, z = 0 }, pitch = 45, duration = 0 } },
				ending = "hold",
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
				ending = "hold",
			})
			loaded.env.widget:Update(0.1)
			assert.is_true(math.abs(lastState().rz) > 0.1)

			loaded.WG.cinematicCamera.Stop()

			assert.are.equal(0, lastState().mode)
			assert.are.equal(0, lastState().rz)
		end)

		it("gives the player's fov back when stopped during a shot with its own fov", function()
			local loaded = loadWidget()
			loaded.WG.cinematicCamera.Play({
				keyframes = { { position = { x = 0, y = 100, z = 0 }, pitch = 45, fov = 20, duration = 0 } },
				ending = "hold",
			})
			loaded.env.widget:Update(0.1)
			assert.near(20, lastState().fov, EPS)

			loaded.WG.cinematicCamera.Stop()

			assert.near(45, lastState().fov, EPS)
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
