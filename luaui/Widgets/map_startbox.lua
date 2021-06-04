function widget:GetInfo()
	return {
		name = "Start Boxes",
		desc = "Displays Start Boxes and Start Points",
		author = "trepan, jK",
		date = "2007-2009",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true  --  loaded by default?
	}
end

if Game.startPosType ~= 2 then
	return false
end

if Spring.GetGameFrame() > 1 then
	widgetHandler:RemoveWidget()
end

-- enable simple version by default though
local drawGroundQuads = true

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local vsx, vsy = Spring.GetViewGeometry()
local fontfileScale = 0.5 + (vsx * vsy / 5700000)
local fontfileSize = 50
local fontfileOutlineSize = 8
local fontfileOutlineStrength = 1.65
local fontfileOutlineStrength2 = 10
local font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
local shadowFont = gl.LoadFont(fontfile, fontfileSize * fontfileScale, 35 * fontfileScale, 1.5)
local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local font2 = gl.LoadFont(fontfile2, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength2)

local useThickLeterring = false
local heightOffset = 50
local fontSize = 18
local fontShadow = true        -- only shows if font has a white outline
local shadowOpacity = 0.35

local infotext = Spring.I18N('ui.startSpot.anywhere')
local infotextBoxes = Spring.I18N('ui.startSpot.startbox')
local infotextFontsize = 13

local comnameList = {}
local drawShadow = fontShadow
local usedFontSize = fontSize

local widgetScale = (1 + (vsx * vsy / 5500000))

local msx = Game.mapSizeX
local msz = Game.mapSizeZ

local xformList = 0
local coneList = 0
local startboxDListStencil = 0
local startboxDListColor = 0

local isSpec = Spring.GetSpectatingState() or Spring.IsReplay()
local myTeamID = Spring.GetMyTeamID()

local placeVoiceNotifTimer = false
local playedChooseStartLoc = false
local amPlaced = false

local gaiaTeamID
local gaiaAllyTeamID

local startTimer = Spring.GetTimer()

local texName = LUAUI_DIRNAME .. 'Images/highlight_strip.png'
local texScale = 512

local infotextList, chobbyInterface

local GetUnitTeam = Spring.GetUnitTeam
local GetTeamInfo = Spring.GetTeamInfo
local GetPlayerInfo = Spring.GetPlayerInfo
local GetPlayerList = Spring.GetPlayerList
local GetTeamColor = Spring.GetTeamColor
local GetVisibleUnits = Spring.GetVisibleUnits
local GetUnitDefID = Spring.GetUnitDefID
local GetAllUnits = Spring.GetAllUnits
local IsUnitInView = Spring.IsUnitInView
local GetCameraPosition = Spring.GetCameraPosition
local GetUnitPosition = Spring.GetUnitPosition
local GetFPS = Spring.GetFPS

local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glDepthTest = gl.DepthTest
local glAlphaTest = gl.AlphaTest
local glColor = gl.Color
local glText = gl.Text
local glTranslate = gl.Translate
local glBillboard = gl.Billboard
local glDrawFuncAtUnit = gl.DrawFuncAtUnit
local glDrawListAtUnit = gl.DrawListAtUnit
local GL_GREATER = GL.GREATER
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local glBlending = gl.Blending
local glScale = gl.Scale

local glCreateList = gl.CreateList
local glBeginEnd = gl.BeginEnd
local glDeleteList = gl.DeleteList
local glCallList = gl.CallList

GL.KEEP = 0x1E00
GL.INCR_WRAP = 0x8507
GL.DECR_WRAP = 0x8508
GL.INCR = 0x1E02
GL.DECR = 0x1E03
GL.INVERT = 0x150A

local stencilBit1 = 0x01
local stencilBit2 = 0x10
local hasStartbox = false

local teamColorKeys = {}
local teams = Spring.GetTeamList()
for i = 1, #teams do
	local r, g, b, a = GetTeamColor(teams[i])
	teamColorKeys[teams[i]] = r..'_'..g..'_'..b
end
teams = nil

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:PlayerChanged(playerID)
	isSpec = Spring.GetSpectatingState()
	myTeamID = Spring.GetMyTeamID()
end

