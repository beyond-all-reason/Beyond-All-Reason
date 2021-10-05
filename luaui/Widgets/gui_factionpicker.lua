function widget:GetInfo()
	return {
		name = "Factionpicker",
		desc = "",
		author = "Floris",
		date = "May 2020",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true
	}
end

local chobbyLoaded = (Spring.GetMenuName and string.find(string.lower(Spring.GetMenuName()), 'chobby') ~= nil)

local restorePreviousFaction = false

local factions = {
	{ UnitDefNames.corcom.id, Spring.I18N('units.factions.cor'), 'unitpics/'..UnitDefNames.corcom.buildpicname },
	{ UnitDefNames.armcom.id, Spring.I18N('units.factions.arm'), 'unitpics/'..UnitDefNames.armcom.buildpicname },
}
local playSounds = true
local posY = 0.75
local posX = 0
local width = 0
local height = 0
local bgBorderOrg = 0.003
local bgBorder = bgBorderOrg
local bgMargin = 0.008

local myTeamID = Spring.GetMyTeamID()
local stickToBottom = true

local startDefID = Spring.GetTeamRulesParam(myTeamID, 'startUnit')

local ui_tileopacity = tonumber(Spring.GetConfigFloat("ui_tileopacity", 0.012) or 0.012)
local bgtexScale = tonumber(Spring.GetConfigFloat("ui_tilescale", 7) or 7)	-- lower = smaller tiles
local bgtexSize

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local factionRect = {}
for i, faction in pairs(factions) do
	factionRect[i] = {}
end

local vsx, vsy = Spring.GetViewGeometry()
local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")

local sound_button = 'LuaUI/Sounds/buildbar_waypoint.wav'

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity", 0.6) or 0.66)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)
local glossMult = 1 + (2 - (ui_opacity * 2))    -- increase gloss/highlight so when ui is transparant, you can still make out its boundaries and make it less flat

local backgroundRect = {}
local lastUpdate = os.clock() - 1

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local os_clock = os.clock

local GL_QUADS = GL.QUADS
local GL_TRIANGLE_FAN = GL.TRIANGLE_FAN
local glBeginEnd = gl.BeginEnd
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glColor = gl.Color
local glRect = gl.Rect
local glVertex = gl.Vertex
local glDepthTest = gl.DepthTest

local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local mCos = math.cos
local mSin = math.sin
local math_min = math.min

local isSpec = Spring.GetSpectatingState()

local font, font2, bgpadding, chobbyInterface, dlistGuishader, dlistFactionpicker, bpWidth, bpHeight, rectMargin, fontSize

