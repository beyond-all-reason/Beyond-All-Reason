-- $Id$
local versionNumber = "v2.3"

function widget:GetInfo()
  return {
    name      = "Point Tracker",
    desc      = versionNumber .. " Tracks recently placed map points.",
    author    = "Evil4Zerggin",
    date      = "29 December 2008",
    license   = "GNU LGPL, v2.1 or later",
    layer     = 0,
    enabled   = false  --  loaded by default?
  }
end

----------------------------------------------------------------
--config
----------------------------------------------------------------
--negative to disable blinking
local blinkPeriod = -1
local ttl = 15
local highlightSize = 32
local highlightLineMin = 24
local highlightLineMax = 40
local edgeMarkerSize = 16
local lineWidth = 1
local maxAlpha = 1
local fontSize = 16
local maxLabelLength = 16

local minimapHighlightSize = 8
local minimapHighlightLineMin = 6
local minimapHighlightLineMax = 10

local useFade = true
----------------------------------------------------------------
--speedups
----------------------------------------------------------------
local ArePlayersAllied = Spring.ArePlayersAllied
local GetPlayerInfo = Spring.GetPlayerInfo
local GetTeamColor = Spring.GetTeamColor
local GetSpectatingState = Spring.GetSpectatingState
local WorldToScreenCoords = Spring.WorldToScreenCoords
local glColor = gl.Color
local glRect = gl.Rect
local glLineWidth = gl.LineWidth
local glShape = gl.Shape
local glPolygonMode = gl.PolygonMode
local glText = gl.Text
local max = math.max
local abs = math.abs
local strSub = string.sub
local GL_LINES = GL.LINES
local GL_TRIANGLES = GL.TRIANGLES
local GL_LINE = GL.LINE
local GL_FRONT_AND_BACK = GL.FRONT_AND_BACK
local GL_FILL = GL.FILL

----------------------------------------------------------------
--vars
----------------------------------------------------------------
--table; i = {r, g, b, a, px, pz, label, expiration}
local mapPoints = {}
local mapPointCount = 0
local MAP_POINT_LIMIT = 50
local myPlayerID
local timeNow, timePart
local on = false
local mapX = Game.mapX * 512
local mapY = Game.mapY * 512

local vsx, vsy, sMidX, sMidY

----------------------------------------------------------------
--local functions
----------------------------------------------------------------
local function GetPlayerColor(playerID)
	local _, _, isSpec, teamID = GetPlayerInfo(playerID)
	if (isSpec) then return GetTeamColor(Spring.GetGaiaTeamID()) end
	if (not teamID) then return nil end
	return GetTeamColor(teamID)
end

local function StartTime()
	local viewSizeX, viewSizeY = widgetHandler:GetViewSizes()
	widget:ViewResize(viewSizeX, viewSizeY)
	timeNow = 0
	timePart = 0
	on = true
end

local function ClearPoints()
	mapPoints = {}
end

local function SetUseFade(bool)
	useFade = bool
end
----------------------------------------------------------------
--callins
----------------------------------------------------------------

function widget:Initialize()
	timeNow = false
	timePart = false
	myPlayerID = Spring.GetMyPlayerID()
	
	WG.PointTracker = {
		ClearPoints = ClearPoints,
		SetUseFade = SetUseFade
	}
end

function widget:Shutdown()
	WG.PointTracker = nil
end

