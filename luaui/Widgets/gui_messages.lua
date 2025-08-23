local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Messages",
		desc      = "Typewrites messages at the center-bottom of the screen",
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

local posY = 0.16
local charSize = 19.5 - (3.5 * ((vsx/vsy) - 1.78))
local charDelay = 0.022
local maxLines = 4
local lineTTL = 15

local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale",1) or 1)
local widgetScale = (((vsx+vsy) / 2000) * 0.55) * (0.95+(ui_scale-1)/1.5)

local glPopMatrix      = gl.PopMatrix
local glPushMatrix     = gl.PushMatrix
local glDeleteList     = gl.DeleteList
local glCreateList     = gl.CreateList
local glCallList       = gl.CallList
local glTranslate      = gl.Translate

local messageLines = {}
local currentLine = 0
local currentTypewriterLine = 0
local lineMaxWidth = 0

local font, buildmenuBottomPosition

local hideSpecChat = tonumber(Spring.GetConfigInt("HideSpecChat", 0) or 0) == 1
local string_lines = string.lines

function widget:ViewResize()
	vsx,vsy = Spring.GetViewGeometry()
	lineMaxWidth = lineMaxWidth / widgetScale
	widgetScale = (((vsx+vsy) / 2000) * 0.55) * (0.95+(ui_scale-1)/1.5)
	lineMaxWidth = lineMaxWidth * widgetScale

	font = WG['fonts'].getFont()

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
		if messageLines[i].displaylist then
			glDeleteList(messageLines[i].displaylist)
			messageLines[i].displaylist = nil
		end
	end

	local area = {
		(vsx * 0.31)-(charSize*widgetScale), (vsy * posY)+(charSize*0.15*widgetScale),
		(vsx * 0.6), (vsy * (posY+0.065))
	}
	lineMaxWidth = math.max(lineMaxWidth, area[3] - area[1])
end

local function addMessage(text)
	if text then
		-- determine text typing start time
		local startTime = os.clock()
		if messageLines[#messageLines] then
			if startTime < messageLines[#messageLines].starttime + messageLines[#messageLines].textlen*charDelay then
				startTime = messageLines[#messageLines].starttime + messageLines[#messageLines].textlen*charDelay
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
				starttime = startTime,
				text = line,
				textlen = string.len(line),
				charstyped = 0,  -- num typed chars
				timepassed = 0,  -- time passed during typing chars (used to calc 'num typed chars')
				displaylist = glCreateList(function() end),
				charsindisplaylist = 0,   -- num chars the displaylist contains
				pos = 1,
			}
			startTime = startTime + (string.len(line)*charDelay)
		end

		if currentTypewriterLine > messageLinesCount then
			currentTypewriterLine = messageLinesCount
		end
		currentLine = currentTypewriterLine
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

	currentLine = #messageLines

	if messageLines[currentTypewriterLine] ~= nil then
		-- continue typewriting line
		if messageLines[currentTypewriterLine].charstyped <= messageLines[currentTypewriterLine].textlen then
			messageLines[currentTypewriterLine].timepassed = messageLines[currentTypewriterLine].timepassed + dt
			messageLines[currentTypewriterLine].charstyped = math.ceil(messageLines[currentTypewriterLine].timepassed/charDelay)

			-- typewrite next line when complete
			if messageLines[currentTypewriterLine].charstyped >= messageLines[currentTypewriterLine].textlen then
				currentTypewriterLine = currentTypewriterLine + 1
				if currentTypewriterLine > #messageLines then
					currentTypewriterLine = #messageLines
				end
			end
		end
	end
end

local function processLine(i)
	if messageLines[i].displaylist == nil or messageLines[i].charstyped ~= messageLines[i].charsindisplaylist or messageLines[i].pos ~= (currentLine+1)-i then
		messageLines[i].pos = (currentLine+1)-i
		messageLines[i].charsindisplaylist = messageLines[i].charstyped
		local text = string.sub(messageLines[i].text, 1, messageLines[i].charstyped)
		lineMaxWidth = math.max(lineMaxWidth, font:GetTextWidth(text)*charSize*widgetScale)
		glDeleteList(messageLines[i].displaylist)
		messageLines[i].displaylist = glCreateList(function()
			font:Begin()
			font:SetTextColor(0.94,0.94,0.94,1)
			font:SetOutlineColor(0,0,0,1)
			font:Print(text, 0, 0, charSize*widgetScale, "o")
			font:End()
		end)
	end
end

function widget:DrawScreen()
	if not messageLines[1] then return end

	if messageLines[currentLine] then
		glPushMatrix()
		glTranslate((vsx * 0.31), (vsy * posY), 0)
		local displayedLines = 0
		local i = currentLine
		while i > 0 do
			glTranslate(0, (charSize*1.15*widgetScale), 0)
			if os.clock() - messageLines[i].starttime < lineTTL then
				processLine(i)
				glCallList(messageLines[i].displaylist)
			end
			displayedLines = displayedLines + 1
			if displayedLines >= maxLines then
				break
			end
			i = i - 1
		end
		glPopMatrix()
	end
end

function widget:Shutdown()
	WG['messages'] = nil
	for i, _ in ipairs(messageLines) do
		if messageLines[i].displaylist then
			glDeleteList(messageLines[i].displaylist)
			messageLines[i].displaylist = nil
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
		messageLines[i].displaylist = nil
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
