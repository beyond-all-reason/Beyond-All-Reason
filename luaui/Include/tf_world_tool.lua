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

local BrushShapes = require("common/brush_shapes")

local cos = math.cos
local sin = math.sin
local pi = math.pi
local rotate = BrushShapes.rotate

local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glPolygonOffset = gl.PolygonOffset
local GL_LINE_LOOP = GL.LINE_LOOP
local GetGroundHeight = Spring.GetGroundHeight

local WorldTool = {
	EDGE_SEGMENTS = 16,
	rotate = rotate,
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

return WorldTool
