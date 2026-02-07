function gadget:GetInfo()
    return {
        name      = "Seismic Ping",
        desc      = "Draw seismic pings effect",
        author    = "Floris",
        date      = "2026",
        license   = "GNU GPL, v2 or later",
        version   = 1,
        layer     = 5,
        enabled   = true
    }
end


if gadgetHandler:IsSyncedCode() then
	return
end


--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------
local spGetSpectatingState = Spring.GetSpectatingState
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetGroundHeight = Spring.GetGroundHeight
local spGetViewGeometry = Spring.GetViewGeometry

local glColor = gl.Color
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glRotate = gl.Rotate
local glScale = gl.Scale
local glBlending = gl.Blending
local glDepthTest = gl.DepthTest
local glBillboard = gl.Billboard
local glCallList = gl.CallList
local glCreateList = gl.CreateList
local glDeleteList = gl.DeleteList
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_QUADS = GL.QUADS

local sin = math.sin
local cos = math.cos
local pi = math.pi
local pi2 = pi * 2
local max = math.max
local min = math.min

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------
local pingLifetime = 0.95
local baseRadius = 16
local maxRadius = 22
local baseThickness = 2.4

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local pings = {}
local gameTime = 0
local thicknessScale = 1.2

--------------------------------------------------------------------------------
-- Display lists for arc geometry (pre-generated at unit radius with proportional thickness)
--------------------------------------------------------------------------------
local displayLists = {
	outerArcs = {},      -- 4 arcs at 60 degrees each
	middleArcs = {},     -- 3 arcs at 80 degrees each
	innerArcs = {},      -- 2 arcs at 120 degrees each
	centerCircle = nil,  -- Full circle
	-- Outlines (slightly larger versions for dark border)
	outerOutlines = {},
	middleOutlines = {},
	innerOutlines = {},
}

-- Proportional thicknesses (relative to unit radius 1.0)
local outerThicknessRatio = baseThickness * 1.05 / baseRadius
local middleThicknessRatio = baseThickness * 0.8 / baseRadius
local innerThicknessRatio = baseThickness * 1 / baseRadius
local centerThicknessRatio = baseThickness * 1.8 / baseRadius
local outlineExtra = 0.02  -- How much larger the outline is on each side

--------------------------------------------------------------------------------
-- Helper: Draw a thick arc as geometry (for display list creation)
--------------------------------------------------------------------------------
local function DrawThickArcVertices(innerRadius, outerRadius, startAngle, endAngle, segments)
	local angleStep = (endAngle - startAngle) / segments
	for i = 0, segments - 1 do
		local angle1 = startAngle + i * angleStep
		local angle2 = startAngle + (i + 1) * angleStep
		local cos1, sin1 = cos(angle1), sin(angle1)
		local cos2, sin2 = cos(angle2), sin(angle2)
		glVertex(cos1 * innerRadius, sin1 * innerRadius, 0)
		glVertex(cos1 * outerRadius, sin1 * outerRadius, 0)
		glVertex(cos2 * outerRadius, sin2 * outerRadius, 0)
		glVertex(cos2 * innerRadius, sin2 * innerRadius, 0)
	end
end

