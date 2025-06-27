--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    selector.lua
--  brief:   the widget selector, loads and unloads widgets
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- changes:
--   jK (April@2009) - updated to new font system
--   Bluestone (Jan 2015) - added to BA as a widget, added various stuff
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Widget Selector",
		desc = "Widget selection widget",
		author = "trepan, jK, Bluestone",
		date = "Jan 8, 2007",
		license = "GNU GPL, v2 or later",
		layer = 999999,
		handler = true,
		enabled = true
	}
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local showButtons = false

-- relies on a gadget to implement "luarules reloadluaui"
-- relies on custom stuff in widgetHandler to implement blankOutConfig and allowUserWidgets

include("keysym.h.lua")
include("fonts.lua")

local WhiteStr = "\255\255\255\255"

local sizeMultiplier = 1


local buttons = {}
local floor = math.floor

local widgetsList = {}
local fullWidgetsList = {}
local localWidgetCount = 0

local minMaxEntries = 14
local curMaxEntries = 24

local startEntry = 1
local pageStep = floor(curMaxEntries / 2) - 1

local fontSize = 14.25
local fontSpace = 8.5
local yStep = fontSize + fontSpace

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local vsx, vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx * vsy / 5700000))
local fontfileSize = 36
local fontfileOutlineSize = 6
local fontfileOutlineStrength = 1.3
local font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local font2 = gl.LoadFont(fontfile2, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)

local bgPadding = 4.5

local maxWidth = 0
local borderx = yStep * 0.75
local bordery = yStep * 0.75

local activeGuishader = false
local scrollbarOffset = -15
local updateUi = true

local midx = vsx * 0.5
local minx = vsx * 0.4
local maxx = vsx * 0.6
local midy = vsy * 0.5
local miny = vsy * 0.4
local maxy = vsy * 0.6

local sbposx = 0.0
local sbposy = 0.0
local sbsizex = 0.0
local sbsizey = 0.0
local sby1 = 0.0
local sby2 = 0.0
local sbsize = 0.0
local sbheight = 0.0
local activescrollbar = false
local scrollbargrabpos = 0.0

local show = false
local pagestepped = false

local RectRound, UiElement, UiSelectHighlight, elementPadding, elementCorner

local dlistGuishader, dlistGuishader2, lastStart

local widgetScale = (vsy / 1080)

local allowuserwidgets = true
if not Spring.GetModOptions().allowuserwidgets and not Spring.IsReplay() then
	allowuserwidgets = false
	buttons[3] = ''
end

local buttonFontSize = 15
local buttonHeight = 24
local buttonTop = 40 -- offset between top of buttons and bottom of widget

local utf8 = VFS.Include('common/luaUtilities/utf8.lua')
local textInputDlist
local uiList
local updateTextInputDlist = true
local textCursorRect
local showTextInput = true
local inputText = ''
local inputTextPosition = 0
local cursorBlinkTimer = 0
local cursorBlinkDuration = 1
local maxTextInputChars = 127	-- tested 127 as being the true max
local inputTextInsertActive = false
local floor = math.floor
local inputMode = ''
local chobbyInterface

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

function widget:TextInput(char)	-- if it isnt working: chobby probably hijacked it
	if not chobbyInterface and not Spring.IsGUIHidden() and showTextInput and show then
		if inputTextInsertActive then
			inputText = utf8.sub(inputText, 1, inputTextPosition) .. char .. utf8.sub(inputText, inputTextPosition+2)
			if inputTextPosition <= utf8.len(inputText) then
				inputTextPosition = inputTextPosition + 1
			end
		else
			inputText = utf8.sub(inputText, 1, inputTextPosition) .. char .. utf8.sub(inputText, inputTextPosition+1)
			inputTextPosition = inputTextPosition + 1
		end
		if string.len(inputText) > maxTextInputChars then
			inputText = string.sub(inputText, 1, maxTextInputChars)
			if inputTextPosition > maxTextInputChars then
				inputTextPosition = maxTextInputChars
			end
		end
		cursorBlinkTimer = 0
		updateTextInputDlist = true
		if WG['limitidlefps'] and WG['limitidlefps'].update then
			WG['limitidlefps'].update()
		end
		UpdateList(true)
		return true
	end
end

local function clearChatInput()
	--showTextInput = false
	inputText = ''
	inputTextPosition = 0
	inputTextInsertActive = false
	--backgroundGuishader = gl.DeleteList(backgroundGuishader)
	if WG['guishader'] then
		WG['guishader'].RemoveRect('selectorinput')
	end
	UpdateList(true)
end

local function cancelChatInput()
	clearChatInput()
	widgetHandler.textOwner = nil	--widgetHandler:DisownText()
	UpdateList(true)
end

function drawChatInputCursor()
	if textCursorRect then
		local a = 1 - (cursorBlinkTimer * (1 / cursorBlinkDuration)) + 0.15
		gl.Color(0.7,0.7,0.7,a)
		gl.Rect(textCursorRect[1], textCursorRect[2], textCursorRect[3], textCursorRect[4])
		gl.Color(1,1,1,1)
	end
end

