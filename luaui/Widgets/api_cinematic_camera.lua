local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Cinematic Camera API",
		desc = "Scripted camera sequences, follow and orbit shots, shake, and save/restore of the player's camera",
		date = "October 2026",
		license = "GNU GPL, v2 or later",
		layer = -99000,
		enabled = true,
		modalExempt = true, -- engine keybinds still run under an open window, so the overview guard must too
	}
end

--[[
	WG.cinematicCamera:
		Play(sequence)        keyframed sequence, see the shapes below
		SamplePath(sequence, samplesPerMove, start)   the eye path Play would fly, for drawing it
		Follow(params)        point at a target and follow it
		Orbit(params)         circle a target
		Restore(params)       blend back to a saved camera and hand control back
		Shake(params)         shake the view; concurrent shakes add up
		Save(slot)            remember the player's camera under a name ("default")
		Stop()                hand control back where the camera is, in the player's camera mode
		IsActive(), IsShaking(), GetPlayerCameraState()

	Play, Follow, Orbit, Restore and Shake check their params first: they return true when the
	shot started, else log what is wrong and return false, leaving the camera alone. A shot ends
	by handing the camera back, except a hold ending and a follow without a duration: those last
	until Stop or the next shot, and once the game is over they end as a release.

	Units: seconds, elmos, degrees (pitch 0 = level, 90 = straight down; yaw is a compass
	bearing, 0 = toward the top of the map; roll; vertical fov).

	target   = { x, y, z } or { unitIDs = {...} } (the centroid of the units still alive), with
	           optional offset = { x, y, z } and relativeToHeading (offset turns with the unit);
	           lastX/lastY/lastZ hold where the units were last seen (the widget writes them,
	           a caller may seed them)
	keyframe = { position = target, lookAt = target?, pitch?, yaw?, roll?, fov?, duration?, hold?,
	             easing?, path = "linear" | "spline" }
	           (path shapes the eye's move and, when the previous keyframe has a lookAt too, the
	            sweep of the point looked at between the two; a hold, and a hold ending, stay on the
	            keyframe and keep riding and looking at its units)
	sequence = { keyframes = {...}, ending = "release" | "restore" | "hold", restoreSlot?,
	             restoreDuration?, restoreEasing?, releaseDuration?, releaseEasing?, onKeyframe? }
	           (release eases roll, fov and whatever the player's camera mode cannot show back
	            over releaseDuration, then that mode takes over at the same spot; restore blends
	            back to a saved camera)
	follow   = { target, distance?, pitch?, yaw?, duration? (none: until stopped), transitionDuration?,
	             easing?, smoothing?, fov?, ending?, restoreSlot?, restoreDuration?, restoreEasing? }
	           (easing shapes the lead-in blend only; smoothing is the trailing lag: the gap to the
	            target halves every `smoothing` seconds, 0 = rigid)
	orbit    = { target, distance?, pitch?, startYaw?, degrees?, duration?, transitionDuration?,
	             easing?, fov?, ending?, ... }
	           (both start moving at once; the first transitionDuration seconds blend the current
	            view into the moving shot, which lasts at least that long)
	restore  = { slot?, duration?, easing? }
	shake    = { magnitude, duration?, rampUp?, falloff?, frequency?, rotationMagnitude? }

	All of them take clock = "real" | "game". Sequence, follow, orbit and restore take
	onEnd(reason), called once when the shot is over: "finished" (its ending handed the camera
	back), "held" (a hold ending began), "replaced" (another shot took over) or "stopped" (Stop).
	A sequence's onKeyframe(index) is called as the camera reaches each keyframe. Callbacks run
	once the frame's camera is set, so they may start the next shot.

	The camera is driven every frame as the engine's fps camera with its position clamp lifted
	(FPSClampPos overlay), since the engine's own transitions cannot be timed in BAR's default
	transition mode. While it is, unit tracking is off and keys bound to the overview toggle or to
	tracking are swallowed: either would take the camera from the shot. Timing is real time by
	default, so sequences also play while the game is paused; an open menu window pauses them where
	the widget handler can say so (IsAnyWindowOpen, which comes with the player input lock; without
	it nothing pauses). clock = "game" runs a shot, its ending included, on game time instead: it
	stops with the game, follows the game speed and stays in step with game-time triggers.
]]

local CameraMath = VFS.Include("common/camera_math.lua")

local spGetCameraState = Spring.GetCameraState
local spSetCameraState = Spring.SetCameraState
local spGetCameraPosition = Spring.GetCameraPosition
local spGetCameraRotation = Spring.GetCameraRotation
local spGetCameraFOV = Spring.GetCameraFOV
local spSetCameraOffset = Spring.SetCameraOffset
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitHeading = Spring.GetUnitHeading
local spGetGroundHeight = Spring.GetGroundHeight
local spGetSmoothMeshHeight = Spring.GetSmoothMeshHeight
local spGetConfigInt = Spring.GetConfigInt
local spGetConfigFloat = Spring.GetConfigFloat
local spSetConfigInt = Spring.SetConfigInt
local spSendCommands = Spring.SendCommands
local spGetGameSecondsInterpolated = Spring.GetGameSecondsInterpolated

local Easings = CameraMath.Easings
local FwdFromRot = CameraMath.FwdFromRot
local LookAtRotation = CameraMath.LookAtRotation
local EyeFromTarget = CameraMath.EyeFromTarget
local LerpAngle = CameraMath.LerpAngle

