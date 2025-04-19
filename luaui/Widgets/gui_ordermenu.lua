local widget = widget ---@type Widget

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

local useRenderToTexture = Spring.GetConfigFloat("ui_rendertotexture", 0) == 1		-- much faster than drawing via DisplayLists only

local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")
local currentLayout

local cellZoom = 1
local cellClickedZoom = 1.05
local cellHoverZoom = 1.035

local showIcons = false
local colorize = 0
local playSounds = true
local stickToBottom = true
local alwaysShow = false

local posX = 0
local posY = 0.8
local width = 0
local height = 0
local cellMarginOriginal = 0.055
local cellMargin = cellMarginOriginal
local commandInfo = {
	move			= { red = 0.64,	green = 1,		blue = 0.64 },
	stop			= { red = 1,	green = 0.3,	blue = 0.3 },
	attack			= { red = 1,	green = 0.5,	blue = 0.35 },
	areaattack		= { red = 1,	green = 0.35,	blue = 0.15 },
	manualfire		= { red = 1,	green = 0.7,	blue = 0.7 },
	patrol			= { red = 0.73,	green = 0.73,	blue = 1 },
	fight			= { red = 0.9,	green = 0.5,	blue = 1 },
	resurrect		= { red = 1,	green = 0.75,	blue = 1, },
	guard			= { red = 0.33,	green = 0.92,	blue = 1 },
	wait			= { red = 0.7,	green = 0.66,	blue = 0.6 },
	repair			= { red = 1,	green = 0.95,	blue = 0.7 },
	reclaim			= { red = 0.86,	green = 1,		blue = 0.86 },
	restore			= { red = 0.77,	green = 1,		blue = 0.77 },
	capture			= { red = 1,	green = 0.85,	blue = 0.22 },
	settarget		= { red = 1,	green = 0.66,	blue = 0.35 },
	canceltarget	= { red = 0.8,	green = 0.55,	blue = 0.2 },
	areamex			= { red = 0.93,	green = 0.93,	blue = 0.93 },
	upgrademex		= { red = 0.93,	green = 0.93,	blue = 0.93 },
	loadunits		= { red = 0.1,	green = 0.7,	blue = 1 },
	unloadunits		= { red = 0,	green = 0.5,	blue = 1 },
	landatairbase	= { red = 0.4,	green = 0.7,	blue = 0.4 },
	wantcloak		= { red = nil,	green = nil,	blue = nil },
	onoff			= { red = nil,	green = nil,	blue = nil },
	sellunit		= { red = nil,	green = nil,	blue = nil },
}
local isStateCommand = {}

local disabledCommand = {}

local viewSizeX, viewSizeY = Spring.GetViewGeometry()

local fontFile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")

local barGlowCenterTexture = ":l:LuaUI/Images/barglow-center.png"
local barGlowEdgeTexture = ":l:LuaUI/Images/barglow-edge.png"

local soundButton = 'LuaUI/Sounds/buildbar_waypoint.wav'

local uiOpacity = Spring.GetConfigFloat("ui_opacity", 0.7)
local uiScale = Spring.GetConfigFloat("ui_scale", 1)

local backgroundRect = {}
local activeRect = {}
local cellRects = {}
local cellMarginPx = 0
local cellMarginPx2 = 0
local commands = {}
local rows = 0
local cols = 0
local disableInput = false
local math_isInRect = math.isInRect
local clickCountDown = 2

local font, backgroundPadding, widgetSpaceMargin, displayListOrders, displayListGuiShader
local clickedCell, clickedCellTime, clickedCellDesiredState, cellWidth, cellHeight
local buildmenuBottomPosition
local activeCommand, previousActiveCommand, doUpdate, doUpdateClock
local ordermenuShows = false

local hiddenCommands = {
	[CMD.LOAD_ONTO] = true,
	[CMD.SELFD] = true,
	[CMD.GATHERWAIT] = true,
	[CMD.SQUADWAIT] = true,
	[CMD.DEATHWAIT] = true,
	[CMD.TIMEWAIT] = true,
	[39812] = true, -- raw move
	[34922] = true, -- set unit target
}

