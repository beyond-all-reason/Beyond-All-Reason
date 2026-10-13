-- Camera math shared by the cinematic camera widget, camera_remember_mode.lua and the
-- mission API's Easing parameter type. Pure functions, no engine state.
--
-- Angles are radians in the engine's camera convention: rx is the inclination from +y
-- (pi/2 level, pi straight down), ry the azimuth around +y (0 looks toward -z, the top of
-- the map), rz the roll. Positions are { x, y, z } tables in elmos.

VFS.Include("common/numberfunctions.lua") -- math.clampRadians

local CameraMath = {}

local PI = math.pi
local HALFPI = PI * 0.5
local sin, cos, tan, acos, atan, atan2, sqrt, abs =
	math.sin, math.cos, math.tan, math.acos, math.atan, math.atan2, math.sqrt, math.abs
local max, min, floor = math.max, math.min, math.floor

--------------------------------------------------------------------------------
-- Easing: t in [0, 1] -> eased fraction in [0, 1]
-- The mission API lists these names in luarules/mission_api/parameter_types.lua; keep both the same.
--------------------------------------------------------------------------------

CameraMath.Easings = {
	linear = function(t)
		return t
	end,
	inSine = function(t)
		return 1 - cos(t * HALFPI)
	end,
	outSine = function(t)
		return sin(t * HALFPI)
	end,
	inOutSine = function(t)
		return (1 - cos(PI * t)) * 0.5
	end,
	inQuad = function(t)
		return t * t
	end,
	outQuad = function(t)
		return 1 - (1 - t) * (1 - t)
	end,
	inOutQuad = function(t)
		if t < 0.5 then
			return 2 * t * t
		end
		local u = -2 * t + 2
		return 1 - u * u * 0.5
	end,
	inCubic = function(t)
		return t * t * t
	end,
	outCubic = function(t)
		local u = 1 - t
		return 1 - u * u * u
	end,
	inOutCubic = function(t)
		if t < 0.5 then
			return 4 * t * t * t
		end
		local u = -2 * t + 2
		return 1 - u * u * u * 0.5
	end,
	smoothstep = function(t)
		return t * t * (3 - 2 * t)
	end,
	-- Holds the start until the very end: an instant cut.
	cut = function(t)
		return t < 1 and 0 or 1
	end,
}

CameraMath.DEFAULT_EASING = "inOutCubic"

---@param name string?
---@return fun(t: number): number
function CameraMath.GetEasing(name)
	return CameraMath.Easings[name] or CameraMath.Easings[CameraMath.DEFAULT_EASING]
end

--------------------------------------------------------------------------------
-- Rotation
--------------------------------------------------------------------------------

---Engine CCamera::GetRotFromDir.
---@return number rx
---@return number ry
function CameraMath.RotFromDir(dx, dy, dz)
	local length = sqrt(dx * dx + dy * dy + dz * dz)
	if length == 0 then
		return HALFPI, 0
	end
	local y = dy / length
	return acos(max(-1, min(1, y))), atan2(dx, -dz)
end

---Engine CCamera::GetFwdFromRot.
---@return number fx
---@return number fy
---@return number fz
function CameraMath.FwdFromRot(rx, ry)
	local sx = sin(rx)
	return sx * sin(ry), cos(rx), -sx * cos(ry)
end

---Rotation that points an eye at a target.
function CameraMath.LookAtRotation(ex, ey, ez, tx, ty, tz)
	return CameraMath.RotFromDir(tx - ex, ty - ey, tz - ez)
end

---Eye position and rotation that look at a target from a distance, pitched down by `pitch`
---(0 = level, pi/2 = straight down) and turned to azimuth `yaw`.
---@return number ex
---@return number ey
---@return number ez
---@return number rx
---@return number ry
function CameraMath.EyeFromTarget(tx, ty, tz, pitch, yaw, distance)
	local rx = HALFPI + pitch
	local fx, fy, fz = CameraMath.FwdFromRot(rx, yaw)
	return tx - fx * distance, ty - fy * distance, tz - fz * distance, rx, yaw
end

local MAX_ROLL = HALFPI - 0.01

