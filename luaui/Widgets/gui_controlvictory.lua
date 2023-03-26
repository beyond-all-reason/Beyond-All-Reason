
local modOptions = Spring.GetModOptions()
if modOptions.scoremode == "disabled" then
	return
end

--Make controlvictory exit if chickens are present
local pveEnabled = Spring.Utilities.Gametype.IsPvE()

if pveEnabled then
	Spring.Echo("[ControlVictory] Deactivated because Chickens or Scavengers are present!")
	return false
end

function widget:GetInfo()
	return {
		name = "Control Victory",
		desc = "",
		author = "Floris",
		date = "July 2021",
		license = "GNU GPL, v2 or later",
		layer = -3,
		enabled = true
	}
end

local getMiniMapFlipped = VFS.Include("luaui/Widgets/Include/minimap_utils.lua").getMiniMapFlipped

local selectedScoreMode = modOptions.scoremode
local captureRadius
if modOptions.usemexconfig then
	captureRadius = 100
else
	captureRadius = 150
end
local startTime = modOptions.starttime
local metalPerPoint = modOptions.metalperpoint
local energyPerPoint = modOptions.energyperpoint
local tugofWarModifier = modOptions.tugofwarmodifier
local limitScore = modOptions.limitscore
local captureTime = modOptions.capturetime
local dominationScoreTime = modOptions.dominationscoretime
local dominationScore = modOptions.dominationscore

local scoreModes = {
	disabled = { name = "Disabled" }, -- none (duh)
	countdown = { name = "Countdown" }, -- A point decreases all opponents' scores, zero means defeat
	tugofwar = { name = "Tug of War" }, -- A point steals enemy score, zero means defeat
	domination = { name = "Domination" }, -- Holding all points will grant 100 score, first to reach the score limit wins
}
local scoreMode = scoreModes[selectedScoreMode]
local _,_,_,_,_,gaiaAllyTeamID = Spring.GetTeamInfo(Spring.GetGaiaTeamID())

local pieces = math.floor(captureRadius / 9)
local OPTIONS = {
	circlePieces = pieces,
	circlePieceDetail = math.floor(pieces / 3),
	circleSpaceUsage = 0.81,
	circleInnerOffset = 0,
	rotationSpeed = 0.3,
}
pieces = nil

local exampleImage = ":n:LuaRules/Images/controlpoints.png"
local showGameModeInfo = true
local controlPointList
local controlPointPromptPlayed = false

local scoreboardRelX = 0.87
local scoreboardRelY = 0.76
local scoreboardWidth = 100
local scoreboardHeight = 100
local scoreboardX, scoreboardY
local draggingScoreboard = false

local bgMargin = 6
local vsx, vsy = Spring.GetViewGeometry()
local uiScale = 1
local ui_scale = Spring.GetConfigFloat("ui_scale", 1)

local closeButtonSize = 30
local screenHeight = 212 - bgMargin - bgMargin
local screenWidth = 1050 - bgMargin - bgMargin
local screenX = (vsx * 0.5) - (screenWidth / 2)
local screenY = (vsy * 0.5) + (screenHeight / 2)
local titleRect, elementRect
local infoList, scoreboardList, mouseoverScoreboardList

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local fontfileScale = (0.5 + (vsx * vsy / 5700000))
local fontfileSize = 32
local fontfileOutlineSize = 10
local fontfileOutlineStrength = 1.4
local font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)


local Text = gl.Text
local Color = gl.Color
local PushMatrix = gl.PushMatrix
local PopMatrix = gl.PopMatrix
local Translate = gl.Translate
local BeginEnd = gl.BeginEnd
local CreateList = gl.CreateList
local CallList = gl.CallList
local Scale = gl.Scale
local Rotate = gl.Rotate
local Vertex = gl.Vertex
local QUADS = GL.QUADS
local TRIANGLE_FAN = GL.TRIANGLE_FAN
local PolygonOffset = gl.PolygonOffset
local playerListEntry = {}
local capturePoints = {}
local controlPointSolidList = {}

local floor = math.floor
local math_isInRect = math.isInRect

local cvScore = {}
local cvPoints = {}
local cvDom = {}

local prevTimer = Spring.GetTimer()
local currentRotationAngle = 0

