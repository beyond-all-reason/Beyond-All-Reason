-----------------------------------------------------------------------------------------------
--
-- Copyright 2024
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the “Software”), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
-- the Software, and to permit persons to whom the Software is furnished to do so,
-- subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
-- FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
-- COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
-- IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
-- CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-----------------------------------------------------------------------------------------------
--
-- Name: King of the Hill
-- Description: This gadget adds the UI components for the king of the hill game mode when it is enabled
-- Author: Saul Goodman
--
-----------------------------------------------------------------------------------------------
--
-- Documentation
--
-- This widget adds the unsynced UI functionality for a King of the Hill game mode. This
-- widget adds a box to the stack of boxes in the bottom-right corner of the screen. The box
-- contains a progress bar for each ally team indicating how close they are to winning. This
-- widget also draws outlines on the map around each team's starting box and the hill region.
--
-- The outlines on the map are drawn using a set of vertices on each outline and rendered
-- as GL.LINE_LOOP. The progress bars are each rectangles with a custom fragment shader
-- that colors the filled portion of the progress bar.
--
-- Goals (TODO)
--
--   Figure out how to make building footprint red when trying to build outside start box
--
-----------------------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name = "King of the Hill",
		desc = "Adds UI for King of the Hill game mode.",
		author = "Saul Goodman",
		date = "2025",
		license = "MIT",
		layer = -10,--Must come before gui_advplayerslist
		enabled = true
	};
end

-- #region Global Constants and Functions
local Spring = Spring
local Game = Game
local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ
local squareSize = Game.squareSize
local UnitDefs = UnitDefs
local UnitDefNames = UnitDefNames
local fps = Game.gameSpeed
local vsx, vsy--view size x and y
local gl = gl
local GL = GL
local VFS = VFS

local tonumber = tonumber
local math = math
table.unpack = table.unpack or unpack
local table = table
-- #endregion

-- /////////////////////////////
-- #region     Utils
-- /////////////////////////////

-- ---- Util Classes ----
-- ----------------------

--A Set class based on the Java API Set
local Set = {
	mt = {}
}
Set.mt.__index = Set
function Set.new()
	local set = {size = 0, elements = {}}
	setmetatable(set, Set.mt)
	return set
end
function Set:add(element)
	if not self.elements[element] then
		self.elements[element] = true
		self.size = self.size + 1
	end
end
function Set:addAll(...)
	for _, value in ipairs({...}) do
		self:add(value)
	end
end
function Set:remove(element)
	if self.elements[element] then
		self.elements[element] = nil
		self.size = self.size - 1
	end
end
function Set:removeAll(...)
	for _, value in ipairs({...}) do
		self:remove(value)
	end
end
function Set:retain(...)
	local newElements = {}
	local newSize = 0
	for _, value in ipairs({...}) do
		if self.elements[value] then
			newElements[value] = true
			newSize = newSize + 1
		end
	end
	self.elements = newElements
	self.size = newSize
end
function Set:contains(element)
	return self.elements[element]
end
function Set:containsAll(...)
	for _, value in ipairs({...}) do
		if not self.elements[value] then
			return false
		end
	end
	return true
end
function Set:clear()
	self.elements = {}
	self.size = 0
end
function Set:iter()
	return function (invariantState, controlVariable)
		local element = next(invariantState, controlVariable)
		return element
	end, self.elements, nil
end
function Set:unpack(lastElement)
	local nextElement = next(self.elements, lastElement)
	if nextElement ~= nil then
		return nextElement, self:unpack(nextElement)
	end
end

-- ---- Util Functions & Variables ----
-- ------------------------------------

local function distance(x1, z1, x2, z2)
	return math.sqrt((x2-x1)^2 + (z2-z1)^2)
end

local function insertArrayIntoArray(valueArray, containerArray)
	for _, value in ipairs(valueArray) do
		table.insert(containerArray, value)
	end
end

-- /////////////////////////////
-- #endregion
-- /////////////////////////////

-- #region Configuration Constants

--Defines the maximum value of the coordinate system used in the hill area mod option
local mapAreaScale = 200

--Defines the maximum number of vertices that will be used to draw a map area outline
local mapAreaMaxVertices = 190

--Defines the desired spacing (in world coords) between each map area vertex provided the total number does not exceed the maximum above
local mapAreaPreferredSpacing = 15

--Defines the width of the map area outlines
local mapAreaLineWidth = 1.5

--Defines how much to add the the y coordinate of each vertex of the map area outlines
local mapAreaLineVertexVerticalShift = 5

--Defines the name of the player list widget for ui box positioning
local playerListWidgetName = "advplayerlist_api"

--Defines the order in which to look for the widget below ours. The first widget that is found is used as
--the one below ours for positioning the ui box
local belowWidgetsInOrder = {"displayinfo", "unittotals", "music", playerListWidgetName}

--Defines the default width of the UI box if there are no boxes below it to go off of
local defaultUIBoxWidth = 340

--Defines the top and bottom padding on the ui box in pixels
local uiBoxVerticalPadding = 10

--Defines the horizontal padding in the ui box relative to box width
local uiBoxHorizontalPadding = 0.05

--Defines the width of a team progress bar relative to the ui box width
local progressBarWidth = 0.7

--Deifnes the height of a team progress bar in pixels
local progressBarHeight = 10

--Defines the vertical space between each team progress bar in pixels
local progressBarVerticalSpacing = 6

--Deifnes the height of the capture progress bar in pixels
local captureProgressBarHeight = 15

--Defines the margin above the capture bar in pixels
local captureProgressBarTopMargin = 15

--Defines the spacing in between the timers and progress bars relative to box width
local timerLeftMargin = 0.05

--Defines the font size of the timers next to the progress bars
local timerFontSize = 13

--Defines the text color of the timers next to the progress bars (rgba)
local timerFontColor = {1, 1, 1, 1}

--Defines the text color of the timer next to the progress bar for a disqualified team
local disqualifiedTimerFontColor = {0.7, 0.7, 0.7, 0.5}

--Defines the path to the font file for the text timers
local timerFontPath = "fonts/Exo2-Regular.otf"

--Progress bar shader file paths
local progressBarVertexShaderPath = "LuaUI/Shaders/kingofthehillui.vert.glsl"
local progressBarFragmentShaderPath = "LuaUI/Shaders/kingofthehillui.frag.glsl"

