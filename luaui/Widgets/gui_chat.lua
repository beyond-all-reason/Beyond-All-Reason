function widget:GetInfo()
	return {
		name      = "Chat",
		desc      = "chat/console (do /clearconsole to wipe history)",
		author    = "Floris",
		date      = "May 2021",
		license   = "GNU GPL, v2 or later",
		layer     = -980000,
		enabled   = true
	}
end

local LineTypes = {
	Console = -1,
	Player = 1,
	Spectator = 2,
	Mapmark = 3,
	Battleroom = 4,
	System = 5
}

local utf8 = VFS.Include('common/luaUtilities/utf8.lua')

local showHistoryWhenChatInput = true

local showHistoryWhenCtrlShift = true
local enableShortcutClick = true -- enable ctrl+click to goto mapmark coords... while not being in history mode

local vsx, vsy = gl.GetViewSizes()
local posY = 0.81
local posX = 0.3
local posX2 = 0.74
local charSize = 21 - (3.5 * ((vsx/vsy) - 1.78))
local consoleFontSizeMult = 0.85
local maxLines = 5
local maxConsoleLines = 2
local maxLinesScrollFull = 16
local maxLinesScrollChatInput = 9
local lineHeightMult = 1.36
local lineTTL = 40
local backgroundOpacity = 0.25
local handleTextInput = true	-- handle chat text input instead of using spring's input method
local maxTextInputChars = 127	-- tested 127 as being the true max
local inputButton = true
local allowMultiAutocomplete = true
local allowMultiAutocompleteMax = 10
local soundErrorsLimit = Spring.Utilities.IsDevMode() and 999 or 10		-- limit max amount of sound errors (sometimes when your device disconnects you will get to see a sound error every call)

local ui_scale = Spring.GetConfigFloat("ui_scale", 1)
local ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.7)
local widgetScale = (((vsx*0.3 + (vsy*2.33)) / 2000) * 0.55) * (0.95+(ui_scale-1)/1.5)

local maxLinesScroll = maxLinesScrollFull
local hide = false
local fontsizeMult = 1
local usedFontSize = charSize*widgetScale*fontsizeMult
local usedConsoleFontSize = usedFontSize*consoleFontSizeMult
local orgLines = {}
local chatLines = {}
local consoleLines = {}
local ignoredPlayers = {}
local activationArea = {0,0,0,0}
local consoleActivationArea = {0,0,0,0}
local currentChatLine = 0
local currentConsoleLine = 0
local historyMode = false
local scrollingPosY = 0.66
local consolePosY = 0.9
local displayedChatLines = 0
local hideSpecChat = (Spring.GetConfigInt('HideSpecChat', 0) == 1)
local lastMapmarkCoords
local lastUnitShare
local lastLineUnitShare

local myName = Spring.GetPlayerInfo(Spring.GetMyPlayerID(), false)
local isSpec = Spring.GetSpectatingState()

local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local fontfile3 = "fonts/monospaced/" .. Spring.GetConfigString("bar_font3", "SourceCodePro-Medium.otf")
local font, font2, font3, chobbyInterface, hovering

local RectRound, UiElement, UiSelectHighlight, UiScroller, elementCorner, elementPadding, elementMargin

local prevGameID
local prevOrgLines

local playSound = true
local sndChatFile  = 'beep4'
local sndChatFileVolume = 0.55

local colorOther = {1,1,1} -- normal chat color
local colorAlly = {0,1,0}
local colorSpec = {1,1,0}
local colorOtherAlly = {1,0.7,0.45} -- enemy ally messages (seen only when spectating)
local colorGame = {0.4,1,1} -- server (autohost) chat
local colorConsole = {0.85,0.85,0.85}

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
local textInputDlist
local updateTextInputDlist = true
local textCursorRect

local showTextInput = false
local inputText = ''
local inputTextPosition = 0
local cursorBlinkTimer = 0
local cursorBlinkDuration = 1

local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode

local anonymousTeamColor = {Spring.GetConfigInt("anonymousColorR", 255)/255, Spring.GetConfigInt("anonymousColorG", 0)/255, Spring.GetConfigInt("anonymousColorB", 0)/255}

local inputMode = ''
if isSpec then
	inputMode = 's:'
else
	if #Spring.GetTeamList(Spring.GetMyAllyTeamID()) > 1 then
		inputMode = 'a:'
	end
end

local inputTextInsertActive = false
local inputHistory = {}
local inputHistoryCurrent = 0
local inputButtonRect
local autocompleteWords = {}
local prevAutocompleteLetters

local glPopMatrix      = gl.PopMatrix
local glPushMatrix     = gl.PushMatrix
local glDeleteList     = gl.DeleteList
local glCreateList     = gl.CreateList
local glCallList       = gl.CallList
local glTranslate      = gl.Translate
local glColor          = gl.Color

local string_lines = string.lines
local math_isInRect = math.isInRect
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
local ColorString = Spring.Utilities.Color.ToString

local soundErrors = {}

