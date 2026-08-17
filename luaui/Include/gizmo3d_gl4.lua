-- luaui/Include/gizmo3d_gl4.lua
--
-- A reusable 3D transform gizmo: three translate arrows, three rotation rings,
-- and a centre handle for free movement over terrain. Object-agnostic -- it owns
-- geometry, hit testing and drag maths, and hands the caller back deltas. The
-- caller decides what those deltas mean.
--
-- Written for the feature placer, but deliberately free of any feature-specific
-- knowledge so the light placer (which already stubs `selectedLight` for this)
-- and the decal placer can use it unchanged.
--
-- Two design notes worth knowing before editing:
--
--   * Hit testing happens in screen space, not with ray-vs-solid intersections.
--     Handle sample points are projected with Spring.WorldToScreenCoords and
--     compared against the cursor in pixels. The repo has no ray-vs-cylinder or
--     ray-vs-torus helper, and pixel distance is both simpler and a better match
--     for how the gizmo actually looks to the user -- a thin ring stays grabbable
--     at any zoom.
--
--   * The gizmo holds a roughly constant on-screen size, but never smaller than
--     the object it is transforming -- a gizmo inside the model's silhouette
--     cannot be picked apart from it. Callers set that floor with
--     setObjectRadius. The world size corresponding to a pixel is measured by
--     projecting a probe along the camera's right vector, which is exact at any
--     camera angle (probing along world +X, as the startpos tool does, is only
--     exact top-down).

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local GetCameraPosition = Spring.GetCameraPosition
local GetCameraVectors = Spring.GetCameraVectors
local WorldToScreenCoords = Spring.WorldToScreenCoords
local GetPixelDir = Spring.GetPixelDir
local TraceScreenRay = Spring.TraceScreenRay
local GetGroundHeight = Spring.GetGroundHeight
local GetViewGeometry = Spring.GetViewGeometry

local sqrt = math.sqrt
local abs = math.abs
local atan2 = math.atan2
local cos = math.cos
local sin = math.sin
local floor = math.floor
local pi = math.pi
local HALF_PI = pi * 0.5
local TAU = pi * 2

----------------------------------------------------------------
-- Tuning
----------------------------------------------------------------
-- Preferred on-screen radius. The gizmo is normally this size regardless of
-- zoom, but it is also never allowed to sit inside the thing it is transforming
-- -- see gizmoScale.
local GIZMO_PX = 110
local GIZMO_MIN_PX = 72 -- below this the handles stop being clickable
local GIZMO_MAX_PX = 320 -- keeps a zoomed-in gizmo from swallowing the screen

-- How far outside the transformed object's bounding radius the handles sit. The
-- rings have to clear the silhouette or they cannot be picked out against the
-- model -- and for a multi-selection, outside the whole group.
local OBJECT_CLEARANCE = 1.35

-- Hard ceiling on the gizmo RADIUS as a fraction of the smaller viewport axis.
-- The clearance floor overrides GIZMO_MAX_PX but not this. Set generously
-- (radius = one viewport axis, so diameter = two) because handles that run off
-- the edge are still perfectly grabbable where they cross the view -- projection
-- does not clip laterally, and both the segment and ring tests find the nearest
-- point on the visible part. This only stops the truly absurd.
local GIZMO_MAX_VIEWPORT_FRAC = 1.0

local ARROW_GRAB_PX = 16
local RING_GRAB_PX = 12
local CENTRE_GRAB_PX = 18

-- Rings are hit-tested by walking the circle, so the arc between probes has to
-- stay under the grab radius or the ring develops dead spots. Any fixed count
-- fails once the gizmo scales with the object (at a 630 px radius, 192 probes
-- are 21 px apart), and a count large enough for the worst case wastes work in
-- the common one. Instead: a coarse sweep to bracket the nearest point, then a
-- ternary search inside that bracket. Constant cost, exact at any size.
local RING_COARSE_SAMPLES = 48
local RING_REFINE_STEPS = 18
local RING_RADIUS = 1.0 -- relative to gizmo size
local ARROW_LENGTH = 0.95
local SHAFT_RADIUS = 0.018
local HEAD_LENGTH = 0.22
local HEAD_RADIUS = 0.062
local CENTRE_RADIUS = 0.085
local SHAFT_LENGTH = ARROW_LENGTH - HEAD_LENGTH