local function DrawMyBox(minX, minY, minZ, maxX, maxY, maxZ)
	gl.BeginEnd(GL.QUADS, function()
		--// top
		gl.Vertex(minX, maxY, minZ)
		gl.Vertex(maxX, maxY, minZ)
		gl.Vertex(maxX, maxY, maxZ)
		gl.Vertex(minX, maxY, maxZ)
		--// bottom
		gl.Vertex(minX, minY, minZ)
		gl.Vertex(minX, minY, maxZ)
		gl.Vertex(maxX, minY, maxZ)
		gl.Vertex(maxX, minY, minZ)
	end)
	gl.BeginEnd(GL.QUAD_STRIP, function()
		--// sides
		gl.Vertex(minX, minY, minZ)
		gl.Vertex(minX, maxY, minZ)
		gl.Vertex(minX, minY, maxZ)
		gl.Vertex(minX, maxY, maxZ)
		gl.Vertex(maxX, minY, maxZ)
		gl.Vertex(maxX, maxY, maxZ)
		gl.Vertex(maxX, minY, minZ)
		gl.Vertex(maxX, maxY, minZ)
		gl.Vertex(minX, minY, minZ)
		gl.Vertex(minX, maxY, minZ)
	end)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function createComnameList(x, y, name, teamID, color)
	comnameList[teamID] = {}
	comnameList[teamID]['x'] = math.floor(x)
	comnameList[teamID]['y'] = math.floor(y)
	comnameList[teamID]['list'] = gl.CreateList(function()
		local outlineColor = { 0, 0, 0, 1 }
		if (color[1] + color[2] * 1.2 + color[3] * 0.4) < 0.68 then
			outlineColor = { 1, 1, 1, 1 }
		end
		if useThickLeterring then
			if outlineColor[1] == 1 and fontShadow then
				glTranslate(0, -(usedFontSize / 44), 0)
				shadowFont:Begin()
				shadowFont:SetTextColor({ 0, 0, 0, shadowOpacity })
				shadowFont:SetOutlineColor({ 0, 0, 0, shadowOpacity })
				shadowFont:Print(name, x, y, usedFontSize, "con")
				shadowFont:End()
				glTranslate(0, (usedFontSize / 44), 0)
			end
			font2:Begin()
			font2:SetTextColor(outlineColor)
			font2:SetOutlineColor(outlineColor)

			font2:Print(name, x - (usedFontSize / 38), y - (usedFontSize / 33), usedFontSize, "con")
			font2:Print(name, x + (usedFontSize / 38), y - (usedFontSize / 33), usedFontSize, "con")
			font2:End()
		end
		font2:Begin()
		font2:SetTextColor(color)
		font2:SetOutlineColor(outlineColor)
		font2:Print(name, x, y, usedFontSize, "con")
		font2:End()
	end)
end

local function DrawName(x, y, name, teamID, color)
	-- not optimal, everytime you move camera the x and y are different so it has to recreate the drawlist
	if comnameList[teamID] == nil or comnameList[teamID]['x'] ~= math.floor(x) or comnameList[teamID]['y'] ~= math.floor(y) then
		-- using floor because the x and y values had a a tiny change each frame
		if comnameList[teamID] ~= nil then
			gl.DeleteList(comnameList[teamID]['list'])
		end
		createComnameList(x, y, name, teamID, color)
	end
	glCallList(comnameList[teamID]['list'])
end

function createInfotextList()
	if infotextList then
		gl.DeleteList(infotextList)
	end
	infotextList = gl.CreateList(function()
		font:Begin()
		font:SetTextColor(0.9, 0.9, 0.9, 1)
		font:Print(hasStartbox and infotextBoxes or infotext, 0, 0, infotextFontsize * widgetScale, "cno")
		font:End()
	end)
end