local RectRound, UiElement, UiUnit

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local function DrawTexRectRound(px, py, sx, sy, cs, tl, tr, br, bl, offset)
	local csyMult = 1 / ((sy - py) / cs)

	local function drawTexCoordVertex(x, y)
		local yc = 1 - ((y - py) / (sy - py))
		local xc = (offset * 0.5) + ((x - px) / (sx - px)) + (-offset * ((x - px) / (sx - px)))
		yc = 1 - (offset * 0.5) - ((y - py) / (sy - py)) + (offset * ((y - py) / (sy - py)))
		gl.TexCoord(xc, yc)
		gl.Vertex(x, y, 0)
	end

	-- mid section
	drawTexCoordVertex(px + cs, py)
	drawTexCoordVertex(sx - cs, py)
	drawTexCoordVertex(sx - cs, sy)
	drawTexCoordVertex(px + cs, sy)

	-- left side
	drawTexCoordVertex(px, py + cs)
	drawTexCoordVertex(px + cs, py + cs)
	drawTexCoordVertex(px + cs, sy - cs)
	drawTexCoordVertex(px, sy - cs)

	-- right side
	drawTexCoordVertex(sx, py + cs)
	drawTexCoordVertex(sx - cs, py + cs)
	drawTexCoordVertex(sx - cs, sy - cs)
	drawTexCoordVertex(sx, sy - cs)

	-- bottom left
	if ((py <= 0 or px <= 0) or (bl ~= nil and bl == 0)) and bl ~= 2 then
		drawTexCoordVertex(px, py)
	else
		drawTexCoordVertex(px + cs, py)
	end
	drawTexCoordVertex(px + cs, py)
	drawTexCoordVertex(px + cs, py + cs)
	drawTexCoordVertex(px, py + cs)
	-- bottom right
	if ((py <= 0 or sx >= vsx) or (br ~= nil and br == 0)) and br ~= 2 then
		drawTexCoordVertex(sx, py)
	else
		drawTexCoordVertex(sx - cs, py)
	end
	drawTexCoordVertex(sx - cs, py)
	drawTexCoordVertex(sx - cs, py + cs)
	drawTexCoordVertex(sx, py + cs)
	-- top left
	if ((sy >= vsy or px <= 0) or (tl ~= nil and tl == 0)) and tl ~= 2 then
		drawTexCoordVertex(px, sy)
	else
		drawTexCoordVertex(px + cs, sy)
	end
	drawTexCoordVertex(px + cs, sy)
	drawTexCoordVertex(px + cs, sy - cs)
	drawTexCoordVertex(px, sy - cs)
	-- top right
	if ((sy >= vsy or sx >= vsx) or (tr ~= nil and tr == 0)) and tr ~= 2 then
		drawTexCoordVertex(sx, sy)
	else
		drawTexCoordVertex(sx - cs, sy)
	end
	drawTexCoordVertex(sx - cs, sy)
	drawTexCoordVertex(sx - cs, sy - cs)
	drawTexCoordVertex(sx, sy - cs)
end
function TexRectRound(px, py, sx, sy, cs, tl, tr, br, bl, zoom)
	gl.BeginEnd(GL.QUADS, DrawTexRectRound, px, py, sx, sy, cs, tl, tr, br, bl, zoom)
end

local function checkGuishader(force)
	if WG['guishader'] then
		if force and dlistGuishader then
			dlistGuishader = gl.DeleteList(dlistGuishader)
		end
		if not dlistGuishader then
			dlistGuishader = gl.CreateList(function()
				RectRound(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], (bgBorder * vsy) * 2)
			end)
			WG['guishader'].InsertDlist(dlistGuishader, 'factionpicker')
		end
	elseif dlistGuishader then
		dlistGuishader = gl.DeleteList(dlistGuishader)
	end
end

function widget:PlayerChanged(playerID)
	isSpec = Spring.GetSpectatingState()
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()

	width = 0.2125
	height = 0.14 * ui_scale

	width = width / (vsx / vsy) * 1.78        -- make smaller for ultrawide screens
	width = width * ui_scale

	-- make pixel aligned
	width = math.floor(width * vsx) / vsx
	height = math.floor(height * vsy) / vsy

	local buildmenuBottomPos
	if WG['buildmenu'] then
		buildmenuBottomPos = WG['buildmenu'].getBottomPosition()
	end

	font = WG['fonts'].getFont()
	font2 = WG['fonts'].getFont(fontfile2)

	local widgetSpaceMargin = WG.FlowUI.elementMargin
	bgpadding = WG.FlowUI.elementPadding

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiUnit = WG.FlowUI.Draw.Unit

	if WG['minimap'] then
		minimapHeight = WG['minimap'].getHeight()
	end

	if stickToBottom then
		posY = height
		posX = width + (widgetSpaceMargin/vsx)
	else
		if buildmenuBottomPos then
			posX = 0
			posY = height + height + (widgetSpaceMargin/vsy)
		elseif WG['buildmenu'] then
			local posY2, _ = WG['buildmenu'].getSize()
			posY2 = posY2 + (widgetSpaceMargin/vsy)
			posY = posY2 + height
			if WG['minimap'] then
				posY = 1 - (minimapHeight / vsy) - (widgetSpaceMargin/vsy)
			end
			posX = 0
		end
	end

	bgtexSize = bgpadding * bgtexScale

	backgroundRect = { posX * vsx, (posY - height) * vsy, (posX + width) * vsx, posY * vsy }

	dlistFactionpicker = gl.DeleteList(dlistFactionpicker)

	checkGuishader(true)

	doUpdate = true

	fontSize = (height * vsy * 0.125) * (1 - ((1 - ui_scale) * 0.5))