function drawChatInput()
	if showTextInput then
		updateTextInputDlist = false
		textInputDlist = gl.DeleteList(textInputDlist)
		textInputDlist = gl.CreateList(function()
			local activationArea = {floor(minx - (bgPadding * sizeMultiplier)), floor(miny - (bgPadding * sizeMultiplier)), floor(maxx + (bgPadding * sizeMultiplier)), floor(maxy + (bgPadding * sizeMultiplier))}
			local usedFontSize = 15 * widgetScale
			local lineHeight = floor(usedFontSize * 1.15)
			local x,y,_ = Spring.GetMouseState()
			local chatlogHeightDiff = 0
			local inputFontSize = floor(usedFontSize * 1.03)
			local inputHeight = floor(inputFontSize * 2.15)
			local leftOffset = floor(lineHeight*0.7)
			local distance = 0 --elementMargin
			local usedFont = inputMode == '' and font3 or font
			local modeText = Spring.I18N('ui.settings.filter')
			if inputMode ~= '' then
				modeText = inputMode
			end
			local modeTextPosX = floor(activationArea[1]+elementPadding+elementPadding+leftOffset)
			local textPosX = floor(modeTextPosX + (usedFont:GetTextWidth(modeText) * inputFontSize) + leftOffset + inputFontSize)
			local textCursorWidth = 1 + math.floor(inputFontSize / 14)
			if inputTextInsertActive then
				textCursorWidth = math.floor(textCursorWidth * 5)
			end
			local textCursorPos = floor(usedFont:GetTextWidth(utf8.sub(inputText, 1, inputTextPosition)) * inputFontSize)

			-- background
			local x2 = math.max(textPosX+lineHeight+floor(usedFont:GetTextWidth(inputText) * inputFontSize), floor(activationArea[1]+((activationArea[3]-activationArea[1])/2)))
			chatInputArea = { activationArea[1], activationArea[2]+chatlogHeightDiff-distance-inputHeight, x2, activationArea[2]+chatlogHeightDiff-distance }
			UiElement(chatInputArea[1], chatInputArea[2], chatInputArea[3], chatInputArea[4], 0,0,nil,nil, 0,nil,nil,nil, math.max(0.75, Spring.GetConfigFloat("ui_opacity", 0.7)))

			if WG['guishader'] and activeGuishader then
				WG['guishader'].InsertRect(activationArea[1], activationArea[2]+chatlogHeightDiff-distance-inputHeight, x2, activationArea[2]+chatlogHeightDiff-distance, 'selectorinput')
			end

			-- button background
			local inputButtonRect = {activationArea[1]+elementPadding, activationArea[2]+chatlogHeightDiff-distance-inputHeight+elementPadding, textPosX-inputFontSize, activationArea[2]+chatlogHeightDiff-distance}
			if inputMode ~= '' then
				gl.Color(0.03, 0.12, 0.03, 0.3)
			else
				gl.Color(0, 0, 0, 0.3)
			end
			RectRound(inputButtonRect[1], inputButtonRect[2], inputButtonRect[3], inputButtonRect[4], elementCorner*0.6, 0,0,0,1)
			gl.Color(1,1,1,0.033)
			gl.Rect(inputButtonRect[3]-1, inputButtonRect[2], inputButtonRect[3], inputButtonRect[4])

			-- button text
			usedFont:Begin()
			usedFont:SetTextColor(0.62, 0.62, 0.62, 1)
			usedFont:Print(modeText, modeTextPosX, activationArea[2]+chatlogHeightDiff-distance-(inputHeight*0.61), inputFontSize, "o")

			-- text cursor
			textCursorRect = { textPosX + textCursorPos, activationArea[2]+chatlogHeightDiff-distance-(inputHeight*0.5)-(inputFontSize*0.6), textPosX + textCursorPos + textCursorWidth, activationArea[2]+chatlogHeightDiff-distance-(inputHeight*0.5)+(inputFontSize*0.64) }

			usedFont:SetTextColor(0.95, 0.95, 0.95, 1)
			usedFont:Print(inputText, textPosX, activationArea[2]+chatlogHeightDiff-distance-(inputHeight*0.61), inputFontSize, "o")
			usedFont:End()
		end)
	end
end

-------------------------------------------------------------------------------


