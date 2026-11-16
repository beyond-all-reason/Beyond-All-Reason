-- Terraform Brush world tools: the drawing helpers they share.
--
-- Every brush tool (terraform, features, units, grass, decals, weather, ...) draws a shape outline on the
-- ground, and they all draw it through here. The shapes follow common/brush_shapes.lua: vertex on +X
-- at the circumradius, `lengthScale` stretches Z, a positive angle turns clockwise on screen, so an outline
-- drawn here is exactly the area BrushShapes.isInside accepts.
--
-- `lift` picks how an outline sits on the ground:
--   nil     hugs it: each point at the ground height, drawn with a polygon offset (the terraform brush look)
--   number  each point that many elmos above the ground, no offset (the placers use 4)
-- `subdiv` is the points per edge; nil gives EDGE_SEGMENTS for up to 8 sides (edges then follow hills
-- instead of cutting under them), and 1 for anything rounder.
--
-- Also here: the smart filter overlay and altitude cap prism the placers draw, with the filter test itself
-- (common/smart_filter.lua) as WorldTool.smart, and the world cursor (WorldTool.cursor).

local BrushShapes = require("common/brush_shapes")
local SmartFilter = require("common/smart_filter")

local cos = math.cos
local sin = math.sin
local pi = math.pi
local floor = math.floor
local max = math.max
local abs = math.abs
local rotate = BrushShapes.rotate
local isInside = BrushShapes.isInside

-- Specs load the widgets that include this file without a GL context; only the draw helpers need it.
local gl = gl or {}
local GL = GL or {}
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glColor = gl.Color
local glDepthTest = gl.DepthTest
local glLineWidth = gl.LineWidth
local glPolygonOffset = gl.PolygonOffset
local GL_LINE_LOOP = GL.LINE_LOOP
local GL_LINES = GL.LINES
local GL_TRIANGLES = GL.TRIANGLES
local GetGroundHeight = Spring.GetGroundHeight
local GetMouseState = Spring.GetMouseState
local TraceScreenRay = Spring.TraceScreenRay
local GetCameraPosition = Spring.GetCameraPosition

local WorldTool = {
	EDGE_SEGMENTS = 16,
	rotate = rotate,
	smart = SmartFilter,
}

-- Intersect the raw mouse ray with the plane y = planeY, so it works past the
-- map edge where TraceScreenRay reports nothing. Returns worldX, worldZ, or nil
-- for the sky. Engine trap: GetPixelDir wants raw window coordinates, while
-- GetMouseState reports viewport bottom-origin ones (TraceScreenRay converts
-- internally, GetPixelDir does not).
---@param mx any
---@param my any
---@param planeY any
---@return any x nil for the sky
---@return any z
function WorldTool.mouseRayOnPlane(mx, my, planeY)
	local _, viewSizeY, viewPosX = Spring.GetViewGeometry()
	local dirX, dirY, dirZ = Spring.GetPixelDir(mx + (viewPosX or 0), viewSizeY - 1 - my)
	if not dirX or abs(dirY) < 0.0001 then
		return nil, nil
	end
	local camX, camY, camZ = GetCameraPosition()
	local t = (planeY - camY) / dirY
	if t <= 0 then
		return nil, nil
	end
	return camX + dirX * t, camZ + dirZ * t
end

