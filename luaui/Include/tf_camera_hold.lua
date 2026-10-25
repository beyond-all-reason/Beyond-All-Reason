-- Terraform Brush camera hold.
--
-- The spring camera re-seats its focus point on the surface every frame (raw terrain, or the smooth mesh
-- in CamSpringTrackMapHeightMode 2), so a stroke that raises or lowers the ground under the view would
-- carry the camera with it. The hold keeps the EYE still instead: it remembers the eye and view direction
-- when a stroke starts, and every frame moves the focus along that view ray to where it now meets the
-- surface. Ground raised into the camera still lifts it (see CLEARANCE).
--
-- The hold stays on after the stroke until the player moves the camera, because the smooth mesh catches
-- up with a heightmap edit over several frames. No setting is touched; only editor terraform strokes
-- engage it.

local M = {}

local CLEARANCE = 40 -- elmos the held eye keeps above the ground under it
local MOVED_XZ = 1.0 -- elmos of sideways eye movement that count as the player moving the camera
local MOVED_DIR = 0.002 -- view direction change (dot product) that counts as the player turning it

local held = false ---@type boolean
local stroking = false ---@type boolean
---@type [number, number, number]
local eye = { 0, 0, 0 }
---@type [number, number, number]
local look = { 0, 0, -1 }

-- The surface the engine seats the focus on depends on engine version and setting, so it is not modelled:
-- the camera state's focus height (py) minus the raw ground there gives an offset added to the ground.
-- Exact for terrain tracking; for the smooth mesh a local estimate the next frame refines.
---@type number
local surfaceOffset = 0

local function surfaceHeight(x, z)
	return Spring.GetGroundHeight(x, z) + surfaceOffset
end

-- distance along the remembered view ray to the surface, nil when the ray never meets it
local function rayToSurface(maxT)
	local function above(t)
		local x, z = eye[1] + look[1] * t, eye[3] + look[3] * t
		return eye[2] + look[2] * t - surfaceHeight(x, z)
	end
	---@type number, number?, number
	local lo, hi, step = 0, nil, 64
	---@type number
	local t = step
	while t <= maxT do
		if above(t) <= 0 then
			hi = t
			break
		end
		lo = t
		t = t + step
		step = step * 1.25
	end
	if not hi then
		return nil
	end
	for _ = 1, 24 do
		local mid = (lo + hi) * 0.5
		if above(mid) > 0 then
			lo = mid
		else
			hi = mid
		end
	end
	return (lo + hi) * 0.5
end

function M.release()
	held, stroking = false, false
end

---@return boolean held, number eyeY
function M.status()
	return held, eye[2]
end

local function capture()
	local x, y, z = Spring.GetCameraPosition()
	local dx, dy, dz = Spring.GetCameraDirection()
	eye[1], eye[2], eye[3] = x, y, z
	look[1], look[2], look[3] = dx, dy, dz
end

---@param active boolean a terraform stroke is changing the ground this frame
function M.update(active)
	local state = Spring.GetCameraState()
	---@cast state CameraState?
	if not (state and state.name == "spring") then
		M.release()
		return
	end
	if active and not stroking then
		capture()
		held = true
	end
	stroking = active
	if not held then
		return
	end

	local x, y, z = Spring.GetCameraPosition()
	local dx, dy, dz = Spring.GetCameraDirection()
	-- the player moved it: a turn, or the eye going sideways (the surface only ever moves it up or down)
	local turned = dx * look[1] + dy * look[2] + dz * look[3] < 1 - MOVED_DIR
	local slid = math.abs(x - eye[1]) > MOVED_XZ or math.abs(z - eye[3]) > MOVED_XZ
	if turned or slid then
		if stroking then
			capture()
		else
			M.release()
			return
		end
	end

	local ground = Spring.GetGroundHeight(eye[1], eye[3])
	if eye[2] < ground + CLEARANCE then
		eye[2] = ground + CLEARANCE
	end
	if math.abs(y - eye[2]) < 0.25 then
		return
	end
	if look[2] >= -0.01 then
		return
	end
	if state.px and state.pz and state.py then
		surfaceOffset = state.py - Spring.GetGroundHeight(state.px, state.pz)
	end
	local t = rayToSurface(math.max(state.dist or 2000, 1000) * 4)
	if not t then
		return
	end
	state.px = eye[1] + look[1] * t
	state.pz = eye[3] + look[3] * t
	state.py = surfaceHeight(state.px, state.pz)
	state.dist = t
	Spring.SetCameraState(state, 0)
end

return M
