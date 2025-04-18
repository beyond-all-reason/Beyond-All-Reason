
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name	= "Shard Help: Draw and timer",
		desc	= "draw and crono stuff in-game that Shard tells me to",
		author	= "eronoobos",
		date 	= "June 2016",
		license	= "whatever",
		layer 	= 0,
		enabled	= false
	}
end

local timerStatCollectionFrames = 120
local lineArrowSize = 80

local aiTeams = {}
local emptyShapeIDs = {}
local teamChannelByID = {}
local commandBindings = {}
local shapeIDCounter = 0
local selectedTeamID
local selectedChannel
local lastTeamID
local lastChannel
local needUpdateRectangles, needUpdateCircles, needUpdateLines, needUpdatePoints, needUpdateLabels, needUpdateTimers
local displayOnOff = true
local shapeCount = 0
local lastKey
local shapesByString = {}

local timers = {}
local timerResults = {}
local timerStats = {}
local timerGotStats = {}
local timerPermaStats = {}
local timerSavedNames = {}
local lastTimerStatFrame = 0
local timerColumns = {}


local myFont, myMonoFont, needUpdateInterface, interfaceDisplayList

local colorLocations = {
	Rectangle = 5,
	Circle = 4,
	Line = 5,
	Point = 3,
}

local coordNames = { x=0, z=0, x1=0, z1=0, x2=0, z2=0, radius=0, y=0 }

local rectangleDisplayList = 0
local circleDisplayList = 0
local lineDisplayList = 0
local pointDisplayList = 0
local labelDisplayList = 0
local timerDisplayList = 0

local tRemove = table.remove
local mFloor = math.floor
local mCeil = math.ceil
local mAbs = math.abs
local mSqrt = math.sqrt
local mCos = math.cos
local mSin = math.sin
local twicePi = math.pi * 2
local mMin = math.min
local mMax = math.max

local spIsSphereInView = Spring.IsSphereInView
local spGetGroundHeight = Spring.GetGroundHeight
local spGetGroundInfo = Spring.GetGroundInfo
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spGetCameraState = Spring.GetCameraState
local spEcho = Spring.Echo
local spGetViewGeometry = Spring.GetViewGeometry
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glColor = gl.Color
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glDepthTest = gl.DepthTest
local glLineWidth = gl.LineWidth
local glPointSize = gl.PointSize
local glTranslate = gl.Translate
local glBillboard = gl.Billboard
-- local glText = gl.Text
-- local glBeginText = gl.BeginText
-- local glEndText = gl.EndText
local glLoadFont = gl.LoadFont
local glBlending = gl.Blending
local glUnitShape = gl.UnitShape

local GL_TRIANGLE_STRIP = GL.TRIANGLE_STRIP
local GL_TRIANGLE_FAN = GL.TRIANGLE_FAN
local GL_LINE_STRIP = GL.LINE_STRIP
local GL_LINE_LOOP = GL.LINE_LOOP
local GL_POINTS = GL.POINTS

local unitScale = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	unitScale[unitDefID] = math.max(unitDef.xsize, unitDef.zsize) * 5
end

