-- Spline tessellation for startbox anchor rings.
-- Used by startbox_utilities.lua to convert spline-flagged polygons into dense
-- polygon vertex lists before they reach containment/rendering code.

local SplineLib = {}

local DEFAULT_SEGMENTS = 12

local function clamp01(v)
	if v < 0 then return 0 end
	if v > 1 then return 1 end
	return v
end

--- Sample a Catmull-Rom curve segment between p1 and p2 (with neighbours p0, p3),
--- blended toward the linear interpolation by `tension` in [0, 1].
--- tension == 0 returns the exact linear interpolation between p1 and p2.
--- tension == 1 returns the full uniform Catmull-Rom sample.
--- Anchor points lie on the curve regardless of tension because at t=0 and t=1
--- both linear and Catmull-Rom outputs coincide with p1 and p2.
local function knotDelta(ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	return (dx * dx + dz * dz) ^ 0.25 -- |delta|^0.5  (alpha = 0.5, centripetal)
end

local function bgLerp(tt, ax, az, bx, bz, ta, tb)
	local w = (tb - tt) / (tb - ta)
	return w * ax + (1 - w) * bx, w * az + (1 - w) * bz
end

local function sampleSegment(p0, p1, p2, p3, t, tension)
	local lx = p1[1] + (p2[1] - p1[1]) * t
	local lz = p1[2] + (p2[2] - p1[2]) * t
	if tension <= 0 then
		return lx, lz
	end

	-- Centripetal Catmull-Rom (Barry-Goldman). Centripetal parameterization
	-- avoids the cusps/self-intersections (the "curly-q" overshoot) that uniform
	-- Catmull-Rom produces at sharp corners between unevenly spaced anchors.
	local t0 = 0
	local t1 = t0 + knotDelta(p0[1], p0[2], p1[1], p1[2])
	local t2 = t1 + knotDelta(p1[1], p1[2], p2[1], p2[2])
	local t3 = t2 + knotDelta(p2[1], p2[2], p3[1], p3[2])

	local crX, crZ
	if t2 - t1 <= 1e-9 then
		crX, crZ = p1[1], p1[2] -- coincident segment endpoints
	else
		local tt = t1 + (t2 - t1) * t
		local A1x, A1z = p1[1], p1[2]
		if t1 - t0 > 1e-9 then
			A1x, A1z = bgLerp(tt, p0[1], p0[2], p1[1], p1[2], t0, t1)
		end
		local A2x, A2z = bgLerp(tt, p1[1], p1[2], p2[1], p2[2], t1, t2)
		local A3x, A3z = p2[1], p2[2]
		if t3 - t2 > 1e-9 then
			A3x, A3z = bgLerp(tt, p2[1], p2[2], p3[1], p3[2], t2, t3)
		end
		local B1x, B1z = bgLerp(tt, A1x, A1z, A2x, A2z, t0, t2)
		local B2x, B2z = bgLerp(tt, A2x, A2z, A3x, A3z, t1, t3)
		crX, crZ = bgLerp(tt, B1x, B1z, B2x, B2z, t1, t2)
	end

	if tension >= 1 then
		return crX, crZ
	end
	return lx + (crX - lx) * tension, lz + (crZ - lz) * tension
end

--- Tessellate a closed ring of anchor points into a polygon.
--- Every polygon goes through this function — plain polygons are a degenerate
--- case where all anchor strengths are zero, producing vertex-identical output
--- to the input. An anchor with a missing 3rd element is treated as strength 0
--- (sharp corner): if the caller didn't ask for curvature, they don't get it.
--- @param anchors table array of {x, z} or {x, z, strength} anchors (closed implicitly).
--- @param opts table|nil { segments = number }
---   segments: subdivisions per curved edge (default 12). Test-time hook;
---   production callers omit this and accept the default.
--- @return table polygon as {{x, z}, ...} suitable for the existing polygon consumers.
function SplineLib.TessellateRing(anchors, opts)
	local n = #anchors
	if n < 2 then
		local out = {}
		for i = 1, n do
			out[i] = { anchors[i][1], anchors[i][2] }
		end
		return out
	end

	local segments = (opts and opts.segments) or DEFAULT_SEGMENTS
	if segments < 1 then segments = 1 end

	local out = {}
	for i = 1, n do
		local iPrev = ((i - 2) % n) + 1
		local iNext = (i % n) + 1
		local iNext2 = (iNext % n) + 1
		local p0 = anchors[iPrev]
		local p1 = anchors[i]
		local p2 = anchors[iNext]
		local p3 = anchors[iNext2]

		local s1 = p1[3]; if s1 == nil then s1 = 0 end
		local s2 = p2[3]; if s2 == nil then s2 = 0 end
		local edgeTension = clamp01((clamp01(s1) + clamp01(s2)) * 0.5)

		out[#out + 1] = { p1[1], p1[2] }
		if edgeTension > 0 and n >= 3 then
			for k = 1, segments - 1 do
				local x, z = sampleSegment(p0, p1, p2, p3, k / segments, edgeTension)
				out[#out + 1] = { x, z }
			end
		end
	end
	return out
end

return SplineLib