-- Rotating an axis-aligned primitive into place. All the primitive helpers build
-- Y-up geometry and the circle helper builds an XY-plane ring, so each handle is
-- one euler triple away, composed the same Rx*Ry*Rz way as the shader.
local HANDLES = {
	tx = { kind = "arrow", axis = { 1, 0, 0 }, euler = { 0, 0, -HALF_PI }, color = { 0.95, 0.25, 0.25 } },
	ty = { kind = "arrow", axis = { 0, 1, 0 }, euler = { 0, 0, 0 }, color = { 0.35, 0.95, 0.35 } },
	tz = { kind = "arrow", axis = { 0, 0, 1 }, euler = { HALF_PI, 0, 0 }, color = { 0.35, 0.55, 1.0 } },
	rx = { kind = "ring", axis = { 1, 0, 0 }, euler = { 0, HALF_PI, 0 }, color = { 0.95, 0.35, 0.35 } },
	ry = { kind = "ring", axis = { 0, 1, 0 }, euler = { HALF_PI, 0, 0 }, color = { 0.45, 0.95, 0.45 } },
	rz = { kind = "ring", axis = { 0, 0, 1 }, euler = { 0, 0, 0 }, color = { 0.45, 0.6, 1.0 } },
	centre = { kind = "centre", axis = { 0, 1, 0 }, euler = { 0, 0, 0 }, color = { 0.95, 0.9, 0.4 } },
}

-- Draw and pick order. Arrows before rings so an arrow tip lying over a ring
-- wins the grab, which is what it looks like from the front.
local HANDLE_ORDER = { "centre", "tx", "ty", "tz", "rx", "ry", "rz" }

----------------------------------------------------------------
-- Shader
----------------------------------------------------------------
local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 10000
//__DEFINES__

layout (location = 0) in vec4 localpos;
layout (location = 1) in vec4 centerscale; // xyz = pivot, w = world size of the gizmo
layout (location = 2) in vec4 rotation;    // pitch, yaw, roll, unused
layout (location = 3) in vec4 color;

//__ENGINEUNIFORMBUFFERDEFS__

#line 15000

out vec4 v_color;

void main() {
	mat3 rot = rotation3dX(rotation.x) * rotation3dY(rotation.y) * rotation3dZ(rotation.z);
	// The circle helper packs circumference into .z, so only xy are positional
	// for rings; DISCARD_Z is set for that instance table.
	#if DISCARD_Z == 1
		vec3 local = vec3(localpos.xy, 0.0);
	#else
		vec3 local = localpos.xyz;
	#endif

	vec3 world = rot * (local * centerscale.w) + centerscale.xyz;

	v_color = color;
	gl_Position = cameraViewProj * vec4(world, 1.0);
}
]]

local fsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 20000

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

in vec4 v_color;
out vec4 fragColor;

void main() {
	fragColor = v_color;
}
]]

local INSTANCE_LAYOUT = {
	{ id = 1, name = "centerscale", size = 4 },
	{ id = 2, name = "rotation", size = 4 },
	{ id = 3, name = "color", size = 4 },
}
local INSTANCE_STEP = 12

----------------------------------------------------------------
-- Module state
----------------------------------------------------------------
local Gizmo = {}

local initialised = false
local solidShader, ringShader
local prims = {} -- kind -> { vbo, numVertices, primitiveType, table, shader }

local pivot = nil -- { x, y, z }
local objectRadius = 0 -- bounding radius of whatever is being transformed
local snap = { grid = nil, angleDeg = nil }

local drag = nil -- see beginDrag

local instanceCache = {}
for i = 1, INSTANCE_STEP do
	instanceCache[i] = 0
end

----------------------------------------------------------------
-- Vector helpers
----------------------------------------------------------------
local function dot(ax, ay, az, bx, by, bz)
	return ax * bx + ay * by + az * bz
