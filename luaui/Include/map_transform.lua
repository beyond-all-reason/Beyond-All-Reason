-- Map transform math, shared by the Terraformer's DIMENSIONS tools.
--
-- One object describes how the authoring of a source map (srcW x srcH elmos)
-- lands on a destination map (dstW x dstH elmos). Everything that carries a
-- position, a heading or a pixel is put through the SAME object, so the
-- heightmap, the paint masks, the features and the start boxes can never
-- disagree about where the map went.
--
-- Order of operations, source -> destination:
--   1. mirror   (mirrorX negates x, mirrorZ negates z)
--   2. rotate   (0/90/180/270, clockwise as seen on the minimap)
--   3. fit      ("stretch" scales the rotated footprint onto the new canvas,
--                "keep" holds 1:1 elmo scale and places it by the anchor)
--
-- Mirror before rotate is what makes the UI honest: the rotation is outermost,
-- so a screen-space "rotate right" is always +90 on `rot` whatever else is set.
-- The panel turns a screen-space flip into the right internal mirror (see
-- flipScreen) rather than exposing this order to the user.
--
-- Conventions this file commits to, and why:
--   * Headings are engine heading units (0..65535; dir = (sin, cos), so 0 = +z
--     = south and 16384 = +x = east). A 90 degree CLOCKWISE map rotation turns
--     a thing facing south into a thing facing west, i.e. heading - 16384.
--   * Mirrors keep the SILHOUETTE, not the chirality: a wreck lying NE-SW comes
--     out lying NW-SE. Mirroring a model properly would need a mirrored mesh,
--     which does not exist, so the long axis is what gets preserved.
--   * Under that convention a mirror flips a model's local sideways axis and
--     keeps its forward axis, so tilt goes roll -> -roll, pitch -> pitch, for
--     EITHER mirror axis. A pure rotation turns heading and lean by the same
--     angle, so it leaves pitch and roll alone. No euler conversion needed.

---@class MapTransformSpec
---@field rot number
---@field mirrorX boolean
---@field mirrorZ boolean
---@field fit string
---@field anchorX number
---@field anchorZ number

---@class MapTransform
---@field rot number
---@field mirrorX boolean
---@field mirrorZ boolean
---@field fit string
---@field anchorX number
---@field anchorZ number
---@field srcW number
---@field srcH number
---@field dstW number
---@field dstH number
---@field oriW number
---@field oriH number
---@field offX number
---@field offZ number
---@field scaleX number
---@field scaleZ number
local MapTransform = {}
MapTransform.__index = MapTransform

local HEADING_FULL = 65536
local floor = math.floor

-- Snap to one of the four quarter turns; anything else is not representable
-- without resampling every texel through an arbitrary rotation.
---@return number
local function normRot(r)
	local v = (tonumber(r) or 0) % 360
	v = floor(v / 90 + 0.5) * 90
	if v >= 360 then
		v = v - 360
	end
	return v
end

-- Footprint of a WxH map after the rotation (90/270 swap the axes).
---@return number, number
function MapTransform.orientedSize(rot, w, h)
	if normRot(rot) == 90 or normRot(rot) == 270 then
		return h, w
	end
	return w, h
end

-- Both mirrors together are a half turn; keep at most one, so two different
-- specs can never describe the same map.
---@return MapTransformSpec
function MapTransform.canonical(spec)
	local rot = normRot(spec.rot)
	local mx = spec.mirrorX and true or false
	local mz = spec.mirrorZ and true or false
	if mx and mz then
		mx, mz = false, false
		rot = normRot(rot + 180)
	end
	local fit = "stretch"
	if spec.fit == "keep" then
		fit = "keep"
	end
	return {
		rot = rot,
		mirrorX = mx,
		mirrorZ = mz,
		fit = fit,
		anchorX = tonumber(spec.anchorX) or 0,
		anchorZ = tonumber(spec.anchorZ) or 0,
	}
end

-- Toggle a flip the way the user sees it on screen. With the map turned a
-- quarter, a screen-space horizontal flip is an internal mirror in Z.
---@return MapTransformSpec
function MapTransform.flipScreen(spec, axis)
	local s = MapTransform.canonical(spec)
	local swapped = (s.rot == 90 or s.rot == 270)
	if axis == "h" then
		if swapped then
			s.mirrorZ = not s.mirrorZ
		else
			s.mirrorX = not s.mirrorX
		end
	else
		if swapped then
			s.mirrorX = not s.mirrorX
		else
			s.mirrorZ = not s.mirrorZ
		end
	end
	return MapTransform.canonical(s)
