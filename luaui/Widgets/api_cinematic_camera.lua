local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Cinematic Camera API",
		desc = "Scripted camera sequences, follow and orbit shots, shake, and save/restore of the player's camera",
		date = "October 2026",
		license = "GNU GPL, v2 or later",
		layer = -99000,
		enabled = true,
	}
end

--[[
	WG.cinematicCamera:
		Play(sequence)        keyframed sequence, see the shapes below
		Follow(params)        point at a target and follow it
		Orbit(params)         circle a target
		Shake(params)         shake the view; concurrent shakes add up
		Save(slot)            remember the player's camera under a name ("default")
		Restore(slot, duration, easing)   blend back to a saved camera and hand control back
		Stop()                hand control back where the camera is, in the player's camera mode
		IsActive(), IsShaking(), GetPlayerCameraState()

	Units: seconds, elmos, degrees (pitch 0 = level, 90 = straight down; yaw is a compass
	bearing, 0 = toward the top of the map; roll; vertical fov).

	target   = { x, y, z } or { unitIDs = {...} } (the centroid of the units still alive), with
	           optional offset = { x, y, z } and relativeToHeading (offset turns with the unit)
	keyframe = { position = target, lookAt = target?, pitch?, yaw?, roll?, fov?, duration?, hold?,
	             easing?, path = "linear" | "spline" }
	sequence = { keyframes = {...}, onEnd = "release" | "restore" | "hold", restoreSlot?,
	             restoreDuration?, restoreEasing?, releaseDuration?, releaseEasing? }
	           (release eases roll and fov back over releaseDuration before the player's camera
	            mode takes over at the same spot; restore blends back to a saved camera)
	follow   = { target, distance?, pitch?, yaw?, duration? (0: until stopped), transitionDuration?,
	             easing?, smoothing?, fov?, onEnd?, restoreSlot?, restoreDuration?, restoreEasing? }
	orbit    = { target, distance?, pitch?, startYaw?, degrees?, duration?, transitionDuration?,
	             easing?, fov?, onEnd?, ... }
	           (both start moving at once; the first transitionDuration seconds blend the current
	            view into the moving shot)
	shake    = { magnitude, duration?, rampUp?, falloff?, frequency?, rotationMagnitude? }

	The camera is driven every frame as the engine's fps camera with its position clamp lifted
	(FPSClampPos overlay), since the engine's own transitions cannot be timed in BAR's default
	transition mode. Timing is real time, so sequences also play while the game is paused; an
	open menu window pauses them.
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
local spGetConfigInt = Spring.GetConfigInt
local spSetConfigInt = Spring.SetConfigInt

local Easings = CameraMath.Easings
local FwdFromRot = CameraMath.FwdFromRot
local LookAtRotation = CameraMath.LookAtRotation
local EyeFromTarget = CameraMath.EyeFromTarget
local LerpAngle = CameraMath.LerpAngle

local sin, cos, tan, rad = math.sin, math.cos, math.tan, math.rad
local HALFPI = math.pi * 0.5

local FPS_CAMERA_MODE = 0
local CLAMP_CONFIG = "FPSClampPos"
local CARDINAL_LOCK_CONFIG = "CamSpringLockCardinalDirections"
local DEFAULT_SLOT = "default"

local DEFAULTS = {
	keyframeDuration = 2,
	easing = CameraMath.DEFAULT_EASING,
	onEnd = "release",
	releaseDuration = 1.5,
	restoreDuration = 2,
	distance = 600,
	pitch = 45,
	yaw = 0,
	transitionDuration = 2,
	smoothing = 0.25,
	orbitDegrees = 360,
	orbitDuration = 10,
	orbitEasing = "inOutCubic",
	shakeDuration = 1,
	shakeRampUp = 0.1,
	shakeFalloff = 0.5,
	shakeFrequency = 20,
	shakeRotationFactor = 0.05, -- degrees of tilt per elmo of magnitude
}

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

---@class CinematicControl a running sequence
---@field snapshot CinematicSnapshot
---@field segments table[]
---@field index integer
---@field elapsed number
---@field pose CinematicPose the pose shown last

---@type CinematicControl?
local control
local slots = {} ---@type table<string, { state: table, pose: CinematicPose }>
local shakes = {} ---@type table<integer, table> active shakes, see Shake()
local shakeOffsetApplied = false
local shakeSeed = 0

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

local function windowOpen()
	return widgetHandler.IsAnyWindowOpen ~= nil and widgetHandler:IsAnyWindowOpen() == true
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
			-- offset x to the unit's right, z to its front
			local h = spGetUnitHeading(unitIDs[1], true) or 0
			local sh, ch = sin(h), cos(h)
			ox, oz = ox * ch + oz * sh, oz * ch - ox * sh
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

---Where a keyframe's eye is right now; `fallback` when its target was never seen.
---@param fallback { x: number, y: number, z: number }
local function keyframeEye(keyframe, fallback)
	local x, y, z = resolveTarget(keyframe.position)
	if not (x and y and z) then
		return fallback
	end
	return { x = x, y = y, z = z }
end

---Panning from one look-at target to the next sweeps the point looked at between them.
---@return number? rx
---@return number? ry
local function panRotation(x, y, z, fromTarget, toTarget, u)
	local ax, ay, az = resolveTarget(fromTarget)
	local bx, by, bz = resolveTarget(toTarget)
	if not (ax and ay and az and bx and by and bz) then
		return nil
	end
	return LookAtRotation(x, y, z, ax + (bx - ax) * u, ay + (by - ay) * u, az + (bz - az) * u)
end

---Where a keyframe looks from its eye: at its target, in its fixed direction, or where the
---previous pose looked.
---@param inherited CinematicPose
local function keyframeRotation(keyframe, eye, inherited)
	if keyframe.lookAt then
		local tx, ty, tz = resolveTarget(keyframe.lookAt)
		if tx and ty and tz then
			return LookAtRotation(eye.x, eye.y, eye.z, tx, ty, tz)
		end
	elseif keyframe.pitch or keyframe.yaw then
		return pitchRad(keyframe.pitch or DEFAULTS.pitch), rad(keyframe.yaw or DEFAULTS.yaw)
	end
	return inherited.rx, inherited.ry
end

local function moveSegment(keyframe, previous, beforePrevious, following)
	local duration = keyframe.duration or DEFAULTS.keyframeDuration
	local ease = easingFor(keyframe.easing)
	local spline = keyframe.path == "spline"
	local segment = { duration = duration }

	function segment.enter(self, startPose)
		self.start = copyPose(startPose)
	end

	function segment.evaluate(self, t)
		local start = self.start
		local u = duration > 0 and ease(t / duration) or 1
		local eye = keyframeEye(keyframe, start)

		local x, y, z
		if spline then
			local p0 = beforePrevious and keyframeEye(beforePrevious, start) or start
			local p3 = following and keyframeEye(following, eye) or eye
			x, y, z = CameraMath.CatmullRom(p0, start, eye, p3, u)
		else
			x, y, z = CameraMath.Lerp3(start, eye, u)
		end

		local rx, ry
		if keyframe.lookAt and previous and previous.lookAt then
			rx, ry = panRotation(x, y, z, previous.lookAt, keyframe.lookAt, u)
		end
		if not rx then
			local toRx, toRy = keyframeRotation(keyframe, eye, start)
			rx = start.rx + (toRx - start.rx) * u
			ry = LerpAngle(start.ry, toRy, u)
		end

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

local function holdSegment(duration)
	local segment = { duration = duration }
	function segment.enter(self, startPose)
		self.start = copyPose(startPose)
	end
	function segment.evaluate(self)
		return self.start
	end
	return segment
end

---Shared by follow and orbit. The shot runs from the moment the segment starts; over the first
---`transitionDuration` seconds the view blends from the entry pose into the already moving
---shot, so the hand-over has no kink.
local function shotSegment(params, duration, shotPose)
	local transition = params.transitionDuration or DEFAULTS.transitionDuration
	local segment = { duration = duration and math.max(duration, transition) or nil }

	function segment.enter(self, startPose)
		self.start = copyPose(startPose)
		self.fov = params.fov or startPose.fov
	end

	function segment.evaluate(self, t)
		local pose = shotPose(self, t)
		if t < transition then
			return blendPoses(self.start, pose, easingFor(DEFAULTS.easing)(t / transition))
		end
		return pose
	end

	return segment
end

local function followSegment(params)
	local target = params.target
	local distance = params.distance or DEFAULTS.distance
	local pitch = pitchRad(params.pitch or DEFAULTS.pitch)
	local yaw = rad(params.yaw or DEFAULTS.yaw)
	local smoothing = params.smoothing or DEFAULTS.smoothing
	local untilStopped = (params.duration or 0) <= 0
	local duration = not untilStopped and params.duration or nil
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
		local ex, ey, ez, rx, ry = EyeFromTarget(smoothed.x, smoothed.y, smoothed.z, pitch - HALFPI, yaw, distance)
		return { x = ex, y = ey, z = ez, rx = rx, ry = ry, roll = 0, fov = self.fov }
	end

	return shotSegment(params, duration, shotPose), untilStopped
end

local function orbitSegment(params)
	local target = params.target
	local distance = params.distance or DEFAULTS.distance
	local pitch = params.pitch or DEFAULTS.pitch
	local degrees = params.degrees or DEFAULTS.orbitDegrees
	local duration = params.duration or DEFAULTS.orbitDuration
	local ease = easingFor(params.easing or DEFAULTS.orbitEasing)
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
				local _, ry = LookAtRotation(self.start.x, self.start.y, self.start.z, tx, ty, tz)
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
	spSetConfigInt(CLAMP_CONFIG, 0, true)
	return running
end

---Hands the camera back, in `state` (a Spring.SetCameraState table) when given.
---@param running CinematicControl
---@param state table?
local function releaseControl(running, state)
	control = nil
	if state then
		spSetCameraState(state, 0)
	end
	spSetConfigInt(CLAMP_CONFIG, running.snapshot.clampPos, true)
end

---The player's camera mode, showing what the sequence last showed.
---@param running CinematicControl
local function releaseInPlaceState(running)
	local cardinalLock = spGetConfigInt(CARDINAL_LOCK_CONFIG, 1) == 1
	return CameraMath.StateFromPose(running.pose, running.snapshot.state, spGetGroundHeight, cardinalLock)
		or running.snapshot.state
end

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
			releaseControl(running, saved.state)
		end
	end
	return segment
end

---Hands the camera back where it is. The player's camera has no roll and keeps its own fov, so
---those ease out first; the mode switch at the end then changes nothing the eye can see.
---@param running CinematicControl
local function releaseSegment(running, duration, easing)
	local ease = easingFor(easing)
	local segment = { duration = duration or DEFAULTS.releaseDuration }
	function segment.enter(self, startPose)
		self.start = copyPose(startPose)
		self.target = copyPose(startPose)
		self.target.roll = 0
		self.target.fov = running.snapshot.pose.fov
	end
	function segment.evaluate(self, t)
		local u = self.duration > 0 and ease(t / self.duration) or 1
		return blendPoses(self.start, self.target, u)
	end
	function segment.finish()
		if control == running then
			releaseControl(running, releaseInPlaceState(running))
		end
	end
	return segment
end

---What happens after the last shot: the default is handing the camera back where it is.
---@param running CinematicControl
local function appendEnding(running, segments, params)
	local onEnd = params.onEnd or DEFAULTS.onEnd
	if onEnd == "restore" then
		local saved = savedCamera(params.restoreSlot)
		segments[#segments + 1] = restoreSegment(saved, params.restoreDuration, params.restoreEasing)
	elseif onEnd == "hold" then
		segments[#segments + 1] = holdSegment(nil)
	else
		segments[#segments + 1] = releaseSegment(running, params.releaseDuration, params.releaseEasing)
	end
end

---@param running CinematicControl
local function startTimeline(running, segments)
	running.segments = segments
	running.index = 1
	running.elapsed = 0
end

--------------------------------------------------------------------------------
-- Shake
--------------------------------------------------------------------------------

local function updateShakes(dt)
	local px, py, pz, tx, ty = 0.0, 0.0, 0.0, 0.0, 0.0
	local i = 1
	while i <= #shakes do
		local shake = shakes[i]
		shake.elapsed = shake.elapsed + dt
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
	local running = takeControl()
	local keyframes = sequence.keyframes
	local segments = {}
	for i = 1, #keyframes do
		local keyframe = keyframes[i]
		segments[#segments + 1] = moveSegment(keyframe, keyframes[i - 1], keyframes[i - 2], keyframes[i + 1])
		if (keyframe.hold or 0) > 0 then
			segments[#segments + 1] = holdSegment(keyframe.hold)
		end
	end
	appendEnding(running, segments, sequence)
	startTimeline(running, segments)
end

local function follow(params)
	local running = takeControl()
	local segment, untilStopped = followSegment(params)
	local segments = { segment }
	if not untilStopped then
		appendEnding(running, segments, params)
	end
	startTimeline(running, segments)
end

local function orbit(params)
	local running = takeControl()
	local segments = { orbitSegment(params) }
	appendEnding(running, segments, params)
	startTimeline(running, segments)
end

local function shake(params)
	local magnitude = params.magnitude or 0
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
	}
end

---Remembers the player's camera: during a sequence that is the camera the sequence took over.
local function save(slot)
	local running = control
	slots[slot or DEFAULT_SLOT] = {
		state = running and running.snapshot.state or spGetCameraState(),
		pose = running and copyPose(running.snapshot.pose) or renderedPose(),
	}
end

local function restore(slot, duration, easing)
	local saved = savedCamera(slot)
	if not saved then
		Spring.Log(widget:GetInfo().name, LOG.WARNING, "No saved camera to restore: " .. tostring(slot or DEFAULT_SLOT))
		return
	end
	local running = takeControl()
	startTimeline(running, { restoreSegment(saved, duration, easing) })
end

local function stop()
	local running = control
	if running then
		releaseControl(running, releaseInPlaceState(running))
	end
	shakes = {}
	if shakeOffsetApplied then
		spSetCameraOffset()
		shakeOffsetApplied = false
	end
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

function widget:Update(dt)
	local running = control
	if windowOpen() then
		if running then
			applyPose(running.pose)
		end
		return
	end

	if #shakes > 0 or shakeOffsetApplied then
		updateShakes(dt)
	end
	if not running then
		return
	end

	running.elapsed = running.elapsed + dt
	local segments = running.segments
	while control do
		local segment = segments[running.index]
		if not segment then
			break -- past the last segment: keep showing the last pose
		end
		if not segment.entered then
			segment.entered = true
			segment:enter(running.pose)
		end
		segment.dt = dt
		local t = running.elapsed
		if segment.duration and t >= segment.duration then
			running.pose = segment:evaluate(segment.duration)
			running.elapsed = t - segment.duration
			running.index = running.index + 1
			if segment.finish then
				segment.finish() -- may release control
			end
		else
			running.pose = segment:evaluate(t)
			break
		end
	end

	if control then
		applyPose(running.pose)
	end
end

function widget:Initialize()
	WG.cinematicCamera = {
		Play = play,
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
	if shakeOffsetApplied then
		spSetCameraOffset()
	end
	WG.cinematicCamera = nil
end