end

-- World units that correspond to one screen pixel at the given world point.
-- Returns nil when the point is off-screen or behind the camera.
local function worldPerPixel(x, y, z)
	local sx0, sy0, sz0 = WorldToScreenCoords(x, y, z)
	if not sz0 or sz0 <= 0 or sz0 >= 1 then
		return nil
	end

	local cam = GetCameraVectors()
	local rx, ry, rz = 1, 0, 0
	if cam and cam.right then
		rx, ry, rz = cam.right[1], cam.right[2], cam.right[3]
	end

	local probe = 100
	local sx1, sy1 = WorldToScreenCoords(x + rx * probe, y + ry * probe, z + rz * probe)
	if not sx1 then
		return nil
	end

	local dx, dy = sx1 - sx0, sy1 - sy0
	local pxPerWorld = sqrt(dx * dx + dy * dy) / probe
	if pxPerWorld < 1e-4 then
		return nil
	end
	return 1 / pxPerWorld
end

-- World radius of the gizmo.
--
-- Normally a constant on-screen size, but a gizmo that fits inside the model it
-- is transforming is unusable: the handles disappear into the silhouette and
-- cannot be picked apart. So the object's own bounding radius sets a floor, and
-- the upper clamp is lifted for objects big enough to need it -- capping a large
-- object back down would put the handles right back inside it.
local function gizmoScale()
	if not pivot then
		return nil
	end
	local wpp = worldPerPixel(pivot.x, pivot.y, pivot.z)
	if not wpp then
		return nil
	end

	local clearance = objectRadius * OBJECT_CLEARANCE
	local size = wpp * GIZMO_PX
	if size < clearance then
		size = clearance
	end

	-- Clearance normally overrides the usual on-screen ceiling, because capping a
	-- large object back down would put the handles inside it again. The one thing
	-- it may not do is outgrow the viewport: past that the handles are off-screen
	-- and there is no "outside the selection" left to sit in, so the fraction
	-- below wins and the user zooms out instead.
	local cap = wpp * GIZMO_MAX_PX
	if cap < clearance then
		cap = clearance
	end
	local vsx, vsy = GetViewGeometry()
	local viewportCap = wpp * (vsx < vsy and vsx or vsy) * GIZMO_MAX_VIEWPORT_FRAC
	if cap > viewportCap then
		cap = viewportCap
	end
	if size > cap then
		size = cap
	end

	-- Applied last: an unclickable gizmo is worse than an oversized one.
	if size < wpp * GIZMO_MIN_PX then
		size = wpp * GIZMO_MIN_PX
	end

	return size
end

-- Orthonormal basis of the plane whose normal is a cardinal axis.
local function planeBasis(axis)
	if axis[1] ~= 0 then
		return { 0, 1, 0 }, { 0, 0, 1 }
	elseif axis[2] ~= 0 then
		return { 0, 0, 1 }, { 1, 0, 0 }
	end
	return { 1, 0, 0 }, { 0, 1, 0 }
end

-- Spring.GetPixelDir hands its arguments straight to CCamera::CalcPixelDir, which
-- wants raw window coordinates. Spring.GetMouseState reports viewport-relative
-- coordinates with y measured from the bottom. TraceScreenRay does this same
-- conversion internally (LuaUnsyncedRead.cpp: wx = mx + viewPosX,
-- wy = viewSizeY - 1 - my); GetPixelDir does not, so it has to happen here or
-- every drag ray comes out vertically mirrored.
--
-- Note this is the opposite of Spring.WorldToScreenCoords, which returns
-- viewport coordinates in the same bottom-origin space as GetMouseState, so the
-- pixel hit testing above needs no conversion.
local function mouseRay(mx, my)
	local _, viewSizeY, viewPosX = Spring.GetViewGeometry()
	local cx, cy, cz = GetCameraPosition()
	local dx, dy, dz = GetPixelDir(mx + (viewPosX or 0), viewSizeY - 1 - my)
	if not dx then
		return nil
	end
	return cx, cy, cz, dx, dy, dz
end