local ringThickness = 3.5
local capturePieParts = 4 + floor(captureRadius / 8)

local RectRound, UiElement, elementCorner

local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode
local anonymousTeamColor = {Spring.GetConfigInt("anonymousColorR", 255)/255, Spring.GetConfigInt("anonymousColorG", 0)/255, Spring.GetConfigInt("anonymousColorB", 0)/255}

-----------------------------------------------------------------------------------------
-- creates initial player listing
-----------------------------------------------------------------------------------------
local function createPlayerList()
	local playerEntries = {}
	for allyTeamID, teamScore in pairs(cvScore) do
		if allyTeamID ~= gaiaAllyTeamID then
			--does this allyteam have a table? if not, make one
			if playerEntries[allyTeamID] == nil then
				playerEntries[allyTeamID] = {}
			end

			for _, teamId in pairs(Spring.GetTeamList(allyTeamID)) do
				local playerList = Spring.GetPlayerList(teamId, true)
				-- does this team have an entry? if not, make one!
				if playerEntries[allyTeamID][teamId] == nil then
					playerEntries[allyTeamID][teamId] = {}
				end
				local r, g, b
				if anonymousMode ~= "disabled" then
					r, g, b = anonymousTeamColor[1], anonymousTeamColor[2], anonymousTeamColor[3]
				else
					r, g, b = Spring.GetTeamColor(teamId)
				end
				local playerTeamColor = string.char("255", r * 255, g * 255, b * 255)

				for k, v in pairs(playerList) do
					-- does this player have an entry? if not, make one!
					if playerEntries[allyTeamID][teamId][v] == nil then
						playerEntries[allyTeamID][teamId][v] = {}
					end

					playerEntries[allyTeamID][teamId][v]["name"] = Spring.GetPlayerInfo(v)
					playerEntries[allyTeamID][teamId][v]["color"] = playerTeamColor
				end -- end playerId
			end -- end teamId
		end -- allyTeamID
	end -- gaia exclusion
	return playerEntries
end

local function drawCircleLine(innersize, outersize)
	BeginEnd(QUADS, function()
		local detailPartWidth, a1, a2, a3, a4
		local width = OPTIONS.circleSpaceUsage
		local detail = OPTIONS.circlePieceDetail

		local radstep = (2.0 * math.pi) / OPTIONS.circlePieces
		for i = 1, OPTIONS.circlePieces do
			for d = 1, detail do

				detailPartWidth = ((width / detail) * d)
				a1 = ((i + detailPartWidth - (width / detail)) * radstep)
				a2 = ((i + detailPartWidth) * radstep)
				a3 = ((i + OPTIONS.circleInnerOffset + detailPartWidth - (width / detail)) * radstep)
				a4 = ((i + OPTIONS.circleInnerOffset + detailPartWidth) * radstep)

				--outer (fadein)
				Vertex(math.sin(a4) * innersize, 0, math.cos(a4) * innersize)
				Vertex(math.sin(a3) * innersize, 0, math.cos(a3) * innersize)
				--outer (fadeout)
				Vertex(math.sin(a1) * outersize, 0, math.cos(a1) * outersize)
				Vertex(math.sin(a2) * outersize, 0, math.cos(a2) * outersize)
			end
		end
	end)
end

local function drawCircleSolid(size, pieces, drawPieces, innercolor, outercolor, revert)
	BeginEnd(TRIANGLE_FAN, function()
		local radstep = (2.0 * math.pi) / pieces
		local a1
		if (innercolor) then
			Color(innercolor)
		end
		Vertex(0, 0, 0)
		if (outercolor) then
			Color(outercolor)
		end
		for i = 0, drawPieces do
			if revert then
				a1 = -(i * radstep)
			else
				a1 = (i * radstep)
			end
			Vertex(math.sin(a1) * size, 0, math.cos(a1) * size)
		end
	end)
end

