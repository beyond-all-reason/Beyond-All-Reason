function widget:GetInfo()
	return {
		name = "Keybind/Mouse Info",
		desc = "Provides information on the controls",
		author = "Bluestone",
		date = "April 2015",
		license = "Mouthwash",
		layer = -99990,
		enabled = true,
	}
end

local texts = {        -- fallback (if you want to change this, also update: language/en.lua, or it will be overwritten)
	title = 'Keybinds',
	disclaimer = 'These keybinds are set by default. If you remove/replace hotkey widgets, or use your own uikeys, they might stop working!',
	lines = {
		{ "Chat", title = true },
		{ "enter", "Send chat message" },
		{ "alt + enter", "Send chat message to allies" },
		{ "shift + enter", "Send chat message to spectators" },
		{ "ctrl + left click on name", "Ignore player" },
		{ blankLine = true },
		{ "Menus", title = true },
		{ "f10", "Settings" },
		{ "f11", "Widget list" },
		{ "ctrl + f11", "Widget teak mode" },
		{ "h", "Share units / resources" },
		{ blankLine = true },
		{ "Camera movement", title = true },
		{ "scrollwheel", "Zoom camera" },
		{ "arrow keys / mouse at screen edge", "Move camera" },
		{ "ctrl + scrollwheel", "Change camera angle" },
		{ "middle click (+ drag)", "Drag camera" },
		{ "ctrl + shift + o", "Flip camera" },
		{ blankLine = true },
		{ "Camera modes", title = true },
		{ "ctrl + f1,2,3,4,5", "Change camera type" },
		{ "alt + backspace", "Toggle fullscreen" },
		{ "tab", "Toggle overview camera" },
		{ "l", "Toggle LOS view" },
		{ "f1", "Show height map" },
		{ "f2", "Show passability (for selected unit)" },
		{ "f3", "Cycle through map marks" },
		{ "f4", "Show metal map" },
		{ "f5", "Hide GUI" },
		{ blankLine = true },
		{ "Sound", title = true },
		{ "-/+", "Change volume" },
		{ "f6", "Toggle mute" },

		{ blankLine = true },
		{ "Selecting units", title = true },
		{ "left mouse (+ drag)", "Select or deselect units" },
		{ blankLine = true },
		{ "Giving orders", title = true },
		{ "right mouse (single click)", "Give order to unit(s)" },
		{ "right mouse (drag)", "Give formation order to unit(s)" },
		{ blankLine = true },
		{ "Selecting orders", title = true },
		{ "(none)", "default order (usually move)" },
		{ "m", "move" },
		{ "a", "attack" },
		{ "y", "set priority target" },
		{ "r", "repair" },
		{ "e", "reclaim" },
		{ "o", "resurrect" },
		{ "f", "fight" },
		{ "p", "patrol" },
		{ "k", "cloak" },
		{ blankLine = true },
		{ "s", "stop (clears order queue)" },
		{ "w", "wait (pause current command)" },
		{ "j", "cancel priority target" },
		{ blankLine = true },
		{ "d", "manual fire (dgun)" },
		{ "ctrl + d", "self-destruct" },
		{ blankLine = true },
		{ "Giving selected orders", title = true },
		{ "left mouse (single click)", "Give order to unit(s)" },
		{ "right mouse (single click)", "Revert to default order" },
		{ "right mouse + drag", "Give formation order to unit(s)" },
		{ blankLine = true },
		{ "Queueing orders", title = true },
		{ "shift + (some order)", "Add order to end of order queue" },
		{ "space + (some order)", "Add order to start of order queue" },

		{ blankLine = true },
		{ "Selecting build orders", title = true },
		{ "(mouse)", "Select from units build-menu" },
		{ "z", "Cycle through mexes" },
		{ "x", "Cycle through energy production" },
		{ "c", "Cycle through radar/defence/etc" },
		{ "v", "Cycle through factories" },
		{ "[ and ], or o", "Change facing of buildings" },
		{ blankLine = true },
		{ "Giving build orders", title = true },
		{ "left mouse", "Give build order" },
		{ "right mouse", "De-select build order" },
		{ "shift + (build order)", "Build in a line" },
		{ "shift + alt + (build order)", "Build in a square" },
		{ "alt+z", "Increase build spacing" },
		{ "alt+x", "Decrease build spacing" },
		{ blankLine = true },
		{ "Group selection", title = true },
		{ "ctrl + a", "Select all units" },
		{ "ctrl + b", "Select all constructors" },
		{ "ctrl + (num)", "Add units to group (num=1,2,..)" },
		{ "(num)", "Select all units assigned to group (num)" },
		{ "ctrl + z", "Select all units of same type as current" },
		{ blankLine = true },
		{ "Drawing", title = true },
		{ "q + dbl click", "Place map mark" },
		{ "q + drag left mouse", "Draw on map" },
		{ "q + drag right mouse", "Erase drawings and markers" },
		{ blankLine = true },
		{ "Console commands", title = true },
		{ "/clearmapmarks", "Erase all drawings and markes" },
		{ "/pause", "Pause" },
	},
}