local autocompleteCommands = {
	-- engine
	'advmapshading',
	'advmodelshading',
	'aicontrol',
	'aikill',
	'ailist',
	'aireload',
	'airmesh',
	'allmapmarks',
	'ally',
	'atm',
	'buffertext',
	'chat',
	'chatall',
	'chatally',
	'chatspec',
	'cheat',
	'clearmapmarks',
	--'clock',
	'cmdcolors',
	'commandhelp',
	'commandlist',
	'console',
	'controlunit',
	'crash',
	'createvideo',
	'cross',
	'ctrlpanel',
	'debug',
	'debugcolvol',
	'debugdrawai',
	'debuggl',
	'debugglerrors',
	'debuginfo',
	'debugpath',
	'debugtraceray',
	'decguiopacity',
	'decreaseviewradius',
	'deselect',
	'destroy',
	'devlua',
	'distdraw',
	'disticon',
	'divbyzero',
	'drawinmap',
	'drawlabel',
	'drawtrees',
	'dumpstate',
	'dynamicsky',
	'echo',
	'editdefs',
	'endgraph',
	'exception',
	'font',
	'fps',
	'fpshud',
	'fullscreen',
	'gameinfo',
	'gathermode',
	'give',
	'globallos',
	'godmode',
	'grabinput',
	'grounddecals',
	'grounddetail',
	'group',
	'group0',
	'group1',
	'group2',
	'group3',
	'group4',
	'group5',
	'group6',
	'group7',
	'group8',
	'group9',
	'hardwarecursor',
	'hideinterface',
	'incguiopacity',
	'increaseviewradius',
	'info',
	'inputtextgeo',
	'keyreload',
	'lastmsgpos',
	'lessclouds',
	'lesstrees',
	'lodscale',
	'luagaia',
	'luarules',
	'luasave',
	'luaui',
	'mapborder',
	'mapmarks',
	'mapmeshdrawer',
	'mapshadowpolyoffset',
	'maxnanoparticles',
	'maxparticles',
	'minimap',
	'moreclouds',
	'moretrees',
	'mouse1',
	'mouse2',
	'mouse3',
	'mouse4',
	'mouse5',
	'moveback',
	'movedown',
	'movefast',
	'moveforward',
	'moveleft',
	'moveright',
	'moveslow',
	'moveup',
	'mutesound',
	'nocost',
	'nohelp',
	'noluadraw',
	'nospecdraw',
	'nospectatorchat',
	'pastetext',
	'pause',
	'quitforce',
	'quitmenu',
	'quitmessage',
	'reloadcegs',
	'reloadcob',
	'reloadforce',
	'reloadgame',
	'reloadshaders',
	'reloadtextures',
	'resbar',
	'resync',
	'safegl',
	'save',
	'savegame',
	'say',
	'screenshot',
	'select',
	'selectcycle',
	'selectunits',
	'send',
	'set',
	'shadows',
	'sharedialog',
	'showelevation',
	'showmetalmap',
	'showpathcost',
	'showpathflow',
	'showpathheat',
	'showpathtraversability',
	'showpathtype',
	'showstandard',
	'skip',
	'slowdown',
	'soundchannelenablec',
	'sounddevice',
	'specfullview',
	'spectator',
	'specteam',
	--'speed',
	'speedcontrol',
	'speedup',
	'take',
	'team',
	'teamhighlight',
	'toggleinfo',
	'togglelos',
	'tooltip',
	'track',
	'trackmode',
	'trackoff',
	'tset',
	'viewselection',
	'vsync',
	'water',
	'wbynum',
	'wiremap',
	'wiremodel',
	'wiresky',
	'wiretree',
	'wirewater',
	'widgetselector',

	-- gadgets
	'luarules battleroyaledebug',
	'luarules buildicon',
	'luarules cmd',
	'luarules clearwrecks',
	'luarules destroyunits',
	'luarules disablecusgl4',
	'luarules fightertest',
	'luarules give',
	'luarules givecat',
	'luarules halfhealth',
	'luarules kill_profiler',
	'luarules loadmissiles',
	'luarules profile',
	'luarules reclaimunits',
	'luarules reloadcus',
	'luarules reloadcusgl4',
	'luarules removeunits',
	'luarules removeunitdef',
	'luarules spawnceg',
	'luarules undo',
	'luarules unitcallinsgadget',
	'luarules updatesun',
	'luarules waterlevel',
	'luarules wreckunits',
	'luarules xpunits',

	-- widgets
	'devmode',
	'profile',
	'grapher',
	'luaui reload',
	'luaui profile',
	--'luaui selector',	-- pops up engine version
	'luaui reset',
	'luaui factoryreset',
	'luaui disable',
	'luaui enable',
	'savegame',
	'addmessage',
	'radarpulse',
	'snow',
	'clearconsole',
	'ecostatstext',
	'defrange ally air',
	'defrange ally nuke',
	'defrange ally ground',
	'defrange enemy air',
	'defrange enemy nuke',
	'defrange enemy ground',
	'playertv',
	'playerview',
	'hidespecchat',
	'speclist',
}
local autocompleteText
local autocompletePlayernames = {}
local playersList = Spring.GetPlayerList()
local playernames = {}
for _, playerID in ipairs(playersList) do
	local name = Spring.GetPlayerInfo(playerID, false)
	autocompletePlayernames[#autocompletePlayernames+1] = name
	playernames[name] = true
end

local autocompleteUnitNames = {}
local autocompleteUnitCodename = {}
local uniqueHumanNames = {}
local unitTranslatedHumanName = {}
local function refreshUnitDefs()
	autocompleteUnitNames = {}
	autocompleteUnitCodename = {}
	uniqueHumanNames = {}
	unitTranslatedHumanName = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		if not uniqueHumanNames[unitDef.translatedHumanName] then
			uniqueHumanNames[unitDef.translatedHumanName] = true
			autocompleteUnitNames[#autocompleteUnitNames+1] = unitDef.translatedHumanName
		end
		if not string.find(unitDef.name, "_scav", nil, true) then
			autocompleteUnitCodename[#autocompleteUnitCodename+1] = unitDef.name:lower()
		end
		unitTranslatedHumanName[unitDefID] = unitDef.translatedHumanName
	end
	uniqueHumanNames = nil
	for featureDefID, featureDef in pairs(FeatureDefs) do
		autocompleteUnitCodename[#autocompleteUnitCodename+1] = featureDef.name:lower()
	end
end
refreshUnitDefs()

local function getAIName(teamID)
	local _, _, _, name, _, options = Spring.GetAIInfo(teamID)
	local niceName = Spring.GetGameRulesParam('ainame_' .. teamID)

	if niceName then
		name = niceName

		if Spring.Utilities.ShowDevUI() and options.profile then
			name = name .. " [" .. options.profile .. "]"
		end
	end

	return Spring.I18N('ui.playersList.aiName', { name = name })
end


local teamColorKeys = {}
local teams = Spring.GetTeamList()
for i = 1, #teams do
	local r, g, b, a = spGetTeamColor(teams[i])
	teamColorKeys[teams[i]] = r..'_'..g..'_'..b

	if select(4, Spring.GetTeamInfo(teams[i], false)) then
		playernames[getAIName(teams[i])] = true
	end
end
teams = nil

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
	local textLines = string_lines(text)

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

	if historyMode ~= 'console' then
		currentConsoleLine = consoleLinesCount
	end
end

local function colourNames(teamID)
	local nameColourR, nameColourG, nameColourB = Spring.GetTeamColor(teamID)
	if (not isSpec) and anonymousMode ~= "disabled" then
		nameColourR, nameColourG, nameColourB = anonymousTeamColor[1], anonymousTeamColor[2], anonymousTeamColor[3]
	end
	return ColorString(nameColourR, nameColourG, nameColourB)
end

local function teamcolorPlayername(playername)
	local playersList = Spring.GetPlayerList()
	for _, playerID in ipairs(playersList) do
		local name,_,_,teamID = Spring.GetPlayerInfo(playerID, false)
		if name == playername then
			return colourNames(teamID)..playername
		end
	end
	local teams = Spring.GetTeamList()
	for i = 1, #teams do
		if select(4, Spring.GetTeamInfo(teams[i], false)) then
			return colourNames(teams[i])..playername
		end
	end
	return playername
end

local energyText = Spring.I18N('ui.topbar.resources.energy'):lower()
local metalText = Spring.I18N('ui.topbar.resources.metal'):lower()

local function addChat(gameFrame, lineType, name, text, isLive)
	if not text or text == '' then return end

	-- determine text typing start time
	local startTime = clock()

	local sendMetal, sendEnergy
	local msgColor = '\255\180\180\180'
	local metalColor = '\255\233\233\233'
	local metalValueColor = '\255\255\255\255'
	local energyColor = '\255\255\255\180'
	local energyValueColor = '\255\255\255\140'


	if lineType == LineTypes.Player and ssub(text, 5, 6) == '> ' then
		text = ssub(text, 7)
		lineType = LineTypes.System
		local params = string.split(text, ':')
		local t = {}
		if params[1] then
			for k,v in pairs(params) do
				if k > 1 then
					local pair = string.split(v, '=')
					if pair[2] then
						if playernames[pair[2]] then
							t[ pair[1] ] = teamcolorPlayername(pair[2])..msgColor
						elseif params[1]:lower():find('energy', nil, true) then
							t[ pair[1] ] = energyValueColor..pair[2]..msgColor
						elseif params[1]:lower():find('metal', nil, true) then
							t[ pair[1] ] = metalValueColor..pair[2]..msgColor
						else
							t[ pair[1] ] = pair[2]
						end
					end
				end
			end
			text = Spring.I18N(params[1], t)
			if text:lower():find(energyText, nil, true) then
				local pos = text:lower():find(energyText, nil, true)
				local len = slen(energyText)
				text = ssub(text, 1, pos-1)..energyColor..ssub(text, pos, pos+len-1).. msgColor..ssub(text, pos+len)
			end
			if text:lower():find(metalText, nil, true) then
				local pos = text:lower():find(metalText, nil, true)
				local len = slen(metalText)
				text = ssub(text, 1, pos-1)..metalColor..ssub(text, pos, pos+len-1).. msgColor..ssub(text, pos+len)
			end
		end
		text = msgColor..text
	end

	-- metal/energy given
	--if lineType == LineTypes.Player and sfind(text, 'I sent ', nil, true) then
	--	if sfind(text, ' metal to ', nil, true) then
	--		sendMetal = tonumber(string.match(ssub(text, sfind(text, 'I sent ')+7), '([0-9]*)')) or '---'
	--		local playername = teamcolorPlayername(ssub(text, sfind(text, ' metal to ')+10))
	--		--text = ssub(text, 1, sfind(text, 'I sent ')-1)..' shared: '..sendMetal..' metal to '..playername
	--		--msgColor = ssub(text, 1, sfind(text, 'I sent ')-1)
	--		text = msgColor..'shared '..metalColor..sendMetal..metalColor.. ' metal'..msgColor..' to '..playername
	--		lineType = LineTypes.System
	--	elseif sfind(text, ' energy to ', nil, true) then
	--		sendEnergy = tonumber(string.match(ssub(text, sfind(text, 'I sent ')+7), '([0-9]*)')) or '---'
	--		local playername = teamcolorPlayername(ssub(text, sfind(text, ' energy to ')+11))	-- no dot stripping needed here
	--		--text = ssub(text, 1, sfind(text, 'I sent ')-1)..' shared: '..sendEnergy..' energy to '..playername
	--		--msgColor = ssub(text, 1, sfind(text, 'I sent ')-1)
	--		text = msgColor..'shared '..energyColor..sendEnergy..energyColor..' energy'..msgColor..' to '..playername
	--		lineType = LineTypes.System
	--	end
	--	-- player taken
	--elseif lineType == LineTypes.Player and sfind(text, 'I took ', nil, true) then	--<StarDoM> Allies: I took  --- .
	--	if sfind(text, 'I took ', nil, true) then
	--		local playernameStart = sfind(text, 'I took ')+7
	--		local playername = ssub(text, playernameStart, slen(text)-1) -- strip dot.
	--		local colonChar = sfind(playername, ':')
	--		local addition = ''
	--		if colonChar then
	--			local leftover = playername
	--			playername = ssub(playername, 1, colonChar-1)
	--			addition = msgColor..ssub(leftover, colonChar)
	--		end
	--		playername = teamcolorPlayername(playername)
	--		text = msgColor..'took '..playername..addition
	--		lineType = LineTypes.System
	--	end
	--end
	-- convert /n into lines
	local textLines = string_lines(text)

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
		if lineType == LineTypes.Mapmark and lastMapmarkCoords then
			chatLines[chatLinesCount].coords = lastMapmarkCoords
			lastMapmarkCoords = nil
		end
		if lineType == LineTypes.System then
			chatLines[chatLinesCount].text = line

			if lastLineUnitShare and lastLineUnitShare.newTeamID == Spring.GetMyTeamID() then
				chatLines[chatLinesCount].selectUnits = lastLineUnitShare.unitIDs
				lastLineUnitShare = nil
			end
		end
		if sendMetal then
			chatLines[chatLinesCount].sendMetal = sendMetal
		end
		if sendEnergy then
			chatLines[chatLinesCount].sendEnergy = sendEnergy
		end
	end

	if historyMode ~= 'chat' then
		currentChatLine = #chatLines
	end

	-- play sound for player/spectator chat
	if isLive and (lineType == LineTypes.Player or lineType == LineTypes.Spectator) and playSound and not Spring.IsGUIHidden() then
		spPlaySoundFile( sndChatFile, sndChatFileVolume, nil, "ui" )
	end
end

local function cancelChatInput()
	showTextInput = false
	if showHistoryWhenChatInput then
		historyMode = false
		currentChatLine = #chatLines
	end
	inputText = ''
	inputTextPosition = 0
	inputTextInsertActive = false
	inputHistoryCurrent = #inputHistory
	autocompleteText = nil
	autocompleteWords = {}
	if WG['guishader'] then
		WG['guishader'].RemoveRect('chatinput')
		WG['guishader'].RemoveRect('chatinputautocomplete')
	end
	widgetHandler:DisownText()
end

local function commonUnitName(unitIDs)
	local commonUnitDefID = nil
	for _, unitID in pairs(unitIDs) do
		local unitDefID = Spring.GetUnitDefID(unitID)

		-- unitDefID will be nil if shared units are visible only as unidentified radar dots
		-- (when spectating with PlayerView ON from enemy team's point of view)
		if (commonUnitDefID and unitDefID ~= commonUnitDefID) or not unitDefID then
			return #unitIDs > 1 and "units" or "unit"
		end

		commonUnitDefID = unitDefID
	end

	return unitTranslatedHumanName[commonUnitDefID]
end

local function getTeamNames()
	local names = {}

	local gaiaTeamID = Spring.GetGaiaTeamID()
	local teamList = Spring.GetTeamList()
	for i = 1, #teamList do
		local teamID = teamList[i]
		if teamID ~= gaiaTeamID then
			local _, playerID, _, isAiTeam = Spring.GetTeamInfo(teamID, false)
			if isAiTeam then
				names[teamID] = getAIName(teamID)
			else
				local name, _, spec, _ = Spring.GetPlayerInfo(playerID)
				if not spec then
					names[teamID] = name
				end
			end
		else
			names[teamID] = "Gaia"
		end
	end

	return names
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

local function convertColor(r,g,b)
	return schar(255, (r*255), (g*255), (b*255))
end

local function processAddConsoleLine(gameFrame, line, addOrgLine, doConsoleLine)
	local orgLine = line

	local roster = spGetPlayerRoster()
	local names = {}
	for i=1, #roster do
		-- [playername] = {allyTeamID, isSpec, teamID, playerID}
		names[roster[i][1]] = {roster[i][4],roster[i][5],roster[i][3],roster[i][2]}
	end

	local name = ''
	local nameText = ''
	local text = ''
	local lineType = 0
	local bypassThisMessage = false
	local skipThisMessage = false
	local textcolor, c

	-- player message
	if names[ssub(line,2,(sfind(line,"> ", nil, true) or 1)-1)] ~= nil then
		lineType = LineTypes.Player
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

		if not isSpec and anonymousMode ~= "disabled" then
			nameText = convertColor(anonymousTeamColor[1], anonymousTeamColor[2], anonymousTeamColor[3])..name
		else
			nameText = convertColor(spGetTeamColor(names[name][3]))..name
		end
		line = convertColor(c[1],c[2],c[3])..text

		-- spectator message
	elseif names[ssub(line,2,(sfind(line,"] ", nil, true) or 1)-1)] ~= nil  or  names[ssub(line,2,(sfind(line," (replay)] ", nil, true) or 1)-1)] ~= nil then
		lineType = LineTypes.Spectator
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

		nameText = convertColor(colorSpec[1],colorSpec[2],colorSpec[3])..'(s) '..name
		line = convertColor(c[1],c[2],c[3])..text

		-- point
	elseif names[ssub(line,1,(sfind(line," added point: ", nil, true) or 1)-1)] ~= nil then
		lineType = LineTypes.Mapmark
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
			namecolor = convertColor(colorSpec[1],colorSpec[2],colorSpec[3])
			textcolor = convertColor(colorSpec[1],colorSpec[2],colorSpec[3])

			-- filter specs
			if hideSpecChat then
				skipThisMessage = true
			end
		else
			if not isSpec and anonymousMode ~= "disabled" then
				namecolor = convertColor(anonymousTeamColor[1], anonymousTeamColor[2], anonymousTeamColor[3])
			else
				namecolor =  convertColor(spGetTeamColor(names[name][3]))
			end

			if names[name][1] == spGetMyAllyTeamID() then
				textcolor = convertColor(colorAlly[1],colorAlly[2],colorAlly[3])
			else
				textcolor = convertColor(colorOtherAlly[1],colorOtherAlly[2],colorOtherAlly[3])
			end
		end

		nameText = namecolor..(spectator and '(s) ' or '')..name
		line = textcolor..text

		-- battleroom message
	elseif ssub(line,1,1) == ">" then
		lineType = LineTypes.Spectator
		text = ssub(line,3)
		if ssub(line,1,3) == "> <" then -- player speaking in battleroom
			local i = sfind(ssub(line,4,slen(line)), ">", nil, true)
			if i then
				name = ssub(line,4,i+2)
				text = ssub(line,i+5)
			else
				name = "unknown "
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

		nameText = convertColor(colorGame[1],colorGame[2],colorGame[3])..'<'..name..'>'
		line = convertColor(colorGame[1],colorGame[2],colorGame[3])..text

		-- units given
	elseif names[ssub(line,1,(sfind(line," shared units to ", nil, true) or 1)-1)] ~= nil then
		lineType = LineTypes.System

		local msgColor = '\255\180\180\180'
		local msgHighlightColor = '\255\215\215\215'

		-- Player1 shared units to Player2: 5 Wind Turbine
		local format = "(.+) shared units to (.+): (.+)"
		local oldTeamName, newTeamName, shareDesc = string.match(line, format)

		-- shared 5 Wind Turbine to Player2
		if newTeamName and shareDesc then
			text = msgColor .. Spring.I18N('ui.unitShare.shared', {
				units = msgHighlightColor .. shareDesc .. msgColor,
				name = teamcolorPlayername(newTeamName)
			})
		end

		nameText = teamcolorPlayername(oldTeamName)
		line = text

		-- console chat
	elseif addOrgLine or doConsoleLine then
		lineType = LineTypes.Console

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
		elseif sfind(line,"could not load sound", nil, true) then
			if soundErrors[line] or #soundErrors > soundErrorsLimit then
				bypassThisMessage = true
			else
				soundErrors[line] = true
			end

			-- filter chobby (debug) messages
		elseif sfind(line,"Chobby]", nil, true) then
			bypassThisMessage = true
		elseif sfind(line,"liblobby]", nil, true) then
			bypassThisMessage = true
		elseif sfind(line,"[LuaMenu", nil, true) then
			bypassThisMessage = true
		elseif sfind(line,"ClientMessage]", nil, true) then
			bypassThisMessage = true
		elseif sfind(line,"ServerMessage]", nil, true) then
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
		elseif sfind(line, 'self%-destruct in ', nil, true) then
			bypassThisMessage = true
		end

		local color = ''
		if sfind(line,'Error', nil, true) then
			color = '\255\255\133\133'
		elseif sfind(line,'Sync error for', nil, true) then
			color = '\255\255\133\133'
		elseif sfind(line,' is lagging behind', nil, true) then
			color = '\255\255\133\133'
			local playername = ssub(line, 1, sfind(line, ' is lagging behind'))
			line = ''
			if names[playername] then
				if not names[playername][2] then
					if not isSpec and anonymousMode ~= "disabled" then
						line = line..convertColor(anonymousTeamColor[1], anonymousTeamColor[2], anonymousTeamColor[3])..playername
					else
						line = line..convertColor(spGetTeamColor(names[playername][3]))..playername
					end
				else
					line = line..convertColor(colorConsole[1],colorConsole[2],colorConsole[3])..playername
				end
			else
				line = line..playername
			end
			line = line .. ' is lagging behind'
		elseif sfind(line,'Warning', nil, true) then
			color = '\255\255\190\170'
		elseif sfind(line,'Failed to load', nil, true) then
			color = '\255\200\200\255'
		elseif sfind(line,'Loaded ', nil, true) or sfind(ssub(line, 1, 25),'Loading ', nil, true) or sfind(ssub(line, 1, 25),'Loading: ', nil, true) then
			color = '\255\200\255\200'
		elseif sfind(line,'Removed: ', nil, true) or  sfind(line,'Removed widget: ', nil, true) then
			color = '\255\255\230\200'
		elseif sfind(line,'paused the game', nil, true) then
			color = '\255\255\255\255'
		elseif sfind(line,'Connection attempt from ', nil, true) then
			color = '\255\255\255\255'
			local playername = ssub(line, sfind(line, 'Connection attempt from ')+24)
			line = 'Connection attempt from: '
			if names[playername] then
				if not names[playername][2] then
					if not isSpec and anonymousMode ~= "disabled" then
						line = line..convertColor(anonymousTeamColor[1], anonymousTeamColor[2], anonymousTeamColor[3])..playername
					else
						line = line..convertColor(spGetTeamColor(names[playername][3]))..playername
					end
				else
					line = line..'(spectator) '..convertColor(colorConsole[1],colorConsole[2],colorConsole[3])..playername
				end
			else
				line = line..playername
			end
		end
		if color ~= '' then
			line = color..line
		else
			line = convertColor(colorConsole[1],colorConsole[2],colorConsole[3])..line
		end
	else
		bypassThisMessage = true
	end

	if not bypassThisMessage then
		-- bot command
		if ssub(text,1,1) == '!' and  ssub(text, 1,2) ~= '!!' then
			bypassThisMessage = true
		end

		if sfind(line, 'My player ID is', nil, true) then
			bypassThisMessage = true
		end
	end

	if not bypassThisMessage and line ~= '' then

		-- ignore muted players
		if ignoredPlayers[name] then
			skipThisMessage = true
		end
		if addOrgLine then
			orgLines[#orgLines+1] = {gameFrame, orgLine}
			-- if you have been mentioned, pass it on
			if lineType > 0 and WG.logo and sfind(text, myName, nil, true) then -- and myName ~= "Player"
				WG.logo.mention()
			end
		end
		if lineType < 1 then
			addConsoleLine(gameFrame, lineType, line, addOrgLine)
		elseif not skipThisMessage then
			addChat(gameFrame, lineType, nameText, line, addOrgLine)
		end
	end
end

local function addLastUnitShareMessage()
	if not lastUnitShare then
		return
	end

	local names = getTeamNames()

	for _, unitShare in pairs(lastUnitShare) do
		local oldTeamName = names[unitShare.oldTeamID]
		local newTeamName = names[unitShare.newTeamID]

		if oldTeamName and newTeamName then
			local shareDescription = commonUnitName(unitShare.unitIDs)
			if #unitShare.unitIDs > 1 then
				shareDescription = #unitShare.unitIDs .. ' ' .. shareDescription
			end

			-- Player1 shared units to Player2: 5 Wind Turbine
			lastLineUnitShare = unitShare
			local line = oldTeamName .. ' shared units to ' .. newTeamName .. ': ' .. shareDescription
			Spring.Echo(line)
		end
	end

	lastUnitShare = nil
end

function widget:UnitTaken(unitID, _, oldTeamID, newTeamID)
	local oldAllyTeamID = select(6, Spring.GetTeamInfo(oldTeamID))
	local newAllyTeamID = select(6, Spring.GetTeamInfo(newTeamID))

	local myAllyTeamID = Spring.GetMyAllyTeamID()

	local allyTeamShare = (oldAllyTeamID == myAllyTeamID and newAllyTeamID == myAllyTeamID)
	local selfShare = (oldTeamID == newTeamID) -- may happen if took other player

	local _, _, _, captureProgress, _ = Spring.GetUnitHealth(unitID)
	local captured = (captureProgress == 1)

	local spec = Spring.GetSpectatingState()

	if (not spec and not allyTeamShare) or selfShare or captured then
		return
	end

	if not lastUnitShare then
		lastUnitShare = {}
	end

	-- I think it's possible for multiple teams to share in the same frame?
	local key = oldTeamID .. 'to' .. newTeamID

	if not lastUnitShare[key] then
		lastUnitShare[key] = {
			oldTeamID = oldTeamID,
			newTeamID = newTeamID,
			unitIDs = {}
		}
	end

	lastUnitShare[key].unitIDs[#lastUnitShare[key].unitIDs + 1] = unitID
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
		local fontHeightOffset = usedFontSize*0.3
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
		local fontHeightOffset = usedFontSize*0.3
		chatLines[i].lineDisplayList = glCreateList(function()
			font:Begin()
			if chatLines[i].gameFrame then
				if chatLines[i].lineType == LineTypes.Mapmark then
					-- player name
					font2:Begin()
					font2:Print(chatLines[i].playerName, maxPlayernameWidth, fontHeightOffset*1.06, usedFontSize*1.03, "or")
					font2:End()
					-- divider
					font2:Print(pointSeparator, maxPlayernameWidth+(lineSpaceWidth/2), fontHeightOffset*0.07, usedFontSize, "oc")
				elseif chatLines[i].lineType == LineTypes.System then -- sharing resources, taken player
					-- player name
					font3:Begin()
					font3:Print(chatLines[i].playerName, maxPlayernameWidth, fontHeightOffset*1.2, usedFontSize*0.9, "or")
					font3:End()
				else
					-- player name
					font2:Begin()
					font2:Print(chatLines[i].playerName, maxPlayernameWidth, fontHeightOffset*1.06, usedFontSize*1.03, "or")
					font2:End()
					-- divider
					font:Print(chatSeparator, maxPlayernameWidth+(lineSpaceWidth/3.75), fontHeightOffset, usedFontSize, "oc")
				end
			end
			if chatLines[i].lineType == LineTypes.System then -- sharing resources, taken player
				font3:Begin()
				font3:Print(chatLines[i].text, maxPlayernameWidth+lineSpaceWidth-(usedFontSize*0.5), fontHeightOffset*1.2, usedFontSize*0.88, "o")
				font3:End()
			else
				font:Print(chatLines[i].text, maxPlayernameWidth+lineSpaceWidth, fontHeightOffset, usedFontSize, "o")
			end
			font:End()
		end)

		-- game time (for when viewing history)
		if chatLines[i].gameFrame then
			glDeleteList(chatLines[i].timeDisplayList)
			chatLines[i].timeDisplayList = createGameTimeDisplayList(chatLines[i].gameFrame)
		end
	end
end

local initialized = false
local function processLines(clearConsole)
	clearDisplayLists()
	chatLines = {}
	if clearConsole then
		consoleLines = {}
	end
	for _, params in ipairs(orgLines) do
		processAddConsoleLine(params[1], params[2], false, not initialized)
	end
	currentChatLine = #chatLines
	initialized = true
end

local uiSec = 0
function widget:Update(dt)
	addLastUnitShareMessage()

	cursorBlinkTimer = cursorBlinkTimer + dt
	if cursorBlinkTimer > cursorBlinkDuration then cursorBlinkTimer = 0 end

	uiSec = uiSec + dt
	if uiSec > 1 then
		uiSec = 0

		local doProcessLines = false

		if prevOrgLines and Spring.GetGameRulesParam("GameID") then
			if prevGameID == Spring.GetGameRulesParam("GameID") then
				orgLines = prevOrgLines
				doProcessLines = true
			end
			prevOrgLines = nil
			prevGameID = nil
		end

		if not addedOptionsList and WG['options'] and WG['options'].getOptionsList then
			local optionsList = WG['options'].getOptionsList()
			addedOptionsList = true
			for i, option in ipairs(optionsList) do
				autocompleteCommands[#autocompleteCommands+1] = 'option '..option
			end
		end
		if hideSpecChat ~= (Spring.GetConfigInt('HideSpecChat', 0) == 1) then
			hideSpecChat = (Spring.GetConfigInt('HideSpecChat', 0) == 1)
			doProcessLines = true
		end

		-- check if team colors have changed
		local teams = Spring.GetTeamList()
		for i = 1, #teams do
			local r, g, b = spGetTeamColor(teams[i])
			if teamColorKeys[teams[i]] ~= r..'_'..g..'_'..b then
				teamColorKeys[teams[i]] = r..'_'..g..'_'..b
				doProcessLines = true
			end
		end
		-- detect a change in muted players
		local detectedMuteChanges = false
		if WG.ignoredPlayers then
			for name, _ in pairs(ignoredPlayers) do
				if not WG.ignoredPlayers[name] then
					doProcessLines = false
				end
			end
			for name, _ in pairs(WG.ignoredPlayers) do
				if not ignoredPlayers[name] then
					doProcessLines = false
				end
			end
			ignoredPlayers = table.copy(WG.ignoredPlayers)
		end

		if doProcessLines then
			processLines()
		end
	end

	local x,y,b = Spring.GetMouseState()

	if topbarArea then
		scrollingPosY = floor(topbarArea[2] - elementMargin - backgroundPadding - backgroundPadding - (lineHeight*maxLinesScroll)) / vsy
	end

	local chatlogHeightDiff = historyMode and floor(vsy*(scrollingPosY-posY)) or 0
	if WG['topbar'] and WG['topbar'].showingQuit() then
		historyMode = false
		currentChatLine = #chatLines
	elseif math_isInRect(x, y, activationArea[1], activationArea[2], activationArea[3], activationArea[4]) then
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		if showHistoryWhenCtrlShift and ctrl and shift then
			if math_isInRect(x, y, consoleActivationArea[1], consoleActivationArea[2], consoleActivationArea[3], consoleActivationArea[4]) then
				historyMode = 'console'
			else
				historyMode = 'chat'
			end
			maxLinesScroll = maxLinesScrollFull
		end
	elseif historyMode and math_isInRect(x, y, activationArea[1], activationArea[2]+chatlogHeightDiff, activationArea[3], activationArea[2]) then
		-- do nothing
	else
		if not showHistoryWhenChatInput or not showTextInput then
			historyMode = false
			currentChatLine = #chatLines
		end
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
		if not chobbyInterface then
			Spring.SDLStartTextInput()	-- because: touch chobby's text edit field once and widget:TextInput is gone for the game, so we make sure its started!
		end
	end
end

local function drawChatInputCursor()
	if textCursorRect then
		local a = 1 - (cursorBlinkTimer * (1 / cursorBlinkDuration)) + 0.15
		glColor(0.7,0.7,0.7,a)
		gl.Rect(textCursorRect[1], textCursorRect[2], textCursorRect[3], textCursorRect[4])
		glColor(1,1,1,1)
	end
end

local function drawChatInput()
	if showTextInput then
		if topbarArea then
			scrollingPosY = floor(topbarArea[2] - elementMargin - backgroundPadding - backgroundPadding - (lineHeight*maxLinesScroll)) / vsy
		end
		updateTextInputDlist = false
		textInputDlist = glDeleteList(textInputDlist)
		textInputDlist = glCreateList(function()
			local x,y,_ = Spring.GetMouseState()
			local chatlogHeightDiff = historyMode and floor(vsy*(scrollingPosY-posY)) or 0
			local inputFontSize = floor(usedFontSize * 1.03)
			local inputHeight = floor(inputFontSize * 2.3)
			local leftOffset = floor(lineHeight*0.7)
			local distance =  (historyMode and inputHeight + elementMargin + elementMargin or elementMargin)
			local isCmd = ssub(inputText, 1, 1) == '/'
			local usedFont = isCmd and font3 or font
			local modeText = Spring.I18N('ui.chat.everyone')
			if inputMode == 'a:' then
				modeText = Spring.I18N('ui.chat.allies')
			elseif inputMode == 's:' then
				modeText = Spring.I18N('ui.chat.spectators')
			end
			if isCmd then
				modeText = Spring.I18N('ui.chat.cmd')
			end
			local modeTextPosX = floor(activationArea[1]+elementPadding+elementPadding+leftOffset)
			local textPosX = floor(modeTextPosX + (usedFont:GetTextWidth(modeText) * inputFontSize) + leftOffset + inputFontSize)
			local textCursorWidth = 1 + math.floor(inputFontSize / 14)
			if inputTextInsertActive then
				textCursorWidth = math.floor(textCursorWidth * 5)
			end
			local textCursorPos = floor(usedFont:GetTextWidth(utf8.sub(inputText, 1, inputTextPosition)) * inputFontSize)

			-- background
			local r,g,b,a
			local inputAlpha = math.min(0.36, ui_opacity*0.66)
			local x2 = math.max(textPosX+lineHeight+floor(usedFont:GetTextWidth(inputText..(autocompleteText and autocompleteText or '')) * inputFontSize), floor(activationArea[1]+((activationArea[3]-activationArea[1])/3)))
			UiElement(activationArea[1], activationArea[2]+chatlogHeightDiff-distance-inputHeight, x2, activationArea[2]+chatlogHeightDiff-distance, nil,nil,nil,nil, nil,nil,nil,nil, inputAlpha)
			if WG['guishader'] then
				WG['guishader'].InsertRect(activationArea[1], activationArea[2]+chatlogHeightDiff-distance-inputHeight, x2, activationArea[2]+chatlogHeightDiff-distance, 'chatinput')
			end

			-- button background
			inputButtonRect = {activationArea[1]+elementPadding, activationArea[2]+chatlogHeightDiff-distance-inputHeight+elementPadding, textPosX-inputFontSize, activationArea[2]+chatlogHeightDiff-distance-elementPadding}
			if isCmd then
				r, g, b = 0, 0, 0
			elseif inputMode == 'a:' then
				r, g, b = 0, 0.1, 0
			elseif inputMode == 's:' then
				r, g, b = 0.1, 0.094, 0
			else
				r, g, b = 0, 0, 0
			end
			glColor(r, g, b, 0.3)
			RectRound(inputButtonRect[1], inputButtonRect[2], inputButtonRect[3], inputButtonRect[4], elementCorner*0.6, 1,0,0,1)
			glColor(1,1,1,0.033)
			gl.Rect(inputButtonRect[3]-1, inputButtonRect[2], inputButtonRect[3], inputButtonRect[4])

			-- button text
			usedFont:Begin()
			if isCmd then
				r, g, b = 0.65, 0.65, 0.65
			elseif inputMode == 'a:' then
				r, g, b = 0.55, 0.72, 0.55
			elseif inputMode == 's:' then
				r, g, b = 0.73, 0.73, 0.54
			else
				r, g, b = 0.7, 0.7, 0.7
			end
			usedFont:SetTextColor(r, g, b, 1)
			usedFont:Print(modeText, modeTextPosX, activationArea[2]+chatlogHeightDiff-distance-(inputHeight*0.61), inputFontSize, "o")

			-- colon
			if not isCmd then
				if inputMode == 'a:' then
					r, g, b = 0.53, 0.66, 0.53
				elseif inputMode == 's:' then
					r, g, b = 0.66, 0.66, 0.5
				else
					r, g, b = 0.55, 0.55, 0.55
				end
				usedFont:SetTextColor(r, g, b, 1)
				usedFont:Print(':', inputButtonRect[3]-0.5, activationArea[2]+chatlogHeightDiff-distance-(inputHeight*0.61), inputFontSize, "co")
			end

			-- text cursor
			textCursorRect = { textPosX + textCursorPos, activationArea[2]+chatlogHeightDiff-distance-(inputHeight*0.5)-(inputFontSize*0.6), textPosX + textCursorPos + textCursorWidth, activationArea[2]+chatlogHeightDiff-distance-(inputHeight*0.5)+(inputFontSize*0.64) }
			--a = 1 - (cursorBlinkTimer * (1 / cursorBlinkDuration)) + 0.15
			--glColor(0.7,0.7,0.7,a)
			--gl.Rect(textPosX + textCursorPos, activationArea[2]+chatlogHeightDiff-distance-(inputHeight*0.5)-(inputFontSize*0.6), textPosX + textCursorPos + textCursorWidth, activationArea[2]+chatlogHeightDiff-distance-(inputHeight*0.5)+(inputFontSize*0.64))
			--glColor(1,1,1,1)

			-- text message
			if isCmd then
				r, g, b = 0.85, 0.85, 0.85
			elseif inputMode == 'a:' then
				r, g, b = 0.2, 1, 0.2
			elseif inputMode == 's:' then
				r, g, b = 1, 1, 0.2
			else
				r, g, b = 0.95, 0.95, 0.95
			end
			usedFont:SetTextColor(r,g,b, 1)
			usedFont:Print(inputText, textPosX, activationArea[2]+chatlogHeightDiff-distance-(inputHeight*0.61), inputFontSize, "o")
			if autocompleteText then
				usedFont:SetTextColor(r,g,b, 0.35)
				usedFont:Print(autocompleteText, textPosX + floor(usedFont:GetTextWidth(inputText) * inputFontSize), activationArea[2]+chatlogHeightDiff-distance-(inputHeight*0.61), inputFontSize, "")
			end

			-- autocomplete multi-suggestions
			if autocompleteText and autocompleteWords[2] then
				--local letters = ''
				--local isCmd = ssub(inputText, 1, 1) == '/'
				--local textWordCount = 0
				--for word in (ssub(inputText, isCmd and 2 or 1)):gmatch("%S+") do
				--	textWordCount = textWordCount + 1
				--	letters = word
				--end

				local letters = ''
				for word in (isCmd and ssub(inputText, 2) or inputText):gmatch("%S+") do
					letters = word
				end
				if ssub(inputText, #inputText) == ' ' then
					letters = letters..' '
				elseif prevAutocompleteLetters then
					letters = prevAutocompleteLetters .. letters
				end
				local letterCount = #letters
				local scale = 0.8
				local autocLineHeight = floor(inputFontSize * scale * 1.3)
				local lettersWidth = floor(usedFont:GetTextWidth(letters) * inputFontSize * scale)
				local xPos = floor(textPosX + textCursorPos - lettersWidth)
				local yPos =  activationArea[2]+chatlogHeightDiff-distance-inputHeight
				local height = (autocLineHeight * math.min(allowMultiAutocompleteMax, #autocompleteWords-1) + leftOffset) + (#autocompleteWords > allowMultiAutocompleteMax+1 and autocLineHeight or 0)
				glColor(0,0,0,inputAlpha)
				RectRound(xPos-leftOffset, yPos-height, x2-elementMargin, yPos, elementCorner*0.6, 0,0,1,1)
				if WG['guishader'] then
					WG['guishader'].InsertRect(xPos-leftOffset, yPos-height, x2-elementPadding, yPos, 'chatinputautocomplete')
				end
				local addHeight = floor((inputFontSize*scale) * 1.35) - autocLineHeight
				for i, word in ipairs(autocompleteWords) do
					if i > 1 then
						addHeight = addHeight + autocLineHeight
						usedFont:SetTextColor(r,g,b, 0.8)
						usedFont:Print(letters, xPos, yPos-addHeight, inputFontSize*scale, "")
						usedFont:SetTextColor(r,g,b, 0.35)
						if i <= allowMultiAutocompleteMax+1 then
							usedFont:Print(ssub(word, letterCount+1), xPos + lettersWidth, yPos-addHeight, inputFontSize*scale, "")
						else
							local text = ''
							for i=1, #word do
								text = text .. '.'
							end
							usedFont:Print(text, xPos + lettersWidth, yPos-addHeight, inputFontSize*scale, "")
							break
						end
					end
				end
			else
				if WG['guishader'] then
					WG['guishader'].RemoveRect('chatinputautocomplete')
				end
			end

			usedFont:End()
		end)
	end
end

function widget:FontsChanged()
	clearDisplayLists()
	textInputDlist = glDeleteList(textInputDlist)
	processLines()
end

function widget:DrawScreen()
	if chobbyInterface then return end
	if not chatLines[1] and not consoleLines[1] then return end

	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	local x,y,b = Spring.GetMouseState()
	local chatlogHeightDiff = historyMode and floor(vsy*(scrollingPosY-posY)) or 0
	if hovering and WG['guishader'] then
		WG['guishader'].RemoveRect('chat')
	end

	-- draw chat input
	if handleTextInput then

		if showTextInput and updateTextInputDlist then
			drawChatInput()
		end
		if showTextInput and textInputDlist then
			glCallList(textInputDlist)
			drawChatInputCursor()
			-- button hover
			if inputButtonRect[1] and math_isInRect(x, y, inputButtonRect[1], inputButtonRect[2], inputButtonRect[3], inputButtonRect[4]) then
				Spring.SetMouseCursor('cursornormal')
				glColor(1,1,1,0.075)
				RectRound(inputButtonRect[1], inputButtonRect[2], inputButtonRect[3], inputButtonRect[4], elementCorner*0.6, 1,0,0,1)
			end
		elseif WG['guishader'] then
			WG['guishader'].RemoveRect('chatinput')
			WG['guishader'].RemoveRect('chatinputautocomplete')
			textInputDlist = glDeleteList(textInputDlist)
		end
	end

	if hide and not historyMode then
		return
	end

	if (showHistoryWhenChatInput and showTextInput) or math_isInRect(x, y, activationArea[1], activationArea[2]+chatlogHeightDiff, activationArea[3], activationArea[4]) or  (scrolling and math_isInRect(x, y, activationArea[1], activationArea[2]+chatlogHeightDiff, activationArea[3], activationArea[2]))  then
		hovering = true
		if historyMode then
			UiElement(activationArea[1], activationArea[2]+chatlogHeightDiff, activationArea[3], activationArea[4])
			if WG['guishader'] then
				WG['guishader'].InsertRect(activationArea[1], activationArea[2]+chatlogHeightDiff, activationArea[3], activationArea[4], 'chat')
			end

			-- player name background
			if historyMode == 'chat' then
				local gametimeEnd = floor(backgroundPadding+maxTimeWidth+(backgroundPadding*0.75))
				local playernameEnd = gametimeEnd + maxPlayernameWidth + (lineSpaceWidth/1.8)
				glColor(1,1,1,0.045)
				RectRound(activationArea[1]+gametimeEnd, activationArea[2]+elementPadding+chatlogHeightDiff, activationArea[1]+playernameEnd, activationArea[4]-elementPadding, elementCorner*0.66, 0,0,0,0)
				-- vertical line at start and end
				glColor(1,1,1,0.045)
				RectRound(activationArea[1]+playernameEnd-1, activationArea[2]+elementPadding+chatlogHeightDiff, activationArea[1]+playernameEnd, activationArea[4]-elementPadding, 0, 0,0,0,0)
				RectRound(activationArea[1]+gametimeEnd, activationArea[2]+elementPadding+chatlogHeightDiff, activationArea[1]+gametimeEnd+1, activationArea[4]-elementPadding, 0, 0,0,0,0)
			end

			local scrollbarMargin = floor(16 * widgetScale)
			local scrollbarWidth = floor(11 * widgetScale)
			UiScroller(
				floor(activationArea[3]-scrollbarMargin-scrollbarWidth),
				floor(activationArea[2]+chatlogHeightDiff+scrollbarMargin),
				floor(activationArea[3]-scrollbarMargin),
				floor(activationArea[4]-scrollbarMargin),
				historyMode == 'console' and #consoleLines*lineHeight or #chatLines*lineHeight,
				historyMode == 'console' and (currentConsoleLine-maxLinesScroll)*lineHeight or (currentChatLine-maxLinesScroll)*lineHeight
			)
		end
	else
		if not showHistoryWhenChatInput or not showTextInput then
			hovering = false
			historyMode = false
			currentChatLine = #chatLines
		end
	end

	-- draw background
	if not historyMode and backgroundOpacity > 0 and displayedChatLines > 0 then
		glColor(1,1,1,0.1*backgroundOpacity)
		local borderSize = 1
		RectRound(activationArea[1]-borderSize, activationArea[2]-borderSize, activationArea[3]+borderSize, activationArea[2]+borderSize+((displayedChatLines+1)*lineHeight)+(displayedChatLines==maxLines and 0 or elementPadding), elementCorner*1.2)

		glColor(0,0,0,backgroundOpacity)
		--RectRound(activationArea[1], activationArea[2]+chatlogHeightDiff, activationArea[3], activationArea[4], elementCorner)
		RectRound(activationArea[1], activationArea[2], activationArea[3], activationArea[2]+((displayedChatLines+1)*lineHeight)+(displayedChatLines==maxLines and 0 or elementPadding), elementCorner)
		if hovering then --and Spring.GetGameFrame() < 30*60*7 then
			font:Begin()
			font:SetTextColor(0.1,0.1,0.1,0.66)
			font:Print(Spring.I18N('ui.chat.shortcut'), activationArea[3]-elementPadding-elementPadding, activationArea[2]+elementPadding+elementPadding, usedConsoleFontSize, "r")
			font:End()
		end
	end

	-- draw console lines
	if not historyMode and consoleLines[1] then
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

	-- draw chat lines or chat/console ui panel
	if historyMode or chatLines[currentChatLine] then
		if #chatLines == 0 and historyMode == 'chat' then
			font:Begin()
			font:SetTextColor(0.35,0.35,0.35,0.66)
			font:Print(Spring.I18N('ui.chat.nohistory'), activationArea[1]+(activationArea[3]-activationArea[1])/2, activationArea[2]+elementPadding+elementPadding, usedConsoleFontSize*1.1, "c")
			font:End()
		end
		local checkedLines = 0
		if not historyMode then
			displayedChatLines = 0
		end
		glPushMatrix()
		local translatedX = (vsx * posX) + backgroundPadding
		local translatedY = vsy * (historyMode and scrollingPosY or posY) + backgroundPadding
		glTranslate(translatedX, translatedY, 0)
		local i = historyMode == 'console' and currentConsoleLine or currentChatLine
		local usedMaxLines = maxLines
		if historyMode then
			usedMaxLines = maxLinesScroll
		end
		local width = floor(maxTimeWidth+(lineHeight*0.75))
		local ctrlHover = enableShortcutClick and ctrl and math_isInRect(x, y, activationArea[1],activationArea[2]+chatlogHeightDiff,activationArea[3],activationArea[4])
		while i > 0 do
			if historyMode or clock() - chatLines[i].startTime < lineTTL or ctrlHover then
				if historyMode == 'console' then
					processConsoleLine(i)
				else
					processLine(i)
				end
				if historyMode or ctrlHover then
					if historyMode == 'console' then
						if consoleLines[i].timeDisplayList then
							glCallList(consoleLines[i].timeDisplayList)
						end
					else
						if historyMode and chatLines[i].timeDisplayList then
							glCallList(chatLines[i].timeDisplayList)
						end

						local isClickableLine = chatLines[i].coords or chatLines[i].selectUnits
						if isClickableLine then
							local lineArea = {
								translatedX + width,
								translatedY + (lineHeight*checkedLines),
								floor(translatedX + width + (activationArea[3]-activationArea[1])-backgroundPadding-backgroundPadding-maxTimeWidth - (38 * widgetScale)),
								translatedY + (lineHeight*checkedLines) + lineHeight
							}
							if math_isInRect(x, y, lineArea[1], lineArea[2], lineArea[3], lineArea[4]) then
								UiSelectHighlight(lineArea[1]-translatedX, lineArea[2]-translatedY-(lineHeight*checkedLines), lineArea[3]-translatedX, lineArea[4]-translatedY-(lineHeight*checkedLines), nil, (b and 0.33 or 0.23))
								if b then
									-- mapmark highlight
									if chatLines[i].coords then
										Spring.SetCameraTarget( chatLines[i].coords[1], chatLines[i].coords[2], chatLines[i].coords[3] )
									end
									-- unit share
									if chatLines[i].selectUnits then
										Spring.SelectUnitArray(chatLines[i].selectUnits)
										Spring.SendCommands("viewselection")
									end
								end
							end
						end
					end
					if historyMode then
						glTranslate(width, 0, 0)
					end
				end
				glCallList(historyMode == 'console' and consoleLines[i].lineDisplayList or chatLines[i].lineDisplayList)
				if historyMode then
					glTranslate(-width, 0, 0)
				end
				if not historyMode then
					displayedChatLines = displayedChatLines + 1
				end
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

		-- show new chat when in historyMode mode
		if historyMode and currentChatLine < #chatLines and clock() - chatLines[#chatLines].startTime < lineTTL then
			glPushMatrix()
			glTranslate(vsx * posX, vsy * ((historyMode and scrollingPosY or posY)-0.02)-backgroundPadding, 0)
			processLine(#chatLines)
			glCallList(chatLines[#chatLines].lineDisplayList)
			glPopMatrix()
		end
	end
end

local function runAutocompleteSet(wordsSet, searchStr, multi, lower)
	autocompleteWords = {}
	local charCount = slen(searchStr)
	for i, word in ipairs(wordsSet) do
		if slen(word) > charCount  and (searchStr == ssub(word, 1, charCount) or (lower and searchStr:lower() == ssub(word:lower(), 1, charCount)))  then
			autocompleteWords[#autocompleteWords+1] = word
			if not autocompleteText then
				autocompleteText = ssub(word, charCount+1)
				if not multi then
					return true
				end
			end
		end
	end
	return autocompleteText ~= nil
end

local function autocomplete(text, fresh)
	autocompleteText = nil
	if fresh then
		autocompleteWords = {}
	end
	if text == '' then
		return
	end
	local letters = ''
	local isCmd = ssub(text, 1, 1) == '/'
	local words = {}
	for word in (ssub(text, isCmd and 2 or 1)):gmatch("%S+") do
		words[#words+1] = word
		letters = word
	end
	-- if there are still suggestions then try to continue before starting fresh with a new word
	if ssub(inputText, #text) == ' ' then
		letters = letters..' '
		if autocompleteWords[1] then
			prevAutocompleteLetters = letters
		end
	else
		if prevAutocompleteLetters and autocompleteWords[1] then
			letters = prevAutocompleteLetters .. letters
			if isCmd then
				words = {[1] = letters}
			end
		else
			prevAutocompleteLetters = nil
		end
	end

	-- find autocompleteWords
	if autocompleteWords[2] then
		runAutocompleteSet(autocompleteWords, letters, allowMultiAutocomplete, true)
	else
		if #letters >= 2 then
			runAutocompleteSet(autocompletePlayernames, letters)
		end
		if not autocompleteWords[1] then
			if isCmd then
				if #words <= 1 then
					runAutocompleteSet(autocompleteCommands, letters, allowMultiAutocomplete)
				else
					runAutocompleteSet(autocompleteUnitCodename, letters, allowMultiAutocomplete)
				end
			else
				if #letters >= 2 then
					runAutocompleteSet(autocompleteUnitNames, letters, allowMultiAutocomplete, true)
				end
			end
		end
	end

	-- if prev autocomplete words didnt result in suggestions, redo it freshly
	if prevAutocompleteLetters and not autocompleteWords[1] and not ssub(inputText, #text) == ' ' then
		prevAutocompleteLetters = nil
		autocomplete(text, true)
	end
end

function widget:TextInput(char)	-- if it isnt working: chobby probably hijacked it
	if handleTextInput and not chobbyInterface and not Spring.IsGUIHidden() and showTextInput then
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
		inputHistory[#inputHistory] = inputText
		cursorBlinkTimer = 0
		autocomplete(inputText)
		updateTextInputDlist = true
		if WG['limitidlefps'] and WG['limitidlefps'].update then
			WG['limitidlefps'].update()
		end
		return true
	end
end

function widget:KeyRelease()
	-- Since we grab the keyboard, we need to specify a KeyRelease to make sure other release actions can be triggered
	return false
end

function widget:KeyPress(key)
	if Spring.IsGUIHidden() or not handleTextInput then
		return
	end

	local alt, ctrl, _, shift = Spring.GetModKeyState()

	if key == 13 then -- RETURN	 (keypad enter = 271)
		if showTextInput then
			if ctrl or alt or shift then
				-- switch mode
				if ctrl then
					inputMode = ''
				elseif alt and not isSpec then
					inputMode = (inputMode == 'a:' and '' or 'a:')
				else
					inputMode = (inputMode == 's:' and '' or 's:')
				end
			else
				-- send chat/cmd
				if inputText ~= '' then
					if ssub(inputText, 1, 1) == '/' then
						Spring.SendCommands(ssub(inputText, 2))
					else
						Spring.SendCommands("say "..inputMode..inputText)
					end
				end
				cancelChatInput()
			end
		else
			cancelChatInput()
			showTextInput = true
			if showHistoryWhenChatInput then
				historyMode = 'chat'
				maxLinesScroll = maxLinesScrollChatInput
			end
			widgetHandler:OwnText()
			if not inputHistory[inputHistoryCurrent] or inputHistory[inputHistoryCurrent] ~= '' then
				if inputHistoryCurrent == 1 or inputHistory[inputHistoryCurrent] ~= inputHistory[inputHistoryCurrent-1] then
					inputHistoryCurrent = inputHistoryCurrent + 1
				end
				inputHistory[inputHistoryCurrent] = ''
			end
			if ctrl then
				inputMode = ''
			elseif alt then
				inputMode = isSpec and 's:' or 'a:'
			elseif shift then
				inputMode = 's:'
			end
			-- again just to be safe, had report locking could still happen
			Spring.SDLStartTextInput()	-- because: touch chobby's text edit field once and widget:TextInput is gone for the game, so we make sure its started!
		end

		updateTextInputDlist = true
		return true
	end

	if not showTextInput then
		return false
	end

	if ctrl and key == 118 then -- CTRL + V
		local clipboardText = Spring.GetClipboard()
		inputText = utf8.sub(inputText, 1, inputTextPosition) .. clipboardText .. utf8.sub(inputText, inputTextPosition+1)
		inputTextPosition = inputTextPosition + utf8.len(clipboardText)
		if string.len(inputText) > maxTextInputChars then
			inputText = string.sub(inputText, 1, maxTextInputChars)
			if inputTextPosition > maxTextInputChars then
				inputTextPosition = maxTextInputChars
			end
		end
		inputHistory[#inputHistory] = inputText
		cursorBlinkTimer = 0
		autocomplete(inputText, true)

	elseif not alt and not ctrl then
		if key == 27 then -- ESC
			cancelChatInput()
		elseif key == 8 then -- BACKSPACE
			if inputTextPosition > 0 then
				inputText = utf8.sub(inputText, 1, inputTextPosition-1) .. utf8.sub(inputText, inputTextPosition+1)
				inputTextPosition = inputTextPosition - 1
				inputHistory[#inputHistory] = inputText
				if not (prevAutocompleteLetters and inputTextPosition == #inputText and ssub(inputText, #inputText) ~= ' ') then
					prevAutocompleteLetters = nil
				end
			end
			cursorBlinkTimer = 0
			autocomplete(inputText, not prevAutocompleteLetters)
		elseif key == 127 then -- DELETE
			if inputTextPosition < utf8.len(inputText) then
				inputText = utf8.sub(inputText, 1, inputTextPosition) .. utf8.sub(inputText, inputTextPosition+2)
				inputHistory[#inputHistory] = inputText
			end
			cursorBlinkTimer = 0
			autocomplete(inputText, true)
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
			inputHistoryCurrent = inputHistoryCurrent - 1
			if inputHistoryCurrent < 1 then
				inputHistoryCurrent = 1
			end
			if inputHistory[inputHistoryCurrent] then
				inputText = inputHistory[inputHistoryCurrent]
				inputHistory[#inputHistory] = inputText
			end
			inputTextPosition = utf8.len(inputText)
			cursorBlinkTimer = 0
			autocomplete(inputText, true)
		elseif key == 274 then -- DOWN
			inputHistoryCurrent = inputHistoryCurrent + 1
			if inputHistoryCurrent >= #inputHistory then
				inputHistoryCurrent = #inputHistory
			end
			inputText = inputHistory[inputHistoryCurrent]
			inputTextPosition = utf8.len(inputText)
			cursorBlinkTimer = 0
			autocomplete(inputText, true)
		elseif key == 9 then -- TAB
			if autocompleteText then
				inputText = utf8.sub(inputText, 1, inputTextPosition) .. autocompleteText .. utf8.sub(inputText, inputTextPosition+1)
				inputTextPosition = inputTextPosition + utf8.len(autocompleteText)
				inputHistory[#inputHistory] = inputText
				autocompleteText = nil
				autocompleteWords = {}
			end
		else
			-- regular chars/keys handled in widget:TextInput
		end
	end

	updateTextInputDlist = true
	return true
end

function widget:MousePress(x, y, button)
	if button == 1 and handleTextInput and showTextInput and inputButton and inputButtonRect and not Spring.IsGUIHidden() and math_isInRect(x, y, inputButtonRect[1], inputButtonRect[2], inputButtonRect[3], inputButtonRect[4]) then
		if inputMode == 'a:' then
			inputMode = ''
		elseif inputMode == 's:' then
			inputMode = isSpec and '' or 'a:'
		else
			inputMode = 's:'
		end
		updateTextInputDlist = true
		return true
	end
end

function widget:MouseWheel(up, value)
	if historyMode and not Spring.IsGUIHidden() then
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		if up then
			if historyMode == 'console' then
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
			if historyMode == 'console' then
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
	local chatlogHeightDiff = historyMode and floor(vsy*(scrollingPosY-posY)) or 0
	if #chatLines > 0 and math_isInRect(x, y, activationArea[1],activationArea[2]+chatlogHeightDiff,activationArea[3],activationArea[4]) then
		return Spring.I18N('ui.chat.scroll', { textColor = "\255\255\255\255", highlightColor = "\255\255\255\001" })
	end
end

function widget:MapDrawCmd(playerID, cmdType, x, y, z, a, b, c)
	if cmdType == 'point' then
		lastMapmarkCoords = {x,y,z}
	end
end

function widget:AddConsoleLine(lines, priority)
	lines = lines:match('^%[f=[0-9]+%] (.*)$') or lines
	for line in lines:gmatch("[^\n]+") do
		processAddConsoleLine(spGetGameFrame(), line, true)
	end
end

function widget:TextCommand(command)
	if string.find(command, "clearconsole", nil, true) == 1  and  string.len(command) == 12 then
		orgLines = {}
		processLines(true)
	end
	if string.sub(command, 1, 12) == 'hidespecchat' then
		if string.sub(command, 14, 14) ~= '' then
			if string.sub(command, 14, 14) == '0' then
				hideSpecChat = false
			elseif string.sub(command, 14, 14) == '1' then
				hideSpecChat = true
			end
		else
			hideSpecChat = not hideSpecChat
		end
		Spring.SetConfigInt('HideSpecChat', hideSpecChat and 1 or 0)
		if hideSpecChat then
			Spring.Echo("Hiding all spectator chat")
		else
			Spring.Echo("Showing all spectator chat again")
		end
	end
	if string.sub(command, 1, 18) == 'preventhistorymode' then
		showHistoryWhenCtrlShift = not showHistoryWhenCtrlShift
		enableShortcutClick = not enableShortcutClick
		if not showHistoryWhenCtrlShift then
			Spring.Echo("Preventing toggling historymode via CTRL+SHIFT")
		else
			Spring.Echo("Enabled toggling historymode via CTRL+SHIFT")
		end
	end
end

function widget:ViewResize()
	vsx,vsy = Spring.GetViewGeometry()

	--widgetScale = (((vsx*0.3 + (vsy*2.33)) / 2000) * 0.55) * (0.95+(ui_scale-1)/1.5)
	widgetScale = vsy * 0.00075 * ui_scale

	UiElement = WG.FlowUI.Draw.Element
	UiScroller = WG.FlowUI.Draw.Scroller
	UiSelectHighlight = WG.FlowUI.Draw.SelectHighlight
	elementCorner = WG.FlowUI.elementCorner
	elementPadding = WG.FlowUI.elementPadding
	elementMargin = WG.FlowUI.elementMargin
	RectRound = WG.FlowUI.Draw.RectRound

	charSize = 21 - (3.5 * ((vsx/vsy) - 1.78))
	usedFontSize = charSize*widgetScale*fontsizeMult
	usedConsoleFontSize = usedFontSize*consoleFontSizeMult
	font = WG['fonts'].getFont(nil, (charSize/18)*fontsizeMult, 0.19, 1.75)
	font2 = WG['fonts'].getFont(fontfile2, (charSize/18)*fontsizeMult, 0.19, 1.75)
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
	consoleLineHeight = math.floor(usedConsoleFontSize*lineHeightMult)
	backgroundPadding = elementPadding + floor(lineHeight*0.5)

	local posY2 = 0.94
	if WG['topbar'] ~= nil then
		topbarArea = WG['topbar'].GetPosition()
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

function widget:PlayerChanged(playerID)
	isSpec = Spring.GetSpectatingState()
	if isSpec and inputMode == 'a:' then
		inputMode = 's:'
	end
end

function widget:PlayerAdded(playerID)
	local name = Spring.GetPlayerInfo(playerID, false)
	autocompletePlayernames[#autocompletePlayernames+1] = name
end


function widget:LanguageChanged()
	refreshUnitDefs()
	energyText = Spring.I18N('ui.topbar.resources.energy'):lower()
	metalText = Spring.I18N('ui.topbar.resources.metal'):lower()
end

function widget:Initialize()
	Spring.SDLStartTextInput()	-- because: touch chobby's text edit field once and widget:TextInput is gone for the game, so we make sure its started!

	widget:ViewResize()

	Spring.SendCommands("console 0")

	if WG.ignoredPlayers then
		ignoredPlayers = table.copy(WG.ignoredPlayers)
	end

	WG['chat'] = {}
	WG['chat'].isInputActive = function()
		return showTextInput
	end
	WG['chat'].getInputButton = function()
		return inputButton
	end
	WG['chat'].setHide = function(value)
		hide = value
	end
	WG['chat'].getHide = function()
		return hide
	end
	WG['chat'].setChatInputHistory = function(value)
		showHistoryWhenChatInput = value
	end
	WG['chat'].getChatInputHistory = function()
		return showHistoryWhenChatInput
	end
	WG['chat'].setInputButton = function(value)
		inputButton = value
	end
	WG['chat'].getHandleInput = function()
		return handleTextInput
	end
	WG['chat'].setHandleInput = function(value)
		handleTextInput = value
		if not handleTextInput then
			cancelChatInput()
		end
		Spring.SDLStartTextInput()	-- because: touch chobby's text edit field once and widget:TextInput is gone for the game, so we make sure its started!
	end
	WG['chat'].getChatVolume = function()
		return sndChatFileVolume
	end
	WG['chat'].setChatVolume = function(value)
		sndChatFileVolume = value
	end
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

function widget:Shutdown()
	clearDisplayLists()	-- console/chat displaylists
	glDeleteList(textInputDlist)
	WG['chat'] = nil
	if WG['guishader'] then
		WG['guishader'].RemoveRect('chat')
		WG['guishader'].RemoveRect('chatinput')
		WG['guishader'].RemoveRect('chatinputautocomplete')
	end
end

function widget:GameOver()
	gameOver = true
end

function widget:GetConfigData(data)
	local inputHistoryLimited = {}
	for k,v in ipairs(inputHistory) do
		if k >= (#inputHistory - 20) then
			inputHistoryLimited[#inputHistoryLimited+1] = v
		end
	end

	local maxOrgLines = 600
	if #orgLines > maxOrgLines then
		local prunedOrgLines = {}
		for i=1, maxOrgLines do
			prunedOrgLines[i] = orgLines[(#orgLines-maxOrgLines)+i]
		end
		orgLines = prunedOrgLines
	end

	return {
		gameFrame = Spring.GetGameFrame(),
		gameID = Game.gameID and Game.gameID or Spring.GetGameRulesParam("GameID"),
		orgLines = gameOver and nil or orgLines,
		inputHistory = inputHistoryLimited,
		maxLines = maxLines,
		maxConsoleLines = maxConsoleLines,
		fontsizeMult = fontsizeMult,
		chatBackgroundOpacity = backgroundOpacity,
		sndChatFileVolume = sndChatFileVolume,
		shutdownTime = os.clock(),
		handleTextInput = handleTextInput,
		inputButton = inputButton,
		hide = hide,
		showHistoryWhenChatInput = showHistoryWhenChatInput,
		showHistoryWhenCtrlShift = showHistoryWhenCtrlShift,
		enableShortcutClick = enableShortcutClick,
		soundErrors = soundErrors,
		version = 1,
	}
end

function widget:SetConfigData(data)
	if data.orgLines ~= nil then
		if Spring.GetGameFrame() > 0 or (data.gameID and data.gameID == (Game.gameID and Game.gameID or Spring.GetGameRulesParam("GameID"))) then
			orgLines = data.orgLines
			if data.soundErrors then
				soundErrors = data.soundErrors
			end
		elseif data.gameID then
			prevGameID = data.gameID
			prevOrgLines = data.orgLines
		end
	end
	if data.inputHistory ~= nil then
		inputHistory = data.inputHistory
		inputHistoryCurrent = #inputHistory
	end
	if data.sndChatFileVolume ~= nil then
		sndChatFileVolume = data.sndChatFileVolume
	end
	if data.showHistoryWhenCtrlShift ~= nil then
		showHistoryWhenCtrlShift = data.showHistoryWhenCtrlShift
	end
	if data.enableShortcutClick ~= nil then
		enableShortcutClick = data.enableShortcutClick
	end
	if data.chatBackgroundOpacity ~= nil then
		backgroundOpacity = data.chatBackgroundOpacity
	end
	if data.hide ~= nil then
		hide = data.hide
	end
	if data.showHistoryWhenChatInput ~= nil then
		showHistoryWhenChatInput = data.showHistoryWhenChatInput
	end
	if data.maxLines ~= nil then
		maxLines = data.maxLines
	end
	if data.maxConsoleLines ~= nil then
		maxConsoleLines = data.maxConsoleLines
	end
	if data.fontsizeMult ~= nil then
		fontsizeMult = data.fontsizeMult
	end
	if data.inputButton ~= nil then
		inputButton = data.inputButton
	end
	if data.version ~= nil then
		if data.handleTextInput ~= nil then
			handleTextInput = data.handleTextInput
		end
	end
end
