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
local spGetMyTeamID = Spring.GetMyTeamID
local spGetSpectatingState = Spring.GetSpectatingState

-- TODO: hide (enemy) cursor light when not specfullview

local cursorSize = 11
local drawNamesCursorSize = 8.5

local rotY = 0

local dlistAmount = 5        -- number of dlists generated for each player (# available opacity levels)

local packetInterval = 0.33
local numMousePos = 2 --//num mouse pos in 1 packet

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
local idleCursorTime = 25        -- fade time cursor (specs only)

local addLights = true
local lightRadiusMult = 0.5
local lightStrengthMult = 0.85
local lightSelfShadowing = false

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

local abs = math.abs
local floor = math.floor
local min = math.min
local diag = math.diag
local clock = os.clock
local alliedCursorsPos = {}
local prevCursorPos = {}
local alliedCursorsTime = {}        -- for API purpose
local usedCursorSize = cursorSize
local allycursorDrawList = {}
local myPlayerID = Spring.GetMyPlayerID()
local _, fullview = spGetSpectatingState()
local myTeamID = spGetMyTeamID()
local isReplay = Spring.IsReplay()

local allyCursor = ":n:LuaUI/Images/allycursor.dds"
local cursors = {}
local teamColors = {}
local specList = {}
local notIdle = {}
local playerPos = {}

local teamColorKeys = {}
local teams = Spring.GetTeamList()
for i = 1, #teams do
	local r, g, b = spGetTeamColor(teams[i])
	teamColorKeys[teams[i]] = r..'_'..g..'_'..b
end
teams = nil

local font, functionID, wx_old, wz_old

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
	local t = Spring.GetPlayerList()
	for _, playerID in ipairs(t) do
		specList[playerID] = select(3, spGetPlayerInfo(playerID, false))
	end
end

local function CubicInterpolate2(x0, x1, mix)
	local mix2 = mix * mix
	local mix3 = mix2 * mix
	return x0 * (2 * mix3 - 3 * mix2 + 1) + x1 * (3 * mix2 - 2 * mix3)
end

local function MouseCursorEvent(playerID, x, z, click)	-- dont local it
	if not isReplay and myPlayerID == playerID then
		return true
	end
	local playerPosList = playerPos[playerID] or {}
	playerPosList[#playerPosList + 1] = { x = x, z = z, click = click }
	playerPos[playerID] = playerPosList
	if #playerPosList < numMousePos then
		return
	end
	playerPos[playerID] = {}

	if alliedCursorsPos[playerID] then
		local acp = alliedCursorsPos[playerID]

		acp[(numMousePos) * 2 + 1] = acp[1]
		acp[(numMousePos) * 2 + 2] = acp[2]

		for i = 0, numMousePos - 1 do
			acp[i * 2 + 1] = playerPosList[i + 1].x
			acp[i * 2 + 2] = playerPosList[i + 1].z
		end

		acp[(numMousePos + 1) * 2 + 1] = clock()
		acp[(numMousePos + 1) * 2 + 2] = playerPosList[#playerPosList].click
	else
		local acp = {}
		alliedCursorsPos[playerID] = acp

		for i = 0, numMousePos - 1 do
			acp[i * 2 + 1] = playerPosList[i + 1].x
			acp[i * 2 + 2] = playerPosList[i + 1].z
		end

		acp[(numMousePos) * 2 + 1] = playerPosList[(numMousePos - 2) * 2 + 1].x
		acp[(numMousePos) * 2 + 2] = playerPosList[(numMousePos - 2) * 2 + 1].z

		acp[(numMousePos + 1) * 2 + 1] = clock()
		acp[(numMousePos + 1) * 2 + 2] = playerPosList[#playerPosList].click
		acp[(numMousePos + 1) * 2 + 3] = select(4, spGetPlayerInfo(playerID, false))
	end

	-- check if there has been changes
	if prevCursorPos[playerID] == nil or alliedCursorsPos[playerID][1] ~= prevCursorPos[playerID][1] or alliedCursorsPos[playerID][2] ~= prevCursorPos[playerID][2] then
		alliedCursorsTime[playerID] = clock()
		if prevCursorPos[playerID] == nil then
			prevCursorPos[playerID] = {}
		end
		prevCursorPos[playerID][1] = alliedCursorsPos[playerID][1]
		prevCursorPos[playerID][2] = alliedCursorsPos[playerID][2]
	end
end

local function DrawGroundquad(wx, wy, wz, size)
	gl.TexCoord(0, 0)
	gl.Vertex(wx - size, wy + size, wz - size)
	gl.TexCoord(0, 1)
	gl.Vertex(wx - size, wy + size, wz + size)
	gl.TexCoord(1, 1)
	gl.Vertex(wx + size, wy + size, wz + size)
	gl.TexCoord(1, 0)
	gl.Vertex(wx + size, wy + size, wz - size)
end

local function SetTeamColor(teamID, playerID, a)
	local color = teamColors[playerID]
	if color then
		gl.Color(color[1], color[2], color[3], color[4] * a)
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
	gl.Color(color)
end


function widget:ViewResize()
	font = WG['fonts'].getFont(1, 1.5)
	deleteDlists()
end

function widget:Initialize()
	widget:ViewResize()
	widgetHandler:RegisterGlobal('MouseCursorEvent', MouseCursorEvent)

	if showPlayerName then
		usedCursorSize = drawNamesCursorSize
	end
	updateSpecList(true)

	WG['allycursors'] = {}
	WG['allycursors'].setLights = function(value)
		addLights = value
		deleteDlists()
	end
	WG['allycursors'].getLights = function()
		return addLights
	end
	WG['allycursors'].setLightStrength = function(value)
		lightStrengthMult = value
	end
	WG['allycursors'].getLightStrength = function()
		return lightStrengthMult
	end
	WG['allycursors'].setLightRadius = function(value)
		lightRadiusMult = value
	end
	WG['allycursors'].setLightSelfShadowing = function(value)
		lightSelfShadowing = value
	end
	WG['allycursors'].getLightRadius = function()
		return lightRadiusMult
	end

	WG['allycursors'].getLightSelfShadowing = function()
		return lightSelfShadowing
	end
	WG['allycursors'].setCursorDot = function(value)
		showCursorDot = value
		deleteDlists()
	end
	WG['allycursors'].getCursorDot = function()
		return showCursorDot
	end
	WG['allycursors'].setPlayerNames = function(value)
		showPlayerName = value
		deleteDlists()
	end
	WG['allycursors'].getPlayerNames = function()
		return showPlayerName
	end
	WG['allycursors'].setSpectatorNames = function(value)
		showSpectatorName = value
		deleteDlists()
	end
	WG['allycursors'].getSpectatorNames = function()
		return showSpectatorName
	end
	WG['allycursors'].getCursors = function()
		return cursors, notIdle
	end

	local now = clock() - (idleCursorTime * 0.95)
	local pList = Spring.GetPlayerList()
	for _, playerID in ipairs(pList) do
		alliedCursorsTime[playerID] = now
	end
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal('MouseCursorEvent')
	deleteDlists()
	WG['allycursors'] = nil
end

function widget:PlayerChanged(playerID)
	myTeamID = spGetMyTeamID()
	local _, _, isSpec, teamID = spGetPlayerInfo(playerID, false)
	specList[playerID] = isSpec
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
			gl.DeleteList(dlist)
		end
		allycursorDrawList[playerID] = nil
	end
	-- update speclist when player becomes spectator
	--if isSpec and not specList[playerID] then
		updateSpecList()
	--end
end

function widget:PlayerAdded(playerID)
	widget:PlayerChanged(playerID)
end

function widget:PlayerRemoved(playerID)
	specList[playerID] = nil
	notIdle[playerID] = nil
	cursors[playerID] = nil
	prevCursorPos[playerID] = nil
	alliedCursorsPos[playerID] = nil
	if allycursorDrawList[playerID] then
		for _, dlist in pairs(allycursorDrawList[playerID]) do
			gl.DeleteList(dlist)
		end
		allycursorDrawList[playerID] = nil
	end
	updateSpecList()
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
	if not spec and showCursorDot and (not addLights or not WG['lightsgl4']) then
		gl.Texture(allyCursor)
		gl.BeginEnd(GL.QUADS, DrawGroundquad, wx, wy, wz, quadSize)
		gl.Texture(false)
	end

	if spec or showPlayerName then

		-- draw nickname
		if not spec or showSpectatorName then
			gl.PushMatrix()
			gl.Translate(wx, wy, wz)
			gl.Rotate(-90, 1, 0, 0)

			font:Begin()
			if spec then
				font:SetTextColor(1, 1, 1, fontOpacitySpec * opacityMultiplier)
				font:Print(name, 0, 0, fontSizeSpec, "cn")
			else
				local verticalOffset = usedCursorSize + 8
				local horizontalOffset = usedCursorSize + 1
				-- text shadow
				font:SetTextColor(0, 0, 0, fontOpacityPlayer * 0.62 * opacityMultiplier)
				font:Print(name, horizontalOffset - (fontSizePlayer / 50), verticalOffset - (fontSizePlayer / 42), fontSizePlayer, "n")
				font:Print(name, horizontalOffset + (fontSizePlayer / 50), verticalOffset - (fontSizePlayer / 42), fontSizePlayer, "n")
				-- text
				font:SetTextColor(r, g, b, fontOpacityPlayer * opacityMultiplier)
				font:Print(name, horizontalOffset, verticalOffset, fontSizePlayer, "n")
			end
			font:End()
			gl.PopMatrix()
		end
	end
end

local function getCameraRotationY()
	local x, y, z = Spring.GetCameraDirection()

	local length = math.sqrt(x*x + y*y + z*z)

	-- We are only concerned with rotY
	x = x/length;
	z = z/length;

	return math.deg(mathAtan2(x, -z))

	-- General implementation
	--
	-- x = x/length;
	-- y = y/length;
	-- z = z/length;

	-- return math.acos(y), mathAtan2(x, -z), 0;
end

local function DrawCursor(playerID, wx, wy, wz, camX, camY, camZ, opacity)
	if not spIsSphereInView(wx, wy, wz, usedCursorSize) then
		return
	end

	--calc scale
	local camDistance = diag(camX - wx, camY - wy, camZ - wz)
	local glScale = 0.83 + camDistance / 5000

	-- calc opacity
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

	if opacityMultiplier > 0.11 then
		if allycursorDrawList[playerID] == nil then
			allycursorDrawList[playerID] = {}
		end
		if allycursorDrawList[playerID][opacityMultiplier] == nil then
			allycursorDrawList[playerID][opacityMultiplier] = glCreateList(createCursorDrawList, playerID, opacityMultiplier)
		end

		gl.PushMatrix()
		gl.Translate(wx, wy, wz)
		gl.Rotate(-rotY, 0, 1, 0)
		if drawNamesScaling then
			gl.Scale(glScale, 0, glScale)
		end
		glCallList(allycursorDrawList[playerID][opacityMultiplier])
		if drawNamesScaling then
			gl.Scale(-glScale, 0, -glScale)
		end
		gl.PopMatrix()
	end
end


local sec = 0
function widget:Update(dt)
	if spIsGUIHidden() then return end

	sec = sec + dt
	if sec > 1.5 then
		sec = 0

		-- check if team colors have changed
		local teams = Spring.GetTeamList()
		for i = 1, #teams do
			local r, g, b = spGetTeamColor(teams[i])
			if teamColorKeys[teams[i]] ~= r..'_'..g..'_'..b then
				teamColorKeys[teams[i]] = r..'_'..g..'_'..b
				local players = Spring.GetPlayerList(teams[i])
				for _, playerID in ipairs(players) do
					widget:PlayerChanged(playerID)
				end
			end
		end
	end

	local now = clock()
	local camX, camY, camZ = spGetCameraPosition()
	rotY = getCameraRotationY()
	for playerID, data in pairs(alliedCursorsPos) do
		local wx, wz = data[1], data[2]
		local lastUpdatedDiff = now - data[#data - 2] + 0.025
		if lastUpdatedDiff < packetInterval then
			local scale = (1 - (lastUpdatedDiff / packetInterval)) * numMousePos
			local iscale = min(floor(scale), numMousePos - 1)
			local fscale = scale - iscale
			wx = CubicInterpolate2(data[iscale * 2 + 1], data[(iscale + 1) * 2 + 1], fscale)
			wz = CubicInterpolate2(data[iscale * 2 + 2], data[(iscale + 1) * 2 + 2], fscale)
		end

		if notIdle[playerID] then
			local opacity = 1
			if specList[playerID] and showSpectatorName then
				opacity = 1 - ((now - alliedCursorsTime[playerID]) / idleCursorTime)
				if opacity > 1 then
					opacity = 1
				end
			end
			if specList[playerID] and not showSpectatorName then
				opacity = 0	-- doing this cause somehow setting cursors[playerID][8]=true doesnt remove the light but setting cursors[playerID]=nil does
			end
			if opacity > 0.1 then
				if not cursors[playerID] then
					cursors[playerID] = { wx, spGetGroundHeight(wx, wz), wz, camX, camY, camZ, opacity, specList[playerID]}
				else
					cursors[playerID][1] = wx
					cursors[playerID][2] = spGetGroundHeight(wx, wz)
					cursors[playerID][3] = wz
					cursors[playerID][4] = camX
					cursors[playerID][5] = camY
					cursors[playerID][6] = camZ
					cursors[playerID][7] = opacity
					cursors[playerID][8] = specList[playerID]
				end
			else
				notIdle[playerID] = nil
				cursors[playerID] = nil
			end
		else
			-- mark a player as notIdle as soon as they move (and keep them always set notIdle after this)
			if wx and wz and wz_old and wz_old and (abs(wx_old - wx) >= 1 or abs(wz_old - wz) >= 1) then
				-- abs is needed because of floating point used in interpolation
				notIdle[playerID] = true
				wx_old = nil
				wz_old = nil
			else
				wx_old = wx
				wz_old = wz
			end
			if specList[playerID] and not showSpectatorName then
				cursors[playerID] = nil
			end
		end
	end
end

function widget:DrawWorldPreUnit()
	if spIsGUIHidden() then
		return
	end

	fullview = select(2, spGetSpectatingState())

	gl.DepthTest(GL.ALWAYS)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.PolygonOffset(-7, -10)

	for playerID, cursor in pairs(cursors) do
		if notIdle[playerID] then
			if fullview or spAreTeamsAllied(myTeamID, spGetPlayerInfo(playerID) and select(4, spGetPlayerInfo(playerID))) then
				DrawCursor(playerID, cursor[1], cursor[2], cursor[3], cursor[4], cursor[5], cursor[6], cursor[7])
			end
		end
	end

	gl.PolygonOffset(false)
	gl.DepthTest(false)
end

function widget:GetConfigData()
	return {
		addLights = addLights,
		lightRadiusMult = lightRadiusMult,
		lightStrengthMult = lightStrengthMult,
		showCursorDot = showCursorDot,
		showSpectatorName = showSpectatorName,
		showPlayerName = showPlayerName
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
