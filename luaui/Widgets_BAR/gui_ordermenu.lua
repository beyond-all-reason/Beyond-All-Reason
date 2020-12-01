function widget:GetInfo()
	return {
		name = "Order menu",
		desc = "",
		author = "Floris",
		date = "April 2020",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true
	}
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local cellZoom = 1
local cellClickedZoom = 1.1
local cellHoverZoom = 1.045

local altPosition = true

local showIcons = false
local colorize = 0
local playSounds = true
local posY = 0.75
local stickToBottom = false

local alwaysShow = false

local posX = 0
local width = 0
local height = 0
local cellMarginOrg = 0.055
local cellMargin = cellMarginOrg
local bgBorderOrg = 0.0018
local bgBorder = bgBorderOrg
local cmdInfo = {		-- r, g, b, SHORTCUT
	Move = { 0.64, 1, 0.64, 'M'},
	Stop = { 1, 0.3, 0.3, 'S'},
	Attack = { 1, 0.5, 0.35, 'A' },
	['Area attack'] = { 1, 0.35, 0.15, 'A'},
	ManualFire = { 1, 0.7, 0.7, 'D' },
	Patrol = { 0.73, 0.73, 1, 'P'},
	Fight = { 0.9, 0.5, 1, 'F'},
	Resurrect = { 1, 0.75, 1 },
	Guard = { 0.33, 0.92, 1, 'G'},
	Wait = { 0.7, 0.66, 0.6, 'W' },
	Repair = { 1, 0.95, 0.7, 'R'},
	Reclaim = { 0.86, 1, 0.86, 'E'},
	Restore = { 0.77, 1, 0.77 },
	Capture = { 1, 0.85, 0.22 },
	['Set Target'] = { 1, 0.66, 0.35, 'Y'},
	['Cancel Target'] = { 0.8, 0.55, 0.2, 'J'},
	Mex = { 0.93, 0.93, 0.93},
	['Upgrade Mex'] = { 0.93, 0.93, 0.93 },
	['Load units'] = { 0.1, 0.7, 1, 'L' },
	['Unload units'] = { 0, 0.5, 1, 'U'},
	['Land At Airbase'] = { 0.4, 0.7, 0.4 },
	['Cloak State'] = { nil,nil,nil, 'K'},
	['Active state'] = { nil,nil,nil, 'X'},
}
local cmdNameAlternative = {
	['Repeat off'] = 'Repeat',
	['Repeat on'] = 'Repeat',
	['Decloaked'] = 'Cloaked',
	['UpgMex OFF'] = 'Upgrade Mex',
	['UpgMex ON'] = 'Upgrade Mex',
}
local isStateCmd = {}

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local vsx, vsy = Spring.GetViewGeometry()

local fontFile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")

local barGlowCenterTexture = ":l:LuaUI/Images/barglow-center.png"
local barGlowEdgeTexture = ":l:LuaUI/Images/barglow-edge.png"

local sound_button = 'LuaUI/Sounds/buildbar_waypoint.wav'

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity", 0.6) or 0.66)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)
local glossMult = 1 + (2 - (ui_opacity * 2))    -- increase gloss/highlight so when ui is transparant, you can still make out its boundaries and make it less flat

local backgroundRect = {}
local activeRect = {}
local cellRects = {}
local cellMarginPx = 0
local cellMarginPx2 = 0
local cmds = {}
local lastUpdate = os.clock() - 1
local rows = 0
local cols = 0
local disableInput = false

local font, font2, bgpadding, widgetSpaceMargin, chobbyInterface, dlistOrders, dlistGuishader
local clickedCell, clickedCellTime, clickedCellDesiredState, cellWidth, cellHeight
local bpWidth, bpHeight, buildmenuBottomPos, buildpowerWidgetEnabled
local activeCmd, prevActiveCmd, doUpdate, doUpdateClock, SelectedUnitsCount

local hiddencmds = {
	[76] = true, --load units clone
	[65] = true, --selfd
	[9] = true, --gatherwait
	[8] = true, --squadwait
	[7] = true, --deathwait
	[6] = true, --timewait
	[39812] = true, --raw move
	[34922] = true, -- set unit target
	--[34923] = true, -- set target
}

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local spGetActiveCommand = Spring.GetActiveCommand
local spGetActiveCmdDescs = Spring.GetActiveCmdDescs

local string_sub = string.sub
local string_gsub = string.gsub
local os_clock = os.clock

local GL_QUADS = GL.QUADS
local GL_TRIANGLE_FAN = GL.TRIANGLE_FAN
local glBeginEnd = gl.BeginEnd
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glColor = gl.Color
local glRect = gl.Rect
local glVertex = gl.Vertex
local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local math_twicePi = math.pi * 2
local math_cos = math.cos
local math_sin = math.sin
local math_min = math.min
local math_max = math.max
local math_ceil = math.ceil
local math_floor = math.floor

local isSpec = Spring.GetSpectatingState()
local cursorTextures = {}

local function convertColor(r, g, b)
	return string.char(255, (r * 255), (g * 255), (b * 255))
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local function checkGuishader(force)
	if WG['guishader'] then
		if force and dlistGuishader then
			dlistGuishader = gl.DeleteList(dlistGuishader)
		end
		if not dlistGuishader then
			dlistGuishader = gl.CreateList(function()
				RectRound(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], bgpadding * 1.6 * ui_scale)
			end)
		end
	elseif dlistGuishader then
		dlistGuishader = gl.DeleteList(dlistGuishader)
	end