--Map area shader file paths
local mapAreaVertexShaderPath = "LuaUI/Shaders/kingofthehillmaparea.vert.glsl"
local mapAreaFragmentShaderPath = "LuaUI/Shaders/kingofthehillmaparea.frag.glsl"

--The size of the arrays in the fragment shaders
local fragmentShaderMaxTeams = 32

--Specifies the interval at which the UI is updated (i.e. updated every x frames)
local framesPerUpdate = 5

-- Used to update the position of the UI box multiple times after the screen is resized
-- since the ordering of the size updates from the lower widgets is unknown to me.
-- This represents the number of frames after the screen is resized for which we will
-- update the widget box size to match those below it
local maxScreenResizeCountdown = 10

--Defines the number of times to check if a team was disqualified after one of its
--member teams dies. Used to prevent checking every update.
local numDisqualifiedChecks = 5

-- #endregion

-- #region Mod Options

-- the MapArea defining the hill
local hillArea

-- whether or not players can build outside of their start area or the captured hill
local buildOutsideBoxes

-- the total time needed as king to win in milliseconds
local winKingTime

-- winKingTime in frames
local winKingTimeFrames

-- the number of milliseconds an ally team must occupy the hill to capture it
local captureDelay

-- captureDelay in frames
local captureDelayFrames

-- health multiplier for capture qualified units
local healthMultiplier

-- whether the king has globalLOS
local kingGlobalLos

-- whether units are immune to damage in their start boxes
local noDamageInBoxes

-- whether all units in the hill will explode when the king changes
local explodehillunits

-- #endregion

-- #region Main Variables

-- teamId to allyTeamId for all teams
local teamToAllyTeam = {}

-- array of allyTeamIds
local allyTeams = {}

-- allyTeamId to index in allyTeams
local allyTeamIndices = {}

-- the number of ally teams
local numAllyTeams = 0

-- allyTeamId to RectMapArea defining the allyTeam's starting area
local startBoxes = {}

-- a table of allyTeamId to the average color of all the constituent teams
local allyTeamColors = {}

-- the user's playerId
local myPlayerId

-- the user's ally team
local myAllyTeam

-- the user's start box as a RectMapArea object
local myStartBox

-- All game state variables below are only updated on an interval and may not exactly match the server at all times

-- allyTeamId to number of frames for which that team has held the hill
local allyTeamKingTime = {}

--The current king ally team's id.
local kingAllyTeam

--The frame on which the current king became king
local kingStartFrame

-- the allyTeamId of the ally team currently in the process of capturing the hill
local capturingAllyTeam

-- the frame at which the current capturing process will be complete (counting up or down, see below)
local capturingCompleteFrame

-- specifies the direction in which capturing progress is being made
-- true = up = progressing toward capturing the hill, false = down = losing progress that was previously made
local capturingCountingUp

-- allyTeamId to counter indicating the number of times remaining to check if the ally team is disqualified
-- this is used so that we are not checking every team every update but only teams who recently died
local disqualifiedTeamChecks = {}

-- #endregion

--//////////////////////////
-- #region       UI
--//////////////////////////

-- UI Variables
-- ------------

--Constants
local flowUIDraw

--Contains the position of the UI box. Used for WG API function 'GetPosition'
local uiBoxPosition

--Contains the position of the player list widget UI box. This is used to check for
--clicks on the player list and update our box size whenever it is clicked since
--clicking certain buttons in the player list causes it to change size
local playerListPosition

--The shaders for the progress bars
local progressBarShader = gl.CreateShader({vertex = VFS.LoadFile(progressBarVertexShaderPath),
												fragment = VFS.LoadFile(progressBarFragmentShaderPath)})
--Spring.Log("KingOfTheHill_ui", "error", "Shader Log: \n" .. gl.GetShaderLog())

--The shaders for the area outlines
local mapAreaShader = gl.CreateShader({vertex = VFS.LoadFile(mapAreaVertexShaderPath):gsub("//##UBO##", gl.GetEngineUniformBufferDef(0)),
											fragment = VFS.LoadFile(mapAreaFragmentShaderPath)})
--Spring.Log("KingOfTheHill_ui", "error", "Shader Log: \n" .. gl.GetShaderLog())

--A UBO containing an array of ally team colors
local allyTeamColorsUBO

--The UIElement for the box containing the progress bars
local uiBoxElement

-- allyTeamId to UIBar object for that team's progress bar
local allyTeamProgressBars = {}

-- The UIBar for the progress bar indicating the capture delay
local captureProgressBar

-- allyTeamId to UITextTimer object for that team's progress timer
local allyTeamProgressTimers = {}

-- The UITextTimer for the timer indicating the capture delay
local captureProgressTimer

-- The font used for the text timers
local timerFont

-- Used to update the position of the UI box multiple times after the screen is resized
-- since the ordering of the size updates from the lower widgets is unknown to me
local screenResizeCountdown = 0

-- UI Util Functions
-- -----------------

-- Converts the given x and y screen coordinates to clip space [-1, 1]
local function convertToClipSpace(x, y)
	if x and y then
		return 2*x/vsx - 1, 2*y/vsy - 1
	elseif x then
		return 2*x/vsx - 1
	elseif y then
		return 2*y/vsy - 1
	else
		return nil
	end
end

-- Prevents switching to a shader if it is currently active
local currentShader = nil
local function useShader(shader)
	if currentShader ~= shader then
		gl.UseShader(shader)
		currentShader = shader
	end
end

-- Prevent rebinding UBO if it is already bound
local allyTeamColorsUBOBound = false
local function bindAllyTeamColorsUBO()
	if allyTeamColorsUBOBound then
		return
	end
	allyTeamColorsUBO:BindBufferRange(6, false, false, GL.UNIFORM_BUFFER)
	allyTeamColorsUBOBound = true
end
local function unbindAllyTeamColorsUBO()
	if not allyTeamColorsUBOBound then
		return
	end
	allyTeamColorsUBO:UnbindBufferRange(6, false, false, GL.UNIFORM_BUFFER)
	allyTeamColorsUBOBound = false
end

--Prevent changing line width if already set to desired value
local currentLineWidth;
local function setLineWidth(width)
	if currentLineWidth ~= width then
		gl.LineWidth(width)
		currentLineWidth = width
	end
end
local function resetLineWidth()
	currentLineWidth = -1
end

-- UI Classes
-- ----------

