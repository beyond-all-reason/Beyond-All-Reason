function widget:GetInfo()
	return {
		name      = "Chat",
		desc      = "chat/console (do /clearconsole to wipe history)",
		author    = "Floris",
		date      = "May 2021",
		license   = "GNU GPL, v2 or later",
		layer     = 30000,
		enabled   = true
	}
end

local vsx, vsy = gl.GetViewSizes()
local posY = 0.81
local posX = 0.3
local posX2 = 0.74
local charSize = 21 - (3.5 * ((vsx/vsy) - 1.78))
local consoleFontSizeMult = 0.85
local maxLines = 5
local maxConsoleLines = 2
local maxLinesScroll = 15
local lineHeightMult = 1.27
local lineTTL = 40
local capitalize = false	-- capitalize first letter of chat text
local backgroundOpacity = 0.18

local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale",1) or 1)
local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity",0.66) or 0.66)
local widgetScale = (((vsx+vsy) / 2000) * 0.55) * (0.95+(ui_scale-1)/1.5)

local fontsizeMult = 1
local usedFontSize = charSize*widgetScale*fontsizeMult
local usedConsoleFontSize = charSize*widgetScale*fontsizeMult*consoleFontSizeMult
local orgLines = {}
local chatLines = {}
local consoleLines = {}
local activationArea = {0,0,0,0}
local consoleActivationArea = {0,0,0,0}
local currentChatLine = 0
local currentConsoleLine = 0
local scrolling = false
local scrollingPosY = 0.66
local consolePosY = 0.9
local displayedChatLines = 0
local hideSpecChat = (Spring.GetConfigInt('HideSpecChat', 0) == 1)

local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local fontfile3 = "fonts/monospaced/" .. Spring.GetConfigString("bar_font3", "SourceCodePro-Medium.otf")
local font, font2, font3, chobbyInterface, hovering

local RectRound = Spring.FlowUI.Draw.RectRound
local UiElement = Spring.FlowUI.Draw.Element
local UiScroller = Spring.FlowUI.Draw.Scroller
local elementCorner = Spring.FlowUI.elementCorner
local elementPadding = Spring.FlowUI.elementPadding
local elementMargin = Spring.FlowUI.elementMargin

local playSound = true
local SoundIncomingChat  = 'beep4'
local SoundIncomingChatVolume = 0.85

local colorOther = {1,1,1} -- normal chat color
local colorAlly = {0,1,0}
local colorSpec = {1,1,0}
local colorOtherAlly = {1,0.7,0.45} -- enemy ally messages (seen only when spectating)
local colorGame = {0.4,1,1} -- server (autohost) chat
local colorConsole = {0.88,0.88,0.88}

local chatSeparator = '\255\210\210\210:'
local pointSeparator = '\255\255\255\255*'
local longestPlayername = '(s) [xx]playername'	-- setting a default minimum width

local maxPlayernameWidth = 50
local maxTimeWidth = 20
local lineSpaceWidth = 24*widgetScale
local lineMaxWidth = 0
local lineHeight = math.floor(usedFontSize*lineHeightMult)
local consoleLineHeight = math.floor(usedConsoleFontSize*lineHeightMult)
local consoleLineMaxWidth = 0
local backgroundPadding = usedFontSize
local gameOver = false

local glPopMatrix      = gl.PopMatrix
local glPushMatrix     = gl.PushMatrix
local glDeleteList     = gl.DeleteList
local glCreateList     = gl.CreateList
local glCallList       = gl.CallList
local glTranslate      = gl.Translate
local glColor          = gl.Color

local floor = math.floor
local clock = os.clock
local schar = string.char
local slen = string.len
local ssub = string.sub
local sfind = string.find
local spGetPlayerRoster = Spring.GetPlayerRoster
local spGetTeamColor = Spring.GetTeamColor
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spPlaySoundFile = Spring.PlaySoundFile
local spGetGameFrame = Spring.GetGameFrame

local teamColorKeys = {}
local teams = Spring.GetTeamList()
for i = 1, #teams do
	local r, g, b, a = spGetTeamColor(teams[i])
	teamColorKeys[teams[i]] = r..'_'..g..'_'..b
end
teams = nil

local function isOnRect(x, y, leftX, bottomY,rightX,TopY)
	return x >= leftX and x <= rightX and y >= bottomY and y <= TopY
end