end

function widget:PlayerChanged(playerID)
	isSpec = Spring.GetSpectatingState()
end

local function RefreshCommands()
	local stateCmds = {}
	local otherCmds = {}
	local stateCmdsCount = 0
	local otherCmdsCount = 0
	for index, cmd in pairs(spGetActiveCmdDescs()) do
		if type(cmd) == "table" then
			if cmd.type == 5 then
				isStateCmd[cmd.id] = true
			end
			if not hiddencmds[cmd.id] and cmd.action ~= nil and cmd.type ~= 21 and cmd.type ~= 18 and cmd.type ~= 17 and not cmd.disabled then
				if cmd.type == 20 --build building
					or (string_sub(cmd.action, 1, 10) == 'buildunit_') then

				elseif cmd.type == 5 then
					stateCmdsCount = stateCmdsCount + 1
					stateCmds[stateCmdsCount] = cmd
				else
					otherCmdsCount = otherCmdsCount + 1
					otherCmds[otherCmdsCount] = cmd
				end
			end
		end
	end
	cmds = {}
	for i = 1, stateCmdsCount do
		cmds[i] = stateCmds[i]
	end
	for i = 1, otherCmdsCount do
		cmds[i + stateCmdsCount] = otherCmds[i]
	end

	setupCellGrid()
end

function setupCellGrid(force)
	local oldcols = cols
	local oldRows = rows
	local cmdCount = #cmds
	local addcol = ui_scale < 0.85 and -1 or 0
	local addRow = ui_scale < 0.85 and 0 or 0
	if cmdCount <= (4 + addcol) * (4 + addRow) then
		cols = 4 + addcol
		rows = 4 + addRow
	elseif cmdCount <= (5 + addcol) * (4 + addRow) then
		cols = 5 + addcol
		rows = 4 + addRow
	elseif cmdCount <= (5 + addcol) * (5 + addRow) then
		cols = 5 + addcol
		rows = 5 + addRow
	elseif cmdCount <= (5 + addcol) * (6 + addRow) then
		cols = 5 + addcol
		rows = 6 + addRow
	elseif cmdCount <= (6 + addcol) * (6 + addRow) then
		cols = 6 + addcol
		rows = 6 + addRow
	elseif cmdCount <= (6 + addcol) * (7 + addRow) then
		cols = 6 + addcol
		rows = 7 + addRow
	else
		cols = 7 + addcol
		rows = 7 + addRow
	end

	local sizeDivider = ((cols + rows) / 16)
	cellMargin = (cellMarginOrg / sizeDivider) * ui_scale
	bgBorder = (bgBorderOrg / sizeDivider) * ui_scale

	if minusColumn then
		cols = cols - 1
		rows = rows + 1
	end

	if force or oldcols ~= cols or oldRows ~= rows then
		clickedCell = nil
		clickedCellTime = nil
		clickedCellDesiredState = nil
		cellRects = {}
		local i = 0
		cellWidth = math_floor((activeRect[3] - activeRect[1]) / cols)
		cellHeight = math_floor((activeRect[4] - activeRect[2]) / rows)
		local leftOverWidth = ((activeRect[3] - activeRect[1]) - (cellWidth * cols))-1
		local leftOverHeight = ((activeRect[4] - activeRect[2]) - (cellHeight * rows)) -(posY-height <= 0 and 1 or 0)
		cellMarginPx = math_max(1, math_ceil(cellHeight * 0.5 * cellMargin))
		cellMarginPx2 = math_max(0, math_ceil(cellHeight * 0.18 * cellMargin))

		--cellWidth = math_floor(cellWidth)
		--cellHeight = math_floor(cellHeight)
		local addedWidth = 0
		local addedHeight = 0
		local addedWidthFloat = 0
		local addedHeightFloat = 0
		local prevAddedWidth = 0
		local prevAddedHeight = 0
		for row = 1, rows do
			prevAddedHeight = addedHeight
			addedHeightFloat = addedHeightFloat + (leftOverHeight / rows)
			addedHeight = math_floor(addedHeightFloat)
			prevAddedWidth = 0
			addedWidthFloat = 0
			for col = 1, cols do
				addedWidthFloat = addedWidthFloat + (leftOverWidth / cols)
				addedWidth = math_floor(addedWidthFloat)
				i = i + 1
				cellRects[i] = {
					math_floor(activeRect[1] + prevAddedWidth + (cellWidth * (col - 1)) + 0.5),
					math_floor(activeRect[4] - addedHeight - (cellHeight * row) + 0.5),
					math_ceil(activeRect[1] + addedWidth + (cellWidth * col) + 0.5),
					math_ceil(activeRect[4] - prevAddedHeight - (cellHeight * (row - 1)) + 0.5)
				}
				prevAddedWidth = addedWidth
			end
		end
	end
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

	if WG['buildmenu'] then
		buildmenuBottomPos = WG['buildmenu'].getBottomPosition()
	end

	font2 = WG['fonts'].getFont(fontFile)
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

	backgroundRect = { posX * vsx, (posY - height) * vsy, (posX + width) * vsx, posY * vsy }
	local activeBgpadding = math_floor((bgpadding * 1.4) + 0.5)
	activeRect = {
		(posX * vsx) + (posX > 0 and activeBgpadding or math.ceil(bgpadding * 0.6)),
		((posY - height) * vsy) + (posY-height > 0 and math_floor(activeBgpadding) or math_floor(activeBgpadding / 3)),
		((posX + width) * vsx) - activeBgpadding,
		(posY * vsy) - activeBgpadding
	}
	dlistOrders = gl.DeleteList(dlistOrders)

	checkGuishader(true)

	setupCellGrid(true)
	doUpdate = true