----------------------------------------------------------------
-- Public: pivot and snapping
----------------------------------------------------------------
---@param x number|nil pass nil to hide the gizmo
function Gizmo.setPivot(x, y, z)
	if not x then
		pivot = nil
		return
	end
	pivot = { x = x, y = y, z = z }
end

---Bounding radius of whatever is being transformed, in world units. The gizmo
---grows to sit outside it so the handles never disappear into the model. Set it
---once per selection change; it survives setPivot, which runs every drag frame.
---@param r number|nil
function Gizmo.setObjectRadius(r)
	objectRadius = r or 0
end

function Gizmo.getPivot()
	return pivot
end

---@param opts table { grid = elmos|nil, angleDeg = degrees|nil }
function Gizmo.setSnap(opts)
	snap.grid = opts and opts.grid or nil
	snap.angleDeg = opts and opts.angleDeg or nil
end

----------------------------------------------------------------
-- Public: hit testing
----------------------------------------------------------------
-- Squared pixel distance from the cursor to a world point, or nil off-screen.
local function pixelDistSq(mx, my, x, y, z)
	local sx, sy, sz = WorldToScreenCoords(x, y, z)
	if not sz or sz <= 0 or sz >= 1 then
		return nil
	end
	local dx, dy = sx - mx, sy - my
	return dx * dx + dy * dy
end

-- Pixel distance from the cursor to a world-space segment. Exact, so an arrow is
-- grabbable along its whole length rather than only near the points a sampler
-- happened to place.
local function pixelDistToSegment(mx, my, ax, ay, az, bx, by, bz)
	local sax, say, saz = WorldToScreenCoords(ax, ay, az)
	local sbx, sby, sbz = WorldToScreenCoords(bx, by, bz)
	local aOk = saz and saz > 0 and saz < 1
	local bOk = sbz and sbz > 0 and sbz < 1

	if not (aOk and bOk) then
		-- One end is behind the camera or past the far plane, which happens once
		-- the gizmo is large enough for the camera to sit inside it. Projecting
		-- across that boundary gives nonsense, so walk the segment and keep the
		-- part that does project.
		if not (aOk or bOk) then
			return nil
		end
		local best = nil
		for i = 0, 16 do
			local t = i / 16
			local d = pixelDistSq(mx, my, ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t)
			if d and (not best or d < best) then
				best = d
			end
		end
		return best and sqrt(best) or nil
	end

	local dx, dy = sbx - sax, sby - say
	local len2 = dx * dx + dy * dy
	local t = 0
	if len2 > 1e-6 then
		t = ((mx - sax) * dx + (my - say) * dy) / len2
		if t < 0 then
			t = 0
		elseif t > 1 then
			t = 1
		end
	end

	local ex, ey = mx - (sax + dx * t), my - (say + dy * t)
	return sqrt(ex * ex + ey * ey)
end

-- Squared pixel distance from the cursor to the ring point at angle `a`.
local function ringProbe(mx, my, u, v, r, a)
	local ca, sa = cos(a) * r, sin(a) * r
	return pixelDistSq(
		mx,
		my,
		pivot.x + u[1] * ca + v[1] * sa,
		pivot.y + u[2] * ca + v[2] * sa,
		pivot.z + u[3] * ca + v[3] * sa
	)
end

-- Pixel distance from the cursor to the nearest point on a ring. Coarse sweep to
-- bracket the minimum, then ternary search inside that bracket -- the distance is
-- smooth and unimodal near its minimum, so this converges to sub-pixel in a fixed
-- number of steps whatever the ring's on-screen size.
local function ringNearestPx(mx, my, u, v, r)
	local bestA, bestD = nil, nil
	for s = 0, RING_COARSE_SAMPLES - 1 do
		local a = (s / RING_COARSE_SAMPLES) * TAU
		local d = ringProbe(mx, my, u, v, r, a)
		if d and (not bestD or d < bestD) then
			bestA, bestD = a, d
		end
	end
	if not bestD then
		return nil
	end

	local step = TAU / RING_COARSE_SAMPLES
	local lo, hi = bestA - step, bestA + step
	for _ = 1, RING_REFINE_STEPS do
		local third = (hi - lo) / 3
		local m1, m2 = lo + third, hi - third
		local d1 = ringProbe(mx, my, u, v, r, m1)
		local d2 = ringProbe(mx, my, u, v, r, m2)
		if not (d1 and d2) then
			break -- part of the bracket is off-screen; the coarse best stands
		end
		if d1 < d2 then
			hi = m2
		else
			lo = m1
		end
	end

	local d = ringProbe(mx, my, u, v, r, (lo + hi) * 0.5)
	if d and d < bestD then
		bestD = d
	end
	return sqrt(bestD)
