local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Collision Volumes Debug",
		desc = "/colvols toggles /debugcolvol and draws the unit volumes it leaves out",
		author = "efrec",
		date = "2026-10",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- /colvols [0|1]
--
-- `/debugcolvol` draws only the piece volumes on units with piece definitions.
-- But their main unit volume is still used in a lot of checks:
-- - setting the unit's overall bounding radius
-- - friendly-fire avoidance for spread weapons
-- - explosion falloff distance when no piece was hit
-- - which projectiles test the unit at all
--
-- /colvols turns on /debugcolvol and also draws those unit volumes in blue.
-- They are drawn in DrawWorldPreUnit, underneath the engine's debug volumes.

local math_cos = math.cos
local math_sin = math.sin
local math_pi = math.pi
local format = string.format

local spGetUnitCollisionVolumeData = Spring.GetUnitCollisionVolumeData
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitVectors = Spring.GetUnitVectors
local spGetVisibleUnits = Spring.GetVisibleUnits
local spSendCommands = Spring.SendCommands

local glBeginEnd = gl.BeginEnd
local glBlending = gl.Blending
local glCallList = gl.CallList
local glColor = gl.Color
local glCreateList = gl.CreateList
local glDeleteList = gl.DeleteList
local glDepthMask = gl.DepthMask
local glDepthTest = gl.DepthTest
local glLineWidth = gl.LineWidth
local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glTranslate = gl.Translate
local glUnitMultMatrix = gl.UnitMultMatrix
local glVertex = gl.Vertex

local ALL_UNITS = Spring.ALL_UNITS
local COLVOL_TYPE_CYLINDER = 1
local COLVOL_TYPE_BOX = 2
local SEGMENTS = 20
local LINE_WIDTH = 1
local COLOR = { 0.2, 0.55, 1.0, 0.5 } -- blue

local hasPieceVolumes = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.collisionVolume.defaultToPieceTree then
		hasPieceVolumes[unitDefID] = true
	end
end

local isEnabled = false
local shapeLists = {} -- display lists in volume space, by shape and scale

--------------------------------------------------------------------------------
-- Shapes ----------------------------------------------------------------------

local function vertexOnAxes(axis, a, b, c)
	if axis == 0 then
		glVertex(c, a, b)
	elseif axis == 1 then
		glVertex(a, c, b)
	else
		glVertex(a, b, c)
	end
end

local function drawBox(hx, hy, hz)
	for _, sy in ipairs({ -hy, hy }) do
		glVertex(-hx, sy, -hz)
		glVertex(hx, sy, -hz)
		glVertex(hx, sy, -hz)
		glVertex(hx, sy, hz)
		glVertex(hx, sy, hz)
		glVertex(-hx, sy, hz)
		glVertex(-hx, sy, hz)
		glVertex(-hx, sy, -hz)
	end
	for _, sx in ipairs({ -hx, hx }) do
		for _, sz in ipairs({ -hz, hz }) do
			glVertex(sx, -hy, sz)
			glVertex(sx, hy, sz)
		end
	end
end

local function drawCylinder(axis, ra, rb, h)
	for k = 0, SEGMENTS - 1 do
		local t0, t1 = 2 * math_pi * k / SEGMENTS, 2 * math_pi * (k + 1) / SEGMENTS
		local a0, b0 = ra * math_cos(t0), rb * math_sin(t0)
		local a1, b1 = ra * math_cos(t1), rb * math_sin(t1)
		vertexOnAxes(axis, a0, b0, -h)
		vertexOnAxes(axis, a1, b1, -h)
		vertexOnAxes(axis, a0, b0, h)
		vertexOnAxes(axis, a1, b1, h)
		if k % (SEGMENTS / 4) == 0 then
			vertexOnAxes(axis, a0, b0, -h)
			vertexOnAxes(axis, a0, b0, h)
		end
	end
end

