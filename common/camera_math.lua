-- Camera math shared by the cinematic camera widget and camera_remember_mode.lua. Pure
-- functions, no engine state.
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
-- The mission API's CameraEasing parameter type lists these names; keep both the same.
--------------------------------------------------------------------------------

---@type table<string, fun(t: number): number>
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

-- Below this share of the length, a direction counts as straight up or down: atan2 of the
-- leftover x and z is noise, and the yaw would spin.
local VERTICAL_EPSILON = 1e-4

---Engine CCamera::GetRotFromDir. A straight up or down direction has no yaw of its own and
---takes `fallbackRy` (default 0).
---@param fallbackRy number?
---@return number rx
---@return number ry
function CameraMath.RotFromDir(dx, dy, dz, fallbackRy)
	local length = sqrt(dx * dx + dy * dy + dz * dz)
	if length == 0 then
		return HALFPI, fallbackRy or 0
	end
	local rx = acos(max(-1, min(1, dy / length)))
	if dx * dx + dz * dz <= (length * VERTICAL_EPSILON) ^ 2 then
		return rx, fallbackRy or 0
	end
	return rx, atan2(dx, -dz)
end

---Engine CCamera::GetFwdFromRot.
---@return number fx
---@return number fy
---@return number fz
function CameraMath.FwdFromRot(rx, ry)
	local sx = sin(rx)
	return sx * sin(ry), cos(rx), -sx * cos(ry)
end

---Rotation that points an eye at a target; `fallbackRy` is the yaw when the target is straight
---above or below.
---@param fallbackRy number?
function CameraMath.LookAtRotation(ex, ey, ez, tx, ty, tz, fallbackRy)
	return CameraMath.RotFromDir(tx - ex, ty - ey, tz - ez, fallbackRy)
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
local MAX_COMPENSATED_ROLL = 1.0 -- past this the right vector nears the view direction and the roll jitters

---The engine applies rz through the right vector, so the roll seen on screen is
---atan(tan(rz) * sin(rx)). Returns the rz that shows the wanted roll at this pitch.
function CameraMath.CompensatedRoll(roll, rx)
	local s = sin(rx)
	if roll == 0 or abs(s) < 1e-4 then
		return 0
	end
	roll = max(-MAX_ROLL, min(MAX_ROLL, roll))
	local rz = atan(tan(roll) / s)
	return max(-MAX_COMPENSATED_ROLL, min(MAX_COMPENSATED_ROLL, rz))
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
---@return number x
---@return number y
---@return number z
function CameraMath.Lerp3(a, b, t)
	return a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t
end

