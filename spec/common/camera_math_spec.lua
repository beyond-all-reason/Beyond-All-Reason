local CameraMath = require("common/camera_math")

local PI = math.pi
local HALFPI = PI * 0.5
-- Recoil's Lua numbers are float32: unitless values and angles hold to about 1e-6, positions of
-- a few thousand elmos to about 1e-3.
local EPS = 1e-5
local ELMOS = 1e-3

local function flatGround()
	return 0
end

describe("common.camera_math", function()
	describe("Easings", function()
		it("start at 0 and end at 1", function()
			for name, ease in pairs(CameraMath.Easings) do
				assert.near(0, ease(0), EPS)
				assert.near(1, ease(1), EPS)
				assert.is_true(ease(0.5) >= 0 and ease(0.5) <= 1, name)
			end
		end)

		it("have the expected midpoints", function()
			assert.near(0.5, CameraMath.Easings.linear(0.5), EPS)
			assert.near(0.5, CameraMath.Easings.inOutSine(0.5), EPS)
			assert.near(0.5, CameraMath.Easings.inOutQuad(0.5), EPS)
			assert.near(0.5, CameraMath.Easings.inOutCubic(0.5), EPS)
			assert.near(0.5, CameraMath.Easings.smoothstep(0.5), EPS)
			assert.near(0.25, CameraMath.Easings.inQuad(0.5), EPS)
			assert.near(0.75, CameraMath.Easings.outQuad(0.5), EPS)
			assert.near(0.125, CameraMath.Easings.inCubic(0.5), EPS)
			assert.near(0.875, CameraMath.Easings.outCubic(0.5), EPS)
			assert.near(1 - math.cos(HALFPI * 0.5), CameraMath.Easings.inSine(0.5), EPS)
			assert.near(math.sin(HALFPI * 0.5), CameraMath.Easings.outSine(0.5), EPS)
			assert.are.equal(0, CameraMath.Easings.cut(0.999))
		end)

		it("falls back to the default easing for unknown names", function()
			assert.are.equal(CameraMath.Easings.inOutCubic, CameraMath.GetEasing("nope"))
			assert.are.equal(CameraMath.Easings.linear, CameraMath.GetEasing("linear"))
		end)
	end)

	describe("rotation", function()
		it("round trips directions through rotations", function()
			local directions = {
				{ 0, -1, 0 },
				{ 0, 0, -1 },
				{ 1, 0, 0 },
				{ 0, 0, 1 },
				{ -1, 0, 0 },
				{ 1, -1, -1 },
				{ -2, -0.5, 3 },
				{ 0.3, 0.2, -0.9 },
			}
			for _, d in ipairs(directions) do
				local length = math.sqrt(d[1] * d[1] + d[2] * d[2] + d[3] * d[3])
				local rx, ry = CameraMath.RotFromDir(d[1], d[2], d[3])
				local fx, fy, fz = CameraMath.FwdFromRot(rx, ry)
				assert.near(d[1] / length, fx, EPS)
				assert.near(d[2] / length, fy, EPS)
				assert.near(d[3] / length, fz, EPS)
			end
		end)

		it("uses the engine convention", function()
			local rx, ry = CameraMath.RotFromDir(0, -1, 0)
			assert.near(PI, rx, EPS) -- straight down
			rx, ry = CameraMath.RotFromDir(0, 0, -1)
			assert.near(HALFPI, rx, EPS) -- level
			assert.near(0, ry, EPS) -- looking toward -z
			rx, ry = CameraMath.RotFromDir(1, 0, 0)
			assert.near(HALFPI, ry, EPS)
		end)

		it("keeps a given yaw for a direction straight up or down", function()
			local _, ry = CameraMath.RotFromDir(0, -1, -0.0, 0.7)
			assert.are.equal(0.7, ry) -- atan2(0, 0) would be 0 or pi depending on the sign of zero
			_, ry = CameraMath.RotFromDir(1e-7, 1, 1e-7, 0.7)
			assert.are.equal(0.7, ry)
			_, ry = CameraMath.RotFromDir(0, -1, 0)
			assert.are.equal(0, ry)
			_, ry = CameraMath.RotFromDir(0.01, -1, 0, 0.7)
			assert.near(HALFPI, ry, EPS) -- tilted enough to have a yaw of its own
		end)

		it("looks from an eye at a target", function()
			local rx, ry = CameraMath.LookAtRotation(100, 500, 100, 100, 0, 100, 0.3)
			assert.near(PI, rx, EPS)
			assert.near(0.3, ry, EPS)
			rx, ry = CameraMath.LookAtRotation(0, 0, 0, 0, 0, -300)
			assert.near(HALFPI, rx, EPS)
			assert.near(0, ry, EPS)
		end)

		it("places the eye above the target at pitch 90", function()
			local ex, ey, ez, rx, ry = CameraMath.EyeFromTarget(100, 50, 200, HALFPI, 0, 600)
			assert.near(100, ex, ELMOS)
			assert.near(650, ey, ELMOS)
			assert.near(200, ez, ELMOS) -- sin(pi) is -8.7e-8 in float32: 5e-5 elmos off at 600 away
			assert.near(PI, rx, EPS)
			assert.near(0, ry, EPS)
		end)

		it("places the eye behind the target at pitch 0, facing the yaw", function()
			local ex, ey, ez = CameraMath.EyeFromTarget(0, 0, 0, 0, 0, 100)
			assert.near(0, ex, ELMOS)
			assert.near(0, ey, ELMOS)
			assert.near(100, ez, ELMOS) -- yaw 0 looks toward -z, so the eye sits at +z
		end)

		it("takes the short way around for yaw", function()
			assert.near(0, math.clampRadians(CameraMath.LerpAngle(math.rad(350), math.rad(10), 0.5)), EPS)
			assert.near(math.rad(5), CameraMath.LerpAngle(math.rad(0), math.rad(10), 0.5), EPS)
		end)

		it("compensates roll for the pitch", function()
			assert.near(0.3, CameraMath.CompensatedRoll(0.3, HALFPI), EPS)
			assert.are.equal(0, CameraMath.CompensatedRoll(0, 2.0))
			assert.are.equal(0, CameraMath.CompensatedRoll(0.3, PI))
			local rz = CameraMath.CompensatedRoll(0.3, 2.677)
			assert.near(0.3, math.atan(math.tan(rz) * math.sin(2.677)), EPS)
		end)
	end)

	describe("paths", function()
		local p0 = { x = -100, y = 0, z = 0 }
		local p1 = { x = 0, y = 0, z = 0 }
		local p2 = { x = 100, y = 50, z = 0 }
		local p3 = { x = 200, y = 50, z = 0 }

		it("lerps", function()
			local x, y, z = CameraMath.Lerp3(p1, p2, 0.5)
			assert.near(50, x, ELMOS)
			assert.near(25, y, ELMOS)
			assert.near(0, z, ELMOS)
		end)

		it("passes through the inner anchors", function()
			local x, y = CameraMath.CatmullRom(p0, p1, p2, p3, 0)
			assert.near(0, x, ELMOS)
			assert.near(0, y, ELMOS)
			x, y = CameraMath.CatmullRom(p0, p1, p2, p3, 1)
			assert.near(100, x, ELMOS)
			assert.near(50, y, ELMOS)
			local mx = CameraMath.CatmullRom(p0, p1, p2, p3, 0.5)
			assert.is_true(mx > 0 and mx < 100)
		end)

		it("moves the eye straight or along the spline", function()
			local x = CameraMath.MoveEye(p1, p2, p0, p3, false, 0.5)
			assert.near(50, x, ELMOS)
			local sx, sy = CameraMath.MoveEye(p1, p2, p0, p3, true, 1)
			assert.near(100, sx, ELMOS)
			assert.near(50, sy, ELMOS)
		end)
	end)

	describe("cardinal lock", function()
		it("snaps yaws near a cardinal direction", function()
			assert.near(0, CameraMath.GetRotationWithCardinalLock(0.1), EPS)
			assert.near(HALFPI, CameraMath.GetRotationWithCardinalLock(HALFPI * 1.2), EPS)
		end)

		it("inverts the lock: the raw yaw shows as the wanted azimuth", function()
			for _, wanted in ipairs({ 0.3, 0.7, 1.0, -0.7, 2.5, 0 }) do
				local raw = CameraMath.RawYawForAzimuth(wanted)
				assert.near(wanted, math.clampRadians(CameraMath.GetRotationWithCardinalLock(raw)), 1e-4)
			end
		end)

		it("gives a raw yaw that shows what the raw yaw showed", function()
			for _, raw in ipairs({ 0.3, 1.0, -0.7, 2.5 }) do
				local safe = CameraMath.GetCardinalLockSafeYaw(raw)
				assert.near(
					math.clampRadians(CameraMath.GetRotationWithCardinalLock(raw)),
					math.clampRadians(CameraMath.GetRotationWithCardinalLock(safe)),
					1e-4
				)
			end
		end)
	end)

	describe("GroundIntersection", function()
		it("finds the ground hit along the view ray", function()
			local x, y, z = CameraMath.GroundIntersection(0, 100, 0, 0, -1, 0, flatGround)
			---@cast x -?
			---@cast y -?
			---@cast z -?
			assert.near(0, x, ELMOS)
			assert.near(0, y, ELMOS)
			assert.near(0, z, ELMOS)
		end)

		it("walks over a stepped heightfield", function()
			local function stepped(x)
				return x > 500 and 200 or 0
			end
			-- level flight at height 100 toward +x: hits the step wall at x = 500
			local x, y = CameraMath.GroundIntersection(0, 100, 0, 1, 0, 0, stepped)
			---@cast x -?
			---@cast y -?
			assert.near(500, x, 1)
			assert.near(200, y, ELMOS)
		end)

		it("returns nil when the ray never reaches the ground", function()
			assert.is_nil(CameraMath.GroundIntersection(0, 100, 0, 0, 1, 0, flatGround, 2000))
		end)
	end)

	describe("StateFromPose", function()
		local DOWN45 = 0.75 * PI
		local limits ---@type CameraLimits

		before_each(function()
			limits = { mapX = 4096, mapZ = 4096, groundHeight = flatGround, springMinDistance = 20, taMinHeight = 60 }
		end)

		---The eye a state shows, the way the engine places it from the state (GetPos).
		local function springEye(state)
			local fx, fy, fz = CameraMath.FwdFromRot(state.rx, state.ry)
			return state.px - fx * state.dist, state.py - fy * state.dist, state.pz - fz * state.dist
		end
		local function overheadEye(state)
			local s = state.flipped > 0 and 1 or -1
			local fy, fz = -math.cos(state.angle), s * math.sin(state.angle)
			return state.px, state.py - fy * state.height, state.pz - fz * state.height
		end

		local function assertEye(shown, x, y, z, tolerance)
			assert.near(x, shown.x, tolerance or ELMOS)
			assert.near(y, shown.y, tolerance or ELMOS)
			assert.near(z, shown.z, tolerance or ELMOS)
		end

		it("keeps an fps pose as is, without roll", function()
			local pose = { x = 1000, y = 300, z = 1300, rx = DOWN45, ry = 0.5, fov = 45 }
			local state, shown = CameraMath.StateFromPose(pose, { mode = 0 }, limits)
			---@cast state -?
			---@cast shown -?
			assert.are.equal(0, state.mode)
			assert.are.equal(0, state.rz)
			assert.near(300, state.py, ELMOS)
			local fx, fy, fz = CameraMath.FwdFromRot(pose.rx, pose.ry)
			assert.near(fx, state.dx, EPS)
			assert.near(fy, state.dy, EPS)
			assert.near(fz, state.dz, EPS)
			assertEye(shown, 1000, 300, 1300)
		end)

		it("keeps a clamped fps eye on the map and above the water", function()
			local pose = { x = -50, y = -20, z = 1000, rx = DOWN45, ry = 0, fov = 45 }
			local _, shown = CameraMath.StateFromPose(pose, { mode = 0 }, limits)
			---@cast shown -?
			assertEye(shown, 0.01, 5, 1000)
			limits.fpsClampPos = false
			local _, unclamped = CameraMath.StateFromPose(pose, { mode = 0 }, limits)
			---@cast unclamped -?
			assertEye(unclamped, -50, -20, 1000)
		end)

		it("rests a spring camera on the ground point of the view, showing the same eye", function()
			local pose = { x = 1000, y = 300, z = 1300, rx = DOWN45, ry = 0, fov = 45 }
			local state, shown = CameraMath.StateFromPose(pose, { mode = 2 }, limits)
			---@cast state -?
			---@cast shown -?
			assert.are.equal(2, state.mode)
			assert.near(1000, state.px, 0.1)
			assert.near(0, state.py, ELMOS)
			assert.near(1000, state.pz, 0.1) -- 45 degrees down from (1000, 300, 1300)
			assert.near(300 * math.sqrt(2), state.dist, 0.1)
			assert.near(DOWN45, state.rx, EPS)
			assertEye(shown, 1000, 300, 1300, 0.1)
			assertEye(shown, springEye(state))
		end)

		it("tips a view that looks up to 45 degrees down, as the spring camera's own switch does", function()
			local pose = { x = 1000, y = 300, z = 1300, rx = 0.4 * PI, ry = 0, fov = 45 }
			local state, shown = CameraMath.StateFromPose(pose, { mode = 2 }, limits)
			---@cast state -?
			---@cast shown -?
			assert.near(DOWN45, state.rx, EPS)
			assertEye(shown, 1000, 300, 1300, 0.1) -- around the eye
			assert.near(DOWN45, shown.rx, EPS)
		end)

		it("clamps a spring pitch near level and keeps the yaw through the cardinal lock", function()
			limits.cardinalLock = true
			local pose = { x = 1000, y = 300, z = 1300, rx = 0.505 * PI, ry = 0.3, fov = 45 }
			local state, shown = CameraMath.StateFromPose(pose, { mode = 2 }, limits)
			---@cast state -?
			---@cast shown -?
			assert.near(0.51 * PI, state.rx, EPS)
			assert.near(CameraMath.RawYawForAzimuth(0.3), state.ry, EPS)
			assert.near(0.3, CameraMath.GetRotationWithCardinalLock(state.ry), 1e-4)
			assert.near(0.3, shown.ry, EPS)
		end)

		it("backs a spring close-up off to the minimum zoom distance along the view", function()
			limits.springMinDistance = 300
			local pose = { x = 1000, y = 100, z = 1100, rx = DOWN45, ry = 0, fov = 45 }
			local state, shown = CameraMath.StateFromPose(pose, { mode = 2 }, limits)
			---@cast state -?
			---@cast shown -?
			assert.near(300, state.dist, ELMOS)
			local back = 300 / math.sqrt(2)
			assertEye(shown, 1000, back, 1000 + back, 0.1)
			assertEye(shown, springEye(state))
		end)

		it("rests the spring camera on the map and its focus surface", function()
			limits.springFocusHeight = function()
				return 40
			end
			local pose = { x = 100, y = 300, z = 100, rx = DOWN45, ry = 0, fov = 45 }
			local state, shown = CameraMath.StateFromPose(pose, { mode = 2 }, limits)
			---@cast state -?
			---@cast shown -?
			assert.near(0.01, state.pz, ELMOS) -- the view's ground point, z = -200, lies off the map
			assert.near(40, state.py, ELMOS)
			assertEye(shown, springEye(state))
		end)

		it("keeps the spring eye above the water", function()
			limits.groundHeight = function(_, z)
				return z > 1150 and -100 or 0 -- sea behind the beach
			end
			limits.springMinDistance = 300
			local pose = { x = 1000, y = 10, z = 1160, rx = 0.55 * PI, ry = 0, fov = 45 }
			local _, shown = CameraMath.StateFromPose(pose, { mode = 2 }, limits)
			---@cast shown -?
			assert.is_true(shown.y >= 5 - ELMOS)
		end)

		it("faces the ta camera along z the way the view faces, measured to the water", function()
			limits.groundHeight = function()
				return -50 -- under water
			end
			local south = { x = 1000, y = 300, z = 1000, rx = DOWN45, ry = PI * 0.9, fov = 45 }
			local state, shown = CameraMath.StateFromPose(south, { mode = 1, flipped = -1 }, limits)
			---@cast state -?
			---@cast shown -?
			assert.are.equal(1, state.mode)
			assert.are.equal(1, state.flipped) -- looking toward +z
			assert.near(0, state.py, ELMOS) -- the water, not the sea floor
			assert.near(1300, state.pz, 0.1)
			assert.near(300 * math.sqrt(2), state.height, 0.1)
			assert.near(PI - DOWN45, state.angle, EPS)
			assert.near(PI, shown.ry, EPS)
			assertEye(shown, overheadEye(state))
			assertEye(shown, 1000, 300, 1000, 0.1)

			local north = { x = 1000, y = 300, z = 1000, rx = DOWN45, ry = 0.2, fov = 45 }
			local northState = CameraMath.StateFromPose(north, { mode = 1, flipped = 1 }, limits)
			---@cast northState -?
			assert.are.equal(-1, northState.flipped)
		end)

		it("keeps the ta camera within its zoom range", function()
			limits.taMinHeight = 300
			local pose = { x = 1000, y = 50, z = 1050, rx = DOWN45, ry = 0, fov = 45 }
			local state, shown = CameraMath.StateFromPose(pose, { mode = 1 }, limits)
			---@cast state -?
			---@cast shown -?
			assert.near(300, state.height, ELMOS)
			assertEye(shown, overheadEye(state))
		end)

		it("keeps the rot camera above ground and below its ceiling", function()
			local low = { x = 1000, y = -40, z = 1000, rx = DOWN45, ry = 0, fov = 45 }
			local state, shown = CameraMath.StateFromPose(low, { mode = 3 }, limits)
			---@cast state -?
			---@cast shown -?
			assert.are.equal(3, state.mode)
			assert.near(5, state.py, ELMOS)
			assert.near(5, shown.y, ELMOS)
			local high = { x = 1000, y = 12000, z = 1000, rx = DOWN45, ry = 0, fov = 45 }
			local highState = CameraMath.StateFromPose(high, { mode = 3 }, limits)
			---@cast highState -?
			assert.near(9000, highState.py, ELMOS)
		end)

		it("moves the free camera in its own angles, without drift, on its ground offset", function()
			local previous = { mode = 4, name = "free", gndOffset = 16, gndLock = -1, gravity = -500, vx = 3, avy = 1 }
			local pose = { x = 1000, y = 10, z = 1000, rx = DOWN45, ry = 0.5, fov = 45 }
			local state, shown = CameraMath.StateFromPose(pose, previous, limits)
			---@cast state -?
			---@cast shown -?
			assert.are.equal(4, state.mode)
			assert.near(HALFPI - DOWN45, state.rx, EPS)
			assert.near(PI - 0.5, state.ry, EPS)
			assert.are.equal(0, state.vx)
			assert.are.equal(0, state.avy)
			assert.are.equal(-500, state.gravity) -- the player's own settings stay
			assert.near(16, state.py, ELMOS)
			assert.near(16, shown.y, ELMOS)
		end)

		it("gives up on modes without a free eye", function()
			local pose = { x = 1000, y = 300, z = 1300, rx = DOWN45, ry = 0, fov = 45 }
			assert.is_nil(CameraMath.StateFromPose(pose, { mode = 5 }, limits))
			assert.is_nil(CameraMath.StateFromPose(pose, { mode = 7 }, limits))
		end)
	end)

	describe("shake", function()
		it("ramps up, holds, and fades", function()
			assert.are.equal(0, CameraMath.Envelope(-1, 2, 0.5, 0.5))
			assert.are.equal(0, CameraMath.Envelope(2.5, 2, 0.5, 0.5))
			assert.near(0.5, CameraMath.Envelope(0.25, 2, 0.5, 0.5), EPS)
			assert.near(1, CameraMath.Envelope(1, 2, 0.5, 0.5), EPS)
			assert.near(0.5, CameraMath.Envelope(1.75, 2, 0.5, 0.5), EPS)
			assert.near(1, CameraMath.Envelope(0, 2, 0, 0), EPS)
		end)

		it("samples bounded, continuous noise", function()
			local noise = CameraMath.ValueNoise.new(10, 7)
			local previous = CameraMath.ValueNoise.Sample(noise, 0)
			for i = 1, 400 do
				local value = CameraMath.ValueNoise.Sample(noise, i * 0.005)
				assert.is_true(value >= -1 and value <= 1)
				assert.is_true(math.abs(value - previous) < 0.3)
				previous = value
			end
		end)

		it("gives different streams for different seeds", function()
			local a = CameraMath.ValueNoise.new(10, 1)
			local b = CameraMath.ValueNoise.new(10, 2)
			assert.are_not.equal(CameraMath.ValueNoise.Sample(a, 0.37), CameraMath.ValueNoise.Sample(b, 0.37))
		end)
	end)
end)
