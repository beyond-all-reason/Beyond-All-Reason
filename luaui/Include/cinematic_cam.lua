--- CINEMATIC CAM's maths: a free camera for framing a view.
---
--- Pure (plus common/camera_math.lua): a pose and the pose it glides to, moved by one frame's
--- input. A pose is { x, y, z, rx, ry, fov }: rx pi/2 = level, pi = straight down, ry a compass
--- bearing in radians (0 looks toward -z).

local CameraMath = VFS.Include("common/camera_math.lua")

local Cam = {}

local TWOPI = math.pi * 2
local HALFPI = math.pi / 2

-- How long the pose takes to catch its target (a critically damped spring).
Cam.SMOOTH = 0.15
-- Radians a pixel of right-drag turns the view.
Cam.LOOK_RATE = 0.004
-- Fly speed: elmos a second per elmo of height above the ground, never under MIN_SPEED.
Cam.SPEED_PER_HEIGHT = 0.5
Cam.MIN_SPEED = 60
-- The height the fly speed reads glides this slowly, so bumpy ground does not jolt the step.
Cam.CRUISE_SMOOTH = 0.6
-- A narrower lens slows the fly, the look and the orbit with it, never below this share.
Cam.MIN_ZOOM_SCALE = 0.3
Cam.FAST, Cam.SLOW = 4, 0.25
-- Never quite straight up or down: the view's yaw is lost there.
Cam.MIN_RX, Cam.MAX_RX = 0.05, math.pi - 0.05
Cam.DEFAULT_FOV = 45
-- The lowest the eye stands over the ground.
Cam.FLOOR = 40
-- The eye flies no higher over the ground than this many times the map's longer side.
Cam.CEILING_PER_SIDE = 1.5

---@class CinematicCamPose
---@field x number
---@field y number
---@field z number
---@field rx number
---@field ry number
---@field fov number

---@class CinematicCamState
---@field pose CinematicCamPose the pose shown
---@field target CinematicCamPose the pose it glides to
---@field velocity CinematicCamPose
---@field flyScale number
---@field lookScale number
---@field hold number? HOLD HEIGHT's height over the ground
---@field cruise number?
---@field cruiseVelocity number?
---@field pivotDistance number?

---@alias CinematicCamGround fun(x: number, z: number): number

--- How much the lens slows things: 1 at the default lens, less zoomed in, more zoomed out.
function Cam.zoomScale(fov)
	return math.max(Cam.MIN_ZOOM_SCALE, (tonumber(fov) or Cam.DEFAULT_FOV) / Cam.DEFAULT_FOV)
end

-- The fly keys of each scheme by SDL scancode, so WASD sits where it is on any layout;
-- `symbol` finds the engine's keycode, `code` stands in when it has none.
---@type table<string, { keys: table<integer, { move: string, sign: integer, symbol: string, code: integer }>, help: string }>
Cam.KEY_SCHEMES = {
	wasd = {
		keys = {
			[26] = { move = "forward", sign = 1, symbol = "sc_w", code = 119 },
			[22] = { move = "forward", sign = -1, symbol = "sc_s", code = 115 },
			[7] = { move = "right", sign = 1, symbol = "sc_d", code = 100 },
			[4] = { move = "right", sign = -1, symbol = "sc_a", code = 97 },
			[8] = { move = "up", sign = 1, symbol = "sc_e", code = 101 },
			[20] = { move = "up", sign = -1, symbol = "sc_q", code = 113 },
		},
		help = "W A S D fly, Q / E down and up",
	},
	arrows = {
		keys = {
			[82] = { move = "forward", sign = 1, symbol = "sc_up", code = 273 },
			[81] = { move = "forward", sign = -1, symbol = "sc_down", code = 274 },
			[79] = { move = "right", sign = 1, symbol = "sc_right", code = 275 },
			[80] = { move = "right", sign = -1, symbol = "sc_left", code = 276 },
			[75] = { move = "up", sign = 1, symbol = "sc_pageup", code = 280 },
			[78] = { move = "up", sign = -1, symbol = "sc_pagedown", code = 281 },
		},
		help = "Arrows fly, Page Down / Page Up down and up",
	},
	numpad = {
		keys = {
			[96] = { move = "forward", sign = 1, symbol = "sc_numpad8", code = 264 },
			[90] = { move = "forward", sign = -1, symbol = "sc_numpad2", code = 258 },
			[94] = { move = "right", sign = 1, symbol = "sc_numpad6", code = 262 },
			[92] = { move = "right", sign = -1, symbol = "sc_numpad4", code = 260 },
			[97] = { move = "up", sign = 1, symbol = "sc_numpad9", code = 265 },
			[95] = { move = "up", sign = -1, symbol = "sc_numpad7", code = 263 },
		},
		help = "Numpad 8 4 2 6 fly, 7 / 9 down and up",
	},
}
Cam.KEY_SCHEME_NAMES = { "wasd", "arrows", "numpad" }

