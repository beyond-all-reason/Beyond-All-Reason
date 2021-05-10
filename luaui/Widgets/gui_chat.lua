function widget:GetInfo()
	return {
		name      = "Chat",
		desc      = "Typewrites chat",
		author    = "Floris",
		date      = "May 2021",
		license   = "GNU GPL, v2 or later",
		layer     = 30000,
		enabled   = true
	}
end

local vsx, vsy = gl.GetViewSizes()
local posY = 0.81
local posYoffset = 0.04 --0.01	-- add extra distance (non scrolling)
local posX = 0.3
local posX2 = 0.74
local charSize = 21 - (3.5 * ((vsx/vsy) - 1.78))
local charDelay = 0.0015
local maxLines = 5
local maxLinesScroll = 15
local lineHeightMult = 1.27
local lineTTL = 45

local fadeTime = 0.3
local fadeDelay = 0.15   -- need to hover this long in order to fadein and respond to CTRL

local backgroundOpacity = 0
local hoverShowBackground = false

local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale",1) or 1)
local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity",0.66) or 0.66)
local widgetScale = (((vsx+vsy) / 2000) * 0.55) * (0.95+(ui_scale-1)/1.5)

local fontsizeMult = 1
local usedFontSize = charSize*widgetScale*fontsizeMult
local chatLines = {}
local activationArea = {0,0,0,0}
local currentLine = 0
local currentTypewriterLine = 0
local scrolling = false
local scrollingPosY = 0.66

local filterSpecs = (Spring.GetConfigInt('HideSpecChat', 0) == 1)

local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local font, font2, chobbyInterface, hovering, startFadeTime

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
local colorMisc = {0.85,0.85,0.85} -- everything else
local colorGame = {0.4,1,1} -- server (autohost) chat

local chatSeparator = '\255\210\210\210:'
local pointSeparator = '\255\255\255\255*'
local longestPlayername = '(s) [xx]playername'	-- setting a default minimum width

local maxPlayernameWidth = 50
local maxTimeWidth = 20
local lineSpaceWidth = 24*widgetScale
local lineMaxWidth = 0
local lineHeight = math.floor(usedFontSize*lineHeightMult)
local backgroundPadding = usedFontSize

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