end

function widget:Initialize()

	if WG['minimap'] then
		altPosition = WG['minimap'].getEnlarged()
	end

	widget:ViewResize()
	widget:SelectionChanged()

	WG['ordermenu'] = {}
	WG['ordermenu'].getPosition = function()
		return posX, posY, width, height
	end
	WG['ordermenu'].setBottomPosition = function(value)
		stickToBottom = value
		widget:ViewResize()
	end
	WG['ordermenu'].getAlwaysShow = function()
		return alwaysShow
	end
	WG['ordermenu'].setAlwaysShow = function(value)
		alwaysShow = value
		widget:ViewResize()
	end
	WG['ordermenu'].getBottomPosition = function()
		return stickToBottom
	end
	WG['ordermenu'].getColorize = function()
		return colorize
	end
	WG['ordermenu'].setColorize = function(value)
		doUpdate = true
		colorize = value
		if colorize > 1 then
			colorize = 1
		end
	end
end

function widget:Shutdown()
	if WG['guishader'] and dlistGuishader then
		WG['guishader'].DeleteDlist('ordermenu')
		dlistGuishader = nil
	end
	dlistOrders = gl.DeleteList(dlistOrders)
	WG['ordermenu'] = nil
end

local buildmenuBottomPos = false
local sec = 0
function widget:Update(dt)
	sec = sec + dt
	if sec > 0.5 then
		sec = 0
		checkGuishader()
		if WG['buildpower'] then
			local newBpWidth, newBpHeight = WG['buildpower'].getPosition()
			if bpWidth == nil or (bpWidth ~= newBpWidth or bpHeight ~= newBpHeight) then
				bpWidth, bpHeight = WG['buildpower'].getPosition()
				widget:ViewResize()
			end
		elseif buildpowerWidgetEnabled then
			buildpowerWidgetEnabled = false
			widget:ViewResize()
		end
		if WG['buildmenu'] and WG['buildmenu'].getBottomPosition then
			local prevbuildmenuBottomPos = buildmenuBottomPos
			buildmenuBottomPos = WG['buildmenu'].getBottomPosition()
			if buildmenuBottomPos ~= prevbuildmenuBottomPos then
				widget:ViewResize()
			end
		end
		if ui_scale ~= Spring.GetConfigFloat("ui_scale", 1) then
			ui_scale = Spring.GetConfigFloat("ui_scale", 1)
			widget:ViewResize()
			setupCellGrid(true)
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
			setupCellGrid(true)
			doUpdate = true
		end

		disableInput = isSpec
		if Spring.IsGodModeEnabled() then
			disableInput = false
		end
	end
end