local function UpdateGeometry()
	midx = vsx * 0.5
	midy = vsy * 0.5

	local halfWidth = (((maxWidth / fontSize) + 2) * fontSize) * sizeMultiplier * 0.5
	minx = floor(midx - halfWidth - (borderx * sizeMultiplier))
	maxx = floor(midx + halfWidth + (borderx * sizeMultiplier))

	local ySize = (yStep * sizeMultiplier) * math.max(#widgetsList, 8)
	miny = floor(midy - (0.5 * ySize)) - ((fontSize + bgPadding + bgPadding) * sizeMultiplier)
	maxy = floor(midy + (0.5 * ySize))
end

local function UpdateListScroll()
	local wCount = #fullWidgetsList
	local lastStart = lastStart or wCount - curMaxEntries + 1
	if lastStart < 1 then
		lastStart = 1
	end
	if lastStart > wCount - curMaxEntries + 1 then
		lastStart = 1
	end
	if startEntry > lastStart then
		startEntry = lastStart
	end
	if startEntry < 1 then
		startEntry = 1
	end

	widgetsList = {}
	local se = startEntry
	local ee = se + curMaxEntries - 1
	local n = 1
	for i = se, ee do
		widgetsList[n], n = fullWidgetsList[i], n + 1
	end

	updateUiList2 = true
end

local function widgetselectorCmd(_, _, params)
	show = not show
	if show then
		widgetHandler.textOwner = self		--widgetHandler:OwnText()
		Spring.SDLStartTextInput()	-- because: touch chobby's text edit field once and widget:TextInput is gone for the game, so we make sure its started!
		Spring.SetConfigInt("widgetselector", 1)
	else
		widgetHandler.textOwner = nil		--widgetHandler:DisownText()
	end
end

local function factoryresetCmd(_, _, params)
	widgetHandler.__blankOutConfig = true
	--widgetHandler.__allowUserWidgets = false
	Spring.SendCommands("luarules reloadluaui")
end

local function userwidgetsCmd(_, _, params)
	if widgetHandler.allowUserWidgets then
		widgetHandler.__allowUserWidgets = false
		Spring.Echo("Disallowed user widgets, reloading...")
	else
		widgetHandler.__allowUserWidgets = true
		Spring.Echo("Allowed user widgets, reloading...")
	end
	Spring.SendCommands("luarules reloadluaui")
end

local function unitControlWidgetsCmd(_, _, params)
	if widgetHandler.allowUnitControlWidgets then
		widgetHandler.__allowUnitControlWidgets = false
		Spring.Echo("Disallowed user 'unit control' widgets, reloading...")
	else
		widgetHandler.__allowUnitControlWidgets = true
		Spring.Echo("Allowed user 'unit control' widgets, reloading...")
	end
	Spring.SendCommands("luarules reloadluaui")
end

function widget:Initialize()

	buttons = { --see MouseRelease for which functions are called by which buttons
		[1] = Spring.I18N('ui.widgetselector.button_reloadluaui'),
		[2] = Spring.I18N('ui.widgetselector.button_unloadallwidgets'),
		[3] = Spring.I18N('ui.widgetselector.button_disallowuserwidgets'),
		[4] = Spring.I18N('ui.widgetselector.button_resetluaui'),
		[5] = Spring.I18N('ui.widgetselector.button_factoryresetluaui'),
	}
	if not allowuserwidgets then
		buttons[3] = ''
	else
		if widgetHandler.allowUserWidgets then
			buttons[3] = Spring.I18N('ui.widgetselector.button_disallowuserwidgets')
		else
			buttons[3] = Spring.I18N('ui.widgetselector.button_allowuserwidgets')
		end
	end

	widgetHandler.knownChanged = true
	Spring.SendCommands('unbindkeyset f11')

	WG['widgetselector'] = {}
	WG['widgetselector'].toggle = function(state)
		local newShow = state
		if newShow == nil then
			newShow = not show
		end
		if newShow and WG['topbar'] then
			WG['topbar'].hideWindows()
		end
		show = newShow
		if show then
			widgetHandler.textOwner = self		--widgetHandler:OwnText()
			Spring.SDLStartTextInput()	-- because: touch chobby's text edit field once and widget:TextInput is gone for the game, so we make sure its started!
			Spring.SetConfigInt("widgetselector", 1)
		else
			widgetHandler.textOwner = nil		--widgetHandler:DisownText()
		end
	end
	WG['widgetselector'].isvisible = function()
		return show
	end
	WG['widgetselector'].getLocalWidgetCount = function()
		return localWidgetCount
	end

	widget:ViewResize(Spring.GetViewGeometry())
	UpdateList()

	widgetHandler.actionHandler:AddAction(self, "widgetselector", widgetselectorCmd, nil, 't')
	widgetHandler.actionHandler:AddAction(self, "factoryreset", factoryresetCmd, nil, 't')
	widgetHandler.actionHandler:AddAction(self, "userwidgets", userwidgetsCmd, nil, 't')
	widgetHandler.actionHandler:AddAction(self, "unitcontrolwidgets", unitControlWidgetsCmd, nil, 't')
end


local function ScrollUp(step)
	startEntry = startEntry - step
	UpdateListScroll()
end

local function ScrollDown(step)
	startEntry = startEntry + step
	UpdateListScroll()
end

function widget:MouseWheel(up, value)
	if not show then
		return false
	end

	local a, c, m, s = Spring.GetModKeyState()
	if a or m then
		return false  -- alt and meta allow normal control
	end
	local step = (s and 4) or (c and 1) or 2
	if up then
		ScrollUp(step)
	else
		ScrollDown(step)
	end
	return true
end

local function SortWidgetListFunc(nd1, nd2)
	--does nd1 come before nd2?
	-- widget profiler on top
	if nd1[1] == "Widget Profiler" then
		return true
	elseif nd2[1] == "Widget Profiler" then
		return false
	end

	-- mod widgets first, then user widgets
	if (nd1[2].fromZip ~= nd2[2].fromZip) then
		return nd1[2].fromZip
	end

	-- sort by name
	return (nd1[1] < nd2[1])
end

function UpdateList(force)
	if not widgetHandler.knownChanged and not force then
		return
	end
	widgetHandler.knownChanged = false

	local myName = widget:GetInfo().name
	--maxWidth = 0
	widgetsList = {}
	fullWidgetsList = {}
	for name, data in pairs(widgetHandler.knownWidgets) do
		if name ~= myName and name ~= 'Write customparam.__def to files' then
			if (not inputText or inputText == '') or (string.find(string.lower(name), string.lower(inputText), nil, true) or (data.desc and string.find(string.lower(data.desc), string.lower(inputText), nil, true)) or (data.basename and string.find(string.lower(data.basename), string.lower(inputText), nil, true)) or (data.author and string.find(string.lower(data.author), string.lower(inputText), nil, true))) then
				fullWidgetsList[#fullWidgetsList+1] = { name, data }
				-- look for the maxWidth
				local width = fontSize * font:GetTextWidth(name)
				if width > maxWidth then
					maxWidth = width
				end
			end
		end
	end
	--maxWidth = (maxWidth / fontSize)

	table.sort(fullWidgetsList, SortWidgetListFunc)	-- occurred: Error in IsAbove(): [string "LuaUI/Widgets/widget_selector.lua"]:300: invalid order function for sorting (migh have happened cause i renamed/added a custom widget after launch)

	localWidgetCount = 0
	for _, namedata in ipairs(fullWidgetsList) do
		if not namedata[2].fromZip then
			localWidgetCount = localWidgetCount + 1
		end
	end

	if force and WG['guishader']then
		activeGuishader = false
		WG['guishader'].DeleteDlist('widgetselector')
		WG['guishader'].DeleteDlist('widgetselector2')
		WG['guishader'].RemoveRect('selectorinput')
		if textInputDlist then
			textInputDlist = gl.DeleteList(textInputDlist)
		end
	end

	UpdateListScroll()
	UpdateGeometry()
end

function widget:ViewResize(n_vsx, n_vsy)
	vsx, vsy = Spring.GetViewGeometry()
	widgetScale = (vsy / 1080)
	local fontfileScale = widgetScale
	font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
	font2 = gl.LoadFont(fontfile2, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)

	sizeMultiplier = widgetScale * 0.95

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	elementPadding = WG.FlowUI.elementPadding
	elementCorner = WG.FlowUI.elementCorner
	UiSelectHighlight = WG.FlowUI.Draw.SelectHighlight

	updateUi = true
	UpdateGeometry()
end

-------------------------------------------------------------------------------

function widget:KeyRelease()
	-- Since we grab the keyboard, we need to specify a KeyRelease to make sure other release actions can be triggered
	return false
end

function widget:KeyPress(key, mods, isRepeat)
	if show and key == KEYSYMS.ESCAPE or (key == KEYSYMS.F11 and not isRepeat and not (mods.alt or mods.ctrl or mods.meta or mods.shift)) then
		if key == KEYSYMS.ESCAPE and inputText and inputText ~= '' then
			clearChatInput()
		else
			local newShow = not show
			if newShow and WG['topbar'] then
				WG['topbar'].hideWindows()
			end
			show = newShow
			if show and not (Spring.Utilities.IsDevMode() or Spring.Utilities.ShowDevUI() or Spring.GetConfigInt("widgetselector", 0) == 1 or localWidgetCount > 0) then
				show = false
			end
			if show then
				widgetHandler.textOwner = self		--widgetHandler:OwnText()
				Spring.SDLStartTextInput()	-- because: touch chobby's text edit field once and widget:TextInput is gone for the game, so we make sure its started!
				Spring.SetConfigInt("widgetselector", 1)
			else
				widgetHandler.textOwner = nil		--widgetHandler:DisownText()
			end
		end
		return true
	end
	if show and key == KEYSYMS.PAGEUP then
		ScrollUp(pageStep)
		return true
	end
	if show and key == KEYSYMS.PAGEDOWN then
		ScrollDown(pageStep)
		return true
	end
	--return false

	if not show then return false end

	if key >= 282 and key <= 293 then	-- Function keys
		return false
	end

	--local alt, ctrl, _, shift = Spring.GetModKeyState()
	if key == 27 then -- ESC
		clearChatInput()
	elseif key == 8 then -- BACKSPACE
		if inputTextPosition > 0 then
			inputText = utf8.sub(inputText, 1, inputTextPosition-1) .. utf8.sub(inputText, inputTextPosition+1)
			inputTextPosition = inputTextPosition - 1
		end
		cursorBlinkTimer = 0
		if inputText == '' then
			clearChatInput()
		else
			UpdateList(true)
		end
	elseif key == 127 then -- DELETE
		if inputTextPosition < utf8.len(inputText) then
			inputText = utf8.sub(inputText, 1, inputTextPosition) .. utf8.sub(inputText, inputTextPosition+2)
		end
		cursorBlinkTimer = 0
		UpdateList(true)
	elseif key == 277 then -- INSERT
		inputTextInsertActive = not inputTextInsertActive
	elseif key == 276 then -- LEFT
		inputTextPosition = inputTextPosition - 1
		if inputTextPosition < 0 then
			inputTextPosition = 0
		end
		cursorBlinkTimer = 0
	elseif key == 275 then -- RIGHT
		inputTextPosition = inputTextPosition + 1
		if inputTextPosition > utf8.len(inputText) then
			inputTextPosition = utf8.len(inputText)
		end
		cursorBlinkTimer = 0
	elseif key == 278 or key == 280 then -- HOME / PGUP
		inputTextPosition = 0
		cursorBlinkTimer = 0
	elseif key == 279 or key == 281 then -- END / PGDN
		inputTextPosition = utf8.len(inputText)
		cursorBlinkTimer = 0
	elseif key == 273 then -- UP

	elseif key == 274 then -- DOWN

	elseif key == 9 then -- TAB

	else
		-- regular chars/keys handled in widget:TextInput
	end

	updateTextInputDlist = true
	return true
end

function widget:Update(dt)
	cursorBlinkTimer = cursorBlinkTimer + dt
	if cursorBlinkTimer > cursorBlinkDuration then cursorBlinkTimer = 0 end
end

function widget:DrawScreen()
	if not show then
		if WG['guishader'] and activeGuishader then
			activeGuishader = false
			WG['guishader'].DeleteDlist('widgetselector')
			WG['guishader'].DeleteDlist('widgetselector2')
			WG['guishader'].RemoveRect('selectorinput')
			if textInputDlist then
				textInputDlist = gl.DeleteList(textInputDlist)
			end
		end
		return
	end

	if not WG['guishader'] then
		activeGuishader = false
	end

	local mx, my, lmb, mmb, rmb = Spring.GetMouseState()

	UpdateList()

	local prevBackgroundRect = backgroundRect or {0,0,1,1}
	backgroundRect = { floor(minx - (bgPadding * sizeMultiplier)), floor(miny - (bgPadding * sizeMultiplier)), floor(maxx + (bgPadding * sizeMultiplier)), floor(maxy + (bgPadding * sizeMultiplier)) }
	if backgroundRect[1] ~= prevBackgroundRect[1] or backgroundRect[2] ~= prevBackgroundRect[2] or backgroundRect[3] ~= prevBackgroundRect[3] or backgroundRect[4] ~= prevBackgroundRect[4] then
		updateUi = true
	end

	local title = Spring.I18N('ui.widgetselector.title')
	local titleFontSize = 18 * widgetScale
	titleRect = { backgroundRect[1], backgroundRect[4], math.floor(backgroundRect[1] + (font2:GetTextWidth(title) * titleFontSize) + (titleFontSize*1.5)), math.floor(backgroundRect[4] + (titleFontSize*1.7)) }
	borderx = (yStep * sizeMultiplier) * 0.75
	bordery = (yStep * sizeMultiplier) * 0.75

	if updateUi then
		dlistGuishader = gl.DeleteList(dlistGuishader)
		dlistGuishader = gl.CreateList(function()
			RectRound(floor(minx - (bgPadding * sizeMultiplier)), floor(miny - (bgPadding * sizeMultiplier)), floor(maxx + (bgPadding * sizeMultiplier)), floor(maxy + (bgPadding * sizeMultiplier)), 6 * sizeMultiplier)
		end)
		dlistGuishader2 = gl.DeleteList(dlistGuishader2)
		dlistGuishader2 = gl.CreateList(function()
			RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], 6 * sizeMultiplier)
		end)

		uiList = gl.DeleteList(uiList)
		uiList = gl.CreateList(function()
			UiElement(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], 0, 1, 1, 0, 1,1,1,1, math.max(0.75, Spring.GetConfigFloat("ui_opacity", 0.7)))

			-- title background
			gl.Color(0, 0, 0, math.max(0.75, Spring.GetConfigFloat("ui_opacity", 0.7)))
			RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], elementCorner, 1, 1, 0, 0)

			-- title
			font2:Begin()
			font2:SetTextColor(1, 1, 1, 1)
			font2:SetOutlineColor(0, 0, 0, 0.4)
			font2:Print(title, backgroundRect[1] + (titleFontSize * 0.75), backgroundRect[4] + (8*widgetScale), titleFontSize, "on")
			font2:End()
		end)
	end

	if WG['guishader'] and not activeGuishader then
		activeGuishader = true
		if dlistGuishader then
			WG['guishader'].InsertDlist(dlistGuishader, 'widgetselector')
			WG['guishader'].InsertDlist(dlistGuishader2, 'widgetselector2')
		end
	end

	local aboveWidget = aboveLabel(mx, my)
	local pointedName = (aboveWidget and aboveWidget[1]) or nil
	if pointedName ~= prevPointedName then
		updateUiList2 = true
	end
	prevPointedName = pointedName

	if prevLmb ~= lmb and math.isInRect(mx, my, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
		updateUiList2 = true
	end
	prevLmb = lmb

	-- content
	if updateUi or updateUiList2 then
		uiList2 = gl.DeleteList(uiList2)
		uiList2 = gl.CreateList(function()
			font:Begin()

			-- draw the widgets
			local pointedY = nil
			local posy = maxy - ((yStep + bgPadding) * sizeMultiplier)
			sby1 = posy + ((fontSize + fontSpace) * sizeMultiplier) * 0.5
			local prevFromZip = true
			local customWidgetPosy
			for _, namedata in ipairs(widgetsList) do

				local name = namedata[1]
				local data = namedata[2]

				if prevFromZip ~= data.fromZip then
					customWidgetPosy = posy
					font2:SetTextColor(0.5, 0.5, 0.5, 0.4)
					font2:Print(Spring.I18N('ui.widgetselector.islocal'), minx + fontSize * sizeMultiplier * 0.25, posy + (fontSize * sizeMultiplier) * 0.33, fontSize * sizeMultiplier, "")
				end

				local color = ''
				local pointed = (pointedName == name)
				local order = widgetHandler.orderList[name]
				local enabled = order and (order > 0)
				local active = data.active
				if pointed and not activescrollbar then
					pointedY = posy
					if not pagestepped and (lmb or mmb or rmb) then
						color = WhiteStr
					else
						color = (active and '\255\128\255\128') or (enabled and '\255\255\255\128') or '\255\255\128\128'
					end
				else
					color = (active and '\255\064\224\064') or (enabled and '\255\200\200\064') or '\255\224\064\064'
				end
				prevFromZip = data.fromZip
				font:Print(color .. name, midx, posy + (fontSize * sizeMultiplier) * 0.5, fontSize * sizeMultiplier, "vc")
				posy = posy - (yStep * sizeMultiplier)
			end
			if customWidgetPosy then
				gl.Color(1, 1, 1, 0.07)
				RectRound(backgroundRect[1]+elementPadding, customWidgetPosy + math.floor(yStep * sizeMultiplier * 0.85), backgroundRect[3]-elementPadding, customWidgetPosy + math.floor(yStep * sizeMultiplier * 0.85)-1, 0, 0,0,0,0)
				gl.Color(1, 1, 1, 0.035)
				RectRound(backgroundRect[1]+elementPadding, backgroundRect[2]+elementPadding, backgroundRect[3]-elementPadding, customWidgetPosy + math.floor(yStep * sizeMultiplier * 0.85), elementPadding, 0,0,1,0)
			end

			-- scrollbar
			if #widgetsList < #fullWidgetsList then
				sby2 = posy + (yStep * sizeMultiplier) - (fontSpace * sizeMultiplier) * 0.5
				sbheight = sby1 - sby2
				sbsize = sbheight * #widgetsList / #fullWidgetsList
				if activescrollbar then
					startEntry = math.max(0, math.min(
						floor(#fullWidgetsList *
							((sby1 - sbsize) -
								(my - math.min(scrollbargrabpos, sbsize)))
							/ sbheight + 0.5),
						#fullWidgetsList - curMaxEntries)) + 1
				end
				local sizex = maxx - minx
				sbposx = minx + sizex + 1.0 + (scrollbarOffset * widgetScale)
				sbposy = sby1 - sbsize - sbheight * (startEntry - 1) / #fullWidgetsList
				sbsizex = (yStep * sizeMultiplier)
				sbsizey = sbsize

				local scrollerPadding = 8 * sizeMultiplier

				-- background
				if (sbposx < mx and mx < sbposx + sbsizex and miny < my and my < maxy) or activescrollbar then
					RectRound(sbposx, miny, sbposx + (sbsizex * 0.61), maxy, 4.5 * sizeMultiplier, 1, 1, 1, 1, { 0.2, 0.2, 0.2, 0.2 }, { 0.5, 0.5, 0.5, 0.2 })
				end

				-- scroller
				if (sbposx < mx and mx < sbposx + sbsizex and sby2 < my and my < sby2 + sbheight) then
					gl.Color(1, 1, 1, 0.1)
					gl.Blending(GL.SRC_ALPHA, GL.ONE)
					RectRound(sbposx + scrollerPadding, sbposy, sbposx + sbsizex - scrollerPadding, sbposy + sbsizey, 1.75 * sizeMultiplier)
					gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
				end
				gl.Color(0.33, 0.33, 0.33, 0.8)
				RectRound(sbposx + scrollerPadding, sbposy, sbposx + sbsizex - scrollerPadding, sbposy + sbsizey, 1.75 * sizeMultiplier)
			else
				sbposx = 0.0
				sbposy = 0.0
				sbsizex = 0.0
				sbsizey = 0.0
			end

			-- highlight label
			if (sbposx < mx and mx < sbposx + sbsizex and miny < my and my < maxy) or activescrollbar then

			else
				if pointedY then
					local xn = minx + 0.5
					local xp = maxx - 0.5
					local yn = pointedY - ((fontSpace * 0.5 + 1) * sizeMultiplier)
					local yp = pointedY + ((fontSize + fontSpace * 0.5 + 1) * sizeMultiplier)
					if scrollbarOffset < 0 then
						xp = xp + scrollbarOffset
						--xn = xn - scrollbarOffset
					end
					yn = yn + 0.5
					yp = yp - 0.5
					gl.Blending(GL.SRC_ALPHA, GL.ONE)
					UiSelectHighlight(math.floor(xn), math.floor(yn), math.floor(xp), math.floor(yp), nil, lmb and 0.18 or 0.11)
					gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
				end
			end
			font:End()
		end)
	end

	updateUi = false
	updateUiList2 = false

	if uiList then
		gl.CallList(uiList)
	end

	if uiList2 then
		gl.CallList(uiList2)
	end

	if showButtons then
		font:Begin()
		local tcol
		for i, name in ipairs(buttons) do
			tcol = WhiteStr
			if minx < mx and mx < maxx and miny - (buttonTop * sizeMultiplier) - i * (buttonHeight * sizeMultiplier) < my and my < miny - (buttonTop * sizeMultiplier) - (i - 1) * (buttonHeight * sizeMultiplier) then
				tcol = '\255\031\031\031'
			end
			font:Print(tcol .. buttons[i], (minx + maxx) / 2, miny - (buttonTop * sizeMultiplier) - (i * (buttonHeight * sizeMultiplier)), buttonFontSize * sizeMultiplier, "oc")
		end
		font:End()
	end

	if WG['tooltip'] ~= nil then
		if aboveWidget then
			local n = aboveWidget[1]
			local d = aboveWidget[2]

			--local tt = (d.active and GreenStr) or (enabled and YellowStr) or RedStr
			local tooltipTitle = ''
			local order = widgetHandler.orderList[n]
			if order then
				if order >= 1 then
					if not d.active then
						tooltipTitle = '\255\255\240\160'..n..'\n'
					else
						tooltipTitle = '\255\130\255\160'..n..'\n'
					end
				else
					tooltipTitle = '\255\255\160\160'..n..'\n'
				end
			end
			local tooltip = ''
			local maxWidth = WG['tooltip'].getFontsize() * 90
			if d.desc and d.desc ~= '' then
				local textLines, numLines = font:WrapText(d.desc, maxWidth)
				tooltip = tooltip..WhiteStr..string.gsub(textLines, '[\n]', '\n'..WhiteStr)..'\n'
			end
			if d.author and d.author ~= '' then
				local textLines, numLines = font:WrapText(d.author, maxWidth)
				tooltip = tooltip.."\255\175\175\175" .. Spring.I18N('ui.widgetselector.author')..':  ' ..string.gsub(textLines, '[\n]', "\n\255\175\175\175")..'\n'
			end
			tooltip = tooltip .."\255\175\175\175".. Spring.I18N('ui.widgetselector.file')..':  '  ..d.basename .. (not d.fromZip and '   ('..Spring.I18N('ui.widgetselector.islocal')..')' or '')
			if WG['tooltip'] then
				WG['tooltip'].ShowTooltip('info', tooltip, nil, nil, tooltipTitle)
			end
		end
	end

	if showTextInput then --and updateTextInputDlist then
		drawChatInput()
	end
	if showTextInput and textInputDlist then
		gl.CallList(textInputDlist)
		drawChatInputCursor()
	elseif WG['guishader'] then
		WG['guishader'].RemoveRect('selectorinput')
		textInputDlist = gl.DeleteList(textInputDlist)
	end

	--local windowClick = (backgroundRect and math.isInRect(mx, my, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]))
	--local titleClick = (titleRect and math.isInRect(mx, my, titleRect[1], titleRect[2], titleRect[3], titleRect[4]))
	--local chatinputClick = (chatInputArea and math.isInRect(mx, my, chatInputArea[1], chatInputArea[2], chatInputArea[3], chatInputArea[4]))
	--if windowClick or titleClick or chatinputClick then
	--	Spring.SetMouseCursor('cursornormal')
	--end
end

function widget:MousePress(x, y, button)
	if Spring.IsGUIHidden() or not show then
		return false
	end

	UpdateList()

	local windowClick = (backgroundRect and math.isInRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]))
	local titleClick = (titleRect and math.isInRect(x, y, titleRect[1], titleRect[2], titleRect[3], titleRect[4]))
	local chatinputClick = (chatInputArea and math.isInRect(x, y, chatInputArea[1], chatInputArea[2], chatInputArea[3], chatInputArea[4]))

	if button == 1 then
		-- above a button
		if showButtons then
			if minx < x and x < maxx and miny - (buttonTop * sizeMultiplier) - #buttons * (buttonHeight * sizeMultiplier) < y and y < miny - (buttonTop * sizeMultiplier) then
				return true
			end
		end

		-- above the scrollbar
		if x >= minx + scrollbarOffset and x <= maxx + scrollbarOffset + (yStep * sizeMultiplier) then
			if y >= (maxy - bordery) and y <= maxy then
				if x > maxx + scrollbarOffset then
					ScrollUp(1)
				else
					ScrollUp(pageStep)
				end
				return true
			elseif y >= miny and y <= miny + bordery then
				if x > maxx + scrollbarOffset then
					ScrollDown(1)
				else
					ScrollDown(pageStep)
				end
				return true
			end
		end

		-- above the list
		if sbposx < x and x < sbposx + sbsizex and sbposy < y and y < sbposy + sbsizey then
			activescrollbar = true
			scrollbargrabpos = y - sbposy
			return true
		elseif sbposx < x and x < sbposx + sbsizex and sby2 < y and y < sby2 + sbheight then
			if y > sbposy + sbsizey then
				startEntry = math.max(1, math.min(startEntry - curMaxEntries, #fullWidgetsList - curMaxEntries + 1))
			elseif y < sbposy then
				startEntry = math.max(1, math.min(startEntry + curMaxEntries, #fullWidgetsList - curMaxEntries + 1))
			end
			UpdateListScroll()
			pagestepped = true
			return true
		end
	end

	if windowClick or titleClick or chatinputClick then
		return true
	else
		show = false
		widgetHandler.textOwner = nil		--widgetHandler:DisownText()
		return false
	end
end

function widget:MouseMove(x, y, dx, dy, button)
	if show and activescrollbar then
		startEntry = math.max(0, math.min(floor((#fullWidgetsList * ((sby1 - sbsize) - (y - math.min(scrollbargrabpos, sbsize))) / sbheight) + 0.5),
			#fullWidgetsList - curMaxEntries)) + 1
		UpdateListScroll()
		return true
	end
	return false
end

function widget:MouseRelease(x, y, mb)
	if Spring.IsGUIHidden() or not show then
		return -1
	end

	UpdateList()
	if pagestepped then
		pagestepped = false
		return true
	end

	if mb == 1 and activescrollbar then
		activescrollbar = false
		scrollbargrabpos = 0.0
		return -1
	end

	if mb == 1 then
		if maxx - 10 < x and x < maxx and maxy + bgPadding < y and y < maxy + buttonFontSize + 7 + bgPadding then
			-- + button
			curMaxEntries = curMaxEntries + 1
			UpdateListScroll()
			UpdateGeometry()
			Spring.WarpMouse(x, y + 0.5 * (fontSize + fontSpace))
			return -1
		end
		if minx < x and x < minx + 10 and maxy + bgPadding < y and y < maxy + buttonFontSize + 7 + bgPadding then
			-- - button
			if curMaxEntries > minMaxEntries then
				curMaxEntries = curMaxEntries - 1
				UpdateListScroll()
				UpdateGeometry()
				Spring.WarpMouse(x, y - 0.5 * (fontSize + fontSpace))
			end
			return -1
		end
	end

	if showButtons and mb == 1 then
		local buttonID = nil
		for i, _ in ipairs(buttons) do
			if minx < x and x < maxx and miny - (buttonTop * sizeMultiplier) - i * (buttonHeight * sizeMultiplier) < y and y < miny - (buttonTop * sizeMultiplier) - (i - 1) * (buttonHeight * sizeMultiplier) then
				buttonID = i
				break
			end
		end
		if buttonID == 1 then
			Spring.SendCommands("luarules reloadluaui")
			return -1
		end
		if buttonID == 2 then
			-- disable all widgets, but don't reload
			for _, namedata in ipairs(fullWidgetsList) do
				widgetHandler:DisableWidget(namedata[1])
			end
			widgetHandler:SaveConfigData()
			return -1
		end
		if buttonID == 3 and allowuserwidgets then
			-- tell the widget handler that we allow/disallow user widgets and reload
			if widgetHandler.allowUserWidgets then
				widgetHandler.__allowUserWidgets = false
				Spring.Echo("Disallowed user widgets, reloading...")
			else
				widgetHandler.__allowUserWidgets = true
				Spring.Echo("Allowed user widgets, reloading...")
			end
			Spring.SendCommands("luarules reloadluaui")
			return -1
		end
		if buttonID == 4 then
			Spring.SendCommands("luaui reset")
			return -1
		end
		if buttonID == 5 then
			Spring.SendCommands("luaui factoryreset")
			return -1
		end
	end

	local namedata = aboveLabel(x, y)
	if not namedata then
		return false
	end

	local name = namedata[1]
	local data = namedata[2]

	if mb == 1 then
		widgetHandler:ToggleWidget(name)
	elseif mb == 2 or mb == 3 then
		local w = widgetHandler:FindWidget(name)
		if not w then
			return -1
		end
		if mb == 2 then
			widgetHandler:LowerWidget(w)
			Spring.Echo('widgetHandler:LowerWidget')
		else
			widgetHandler:RaiseWidget(w)
			Spring.Echo('widgetHandler:RaiseWidget')
		end
		widgetHandler:SaveConfigData()
	end
	return -1
end

function aboveLabel(x, y)
	if x < minx or y < (miny + bordery) or
		x > maxx or y > (maxy - bordery) then
		return nil
	end
	local count = #widgetsList
	if count < 1 then
		return nil
	end

	local i = floor(1 + ((maxy - bordery) - y) / (yStep * sizeMultiplier))
	if i < 1 then
		i = 1
	elseif i == count then
		i = count
	end

	return widgetsList[i]
end


function widget:GetConfigData()
	local data = { startEntry = startEntry, show = show }
	return data
end

function widget:SetConfigData(data)
	startEntry = data.startEntry or startEntry
	show = data.show or show
	if show then
		widgetHandler.textOwner = self		--widgetHandler:OwnText()
		Spring.SDLStartTextInput()	-- because: touch chobby's text edit field once and widget:TextInput is gone for the game, so we make sure its started!
	end
end

function widget:Shutdown()
	Spring.SendCommands('bind f11 luaui selector') -- if this one is removed or crashes, then have the backup one take over.
	cancelChatInput()
	if WG['guishader'] then
		WG['guishader'].DeleteDlist('widgetselector')
		WG['guishader'].DeleteDlist('widgetselector2')
	end
	uiList = gl.DeleteList(uiList)
	uiList2 = gl.DeleteList(uiList2)
	gl.DeleteFont(font)
	gl.DeleteFont(font2)

	widgetHandler.actionHandler:RemoveAction(self, "widgetselector")
	widgetHandler.actionHandler:RemoveAction(self, "factoryreset")
	widgetHandler.actionHandler:RemoveAction(self, "userwidgets")
end