---The engine applies rz through the right vector, so the roll seen on screen is
---atan(tan(rz) * sin(rx)). Returns the rz that shows the wanted roll at this pitch.
function CameraMath.CompensatedRoll(roll, rx)
	local s = sin(rx)
	if roll == 0 or abs(s) < 1e-4 then
		return 0
	end
	roll = max(-MAX_ROLL, min(MAX_ROLL, roll))
	return atan(tan(roll) / s)
end

---Interpolates angles along the shortest path.
function CameraMath.LerpAngle(a, b, t)
	return a + math.clampRadians(b - a) * t
end

--------------------------------------------------------------------------------
-- Paths
--------------------------------------------------------------------------------

---@param a { x: number, y: number, z: number }
---@param b { x: number, y: number, z: number }
function CameraMath.Lerp3(a, b, t)
	return a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t
end

local function catmullRom(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

---Uniform Catmull-Rom point between p1 (t = 0) and p2 (t = 1), shaped by neighbours p0 and p3.
function CameraMath.CatmullRom(p0, p1, p2, p3, t)
	return catmullRom(p0.x, p1.x, p2.x, p3.x, t),
		catmullRom(p0.y, p1.y, p2.y, p3.y, t),
		catmullRom(p0.z, p1.z, p2.z, p3.z, t)
end

--------------------------------------------------------------------------------
-- Spring camera cardinal lock (CamSpringLockCardinalDirections)
--------------------------------------------------------------------------------

local LOCK_WIDTH = 0.2
local B = 1.0 / (1.0 - LOCK_WIDTH)
local C = 1.0 - B

---The azimuth the spring camera shows for a raw ry: yaws near a cardinal direction snap to it.
function CameraMath.GetRotationWithCardinalLock(rot)
	local q = rot / HALFPI
	local x = abs(q) - LOCK_WIDTH * 0.5
	local n = math.modf(x)
	local f = x - n
	local y = n + ((f > LOCK_WIDTH) and (f * B + C) or 0.0)
	return ((q < 0) and -y or y) * HALFPI
end

---The raw ry that the cardinal lock shows as `azimuth`: the inverse of GetRotationWithCardinalLock.
function CameraMath.RawYawForAzimuth(azimuth)
	local locked = math.clampRadians(azimuth)
	local q = abs(locked) / HALFPI
	local n = floor(q)
	local f = q - n

	q = n + LOCK_WIDTH * 0.5 + (f - C) / B
	return ((locked < 0) and -q or q) * HALFPI
end

---A raw ry that, applied again, shows what `rawYaw` showed (the lock is not idempotent on raw values).
function CameraMath.GetCardinalLockSafeYaw(rawYaw)
	return CameraMath.RawYawForAzimuth(CameraMath.GetRotationWithCardinalLock(rawYaw))
end

--------------------------------------------------------------------------------
-- Ground and camera states
--------------------------------------------------------------------------------

local MARCH_STEP = 32
local BISECTIONS = 10

---First point where the ray from the eye along f reaches the ground, or nil when it never does.
---@param groundHeightFn fun(x: number, z: number): number
---@param maxDistance number?
function CameraMath.GroundIntersection(ex, ey, ez, fx, fy, fz, groundHeightFn, maxDistance)
	maxDistance = maxDistance or 20000
	local function above(d)
		local x, z = ex + fx * d, ez + fz * d
		return ey + fy * d > groundHeightFn(x, z)
	end
	if not above(0) then
		return ex, groundHeightFn(ex, ez), ez
	end
	local lo = 0 ---@type number
	local hi = MARCH_STEP ---@type number
	while hi <= maxDistance and above(hi) do
		lo = hi
		hi = hi + MARCH_STEP
	end
	if hi > maxDistance then
		return nil
	end
	for _ = 1, BISECTIONS do
		local mid = (lo + hi) * 0.5
		if above(mid) then
			lo = mid
		else
			hi = mid
		end
	end
	local x, z = ex + fx * hi, ez + fz * hi
	return x, groundHeightFn(x, z), z
end

local SPRING_MIN_RX = 0.51 * PI
local SPRING_MAX_RX = 0.99 * PI
local TA_MIN_ANGLE = 0.01
local FALLBACK_LOOK_DISTANCE = 1000

---A camera state table for Spring.SetCameraState that shows `pose` (an eye position, rotation
---and fov) in the camera mode of `previousState`. Nil for modes without a free eye (overview,
---free, dolly): the caller falls back to restoring the previous state as it was.
---@param pose { x: number, y: number, z: number, rx: number, ry: number, rz: number, fov: number }
---@param previousState table a Spring.GetCameraState() table
---@param groundHeightFn fun(x: number, z: number): number
---@param cardinalLock boolean whether CamSpringLockCardinalDirections is on
---@return table?
function CameraMath.StateFromPose(pose, previousState, groundHeightFn, cardinalLock)
	local mode = previousState.mode
	local fx, fy, fz = CameraMath.FwdFromRot(pose.rx, pose.ry)

	if mode == 0 then -- fps
		return {
			name = "fps",
			mode = 0,
			px = pose.x,
			py = pose.y,
			pz = pose.z,
			dx = fx,
			dy = fy,
			dz = fz,
			rx = pose.rx,
			ry = pose.ry,
			rz = pose.rz,
			fov = pose.fov,
		}
	elseif mode == 3 then -- rot
		return {
			name = "rot",
			mode = 3,
			px = pose.x,
			py = pose.y,
			pz = pose.z,
			rx = pose.rx,
			ry = pose.ry,
			rz = pose.rz,
			fov = pose.fov,
		}
	elseif mode ~= 1 and mode ~= 2 then
		return nil
	end

	-- Ground-point cameras: the state holds the point the view centre rests on.
	local hx, hy, hz = CameraMath.GroundIntersection(pose.x, pose.y, pose.z, fx, fy, fz, groundHeightFn)
	if not hx then
		hx, hz = pose.x + fx * FALLBACK_LOOK_DISTANCE, pose.z + fz * FALLBACK_LOOK_DISTANCE
		hy = groundHeightFn(hx, hz)
	end
	local dx, dy, dz = pose.x - hx, pose.y - hy, pose.z - hz
	local distance = sqrt(dx * dx + dy * dy + dz * dz)

	if mode == 2 then -- spring
		local ry = cardinalLock and CameraMath.RawYawForAzimuth(pose.ry) or pose.ry
		return {
			name = "spring",
			mode = 2,
			px = hx,
			py = hy,
			pz = hz,
			dist = distance,
			rx = max(SPRING_MIN_RX, min(SPRING_MAX_RX, pose.rx)),
			ry = ry,
			rz = 0,
			fov = pose.fov,
		}
	end

	-- ta: looks along +-z only; angle counts from straight down
	return {
		name = "ta",
		mode = 1,
		px = hx,
		py = hy,
		pz = hz,
		height = distance,
		angle = max(TA_MIN_ANGLE, min(HALFPI, PI - pose.rx)),
		flipped = previousState.flipped or -1,
		fov = pose.fov,
	}
end

--------------------------------------------------------------------------------
-- Shake
--------------------------------------------------------------------------------

---Strength of a shake at time t: a linear ramp up, a hold, and a linear fade over the last
---`falloff` seconds. 0 outside [0, duration].
function CameraMath.Envelope(t, duration, rampUp, falloff)
	if t < 0 or t > duration then
		return 0
	end
	local ramp = rampUp > 0 and min(1, t / rampUp) or 1
	local fade = falloff > 0 and min(1, (duration - t) / falloff) or 1
	return min(ramp, fade)
end

-- Deterministic sample in [-1, 1] for integer step i of stream `seed`.
local function hashSample(seed, i)
	local v = sin(seed * 12.9898 + i * 78.233) * 43758.5453
	return (v - floor(v)) * 2 - 1
end

---Smooth random noise: samples at `frequency` Hz joined by cosine interpolation.
CameraMath.ValueNoise = {}

---@param frequency number samples per second
---@param seed number distinct streams give distinct noise
function CameraMath.ValueNoise.new(frequency, seed)
	return { frequency = frequency, seed = seed }
end

---@return number value in [-1, 1]
function CameraMath.ValueNoise.Sample(noise, t)
	local u = t * noise.frequency
	local i = floor(u)
	local f = u - i
	local a = hashSample(noise.seed, i)
	local b = hashSample(noise.seed, i + 1)
	local s = (1 - cos(PI * f)) * 0.5
	return a + (b - a) * s
end

return CameraMath