local function DrawRectRound(px, py, sx, sy, cs, tl, tr, br, bl, c1, c2)
	local csyMult = 1 / ((sy - py) / cs)

	if c2 then
		gl.Color(c1[1], c1[2], c1[3], c1[4])
	end
	gl.Vertex(px + cs, py, 0)
	gl.Vertex(sx - cs, py, 0)
	if c2 then
		gl.Color(c2[1], c2[2], c2[3], c2[4])
	end
	gl.Vertex(sx - cs, sy, 0)
	gl.Vertex(px + cs, sy, 0)

	-- left side
	if c2 then
		gl.Color(c1[1] * (1 - csyMult) + (c2[1] * csyMult), c1[2] * (1 - csyMult) + (c2[2] * csyMult), c1[3] * (1 - csyMult) + (c2[3] * csyMult), c1[4] * (1 - csyMult) + (c2[4] * csyMult))
	end
	gl.Vertex(px, py + cs, 0)
	gl.Vertex(px + cs, py + cs, 0)
	if c2 then
		gl.Color(c2[1] * (1 - csyMult) + (c1[1] * csyMult), c2[2] * (1 - csyMult) + (c1[2] * csyMult), c2[3] * (1 - csyMult) + (c1[3] * csyMult), c2[4] * (1 - csyMult) + (c1[4] * csyMult))
	end
	gl.Vertex(px + cs, sy - cs, 0)
	gl.Vertex(px, sy - cs, 0)

	-- right side
	if c2 then
		gl.Color(c1[1] * (1 - csyMult) + (c2[1] * csyMult), c1[2] * (1 - csyMult) + (c2[2] * csyMult), c1[3] * (1 - csyMult) + (c2[3] * csyMult), c1[4] * (1 - csyMult) + (c2[4] * csyMult))
	end
	gl.Vertex(sx, py + cs, 0)
	gl.Vertex(sx - cs, py + cs, 0)
	if c2 then
		gl.Color(c2[1] * (1 - csyMult) + (c1[1] * csyMult), c2[2] * (1 - csyMult) + (c1[2] * csyMult), c2[3] * (1 - csyMult) + (c1[3] * csyMult), c2[4] * (1 - csyMult) + (c1[4] * csyMult))
	end
	gl.Vertex(sx - cs, sy - cs, 0)
	gl.Vertex(sx, sy - cs, 0)

	-- bottom left
	if c2 then
		gl.Color(c1[1], c1[2], c1[3], c1[4])
	end
	if ((py <= 0 or px <= 0) or (bl ~= nil and bl == 0)) and bl ~= 2 then
		gl.Vertex(px, py, 0)
	else
		gl.Vertex(px + cs, py, 0)
	end
	gl.Vertex(px + cs, py, 0)
	if c2 then
		gl.Color(c1[1] * (1 - csyMult) + (c2[1] * csyMult), c1[2] * (1 - csyMult) + (c2[2] * csyMult), c1[3] * (1 - csyMult) + (c2[3] * csyMult), c1[4] * (1 - csyMult) + (c2[4] * csyMult))
	end
	gl.Vertex(px + cs, py + cs, 0)
	gl.Vertex(px, py + cs, 0)
	-- bottom right
	if c2 then
		gl.Color(c1[1], c1[2], c1[3], c1[4])
	end
	if ((py <= 0 or sx >= vsx) or (br ~= nil and br == 0)) and br ~= 2 then
		gl.Vertex(sx, py, 0)
	else
		gl.Vertex(sx - cs, py, 0)
	end
	gl.Vertex(sx - cs, py, 0)
	if c2 then
		gl.Color(c1[1] * (1 - csyMult) + (c2[1] * csyMult), c1[2] * (1 - csyMult) + (c2[2] * csyMult), c1[3] * (1 - csyMult) + (c2[3] * csyMult), c1[4] * (1 - csyMult) + (c2[4] * csyMult))
	end
	gl.Vertex(sx - cs, py + cs, 0)
	gl.Vertex(sx, py + cs, 0)
	-- top left
	if c2 then
		gl.Color(c2[1], c2[2], c2[3], c2[4])
	end
	if ((sy >= vsy or px <= 0) or (tl ~= nil and tl == 0)) and tl ~= 2 then
		gl.Vertex(px, sy, 0)
	else
		gl.Vertex(px + cs, sy, 0)
	end
	gl.Vertex(px + cs, sy, 0)
	if c2 then
		gl.Color(c2[1] * (1 - csyMult) + (c1[1] * csyMult), c2[2] * (1 - csyMult) + (c1[2] * csyMult), c2[3] * (1 - csyMult) + (c1[3] * csyMult), c2[4] * (1 - csyMult) + (c1[4] * csyMult))
	end
	gl.Vertex(px + cs, sy - cs, 0)
	gl.Vertex(px, sy - cs, 0)
	-- top right
	if c2 then
		gl.Color(c2[1], c2[2], c2[3], c2[4])
	end
	if ((sy >= vsy or sx >= vsx) or (tr ~= nil and tr == 0)) and tr ~= 2 then
		gl.Vertex(sx, sy, 0)
	else
		gl.Vertex(sx - cs, sy, 0)
	end
	gl.Vertex(sx - cs, sy, 0)
	if c2 then
		gl.Color(c2[1] * (1 - csyMult) + (c1[1] * csyMult), c2[2] * (1 - csyMult) + (c1[2] * csyMult), c2[3] * (1 - csyMult) + (c1[3] * csyMult), c2[4] * (1 - csyMult) + (c1[4] * csyMult))
	end
	gl.Vertex(sx - cs, sy - cs, 0)
	gl.Vertex(sx, sy - cs, 0)
end
function RectRound(px, py, sx, sy, cs, tl, tr, br, bl, c1, c2)
	-- (coordinates work differently than the RectRound func in other widgets)
	--gl.Texture(false)
	gl.BeginEnd(GL.QUADS, DrawRectRound, px, py, sx, sy, cs, tl, tr, br, bl, c1, c2)
end

local function RectQuad(px, py, sx, sy, offset)
	gl.TexCoord(offset, 1 - offset)
	gl.Vertex(px, py, 0)
	gl.TexCoord(1 - offset, 1 - offset)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(1 - offset, offset)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(offset, offset)
	gl.Vertex(px, sy, 0)
end
function DrawRect(px, py, sx, sy, zoom)
	gl.BeginEnd(GL.QUADS, RectQuad, px, py, sx, sy, zoom)
end

function IsOnRect(x, y, BLcornerX, BLcornerY, TRcornerX, TRcornerY)
	return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
end

local function DrawCircle(x, y, z, radius, sides, color1, color2)
	if not color2 then
		color2 = color1
	end
	local sideAngle = math_twicePi / sides
	glColor(color1)
	glVertex(x, z, y)
	glColor(color2)
	for i = 1, sides + 1 do
		local cx = x + (radius * math_cos(i * sideAngle))
		local cz = z + (radius * math_sin(i * sideAngle))
		glVertex(cx, cz, y)
	end
end

local function doCircle(x, y, z, radius, sides, color1, color2)
	glBeginEnd(GL_TRIANGLE_FAN, DrawCircle, x, 0, z, radius, sides, color1, color2)
