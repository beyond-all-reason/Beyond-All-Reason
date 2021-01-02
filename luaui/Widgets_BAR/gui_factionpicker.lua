function widget:GetInfo()
	return {
		name = "Factionpicker",
		desc = "",
		author = "Floris",
		date = "May 2020",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true
	}
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
local factions = {
	{ UnitDefNames.corcom.id, 'Cortex', 'unitpics/corcom.png' },
	{ UnitDefNames.armcom.id, 'Armada', 'unitpics/armcom.png' },
}
local altPosition = false
local playSounds = true
local posY = 0.75
local posX = 0
local width = 0
local height = 0
local bgBorderOrg = 0.003
local bgBorder = bgBorderOrg
local bgMargin = 0.008

local myTeamID = Spring.GetMyTeamID()
local stickToBottom = false


local backgroundTexture = "LuaUI/Images/backgroundtile.png"
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

local RectRound = Spring.Utilities.RectRound
local TexturedRectRound = Spring.Utilities.TexturedRectRound

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
	local widgetSpaceMargin
	if stickToBottom or (altPosition and not buildmenuBottomPos) then
		widgetSpaceMargin = math.floor(0.0045 * (vsy / vsx) * vsx * ui_scale) / vsx
		bgpadding = math.ceil(widgetSpaceMargin * 0.66 * vsx)

		posY = height
		posX = width + widgetSpaceMargin
	else
		if buildmenuBottomPos then
			widgetSpaceMargin = math.floor(0.0045 * vsy * ui_scale) / vsy
			bgpadding = math.ceil(widgetSpaceMargin * 0.66 * vsy)
			posX = 0
			posY = height + height + widgetSpaceMargin
		else
			widgetSpaceMargin = math.floor(0.0045 * vsy * ui_scale) / vsy
			bgpadding = math.ceil(widgetSpaceMargin * 0.66 * vsy)
			posY = 0.75
			local posY2, _ = WG['buildmenu'].getSize()
			posY2 = posY2 + widgetSpaceMargin
			posY = posY2 + height
			if WG['minimap'] then
				posY = 1 - (WG['minimap'].getHeight() / vsy) - widgetSpaceMargin
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
		widgetHandler:RemoveWidget(self)
		return
	end

	if WG['minimap'] then
		altPosition = WG['minimap'].getEnlarged()
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
	widgetHandler:RemoveWidget(self)
end

local sec = 0
function widget:Update(dt)
	sec = sec + dt
	if sec > 0.5 then
		doUpdate = true
		sec = 0
		checkGuishader()
		if WG['buildpower'] then
			local newBpWidth, newBpHeight = WG['buildpower'].getPosition()
			if bpWidth == nil or (bpWidth ~= newBpWidth or bpHeight ~= newBpHeight) then
				bpWidth = newBpWidth
				bpHeight = newBpHeight
				widget:ViewResize()
			end
		end
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
		if WG['minimap'] and altPosition ~= WG['minimap'].getEnlarged() then
			altPosition = WG['minimap'].getEnlarged()
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