local function lines(str)
	local text = {}
	local function helper(line) text[#text+1] = line return "" end
	helper((str:gsub("(.-)\r?\n", helper)))
	return text
end

local function wordWrap(text, maxWidth, fontSize)
	local lines = {}
	local lineCount = 0
	for _, line in ipairs(text) do
		local words = {}
		local wordsCount = 0
		local linebuffer = ''
		for w in line:gmatch("%S+") do
			wordsCount = wordsCount + 1
			words[wordsCount] = w
		end
		for _, word in ipairs(words) do
			if font:GetTextWidth(linebuffer..' '..word)*fontSize > maxWidth then
				lineCount = lineCount + 1
				lines[lineCount] = linebuffer
				linebuffer = ''
			end
			linebuffer = (linebuffer ~= '' and linebuffer..' '..word or word)
		end
		if linebuffer ~= '' then
			lineCount = lineCount + 1
			lines[lineCount] = linebuffer
		end
	end
	return lines
end

local function addConsoleLine(gameFrame, lineType, text, isLive)
	if not text or text == '' then return end

	-- convert /n into lines
	local textLines = lines(text)

	-- word wrap text into lines
	local wordwrappedText = wordWrap(textLines, consoleLineMaxWidth, usedConsoleFontSize)

	local consoleLinesCount = #consoleLines
	local lineColor = #wordwrappedText > 1 and ssub(wordwrappedText[1], 1, 4) or ''
	local startTime = clock()
	for i, line in ipairs(wordwrappedText) do
		consoleLinesCount = consoleLinesCount + 1
		consoleLines[consoleLinesCount] = {
			startTime = startTime,
			gameFrame = i == 1 and gameFrame,
			lineType = lineType,
			text = (i > 1 and lineColor or '')..line,
			--lineDisplayList = glCreateList(function() end),
			--timeDisplayList = glCreateList(function() end),
		}
	end

	if scrolling ~= 'console' then
		currentConsoleLine = consoleLinesCount
	end

	-- play sound for ...
	--if isLive and playSound and not Spring.IsGUIHidden() then
	--	spPlaySoundFile( SoundIncomingChat, SoundIncomingChatVolume, nil, "ui" )
	--end
end

local function addChat(gameFrame, lineType, name, text, isLive)
	if not text or text == '' then return end

	-- determine text typing start time
	local startTime = clock()

	-- convert /n into lines
	local textLines = lines(text)

	-- word wrap text into lines
	local wordwrappedText = wordWrap(textLines, lineMaxWidth, usedFontSize)


	local chatLinesCount = #chatLines
	local lineColor = #wordwrappedText > 1 and ssub(wordwrappedText[1], 1, 4) or ''
	for i, line in ipairs(wordwrappedText) do
		chatLinesCount = chatLinesCount + 1
		chatLines[chatLinesCount] = {
			startTime = startTime,
			gameFrame = i == 1 and gameFrame,
			lineType = lineType,
			playerName = name,
			text = (i > 1 and lineColor or '')..line,
			--lineDisplayList = glCreateList(function() end),
			--timeDisplayList = glCreateList(function() end),
		}
	end

	if scrolling ~= 'chat' then
		currentChatLine = #chatLines
	end

	-- play sound for player/spectator chat
	if isLive and (lineType == 1 or lineType == 2) and playSound and not Spring.IsGUIHidden() then
		spPlaySoundFile( SoundIncomingChat, SoundIncomingChatVolume, nil, "ui" )
	end
end

function widget:Initialize()
	widget:ViewResize()
	Spring.SendCommands("console 0")

	WG['chat'] = {}
	WG['chat'].getBackgroundOpacity = function()
		return backgroundOpacity
	end
	WG['chat'].setBackgroundOpacity = function(value)
		backgroundOpacity = value
	end
	WG['chat'].getCapitalize = function()
		return capitalize
	end
	WG['chat'].setCapitalize = function(value)
		capitalize = value
		widget:ViewResize()
	end
	WG['chat'].getMaxLines = function()
		return maxLines
	end
	WG['chat'].setMaxLines = function(value)
		maxLines = value
		widget:ViewResize()
	end
	WG['chat'].getMaxConsoleLines = function()
		return maxLines
	end
	WG['chat'].setMaxConsoleLines = function(value)
		maxConsoleLines = value
		widget:ViewResize()
	end
	WG['chat'].getFontsize = function()
		return fontsizeMult
	end
	WG['chat'].setFontsize = function(value)
		fontsizeMult = value
		widget:ViewResize()
	end
end

local uiSec = 0
function widget:Update(dt)
	uiSec = uiSec + dt
	if uiSec > 1 then
		uiSec = 0
		if ui_scale ~= Spring.GetConfigFloat("ui_scale",1) or ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66)  then
			ui_scale = Spring.GetConfigFloat("ui_scale",1)
			ui_opacity = Spring.GetConfigFloat("ui_opacity",0.65)
			widget:ViewResize()
		end
		if hideSpecChat ~= (Spring.GetConfigInt('HideSpecChat', 0) == 1) then
			hideSpecChat = (Spring.GetConfigInt('HideSpecChat', 0) == 1)
			widget:ViewResize()
		end

		-- check if team colors have changed
		local teams = Spring.GetTeamList()
		local detectedChanges = false
		for i = 1, #teams do
			local r, g, b, a = spGetTeamColor(teams[i])
			if teamColorKeys[teams[i]] ~= r..'_'..g..'_'..b then
				teamColorKeys[teams[i]] = r..'_'..g..'_'..b
				detectedChanges = true
			end
		end
		if detectedChanges then
			widget:ViewResize()
		end
	end

	local x,y,b = Spring.GetMouseState()

	local heightDiff = scrolling and floor(vsy*(scrollingPosY-posY)) or 0
	if WG['topbar'] and WG['topbar'].showingQuit() then
		scrolling = false
	elseif isOnRect(x, y, activationArea[1], activationArea[2], activationArea[3], activationArea[4]) then
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		if ctrl and shift then
			if isOnRect(x, y, consoleActivationArea[1], consoleActivationArea[2], consoleActivationArea[3], consoleActivationArea[4]) then
				scrolling = 'console'
			else
				scrolling = 'chat'
			end
		end
	elseif scrolling and isOnRect(x, y, activationArea[1], activationArea[2]+heightDiff, activationArea[3], activationArea[2]) then
		-- do nothing
	else
		scrolling = false
		currentChatLine = #chatLines
	end