end

---@return string|nil handle one of tx/ty/tz/rx/ry/rz/centre
function Gizmo.hitTest(mx, my)
	if not pivot then
		return nil
	end
	local size = gizmoScale()
	if not size then
		return nil
	end

	local best, bestDist = nil, nil

	local function keep(handle, d, limitPx)
		if d and d <= limitPx and (not bestDist or d < bestDist) then
			best, bestDist = handle, d
		end
	end

	for i = 1, #HANDLE_ORDER do
		local name = HANDLE_ORDER[i]
		local h = HANDLES[name]

		if h.kind == "centre" then
			local dsq = pixelDistSq(mx, my, pivot.x, pivot.y, pivot.z)
			keep(name, dsq and sqrt(dsq), CENTRE_GRAB_PX)
		elseif h.kind == "arrow" then
			-- Skip the innermost stub so the centre handle keeps its own zone.
			local from = CENTRE_RADIUS * 1.5 * size
			local to = ARROW_LENGTH * size
			keep(
				name,
				pixelDistToSegment(
					mx,
					my,
					pivot.x + h.axis[1] * from,
					pivot.y + h.axis[2] * from,
					pivot.z + h.axis[3] * from,
					pivot.x + h.axis[1] * to,
					pivot.y + h.axis[2] * to,
					pivot.z + h.axis[3] * to
				),
				ARROW_GRAB_PX
			)
		else
			local u, v = planeBasis(h.axis)
			keep(name, ringNearestPx(mx, my, u, v, RING_RADIUS * size), RING_GRAB_PX)
		end
	end

	return best
end

----------------------------------------------------------------
-- Public: dragging
----------------------------------------------------------------
-- Distance along an axis line through `origin` to the point where the mouse ray
-- passes closest. nil when the ray is near-parallel to the axis, where the
-- solution explodes.
--
-- `origin` is the pivot FROM DRAG START, never the live one. updateDrag returns a
-- delta measured from where the drag began, and the caller moves the live pivot
-- by that delta every frame -- measuring against the moved pivot would subtract
-- the previous frame's delta from this frame's, so a held cursor would strobe
-- between two positions and half the drags would commit a zero delta.
local function axisParam(origin, axis, mx, my)
	local cx, cy, cz, dx, dy, dz = mouseRay(mx, my)
	if not cx then
		return nil
	end

	local wx, wy, wz = origin.x - cx, origin.y - cy, origin.z - cz
	local a = dot(axis[1], axis[2], axis[3], axis[1], axis[2], axis[3])
	local b = dot(axis[1], axis[2], axis[3], dx, dy, dz)
	local c = dot(dx, dy, dz, dx, dy, dz)
	local d = dot(axis[1], axis[2], axis[3], wx, wy, wz)
	local e = dot(dx, dy, dz, wx, wy, wz)

	local denom = a * c - b * b
	-- cos^2 of the angle between ray and axis; 0.995 is about 5.7 degrees.
	if abs(denom) < 1e-6 or (b * b) > 0.995 * a * c then
		return nil
	end

	return (b * e - c * d) / denom
end