end

-- spec fields as in canonical(), plus the four extents in ELMOS.
---@return MapTransform
function MapTransform.new(spec, srcW, srcH, dstW, dstH)
	local s = MapTransform.canonical(spec or {})
	local T = setmetatable({}, MapTransform)
	T.rot = s.rot
	T.mirrorX = s.mirrorX
	T.mirrorZ = s.mirrorZ
	T.fit = s.fit
	T.anchorX = s.anchorX
	T.anchorZ = s.anchorZ
	T.srcW, T.srcH = srcW, srcH
	T.dstW, T.dstH = dstW, dstH
	T.oriW, T.oriH = MapTransform.orientedSize(s.rot, srcW, srcH)

	if T.fit == "keep" then
		-- anchor -1/0/1 = flush low edge / centred / flush high edge. The offset
		-- goes negative when the canvas shrinks, which is the crop case.
		local slackX = T.dstW - T.oriW
		local slackZ = T.dstH - T.oriH
		if T.anchorX < 0 then
			T.offX = 0.0
		elseif T.anchorX > 0 then
			T.offX = slackX
		else
			T.offX = slackX * 0.5
		end
		if T.anchorZ < 0 then
			T.offZ = 0.0
		elseif T.anchorZ > 0 then
			T.offZ = slackZ
		else
			T.offZ = slackZ * 0.5
		end
		T.scaleX, T.scaleZ = 1.0, 1.0
	else
		T.offX, T.offZ = 0.0, 0.0
		T.scaleX = (T.oriW > 0) and (T.dstW / T.oriW) or 1.0
		T.scaleZ = (T.oriH > 0) and (T.dstH / T.oriH) or 1.0
	end
	return T
end

function MapTransform:isIdentity()
	return self.rot == 0 and not self.mirrorX and not self.mirrorZ and self.srcW == self.dstW and self.srcH == self.dstH
end

-- True when every destination texel comes from exactly one source texel, i.e.
-- the transform is a permutation and nothing is resampled.
function MapTransform:isExact()
	return self.dstW == self.oriW and self.dstH == self.oriH
end

----------------------------------------------------------------
-- Positions
----------------------------------------------------------------

-- Source elmo -> destination elmo. `inside` is false when the point falls off
-- the new canvas (a crop), which is the caller's cue to drop the object.
---@return number, number, boolean
function MapTransform:srcToDst(x, z)
	local mx, mz = x, z
	if self.mirrorX then
		mx = self.srcW - x
	end
	if self.mirrorZ then
		mz = self.srcH - z
	end
	local u, v
	local rot = self.rot
	if rot == 0 then
		u, v = mx, mz
	elseif rot == 90 then
		u, v = self.srcH - mz, mx
	elseif rot == 180 then
		u, v = self.srcW - mx, self.srcH - mz
	else
		u, v = mz, self.srcW - mx
	end
	local dx = u * self.scaleX + self.offX
	local dz = v * self.scaleZ + self.offZ
	local inside = dx >= 0 and dz >= 0 and dx <= self.dstW and dz <= self.dstH
	return dx, dz, inside
end

-- Destination elmo -> source elmo (what every sampler needs). `inside` is false
-- where the new canvas reaches past the old map, i.e. the extended area.
---@return number, number, boolean
function MapTransform:dstToSrc(x, z)
	local u = (x - self.offX) / self.scaleX
	local v = (z - self.offZ) / self.scaleZ
	local mx, mz
	local rot = self.rot
	if rot == 0 then
		mx, mz = u, v
	elseif rot == 90 then
		mx, mz = v, self.srcH - u
	elseif rot == 180 then
		mx, mz = self.srcW - u, self.srcH - v
	else
		mx, mz = self.srcW - v, u
	end
	-- Explicit branches, not `and/or`: a union of boolean and number is what
	-- the analyzer reads out of the compact form.
	local sx, sz = mx, mz
	if self.mirrorX then
		sx = self.srcW - mx
	end
	if self.mirrorZ then
		sz = self.srcH - mz
	end
	local inside = sx >= 0 and sz >= 0 and sx <= self.srcW and sz <= self.srcH
	return sx, sz, inside
