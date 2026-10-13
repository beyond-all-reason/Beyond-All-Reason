local CameraMath = require("common/camera_math")

local PI = math.pi
local HALFPI = PI * 0.5
local EPS = 1e-5

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

local function flatGround()
	return 0
end

describe("common.camera_math", function()
	describe("Easings", function()
		it("start at 0 and end at 1", function()
			for name, ease in pairs(CameraMath.Easings) do
				near(0, ease(0))
				near(1, ease(1))
				assert.is_true(ease(0.5) >= 0 and ease(0.5) <= 1, name)
			end
		end)

		it("have the expected midpoints", function()
			near(0.5, CameraMath.Easings.linear(0.5))
			near(0.5, CameraMath.Easings.inOutSine(0.5))
			near(0.5, CameraMath.Easings.inOutQuad(0.5))
			near(0.5, CameraMath.Easings.inOutCubic(0.5))
			near(0.5, CameraMath.Easings.smoothstep(0.5))
			near(0.25, CameraMath.Easings.inQuad(0.5))
			near(0.75, CameraMath.Easings.outQuad(0.5))
			near(0.125, CameraMath.Easings.inCubic(0.5))
			near(0.875, CameraMath.Easings.outCubic(0.5))
			near(1 - math.cos(HALFPI * 0.5), CameraMath.Easings.inSine(0.5))
			near(math.sin(HALFPI * 0.5), CameraMath.Easings.outSine(0.5))
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
				near(d[1] / length, fx)
				near(d[2] / length, fy)
				near(d[3] / length, fz)
			end
		end)

		it("uses the engine convention", function()
			local rx, ry = CameraMath.RotFromDir(0, -1, 0)
			near(PI, rx) -- straight down
			rx, ry = CameraMath.RotFromDir(0, 0, -1)
			near(HALFPI, rx) -- level
			near(0, ry) -- looking toward -z
			rx, ry = CameraMath.RotFromDir(1, 0, 0)
			near(HALFPI, ry)
		end)

		it("looks from an eye at a target", function()
			local rx, ry = CameraMath.LookAtRotation(100, 500, 100, 100, 0, 100)
			near(PI, rx)
			rx, ry = CameraMath.LookAtRotation(0, 0, 0, 0, 0, -300)
			near(HALFPI, rx)
			near(0, ry)
		end)

		it("places the eye above the target at pitch 90", function()
			local ex, ey, ez, rx, ry = CameraMath.EyeFromTarget(100, 50, 200, HALFPI, 0, 600)
			near(100, ex)
			near(650, ey)
			near(200, ez)
			near(PI, rx)
			near(0, ry)
		end)

		it("places the eye behind the target at pitch 0, facing the yaw", function()
			local ex, ey, ez = CameraMath.EyeFromTarget(0, 0, 0, 0, 0, 100)
			near(0, ex)
			near(0, ey)
			near(100, ez) -- yaw 0 looks toward -z, so the eye sits at +z
		end)

		it("takes the short way around for yaw", function()
			near(0, math.clampRadians(CameraMath.LerpAngle(math.rad(350), math.rad(10), 0.5)))
			near(math.rad(5), CameraMath.LerpAngle(math.rad(0), math.rad(10), 0.5))
		end)

		it("compensates roll for the pitch", function()
			near(0.3, CameraMath.CompensatedRoll(0.3, HALFPI))
			assert.are.equal(0, CameraMath.CompensatedRoll(0, 2.0))
			assert.are.equal(0, CameraMath.CompensatedRoll(0.3, PI))
			local rz = CameraMath.CompensatedRoll(0.3, 2.677)
			near(0.3, math.atan(math.tan(rz) * math.sin(2.677)))
		end)
	end)

	describe("paths", function()
		local p0 = { x = -100, y = 0, z = 0 }
		local p1 = { x = 0, y = 0, z = 0 }
		local p2 = { x = 100, y = 50, z = 0 }
		local p3 = { x = 200, y = 50, z = 0 }

		it("lerps", function()
			local x, y, z = CameraMath.Lerp3(p1, p2, 0.5)
			near(50, x)
			near(25, y)
			near(0, z)
		end)

		it("passes through the inner anchors", function()
			local x, y = CameraMath.CatmullRom(p0, p1, p2, p3, 0)
			near(0, x)
			near(0, y)
			x, y = CameraMath.CatmullRom(p0, p1, p2, p3, 1)
			near(100, x)
			near(50, y)
			local mx = CameraMath.CatmullRom(p0, p1, p2, p3, 0.5)
			assert.is_true(mx > 0 and mx < 100)
		end)

		it("moves the eye straight or along the spline", function()
			local x = CameraMath.MoveEye(p1, p2, p0, p3, false, 0.5)
			near(50, x)
			local sx, sy = CameraMath.MoveEye(p1, p2, p0, p3, true, 1)
			near(100, sx)
			near(50, sy)
		end)
	end)

	describe("cardinal lock", function()
		it("snaps yaws near a cardinal direction", function()
			near(0, CameraMath.GetRotationWithCardinalLock(0.1))
			near(HALFPI, CameraMath.GetRotationWithCardinalLock(HALFPI * 1.2))
		end)

		it("inverts the lock: the raw yaw shows as the wanted azimuth", function()
			for _, wanted in ipairs({ 0.3, 0.7, 1.0, -0.7, 2.5, 0 }) do
				local raw = CameraMath.RawYawForAzimuth(wanted)
				near(wanted, math.clampRadians(CameraMath.GetRotationWithCardinalLock(raw)), 1e-4)
			end
		end)

		it("gives a raw yaw that shows what the raw yaw showed", function()
			for _, raw in ipairs({ 0.3, 1.0, -0.7, 2.5 }) do
				local safe = CameraMath.GetCardinalLockSafeYaw(raw)
				near(
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
			near(0, x)
			near(0, y)
			near(0, z, 1e-3)
		end)

		it("walks over a stepped heightfield", function()
			local function stepped(x)
				return x > 500 and 200 or 0
			end
			-- level flight at height 100 toward +x: hits the step wall at x = 500
			local x, y = CameraMath.GroundIntersection(0, 100, 0, 1, 0, 0, stepped)
			near(500, x, 1)
			near(200, y)
		end)

		it("returns nil when the ray never reaches the ground", function()
			assert.is_nil(CameraMath.GroundIntersection(0, 100, 0, 0, 1, 0, flatGround, 2000))
		end)
	end)

	describe("StateFromPose", function()
		local pose = { x = 0, y = 300, z = 300, rx = 0.75 * PI, ry = 0, rz = 0, fov = 45 }

		it("keeps an fps or rot pose as is", function()
			local fps = CameraMath.StateFromPose(pose, { mode = 0 }, flatGround, false)
			---@cast fps -?
			assert.are.equal(0, fps.mode)
			near(0, fps.px)
			near(300, fps.py)
			near(300, fps.pz)
			near(pose.rx, fps.rx)
			local fx, fy, fz = CameraMath.FwdFromRot(pose.rx, pose.ry)
			near(fx, fps.dx)
			near(fy, fps.dy)
			near(fz, fps.dz)
			local rot = CameraMath.StateFromPose(pose, { mode = 3 }, flatGround, false)
			---@cast rot -?
			assert.are.equal(3, rot.mode)
		end)

		it("rests a spring camera on the ground point of the view", function()
			local state = CameraMath.StateFromPose(pose, { mode = 2 }, flatGround, false)
			---@cast state -?
			assert.are.equal(2, state.mode)
			near(0, state.px, 1)
			near(0, state.py)
			near(0, state.pz, 1) -- 45 degrees down from (0, 300, 300) lands at the origin
			near(300 * math.sqrt(2), state.dist, 1)
			near(pose.rx, state.rx)
			near(0, state.ry)
			assert.are.equal(45, state.fov)
		end)

		it("clamps the spring pitch and uses a cardinal-safe yaw when locked", function()
			local level = { x = 0, y = 300, z = 300, rx = HALFPI, ry = 0.3, rz = 0, fov = 45 }
			local state = CameraMath.StateFromPose(level, { mode = 2 }, flatGround, true)
			---@cast state -?
			near(0.51 * PI, state.rx)
			near(CameraMath.RawYawForAzimuth(0.3), state.ry)
			near(0.3, CameraMath.GetRotationWithCardinalLock(state.ry), 1e-4)
		end)

		it("builds an overhead state from height and angle", function()
			local state = CameraMath.StateFromPose(pose, { mode = 1, flipped = 1 }, flatGround, false)
			---@cast state -?
			assert.are.equal(1, state.mode)
			near(300 * math.sqrt(2), state.height, 1)
			near(PI - pose.rx, state.angle)
			assert.are.equal(1, state.flipped)
		end)

		it("gives up on modes without a free eye", function()
			assert.is_nil(CameraMath.StateFromPose(pose, { mode = 4 }, flatGround, false))
			assert.is_nil(CameraMath.StateFromPose(pose, { mode = 5 }, flatGround, false))
		end)
	end)

	describe("shake", function()
		it("ramps up, holds, and fades", function()
			assert.are.equal(0, CameraMath.Envelope(-1, 2, 0.5, 0.5))
			assert.are.equal(0, CameraMath.Envelope(2.5, 2, 0.5, 0.5))
			near(0.5, CameraMath.Envelope(0.25, 2, 0.5, 0.5))
			near(1, CameraMath.Envelope(1, 2, 0.5, 0.5))
			near(0.5, CameraMath.Envelope(1.75, 2, 0.5, 0.5))
			near(1, CameraMath.Envelope(0, 2, 0, 0))
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