local sin, cos, tan, rad = math.sin, math.cos, math.tan, math.rad
local HALFPI = math.pi * 0.5

local FPS_CAMERA_MODE = 0
local CLAMP_CONFIG = "FPSClampPos"
local DEFAULT_SLOT = "default"

local DEFAULTS = {
	keyframeDuration = 2,
	pathSamples = 16, -- SamplePath points per move
	easing = CameraMath.DEFAULT_EASING,
	ending = "release",
	releaseDuration = 1.5,
	restoreDuration = 2,
	distance = 600,
	pitch = 45,
	yaw = 0,
	transitionDuration = 2,
	smoothing = 0.25,
	orbitDegrees = 360,
	orbitDuration = 10,
	shakeDuration = 1,
	shakeRampUp = 0.1,
	shakeFalloff = 0.5,
	shakeFrequency = 20,
	shakeRotationFactor = 0.05, -- degrees of tilt per elmo of magnitude
}

local ENDINGS = { release = true, restore = true, hold = true } ---@type table<string, boolean>
local CLOCKS = { real = true, game = true } ---@type table<string, boolean>

-- Actions that would take the camera from a shot: the overview toggle (which also stacks the fps
-- mode the shot runs in, for the player's next toggle to pop them into) and unit tracking (which
-- moves the camera after every Update).
local GUARDED_ACTIONS = { toggleoverview = true, track = true } ---@type table<string, boolean>

-- A shake jitters at its frequency plus a faster, fainter overtone, so it reads as a rattle
-- rather than a slow wobble. The two bands are scaled so their sum stays within the magnitude.
local SHAKE_OVERTONE_RATE = 2.7
local SHAKE_OVERTONE_WEIGHT = 0.5
local SHAKE_BAND_SCALE = 1 / (1 + SHAKE_OVERTONE_WEIGHT)

---@class CinematicPose
---@field x number
---@field y number
---@field z number
---@field rx number inclination, engine convention (pi/2 level, pi straight down)
---@field ry number azimuth
---@field roll number wanted screen roll, radians
---@field fov number vertical fov, degrees

---@class CinematicSnapshot the player's camera as it was taken over
---@field state table Spring.GetCameraState() then
---@field pose CinematicPose the rendered camera then
---@field clampPos integer the FPSClampPos setting then

---@class CinematicShot the callbacks of the shot on the timeline
---@field onEnd fun(reason: string)?
---@field onKeyframe fun(index: integer)?
---@field ended boolean?

---@class CinematicControl a running sequence
---@field snapshot CinematicSnapshot
---@field segments table[]
---@field index integer
---@field elapsed number
---@field pose CinematicPose the pose shown last
---@field clock string? "game" to run on game time, else real time
---@field shot CinematicShot?

---@type CinematicControl?
local control
local slots = {} ---@type table<string, { state: table, pose: CinematicPose }>
local shakes = {} ---@type table<integer, table> active shakes, see Shake()
local shakeOffsetApplied = false
local shakeSeed = 0
local gameOver = false
local lastGameSeconds ---@type number?
local notifications = {} ---@type table<integer, { fn: function, arg: any }>

--------------------------------------------------------------------------------
-- Poses
--------------------------------------------------------------------------------

---@return CinematicPose
local function renderedPose()
	local x, y, z = spGetCameraPosition()
	local rx, ry = spGetCameraRotation()
	return { x = x, y = y, z = z, rx = rx, ry = ry, roll = 0, fov = spGetCameraFOV() }
end

---@param pose CinematicPose
---@return CinematicPose
local function copyPose(pose)
	return { x = pose.x, y = pose.y, z = pose.z, rx = pose.rx, ry = pose.ry, roll = pose.roll, fov = pose.fov }
end

---@param a CinematicPose
---@param b CinematicPose
---@return CinematicPose
local function blendPoses(a, b, t)
	return {
		x = a.x + (b.x - a.x) * t,
		y = a.y + (b.y - a.y) * t,
		z = a.z + (b.z - a.z) * t,
		rx = a.rx + (b.rx - a.rx) * t,
		ry = LerpAngle(a.ry, b.ry, t),
		roll = a.roll + (b.roll - a.roll) * t,
		fov = a.fov + (b.fov - a.fov) * t,
	}
end

---@param pose CinematicPose
local function applyPose(pose)
	local fx, fy, fz = FwdFromRot(pose.rx, pose.ry)
	spSetCameraState({
		name = "fps",
		mode = FPS_CAMERA_MODE,
		px = pose.x,
		py = pose.y,
		pz = pose.z,
		dx = fx,
		dy = fy,
		dz = fz,
		rx = pose.rx,
		ry = pose.ry,
		rz = CameraMath.CompensatedRoll(pose.roll, pose.rx),
		fov = pose.fov,
	}, 0)
end

-- widgetHandler:IsAnyWindowOpen() arrives with the player input lock; older handlers never pause.
local function windowOpen()
	return widgetHandler.IsAnyWindowOpen ~= nil and widgetHandler:IsAnyWindowOpen() == true
end

--------------------------------------------------------------------------------
-- Callbacks: queued while the timeline moves and run once it is settled, so a callback may
-- start the next shot
--------------------------------------------------------------------------------