--------------------------------------------------------------------------------
-- Create display lists for all arc types
--------------------------------------------------------------------------------
local function CreateDisplayLists()
	-- Outer arcs: 4 arcs, 60 degrees each, at unit radius with proportional thickness
	local outerInner = 1.08 - outerThicknessRatio / 2
	local outerOuter = 1.08 + outerThicknessRatio / 2
	for i = 0, 3 do
		local startAngle = (i * 90) * pi / 180
		local arcLength = 60 * pi / 180
		-- Outline (slightly larger)
		displayLists.outerOutlines[i] = glCreateList(function()
			glBeginEnd(GL_QUADS, DrawThickArcVertices, outerInner - outlineExtra, outerOuter + outlineExtra, startAngle - 0.02, startAngle + arcLength + 0.02, 12)
		end)
		-- Main arc
		displayLists.outerArcs[i] = glCreateList(function()
			glBeginEnd(GL_QUADS, DrawThickArcVertices, outerInner, outerOuter, startAngle, startAngle + arcLength, 12)
		end)
	end

	-- Middle arcs: 3 arcs, 80 degrees each, at 0.85 of unit radius
	local middleRadiusRatio = 0.85
	local middleInner = middleRadiusRatio - middleThicknessRatio / 2
	local middleOuter = middleRadiusRatio + middleThicknessRatio / 2
	for i = 0, 2 do
		local startAngle = (i * 120) * pi / 180
		local arcLength = 80 * pi / 180
		-- Outline (slightly larger)
		displayLists.middleOutlines[i] = glCreateList(function()
			glBeginEnd(GL_QUADS, DrawThickArcVertices, middleInner - outlineExtra, middleOuter + outlineExtra, startAngle - 0.02, startAngle + arcLength + 0.02, 12)
		end)
		-- Main arc
		displayLists.middleArcs[i] = glCreateList(function()
			glBeginEnd(GL_QUADS, DrawThickArcVertices, middleInner, middleOuter, startAngle, startAngle + arcLength, 12)
		end)
	end

	-- Inner arcs: 2 arcs, 120 degrees each, at 0.66 of unit radius
	local innerRadiusRatio = 0.66
	local innerInner = innerRadiusRatio - innerThicknessRatio / 2
	local innerOuter = innerRadiusRatio + innerThicknessRatio / 2
	for i = 0, 1 do
		local startAngle = (i * 180) * pi / 180
		local arcLength = 120 * pi / 180
		-- Outline (slightly larger)
		displayLists.innerOutlines[i] = glCreateList(function()
			glBeginEnd(GL_QUADS, DrawThickArcVertices, innerInner - outlineExtra, innerOuter + outlineExtra, startAngle - 0.02, startAngle + arcLength + 0.02, 16)
		end)
		-- Main arc
		displayLists.innerArcs[i] = glCreateList(function()
			glBeginEnd(GL_QUADS, DrawThickArcVertices, innerInner, innerOuter, startAngle, startAngle + arcLength, 16)
		end)
	end

	-- Center circle: full circle at unit radius with proportional thickness
	local centerInner = 1 - centerThicknessRatio / 1.3
	local centerOuter = 1.25 + centerThicknessRatio / 1.3
	displayLists.centerCircle = glCreateList(function()
		glBeginEnd(GL_QUADS, DrawThickArcVertices, centerInner, centerOuter, 0, pi2, 20)
	end)
end

--------------------------------------------------------------------------------
-- Delete display lists
--------------------------------------------------------------------------------
local function DeleteDisplayLists()
	for i = 0, 3 do
		if displayLists.outerArcs[i] then glDeleteList(displayLists.outerArcs[i]) end
		if displayLists.outerOutlines[i] then glDeleteList(displayLists.outerOutlines[i]) end
	end
	for i = 0, 2 do
		if displayLists.middleArcs[i] then glDeleteList(displayLists.middleArcs[i]) end
		if displayLists.middleOutlines[i] then glDeleteList(displayLists.middleOutlines[i]) end
	end
	for i = 0, 1 do
		if displayLists.innerArcs[i] then glDeleteList(displayLists.innerArcs[i]) end
		if displayLists.innerOutlines[i] then glDeleteList(displayLists.innerOutlines[i]) end
	end
	if displayLists.centerCircle then glDeleteList(displayLists.centerCircle) end
end