end

function widget:Initialize()
	if isSpec or Spring.GetGameFrame() > 0 then
		widgetHandler:RemoveWidget()
		return
	end

  if Spring.GetModOptions().scenariooptions then
    local scenarioopts = string.base64Decode(Spring.GetModOptions().scenariooptions)
    scenarioopts = Spring.Utilities.json.decode(scenarioopts)
    if scenarioopts and scenarioopts.scenariooptions and scenarioopts.scenariooptions.disablefactionpicker == true then
      widgetHandler:RemoveWidget()
      return
    end
  end

	if WG['ordermenu'] then
		stickToBottom = WG['ordermenu'].getBottomPosition()
	end

	widget:ViewResize()

	-- cache
	dlistFactionpicker = gl.CreateList(function()
		drawFactionpicker()
	end)
end

function widget:Shutdown()
	if WG['guishader'] and dlistGuishader then
		WG['guishader'].DeleteDlist('factionpicker')
		dlistGuishader = nil
	end
	dlistFactionpicker = gl.DeleteList(dlistFactionpicker)
end

function widget:GameFrame(n)
	widgetHandler:RemoveWidget()
end

local sec = 0
function widget:Update(dt)
	sec = sec + dt
	if sec > 0.5 then
		doUpdate = true
		sec = 0
		checkGuishader()

		if ui_scale ~= Spring.GetConfigFloat("ui_scale", 1) then
			ui_scale = Spring.GetConfigFloat("ui_scale", 1)
			widget:ViewResize()
			doUpdate = true
		end
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity", 0.6) then
			ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.6)
			glossMult = 1 + (2 - (ui_opacity * 2))
			doUpdate = true
		end

		if WG['minimap'] and minimapHeight ~= WG['minimap'].getHeight() then
			widget:ViewResize()
			doUpdate = true
		end

		if WG['ordermenu'] and stickToBottom ~= WG['ordermenu'].getBottomPosition() then
			stickToBottom = WG['ordermenu'].getBottomPosition()
			widget:ViewResize()
			doUpdate = true
		end
	end
end

function IsOnRect(x, y, BLcornerX, BLcornerY, TRcornerX, TRcornerY)
	return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
end