-- This class is used to set the value of an OpenGL uniform. Its main purpose is to
-- prevent setting the uniform to the same value multiple times. Each instance of this
-- class represents one uniform value or index in a uniform array.
local UniformValue = {
	mt = {},
	Type = {INT = 1, FLOAT = 2, VECTOR = 3, ARRAY = 4, MATRIX = 5}
}
UniformValue.mt.__index = UniformValue
function UniformValue.new(args)
	args = args or {}
	if not args.name or not args.shader or not args.value or not args.type or (args.type == UniformValue.Type.ARRAY and not args.arraySubtype) then
		error("Missing one or more arguments for new UniformValue", 2)
	end
	setmetatable(args, UniformValue.mt)
	args.lastValue = nil
	args.location = args.location or gl.GetUniformLocation(args.shader, args.name)
	args.invalid = true
	return args
end
function UniformValue:update()
	if not self.invalid then
		return
	end
	useShader(self.shader)
	if self.type == UniformValue.Type.FLOAT then
		gl.Uniform(self.location, self.value)
	elseif self.type == UniformValue.Type.INT then
		gl.UniformInt(self.location, self.value)
	elseif self.type == UniformValue.Type.VECTOR then
		gl.Uniform(self.location, table.unpack(self.value))
	elseif self.type == UniformValue.Type.ARRAY then
		gl.UniformArray(self.location, self.arraySubtype, self.value)
	elseif self.type == UniformValue.Type.MATRIX then
		gl.UniformMatrix(self.location, self.value)
	end
	self.lastValue = self.value
	self.invalid = false
end
function UniformValue:set(newValue)
	self.value = newValue
	self.invalid = not self:equalsLastValue(newValue)
end
function UniformValue:setAndUpdate(newValue)
	self:set(newValue)
	self:update()
end
function UniformValue:equalsLastValue(newValue)
	if self.type == UniformValue.Type.VECTOR or self.type == UniformValue.Type.ARRAY or self.type == UniformValue.Type.MATRIX then
		for index, value in ipairs(self.lastValue) do
			if value ~= newValue[index] then
				return false
			end
		end
		return true
	end
	return self.lastValue == newValue
end

-- A class for a generic UI element, by default, renders a basic FlowUI box. This class and all its
-- subclasses below update the position and data associated with the element on a draw call whenever
-- it is invalidated.
local UIElement = {
	mt = {}
}
UIElement.mt.__index = UIElement
function UIElement.new(args)
	args = args or {}
	setmetatable(args, UIElement.mt)
	args.top = args.top or 0
	args.bottom = args.bottom or 0
	args.left = args.left or 0
	args.right = args.right or 0
	args.children = args.children or Set.new()
	if args.parent then
		args.parent.children:add(args)
	end
	args.width = args.right - args.left
	args.height = args.top - args.bottom
	args.positionInvalid = true
	args.dataInvalid = true
	return args
end
-- Meant to be called every frame in draw callin. Updates and draws this element
function UIElement:drawFrame()
	if self.positionInvalid then
		self:updatePosition()
	end
	if self.dataInvalid then
		self:updateData()
	end
	self:draw()
end
-- draws this UI element
function UIElement:draw()
	gl.CallList(self.displayList)
end
-- updates the position data of the UI element (i.e. VBO vertices)
function UIElement:updatePosition()
	self:computeAbsoluteRect()
	self:updateData()
	self.positionInvalid = false
end
-- updates the data associated with this UI element (i.e. UBO, SSBO, etc.)
function UIElement:updateData()
	gl.DeleteList(self.displayList)
	self.displayList = gl.CreateList(function ()
		flowUIDraw.Element(self.absLeft, self.absBottom, self.absRight, self.absTop, self.cornerTL, self.cornerTR, self.cornerBR, self.cornerBL, self.ptl, self.ptr, self.pbr, self.pbl,  self.opacity, self.color1, self.color2, self.bgpadding)
	end)
	self.dataInvalid = false
end
-- Invalidates the position data of this UI element (and all its children) so that it will be updated next render
function UIElement:invalidatePosition()
	self.positionInvalid = true
	for child in self.children:iter() do
		child:invalidatePosition()
	end
end
-- Invalidates the data associated with this UI element so that it will be updated next render
function UIElement:invalidateData()
	self.dataInvalid = true
end
function UIElement:setPos(args)
	if not ((args.top and args.top ~= self.top) or (args.right and args.right ~= self.right) or (args.bottom and args.bottom ~= self.bottom)
		or (args.left and args.left ~= self.left)) then
		return
	end
	self.top = args.top or self.top
	self.left = args.left or self.left
	self.bottom = args.bottom or self.bottom
	self.right = args.right or self.right
	self.width = self.right - self.left
	self.height = self.top - self.bottom
	self:invalidatePosition()
end
-- computes the absolute pixel coordinates of this UI element
-- abs coordinates are equivalent to x1 x2, y1 y2, relative coordinates are distance from side (like css)
function UIElement:computeAbsoluteRect()
	if self.parent then
		self.absLeft = self.parent.absLeft + (self.parent.absWidth * self.left)
		self.absRight = self.parent.absRight - (self.parent.absWidth * self.right)
		self.absBottom = self.parent.absBottom + (self.parent.absHeight * self.bottom)
		self.absTop = self.parent.absTop - (self.parent.absHeight * self.top)
		self.absWidth = self.absRight - self.absLeft
		self.absHeight = self.absTop - self.absBottom
	else
		self.absLeft = self.left
		self.absRight = self.right
		self.absBottom = self.bottom
		self.absTop = self.top
		self.absWidth = self.width
		self.absHeight = self.height
	end
end

-- A class for each UI progress bar
local UIBar = {
	mt = {},
	ProgressBarData = UniformValue.new({name = "progressBarData", shader = progressBarShader, value = 0, type = UniformValue.Type.INT}),
	Flags = {CAPTURE_BAR = 0x00800000, DISQUALIFIED = 0x00400000}
}
setmetatable(UIBar, UIElement.mt)
UIBar.mt.__index = UIBar
function UIBar.new(args)
	args = UIElement.new(args)
	args.flags = args.flags or 0
	if not args.allyTeam and (not args.flags or math.bit_and(args.flags, UIBar.Flags.CAPTURE_BAR) == 0) then
		error("Missing one or more arguments for new UIBar", 2)
	end
	setmetatable(args, UIBar.mt)
	args.allyTeamIndex = (allyTeamIndices[args.allyTeam] or 1) - 1
	args.shader = args.shader or progressBarShader
	local progressIndex = math.bit_and(args.flags, UIBar.Flags.CAPTURE_BAR) ~= 0 and fragmentShaderMaxTeams or args.allyTeamIndex
	args.progress = UniformValue.new({name = "progress[" .. progressIndex .. "]", shader = args.shader, value = args.progress or 0, type = UniformValue.Type.FLOAT})
	args.vbo = gl.GetVBO(GL.ARRAY_BUFFER, false)
	args.vbo:Define(4, {{id = 0, name = "position", size = 2}, {id = 1, name = "uv", size = 2}})
	args.vao = gl.GetVAO()
	args.vao:AttachVertexBuffer(args.vbo)
	return args
