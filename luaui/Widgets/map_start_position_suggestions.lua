local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Start Position Suggestions",
		desc = "Show expert recommended starting locations on the map",
		license = "GNU GPL, v2 or later",
		layer = 10000,
		enabled = true
	}
end


-- Localized functions for performance
local mathCeil = math.ceil
local mathMax = math.max
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
	circleThickness = 6,

	playerTextSize = 140,
	roleTextSize = 90,
	tutorialTextSize = 20,

	spawnPointCircleColor = { 1, 1, 1, 0.6 },
	baseCenterCircleColor = { 1, 1, 1, 0.4 },
	usePlayerColorForSpawnPointCircle = true,

	playerTextColor = { 1, 1, 1, 0.6 },
	roleTextColor = { 1, 1, 1, 0.6 },

	glowRadiusCoefficient = -0.3,

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

-- widget code
-- ===========

local font = nil
local fontTutorial = nil

---@type WidgetStartPositions
local startPositions = {}

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

	if colors and #colors > 0 then
		if type(colors[1]) == "number" then
			reuseColorsArray[1] = colors
			colors = reuseColorsArray
		end

		local colorCount = #colors
		arcSegments = mathCeil(segments / colorCount)
		arcRadius = radius
		arcThickness = thickness

		for i = 1, colorCount do
			local co = colors[i]
			arcA1 = i * 2 * mathPi / colorCount
			arcA2 = (i + 1) * 2 * mathPi / colorCount
			arcColorInner = co
			arcColorOuter = co
			glBeginEnd(GL.TRIANGLE_STRIP, drawArc)
		end
	end

	if colorsGlow and #colorsGlow > 0 then
		if type(colorsGlow[1]) == "number" then
			reuseGlowColorsArray[1] = colorsGlow
			colorsGlow = reuseGlowColorsArray
		end

		local glowCount = #colorsGlow
		arcSegments = mathCeil(segments / glowCount)
		arcRadius = config.glowRadiusCoefficient < 0 and radius or radius - thickness
		arcThickness = radius * config.glowRadiusCoefficient

		for i = 1, glowCount do
			local co = colorsGlow[i]
			reuseColorTable[1], reuseColorTable[2], reuseColorTable[3], reuseColorTable[4] = co[1], co[2], co[3], 0
			arcA1 = i * 2 * mathPi / glowCount
			arcA2 = (i + 1) * 2 * mathPi / glowCount
			arcColorInner = reuseColorTable
			arcColorOuter = co
			glBeginEnd(GL.TRIANGLE_STRIP, drawArc)
		end
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
				baseCircleColors[1] = config.spawnPointCircleColor
			end
			for j = baseCount + 1, #baseCircleColors do
				baseCircleColors[j] = nil
			end

			local glowAlpha = config.spawnPointCircleColor[4] * 0.5
			for j = 1, colorCount do
				if not glowColors[j] then
					glowColors[j] = { circleColors[j][1], circleColors[j][2], circleColors[j][3], glowAlpha }
				else
					glowColors[j][1], glowColors[j][2], glowColors[j][3], glowColors[j][4] = circleColors[j][1], circleColors[j][2], circleColors[j][3], glowAlpha
				end
			end
			for j = colorCount + 1, #glowColors do
				glowColors[j] = nil
			end

			drawCircle(sx, sz, config.circleRadius, 128, config.circleThickness, baseCircleColors, glowColors)

			if position.baseCenter then
				local bx, bz = position.baseCenter.x, position.baseCenter.z
				glColor(config.baseCenterCircleColor[1], config.baseCenterCircleColor[2], config.baseCenterCircleColor[3], config.baseCenterCircleColor[4])
				drawCircle(bx, bz, config.circleRadius, 128, config.circleThickness, config.baseCenterCircleColor, nil)
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

local function buildTextDisplayList(cameraFlipped, cameraMode, cameraRy)
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
			elseif cameraMode == 2 then
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

local function drawAllStartLocationsText()
	if startPositions == nil then
		return
	end

	local cameraState = SpringGetCameraState()
	local _, ry, _ = SpringGetCameraRotation()

	local cameraFlipped = cameraState.flipped
	local cameraMode = cameraState.mode
	local roundedRy = mathCeil(ry * 100) / 100

	local needsRebuild = not textDisplayListID
		or textDisplayListCameraFlipped ~= cameraFlipped
		or textDisplayListCameraMode ~= cameraMode
		or (cameraMode == 2 and textDisplayListCameraRy ~= roundedRy)

	if needsRebuild then
		invalidateTextDisplayList()
		textDisplayListCameraFlipped = cameraFlipped
		textDisplayListCameraMode = cameraMode
		textDisplayListCameraRy = roundedRy
		textDisplayListID = gl.CreateList(buildTextDisplayList, cameraFlipped, cameraMode, ry)
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

	fontTutorial:SetOutlineColor(0,0,0,1)
	fontTutorial:SetTextColor(0.9, 0.9, 0.9, 1)
	fontTutorial:Print(
		cachedTutorialText,
		vsx * 0.5,
		vsy * 0.75,
		config.tutorialTextSize*resMult,
		"cao"
	)
end

function widget:ViewResize()
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
	startPositions = loadStartPositions()
	if not startPositions then
		widgetHandler:RemoveWidget()
		return
	end
end

function widget:Shutdown()
	invalidateCircleDisplayList()
	invalidateTextDisplayList()
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

	for allyTeamID, teamStartPosition in pairs(startPositions) do
		for i, position in ipairs(teamStartPosition) do
			local newKey
			if math.distance2dSquared(mwx, mwz, position.spawnPoint.x, position.spawnPoint.z) < CIRCLE_RADIUS_SQUARED then
				newKey = position.role
			elseif position.baseCenter and math.distance2dSquared(mwx, mwz, position.baseCenter.x, position.baseCenter.z) < CIRCLE_RADIUS_SQUARED then
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

local function getPlacedCommanders()
	local newPlacedCommanders = {}
	for _, teamID in ipairs(Spring.GetTeamList()) do
		local playerID = select(2, Spring.GetTeamInfo(teamID, false))
		local name, _, spec = Spring.GetPlayerInfo(playerID, false)
		if name ~= nil and not spec and teamID ~= gaiaTeamID then
			local x, y, z = Spring.GetTeamStartPosition(teamID)
			if x and y and z then
				tableInsert(newPlacedCommanders, {
					position = { x, y, z },
					teamID = teamID,
					playerID = playerID,
					playerName = name,
				})
			end
		end
	end

	local modified = false
	if #placedCommanders ~= #newPlacedCommanders then
		modified = true
	else
		for i = 1, #newPlacedCommanders do
			local old = placedCommanders[i]
			local new = newPlacedCommanders[i]
			if old.teamID ~= new.teamID or
			   old.position[1] ~= new.position[1] or
			   old.position[2] ~= new.position[2] or
			   old.position[3] ~= new.position[3] then
				modified = true
				break
			end
		end
	end

	return newPlacedCommanders, modified
end

local function checkPlacedCommanders()
	local newPlacedCommanders, modified = getPlacedCommanders()
	if modified then
		placedCommanders = newPlacedCommanders
		invalidateCircleDisplayList()
	end
end

local tooltipTimer = 0
local commanderTimer = 0
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