-- Angle of the mouse ray's intersection with the plane through `origin` whose
-- normal is `axis`, measured in that plane's basis. Frozen at drag start for the
-- same reason as axisParam.
local function ringAngle(origin, axis, mx, my)
	local cx, cy, cz, dx, dy, dz = mouseRay(mx, my)
	if not cx then
		return nil
	end

	local nd = dot(dx, dy, dz, axis[1], axis[2], axis[3])
	if abs(nd) < 1e-4 then
		return nil
	end

	local t = dot(origin.x - cx, origin.y - cy, origin.z - cz, axis[1], axis[2], axis[3]) / nd
	if t <= 0 then
		return nil
	end

	local hx, hy, hz = cx + dx * t - origin.x, cy + dy * t - origin.y, cz + dz * t - origin.z
	local u, v = planeBasis(axis)
	return atan2(dot(hx, hy, hz, v[1], v[2], v[3]), dot(hx, hy, hz, u[1], u[2], u[3]))
end

---@return boolean started
function Gizmo.beginDrag(handle, mx, my)
	local h = pivot and HANDLES[handle]
	if not h then
		return false
	end

	drag = {
		handle = handle,
		kind = h.kind,
		axis = h.axis,
		origin = { x = pivot.x, y = pivot.y, z = pivot.z },
	}

	if h.kind == "arrow" then
		drag.startParam = axisParam(drag.origin, h.axis, mx, my)
		if not drag.startParam then
			drag = nil
			return false
		end
	elseif h.kind == "ring" then
		drag.startAngle = ringAngle(drag.origin, h.axis, mx, my)
		if not drag.startAngle then
			drag = nil
			return false
		end
	else
		local _, pos = TraceScreenRay(mx, my, true)
		if not pos then
			drag = nil
			return false
		end
		drag.startGround = { pos[1], pos[3] }
	end

	return true
end

function Gizmo.isDragging()
	return drag ~= nil
end

function Gizmo.getDragHandle()
	return drag and drag.handle or nil
end

local function snapValue(v, step)
	if not step or step <= 0 then
		return v
	end
	return floor(v / step + 0.5) * step
end

---Cumulative transform delta since beginDrag.
---@return number dx, number dy, number dz, number dPitch, number dYaw, number dRoll
function Gizmo.updateDrag(mx, my)
	if not drag then
		return 0, 0, 0, 0, 0, 0
	end

	if drag.kind == "arrow" then
		local param = axisParam(drag.origin, drag.axis, mx, my)
		if not param then
			return 0, 0, 0, 0, 0, 0
		end
		local delta = snapValue(param - drag.startParam, snap.grid)
		return drag.axis[1] * delta, drag.axis[2] * delta, drag.axis[3] * delta, 0, 0, 0
	end

	if drag.kind == "ring" then
		local angle = ringAngle(drag.origin, drag.axis, mx, my)
		if not angle then
			return 0, 0, 0, 0, 0, 0
		end

		local delta = angle - drag.startAngle
		-- Keep the delta continuous across the atan2 discontinuity so a drag that
		-- crosses the seam does not snap a full turn.
		while delta > pi do
			delta = delta - TAU
		end
		while delta < -pi do
			delta = delta + TAU
		end

		if snap.angleDeg and snap.angleDeg > 0 then
			delta = snapValue(delta, snap.angleDeg * pi / 180)
		end

		-- Negated to convert into Recoil's left-handed angles. planeBasis picks a
		-- right-handed (u, v) pair for each axis, so a positive atan2 sweep in
		-- that basis is a negative engine rotation; the relation holds for all
		-- three rings, which is why one sign flip covers them.
		return 0, 0, 0, -delta * drag.axis[1], -delta * drag.axis[2], -delta * drag.axis[3]
	end

	local _, pos = TraceScreenRay(mx, my, true)
	if not pos then
		return 0, 0, 0, 0, 0, 0
	end

	local dx = snapValue(pos[1] - drag.startGround[1], snap.grid)
	local dz = snapValue(pos[3] - drag.startGround[2], snap.grid)
	-- Free move follows the terrain: the caller gets a y delta that puts the
	-- pivot back on the ground at its new xz.
	local targetY = GetGroundHeight(drag.origin.x + dx, drag.origin.z + dz) or drag.origin.y
	return dx, targetY - drag.origin.y, dz, 0, 0, 0
end

function Gizmo.endDrag()
	drag = nil
end