end
function UIBar:draw()
	useShader(self.shader)
	bindAllyTeamColorsUBO()
	UIBar.ProgressBarData:setAndUpdate(math.bit_or(self.allyTeamIndex, self.flags))
	self.vao:DrawArrays(GL.TRIANGLE_STRIP)
end
function UIBar:updatePosition()
	self:computeAbsoluteRect()
	--Progress bar region clip positions. Floor and ceil to round to nearest pixel to prevent fractional pixel artifacts
	local left = convertToClipSpace(math.floor(self.absLeft), nil)
	local right = convertToClipSpace(math.ceil(self.absRight), nil)
	local top = convertToClipSpace(nil, math.ceil(self.absTop))
	local bottom = convertToClipSpace(nil, math.floor(self.absBottom))
	--Triangle strip vertices with uv
	local vertices = {
		left, top, 0, 1,
		left, bottom, 0, 0,
		right, top, 1, 1,
		right, bottom, 1, 0
	}
	self.vbo:Upload(vertices)
	self.positionInvalid = false
end
function UIBar:updateData()
	self.progress:update()
	self.dataInvalid = false
end
function UIBar:setProgress(progress)
	progress = math.max(math.min(progress, 1), 0)
	if math.abs(progress - self.progress.lastValue) * self.absWidth >= 1 then
		self.progress:set(progress)
		self:invalidateData()
	end
end
function UIBar:setAllyTeam(allyTeamId)
	self.allyTeamIndex = (allyTeamIndices[allyTeamId] or 1) - 1
end
function UIBar:setDisqualified(value)
	local flag = UIBar.Flags.DISQUALIFIED
	if value then
		self.flags = math.bit_or(self.flags, flag)
	else
		self.flags = math.bit_and(self.flags, math.bit_inv(flag))
	end
end

