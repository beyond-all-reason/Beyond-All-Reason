local versionNumber = "v1.1"

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Share Tracker",
		desc = versionNumber .. " Marks received units.",
		author = "Evil4Zerggin/TheFatController/indev29",
		date = "17 August 2009",
		license = "GNU LGPL, v2.1 or later",
		layer = 0,
		enabled = true
	}
end

local minimapUtils = VFS.Include("luaui/Include/minimap_utils.lua")
local getCurrentMiniMapRotationOption = minimapUtils.getCurrentMiniMapRotationOption
local ROTATION = minimapUtils.ROTATION

----------------------------------------------------------------
-- config
----------------------------------------------------------------

local ttl = 10
local highlightLineMin = 10
local highlightLineMax = 20
local edgeMarkerSize = 8
local lineWidth = 1
local fontSize = 16
local unitCount = 0
local msgTimer = 0

local blink = false
local blinkTime = 0
local blinkPeriod = 0.07
local blinkOnScreenAlphaMin = 0.5
local blinkOnScreenAlphaMax = 1.0
local blinkOnMinimapAlphaMin = 0.8
local blinkOnMinimapAlphaMax = 1.0
local blinkOnEdgeAlphaMin = 1.0
local blinkOnEdgeAlphaMax = 1.0

local minimapHighlightSize = 3
local minimapHighlightLineMin = 4
local minimapHighlightLineMax = 8

local font

----------------------------------------------------------------
-- speedups
----------------------------------------------------------------

local GetPlayerInfo = Spring.GetPlayerInfo
local GetTeamColor = Spring.GetTeamColor
local WorldToScreenCoords = Spring.WorldToScreenCoords
local GetUnitPosition = Spring.GetUnitPosition
local GetMyTeamID = Spring.GetMyTeamID
local glColor = gl.Color
local glRect = gl.Rect
local glLineWidth = gl.LineWidth
local glShape = gl.Shape
local glPolygonMode = gl.PolygonMode
local abs = math.abs
local GL_LINES = GL.LINES
local GL_TRIANGLES = GL.TRIANGLES
local GL_LINE = GL.LINE
local GL_FRONT_AND_BACK = GL.FRONT_AND_BACK
local GL_FILL = GL.FILL

----------------------------------------------------------------
-- vars
----------------------------------------------------------------

local vsx, vsy = Spring.GetViewGeometry()
local mapPoints = {}
local timeNow, timePart
local on = false
local mapX = Game.mapX * 512
local mapY = Game.mapY * 512

local myPlayerID, sMidX, sMidY

----------------------------------------------------------------
-- local functions
----------------------------------------------------------------

local function GetPlayerColor(playerID)
	local _, _, _, teamID = GetPlayerInfo(playerID, false)
	if not teamID then
		return nil
	end
	return GetTeamColor(teamID)
end

local function StartTime()
	timeNow = 0
	timePart = 0
	on = true
end

local function blinkAlpha(minAlpha, maxAlpha)
	if blink then
		return minAlpha
	end
	return maxAlpha
end

----------------------------------------------------------------
-- callins
----------------------------------------------------------------

function widget:Initialize()
	timeNow = false
	timePart = false
	myPlayerID = Spring.GetMyPlayerID()
	widget:ViewResize()
end

function widget:DrawScreen()
	if not on or next(mapPoints) == nil then
		return
	end

	glLineWidth(lineWidth)

	for unitID, defs in pairs(mapPoints) do
		local expired = timeNow > defs.time
		if expired then
			mapPoints[unitID] = nil
		else
			defs.x, defs.y, defs.z = Spring.GetUnitPosition(unitID)
			if defs.x then
				local sx, sy, sz = WorldToScreenCoords(defs.x, defs.y, defs.z)
				if sx >= 0 and sy >= 0 and sx <= vsx and sy <= vsy then
					--in screen
					local alpha = blinkAlpha(blinkOnScreenAlphaMin, blinkOnScreenAlphaMax)
					glColor(defs.r, defs.g, defs.b, alpha)

					local vertices = {
						{ v = { sx, sy - highlightLineMin, 0 } },
						{ v = { sx, sy - highlightLineMax, 0 } },
						{ v = { sx, sy + highlightLineMin, 0 } },
						{ v = { sx, sy + highlightLineMax, 0 } },
						{ v = { sx - highlightLineMin, sy, 0 } },
						{ v = { sx - highlightLineMax, sy, 0 } },
						{ v = { sx + highlightLineMin, sy, 0 } },
						{ v = { sx + highlightLineMax, sy, 0 } },
					}
					glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)
					glRect(sx - defs.highlightSize, sy - defs.highlightSize, sx + defs.highlightSize, sy + defs.highlightSize)
					glShape(GL_LINES, vertices)
				else
					--out of screen
					local alpha = blinkAlpha(blinkOnEdgeAlphaMin, blinkOnEdgeAlphaMax)
					glColor(defs.r, defs.g, defs.b, alpha)

					glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
					--flip if behind screen
					if sz > 1 then
						sx = sMidX - sx
						sy = sMidY - sy
					end
					local xRatio = sMidX / abs(sx - sMidX)
					local yRatio = sMidY / abs(sy - sMidY)
					local edgeDist, vertices, textX, textY, textOptions
					if xRatio < yRatio then
						edgeDist = (sy - sMidY) * xRatio + sMidY
						if sx > 0 then
							vertices = {
								{ v = { vsx, edgeDist, 0 } },
								{ v = { vsx - edgeMarkerSize, edgeDist + edgeMarkerSize, 0 } },
								{ v = { vsx - edgeMarkerSize, edgeDist - edgeMarkerSize, 0 } },
							}
							textX = vsx - edgeMarkerSize
							textY = edgeDist - fontSize * 0.5
							textOptions = "rn"
						else
							vertices = {
								{ v = { 0, edgeDist, 0 } },
								{ v = { edgeMarkerSize, edgeDist - edgeMarkerSize, 0 } },
								{ v = { edgeMarkerSize, edgeDist + edgeMarkerSize, 0 } },
							}
							textX = edgeMarkerSize
							textY = edgeDist - fontSize * 0.5
							textOptions = "n"
						end
					else
						edgeDist = (sx - sMidX) * yRatio + sMidX
						if sy > 0 then
							vertices = {
								{ v = { edgeDist, vsy, 0 } },
								{ v = { edgeDist - edgeMarkerSize, vsy - edgeMarkerSize, 0 } },
								{ v = { edgeDist + edgeMarkerSize, vsy - edgeMarkerSize, 0 } },
							}
							textX = edgeDist
							textY = vsy - edgeMarkerSize - fontSize
							textOptions = "cn"
						else
							vertices = {
								{ v = { edgeDist, 0, 0 } },
								{ v = { edgeDist + edgeMarkerSize, edgeMarkerSize, 0 } },
								{ v = { edgeDist - edgeMarkerSize, edgeMarkerSize, 0 } },
							}
							textX = edgeDist
							textY = edgeMarkerSize
							textOptions = "cn"
						end
					end
					glShape(GL_TRIANGLES, vertices)

					font:Begin()
					font:SetTextColor(1, 1, 1, alpha)
					font:Print(defs.unitName, textX, textY, fontSize, textOptions)
					font:End()
				end
			end
		end
	end
	glColor(1, 1, 1)
	glLineWidth(1)
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()

	font = WG['fonts'].getFont(1, 1.5)

	sMidX = vsx * 0.5
	sMidY = vsy * 0.5