-- Mouse-to-world resolver, extended past the map edge: when the ray misses the
-- terrain, the ground plane is extended so the brush keeps following the mouse
-- and can work right up against the border. Returns wx, wz, fade: fade is 1
-- while the footprint touches the map (within `radius` of the edge) and drops
-- to 0 one fade span later, for dimming the cursor. The terraform brush exports
-- it as WG.TerraformBrush.getWorldPositionExtended.
---@param radius any
---@return any x nil once past the fade band or for the sky
---@return any z
---@return any fade
function WorldTool.extendedCursor(radius)
	local mx, my = GetMouseState()
	local _, pos = TraceScreenRay(mx, my, true)
	if pos then
		return pos[1], pos[3], 1
	end
	local wx, wz = WorldTool.mouseRayOnPlane(mx, my, 0)
	if not wx then
		return nil, nil, nil
	end
	-- Re-intersect at the height of the nearest in-map point (GetGroundHeight
	-- clamps to the edge) so raised borders land where the cursor points.
	local edgeY = GetGroundHeight(wx, wz)
	if edgeY and edgeY ~= 0 then
		local ex, ez = WorldTool.mouseRayOnPlane(mx, my, edgeY)
		if ex then
			wx, wz = ex, ez
		end
	end
	local dx = max(0, -wx, wx - Game.mapSizeX)
	local dz = max(0, -wz, wz - Game.mapSizeZ)
	local dist = (dx * dx + dz * dz) ^ 0.5
	local band = radius or 0
	local fadeSpan = max(band, 100)
	if dist >= band + fadeSpan then
		return nil, nil, nil
	end
	return wx, wz, 1 - max(0, dist - band) / fadeSpan
end

---The ground under the mouse, plain (stops at the map edge): x, z and the traced y, or nil.
---@return any x nil off the map
---@return any z
---@return any y
function WorldTool.plainCursor()
	local mx, my = GetMouseState()
	local _, pos = TraceScreenRay(mx, my, true)
	if pos then
		return pos[1], pos[3], pos[2]
	end
	return nil, nil, nil
end

---plainCursor, but only a "ground" hit counts.
---@return any x nil unless the ground is hit
---@return any z
function WorldTool.groundCursor()
	local mx, my = GetMouseState()
	local kind, pos = TraceScreenRay(mx, my, true)
	if kind == "ground" and pos then
		return pos[1], pos[3]
	end
	return nil, nil
end

---The brush cursor the tools share: the terraform brush's edge-extended one while the brush is
---loaded, else `fallback` (plainCursor when nil). Returns x, z and the cursor fade; the fade is 1
---when there is no position or it comes from the fallback.
---@param radius any the footprint that may hang over the map edge
---@param fallback any number?, number?)?
---@return any x nil when there is no position
---@return any z
---@return any fade 1 without a position or from the fallback
function WorldTool.cursor(radius, fallback)
	---@type table?
	local tb = WG.TerraformBrush
	if tb and tb.getWorldPositionExtended then
		local wx, wz, fade = tb.getWorldPositionExtended(radius)
		if wx then
			return wx, wz, fade or 1
		end
		return nil, nil, 1
	end
	local x, z = (fallback or WorldTool.plainCursor)()
	return x, z, 1
end

---A regular polygon outline, vertex 0 on +X before the turn.
---@param cx any
---@param cz any
---@param radius any circumradius along X
---@param angleDeg any
---@param sides any
---@param lengthScale any Z stretch, 1 when nil
---@param lift any elmos above the ground; nil hugs it with a polygon offset
---@param subdiv any points per edge
function WorldTool.drawPolygon(cx, cz, radius, angleDeg, sides, lengthScale, lift, subdiv)
	lengthScale = lengthScale or 1.0
	subdiv = subdiv or (sides <= 8 and WorldTool.EDGE_SEGMENTS or 1)
	local hug = lift == nil
	local up = lift or 0
	local angleStep = 2 * pi / sides
	if hug then
		glPolygonOffset(-2, -2)
	end
	glBeginEnd(GL_LINE_LOOP, function()
		for i = 0, sides - 1 do
			local a0 = i * angleStep
			local a1 = (i + 1) * angleStep
			local x0 = cos(a0) * radius
			local z0 = sin(a0) * radius * lengthScale
			local x1 = cos(a1) * radius
			local z1 = sin(a1) * radius * lengthScale
			for s = 0, subdiv - 1 do
				local t = s / subdiv
				local rx, rz = rotate(x0 + (x1 - x0) * t, z0 + (z1 - z0) * t, angleDeg)
				local wx, wz = cx + rx, cz + rz
				glVertex(wx, GetGroundHeight(wx, wz) + up, wz)
			end
		end
	end)
	if hug then
		glPolygonOffset(false)
	end
end

