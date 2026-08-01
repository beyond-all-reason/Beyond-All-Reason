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


-- Localized Spring API for performance
local spGetUnitPosition = Spring.GetUnitPosition
local spGetViewGeometry = Spring.GetViewGeometry
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetTeamColor = Spring.GetTeamColor
local spGetMyTeamID = Spring.GetMyTeamID
local spGetMyPlayerID = Spring.GetMyPlayerID
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spEcho = Spring.Echo
local spPlaySoundFile = Spring.PlaySoundFile
local spI18N = Spring.I18N
local spWorldToScreenCoords = Spring.WorldToScreenCoords

-- Localized GL functions
local glColor = gl.Color
local glRect = gl.Rect
local glLineWidth = gl.LineWidth
local glShape = gl.Shape
local glPolygonMode = gl.PolygonMode

-- Localized math functions
local mathAbs = math.abs

-- Localized Lua functions
local pairs = pairs
local next = next

local getCurrentMiniMapRotationOption = VFS.Include("luaui/Include/minimap_utils.lua").getCurrentMiniMapRotationOption
local ROTATION = VFS.Include("luaui/Include/minimap_utils.lua").ROTATION

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

local GL_LINES = GL.LINES
local GL_TRIANGLES = GL.TRIANGLES
local GL_LINE = GL.LINE
local GL_FRONT_AND_BACK = GL.FRONT_AND_BACK
local GL_FILL = GL.FILL

----------------------------------------------------------------
-- vars
----------------------------------------------------------------

local vsx, vsy = spGetViewGeometry()
local mapPoints = {}
local timeNow, timePart
local on = false
local mapX = Game.mapX * 512
local mapY = Game.mapY * 512

local myPlayerID, sMidX, sMidY
local fontSizeHalf = fontSize * 0.5

-- Reusable vertex tables to reduce allocations
local screenVertices = {
	{ v = { 0, 0, 0 } },
	{ v = { 0, 0, 0 } },
	{ v = { 0, 0, 0 } },
	{ v = { 0, 0, 0 } },
	{ v = { 0, 0, 0 } },
	{ v = { 0, 0, 0 } },
	{ v = { 0, 0, 0 } },
	{ v = { 0, 0, 0 } },
}

local edgeVertices = {
	{ v = { 0, 0, 0 } },
	{ v = { 0, 0, 0 } },
	{ v = { 0, 0, 0 } },
}

local minimapVertices = {
	{ v = { 0, 0, 0 } },
	{ v = { 0, 0, 0 } },
	{ v = { 0, 0, 0 } },
	{ v = { 0, 0, 0 } },
	{ v = { 0, 0, 0 } },
	{ v = { 0, 0, 0 } },
	{ v = { 0, 0, 0 } },
	{ v = { 0, 0, 0 } },
}

----------------------------------------------------------------
-- local functions
----------------------------------------------------------------

local function GetPlayerColor(playerID)
	local _, _, _, teamID = spGetPlayerInfo(playerID, false)
	if not teamID then
		return nil
	end
	return spGetTeamColor(teamID)
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
	myPlayerID = spGetMyPlayerID()
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
			local x, y, z = spGetUnitPosition(unitID)
			if x then
				defs.x, defs.y, defs.z = x, y, z
				local sx, sy, sz = spWorldToScreenCoords(x, y, z)
				if sx >= 0 and sy >= 0 and sx <= vsx and sy <= vsy then
					--in screen
					local alpha = blinkAlpha(blinkOnScreenAlphaMin, blinkOnScreenAlphaMax)
					glColor(defs.r, defs.g, defs.b, alpha)

					-- Update reusable vertex table
					local v = screenVertices
					v[1].v[1], v[1].v[2] = sx, sy - highlightLineMin
					v[2].v[1], v[2].v[2] = sx, sy - highlightLineMax
					v[3].v[1], v[3].v[2] = sx, sy + highlightLineMin
					v[4].v[1], v[4].v[2] = sx, sy + highlightLineMax
					v[5].v[1], v[5].v[2] = sx - highlightLineMin, sy
					v[6].v[1], v[6].v[2] = sx - highlightLineMax, sy
					v[7].v[1], v[7].v[2] = sx + highlightLineMin, sy
					v[8].v[1], v[8].v[2] = sx + highlightLineMax, sy

					glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)
					glRect(sx - defs.highlightSize, sy - defs.highlightSize, sx + defs.highlightSize, sy + defs.highlightSize)
					glShape(GL_LINES, v)
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
					local xDiff = mathAbs(sx - sMidX)
					local yDiff = mathAbs(sy - sMidY)
					if xDiff < 0.001 then xDiff = 0.001 end
					if yDiff < 0.001 then yDiff = 0.001 end
					local xRatio = sMidX / xDiff
					local yRatio = sMidY / yDiff
					local edgeDist, textX, textY, textOptions
					local v = edgeVertices
					if xRatio < yRatio then
						edgeDist = (sy - sMidY) * xRatio + sMidY
						if sx > 0 then
							v[1].v[1], v[1].v[2] = vsx, edgeDist
							v[2].v[1], v[2].v[2] = vsx - edgeMarkerSize, edgeDist + edgeMarkerSize
							v[3].v[1], v[3].v[2] = vsx - edgeMarkerSize, edgeDist - edgeMarkerSize
							textX = vsx - edgeMarkerSize
							textY = edgeDist - fontSizeHalf
							textOptions = "rn"
						else
							v[1].v[1], v[1].v[2] = 0, edgeDist
							v[2].v[1], v[2].v[2] = edgeMarkerSize, edgeDist - edgeMarkerSize
							v[3].v[1], v[3].v[2] = edgeMarkerSize, edgeDist + edgeMarkerSize
							textX = edgeMarkerSize
							textY = edgeDist - fontSizeHalf
							textOptions = "n"
						end
					else
						edgeDist = (sx - sMidX) * yRatio + sMidX
						if sy > 0 then
							v[1].v[1], v[1].v[2] = edgeDist, vsy
							v[2].v[1], v[2].v[2] = edgeDist - edgeMarkerSize, vsy - edgeMarkerSize
							v[3].v[1], v[3].v[2] = edgeDist + edgeMarkerSize, vsy - edgeMarkerSize
							textX = edgeDist
							textY = vsy - edgeMarkerSize - fontSize
							textOptions = "cn"
						else
							v[1].v[1], v[1].v[2] = edgeDist, 0
							v[2].v[1], v[2].v[2] = edgeDist + edgeMarkerSize, edgeMarkerSize
							v[3].v[1], v[3].v[2] = edgeDist - edgeMarkerSize, edgeMarkerSize
							textX = edgeDist
							textY = edgeMarkerSize
							textOptions = "cn"
						end
					end
					glShape(GL_TRIANGLES, v)

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
	vsx, vsy = spGetViewGeometry()

	font = WG['fonts'].getFont(1, 1.5)

	sMidX = vsx * 0.5
	sMidY = vsy * 0.5