end

function drawCell(cell, zoom)
	if not zoom then
		zoom = 1
	end

	local cmd = cmds[cell]
	if cmd then
		local leftMargin = cellMarginPx
		local rightMargin = cellMarginPx2
		local topMargin = cellMarginPx
		local bottomMargin = cellMarginPx2
		local yFirstMargin = cell % rows == 1 and rightMargin or leftMargin
		if cell % cols == 1 then
			leftMargin = cellMarginPx2
		end
		if cell % cols == 0 then
			rightMargin = cellMarginPx2
		end
		if cols/cell >= 1  then
			topMargin = math_floor(((cellMarginPx + cellMarginPx2) / 2) + 0.5)
		end
		--if cols/cell < 1/(cols-1) then
		--  bottomMargin = cellMarginPx2
		--end

		local cellInnerWidth = math_floor(((cellRects[cell][3] - rightMargin) - (cellRects[cell][1] + leftMargin)) + 0.5)
		local cellInnerHeight = math_floor(((cellRects[cell][4] - topMargin) - (cellRects[cell][2] + bottomMargin)) + 0.5)

		local isActiveCmd = (activeCmd == cmd.name)
		-- order button background
		local color1, color2
		if isActiveCmd then
			zoom = cellClickedZoom
			color1 = { 0.66, 0.66, 0.66, 0.95 }
			color2 = { 1, 1, 1, 0.95 }
		else
			if WG['guishader'] then
				color1 = (cmd.type == 5) and { 0.4, 0.4, 0.4, math_max(0.35, math_min(0.55, ui_opacity/1.5)) } or { 0.6, 0.6, 0.6, math_max(0.35, math_min(0.55, ui_opacity/1.5)) }
				color2 = { 0.8, 0.8, 0.8, math_max(0.35, math_min(0.6, ui_opacity/1.4)) }
			else
				color1 = (cmd.type == 5) and { 0.25, 0.25, 0.25, 1 } or { 0.33, 0.33, 0.33, 1 }
				color2 = { 0.8, 0.8, 0.8, math_max(0.35, math_min(0.6, ui_opacity/1.4)) }
			end
			RectRound(cellRects[cell][1] + leftMargin, cellRects[cell][2] + bottomMargin, cellRects[cell][3] - rightMargin, cellRects[cell][4] - topMargin, cellWidth * 0.025, 2, 2, 2, 2, color1, color2)

			color1 = { 0, 0, 0, 0.8 }
			color2 = { 0, 0, 0, 0.6 }
		end

		local padding = math_max(1, math_floor(bgpadding * 0.52))
		if padding == 1 then	-- make border less harch
			RectRound(cellRects[cell][1] + leftMargin + padding + padding, cellRects[cell][2] + bottomMargin + padding + padding, cellRects[cell][3] - rightMargin - padding - padding, cellRects[cell][4] - topMargin - padding - padding, cellWidth * 0.008, 2, 2, 2, 2, {color1[1],color1[2],color1[3],color1[4]*math_min(0.55, ui_opacity)}, {color2[1],color2[2],color2[3],color2[4]*math_min(0.55, ui_opacity)})
		end
		RectRound(cellRects[cell][1] + leftMargin + padding, cellRects[cell][2] + bottomMargin + padding, cellRects[cell][3] - rightMargin - padding, cellRects[cell][4] - topMargin - padding, cellWidth * 0.017, 2, 2, 2, 2, {color1[1],color1[2],color1[3],color2[4]*(padding>1 and 1 or ui_opacity+0.25)}, {color2[1],color2[2],color2[3],color2[4]*(padding>1 and 1 or ui_opacity+0.25)})

		-- gloss
		RectRound(cellRects[cell][1] + leftMargin + padding, cellRects[cell][4] - topMargin - ((cellRects[cell][4] - cellRects[cell][2]) * 0.42) - padding, cellRects[cell][3] - rightMargin - padding, (cellRects[cell][4] - topMargin) - padding, cellWidth * 0.017, 2, 2, 0, 0, { 1, 1, 1, 0.03 }, { 1, 1, 1, 0.09 })
		RectRound(cellRects[cell][1] + leftMargin + padding, cellRects[cell][2] + bottomMargin + padding, cellRects[cell][3] - rightMargin - padding, (cellRects[cell][2] - leftMargin) + ((cellRects[cell][4] - cellRects[cell][2]) * 0.5) - padding, cellWidth * 0.017, 0, 0, 2, 2, { 1, 1, 1, 0.07 }, { 1, 1, 1, 0 })

		-- icon
		if showIcons then
			if cursorTextures[cmd.cursor] == nil then
				local cursorTexture = 'anims/icexuick_200/cursor' .. string.lower(cmd.cursor) .. '_0.png'
				cursorTextures[cmd.cursor] = VFS.FileExists(cursorTexture) and cursorTexture or false
			end
			if cursorTextures[cmd.cursor] then
				local cursorTexture = 'anims/icexuick_200/cursor' .. string.lower(cmd.cursor) .. '_0.png'
				if VFS.FileExists(cursorTexture) then
					local s = 0.45
					local halfsize = s * ((cellRects[cell][4] - topMargin - padding) - (cellRects[cell][2] + bottomMargin + padding))
					--local midPosX = (cellRects[cell][3]-leftMargin-padding) - halfsize - (halfsize*((1-s-s)/2))
					--local midPosY = (cellRects[cell][4]-topMargin-padding) - (((cellRects[cell][4]-topMargin-padding)-(cellRects[cell][2]+bottomMargin+padding)) / 2)
					local midPosX = (cellRects[cell][3] - rightMargin - padding) - (((cellRects[cell][3] - rightMargin - padding) - (cellRects[cell][1] + leftMargin + padding)) / 2)
					local midPosY = (cellRects[cell][4] - topMargin - padding) - (((cellRects[cell][4] - topMargin - padding) - (cellRects[cell][2] + bottomMargin + padding)) / 2)
					glColor(1, 1, 1, 0.66)
					glTexture('' .. cursorTexture)
					glTexRect(midPosX - halfsize, midPosY - halfsize, midPosX + halfsize, midPosY + halfsize)
					glTexture(false)
				end
			end
		end

		-- text
		if not showIcons or not cursorTextures[cmd.cursor] then
			local text = string_gsub(cmd.name, "\n", " ")
			if cmd.params[1] and cmd.params[cmd.params[1] + 2] then
				text = cmd.params[cmd.params[1] + 2]
			end
			if cmdNameAlternative[text] then
				text = cmdNameAlternative[text]
			end
			local fontSize = cellInnerWidth / font2:GetTextWidth('  ' .. text .. ' ') * math_min(1, (cellInnerHeight / (rows * 6)))
			if fontSize > cellInnerWidth / 6.3 then
				fontSize = cellInnerWidth / 6.3
			end
			fontSize = fontSize * zoom
			local fontHeight = font2:GetTextHeight(text) * fontSize
			local fontHeightOffset = fontHeight * 0.34
			if cmd.type == 5 then
				-- state cmds (fire at will, etc)
				fontHeightOffset = fontHeight * 0.22
			end
			local textColor = "\255\233\233\233"
			if colorize > 0 and cmdInfo[cmd.name] and cmdInfo[cmd.name][1] then
				local part = (1 / colorize)
				local grey = (0.93 * (part - 1))
				textColor = convertColor((grey + cmdInfo[cmd.name][1]) / part, (grey + cmdInfo[cmd.name][2]) / part, (grey + cmdInfo[cmd.name][3]) / part)
			end
			if isActiveCmd then
				textColor = "\255\020\020\020"
			end
			font2:Print(textColor .. text, cellRects[cell][1] + ((cellRects[cell][3] - cellRects[cell][1]) / 2), (cellRects[cell][2] - ((cellRects[cell][2] - cellRects[cell][4]) / 2) - fontHeightOffset), fontSize, "con")
		end

		-- state lights
		if cmd.type == 5 then
			-- state cmds (fire at will, etc)

			local statecount = #cmd.params - 1 --number of states for the cmd
			local curstate = cmd.params[1] + 1
			local desiredState = nil
			if clickedCellDesiredState and cell == clickedCell then
				desiredState = clickedCellDesiredState + 1
			end
			if curstate == desiredState then
				clickedCellDesiredState = nil
				desiredState = nil
			end
			local stateWidth = cellInnerWidth / statecount
			local stateHeight = math_floor(cellInnerHeight * 0.14)
			local stateMargin = math_floor((stateWidth * 0.075) + 0.5)
			local glowSize = math_floor(stateHeight * 8)
			local r, g, b, a = 0, 0, 0, 0
			for i = 1, statecount do
				if i == curstate or i == desiredState then
					if i == 1 then
						r, g, b, a = 1, 0.1, 0.1, (i == desiredState and 0.33 or 0.8)
					elseif i == 2 then
						if statecount == 2 then
							r, g, b, a = 0.1, 1, 0.1, (i == desiredState and 0.22 or 0.8)
						else
							r, g, b, a = 1, 1, 0.1, (i == desiredState and 0.22 or 0.8)
						end
					else
						r, g, b, a = 0.1, 1, 0.1, (i == desiredState and 0.26 or 0.8)
					end
				else
					r, g, b, a = 0, 0, 0, 0.36  -- default off state
				end
				glColor(r, g, b, a)
				local x1 = math_floor(cellRects[cell][1] + leftMargin + padding + (stateWidth * (i - 1)) + (i == 1 and 0 or stateMargin))
				local y1 = math_floor(cellRects[cell][2] + bottomMargin + padding)
				local x2 = math_ceil(cellRects[cell][3] - rightMargin - padding - (stateWidth * (statecount - i)) - (i == statecount and 0 or stateMargin))
				local y2 = math_ceil(cellRects[cell][2] + bottomMargin + stateHeight)
				-- fancy fitting rectrounds
				if rows < 6 then
					RectRound(x1, y1, x2, y2, stateHeight * 0.33,
						(i == 1 and 0 or 2), (i == statecount and 0 or 2), (i == statecount and 2 or 0), (i == 1 and 2 or 0))
				else
					glRect(x1, y1, x2, y2)
				end
				-- fancy active state glow
				if rows < 6 and i == curstate then
					glBlending(GL_SRC_ALPHA, GL_ONE)
					glColor(r, g, b, 0.09)
					glTexture(barGlowCenterTexture)
					DrawRect(x1, y1 - glowSize, x2, y2 + glowSize, 0.008)
					glTexture(barGlowEdgeTexture)
					DrawRect(x1 - (glowSize * 2), y1 - glowSize, x1, y2 + glowSize, 0.008)
					DrawRect(x2 + (glowSize * 2), y1 - glowSize, x2, y2 + glowSize, 0.008)
					glTexture(false)
					glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
				end
			end
		end
	end