----------------------------------------------------------------
-- Rendering
----------------------------------------------------------------
local function makeInstanceTable(name, vbo, numVertices, primitiveType)
	local iT = InstanceVBOTable.makeInstanceVBOTable(INSTANCE_LAYOUT, 8, name)
	if not iT then
		return nil
	end
	iT.vertexVBO = vbo
	iT.numVertices = numVertices
	iT.primitiveType = primitiveType
	iT.VAO = InstanceVBOTable.makeVAOandAttach(vbo, iT.instanceVBO)
	return iT
end

local function buildShader(name, discardZ)
	local engineDefs = LuaShader.GetEngineUniformBufferDefs()
	local defines = LuaShader.CreateShaderDefinesString({ DISCARD_Z = discardZ and 1 or 0 })

	local vs = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineDefs):gsub("//__DEFINES__", defines)
	local fs = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineDefs):gsub("//__DEFINES__", defines)

	local shader = LuaShader({ vertex = vs, fragment = fs }, name)
	if shader:Initialize() ~= true then
		return nil
	end
	return shader
end

---@return boolean ok
function Gizmo.init()
	if initialised then
		return true
	end
	if not (LuaShader and InstanceVBOTable) then
		return false
	end

	solidShader = buildShader("Gizmo3D solid", false)
	ringShader = buildShader("Gizmo3D ring", true)
	if not (solidShader and ringShader) then
		Spring.Echo("[Gizmo3D] shader compilation failed")
		return false
	end

	-- Built at its final proportions so every instance can use one uniform scale
	-- (the gizmo's world size). The cylinder spans -height..+height, hence the
	-- half-length here.
	local shaftVBO, shaftVerts =
		InstanceVBOTable.makeCylinderVBO(10, SHAFT_LENGTH * 0.5, SHAFT_RADIUS, false, false, "gizmoShaft")
	local headVBO, headVerts = InstanceVBOTable.makeConeVBO(12, HEAD_LENGTH, HEAD_RADIUS, "gizmoHead")
	local ringVBO, ringVerts = InstanceVBOTable.makeCircleVBO(64, RING_RADIUS, false, "gizmoRing")
	-- A box, not makeSphereVBO: the sphere helper declares attributes at ids 0-2,
	-- which would collide with this module's instance attributes, and it needs an
	-- index buffer. The box is one id-0 attribute and draws as plain triangles.
	local centreVBO, centreVerts = InstanceVBOTable.makeBoxVBO(
		-CENTRE_RADIUS,
		-CENTRE_RADIUS,
		-CENTRE_RADIUS,
		CENTRE_RADIUS,
		CENTRE_RADIUS,
		CENTRE_RADIUS,
		"gizmoCentre"
	)

	if not (shaftVBO and headVBO and ringVBO and centreVBO) then
		Spring.Echo("[Gizmo3D] could not build gizmo geometry")
		return false
	end

	prims.shaft =
		{ table = makeInstanceTable("gizmoShaftInst", shaftVBO, shaftVerts, GL.TRIANGLES), shader = solidShader }
	prims.head = { table = makeInstanceTable("gizmoHeadInst", headVBO, headVerts, GL.TRIANGLES), shader = solidShader }
	prims.ring = { table = makeInstanceTable("gizmoRingInst", ringVBO, ringVerts, GL.LINE_STRIP), shader = ringShader }
	prims.centre =
		{ table = makeInstanceTable("gizmoCentreInst", centreVBO, centreVerts, GL.TRIANGLES), shader = solidShader }

	for _, prim in pairs(prims) do
		if not prim.table then
			Spring.Echo("[Gizmo3D] could not build instance tables")
			return false
		end
	end

	initialised = true
	return true
end

function Gizmo.shutdown()
	for _, prim in pairs(prims) do
		local iT = prim.table
		if iT then
			if iT.VAO then
				iT.VAO:Delete()
				iT.VAO = nil
			end
			if iT.instanceVBO then
				iT.instanceVBO:Delete()
				iT.instanceVBO = nil
			end
			if iT.vertexVBO then
				iT.vertexVBO:Delete()
				iT.vertexVBO = nil
			end
			if WG.VBOTableRegistry then
				WG.VBOTableRegistry[iT.myName] = nil
			end
		end
	end
	prims = {}

	if solidShader then
		solidShader:Finalize()
		solidShader = nil
	end
	if ringShader then
		ringShader:Finalize()
		ringShader = nil
	end

	pivot = nil
	drag = nil
	initialised = false
end

local function push(prim, cx, cy, cz, size, euler, r, g, b, a, id)
	instanceCache[1], instanceCache[2], instanceCache[3], instanceCache[4] = cx, cy, cz, size
	instanceCache[5], instanceCache[6], instanceCache[7], instanceCache[8] = euler[1], euler[2], euler[3], 0
	instanceCache[9], instanceCache[10], instanceCache[11], instanceCache[12] = r, g, b, a
	-- noUpload: the whole gizmo is rebuilt every frame, so one upload per table
	-- at the end beats a GL call per handle.
	InstanceVBOTable.pushElementInstance(prim.table, instanceCache, id, true, true)
end

---@param hovered string|nil handle name currently under the cursor
function Gizmo.draw(hovered)
	if not (initialised and pivot) then
		return
	end
	local size = gizmoScale()
	if not size then
		return
	end

	local active = drag and drag.handle or nil

	for _, prim in pairs(prims) do
		InstanceVBOTable.clearInstanceTable(prim.table)
	end

	for i = 1, #HANDLE_ORDER do
		local name = HANDLE_ORDER[i]
		local h = HANDLES[name]

		local r, g, b = h.color[1], h.color[2], h.color[3]
		if name == active then
			r, g, b = 1, 1, 1
		elseif name == hovered then
			r, g, b = r * 0.4 + 0.6, g * 0.4 + 0.6, b * 0.4 + 0.6
		end
		-- Everything but the handle being dragged dims, so the active axis reads
		-- unambiguously mid-drag.
		local a = (active and name ~= active) and 0.35 or 0.95

		if h.kind == "arrow" then
			-- The shaft geometry is centred on its own origin, so offset the
			-- instance to the shaft's midpoint; the cone's base is at its origin,
			-- so that one sits at the shaft's far end.
			local mid = SHAFT_LENGTH * 0.5 * size
			push(
				prims.shaft,
				pivot.x + h.axis[1] * mid,
				pivot.y + h.axis[2] * mid,
				pivot.z + h.axis[3] * mid,
				size,
				h.euler,
				r,
				g,
				b,
				a,
				name
			)

			local headBase = SHAFT_LENGTH * size
			push(
				prims.head,
				pivot.x + h.axis[1] * headBase,
				pivot.y + h.axis[2] * headBase,
				pivot.z + h.axis[3] * headBase,
				size,
				h.euler,
				r,
				g,
				b,
				a,
				name
			)
		elseif h.kind == "ring" then
			push(prims.ring, pivot.x, pivot.y, pivot.z, size, h.euler, r, g, b, a, name)
		else
			push(prims.centre, pivot.x, pivot.y, pivot.z, size, h.euler, r, g, b, a, name)
		end
	end

	for _, prim in pairs(prims) do
		InstanceVBOTable.uploadAllElements(prim.table)
	end

	-- Drawn through terrain on purpose: a handle buried in a hillside cannot be
	-- grabbed, and hit testing does not depth-test either, so hiding it would
	-- only make the two disagree.
	gl.DepthTest(GL.ALWAYS)
	gl.DepthMask(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.Culling(false)
	gl.LineWidth(2.5)

	local activeShader = nil
	for _, prim in pairs(prims) do
		local iT = prim.table
		if iT.usedElements > 0 then
			if activeShader ~= prim.shader then
				if activeShader then
					activeShader:Deactivate()
				end
				prim.shader:Activate()
				activeShader = prim.shader
			end
			iT.VAO:DrawArrays(iT.primitiveType, iT.numVertices, 0, iT.usedElements, 0)
		end
	end
	if activeShader then
		activeShader:Deactivate()
	end

	gl.LineWidth(1)
	gl.Blending(false)
	gl.DepthTest(false)
end

return Gizmo