local function lines(str)
	local text = {}
	local function helper(line) text[#text+1] = line return "" end
	helper((str:gsub("(.-)\r?\n", helper)))
	return text
end

local function isOnRect(x, y, leftX, bottomY,rightX,TopY)
	return x >= leftX and x <= rightX and y >= bottomY and y <= TopY
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
	--font = WG['fonts'].getFont(nil, (charSize/18)*fontsizeMult, 0.18, 1.9)
	font = WG['fonts'].getFont(fontfile2, (charSize/18)*fontsizeMult, 0.18, 1.9)
	font2 = WG['fonts'].getFont(fontfile2, (charSize/18)*fontsizeMult, 0.18, 2.3)

	-- get longest playername and calc its width
	local namePrefix = '(s)'
	maxPlayernameWidth = font2:GetTextWidth(namePrefix..longestPlayername) * usedFontSize
	local playersList = Spring.GetPlayerList()
	for _, playerID in ipairs(playersList) do
		local name = Spring.GetPlayerInfo(playerID, false)
		if name ~= longestPlayername and font2:GetTextWidth(namePrefix..name)*usedFontSize > maxPlayernameWidth then
			longestPlayername = name
			maxPlayernameWidth = font2:GetTextWidth(namePrefix..longestPlayername) * usedFontSize
		end
	end
	maxTimeWidth = font:GetTextWidth('00:00') * usedFontSize
	lineSpaceWidth = 24*widgetScale
	lineHeight = floor(usedFontSize*lineHeightMult)
	backgroundPadding = elementPadding + floor(lineHeight*0.5)

	if WG['topbar'] ~= nil then
		local topbarArea = WG['topbar'].GetPosition()
		activationArea[4] = topbarArea[2] - elementMargin
		posY = floor(topbarArea[2] - elementMargin - backgroundPadding - backgroundPadding - (posYoffset * vsy) - (lineHeight*maxLines)) / vsy
		scrollingPosY = floor(topbarArea[2] - elementMargin - backgroundPadding - backgroundPadding - (lineHeight*maxLinesScroll)) / vsy
	end

	-- clear old displaylists
	for i, _ in ipairs(chatLines) do
		if chatLines[i][9] then
			glDeleteList(chatLines[i][9])
			chatLines[i][9] = nil
		end
	end

	activationArea = {
		floor(vsx * posX),
		floor(vsy * posY),
		floor(vsx * posX2),
		floor(vsy * (posY+0.12))
	}
	if WG['topbar'] ~= nil then
		local topbarArea = WG['topbar'].GetPosition()
		activationArea[4] = topbarArea[2] - elementMargin
		activationArea[1] = topbarArea[1]
	end

	lineMaxWidth = floor((activationArea[3] - activationArea[1]) * 0.65)
end

local function addChat(ignore, type, name, text)
	if not text or text == '' then return end

	-- determine text typing start time
	local startTime = clock()
	if chatLines[#chatLines] then
		if startTime < chatLines[#chatLines][1] + chatLines[#chatLines][6]*charDelay then
			startTime = chatLines[#chatLines][1] + chatLines[#chatLines][6]*charDelay
		else
			currentTypewriterLine = currentTypewriterLine + 1
		end
	else
		currentTypewriterLine = currentTypewriterLine + 1
	end

	-- convert /n into lines
	local textLines = lines(text)

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
			if font:GetTextWidth(linebuffer..' '..word)*usedFontSize > lineMaxWidth then
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

	local chatLinesCount = #chatLines
	local lineColor = ''
	if #wordwrappedText > 1 then
		lineColor = ssub(wordwrappedText[1], 1, 4)
	end
	for i, line in ipairs(wordwrappedText) do
		chatLinesCount = chatLinesCount + 1
		chatLines[chatLinesCount] = {
			startTime,
			i == 1 and spGetGameFrame(),
			type,
			name,
			(i > 1 and lineColor or '')..line,
			slen(line),
			0,  -- num typed chars
			0,  -- time passed during typing chars (used to calc 'num typed chars')
			glCreateList(function() end),
			0   -- num chars the displaylist contains
		}
		startTime = startTime + (slen(line)*charDelay)
	end

	if currentTypewriterLine > chatLinesCount then
		currentTypewriterLine = chatLinesCount
	end
	if not scrolling then
		currentLine = currentTypewriterLine
	end

	-- play sound for player/spectator chat
	if (type == 1 or type == 2) and playSound and not Spring.IsGUIHidden() then
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
	WG['chat'].getMaxLines = function()
		return maxLines
	end
	WG['chat'].setMaxLines = function(value)
		maxLines = value
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
	if uiSec > 0.5 then
		uiSec = 0
		if ui_scale ~= Spring.GetConfigFloat("ui_scale",1) or ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66)  then
			ui_scale = Spring.GetConfigFloat("ui_scale",1)
			ui_opacity = Spring.GetConfigFloat("ui_opacity",0.65)
			widget:ViewResize()
		end
	end

	local x,y,b = Spring.GetMouseState()

	local heightDiff = scrolling and floor(vsy*(scrollingPosY-posY)) or 0
	if WG['topbar'] and WG['topbar'].showingQuit() then
		scrolling = false
	elseif isOnRect(x, y, activationArea[1], activationArea[2], activationArea[3], activationArea[4]) then
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		if ctrl and startFadeTime and clock() > startFadeTime+fadeDelay then
			scrolling = true
		end
	elseif scrolling and isOnRect(x, y, activationArea[1], activationArea[2]+heightDiff, activationArea[3], activationArea[2]) then
		-- do nothing
	else
		scrolling = false
		currentLine = #chatLines
	end

	if chatLines[currentTypewriterLine] ~= nil then
		-- continue typewriting line
		if chatLines[currentTypewriterLine][7] <= chatLines[currentTypewriterLine][6] then
			chatLines[currentTypewriterLine][8] = chatLines[currentTypewriterLine][8] + dt
			chatLines[currentTypewriterLine][7] = math.ceil(chatLines[currentTypewriterLine][8]/charDelay)

			-- typewrite next line when complete
			if chatLines[currentTypewriterLine][7] >= chatLines[currentTypewriterLine][6] then
				currentTypewriterLine = currentTypewriterLine + 1
				if currentTypewriterLine > #chatLines then
					currentTypewriterLine = #chatLines
				end
			end
		end
	end
end

local function processLine(i)
	if chatLines[i][9] == nil or chatLines[i][7] ~= chatLines[i][10] then
		chatLines[i][10] = chatLines[i][7]
		glDeleteList(chatLines[i][9])
		local fontHeightOffset = usedFontSize*0.24
		chatLines[i][9] = glCreateList(function()
			local text = ssub(chatLines[i][5], 1, chatLines[i][7])
			if chatLines[i][2] then

				-- player name
				font2:Begin()
				font2:Print(chatLines[i][4], maxPlayernameWidth, fontHeightOffset, usedFontSize, "or")
				font2:End()

				-- mapmark point
				font:Begin()
				if chatLines[i][3] == 3 then
					font:Print(pointSeparator, maxPlayernameWidth+(lineSpaceWidth/2), 0, usedFontSize, "oc")
				else
					font:Print(chatSeparator, maxPlayernameWidth+(lineSpaceWidth/3.8), fontHeightOffset, usedFontSize, "oc")
				end
				font:End()

			end
			font:Begin()
			font:Print(text, maxPlayernameWidth+lineSpaceWidth, fontHeightOffset, usedFontSize, "o")
			font:End()
		end)

		-- game time (for when viewing history)
		if chatLines[i][2] then
			glDeleteList(chatLines[i][11])
			chatLines[i][11] = glCreateList(function()
				local minutes = floor((chatLines[i][2] / 30 / 60))
				local seconds = floor((chatLines[i][2] - ((minutes*60)*30)) / 30)
				if seconds == 0 then
					seconds = '00'
				elseif seconds < 10 then
					seconds = '0'..seconds
				end
				local gameTime = '\255\200\200\200'..minutes..':'..seconds
				font:Begin()
				font:Print(gameTime, backgroundPadding, fontHeightOffset, usedFontSize*0.82, "o")
				font:End()
			end)
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
	if not chatLines[1] then return end

	local x,y,b = Spring.GetMouseState()
	local heightDiff = scrolling and floor(vsy*(scrollingPosY-posY)) or 0
	if hovering and WG['guishader'] then
		WG['guishader'].RemoveRect('chat')
	end
	if isOnRect(x, y, activationArea[1], activationArea[2]+heightDiff, activationArea[3], activationArea[4]) or  (scrolling and isOnRect(x, y, activationArea[1], activationArea[2]+heightDiff, activationArea[3], activationArea[2]))  then
		hovering = true
		if not startFadeTime then
			startFadeTime = clock()
		end
		if scrolling then
			glColor(0,0,0,backgroundOpacity)
			UiElement(activationArea[1], activationArea[2]+heightDiff, activationArea[3], activationArea[4])

			-- player name background
			local gametimeEnd = floor(backgroundPadding+maxTimeWidth+(backgroundPadding*0.75))
			local playernameEnd = gametimeEnd + maxPlayernameWidth+(lineSpaceWidth/2)
			glColor(1,1,1,0.045)
			RectRound(activationArea[1]+gametimeEnd, activationArea[2]+elementPadding+heightDiff, activationArea[1]+playernameEnd, activationArea[4]-elementPadding, elementCorner*0.66, 0,0,0,0)
			-- vertical line at start and end
			glColor(1,1,1,0.045)
			RectRound(activationArea[1]+playernameEnd-1, activationArea[2]+elementPadding+heightDiff, activationArea[1]+playernameEnd, activationArea[4]-elementPadding, 0, 0,0,0,0)
			RectRound(activationArea[1]+gametimeEnd, activationArea[2]+elementPadding+heightDiff, activationArea[1]+gametimeEnd+1, activationArea[4]-elementPadding, 0, 0,0,0,0)

			local scrollbarMargin = floor(16 * widgetScale)
			local scrollbarWidth = floor(11 * widgetScale)
			UiScroller(
					floor(activationArea[3]-scrollbarMargin-scrollbarWidth),
					floor(activationArea[2]+heightDiff+scrollbarMargin),
					floor(activationArea[3]-scrollbarMargin),
					floor(activationArea[4]-scrollbarMargin),
					#chatLines*lineHeight,
					(currentLine-maxLinesScroll)*lineHeight
			)

			if WG['guishader'] then
				WG['guishader'].InsertRect(activationArea[1], activationArea[2]+heightDiff, activationArea[3], activationArea[4], 'chat')
			end
		else
			if backgroundOpacity > 0 then
				glColor(0,0,0,backgroundOpacity)
				RectRound(activationArea[1], activationArea[2]+heightDiff, activationArea[3], activationArea[4], elementCorner)
			elseif hoverShowBackground then
				local opacity = ((clock() - (startFadeTime+fadeDelay)) / fadeTime) * backgroundOpacity
				if opacity > backgroundOpacity then
					opacity = backgroundOpacity
				end
				glColor(0,0,0,opacity)
				RectRound(activationArea[1], activationArea[2]+heightDiff, activationArea[3], activationArea[4], elementCorner)
			end
		end
	else
		if hovering then
			local opacityPercentage = (clock() - (startFadeTime+fadeDelay)) / fadeTime
			startFadeTime = clock() - math.max((1-opacityPercentage)*fadeTime, 0)
		end
		hovering = false
		if backgroundOpacity > 0 then
			glColor(0,0,0,backgroundOpacity)
			RectRound(activationArea[1], activationArea[2]+heightDiff, activationArea[3], activationArea[4], elementCorner)
		elseif hoverShowBackground and startFadeTime then
			local opacity = backgroundOpacity - (((clock() - startFadeTime) / fadeTime) * backgroundOpacity)
			if opacity > 1 then
				opacity = 1
			end
			if opacity <= 0 then
				startFadeTime = nil
			else
				glColor(0,0,0,opacity)
				RectRound(activationArea[1], activationArea[2]+heightDiff, activationArea[3], activationArea[4], elementCorner)
			end
		end
		scrolling = false
		currentLine = #chatLines
	end

	if chatLines[currentLine] then
		glPushMatrix()
		glTranslate((vsx * posX) + backgroundPadding, vsy * (scrolling and scrollingPosY or posY) + backgroundPadding, 0)
		local displayedLines = 0
		local i = currentLine
		local usedMaxLines = maxLines
		if scrolling then
			usedMaxLines = maxLinesScroll
		end
		local width = floor(maxTimeWidth+(lineHeight*0.75))
		while i > 0 do
			if scrolling or clock() - chatLines[i][1] < lineTTL then
				processLine(i)
				if scrolling then
					if chatLines[i][11] then
						glCallList(chatLines[i][11])
					end
					glTranslate(width, 0, 0)
				end
				--if scrolling then
				--	RectRound(0, 0, (activationArea[3]-activationArea[1])-backgroundPadding-backgroundPadding-maxTimeWidth, lineHeight, elementCorner*0.66, 0,0,0,0, {1,1,1,0.03}, {1,1,1,0})
				--end
				glCallList(chatLines[i][9])
				if scrolling  then
					glTranslate(-width, 0, 0)
				end
			end
			displayedLines = displayedLines + 1
			if displayedLines >= usedMaxLines then
				break
			end
			i = i - 1
			glTranslate(0, lineHeight, 0)
		end
		glPopMatrix()

		-- show newly written line when in scrolling mode
		if scrolling and currentLine < #chatLines and clock() - chatLines[currentTypewriterLine][1] < lineTTL then
			glPushMatrix()
			glTranslate(vsx * posX, vsy * ((scrolling and scrollingPosY or posY)-0.02)-backgroundPadding, 0)
			processLine(currentTypewriterLine, true)
			glCallList(chatLines[currentTypewriterLine][9])
			glPopMatrix()
		end
	end
end

function widget:MouseWheel(up, value)
	if scrolling then
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		if up then
			currentLine = currentLine - (shift and maxLinesScroll or (ctrl and 3 or 1))
			if currentLine < maxLinesScroll then
				currentLine = maxLinesScroll
				if currentLine > #chatLines then
					currentLine = #chatLines
				end
			end
		else
			currentLine = currentLine + (shift and maxLinesScroll or (ctrl and 3 or 1))
			if currentLine > #chatLines then
				currentLine = #chatLines
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
		return Spring.I18N('ui.messages.scroll', { textColor = "\255\255\255\255", highlightColor = "\255\255\255\001" })
	end
end


function widget:Shutdown()
	for i, _ in ipairs(chatLines) do
		if chatLines[i][9] then
			glDeleteList(chatLines[i][9])
			chatLines[i][9] = nil
		end
	end
	WG['chat'] = nil
	Spring.SendCommands("console 1")
end

local function convertColor(r,g,b)
	return schar(255, (r*255), (g*255), (b*255))
end

local function processConsoleLine(line)
	local roster = spGetPlayerRoster()
	local names = {}
	for i=1, #roster do
		names[roster[i][1]] = {roster[i][4],roster[i][5],roster[i][3],roster[i][2]}
	end

	local name = ''
	local text = ''
	local ignoredText = '(ignored)'	--'('..Spring.I18N('ui.chat.ignored')..')'
	local lineType = 0
	local bypassThisMessage = false
	local ignoreThisMessage = false

	-- player message
	if names[ssub(line,2,(sfind(line,"> ", nil, true) or 1)-1)] ~= nil then
		bypassThisMessage = false
		lineType = 1
		name = ssub(line,2,sfind(line,"> ", nil, true)-1)
		text = ssub(line,slen(name)+4)
		if ssub(text,1,1) == "!" and  ssub(text, 1,2) ~= "!!" then --bot command
			bypassThisMessage = true
		end

		-- spectator message
	elseif names[ssub(line,2,(sfind(line," (replay)] ", nil, true) or 1)-1)] ~= nil then
		bypassThisMessage = false
		lineType = 2
		name = ssub(line,2,sfind(line," (replay)] ", nil, true)-1)
		text = ssub(line,slen(name)+13)
		if ssub(text,1,1) == "!" and  ssub(text, 1,2) ~= "!!" then --bot command
			bypassThisMessage = true
		end

		-- spectator message
	elseif names[ssub(line,2,(sfind(line,"] ", nil, true) or 1)-1)] ~= nil then
		bypassThisMessage = false
		lineType = 2
		name = ssub(line,2,sfind(line,"] ", nil, true)-1)
		text = ssub(line,slen(name)+4)
		if ssub(text,1,1) == "!" and  ssub(text, 1,2) ~= "!!" then --bot command
			bypassThisMessage = true
		end

		-- point
	elseif names[ssub(line,1,(sfind(line," added point: ", nil, true) or 1)-1)] ~= nil then
		bypassThisMessage = false
		lineType = 3
		name = ssub(line,1,sfind(line," added point: ", nil, true)-1)
		text = ssub(line,slen(name.." added point: ")+1)
		if text == "" then
			text = "Look here!"
		end

		-- battleroom message
	elseif ssub(line,1,1) == ">" then
		lineType = 4
		text = ssub(line,3)
		bypassThisMessage = true
		if ssub(line,1,3) == "> <" then -- player speaking in battleroom
			bypassThisMessage = false
			if ssub(text,1,1) == "!" and  ssub(text, 1,2) ~= "!!" then --bot command
				bypassThisMessage = true
			end
			local i = sfind(ssub(line,4,slen(line)), ">", nil, true)
			if i then
				name = ssub(line,4,i+2)
				text = ssub(line,i+5)
			else
				name = "unknown"
			end
		end
	end

	-- filter all but chat messages and map-markers
	bypassThisMessage = true

	if sfind(line, "My player ID is", nil, true) then
		bypassThisMessage = true

	elseif sfind(line," added point: ", nil, true) then
		bypassThisMessage = false

		-- battleroom chat
	elseif sfind(line,"^(> <.*>)") then
		-- will not check for name, user might not have connected before
		local endChar = sfind(line, "> ", nil, true)
		if endChar then
			if filterSpecs then
				bypassThisMessage = true
			else
				bypassThisMessage = false
			end
		end

		-- player chat
	elseif sfind(line,"^(<.*>)") then
		local endChar = sfind(line, "> ", nil, true)
		if endChar then
			local name = ssub(line, sfind(line, "<", nil, true)+1, endChar-1)
			if name and names[name] then
				bypassThisMessage = false
			end
		end

		-- spectator chat
	elseif sfind(line,"^(\[\[.*\])") then	-- somehow adding space at end doesnt work

		local endChar = sfind(line, "] ", nil, true)
		if endChar then
			local name = ssub(line, 2, endChar-1)
			if sfind(name," (replay)", nil, true) then
				name = ssub(line, 2, sfind(name," (replay)", nil, true))
			end
			if name and names[name] then
				if filterSpecs then
					bypassThisMessage = true
				else
					bypassThisMessage = false
				end
			end
		end
	end

	-- ignore muted players
	if WG.ignoredPlayers and WG.ignoredPlayers[name] then
		bypassThisMessage = true
	end

	local MyAllyTeamID = spGetMyAllyTeamID()
	local textcolor = nil


	if lineType == 1 then	-- player message
		local c
		if sfind(text,"Allies: ", nil, true) == 1 then
			text = ssub(text,9)
			if names[name][1] == MyAllyTeamID then
				c = colorAlly
			else
				c = colorOtherAlly
			end
		elseif sfind(text,"Spectators: ", nil, true) == 1 then
			text = ssub(text,13)
			c = colorSpec
		else
			c = colorOther
		end

		if ignoreThisMessage then text = ignoredText end

		name = convertColor(spGetTeamColor(names[name][3]))..name
		line = convertColor(c[1],c[2],c[3])..text


	elseif lineType == 2 then	-- spectator chat

		if filterSpecs then
			bypassThisMessage = true
		end

		local c
		if sfind(text,"Allies: ", nil, true) == 1 then
			text = ssub(text,9)
			c = colorSpec
		elseif sfind(text,"Spectators: ", nil, true) == 1 then
			text = ssub(text,13)
			c = colorSpec
		else
			c = colorOther
		end
		textcolor = convertColor(c[1],c[2],c[3])
		local namecolor = convertColor(colorSpec[1],colorSpec[2],colorSpec[3])

		if ignoreThisMessage then text = ignoredText end

		name = namecolor..'(s) '..name
		line = textcolor..text


	elseif lineType == 3 then	-- mapmark point
		local namecolor
		local spectator = true
		if names[name] ~= nil then
			spectator = names[name][2]
		end
		if spectator then
			name = '(s) '..name
			namecolor = convertColor(colorSpec[1],colorSpec[2],colorSpec[3])
			textcolor = convertColor(colorSpec[1],colorSpec[2],colorSpec[3])
		else
			namecolor =  convertColor(spGetTeamColor(names[name][3]))

			if names[name][1] == MyAllyTeamID then
				textcolor = convertColor(colorAlly[1],colorAlly[2],colorAlly[3])
			else
				textcolor = convertColor(colorOtherAlly[1],colorOtherAlly[2],colorOtherAlly[3])
			end
		end

		if ignoreThisMessage then text = ignoredText end

		name = namecolor..name
		line = textcolor..text


	elseif lineType == 4 then	-- battleroom message
		if ignoreThisMessage and name then text = ignoredText end
		textcolor = convertColor(colorGame[1],colorGame[2],colorGame[3])
		name = textcolor..'<'..name..'>'
		line = textcolor..text


	else	-- every other message
		line = convertColor(colorMisc[1],colorMisc[2],colorMisc[3])..line
	end

	return bypassThisMessage, ignoreThisMessage, lineType, name, line
end

function widget:AddConsoleLine(lines, priority)
	lines = lines:match('^\[f=[0-9]+\] (.*)$') or lines
	for line in lines:gmatch("[^\n]+") do
		local bypass, ignore, type, name, line = processConsoleLine(line)
		if not bypass then
			addChat(ignore, type, name, line)
		end
	end
end

function widget:GetConfigData(data)
	for i, _ in ipairs(chatLines) do
		chatLines[i][9] = nil
	end
	return {
		chatLines = chatLines,
		fontsizeMult = fontsizeMult,
		backgroundOpacity = backgroundOpacity
	}
end

function widget:SetConfigData(data)
	if Spring.GetGameFrame() > 0 and data.chatLines ~= nil then
		chatLines = data.chatLines
		currentLine = #chatLines
		currentTypewriterLine = currentLine
	end
	if data.backgroundOpacity ~= nil then
		backgroundOpacity = data.backgroundOpacity
	end
end