local function drawGameModeInfo()
	local white = "\255\255\255\255"
	local offwhite = "\255\210\210\210"
	local yellow = "\255\255\255\0"
	local orange = "\255\255\135\0"
	local green = "\255\0\255\0"
	local red = "\255\255\0\0"
	local skyblue = "\255\136\197\226"

	PushMatrix()
	Translate(-(vsx * (uiScale - 1)) / 2, -(vsy * (uiScale - 1)) / 2, 0)
	Scale(uiScale, uiScale, 1)

	-- background
	local infoRect = {screenX - bgMargin, screenY - screenHeight - bgMargin, screenX + screenWidth + bgMargin, screenY + bgMargin}
	UiElement(infoRect[1], infoRect[2], infoRect[3], infoRect[4], 0,1,1,1, 1,1,1,1, Spring.GetConfigFloat("ui_opacity", 0.6) + 0.2)

	-- close button
	local size = closeButtonSize * 0.7
	local width = size * 0.055
	Color(1, 1, 1, 1)
	PushMatrix()
	Translate(screenX + screenWidth - (closeButtonSize / 2), screenY - (closeButtonSize / 2), 0)
	gl.Rotate(-45, 0, 0, 1)
	gl.Rect(-width, size / 2, width, -size / 2)
	gl.Rotate(90, 0, 0, 1)
	gl.Rect(-width, size / 2, width, -size / 2)
	PopMatrix()

	-- title
	local title = offwhite .. [[Area Capture Mode    ]] .. yellow .. scoreMode.name
	local titleFontSize = 18
	Color(0, 0, 0, 0.8)
	titleRect = { screenX - bgMargin, screenY + bgMargin, screenX + (gl.GetTextWidth(title) * titleFontSize) + 27 - bgMargin, screenY + 37 }
	RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], elementCorner, 1, 1, 0, 0)

	font:Begin()
	font:SetTextColor(1, 1, 1, 1)
	font:SetOutlineColor(0, 0, 0, 0.4)
	font:Print(title, screenX- bgMargin + (titleFontSize * 0.75), screenY + bgMargin + 8, titleFontSize, "on")
	font:End()

	-- image of minimap showing controlpoints
	local imageSize = 200
	Color(1, 1, 1, 1)
	gl.Texture(exampleImage)
	gl.TexRect(screenX, screenY, screenX + imageSize, screenY - imageSize)
	gl.Texture(false)

	-- textarea

	local infotext = offwhite .. [[Controlpoints are spread across the map. They can be captured by moving units into the circles.
Note that you can only build certain units inside them (e.g. Metal Extractors/Resource Node Generators).

There are 3 modes (Current mode is ]] .. yellow .. scoreMode.name .. offwhite .. [[):
- Countdown:  Your score counts down until zero based upon how many points your enemy owns.
- Tug of War: Score is transferred between teams. Score transferred is multiplied by ]] .. yellow .. tugofWarModifier .. offwhite .. [[.
- Domination: Capture all controlpoints on the map for ]] .. yellow .. dominationScoreTime .. offwhite .. [[ seconds in order to gain ]] .. yellow .. dominationScore .. offwhite .. [[ score. Goal ]] .. yellow .. limitScore .. offwhite .. [[.

You will also gain ]] .. white .. [[+]] .. skyblue .. metalPerPoint .. offwhite .. [[ metal and ]] .. white .. [[+]] .. yellow .. energyPerPoint .. offwhite .. [[ energy for each controlpoint you own.

There are various options available in the lobby bsettings (use ]] .. yellow .. [[!list bsettings]] .. offwhite .. [[ in the lobby chat)]]

	Text(infotext, screenX + imageSize + 15, screenY - 25, 16, "no")

	PopMatrix()
end

function widget:ViewResize(vsx2, vsy2)
	vsx, vsy = Spring.GetViewGeometry()
	ui_scale = Spring.GetConfigFloat("ui_scale", 1)
	uiScale = (0.75 + (vsx * vsy / 7500000)) * ui_scale

	screenX = (vsx * 0.5) - (screenWidth / 2)
	screenY = (vsy * 0.5) + (screenHeight / 2)

	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element

	scoreboardX = floor(vsx * scoreboardRelX)
	scoreboardY = floor(vsy * scoreboardRelY)

	if infoList then
		gl.DeleteList(infoList)
	end
	infoList = CreateList(drawGameModeInfo)
end

local function GadgetControlVictoryUpdate(score, points, dom)
	cvScore = score
	cvPoints = points
	cvDom = dom
end