end

function widget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	local _, _, _, captureProgress, _ = Spring.GetUnitHealth(unitID)
	local captured = (captureProgress == 1)

	local selfShare = (oldTeam == newTeam) -- may happen if took other player

	local price = Spring.GetUnitRulesParam(unitID, "unitPrice")
	local bought = price ~= nil and price > 0

	if newTeam == GetMyTeamID() and not selfShare and not captured and not bought then
		if not timeNow then
			StartTime()
		end
		local x, y, z = GetUnitPosition(unitID)
		local r, g, b = Spring.GetTeamColor(oldTeam)
		if x and r then
			mapPoints[unitID] = { r = r, g = g, b = b, x = x, y = y, z = z, unitName = Spring.I18N('ui.unitShare.unit', { unit = UnitDefs[unitDefID].translatedHumanName }), time = (timeNow + ttl), highlightSize = UnitDefs[unitDefID].radius * 0.6 }
			unitCount = unitCount + 1
		end
	end
end

function widget:Update(dt)
	if not timeNow then
		StartTime()
	else
		timeNow = timeNow + dt
		timePart = timePart + dt
	end
	if blinkTime > blinkPeriod then
		blink = not blink
		blinkTime = 0
	else
		blinkTime = blinkTime + dt
	end
	if unitCount > 0 then
		msgTimer = msgTimer + dt
		if msgTimer > 0.1 then
			Spring.Echo( Spring.I18N('ui.unitShare.received', { count = unitCount }) )
			Spring.PlaySoundFile("beep4", 1, 'ui')
			unitCount = 0
			msgTimer = 0
		end
	end
end

function widget:DrawInMiniMap(sx, sy)
	if not on then
		return
	end
	glLineWidth(lineWidth)

	local currRot = getCurrentMiniMapRotationOption()

	for unitID, defs in pairs(mapPoints) do
		if defs.x then
			local x, y

			if currRot == ROTATION.DEG_0 then
				x = defs.x * sx / mapX
				y = sy - defs.z * sy / mapY
			elseif currRot == ROTATION.DEG_90 then
				x = defs.z * sx / mapY
				y = defs.x * sy / mapX
			elseif currRot == ROTATION.DEG_180 then
				x = sx - defs.x * sx / mapX
				y = defs.z * sy / mapY
			elseif currRot == ROTATION.DEG_270 then
				x = sx - defs.z * sx / mapY
				y = sy - defs.x * sy / mapX
			end

			local expired = timeNow > defs.time
			if expired then
				mapPoints[unitID] = nil
			else
				local alpha = blinkAlpha(blinkOnMinimapAlphaMin, blinkOnMinimapAlphaMax)
				glColor(defs.r, defs.g, defs.b, alpha)
				local vertices = {
					{ v = { x, y - minimapHighlightLineMin, 0 } },
					{ v = { x, y - minimapHighlightLineMax, 0 } },
					{ v = { x, y + minimapHighlightLineMin, 0 } },
					{ v = { x, y + minimapHighlightLineMax, 0 } },
					{ v = { x - minimapHighlightLineMin, y, 0 } },
					{ v = { x - minimapHighlightLineMax, y, 0 } },
					{ v = { x + minimapHighlightLineMin, y, 0 } },
					{ v = { x + minimapHighlightLineMax, y, 0 } },
				}
				glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)
				glRect(x - minimapHighlightSize, y - minimapHighlightSize, x + minimapHighlightSize, y + minimapHighlightSize)
				glShape(GL_LINES, vertices)
			end
		end
	end

	glColor(1, 1, 1)
	glLineWidth(1)
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
end
