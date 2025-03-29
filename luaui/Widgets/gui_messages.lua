local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Messages",
		desc      = "Typewrites messages at the center-bottom of the screen (missions, tutorials)",
		author    = "Floris",
		date      = "September 2019",
		license   = "GNU GPL, v2 or later",
		layer     = 30000,
		enabled   = true
	}
end

--------------------------------------------------------------------------------

-- Widgets can call: WG['messages'].addMessage('message text')
-- Gadgets (unsynced) can call: Script.LuaUI.GadgetAddMessage('message text')
-- plain text (without markup) via: /addmessage message text

--------------------------------------------------------------------------------

local vsx, vsy = gl.GetViewSizes()

local allowInteraction = false	-- hovering and ctrl+shift shows background + scrollable history
local posY = 0.16
local charSize = 19.5 - (3.5 * ((vsx/vsy) - 1.78))
local charDelay = 0.018
local maxLines = 4
local maxLinesScroll = 10
local lineTTL = 15
local fadeTime = 0.3
local fadeDelay = 0.25   -- need to hover this long in order to fadein and respond to CTRL
local backgroundOpacity = 0.17

local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale",1) or 1)
local widgetScale = (((vsx+vsy) / 2000) * 0.55) * (0.95+(ui_scale-1)/1.5)

local glPopMatrix      = gl.PopMatrix
local glPushMatrix     = gl.PushMatrix
local glDeleteList     = gl.DeleteList
local glCreateList     = gl.CreateList
local glCallList       = gl.CallList
local glTranslate      = gl.Translate
local glColor          = gl.Color

local messageLines = {}
local activationArea = {0,0,0,0}
local activatedHeight = 0
local currentLine = 0
local currentTypewriterLine = 0
local scrolling = false
local lineMaxWidth = 0

local font, hovering, startFadeTime, buildmenuBottomPosition

local RectRound, elementCorner

local hideSpecChat = tonumber(Spring.GetConfigInt("HideSpecChat", 0) or 0) == 1
local math_isInRect = math.isInRect
local string_lines = string.lines

function widget:ViewResize()
	vsx,vsy = Spring.GetViewGeometry()
	lineMaxWidth = lineMaxWidth / widgetScale
	widgetScale = (((vsx+vsy) / 2000) * 0.55) * (0.95+(ui_scale-1)/1.5)
	lineMaxWidth = lineMaxWidth * widgetScale

	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound

	font = WG['fonts'].getFont(nil, 1, 0.18, 1.4)

	if WG['buildmenu'] then
		buildmenuBottomPosition = WG['buildmenu'].getBottomPosition()
	end

	posY = 0.16
	if buildmenuBottomPosition then
		posY = 0.21
		if WG['ordermenu'] then
			local oposX, oposY, owidth, oheight = WG['ordermenu'].getPosition()
			if oposY > 0.5 then
				posY = 0.16
			end
		end
	end

	for i, _ in ipairs(messageLines) do
		if messageLines[i][6] then
			glDeleteList(messageLines[i][6])
			messageLines[i][6] = nil
		end
	end

	activationArea = {
		(vsx * 0.31)-(charSize*widgetScale), (vsy * posY)+(charSize*0.15*widgetScale),
		(vsx * 0.6), (vsy * (posY+0.065))
	}
	lineMaxWidth = math.max(lineMaxWidth, activationArea[3] - activationArea[1])
	activatedHeight = (1+maxLinesScroll)*charSize*1.15*widgetScale
end