end

function drawOrders()
	-- just making sure blending mode is correct
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

	-- background
	RectRound(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], bgpadding * 1.6, 1, 1, 1, 1, { 0.05, 0.05, 0.05, ui_opacity }, { 0, 0, 0, ui_opacity })
	RectRound(backgroundRect[1] + (posX > 0 and bgpadding or 0), backgroundRect[2] + bgpadding, backgroundRect[3] - bgpadding, backgroundRect[4] - bgpadding, bgpadding, (posX > 0 and 1 or 0), 1, 1, 0, { 0.3, 0.3, 0.3, ui_opacity * 0.1 }, { 1, 1, 1, ui_opacity * 0.1 })

	-- gloss
	glBlending(GL_SRC_ALPHA, GL_ONE)
	RectRound(
		backgroundRect[1] + (posX > 0 and bgpadding or 0),
		backgroundRect[4] - ((backgroundRect[4] - backgroundRect[2]) * 0.16),
		backgroundRect[3] - bgpadding, backgroundRect[4] - bgpadding,
		bgpadding,
		(posX > 0 and 1 or 0), 1, 0, 0,
		{ 1, 1, 1, 0.006 * glossMult }, { 1, 1, 1, 0.055 * glossMult }
	)
	RectRound(
		backgroundRect[1] + (posX > 0 and bgpadding or 0),
		backgroundRect[2] + (posY-height > 0 and bgpadding or 0),
		backgroundRect[3] - bgpadding, backgroundRect[2] + ((backgroundRect[4] - backgroundRect[2]) * 0.15),
		bgpadding,
		0, 0, (posY > 0 and 1 or 0), 0,
		{ 1, 1, 1, 0.025 * glossMult }, { 1, 1, 1, 0 }
	)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

	--RectRound(activeRect[1], activeRect[2], activeRect[3], activeRect[4], 0, 0,0,0,0, {1,0,1,0.5}, {1,0,1,0.5})
	if #cmds > 0 then
		font2:Begin()
		for cell = 1, #cmds do
			drawCell(cell, cellZoom)
		end
		font2:End()
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