function widget:Initialize()

	-- only show at the beginning
	if Spring.GetGameFrame() > 1 then
		widgetHandler:RemoveWidget()
		return
	end

	-- get the gaia teamID and allyTeamID
	gaiaTeamID = Spring.GetGaiaTeamID()
	if gaiaTeamID then
		gaiaAllyTeamID = select(6, Spring.GetTeamInfo(gaiaTeamID, false))
	end

	-- flip and scale  (using x & y for gl.Rect())
	xformList = gl.CreateList(function()
		gl.LoadIdentity()
		gl.Translate(0, 1, 0)
		gl.Scale(1 / msx, -1 / msz, 1)
	end)

	-- cone list for world start positions
	coneList = gl.CreateList(function()
		local h = 100
		local r = 25
		local divs = 32
		gl.BeginEnd(GL.TRIANGLE_FAN, function()
			gl.Vertex(0, h, 0)
			for i = 0, divs do
				local a = i * ((math.pi * 2) / divs)
				local cosval = math.cos(a)
				local sinval = math.sin(a)
				gl.Vertex(r * sinval, 0, r * cosval)
			end
		end)
	end)

	if drawGroundQuads then
		startboxDListStencil = gl.CreateList(function()
			local minY, maxY = Spring.GetGroundExtremes()
			minY = minY - 200
			maxY = maxY + 500
			for _, at in ipairs(Spring.GetAllyTeamList()) do
				if true or at ~= gaiaAllyTeamID then
					local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(at)
					if xn and (xn ~= 0 or zn ~= 0 or xp ~= msx or zp ~= msz) then

						if at == Spring.GetMyAllyTeamID() then
							gl.StencilMask(stencilBit2)
							gl.StencilFunc(GL.ALWAYS, 0, stencilBit2)
						else
							gl.StencilMask(stencilBit1)
							gl.StencilFunc(GL.ALWAYS, 0, stencilBit1)
						end
						DrawMyBox(xn - 1, minY, zn - 1, xp + 1, maxY, zp + 1)
					end
				end
			end
		end)

		startboxDListColor = gl.CreateList(function()
			local minY, maxY = Spring.GetGroundExtremes()
			minY = minY - 200
			maxY = maxY + 500
			for _, at in ipairs(Spring.GetAllyTeamList()) do
				if true or at ~= gaiaAllyTeamID then
					local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(at)
					if xn and (xn ~= 0 or zn ~= 0 or xp ~= msx or zp ~= msz) then

						if at == Spring.GetMyAllyTeamID() then
							gl.Color(0, 1, 0, 0.22)  --  green
							gl.StencilMask(stencilBit2)
							gl.StencilFunc(GL.NOTEQUAL, 0, stencilBit2)
							hasStartbox = true
						else
							gl.Color(1, 0, 0, 0.22)  --  red
							gl.StencilMask(stencilBit1)
							gl.StencilFunc(GL.NOTEQUAL, 0, stencilBit1)
						end
						DrawMyBox(xn - 1, minY, zn - 1, xp + 1, maxY, zp + 1)

					end
				end
			end
		end)
	end

	createInfotextList()
end

local function removeTeamLists()
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if comnameList[teamID] ~= nil then
			gl.DeleteList(comnameList[teamID].list)
		end
	end
	comnameList = {}
end

local function removeLists()
	gl.DeleteList(infotextList)
	gl.DeleteList(xformList)
	gl.DeleteList(coneList)
	gl.DeleteList(startboxDListStencil)
	gl.DeleteList(startboxDListColor)
	removeTeamLists()
end

function widget:Shutdown()
	removeLists()
	gl.DeleteFont(font)
	gl.DeleteFont(shadowFont)
end

local teamColors = {}
local function GetTeamColor(teamID)
	local color = teamColors[teamID]
	if color then
		return color
	end
	local r, g, b = Spring.GetTeamColor(teamID)
	color = { r, g, b }
	teamColors[teamID] = color
	return color
end


local teamColorStrs = {}
local function GetTeamColorStr(teamID)
	local colorSet = teamColorStrs[teamID]
	if colorSet then
		return colorSet[1], colorSet[2]
	end

	local outlineChar = ''
	local r, g, b = Spring.GetTeamColor(teamID)
	if r and g and b then
		local function ColorChar(x)
			local c = math.floor(x * 255)
			c = ((c <= 1) and 1) or ((c >= 255) and 255) or c
			return string.char(c)
		end
		local colorStr
		colorStr = '\255'
		colorStr = colorStr .. ColorChar(r)
		colorStr = colorStr .. ColorChar(g)
		colorStr = colorStr .. ColorChar(b)
		local i = (r * 0.299) + (g * 0.587) + (b * 0.114)
		outlineChar = ((i > 0.25) and 'o') or 'O'
		teamColorStrs[teamID] = { colorStr, outlineChar }
		return colorStr, "s", outlineChar
	end