local function notify(fn, arg)
	if fn then
		notifications[#notifications + 1] = { fn = fn, arg = arg }
	end
end

---@param shot CinematicShot?
local function endShot(shot, reason)
	if shot and not shot.ended then
		shot.ended = true
		notify(shot.onEnd, reason)
	end
end

local function runNotifications()
	while #notifications > 0 do
		local entry = table.remove(notifications, 1)
		local ok, err = pcall(entry.fn, entry.arg)
		if not ok then
			Spring.Log(widget:GetInfo().name, LOG.ERROR, "camera callback failed: " .. tostring(err))
		end
	end
end

--------------------------------------------------------------------------------
-- Checks: a shot is checked whole before it takes the camera, so a bad one never holds it
--------------------------------------------------------------------------------

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

---What is wrong with the optional numbers `keys` of `params`, or nil.
local function badNumbers(params, keys, where)
	for i = 1, #keys do
		local value = params[keys[i]]
		if value ~= nil and not finite(value) then
			return (where or "") .. keys[i] .. " must be a number"
		end
	end
end

---What is wrong with the optional durations `keys` of `params` (seconds, 0 or more), or nil.
local function badDurations(params, keys, where)
	for i = 1, #keys do
		local value = params[keys[i]]
		if value ~= nil and not (finite(value) and value >= 0) then
			return (where or "") .. keys[i] .. " must be a number of seconds, 0 or more"
		end
	end
end

local function badTarget(target, where)
	if type(target) ~= "table" then
		return where .. " must be a table"
	elseif target.unitIDs ~= nil then
		if type(target.unitIDs) ~= "table" then
			return where .. ".unitIDs must be a list of unit IDs"
		end
	elseif not (finite(target.x) and finite(target.y) and finite(target.z)) then
		return where .. " needs x, y and z, or unitIDs"
	end
end

---The fields every shot may take: its clock and callbacks.
local function badCommon(params)
	if params.clock ~= nil and not CLOCKS[params.clock] then
		return 'clock must be "real" or "game"'
	elseif params.onEnd ~= nil and type(params.onEnd) ~= "function" then
		return "onEnd must be a function"
	end
end

---The fields of a shot that ends: how it hands the camera back.
local function badEnding(params)
	if params.ending ~= nil and not ENDINGS[params.ending] then
		return 'ending must be "release", "restore" or "hold"'
	end
	return badDurations(params, { "transitionDuration", "releaseDuration", "restoreDuration" }) or badCommon(params)
end

local function badSequence(sequence)
	if type(sequence) ~= "table" then
		return "expected a sequence table"
	end
	local keyframes = sequence.keyframes
	if type(keyframes) ~= "table" or #keyframes == 0 then
		return "keyframes must be a list of at least one keyframe"
	end
	for i = 1, #keyframes do
		local keyframe = keyframes[i]
		local where = "keyframes[" .. i .. "]"
		if type(keyframe) ~= "table" then
			return where .. " must be a table"
		end
		local problem = keyframe.position ~= nil and badTarget(keyframe.position, where .. ".position")
			or keyframe.lookAt ~= nil and badTarget(keyframe.lookAt, where .. ".lookAt")
			or badNumbers(keyframe, { "pitch", "yaw", "roll", "fov" }, where .. ".")
			or badDurations(keyframe, { "duration", "hold" }, where .. ".")
		if problem then
			return problem
		end
	end
	if sequence.onKeyframe ~= nil and type(sequence.onKeyframe) ~= "function" then
		return "onKeyframe must be a function"
	end
	return badEnding(sequence)
end

---@param numbers string[]
---@param durations string[]
local function badShot(params, numbers, durations)
	if type(params) ~= "table" then
		return "expected a params table"
	end
	return badTarget(params.target, "target")
		or badNumbers(params, numbers)
		or badDurations(params, durations)
		or badEnding(params)
end

---Logs why `api` left the camera alone.
---@return false
local function rejected(api, problem)
	Spring.Log(widget:GetInfo().name, LOG.WARNING, api .. ": " .. problem .. "; the camera was left alone")
	return false
end

--------------------------------------------------------------------------------
-- Targets
--------------------------------------------------------------------------------

---A target's point right now: a position, or the centroid of its units in view. Units out of
---view leave the target where it was last seen; a target never seen at all has no point (nil),
---and a shot aimed at it holds its view rather than swinging to the map origin.
---@return number? x
---@return number? y
---@return number? z
local function resolveTarget(target)
	if not target then
		return nil
	end
	local x, y, z
	local unitIDs = target.unitIDs
	if unitIDs then
		local n = 0
		local sx, sy, sz = 0.0, 0.0, 0.0
		for i = 1, #unitIDs do
			local ux, uy, uz = spGetUnitPosition(unitIDs[i])
			if ux then
				n, sx, sy, sz = n + 1, sx + ux, sy + uy, sz + uz
			end
		end
		if n > 0 then
			x, y, z = sx / n, sy / n, sz / n
			target.lastX, target.lastY, target.lastZ = x, y, z
		elseif target.lastX then
			x, y, z = target.lastX, target.lastY, target.lastZ
		else
			return nil
		end
	else
		x, y, z = target.x, target.y, target.z
	end

	local offset = target.offset
	if offset then
		local ox, oy, oz = offset.x or 0, offset.y or 0, offset.z or 0
		if target.relativeToHeading and unitIDs and unitIDs[1] then
			-- offset z along the unit's front (sin h, cos h) and x along its right (-cos h, sin h),
			-- the engine's frontdir and rightdir for a heading h
			local h = spGetUnitHeading(unitIDs[1], true) or target.lastHeading or 0
			target.lastHeading = h -- a dead or hidden unit keeps its last heading
			local sh, ch = sin(h), cos(h)
			ox, oz = oz * sh - ox * ch, oz * ch + ox * sh
		end
		x, y, z = x + ox, y + oy, z + oz
	end
	return x, y, z
end

---@return number inclination radians, from degrees of pitch below level
local function pitchRad(degrees)
	return HALFPI + rad(degrees)
end

--------------------------------------------------------------------------------
-- Segments: each yields a pose for its local time, starting from the pose it was entered with.
-- duration nil = runs until replaced.
--------------------------------------------------------------------------------

local function easingFor(name)
	return Easings[name] or Easings[DEFAULTS.easing]
end

---Where a keyframe's eye is right now; `fallback` when it has no position or its target was
---never seen.
---@param fallback { x: number, y: number, z: number }
local function keyframeEye(keyframe, fallback)
	if not keyframe.position then
		return fallback
	end
	local x, y, z = resolveTarget(keyframe.position)
	if not (x and y and z) then
		return fallback
	end
	return { x = x, y = y, z = z }
end

---The eyes a move interpolates between: the keyframe's own, and the neighbours' as spline
---anchors (the start pose and the keyframe's eye stand in at the ends of the sequence).
local function moveEyes(keyframe, beforePrevious, following, start)
	local eye = keyframeEye(keyframe, start)
	local p0 = beforePrevious and keyframeEye(beforePrevious, start) or start
	local p3 = following and keyframeEye(following, eye) or eye
	return eye, p0, p3
end

---Panning from one look-at target to the next sweeps the point looked at between them, along
---the same kind of path as the eye: straight, or a spline through the neighbouring keyframes'
---look-at points (the two ends stand in where a neighbour has none).
---@return number? x
---@return number? y
---@return number? z
local function panPoint(fromTarget, toTarget, beforeTarget, afterTarget, spline, u)
	local ax, ay, az = resolveTarget(fromTarget)
	local bx, by, bz = resolveTarget(toTarget)
	if not (ax and ay and az and bx and by and bz) then
		return nil
	end
	local from, to = { x = ax, y = ay, z = az }, { x = bx, y = by, z = bz }
	local p0, p3 = from, to
	if spline then
		local px, py, pz = resolveTarget(beforeTarget)
		if px and py and pz then
			p0 = { x = px, y = py, z = pz }
		end
		local nx, ny, nz = resolveTarget(afterTarget)
		if nx and ny and nz then
			p3 = { x = nx, y = ny, z = nz }
		end
	end
	return CameraMath.MoveEye(from, to, p0, p3, spline, u)
end

---Where a keyframe looks from `eye`: at its target, or in its own pitch and yaw, each of which
---is inherited from the previous pose when left out.
---@param inherited CinematicPose
local function keyframeRotation(keyframe, eye, inherited)
	if keyframe.lookAt then
		local tx, ty, tz = resolveTarget(keyframe.lookAt)
		if tx and ty and tz then
			return LookAtRotation(eye.x, eye.y, eye.z, tx, ty, tz, inherited.ry)
		end
	end
	local rx = keyframe.pitch and pitchRad(keyframe.pitch) or inherited.rx
	local ry = keyframe.yaw and rad(keyframe.yaw) or inherited.ry
	return rx, ry
end

---The move to keyframe `index`.
local function moveSegment(index, keyframe, previous, beforePrevious, following)
	local duration = keyframe.duration or DEFAULTS.keyframeDuration
	local ease = easingFor(keyframe.easing)
	local spline = keyframe.path == "spline"
	local segment = { duration = duration, keyframe = index }

	function segment.enter(self, startPose)
		self.start = copyPose(startPose)
	end

	function segment.evaluate(self, t)
		local start = self.start
		local u = duration > 0 and ease(t / duration) or 1
		local eye, p0, p3 = moveEyes(keyframe, beforePrevious, following, start)
		local x, y, z = CameraMath.MoveEye(start, eye, p0, p3, spline, u)

		local rx, ry
		if keyframe.lookAt and previous and previous.lookAt then
			local lx, ly, lz = panPoint(
				previous.lookAt,
				keyframe.lookAt,
				beforePrevious and beforePrevious.lookAt,
				following and following.lookAt,
				spline,
				u
			)
			if lx then
				rx, ry = LookAtRotation(x, y, z, lx, ly, lz, self.ry or start.ry)
			end
		end
		if not rx then
			-- aimed from where the eye is now: the blend into the keyframe's direction ends on target
			local toRx, toRy = keyframeRotation(keyframe, { x = x, y = y, z = z }, start)
			rx = start.rx + (toRx - start.rx) * u
			ry = LerpAngle(start.ry, toRy, u)
		end
		self.ry = ry -- the yaw to keep while the pan passes straight above or below the eye

		local roll = rad(keyframe.roll or 0)
		local fov = keyframe.fov or start.fov
		return {
			x = x,
			y = y,
			z = z,
			rx = rx,
			ry = ry,
			roll = start.roll + (roll - start.roll) * u,
			fov = start.fov + (fov - start.fov) * u,
		}
	end

	return segment
end

---Stays on a keyframe's `move` at its end, so units it rides or looks at are still followed;
---without one, keeps the pose it was entered with.
local function holdSegment(duration, move)
	local segment = { duration = duration }
	function segment.enter(self, startPose)
		self.start = copyPose(startPose)
	end
	function segment.evaluate(self)
		if move then
			return move:evaluate(move.duration)
		end
		return self.start
	end
	return segment
end

---Shared by follow and orbit. The shot runs from the moment the segment starts; over the first
---`transitionDuration` seconds the view blends from the entry pose into the already moving
---shot, so the hand-over has no kink. `blendEasing` shapes that blend (nil: the default).
local function shotSegment(params, duration, shotPose, blendEasing)
	local transition = params.transitionDuration or DEFAULTS.transitionDuration
	local segment = { duration = duration and math.max(duration, transition) or nil }

	function segment.enter(self, startPose)
		self.start = copyPose(startPose)
		self.fov = params.fov or startPose.fov
	end

	function segment.evaluate(self, t)
		local pose = shotPose(self, t)
		if t < transition then
			return blendPoses(self.start, pose, easingFor(blendEasing)(t / transition))
		end
		return pose
	end

	return segment
end

local function followSegment(params)
	local target = params.target
	local distance = params.distance or DEFAULTS.distance
	local pitch = rad(params.pitch or DEFAULTS.pitch)
	local yaw = rad(params.yaw or DEFAULTS.yaw)
	local smoothing = params.smoothing or DEFAULTS.smoothing
	local smoothed ---@type { x: number, y: number, z: number }?

	local function shotPose(self, _)
		local tx, ty, tz = resolveTarget(target)
		if not (tx and ty and tz) then
			return self.start -- nothing to follow yet: hold the view
		end
		if not smoothed then
			smoothed = { x = tx, y = ty, z = tz }
		elseif smoothing > 0 and self.dt then
			local alpha = 1 - 0.5 ^ (self.dt / smoothing)
			smoothed.x = smoothed.x + (tx - smoothed.x) * alpha
			smoothed.y = smoothed.y + (ty - smoothed.y) * alpha
			smoothed.z = smoothed.z + (tz - smoothed.z) * alpha
		else
			smoothed.x, smoothed.y, smoothed.z = tx, ty, tz
		end
		local ex, ey, ez, rx, ry = EyeFromTarget(smoothed.x, smoothed.y, smoothed.z, pitch, yaw, distance)
		return { x = ex, y = ey, z = ez, rx = rx, ry = ry, roll = 0, fov = self.fov }
	end

	-- no duration: until stopped
	return shotSegment(params, params.duration, shotPose, params.easing)
end

local function orbitSegment(params)
	local target = params.target
	local distance = params.distance or DEFAULTS.distance
	local pitch = params.pitch or DEFAULTS.pitch
	local degrees = params.degrees or DEFAULTS.orbitDegrees
	local duration = params.duration or DEFAULTS.orbitDuration
	local ease = easingFor(params.easing)
	local startYaw ---@type number?

	local function shotPose(self, t)
		local tx, ty, tz = resolveTarget(target)
		if not (tx and ty and tz) then
			return self.start -- nothing to circle: hold the view
		end
		if not startYaw then
			if params.startYaw then
				startYaw = rad(params.startYaw)
			else
				-- the bearing the camera already has toward the target: the orbit starts from here
				local _, ry = LookAtRotation(self.start.x, self.start.y, self.start.z, tx, ty, tz, self.start.ry)
				startYaw = ry
			end
		end
		local u = duration > 0 and ease(math.min(1, t / duration)) or 1
		local yaw = startYaw + rad(degrees) * u
		local ex, ey, ez, rx, ry = EyeFromTarget(tx, ty, tz, rad(pitch), yaw, distance)
		return { x = ex, y = ey, z = ez, rx = rx, ry = ry, roll = 0, fov = self.fov }
	end

	return shotSegment(params, duration, shotPose)
end

--------------------------------------------------------------------------------
-- Control: taking the camera over and giving it back
--------------------------------------------------------------------------------

---The running sequence, started from the player's camera when there was none.
---@return CinematicControl
local function takeControl()
	local running = control
	if running then
		return running
	end
	local pose = renderedPose()
	running = {
		snapshot = { state = spGetCameraState(), pose = copyPose(pose), clampPos = spGetConfigInt(CLAMP_CONFIG, 1) },
		segments = {},
		index = 1,
		elapsed = 0,
		pose = pose,
	}
	control = running
	-- the engine reads the overlay on its next config flush, so the first frame may still be clamped
	spSetConfigInt(CLAMP_CONFIG, 0, true)
	spSendCommands("track off") -- the unit tracker moves the camera after every Update
	return running
end

---Hands the camera back, in `state` (a Spring.SetCameraState table) when given, and ends the
---shot for `reason` (none: without callbacks).
---@param running CinematicControl
---@param state table?
---@param reason string?
local function releaseControl(running, state, reason)
	control = nil
	if state then
		spSetCameraState(state, 0)
	end
	spSetConfigInt(CLAMP_CONFIG, running.snapshot.clampPos, true)
	if reason then
		endShot(running.shot, reason)
	end
end

---What the player's camera modes clamp to.
---@param running CinematicControl
---@return CameraLimits
local function cameraLimits(running)
	local limits = {
		mapX = Game.mapSizeX,
		mapZ = Game.mapSizeZ,
		groundHeight = spGetGroundHeight,
		cardinalLock = spGetConfigInt("CamSpringLockCardinalDirections", 1) == 1,
		springMinDistance = spGetConfigFloat("CamSpringMinZoomDistance", 20),
		taMinHeight = spGetConfigFloat("OverheadMinZoomDistance", 60),
		taMaxHeightFactor = spGetConfigFloat("OverheadMaxHeightFactor", 1),
		rotClampToMap = spGetConfigInt("RotOverheadClampMap", 1) == 1,
		fpsClampPos = running.snapshot.clampPos == 1,
	}
	if spGetConfigInt("CamSpringTrackMapHeightMode", 1) == 2 then
		-- the smooth mesh, faded to the ground at close zoom (CSpringController::GetFocusSurfaceHeight)
		local near = spGetConfigFloat("CamSpringSmoothMeshBlendMinDist", 150)
		local far = math.max(spGetConfigFloat("CamSpringSmoothMeshBlendMaxDist", 600), near + 1)
		limits.springFocusHeight = function(x, z, distance)
			local ground = spGetGroundHeight(x, z)
			local t = math.min(1, math.max(0, (distance - near) / (far - near)))
			return ground + (spGetSmoothMeshHeight(x, z) - ground) * t * t * (3 - 2 * t)
		end
	end
	return limits
end

---The player's camera mode, in the player's own fov, as near `pose` as that mode can show: the
---state to hand back in, and the pose it shows. The overview shows no free eye: there it is the
---camera taken over.
---@param running CinematicControl
---@param pose CinematicPose
---@return table state
---@return CinematicPose shown
local function releaseTarget(running, pose)
	local wanted = copyPose(pose)
	wanted.fov = running.snapshot.pose.fov
	local state, shown = CameraMath.StateFromPose(wanted, running.snapshot.state, cameraLimits(running))
	if state and shown then
		return state, shown
	end
	return running.snapshot.state, copyPose(running.snapshot.pose)
end

---The camera saved under `slot`, else the one the running sequence took over.
---@param slot string?
---@return { state: table, pose: CinematicPose }?
local function savedCamera(slot)
	local running = control
	return slots[slot or DEFAULT_SLOT] or (running and running.snapshot) or nil
end

---Blends to a saved camera's pose, then switches to its state and gives control back.
local function restoreSegment(saved, duration, easing)
	local ease = easingFor(easing)
	local segment = { duration = duration or DEFAULTS.restoreDuration }
	function segment.enter(self, startPose)
		self.start = copyPose(startPose)
	end
	function segment.evaluate(self, t)
		local u = self.duration > 0 and ease(t / self.duration) or 1
		return blendPoses(self.start, saved.pose, u)
	end
	function segment.finish()
		local running = control
		if running then
			releaseControl(running, saved.state, "finished")
		end
	end
	return segment
end

---Hands the camera back where it is. The player's camera mode has no roll, its own fov and its
---own limits (see CameraMath.StateFromPose), so the view first eases into what that mode will
---show, and the switch at the end changes nothing on screen.
---@param running CinematicControl
local function releaseSegment(running, duration, easing)
	local ease = easingFor(easing)
	local segment = { duration = duration or DEFAULTS.releaseDuration }
	function segment.enter(self, startPose)
		self.start = copyPose(startPose)
		self.state, self.target = releaseTarget(running, startPose)
	end
	function segment.evaluate(self, t)
		local u = self.duration > 0 and ease(t / self.duration) or 1
		return blendPoses(self.start, self.target, u)
	end
	function segment.finish(self)
		if control == running then
			releaseControl(running, self.state, "finished")
		end
	end
	return segment
end

---What happens after the last shot: the default is handing the camera back where it is.
---@param running CinematicControl
---@param lastMove table? the last keyframe's move, which a hold ending stays on
local function appendEnding(running, segments, params, lastMove)
	local ending = params.ending or DEFAULTS.ending
	if ending == "restore" then
		local saved = savedCamera(params.restoreSlot)
		segments[#segments + 1] = restoreSegment(saved, params.restoreDuration, params.restoreEasing)
	elseif ending == "hold" then
		local hold = holdSegment(nil, lastMove)
		hold.held = true -- the shot is over once it holds
		segments[#segments + 1] = hold
	else
		segments[#segments + 1] = releaseSegment(running, params.releaseDuration, params.releaseEasing)
	end
end

---Puts a new shot on the timeline; the one it replaces is over.
---@param running CinematicControl
local function startTimeline(running, segments, params)
	endShot(running.shot, "replaced")
	running.shot = { onEnd = params.onEnd, onKeyframe = params.onKeyframe }
	running.segments = segments
	running.index = 1
	running.elapsed = 0
	running.clock = params.clock
end

--------------------------------------------------------------------------------
-- Shake
--------------------------------------------------------------------------------

---@param realDt number? nil while an open window holds real time
---@param gameDt number
local function updateShakes(realDt, gameDt)
	local px, py, pz, tx, ty = 0.0, 0.0, 0.0, 0.0, 0.0
	local i = 1
	while i <= #shakes do
		local shake = shakes[i]
		local dt = shake.clock == "game" and gameDt or realDt
		if dt then
			shake.elapsed = shake.elapsed + dt
		end
		if shake.elapsed >= shake.duration then
			table.remove(shakes, i)
		else
			local strength = CameraMath.Envelope(shake.elapsed, shake.duration, shake.rampUp, shake.falloff)
			local noise = shake.noise
			local t = shake.elapsed
			local sample = CameraMath.ValueNoise.Sample
			local function band(axis)
				return (sample(noise[axis], t) + SHAKE_OVERTONE_WEIGHT * sample(noise[axis + 5], t)) * SHAKE_BAND_SCALE
			end
			px = px + shake.magnitude * strength * band(1)
			py = py + shake.magnitude * strength * band(2)
			pz = pz + shake.magnitude * strength * band(3)
			tx = tx + shake.tilt * strength * band(4)
			ty = ty + shake.tilt * strength * band(5)
			i = i + 1
		end
	end
	if #shakes > 0 then
		spSetCameraOffset(px, py, pz, tx, ty)
		shakeOffsetApplied = true
	elseif shakeOffsetApplied then
		spSetCameraOffset()
		shakeOffsetApplied = false
	end
end

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------

local function play(sequence)
	local problem = badSequence(sequence)
	if problem then
		return rejected("Play", problem)
	end
	local running = takeControl()
	local keyframes = sequence.keyframes
	local segments = {}
	local move
	for i = 1, #keyframes do
		local keyframe = keyframes[i]
		move = moveSegment(i, keyframe, keyframes[i - 1], keyframes[i - 2], keyframes[i + 1])
		segments[#segments + 1] = move
		if (keyframe.hold or 0) > 0 then
			segments[#segments + 1] = holdSegment(keyframe.hold, move)
		end
	end
	appendEnding(running, segments, sequence, move)
	startTimeline(running, segments, sequence)
	runNotifications()
	return true
end

---The path a sequence would fly, for drawing it. `points` lie along the eye path, spaced evenly
---in time (`t` seconds from the start, holds included), each with the `lookAt` point panned to
---where the move pans between two look-at keyframes; `keyframes` has one entry per keyframe
---with its eye, its arrival time, `unit` when it rides a unit and, when it looks at something
---that resolves, its `lookAt` point. Unit targets resolve to where the units are now. The first
---move starts from `start` ({ x, y, z }, default the rendered camera), as Play starts from the
---player's view. Takes nothing over; nil (and a logged warning) for a sequence Play would refuse.
---@param sequence table as for Play
---@param samplesPerMove integer? points per move besides its start (default 16)
---@param start { x: number, y: number, z: number }?
---@return { points: table[], keyframes: table[] }?
local function samplePath(sequence, samplesPerMove, start)
	local problem = badSequence(sequence)
	if problem then
		rejected("SamplePath", problem)
		return nil
	end
	local keyframes = sequence.keyframes
	local samples = math.max(1, samplesPerMove or DEFAULTS.pathSamples)
	local from = start and { x = start.x, y = start.y, z = start.z } or renderedPose()
	local points = { { x = from.x, y = from.y, z = from.z, t = 0 } }
	local marks = {}
	local time = 0.0
	for i = 1, #keyframes do
		local keyframe = keyframes[i]
		local duration = keyframe.duration or DEFAULTS.keyframeDuration
		local ease = easingFor(keyframe.easing)
		local spline = keyframe.path == "spline"
		local eye, p0, p3 = moveEyes(keyframe, keyframes[i - 2], keyframes[i + 1], from)
		local previous = keyframes[i - 1]
		local panning = keyframe.lookAt and previous and previous.lookAt
		if duration > 0 then
			for s = 1, samples do
				local u = ease(s / samples)
				local x, y, z = CameraMath.MoveEye(from, eye, p0, p3, spline, u)
				local point = { x = x, y = y, z = z, t = time + duration * s / samples }
				if panning then
					local lx, ly, lz = panPoint(
						previous.lookAt,
						keyframe.lookAt,
						keyframes[i - 2] and keyframes[i - 2].lookAt,
						keyframes[i + 1] and keyframes[i + 1].lookAt,
						spline,
						u
					)
					if lx then
						point.lookAt = { x = lx, y = ly, z = lz }
					end
				end
				points[#points + 1] = point
			end
		else
			points[#points + 1] = { x = eye.x, y = eye.y, z = eye.z, t = time }
		end
		time = time + duration
		local position = keyframe.position
		local mark = { x = eye.x, y = eye.y, z = eye.z, t = time, unit = position ~= nil and position.unitIDs ~= nil }
		if keyframe.lookAt then
			local lx, ly, lz = resolveTarget(keyframe.lookAt)
			if lx then
				mark.lookAt = { x = lx, y = ly, z = lz }
			end
		end
		marks[#marks + 1] = mark
		time = time + (keyframe.hold or 0)
		from = eye
	end
	return { points = points, keyframes = marks }
end

local function follow(params)
	local problem = badShot(params, { "distance", "pitch", "yaw", "fov" }, { "duration", "smoothing" })
	if problem then
		return rejected("Follow", problem)
	end
	local running = takeControl()
	local segments = { followSegment(params) }
	if params.duration then
		appendEnding(running, segments, params)
	end
	startTimeline(running, segments, params)
	runNotifications()
	return true
end

local function orbit(params)
	local problem = badShot(params, { "distance", "pitch", "startYaw", "degrees", "fov" }, { "duration" })
	if problem then
		return rejected("Orbit", problem)
	end
	local running = takeControl()
	local segments = { orbitSegment(params) }
	appendEnding(running, segments, params)
	startTimeline(running, segments, params)
	runNotifications()
	return true
end

local function shake(params)
	local problem
	if type(params) ~= "table" then
		problem = "expected a params table"
	elseif not finite(params.magnitude) then
		problem = "magnitude must be a number"
	else
		problem = badNumbers(params, { "frequency", "rotationMagnitude" })
			or badDurations(params, { "duration", "rampUp", "falloff" })
			or badCommon(params)
	end
	if problem then
		return rejected("Shake", problem)
	end
	local magnitude = params.magnitude
	local frequency = params.frequency or DEFAULTS.shakeFrequency
	local tiltDegrees = params.rotationMagnitude or magnitude * DEFAULTS.shakeRotationFactor
	local noise = {}
	for i = 1, 5 do
		shakeSeed = shakeSeed + 2
		noise[i] = CameraMath.ValueNoise.new(frequency, shakeSeed)
		noise[i + 5] = CameraMath.ValueNoise.new(frequency * SHAKE_OVERTONE_RATE, shakeSeed + 1)
	end
	shakes[#shakes + 1] = {
		magnitude = magnitude,
		tilt = tan(rad(tiltDegrees)),
		duration = params.duration or DEFAULTS.shakeDuration,
		rampUp = params.rampUp or DEFAULTS.shakeRampUp,
		falloff = params.falloff or DEFAULTS.shakeFalloff,
		elapsed = 0,
		noise = noise,
		clock = params.clock,
	}
	return true
end

---Remembers the player's camera: during a sequence that is the camera the sequence took over.
local function save(slot)
	local running = control
	slots[slot or DEFAULT_SLOT] = {
		state = running and running.snapshot.state or spGetCameraState(),
		pose = running and copyPose(running.snapshot.pose) or renderedPose(),
	}
end

local function restore(params)
	params = params or {}
	local problem
	if type(params) ~= "table" then
		problem = "expected a params table"
	elseif params.slot ~= nil and type(params.slot) ~= "string" then
		problem = "slot must be a string"
	else
		problem = badDurations(params, { "duration" }) or badCommon(params)
	end
	if problem then
		return rejected("Restore", problem)
	end
	local slot = params.slot
	local saved = savedCamera(slot)
	if (slot and not slots[slot]) or not saved then
		Spring.Log(
			widget:GetInfo().name,
			LOG.WARNING,
			"No camera saved as '"
				.. tostring(slot or DEFAULT_SLOT)
				.. "'"
				.. (saved and ", restoring the camera the sequence took over instead" or "")
		)
	end
	if not saved then
		return false
	end
	local running = takeControl()
	startTimeline(running, { restoreSegment(saved, params.duration, params.easing) }, params)
	runNotifications()
	return true
end

local function stop()
	local running = control
	if running then
		local state = releaseTarget(running, running.pose)
		releaseControl(running, state, "stopped")
	end
	shakes = {}
	if shakeOffsetApplied then
		spSetCameraOffset()
		shakeOffsetApplied = false
	end
	runNotifications()
end

local function isActive()
	return control ~= nil
end

local function isShaking()
	return #shakes > 0
end

local function getPlayerCameraState()
	local running = control
	return running and running.snapshot.state or nil
end

--------------------------------------------------------------------------------
-- Call-ins
--------------------------------------------------------------------------------

---Seconds of game time since the last call, interpolated between sim frames; none while paused.
local function gameStep()
	local now = spGetGameSecondsInterpolated()
	local step = lastGameSeconds and math.max(0, now - lastGameSeconds) or 0
	lastGameSeconds = now
	return step
end

---Moves the running timeline on by `dt` seconds of its clock.
---@param running CinematicControl
local function advance(running, dt)
	running.elapsed = running.elapsed + dt
	local segments = running.segments
	while control do
		local segment = segments[running.index]
		if not segment then
			break -- past the last segment: keep showing the last pose
		end
		if gameOver and not segment.duration then
			-- a shot without an end gives the camera back once the game is over
			if segment.entered then
				running.elapsed = 0
			end
			segment = releaseSegment(running)
			segments[running.index] = segment
		end
		if not segment.entered then
			segment.entered = true
			segment:enter(running.pose)
			if segment.held then
				endShot(running.shot, "held")
			end
		end
		segment.dt = dt
		local t = running.elapsed
		if segment.duration and t >= segment.duration then
			running.pose = segment:evaluate(segment.duration)
			running.elapsed = t - segment.duration
			running.index = running.index + 1
			if segment.keyframe and running.shot then
				notify(running.shot.onKeyframe, segment.keyframe)
			end
			if segment.finish then
				segment:finish() -- may release control
			end
		else
			running.pose = segment:evaluate(t)
			break
		end
	end
end

function widget:Update(dt)
	local gameDt = gameStep()
	local realDt = not windowOpen() and dt or nil -- an open window holds what runs on real time

	if #shakes > 0 or shakeOffsetApplied then
		updateShakes(realDt, gameDt)
	end
	local running = control
	if running then
		local step = running.clock == "game" and gameDt or realDt
		if step then
			advance(running, step)
		end
		if control == running then
			applyPose(running.pose)
		end
	end
	runNotifications()
end

function widget:KeyPress(_, _, _, _, _, _, actions)
	if control and actions then
		for i = 1, #actions do
			if GUARDED_ACTIONS[actions[i].command] then
				return true
			end
		end
	end
	return false
end

function widget:GameOver()
	gameOver = true
end

function widget:Initialize()
	WG.cinematicCamera = {
		Play = play,
		SamplePath = samplePath,
		Follow = follow,
		Orbit = orbit,
		Shake = shake,
		Save = save,
		Restore = restore,
		Stop = stop,
		IsActive = isActive,
		IsShaking = isShaking,
		GetPlayerCameraState = getPlayerCameraState,
	}
end

function widget:Shutdown()
	local running = control
	if running then
		releaseControl(running, running.snapshot.state)
	end
	notifications = {}
	if shakeOffsetApplied then
		spSetCameraOffset()
	end
	WG.cinematicCamera = nil
end