function widget:Initialize()

	widgetHandler:RegisterGlobal('GadgetControlVictoryUpdate', GadgetControlVictoryUpdate)

	playerListEntry = createPlayerList()

	widget:ViewResize(vsx, vsy)

	controlPointList = CreateList(drawCircleLine, captureRadius - ringThickness, captureRadius)
	if Spring.GetGameFrame() > 0 then
		showGameModeInfo = false
	end

	for i, capturePoint in pairs(cvPoints) do
		if capturePoints[i] == nil then
			capturePoints[i] = {}
			capturePoints[i].color = { 1, 1, 1 }
			capturePoints[i].aggressorColor = { 1, 1, 1 }
			capturePoints[i].x = capturePoint.x
			capturePoints[i].y = Spring.GetGroundHeight(capturePoint.x, capturePoint.z) + 2
			capturePoints[i].z = capturePoint.z
		end
		if capturePoint.owner and capturePoint.owner ~= gaiaAllyTeamID then
			capturePoints[i].color[1], capturePoints[i].color[2], capturePoints[i].color[3] = Spring.GetTeamColor(Spring.GetTeamList(capturePoint.owner)[1])
		else
			capturePoints[i].color = { 1, 1, 1 }
		end
		if capturePoint.aggressor and capturePoint.aggressor ~= gaiaAllyTeamID then
			capturePoints[i].aggressorColor[1], capturePoints[i].aggressorColor[2], capturePoints[i].aggressorColor[3] = Spring.GetTeamColor(Spring.GetTeamList(capturePoint.aggressor)[1])
		else
			capturePoints[i].aggressorColor = { 1, 1, 1 }
		end
		capturePoints[i].capture = capturePoint.capture
	end
end

local function drawPoints(simplified)
	local capturedAlpha, capturingAlpha, prefix, parts
	if simplified then
		-- for minimap
		capturedAlpha = 0.6
		capturingAlpha = 0.9
		prefix = 'm_'        -- so it uses different displaylists
		parts = math.ceil((OPTIONS.circlePieces * OPTIONS.circlePieceDetail) / 2)
	else
		capturedAlpha = 0.3
		capturingAlpha = 0.6
		prefix = ''
		parts = (OPTIONS.circlePieces * OPTIONS.circlePieceDetail)
	end
	for i, point in pairs(capturePoints) do
		PushMatrix()
		Translate(point.x, point.y, point.z)
		-- owner circle backgroundcolor
		if controlPointSolidList[prefix .. point.color[1] .. '_' .. point.color[2] .. '_' .. point.color[3]] == nil then
			controlPointSolidList[prefix .. point.color[1] .. '_' .. point.color[2] .. '_' .. point.color[3]] = CreateList(drawCircleSolid, captureRadius + ringThickness, parts, parts, { 0, 0, 0, 0 }, { point.color[1], point.color[2], point.color[3], capturedAlpha })
		end
		CallList(controlPointSolidList[prefix .. point.color[1] .. '_' .. point.color[2] .. '_' .. point.color[3]])

		-- captured percentage
		if point.capture > 0 then
			local revert = false
			if point.aggressorColor[1] .. '_' .. point.aggressorColor[2] .. '_' .. point.aggressorColor[3] == '1_1_1' then
				revert = true
			end
			local piesize = floor(((point.capture / captureTime) / (1 / capturePieParts)) + 0.5)
			if controlPointSolidList[prefix .. point.aggressorColor[1] .. '_' .. point.aggressorColor[2] .. '_' .. point.aggressorColor[3] .. '_' .. piesize] == nil then
				controlPointSolidList[prefix .. point.aggressorColor[1] .. '_' .. point.aggressorColor[2] .. '_' .. point.aggressorColor[3] .. '_' .. piesize] = CreateList(drawCircleSolid, (captureRadius - ringThickness * 2), capturePieParts, piesize, { 0, 0, 0, 0 }, { point.aggressorColor[1], point.aggressorColor[2], point.aggressorColor[3], capturingAlpha }, revert)
			end
			CallList(controlPointSolidList[prefix .. point.aggressorColor[1] .. '_' .. point.aggressorColor[2] .. '_' .. point.aggressorColor[3] .. '_' .. piesize])
		end
		if not simplified then
			-- not for minimap
			--ring
			Rotate(currentRotationAngle, 0, 1, 0)
			Color(1, 1, 1, 0.6)
			CallList(controlPointList)
		end
		PopMatrix()
	end