local hiddenCommandTypes = {
	[CMDTYPE.CUSTOM] = true,
	[CMDTYPE.PREV] = true,
	[CMDTYPE.NEXT] = true,
}

local CMDTYPE_ICON_BUILDING = CMDTYPE.ICON_BUILDING
local CMDTYPE_ICON_MODE = CMDTYPE.ICON_MODE

local spGetActiveCommand = Spring.GetActiveCommand
local spGetActiveCmdDescs = Spring.GetActiveCmdDescs

local os_clock = os.clock

local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glColor = gl.Color
local glRect = gl.Rect
local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local math_min = math.min
local math_max = math.max
local math_clamp = math.clamp
local math_ceil = math.ceil
local math_floor = math.floor

local RectRound, UiElement, UiButton, elementCorner

local isSpectating = Spring.GetSpectatingState()
local cursorTextures = {}
local actionHotkeys

local isFactory = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isFactory then
		isFactory[unitDefID] = true
	end
end

local function convertColor(r, g, b)
	return string.char(255, (r * 255), (g * 255), (b * 255))
end

local function checkGuiShader(force)
	if WG['guishader'] then
		if force and displayListGuiShader then
			displayListGuiShader = gl.DeleteList(displayListGuiShader)
		end
		if not displayListGuiShader then
			displayListGuiShader = gl.CreateList(function()
				RectRound(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], elementCorner * uiScale, ((posX <= 0) and 0 or 1), 1, ((posY-height > 0 or posX <= 0) and 1 or 0), ((posY-height > 0 and posX > 0) and 1 or 0))
			end)
		end
	elseif displayListGuiShader then
		displayListGuiShader = gl.DeleteList(displayListGuiShader)
	end
end

function widget:PlayerChanged(playerID)
	isSpectating = Spring.GetSpectatingState()
end

local function setupCellGrid(force)
	local oldCols = cols
	local oldRows = rows
	local cmdCount = #commands
	local addCol = uiScale < 0.85 and -1 or 0
	local addRow = uiScale < 0.85 and 0 or 0
	if cmdCount <= (4 + addCol) * (4 + addRow) then
		cols = 4 + addCol
		rows = 4 + addRow
	elseif cmdCount <= (5 + addCol) * (4 + addRow) then
		cols = 5 + addCol
		rows = 4 + addRow
	elseif cmdCount <= (5 + addCol) * (5 + addRow) then
		cols = 5 + addCol
		rows = 5 + addRow
	elseif cmdCount <= (5 + addCol) * (6 + addRow) then
		cols = 5 + addCol
		rows = 6 + addRow
	elseif cmdCount <= (6 + addCol) * (6 + addRow) then
		cols = 6 + addCol
		rows = 6 + addRow
	elseif cmdCount <= (6 + addCol) * (7 + addRow) then
		cols = 6 + addCol
		rows = 7 + addRow
	else
		cols = 7 + addCol
		rows = 7 + addRow
	end

	local sizeDivider = ((cols + rows) / 16)
	cellMargin = (cellMarginOriginal / sizeDivider) * uiScale

	if force or oldCols ~= cols or oldRows ~= rows then
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

local function refreshCommands()
	local waitCommand
	local stateCommands = {}
	local otherCommands = {}
	local stateCommandsCount = 0
	local waitCommandCount = 0
	local otherCommandsCount = 0
	local activeCmdDescs = spGetActiveCmdDescs()
	for _, command in ipairs(activeCmdDescs) do
		if type(command) == "table" and not disabledCommand[command.name] then
			if command.type == CMDTYPE_ICON_MODE then
				isStateCommand[command.id] = true
			end
			if not hiddenCommands[command.id] and not hiddenCommandTypes[command.type] and command.action ~= nil and not command.disabled then
				if command.type == CMDTYPE_ICON_BUILDING or (string.sub(command.action, 1, 10) == 'buildunit_') then
					-- intentionally empty, no action to take
				elseif isStateCommand[command.id] then
					stateCommandsCount = stateCommandsCount + 1
					stateCommands[stateCommandsCount] = command
				elseif command.id == CMD.WAIT then
					waitCommandCount = 1
					waitCommand = command
				else
					otherCommandsCount = otherCommandsCount + 1
					otherCommands[otherCommandsCount] = command
				end
			end
		end
	end
	commands = {}
	for i = 1, stateCommandsCount do
		commands[i] = stateCommands[i]
	end
	if waitCommand then
		commands[1 + stateCommandsCount] = waitCommand
	end
	for i = 1, otherCommandsCount do
		commands[i + stateCommandsCount + waitCommandCount] = otherCommands[i]
	end

	setupCellGrid(false)