--------------------------------------------------------------------------------
-- Draw a single seismic ping with rotating arcs using display lists
--------------------------------------------------------------------------------
local function DrawPing(ping, currentTime, cameraDistance)
	local age = currentTime - ping.startTime
	if age > pingLifetime then
		return false
	end

	local progress = age / pingLifetime
	local radius = (baseRadius + (maxRadius - baseRadius) * progress) * thicknessScale
	local wx, wy, wz = ping.x, ping.y, ping.z

	glPushMatrix()
	glTranslate(wx, wy + 5, wz)
	glBillboard()

	-- Calculate all progress/alpha values
	local rotation1 = currentTime * 70
	local outerProgress = min(1, progress * 1.3)
	local outerAlpha = max(0, (1 - outerProgress) * 0.7)
	local outerRadius = radius*1.15-(radius*progress*0.25)

	local rotation2 = -currentTime * 150
	local middleProgress = max(0, min(1, (progress - 0.1) / 0.9))
	local middleAlpha = max(0, (1 - middleProgress) * 0.85)
	local middleRadius = radius+(radius*progress*0.4)

	local rotation3 = currentTime * 90
	local innerProgress = max(0, min(1, (progress - 0.15) / 0.85))
	local innerAlpha = max(0, (1 - innerProgress))
	local innerRadius = radius-(radius*progress*0.45)

	-- PASS 1: Draw all dark outlines with normal blending (skip when camera is far away for performance)
	if cameraDistance < 3000 then
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

		-- Outer outlines
		glColor(0.09, 0, 0, outerAlpha * 0.25)
		for i = 0, 3 do
			glPushMatrix()
			glRotate(rotation1, 0, 0, 1)
			glScale(outerRadius, outerRadius, 1)
			glCallList(displayLists.outerOutlines[i])
			glPopMatrix()
		end

		-- Middle outlines
		glColor(0.09, 0, 0, middleAlpha * 0.25)
		for i = 0, 2 do
			glPushMatrix()
			glRotate(rotation2, 0, 0, 1)
			glScale(middleRadius, middleRadius, 1)
			glCallList(displayLists.middleOutlines[i])
			glPopMatrix()
		end

		-- Inner outlines
		glColor(0.07, 0, 0, innerAlpha * 0.25)
		for i = 0, 1 do
			glPushMatrix()
			glRotate(rotation3, 0, 0, 1)
			glScale(innerRadius, innerRadius, 1)
			glCallList(displayLists.innerOutlines[i])
			glPopMatrix()
		end
	end

	-- PASS 2: Draw all bright arcs with additive blending
	glBlending(GL_SRC_ALPHA, GL_ONE)

	-- Outer ring - 4 arcs rotating clockwise
	glColor(1, 0.1, 0.09, outerAlpha)
	for i = 0, 3 do
		glPushMatrix()
		glRotate(rotation1, 0, 0, 1)
		glScale(outerRadius, outerRadius, 1)
		glCallList(displayLists.outerArcs[i])
		glPopMatrix()
	end

	-- Middle ring - 3 arcs rotating counter-clockwise
	glColor(1, 0.22, 0.2, middleAlpha)
	for i = 0, 2 do
		glPushMatrix()
		glRotate(rotation2, 0, 0, 1)
		glScale(middleRadius, middleRadius, 1)
		glCallList(displayLists.middleArcs[i])
		glPopMatrix()
	end

	-- Inner ring - 2 arcs rotating clockwise
	glColor(1, 0.37, 0.33, innerAlpha)
	for i = 0, 1 do
		glPushMatrix()
		glRotate(rotation3, 0, 0, 1)
		glScale(innerRadius, innerRadius, 1)
		glCallList(displayLists.innerArcs[i])
		glPopMatrix()
	end

	-- Center dot (shrinks from large to small with fade in/out)
	local centerProgress = min(1, progress * 1.8)
	local centerScale = baseRadius * 0.82 * (1 - centerProgress) * thicknessScale
	if centerScale > 0.1 then
		local centerAlphaMultiplier
		if centerProgress < 0.2 then
			centerAlphaMultiplier = centerProgress / 0.2
		else
			centerAlphaMultiplier = (1 - centerProgress) / 0.8
		end
		local centerAlpha = max(0, centerAlphaMultiplier * 0.6)
		glColor(1, 0.25, 0.23, centerAlpha)
		glPushMatrix()
		glScale(centerScale, centerScale, 1)
		glCallList(displayLists.centerCircle)
		glPopMatrix()
	end

	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glPopMatrix()

	return true
end

--------------------------------------------------------------------------------
-- callins
--------------------------------------------------------------------------------
function gadget:Initialize()
	CreateDisplayLists()
end

function gadget:Shutdown()
	DeleteDisplayLists()
end

function gadget:UnitSeismicPing(x, y, z, strength, allyTeam, unitID, unitDefID)
	local spec, fullview = spGetSpectatingState()
	local myAllyTeam = spGetMyAllyTeamID()
	local unitAllyTeam = Spring.GetUnitAllyTeam(unitID)

	if (spec or allyTeam == myAllyTeam) and unitAllyTeam ~= allyTeam then
		if spec and not fullview then
			if allyTeam ~= myAllyTeam then return end
		end

		table.insert(pings, {
			x = x,
			y = spGetGroundHeight(x, z) or y,
			z = z,
			strength = strength,
			startTime = gameTime,
		})
	end
end

function gadget:Update(dt)
	gameTime = gameTime + dt
end

function gadget:DrawWorld()
	if #pings == 0 then return end

	glDepthTest(false)

	-- Get visible world bounds for culling
	local cx, cy, cz = Spring.GetCameraPosition()
	local cs = Spring.GetCameraState()
	local vsx, vsy = spGetViewGeometry()

	-- Calculate visible world area based on camera state
	local viewDistance = cy / math.tan(math.rad(cs.fov or 45))
	local viewWidth = viewDistance * (vsx / vsy)
	local margin = maxRadius * thicknessScale * 3  -- Add margin for ping radius

	local minX = cx - viewWidth - margin
	local maxX = cx + viewWidth + margin
	local minZ = cz - viewDistance - margin
	local maxZ = cz + viewDistance + margin

	local currentTime = gameTime
	local i = 1
	while i <= #pings do
		local ping = pings[i]
		-- Check if ping is within visible bounds
		if ping.x < minX or ping.x > maxX or ping.z < minZ or ping.z > maxZ then
			-- Ping is outside view, skip drawing but don't remove yet
			if currentTime - ping.startTime > pingLifetime then
				table.remove(pings, i)
			else
				i = i + 1
			end
		else
			-- Ping is visible, try to draw it
			if not DrawPing(ping, currentTime, cy) then
				table.remove(pings, i)
			else
				i = i + 1
			end
		end
	end

	glDepthTest(true)
	glColor(1, 1, 1, 1)
end