-- A class for map area outlines rendered on the world
local UIMapArea = {
	mt = {},
	MapAreaData = UniformValue.new({name = "mapAreaData", shader = mapAreaShader, value = 0, type = UniformValue.Type.INT}),
	Flags = {HILL_AREA = 0x00800000}
}
setmetatable(UIMapArea, UIElement.mt)
UIMapArea.mt.__index = UIMapArea
function UIMapArea.new(args)
	args = UIElement.new(args)
	args.flags = args.flags or 0
	if not args.allyTeam and (not args.flags or math.bit_and(args.flags, UIMapArea.Flags.HILL_AREA) == 0) then
		error("Missing one or more arguments for new UIMapArea", 2)
	end
	setmetatable(args, UIMapArea.mt)
	args.allyTeamIndex = (allyTeamIndices[args.allyTeam] or fragmentShaderMaxTeams + 1) - 1
	args.lineWidth = args.lineWidth or mapAreaLineWidth
	args.shader = args.shader or mapAreaShader
	args.vbo = gl.GetVBO(GL.ARRAY_BUFFER, false)
	args.vbo:Define(#args.xzVertices, {{id = 0, name = "position", size = 3}})
	args.vao = gl.GetVAO()
	args.vao:AttachVertexBuffer(args.vbo)
	return args
end
function UIMapArea:draw()
	useShader(self.shader)
	bindAllyTeamColorsUBO()
	setLineWidth(self.lineWidth)
	UIMapArea.MapAreaData:setAndUpdate(math.bit_or(self.allyTeamIndex, self.flags))
	self.vao:DrawArrays(GL.LINE_LOOP)
end
function UIMapArea:updatePosition()
	local vertices = {}
	for index, xzVertex in ipairs(self.xzVertices) do
		local offset = index * 3 - 2
		local x = xzVertex[1]
		local z = xzVertex[2]
		vertices[offset] = x
		vertices[offset + 1] = Spring.GetGroundHeight(x, z) + mapAreaLineVertexVerticalShift
		vertices[offset + 2] = z
	end
	self.vbo:Upload(vertices)
	self.positionInvalid = false
end
function UIMapArea:updateData()
	self.dataInvalid = false
end
function UIMapArea:setAllyTeam(allyTeamId)
	self.allyTeamIndex = (allyTeamIndices[allyTeamId] or fragmentShaderMaxTeams + 1) - 1
end
function UIMapArea:isRectIntersectingOutline(x1, z1, x2, z2)
	local corners = {x1, z1, x1, z2, x2, z1, x2, z2}
	local isInside = false
	local isOutside = false
	for i = 1, 7, 2 do
		local isPointInside = self:isPointInside(corners[i], corners[i + 1])
		isInside = isInside or isPointInside
		isOutside = isOutside or not isPointInside
		if isInside and isOutside then
			return true
		end
	end
	return false
end

local RectMapArea = {
	mt = {}
}
setmetatable(RectMapArea, UIMapArea.mt)
RectMapArea.mt.__index = RectMapArea
function RectMapArea.new(args)
	if not args.left or not args.right or not args.top or not args.bottom then
		error("Missing one or more arguments for new RectMapArea", 2)
	end
	args.type = args.type or "rect"
	args.centerX = (args.left + args.right) / 2
	args.centerZ = (args.top + args.bottom) / 2
	args.xSize = args.right - args.left
	args.zSize = args.bottom - args.top
	
	--Populate the XZ vertex coordinates
	local left, right, top, bottom, xSize, zSize = args.left, args.right, args.top, args.bottom, args.xSize, args.zSize
	local numVertices = math.min(math.ceil((xSize * 2 + zSize * 2) / mapAreaPreferredSpacing), mapAreaMaxVertices)
	local numXPoints = math.floor((numVertices - 4) * (xSize / (xSize + zSize)) / 2)
	local numZPoints = math.floor(((numVertices - 4) - (numXPoints * 2)) / 2)
	local xDelim = (xSize + 1) / numXPoints
	local zDelim = (zSize + 1) / numZPoints
	local topSide = {{left, top}}--the vertices along the top edge starting with the top left corner moving to the right not including the top right corner
	local bottomSide = {{right, bottom}}--the vertices along the bottom edge starting with the bottom right corner moving to the left not including the bottom left corner
	for i = 1, numXPoints, 1 do
		table.insert(topSide, {left + (xDelim * i), top})
		table.insert(bottomSide, {right - (xDelim * i), bottom})
	end
	local rightSide = {{right, top}}--the vertices along the right edge starting with the top right corner moving down not including the bottom right corner
	local leftSide = {{left, bottom}}--the vertices along the left edge starting with the bottom left corner moving up not including the top left corner
	for i = 1, numZPoints, 1 do
		table.insert(rightSide, {right, top + (zDelim * i)})
		table.insert(leftSide, {left, bottom - (zDelim * i)})
	end
	local xzVertices = {}
	insertArrayIntoArray(topSide, xzVertices)
	insertArrayIntoArray(rightSide, xzVertices)
	insertArrayIntoArray(bottomSide, xzVertices)
	insertArrayIntoArray(leftSide, xzVertices)
	args.xzVertices = xzVertices
	
	args = UIMapArea.new(args)
	setmetatable(args, RectMapArea.mt)
	return args
end
function RectMapArea:isPointInside(x, z)
	return x >= self.left and x <= self.right and z <= self.bottom and z >= self.top
end
function RectMapArea:isBuildingInside(x, z, sizeX, sizeZ)
	local top, right, bottom, left = z - sizeZ/2, x + sizeX/2, z + sizeZ/2, x - sizeX/2
	return top >= self.top and right <= self.right and bottom <= self.bottom and left >= self.left
end

local CircleMapArea = {
	mt = {}
}
setmetatable(CircleMapArea, UIMapArea.mt)
CircleMapArea.mt.__index = CircleMapArea
function CircleMapArea.new(args)
	if not args.x or not args.z or not args.radius then
		error("Missing one or more arguments for new CircleMapArea", 2)
	end
	args.type = args.type or "circle"
	args.circumference = 2 * math.pi * args.radius
	
	--Populate the XZ vertex coordinates
	args.xzVertices = {}
	local numVertices = math.min(math.ceil(args.circumference / mapAreaPreferredSpacing), mapAreaMaxVertices)
	local angleDelim = 2 * math.pi / numVertices
	for i = 0, 2 * math.pi, angleDelim do
		table.insert(args.xzVertices, {args.x + (args.radius * math.cos(i)), args.z + (args.radius * math.sin(i))})
	end
	
	args = UIMapArea.new(args)
	setmetatable(args, CircleMapArea.mt)
	return args
end
function CircleMapArea:isPointInside(x, z)
	return distance(x, z, self.x, self.z) <= self.radius
end
function CircleMapArea:isBuildingInside(x, z, sizeX, sizeZ)
	local top, right, bottom, left = z - sizeZ/2, x + sizeX/2, z + sizeZ/2, x - sizeX/2
	return self:isPointInside(left, top) and self:isPointInside(right, top) and self:isPointInside(right, bottom) and self:isPointInside(left, bottom)
end

-- A class for the timer next to each progress bar
local UITextTimer = {
	mt = {}
}
setmetatable(UITextTimer, UIElement.mt)
UITextTimer.mt.__index = UITextTimer
function UITextTimer.new(args)
	args = UIElement.new(args)
	if not args.totalTimeSecs then
		error("Missing one or more arguments for new UITextTimer", 2)
	end
	setmetatable(args, UITextTimer.mt)
	args.fontSize = args.fontSize or timerFontSize
	args.color = args.color or timerFontColor
	args.originalColor = args.color
	args.disqualifiedColor = args.disqualifiedColor or disqualifiedTimerFontColor
	args.currentTimeSecs = math.ceil(args.totalTimeSecs)
	args.disqualified = false
	return args
end
function UITextTimer:draw()
	gl.CallList(self.displayList)
end
function UITextTimer:updatePosition()
	self:computeAbsoluteRect()
	self:updateData()
	self.positionInvalid = false
end
function UITextTimer:updateData()
	gl.DeleteList(self.displayList)
	local minutes = math.floor(self.currentTimeSecs / 60)
	local seconds = self.currentTimeSecs % 60
	local timeString
	if minutes > 0 then
		local secondsString = tostring(seconds)
		if seconds < 10 then
			secondsString = "0" .. secondsString
		end
		timeString = tostring(minutes) .. ":" .. secondsString
	else
		timeString = tostring(seconds) .. "s"
	end
	self.displayList = gl.CreateList(function ()
		timerFont:SetTextColor(self.color)
		timerFont:Print(timeString, self.absLeft, self.absBottom + self.absHeight / 2, self.fontSize * uiBoxPosition.scale, "v")
	end)
	self.dataInvalid = false
end
function UITextTimer:setProgress(progress)
	progress = math.max(math.min(progress, 1), 0)
	local newTime = math.ceil((1 - progress) * self.totalTimeSecs)
	if newTime ~= self.currentTimeSecs then
		self.progress = progress
		self.currentTimeSecs = newTime
		self:invalidateData()
	end
end
function UITextTimer:setDisqualified(value)
	if self.disqualified == value then
		return
	end
	self.disqualified = value
	self.color = value and self.disqualifiedColor or self.originalColor
	self:invalidateData()
end

--///////////////
-- #endregion
--///////////////

-- Parses the modoptions that define the hill area and returns args for a MapArea constructor
-- Returns args instead of MapArea object because we still need to set some args after this function in widget:Initialize
local function parseAreaModOptions(left, right, top, bottom, type)
	if type == "rect" then
		-- Map coords have 0 at top left corner
		return {type = type, left = left*mapSizeX/mapAreaScale, top = top*mapSizeZ/mapAreaScale, right = right*mapSizeX/mapAreaScale, bottom = bottom*mapSizeZ/mapAreaScale}
	elseif type == "circle" then
		--Make sure that the area defined by left, right, top, bottom is square for a circle
		--Mod option coords are always [0,200] but map is not always square
		--Same code as used in lobby 'gui_battle_room_window.lua'
		--Invalid mod option coords must produce same circle as is rendered in lobby
		local currentAreaWidth = right - left
		local currentAreaHeight = bottom - top
		local currentAreaAspectRatio = currentAreaWidth / currentAreaHeight
		local targetAspectRatio =  mapSizeZ / mapSizeX
		if targetAspectRatio >= currentAreaAspectRatio then--needs to be made more wide and less tall, so keep width same and reduce height
			local newHeight = currentAreaWidth / targetAspectRatio
			bottom = top + newHeight
		else--needs to be made more tall and less wide, so keep height the same and reduce width
			local newWidth = currentAreaHeight * targetAspectRatio
			right = left + newWidth
		end
		
		return {type = type, x = ((left + right)/2)*mapSizeX/mapAreaScale, z = ((top + bottom)/2)*mapSizeZ/mapAreaScale, radius = ((right - left)/2)*mapSizeX/mapAreaScale}
	end
end

--Called when the addon is (re)loaded.
function widget:Initialize()
	
	--Get mod options to see if KOTH is enabled and, if so, get related settings
	local modOptions = Spring.GetModOptions()
	
	--Disable this widget if KOTH game mode is not enabled
	if not modOptions.kingofthehillenabled then
		widgetHandler.RemoveWidget()
		return
	end
	
	--Get and parse KOTH related mod options
	local hillAreaArgs = parseAreaModOptions(modOptions.kingofthehillarealeft, modOptions.kingofthehillarearight,
								modOptions.kingofthehillareatop, modOptions.kingofthehillareabottom,
								modOptions.kingofthehillareatype)
	hillAreaArgs.allyTeam = false
	hillAreaArgs.flags = UIMapArea.Flags.HILL_AREA
	hillArea = hillAreaArgs.type == "circle" and CircleMapArea.new(hillAreaArgs) or RectMapArea.new(hillAreaArgs)
	buildOutsideBoxes = not modOptions.kingofthehillbuildoutsideboxes
	winKingTime = (tonumber(modOptions.kingofthehillwinkingtime) or 10) * 60 * 1000
	winKingTimeFrames = fps * winKingTime / 1000
	captureDelay = (tonumber(modOptions.kingofthehillcapturedelay) or 20) * 1000
	captureDelayFrames = fps * captureDelay / 1000
	healthMultiplier = tonumber(modOptions.kingofthehillhealthmultiplier) or 1
	kingGlobalLos = modOptions.kingofthehillkinggloballos
	noDamageInBoxes = modOptions.kingofthehillnodamageinboxes
	explodehillunits = modOptions.kingofthehillexplodehillunits
	
	--Arrays for data in uniforms and UBO
	local allyTeamColorsVec4Array = {}
	
	-- Initialize the main box UIElement
	uiBoxElement = UIElement.new()
	
	local gaiaAllyTeamID
	if Spring.GetGaiaTeamID() then
		gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID()))
	end
	
	--Populate per team data such as start boxes, average color, porgress bars, etc.
	for index, allyTeamId in ipairs(Spring.GetAllyTeamList()) do
		if allyTeamId ~= gaiaAllyTeamID then
			table.insert(allyTeams, allyTeamId)
			allyTeamIndices[allyTeamId] = index
			numAllyTeams = numAllyTeams + 1
			allyTeamKingTime[allyTeamId] = 0
			disqualifiedTeamChecks[allyTeamId] = 1--Check once initially in case a team starts disqualified (e.g. if the widget is reloaded)
			
			local xMin, zMin, xMax, zMax = Spring.GetAllyTeamStartBox(allyTeamId)
			local startBox = RectMapArea.new{left = xMin, top = zMin, right = xMax, bottom = zMax, allyTeam = allyTeamId}
			startBoxes[allyTeamId] = startBox
			
			local red, green, blue = 0, 0, 0
			local numTeams = 0
			
			for _, teamId in ipairs(Spring.GetTeamList(allyTeamId)) do
				teamToAllyTeam[teamId] = allyTeamId
				
				-- color average computed using squares (https://youtu.be/LKnqECcg6Gw)
				local teamRed, teamGreen, teamBlue = Spring.GetTeamColor(teamId)
				red = red + teamRed ^ 2
				green = green + teamGreen ^ 2
				blue = blue + teamBlue ^ 2
				numTeams = numTeams + 1
			end
			
			-- r g b a = 1 2 3 4
			local averageColor = {math.sqrt(red/numTeams), math.sqrt(green/numTeams), math.sqrt(blue/numTeams), 1}
			allyTeamColors[allyTeamId] = averageColor
			
			allyTeamProgressBars[allyTeamId] = UIBar.new({allyTeam = allyTeamId, parent = uiBoxElement})
			allyTeamProgressTimers[allyTeamId] = UITextTimer.new({totalTimeSecs = winKingTime / 1000, parent = uiBoxElement})
			
			if index <= fragmentShaderMaxTeams then
				local dataOffset = (index - 1) * 4
				for j = 1, 4, 1 do
					allyTeamColorsVec4Array[dataOffset + j] = averageColor[j]
				end
			end
		end
	end
	
	-- color gets set when a team starts capturing
	captureProgressBar = UIBar.new({flags = UIBar.Flags.CAPTURE_BAR, parent = uiBoxElement})
	captureProgressTimer = UITextTimer.new({totalTimeSecs = captureDelay / 1000, parent = uiBoxElement})
	
	-- fill in extra space in uniform arrays
	for i = numAllyTeams * 4 + 1, fragmentShaderMaxTeams * 4, 1 do
		allyTeamColorsVec4Array[i] = 0
	end
	
	--Initialize the ally team colors UBO
	allyTeamColorsUBO = gl.GetVBO(GL.UNIFORM_BUFFER, false)
	allyTeamColorsUBO:Define(1, fragmentShaderMaxTeams)--seconds arg expects size in number of Vec4s
	allyTeamColorsUBO:Upload(allyTeamColorsVec4Array)
	
	myPlayerId = Spring.GetMyPlayerID()
	myAllyTeam = Spring.GetMyAllyTeamID()
	myStartBox = startBoxes[myAllyTeam]
	
	--Remove the call-in that cancels unpermitted build commands if building outside boxes is allowed
	if buildOutsideBoxes then
		widgetHandler.RemoveCallIn(nil, "CommandNotify")
	end
	
	vsx, vsy = Spring.GetViewGeometry()
	widget:ViewResize(vsx, vsy)
	
	--Register the API function used by other widgets to stack boxes in the bottom right corner of the screen
	WG.kingofthehill_ui = {}
	WG.kingofthehill_ui.GetPosition = function()
		return {uiBoxPosition.top, uiBoxPosition.left, uiBoxPosition.bottom, uiBoxPosition.right, uiBoxPosition.scale}
	end
	
end

-- Gets the position on the screen of the ui box of the widget below our box
-- We make our box the same width as the below box and put it right above
-- Returns top, left, bottom, right, scale
local function getBelowBoxPosition()
	local playerListWG = WG[playerListWidgetName]
	local pos = playerListWG and playerListWG.GetPosition() or {0, vsx, 0, vsx}
	playerListPosition = {top = pos[1], left = pos[2], bottom = pos[3], right = pos[4]}
	
	for _, widgetName in ipairs(belowWidgetsInOrder) do
		local widgetWG = WG[widgetName]
		if widgetWG then
			if widgetWG.GetPosition then
				local widgetPos = widgetWG.GetPosition()
				if widgetPos then
					return widgetPos
				end
			end
		end
	end
	
	local scale = Spring.GetConfigFloat("ui_scale", 1)
	return {0, math.floor(vsx-(defaultUIBoxWidth*scale)), 0, vsx, scale}
end

-- Updates uiBoxPosition to the correct value
local function updateUIBoxPosition()
	local belowBoxPos = getBelowBoxPosition()
	local top = math.ceil(belowBoxPos[1])
	local left = math.floor(belowBoxPos[2])
	local bottom = math.floor(belowBoxPos[3])
	local right = math.ceil(belowBoxPos[4])
	local scale = belowBoxPos[5]
	
	local scaledBoxVerticalPadding = math.ceil(uiBoxVerticalPadding * scale)
	local scaledBarHeight = math.ceil(progressBarHeight * scale)
	local scaledBarVerticalSpacing = math.ceil(progressBarVerticalSpacing * scale)
	local scaledCaptureBarHeight = math.ceil(captureProgressBarHeight * scale)
	local scaledCaptureBarTopMargin = math.ceil(captureProgressBarTopMargin * scale)
	local scaledUIBoxHeight = ((scaledBarHeight + scaledBarVerticalSpacing) * numAllyTeams) + (2 * scaledBoxVerticalPadding) - scaledBarVerticalSpacing + scaledCaptureBarTopMargin + scaledCaptureBarHeight
	
	uiBoxPosition = {
		left = left,
		right = right,
		top = top + scaledUIBoxHeight,
		bottom = top,
		width = right - left,
		height = scaledUIBoxHeight,
		scale = scale
	}
	
	uiBoxElement:setPos(uiBoxPosition)
	
	local relativeBarHeight = scaledBarHeight / uiBoxPosition.height
	local relativeBarVerticalSpacing = scaledBarVerticalSpacing / uiBoxPosition.height
	local relativeBoxVerticalPadding = scaledBoxVerticalPadding / uiBoxPosition.height
	
	local barTopRelCoord = relativeBoxVerticalPadding
	for _, allyTeamId in ipairs(allyTeams) do
		local uiBar = allyTeamProgressBars[allyTeamId]
		local uiTimer = allyTeamProgressTimers[allyTeamId]
		uiBar:setPos({top = barTopRelCoord, bottom = 1 - (barTopRelCoord + relativeBarHeight), left = uiBoxHorizontalPadding, right = 1 - (uiBoxHorizontalPadding + progressBarWidth)})
		uiTimer:setPos({top = uiBar.top, bottom = uiBar.bottom, left = uiBoxHorizontalPadding + progressBarWidth + timerLeftMargin, right = uiBoxHorizontalPadding})
		barTopRelCoord = barTopRelCoord + relativeBarHeight + relativeBarVerticalSpacing
	end
	
	local captureBarRelativeHeight = scaledCaptureBarHeight / uiBoxPosition.height
	local captureBarRelativeTopMargin = scaledCaptureBarTopMargin / uiBoxPosition.height
	captureProgressBar:setPos({top = barTopRelCoord - relativeBarVerticalSpacing + captureBarRelativeTopMargin, bottom = relativeBoxVerticalPadding, left = uiBoxHorizontalPadding, right = 1 - (uiBoxHorizontalPadding + progressBarWidth)})
	captureProgressTimer:setPos({top = captureProgressBar.top, bottom = captureProgressBar.bottom, left = uiBoxHorizontalPadding + progressBarWidth + timerLeftMargin, right = uiBoxHorizontalPadding})
	
end

-- Triggers the UI box position to be updated for the next couple frames.
-- This is used because we don't know the order of the updating of the boxes below ours, so
-- we just update many times.
local function triggerUIBoxResize()
	updateUIBoxPosition()
	screenResizeCountdown = maxScreenResizeCountdown
end

-- Called whenever the window is resized
function widget:ViewResize(vs_x, vs_y)
	vsx = vs_x
	vsy = vs_y
	flowUIDraw = WG.FlowUI.Draw
	timerFont = WG.fonts.getFont(timerFontPath)
	-- Call here as well as in widget:DrawScreen because I have no idea the order
	-- of other widgets resizing so we want the best chance of getting it right
	triggerUIBoxResize()
end

-- Called whenever a player's status changes e.g. becoming a spectator. Also called when changing teams.
-- Used to resize ui box whenever the player list box below changes size and update myAllyTeam and myStartBox
function widget:PlayerChanged(playerID)
	triggerUIBoxResize()
	if playerID == myPlayerId then
		myAllyTeam = Spring.GetMyAllyTeamID()
		myStartBox = startBoxes[myAllyTeam]
	end
end

-- Called whenever a new player joins the game.
-- Used to resize ui box whenever the player list box below changes size
function widget:PlayerAdded(playerID)
	triggerUIBoxResize()
end

-- Called whenever a player is removed from the game.
-- Used to resize ui box whenever the player list box below changes size
function widget:PlayerRemoved(playerID, reason)
	triggerUIBoxResize()
end

--Called when a mouse button is pressed. The button parameter supports up to 7 buttons.
--Must return true for MouseRelease and other functions to be called.
--Used to resize our ui box whenever the player list box is clicked since it can change size when certain buttons are clicked.
function widget:MousePress(x, y, button)
	--If left click and inside player list box
	if button == 1 and x <= playerListPosition.right and x >= playerListPosition.left and y >= playerListPosition.bottom and y <= playerListPosition.top then
		triggerUIBoxResize()
	end
	return false
end

local updateCounter = framesPerUpdate
-- Called for every game simulation frame
-- Used to update the progress bar when there is a king
function widget:GameFrame(frame)
	updateCounter = updateCounter - 1
	if updateCounter > 0 then
		return
	end
	updateCounter = framesPerUpdate
	
	local newKingStartFrame = Spring.GetGameRulesParam("kingStartFrame")
	local kingChanged = newKingStartFrame ~= kingStartFrame--King may still be the same if it changed and then changed back before we updated
	--														 but we still need to update king times if that is the case
	
	if kingChanged then
		local newKingAllyTeam = Spring.GetGameRulesParam("kingAllyTeam")
		kingAllyTeam = newKingAllyTeam
		hillArea:setAllyTeam(kingAllyTeam)
		
		for _, allyTeamId in ipairs(allyTeams) do
			local kingTime = Spring.GetGameRulesParam("allyTeamKingTime" .. allyTeamId)
			allyTeamKingTime[allyTeamId] = kingTime
			local progress = math.abs(kingTime) / winKingTimeFrames
			allyTeamProgressBars[allyTeamId]:setProgress(progress)
			allyTeamProgressTimers[allyTeamId]:setProgress(progress)
		end
		kingStartFrame = newKingStartFrame
	end
	
	if kingAllyTeam then
		local newKingProgress = (allyTeamKingTime[kingAllyTeam] + (frame - kingStartFrame)) / winKingTimeFrames
		allyTeamProgressBars[kingAllyTeam]:setProgress(newKingProgress)
		allyTeamProgressTimers[kingAllyTeam]:setProgress(newKingProgress)
	end
	
	--Check for disqualified teams
	for allyTeamId, numChecks in pairs(disqualifiedTeamChecks) do
		local isDisqualified = (Spring.GetGameRulesParam("allyTeamKingTime" .. allyTeamId)) < 0
		if isDisqualified then
			disqualifiedTeamChecks[allyTeamId] = nil
			allyTeamProgressBars[allyTeamId]:setDisqualified(true)
			allyTeamProgressTimers[allyTeamId]:setDisqualified(true)
		else
			disqualifiedTeamChecks[allyTeamId] = numChecks > 1 and numChecks - 1 or nil
		end
	end
	
	local newCapturingCompleteFrame = Spring.GetGameRulesParam("capturingCompleteFrame")
	local capturingTeamChanged = newCapturingCompleteFrame ~= capturingCompleteFrame
	
	capturingCountingUp = Spring.GetGameRulesParam("capturingCountingUp")
	
	if capturingTeamChanged then
		capturingCompleteFrame = newCapturingCompleteFrame
		capturingAllyTeam = Spring.GetGameRulesParam("capturingAllyTeam")
		captureProgressBar:setAllyTeam(capturingAllyTeam)
	end
	
	local captureProgress = (capturingCompleteFrame - frame) / captureDelayFrames
	if capturingCountingUp then
		captureProgress = 1 - captureProgress
	end
	captureProgressBar:setProgress(captureProgress)
	captureProgressTimer:setProgress(captureProgress)
end

--Called when a team dies. Used to signal that we should check for disqualified teams.
--We also resize the ui box because removing a team changes the sizes of the lower boxes.
function widget:TeamDied(teamID)
	local allyTeamId = teamToAllyTeam[teamID]
	disqualifiedTeamChecks[allyTeamId] = numDisqualifiedChecks
	triggerUIBoxResize()
end

function widget:UnsyncedHeightMapUpdate(x1, z1, x2, z2)--TODO consider using height texture in vertex shader
	x1, z1, x2, z2 = x1 * squareSize, z1 * squareSize, x2 * squareSize, z2 * squareSize
	
	for _, startArea in pairs(startBoxes) do
		if startArea:isRectIntersectingOutline(x1, z1, x2, z2) then
			startArea:invalidatePosition()
		end
	end
	
	if hillArea:isRectIntersectingOutline(x1, z1, x2, z2) then
		hillArea:invalidatePosition()
	end
end

-- No documentation. This is the call-in that many other widgets use to draw UI.
function widget:DrawScreen()
	
	if screenResizeCountdown > 0 then
		-- Update the UI box position multiple times because I have no idea the order
		-- of other widgets resizing so we want the best chance of getting it right
		updateUIBoxPosition()
		screenResizeCountdown = screenResizeCountdown - 1
	end
	
	gl.DepthTest(false)
	gl.DepthMask(false)
	
	uiBoxElement:drawFrame()
	
	for _, uiTextTimer in pairs(allyTeamProgressTimers) do
		uiTextTimer:drawFrame()
	end
	
	captureProgressTimer:drawFrame()
	
	for _, uiBar in pairs(allyTeamProgressBars) do
		uiBar:drawFrame()
	end
	
	captureProgressBar:drawFrame()
	
	unbindAllyTeamColorsUBO()
	useShader(0)
	
end

function widget:DrawWorldPreUnit()
	
	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(false)
	
	for _, mapArea in pairs(startBoxes) do
		mapArea:drawFrame()
	end
	
	hillArea:drawFrame()
	
	resetLineWidth()
	unbindAllyTeamColorsUBO()
	useShader(0)
	
end

-- Called when a command is issued. Returning true deletes the command and does not send it through the network.
-- Used to block build commands that are outside of permitted areas if buildOutsideBoxes is false
function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	local buildingUnitDef = UnitDefs[-cmdID]
	if buildingUnitDef and (buildingUnitDef.isBuilding or buildingUnitDef.isStaticBuilder) then
		local cmdX, _, cmdZ, rotation = table.unpack(cmdParams)
		-- rotation 0=south(-z), 1=east(+x), 2=north(+z), 3=west(-x), unitDef sizeX and sizeZ seem to refer to north/south orientation
		local sizeX = (rotation % 2 == 0 and buildingUnitDef.xsize or buildingUnitDef.zsize) * squareSize
		local sizeZ = (rotation % 2 == 0 and buildingUnitDef.zsize or buildingUnitDef.xsize) * squareSize
		if myStartBox:isBuildingInside(cmdX, cmdZ, sizeX, sizeZ) or (kingAllyTeam == myAllyTeam and hillArea:isBuildingInside(cmdX, cmdZ, sizeX, sizeZ)) then
			return false
		end
		return true
	end
	return false
end

function widget:Shutdown()
	
	gl.DeleteShader(progressBarShader)
	
	gl.DeleteShader(mapAreaShader)
	
	WG.kingofthehill_ui = nil
	
end