end

local function createGameTimeDisplayList(gametime)
	return glCreateList(function()
		local minutes = floor((gametime / 30 / 60))
		local seconds = floor((gametime - ((minutes*60)*30)) / 30)
		if seconds == 0 then
			seconds = '00'
		elseif seconds < 10 then
			seconds = '0'..seconds
		end
		local offset = 0
		if minutes >= 100 then
			offset = (usedFontSize*0.2*widgetScale)
		end
		local gameTime = '\255\200\200\200'..minutes..':'..seconds
		font3:Begin()
		font3:Print(gameTime, maxTimeWidth+offset, usedFontSize*0.3, usedFontSize*0.82, "ro")
		font3:End()
	end)
end

local function processConsoleLine(i)
	if consoleLines[i].lineDisplayList == nil then
		glDeleteList(consoleLines[i].lineDisplayList)
		local fontHeightOffset = usedFontSize*0.24
		consoleLines[i].lineDisplayList = glCreateList(function()
			font:Begin()
			font:Print(consoleLines[i].text, 0, fontHeightOffset, usedConsoleFontSize, "o")
			font:End()
		end)

		-- game time (for when viewing history)
		if consoleLines[i].gameFrame then
			glDeleteList(consoleLines[i].timeDisplayList)
			consoleLines[i].timeDisplayList = createGameTimeDisplayList(consoleLines[i].gameFrame)
		end
	end
end