end

----------------------------------------------------------------
-- Orientations
----------------------------------------------------------------

-- Engine heading units.
---@return number
function MapTransform:heading(h)
	local v = tonumber(h) or 0
	if self.mirrorX then
		v = -v
	elseif self.mirrorZ then
		v = HEADING_FULL / 2 - v
	end
	v = (v - self.rot * (HEADING_FULL / 360)) % HEADING_FULL
	return floor(v + 0.5) % HEADING_FULL
end

-- The same turn applied to a radian angle about Y (ground decals, cone lights).
-- Kept in one place so a convention fix lands everywhere at once.
---@return number
function MapTransform:angleRad(a)
	local v = tonumber(a) or 0
	if self.mirrorX then
		v = -v
	elseif self.mirrorZ then
		v = math.pi - v
	end
	return (v - self.rot * math.pi / 180) % (2 * math.pi)
end

---@return number
function MapTransform:angleDeg(a)
	local v = tonumber(a) or 0
	if self.mirrorX then
		v = -v
	elseif self.mirrorZ then
		v = 180 - v
	end
	return (v - self.rot) % 360
end

-- Local tilt under the silhouette-preserving mirror convention (see header).
---@return number, number
function MapTransform:tilt(pitch, roll)
	local p = tonumber(pitch) or 0
	local r = tonumber(roll) or 0
	if self.mirrorX or self.mirrorZ then
		r = -r
	end
	return p, r
end

-- Lengths along the two world axes, for anything carrying a size (decal
-- extents, weather spawner radii). Both are 1 in "keep" fit; a stretch to a
-- different aspect makes them differ, and a quarter turn swaps which applies.
---@return number, number
function MapTransform:sizeScale()
	if self.rot == 90 or self.rot == 270 then
		return self.scaleZ, self.scaleX
	end
	return self.scaleX, self.scaleZ
end

----------------------------------------------------------------
-- World pattern frame
----------------------------------------------------------------

-- This transform as a plain AFFINE, destination -> source:
--   sx = m00 * x + m01 * z + tx
--   sz = m10 * x + m11 * z + tz
-- Sampled off dstToSrc rather than re-derived from rot/mirror/fit, so it cannot
-- drift from the mapping every mask and every position already goes through.
-- Six returns rather than a table: every caller does arithmetic with these, and
-- an indexed read types as possibly-nil at each of them.
---@return number, number, number, number, number, number
function MapTransform:affine()
	local ox, oz = self:dstToSrc(0, 0)
	local ax, az = self:dstToSrc(1, 0)
	local bx, bz = self:dstToSrc(0, 1)
	return ax - ox, bx - ox, az - oz, bz - oz, ox, oz
end

-- WORLD PATTERN FRAME for the tileset shader (patternXZ in
-- dev_tileset_terrain.lua). Where the artist has claimed no texel the shader
-- picks the material from patterns addressed in WORLD XZ - the stagger mask
-- behind the cliff and foothills lerps, the fbm fields behind the intermediate
-- scatter and the macro drift, the anti-tile warp, the automatic deposit's
-- wind. Those are nailed to the world axes, so a map turned under them keeps
-- its terrain and its paint and re-rolls every automatic placement: "some
-- surfaces aren't being rotated, but some are" (CM02, 2026-09-23).
--
-- The frame puts them back. It is an affine from the map's CURRENT world XZ to
-- the XZ it was authored in, carried in the project's tileset.lua and composed
-- afresh on every transform, and the shader samples those patterns through it.
--
-- `frame` is the map's existing frame as a project file carries it: the six
-- numbers in the same order, or nil / short / junk for the map that was never
-- transformed, which reads as identity. The result is that frame applied AFTER
-- this transform's destination -> source map, which is function composition.
---@param frame number[]|nil
---@return number, number, number, number, number, number
function MapTransform:composeFrame(frame)
	local d00, d01, d10, d11, dx, dz = self:affine()
	if type(frame) ~= "table" then
		return d00, d01, d10, d11, dx, dz
	end
	local a00, a01 = tonumber(frame[1]) or 1, tonumber(frame[2]) or 0
	local a10, a11 = tonumber(frame[3]) or 0, tonumber(frame[4]) or 1
	local ax, az = tonumber(frame[5]) or 0, tonumber(frame[6]) or 0
	return a00 * d00 + a01 * d10,
		a00 * d01 + a01 * d11,
		a10 * d00 + a11 * d10,
		a10 * d01 + a11 * d11,
		a00 * dx + a01 * dz + ax,
		a10 * dx + a11 * dz + az