end

function widget:ViewResize()
	viewSizeX, viewSizeY = Spring.GetViewGeometry()

	width = 0.2125
	height = 0.14 * uiScale

	width = width / (viewSizeX / viewSizeY) * 1.78        -- make smaller for ultrawide screens
	width = width * uiScale

	-- make pixel aligned
	width = math.floor(width * viewSizeX) / viewSizeX
	height = math.floor(height * viewSizeY) / viewSizeY

	if WG['buildmenu'] then
		buildmenuBottomPosition = WG['buildmenu'].getBottomPosition()
	end

	font = WG['fonts'].getFont(fontFile, 1.1 * (useRenderToTexture and 1.6 or 1), 0.18 * (useRenderToTexture and 1.4 or 1), useRenderToTexture and 2 or 1.25)

	elementCorner = WG.FlowUI.elementCorner
	backgroundPadding = WG.FlowUI.elementPadding

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiButton = WG.FlowUI.Draw.Button
	elementCorner = WG.FlowUI.elementCorner

	widgetSpaceMargin = WG.FlowUI.elementMargin

	if WG['minimap'] then
		minimapHeight = WG['minimap'].getHeight()
	end
	if stickToBottom then
		posY = height
		posX = width + (widgetSpaceMargin/viewSizeX)
	else
		if buildmenuBottomPosition then
			posX = 0
			posY = height + height + (widgetSpaceMargin/viewSizeY)
		elseif WG['buildmenu'] then
			local posY2, _ = WG['buildmenu'].getSize()
			posY2 = posY2 + (widgetSpaceMargin/viewSizeY)
			posY = posY2 + height
			if WG['minimap'] then
				posY = 1 - (minimapHeight / viewSizeY) - (widgetSpaceMargin/viewSizeY)
			end
			posX = 0
		end
	end

	backgroundRect = { posX * viewSizeX, (posY - height) * viewSizeY, (posX + width) * viewSizeX, posY * viewSizeY }
	local activeBgpadding = math_floor((backgroundPadding * 1.4) + 0.5)
	activeRect = {
		(posX * viewSizeX) + (posX > 0 and activeBgpadding or math.ceil(backgroundPadding * 0.6)),
		((posY - height) * viewSizeY) + (posY-height > 0 and math_floor(activeBgpadding) or math_floor(activeBgpadding / 3)),
		((posX + width) * viewSizeX) - activeBgpadding,
		(posY * viewSizeY) - activeBgpadding
	}
	displayListOrders = gl.DeleteList(displayListOrders)

	checkGuiShader(true)
	setupCellGrid(true)
	doUpdate = true

	if ordermenuTex then
		gl.DeleteTextureFBO(ordermenuBgTex)
		ordermenuBgTex = nil
		gl.DeleteTextureFBO(ordermenuTex)
		ordermenuTex = nil
	end
end

local function reloadBindings()
	currentLayout = Spring.GetConfigString("KeyboardLayout", "qwerty")
	actionHotkeys = VFS.Include("luaui/Include/action_hotkeys.lua")
end

function widget:Initialize()
	reloadBindings()
	widget:ViewResize()
	widget:SelectionChanged()

	WG['ordermenu'] = {}
	WG['ordermenu'].getPosition = function()
		return posX, posY, width, height
	end
	WG['ordermenu'].reloadBindings = reloadBindings
	WG['ordermenu'].setBottomPosition = function(value)
		stickToBottom = value
		doUpdate = true
	end
	WG['ordermenu'].getAlwaysShow = function()
		return alwaysShow
	end
	WG['ordermenu'].setAlwaysShow = function(value)
		alwaysShow = value
		doUpdate = true
	end
	WG['ordermenu'].getBottomPosition = function()
		return stickToBottom
	end
	WG['ordermenu'].getDisabledCmd = function(cmd)
		return disabledCommand[cmd]
	end
	WG['ordermenu'].setDisabledCmd = function(params)
		if params[2] then
			disabledCommand[params[1]] = true
		else
			disabledCommand[params[1]] = nil
		end
		doUpdate = true
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
	WG['ordermenu'].getIsShowing = function()
		return ordermenuShows
	end