local vsx, vsy = Spring.GetViewGeometry()
local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")

local bgMargin = 6

local screenHeight = 520 - bgMargin - bgMargin
local screenWidth = 1050 - bgMargin - bgMargin

local spIsGUIHidden = Spring.IsGUIHidden
local showHelp = false

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glPolygonMode = gl.PolygonMode
local glRect = gl.Rect
local glText = gl.Text
local glShape = gl.Shape

local bgColorMultiplier = 0

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList

local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glTranslate = gl.Translate
local glScale = gl.Scale

local GL_FILL = GL.FILL
local GL_FRONT_AND_BACK = GL.FRONT_AND_BACK
local GL_LINE_STRIP = GL.LINE_STRIP

local RectRound = Spring.Utilities.RectRound

local myTeamID = Spring.GetMyTeamID()
local showOnceMore = false

-- keybind info
local bindColor = "\255\235\185\070"
local titleColor = "\255\254\254\254"
local descriptionColor = "\255\192\190\180"

local widgetScale = 1
local customScale = 1
local centerPosX = 0.5    -- note: dont go too far from 0.5
local centerPosY = 0.49        -- note: dont go too far from 0.5
local screenX = (vsx * centerPosX) - (screenWidth / 2)
local screenY = (vsy * centerPosY) + (screenHeight / 2)

local font, font2, loadedFontSize, titleRect, keybinds, chobbyInterface, backgroundGuishader, show

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	screenX = (vsx * centerPosX) - (screenWidth / 2)
	screenY = (vsy * centerPosY) + (screenHeight / 2)
	widgetScale = ((vsx + vsy) / 2000) * 0.65 * customScale
	widgetScale = widgetScale * (1 - (0.11 * ((vsx / vsy) - 1.78)))        -- make smaller for ultrawide screens

	font, loadedFontSize = WG['fonts'].getFont()
	font2 = WG['fonts'].getFont(fontfile2)

	if keybinds then
		gl.DeleteList(keybinds)
	end
	keybinds = gl.CreateList(DrawWindow)
end