end

local function DrawStartboxes3dWithStencil()
	gl.DepthMask(false)
	if gl.DepthClamp then
		gl.DepthClamp(true)
	end

	gl.DepthTest(true)
	gl.StencilTest(true)
	gl.ColorMask(false, false, false, false)
	gl.Culling(false)

	gl.StencilOp(GL.KEEP, GL.INVERT, GL.KEEP)

	gl.CallList(startboxDListStencil)   --// draw

	gl.Culling(GL.BACK)
	gl.DepthTest(false)

	gl.ColorMask(true, true, true, true)

	gl.CallList(startboxDListColor)   --// draw

	if gl.DepthClamp then
		gl.DepthClamp(false)
	end
	gl.StencilTest(false)
	gl.DepthTest(true)
	gl.Culling(false)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:DrawWorld()
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	local time = Spring.DiffTimers(Spring.GetTimer(), startTimer)

	-- show the ally startboxes
	DrawStartboxes3dWithStencil()

	-- show the team start positions
	for _, teamID in ipairs(Spring.GetTeamList()) do
		local _, _, spec = Spring.GetPlayerInfo(select(2, Spring.GetTeamInfo(teamID, false)), false)
		if not spec and teamID ~= gaiaTeamID then
			local x, y, z = Spring.GetTeamStartPosition(teamID)
			local isNewbie = (Spring.GetTeamRulesParam(teamID, 'isNewbie') == 1) -- =1 means the startpoint will be replaced and chosen by initial_spawn
			if x ~= nil and x > 0 and z > 0 and y > -500 and not isNewbie then
				local color = GetTeamColor(teamID)
				local alpha = 0.5 + math.abs(((time * 3) % 1) - 0.5)
				gl.PushMatrix()
				gl.Translate(x, y, z)
				gl.Color(color[1], color[2], color[3], alpha)
				gl.CallList(coneList)
				gl.PopMatrix()
				if teamID == myTeamID then
					amPlaced = true
				end
			end
		end
	end
end

function widget:DrawScreenEffects()
	-- show the names over the team start positions
	for _, teamID in ipairs(Spring.GetTeamList()) do
		local name, _, spec = Spring.GetPlayerInfo(select(2, Spring.GetTeamInfo(teamID, false)), false)
		local isNewbie = (Spring.GetTeamRulesParam(teamID, 'isNewbie') == 1) -- =1 means the startpoint will be replaced and chosen by initial_spawn
		if name ~= nil and not spec and teamID ~= gaiaTeamID and not isNewbie then
			local colorStr, outlineStr = GetTeamColorStr(teamID)
			local x, y, z = Spring.GetTeamStartPosition(teamID)
			if x ~= nil and x > 0 and z > 0 and y > -500 then
				local sx, sy, sz = Spring.WorldToScreenCoords(x, y + 120, z)
				if sz < 1 then
					DrawName(sx, sy, name, teamID, GetTeamColor(teamID))
				end
			end
		end
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreen()
	if chobbyInterface then
		return
	end
	if not isSpec then
		gl.PushMatrix()
		gl.Translate(vsx / 2, vsy / 6.2, 0)
		gl.Scale(1 * widgetScale, 1 * widgetScale, 1)
		gl.CallList(infotextList)
		gl.PopMatrix()
	end
end

