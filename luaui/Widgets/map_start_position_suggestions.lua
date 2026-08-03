local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Start Position Suggestions",
		desc = "Show expert recommended starting locations on the map",
		license = "GNU GPL, v2 or later",
		layer = -100,
		enabled = true
	}
end


-- Localized functions for performance
local mathCeil = math.ceil
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local mathSin = math.sin
local mathCos = math.cos
local mathPi = math.pi
local mathSqrt = math.sqrt
local mathAtan2 = math.atan2
local mathAsin = math.asin
local tableInsert = table.insert
local tableConcat = table.concat

-- Localized Spring API for performance
local spGetMouseState = Spring.GetMouseState
local spGetGroundHeight = Spring.GetGroundHeight
local spGetViewGeometry = Spring.GetViewGeometry
local spGetTeamColor = Spring.GetTeamColor

--todo: gl4 (also make circles more transparent as you zoom in)

local base64 = VFS.Include("common/luaUtilities/base64.lua")

-- config
-- ======

local config = {
	-- saved
	hasRunBefore = false,

	-- local
	circleRadius = 300,
	circleThickness = 8,
	circleSegments = 32,
	circleSegmentFill = 0.6,
	circleGroundOffset = 3,
	circleGlowSegments = 96,

	playerTextSize = 100,
	roleTextSize = 70,
	tutorialTextSize = 18,

	spawnPointCircleColor = { 1, 1, 1, 0.6 },
	baseCenterCircleColor = { 1, 1, 1, 0.4 },
	usePlayerColorForSpawnPointCircle = true,

	playerTextColor = { 1, 1, 1, 0.6 },
	roleTextColor = { 1, 1, 1, 0.6 },

	glowInnerRadiusCoefficient = 0.16,
	glowOuterRadiusCoefficient = 0.17,

	tooltipDelay = 0.37,
	tooltipMaxWidthChars = 60,

	hideTooltipsAfterBuild = true,

	tutorialMaxWidthChars = 100,
}

local CIRCLE_RADIUS_SQUARED = config.circleRadius * config.circleRadius

local vsx, vsy = spGetViewGeometry()
local resMult = vsy/1440

-- engine call optimizations
-- =========================

local SpringGetCameraState = Spring.GetCameraState
local SpringIsGUIHidden = Spring.IsGUIHidden
local SpringGetCameraRotation = Spring.GetCameraRotation
local SpringGetGameFrame = Spring.GetGameFrame

local glColor = gl.Color
local glCulling = gl.Culling
local glDepthTest = gl.DepthTest
local glPushMatrix = gl.PushMatrix
local glTranslate = gl.Translate
local glRotate = gl.Rotate
local glPopMatrix = gl.PopMatrix

-- types
-- =====

---@alias Timer userdata
---
---@alias StartPositionID string

---@class ModOptionPosition
---@field x number
---@field y number

---@class ModOptionTeamStartPositionEntry
---@field spawnPoint StartPositionID
---@field baseCenter StartPositionID
---@field role string

---@class ModOptionTeamStartPositions
---@field starts ModOptionTeamStartPositionEntry[]
---
---@class ModOptionTeams
---@field playersPerTeam number
---@field teamCount number
---@field sides ModOptionTeamStartPositions[]

---@alias ModOptionPositions table<StartPositionID, ModOptionPosition>

---@class ModOptionData
---@field positions ModOptionPositions
---@field team ModOptionTeams[]

---@alias AllyTeamID number

---@class WidgetMapPosition
---@field x number
---@field z number

---@class WidgetTeamStartPositionEntry
---@field spawnPoint WidgetMapPosition
---@field baseCenter WidgetMapPosition?
---@field role string

---@alias WidgetStartPositions table<AllyTeamID, WidgetTeamStartPositionEntry[]>


-- loading and processing code
-- ===========================

local function convertXYToXZ(p)
	return {
		x = p.x,
		z = p.y,
	}
end

local gaiaTeamID = Spring.GetGaiaTeamID()
local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(gaiaTeamID, false))

