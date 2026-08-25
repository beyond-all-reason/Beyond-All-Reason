local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "AllyCursors",
		desc = "Shows the mouse pos of allied players",
		author = "Floris,jK,TheFatController",
		date = "31 may 2015",
		license = "GNU GPL, v2 or later",
		layer = 5,
		enabled = true,
	}
end

-- Localized functions for performance
local mathAtan2 = math.atan2

-- Localized Spring API for performance
local spGetMyTeamID = Spring.GetLocalTeamID
local spGetSpectatingState = Spring.GetSpectatingState

local cursorSize = 11
local drawNamesCursorSize = 8.5

local rotY = 0

local dlistAmount = 5 -- number of dlists generated for each player (# available opacity levels)

local packetInterval = 0.12 -- fallback for first packet; runtime interval adapts to observed packet cadence
local numMousePos = 1 --//num mouse pos in 1 packet

local showSpectatorName = false
local showPlayerName = true
local showCursorDot = true
local drawNamesScaling = true
local drawNamesFade = true

local fontSizePlayer = 18
local fontOpacityPlayer = 0.7
local fontSizeSpec = 13
local fontOpacitySpec = 0.5

local NameFadeStartDistance = 4000
local NameFadeEndDistance = 6500
local idleCursorTime = 25 -- fade time cursor (specs only)

local addLights = true
local lightRadiusMult = 0.5
local lightStrengthMult = 0.85
local lightSelfShadowing = false
local showOwnCursor = false -- for debugging purposes

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spGetGroundHeight = Spring.GetGroundHeight
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetTeamColor = Spring.GetTeamColor
local spIsSphereInView = Spring.IsSphereInView
local spGetCameraPosition = Spring.GetCameraPosition
local spIsGUIHidden = Spring.IsGUIHidden
local spAreTeamsAllied = Spring.AreTeamsAllied

local glCreateList = gl.CreateList
local glDeleteList = gl.DeleteList
local glCallList = gl.CallList
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glRotate = gl.Rotate
local glScale = gl.Scale
local glColor = gl.Color
local glTexture = gl.Texture
local glBeginEnd = gl.BeginEnd
local glTexCoord = gl.TexCoord
local glVertex = gl.Vertex
local glDepthTest = gl.DepthTest
local glBlending = gl.Blending
local glPolygonOffset = gl.PolygonOffset

local spGetCameraDirection = Spring.GetCameraDirection
local math_deg = math.deg

local abs = math.abs
local floor = math.floor
local min = math.min
local max = math.max
local diag = math.diag
local clock = os.clock
local next = next
local TIMESTAMP_IDX = (numMousePos + 1) * 2 + 1
local CLICK_IDX = (numMousePos + 1) * 2 + 2
local TEAMID_IDX = (numMousePos + 1) * 2 + 3
local PACKET_INTERVAL_IDX = (numMousePos + 1) * 2 + 4
local PREV_X_KEY = "prevX"
local PREV_Z_KEY = "prevZ"
local INACTIVE_CURSOR_POS = -1

local alliedCursorsPos = {}
local prevCursorPos = {}
local alliedCursorsTime = {} -- for API purpose
local usedCursorSize = cursorSize
local allycursorDrawList = {}
local playerTeamIDs = {}
local myPlayerID = Spring.GetLocalPlayerID()
local _, fullview = spGetSpectatingState()
local myTeamID = spGetMyTeamID()
local isReplay = Spring.IsReplay()

local allyCursor = ":n:LuaUI/Images/allycursor.dds"
local cursors = {}
local teamColors = {}
local specList = {}
local notIdle = {}

local teamColorKeys = {}
local teamList = Spring.GetTeamList()
for i = 1, #teamList do
	local r, g, b = spGetTeamColor(teamList[i])
	teamColorKeys[teamList[i]] = { r, g, b }
end

local font, functionID
local lastCursorPos = {}
local visibleCursor = {} -- playerID -> whether the current viewer may see that cursor
local viewerSpectating = false
local guiHidden = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function deleteDlists()
	for _, dlists in pairs(allycursorDrawList) do
		for _, dlist in pairs(dlists) do
			glDeleteList(dlist)
		end
	end
	allycursorDrawList = {}
end

local function updateSpecList(init)
	specList = {}
	playerTeamIDs = {}
	local t = Spring.GetPlayerList()
	for _, playerID in ipairs(t) do
		local _, _, isSpec, teamID = spGetPlayerInfo(playerID, false)
		specList[playerID] = isSpec
		playerTeamIDs[playerID] = teamID
	end
end

local function sanitizeCoord(value, fallback)
	if type(value) == "number" then
		return value
	end
	if type(fallback) == "number" then
		return fallback
	end
	return nil
end

local function GetViewerState()
	local spectating, currentFullview = spGetSpectatingState()
	return spectating == true, currentFullview == true, spGetMyTeamID()
end

local function IsCursorVisibleToViewer(playerID, spectating, currentFullview, viewedTeamID)
	local teamID = playerTeamIDs[playerID]
	if not teamID or not viewedTeamID then
		return false
	end
	if currentFullview then
		return true
	end
	if spectating then
		return teamID == viewedTeamID or spAreTeamsAllied(viewedTeamID, teamID)
	end
	return spAreTeamsAllied(viewedTeamID, teamID)
end

-- caches per-player visibility so the draw pass doesn't need Spring.AreTeamsAllied every frame
local function RebuildVisibility()
	local spectating, currentFullview, viewedTeamID = GetViewerState()
	viewerSpectating = spectating
	fullview = currentFullview
	myTeamID = viewedTeamID
	local vis = {}
	for playerID in pairs(playerTeamIDs) do
		vis[playerID] = IsCursorVisibleToViewer(playerID, spectating, currentFullview, viewedTeamID)
	end
	visibleCursor = vis
end

local function MouseCursorEvent(playerID, x1, z1, x2, z2, click)
	if not showOwnCursor and not isReplay and myPlayerID == playerID then
		return true
	end

	local now = clock()

	local acp = alliedCursorsPos[playerID]
	if acp then
		x1 = sanitizeCoord(x1, acp[1])
		z1 = sanitizeCoord(z1, acp[2])
		x2 = sanitizeCoord(x2, x1)
		z2 = sanitizeCoord(z2, z1)
		if x1 == nil or z1 == nil then
			return
		end

		acp[PREV_X_KEY] = acp[1]
		acp[PREV_Z_KEY] = acp[2]
		acp[1] = x1
		acp[2] = z1
		acp[3] = x2
		acp[4] = z2
		local observedInterval = min(max(now - (acp[TIMESTAMP_IDX] or now), 0.05), 1)
		local prevInterval = acp[PACKET_INTERVAL_IDX] or observedInterval
		acp[PACKET_INTERVAL_IDX] = min(max(prevInterval * 0.7 + observedInterval * 0.3, 0.05), 1)
		acp[TIMESTAMP_IDX] = now
		acp[CLICK_IDX] = click
	else
		x1 = sanitizeCoord(x1, x2)
		z1 = sanitizeCoord(z1, z2)
		x2 = sanitizeCoord(x2, x1)
		z2 = sanitizeCoord(z2, z1)
		if x1 == nil or z1 == nil then
			return
		end

		acp = { x1, z1, x2, z2, x1, z1 }
		acp[PREV_X_KEY] = x1
		acp[PREV_Z_KEY] = z1
		acp[TIMESTAMP_IDX] = now
		acp[PACKET_INTERVAL_IDX] = packetInterval
		acp[CLICK_IDX] = click
		acp[TEAMID_IDX] = playerTeamIDs[playerID] or select(4, spGetPlayerInfo(playerID, false))
		alliedCursorsPos[playerID] = acp
	end

	local prev = prevCursorPos[playerID]
	if not prev or acp[1] ~= prev[1] or acp[2] ~= prev[2] then
		alliedCursorsTime[playerID] = now
		if not prev then
			prev = {}
			prevCursorPos[playerID] = prev
		end
		prev[1] = acp[1]
		prev[2] = acp[2]
	end
end

local function DrawGroundquad(wx, wy, wz, size)
	glTexCoord(0, 0)
	glVertex(wx - size, wy + size, wz - size)
	glTexCoord(0, 1)
	glVertex(wx - size, wy + size, wz + size)
	glTexCoord(1, 1)
	glVertex(wx + size, wy + size, wz + size)
	glTexCoord(1, 0)
	glVertex(wx + size, wy + size, wz - size)
end

local function SetTeamColor(teamID, playerID, a)
	local color = teamColors[playerID]
	if color then
		glColor(color[1], color[2], color[3], color[4] * a)
		return
	end

	--make color
	local r, g, b = spGetTeamColor(teamID)
	if specList[playerID] then
		color = { 1, 1, 1, 0.6 }
	elseif r and g and b then
		color = { r, g, b, 0.75 }
	end
	teamColors[playerID] = color
	glColor(color)
end

function widget:ViewResize()
	font = WG.fonts.getFont(1, 1.5)
	deleteDlists()
end

function widget:MouseCursorEvent(playerID, x1, z1, x2, z2, click)
	MouseCursorEvent(playerID, x1, z1, x2, z2, click)
end

function widget:Initialize()
	widget:ViewResize()

	if showPlayerName then
		usedCursorSize = drawNamesCursorSize
	end
	updateSpecList(true)
	RebuildVisibility()

	WG.allycursors = {}
	WG.allycursors.setLights = function(value)
		addLights = value
		deleteDlists()
	end
	WG.allycursors.getLights = function()
		return addLights
	end
	WG.allycursors.setLightStrength = function(value)
		lightStrengthMult = value
	end
	WG.allycursors.getLightStrength = function()
		return lightStrengthMult
	end
	WG.allycursors.setLightRadius = function(value)
		lightRadiusMult = value
	end
	WG.allycursors.setLightSelfShadowing = function(value)
		lightSelfShadowing = value
	end
	WG.allycursors.getLightRadius = function()
		return lightRadiusMult
	end

	WG.allycursors.getLightSelfShadowing = function()
		return lightSelfShadowing
	end
	WG.allycursors.setCursorDot = function(value)
		showCursorDot = value
		deleteDlists()
	end
	WG.allycursors.getCursorDot = function()
		return showCursorDot
	end
	WG.allycursors.setPlayerNames = function(value)
		showPlayerName = value
		deleteDlists()
	end
	WG.allycursors.getPlayerNames = function()
		return showPlayerName
	end
	WG.allycursors.setSpectatorNames = function(value)
		showSpectatorName = value
		deleteDlists()
	end
	WG.allycursors.getSpectatorNames = function()
		return showSpectatorName
	end
	WG.allycursors.getCursors = function()
		return cursors, notIdle
	end
	WG.allycursors.getCursor = function(playerID)
		if not playerID then
			return nil
		end
		local spectating, currentFullview, viewedTeamID = GetViewerState()
		if not IsCursorVisibleToViewer(playerID, spectating, currentFullview, viewedTeamID) then
			return nil, nil
		end
		return cursors[playerID], notIdle[playerID]
	end
	WG.allycursors.isCursorVisible = function(playerID)
		if not playerID then
			return false
		end
		local spectating, currentFullview, viewedTeamID = GetViewerState()
		return IsCursorVisibleToViewer(playerID, spectating, currentFullview, viewedTeamID)
	end

	local now = clock() - (idleCursorTime * 0.95)
	local pList = Spring.GetPlayerList()
	for _, playerID in ipairs(pList) do
		alliedCursorsTime[playerID] = now
	end
end

function widget:Shutdown()
	deleteDlists()
	WG.allycursors = nil
end

function widget:PlayerChanged(playerID)
	local _, _, isSpec, teamID = spGetPlayerInfo(playerID, false)
	specList[playerID] = isSpec
	playerTeamIDs[playerID] = teamID
	local r, g, b = spGetTeamColor(teamID)
	if isSpec then
		teamColors[playerID] = { 1, 1, 1, 0.6 }
		if cursors[playerID] then
			if not showSpectatorName then
				cursors[playerID][7] = 0
			end
			cursors[playerID][8] = true
		end
	elseif r and g and b then
		teamColors[playerID] = { r, g, b, 0.75 }
	end
	if allycursorDrawList[playerID] ~= nil then
		for _, dlist in pairs(allycursorDrawList[playerID]) do
			glDeleteList(dlist)
		end
		allycursorDrawList[playerID] = nil
	end
	-- update speclist when player becomes spectator
	--if isSpec and not specList[playerID] then
	updateSpecList()
	--end
	RebuildVisibility()
end

function widget:PlayerAdded(playerID)
	widget:PlayerChanged(playerID)
end

function widget:PlayerRemoved(playerID)
	specList[playerID] = nil
	playerTeamIDs[playerID] = nil
	notIdle[playerID] = nil
	cursors[playerID] = nil
	lastCursorPos[playerID] = nil
	prevCursorPos[playerID] = nil
	alliedCursorsPos[playerID] = nil
	if allycursorDrawList[playerID] then
		for _, dlist in pairs(allycursorDrawList[playerID]) do
			glDeleteList(dlist)
		end
		allycursorDrawList[playerID] = nil
	end
	updateSpecList()
	RebuildVisibility()
end

local function createCursorDrawList(playerID, opacityMultiplier)
	local name, _, spec, teamID = spGetPlayerInfo(playerID, false)
	name = ((WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(playerID)) or name
	local r, g, b = spGetTeamColor(teamID)
	local wx, wy, wz = 0, 0, 0
	local quadSize = usedCursorSize
	if spec then
		quadSize = usedCursorSize * 0.77
	end

	SetTeamColor(teamID, playerID, 1)

	-- draw player cursor
	if not spec and showCursorDot and (not addLights or not WG.lightsgl4) then
		glTexture(allyCursor)
		glBeginEnd(GL.QUADS, DrawGroundquad, wx, wy, wz, quadSize)
		glTexture(false)
	end

	if spec or showPlayerName then
		-- draw nickname
		if not spec or showSpectatorName then
			glPushMatrix()
			glTranslate(wx, wy, wz)
			glRotate(-90, 1, 0, 0)

			font:Begin()
			if spec then
				font:SetTextColor(1, 1, 1, fontOpacitySpec * opacityMultiplier)
				font:Print(name, 0, 0, fontSizeSpec, "cn")
			else
				local verticalOffset = usedCursorSize + 8
				local horizontalOffset = usedCursorSize + 1
				-- text shadow
				font:SetTextColor(0, 0, 0, fontOpacityPlayer * 0.62 * opacityMultiplier)
				font:Print(
					name,
					horizontalOffset - (fontSizePlayer / 50),
					verticalOffset - (fontSizePlayer / 42),
					fontSizePlayer,
					"n"
				)
				font:Print(
					name,
					horizontalOffset + (fontSizePlayer / 50),
					verticalOffset - (fontSizePlayer / 42),
					fontSizePlayer,
					"n"
				)
				-- text
				font:SetTextColor(r, g, b, fontOpacityPlayer * opacityMultiplier)
				font:Print(name, horizontalOffset, verticalOffset, fontSizePlayer, "n")
			end
			font:End()
			glPopMatrix()
		end
	end
end

local function getCameraRotationY()
	local x, _, z = spGetCameraDirection()
	return math_deg(mathAtan2(x, -z))
end

local function GetCursorOpacityMultiplier(wx, wy, wz, camX, camY, camZ, opacity)
	local camDistance = diag(camX - wx, camY - wy, camZ - wz)

	local opacityMultiplier = 1
	if drawNamesFade and camDistance > NameFadeStartDistance then
		opacityMultiplier = (1 - (camDistance - NameFadeStartDistance) / (NameFadeEndDistance - NameFadeStartDistance))
		if opacityMultiplier > 1 then
			opacityMultiplier = 1
		end
	end

	if opacity >= 1 then
		opacityMultiplier = floor(opacityMultiplier * dlistAmount) / dlistAmount
	else
		-- if (spec and) fading out due to idling
		opacityMultiplier = floor(opacityMultiplier * (opacity * dlistAmount)) / dlistAmount
	end
	return opacityMultiplier, 0.83 + camDistance / 5000
end

local function PrepareCursorDrawList(playerID, cursor)
	local wx, wy, wz = cursor[1], cursor[2], cursor[3]
	if not spIsSphereInView(wx, wy, wz, usedCursorSize) then
		cursor[9] = false
		return
	end

	local opacityMultiplier, drawScale =
		GetCursorOpacityMultiplier(wx, wy, wz, cursor[4], cursor[5], cursor[6], cursor[7])
	cursor[9] = opacityMultiplier > 0.11
	cursor[10] = opacityMultiplier
	cursor[11] = drawScale
	if not cursor[9] then
		return
	end

	if allycursorDrawList[playerID] == nil then
		allycursorDrawList[playerID] = {}
	end
	if allycursorDrawList[playerID][opacityMultiplier] == nil then
		allycursorDrawList[playerID][opacityMultiplier] =
			glCreateList(createCursorDrawList, playerID, opacityMultiplier)
	end
end

local function DrawCursor(playerID, cursor)
	local dlists = allycursorDrawList[playerID]
	local drawList = dlists and dlists[cursor[10]]
	if not drawList then
		return
	end

	glPushMatrix()
	glTranslate(cursor[1], cursor[2], cursor[3])
	glRotate(-rotY, 0, 1, 0)
	if drawNamesScaling then
		glScale(cursor[11], 0, cursor[11])
	end
	glCallList(drawList)
	glPopMatrix()
end

local sec = 0
function widget:Update(dt)
	guiHidden = spIsGUIHidden()
	if guiHidden then
		return
	end

	sec = sec + dt
	if sec > 1.5 then
		sec = 0

		-- check if team colors have changed
		for i = 1, #teamList do
			local teamID = teamList[i]
			local r, g, b = spGetTeamColor(teamID)
			local key = teamColorKeys[teamID]
			if key[1] ~= r or key[2] ~= g or key[3] ~= b then
				key[1], key[2], key[3] = r, g, b
				local players = Spring.GetPlayerList(teamID)
				for _, playerID in ipairs(players) do
					widget:PlayerChanged(playerID)
				end
			end
		end
	end

	if next(alliedCursorsPos) == nil then
		return
	end

	local spectating, currentFullview, viewedTeamID = GetViewerState()
	if spectating ~= viewerSpectating or currentFullview ~= fullview or viewedTeamID ~= myTeamID then
		RebuildVisibility()
	end

	local now = clock()
	local camX, camY, camZ = spGetCameraPosition()
	rotY = getCameraRotationY()
	for playerID, data in pairs(alliedCursorsPos) do
		local isSpec = specList[playerID]
		if isSpec and not showSpectatorName then
			-- never drawn: skip interpolation/idle tracking entirely
			if cursors[playerID] then
				notIdle[playerID] = nil
				cursors[playerID] = nil
			end
		else
			-- coords in data are guaranteed numeric by MouseCursorEvent's sanitizing
			local wx, wz = data[1], data[2]
			local lastUpdatedDiff = now - data[TIMESTAMP_IDX]
			local interpInterval = data[PACKET_INTERVAL_IDX]
			if lastUpdatedDiff < interpInterval then
				local blendWindow = interpInterval
				if blendWindow < 0.08 then
					blendWindow = 0.08
				end
				local mix = (lastUpdatedDiff + 0.02) / blendWindow
				if mix > 1 then
					mix = 1
				end
				local mix2 = mix * mix
				local w0 = 2 * mix2 * mix - 3 * mix2 + 1 -- smoothstep weight; the pair sums to 1
				local w1 = 1 - w0
				wx = data[PREV_X_KEY] * w0 + wx * w1
				wz = data[PREV_Z_KEY] * w0 + wz * w1
			end

			if notIdle[playerID] then
				local opacity = 1
				if isSpec then
					opacity = 1 - ((now - alliedCursorsTime[playerID]) / idleCursorTime)
					if opacity > 1 then
						opacity = 1
					end
				end
				if opacity > 0.1 then
					local cursor = cursors[playerID]
					if not cursor then
						cursor = { wx, spGetGroundHeight(wx, wz), wz, camX, camY, camZ, opacity, isSpec }
						cursor[12] = wx
						cursor[13] = wz
						cursors[playerID] = cursor
					else
						if wx ~= cursor[12] or wz ~= cursor[13] then
							cursor[2] = spGetGroundHeight(wx, wz)
							cursor[12] = wx
							cursor[13] = wz
						end
						cursor[1] = wx
						cursor[3] = wz
						cursor[4] = camX
						cursor[5] = camY
						cursor[6] = camZ
						cursor[7] = opacity
						cursor[8] = isSpec
					end
					if visibleCursor[playerID] then
						PrepareCursorDrawList(playerID, cursor)
					else
						cursor[9] = false
					end
				else
					notIdle[playerID] = nil
					cursors[playerID] = nil
				end
			else
				-- mark a player as notIdle as soon as they move (and keep them always set notIdle after this)
				local prevPos = lastCursorPos[playerID]
				if prevPos and prevPos[1] >= 0 and (abs(prevPos[1] - wx) >= 0.25 or abs(prevPos[2] - wz) >= 0.25) then
					-- abs is needed because of floating point used in interpolation
					notIdle[playerID] = true
					prevPos[1] = INACTIVE_CURSOR_POS
					prevPos[2] = INACTIVE_CURSOR_POS
				elseif prevPos then
					prevPos[1] = wx
					prevPos[2] = wz
				else
					lastCursorPos[playerID] = { wx, wz }
				end
			end
		end
	end
end

function widget:DrawWorldPreUnit()
	-- visibility was already filtered into cursor[9] during Update (via visibleCursor + in-view check)
	if guiHidden or next(cursors) == nil then
		return
	end

	glDepthTest(GL.ALWAYS)
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	glPolygonOffset(-7, -10)

	for playerID, cursor in pairs(cursors) do
		if cursor[9] then
			DrawCursor(playerID, cursor)
		end
	end

	glPolygonOffset(false)
	glDepthTest(false)
end

function widget:GetConfigData()
	return {
		addLights = addLights,
		lightRadiusMult = lightRadiusMult,
		lightStrengthMult = lightStrengthMult,
		showCursorDot = showCursorDot,
		showSpectatorName = showSpectatorName,
		showPlayerName = showPlayerName,
	}
end

function widget:SetConfigData(data)
	if data.showSpectatorName ~= nil then
		showSpectatorName = data.showSpectatorName
	end
	if data.showPlayerName ~= nil then
		showPlayerName = data.showPlayerName
	end
	if showPlayerName then
		usedCursorSize = drawNamesCursorSize
	end
	if data.addLights ~= nil then
		addLights = data.addLights
		lightRadiusMult = data.lightRadiusMult
		lightStrengthMult = data.lightStrengthMult
		if data.showCursorDot ~= nil then
			showCursorDot = data.showCursorDot
		end
	end
end