---A square outline, corners at (+-radius, +-radius * lengthScale) before the turn.
---@param cx any
---@param cz any
---@param radius any half the side along X
---@param angleDeg any
---@param lengthScale any Z stretch, 1 when nil
---@param lift any elmos above the ground; nil hugs it with a polygon offset
---@param subdiv any points per edge, EDGE_SEGMENTS when nil
function WorldTool.drawSquare(cx, cz, radius, angleDeg, lengthScale, lift, subdiv)
	lengthScale = lengthScale or 1.0
	subdiv = subdiv or WorldTool.EDGE_SEGMENTS
	local hug = lift == nil
	local up = lift or 0
	local rz = radius * lengthScale
	-- corner k, from (-radius, -rz) round to (-radius, rz)
	local function corner(k)
		if k == 1 then
			return -radius, -rz
		elseif k == 2 then
			return radius, -rz
		elseif k == 3 then
			return radius, rz
		end
		return -radius, rz
	end
	if hug then
		glPolygonOffset(-2, -2)
	end
	glBeginEnd(GL_LINE_LOOP, function()
		for i = 1, 4 do
			local x0, z0 = corner(i)
			local x1, z1 = corner((i % 4) + 1)
			for s = 0, subdiv - 1 do
				local t = s / subdiv
				local ox, oz = rotate(x0 + (x1 - x0) * t, z0 + (z1 - z0) * t, angleDeg)
				local wx, wz = cx + ox, cz + oz
				glVertex(wx, GetGroundHeight(wx, wz) + up, wz)
			end
		end
	end)
	if hug then
		glPolygonOffset(false)
	end
end

---@type table<string, integer?>
local SHAPE_SIDES = { hexagon = 6, octagon = 8, triangle = 3 }

---The outline of a BrushShape; anything else draws nothing.
---@param shape any
---@param cx any
---@param cz any
---@param radius any
---@param angleDeg any
---@param lengthScale any
---@param lift any
---@param subdiv any
---@param circleSides any the circle's segment count
function WorldTool.drawShape(shape, cx, cz, radius, angleDeg, lengthScale, lift, subdiv, circleSides)
	if shape == "square" then
		WorldTool.drawSquare(cx, cz, radius, angleDeg, lengthScale, lift, subdiv)
	elseif shape == "circle" then
		WorldTool.drawPolygon(cx, cz, radius, angleDeg, circleSides, lengthScale, lift, subdiv)
	elseif SHAPE_SIDES[shape] then
		WorldTool.drawPolygon(cx, cz, radius, angleDeg, SHAPE_SIDES[shape], lengthScale, lift, subdiv)
	end
end

---The smart filter overlay: small quads on a grid over the brush, green where `predicate` lets a stamp land
---and red where it refuses. The grid is laid out unturned inside the shape and turned with the brush, the
---way placement lays out its stamps.
---@param cx any
---@param cz any
---@param radius any
---@param shape any
---@param angleDeg any
---@param lengthScale any Z stretch, 1 when nil
---@param fade any cursor fade, scales the alpha
---@param step any elmos between grid points
---@param flatLift any nil: each quad corner sits 3 elmos above the ground under it; a number: the whole quad at the ground height of its centre plus this
---@param predicate any number, wz: number, a1: any, a2: any, a3: any): boolean
---@param a1 any passed on to predicate
---@param a2 any
---@param a3 any
function WorldTool.drawFilterOverlay(
	cx,
	cz,
	radius,
	shape,
	angleDeg,
	lengthScale,
	fade,
	step,
	flatLift,
	predicate,
	a1,
	a2,
	a3
)
	lengthScale = lengthScale or 1.0
	local halfStep = step * 0.3
	local rad = angleDeg * pi / 180
	local cosR, sinR = cos(rad), sin(rad)
	local radiusZ = radius * lengthScale
	glDepthTest(true)
	glBeginEnd(GL_TRIANGLES, function()
		for lx = -radius, radius, step do
			for lz = -radiusZ, radiusZ, step do
				if isInside(lx, lz, radius, shape, 0, lengthScale) then
					local wx = cx + lx * cosR - lz * sinR
					local wz = cz + lx * sinR + lz * cosR
					if predicate(wx, wz, a1, a2, a3) then
						glColor(0.2, 0.85, 0.3, 0.08 * fade)
					else
						glColor(0.9, 0.15, 0.15, 0.14 * fade)
					end
					local x0, x1, z0, z1 = wx - halfStep, wx + halfStep, wz - halfStep, wz + halfStep
					local y00, y10, y01, y11
					if flatLift then
						y00 = GetGroundHeight(wx, wz) + flatLift
						y10, y01, y11 = y00, y00, y00
					else
						y00 = GetGroundHeight(x0, z0) + 3
						y10 = GetGroundHeight(x1, z0) + 3
						y01 = GetGroundHeight(x0, z1) + 3
						y11 = GetGroundHeight(x1, z1) + 3
					end
					glVertex(x0, y00, z0)
					glVertex(x1, y10, z0)
					glVertex(x1, y11, z1)
					glVertex(x0, y00, z0)
					glVertex(x1, y11, z1)
					glVertex(x0, y01, z1)
				end
			end
		end
	end)
	glDepthTest(false)
