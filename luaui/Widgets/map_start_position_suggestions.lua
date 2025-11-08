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
local tableInsert = table.insert

-- Localized Spring API for performance
local spGetMouseState = Spring.GetMouseState
local spGetGroundHeight = Spring.GetGroundHeight
local spGetViewGeometry = Spring.GetViewGeometry

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

local vsx, vsy = spGetViewGeometry()

local function glListCache(originalFunc)
	local cache = {}

	local function clearCache()
		for key, listID in pairs(cache) do
			gl.DeleteList(listID)
		end
		cache = {}
	end

	local function decoratedFunc(...)
		local rawParams = { ... }
		local params = {}
		for index, value in ipairs(rawParams) do
			if index > 1 then
				tableInsert(params, value)
			end
		end

		local key = table.toString(params)

		if cache[key] == nil then
			local function fn()
				originalFunc(unpack(params))
			end
			cache[key] = gl.CreateList(fn)
		end

		gl.CallList(cache[key])
	end

	local decoratedFunction = setmetatable({}, {
		__call = decoratedFunc,
		__index = {
			invalidate = clearCache,
			getCache = function()
				return cache
			end,
			getListID = function(...)
				local params = { ... }
				local key = table.toString(params)
				return cache[key]
			end
		}
	})

	return decoratedFunction
end

local function drawArrow(a, b, size, cStart, cEnd)
	local dir = { b[1] - a[1], b[2] - a[2], b[3] - a[3] }
	local length = math.sqrt(dir[1] ^ 2 + dir[2] ^ 2 + dir[3] ^ 2)

	local dirN = { dir[1] / length, dir[2] / length, dir[3] / length }

	local horizontalAngle = math.atan2(dirN[1], dirN[3])
	local verticalAngle = -math.asin(dirN[2])

	size = size or 0.1 * length
	local headL = size
	local headW = size / 2

	local pL = { -headW, 0, length - headL }
	local pR = { headW, 0, length - headL }

	local shaftWidth = headW / 6

	local function drawShaft()
		if cStart ~= nil then
			gl.Color(cStart)
		end
		gl.Vertex(-shaftWidth, 0, 0)
		gl.Vertex(shaftWidth, 0, 0)

		if cEnd ~= nil then
			gl.Color(cEnd)
		end
		gl.Vertex(shaftWidth, 0, length - headL)
		gl.Vertex(-shaftWidth, 0, length - headL)
	end

	local function drawHead()
		if cEnd ~= nil then
			gl.Color(cEnd)
		end
		gl.Vertex(0, 0, length)
		gl.Vertex(pL[1], pL[2], pL[3])
		gl.Vertex(pR[1], pR[2], pR[3])
	end

	gl.PushMatrix()
	gl.Translate(a[1], a[2], a[3])
	gl.Rotate(horizontalAngle * 180 / mathPi, 0, 1, 0) -- Rotate around Y-axis
	gl.Rotate(verticalAngle * 180 / mathPi, 1, 0, 0) -- Tilt up or down

	gl.BeginEnd(GL.QUADS, drawShaft)
	gl.BeginEnd(GL.TRIANGLES, drawHead)

	gl.PopMatrix()
end