function drawFactionpicker()
	UiElement(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], 1, 1, ((posY-height > 0 or posX <= 0) and 1 or 0), 0)

	local contentPadding = math.floor((height * vsy * 0.09) * (1 - ((1 - ui_scale) * 0.5)))
	font2:Begin()
	font2:Print("Pick your faction", backgroundRect[1] + contentPadding, backgroundRect[4] - contentPadding - (fontSize * 0.7), fontSize, "o")

	local contentWidth = math.floor(backgroundRect[3] - backgroundRect[1] - contentPadding)
	local contentHeight = math.floor(backgroundRect[4] - backgroundRect[2] - (contentPadding*1.33))
	local maxCellHeight = math.floor((contentHeight - (fontSize * 1.1)) + 0.5)
	local maxCellWidth = math.floor((contentWidth / #factions) + 0.5)
	local cellSize = math.min(maxCellHeight, maxCellWidth)
	local padding = bgpadding
	for i, faction in pairs(factions) do
		factionRect[i] = {
			math.floor(backgroundRect[3] - padding - (cellSize * i)),
			math.floor(backgroundRect[2]),
			math.floor(backgroundRect[3] - padding - (cellSize * (i - 1))),
			math.floor(backgroundRect[2] + cellSize)
		}
		glColor(1,1,1,1)
		UiUnit(factionRect[i][1]+bgpadding, factionRect[i][2] + bgpadding, factionRect[i][3], factionRect[i][4],
			nil,
			1,1,1,1,
			0,
			nil, nil,
			(Spring.GetTeamRulesParam(myTeamID, 'startUnit') == factions[i][1] and ":lr256,256:" or ":lgr256,256:") .. factions[i][3]
		)
		-- faction name
		if startDefID == factions[i][1] then
			font2:Print(factions[i][2], factionRect[i][1] + ((factionRect[i][3] - factionRect[i][1]) * 0.5), factionRect[i][2] + ((factionRect[i][4] - factionRect[i][2]) * 0.22) - (fontSize * 0.5), fontSize * 0.96, "co")
		else
			font2:Print("\255\200\200\200"..factions[i][2], factionRect[i][1] + ((factionRect[i][3] - factionRect[i][1]) * 0.5), factionRect[i][2] + ((factionRect[i][4] - factionRect[i][2]) * 0.22) - (fontSize * 0.5), fontSize * 0.96, "co")
		end
	end
	font2:End()
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

	local x, y, b = Spring.GetMouseState()
	if not WG['topbar'] or not WG['topbar'].showingQuit() then
		if IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
			Spring.SetMouseCursor('cursornormal')
		end
	end

	if startDefID ~= Spring.GetTeamRulesParam(myTeamID, 'startUnit') then
		startDefID = Spring.GetTeamRulesParam(myTeamID, 'startUnit')
		doUpdate = true
	end

	if doUpdate then
		lastUpdate = os_clock()
	end

	if dlistGuishader and WG['guishader'] then
		WG['guishader'].InsertDlist(dlistGuishader, 'factionpicker')
	end
	if doUpdate then
		dlistFactionpicker = gl.DeleteList(dlistFactionpicker)
	end
	if not dlistFactionpicker then
		dlistFactionpicker = gl.CreateList(function()
			drawFactionpicker()
		end)
	end
	gl.CallList(dlistFactionpicker)

	-- highlight
	if IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
		for i, faction in pairs(factions) do
			if IsOnRect(x, y, factionRect[i][1], factionRect[i][2], factionRect[i][3], factionRect[i][4]) then
				glBlending(GL_SRC_ALPHA, GL_ONE)
				RectRound(factionRect[i][1] + bgpadding, factionRect[i][2] + bgpadding, factionRect[i][3], factionRect[i][4], bgpadding, 1, 1, 1, 1, { 0.3, 0.3, 0.3, (b and 0.5 or 0.25) }, { 1, 1, 1, (b and 0.3 or 0.15) })
				glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

				font2:Print(factions[i][2], factionRect[i][1] + ((factionRect[i][3] - factionRect[i][1]) * 0.5), factionRect[i][2] + ((factionRect[i][4] - factionRect[i][2]) * 0.22) - (fontSize * 0.5), fontSize * 0.96, "co")
				break
			end
		end
	end

	doUpdate = nil
end

function widget:MousePress(x, y, button)
	if IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then

		for i, faction in pairs(factions) do
			if IsOnRect(x, y, factionRect[i][1], factionRect[i][2], factionRect[i][3], factionRect[i][4]) then
				if playSounds then
					Spring.PlaySoundFile(sound_button, 0.6, 'ui')
				end
				-- tell initial spawn
				Spring.SendLuaRulesMsg('\138' .. tostring(factions[i][1]))
				break
			end
		end
		return true
	end
end

function widget:GetConfigData()
	return { startDefID = startDefID }
end

function widget:SetConfigData(data)
	if restorePreviousFaction then
		if data ~= nil and data.startDefID then

			-- loop factions to make sure startDefID is legit
			for i,v in pairs(factions) do
				if factions[i][1] == startDefID then
					startDefID = factions[i][1]
					-- tell initial spawn
					Spring.SendLuaRulesMsg('\138' .. tostring(factions[i][1]))
					break
				end
			end
		end
	end
end