--- The scheme of that name and the name; WASD for an unknown one.
function Cam.keyScheme(name)
	if Cam.KEY_SCHEMES[name] then
		return Cam.KEY_SCHEMES[name], name
	end
	return Cam.KEY_SCHEMES.wasd, "wasd"
end

--- The step's moves from the scancodes held; opposite keys cancel.
function Cam.keyMoves(scheme, held)
	local out = {}
	for scan in pairs(held) do
		local key = scheme.keys[scan]
		if key then
			out[key.move] = (out[key.move] or 0) + key.sign
		end
	end
	return out
end

local function wrap(angle)
	angle = angle % TWOPI
	if angle > math.pi then
		angle = angle - TWOPI
	end
	return angle
end

--- One step of a critically damped spring toward `target`: the value and its new velocity.
function Cam.smoothDamp(current, target, velocity, smoothTime, dt)
	smoothTime = math.max(0.0001, smoothTime)
	local omega = 2 / smoothTime
	local x = omega * dt
	local decay = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
	local change = current - target
	local temp = (velocity + omega * change) * dt
	velocity = (velocity - omega * temp) * decay
	local value = target + (change + temp) * decay
	-- Never past the target.
	if (target - current > 0) == (value > target) then
		value = target
		velocity = 0
	end
	return value, velocity
end

---@return CinematicCamPose
local function copyPose(pose)
	return { x = pose.x, y = pose.y, z = pose.z, rx = pose.rx, ry = pose.ry, fov = pose.fov or Cam.DEFAULT_FOV }
end

--- A pose from the camera as the engine shows it: its position, direction and fov.
---@return CinematicCamPose
function Cam.poseFrom(px, py, pz, dx, dy, dz, fov)
	local rx, ry = CameraMath.RotFromDir(dx, dy, dz)
	return { x = px, y = py, z = pz, rx = rx, ry = ry, fov = fov or Cam.DEFAULT_FOV }
end

--- The camera's state from where it is: the pose shown and the target it glides to.
---@param pose CinematicCamPose
---@return CinematicCamState
function Cam.new(pose)
	return {
		pose = copyPose(pose),
		target = copyPose(pose),
		velocity = { x = 0, y = 0, z = 0, rx = 0, ry = 0, fov = 0 },
		flyScale = 1,
		lookScale = 1,
	}
end

local map ---@type { w: number, h: number }?

--- The map's size: the ceiling and HOME come from it; nil forgets it.
function Cam.setBounds(width, height)
	map = width and height and { w = width, h = height } or nil
end

--- The eye stands no lower than the floor and no higher than the ceiling.
local function lift(pose, groundHeight)
	local floor = (tonumber(groundHeight(pose.x, pose.z)) or 0) + Cam.FLOOR
	pose.y = math.max(pose.y, floor)
	if map then
		pose.y = math.min(pose.y, floor + Cam.CEILING_PER_SIDE * math.max(map.w, map.h))
	end
end

--- The fly speed now, elmos a second: grows with height and the lens, Shift x4, Ctrl x0.25.
---@param state CinematicCamState
function Cam.flySpeed(state, fast, slow)
	local scale = (fast and Cam.FAST or 1)
		* (slow and Cam.SLOW or 1)
		* Cam.zoomScale(state.pose.fov)
		* (state.flyScale or 1)
	return math.max(Cam.MIN_SPEED, (state.cruise or 0) * Cam.SPEED_PER_HEIGHT) * scale
end