end

function widget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	local _, _, _, captureProgress, _ = spGetUnitHealth(unitID)
	local captured = (captureProgress == 1)

	local selfShare = (oldTeam == newTeam) -- may happen if took other player

	local price = spGetUnitRulesParam(unitID, "unitPrice")
	local bought = price ~= nil and price > 0

	if newTeam == spGetMyTeamID() and not selfShare and not captured and not bought then
		if not timeNow then
			StartTime()
		end
		local x, y, z = spGetUnitPosition(unitID)
		local r, g, b = spGetTeamColor(oldTeam)
		if x and r then
			mapPoints[unitID] = { r = r, g = g, b = b, x = x, y = y, z = z, unitName = spI18N('ui.unitShare.unit', { unit = UnitDefs[unitDefID].translatedHumanName }), time = (timeNow + ttl), highlightSize = UnitDefs[unitDefID].radius * 0.6 }
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
			spEcho( spI18N('ui.unitShare.received', { count = unitCount }) )
			spPlaySoundFile("beep4", 1, 'ui')
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
	local sxOverMapX = sx / mapX
	local syOverMapY = sy / mapY
	local sxOverMapY = sx / mapY
	local syOverMapX = sy / mapX

	for unitID, defs in pairs(mapPoints) do
		if defs.x then
			local x, y

			if currRot == ROTATION.DEG_0 then
				x = defs.x * sxOverMapX
				y = sy - defs.z * syOverMapY
			elseif currRot == ROTATION.DEG_90 then
				x = defs.z * sxOverMapY
				y = defs.x * syOverMapX
			elseif currRot == ROTATION.DEG_180 then
				x = sx - defs.x * sxOverMapX
				y = defs.z * syOverMapY
			elseif currRot == ROTATION.DEG_270 then
				x = sx - defs.z * sxOverMapY
				y = sy - defs.x * syOverMapX
			end

			local expired = timeNow > defs.time
			if expired then
				mapPoints[unitID] = nil
			else
				local alpha = blinkAlpha(blinkOnMinimapAlphaMin, blinkOnMinimapAlphaMax)
				glColor(defs.r, defs.g, defs.b, alpha)

				-- Update reusable vertex table
				local v = minimapVertices
				v[1].v[1], v[1].v[2] = x, y - minimapHighlightLineMin
				v[2].v[1], v[2].v[2] = x, y - minimapHighlightLineMax
				v[3].v[1], v[3].v[2] = x, y + minimapHighlightLineMin
				v[4].v[1], v[4].v[2] = x, y + minimapHighlightLineMax
				v[5].v[1], v[5].v[2] = x - minimapHighlightLineMin, y
				v[6].v[1], v[6].v[2] = x - minimapHighlightLineMax, y
				v[7].v[1], v[7].v[2] = x + minimapHighlightLineMin, y
				v[8].v[1], v[8].v[2] = x + minimapHighlightLineMax, y

				glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)
				glRect(x - minimapHighlightSize, y - minimapHighlightSize, x + minimapHighlightSize, y + minimapHighlightSize)
				glShape(GL_LINES, v)
			end
		end
	end

	glColor(1, 1, 1)
	glLineWidth(1)
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
end