end

function widget:Shutdown()
	if WG['guishader'] and displayListGuiShader then
		WG['guishader'].DeleteDlist('ordermenu')
		displayListGuiShader = nil
	end
	displayListOrders = gl.DeleteList(displayListOrders)
	if ordermenuTex then
		gl.DeleteTextureFBO(ordermenuBgTex)
		ordermenuBgTex = nil
		gl.DeleteTextureFBO(ordermenuTex)
		ordermenuTex = nil
	end
	WG['ordermenu'] = nil
end

local buildmenuBottomPos = false
local sec = 0
function widget:Update(dt)
	ordermenuShows = false

	sec = sec + dt
	if sec > 0.5 then
		sec = 0
		checkGuiShader()

		if WG['buildmenu'] and WG['buildmenu'].getBottomPosition then
			local prevbuildmenuBottomPos = buildmenuBottomPos
			buildmenuBottomPos = WG['buildmenu'].getBottomPosition()
			if buildmenuBottomPos ~= prevbuildmenuBottomPos then
				widget:ViewResize()
			end
		end

		if WG['minimap'] and minimapHeight ~= WG['minimap'].getHeight() then
			widget:ViewResize()
			setupCellGrid(true)
			doUpdate = true
		end

		disableInput = isSpectating
		if Spring.IsGodModeEnabled() then
			disableInput = false
		end
	end

	clickCountDown = clickCountDown - 1
	if clickCountDown == 0 then
		doUpdate = true
	end
	previousActiveCommand = activeCommand
	activeCommand = select(4, spGetActiveCommand())
	if activeCommand ~= previousActiveCommand then
		doUpdate = true
	end

	if (WG['guishader'] and not displayListGuiShader) or (#commands == 0 and (not alwaysShow or Spring.GetGameFrame() == 0)) then
		ordermenuShows = false
	else
		ordermenuShows = true
	end
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
local function DrawRect(px, py, sx, sy, zoom)
	gl.BeginEnd(GL.QUADS, RectQuad, px, py, sx, sy, zoom)
end


local function drawCell(cell, zoom)
	if not zoom then
		zoom = 1
	end

	local cmd = commands[cell]
	if cmd then
		local leftMargin = cellMarginPx
		local rightMargin = cellMarginPx2
		local topMargin = cellMarginPx
		local bottomMargin = cellMarginPx2

		if cell % cols == 1 then
			leftMargin = cellMarginPx2
		end
		if cell % cols == 0 then
			rightMargin = cellMarginPx2
		end
		if cols/cell >= 1  then
			topMargin = math_floor(((cellMarginPx + cellMarginPx2) / 2) + 0.5)
		end

		local cellInnerWidth = math_floor(((cellRects[cell][3] - rightMargin) - (cellRects[cell][1] + leftMargin)) + 0.5)
		local cellInnerHeight = math_floor(((cellRects[cell][4] - topMargin) - (cellRects[cell][2] + bottomMargin)) + 0.5)

		local padding = math_max(1, math_floor(backgroundPadding * 0.52))

		local isActiveCmd = (activeCommand == cmd.name)
		-- order button background
		local color1, color2
		if isActiveCmd then
			zoom = cellClickedZoom
			color1 = { 0.66, 0.66, 0.66, math_clamp(uiOpacity, 0.75, 0.95) }	-- bottom
			color2 = { 1, 1, 1, math_clamp(uiOpacity, 0.75, 0.95) }			-- top
		else
			if WG['guishader'] then
				color1 = (isStateCommand[cmd.id]) and { 0.5, 0.5, 0.5, math_clamp(uiOpacity/1.5, 0.35, 0.55) } or { 0.6, 0.6, 0.6, math_clamp(uiOpacity/1.5, 0.35, 0.55) }
				color1[4] = math_clamp(uiOpacity-0.3, 0, 0.35)
				color2 = { 1,1,1, math_clamp(uiOpacity-0.3, 0, 0.35) }
			else
				color1 = (isStateCommand[cmd.id]) and { 0.33, 0.33, 0.33, 1 } or { 0.33, 0.33, 0.33, 1 }
				color1[4] = math_clamp(uiOpacity-0.4, 0, 0.35)
				color2 = { 1,1,1, math_clamp(uiOpacity-0.4, 0, 0.35) }
			end
			if useRenderToTexture then
				color1[4] = color1[4] * 2.1
				color2[4] = color2[4] * 2.1
			end
			if color1[4] > 0.06 then
				-- white bg (outline)
				RectRound(cellRects[cell][1] + leftMargin, cellRects[cell][2] + bottomMargin, cellRects[cell][3] - rightMargin, cellRects[cell][4] - topMargin, cellWidth * 0.021, 2, 2, 2, 2, color1, color2)
				-- darken inside
				color1 = {0,0,0, color1[4]*0.85}
				color2 = {0,0,0, color2[4]*0.85}
				RectRound(cellRects[cell][1] + leftMargin + padding, cellRects[cell][2] + bottomMargin + padding, cellRects[cell][3] - rightMargin - padding, cellRects[cell][4] - topMargin - padding, padding, 2, 2, 2, 2, color1, color2)
			end
			color1 = { 0, 0, 0, math_clamp(uiOpacity, 0.55, 0.95) }	-- bottom
			color2 = { 0, 0, 0,  math_clamp(uiOpacity, 0.55, 0.95) }	-- top
		end

		UiButton(cellRects[cell][1] + leftMargin + padding, cellRects[cell][2] + bottomMargin + padding, cellRects[cell][3] - rightMargin - padding, cellRects[cell][4] - topMargin - padding, 1,1,1,1, 1,1,1,1, nil, color1, color2, padding, useRenderToTexture and 1.66)

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
			local text
			-- First element of params represents selected state index, but Spring engine implementation returns a value 2 less than the actual index
			local stateOffset = 2

			if isStateCommand[cmd.id] then
				local currentStateIndex = cmd.params[1]
				if currentStateIndex then
					local commandState = cmd.params[currentStateIndex + stateOffset]
					if commandState then
						text = Spring.I18N('ui.orderMenu.' .. commandState)
					else
						text = '?'
					end
				else
					text = '?'
				end
			else
				if cmd.action == 'stockpile' then
					-- Stockpile command name gets mutated to reflect the current status, so can just pass it in
					text  = Spring.I18N('ui.orderMenu.' .. cmd.action, { stockpileStatus = cmd.name })
				else
					text = Spring.I18N('ui.orderMenu.' .. cmd.action)
				end
			end

			local fontSize = cellInnerWidth / font:GetTextWidth('  ' .. text .. ' ') * math_min(1, (cellInnerHeight / (rows * 6)))
			if fontSize > cellInnerWidth / 7 then
				fontSize = cellInnerWidth / 7
			end
			fontSize = fontSize * zoom
			local fontHeight = font:GetTextHeight(text) * fontSize
			local fontHeightOffset = fontHeight * 0.34
			if isStateCommand[cmd.id] then
				fontHeightOffset = fontHeight * 0.22
			end
			local textColor = "\255\233\233\233"
			if colorize > 0 and commandInfo[cmd.action] and commandInfo[cmd.action].red then
				local part = (1 / colorize)
				local grey = (0.93 * (part - 1))
				textColor = convertColor((grey + commandInfo[cmd.action].red) / part, (grey + commandInfo[cmd.action].green) / part, (grey + commandInfo[cmd.action].blue) / part)
			end
			if isActiveCmd then
				textColor = "\255\020\020\020"
			end
			font:Print(textColor .. text, cellRects[cell][1] + ((cellRects[cell][3] - cellRects[cell][1]) / 2), (cellRects[cell][2] - ((cellRects[cell][2] - cellRects[cell][4]) / 2) - fontHeightOffset), fontSize, "con")
		end

		-- state lights
		if isStateCommand[cmd.id] or cmd.id == CMD.WAIT then
			local statecount, curstate
			if isStateCommand[cmd.id] then
				statecount = #cmd.params - 1 --number of states for the cmd
				curstate = cmd.params[1] + 1
			else
				statecount = 2
				local referenceUnit
				for _, unitID in ipairs(Spring.GetSelectedUnits()) do
					local canWait = Spring.FindUnitCmdDesc(unitID, CMD.WAIT)
					if canWait then
						referenceUnit = unitID
						break
					end
				end
				if referenceUnit then
					local commandQueue
					if isFactory[Spring.GetUnitDefID(referenceUnit)] then
						commandQueue = Spring.GetFactoryCommands(referenceUnit, 1)
					else
						commandQueue = Spring.GetUnitCommands(referenceUnit, 1)
					end
					if commandQueue and commandQueue[1] and commandQueue[1].id == CMD.WAIT then
						curstate = 2
					else
						curstate = 1
					end
				end
			end
			local desiredState = nil
			if clickedCellDesiredState and cell == clickedCell then
				desiredState = clickedCellDesiredState + 1
			end
			if curstate == desiredState then
				clickedCellDesiredState = nil
				desiredState = nil
			end
			local padding2 = padding
			local stateWidth = (cellInnerWidth / statecount) - padding2 - padding2
			local stateHeight = math_floor(cellInnerHeight * 0.14)
			local stateMargin = math_floor((stateWidth * 0.075) + 0.5) + padding2 + padding2
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
				local x1 = math_floor(cellRects[cell][1] + leftMargin + padding + padding2 + (stateWidth * (i - 1)) + (i == 1 and 0 or stateMargin))
				local y1 = math_floor(cellRects[cell][2] + bottomMargin + padding + padding2)
				local x2 = math_ceil(cellRects[cell][3] - rightMargin - padding - padding2 - (stateWidth * (statecount - i)) - (i == statecount and 0 or stateMargin))
				local y2 = math_ceil(cellRects[cell][2] + bottomMargin + stateHeight + padding2)
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
local function drawOrdersBackground()
	-- just making sure blending mode is correct
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	UiElement(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], ((posX <= 0) and 0 or 1), 1, ((posY-height > 0 or posX <= 0) and 1 or 0), ((posY-height > 0 and posX > 0) and 1 or 0), nil, nil, nil, nil, nil, nil, nil, nil, useRenderToTexture)
end