local function getTeamSizes()
	local allyTeams = Spring.GetAllyTeamList()
	local allyTeamCount = 0
	local playersPerTeam = 0
	for _, allyTeamID in ipairs(allyTeams) do
		if allyTeamID ~= gaiaAllyTeamID then
			allyTeamCount = allyTeamCount + 1
			local teamList = Spring.GetTeamList(allyTeamID) or {}
			playersPerTeam = mathMax(playersPerTeam, #teamList)
		end
	end

	return allyTeamCount, playersPerTeam
end

---@param positions ModOptionPositions
---@param teamPositions ModOptionTeamStartPositions
local function processModoptionTeamConfig(positions, teamPositions)
	return table.map(teamPositions, function(sidePositions)
		return table.map(sidePositions.starts, function(teamStart)
			return {
				name = teamStart.spawnPoint,
				spawnPoint = convertXYToXZ(positions[teamStart.spawnPoint]),
				baseCenter = teamStart.baseCenter and convertXYToXZ(positions[teamStart.baseCenter]) or nil,
				role = teamStart.role and teamStart.role or nil,
			}
		end)
	end)
end

local function selectModoptionConfigForPlayers(modoptionData, allyTeamCount, playersPerTeam)
	Spring.Log(
		widget:GetInfo().name,
		LOG.INFO,
		"Searching for start positions for " .. table.toString({
			allyTeamCount = allyTeamCount,
			playersPerTeam = playersPerTeam,
		})
	)

	for _, teamConfig in ipairs(modoptionData.team) do
		if teamConfig.playersPerTeam == playersPerTeam and teamConfig.teamCount == allyTeamCount then
			Spring.Log(widget:GetInfo().name, LOG.INFO, "Found start positions")
			return teamConfig.sides
		end
	end

	return nil
end

local function loadStartPositions()
	local modoptionDataRaw = Spring.GetModOptions().mapmetadata_startpos

	if modoptionDataRaw == nil or string.len(modoptionDataRaw) == 0 then
		Spring.Log(widget:GetInfo().name, LOG.WARNING, "No modoption start position data found")
		return
	end

	local decoded = base64.Decode(modoptionDataRaw)
	local decompressed = VFS.ZlibDecompress(decoded)
	local parsed = Json.decode(decompressed)

	local allyTeamCount, playersPerTeam = getTeamSizes()
	local selectedConfig = selectModoptionConfigForPlayers(parsed, allyTeamCount, playersPerTeam)

	if selectedConfig == nil then
		Spring.Log(widget:GetInfo().name, LOG.WARNING, "Could not find matching start positions")
		return
	end

	local positions = processModoptionTeamConfig(
		parsed.positions,
		selectedConfig
	)

	return positions
end

local function loadCurrentTeamStartPositions()
	local positions = {}
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if teamID ~= gaiaTeamID then
			local allyTeamID = select(6, Spring.GetTeamInfo(teamID, false))
			local x, _, z = Spring.GetTeamStartPosition(teamID)
			if allyTeamID and x and z and x > 0 and z > 0 then
				if not positions[allyTeamID] then
					positions[allyTeamID] = {}
				end
				tableInsert(positions[allyTeamID], {
					spawnPoint = { x = x, z = z },
				})
			end
		end
	end
	return positions
end

-- widget code
-- ===========

local font = nil
local fontTutorial = nil

---@type WidgetStartPositions
local startPositions = {}
local usingCurrentTeamStartPositions = false

---@type string
local tooltipKey = nil

---@type Timer
local tooltipStartTime = 0

local placedCommanders = {}
local captionsCache = {}
local wrappedDescriptionCache = {}
local cachedTutorialText = nil

local textDisplayListID = nil
local textDisplayListCameraFlipped = nil
local textDisplayListCameraMode = nil
local textDisplayListCameraRy = nil
local activeCameraName = nil
local activeCameraFlipped = nil

local function invalidateTextDisplayList()
	if textDisplayListID then
		gl.DeleteList(textDisplayListID)
		textDisplayListID = nil
	end
end

local circleDisplayListID = nil

local function invalidateCircleDisplayList()
	if circleDisplayListID then
		gl.DeleteList(circleDisplayListID)
		circleDisplayListID = nil
	end
end

local tutorialDisplayListID = nil

local function invalidateTutorialDisplayList()
	if tutorialDisplayListID then
		gl.DeleteList(tutorialDisplayListID)
		tutorialDisplayListID = nil
	end
end

local reusePositionTable = { 0, 0, 0 }
local reuseColorTable = { 0, 0, 0, 0 }
local reuseColorTable2 = { 0, 0, 0, 0 }
local reuseColorsArray = {}
local reuseGlowColorsArray = {}

local glVertex = gl.Vertex
local glBeginEnd = gl.BeginEnd

local arrowShaftWidth = 0
local arrowHeadL = 0
local arrowLength = 0
local arrowCStart = nil
local arrowCEnd = nil

local function drawArrowShaft()
	if arrowCStart then
		glColor(arrowCStart)
	end
	glVertex(-arrowShaftWidth, 0, 0)
	glVertex(arrowShaftWidth, 0, 0)
	if arrowCEnd then
		glColor(arrowCEnd)
	end
	glVertex(arrowShaftWidth, 0, arrowLength - arrowHeadL)
	glVertex(-arrowShaftWidth, 0, arrowLength - arrowHeadL)
end

local arrowHeadW = 0

local function drawArrowHead()
	if arrowCEnd then
		glColor(arrowCEnd)
	end
	glVertex(0, 0, arrowLength)
	glVertex(-arrowHeadW, 0, arrowLength - arrowHeadL)
	glVertex(arrowHeadW, 0, arrowLength - arrowHeadL)
end

local arcCx, arcCz = 0, 0
local arcStartAngle = 0
local arcRadius, arcSegments, arcThickness = 0, 0, 0
local arcA1, arcA2 = 0, 0
local arcColorInner, arcColorOuter = nil, nil

local function drawArc()
	for i = 0, arcSegments do
		local angle = arcStartAngle + arcA1 + (arcA2 - arcA1) * (i / arcSegments)
		local cosAngle = mathCos(angle)
		local sinAngle = mathSin(angle)
		local xOuter = arcCx + arcRadius * cosAngle
		local zOuter = arcCz + arcRadius * sinAngle
		local xInner = arcCx + (arcRadius - arcThickness) * cosAngle
		local zInner = arcCz + (arcRadius - arcThickness) * sinAngle
		if arcColorInner then
			glColor(arcColorInner)
		end
		glVertex(xInner, spGetGroundHeight(xInner, zInner), zInner)
		if arcColorOuter then
			glColor(arcColorOuter)
		end
		glVertex(xOuter, spGetGroundHeight(xOuter, zOuter), zOuter)
	end
end

local tileCx, tileCz = 0, 0
local tileRadius, tileWidth = 0, 0
local tileSegments, tileColorCount = 0, 0
---@type number[][]
local tileColors = {}

local tileVertexCenterX, tileVertexCenterZ = 0, 0
local tileVertexRadialX, tileVertexRadialZ = 0, 0
local tileVertexTangentX, tileVertexTangentZ = 0, 0
local tileVertexR, tileVertexG, tileVertexB = 0, 0, 0
local tileVertexGroundOffset = 0
local tileRadialOffsets = {}
local tileTangentOffsets = {}
local tileVertexX = {}
local tileVertexY = {}
local tileVertexZ = {}
local tileVertexShade = {}

---@param halfWidth number
---@param halfLength number
---@param chamfer number
---@param innerShade number
---@param outerShade number
---@param alpha number
local function drawChamferedTile(halfWidth, halfLength, chamfer, innerShade, outerShade, alpha)
	chamfer = mathMin(chamfer, halfWidth - 0.5, halfLength - 0.5)
	tileRadialOffsets[1], tileTangentOffsets[1] = -halfWidth, -halfLength + chamfer
	tileRadialOffsets[2], tileTangentOffsets[2] = -halfWidth, halfLength - chamfer
	tileRadialOffsets[3], tileTangentOffsets[3] = -halfWidth + chamfer, halfLength
	tileRadialOffsets[4], tileTangentOffsets[4] = halfWidth - chamfer, halfLength
	tileRadialOffsets[5], tileTangentOffsets[5] = halfWidth, halfLength - chamfer
	tileRadialOffsets[6], tileTangentOffsets[6] = halfWidth, -halfLength + chamfer
	tileRadialOffsets[7], tileTangentOffsets[7] = halfWidth - chamfer, -halfLength
	tileRadialOffsets[8], tileTangentOffsets[8] = -halfWidth + chamfer, -halfLength

	local shadeRange = outerShade - innerShade
	local inverseWidth = 1 / (2 * halfWidth)
	for vertexIndex = 1, 8 do
		local radialOffset = tileRadialOffsets[vertexIndex]
		local tangentOffset = tileTangentOffsets[vertexIndex]
		local x = tileVertexCenterX + radialOffset * tileVertexRadialX + tangentOffset * tileVertexTangentX
		local z = tileVertexCenterZ + radialOffset * tileVertexRadialZ + tangentOffset * tileVertexTangentZ
		tileVertexX[vertexIndex] = x
		tileVertexY[vertexIndex] = spGetGroundHeight(x, z) + tileVertexGroundOffset
		tileVertexZ[vertexIndex] = z
		tileVertexShade[vertexIndex] = innerShade + shadeRange * ((radialOffset + halfWidth) * inverseWidth)
	end

	for vertexIndex = 2, 7 do
		glColor(tileVertexR * tileVertexShade[1], tileVertexG * tileVertexShade[1], tileVertexB * tileVertexShade[1], alpha)
		glVertex(tileVertexX[1], tileVertexY[1], tileVertexZ[1])
		glColor(tileVertexR * tileVertexShade[vertexIndex], tileVertexG * tileVertexShade[vertexIndex], tileVertexB * tileVertexShade[vertexIndex], alpha)
		glVertex(tileVertexX[vertexIndex], tileVertexY[vertexIndex], tileVertexZ[vertexIndex])
		local nextIndex = vertexIndex + 1
		glColor(tileVertexR * tileVertexShade[nextIndex], tileVertexG * tileVertexShade[nextIndex], tileVertexB * tileVertexShade[nextIndex], alpha)
		glVertex(tileVertexX[nextIndex], tileVertexY[nextIndex], tileVertexZ[nextIndex])
	end
end

local function drawRingTiles()
	local angleStep = 2 * mathPi / tileSegments
	local halfLength = tileRadius * angleStep * config.circleSegmentFill * 0.5
	local halfWidth = tileWidth * 0.5
	local chamfer = mathMin(5, halfWidth * 0.4, halfLength * 0.2)

	for i = 0, tileSegments - 1 do
		local angle = -mathPi / 2 + (i + 0.5) * angleStep
		local radialX, radialZ = mathCos(angle), mathSin(angle)
		local tangentX, tangentZ = -radialZ, radialX
		local centerX = tileCx + tileRadius * radialX
		local centerZ = tileCz + tileRadius * radialZ
		local color = tileColors[mathFloor(i * tileColorCount / tileSegments) + 1] or config.spawnPointCircleColor
		local r, g, b, a = color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
		local materialIntensity = mathMin(1, 0.65 + a * 0.45)

		tileVertexCenterX, tileVertexCenterZ = centerX, centerZ
		tileVertexRadialX, tileVertexRadialZ = radialX, radialZ
		tileVertexTangentX, tileVertexTangentZ = tangentX, tangentZ

		tileVertexR, tileVertexG, tileVertexB = 0.02, 0.025, 0.035
		tileVertexGroundOffset = 1
		drawChamferedTile(halfWidth + 3, halfLength + 3, chamfer + 1.5, 1, 1, 0.68)

		tileVertexR, tileVertexG, tileVertexB = r, g, b
		tileVertexGroundOffset = 2
		drawChamferedTile(halfWidth + 1.5, halfLength + 1.5, chamfer + 0.75, materialIntensity * 0.38, materialIntensity * 0.56, 1)

		tileVertexGroundOffset = config.circleGroundOffset
		drawChamferedTile(halfWidth, halfLength, chamfer, materialIntensity * 0.72, mathMin(1, materialIntensity * 1.08), 1)
	end
end

local function drawArrow(ax, ay, az, bx, by, bz, size, cStart, cEnd)
	local dx, dy, dz = bx - ax, by - ay, bz - az
	local length = mathSqrt(dx * dx + dy * dy + dz * dz)
	local invLength = 1 / length
	local dirNx, dirNy, dirNz = dx * invLength, dy * invLength, dz * invLength

	local horizontalAngle = mathAtan2(dirNx, dirNz)
	local verticalAngle = -mathAsin(dirNy)

	size = size or 0.1 * length
	arrowLength = length
	arrowHeadL = size
	arrowHeadW = size * 0.5
	arrowShaftWidth = arrowHeadW / 6
	arrowCStart = cStart
	arrowCEnd = cEnd

	glPushMatrix()
	glTranslate(ax, ay, az)
	glRotate(horizontalAngle * 180 / mathPi, 0, 1, 0)
	glRotate(verticalAngle * 180 / mathPi, 1, 0, 0)

	glBeginEnd(GL.QUADS, drawArrowShaft)
	glBeginEnd(GL.TRIANGLES, drawArrowHead)

	glPopMatrix()
end

local function drawCircle(cx, cz, radius, segments, thickness, colors, colorsGlow)
	arcStartAngle = -mathPi / 2
	arcCx, arcCz = cx, cz

	if colorsGlow and #colorsGlow > 0 then
		if type(colorsGlow[1]) == "number" then
			reuseGlowColorsArray[1] = colorsGlow
			colorsGlow = reuseGlowColorsArray
		end

		local glowCount = #colorsGlow
		arcSegments = mathCeil(config.circleGlowSegments / glowCount)

		for i = 1, glowCount do
			local co = colorsGlow[i]
			reuseColorTable[1], reuseColorTable[2], reuseColorTable[3], reuseColorTable[4] = co[1], co[2], co[3], 0
			arcA1 = (i - 1) * 2 * mathPi / glowCount
			arcA2 = i * 2 * mathPi / glowCount

			arcRadius = radius
			arcThickness = radius * config.glowInnerRadiusCoefficient
			arcColorInner = reuseColorTable
			arcColorOuter = co
			glBeginEnd(GL.TRIANGLE_STRIP, drawArc)

			arcThickness = radius * config.glowOuterRadiusCoefficient
			arcRadius = radius + arcThickness
			arcColorInner = co
			arcColorOuter = reuseColorTable
			glBeginEnd(GL.TRIANGLE_STRIP, drawArc)
		end
	end

	if colors and #colors > 0 then
		if type(colors[1]) == "number" then
			reuseColorsArray[1] = colors
			colors = reuseColorsArray
		end

		tileCx, tileCz = cx, cz
		tileRadius, tileWidth = radius, thickness
		tileSegments, tileColorCount = segments, #colors
		tileColors = colors
		glCulling(false)
		glBeginEnd(GL.TRIANGLES, drawRingTiles)
		glCulling(false)
	end
end

local spawnPointAlphaZeroColor = { config.spawnPointCircleColor[1], config.spawnPointCircleColor[2], config.spawnPointCircleColor[3], 0 }
local mathDistance2dSquared = math.distance2dSquared

local function buildCircleDisplayList()
	if startPositions == nil then
		return
	end

	glDepthTest(false)

	local circleColors = {}
	local baseCircleColors = {}
	local glowColors = {}

	for _, teamStartPosition in pairs(startPositions) do
		for _, position in ipairs(teamStartPosition) do
			local sx, sz = position.spawnPoint.x, position.spawnPoint.z

			local colorCount = 0
			for j = 1, #placedCommanders do
				local p = placedCommanders[j].position
				if mathDistance2dSquared(sx, sz, p[1], p[3]) < CIRCLE_RADIUS_SQUARED then
					colorCount = colorCount + 1
					local r, g, b, a = spGetTeamColor(placedCommanders[j].teamID)
					if not circleColors[colorCount] then
						circleColors[colorCount] = { r, g, b, a }
					else
						circleColors[colorCount][1], circleColors[colorCount][2], circleColors[colorCount][3], circleColors[colorCount][4] = r, g, b, a
					end
				end
			end
			for j = colorCount + 1, #circleColors do
				circleColors[j] = nil
			end

			local baseCount = 0
			if config.usePlayerColorForSpawnPointCircle and colorCount > 0 then
				for j = 1, colorCount do
					baseCount = baseCount + 1
					if not baseCircleColors[baseCount] then
						baseCircleColors[baseCount] = { circleColors[j][1], circleColors[j][2], circleColors[j][3], config.spawnPointCircleColor[4] }
					else
						baseCircleColors[baseCount][1] = circleColors[j][1]
						baseCircleColors[baseCount][2] = circleColors[j][2]
						baseCircleColors[baseCount][3] = circleColors[j][3]
						baseCircleColors[baseCount][4] = config.spawnPointCircleColor[4]
					end
				end
			else
				baseCount = 1
				if not baseCircleColors[1] then
					baseCircleColors[1] = {}
				end
				baseCircleColors[1][1] = config.spawnPointCircleColor[1]
				baseCircleColors[1][2] = config.spawnPointCircleColor[2]
				baseCircleColors[1][3] = config.spawnPointCircleColor[3]
				baseCircleColors[1][4] = config.spawnPointCircleColor[4]
			end
			for j = baseCount + 1, #baseCircleColors do
				baseCircleColors[j] = nil
			end

			local glowAlpha = config.spawnPointCircleColor[4] * 0.2
			for j = 1, baseCount do
				if not glowColors[j] then
					glowColors[j] = { baseCircleColors[j][1], baseCircleColors[j][2], baseCircleColors[j][3], glowAlpha }
				else
					glowColors[j][1], glowColors[j][2], glowColors[j][3], glowColors[j][4] = baseCircleColors[j][1], baseCircleColors[j][2], baseCircleColors[j][3], glowAlpha
				end
			end
			for j = baseCount + 1, #glowColors do
				glowColors[j] = nil
			end

			drawCircle(sx, sz, config.circleRadius, config.circleSegments, config.circleThickness, baseCircleColors, glowColors)

			if position.baseCenter then
				local bx, bz = position.baseCenter.x, position.baseCenter.z
				glColor(config.baseCenterCircleColor[1], config.baseCenterCircleColor[2], config.baseCenterCircleColor[3], config.baseCenterCircleColor[4])
				drawCircle(bx, bz, config.circleRadius, config.circleSegments, config.circleThickness, config.baseCenterCircleColor, nil)
				drawArrow(sx, spGetGroundHeight(sx, sz), sz, bx, spGetGroundHeight(bx, bz), bz, 70, spawnPointAlphaZeroColor, config.spawnPointCircleColor)
			end
		end
	end
end

local function drawAllStartLocationsCircles()
	if not circleDisplayListID then
		circleDisplayListID = gl.CreateList(buildCircleDisplayList)
	end
	gl.CallList(circleDisplayListID)
end

local function getCaptions(role)
	if captionsCache[role] then
		return captionsCache[role]
	end

	local title, description
	local roles = role:split("/")

	if #roles == 1 then
		title = Spring.I18N("ui.startPositionSuggestions.roles." .. roles[1] .. ".title")
		description = Spring.I18N("ui.startPositionSuggestions.roles." .. roles[1] .. ".description")
	elseif #roles > 1 then
		local title1 = Spring.I18N("ui.startPositionSuggestions.roles." .. roles[1] .. ".title")
		local title2 = Spring.I18N("ui.startPositionSuggestions.roles." .. roles[2] .. ".title")
		title = Spring.I18N("ui.startPositionSuggestions.multiRole.title", { role1 = title1, role2 = title2})

		local description1 = Spring.I18N("ui.startPositionSuggestions.roles." .. roles[1] .. ".description")
		local description2 = Spring.I18N("ui.startPositionSuggestions.roles." .. roles[2] .. ".description")
		description = Spring.I18N("ui.startPositionSuggestions.multiRole.description", { role1 = description1, role2 = description2})
	end

	captionsCache[role] = { title = title, description = description }
	return captionsCache[role]
end

local function buildTextDisplayList(cameraFlipped, cameraName, cameraRy)
	if startPositions == nil then
		return
	end

	glDepthTest(false)

	for _, teamStartPosition in pairs(startPositions) do
		for i, position in ipairs(teamStartPosition) do
			local sx, sz = position.spawnPoint.x, position.spawnPoint.z

			glPushMatrix()
			glTranslate(sx, spGetGroundHeight(sx, sz), sz)

			glRotate(-90, 1, 0, 0)
			if cameraFlipped == 1 then
				glRotate(180, 0, 0, 1)
			elseif cameraName == "spring" then
				glRotate(-180 * cameraRy / mathPi, 0, 0, 1)
			end

			local showRole = position.role ~= nil
			if showRole then
				font:SetTextColor(config.roleTextColor)
				font:Print(getCaptions(position.role).title, 0, 0, config.roleTextSize, "cao")
			end

			font:SetTextColor(config.playerTextColor)
			font:Print(tostring(i), 0, 0, config.playerTextSize, showRole and "cdo" or "cvo")

			glPopMatrix()
		end
	end
end

local function updateCameraController()
	local cameraName, _, _, cameraStateValue3 = SpringGetCameraState(false)
	local cameraFlipped = cameraName == "ta" and cameraStateValue3 or nil
	if activeCameraName ~= cameraName or activeCameraFlipped ~= cameraFlipped then
		activeCameraName = cameraName
		activeCameraFlipped = cameraFlipped
		invalidateTextDisplayList()
	end
end

local function drawAllStartLocationsText()
	if startPositions == nil then
		return
	end

	local cameraName = activeCameraName
	local cameraFlipped = activeCameraFlipped
	local ry = 0
	local roundedRy = 0
	if cameraName == "spring" then
		_, ry, _ = SpringGetCameraRotation()
		roundedRy = mathCeil(ry * 100) / 100
	end

	local needsRebuild = not textDisplayListID
		or textDisplayListCameraFlipped ~= cameraFlipped
		or textDisplayListCameraMode ~= cameraName
		or (cameraName == "spring" and textDisplayListCameraRy ~= roundedRy)

	if needsRebuild then
		invalidateTextDisplayList()
		textDisplayListCameraFlipped = cameraFlipped
		textDisplayListCameraMode = cameraName
		textDisplayListCameraRy = roundedRy
		textDisplayListID = gl.CreateList(buildTextDisplayList, cameraFlipped, cameraName, ry)
	end

	gl.CallList(textDisplayListID)
end

local function drawAllStartLocations()
	drawAllStartLocationsCircles()
	drawAllStartLocationsText()
end

local function wrapLine(str, maxLength)
	local result = {}
	local line = ""

	for word in str:gmatch("%S+") do
		if #line + #word + 1 > maxLength then
			tableInsert(result, line)
			line = word
		else
			if #line > 0 then
				line = line .. " " .. word
			else
				line = word
			end
		end
	end

	if #line > 0 then
		tableInsert(result, line)
	end

	return tableConcat(result, "\n")
end

local function wrapText(str, maxLength)
	local result = string.gsub(str,
		"[^\n]*",
		function(s)
			return wrapLine(s, maxLength)
		end
	)
	return result
end

local function drawTooltip()
	if not tooltipKey or Spring.DiffTimers(Spring.GetTimer(), tooltipStartTime) < config.tooltipDelay then
		return
	end

	if WG["pregame-build"] then
		if #(WG["pregame-build"].getBuildQueue()) > 0 or WG["pregame-build"].getPreGameDefID() then
			return
		end
	end

	local x, y = spGetMouseState()
	if not x or not y then
		return
	end

	if not wrappedDescriptionCache[tooltipKey] then
		wrappedDescriptionCache[tooltipKey] = wrapText(
			getCaptions(tooltipKey).description,
			config.tooltipMaxWidthChars
		)
	end

	local xOffset, yOffset = 20, -12
	WG["tooltip"].ShowTooltip(
		"startPositionTooltip",
		wrappedDescriptionCache[tooltipKey],
		x + xOffset,
		y + yOffset,
		getCaptions(tooltipKey).title
	)
end

local function drawTutorial()
	if config.hasRunBefore and (not WG["notifications"] or not WG["notifications"].getTutorial()) then
		return
	end

	if not cachedTutorialText then
		cachedTutorialText = wrapText(
			Spring.I18N("ui.startPositionSuggestions.tutorial"),
			config.tutorialMaxWidthChars
		)
	end

	if not tutorialDisplayListID then
		tutorialDisplayListID = gl.CreateList(function()
			fontTutorial:SetOutlineColor(0,0,0,1)
			fontTutorial:SetTextColor(0.9, 0.9, 0.9, 1)
			fontTutorial:Print(
				cachedTutorialText,
				vsx * 0.5,
				vsy * 0.75,
				config.tutorialTextSize*resMult,
				"cao"
			)
		end)
	end
	gl.CallList(tutorialDisplayListID)
end

function widget:ViewResize()
	invalidateTextDisplayList()
	invalidateTutorialDisplayList()
	if font then
		gl.DeleteFont(font)
	end
	if fontTutorial then
		gl.DeleteFont(fontTutorial)
	end
	vsx, vsy = spGetViewGeometry()
	resMult = vsy/1440
	local baseFontSize = mathMax(config.playerTextSize, config.roleTextSize) * 0.6
	font = gl.LoadFont(
		"fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf"),
		baseFontSize*resMult,
		(baseFontSize*resMult) / 14,
		1
	)
	fontTutorial = gl.LoadFont(
		"fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf"),
		config.tutorialTextSize*resMult,
		(config.tutorialTextSize*resMult) / 14,
		1
	)
