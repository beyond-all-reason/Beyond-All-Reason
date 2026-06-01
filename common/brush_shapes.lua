-- common/brush_shapes.lua
--
-- Shared brush-shape containment test used by the realtime-terraformer family
-- of brush widgets (weather, grass, decal, light, ...). Previously each widget
-- carried its own copy of `isInsideShape`, which drifted apart over time. This
-- module is the single source of truth.
--
-- Convention (matches the `drawRegularPolygon` outline helpers in the widgets):
--   * Shapes are centred on the origin; pass offsets `dx, dz` from the brush
--     centre, not absolute world coordinates.
--   * `radius` is the circumradius along X. `lengthScale` stretches the Z axis
--     (ellipse / elongated polygons); defaults to 1.0.
--   * Polygons have a VERTEX on the +X axis (pointy-on-x) at the circumradius,
--     so the containment mask lines up with the drawn outline.
--   * `angleDeg` rotates the shape clockwise (same sign the widgets already use).
--
-- Returns: inside (boolean), normDist (number)
--   normDist <= 1.0 means inside. It is the normalised distance toward the
--   shape edge (0 at centre, 1 on the boundary), suitable for falloff curves.
--
-- Supported shapes: "circle", "square", "hexagon", "octagon", "triangle".
-- Unknown shapes return (false, 1).

local cos  = math.cos
local sin  = math.sin
local abs  = math.abs
local max  = math.max
local sqrt = math.sqrt
local pi   = math.pi

local function rotateInv(dx, dz, angleDeg)
	if angleDeg == 0 then return dx, dz end
	local rad = -angleDeg * pi / 180
	local c, s = cos(rad), sin(rad)
	return dx * c - dz * s, dx * s + dz * c
end

local function isInside(dx, dz, radius, shape, angleDeg, lengthScale)
	lengthScale = lengthScale or 1.0
	angleDeg = angleDeg or 0
	local rx, rz = rotateInv(dx, dz, angleDeg)
	local radX = radius
	local radZ = radius * lengthScale
	if shape == "circle" then
		local normX = rx / radX
		local normZ = rz / radZ
		local d = sqrt(normX * normX + normZ * normZ)
		return d <= 1.0, d
	elseif shape == "square" then
		-- axis-aligned square; corners at (±radX, ±radZ) match outline
		local d = max(abs(rx) / radX, abs(rz) / radZ)
		return d <= 1.0, d
	elseif shape == "hexagon" then
		-- regular hexagon, vertices on ±x axis (pointy-on-x) matching outline
		-- constraints: |x| + |z|/sqrt(3) <= 1  and  2|z|/sqrt(3) <= 1
		local ax, az = abs(rx) / radX, abs(rz) / radZ
		local d = max(ax + az * 0.5773503, az * 1.1547005)
		return d <= 1.0, d
	elseif shape == "octagon" then
		-- regular octagon, vertex on +x axis matching outline
		local ax, az = abs(rx) / radX, abs(rz) / radZ
		local d = max(ax + az * 0.4142136, az + ax * 0.4142136)
		return d <= 1.0, d
	elseif shape == "triangle" then
		-- equilateral triangle pointing +x, vertices at angles 0°,120°,240°
		local nx = rx / radX
		local az = abs(rz) / radZ
		local d = max(nx + az * 1.7320508, -2 * nx)
		return d <= 1.0, d
	end
	return false, 1
end

return {
	isInside = isInside,
	rotateInv = rotateInv,
}