end

---Corner points of a shape's outline (offsets from the centre), for the altitude cap prism: 16 for a circle,
---else the outline's vertices.
---@param shape any
---@param radius any
---@param angleDeg any
---@return table corners { {dx, dz}, ... }
function WorldTool.shapeCorners(shape, radius, angleDeg)
	local corners = {}
	local rad = angleDeg * pi / 180
	if shape == "square" then
		local pts = { { -radius, -radius }, { radius, -radius }, { radius, radius }, { -radius, radius } }
		for _, p in ipairs(pts) do
			local rx = p[1] * cos(rad) - p[2] * sin(rad)
			local rz = p[1] * sin(rad) + p[2] * cos(rad)
			corners[#corners + 1] = { rx, rz }
		end
		return corners
	end
	local n = shape == "circle" and 16 or SHAPE_SIDES[shape]
	if n then
		for i = 0, n - 1 do
			local a = i * (2 * pi / n) + rad
			corners[#corners + 1] = { radius * cos(a), radius * sin(a) }
		end
	end
	return corners
end

---The altitude cap prism: the shape drawn at the min (cyan) and max (orange) caps with white struts between.
---@param cx any
---@param cz any
---@param radius any
---@param shape any
---@param angleDeg any
---@param sf any
---@param fade any cursor fade, scales the alpha
function WorldTool.drawAltitudePrism(cx, cz, radius, shape, angleDeg, sf, fade)
	if not sf.altMinEnable and not sf.altMaxEnable then
		return
	end
	local corners = WorldTool.shapeCorners(shape, radius, angleDeg)
	if #corners == 0 then
		return
	end
	local botY = sf.altMinEnable and sf.altMin or nil
	local topY = sf.altMaxEnable and sf.altMax or nil

	glDepthTest(true)
	glLineWidth(1.5)
	if topY then
		glColor(1.0, 0.6, 0.1, 0.55 * fade)
		glBeginEnd(GL_LINE_LOOP, function()
			for i = 1, #corners do
				glVertex(cx + corners[i][1], topY, cz + corners[i][2])
			end
		end)
	end
	if botY then
		glColor(0.1, 0.6, 1.0, 0.55 * fade)
		glBeginEnd(GL_LINE_LOOP, function()
			for i = 1, #corners do
				glVertex(cx + corners[i][1], botY, cz + corners[i][2])
			end
		end)
	end
	local stride = max(1, floor(#corners / 8))
	---@type number
	local strutBot = botY or (topY and topY - 100) or 0
	---@type number
	local strutTop = topY or (botY and botY + 100) or 0
	glColor(1, 1, 1, 0.2 * fade)
	glBeginEnd(GL_LINES, function()
		for i = 1, #corners, stride do
			---@type number
			local wx = cx + corners[i][1]
			---@type number
			local wz = cz + corners[i][2]
			glVertex(wx, strutBot, wz)
			glVertex(wx, strutTop, wz)
		end
	end)
	glLineWidth(1)
	glDepthTest(false)
end

return WorldTool