local function drawCircle(position, radius, segments, thickness, colors, colorsGlow)
	local startAngle = -mathPi / 2
	local cx, cy, cz = unpack(position)

	local function drawArc(r, s, t, a1, a2, ci, co)
		for i = 0, s do
			local angle = startAngle + a1 + (a2 - a1) * (i / s)
			local xOuter = cx + r * mathCos(angle)
			local zOuter = cz + r * mathSin(angle)
			local xInner = cx + (r - t) * mathCos(angle)
			local zInner = cz + (r - t) * mathSin(angle)

			if ci ~= nil then
				gl.Color(ci)
			end
			gl.Vertex(xInner, spGetGroundHeight(xInner, zInner), zInner)

			if co ~= nil then
				gl.Color(co)
			end
			gl.Vertex(xOuter, spGetGroundHeight(xOuter, zOuter), zOuter)
		end
	end

	if colors ~= nil and #colors > 0 then
		if type(colors[1]) == "number" then
			-- single color
			colors = { colors }
		end

		local s = mathCeil(segments / #colors)
		for i, co in ipairs(colors) do
			local a1 = i * 2 * mathPi / #colors
			local a2 = (i + 1) * 2 * mathPi / #colors
			gl.BeginEnd(
				GL.TRIANGLE_STRIP, drawArc,
				radius,
				s,
				thickness,
				a1,
				a2,
				co,
				co
			)
		end
	end

	if colorsGlow ~= nil and #colorsGlow > 0 then
		if type(colorsGlow[1]) == "number" then
			-- single color
			colorsGlow = { colorsGlow }
		end

		local s = mathCeil(segments / #colorsGlow)
		for i, co in ipairs(colorsGlow) do
			local ci = { co[1], co[2], co[3], 0 }
			local a1 = i * 2 * mathPi / #colorsGlow
			local a2 = (i + 1) * 2 * mathPi / #colorsGlow
			local baseRadius = config.glowRadiusCoefficient < 0 and radius or radius - thickness
			gl.BeginEnd(
				GL.TRIANGLE_STRIP, drawArc,
				baseRadius,
				s,
				radius * config.glowRadiusCoefficient,
				a1,
				a2,
				ci,
				co
			)
		end
	end
end

local function multiplyAlpha(c, m)
	return { c[1], c[2], c[3], c[4] * m }
end

local drawAllStartLocationsCircles = glListCache(function()
	if startPositions == nil then
		return
	end

	glDepthTest(false)

	for allyTeamID, teamStartPosition in pairs(startPositions) do
		for i, position in ipairs(teamStartPosition) do
			local sx, sz = position.spawnPoint.x, position.spawnPoint.z

			local circleColors = {}
			for _, placed in ipairs(placedCommanders) do
				local p = placed.position

				if math.diag(sx - p[1], sz - p[3]) < config.circleRadius then
					tableInsert(circleColors, table.pack(Spring.GetTeamColor(placed.teamID)))
				end
			end

			local baseCircleColors = { config.spawnPointCircleColor }
			if config.usePlayerColorForSpawnPointCircle and #circleColors > 0 then
				baseCircleColors = circleColors
			end

			drawCircle(
				{ sx, spGetGroundHeight(sx, sz), sz },
				config.circleRadius,
				128,
				config.circleThickness,
				table.map(baseCircleColors, function(c)
					return { c[1], c[2], c[3], config.spawnPointCircleColor[4] }
				end),
				table.map(circleColors, function(c)
					return { c[1], c[2], c[3], config.spawnPointCircleColor[4] * 0.5 }
				end)
			)

			if position.baseCenter ~= nil then
				local bx, bz = position.baseCenter.x, position.baseCenter.z

				glColor(unpack(config.baseCenterCircleColor))
				drawCircle(
					{ bx, 0, bz },
					config.circleRadius,
					128,
					config.circleThickness,
					config.baseCenterCircleColor
				)

				drawArrow(
					{ sx, spGetGroundHeight(sx, sz), sz },
					{ bx, spGetGroundHeight(bx, bz), bz },
					70,
					multiplyAlpha(config.spawnPointCircleColor, 0),
					config.spawnPointCircleColor
				)
			end
		end
	end
end)

local function getCaptions(role)
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

	return { title = title, description = description }
end

local function drawAllStartLocationsText()
	if startPositions == nil then
		return
	end

	local cameraState = SpringGetCameraState()
	local _, ry, _ = SpringGetCameraRotation()

	glDepthTest(false)

	for allyTeamID, teamStartPosition in pairs(startPositions) do
		for i, position in ipairs(teamStartPosition) do
			local sx, sz = position.spawnPoint.x, position.spawnPoint.z

			glPushMatrix()
			glTranslate(sx, spGetGroundHeight(sx, sz), sz)

			glRotate(-90, 1, 0, 0)
			if cameraState.flipped == 1 then
				-- only applicable in ta camera
				glRotate(180, 0, 0, 1)
			elseif cameraState.mode == 2 then
				-- spring camera
				glRotate(-180 * ry / mathPi, 0, 0, 1)
			end

			local showRole = position.role ~= nil
			if showRole then
				font:SetTextColor(config.roleTextColor)
				font:Print(
					getCaptions(position.role).title,
					0,
					0,
					config.roleTextSize,
					"cao"
				)
			end

			font:SetTextColor(config.playerTextColor)
			font:Print(
				tostring(i),
				0,
				0,
				config.playerTextSize,
				showRole and "cdo" or "cvo"
			)

			glPopMatrix()
		end
	end
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

	return table.concat(result, "\n")
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

	local xOffset, yOffset = 20, -12
	WG["tooltip"].ShowTooltip(
		"startPositionTooltip",
		wrapText(
			getCaptions(tooltipKey).description,
			config.tooltipMaxWidthChars
		),
		x + xOffset,
		y + yOffset,
		getCaptions(tooltipKey).title
	)
end

local function drawTutorial()
	if config.hasRunBefore and (not WG["notifications"] or not WG["notifications"].getTutorial()) then
		return
	end

	fontTutorial:SetOutlineColor(0,0,0,1)
	fontTutorial:SetTextColor(0.9, 0.9, 0.9, 1)
	fontTutorial:Print(
		wrapText(
			Spring.I18N("ui.startPositionSuggestions.tutorial"),
			config.tutorialMaxWidthChars
		),
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
	drawAllStartLocationsCircles.invalidate()
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
			if math.diag(mwx - position.spawnPoint.x, mwz - position.spawnPoint.z) < config.circleRadius then
				newKey = position.role
			elseif position.baseCenter and math.diag(mwx - position.baseCenter.x, mwz - position.baseCenter.z) < config.circleRadius then
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
	if table.toString(placedCommanders) ~= table.toString(newPlacedCommanders) then
		modified = true
	end

	return newPlacedCommanders, modified
end

local function checkPlacedCommanders()
	local newPlacedCommanders, modified = getPlacedCommanders()
	if modified then
		placedCommanders = newPlacedCommanders
		drawAllStartLocationsCircles.invalidate()
	end
end

local t = 0
function widget:Update(dt)
	checkTooltips()
	t = t + dt
	if t > 0.5 then
		checkPlacedCommanders()
		t = 0
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