local function processLine(i)
	if chatLines[i].lineDisplayList == nil then
		glDeleteList(chatLines[i].lineDisplayList)
		local fontHeightOffset = usedFontSize*0.24
		chatLines[i].lineDisplayList = glCreateList(function()
			font:Begin()
			if chatLines[i].gameFrame then

				-- player name
				font:Print(chatLines[i].playerName, maxPlayernameWidth, fontHeightOffset, usedFontSize, "or")

				-- mapmark point
				if chatLines[i].lineType == 3 then
					font:Print(pointSeparator, maxPlayernameWidth+(lineSpaceWidth/2), 0, usedFontSize, "oc")
				else
					font:Print(chatSeparator, maxPlayernameWidth+(lineSpaceWidth/3.8), fontHeightOffset, usedFontSize, "oc")
				end
			end
			font:Print(chatLines[i].text, maxPlayernameWidth+lineSpaceWidth, fontHeightOffset, usedFontSize, "o")
			font:End()
		end)

		-- game time (for when viewing history)
		if chatLines[i].gameFrame then
			glDeleteList(chatLines[i].timeDisplayList)
			chatLines[i].timeDisplayList = createGameTimeDisplayList(chatLines[i].gameFrame)
		end
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreen()
	if chobbyInterface then return end
	if not chatLines[1] and not consoleLines[1] then return end

	local x,y,b = Spring.GetMouseState()
	local heightDiff = scrolling and floor(vsy*(scrollingPosY-posY)) or 0
	if hovering and WG['guishader'] then
		WG['guishader'].RemoveRect('chat')
	end
	if isOnRect(x, y, activationArea[1], activationArea[2]+heightDiff, activationArea[3], activationArea[4]) or  (scrolling and isOnRect(x, y, activationArea[1], activationArea[2]+heightDiff, activationArea[3], activationArea[2]))  then
		hovering = true
		if scrolling then
			glColor(0,0,0,backgroundOpacity)
			UiElement(activationArea[1], activationArea[2]+heightDiff, activationArea[3], activationArea[4])

			-- player name background
			if scrolling == 'chat' then
				local gametimeEnd = floor(backgroundPadding+maxTimeWidth+(backgroundPadding*0.75))
				local playernameEnd = gametimeEnd + maxPlayernameWidth+(lineSpaceWidth/2)
				glColor(1,1,1,0.045)
				RectRound(activationArea[1]+gametimeEnd, activationArea[2]+elementPadding+heightDiff, activationArea[1]+playernameEnd, activationArea[4]-elementPadding, elementCorner*0.66, 0,0,0,0)
				-- vertical line at start and end
				glColor(1,1,1,0.045)
				RectRound(activationArea[1]+playernameEnd-1, activationArea[2]+elementPadding+heightDiff, activationArea[1]+playernameEnd, activationArea[4]-elementPadding, 0, 0,0,0,0)
				RectRound(activationArea[1]+gametimeEnd, activationArea[2]+elementPadding+heightDiff, activationArea[1]+gametimeEnd+1, activationArea[4]-elementPadding, 0, 0,0,0,0)
			end

			local scrollbarMargin = floor(16 * widgetScale)
			local scrollbarWidth = floor(11 * widgetScale)
			UiScroller(
				floor(activationArea[3]-scrollbarMargin-scrollbarWidth),
				floor(activationArea[2]+heightDiff+scrollbarMargin),
				floor(activationArea[3]-scrollbarMargin),
				floor(activationArea[4]-scrollbarMargin),
				scrolling == 'console' and #consoleLines*lineHeight or #chatLines*lineHeight,
				scrolling == 'console' and (currentConsoleLine-maxLinesScroll)*lineHeight or (currentChatLine-maxLinesScroll)*lineHeight
			)

			if WG['guishader'] then
				WG['guishader'].InsertRect(activationArea[1], activationArea[2]+heightDiff, activationArea[3], activationArea[4], 'chat')
			end
		else
			if backgroundOpacity > 0 and displayedChatLines > 0  then
				glColor(0,0,0,backgroundOpacity)
				--RectRound(activationArea[1], activationArea[2]+heightDiff, activationArea[3], activationArea[4], elementCorner)
				RectRound(activationArea[1], activationArea[2], activationArea[3], activationArea[2]+((displayedChatLines+1)*lineHeight)+(displayedChatLines==maxLines and 0 or elementPadding), elementCorner)
			end
		end
	else
		hovering = false
		if backgroundOpacity > 0 and displayedChatLines > 0 then
			glColor(0,0,0,backgroundOpacity)
			--RectRound(activationArea[1], activationArea[2]+heightDiff, activationArea[3], activationArea[4], elementCorner)
			RectRound(activationArea[1], activationArea[2], activationArea[3], activationArea[2]+((displayedChatLines+1)*lineHeight)+(displayedChatLines==maxLines and 0 or elementPadding), elementCorner)
		end
		scrolling = false
		currentChatLine = #chatLines
	end

	-- draw console lines
	if not scrolling and consoleLines[1] then
		glPushMatrix()
		glTranslate((vsx * posX) + backgroundPadding, (consolePosY*vsy)+(usedConsoleFontSize*0.24), 0)
		local checkedLines = 0
		local i = #consoleLines
		while i > 0 do
			if clock() - consoleLines[i].startTime < lineTTL then
				processConsoleLine(i)
				glCallList(consoleLines[i].lineDisplayList)
			else
				break
			end
			checkedLines = checkedLines + 1
			if checkedLines >= maxConsoleLines then
				break
			end
			i = i - 1
			glTranslate(0, consoleLineHeight, 0)
		end
		glPopMatrix()
	end

	-- draw chat lines / panel
	if scrolling or chatLines[currentChatLine] then
		local checkedLines = 0
		displayedChatLines = 0
		glPushMatrix()
		glTranslate((vsx * posX) + backgroundPadding, vsy * (scrolling and scrollingPosY or posY) + backgroundPadding, 0)
		local i = scrolling == 'console' and currentConsoleLine or currentChatLine
		local usedMaxLines = maxLines
		if scrolling then
			usedMaxLines = maxLinesScroll
		end
		local width = floor(maxTimeWidth+(lineHeight*0.75))
		while i > 0 do
			if scrolling or clock() - chatLines[i].startTime < lineTTL then
				if scrolling == 'console' then
					processConsoleLine(i)
				else
					processLine(i)
				end
				if scrolling then
					if scrolling == 'console' then
						if consoleLines[i].timeDisplayList then
							glCallList(consoleLines[i].timeDisplayList)
						end
					else
						if chatLines[i].timeDisplayList then
							glCallList(chatLines[i].timeDisplayList)
						end
					end
					glTranslate(width, 0, 0)
				end
				--if scrolling == 'chat' and isOnRect(x, y, activationArea[1]+backgroundPadding, activationArea[4], activationArea[3]-backgroundPadding, activationArea[4]+(lineHeight*(maxLinesScroll-displayedLines))) then
				--	RectRound(0, 0, (activationArea[3]-activationArea[1])-backgroundPadding-backgroundPadding-maxTimeWidth, lineHeight, elementCorner*0.66, 0,0,0,0, {1,1,1,0.15}, {0.8,0.8,0.8,0.15})
				--end
				glCallList(scrolling == 'console' and consoleLines[i].lineDisplayList or chatLines[i].lineDisplayList)
				if scrolling  then
					glTranslate(-width, 0, 0)
				end
				displayedChatLines = displayedChatLines + 1
			else
				break
			end
			checkedLines = checkedLines + 1
			if checkedLines >= usedMaxLines then
				break
			end
			i = i - 1
			glTranslate(0, lineHeight, 0)
		end
		glPopMatrix()

		-- show new chat when in scrolling mode
		if scrolling and currentChatLine < #chatLines and clock() - chatLines[#chatLines].startTime < lineTTL then
			glPushMatrix()
			glTranslate(vsx * posX, vsy * ((scrolling and scrollingPosY or posY)-0.02)-backgroundPadding, 0)
			processLine(#chatLines)
			glCallList(chatLines[#chatLines].lineDisplayList)
			glPopMatrix()
		end
	end
end

function widget:MouseWheel(up, value)
	if scrolling then
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		if up then
			if scrolling == 'console' then
				currentConsoleLine = currentConsoleLine - (shift and maxLinesScroll or (ctrl and 3 or 1))
				if currentConsoleLine < maxLinesScroll then
					currentConsoleLine = maxLinesScroll
					if currentConsoleLine > #consoleLines then
						currentConsoleLine = #consoleLines
					end
				end
			else
				currentChatLine = currentChatLine - (shift and maxLinesScroll or (ctrl and 3 or 1))
				if currentChatLine < maxLinesScroll then
					currentChatLine = maxLinesScroll
					if currentChatLine > #chatLines then
						currentChatLine = #chatLines
					end
				end
			end
		else
			if scrolling == 'console' then
				currentConsoleLine = currentConsoleLine + (shift and maxLinesScroll or (ctrl and 3 or 1))
				if currentConsoleLine > #consoleLines then
					currentConsoleLine = #consoleLines
				end
			else
				currentChatLine = currentChatLine + (shift and maxLinesScroll or (ctrl and 3 or 1))
				if currentChatLine > #chatLines then
					currentChatLine = #chatLines
				end
			end
		end
		return true
	else
		return false
	end
end

function widget:WorldTooltip(ttType,data1,data2,data3)
	local x,y,_ = Spring.GetMouseState()
	local heightDiff = scrolling and floor(vsy*(scrollingPosY-posY)) or 0
	if #chatLines > 0 and isOnRect(x, y, activationArea[1],activationArea[2]+heightDiff,activationArea[3],activationArea[4]) then
		return Spring.I18N('ui.chat.scroll', { textColor = "\255\255\255\255", highlightColor = "\255\255\255\001" })
	end
end

local function convertColor(r,g,b)
	return schar(255, (r*255), (g*255), (b*255))
end

local function processConsoleLine(gameFrame, line, addOrgLine)
	local orgLine = line

	local roster = spGetPlayerRoster()
	local names = {}
	for i=1, #roster do
		names[roster[i][1]] = {roster[i][4],roster[i][5],roster[i][3],roster[i][2]}
	end

	local name = ''
	local text = ''
	local lineType = 0
	local bypassThisMessage = false
	local skipThisMessage = false
	local textcolor, c

	-- player message
	if names[ssub(line,2,(sfind(line,"> ", nil, true) or 1)-1)] ~= nil then
		lineType = 1
		name = ssub(line,2,sfind(line,"> ", nil, true)-1)
		text = ssub(line,slen(name)+4)

		if sfind(text,'Allies: ', nil, true) == 1 then
			text = ssub(text,9)
			if names[name][1] == spGetMyAllyTeamID() then
				c = colorAlly
			else
				c = colorOtherAlly
			end
		elseif sfind(text,'Spectators: ', nil, true) == 1 then
			text = ssub(text,13)
			c = colorSpec
		else
			c = colorOther
		end


		-- filter occasional starting space
		if ssub(text,1,1) == ' ' then
			text = ssub(text,2)
		end
		if capitalize and text:len() >= 10 then
			text = ssub(text,1,1):upper()..ssub(text,2)
		end

		name = convertColor(spGetTeamColor(names[name][3]))..name
		line = convertColor(c[1],c[2],c[3])..text

		-- spectator message
	elseif names[ssub(line,2,(sfind(line,"] ", nil, true) or 1)-1)] ~= nil  or  names[ssub(line,2,(sfind(line," (replay)] ", nil, true) or 1)-1)] ~= nil then
		lineType = 2
		if names[ssub(line,2,(sfind(line,"] ", nil, true) or 1)-1)] ~= nil then
			name = ssub(line,2,sfind(line,"] ", nil, true)-1)
			text = ssub(line,slen(name)+4)
		else
			name = ssub(line,2,sfind(line," (replay)] ", nil, true)-1)
			text = ssub(line,slen(name)+13)
		end

		-- filter specs
		if hideSpecChat then
			skipThisMessage = true
		end

		if sfind(text,'Allies: ', nil, true) == 1 then
			text = ssub(text,9)
			c = colorSpec
		elseif sfind(text,'Spectators: ', nil, true) == 1 then
			text = ssub(text,13)
			c = colorSpec
		else
			c = colorOther
		end

		-- filter occasional starting space
		if ssub(text,1,1) == ' ' then
			text = ssub(text,2)
		end
		if capitalize and text:len() >= 10 then
			text = ssub(text,1,1):upper()..ssub(text,2)
		end

		name = convertColor(colorSpec[1],colorSpec[2],colorSpec[3])..'(s) '..name
		line = convertColor(c[1],c[2],c[3])..text

		-- point
	elseif names[ssub(line,1,(sfind(line," added point: ", nil, true) or 1)-1)] ~= nil then
		lineType = 3
		name = ssub(line,1,sfind(line," added point: ", nil, true)-1)
		text = ssub(line,slen(name.." added point: ")+1)
		if text == '' then
			text = 'Look here!'
		end

		local namecolor
		local spectator = true
		if names[name] ~= nil then
			spectator = names[name][2]
		end
		if spectator then
			name = '(s) '..name
			namecolor = convertColor(colorSpec[1],colorSpec[2],colorSpec[3])
			textcolor = convertColor(colorSpec[1],colorSpec[2],colorSpec[3])

			-- filter specs
			if hideSpecChat then
				skipThisMessage = true
			end
		else
			namecolor =  convertColor(spGetTeamColor(names[name][3]))

			if names[name][1] == spGetMyAllyTeamID() then
				textcolor = convertColor(colorAlly[1],colorAlly[2],colorAlly[3])
			else
				textcolor = convertColor(colorOtherAlly[1],colorOtherAlly[2],colorOtherAlly[3])
			end
		end

		if capitalize and text:len() >= 10 then
			text = ssub(text,1,1):upper()..ssub(text,2)
		end

		name = namecolor..name
		line = textcolor..text

		-- battleroom message
	elseif ssub(line,1,1) == ">" then
		lineType = 4
		text = ssub(line,3)
		if ssub(line,1,3) == "> <" then -- player speaking in battleroom
			local i = sfind(ssub(line,4,slen(line)), ">", nil, true)
			if i then
				name = ssub(line,4,i+2)
				text = ssub(line,i+5)
			else
				name = "unknown"
			end
		else
			bypassThisMessage = true
		end
		-- filter specs
		local spectator = false
		if names[name] ~= nil then
			spectator = names[name][2]
		end
		if hideSpecChat and (not names[name] or spectator) then
			skipThisMessage = true
		end

		-- filter occasional starting space
		if ssub(text,1,1) == ' ' then
			text = ssub(text,2)
		end

		--if capitalize and text:len() >= 10 then
		--	text = ssub(text,1,1):upper()..ssub(text,2)
		--end

		name = convertColor(colorGame[1],colorGame[2],colorGame[3])..'<'..name..'>'
		line = convertColor(colorGame[1],colorGame[2],colorGame[3])..text

		-- console chat
	else
		lineType = -1

		if sfind(line, "Input grabbing is ", nil, true) then
			bypassThisMessage = true
		elseif sfind(line," to access the quit menu", nil, true) then
			bypassThisMessage = true
		elseif sfind(line,"VSync::SetInterval", nil, true) then
			bypassThisMessage = true
		elseif sfind(line," now spectating team ", nil, true) then
			bypassThisMessage = true
		elseif sfind(line,"TotalHideLobbyInterface, ", nil, true) then	-- filter lobby on/off message
			bypassThisMessage = true
		elseif sfind(line,"HandleLobbyOverlay", nil, true) then
			bypassThisMessage = true
		elseif sfind(line,"->", nil, true) then
			bypassThisMessage = true
		elseif sfind(line,"server=[0-9a-z][0-9a-z][0-9a-z][0-9a-z]") or sfind(line,"client=[0-9a-z][0-9a-z][0-9a-z][0-9a-z]") then	-- filter hash messages: server= / client=
			bypassThisMessage = true

		--2 lines (instead of 4) appears when player connects
		elseif sfind(line,'-> Version', nil, true) or sfind(line,'ClientReadNet', nil, true) or sfind(line,'Address', nil, true) then
			bypassThisMessage = true
		elseif sfind(line,"Wrong network version", nil, true) then
			local n,_ = sfind(line,"Message", nil, true)
			if n ~= nil then
				line = ssub(line,1,n-3) --shorten so as these messages don't get clipped and can be detected as duplicates
			end
		elseif gameOver and sfind(line,'left the game', nil, true) then
			bypassThisMessage = true
		end

		line = convertColor(colorConsole[1],colorConsole[2],colorConsole[3])..line
	end
	-- bot command
	if ssub(text,1,1) == '!' and  ssub(text, 1,2) ~= '!!' then
		bypassThisMessage = true
	end

	if sfind(line, 'My player ID is', nil, true) then
		bypassThisMessage = true
	end
	-- ignore muted players
	if WG.ignoredPlayers and WG.ignoredPlayers[name] then
		skipThisMessage = true
	end

	-- ignore muted players
	if WG.ignoredPlayers and WG.ignoredPlayers[name] then
		bypassThisMessage = true
	end

	if not bypassThisMessage and line ~= '' then
		if addOrgLine then
			orgLines[#orgLines+1] = {gameFrame, orgLine}
		end
		if lineType < 1 then
			addConsoleLine(gameFrame, lineType, line, addOrgLine)
		elseif not skipThisMessage then
			addChat(gameFrame, lineType, name, line, addOrgLine)
		end
	end
end

function widget:MapDrawCmd(playerID, cmdType, x, y, z, a, b, c)
	local time = clock()
	local gameFrame = spGetGameFrame()
	if cmdType == 'point' then

	elseif cmdType == 'line' then

	elseif cmdType == 'erase' then

	end
end

function widget:AddConsoleLine(lines, priority)
	lines = lines:match('^\[f=[0-9]+\] (.*)$') or lines
	for line in lines:gmatch("[^\n]+") do
		processConsoleLine(spGetGameFrame(), line, true)
	end
end


local function clearDisplayLists()
	for i, _ in ipairs(chatLines) do
		if chatLines[i].lineDisplayList then
			glDeleteList(chatLines[i].lineDisplayList)
			chatLines[i].lineDisplayList = nil
		end
		if chatLines[i].timeDisplayList then
			glDeleteList(chatLines[i].timeDisplayList)
			chatLines[i].timeDisplayList = nil
		end
	end
	for i, _ in ipairs(consoleLines) do
		if consoleLines[i].lineDisplayList then
			glDeleteList(consoleLines[i].lineDisplayList)
			consoleLines[i].lineDisplayList = nil
		end
		if consoleLines[i].timeDisplayList then
			glDeleteList(consoleLines[i].timeDisplayList)
			consoleLines[i].timeDisplayList = nil
		end
	end
end

local function processLines()
	clearDisplayLists()
	chatLines = {}
	consoleLines = {}
	for _, params in ipairs(orgLines) do
		processConsoleLine(params[1], params[2])
	end
	currentChatLine = #chatLines
end

function widget:TextCommand(command)
	if string.find(command, "clearconsole", nil, true) == 1  and  string.len(command) == 12 then
		orgLines = {}
		processLines()
	end
end

function widget:ViewResize()
	vsx,vsy = Spring.GetViewGeometry()
	widgetScale = (((vsx+vsy) / 2000) * 0.55) * (0.95+(ui_scale-1)/1.5)

	UiElement = Spring.FlowUI.Draw.Element
	UiScroller = Spring.FlowUI.Draw.Scroller
	elementCorner = Spring.FlowUI.elementCorner
	elementPadding = Spring.FlowUI.elementPadding
	elementMargin = Spring.FlowUI.elementMargin

	usedFontSize = charSize*widgetScale*fontsizeMult
	usedConsoleFontSize = charSize*widgetScale*fontsizeMult*consoleFontSizeMult
	font = WG['fonts'].getFont(nil, (charSize/18)*fontsizeMult, 0.19, 1.75)
	font3 = WG['fonts'].getFont(fontfile3, (charSize/18)*fontsizeMult, 0.19, 1.75)

	-- get longest player name and calc its width
	local namePrefix = '(s)'
	maxPlayernameWidth = font:GetTextWidth(namePrefix..longestPlayername) * usedFontSize
	local playersList = Spring.GetPlayerList()
	for _, playerID in ipairs(playersList) do
		local name = Spring.GetPlayerInfo(playerID, false)
		if name ~= longestPlayername and font:GetTextWidth(namePrefix..name)*usedFontSize > maxPlayernameWidth then
			longestPlayername = name
			maxPlayernameWidth = font:GetTextWidth(namePrefix..longestPlayername) * usedFontSize
		end
	end
	maxTimeWidth = font3:GetTextWidth('00:00') * usedFontSize
	lineSpaceWidth = 24*widgetScale
	lineHeight = floor(usedFontSize*lineHeightMult)
	backgroundPadding = elementPadding + floor(lineHeight*0.5)

	local posY2 = 0.94
	if WG['topbar'] ~= nil then
		local topbarArea = WG['topbar'].GetPosition()
		posY2 = floor(topbarArea[2] - elementMargin)/vsy
		posX = topbarArea[1]/vsx
		scrollingPosY = floor(topbarArea[2] - elementMargin - backgroundPadding - backgroundPadding - (lineHeight*maxLinesScroll)) / vsy
	end
	consolePosY = floor((vsy * posY2) - backgroundPadding - (maxConsoleLines * consoleLineHeight)) / vsy
	posY = floor((consolePosY*vsy) - (backgroundPadding*1.5) - ((lineHeight*maxLines))) / vsy

	activationArea = {
		floor(vsx * posX),
		floor(vsy * posY),
		floor(vsx * posX2),
		floor(vsy * posY2),
	}
	consoleActivationArea = {
		floor(vsx * posX),
		floor(vsy * consolePosY),
		floor(vsx * posX2),
		floor(vsy * posY2),
	}

	lineMaxWidth = floor((activationArea[3] - activationArea[1]) * 0.65)
	consoleLineMaxWidth = floor((activationArea[3] - activationArea[1]) * 0.88)

	processLines()
end

function widget:Shutdown()
	clearDisplayLists()
	WG['chat'] = nil
	Spring.SendCommands("console 1")
end

function widget:GameOver()
	gameOver = true
end

function widget:GetConfigData(data)
	return {
		gameFrame = Spring.GetGameFrame(),
		orgLines = gameOver and nil or orgLines,
		maxLines = maxLines,
		maxConsoleLines = maxConsoleLines,
		capitalize = capitalize,
		fontsizeMult = fontsizeMult,
		chatBackgroundOpacity = backgroundOpacity
	}
end

function widget:SetConfigData(data)
	if data.orgLines ~= nil then
		if Spring.GetGameFrame() > 0 or (data.gameFrame and data.gameFrame == 0) then
			orgLines = data.orgLines
		end
	end
	if data.chatBackgroundOpacity ~= nil then
		backgroundOpacity = data.chatBackgroundOpacity
	end
	if data.maxLines ~= nil then
		maxLines = data.maxLines
	end
	if data.maxConsoleLines ~= nil then
		maxConsoleLines = data.maxConsoleLines
	end
	if data.capitalize ~= nil then
		capitalize = data.capitalize
	end
	if data.fontsizeMult ~= nil then
		fontsizeMult = data.fontsizeMult
	end
end