end

function widget:GetConfigData()
	return {
		hasRunBefore = true
	}
end

function widget:SetConfigData(data)
	if data and data.hasRunBefore then
		config.hasRunBefore = data.hasRunBefore
	end
end

function widget:Initialize()
	Spring.SetLogSectionFilterLevel(widget:GetInfo().name, LOG.INFO)
	widget:ViewResize()
	updateCameraController()
	startPositions = loadStartPositions()
	if not startPositions then
		--usingCurrentTeamStartPositions = true
		--startPositions = loadCurrentTeamStartPositions()
		--Spring.Log(widget:GetInfo().name, LOG.WARNING, "Using current team start positions for testing")
		widgetHandler:RemoveWidget()
		return
	end
end

function widget:Shutdown()
	invalidateCircleDisplayList()
	invalidateTextDisplayList()
	invalidateTutorialDisplayList()
	gl.DeleteFont(font)
	gl.DeleteFont(fontTutorial)
end

local function checkTooltips()
	local mx, my = spGetMouseState()
	local _, mw = Spring.TraceScreenRay(mx, my, true, true)
	local mwx, mwy, mwz
	if mw ~= nil then
		mwx, mwy, mwz = unpack(mw)
	end

	local prevTooltipKey = tooltipKey
	tooltipKey = nil

	if mw == nil then
		return
	end

	for _, teamStartPosition in pairs(startPositions) do
		for _, position in ipairs(teamStartPosition) do
			local newKey
			if mathDistance2dSquared(mwx, mwz, position.spawnPoint.x, position.spawnPoint.z) < CIRCLE_RADIUS_SQUARED then
				newKey = position.role
			elseif position.baseCenter and mathDistance2dSquared(mwx, mwz, position.baseCenter.x, position.baseCenter.z) < CIRCLE_RADIUS_SQUARED then
				newKey = "baseCenter"
			end

			if newKey then
				if newKey ~= prevTooltipKey then
					tooltipStartTime = Spring.GetTimer()
				end
				tooltipKey = newKey
			end
		end
	end