function DrawTextTable(t, x, y)
	local j = 0
	local height = 0
	local width = 0
	local fontSize = (screenHeight * 0.96) / math.ceil(#texts.lines / 3)
	font:Begin()
	for _, t in pairs(t) do
		if t.blankLine then
			-- nothing here
		elseif t.title then
			-- title line
			local title = t[1] or ""
			local line = " " .. titleColor .. title -- a WTF whitespace is needed here, the colour doesn't show without it...
			font:Print(line, x + 4, y - ((fontSize * 0.94) * j) + 5, fontSize)
			screenWidth = math.max(font:GetTextWidth(line) * 13, screenWidth)
		else
			-- keybind line
			local bind = string.upper(t[1]) or ""
			local effect = t[2] or ""
			local line = " " .. bindColor .. bind .. "   " .. descriptionColor .. effect
			font:Print(line, x + 14, y - (fontSize * 0.94) * j, fontSize * 0.8)
			width = math.max(font:GetTextWidth(line) * 11, width)
		end
		height = height + 13

		j = j + 1
		-- dont let the first line of a column be blank
		if j == 1 and t.blankLine then
			j = j - 1
		end
	end
	font:End()
	--screenHeight = math.max(screenHeight, height)
	--screenWidth = screenWidth + width
	return x, j
end

function DrawWindow()
	local vsx, vsy = Spring.GetViewGeometry()
	local x = screenX --rightwards
	local y = screenY --upwards

	-- background
	if WG['guishader'] then
		gl.Color(0, 0, 0, 0.8)
	else
		gl.Color(0, 0, 0, 0.85)
	end
	RectRound(x - bgMargin, y - screenHeight - bgMargin, x + screenWidth + bgMargin, y + bgMargin, 8, 0, 1, 1, 1, { 0.05, 0.05, 0.05, WG['guishader'] and 0.8 or 0.88 }, { 0, 0, 0, WG['guishader'] and 0.8 or 0.88 })
	-- content area
	gl.Color(0.33, 0.33, 0.33, 0.15)
	RectRound(x, y - screenHeight, x + screenWidth, y, 5.5, 1, 1, 1, 1, { 0.25, 0.25, 0.25, 0.2 }, { 0.5, 0.5, 0.5, 0.2 })

	-- title background
	local title = texts.title
	local titleFontSize = 18
	if WG['guishader'] then
		gl.Color(0, 0, 0, 0.8)
	else
		gl.Color(0, 0, 0, 0.85)
	end
	titleRect = { x - bgMargin, y + bgMargin, x - bgMargin + (font2:GetTextWidth(title) * titleFontSize) + 27, y + 37 }
	RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], 8, 1, 1, 0, 0)
	-- title
	font2:Begin()
	font2:SetTextColor(1, 1, 1, 1)
	font2:SetOutlineColor(0, 0, 0, 0.4)
	font2:Print(title, x - bgMargin + (titleFontSize * 0.75), y + bgMargin + 8, titleFontSize, "on")
	font2:End()

	local entriesPerColumn = math.ceil(#texts.lines / 3)
	local entries1 = {}
	local entries2 = {}
	local entries3 = {}
	for k, v in pairs(texts.lines) do
		if k <= entriesPerColumn then
			entries1[#entries1 + 1] = v
		elseif k > entriesPerColumn and k <= entriesPerColumn * 2 then
			entries2[#entries2 + 1] = v
		else
			entries3[#entries3 + 1] = v
		end
	end
	DrawTextTable(entries1, x, y - 24)
	x = x + 350
	DrawTextTable(entries2, x, y - 24)
	x = x + 350
	DrawTextTable(entries3, x, y - 24)

	gl.Color(1, 1, 1, 1)
	font:Begin()
	font:Print(texts.disclaimer, screenX + 12, y - screenHeight + 14, 12.5)
	font:End()
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
	if spIsGUIHidden() then
		return
	end

	-- draw the help
	if not keybinds then
		keybinds = gl.CreateList(DrawWindow)
	end

	if show or showOnceMore then
		gl.Texture(false)	-- some other widget left it on
		glPushMatrix()
		glTranslate(-(vsx * (widgetScale - 1)) / 2, -(vsy * (widgetScale - 1)) / 2, 0)
		glScale(widgetScale, widgetScale, 1)
		glCallList(keybinds)
		glPopMatrix()
		if WG['guishader'] then
			local rectX1 = ((screenX - bgMargin) * widgetScale) - ((vsx * (widgetScale - 1)) / 2)
			local rectY1 = ((screenY + bgMargin) * widgetScale) - ((vsy * (widgetScale - 1)) / 2)
			local rectX2 = ((screenX + screenWidth + bgMargin) * widgetScale) - ((vsx * (widgetScale - 1)) / 2)
			local rectY2 = ((screenY - screenHeight - bgMargin) * widgetScale) - ((vsy * (widgetScale - 1)) / 2)
			if backgroundGuishader ~= nil then
				glDeleteList(backgroundGuishader)
			end
			backgroundGuishader = glCreateList(function()
				-- background
				RectRound(rectX1, rectY2, rectX2, rectY1, 9 * widgetScale, 0, 1, 1, 1)
				-- title
				rectX1 = (titleRect[1] * widgetScale) - ((vsx * (widgetScale - 1)) / 2)
				rectY1 = (titleRect[2] * widgetScale) - ((vsy * (widgetScale - 1)) / 2)
				rectX2 = (titleRect[3] * widgetScale) - ((vsx * (widgetScale - 1)) / 2)
				rectY2 = (titleRect[4] * widgetScale) - ((vsy * (widgetScale - 1)) / 2)
				RectRound(rectX1, rectY1, rectX2, rectY2, 9 * widgetScale, 1, 1, 0, 0)
			end)
			WG['guishader'].InsertDlist(backgroundGuishader, 'keybindinfo')
		end
		showOnceMore = false
	else
		if WG['guishader'] then
			WG['guishader'].DeleteDlist('keybindinfo')
		end
	end
end

function widget:KeyPress(key)
	if key == 27 then
		-- ESC
		show = false
	end
end

function IsOnRect(x, y, BLcornerX, BLcornerY, TRcornerX, TRcornerY)

	-- check if the mouse is in a rectangle
	return x >= BLcornerX and x <= TRcornerX
		and y >= BLcornerY
		and y <= TRcornerY
end

function widget:MousePress(x, y, button)
	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end

function mouseEvent(x, y, button, release)
	if spIsGUIHidden() then
		return false
	end

	if show then
		-- on window
		local rectX1 = ((screenX - bgMargin) * widgetScale) - ((vsx * (widgetScale - 1)) / 2)
		local rectY1 = ((screenY + bgMargin) * widgetScale) - ((vsy * (widgetScale - 1)) / 2)
		local rectX2 = ((screenX + screenWidth + bgMargin) * widgetScale) - ((vsx * (widgetScale - 1)) / 2)
		local rectY2 = ((screenY - screenHeight - bgMargin) * widgetScale) - ((vsy * (widgetScale - 1)) / 2)
		if IsOnRect(x, y, rectX1, rectY2, rectX2, rectY1) then
			return true
		elseif titleRect == nil or not IsOnRect(x, y, (titleRect[1] * widgetScale) - ((vsx * (widgetScale - 1)) / 2), (titleRect[2] * widgetScale) - ((vsy * (widgetScale - 1)) / 2), (titleRect[3] * widgetScale) - ((vsx * (widgetScale - 1)) / 2), (titleRect[4] * widgetScale) - ((vsy * (widgetScale - 1)) / 2)) then
			if release then
				showOnceMore = show        -- show once more because the guishader lags behind, though this will not fully fix it
				show = false
			end
			return true
		end
	end
end

function widget:Initialize()
	if WG['lang'] then
		texts = WG['lang'].getText('keys')
	end

	WG['keybinds'] = {}
	WG['keybinds'].toggle = function(state)
		if state ~= nil then
			show = state
		else
			show = not show
		end
	end
	WG['keybinds'].isvisible = function()
		return show
	end
	widget:ViewResize()
end

function widget:Shutdown()
	if keybinds then
		glDeleteList(keybinds)
		keybinds = nil
	end
	if WG['guishader'] then
		WG['guishader'].DeleteDlist('keybindinfo')
	end
end