end

function widget:DrawInMiniMap()
	PushMatrix()
	gl.LoadIdentity()
	if getMiniMapFlipped() then
		Translate(1, 0, 0)
		Scale(-1 / Game.mapSizeX, -1 / Game.mapSizeZ, 0)
		Rotate(90, 1, 0, 0)
	else
		Translate(0, 1, 0)
		Scale(1 / Game.mapSizeX, 1 / Game.mapSizeZ, 0)
		Rotate(90, 1, 0, 0)
	end
	drawPoints(true)
	PopMatrix()
end

function widget:Update()
	local clockDifference = Spring.DiffTimers(Spring.GetTimer(), prevTimer)
	prevTimer = Spring.GetTimer()

	-- animate rotation
	if OPTIONS.rotationSpeed > 0 then
		local angleDifference = (OPTIONS.rotationSpeed) * (clockDifference * 5)
		currentRotationAngle = currentRotationAngle + (angleDifference * 0.6)
		if currentRotationAngle > 360 then
			currentRotationAngle = currentRotationAngle - 360
		end
	end
end

function widget:GameFrame()
	for i, capturePoint in pairs(cvPoints) do
		if capturePoints[i] == nil then
			capturePoints[i] = {}
			capturePoints[i].color = { 1, 1, 1 }
			capturePoints[i].aggressorColor = { 1, 1, 1 }
			capturePoints[i].x = capturePoint.x
			capturePoints[i].y = Spring.GetGroundHeight(capturePoint.x, capturePoint.z) + 2
			capturePoints[i].z = capturePoint.z
		end
		if capturePoint.owner and capturePoint.owner ~= gaiaAllyTeamID then
			capturePoints[i].color[1], capturePoints[i].color[2], capturePoints[i].color[3] = Spring.GetTeamColor(Spring.GetTeamList(capturePoint.owner)[1])
		else
			capturePoints[i].color = { 1, 1, 1 }
		end
		if capturePoint.aggressor and capturePoint.aggressor ~= gaiaAllyTeamID then
			capturePoints[i].aggressorColor[1], capturePoints[i].aggressorColor[2], capturePoints[i].aggressorColor[3] = Spring.GetTeamColor(Spring.GetTeamList(capturePoint.aggressor)[1])
		else
			capturePoints[i].aggressorColor = { 1, 1, 1 }
		end
		capturePoints[i].capture = capturePoint.capture
	end
end

function widget:DrawWorldPreUnit()
	if Spring.IsGUIHidden() then return end
	PolygonOffset(-10000, -1)  -- draw on top of water/map - sideeffect: will shine through terrain/mountains
	drawPoints(false)        -- Todo: use DrawWorldPreUnit make it so that it colorizes the map/ground
	PolygonOffset(false)
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal('GadgetControlVictoryUpdate')
	if WG['guishader'] then
		WG['guishader'].RemoveRect('cv_scoreboard')
		WG['guishader'].RemoveRect('cv_scoreboardtitle')
	end
	gl.DeleteFont(font)
end

local function drawMouseoverScoreboard()
	-- background
	Color(0, 0, 0, 0.75)
	RectRound(elementRect[1], elementRect[2], elementRect[3], elementRect[4], elementCorner, 0, 1, 1, 1)

	-- text
	Text("\255\200\200\200Middlemouse\nto move", scoreboardX, scoreboardY + 7, 15*uiScale, "co")
end