end

-- The frame that changes nothing, so a map turned all the way round again
-- drops the key instead of carrying a rounding of itself. The quarter turns
-- compose in exact integers; the tolerances are there for a stretch.
---@return boolean
function MapTransform.isIdentityFrame(m00, m01, m10, m11, tx, tz)
	local abs = math.abs
	return abs((tonumber(m00) or 1) - 1) < 1e-6
		and abs(tonumber(m01) or 0) < 1e-6
		and abs(tonumber(m10) or 0) < 1e-6
		and abs((tonumber(m11) or 1) - 1) < 1e-6
		and abs(tonumber(tx) or 0) < 1e-3
		and abs(tonumber(tz) or 0) < 1e-3
end

----------------------------------------------------------------
-- Expansion
----------------------------------------------------------------

-- Doubling the map along one axis. The original keeps its scale and sits on the
-- far side of the growth; the new half is either left alone or filled with a
-- copy of the map. The copy's variants are the four ways a rectangle can be
-- laid beside itself: as it is, mirrored across the seam (the one that makes a
-- symmetric map), flipped along the seam, or both, which is a half turn.
--
-- Both halves are ordinary placements of the SAME source, so everything that
-- can transform a map can expand one: each layer is simply replayed once per
-- placement.
--
-- dir: "left" | "right" | "up" | "down" (up/down are -z/+z)
-- copy: nil for an empty half, else "none" | "mirror" | "flip" | "both"
---@return MapTransformSpec[], number, number
function MapTransform.expandPlan(dir, copy, srcW, srcH)
	local horizontal = (dir == "left" or dir == "right")
	local dstW = horizontal and (srcW * 2) or srcW
	local dstH = horizontal and srcH or (srcH * 2)
	-- The map is anchored AWAY from the side it grows into.
	local keepX, keepZ = 0, 0
	if dir == "right" then
		keepX = -1
	elseif dir == "left" then
		keepX = 1
	elseif dir == "down" then
		keepZ = -1
	else
		keepZ = 1
	end
	local plan = {
		{ rot = 0, mirrorX = false, mirrorZ = false, fit = "keep", anchorX = keepX, anchorZ = keepZ },
	}
	if copy then
		local acrossSeam = (copy == "mirror" or copy == "both")
		local alongSeam = (copy == "flip" or copy == "both")
		-- Mirroring ACROSS the seam is a mirror on the growth axis; the flip
		-- that slides along the seam is the other one. Explicit branches, not
		-- an `and/or` pick: both sides are booleans, so a false left hand would
		-- fall through to the wrong axis.
		local mirrorX, mirrorZ = alongSeam, acrossSeam
		if horizontal then
			mirrorX, mirrorZ = acrossSeam, alongSeam
		end
		plan[2] = {
			rot = 0,
			mirrorX = mirrorX,
			mirrorZ = mirrorZ,
			fit = "keep",
			anchorX = -keepX,
			anchorZ = -keepZ,
		}
	end
	return plan, dstW, dstH
end

---@return string
function MapTransform.describeExpand(dir, copy)
	local where = ({ left = "west", right = "east", up = "north", down = "south" })[dir] or dir
	if not copy then
		return "doubles the map " .. where .. ", the new half empty"
	end
	local how = ({
		none = "a plain copy",
		mirror = "mirrored across the seam",
		flip = "flipped along the seam",
		both = "turned half way round",
	})[copy] or copy
	return "doubles the map " .. where .. ", the new half " .. how
end

----------------------------------------------------------------
-- Description
----------------------------------------------------------------

---@return string
function MapTransform.describe(spec)
	local s = MapTransform.canonical(spec or {})
	local parts = {}
	if s.rot ~= 0 then
		parts[#parts + 1] = string.format("rotate %d\194\176", s.rot)
	end
	if s.mirrorX then
		parts[#parts + 1] = "mirror X"
	end
	if s.mirrorZ then
		parts[#parts + 1] = "mirror Z"
	end
	if #parts == 0 then
		return "no rotation"
	end
	return table.concat(parts, " + ")
end

return MapTransform