function widget:DrawInMiniMap(sx, sz)

	if Spring.GetGameFrame() > 1 then
		widgetHandler:RemoveWidget()
	end

	gl.PushMatrix()
	gl.CallList(xformList)

	gl.LineWidth(1.49)

	local gaiaAllyTeamID
	local gaiaTeamID = Spring.GetGaiaTeamID()
	if gaiaTeamID then
		gaiaAllyTeamID = select(6, Spring.GetTeamInfo(gaiaTeamID, false))
	end

	-- show all start boxes
	for _, at in ipairs(Spring.GetAllyTeamList()) do
		if at ~= gaiaAllyTeamID then
			local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(at)
			if xn and (xn ~= 0 or zn ~= 0 or xp ~= msx or zp ~= msz) then
				local color
				if at == Spring.GetMyAllyTeamID() then
					color = { 0, 1, 0, 0.1 }  --  green
				else
					color = { 1, 0, 0, 0.1 }  --  red
				end
				gl.Color(color)
				gl.Rect(xn, zn, xp, zp)
				color[4] = 0.5  --  pump up the volume
				gl.Color(color)
				gl.PolygonMode(GL.FRONT_AND_BACK, GL.LINE)
				gl.Rect(xn, zn, xp, zp)
				gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL)
			end
		end
	end

	gl.PushAttrib(GL_HINT_BIT)
	--gl.Smoothing(true) --enable point smoothing

	-- show the team start positions
	for _, teamID in ipairs(Spring.GetTeamList()) do
		local _, _, spec = Spring.GetPlayerInfo(select(2, Spring.GetTeamInfo(teamID, false)), false)
		if not spec and teamID ~= gaiaTeamID then
			local x, y, z = Spring.GetTeamStartPosition(teamID)
			local isNewbie = (Spring.GetTeamRulesParam(teamID, 'isNewbie') == 1) -- =1 means the startpoint will be replaced and chosen by initial_spawn
			if x ~= nil and x > 0 and z > 0 and y > -500 and not isNewbie then
				local color = GetTeamColor(teamID)
				local r, g, b = color[1], color[2], color[3]
				local time = Spring.DiffTimers(Spring.GetTimer(), startTimer)
				local i = 2 * math.abs(((time * 3) % 1) - 0.5)
				gl.PointSize(11)
				gl.Color(i, i, i)
				gl.BeginEnd(GL.POINTS, gl.Vertex, x, z)
				gl.PointSize(7.5)
				gl.Color(r, g, b)
				gl.BeginEnd(GL.POINTS, gl.Vertex, x, z)
			end
		end
	end

	gl.LineWidth(1.0)
	gl.PointSize(1.0)
	gl.PopAttrib() --reset point smoothing
	gl.PopMatrix()
end

function widget:ViewResize(x, y)
	vsx, vsy = x, y
	widgetScale = (0.75 + (vsx * vsy / 7500000))
	removeTeamLists()
	usedFontSize = fontSize * widgetScale
	local newFontfileScale = (0.5 + (vsx * vsy / 5700000))
	if fontfileScale ~= newFontfileScale then
		fontfileScale = newFontfileScale
		gl.DeleteFont(font)
		gl.DeleteFont(shadowFont)
		font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
		font2 = gl.LoadFont(fontfile2, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength2)
		shadowFont = gl.LoadFont(fontfile, fontfileSize * fontfileScale, 35 * fontfileScale, 1.6)
		createInfotextList()
	end
end

-- reset needed when waterlevel has changed by gadget (modoption)
local resetsec = 0
local resetted = false
local doWaterLevelCheck = false
if Spring.GetModOptions() ~= nil and Spring.GetModOptions().map_waterlevel ~= 0 then
	doWaterLevelCheck = true
end

local groundHeightPoint = Spring.GetGroundHeight(0, 0)
local sec = 0
function widget:Update(dt)
	if Spring.GetGameFrame() > 1 then
		widgetHandler:RemoveWidget()
	end
	if not placeVoiceNotifTimer then
		placeVoiceNotifTimer = os.clock() + 22
	end

	if (doWaterLevelCheck and not resetted) or (Spring.IsCheatingEnabled() and Spring.GetGroundHeight(0, 0) ~= groundHeightPoint) then
		resetsec = resetsec + dt
		if resetsec > 1 then
			groundHeightPoint = Spring.GetGroundHeight(0, 0)
			resetted = true
			removeLists()
			widget:Initialize()
		end
	end

	if not isSpec and not amPlaced and not playedChooseStartLoc and placeVoiceNotifTimer < os.clock() and WG['notifications'] then
		playedChooseStartLoc = true
		WG['notifications'].addEvent('ChooseStartLoc', true)
	end


	sec = sec + dt
	if sec > 1 then
		sec = 0

		-- check if team colors have changed
		local teams = Spring.GetTeamList()
		local detectedChanges = false
		for i = 1, #teams do
			local color = GetTeamColor(teams[i])
			local r, g, b = color[1], color[2], color[3]
			if teamColorKeys[teams[i]] ~= r..'_'..g..'_'..b then
				teamColorKeys[teams[i]] = r..'_'..g..'_'..b
				detectedChanges = true
			end
		end
		if detectedChanges then
			removeLists()
		end
	end
end
