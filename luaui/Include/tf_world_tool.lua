-- Terraform Brush world tools: the drawing helpers they share.
--
-- Every brush tool (terraform, features, units, grass, decals, weather, ...) draws a shape outline on the
-- ground, and they used to carry their own copies. The shapes follow common/brush_shapes.lua: vertex on +X
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
-- (common/smart_filter.lua) as WorldTool.smart.

local BrushShapes = require("common/brush_shapes")
local SmartFilter = require("common/smart_filter")

local cos = math.cos
local sin = math.sin
local pi = math.pi
local floor = math.floor
local max = math.max
local rotate = BrushShapes.rotate
local isInside = BrushShapes.isInside

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

local WorldTool = {
	EDGE_SEGMENTS = 16,
	rotate = rotate,
	smart = SmartFilter,
}

---A regular polygon outline, vertex 0 on +X before the turn.
---@param cx number
---@param cz number
---@param radius number circumradius along X
---@param angleDeg number
---@param sides integer
---@param lengthScale number? Z stretch, 1 when nil
---@param lift number? elmos above the ground; nil hugs it with a polygon offset
---@param subdiv integer? points per edge
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
---@param cx number
---@param cz number
---@param radius number half the side along X
---@param angleDeg number
---@param lengthScale number? Z stretch, 1 when nil
---@param lift number? elmos above the ground; nil hugs it with a polygon offset
---@param subdiv integer? points per edge, EDGE_SEGMENTS when nil
function WorldTool.drawSquare(cx, cz, radius, angleDeg, lengthScale, lift, subdiv)
	lengthScale = lengthScale or 1.0
	subdiv = subdiv or WorldTool.EDGE_SEGMENTS
	local hug = lift == nil
	local up = lift or 0
	local rz = radius * lengthScale
	local corners = { { -radius, -rz }, { radius, -rz }, { radius, rz }, { -radius, rz } }
	if hug then
		glPolygonOffset(-2, -2)
	end
	glBeginEnd(GL_LINE_LOOP, function()
		for i = 1, 4 do
			local c0, c1 = corners[i], corners[(i % 4) + 1]
			local x0, z0, x1, z1 = c0[1], c0[2], c1[1], c1[2]
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

local SHAPE_SIDES = { hexagon = 6, octagon = 8, triangle = 3 }

---The outline of a BrushShape; anything else draws nothing.
---@param shape string
---@param cx number
---@param cz number
---@param radius number
---@param angleDeg number
---@param lengthScale number?
---@param lift number?
---@param subdiv integer?
---@param circleSides integer the circle's segment count
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
---@param cx number
---@param cz number
---@param radius number
---@param shape string
---@param angleDeg number
---@param lengthScale number? Z stretch, 1 when nil
---@param fade number cursor fade, scales the alpha
---@param step number elmos between grid points
---@param flatLift number? nil: each quad corner sits 3 elmos above the ground under it; a number: the whole quad at the ground height of its centre plus this
---@param predicate fun(wx: number, wz: number, a1: any, a2: any, a3: any): boolean
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
---@param shape string
---@param radius number
---@param angleDeg number
---@return number[][]
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
---@param cx number
---@param cz number
---@param radius number
---@param shape string
---@param angleDeg number
---@param sf SmartFilterSettings
---@param fade number cursor fade, scales the alpha
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
	local strutBot = botY or (topY and topY - 100) or 0
	local strutTop = topY or (botY and botY + 100) or 0
	glColor(1, 1, 1, 0.2 * fade)
	glBeginEnd(GL_LINES, function()
		for i = 1, #corners, stride do
			local wx = cx + corners[i][1]
			local wz = cz + corners[i][2]
			glVertex(wx, strutBot, wz)
			glVertex(wx, strutTop, wz)
		end
	end)
	glLineWidth(1)
	glDepthTest(false)
end

return WorldTool