local function drawEllipsoid(hx, hy, hz)
	for k = 0, SEGMENTS - 1 do
		local t0, t1 = 2 * math_pi * k / SEGMENTS, 2 * math_pi * (k + 1) / SEGMENTS
		local c0, s0, c1, s1 = math_cos(t0), math_sin(t0), math_cos(t1), math_sin(t1)
		glVertex(c0 * hx, s0 * hy, 0)
		glVertex(c1 * hx, s1 * hy, 0)
		glVertex(c0 * hx, 0, s0 * hz)
		glVertex(c1 * hx, 0, s1 * hz)
		glVertex(0, c0 * hy, s0 * hz)
		glVertex(0, c1 * hy, s1 * hz)
	end
end

local function getShapeList(sx, sy, sz, volumeType, axis)
	local key = format("%d %d %g %g %g", volumeType, axis, sx, sy, sz)
	local list = shapeLists[key]
	if list == nil then
		local hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
		list = glCreateList(glBeginEnd, GL.LINES, function()
			if volumeType == COLVOL_TYPE_BOX then
				drawBox(hx, hy, hz)
			elseif volumeType == COLVOL_TYPE_CYLINDER then
				if axis == 0 then
					drawCylinder(axis, hy, hz, hx)
				elseif axis == 1 then
					drawCylinder(axis, hx, hz, hy)
				else
					drawCylinder(axis, hx, hy, hz)
				end
			else
				drawEllipsoid(hx, hy, hz)
			end
		end)
		shapeLists[key] = list
	end
	return list
end

--------------------------------------------------------------------------------
-- Drawing ---------------------------------------------------------------------

local function drawUnitVolume(unitID)
	local sx, sy, sz, ox, oy, oz, volumeType, _, axis = spGetUnitCollisionVolumeData(unitID)
	if sx == nil then
		return
	end

	-- Origin is the unit's midpoint. Orientation is in unit space, where +x is along -right.
	local bx, by, bz, mx, my, mz = spGetUnitPosition(unitID, true)
	local front, up, right = spGetUnitVectors(unitID)
	local dx, dy, dz = mx - bx, my - by, mz - bz
	local relX = -(dx * right[1] + dy * right[2] + dz * right[3])
	local relY = dx * up[1] + dy * up[2] + dz * up[3]
	local relZ = dx * front[1] + dy * front[2] + dz * front[3]

	glPushMatrix()
	glUnitMultMatrix(unitID)
	glTranslate(relX + ox, relY + oy, relZ + oz)
	glCallList(getShapeList(sx, sy, sz, volumeType, axis))
	glPopMatrix()
end

function widget:DrawWorldPreUnit()
	-- Terrain is in the depth buffer already. Unit models will cover these lines later.
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	glDepthTest(true)
	glDepthMask(true)
	glLineWidth(LINE_WIDTH)
	glColor(COLOR)

	local units = spGetVisibleUnits(ALL_UNITS)
	for i = 1, #units do
		local unitID = units[i]
		if hasPieceVolumes[spGetUnitDefID(unitID)] then
			drawUnitVolume(unitID)
		end
	end

	glColor(1, 1, 1, 1)
	glLineWidth(1)
	glBlending(false)
end

--------------------------------------------------------------------------------
-- Command ---------------------------------------------------------------------

local function colvols(enable)
	isEnabled = enable
	spSendCommands("DebugColVol " .. (enable and "1" or "0"))
	if enable then
		widgetHandler:UpdateCallIn("DrawWorldPreUnit")
	else
		widgetHandler:RemoveCallIn("DrawWorldPreUnit")
	end
end

local function colvolsCmd(_, _, words)
	local arg = words and words[1]
	if arg == nil then
		colvols(not isEnabled)
	else
		colvols(arg ~= "0" and arg ~= "false" and arg ~= "off")
	end
	return true
end

function widget:Initialize()
	widgetHandler:RemoveCallIn("DrawWorldPreUnit")
	widgetHandler:AddAction("colvols", colvolsCmd, nil, "t")
end

function widget:Shutdown()
	widgetHandler:RemoveAction("colvols", "t")
	if isEnabled then
		spSendCommands("DebugColVol 0")
	end
	for _, list in pairs(shapeLists) do
		glDeleteList(list)
	end
end