--- One frame of input moves the target, and the pose glides after it. `input`: forward,
--- right, up (each -1..1), fast, slow, lookX, lookY (pixels of drag this frame).
---@param state CinematicCamState
---@param input table?
---@param dt number
---@param groundHeight CinematicCamGround
---@return CinematicCamPose
function Cam.step(state, input, dt, groundHeight)
	input = input or {}
	local target, pose, velocity = state.target, state.pose, state.velocity
	local lookScale = (input.slow and Cam.SLOW or 1) * Cam.zoomScale(pose.fov) * (state.lookScale or 1)
	target.ry = target.ry + (tonumber(input.lookX) or 0) * Cam.LOOK_RATE * lookScale
	target.rx =
		math.max(Cam.MIN_RX, math.min(Cam.MAX_RX, target.rx + (tonumber(input.lookY) or 0) * Cam.LOOK_RATE * lookScale))

	local height = target.y - (tonumber(groundHeight(target.x, target.z)) or 0)
	if not state.cruise then
		state.cruise, state.cruiseVelocity = height, 0
	elseif dt > 0 then
		state.cruise, state.cruiseVelocity =
			Cam.smoothDamp(state.cruise, height, state.cruiseVelocity, Cam.CRUISE_SMOOTH, dt)
	end
	local speed = Cam.flySpeed(state, input.fast, input.slow) * dt
	-- Flat along the view, whatever the pitch: W never dives into the ground.
	local fx, fz = math.sin(target.ry), -math.cos(target.ry)
	local forward, right, up = tonumber(input.forward) or 0, tonumber(input.right) or 0, tonumber(input.up) or 0
	target.x = target.x + (fx * forward - fz * right) * speed
	target.z = target.z + (fz * forward + fx * right) * speed
	if state.hold then
		state.hold = math.max(Cam.FLOOR, state.hold + up * speed)
		target.y = (tonumber(groundHeight(target.x, target.z)) or 0) + state.hold
	else
		target.y = target.y + up * speed
	end
	lift(target, groundHeight)

	if dt > 0 then
		local smooth = Cam.SMOOTH
		pose.x, velocity.x = Cam.smoothDamp(pose.x, target.x, velocity.x, smooth, dt)
		pose.y, velocity.y = Cam.smoothDamp(pose.y, target.y, velocity.y, smooth, dt)
		pose.z, velocity.z = Cam.smoothDamp(pose.z, target.z, velocity.z, smooth, dt)
		pose.rx, velocity.rx = Cam.smoothDamp(pose.rx, target.rx, velocity.rx, smooth, dt)
		-- The yaw the short way round.
		local goal = pose.ry + wrap(target.ry - pose.ry)
		pose.ry, velocity.ry = Cam.smoothDamp(pose.ry, goal, velocity.ry, smooth, dt)
		pose.fov, velocity.fov = Cam.smoothDamp(pose.fov, target.fov, velocity.fov, smooth, dt)
	end
	lift(pose, groundHeight)
	return pose
end

--- Whether the pose has caught its target.
---@param state CinematicCamState
function Cam.settled(state, epsilon)
	epsilon = epsilon or 0.5
	local pose, target = state.pose, state.target
	return math.abs(pose.x - target.x) < epsilon
		and math.abs(pose.y - target.y) < epsilon
		and math.abs(pose.z - target.z) < epsilon
		and math.abs(pose.rx - target.rx) < 0.001
		and math.abs(wrap(pose.ry - target.ry)) < 0.001
		and math.abs(pose.fov - target.fov) < 0.05
end

-- The pivot (what the wheel dollies to and a middle-drag circles) sits on the view line: where
-- the view meets the ground, at most PIVOT_MAX out; over the sky, the distance the last one had.
Cam.AIM_FAR, Cam.PIVOT_MAX, Cam.PIVOT_DISTANCE = 20000, 6000, 3000
-- A wheel notch keeps this share of the distance to the pivot; Shift and Ctrl the same.
Cam.DOLLY_STEP, Cam.DOLLY_FAST, Cam.DOLLY_SLOW = 0.8, 0.5, 0.95
Cam.DOLLY_MIN = 30
-- Radians a pixel of middle-drag orbits; the eye stays between these over the pivot.
Cam.ORBIT_RATE = 0.006
Cam.MIN_ELEVATION, Cam.MAX_ELEVATION = 0.03, 1.5
-- Lens: degrees a notch (Ctrl: one), and its range: 5 is near isometric, 90 the widest.
Cam.LENS_STEP, Cam.MIN_FOV, Cam.MAX_FOV = 5, 5, 90

--- Where the middle of the view meets the ground, on or off the map, or nil over the sky.
function Cam.aimPoint(pose, groundHeight)
	local fx, fy, fz = CameraMath.FwdFromRot(pose.rx, pose.ry)
	local x, y, z = CameraMath.GroundIntersection(pose.x, pose.y, pose.z, fx, fy, fz, groundHeight, Cam.AIM_FAR)
	if not x then
		return nil
	end
	return { x = x, y = y, z = z }
end