local function pairsByKeys(t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

local function trim(s)
  return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

local function normalizeVector2d(vx, vy)
	if vx == 0 and vy == 0 then return 0, 0 end
	local dist = mSqrt(vx*vx + vy*vy)
	return vx/dist, vy/dist, dist
end

-- using GL_POINT
local function doPoint(x, y, z)
	glVertex(x, y, z)
end

-- using GL_LINE_STRIP
local function doLine(x1, y1, z1, x2, y2, z2)
    gl.Vertex(x1, y1, z1)
    gl.Vertex(x2, y2, z2)
end

-- using GL_TRIANGLE_STRIP
local function doTriangle(x1, y1, z1, x2, y2, z2, x3, y3, z3)
	glVertex(x1, y1, z1)
    glVertex(x2, y2, z2)
    glVertex(x3, y3, z3)
end

-- using GL_TRIANGLE_FAN
local function doCircle(x, y, z, radius, sides)
	local sideAngle = twicePi / sides
	glVertex(x, y, z)
	for i = 1, sides+1 do
		local cx = x + (radius * mCos(i * sideAngle))
		local cz = z + (radius * mSin(i * sideAngle))
		glVertex(cx, y, cz)
	end
end

-- using GL_LINE_LOOP
local function doEmptyCircle(x, y, z, radius, sides)
	local sideAngle = twicePi / sides
	for i = 1, sides do
		local cx = x + (radius * mCos(i * sideAngle))
		local cz = z + (radius * mSin(i * sideAngle))
		glVertex(cx, y, cz)
	end
end

-- using GL_LINE_LOOP
local function doEmptyCircle2d(x, y, radius, sides)
	local sideAngle = twicePi / sides
	for i = 1, sides do
		local cx = x + (radius * mCos(i * sideAngle))
		local cy = y + (radius * mSin(i * sideAngle))
		glVertex(cx, cy)
	end
end

-- using GL_TRIANGLE_STRIP
local function doRectangleFlat(x1, z1, x2, z2, y)
	glVertex(x1, y, z1)
	glVertex(x2, y, z1)
	glVertex(x2, y, z2)
	glVertex(x1, y, z1)
	glVertex(x1, y, z2)
	glVertex(x2, y, z2)
end

-- using GL_TRIANGLE_STRIP
local function doRectangle2d(x1, y1, x2, y2)
	glVertex(x1, y1)
	glVertex(x2, y1)
	glVertex(x2, y2)
	glVertex(x1, y1)
	glVertex(x1, y2)
	glVertex(x2, y2)
end

-- using GL_TRIANGLE_STRIP
-- local function doRectangleContoured(x1, z1, x2, z2, y1, y2, y3, y4)
-- 	glVertex(x1, y1, z1)
-- 	glVertex(x2, y2, z1)
-- 	glVertex(x2, y3, z2)
-- 	glVertex(x1, y1, z1)
-- 	glVertex(x1, y4, z2)
-- 	glVertex(x2, y3, z2)
-- end

-- using GL_LINE_LOOP
local function doEmptyRectangle(x1, z1, x2, z2, y)
	glVertex(x1, y, z1)
	glVertex(x2, y, z1)
	glVertex(x2, y, z2)
	glVertex(x1, y, z2)
end

local function CameraStatesMatch(stateA, stateB)
	if not stateA or not stateB then return end
	if #stateA ~= #stateB then return end
	for key, value in pairs(stateA) do
		if value ~= stateB[key] then return end
	end
	for key, value in pairs(stateB) do
		if value ~= stateA[key] then return end
	end
	return true
end

local function colorByTable(color)
	glColor(color[1], color[2], color[3], color[4])
end

local function GetShapes(teamID, channel)
	channel = channel or 1
	if not aiTeams[teamID] then
		aiTeams[teamID] = {}
	end
	if not aiTeams[teamID][channel] then
		aiTeams[teamID][channel] = {}
	end
	return aiTeams[teamID][channel]
end

local function DrawRectangles(shapes)
	glDepthTest(false)
	glPushMatrix()
	glLineWidth(2)
	for i = 1, #shapes do
		local shape = shapes[i]
		if shape.type == "rectangle" then
			colorByTable(shape.color)
			if shape.filled then
				if type(shape.filled) == 'string' then
					glBlending(shape.filled)
				end
				glBeginEnd(GL_TRIANGLE_STRIP, doRectangleFlat, shape.x1, shape.z1, shape.x2, shape.z2, shape.y)
				if type(shape.filled) == 'string' then
					glBlending('reset')
				end
			else
				glBeginEnd(GL_LINE_LOOP, doEmptyRectangle, shape.x1, shape.z1, shape.x2, shape.z2, shape.y)
			end
		end
	end
	glLineWidth(1)
	glColor(1, 1, 1, 0.5)
	glPopMatrix()
end

local function DrawCircles(shapes)
	glDepthTest(false)
	glPushMatrix()
	glLineWidth(2)
	for i = 1, #shapes do
		local shape = shapes[i]
		if shape.type == "circle" then
			colorByTable(shape.color)
			if shape.filled then
				if type(shape.filled) == 'string' then
					glBlending(shape.filled)
				end
				glBeginEnd(GL_TRIANGLE_FAN, doCircle, shape.x, shape.y, shape.z, shape.radius, shape.sides)
				if type(shape.filled) == 'string' then
					glBlending('reset')
				end
			else
				glBeginEnd(GL_LINE_LOOP, doEmptyCircle, shape.x, shape.y, shape.z, shape.radius, shape.sides)
			end
		end
	end
	glLineWidth(1)
	glColor(1, 1, 1, 0.5)
	glDepthTest(true)
	glPopMatrix()
end

local function DrawLines(shapes)
	glDepthTest(false)
	glPushMatrix()
	glLineWidth(2)
	for i = 1, #shapes do
		local shape = shapes[i]
		if shape.type == "line" then
			colorByTable(shape.color)
			glBeginEnd(GL_LINE_STRIP, doLine, shape.x1, shape.y1, shape.z1, shape.x2, shape.y2, shape.z2)
			if shape.arrow then
				glBeginEnd(GL_TRIANGLE_STRIP, doTriangle, shape.x2, shape.y2, shape.z2, shape.ax1, shape.y2, shape.az1, shape.ax2, shape.y2, shape.az2)
			end
		end
	end
	glLineWidth(1)
	glColor(1, 1, 1, 0.5)
	glDepthTest(true)
	glPopMatrix()
end

local function DrawPoints(shapes)
	glDepthTest(false)
	glPushMatrix()
	glPointSize(6)
	for i = 1, #shapes do
		local shape = shapes[i]
		if shape.type == "point" then
			colorByTable(shape.color)
			glBeginEnd(GL_POINTS, doPoint, shape.x, shape.y, shape.z)
		end
	end
	glPointSize(1)
	glColor(1, 1, 1, 0.5)
	glDepthTest(true)
	glPopMatrix()
end

local function DrawUnits(shapes)
	glDepthTest(false)
	glLineWidth(3)
	for i = 1, #shapes do
		local shape = shapes[i]
		if shape.type == "unit" then
			colorByTable(shape.color)
			glPushMatrix()
			glTranslate(shape.x, shape.y, shape.z)
			glBillboard()
			glBeginEnd(GL_LINE_LOOP, doEmptyCircle2d, 0, 0, shape.radius, shape.sides)
			glPopMatrix()
		end
	end
	glColor(1, 1, 1, 0.5)
	glLineWidth(1)
	glDepthTest(true)
end

local function DrawLabels(shapes)
	-- glBeginText()
	myFont:Begin()
	local labels = {}
	local labelsCount = 0
	for i = 1, #shapes do
		local shape = shapes[i]
		if shape.label and spIsSphereInView(shape.x, shape.y, shape.z, 50) then
			-- colorByTable(shape.color)
			local sx, sy = spWorldToScreenCoords(shape.x, shape.y, shape.z)
			local halfWidth = shape.halfLabelWidth
			for l = 1, labelsCount do
				local label = labels[l]
				if mAbs(label.sx - sx) < halfWidth + label.halfWidth then
					local dy = mAbs(label.sy - sy)
					if dy < 16 then
						sy = sy + (16-dy)
					end
				end
			end
			-- glText(shape.label, sx, sy, 12, "cd")
			local c = shape.color
			myFont:SetTextColor(c[1], c[2], c[3], 1)
			myFont:SetOutlineColor(shape.textOutlineColor)
			myFont:Print(shape.label, sx, sy, 12, "cdo")
			labelsCount = labelsCount + 1
			labels[labelsCount] = {sx=sx, sy=sy, halfWidth=halfWidth}
		end
	end
	myFont:End()
	-- glEndText()
end

local function DrawInterface()
	local viewX, viewY, posX, posY = spGetViewGeometry()
	local quarterX = mCeil(viewX * 0.25)
	local threeQuartersY = mCeil(viewY * 0.75)
	myMonoFont:Begin()
	myMonoFont:SetTextColor(1, 1, 1, 1)
	local teamParenthesis = 'press t to change'
	local channelParenthesis = 'press c to change'
	if lastKey == 99 then -- c
		channelParenthesis = 'press 1 through 9 to change'
		local y = threeQuartersY
		for channel, shapes in pairs(aiTeams[selectedTeamID]) do
			myMonoFont:Print('Channel ' .. channel .. " has " .. #shapes .. " shapes", quarterX, y, 16, "do")
			y = y - 24
		end
	elseif lastKey == 116 then -- t
		teamParenthesis = 'press 0 through 9 to change'
		local y = threeQuartersY
		for teamID, channels in pairs(aiTeams) do
			local chnCnt = 0
			local shpCnt = 0
			for channel, shapes in pairs(channels) do
				chnCnt = chnCnt + 1
				shpCnt = shpCnt + #shapes
			end
			myMonoFont:Print('Team ' .. teamID .. " has " .. chnCnt .. " channels and " .. shpCnt .. " shapes", quarterX, y, 16, "do")
			y = y - 24
		end
	end
	local shapes = GetShapes(selectedTeamID, selectedChannel)
	myMonoFont:Print('Team    ' .. selectedTeamID .. ' (' .. teamParenthesis .. ')', quarterX, 32, 16, "do")
	myMonoFont:Print('Channel ' .. selectedChannel .. ' (' .. channelParenthesis .. ')', quarterX, 56, 16, "do")
	myMonoFont:Print(#shapes .. ' Shapes in current Channel of current Team, of ' .. shapeCount .. ' total shapes', quarterX, 80, 16, "do")
	myMonoFont:End()
end

local function DrawTimers()
	local columns = timerColumns
	local viewX, viewY, posX, posY = spGetViewGeometry()
	local i = 0
	local longestHeadingWidth
	for c = 1, #columns do
		local col = columns[c]
		local width = myFont:GetTextWidth(col.heading .. ' ' .. col.field .. ' ' .. col.unit)
		if not longestHeadingWidth or width > longestHeadingWidth then
			longestHeadingWidth = width
		end
	end
	for name, _ in pairs(timerSavedNames) do
		for c = 1, #columns do
			local col = columns[c]
			local stats = col.stats[name]
			if stats then
				local num = stats[col.field]
				if not col.max or num > col.max then
					col.max = num
				end
			end
		end
		i = i + 1
	end
	if i == 0 then return end
	local rows = i+0
	local rowHeight = 14
	local spacing = 5
	local doubleSpacing = spacing * 2
	if (rows + 1) * rowHeight > viewY - doubleSpacing then
		rowHeight = mFloor((viewY - doubleSpacing) / (rows+1))
	end
	local barWidth = mCeil(rowHeight * longestHeadingWidth * 0.9)
	local halfBarWidth = mCeil(barWidth / 2)
	local colWidth = barWidth + spacing
	local namesBySum = {}
	for name, _ in pairs(timerSavedNames) do
		local stats = timerPermaStats[name]
		namesBySum[stats.sum] = name
	end
	i = 0
	for _, name in pairsByKeys(namesBySum) do
		local y1 = 5 + (rowHeight * i)
		local y2 = y1 + rowHeight
		for c = 1, #columns do
			local col = columns[c]
			local stats = col.stats[name]
			if stats then
				local num = stats[col.field]
				local numMax = col.max
				if num > 0 and numMax and numMax > 0 then
					local r = num / numMax
					local g = 1 - r
					local w = r * barWidth
					glColor(r,g,0,1)
					local x1 = viewX - (colWidth*c)
					local x2 = x1 + w
					glBeginEnd(GL_TRIANGLE_STRIP, doRectangle2d, x1, y1, x2, y2)
				end
			end
		end
		i = i + 1
	end
	local totalColumnsWidth = 5 + (colWidth * #columns)
	local nameX = viewX - totalColumnsWidth
	myFont:Begin()
	myFont:SetTextColor(1,1,1,1)
	i = 0
	for _, name in pairsByKeys(namesBySum) do
		local y = 5 + (rowHeight * i)
		for c = 1, #columns do
			local col = columns[c]
			local stats = col.stats[name]
			if stats then
				local num = stats[col.field]
				local x = viewX - (colWidth - halfBarWidth) - (colWidth * (c - 1))
				myFont:Print(num --[[.. col.unit]], x, y, rowHeight, "dco")
			end
		end
		myFont:Print(name, nameX, y, rowHeight, "dro")
		i = i + 1
	end
	local columnHeadingY = 5 + (rowHeight * i)
	for c = 1, #columns do
		local col = columns[c]
		local x = viewX - (colWidth - halfBarWidth) - (colWidth * (c - 1))
		myFont:Print(col.heading .. ' ' .. col.field .. ' ' .. col.unit, x, columnHeadingY, rowHeight, "dco")
	end
	myFont:End()
	glColor(1,1,1,0.5)
end

local function UpdateInterface()
	needUpdateInterface = true
end

local function UpdateLabels()
	needUpdateLabels = true
	UpdateInterface()
end

local function UpdateTimers()
	needUpdateTimers = true
end

local function UpdateShapesByType(shapeType)
	if not shapeType then
		needUpdateRectangles = true
		needUpdateCircles = true
		needUpdateLines = true
		needUpdatePoints = true
	elseif shapeType == "rectangle" then
		needUpdateRectangles = true
	elseif shapeType == "circle" then
		needUpdateCircles = true
	elseif shapeType == "line" then
		needUpdateLines = true
	elseif shapeType == "point" then
		needUpdatePoints = true
	end
	UpdateLabels()
end

local function GetShapeID()
	if #emptyShapeIDs > 0 then
		return tRemove(emptyShapeIDs)
	end
	shapeIDCounter = shapeIDCounter + 1
	return shapeIDCounter
end

local function GetShapeString(shape)
	local shapeString = shape.x .. " " .. shape.z .. " " .. tostring(shape.filled)
	if shape.x1 then
		shapeString = shapeString .. " " .. shape.x1 .. " " .. shape.z1 .. " " .. shape.x2 .. " " .. shape.z2
	end
	return shapeString
end

local function AddShape(shape, teamID, channel)
	channel = channel or 1
	shape.id = GetShapeID()
	local color = shape.color or {1, 1, 1, 0.5}
	color[1] = color[1] or 1
	color[2] = color[2] or 1
	color[3] = color[3] or 1
	color[4] = color[4] or 0.5
	shape.color = color
	local perceivedBrightness = mSqrt( 0.241*(color[1]^2) + 0.691*(color[2]^2) + 0.068*(color[3]^2) )
	if perceivedBrightness < 0.5 then
		shape.textOutlineColor = {1,1,1,1}
	else
		shape.textOutlineColor = {0,0,0,1}
	end
	if shape.label then
		shape.halfLabelWidth = myFont:GetTextWidth(shape.label) * 6
	end
	local shapes = GetShapes(teamID, channel)
	local shapeString = GetShapeString(shape)
	shapesByString[shapeString] = shapesByString[shapeString] or {}
	shape.y = shape.y + #shapesByString[shapeString] -- so that overlapping semitransparent shapes have an order
	shape.string = shapeString
	shapesByString[shapeString][#shapesByString[shapeString]+1] = shape
	lastTeamID = teamID
	lastChannel = channel
	shapes[#shapes+1] = shape
	teamChannelByID[shape.id] = {teamID = teamID, channel = channel}
	UpdateShapesByType(shape.type)
	shapeCount = shapeCount + 1
	return shape.id
end

local function AddRectangle(x1, z1, x2, z2, color, label, filled, teamID, channel)
	x1, z1, x2, z2 = mCeil(x1), mCeil(z1), mCeil(x2), mCeil(z2)
	local xAvg = mCeil( (x1 + x2) / 2 )
	local zAvg = mCeil( (z1 + z2) / 2 )
	local shape = {
		type = "rectangle",
		x = xAvg,
		z = zAvg,
		y = spGetGroundHeight(xAvg, zAvg),
		x1 = x1,
		z1 = z1,
		x2 = x2,
		z2 = z2,
		-- y1 = spGetGroundHeight(x1, z1),
		-- y2 = spGetGroundHeight(x2, z1),
		-- y3 = spGetGroundHeight(x2, z2),
		-- y4 = spGetGroundHeight(x1, z2),
		color = color,
		label = label,
		filled = filled,
	}
	return AddShape(shape, teamID, channel)
end

local function AddCircle(x, z, radius, color, label, filled, teamID, channel)
	x, z, radius = mCeil(x), mCeil(z), mCeil(radius)
	local shape = {
		type = "circle",
		x = x,
		z = z,
		y = spGetGroundHeight(x, z),
		radius = radius,
		color = color,
		label = label,
		filled = filled,
		sides = mCeil(mSqrt(radius*2)),
	}
	return AddShape(shape, teamID, channel)
end

local function AddLine(x1, z1, x2, z2, color, label, arrow, teamID, channel)
	x1, z1, x2, z2 = mCeil(x1), mCeil(z1), mCeil(x2), mCeil(z2)
	local xAvg = mCeil( (x1 + x2) / 2 )
	local zAvg = mCeil( (z1 + z2) / 2 )
	local shape = {
		type = "line",
		x = xAvg,
		z = zAvg,
		y = spGetGroundHeight(xAvg, zAvg),
		x1 = x1,
		z1 = z1,
		y1 = spGetGroundHeight(x1, z1),
		x2 = x2,
		z2 = z2,
		y2 = spGetGroundHeight(x2, z2),
		color = color,
		label = label,
		arrow = arrow,
	}
	if arrow then
		local dx = x2 - x1
		local dz = z2 - z1
		local vx, vz, dist = normalizeVector2d(dx, dz)
		local arrowSize = mMin(lineArrowSize, dist)
		local arrowSizeHalf = arrowSize / 2
		local backX, backZ = x2-(vx*arrowSize), z2-(vz*arrowSize)
		local ax1, az1 = backX+(vz*arrowSizeHalf), backZ-(vx*arrowSizeHalf)
		local ax2, az2 = backX-(vz*arrowSizeHalf), backZ+(vx*arrowSizeHalf)
		shape.ax1, shape.az1, shape.ax2, shape.az2 = ax1, az1, ax2, az2
	end
	return AddShape(shape, teamID, channel)
end

local function AddPoint(x, z, color, label, teamID, channel)
	x, z = mCeil(x), mCeil(z)
	local y = spGetGroundHeight(x, z)
	local shape = {
		type = "point",
		x = x,
		z = z,
		y = y,
		color = color,
		label = label,
	}
	return AddShape(shape, teamID, channel)
end

local function AddUnit(unitID, color, label, teamID, channel)
	local x, y, z = spGetUnitPosition(unitID)
	local unitDefID = spGetUnitDefID(unitID)
	local radius = unitScale[unitDefID]
	color = color or {}
	color[4] = 1
	local shape = {
		type = "unit",
		unitID = unitID,
		unitDefID = unitDefID,
		teamID = spGetUnitTeam(unitID),
		x = x,
		y = y,
		z = z,
		radius = radius,
		sides = mCeil(mSqrt(radius*2)),
		color = color,
		label = label,
	}
	return AddShape(shape, teamID, channel)
end

local function EraseShape(id, address)
	local found = false
	local tc = teamChannelByID[id]
	if not tc then
		return false
	end
	local shapes = GetShapes(tc.teamID, tc.channel)
	if not address then
		for i = #shapes, 1, -1 do
			local shape = shapes[i]
			if shape.id == id then
				address = i
				break
			end
		end
	end
	if address and shapes[address] then
		emptyShapeIDs[#emptyShapeIDs+1] = id
		teamChannelByID[id] = nil
		local foundShape = tRemove(shapes, address)
		shapesByString[foundShape.string] = nil
		UpdateShapesByType(foundShape.type)
		found = true
		shapeCount = shapeCount - 1
	end
	return found
end

local function EraseShapes(attributes, teamID, channel)
	for k, v in pairs(attributes) do
		if coordNames[k] then attributes[k] = mCeil(v) end
	end
	local shapes = GetShapes(teamID, channel)
	for i = #shapes, 1, -1 do
		local shape = shapes[i]
		local match = true
		for k, v in pairs(attributes) do
			local shapeV = shape[k]
			if v ~= shapeV then
				if type(v) == 'table' then
					if type(shapeV) == 'table' then
						for kk, vv in pairs(v) do
							if vv ~= shapeV[kk] then
								match = false
								break
							end
						end
					else
						match = false
					end
				else
					match = false
				end
			end
			if not match then
				break
			end
		end
		if match then
			EraseShape(shape.id, i)
		end
	end
end

local function EraseRectangle(x1, z1, x2, z2, color, label, filled, teamID, channel)
	EraseShapes({x1=x1, z1=z1, x2=x2, z2=z2, color=color, label=label, filled=filled}, teamID, channel)
end

local function EraseCircle(x, z, radius, color, label, filled, teamID, channel)
	EraseShapes({x=x, z=z, radius=radius, color=color, label=label, filled=filled}, teamID, channel)
end

local function EraseLine(x1, z1, x2, z2, color, label, arrow, teamID, channel)
	EraseShapes({x1=x1, z1=z1, x2=x2, z2=z2, color=color, label=label, arrow=arrow}, teamID, channel)
end

local function ErasePoint(x, z, color, label, teamID, channel)
	EraseShapes({x=x, z=z, color=color, label=label}, teamID, channel)
end

local function EraseUnit(unitID, color, label, teamID, channel)
	EraseShapes({unitID=unitID, color=color, label=label}, teamID, channel)
end

local function ClearShapes(teamID, channel)
	local shapes = GetShapes(teamID, channel)
	for i = #shapes, 1, -1 do
		local shape = shapes[i]
		EraseShape(shape.id, i)
	end
	UpdateShapesByType()
end

local function DisplayOnOff(onOff)--boolean

	displayOnOff = onOff
end

local function StartTimer(name)
	--spEcho("start timer", name)
	timers[name] = spGetTimer()
end

local function StopTimer(name)
	--spEcho("stop timer", name, timers[name])
	if not timers[name] then return end
	local ms = spDiffTimers(spGetTimer(), timers[name])
	if ms > 100 then
		spEcho(ms .. "ms", name)
	end
	timerResults[name] = ms
	timerStats[name] = timerStats[name] or {}
	local stats = timerStats[name]
	if not stats.max or ms > stats.max then
		stats.max = ms
	end
	if not stats.min or ms < stats.min then
		stats.min = ms
	end
	stats.sum = (stats.sum or 0) + ms
	stats.count = (stats.count or 0) + 1
	timerPermaStats[name] = timerPermaStats[name] or {}
	local permaStats = timerPermaStats[name]
	if not permaStats.max or ms > permaStats.max then
		permaStats.max = ms
	end
	if not permaStats.min or ms < permaStats.min then
		permaStats.min = ms
	end
	permaStats.sum = (permaStats.sum or 0) + ms
	permaStats.count = (permaStats.count or 0) + 1
	timers[name] = nil
end

local function CollectTimerStats()
	timerGotStats = {}
	for name, stats in pairs(timerStats) do
		stats.avg = stats.sum / stats.count
		timerGotStats[name] = stats
		if stats.sum > 0.01 then
			timerSavedNames[name] = true
		end
	end
	for name, stats in pairs(timerPermaStats) do
		stats.avg = stats.sum / stats.count
	end
	timerStats = {}
	timerColumns = {
		{stats = timerGotStats, field = 'sum', unit = 'ms', heading = '120gf'},
		{stats = timerGotStats, field = 'avg', unit = 'ms', heading = '120gf'},
		-- {stats = timerGotStats, field = 'min', unit = 'ms', heading = '120gf'},
		{stats = timerGotStats, field = 'max', unit = 'ms', heading = '120gf'},
		{stats = timerGotStats, field = 'count', unit = ' calls', heading = '120gf'},
		{stats = timerPermaStats, field = 'sum', unit = 'ms', heading = 'total'},
		{stats = timerPermaStats, field = 'avg', unit = 'ms', heading = 'total'},
		-- {stats = timerPermaStats, field = 'min', unit = 'ms', heading = 'total'},
		{stats = timerPermaStats, field = 'max', unit = 'ms', heading = 'total'},
		{stats = timerPermaStats, field = 'count', unit = ' calls', heading = 'total'},
	}
	UpdateTimers()
end

local function UpdateUnitPositions(shapes)
	for i = #shapes, 1, -1 do
		local shape = shapes[i]
		if shape.type == "unit" then
			shape.x, shape.y, shape.z = spGetUnitPosition(shape.unitID)
			if not shape.x then
				EraseShape(shape.id, i)
			end
		end
	end
end

local function InterpretStringData(data, command)
	local colorLoc
	for shapeTypeCapitalized, loc in pairs(colorLocations) do
		if string.find(command, shapeTypeCapitalized) then
			colorLoc = loc
			-- Spring.Echo(command, shapeTypeCapitalized, colorLoc)
			break
		end
	end
	local dataCount = #data
	for i = 1, #data do
		local d = data[i]
		-- Spring.Echo(i, d, "(raw)")
		if d == 'nil' then
			d = false
		elseif d == 'true' then
			d = true
		elseif d == 'false' then
			d = false
		elseif tonumber(d) then
			d = tonumber(d)
		end
		-- Spring.Echo(i, tostring(d), "(processed")
		data[i] = d
	end
	if colorLoc then
		local color = {}
		for i = 0, 3 do
			color[i+1] = data[colorLoc+i]
			if i > 0 then data[colorLoc+i] = "|REMOVE|" end
		end
		data[colorLoc] = color
	end
	local newData = {}
	local ndi = 0
	for i = 1, dataCount do
		local d = data[i]
		if d ~= "|REMOVE|" then
			ndi = ndi + 1
			newData[ndi] = d
			-- Spring.Echo(ndi, tostring(d))
		end
	end
	-- Spring.Echo(table.maxn(newData), "data fields out")
	return newData
end

local function SaveTable(tableinput, tablename, filename)
	Spring.Echo('Saving ' .. tablename .. ' on ' .. filename)
	local fileobj = io.open(filename, 'w')
	fileobj:write(tablename .. " = " .. tableinput)
	fileobj:close()
end

local boundCommands = {}
local function BindCommand(command, func)
	boundCommands[command] = true
	widgetHandler:RegisterGlobal(command, func)
	commandBindings[command] = func
end

local function ExecuteCommand(command, data)
	local execFunc = commandBindings[command]
	execFunc(unpack(data, 1, table.maxn(data)))
end

function widget:Initialize()
	BindCommand("ShardDrawAddRectangle", AddRectangle)
	BindCommand("ShardDrawAddCircle", AddCircle)
	BindCommand("ShardDrawAddLine", AddLine)
	BindCommand("ShardDrawAddPoint", AddPoint)
	BindCommand("ShardDrawAddUnit", AddUnit)
	BindCommand("ShardDrawEraseShape", EraseShape)
	BindCommand("ShardDrawEraseRectangle", EraseRectangle)
	BindCommand("ShardDrawEraseCircle", EraseCircle)
	BindCommand("ShardDrawEraseLine", EraseLine)
	BindCommand("ShardDrawErasePoint", ErasePoint)
	BindCommand("ShardDrawEraseUnit", EraseUnit)
	BindCommand("ShardDrawClearShapes", ClearShapes)
	BindCommand("ShardDrawDisplay", DisplayOnOff)
	BindCommand("ShardStartTimer", StartTimer)
	BindCommand("ShardStopTimer", StopTimer)
	BindCommand("ShardSaveTable", SaveTable)
	myFont = glLoadFont('fonts/Exo2-SemiBold.otf', 16, 4, 5)
	myMonoFont = glLoadFont('fonts/Mesmerize-Bold.ttf', 16, 4, 5) or myFont
	-- myFont:SetAutoOutlineColor(true)
end

function widget:GameFrame(frameNum)

	local buff = io.open('sharddrawbuffer', 'r')


	if buff then
		for line in buff:lines() do
			if line and line ~= '' and line ~= ' ' then
				widget:RecvSkirmishAIMessage(nil, line)
			end
		end
		buff:close()
	end
	local buffClear = io.open('sharddrawbuffer', 'w')
	if buffClear then
		buffClear:write(' ')
		buffClear:close()
	end
	if frameNum > lastTimerStatFrame + timerStatCollectionFrames then
		CollectTimerStats()
		lastTimerStatFrame = frameNum
	end
	if shapeCount == 0 or not displayOnOff or not selectedTeamID or not selectedChannel then
		return
	end
	local shapes = GetShapes(selectedTeamID, selectedChannel)
	UpdateUnitPositions(shapes)
end

function widget:RecvSkirmishAIMessage(teamID, dataStr)
	dataStr = trim(dataStr)
	if dataStr:sub(1,9) == 'ShardDraw' then
		local data = string.split(dataStr, '|')
		local command = tRemove(data, 1)
		-- Spring.Echo(command)
		data = InterpretStringData(data, command)
		ExecuteCommand(command, data)
	end
end

function widget:KeyPress(key, mods, isRepeat)
	-- Spring.Echo(key, mods, isRepeat)
	if shapeCount == 0 or not displayOnOff then
		return
	end
	if key > 47 and key < 58 then
		local number  = 0
		if key > 48 then
			number = key - 48
		end
		if lastKey == 99 and number > 0 then -- c
			selectedChannel = number
			UpdateShapesByType()
		elseif lastKey == 116 then -- t
			selectedTeamID = number
			UpdateShapesByType()
		end
	end
	lastKey = key
	UpdateInterface()
end

function widget:Update()
	if needUpdateTimers then
		timerDisplayList = glCreateList(DrawTimers)
		needUpdateTimers = false
	end
	if shapeCount == 0 or not displayOnOff then
		return
	end

	selectedTeamID = selectedTeamID or lastTeamID
	selectedChannel = selectedChannel or lastChannel
	if not selectedTeamID or not selectedChannel then
		return
	end
	local shapes = GetShapes(selectedTeamID, selectedChannel)
	if needUpdateRectangles then
		rectangleDisplayList = glCreateList(DrawRectangles, shapes)
		needUpdateRectangles = false
	end
	if needUpdateCircles then
		circleDisplayList = glCreateList(DrawCircles, shapes)
		needUpdateCircles = false
	end
	if needUpdateLines then
		lineDisplayList = glCreateList(DrawLines, shapes)
		needUpdateLines = false
	end
	if needUpdatePoints then
		pointDisplayList = glCreateList(DrawPoints, shapes)
		needUpdatePoints = false
	end
	-- if needUpdateLabels then
		-- labelDisplayList = glCreateList(DrawLabels, shapes)
		-- needUpdateLabels = false
	-- end
	if needUpdateInterface then
		interfaceDisplayList = glCreateList(DrawInterface)
		needUpdateInterface = false
	end
end

function widget:DrawWorldPreUnit()
	if shapeCount == 0 or not displayOnOff or not selectedTeamID or not selectedChannel then
		return
	end
	glCallList(rectangleDisplayList)
	glCallList(circleDisplayList)
	glCallList(lineDisplayList)
	glCallList(pointDisplayList)
end

function widget:DrawWorld()
	if shapeCount == 0 or not displayOnOff or not selectedTeamID or not selectedChannel then
		return
	end
	local shapes = GetShapes(selectedTeamID, selectedChannel)
	DrawUnits(shapes)
end

function widget:DrawScreen()
	glCallList(timerDisplayList)
	if shapeCount == 0 or not displayOnOff or not selectedTeamID or not selectedChannel then
		return
	end
	-- glCallList(labelDisplayList)
	local shapes = GetShapes(selectedTeamID, selectedChannel)
	DrawLabels(shapes)
	glCallList(interfaceDisplayList)
end

local function EchoStats(name, stats, longestName, longestKV, headings)
	local outStr = name
	if string.len(name) < longestName then
		for i = 1, longestName - string.len(name) do
			outStr = outStr .. ' '
		end
	end
	outStr = outStr .. "\t"
	for k, v in pairs(stats) do
		local str = tostring(v)
		if headings then str = k end
		outStr = outStr .. str
		if string.len(str) < longestKV[k] then
			for i = 1, longestKV[k] - string.len(str) do
				outStr = outStr .. ' '
			end
		end
		outStr = outStr .. "\t"
	end
	spEcho(outStr)
end

function widget:Shutdown()
	local longestName
	local anyName
	local longestKV = {}
	local i = 0
	for name, stats in pairs(timerPermaStats) do
		if stats.max > 0 then
			if not anyName then anyName = name end
			if not longestName or string.len(name) > longestName then
				longestName = string.len(name)
			end
			for k, v in pairs(stats) do
				local str = tostring(v)
				local l = string.len(str)
				if string.len(k) > l then
					str = k
					l = string.len(k)
				end
				if not longestKV[k] or l > longestKV[k] then
					longestKV[k] = l
				end
			end
			i = i + 1
		end
	end
	if i == 0 then return end
	Spring.SendCommands('screenshot')
	EchoStats('', timerPermaStats[anyName], longestName, longestKV, true)
	local namesBySum = {}
	for name, stats in pairs(timerPermaStats) do
		namesBySum[-stats.sum] = name
	end
	for _, name in pairsByKeys(namesBySum) do
		local stats = timerPermaStats[name]
		if stats.max > 0 then
			EchoStats(name, stats, longestName, longestKV)
		end
	end
	for i,v in pairs(boundCommands) do
		widgetHandler:DeregisterGlobal(boundCommands[i])
	end
end