local function DrawRectRoundCircle(x, y, z, radius, cs, centerOffset, color1, color2)
	if not color2 then
		color2 = color1
	end
	--centerOffset = 0
	local coords = {
		{ x - radius + cs, z + radius, y }, -- top left
		{ x + radius - cs, z + radius, y }, -- top right
		{ x + radius, z + radius - cs, y }, -- right top
		{ x + radius, z - radius + cs, y }, -- right bottom
		{ x + radius - cs, z - radius, y }, -- bottom right
		{ x - radius + cs, z - radius, y }, -- bottom left
		{ x - radius, z - radius + cs, y }, -- left bottom
		{ x - radius, z + radius - cs, y }, -- left top
	}
	local cs2 = cs * (centerOffset / radius)
	local coords2 = {
		{ x - centerOffset + cs2, z + centerOffset, y }, -- top left
		{ x + centerOffset - cs2, z + centerOffset, y }, -- top right
		{ x + centerOffset, z + centerOffset - cs2, y }, -- right top
		{ x + centerOffset, z - centerOffset + cs2, y }, -- right bottom
		{ x + centerOffset - cs2, z - centerOffset, y }, -- bottom right
		{ x - centerOffset + cs2, z - centerOffset, y }, -- bottom left
		{ x - centerOffset, z - centerOffset + cs2, y }, -- left bottom
		{ x - centerOffset, z + centerOffset - cs2, y }, -- left top
	}
	for i = 1, 8 do
		local i2 = (i >= 8 and 1 or i + 1)
		glColor(color2)
		glVertex(coords[i][1], coords[i][2], coords[i][3])
		glVertex(coords[i2][1], coords[i2][2], coords[i2][3])
		glColor(color1)
		glVertex(coords2[i2][1], coords2[i2][2], coords2[i2][3])
		glVertex(coords2[i][1], coords2[i][2], coords2[i][3])
	end
end

local function RectRoundCircle(x, y, z, radius, cs, centerOffset, color1, color2)
	glBeginEnd(GL.QUADS, DrawRectRoundCircle, x, y, z, radius, cs, centerOffset, color1, color2)
end

function IsOnRect(x, y, BLcornerX, BLcornerY, TRcornerX, TRcornerY)
	return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
end