--- The pivot on the target view's line, its distance remembered so a dolly or an orbit never jumps.
---@param state CinematicCamState
function Cam.pivot(state, groundHeight)
	local target = state.target
	local fx, fy, fz = CameraMath.FwdFromRot(target.rx, target.ry)
	local hit = Cam.aimPoint(target, groundHeight)
	local distance = state.pivotDistance or Cam.PIVOT_DISTANCE
	if hit then
		distance = math.sqrt((hit.x - target.x) ^ 2 + (hit.y - target.y) ^ 2 + (hit.z - target.z) ^ 2)
	end
	distance = math.max(Cam.DOLLY_MIN, math.min(Cam.PIVOT_MAX, distance))
	state.pivotDistance = distance
	return { x = target.x + fx * distance, y = target.y + fy * distance, z = target.z + fz * distance }
end

--- The wheel: `notches` toward the pivot (negative: away), along the view.
---@param state CinematicCamState
function Cam.dolly(state, notches, groundHeight, fast, slow)
	local target = state.target
	local aim = Cam.pivot(state, groundHeight)
	local fx, fy, fz = CameraMath.FwdFromRot(target.rx, target.ry)
	local step = fast and Cam.DOLLY_FAST or slow and Cam.DOLLY_SLOW or Cam.DOLLY_STEP
	local wanted = math.max(Cam.DOLLY_MIN, (state.pivotDistance or Cam.PIVOT_DISTANCE) * step ^ notches)
	target.x, target.y, target.z = aim.x - fx * wanted, aim.y - fy * wanted, aim.z - fz * wanted
	state.pivotDistance = wanted
	lift(target, groundHeight)
end

--- A middle-drag: the eye circles `pivot` at its distance, looking at it. `dx` right circles
--- to the camera's right, `dy` up lowers the eye.
---@param state CinematicCamState
function Cam.orbit(state, pivot, dx, dy, groundHeight, slow)
	local target = state.target
	local rate = Cam.ORBIT_RATE * (slow and Cam.SLOW or 1) * Cam.zoomScale(state.pose.fov) * (state.lookScale or 1)
	local ox, oy, oz = target.x - pivot.x, target.y - pivot.y, target.z - pivot.z
	local flat = math.sqrt(ox * ox + oz * oz)
	local distance = math.max(Cam.DOLLY_MIN, math.sqrt(flat * flat + oy * oy))
	local azimuth = math.atan2(ox, oz) + (tonumber(dx) or 0) * rate
	local elevation = math.atan2(oy, math.max(flat, 0.001)) - (tonumber(dy) or 0) * rate
	elevation = math.max(Cam.MIN_ELEVATION, math.min(Cam.MAX_ELEVATION, elevation))
	target.x = pivot.x + distance * math.cos(elevation) * math.sin(azimuth)
	target.z = pivot.z + distance * math.cos(elevation) * math.cos(azimuth)
	target.y = pivot.y + distance * math.sin(elevation)
	lift(target, groundHeight)
	local rx, ry = CameraMath.LookAtRotation(target.x, target.y, target.z, pivot.x, pivot.y, pivot.z)
	target.rx = math.max(Cam.MIN_RX, math.min(Cam.MAX_RX, rx))
	target.ry = target.ry + wrap(ry - target.ry)
end

--- Elmos a pixel of PAN slides the eye, so the ground `distance` out stays under the pointer.
function Cam.panScale(distance, fov, viewHeight)
	local far = math.max(Cam.DOLLY_MIN, tonumber(distance) or 0)
	return 2 * far * math.tan(math.rad(tonumber(fov) or Cam.DEFAULT_FOV) / 2) / math.max(1, tonumber(viewHeight) or 1)
end

--- A middle-drag set to PAN: the eye slides in its own plane, no turn.
---@param state CinematicCamState
function Cam.pan(state, dx, dy, elmosPerPixel, groundHeight)
	local target = state.target
	local fx, fy, fz = CameraMath.FwdFromRot(target.rx, target.ry)
	local rx, rz = math.cos(target.ry), math.sin(target.ry)
	-- Screen up: the camera's right crossed with its forward.
	local ux, uy, uz = -rz * fy, rz * fx - rx * fz, rx * fy
	local e = tonumber(elmosPerPixel) or 1
	dx, dy = (tonumber(dx) or 0) * e, (tonumber(dy) or 0) * e
	target.x = target.x - rx * dx - ux * dy
	target.y = target.y - uy * dy
	target.z = target.z - rz * dx - uz * dy
	lift(target, groundHeight)
end

--- A wheel turn as the game camera takes it: 1 toward the view, -1 away.
function Cam.wheelNotches(up, scrollWheelSpeed)
	local turn = up and 1 or -1
	return (turn * (tonumber(scrollWheelSpeed) or 25) > 0) and 1 or -1
end