local function addMessage(text)
	if text then
		-- determine text typing start time
		local startTime = os.clock()
		if messageLines[#messageLines] then
			if startTime < messageLines[#messageLines][1] + messageLines[#messageLines][3]*charDelay then
				startTime = messageLines[#messageLines][1] + messageLines[#messageLines][3]*charDelay
			else
				currentTypewriterLine = currentTypewriterLine + 1
			end
		else
			currentTypewriterLine = currentTypewriterLine + 1
		end

		-- convert /n into lines
		local textLines = string_lines(text)

		-- word wrap text into lines
		local wordwrappedText = {}
		local wordwrappedTextCount = 0
		for _, line in ipairs(textLines) do
			local words = {}
			local wordsCount = 0
			local linebuffer = ''
			for w in line:gmatch("%S+") do
				wordsCount = wordsCount + 1
				words[wordsCount] = w
			end
			for _, word in ipairs(words) do
				if font:GetTextWidth(linebuffer..' '..word)*charSize*widgetScale > lineMaxWidth then
					wordwrappedTextCount = wordwrappedTextCount + 1
					wordwrappedText[wordwrappedTextCount] = linebuffer
					linebuffer = ''
				end
				if linebuffer == '' then
					linebuffer = word
				else
					linebuffer = linebuffer..' '..word
				end
			end
			if linebuffer ~= '' then
				wordwrappedTextCount = wordwrappedTextCount + 1
				wordwrappedText[wordwrappedTextCount] = linebuffer
			end
		end

		local messageLinesCount = #messageLines
		for _, line in ipairs(wordwrappedText) do
			lineMaxWidth = math.max(lineMaxWidth, font:GetTextWidth(line)*charSize*widgetScale)
			messageLinesCount = messageLinesCount + 1
			messageLines[messageLinesCount] = {
				startTime,
				line,
				string.len(line),
				0,  -- num typed chars
				0,  -- time passed during typing chars (used to calc 'num typed chars')
				glCreateList(function() end),
				0   -- num chars the displaylist contains
			}
			startTime = startTime + (string.len(line)*charDelay)
		end

		if currentTypewriterLine > messageLinesCount then
			currentTypewriterLine = messageLinesCount
		end
		if not scrolling then
			currentLine = currentTypewriterLine
		end
	end
end

function widget:Initialize()
	widget:ViewResize()
	widgetHandler:RegisterGlobal('GadgetAddMessage', addMessage)
	WG['messages'] = {}
	WG['messages'].addMessage = function(text)
		addMessage(text)
	end
end

local uiSec = 0
local buildmenuBottomPos = false
function widget:Update(dt)
	uiSec = uiSec + dt
	if uiSec > 0.5 then
		uiSec = 0
		if ui_scale ~= Spring.GetConfigFloat("ui_scale",1) then
			ui_scale = Spring.GetConfigFloat("ui_scale",1)
			widget:ViewResize()
		end
		if hideSpecChat ~= tonumber(Spring.GetConfigInt("HideSpecChat", 0) or 0) == 1 then
			hideSpecChat = tonumber(Spring.GetConfigInt("HideSpecChat", 0) or 0) == 1
		end
		if WG['buildmenu'] and WG['buildmenu'].getBottomPosition then
			local prevbuildmenuBottomPos = buildmenuBottomPos
			buildmenuBottomPos = WG['buildmenu'].getBottomPosition()
			if buildmenuBottomPos ~= prevbuildmenuBottomPos then
				widget:ViewResize()
			end
		end
	end

	local x,y,b = Spring.GetMouseState()
	if WG['topbar'] and WG['topbar'].showingQuit() then
		scrolling = false
	elseif math_isInRect(x, y, activationArea[1], activationArea[2], activationArea[3], activationArea[4]) then
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		if ctrl and shift and startFadeTime and os.clock() > startFadeTime+fadeDelay then
			scrolling = true
		end
	elseif scrolling and math_isInRect(x, y, activationArea[1], activationArea[2], activationArea[1]+lineMaxWidth+(charSize*2*widgetScale), activationArea[2]+activatedHeight) then
		-- do nothing
	else
		scrolling = false
		currentLine = #messageLines
	end

	if messageLines[currentTypewriterLine] ~= nil then
		-- continue typewriting line
		if messageLines[currentTypewriterLine][4] <= messageLines[currentTypewriterLine][3] then
			messageLines[currentTypewriterLine][5] = messageLines[currentTypewriterLine][5] + dt
			messageLines[currentTypewriterLine][4] = math.ceil(messageLines[currentTypewriterLine][5]/charDelay)

			-- typewrite next line when complete
			if messageLines[currentTypewriterLine][4] >= messageLines[currentTypewriterLine][3] then
				currentTypewriterLine = currentTypewriterLine + 1
				if currentTypewriterLine > #messageLines then
					currentTypewriterLine = #messageLines
				end
			end
		end
	end
end

local function processLine(i)
	if messageLines[i][6] == nil or messageLines[i][4] ~= messageLines[i][7] then
		messageLines[i][7] = messageLines[i][4]
		local text = string.sub(messageLines[i][2], 1, messageLines[i][4])
		glDeleteList(messageLines[i][6])
		messageLines[i][6] = glCreateList(function()
			font:Begin()
			lineMaxWidth = math.max(lineMaxWidth, font:GetTextWidth(text)*charSize*widgetScale)
			font:Print(text, 0, 0, charSize*widgetScale, "o")
			font:End()
		end)
	end
end

function widget:DrawScreen()
	if not messageLines[1] then return end

	if allowInteraction then
		local x,y,b = Spring.GetMouseState()
		if math_isInRect(x, y, activationArea[1], activationArea[2], activationArea[3], activationArea[4]) or  (scrolling and math_isInRect(x, y, activationArea[1], activationArea[2], activationArea[1]+lineMaxWidth+(charSize*2*widgetScale), activationArea[2]+activatedHeight))  then
			hovering = true
			if not startFadeTime then
				startFadeTime = os.clock()
			end
			if scrolling then
				glColor(0,0,0,backgroundOpacity)
				RectRound(activationArea[1], activationArea[2], activationArea[1]+lineMaxWidth+(charSize*2*widgetScale), activationArea[2]+activatedHeight, elementCorner)
			else
				local opacity = ((os.clock() - (startFadeTime+fadeDelay)) / fadeTime) * backgroundOpacity
				if opacity > backgroundOpacity then
					opacity = backgroundOpacity
				end
				glColor(0,0,0,opacity)
				RectRound(activationArea[1], activationArea[2], activationArea[3], activationArea[4], elementCorner)
			end
		else
			if hovering then
				local opacityPercentage = (os.clock() - (startFadeTime+fadeDelay)) / fadeTime
				startFadeTime = os.clock() - math.max((1-opacityPercentage)*fadeTime, 0)
			end
			hovering = false
			if startFadeTime then
				local opacity = backgroundOpacity - (((os.clock() - startFadeTime) / fadeTime) * backgroundOpacity)
				if opacity > 1 then
					opacity = 1
				end
				if opacity <= 0 then
					startFadeTime = nil
				else
					glColor(0,0,0,opacity)
					RectRound(activationArea[1], activationArea[2], activationArea[3], activationArea[4], elementCorner)
				end
			end
			scrolling = false
			currentLine = #messageLines
		end
	end

	if messageLines[currentLine] then
		glPushMatrix()
		glTranslate((vsx * 0.31), (vsy * posY), 0)
		local displayedLines = 0
		local i = currentLine
		local usedMaxLines = maxLines
		if scrolling then
			usedMaxLines = maxLinesScroll
		end
		while i > 0 do
			glTranslate(0, (charSize*1.15*widgetScale), 0)
			if scrolling or os.clock() - messageLines[i][1] < lineTTL then
				processLine(i)
				glCallList(messageLines[i][6])
			end
			displayedLines = displayedLines + 1
			if displayedLines >= usedMaxLines then
				break
			end
			i = i - 1
		end
		glPopMatrix()

		-- show newly written line when in scrolling mode
		if scrolling and currentLine < #messageLines and os.clock() - messageLines[currentTypewriterLine][1] < lineTTL then
			glPushMatrix()
			glTranslate((vsx * 0.31), (vsy * (posY-0.02)), 0)
			processLine(currentTypewriterLine)
			glCallList(messageLines[currentTypewriterLine][6])
			glPopMatrix()
		end
	end
end

function widget:MouseWheel(up, value)
	if allowInteraction and scrolling then
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		if up then
			currentLine = currentLine - (shift and maxLinesScroll or (ctrl and 3 or 1))
			if currentLine < maxLinesScroll then
				currentLine = maxLinesScroll
				if currentLine > #messageLines then
					currentLine = #messageLines
				end
			end
		else
			currentLine = currentLine + (shift and maxLinesScroll or (ctrl and 3 or 1))
			if currentLine > #messageLines then
				currentLine = #messageLines
			end
		end
		return true
	else
		return false
	end
end

function widget:WorldTooltip(ttType,data1,data2,data3)
	local x,y,_ = Spring.GetMouseState()
	if #messageLines > 0 and math_isInRect(x, y, activationArea[1],activationArea[2],activationArea[3],activationArea[4]) then
		return Spring.I18N('ui.messages.scroll', { textColor = "\255\255\255\255", highlightColor = "\255\255\255\001" })
	end
end

function widget:Shutdown()
	WG['messages'] = nil
	for i, _ in ipairs(messageLines) do
		if messageLines[i][6] then
			glDeleteList(messageLines[i][6])
			messageLines[i][6] = nil
		end
	end
	widgetHandler:DeregisterGlobal('GadgetAddMessage')
end

function widget:TextCommand(command)
	if string.sub(command,1, 11) == "addmessage " then
		addMessage(string.sub(command, 11))
	end
end

function widget:GetConfigData(data)
	for i, _ in ipairs(messageLines) do
		messageLines[i][6] = nil
	end
	return {messageLines = messageLines}
end

function widget:SetConfigData(data)
	if Spring.GetGameFrame() > 0 and data.messageLines ~= nil then
		messageLines = data.messageLines
		currentLine = #messageLines
		currentTypewriterLine = currentLine
	end
end