function drawFactionpicker()
	-- background
	local padding = bgpadding
	RectRound(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], padding * 1.6, 1, 1, 1, 1, { 0.05, 0.05, 0.05, ui_opacity }, { 0, 0, 0, ui_opacity })
	RectRound(backgroundRect[1] + (altPosition and padding or 0), backgroundRect[2] + padding, backgroundRect[3] - padding, backgroundRect[4] - padding, padding, (altPosition and 1 or 0), 1, 1, 0, { 0.3, 0.3, 0.3, ui_opacity * 0.1 }, { 1, 1, 1, ui_opacity * 0.1 })

	if ui_tileopacity > 0 then
		gl.Texture(backgroundTexture)
		gl.Color(1,1,1, ui_tileopacity)
		TexturedRectRound(backgroundRect[1] + (altPosition and padding or 0), backgroundRect[2] + padding, backgroundRect[3] - padding, backgroundRect[4] - padding, padding, (altPosition and 1 or 0), 1, 1, 0, bgtexSize, 0)
		gl.Texture(false)
	end

	-- gloss
	glBlending(GL_SRC_ALPHA, GL_ONE)
	RectRound(backgroundRect[1] + (altPosition and padding or 0), backgroundRect[4] - ((backgroundRect[4] - backgroundRect[2]) * 0.16), backgroundRect[3] - padding, backgroundRect[4] - padding, padding, (altPosition and 1 or 0), 1, 0, 0, { 1, 1, 1, 0.01 * glossMult }, { 1, 1, 1, 0.055 * glossMult })
	RectRound(backgroundRect[1] + (altPosition and padding or 0), backgroundRect[2] + (altPosition and 0 or padding), backgroundRect[3] - padding, backgroundRect[2] + ((backgroundRect[4] - backgroundRect[2]) * 0.15), padding, 0, 0, (altPosition and 0 or 1), 0, { 1, 1, 1, 0.035 * glossMult }, { 1, 1, 1, 0 })
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

	padding = bgpadding * 0.4

	font2:Begin()

	local contentPadding = (height * vsy * 0.075) * (1 - ((1 - ui_scale) * 0.5))
	local contentWidth = backgroundRect[3] - backgroundRect[1] - contentPadding - contentPadding
	local contentHeight = backgroundRect[4] - backgroundRect[2] - contentPadding - contentPadding
	font2:Print("Pick your faction", backgroundRect[1] + contentPadding, backgroundRect[4] - contentPadding - (fontSize * 0.8), fontSize, "o")

	local maxCellHeight = math.floor((contentHeight - (fontSize * 1.1)) + 0.5)
	local maxCellWidth = math.floor((contentWidth / #factions) + 0.5)
	local cellSize = math.min(maxCellHeight, maxCellWidth)

	rectMargin = math.floor((padding * 1) + 0.5)
	for i, faction in pairs(factions) do
		factionRect[i] = {
			math.floor(backgroundRect[3] - padding - (cellSize * i)),
			math.floor(backgroundRect[2] + padding),
			math.floor(backgroundRect[3] - padding - (cellSize * (i - 1))),
			math.floor(backgroundRect[2] + padding + cellSize)
		}

		-- background
		local color1, color2
		if WG['guishader'] then
			color1 = { 0.35, 0.35, 0.35, 0.66 }
			color2 = { 0.45, 0.45, 0.45, 0.66 }
		else
			color1 = { 0.3, 0.3, 0.3, 0.9 }
			color2 = { 0.4, 0.4, 0.4, 0.9 }
		end
		RectRound(factionRect[i][1] + rectMargin, factionRect[i][2] + rectMargin, factionRect[i][3] - rectMargin, factionRect[i][4] - rectMargin, rectMargin, 1, 1, 1, 1, color1, color2)

		glBlending(GL_SRC_ALPHA, GL_ONE)
		RectRoundCircle(factionRect[i][1] + rectMargin + ((factionRect[i][3] - factionRect[i][1] - rectMargin - rectMargin) / 2), 0, factionRect[i][2] + rectMargin + ((factionRect[i][4] - factionRect[i][2] - rectMargin - rectMargin) / 2), ((factionRect[i][3] - factionRect[i][1] - rectMargin - rectMargin) / 2), rectMargin, math.ceil(((factionRect[i][3] - factionRect[i][1] - rectMargin - rectMargin) / 2) - rectMargin), { 1, 1, 1, 0.06 }, { 1, 1, 1, 0.06 })
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

		-- gloss
		RectRound(factionRect[i][1] + rectMargin, factionRect[i][4] - ((factionRect[i][4] - factionRect[i][2]) * 0.5), factionRect[i][3] - rectMargin, factionRect[i][4] - rectMargin, rectMargin, 1, 1, 0, 0, { 1, 1, 1, 0.04 }, { 1, 1, 1, 0.3 })
		RectRound(factionRect[i][1] + rectMargin, factionRect[i][2] + rectMargin, factionRect[i][3] - rectMargin, factionRect[i][2] + ((factionRect[i][4] - factionRect[i][2]) * 0.33), rectMargin, 0, 0, 1, 1, { 1, 1, 1, 0.11 }, { 1, 1, 1, 0 })

		-- selected
		if Spring.GetTeamRulesParam(myTeamID, 'startUnit') == factions[i][1] then
			glBlending(GL_SRC_ALPHA, GL_ONE)
			RectRound(factionRect[i][1] + rectMargin, factionRect[i][2] + rectMargin, factionRect[i][3] - rectMargin, factionRect[i][4] - rectMargin, rectMargin, 1, 1, 1, 1, { 1, 1, 1, 0.08 }, { 1, 1, 1, 0.08 })
			-- gloss
			RectRound(factionRect[i][1] + rectMargin, factionRect[i][4] - ((factionRect[i][4] - factionRect[i][2]) * 0.5), factionRect[i][3] - rectMargin, factionRect[i][4] - rectMargin, rectMargin, 1, 1, 0, 0, { 1, 1, 1, 0.02 }, { 1, 1, 1, 0.25 })
			RectRound(factionRect[i][1] + rectMargin, factionRect[i][2] + rectMargin, factionRect[i][3] - rectMargin, factionRect[i][2] + ((factionRect[i][4] - factionRect[i][2]) * 0.33), rectMargin, 0, 0, 1, 1, { 1, 1, 1, 0.1 }, { 1, 1, 1, 0 })
			glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
			glColor(1, 1, 1, 1)
			glTexture(":lr256,256:" .. factions[i][3])
		else
			glColor(1, 1, 1, 1)
			glTexture(":lgr256,256:" .. factions[i][3])
			TexRectRound(factionRect[i][1] + rectMargin, factionRect[i][2] + rectMargin, factionRect[i][3] - rectMargin, factionRect[i][4] - rectMargin, rectMargin, 1, 1, 1, 1, 0)
			glTexture(false)

			glColor(1, 1, 1, 0.09)
			glTexture(":lr256,256:" .. factions[i][3])
		end

		-- startunit icon
		TexRectRound(factionRect[i][1] + rectMargin, factionRect[i][2] + rectMargin, factionRect[i][3] - rectMargin, factionRect[i][4] - rectMargin, rectMargin, 1, 1, 1, 1, 0)
		glTexture(false)

		-- darken bottom
		RectRound(factionRect[i][1] + rectMargin, factionRect[i][2] + ((factionRect[i][4]-factionRect[i][2])*0.5), factionRect[i][3] - rectMargin, factionRect[i][2] + rectMargin, rectMargin, 2, 2, 0, 0, { 0,0,0, 0 }, { 0,0,0, 0.3 })

		-- gloss
		glBlending(GL_SRC_ALPHA, GL_ONE)
		--RectRound(cellRects[cellRectID][1]+iconPadding, cellRects[cellRectID][4]-iconPadding-(cellInnerSize*0.5), cellRects[cellRectID][3]-iconPadding, cellRects[cellRectID][4]-iconPadding, cellSize*0.03, 1,1,0,0,{1,1,1,0.1}, {1,1,1,0.18})
		RectRound(factionRect[i][1] + rectMargin, factionRect[i][4] - ((factionRect[i][4]-factionRect[i][2])*0.6), factionRect[i][3] - rectMargin, factionRect[i][4] - rectMargin, rectMargin, 2, 2, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.1 })
		RectRound(factionRect[i][1] + rectMargin, factionRect[i][2] + ((factionRect[i][4]-factionRect[i][2])*0.25), factionRect[i][3] - rectMargin, factionRect[i][2] + rectMargin, rectMargin, 2, 2, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.06 })
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

		-- border
		local halfSize = (factionRect[i][3]-factionRect[i][1]-rectMargin-rectMargin) * 0.5
		glBlending(GL_SRC_ALPHA, GL_ONE)
		RectRoundCircle(
				factionRect[i][1] + rectMargin + halfSize,
				0,
				factionRect[i][2] + rectMargin + halfSize,
				halfSize, rectMargin*0.6, halfSize - math.max(1, math.floor(halfSize * 0.04)), { 1, 1, 1, 0.1}, { 1, 1, 1, 0.1 }
		)
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

		-- faction name
		if Spring.GetTeamRulesParam(myTeamID, 'startUnit') == factions[i][1] then
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
				RectRound(factionRect[i][1] + rectMargin, factionRect[i][2] + rectMargin, factionRect[i][3] - rectMargin, factionRect[i][4] - rectMargin, rectMargin, 1, 1, 1, 1, { 0.3, 0.3, 0.3, (b and 0.5 or 0.25) }, { 1, 1, 1, (b and 0.3 or 0.15) })
				glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

				-- border
				local halfSize = (factionRect[i][3]-factionRect[i][1]-rectMargin-rectMargin) * 0.5
				glBlending(GL_SRC_ALPHA, GL_ONE)
				RectRoundCircle(
						factionRect[i][1] + rectMargin + halfSize,
						0,
						factionRect[i][2] + rectMargin + halfSize,
						halfSize, rectMargin*0.6, halfSize - math.max(1, math.floor(halfSize * 0.04)), { 1, 1, 1, 0.1}, { 1, 1, 1, 0.1 }
				)
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
				if WG["buildmenu"] then
					WG["buildmenu"].factionChange(factions[i][1])
				end
				-- tell initial spawn
				Spring.SendLuaRulesMsg('\138' .. tostring(factions[i][1]))
				doUpdate = true
				break
			end
		end
		return true
	end
end