local function drawOrders()
	if #commands > 0 then
		font:Begin()
		for cell = 1, #commands do
			drawCell(cell, cellZoom)
		end
		font:End()
	end
end

function widget:DrawScreen()
	local x, y = Spring.GetMouseState()
	local cellHovered
	if not WG['topbar'] or not WG['topbar'].showingQuit() then
		if math_isInRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
			Spring.SetMouseCursor('cursornormal')
			for cell = 1, #cellRects do
				if commands[cell] then
					if math_isInRect(x, y, cellRects[cell][1], cellRects[cell][2], cellRects[cell][3], cellRects[cell][4]) then
						local cmd = commands[cell]
						if WG['tooltip'] then
							local tooltipKey = cmd.action .. '_tooltip'
							local tooltip = Spring.I18N('ui.orderMenu.' .. tooltipKey)
							local hotkey = keyConfig.sanitizeKey(actionHotkeys[cmd.action], currentLayout)

							if tooltip ~= '' and hotkey ~= '' then
								tooltip = Spring.I18N('ui.orderMenu.hotkeyTooltip', { hotkey = hotkey:upper(), tooltip = tooltip, highlightColor = "\255\255\215\100", textColor = "\255\240\240\240" })
							end
							if tooltip ~= '' then
								local title
								if isStateCommand[cmd.id] then
									local currentStateIndex = cmd.params[1]
									-- First element of params represents selected state index, but Spring engine implementation returns a value 2 less than the actual index
									local stateOffset = 2
									local commandState = cmd.params[currentStateIndex + stateOffset]
									if commandState then
										title = Spring.I18N('ui.orderMenu.' .. commandState)
									end
								else
									title = Spring.I18N('ui.orderMenu.' .. cmd.action)
								end
								WG['tooltip'].ShowTooltip('ordermenu', tooltip, nil, nil, title)
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
	if clickedCellDesiredState and not doUpdateClock then	-- make sure state changes get updated
		doUpdateClock = now + 0.1
	end
	if doUpdate or (doUpdateClock and now >= doUpdateClock) then
		if doUpdateClock and now >= doUpdateClock then
			doUpdateClock = nil
			doUpdate = true
		end
		doUpdateClock = nil
		refreshCommands()
	end

	if #commands == 0 and (not alwaysShow or Spring.GetGameFrame() == 0) then	-- dont show pregame because factions interface is shown
		if displayListGuiShader and WG['guishader'] then
			WG['guishader'].RemoveDlist('ordermenu')
		end
	else
		if displayListGuiShader and WG['guishader'] then
			WG['guishader'].InsertDlist(displayListGuiShader, 'ordermenu')
		end
		if doUpdate then
			displayListOrders = gl.DeleteList(displayListOrders)
		end
		if not displayListOrders then
			displayListOrders = gl.CreateList(function()
				if not useRenderToTexture then
					drawOrdersBackground()
					drawOrders()
				end
			end)
			if useRenderToTexture then
				if not ordermenuBgTex then
					ordermenuTex = gl.CreateTexture(math_floor(width*viewSizeX)*(viewSizeY<1600 and 2 or 1), math_floor(height*viewSizeY)*(viewSizeY<1600 and 2 or 1), {
						target = GL.TEXTURE_2D,
						format = GL.ALPHA,
						fbo = true,
					})
					ordermenuBgTex = gl.CreateTexture(math_floor(width*viewSizeX), math_floor(height*viewSizeY), {
						target = GL.TEXTURE_2D,
						format = GL.ALPHA,
						fbo = true,
					})
					if ordermenuBgTex then
						gl.RenderToTexture(ordermenuBgTex, function()
							gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
							gl.Color(1,1,1,1)
							gl.PushMatrix()
							gl.Translate(-1, -1, 0)
							gl.Scale(2 / (width*viewSizeX), 2 / (height*viewSizeY),	0)
							gl.Translate(-backgroundRect[1], -backgroundRect[2], 0)
							drawOrdersBackground()
							gl.PopMatrix()
						end)
					end
				end
				if ordermenuTex then
					gl.RenderToTexture(ordermenuTex, function()
						gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
						gl.Color(1,1,1,1)
						gl.PushMatrix()
						gl.Translate(-1, -1, 0)
						gl.Scale(2 / (width*viewSizeX), 2 / (height*viewSizeY),	0)
						gl.Translate(-backgroundRect[1], -backgroundRect[2], 0)
						drawOrders()
						gl.PopMatrix()
					end)
				end
			end
		end

		if useRenderToTexture and ordermenuTex then
			-- background element
			gl.Color(1,1,1,Spring.GetConfigFloat("ui_opacity", 0.7)*1.1)
			gl.Texture(ordermenuBgTex)
			gl.TexRect(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], false, true)
			-- content
			gl.Color(1,1,1,1)
			gl.Texture(ordermenuTex)
			gl.TexRect(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], false, true)
			gl.Texture(false)
		else
			gl.CallList(displayListOrders)
		end

		if #commands >0 then
			-- draw highlight on top of button
			if not WG['topbar'] or not WG['topbar'].showingQuit() then
				if commands and cellHovered then
					local cell = cellHovered
					if cellRects[cell] and cellRects[cell][4] then
						drawCell(cell, cellHoverZoom)

						local colorMult = 1
						if commands[cell] and activeCommand == commands[cell].name then
							colorMult = 0.4
						end

						local leftMargin = cellMarginPx
						local rightMargin = cellMarginPx2
						local topMargin = cellMarginPx
						local bottomMargin = cellMarginPx2

						if cell % cols == 1 then
							leftMargin = cellMarginPx2
						end
						if cell % cols == 0 then
							rightMargin = cellMarginPx2
						end
						if cols/cell >= 1  then
							topMargin = math_floor(((cellMarginPx + cellMarginPx2) / 2) + 0.5)
						end

						-- gloss highlight
						local pad = math_max(1, math_floor(backgroundPadding * 0.52))
						local pad2 = pad
						glBlending(GL_SRC_ALPHA, GL_ONE)
						RectRound(cellRects[cell][1] + leftMargin + pad + pad2, cellRects[cell][4] - topMargin - backgroundPadding - pad - pad2 - ((cellRects[cell][4] - cellRects[cell][2]) * 0.42), cellRects[cell][3] - rightMargin - pad - pad2, (cellRects[cell][4] - topMargin - pad - pad2), cellMargin * 0.025, 2, 2, 0, 0, { 1, 1, 1, 0.035 * colorMult }, { 1, 1, 1, (disableInput and 0.11 * colorMult or 0.24 * colorMult) })
						RectRound(cellRects[cell][1] + leftMargin + pad + pad2, cellRects[cell][2] + bottomMargin + pad + pad2, cellRects[cell][3] - rightMargin - pad - pad2, (cellRects[cell][2] - bottomMargin - pad - pad2) + ((cellRects[cell][4] - cellRects[cell][2]) * 0.5), cellMargin * 0.025, 0, 0, 2, 2, { 1, 1, 1, (disableInput and 0.035 * colorMult or 0.075 * colorMult) }, { 1, 1, 1, 0 })
						glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
					end
				end
			end

			-- clicked cell effect
			if clickedCellTime and commands[clickedCell] then
				local cell = clickedCell
				if cellRects[cell] and cellRects[cell][4] then
					local isActiveCmd = (commands[cell].name == activeCommand)
					local duration = 0.33
					if isActiveCmd then
						duration = 0.45
					elseif isStateCommand[commands[clickedCell].id] then
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

						local leftMargin = cellMarginPx
						local rightMargin = cellMarginPx2
						local topMargin = cellMarginPx
						local bottomMargin = cellMarginPx2

						if cell % cols == 1 then
							leftMargin = cellMarginPx2
						end
						if cell % cols == 0 then
							rightMargin = cellMarginPx2
						end
						if cols/cell >= 1  then
							topMargin = math_floor(((cellMarginPx + cellMarginPx2) / 2) + 0.5)
						end

						-- gloss highlight
						local pad = math_max(1, math_floor(backgroundPadding * 0.52))
						RectRound(cellRects[cell][1] + leftMargin + pad, cellRects[cell][2] + bottomMargin + pad, cellRects[cell][3] - rightMargin - pad, cellRects[cell][4] - topMargin - pad, pad, 2, 2, 2, 2)
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
	if ordermenuShows and math_isInRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
		if #commands > 0 then
			if not disableInput then
				for cell = 1, #cellRects do
					local cmd = commands[cell]
					if cmd then
						if math_isInRect(x, y, cellRects[cell][1], cellRects[cell][2], cellRects[cell][3], cellRects[cell][4]) then
							clickCountDown = 2
							clickedCell = cell
							clickedCellTime = os_clock()

							-- remember desired state: only works for a single cell at a time, because there is no way to re-identify a cell when the selection changes
							if isStateCommand[cmd.id] then
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
								Spring.PlaySoundFile(soundButton, 0.6, 'ui')
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
		elseif alwaysShow and Spring.GetGameFrame() > 0 then
			return true
		end
	end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdOpts, cmdParams, cmdTag)
	if isStateCommand[cmdID] or cmdID == CMD.WAIT then
		if not hiddenCommands[cmdID] and doUpdateClock == nil then
			doUpdateClock = os_clock() + 0.01
		end
	end
end

function widget:CommandsChanged() -- required to read changes from EditUnitCmdDesc
	doUpdateClock = os_clock() + 0.01
end

function widget:SelectionChanged(sel)
	clickCountDown = 2
	clickedCellDesiredState = nil
end

function widget:LanguageChanged()
	widget:ViewResize()
end

function widget:GetConfigData()
	return { version = 1, colorize = colorize, stickToBottom = stickToBottom, alwaysShow = alwaysShow, disabledCmd = disabledCommand}
end

function widget:SetConfigData(data)
	if data.version then
		if data.stickToBottom ~= nil then
			stickToBottom = data.stickToBottom
		end
	end
	if data.colorize ~= nil then
		colorize = data.colorize
	end
	if data.alwaysShow ~= nil then
		alwaysShow = data.alwaysShow
	end
	if data.disabledCmd ~= nil then
		disabledCommand = data.disabledCmd
	end
end