end

local function updatePlacedCommanders()
	local commanderCount = 0
	local modified = false
	for _, teamID in ipairs(Spring.GetTeamList()) do
		local playerID = select(2, Spring.GetTeamInfo(teamID, false))
		local name, _, spec = Spring.GetPlayerInfo(playerID, false)
		if name ~= nil and not spec and teamID ~= gaiaTeamID then
			local x, y, z = Spring.GetTeamStartPosition(teamID)
			if x and y and z then
				local r, g, b, a = spGetTeamColor(teamID)
				commanderCount = commanderCount + 1
				local commander = placedCommanders[commanderCount]
				if not commander then
					commander = { position = {} }
					placedCommanders[commanderCount] = commander
					modified = true
				elseif commander.teamID ~= teamID or
				       commander.position[1] ~= x or
				       commander.position[2] ~= y or
				       commander.position[3] ~= z or
				       commander.colorR ~= r or
				       commander.colorG ~= g or
				       commander.colorB ~= b or
				       commander.colorA ~= a then
					modified = true
				end

				commander.position[1], commander.position[2], commander.position[3] = x, y, z
				commander.teamID = teamID
				commander.colorR, commander.colorG, commander.colorB, commander.colorA = r, g, b, a
				commander.playerID = playerID
				commander.playerName = name
			end
		end
	end

	if #placedCommanders ~= commanderCount then
		modified = true
		for i = #placedCommanders, commanderCount + 1, -1 do
			placedCommanders[i] = nil
		end
	end

	return modified
end

local function checkPlacedCommanders()
	if updatePlacedCommanders() then
		if usingCurrentTeamStartPositions then
			startPositions = loadCurrentTeamStartPositions()
			invalidateTextDisplayList()
		end
		invalidateCircleDisplayList()
	end
end

local tooltipTimer = 0
local commanderTimer = 0
local cameraControllerTimer = 0
function widget:Update(dt)
	tooltipTimer = tooltipTimer + dt
	if tooltipTimer > 0.2 then
		checkTooltips()
		tooltipTimer = 0
	end
	commanderTimer = commanderTimer + dt
	if commanderTimer > 0.5 then
		checkPlacedCommanders()
		commanderTimer = 0
	end
	cameraControllerTimer = cameraControllerTimer + dt
	if cameraControllerTimer > 0.1 then
		updateCameraController()
		cameraControllerTimer = 0
	end
end

function widget:DrawWorldPreUnit()
	if SpringGetGameFrame() > 0 then
		widgetHandler:RemoveWidget()
		return
	end
	if SpringIsGUIHidden() then
		return
	end
	drawAllStartLocations()
end

function widget:DrawScreen()
	if SpringIsGUIHidden() then
		return
	end
	drawTooltip()
	drawTutorial()
end