--- Alt+wheel: `notches` narrower (negative: wider), in degrees.
---@param state CinematicCamState
function Cam.lens(state, notches, slow)
	local step = slow and 1 or Cam.LENS_STEP
	local fov = (tonumber(state.target.fov) or Cam.DEFAULT_FOV) - notches * step
	state.target.fov = math.max(Cam.MIN_FOV, math.min(Cam.MAX_FOV, fov))
end

local LEVEL_STEP = math.rad(5)

--- HOLD HEIGHT on (the height over the ground it has now) or off.
---@param state CinematicCamState
function Cam.setHold(state, on, groundHeight)
	local target = state.target
	state.hold = on and math.max(Cam.FLOOR, target.y - (tonumber(groundHeight(target.x, target.z)) or 0)) or nil
end

--- The pitch to the nearest 5 degrees.
---@param state CinematicCamState
function Cam.level(state)
	local target = state.target
	local down = math.floor((target.rx - HALFPI) / LEVEL_STEP + 0.5) * LEVEL_STEP
	target.rx = math.max(Cam.MIN_RX, math.min(Cam.MAX_RX, HALFPI + down))
end

--- A pose's numbers for a readout: height over the ground, pitch down, compass yaw, lens.
function Cam.readout(pose, groundHeight)
	return {
		x = math.floor(pose.x + 0.5),
		z = math.floor(pose.z + 0.5),
		height = math.floor(pose.y - (tonumber(groundHeight(pose.x, pose.z)) or 0) + 0.5),
		pitch = math.floor(math.deg(pose.rx - HALFPI) + 0.5),
		yaw = math.floor(math.deg(pose.ry) % 360 + 0.5) % 360,
		lens = math.floor((pose.fov or Cam.DEFAULT_FOV) + 0.5),
	}
end

Cam.SAVED_VIEWS = 9

--- What a saved view keeps of a pose.
---@return CinematicCamPose
function Cam.viewOf(pose)
	return copyPose(pose)
end

--- Fly to `view` (a pose) as a fly glides; `snap` lands at once.
---@param state CinematicCamState
function Cam.jump(state, view, snap)
	local target, pose, velocity = state.target, state.pose, state.velocity
	target.x = tonumber(view.x) or target.x
	target.y = tonumber(view.y) or target.y
	target.z = tonumber(view.z) or target.z
	target.rx = tonumber(view.rx) or target.rx
	target.fov = tonumber(view.fov) or target.fov
	target.ry = target.ry + wrap((tonumber(view.ry) or target.ry) - target.ry)
	state.hold = nil
	if snap then
		for key, value in pairs(target) do
			pose[key] = value
			velocity[key] = 0
		end
	end
end

-- HOME: over the map's middle, this share of its longer side up, looking down this steeply.
Cam.HOME_HEIGHT_PER_SIDE, Cam.HOME_PITCH = 0.6, math.rad(60)

--- Fly back over the map's middle, looking north and down at it. False with no map known.
---@param state CinematicCamState
function Cam.home(state, groundHeight)
	if not map then
		return false
	end
	local height = math.max(map.w, map.h) * Cam.HOME_HEIGHT_PER_SIDE
	local x, z = map.w / 2, map.h / 2 + height / math.tan(Cam.HOME_PITCH)
	local y = (tonumber(groundHeight(x, z)) or 0) + height
	Cam.jump(state, { x = x, y = y, z = z, rx = HALFPI + Cam.HOME_PITCH, ry = 0, fov = state.target.fov })
	return true
end

--- GUIDES on a `width` x `height` box at `ox`, `oy`: the 16:9 frame in its middle and its
--- thirds. { frame = { x0, y0, x1, y1 }, lines = { { x0, y0, x1, y1 }... } }.
function Cam.guides(width, height, ox, oy)
	local w, h = width, width * 9 / 16
	if h > height then
		h, w = height, height * 16 / 9
	end
	local x0, y0 = (ox or 0) + (width - w) / 2, (oy or 0) + (height - h) / 2
	local x1, y1 = x0 + w, y0 + h
	local lines = {}
	for n = 1, 2 do
		local x, y = x0 + w * n / 3, y0 + h * n / 3
		lines[#lines + 1] = { x, y0, x, y1 }
		lines[#lines + 1] = { x0, y, x1, y }
	end
	return { frame = { x0, y0, x1, y1 }, lines = lines }
end

--- The camera state Spring.SetCameraState takes for a pose: the fps camera.
function Cam.cameraState(pose)
	local fx, fy, fz = CameraMath.FwdFromRot(pose.rx, pose.ry)
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
		rz = 0,
		fov = pose.fov,
	}
end

return Cam