local clickCountDown = 2
function widget:DrawScreen()
	if chobbyInterface then
		return
	end
	clickCountDown = clickCountDown - 1
	if clickCountDown == 0 then
		doUpdate = true
	end
	prevActiveCmd = activeCmd
	activeCmd = select(4, spGetActiveCommand())
	if activeCmd ~= prevActiveCmd then
		doUpdate = true
	end

	local x, y, b = Spring.GetMouseState()
	local cellHovered
	if not WG['topbar'] or not WG['topbar'].showingQuit() then
		if IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
			Spring.SetMouseCursor('cursornormal')
			for cell = 1, #cellRects do
				if cmds[cell] then
					if IsOnRect(x, y, cellRects[cell][1], cellRects[cell][2], cellRects[cell][3], cellRects[cell][4]) then
						local cmd = cmds[cell]
						if WG['tooltip'] and cmd.tooltip then
							--Spring.Echo(cmd.name)
							if cmdInfo[cmd.name] and cmdInfo[cmd.name][4] then
								WG['tooltip'].ShowTooltip('ordermenu', '\255\255\215\100'..cmdInfo[cmd.name][4]..'\255\240\240\240 - '..cmd.tooltip)
							else
								WG['tooltip'].ShowTooltip('ordermenu', cmd.tooltip)
							end
						end
						cellHovered = cell
					end
				else
					break
				end
			end
		end
	end

	-- make all cmd's fit in the grid
	local now = os_clock()
	if doUpdate or (doUpdateClock and now >= doUpdateClock) then
		if doUpdateClock and now >= doUpdateClock then
			doUpdateClock = nil
			doUpdate = true
		end
		doUpdateClock = nil
		lastUpdate = now
		RefreshCommands()
	end

	if #cmds == 0 and not alwaysShow then
		if dlistGuishader and WG['guishader'] then
			WG['guishader'].RemoveDlist('ordermenu')
		end
	else
		if dlistGuishader and WG['guishader'] then
			WG['guishader'].InsertDlist(dlistGuishader, 'ordermenu')
		end
		if doUpdate then
			dlistOrders = gl.DeleteList(dlistOrders)
		end
		if not dlistOrders then
			dlistOrders = gl.CreateList(function()
				drawOrders()
			end)
		end

		gl.CallList(dlistOrders)

		if #cmds >0 then
			-- draw highlight on top of button
			if not WG['topbar'] or not WG['topbar'].showingQuit() then
				if cmds and cellHovered then
					local cell = cellHovered
					if cellRects[cell] and cellRects[cell][4] then
						drawCell(cell, cellHoverZoom)

						local pad = 0
						local colorMult = 1
						if cmds[cell] and activeCmd == cmds[cell].name then
							pad = (bgBorder * vsy) * 0.35
							colorMult = 0.4
						end

						local leftMargin = cellMarginPx
						local rightMargin = cellMarginPx2
						local topMargin = cellMarginPx
						local bottomMargin = cellMarginPx2
						local yFirstMargin = cell % rows == 1 and rightMargin or leftMargin
						if cell % cols == 1 then
							leftMargin = cellMarginPx2
						end
						if cell % cols == 0 then
							rightMargin = cellMarginPx2
						end
						if cols/cell >= 1  then
							topMargin = math_floor(((cellMarginPx + cellMarginPx2) / 2) + 0.5)
						end
						--if cols/cell < 1/(cols-1) then
						--  bottomMargin = cellMarginPx2
						--end

						-- gloss highlight
						glBlending(GL_SRC_ALPHA, GL_ONE)
						RectRound(cellRects[cell][1] + leftMargin + pad, cellRects[cell][4] - topMargin - bgpadding - pad - ((cellRects[cell][4] - cellRects[cell][2]) * 0.42), cellRects[cell][3] - rightMargin, (cellRects[cell][4] - topMargin - pad), cellWidth * 0.025, 2, 2, 0, 0, { 1, 1, 1, 0.035 * colorMult }, { 1, 1, 1, (disableInput and 0.11 * colorMult or 0.24 * colorMult) })
						RectRound(cellRects[cell][1] + leftMargin + pad, cellRects[cell][2] + bottomMargin + pad, cellRects[cell][3] - rightMargin - pad, (cellRects[cell][2] - bottomMargin - pad) + ((cellRects[cell][4] - cellRects[cell][2]) * 0.5), cellWidth * 0.025, 0, 0, 2, 2, { 1, 1, 1, (disableInput and 0.035 * colorMult or 0.075 * colorMult) }, { 1, 1, 1, 0 })
						glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
					end
				end
			end

			-- clicked cell effect
			if clickedCellTime and cmds[clickedCell] then
				local cell = clickedCell
				if cellRects[cell] and cellRects[cell][4] then
					local isActiveCmd = (cmds[cell].name == activeCmd)
					local padding = (bgBorder * vsy) * 0.5
					local duration = 0.33
					if isActiveCmd then
						duration = 0.45
					elseif cmds[clickedCell].type == 5 then
						duration = 0.6
					end
					local alpha = 0.33 - ((now - clickedCellTime) / duration)
					if alpha > 0 then
						if isActiveCmd then
							glColor(0, 0, 0, alpha)
						else
							glBlending(GL_SRC_ALPHA, GL_ONE)
							glColor(1, 1, 1, alpha)
						end
						RectRound(cellRects[cell][1] + cellMarginPx, cellRects[cell][2] + cellMarginPx, cellRects[cell][3] - cellMarginPx2, (cellRects[cell][4] - cellMarginPx2), cellWidth * 0.025, 2, 2, 2, 2)
					else
						clickedCellTime = nil
					end
					glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
				end
			end
		end
	end
	doUpdate = nil