function widget:DrawScreen()
	if (not on) then return end
	
	glLineWidth(lineWidth)
	
	local i = 1
	while i <= mapPointCount do
		local curr = mapPoints[i]
		local alpha = maxAlpha * (curr[6] - timeNow) / ttl
		if (alpha <= 0) then
			mapPoints[i] = mapPoints[mapPointCount]
			mapPoints[mapPointCount] = nil
			mapPointCount = mapPointCount - 1
		else
			local sx, sy, sz = WorldToScreenCoords(curr[2], curr[3], curr[4])
			glColor(curr[1][1], curr[1][2], curr[1][3], alpha)
			if (sx >= 0 and sy >= 0
					and sx <= vsx and sy <= vsy) then
				--in screen
				local vertices = {
					{v = {sx, sy - highlightLineMin, 0}},
					{v = {sx, sy - highlightLineMax, 0}},
					{v = {sx, sy + highlightLineMin, 0}},
					{v = {sx, sy + highlightLineMax, 0}},
					{v = {sx - highlightLineMin, sy, 0}},
					{v = {sx - highlightLineMax, sy, 0}},
					{v = {sx + highlightLineMin, sy, 0}},
					{v = {sx + highlightLineMax, sy, 0}},
				}
				glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)
				glRect(sx - highlightSize, sy - highlightSize, sx + highlightSize, sy + highlightSize)
				glShape(GL_LINES, vertices)
			else
				--out of screen
				glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
				--flip if behind screen
				if (sz > 1) then
					sx = sMidX - sx
					sy = sMidY - sy
				end
				local xRatio = sMidX / abs(sx - sMidX)
				local yRatio = sMidY / abs(sy - sMidY)
				local edgeDist, vertices, textX, textY, textOptions
				if (xRatio < yRatio) then
					edgeDist = (sy - sMidY) * xRatio + sMidY
					if (sx > 0) then
						vertices = {
							{v = {vsx, edgeDist, 0}},
							{v = {vsx - edgeMarkerSize, edgeDist + edgeMarkerSize, 0}},
							{v = {vsx - edgeMarkerSize, edgeDist - edgeMarkerSize, 0}},
						}
						textX = vsx - edgeMarkerSize
						textY = edgeDist - fontSize * 0.5
						textOptions = "rn"
					else
						vertices = {
							{v = {0, edgeDist, 0}},
							{v = {edgeMarkerSize, edgeDist - edgeMarkerSize, 0}},
							{v = {edgeMarkerSize, edgeDist + edgeMarkerSize, 0}},
						}
						textX = edgeMarkerSize
						textY = edgeDist - fontSize * 0.5
						textOptions = "n"
					end
				else
					edgeDist = (sx - sMidX) * yRatio + sMidX
					if (sy > 0) then
						vertices = {
							{v = {edgeDist, vsy, 0}},
							{v = {edgeDist - edgeMarkerSize, vsy - edgeMarkerSize, 0}},
							{v = {edgeDist + edgeMarkerSize, vsy - edgeMarkerSize, 0}},
						}
						textX = edgeDist
						textY = vsy - edgeMarkerSize - fontSize
						textOptions = "cn"
					else
						vertices = {
							{v = {edgeDist, 0, 0}},
							{v = {edgeDist + edgeMarkerSize, edgeMarkerSize, 0}},
							{v = {edgeDist - edgeMarkerSize, edgeMarkerSize, 0}},
						}
						textX = edgeDist
						textY = edgeMarkerSize
						textOptions = "cn"
					end
				end
				glShape(GL_TRIANGLES, vertices)
				glColor(1, 1, 1, alpha)
				glText(curr[5], textX, textY, fontSize, textOptions)
			end
			i = i + 1
		end
	end
	
	glColor(1, 1, 1)
	glLineWidth(1)
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
end

function widget:ViewResize(viewSizeX, viewSizeY)
	vsx = viewSizeX
	vsy = viewSizeY
  sMidX = viewSizeX * 0.5
  sMidY = viewSizeY * 0.5
end

function widget:MapDrawCmd(playerID, cmdType, px, py, pz, label)
	if mapPointCount >= MAP_POINT_LIMIT then
		return
	end
	if (not timeNow) then
		StartTime()
	end
	local spectator, fullView = GetSpectatingState()
	local _, _, _, playerTeam = GetPlayerInfo(playerID)
	if (label == "Start " .. playerTeam
			or cmdType ~= "point" 
			or not (ArePlayersAllied(myPlayerID, playerID) or (spectator and fullView))) then 
		return 
	end
	
	local r, g, b = GetPlayerColor(playerID)
	local color = {r, g, b}
	local expiration = timeNow + ttl
	
	mapPointCount = mapPointCount + 1
	mapPoints[mapPointCount] = {color, px, py, pz, strSub(label, 1, maxLabelLength), expiration}
end

function widget:Update(dt)
	if (not timeNow) then
		StartTime()
	else
		if useFade then
			timeNow = timeNow + dt
		end
		timePart = timePart + dt
		if (timePart > blinkPeriod and blinkPeriod > 0) then
			timePart = timePart - blinkPeriod
			on = not on
		end
  end
end

function widget:DrawInMiniMap(sx, sy)
	if (not on) then return end
	glLineWidth(lineWidth)
	
	local ratioX = sx / mapX
	local ratioY = sy / mapY
	
	local i = 1
	while i <= mapPointCount do
		local curr = mapPoints[i]
		local x = curr[2] * ratioX
		local y = sy - curr[4] * ratioY
		local alpha = maxAlpha * (curr[6] - timeNow) / ttl
		if (alpha <= 0) then
			mapPoints[i] = mapPoints[mapPointCount]
			mapPoints[mapPointCount] = nil
			mapPointCount = mapPointCount - 1
		else
			glColor(curr[1][1], curr[1][2], curr[1][3], alpha)
			local vertices = {
				{v = {x, y - minimapHighlightLineMin, 0}},
				{v = {x, y - minimapHighlightLineMax, 0}},
				{v = {x, y + minimapHighlightLineMin, 0}},
				{v = {x, y + minimapHighlightLineMax, 0}},
				{v = {x - minimapHighlightLineMin, y, 0}},
				{v = {x - minimapHighlightLineMax, y, 0}},
				{v = {x + minimapHighlightLineMin, y, 0}},
				{v = {x + minimapHighlightLineMax, y, 0}},
			}
			glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)
			glRect(x - minimapHighlightSize, y - minimapHighlightSize, x + minimapHighlightSize, y + minimapHighlightSize)
			glShape(GL_LINES, vertices)
			
			i = i + 1
		end
	end
	
	glColor(1, 1, 1)
	glLineWidth(1)
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
end