local function catmullRom(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

---Uniform Catmull-Rom point between p1 (t = 0) and p2 (t = 1), shaped by neighbours p0 and p3.
---@return number x
---@return number y
---@return number z
function CameraMath.CatmullRom(p0, p1, p2, p3, t)
	return catmullRom(p0.x, p1.x, p2.x, p3.x, t),
		catmullRom(p0.y, p1.y, p2.y, p3.y, t),
		catmullRom(p0.z, p1.z, p2.z, p3.z, t)
end

---The eye `u` of the way along a move from `start` to `eye`: a straight line, or when `spline`,
---a Catmull-Rom shaped by the neighbouring keyframes' eyes `p0` (before the start) and `p3`
---(after the end). The widget flies this; an editor samples it to draw the path.
---@return number x
---@return number y
---@return number z
function CameraMath.MoveEye(start, eye, p0, p3, spline, u)
	if spline then
		return CameraMath.CatmullRom(p0, start, eye, p3, u)
	end
	return CameraMath.Lerp3(start, eye, u)
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

--------------------------------------------------------------------------------
-- The player's camera modes: what each can show (rts/Game/Camera/*Controller.cpp)
--------------------------------------------------------------------------------

local MAP_MARGIN = 0.01
local EYE_CLEARANCE = 5 -- spring, rot and a clamped fps eye stay this far above ground or water
local MAX_EYE_HEIGHT = 9000 -- rot and a clamped fps eye
local SPRING_MIN_RX = 0.51 * PI
local SPRING_MAX_RX = 0.99 * PI
local SPRING_SWITCH_RX = 0.75 * PI -- what the spring camera tips a level or upward view to
local SPRING_MAX_DISTANCE = 1.333 -- times the longer map side
local ROT_MIN_RX = 0.4999 * PI -- the rot camera's mouse look range
local ROT_MAX_RX = 0.9999 * PI
local TA_MIN_ANGLE = 0.01
local TA_MAX_HEIGHT = 9.5 / 8 -- times the longer map side, in elmos

---@class CameraLimits engine settings the player's camera modes clamp to
---@field mapX number map size in elmos
---@field mapZ number
---@field groundHeight fun(x: number, z: number): number
---@field springFocusHeight (fun(x: number, z: number, distance: number): number)? what the spring camera rests on
---@field cardinalLock boolean? CamSpringLockCardinalDirections
---@field springMinDistance number? CamSpringMinZoomDistance
---@field taMinHeight number? OverheadMinZoomDistance
---@field taMaxHeightFactor number? OverheadMaxHeightFactor
---@field rotClampToMap boolean? RotOverheadClampMap
---@field fpsClampPos boolean? FPSClampPos

local function clamp(value, low, high)
	return max(low, min(high, value))
end

---CGround::GetHeightAboveWater, with the water at 0.
local function heightAboveWater(limits, x, z)
	return max(0.0, limits.groundHeight(x, z))
end

local function clampToMap(limits, x, z)
	return clamp(x, MAP_MARGIN, limits.mapX - MAP_MARGIN), clamp(z, MAP_MARGIN, limits.mapZ - MAP_MARGIN)
end

---Where a ground-point camera looking from the eye along f rests: the first hit on the surface,
---else `maxDistance` along.
---@return number x
---@return number z
---@return number distance
local function restingPoint(pose, fx, fy, fz, heightFn, maxDistance)
	local hx, hy, hz = CameraMath.GroundIntersection(pose.x, pose.y, pose.z, fx, fy, fz, heightFn, maxDistance)
	if not hx then
		return pose.x + fx * maxDistance, pose.z + fz * maxDistance, maxDistance
	end
	local dx, dy, dz = pose.x - hx, pose.y - hy, pose.z - hz
	return hx, hz, sqrt(dx * dx + dy * dy + dz * dz)
end

local function shownPose(x, y, z, rx, ry, fov)
	return { x = x, y = y, z = z, rx = rx, ry = ry, roll = 0, fov = fov }
end

local function fpsState(pose, limits)
	local x, y, z = pose.x, pose.y, pose.z
	if limits.fpsClampPos ~= false then
		x, z = clampToMap(limits, x, z)
		y = clamp(y, heightAboveWater(limits, x, z) + EYE_CLEARANCE, MAX_EYE_HEIGHT)
	end
	local fx, fy, fz = CameraMath.FwdFromRot(pose.rx, pose.ry)
	local state = { name = "fps", mode = 0, px = x, py = y, pz = z, dx = fx, dy = fy, dz = fz }
	state.rx, state.ry, state.rz, state.fov = pose.rx, pose.ry, 0, pose.fov
	return state, shownPose(x, y, z, pose.rx, pose.ry, pose.fov)
end

local function rotState(pose, limits)
	local x, z = pose.x, pose.z
	if limits.rotClampToMap == false then
		x = clamp(x, -limits.mapX, 2 * limits.mapX - MAP_MARGIN)
		z = clamp(z, -limits.mapZ, 2 * limits.mapZ - MAP_MARGIN)
	else
		x, z = clampToMap(limits, x, z)
	end
	local y = clamp(pose.y, heightAboveWater(limits, x, z) + EYE_CLEARANCE, MAX_EYE_HEIGHT)
	local rx = clamp(pose.rx, ROT_MIN_RX, ROT_MAX_RX)
	local state = { name = "rot", mode = 3, px = x, py = y, pz = z, rx = rx, ry = pose.ry, rz = 0, fov = pose.fov }
	return state, shownPose(x, y, z, rx, pose.ry, pose.fov)
end

local function springState(pose, limits)
	-- the spring camera's own switch tips a level or upward view to 45 degrees down
	local rx = pose.rx <= HALFPI and SPRING_SWITCH_RX or clamp(pose.rx, SPRING_MIN_RX, SPRING_MAX_RX)
	local fx, fy, fz = CameraMath.FwdFromRot(rx, pose.ry)
	local maxDistance = max(limits.mapX, limits.mapZ) * SPRING_MAX_DISTANCE
	local px, pz, distance = restingPoint(pose, fx, fy, fz, limits.groundHeight, maxDistance)
	px, pz = clampToMap(limits, px, pz)
	distance = clamp(distance, max(limits.springMinDistance or 20, 0.1), maxDistance)
	local focusHeight = limits.springFocusHeight
	local py = focusHeight and focusHeight(px, pz, distance) or limits.groundHeight(px, pz)

	local ex, ez = px - fx * distance, pz - fz * distance
	local ey = max(py - fy * distance, heightAboveWater(limits, ex, ez) + EYE_CLEARANCE)
	local ry = limits.cardinalLock and CameraMath.RawYawForAzimuth(pose.ry) or pose.ry
	local state = { name = "spring", mode = 2, px = px, py = py, pz = pz, dist = distance }
	state.rx, state.ry, state.rz, state.fov = rx, ry, 0, pose.fov
	return state, shownPose(ex, ey, ez, rx, pose.ry, pose.fov)
end

local function overheadState(pose, limits)
	-- looks along +-z only, with the angle counted from straight down; an upward view is tipped
	-- down the way the ta camera's own switch does it
	local rx = pose.rx
	if rx < HALFPI then
		local s = sin(rx)
		rx = acos(-0.5 / sqrt(s * s + 0.25))
	end
	local angle = clamp(PI - rx, TA_MIN_ANGLE, HALFPI)
	local flipped = cos(pose.ry) < 0 -- facing +z, the bottom of the map
	local fx, fy, fz = 0, -cos(angle), flipped and sin(angle) or -sin(angle)
	local maxHeight = max(limits.mapX, limits.mapZ) * TA_MAX_HEIGHT * (limits.taMaxHeightFactor or 1)
	local function surface(x, z)
		return heightAboveWater(limits, x, z)
	end
	local px, pz, height = restingPoint(pose, fx, fy, fz, surface, maxHeight)
	px, pz = clampToMap(limits, px, pz)
	height = clamp(height, max(limits.taMinHeight or 60, 0.1), maxHeight)
	local py = surface(px, pz)

	local state = { name = "ta", mode = 1, px = px, py = py, pz = pz, height = height, angle = angle }
	state.flipped, state.fov = flipped and 1 or -1, pose.fov
	local ex, ey, ez = px - fx * height, py - fy * height, pz - fz * height
	return state, shownPose(ex, ey, ez, PI - angle, flipped and PI or 0, pose.fov)
end

local function freeState(pose, previousState, limits)
	local state = {}
	for key, value in pairs(previousState) do
		state[key] = value
	end
	local y = pose.y
	local ground = limits.groundHeight(pose.x, pose.z)
	local offset = previousState.gndOffset or 0
	if offset < 0 then
		y = ground - offset
	elseif (previousState.gndLock or 0) > 0 and (previousState.gravity or 0) >= 0 then
		y = ground + offset
	elseif offset > 0 then
		y = max(y, ground + offset)
	end
	local fx, fy, fz = CameraMath.FwdFromRot(pose.rx, pose.ry)
	state.px, state.py, state.pz, state.dx, state.dy, state.dz = pose.x, y, pose.z, fx, fy, fz
	state.rx, state.ry, state.rz, state.fov = HALFPI - pose.rx, PI - pose.ry, 0, pose.fov -- the free camera's own angles
	state.vx, state.vy, state.vz, state.avx, state.avy, state.avz = 0, 0, 0, 0, 0, 0
	return state, shownPose(pose.x, y, pose.z, pose.rx, pose.ry, pose.fov)
end

---A Spring.SetCameraState table that shows `pose` in the camera mode of `previousState` as near
---as that mode can, and the pose that state really shows. Each mode keeps its own limits (pitch
---range, the spring and ta cameras' zoom range and ground point, height above ground and water),
---so a hand-over can ease into the second pose first and then switch without a jump. The player's
---cameras have no roll. Nil for modes without a free eye (overview, dolly).
---@param pose { x: number, y: number, z: number, rx: number, ry: number, fov: number }
---@param previousState table a Spring.GetCameraState() table
---@param limits CameraLimits
---@return table? state
---@return { x: number, y: number, z: number, rx: number, ry: number, roll: number, fov: number }? shown
function CameraMath.StateFromPose(pose, previousState, limits)
	local mode = previousState.mode
	if mode == 0 then
		return fpsState(pose, limits)
	elseif mode == 1 then
		return overheadState(pose, limits)
	elseif mode == 2 then
		return springState(pose, limits)
	elseif mode == 3 then
		return rotState(pose, limits)
	elseif mode == 4 then
		return freeState(pose, previousState, limits)
	end
	return nil, nil
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