local function drawScoreboard()
	PushMatrix()
	local maxWidth = scoreboardWidth
	local maxHeight = scoreboardHeight

	-- background
	elementRect = {scoreboardX - floor((bgMargin + (scoreboardWidth/2))*uiScale), scoreboardY - floor(((scoreboardHeight/2) + bgMargin)*uiScale), scoreboardX + floor(((scoreboardWidth/2) + bgMargin)*uiScale), scoreboardY + floor((bgMargin + (scoreboardHeight/2))*uiScale)}
	UiElement(elementRect[1], elementRect[2], elementRect[3], elementRect[4], 0,1,1,1, 1,1,1,1, Spring.GetConfigFloat("ui_opacity", 0.6) + 0.2)
	if WG['guishader'] then
		WG['guishader'].InsertRect(elementRect[1], elementRect[2], elementRect[3], elementRect[4], 'cv_scoreboard')
	end

	-- title
	local title = "\255\255\255\255" .. scoreMode.name
	local titleFontSize = 18
	Color(0, 0, 0, 0.8)
	titleRect = { scoreboardX - floor((bgMargin + (scoreboardWidth/2))*uiScale), scoreboardY + floor((bgMargin + (scoreboardHeight/2))*uiScale), scoreboardX - floor(((scoreboardWidth/2) - (gl.GetTextWidth(title) * titleFontSize) - 27 + bgMargin)*uiScale), scoreboardY + floor(((scoreboardHeight/2) + 37)*uiScale) }
	RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], elementCorner, 1, 1, 0, 0)
	if WG['guishader'] then
		WG['guishader'].InsertRect(titleRect[1], titleRect[2], titleRect[3], titleRect[4], 'cv_scoreboardtitle')
	end

	font:Begin()
	font:SetTextColor(1, 1, 1, 1)
	font:SetOutlineColor(0, 0, 0, 0.4)
	font:Print(title, scoreboardX - ((bgMargin + (scoreboardWidth/2) - (titleFontSize * 0.75))*uiScale), scoreboardY + ((bgMargin + (scoreboardHeight/2) + 8)*uiScale), titleFontSize*uiScale, "on")
	font:End()

	local n = 1
	local dominator = cvDom.dominatorwa
	local dominationTime = cvDom.dominationTime
	local white = string.char("255", "255", "255", "255")
	local allyCounter = 0

	-- for all the scores with a team.
	for allyTeamID, allyScore in pairs(cvScore) do
		local allyTeamMembers = Spring.GetTeamList(allyTeamID)
		if allyTeamID ~= gaiaAllyTeamID and allyTeamMembers and (#allyTeamMembers > 0) then
			local allyFound = false
			local name = "Some Bot"
			local team = allyTeamMembers[1]

			for _, teamId in pairs(Spring.GetTeamList(allyTeamID)) do
				local playerList = Spring.GetPlayerList(teamId)
				for _, playerId in pairs(playerList) do
					local _, _, spectator = Spring.GetPlayerInfo(playerId)
					if not spectator and not allyFound then
						name = Spring.GetPlayerInfo(playerId)
						team = teamId
						allyFound = true
					end
				end -- end playerId
			end -- end teamId

			if allyFound == false then
				if Spring.GetTeamLuaAI(team) == "" then
					name = "Evil Machine"
				else
					name = Spring.GetTeamLuaAI(team)
					if not name then
						name = "AI Team"
					end
				end
				--get AI info?
			end
			local r, g, b
			if anonymousMode ~= "disabled" then
				r, g, b = anonymousTeamColor[1], anonymousTeamColor[2], anonymousTeamColor[3]
			else
				r, g, b = Spring.GetTeamColor(team)
			end
			local color = string.char("255", r * 255, g * 255, b * 255)
			Text(color .. name .. "'s team", scoreboardX - (((scoreboardWidth/2) - 10)*uiScale), scoreboardY + (((scoreboardHeight/2) - 22 - (55 * allyCounter - 1))*uiScale), 16*uiScale, "lo")
			Text(white .. "\255\200\200\200Score: \255\255\255\255" .. allyScore, scoreboardX - (((scoreboardWidth/2) - 10)*uiScale), scoreboardY + (((scoreboardHeight/2) - 42 - (55 * allyCounter - 1))*uiScale), 16*uiScale, "lo")

			local textwidth = 20 + gl.GetTextWidth(name .. "'s team") * 16
			if textwidth > maxWidth then
				maxWidth = textwidth
			end
			maxHeight = 42 + (55 * allyCounter - 1) + 13
			allyCounter = allyCounter + 1
		end -- not gaia
	end -- end allyTeamID

	if dominator and dominationTime > Spring.GetGameFrame() then
		--	Text( playerListEntry[dominator]["color"] .. "<" .. playerListEntry[dominator] .. "> will score a --Domination in " ..
		--		math.floor((dominationTime - Spring.GetGameFrame()) / 30) ..
		--		" seconds!", vsx *.5, vsy *.7, 24, "oc")
	end
	scoreboardWidth = floor(maxWidth / 2) * 2
	scoreboardHeight = floor(maxHeight / 2) * 2
	PopMatrix()
end

function widget:DrawScreen()
	local mouseoverScoreboard = false

	if showGameModeInfo then
		if infoList == nil then
			infoList = CreateList(drawGameModeInfo)
		end
		CallList(infoList)
	end

	local frame = Spring.GetGameFrame()
	if frame / 30 > startTime then
		if controlPointPromptPlayed ~= true then
			--Spring.PlaySoundFile("sounds/ui/controlpointscanbecaptured.wav", 1)
			Spring.Echo([[Control Points may now be captured!]])
			controlPointPromptPlayed = true
		end
		if scoreboardList == nil or frame % 15 == 0 then
			if scoreboardList ~= nil then
				gl.DeleteList(scoreboardList)
			end
			scoreboardList = CreateList(drawScoreboard)
		end
		CallList(scoreboardList)

		local x, y = Spring.GetMouseState()
		if elementRect and math_isInRect(x, y, elementRect[1], elementRect[2], elementRect[3], elementRect[4]) then
			if not mouseoverScoreboard then
				mouseoverScoreboard = true
				if mouseoverScoreboardList ~= nil then
					gl.DeleteList(mouseoverScoreboardList)
				end
				mouseoverScoreboardList = CreateList(drawMouseoverScoreboard)
			end
		else
			mouseoverScoreboard = false
		end

		if mouseoverScoreboard then
			CallList(mouseoverScoreboardList)
		end
	else
		Text("Capturing points begins in:", vsx - 280, vsy * .58, 18, "lo")
		local timeleft = startTime - frame / 30
		timeleft = timeleft - timeleft % 1
		Text(timeleft .. " seconds", vsx - 280, vsy * .58 - 25, 18, "lo")
	end
end

function widget:MouseMove(x, y, dx, dy)
	if draggingScoreboard then
		scoreboardRelX = scoreboardRelX + (dx / vsx)
		scoreboardRelY = scoreboardRelY + (dy / vsy)
		if scoreboardList ~= nil then
			gl.DeleteList(scoreboardList)
		end
		scoreboardList = CreateList(drawScoreboard)

		if mouseoverScoreboardList ~= nil then
			gl.DeleteList(mouseoverScoreboardList)
		end
		mouseoverScoreboardList = CreateList(drawMouseoverScoreboard)

		widget:ViewResize(Spring.GetViewGeometry())
	end
end

local function mouseEvent(x, y, button, release)
	if Spring.IsGUIHidden() then
		return false
	end
	if release and draggingScoreboard then
		draggingScoreboard = false
	end
	if not release and Spring.GetGameFrame() > 0 then
		if elementRect and (math_isInRect(x, y, elementRect[1], elementRect[2], elementRect[3], elementRect[4]) or math_isInRect(x, y, titleRect[1], titleRect[2], titleRect[3], titleRect[4])) then

			if button == 2 then
				draggingScoreboard = true
			end
			return true
		end
	end
	if showGameModeInfo then
		-- on window
		local rectX1 = ((screenX - bgMargin) * uiScale) - ((vsx * (uiScale - 1)) / 2)
		local rectY1 = ((screenY + bgMargin) * uiScale) - ((vsy * (uiScale - 1)) / 2)
		local rectX2 = ((screenX + screenWidth + bgMargin) * uiScale) - ((vsx * (uiScale - 1)) / 2)
		local rectY2 = ((screenY - screenHeight - bgMargin) * uiScale) - ((vsy * (uiScale - 1)) / 2)
		if math_isInRect(x, y, rectX1, rectY2, rectX2, rectY1) then

			-- on close button
			local brectX1 = rectX2 - ((closeButtonSize + bgMargin + bgMargin) * uiScale)
			local brectY2 = rectY1 - ((closeButtonSize + bgMargin + bgMargin) * uiScale)
			if math_isInRect(x, y, brectX1, brectY2, rectX2, rectY1) then
				if release then
					showGameModeInfo = false
				end
				return true
			end
		end
	end
end

function widget:MousePress(x, y, button)
	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end