end

function widget:MousePress(x, y, button)
	if Spring.IsGUIHidden() then
		return
	end
	if IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
		if #cmds > 0 then
			if not disableInput then
				for cell = 1, #cellRects do
					local cmd = cmds[cell]
					if cmd then
						if IsOnRect(x, y, cellRects[cell][1], cellRects[cell][2], cellRects[cell][3], cellRects[cell][4]) then
							clickCountDown = 2
							clickedCell = cell
							clickedCellTime = os_clock()

							-- remember desired state: only works for a single cell at a time, because there is no way to re-identify a cell when the selection changes
							if cmd.type == 5 then
								if button == 1 then
									clickedCellDesiredState = cmd.params[1] + 1
									if clickedCellDesiredState >= #cmd.params - 1 then
										clickedCellDesiredState = 0
									end
								else
									clickedCellDesiredState = cmd.params[1] - 1
									if clickedCellDesiredState < 0 then
										clickedCellDesiredState = #cmd.params - 1
									end
								end
								doUpdate = true
							end

							if playSounds then
								Spring.PlaySoundFile(sound_button, 0.6, 'ui')
							end
							if cmd.id and Spring.GetCmdDescIndex(cmd.id) then
								Spring.SetActiveCommand(Spring.GetCmdDescIndex(cmd.id), button, true, false, Spring.GetModKeyState())
							end
							break
						end
					else
						break
					end
				end
			end
			return true
		elseif alwaysShow then
			return true
		end
	end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdOpts, cmdParams, cmdTag)
	if isStateCmd[cmdID] then
		if not hiddencmds[cmdID] and doUpdateClock == nil then
			doUpdateClock = os_clock() + 0.01
		end
	end
end

function widget:SelectionChanged(sel)
	SelectedUnitsCount = spGetSelectedUnitsCount()
	clickCountDown = 2
end

function widget:GetConfigData()
	--save config
	return { colorize = colorize, stickToBottom = stickToBottom, alwaysShow = alwaysShow}
end

function widget:SetConfigData(data)
	--load config
	if data.colorize ~= nil then
		colorize = data.colorize
	end
	if data.stickToBottom ~= nil then
		stickToBottom = data.stickToBottom
	end
	if data.alwaysShow ~= nil then
		alwaysShow = data.alwaysShow
	end
end
