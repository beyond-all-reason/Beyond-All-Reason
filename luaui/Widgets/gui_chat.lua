local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Chat",
		desc      = "chat/console (do /clearconsole to wipe history)",
		author    = "Floris",
		date      = "May 2021",
		license   = "GNU GPL, v2 or later",
		layer     = -95000,
		enabled   = true,
		handler   = true,
	}
end

-- Forward declarations to avoid upvalue limit (200 max per function)
local drawGameTime, drawConsoleLine, drawChatLine, drawChatInputCursor, drawChatInput, drawUi, drawTextInput

-- Localized functions for performance
local mathFloor = math.floor
local mathMin = math.min

-- Localized Spring API for performance
local spGetMyTeamID = Spring.GetMyTeamID
local spGetMouseState = Spring.GetMouseState
local spEcho = Spring.Echo
local spGetSpectatingState = Spring.GetSpectatingState

local useRenderToTexture = Spring.GetConfigFloat("ui_rendertotexture", 1) == 1		-- much faster than drawing via DisplayLists only

local LineTypes = {
	Console = -1,
	Player = 1,
	Spectator = 2,
	Mapmark = 3,
	Battleroom = 4,
	System = 5
}

local utf8 = VFS.Include('common/luaUtilities/utf8.lua')
local badWords = VFS.Include('luaui/configs/badwords.lua')

local L_DEPRECATED = LOG.DEPRECATED
local isDevSingle = (Spring.Utilities.IsDevMode() and Spring.Utilities.Gametype.IsSinglePlayer())

-- Configuration consolidated into table to reduce local variable count
local vsx, vsy = gl.GetViewSizes()
local config = {
	showHistoryWhenChatInput = true,
	showHistoryWhenCtrlShift = true,
	enableShortcutClick = true,
	posY = 0.81,
	posX = 0.3,
	posX2 = 0.74,
	charSize = 21 - (3.5 * ((vsx/vsy) - 1.78)),
	consoleFontSizeMult = 0.85,
	maxLines = 5,
	maxConsoleLines = 2,
	maxLinesScrollFull = 16,
	maxLinesScrollChatInput = 9,
	lineHeightMult = 1.36,
	lineTTL = 40,
	consoleLineCleanupTarget = Spring.Utilities.IsDevMode() and 1200 or 400,
	orgLineCleanupTarget = Spring.Utilities.IsDevMode() and 1400 or 600,
	backgroundOpacity = 0.25,
	handleTextInput = true,
	maxTextInputChars = 127,
	inputButton = true,
	allowMultiAutocomplete = true,
	allowMultiAutocompleteMax = 10,
	soundErrorsLimit = Spring.Utilities.IsDevMode() and 999 or 10,
	ui_scale = Spring.GetConfigFloat("ui_scale", 1),
	ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.7),
	widgetScale = 1,
	maxLinesScroll = 16, -- maxLinesScrollFull
	hide = false,
	refreshUi = true,
	fontsizeMult = 1,
	scrollingPosY = 0.66,
	consolePosY = 0.9,
	hideSpecChat = (Spring.GetConfigInt('HideSpecChat', 0) == 1),
	hideSpecChatPlayer = (Spring.GetConfigInt('HideSpecChatPlayer', 1) == 1),
	playSound = true,
	sndChatFile = 'beep4',
	sndChatFileVolume = 0.55,
}

-- Mutable config values (can be changed at runtime and saved)
local maxConsoleLines = config.maxConsoleLines
local fontsizeMult = config.fontsizeMult
local backgroundOpacity = config.backgroundOpacity
local handleTextInput = config.handleTextInput
local inputButton = config.inputButton
local hide = config.hide
local showHistoryWhenChatInput = config.showHistoryWhenChatInput
local showHistoryWhenCtrlShift = config.showHistoryWhenCtrlShift
local enableShortcutClick = config.enableShortcutClick

-- Access config/state/colors/layout via tables to stay under 200 locals
local usedFontSize = config.charSize*config.widgetScale*config.fontsizeMult
local usedConsoleFontSize = usedFontSize*config.consoleFontSizeMult

-- Essential config aliases (most frequently accessed)
local posY, posX, maxLines = config.posY, config.posX, config.maxLines
local lineHeightMult, hideSpecChat, hideSpecChatPlayer = config.lineHeightMult, config.hideSpecChat, config.hideSpecChatPlayer
local consoleFontSizeMult, posX2 = config.consoleFontSizeMult, config.posX2
local ui_scale, ui_opacity, lineHeight = config.ui_scale, config.ui_opacity, mathFloor(usedFontSize*config.lineHeightMult)
local consoleLineHeight = mathFloor(usedConsoleFontSize*config.lineHeightMult)
local orgLineCleanupTarget, maxTextInputChars = config.orgLineCleanupTarget, config.maxTextInputChars
local allowMultiAutocomplete, allowMultiAutocompleteMax, maxLinesScrollFull = config.allowMultiAutocomplete, config.allowMultiAutocompleteMax, config.maxLinesScrollFull
local lineTTL, consoleLineCleanupTarget, soundErrorsLimit = config.lineTTL, config.consoleLineCleanupTarget, config.soundErrorsLimit
local maxLinesScrollChatInput = config.maxLinesScrollChatInput
local maxLinesScroll = config.maxLinesScroll

-- Color configuration (keep local for performance)
local colorOther, colorAlly, colorSpec, colorSpecName = {1,1,1}, {0,1,0}, {1,1,0}, {1,1,1}
local colorOtherAlly, colorGame, colorConsole = {1,0.7,0.45}, {0.4,1,1}, {0.85,0.85,0.85}
local msgColor, msgHighlightColor = '\255\180\180\180', '\255\215\215\215'
local metalColor, metalValueColor = '\255\233\233\233', '\255\255\255\255'
local energyColor, energyValueColor = '\255\255\255\180', '\255\255\255\140'
local chatSeparator, pointSeparator = '\255\210\210\210:', '\255\255\255\255*'
local colorSpecStr, colorAllyStr, colorOtherAllyStr, colorGameStr, colorConsoleStr = '', '', '', '', ''

-- Layout (keep local for performance)
local maxPlayernameWidth, lineSpaceWidth, backgroundPadding = 50, 24*config.widgetScale, usedFontSize
local longestPlayername = '(s) [xx]playername'

-- State tables to reduce local variable count
local state = {
	I18N = {},
	orgLines = {},
	chatLines = {},
	consoleLines = {},
	ignoredAccounts = {},
	activationArea = {0,0,0,0},
	consoleActivationArea = {0,0,0,0},
	currentChatLine = 0,
	currentConsoleLine = 0,
	historyMode = false,
	prevCurrentConsoleLine = -1,
	prevCurrentChatLine = -1,
	prevHistoryMode = false,
	displayedChatLines = 0,
	lastMapmarkCoords = nil,
	lastUnitShare = nil,
	lastLineUnitShare = nil,
	lastDrawUiUpdate = os.clock(),
	myName = Spring.GetPlayerInfo(Spring.GetMyPlayerID(), false),
	mySpec = spGetSpectatingState(),
	myTeamID = spGetMyTeamID(),
	myAllyTeamID = Spring.GetMyAllyTeamID(),
	font = nil,
	font2 = nil,
	font3 = nil,
	chobbyInterface = nil,
	hovering = nil,
	RectRound = nil,
	UiElement = nil,
	UiSelectHighlight = nil,
	UiScroller = nil,
	elementCorner = nil,
	elementPadding = nil,
	elementMargin = nil,
	prevGameID = nil,
	prevOrgLines = nil,
	gameOver = false,
	textInputDlist = nil,
	updateTextInputDlist = true,
	textCursorRect = nil,
	showTextInput = false,
	inputText = '',
	inputTextPosition = 0,
	inputSelectionStart = nil,
	cursorBlinkTimer = 0,
	cursorBlinkDuration = 1,
	inputMode = nil,
	inputTextInsertActive = false,
	inputHistory = {},
	inputHistoryCurrent = 0,
	inputButtonRect = nil,
	autocompleteWords = {},
	prevAutocompleteLetters = nil,
	scrolling = false,
}

-- Essential state aliases (heavily accessed - keep as locals)
local I18N, orgLines, chatLines, consoleLines = state.I18N, state.orgLines, state.chatLines, state.consoleLines
local activationArea, font = state.activationArea, state.font
local showTextInput, inputText, cursorBlinkTimer, cursorBlinkDuration = false, '', 0, 1
local inputSelectionStart = nil
local inputMode, inputHistory, autocompleteWords, prevAutocompleteLetters = nil, {}, {}, nil
local scrolling, playSound, sndChatFile, sndChatFileVolume = false, config.playSound, config.sndChatFile, config.sndChatFileVolume
local myName, mySpec = state.myName, state.mySpec
local lastDrawUiUpdate = state.lastDrawUiUpdate
local displayedChatLines = state.displayedChatLines
local currentChatLine, currentConsoleLine = state.currentChatLine, state.currentConsoleLine
local historyMode = state.historyMode
local prevCurrentChatLine, prevCurrentConsoleLine, prevHistoryMode = state.prevCurrentChatLine, state.prevCurrentConsoleLine, state.prevHistoryMode
local gameOver = state.gameOver
local prevGameID, prevOrgLines = state.prevGameID, state.prevOrgLines
local ignoredAccounts = state.ignoredAccounts

local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode
local anonymousTeamColor = {Spring.GetConfigInt("anonymousColorR", 255)/255, Spring.GetConfigInt("anonymousColorG", 0)/255, Spring.GetConfigInt("anonymousColorB", 0)/255}

-- Keep only essential locals for GL/Spring/strings (heavily used in loops)
local glPopMatrix, glPushMatrix, glDeleteList, glCreateList, glCallList, glTranslate, glColor =
	gl.PopMatrix, gl.PushMatrix, gl.DeleteList, gl.CreateList, gl.CallList, gl.Translate, gl.Color
local string_lines, schar, slen, ssub, sfind = string.lines, string.char, string.len, string.sub, string.find
local math_isInRect, floor, clock = math.isInRect, mathFloor, os.clock
local spGetTeamColor, spGetPlayerInfo, spPlaySoundFile = Spring.GetTeamColor, Spring.GetPlayerInfo, Spring.PlaySoundFile
local spGetGameFrame, spGetTeamInfo = Spring.GetGameFrame, Spring.GetTeamInfo
local ColorString, ColorIsDark = Spring.Utilities and Spring.Utilities.Color and Spring.Utilities.Color.ToString, Spring.Utilities and Spring.Utilities.Color and Spring.Utilities.Color.ColorIsDark

local soundErrors = {}
local teamColorKeys = {}
local teamNames = {}

-- Filter color codes and control characters from player input to prevent injection
-- Based on engine TextWrap.h constants
local function stripColorCodes(text)
	local result = text
	-- Remove color codes and control characters according to Spring's TextWrap.h:
	-- ColorCodeIndicator (0xFF / \255) - followed by 3 bytes RGB
	result = result:gsub("\255...", "")
	result = result:gsub("\255", "")  -- ÿ
	result = result:gsub("ÿ", "")  -- ÿ
	-- ColorCodeIndicatorEx (0xFE / \254) - followed by 8 bytes RGBA + outline RGBA
	result = result:gsub("\254........", "")
	result = result:gsub("\254", "")  -- þ
	result = result:gsub("þ", "")  -- þ
	-- ColorResetIndicator (0x08 / \008) - reset to default color
	result = result:gsub("\008", "")
	-- SetColorIndicator (0x01 / \001) - followed by 3 bytes RGB (legacy)
	result = result:gsub("\001...", "")
	-- Also strip any remaining standalone control characters that might affect rendering
	result = result:gsub("\001", "")  -- SOH
	return result
end

-- Helper function to cleanup line tables when they grow too large
local function cleanupLineTable(prevTable, maxLines)
	local newTable = {}
	local start = #prevTable - maxLines
	for i=1, maxLines do
		newTable[i] = prevTable[start + i]
	end
	return newTable
end

local autocompleteCommands = {
	-- engine
	'advmapshading',
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
	'luarules removenearbyunits',
	'luarules spawnceg',
	'luarules spawnunitexplosion',
	'luarules undo',
	'luarules unitcallinsgadget',
	'luarules updatesun',
	'luarules waterlevel',
	'luarules wreckunits',
	'luarules xp',
	'luarules transferunits',
	'luarules playertoteam',
	'luarules killteam',
	'luarules globallos',

	-- zombie commands
	'luarules zombiesetallgaia',
	'luarules zombiequeueallcorpses',
	'luarules zombieautospawn 0',
	'luarules zombieclearspawns',
	'luarules zombiepacify 0',
	'luarules zombiesuspendorders 0',
	'luarules zombieaggroteam 0',
	'luarules zombieaggroally 0',
	'luarules zombiekillall',
	'luarules zombieclearallorders',
	'luarules zombiedebug 0',
	'luarules zombiemode normal',

	-- build blocking commands
	'luarules buildblock all default_reason',
	'luarules buildunblock all default_reason',

	-- widgets
	'luaui reload',
	'luaui disable',
	'luaui enable',
	'addmessage',
	'radarpulse',
	'ecostatstext',
	'defrange ally air',
	'defrange ally nuke',
	'defrange ally ground',
	'defrange enemy air',
	'defrange enemy nuke',
	'defrange enemy ground',
}

local playernames = {}
local playersList = Spring.GetPlayerList()
local chatProcessors = {}
local unitTranslatedHumanName = {}
local autocompleteText
local autocompletePlayernames = {}
local autocompleteUnitNames = {}
local autocompleteUnitCodename = {}

local function refreshUnitDefs()
	autocompleteUnitNames = {}
	autocompleteUnitCodename = {}
	local uniqueHumanNames = {}
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

function widget:LanguageChanged()
	I18N = {
		energy = Spring.I18N('ui.topbar.resources.energy'):lower(),
		metal = Spring.I18N('ui.topbar.resources.metal'):lower(),
		everyone = Spring.I18N('ui.chat.everyone'),
		allies = Spring.I18N('ui.chat.allies'),
		spectators = Spring.I18N('ui.chat.spectators'),
		cmd = Spring.I18N('ui.chat.cmd'),
		shortcut = Spring.I18N('ui.chat.shortcut'),
		nohistory = Spring.I18N('ui.chat.nohistory'),
		scroll = Spring.I18N('ui.chat.scroll', { textColor = "\255\255\255\255", highlightColor = "\255\255\255\001" }),
	}
	refreshUnitDefs()
	-- Cache color strings after language change (optimization)
	if ColorString then
		colorSpecStr = ColorString(colorSpec[1], colorSpec[2], colorSpec[3]) or ''
		colorAllyStr = ColorString(colorAlly[1], colorAlly[2], colorAlly[3]) or ''
		colorOtherAllyStr = ColorString(colorOtherAlly[1], colorOtherAlly[2], colorOtherAlly[3]) or ''
		colorGameStr = ColorString(colorGame[1], colorGame[2], colorGame[3]) or ''
		colorConsoleStr = ColorString(colorConsole[1], colorConsole[2], colorConsole[3]) or ''
	else
		colorSpecStr = ''
		colorAllyStr = ''
		colorOtherAllyStr = ''
		colorGameStr = ''
		colorConsoleStr = ''
	end
end
widget:LanguageChanged()

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

local lastMessage

local function findBadWords(str)
	str = string.lower(str)
	for w in str:gmatch("%w+") do
		for _, bw in ipairs(badWords) do
			if sfind(w, bw) then
				return w
			end
		end
	end
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
			if font and font:GetTextWidth(linebuffer..' '..word)*fontSize > maxWidth then
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

local function addConsoleLine(gameFrame, lineType, text, orgLineID, consoleLineID)
	if not text or text == '' then return end

	consoleLineID = consoleLineID and consoleLineID or #consoleLines+1

	-- convert /n into lines
	local textLines = string_lines(text)

	-- word wrap text into lines
	local wordwrappedText = wordWrap(textLines, consoleLineMaxWidth, usedConsoleFontSize)

	local lineColor = #wordwrappedText > 1 and ssub(wordwrappedText[1], 1, 4) or ''
	local startTime = clock()
	for i, line in ipairs(wordwrappedText) do
		consoleLines[consoleLineID] = {
			startTime = startTime,
			gameFrame = i == 1 and gameFrame,
			lineType = lineType,
			text = (i > 1 and lineColor or '')..line,
			orgLineID = orgLineID,
			--lineDisplayList = glCreateList(function() end),
			--timeDisplayList = glCreateList(function() end),
		}
		consoleLineID = consoleLineID + 1
	end

	if historyMode ~= 'console' then
		currentConsoleLine = consoleLineID
	end
end

local function getPlayerColorString(playername, gameFrame)
	if not ColorString then
		return ''
	end
	local color
	if playernames[playername] then
		if playernames[playername][5] and (not gameFrame or not playernames[playername][8] or gameFrame < playernames[playername][8]) then
			if not mySpec and anonymousMode ~= "disabled" then
				color = ColorString(anonymousTeamColor[1], anonymousTeamColor[2], anonymousTeamColor[3])
			else
				color = ColorString(playernames[playername][5][1], playernames[playername][5][2], playernames[playername][5][3])
			end
		else
			color = ColorString(colorSpecName[1], colorSpecName[2], colorSpecName[3])
		end
	else
		color = ColorString(0.7, 0.7, 0.7)
	end
	return color or ''
end

local function setCurrentChatLine(line)
	local i = line
	while i > 0 do
		if not chatLines[i].ignore then
			currentChatLine = i
			break
		end
		i = i - 1
	end
end

local function addChatLine(gameFrame, lineType, name, nameText, text, orgLineID, ignore, chatLineID, noProcessors)
	chatLineID = chatLineID and chatLineID or #chatLines + 1

	if not noProcessors then
		for _, processor in pairs(chatProcessors) do
			if text == nil then break end
			text = processor(gameFrame, lineType, name, nameText, text, orgLineID, ignore, chatLineID)
		end
	end

	if not text or text == '' then return end

	-- determine text typing start time
	local startTime = clock()

	local text_orig = text

	-- metal/energy given
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
							t[ pair[1] ] = getPlayerColorString(pair[2], gameFrame)..playernames[pair[2]][7]..msgColor
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
			-- Fix a widget crash that could occur with message "> ."
			if type(text) ~= "string" then text = text_orig end
			if text:lower():find(I18N.energy, nil, true) then
				local pos = text:lower():find(I18N.energy, nil, true)
				local len = slen(I18N.energy)
				text = ssub(text, 1, pos-1)..energyColor..ssub(text, pos, pos+len-1).. msgColor..ssub(text, pos+len)
			end
			if text:lower():find(I18N.metal, nil, true) then
				local pos = text:lower():find(I18N.metal, nil, true)
				local len = slen(I18N.metal)
				text = ssub(text, 1, pos-1)..metalColor..ssub(text, pos, pos+len-1).. msgColor..ssub(text, pos+len)
			end
		end
		text = msgColor..text
	end

	-- convert /n into lines
	local textLines = string_lines(text)

	-- word wrap text into lines
	local wordwrappedText = wordWrap(textLines, lineMaxWidth, usedFontSize)

	local lineColor = #wordwrappedText > 1 and ssub(wordwrappedText[1], 1, 4) or ''
	for i, line in ipairs(wordwrappedText) do
		chatLines[chatLineID] = {
			startTime = startTime,
			gameFrame = i == 1 and gameFrame,
			lineType = lineType,
			playerName = name,
			playerNameText = nameText,
			textOutline = (lineType ~= LineTypes.Spectator and (playernames[name] and playernames[name][5]) and ColorIsDark(playernames[name][5][1], playernames[name][5][2], playernames[name][5][3])) or false,
			text = (i > 1 and lineColor or '')..line,
			orgLineID = orgLineID,
			ignore = ignore,
			--lineDisplayList = glCreateList(function() end),
			--timeDisplayList = glCreateList(function() end),
		}
		if lineType == LineTypes.Mapmark and lastMapmarkCoords then
			chatLines[chatLineID].coords = lastMapmarkCoords
			lastMapmarkCoords = nil
		end
		if lineType == LineTypes.System then
			chatLines[chatLineID].text = line
			if lastLineUnitShare and lastLineUnitShare.newTeamID == myTeamID then
				chatLines[chatLineID].selectUnits = lastLineUnitShare.unitIDs
				lastLineUnitShare = nil
			end
		end
		chatLineID = chatLineID + 1
	end

	if historyMode ~= 'chat' and not ignore then
		setCurrentChatLine(#chatLines)
	end

	-- play sound for new player/spectator chat
	if not ignore and #orgLines == orgLineID and (lineType == LineTypes.Player or lineType == LineTypes.Spectator) and playSound and not Spring.IsGUIHidden() then
		spPlaySoundFile( sndChatFile, sndChatFileVolume, nil, "ui" )
	end
end

local function cancelChatInput()
	showTextInput = false
	if showHistoryWhenChatInput then
		historyMode = false
		setCurrentChatLine(#chatLines)
	end
	inputText = ''
	inputTextPosition = 0
	inputSelectionStart = nil
	inputTextInsertActive = false
	inputHistoryCurrent = #inputHistory
	autocompleteText = nil
	autocompleteWords = {}
	if WG['guishader'] then
		WG['guishader'].RemoveRect('chatinput')
		WG['guishader'].RemoveRect('chatinputautocomplete')
	end
	Spring.SDLStopTextInput()
	widgetHandler.textOwner = nil	-- non handler = true: widgetHandler:DisownText()
	updateDrawUi = true
end

local function commonUnitName(unitIDs)
	local commonUnitDefID = nil
	for _, unitID in pairs(unitIDs) do
		local unitDefID = Spring.GetUnitDefID(unitID)

		-- unitDefID will be nil if shared units are visible only as unidentified radar dots
		-- (when spectating with PlayerView ON from enemy team's point of view)
		if not unitDefID or (commonUnitDefID and unitDefID ~= commonUnitDefID) then
			return #unitIDs > 1 and "units" or "unit"
		end

		commonUnitDefID = unitDefID
	end
	return unitTranslatedHumanName[commonUnitDefID]
end

-- Helper to delete display lists from a line object
local function clearLineDisplayLists(line)
	if line.lineDisplayList then
		glDeleteList(line.lineDisplayList)
		line.lineDisplayList = nil
	end
	if line.timeDisplayList then
		glDeleteList(line.timeDisplayList)
		line.timeDisplayList = nil
	end
end

local function clearDisplayLists()
	for i = 1, #chatLines do
		clearLineDisplayLists(chatLines[i])
	end
	for i = 1, #consoleLines do
		clearLineDisplayLists(consoleLines[i])
	end
end

-- Helper function to clean user text input
local function cleanUserText(text)
	-- Filter occasional starting space
	if ssub(text, 1, 1) == ' ' then
		text = ssub(text, 2)
	end
	-- Filter color codes from user input
	return stripColorCodes(text)
end

-- Helper function to check if spectator messages should be hidden
local function shouldHideSpecMessage()
	-- Check config values directly to ensure we have the latest settings
	local currentHideSpecChat = (Spring.GetConfigInt('HideSpecChat', 0) == 1)
	local currentHideSpecChatPlayer = (Spring.GetConfigInt('HideSpecChatPlayer', 1) == 1)
	return currentHideSpecChat and (not currentHideSpecChatPlayer or not mySpec)
end

-- Helper function to extract channel prefix and apply color
local function extractChannelPrefix(text)
	if sfind(text, 'Allies: ', nil, true) == 1 then
		return ssub(text, 9), 'allies'
	elseif sfind(text, 'Spectators: ', nil, true) == 1 then
		return ssub(text, 13), 'spectators'
	end
	return text, 'all'
end

-- Helper function to get colored player name
local function getColoredPlayerName(name, gameFrame, isSpectator)
	local displayName = (playernames[name] and playernames[name][7]) or name
	if isSpectator then
		return colorSpecStr .. '(s) ' .. displayName
	end
	return getPlayerColorString(name, gameFrame) .. displayName
end

-- Helper function to format system message with player name
local function formatSystemMessage(i18nKey, playername, gameFrame, lineColor, extraParams)
	local params = extraParams or {}
	params.name = getPlayerColorString(playername, gameFrame) .. playername
	params.textColor = lineColor
	return Spring.I18N(i18nKey, params)
end

local function processAddConsoleLine(gameFrame, line, orgLineID, reprocessID)
	local orgLine = line
	local name = ''
	local nameText = ''
	local text = ''
	local lineType = 0
	local bypassThisMessage = false
	local skipThisMessage = false
	local textcolor, c

	-- player message
	if playernames[ssub(line,2,(sfind(line,"> ", nil, true) or 1)-1)] ~= nil then
		lineType = LineTypes.Player
		name = ssub(line,2,sfind(line,"> ", nil, true)-1)
		text = ssub(line,slen(name)+4)

		local channel
		text, channel = extractChannelPrefix(text)
		text = cleanUserText(text)

		if channel == 'allies' then
			c = playernames[name][1] == myAllyTeamID and colorAllyStr or colorOtherAllyStr
		elseif channel == 'spectators' then
			c = colorSpecStr
		else
			c = ColorString(colorOther[1], colorOther[2], colorOther[3])
		end

		nameText = getColoredPlayerName(name, gameFrame, false)
		line = c .. text

	-- spectator message
	elseif playernames[ssub(line,2,(sfind(line,"] ", nil, true) or 1)-1)] ~= nil  or  playernames[ssub(line,2,(sfind(line," (replay)] ", nil, true) or 1)-1)] ~= nil then
		lineType = LineTypes.Spectator
		if playernames[ssub(line,2,(sfind(line,"] ", nil, true) or 1)-1)] ~= nil then
			name = ssub(line,2,sfind(line,"] ", nil, true)-1)
			text = ssub(line,slen(name)+4)
		else
			name = ssub(line,2,sfind(line," (replay)] ", nil, true)-1)
			text = ssub(line,slen(name)+13)
		end

		skipThisMessage = shouldHideSpecMessage()

		local channel
		text, channel = extractChannelPrefix(text)
		text = cleanUserText(text)
		c = (channel ~= 'all') and colorSpecStr or ColorString(colorOther[1], colorOther[2], colorOther[3])

		nameText = getColoredPlayerName(name, gameFrame, true)
		line = c .. text

	-- point
	elseif playernames[ssub(line,1,(sfind(line," added point: ", nil, true) or 1)-1)] ~= nil then
		lineType = LineTypes.Mapmark
		name = ssub(line,1,sfind(line," added point: ", nil, true)-1)
		text = ssub(line,slen(name.." added point: ")+1)
		text = cleanUserText(text)

		if text == '' then
			text = 'Look here!'
		end

		local spectator = playernames[name] and playernames[name][2] or false
		if spectator then
			skipThisMessage = shouldHideSpecMessage()
			textcolor = colorSpecStr
		else
			textcolor = playernames[name][1] == myAllyTeamID and colorAllyStr or colorOtherAllyStr
		end

		nameText = getColoredPlayerName(name, gameFrame, spectator)
		line = textcolor .. text

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

		local spectator = playernames[name] and playernames[name][2] or false
		skipThisMessage = hideSpecChat and (not playernames[name] or spectator) and (not hideSpecChatPlayer or not mySpec)
		text = cleanUserText(text)

		nameText = colorGameStr .. '<' .. (playernames[name] and playernames[name][7] or name) .. '>'
		line = colorGameStr .. text

		-- units given
	elseif playernames[ssub(line,1,(sfind(line," shared units to ", nil, true) or 1)-1)] ~= nil then
		lineType = LineTypes.System

		-- Player1 shared units to Player2: 5 Wind Turbine
		local format = "(.+) shared units to (.+): (.+)"
		local oldTeamName, newTeamName, shareDesc = string.match(line, format)

		-- shared 5 Wind Turbine to Player2
		if newTeamName and newTeamName ~= '' and shareDesc and shareDesc ~= '' then
			local displayName = (playernames[newTeamName] and playernames[newTeamName][7]) or newTeamName
			text = msgColor .. Spring.I18N('ui.unitShare.shared', {
				units = msgHighlightColor .. shareDesc .. msgColor,
				name = getPlayerColorString(newTeamName, gameFrame) .. displayName
			})
		end

		nameText = getColoredPlayerName(oldTeamName, gameFrame, false)
		line = text

	-- console chat
	else
		lineType = LineTypes.Console
		local lineColor = ''

		-- Define bypass patterns to avoid repetitive checks
		local bypassPatterns = {
			"Input grabbing is ",
			" to access the quit menu",
			"VSync::SetInterval",
			" now spectating team ",
			"TotalHideLobbyInterface, ",
			"HandleLobbyOverlay",
			"Chobby]",
			"liblobby]",
			"[LuaMenu",
			"ClientMessage]",
			"ServerMessage]",
			"->",
			"-> Version",
			"ClientReadNet",
			"Address",
			'self%-destruct in ',
		}

		-- Check bypass patterns
		for _, pattern in ipairs(bypassPatterns) do
			if sfind(line, pattern, nil, true) then
				bypassThisMessage = true
				break
			end
		end

		if not bypassThisMessage then
			if sfind(line,"server=[0-9a-z][0-9a-z][0-9a-z][0-9a-z]") or sfind(line,"client=[0-9a-z][0-9a-z][0-9a-z][0-9a-z]") then
				bypassThisMessage = true
			elseif sfind(line,"could not load sound", nil, true) then
				if soundErrors[line] or #soundErrors > soundErrorsLimit then
					bypassThisMessage = true
				else
					soundErrors[line] = true
				end
			elseif gameOver and sfind(line,'left the game', nil, true) then
				bypassThisMessage = true
			elseif ssub(line,1,6) == "[i18n]" or ssub(line,1,6) == "[Font]" then
				lineColor = msgColor
			elseif sfind(line,"Wrong network version", nil, true) then
				local n = sfind(line,"Message", nil, true)
				if n then
					line = ssub(line,1,n-3)
				end
			elseif sfind(line,' paused the game', nil, true) then
				lineColor = '\255\225\225\255'
				local playername = ssub(line, 1, sfind(line, ' paused the game', nil, true)-1)
				line = formatSystemMessage('ui.chat.pausedthegame', playername, gameFrame, lineColor)
			elseif sfind(line,' unpaused the game', nil, true) then
				lineColor = '\255\225\255\225'
				local playername = ssub(line, 1, sfind(line, ' unpaused the game', nil, true)-1)
				line = formatSystemMessage('ui.chat.unpausedthegame', playername, gameFrame, lineColor)
			elseif sfind(line,'Sync error for', nil, true) then
				local playername = ssub(line, 16, sfind(line, ' in frame', nil, true)-1)
				lineColor = (playernames[playername] and not playernames[playername][2]) and '\255\255\133\133' or '\255\255\200\200'
				line = formatSystemMessage('ui.chat.syncerrorfor', playername, gameFrame, lineColor)
			elseif sfind(line,' is lagging behind', nil, true) then
				local playername = ssub(line, 1, sfind(line, ' is lagging behind', nil, true)-1)
				lineColor = (playernames[playername] and not playernames[playername][2]) and '\255\255\133\133' or '\255\255\200\200'
				line = formatSystemMessage('ui.chat.laggingbehind', playername, gameFrame, lineColor)
			elseif sfind(line,'Connection attempt from ', nil, true) then
				lineColor = msgHighlightColor
				local startPos, endPos = sfind(line, 'Connection attempt from ', nil, true)
				local playername = ssub(line, endPos + 1)
				local spectator = (playernames[playername] and playernames[playername][2]) and msgColor..' ('..Spring.I18N('ui.chat.spectator')..')' or ''
				-- Format message and append spectator suffix if needed
				local params = { textColor = lineColor, textColor2 = msgColor }
				params.name = getPlayerColorString(playername, gameFrame) .. playername .. spectator
				line = Spring.I18N('ui.chat.connectionattemptfrom', params)
			elseif sfind(line,'left the game:  normal quit', nil, true) then
				local isSpec = sfind(line,'Spectator', nil, true)
				local playername = ssub(line, isSpec and 11 or 8, sfind(line, ' left the game', nil, true)-1)
				lineColor = isSpec and msgHighlightColor or '\255\255\133\133'
				local spectator = isSpec and msgColor..' ('..Spring.I18N('ui.chat.spectator')..')' or ''
				line = formatSystemMessage('ui.chat.leftthegamenormal', playername, gameFrame, lineColor, { textColor2 = isSpec and msgColor or lineColor })
				if spectator ~= '' then
					-- Append spectator suffix
					line = line .. spectator:gsub(getPlayerColorString(playername, gameFrame) .. playername, '')
				end
			elseif sfind(line,'left the game:  timeout', nil, true) then
				local isSpec = sfind(line,'Spectator', nil, true)
				local playername = ssub(line, isSpec and 11 or 8, sfind(line, ' left the game', nil, true)-1)
				lineColor = isSpec and msgHighlightColor or '\255\255\133\133'
				local spectator = isSpec and msgColor..' ('..Spring.I18N('ui.chat.spectator')..')' or ''
				line = formatSystemMessage('ui.chat.leftthegametimeout', playername, gameFrame, lineColor, { textColor2 = isSpec and msgColor or lineColor })
				if spectator ~= '' then
					-- Append spectator suffix
					line = line .. spectator:gsub(getPlayerColorString(playername, gameFrame) .. playername, '')
				end
			elseif sfind(line,'Error', nil, true) then
				lineColor = '\255\255\133\133'
			elseif sfind(line,'Warning', nil, true) then
				lineColor = '\255\255\190\170'
			elseif sfind(line,'Failed to load', nil, true) then
				lineColor = '\255\200\200\255'
			elseif sfind(line,'Loaded ', nil, true) or sfind(ssub(line, 1, 25),'Loading ', nil, true) or sfind(ssub(line, 1, 25),'Loading: ', nil, true) then
				lineColor = '\255\200\255\200'
			elseif sfind(line,'Removed: ', nil, true) or sfind(line,'Removed widget: ', nil, true) then
				lineColor = '\255\255\230\200'
			end
		end

		line = colorConsoleStr .. lineColor .. line
	end

	if not bypassThisMessage then
		-- bot command or player ID message
		if (ssub(text,1,1) == '!' and ssub(text, 1,2) ~= '!!') or sfind(line, 'My player ID is', nil, true) then
			bypassThisMessage = true
		end

		if not bypassThisMessage and line ~= '' then
			if ignoredAccounts[name] then
				skipThisMessage = true
			end
			if not orgLineID then
				orgLineID = #orgLines+1
				orgLines[orgLineID] = {gameFrame, orgLine}
				-- if your name has been mentioned, pass it on
				if lineType > 0 and WG.logo and sfind(text, myName, nil, true) then
					WG.logo.mention()
				end
			end
			if lineType < 1 then
				addConsoleLine(gameFrame, lineType, line, orgLineID, reprocessID)
			else
				addChatLine(gameFrame, lineType, name, nameText, line, orgLineID, skipThisMessage, reprocessID)
			end
		end
	end
end

local function addLastUnitShareMessage()
	if not lastUnitShare then
		return
	end
	for _, unitShare in pairs(lastUnitShare) do
		local oldTeamName = teamNames[unitShare.oldTeamID]
		local newTeamName = teamNames[unitShare.newTeamID]
		if oldTeamName and newTeamName then
			local shareDescription = commonUnitName(unitShare.unitIDs)
			if #unitShare.unitIDs > 1 then
				shareDescription = #unitShare.unitIDs .. ' ' .. shareDescription
			end
			-- Player1 shared units to Player2: 5 Wind Turbine
			lastLineUnitShare = unitShare
			local line = oldTeamName .. ' shared units to ' .. newTeamName .. ': ' .. shareDescription
			spEcho(line)
		end
	end
	lastUnitShare = nil
end

function widget:UnitTaken(unitID, _, oldTeamID, newTeamID)
	local oldAllyTeamID = select(6, spGetTeamInfo(oldTeamID))
	local newAllyTeamID = select(6, spGetTeamInfo(newTeamID))

	local allyTeamShare = (oldAllyTeamID == myAllyTeamID and newAllyTeamID == myAllyTeamID)
	local selfShare = (oldTeamID == newTeamID) -- may happen if took other player

	local _, _, _, captureProgress, _ = Spring.GetUnitHealth(unitID)
	local captured = (captureProgress == 1)
	if (not mySpec and not allyTeamShare) or selfShare or captured then
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

drawGameTime = function(gameFrame)
	local minutes = floor((gameFrame / 30 / 60))
	local seconds = floor((gameFrame - ((minutes*60)*30)) / 30)
	if seconds == 0 then
		seconds = '00'
	elseif seconds < 10 then
		seconds = '0'..seconds
	end
	local offset = 0
	if minutes >= 100 then
		offset = (usedFontSize*0.2*widgetScale)
	end
	font3:Begin(useRenderToTexture)
	font3:SetOutlineColor(0,0,0,1)
	font3:Print('\255\200\200\200'..minutes..':'..seconds, maxTimeWidth+offset, usedFontSize*0.3, usedFontSize*0.82, "ro")
	font3:End()
end

drawConsoleLine = function(i)
	font:Begin(useRenderToTexture)
	font:SetOutlineColor(0,0,0,1)
	font:Print(consoleLines[i].text, 0, usedFontSize*0.3, usedConsoleFontSize, "o")
	font:End()
end

local function processConsoleLineGL(i)
	if consoleLines[i] and not consoleLines[i].lineDisplayList then
		glDeleteList(consoleLines[i].lineDisplayList)
		consoleLines[i].lineDisplayList = glCreateList(function()
			drawConsoleLine(i)
		end)
	end
	-- game time (for when viewing history)
	if consoleLines[i] and not consoleLines[i].timeDisplayList and consoleLines[i].gameFrame then
		glDeleteList(consoleLines[i].timeDisplayList)
		consoleLines[i].timeDisplayList = glCreateList(function()
			drawGameTime(consoleLines[i].gameFrame)
		end)
	end
end

drawChatLine = function(i)
	local fontHeightOffset = usedFontSize*0.3
	font:Begin(useRenderToTexture)
	if chatLines[i].gameFrame then
		if chatLines[i].lineType == LineTypes.Mapmark then
			font2:Begin(useRenderToTexture)
			if chatLines[i].textOutline then
				font2:SetOutlineColor(1,1,1,1)
			else
				font2:SetOutlineColor(0,0,0,1)
			end
			font2:Print(chatLines[i].playerNameText, maxPlayernameWidth, fontHeightOffset*1.06, usedFontSize*1.03, "or")
			font2:End()
			font2:SetOutlineColor(0,0,0,1)
			font2:Print(pointSeparator, maxPlayernameWidth+(lineSpaceWidth/2), fontHeightOffset*0.07, usedFontSize, "oc")
		elseif chatLines[i].lineType == LineTypes.System then -- sharing resources, taken player
			font3:Begin(useRenderToTexture)
			if chatLines[i].textOutline then
				font3:SetOutlineColor(1,1,1,1)
			else
				font3:SetOutlineColor(0,0,0,1)
			end
			font3:Print(chatLines[i].playerNameText, maxPlayernameWidth, fontHeightOffset*1.2, usedFontSize*0.9, "or")
			font3:End()
		else
			font2:Begin(useRenderToTexture)
			if chatLines[i].textOutline then
				font2:SetOutlineColor(1,1,1,1)
			else
				font2:SetOutlineColor(0,0,0,1)
			end
			font2:Print(chatLines[i].playerNameText, maxPlayernameWidth, fontHeightOffset*1.06, usedFontSize*1.03, "or")
			font2:End()
			font:SetOutlineColor(0,0,0,1)
			font:Print(chatSeparator, maxPlayernameWidth+(lineSpaceWidth/3.75), fontHeightOffset, usedFontSize, "oc")
		end
	end
	if chatLines[i].lineType == LineTypes.System then -- sharing resources, taken player
		font3:Begin(useRenderToTexture)
		font3:SetOutlineColor(0,0,0,1)
		font3:Print(chatLines[i].text, maxPlayernameWidth+lineSpaceWidth-(usedFontSize*0.5), fontHeightOffset*1.2, usedFontSize*0.88, "o")
		font3:End()
	else
		font:SetOutlineColor(0,0,0,1)
		font:Print(chatLines[i].text, maxPlayernameWidth+lineSpaceWidth, fontHeightOffset, usedFontSize, "o")
	end
	font:End()
end

local function processChatLineGL(i)
	if chatLines[i] and not chatLines[i].lineDisplayList then
		glDeleteList(chatLines[i].lineDisplayList)
		chatLines[i].lineDisplayList = glCreateList(function()
			drawChatLine(i)
		end)
	end
	-- game time (for when viewing history)
	if chatLines[i] and not chatLines[i].timeDisplayList and chatLines[i].gameFrame then
		glDeleteList(chatLines[i].timeDisplayList)
		chatLines[i].timeDisplayList = glCreateList(function()
			drawGameTime(chatLines[i].gameFrame)
		end)
	end
end

local uiSec = 0
function widget:Update(dt)
	addLastUnitShareMessage()

	cursorBlinkTimer = cursorBlinkTimer + dt
	if cursorBlinkTimer > cursorBlinkDuration then cursorBlinkTimer = 0 end

	uiSec = uiSec + dt
	if uiSec > 1 then
		uiSec = 0

		-- restore pregame reconnection messages
		--if prevOrgLines and Spring.GetGameRulesParam("GameID") then
		--	if prevGameID == Spring.GetGameRulesParam("GameID") then
		--		orgLines = prevOrgLines
		--	end
		--	prevOrgLines = nil
		--	prevGameID = nil
		--
		--	chatLines = {}
		--	consoleLines = {}
		--	for orgLineID, params in ipairs(orgLines) do
		--		processAddConsoleLine(params[1], params[2], orgLineID)
		--	end
		--	setCurrentChatLine(#chatLines)
		--end

		-- detect team colors changes
		local changeDetected = false
		local changedPlayers = {}
		local teams = Spring.GetTeamList()
		for i = 1, #teams do
			local r, g, b = spGetTeamColor(teams[i])
			if teamColorKeys[teams[i]] ~= r..'_'..g..'_'..b then
				teamColorKeys[teams[i]] = r..'_'..g..'_'..b
				changeDetected = true
				for _, playerID in ipairs(Spring.GetPlayerList(teams[i])) do
					local name = spGetPlayerInfo(playerID, false)
					name = ((WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(playerID)) or name
					changedPlayers[name] = true
				end
			end
		end
		if changeDetected and not useRenderToTexture then
			for i, _ in ipairs(chatLines) do
				if changedPlayers[chatLines[i].playerName] then
					chatLines[i].reprocess = true
					if chatLines[i].lineDisplayList then
						glDeleteList(chatLines[i].lineDisplayList)
						chatLines[i].lineDisplayList = nil
					end
				end
				updateDrawUi = true
			end
			-- reprocessing not implemented yet for consoleLines, maybe not really that needed anyway
			--for i, _ in ipairs(consoleLines) do
			--	if changedPlayers[consoleLines[i].playerName] then
			--		consoleLines[i].reprocess = true
			--		if chatLines[i].lineDisplayList then
			--			glDeleteList(consoleLines[i].lineDisplayList)
			--			consoleLines[i].lineDisplayList = nil
			--		end
			--	end
			--end
		end

		if WG.ignoredAccounts then
			-- unhide chats from players that used to be ignored
			for accountID_or_name, _ in pairs(ignoredAccounts) do
				if not WG.ignoredAccounts[accountID_or_name] then
					for i=1, #chatLines do
						if chatLines[i].playerName == accountID_or_name then
							chatLines[i].ignore = nil
							updateDrawUi = true
						end
					end
				end
			end
			-- hide chats from players that are now ignored
			for accountID_or_name, _ in pairs(WG.ignoredAccounts) do
				if not ignoredAccounts[accountID_or_name] then
					for i=1, #chatLines do
						if chatLines[i].playerName == accountID_or_name then
							chatLines[i].ignore = true
							updateDrawUi = true
						end
					end
				end
			end
			ignoredAccounts = table.copy(WG.ignoredAccounts)
		end

		-- add settings option commands
		if not addedOptionsList and WG['options'] and WG['options'].getOptionsList then
			local optionsList = WG['options'].getOptionsList()
			if optionsList and #optionsList > 0 then
				addedOptionsList = true
				for i, option in ipairs(optionsList) do
					autocompleteCommands[#autocompleteCommands+1] = 'option '..option
				end
			end
		end

		-- detect spectator filter change
		if hideSpecChat ~= (Spring.GetConfigInt('HideSpecChat', 0) == 1) or hideSpecChatPlayer ~= (Spring.GetConfigInt('HideSpecChatPlayer', 1) == 1) then
			hideSpecChat = (Spring.GetConfigInt('HideSpecChat', 0) == 1)
			hideSpecChatPlayer = (Spring.GetConfigInt('HideSpecChatPlayer', 1) == 1)
			for i=1, #chatLines do
				if chatLines[i].lineType == LineTypes.Spectator then
					if shouldHideSpecMessage() then
						chatLines[i].ignore = true
					else
						chatLines[i].ignore = WG.ignoredAccounts[chatLines[i].playerName] and true or nil
					end
				elseif chatLines[i].lineType == LineTypes.Mapmark then
					-- filter spectator map points
					local spectator = playernames[chatLines[i].playerName] and playernames[chatLines[i].playerName][2] or false
					if spectator then
						if shouldHideSpecMessage() then
							chatLines[i].ignore = true
						else
							chatLines[i].ignore = WG.ignoredAccounts[chatLines[i].playerName] and true or nil
						end
					end
				end
			end
		end
	end

	local x,y,_ = spGetMouseState()

	if topbarArea then
		scrollingPosY = floor(topbarArea[2] - elementMargin - backgroundPadding - backgroundPadding - (lineHeight*maxLinesScroll)) / vsy
	end

	local chatlogHeightDiff = historyMode and floor(vsy*(scrollingPosY-posY)) or 0
	if WG['topbar'] and WG['topbar'].showingQuit() then
		historyMode = false
		setCurrentChatLine(#chatLines)
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
			setCurrentChatLine(#chatLines)
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

drawChatInputCursor = function()
	if textCursorRect then
		local a = 1 - (cursorBlinkTimer * (1 / cursorBlinkDuration)) + 0.15
		glColor(0.7,0.7,0.7,a)
		gl.Rect(textCursorRect[1], textCursorRect[2], textCursorRect[3], textCursorRect[4])
		glColor(1,1,1,1)
	end
end

drawChatInput = function()
	if showTextInput then
		if topbarArea then
			scrollingPosY = floor(topbarArea[2] - elementMargin - backgroundPadding - backgroundPadding - (lineHeight*maxLinesScroll)) / vsy
		end
		updateTextInputDlist = false
		textInputDlist = glDeleteList(textInputDlist)
		textInputDlist = glCreateList(function()
			local chatlogHeightDiff = historyMode and floor(vsy*(scrollingPosY-posY)) or 0
			local inputFontSize = floor(usedFontSize * 1.03)
			local inputHeight = floor(inputFontSize * 2.3)
			local leftOffset = floor(lineHeight*0.7)
			local distance =  (historyMode and inputHeight + elementMargin + elementMargin or elementMargin)
			local isCmd = ssub(inputText, 1, 1) == '/'
			local usedFont = isCmd and font3 or font
			local modeText = I18N.everyone
			if isCmd then
				modeText = I18N.cmd
			elseif inputMode == 'a:' then
				modeText = I18N.allies
			elseif inputMode == 's:' then
				modeText = I18N.spectators
			end
			local modeTextPosX = floor(activationArea[1]+elementPadding+elementPadding+leftOffset)
			local textPosX = floor(modeTextPosX + (usedFont:GetTextWidth(modeText) * inputFontSize) + leftOffset + inputFontSize)
			local textCursorWidth = 1 + mathFloor(inputFontSize / 14)
			if inputTextInsertActive then
				textCursorWidth = mathFloor(textCursorWidth * 5)
			end
			local textCursorPos = floor(usedFont:GetTextWidth(utf8.sub(inputText, 1, inputTextPosition)) * inputFontSize)

			-- background
			local r,g,b,a
			local inputAlpha = mathMin(0.36, ui_opacity*0.66)
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
			usedFont:Begin(useRenderToTexture)
			usedFont:SetOutlineColor(0.22, 0.22, 0.22, 1)
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

			-- text selection highlight
			if inputSelectionStart and inputSelectionStart ~= inputTextPosition then
				local selStart = math.min(inputSelectionStart, inputTextPosition)
				local selEnd = math.max(inputSelectionStart, inputTextPosition)
				local selStartPos = floor(usedFont:GetTextWidth(utf8.sub(inputText, 1, selStart)) * inputFontSize)
				local selEndPos = floor(usedFont:GetTextWidth(utf8.sub(inputText, 1, selEnd)) * inputFontSize)
				glColor(0.55, 0.55, 0.55, 0.5)
				gl.Rect(textPosX + selStartPos, activationArea[2]+chatlogHeightDiff-distance-(inputHeight*0.5)-(inputFontSize*0.6), textPosX + selEndPos, activationArea[2]+chatlogHeightDiff-distance-(inputHeight*0.5)+(inputFontSize*0.64))
				glColor(1,1,1,1)
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
				local height = (autocLineHeight * mathMin(allowMultiAutocompleteMax, #autocompleteWords-1) + leftOffset) + (#autocompleteWords > allowMultiAutocompleteMax+1 and autocLineHeight or 0)
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
	refreshUi = true
end

drawUi = function()
	if not historyMode then

		-- draw background
		if backgroundOpacity > 0 and displayedChatLines > 0 then
			glColor(1,1,1,0.1*backgroundOpacity)
			local borderSize = 1
			RectRound(activationArea[1]-borderSize, activationArea[2]-borderSize, activationArea[3]+borderSize, activationArea[2]+borderSize+((displayedChatLines+1)*lineHeight)+(displayedChatLines==maxLines and 0 or elementPadding), elementCorner*1.2)

			glColor(0,0,0,backgroundOpacity)
			RectRound(activationArea[1], activationArea[2], activationArea[3], activationArea[2]+((displayedChatLines+1)*lineHeight)+(displayedChatLines==maxLines and 0 or elementPadding), elementCorner)
			if hovering then --and Spring.GetGameFrame() < 30*60*7 then
				font:Begin(useRenderToTexture)
				font:SetTextColor(0.1,0.1,0.1,0.66)
				font:Print(I18N.shortcut, activationArea[3]-elementPadding-elementPadding, activationArea[2]+elementPadding+elementPadding, usedConsoleFontSize, "r")
				font:End()
			end
		end

		-- draw console lines
		if consoleLines[1] then
			glPushMatrix()
			glTranslate((vsx * posX) + backgroundPadding, (consolePosY*vsy)+(usedConsoleFontSize*0.24), 0)
			local checkedLines = 0
			local i = #consoleLines
			while i > 0 do
				if clock() - consoleLines[i].startTime < lineTTL then
					if useRenderToTexture then
						drawConsoleLine(i)
					else
						processConsoleLineGL(i)
						glCallList(consoleLines[i].lineDisplayList)
					end
				else
					break
				end
				checkedLines = checkedLines + 1
				if checkedLines >= maxConsoleLines then
					break
				end
				glTranslate(0, consoleLineHeight, 0)
				i = i - 1
			end
			if i - 1 > consoleLineCleanupTarget*1.15 then
				consoleLines = cleanupLineTable(consoleLines, consoleLineCleanupTarget)
			end
			glPopMatrix()

			if #orgLines > orgLineCleanupTarget*1.15 then
				orgLines = cleanupLineTable(orgLines, orgLineCleanupTarget)
			end
		end
	end

	-- draw chat lines or chat/console history ui panel
	if historyMode or chatLines[currentChatLine] then
		if #chatLines == 0 and historyMode == 'chat' then
			font:Begin(useRenderToTexture)
			font:SetTextColor(0.35,0.35,0.35,0.66)
			font:Print(I18N.nohistory, activationArea[1]+(activationArea[3]-activationArea[1])/2, activationArea[2]+elementPadding+elementPadding, usedConsoleFontSize*1.1, "c")
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
		while i > 0 do
			if (historyMode and historyMode == 'console') or (chatLines[i] and not chatLines[i].ignore) then
				if historyMode or clock() - chatLines[i].startTime < lineTTL then
					if historyMode == 'console' then
						if not useRenderToTexture then
							processConsoleLineGL(i)
						end
					else
						if chatLines[i].reprocess then
							chatLines[i].reprocess = nil
							local orgLineID = chatLines[i].orgLineID
							if orgLines[orgLineID] then
								local firstWordrappedChatLine = i
								for c=1, 6 do
									if not chatLines[firstWordrappedChatLine-c] or chatLines[firstWordrappedChatLine-c].orgLineID ~= orgLineID then
										break
									else
										firstWordrappedChatLine = firstWordrappedChatLine - c
									end
								end
								processAddConsoleLine(orgLines[orgLineID][1], orgLines[orgLineID][2], orgLineID, firstWordrappedChatLine)
							end
						end
						if not useRenderToTexture then
							processChatLineGL(i)
						end
					end
					if historyMode then
						if historyMode == 'console' then
							if consoleLines[i] then
								if useRenderToTexture and consoleLines[i].gameFrame then
									drawGameTime(consoleLines[i].gameFrame)
								elseif consoleLines[i].timeDisplayList then
									glCallList(consoleLines[i].timeDisplayList)
								end
							end
						else
							if historyMode and chatLines[i] then
								if useRenderToTexture and chatLines[i].gameFrame then
									drawGameTime(chatLines[i].gameFrame)
								elseif chatLines[i].timeDisplayList then
									glCallList(chatLines[i].timeDisplayList)
								end
							end
						end
						if historyMode then
							glTranslate(width, 0, 0)
						end
					end
					if historyMode == 'console' then
						if consoleLines[i] then
							if useRenderToTexture then
								drawConsoleLine(i)
							elseif consoleLines[i].lineDisplayList then
								glCallList(consoleLines[i].lineDisplayList)
							end
						end
					else
						if chatLines[i] then
							if useRenderToTexture then
								drawChatLine(i)
							elseif chatLines[i].lineDisplayList then
								glCallList(chatLines[i].lineDisplayList)
							end
						end
					end
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
				glTranslate(0, lineHeight, 0)
			end
			i = i - 1
		end
		glPopMatrix()

		-- show new chat when in historyMode mode
		local lastUnignoredChatLineID = #chatLines
		local i = #chatLines
		while i > 0 do
			if not chatLines[i].ignore then
				lastUnignoredChatLineID = i
				break
			end
			 i = i - 1
		end
		if chatLines[lastUnignoredChatLineID] and not chatLines[lastUnignoredChatLineID].ignore then
			if historyMode and currentChatLine < lastUnignoredChatLineID and clock() - chatLines[lastUnignoredChatLineID].startTime < lineTTL then
				glPushMatrix()
				glTranslate(vsx * posX, vsy * ((historyMode and scrollingPosY or posY)-0.02)-backgroundPadding, 0)
				if useRenderToTexture then
					drawChatLine(lastUnignoredChatLineID)
				else
					processChatLineGL(lastUnignoredChatLineID)
					glCallList(chatLines[lastUnignoredChatLineID].lineDisplayList)
				end
				glPopMatrix()
			end
		end
	end
end

drawTextInput = function()
	if handleTextInput then
		if showTextInput and updateTextInputDlist then
			drawChatInput()
		end
		if showTextInput and textInputDlist then
			glCallList(textInputDlist)
			drawChatInputCursor()
			-- button hover
			local x,y,b = spGetMouseState()
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
end

function widget:DrawScreen()
	if chobbyInterface then return end
	if not chatLines[1] and not consoleLines[1] then return end

	local _, ctrl, _, _ = Spring.GetModKeyState()
	local x,y,b = spGetMouseState()
	local chatlogHeightDiff = historyMode and floor(vsy*(scrollingPosY-posY)) or 0
	if hovering and WG['guishader'] then
		WG['guishader'].RemoveRect('chat')
	end

	-- draw chat input
	drawTextInput()

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

			local totalUnignoredChatLines = 0
			for i=1, #chatLines do
				if not chatLines[i].ignore then
					totalUnignoredChatLines = totalUnignoredChatLines + 1
				end
			end

			local scrollbarMargin = floor(16 * widgetScale)
			local scrollbarWidth = floor(11 * widgetScale)
			UiScroller(
				floor(activationArea[3]-scrollbarMargin-scrollbarWidth),
				floor(activationArea[2]+chatlogHeightDiff+scrollbarMargin),
				floor(activationArea[3]-scrollbarMargin),
				floor(activationArea[4]-scrollbarMargin),
				historyMode == 'console' and #consoleLines*lineHeight or totalUnignoredChatLines*lineHeight,
				historyMode == 'console' and (currentConsoleLine-maxLinesScroll)*lineHeight or (currentChatLine-maxLinesScroll)*lineHeight
			)
		end
	else
		if not showHistoryWhenChatInput or not showTextInput then
			hovering = false
			historyMode = false
			setCurrentChatLine(#chatLines)
		end
	end

	if currentChatLine ~= prevCurrentChatLine or currentConsoleLine ~= prevCurrentConsoleLine or historyMode ~= prevHistoryMode then -- or showTextInput ~= prevShowTextInput or displayedChatLines ~= prevDisplayedChatLines
		updateDrawUi = true
	end

	local ctrlHover = enableShortcutClick and ctrl and math_isInRect(x, y, activationArea[1],activationArea[2]+chatlogHeightDiff,activationArea[3],activationArea[4])
	if ctrlHover or (historyMode and historyMode == 'chat') then
		--updateDrawUi = true

		glPushMatrix()
		local translatedX = (vsx * posX) + backgroundPadding
		local translatedY = vsy * (historyMode and scrollingPosY or posY) + backgroundPadding
		glTranslate(translatedX, translatedY, 0)
		local i = currentChatLine
		local usedMaxLines = maxLines
		if historyMode then
			usedMaxLines = maxLinesScroll
		end
		local width = floor(maxTimeWidth+(lineHeight*0.75))
		local checkedLines = 0
		while i > 0 do
			if chatLines[i] and not chatLines[i].ignore then
				if historyMode or clock() - chatLines[i].startTime < lineTTL or ctrlHover then
					local isClickableLine = chatLines[i].coords or chatLines[i].selectUnits
					if isClickableLine then
						local lineArea = {
							translatedX + width,
							translatedY + (lineHeight*checkedLines),
							floor(translatedX + width + (activationArea[3]-activationArea[1])-backgroundPadding-backgroundPadding-maxTimeWidth - (38 * widgetScale)),
							translatedY + (lineHeight*checkedLines) + lineHeight
						}
						if math_isInRect(x, y, lineArea[1], lineArea[2], lineArea[3], lineArea[4]) then
							UiSelectHighlight(lineArea[1]-translatedX, lineArea[2]-translatedY-(lineHeight*checkedLines), lineArea[3]-translatedX, lineArea[4]-translatedY-(lineHeight*checkedLines), nil, historyMode and (b and 0.4 or 0.3) or (b and 0.52 or 0.42))
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
				else
					break
				end
				checkedLines = checkedLines + 1
				if checkedLines >= usedMaxLines then
					break
				end
				glTranslate(0, lineHeight, 0)
			end
			i = i - 1
		end
		glPopMatrix()
	end

	prevCurrentConsoleLine = currentConsoleLine
	prevCurrentChatLine = currentChatLine
	prevHistoryMode = historyMode
	--prevShowTextInput = showTextInput
	--prevDisplayedChatLines = displayedChatLines

	if useRenderToTexture then
		if refreshUi then
			refreshUi = false
			updateDrawUi = true
			if uiTex then
				gl.DeleteTexture(uiTex)
				uiTex = nil
			end
			rttArea = {consoleActivationArea[1], activationArea[2]+floor(vsy*(scrollingPosY-posY)), consoleActivationArea[3], consoleActivationArea[4]}
			local texWidth = mathFloor(rttArea[3]-rttArea[1])
			local texHeight = mathFloor(rttArea[4]-rttArea[2])
			if texWidth > 0 and texHeight > 0 then
				uiTex = gl.CreateTexture(texWidth, texHeight, {
					target = GL.TEXTURE_2D,
					format = GL.ALPHA,
					fbo = true,
				})
			end
		end
		if uiTex then
			if lastDrawUiUpdate+2 < clock() then	-- this is to make sure stuff times out/clears respecting lineTTL
				updateDrawUi = true
			end
			if updateDrawUi ~= nil then
				lastDrawUiUpdate = clock()
				gl.R2tHelper.RenderToTexture(uiTex,
					function()
						gl.Translate(-1, -1, 0)
						gl.Scale(2 / ((rttArea[3]-rttArea[1])), 2 / ((rttArea[4]-rttArea[2])),	0)
						gl.Translate(-rttArea[1], -rttArea[2], 0)
						drawUi()
					end,
					useRenderToTexture
				)

				-- drawUi() needs to run twice to fix some alignment issues so lets scedule one more update as workaround for now
				if updateDrawUi == false then
					updateDrawUi = nil
				elseif updateDrawUi then
					updateDrawUi = false	-- update once more after this
				end
			end

			gl.R2tHelper.BlendTexRect(uiTex, rttArea[1], rttArea[2], rttArea[3], rttArea[4], useRenderToTexture)
		end
	else
		drawUi()
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

local loadedAutocompleteCommands = false
local function autocomplete(text, fresh)
	if not loadedAutocompleteCommands then
		loadedAutocompleteCommands = true
		for textAction, v in pairs(widgetHandler.actionHandler.textActions) do
			if type(textAction) == 'string' then
				local found = false
				for k, cmd in ipairs(autocompleteCommands) do
					if cmd == textAction then
						found = true
						break
					end
				end
				if not found then
					--spEcho('"'..textAction..'"')
					autocompleteCommands[#autocompleteCommands+1] = textAction
				end
			end
		end
	end

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
		-- If there's a selection, delete it first
		if inputSelectionStart and inputSelectionStart ~= inputTextPosition then
			local selStart = math.min(inputSelectionStart, inputTextPosition)
			local selEnd = math.max(inputSelectionStart, inputTextPosition)
			inputText = utf8.sub(inputText, 1, selStart) .. utf8.sub(inputText, selEnd + 1)
			inputTextPosition = selStart
			inputSelectionStart = nil
		end
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
				elseif alt and not mySpec then
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
						local badWord = findBadWords(inputText)
						if badWord ~= nil and inputText ~= lastMessage then
							addChatLine(Spring.GetGameFrame(), LineTypes.System, "Moderation", "\255\255\000\000" .. Spring.I18N('ui.chat.moderation.prefix'),
								Spring.I18N('ui.chat.moderation.blocked', { badWord = badWord }))
						else
							Spring.SendCommands("say "..inputMode..inputText)
						end
						lastMessage = inputText
					end
					-- Remove any duplicate of this message from earlier in history (move to front)
					for i = #inputHistory - 1, 1, -1 do
						if inputHistory[i] == inputText then
							table.remove(inputHistory, i)
							break  -- Only remove one duplicate (the most recent one)
						end
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
			widgetHandler.textOwner = self	-- non handler = true: widgetHandler:OwnText()
			if not inputHistory[inputHistoryCurrent] or inputHistory[inputHistoryCurrent] ~= '' then
				if inputHistoryCurrent == 1 or inputHistory[inputHistoryCurrent] ~= inputHistory[inputHistoryCurrent-1] then
					inputHistoryCurrent = inputHistoryCurrent + 1
				end
				inputHistory[inputHistoryCurrent] = ''
			end
			if ctrl then
				inputMode = ''
			elseif alt then
				inputMode = mySpec and 's:' or 'a:'
			elseif shift then
				inputMode = 's:'
			elseif inputMode == nil then
				-- First time opening chat - default to allies/spectators
				inputMode = mySpec and 's:' or 'a:'
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
		-- Delete selection if any
		if inputSelectionStart and inputSelectionStart ~= inputTextPosition then
			local selStart = math.min(inputSelectionStart, inputTextPosition)
			local selEnd = math.max(inputSelectionStart, inputTextPosition)
			inputText = utf8.sub(inputText, 1, selStart) .. utf8.sub(inputText, selEnd + 1)
			inputTextPosition = selStart
			inputSelectionStart = nil
		end
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

	elseif ctrl and key == 99 then -- CTRL + C
		if inputSelectionStart and inputSelectionStart ~= inputTextPosition then
			local selStart = math.min(inputSelectionStart, inputTextPosition)
			local selEnd = math.max(inputSelectionStart, inputTextPosition)
			local selectedText = utf8.sub(inputText, selStart + 1, selEnd)
			Spring.SetClipboard(selectedText)
		end

	elseif ctrl and key == 120 then -- CTRL + X
		if inputSelectionStart and inputSelectionStart ~= inputTextPosition then
			local selStart = math.min(inputSelectionStart, inputTextPosition)
			local selEnd = math.max(inputSelectionStart, inputTextPosition)
			local selectedText = utf8.sub(inputText, selStart + 1, selEnd)
			Spring.SetClipboard(selectedText)
			inputText = utf8.sub(inputText, 1, selStart) .. utf8.sub(inputText, selEnd + 1)
			inputTextPosition = selStart
			inputSelectionStart = nil
			inputHistory[#inputHistory] = inputText
			cursorBlinkTimer = 0
			autocomplete(inputText, true)
		end

	elseif ctrl and key == 97 then -- CTRL + A
		inputSelectionStart = 0
		inputTextPosition = utf8.len(inputText)
		cursorBlinkTimer = 0

	elseif ctrl and key == 276 then -- CTRL + LEFT (word jump)
		if shift then
			if not inputSelectionStart then
				inputSelectionStart = inputTextPosition
			end
		else
			inputSelectionStart = nil
		end
		-- Move to previous word boundary
		local pos = inputTextPosition
		-- Skip any spaces before current position
		while pos > 0 and utf8.sub(inputText, pos, pos):match("%s") do
			pos = pos - 1
		end
		-- Skip the word
		while pos > 0 and not utf8.sub(inputText, pos, pos):match("%s") do
			pos = pos - 1
		end
		inputTextPosition = pos
		cursorBlinkTimer = 0

	elseif ctrl and key == 275 then -- CTRL + RIGHT (word jump)
		if shift then
			if not inputSelectionStart then
				inputSelectionStart = inputTextPosition
			end
		else
			inputSelectionStart = nil
		end
		-- Move to next word boundary
		local textLen = utf8.len(inputText)
		local pos = inputTextPosition
		-- Skip the current word
		while pos < textLen and not utf8.sub(inputText, pos + 1, pos + 1):match("%s") do
			pos = pos + 1
		end
		-- Skip any spaces after the word
		while pos < textLen and utf8.sub(inputText, pos + 1, pos + 1):match("%s") do
			pos = pos + 1
		end
		inputTextPosition = pos
		cursorBlinkTimer = 0

	elseif not alt and not ctrl then
		if key == 27 then -- ESC
			cancelChatInput()
		elseif key == 8 then -- BACKSPACE
			if inputSelectionStart and inputSelectionStart ~= inputTextPosition then
				-- Delete selection
				local selStart = math.min(inputSelectionStart, inputTextPosition)
				local selEnd = math.max(inputSelectionStart, inputTextPosition)
				inputText = utf8.sub(inputText, 1, selStart) .. utf8.sub(inputText, selEnd + 1)
				inputTextPosition = selStart
				inputSelectionStart = nil
				inputHistory[#inputHistory] = inputText
				prevAutocompleteLetters = nil
			elseif inputTextPosition > 0 then
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
			if inputSelectionStart and inputSelectionStart ~= inputTextPosition then
				-- Delete selection
				local selStart = math.min(inputSelectionStart, inputTextPosition)
				local selEnd = math.max(inputSelectionStart, inputTextPosition)
				inputText = utf8.sub(inputText, 1, selStart) .. utf8.sub(inputText, selEnd + 1)
				inputTextPosition = selStart
				inputSelectionStart = nil
				inputHistory[#inputHistory] = inputText
			elseif inputTextPosition < utf8.len(inputText) then
				inputText = utf8.sub(inputText, 1, inputTextPosition) .. utf8.sub(inputText, inputTextPosition+2)
				inputHistory[#inputHistory] = inputText
			end
			cursorBlinkTimer = 0
			autocomplete(inputText, true)
		elseif key == 277 then -- INSERT
			inputTextInsertActive = not inputTextInsertActive
		elseif key == 276 then -- LEFT
			if shift then
				-- Start or extend selection
				if not inputSelectionStart then
					inputSelectionStart = inputTextPosition
				end
			else
				-- Clear selection
				inputSelectionStart = nil
			end
			inputTextPosition = inputTextPosition - 1
			if inputTextPosition < 0 then
				inputTextPosition = 0
			end
			cursorBlinkTimer = 0
		elseif key == 275 then -- RIGHT
			if shift then
				-- Start or extend selection
				if not inputSelectionStart then
					inputSelectionStart = inputTextPosition
				end
			else
				-- Clear selection
				inputSelectionStart = nil
			end
			inputTextPosition = inputTextPosition + 1
			if inputTextPosition > utf8.len(inputText) then
				inputTextPosition = utf8.len(inputText)
			end
			cursorBlinkTimer = 0
		elseif key == 278 or key == 280 then -- HOME / PGUP
			if shift then
				if not inputSelectionStart then
					inputSelectionStart = inputTextPosition
				end
			else
				inputSelectionStart = nil
			end
			inputTextPosition = 0
			cursorBlinkTimer = 0
		elseif key == 279 or key == 281 then -- END / PGDN
			if shift then
				if not inputSelectionStart then
					inputSelectionStart = inputTextPosition
				end
			else
				inputSelectionStart = nil
			end
			inputTextPosition = utf8.len(inputText)
			cursorBlinkTimer = 0
		elseif key == 273 then -- UP
			inputSelectionStart = nil
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
			inputSelectionStart = nil
			inputHistoryCurrent = inputHistoryCurrent + 1
			if inputHistoryCurrent >= #inputHistory then
				inputHistoryCurrent = #inputHistory
			end
			inputText = inputHistory[inputHistoryCurrent]
			inputTextPosition = utf8.len(inputText)
			cursorBlinkTimer = 0
			autocomplete(inputText, true)
		elseif key == 9 then -- TAB
			inputSelectionStart = nil
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
			inputMode = mySpec and '' or 'a:'
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
		if historyMode == 'chat' then
			local scrollCount = 0
			local scrollAmount = (shift and maxLinesScroll or (ctrl and 3 or 1))
			local i = currentChatLine
			while i > 0 and i <= #chatLines do
				i = i + (up and -1 or 1)
				if chatLines[i] and not chatLines[i].ignore then
					currentChatLine = i
					scrollCount = scrollCount + 1
					if scrollCount == scrollAmount then
						break
					end
				end
			end
			if currentChatLine < maxLinesScroll then
				currentChatLine = maxLinesScroll
			end
		else
			if up then
				currentConsoleLine = currentConsoleLine - (shift and maxLinesScroll or (ctrl and 3 or 1))
				if currentConsoleLine < maxLinesScroll then
					currentConsoleLine = maxLinesScroll
					if currentConsoleLine > #consoleLines then
						currentConsoleLine = #consoleLines
					end
				end
			else
				currentConsoleLine = currentConsoleLine + (shift and maxLinesScroll or (ctrl and 3 or 1))
				if currentConsoleLine > #consoleLines then
					currentConsoleLine = #consoleLines
				end
				currentChatLine = currentChatLine + (shift and maxLinesScroll or (ctrl and 3 or 1))
				if currentChatLine > #chatLines then
					currentChatLine = #chatLines
				end
			end
			--if up then
			--	currentConsoleLine = currentConsoleLine - (shift and maxLinesScroll or (ctrl and 3 or 1))
			--else
			--	currentConsoleLine = currentConsoleLine + (shift and maxLinesScroll or (ctrl and 3 or 1))
			--end
			--if currentConsoleLine < maxLinesScroll then
			--	currentConsoleLine = maxLinesScroll
			--end
			--if currentConsoleLine > #consoleLines then
			--	currentConsoleLine = #consoleLines
			--end
		end
		return true
	else
		return false
	end
end

function widget:WorldTooltip(ttType,data1,data2,data3)
	local x,y,_ = spGetMouseState()
	local chatlogHeightDiff = historyMode and floor(vsy*(scrollingPosY-posY)) or 0
	if #chatLines > 0 and math_isInRect(x, y, activationArea[1],activationArea[2]+chatlogHeightDiff,activationArea[3],activationArea[4]) then
		return I18N.scroll
	end
end

function widget:MapDrawCmd(playerID, cmdType, x, y, z, a, b, c)
	if cmdType == 'point' then
		lastMapmarkCoords = {x,y,z}
	end
end

function widget:AddConsoleLine(lines, priority)
	if priority and priority == L_DEPRECATED and not isDevSingle then return end
	lines = lines:match('^%[f=[0-9]+%] (.*)$') or lines
	for line in lines:gmatch("[^\n]+") do
		processAddConsoleLine(spGetGameFrame(), line)
	end
end

function widget:ViewResize()
	vsx,vsy = Spring.GetViewGeometry()

	widgetScale = vsy * 0.00075 * ui_scale

	UiElement = WG.FlowUI.Draw.Element
	UiScroller = WG.FlowUI.Draw.Scroller
	UiSelectHighlight = WG.FlowUI.Draw.SelectHighlight
	elementCorner = WG.FlowUI.elementCorner
	elementPadding = WG.FlowUI.elementPadding
	elementMargin = WG.FlowUI.elementMargin
	RectRound = WG.FlowUI.Draw.RectRound
	charSize = 21 * math.clamp(1+((1-(vsy/1200))*0.5), 1, 1.2)	-- increase for small resolutions
	usedFontSize = charSize*widgetScale*fontsizeMult
	usedConsoleFontSize = usedFontSize*consoleFontSizeMult

	font = WG['fonts'].getFont()
    font2 = WG['fonts'].getFont(2)
	font3 = WG['fonts'].getFont(3)

	--local outlineMult = math.clamp(1+((1-(vsy/1400))*0.9), 1, 1.5)
	--font = WG['fonts'].getFont(1, 1, 0.22 * outlineMult, 2+(outlineMult*0.25))
    --font2 = WG['fonts'].getFont(2, 1, 0.22 * outlineMult, 2+(outlineMult*0.25))

	-- get longest player name and calc its width
	if not font or not longestPlayername then
		return
	end
	local namePrefix = '(s)'
	local namePrefixWidth = font:GetTextWidth(namePrefix)
	maxPlayernameWidth = (namePrefixWidth + font:GetTextWidth(longestPlayername)) * usedFontSize
	for _, playerID in ipairs(playersList) do
		local name = spGetPlayerInfo(playerID, false)
		name = ((WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(playerID)) or name
		if name ~= longestPlayername then
			local nameWidth = (namePrefixWidth + font:GetTextWidth(name)) * usedFontSize
			if nameWidth > maxPlayernameWidth then
				longestPlayername = name
				maxPlayernameWidth = nameWidth
			end
		end
	end
	maxTimeWidth = font3:GetTextWidth('00:00') * usedFontSize
	lineSpaceWidth = 24*widgetScale
	lineHeight = floor(usedFontSize*lineHeightMult)
	consoleLineHeight = mathFloor(usedConsoleFontSize*lineHeightMult)
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

	clearDisplayLists()
	refreshUi = true
end

function widget:PlayerChanged(playerID)
	mySpec = spGetSpectatingState()
	myTeamID = spGetMyTeamID()
	myAllyTeamID = Spring.GetMyAllyTeamID()
	if mySpec and inputMode == 'a:' then
		inputMode = 's:'
	end
	local name, _, isSpec = spGetPlayerInfo(playerID, false)
	--local historyName = ((WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(playerID)) or name
	if not playernames[name] then
		widget:PlayerAdded(playerID)
	else
		if isSpec ~= playernames[name].isSpec then
			playernames[name][2] = isSpec
			if isSpec then
				playernames[name][8] = Spring.GetGameFrame()	-- log frame of death
			end
		end
	end
end

function widget:PlayerAdded(playerID)
	local name, _, isSpec, teamID, allyTeamID = spGetPlayerInfo(playerID, false)
	local historyName = ((WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(playerID)) or name
	playernames[name] = { allyTeamID, isSpec, teamID, playerID, not isSpec and { spGetTeamColor(teamID) }, ColorIsDark(spGetTeamColor(teamID)), historyName }
	autocompletePlayernames[#autocompletePlayernames+1] = name
	if historyName ~= name then
		autocompletePlayernames[#autocompletePlayernames+1] = historyName
	end
end

local function clearconsoleCmd(_, _, params)
	orgLines = {}
	chatLines = {}
	consoleLines = {}
	currentChatLine = 0
	currentConsoleLine = 0

	clearDisplayLists()
	updateDrawUi = true
end

local function hidespecchatCmd(_, _, params)
	if params[1] then
		hideSpecChat = (params[1] == '1')
	else
		hideSpecChat = not hideSpecChat
	end
	Spring.SetConfigInt('HideSpecChat', hideSpecChat and 1 or 0)
	if hideSpecChat then
		spEcho("Hiding all spectator chat")
	else
		spEcho("Showing all spectator chat again")
	end
end

local function hidespecchatplayerCmd(_, _, params)
	if params[1] then
		hideSpecChatPlayer = (params[1] == '1')
	else
		hideSpecChatPlayer = not hideSpecChatPlayer
	end
	Spring.SetConfigInt('HideSpecChatPlayer', hideSpecChatPlayer and 1 or 0)
	if hideSpecChat then
		spEcho("Hiding all spectator chat when player")
	else
		spEcho("Showing all spectator chat when player again")
	end
end

local function preventhistorymodeCmd(_, _, params)
	showHistoryWhenCtrlShift = not showHistoryWhenCtrlShift
	enableShortcutClick = not enableShortcutClick
	if not showHistoryWhenCtrlShift then
		spEcho("Preventing toggling historymode via CTRL+SHIFT")
	else
		spEcho("Enabled toggling historymode via CTRL+SHIFT")
	end
end


function widget:Initialize()
	Spring.SDLStartTextInput()	-- because: touch chobby's text edit field once and widget:TextInput is gone for the game, so we make sure its started!

	-- Ensure ColorString and ColorIsDark are initialized
	if not ColorString and Spring.Utilities and Spring.Utilities.Color then
		ColorString = Spring.Utilities.Color.ToString
		ColorIsDark = Spring.Utilities.Color.ColorIsDark
	end

	if WG.ignoredAccounts then
		ignoredAccounts = table.copy(WG.ignoredAccounts)
	end

	-- Initialize team data
	local gaiaTeamID = Spring.GetGaiaTeamID()
	local teams = Spring.GetTeamList()
	for i = 1, #teams do
		local teamID = teams[i]
		local r, g, b = spGetTeamColor(teamID)
		local _, playerID, _, isAiTeam, _, allyTeamID = spGetTeamInfo(teamID, false)
		teamColorKeys[teamID] = r..'_'..g..'_'..b
		local aiName
		if isAiTeam then
			aiName = getAIName(teamID)
			playernames[aiName] = { allyTeamID, false, teamID, playerID, { r, g, b }, ColorIsDark(r, g, b), aiName }
		end
		if teamID == gaiaTeamID then
			teamNames[teamID] = "Gaia"
		else
			if isAiTeam then
				teamNames[teamID] = aiName
			else
				local name, _, spec, _ = spGetPlayerInfo(playerID, false)
				name = ((WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(playerID)) or name
				if not spec then
					teamNames[teamID] = name
				end
			end
		end
	end

	widget:ViewResize()
	widget:PlayerChanged(Spring.GetMyPlayerID())

	Spring.SendCommands("console 0")

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
	WG['chat'].addChatLine = function(gameFrame, lineType, name, nameText, text, orgLineID, ignore, chatLineID)
		addChatLine(gameFrame, lineType, name, nameText, text, orgLineID, ignore, chatLineID, true)
	end
	WG['chat'].addChatProcessor = function(id, func)
		if type(func) == 'function' then
			chatProcessors[id] = func
		end
	end
	WG['chat'].removeChatProcessor = function(id)
		chatProcessors[id] = nil
	end

	for orgLineID, params in ipairs(orgLines) do
		processAddConsoleLine(params[1], params[2], orgLineID)
	end

	widgetHandler.actionHandler:AddAction(self, "clearconsole", clearconsoleCmd, nil, 't')
	widgetHandler.actionHandler:AddAction(self, "hidespecchat", hidespecchatCmd, nil, 't')
	widgetHandler.actionHandler:AddAction(self, "hidespecchatplayer", hidespecchatplayerCmd, nil, 't')
	widgetHandler.actionHandler:AddAction(self, "preventhistorymode", preventhistorymodeCmd, nil, 't')

	for _, playerID in ipairs(playersList) do
		local name, _, isSpec, teamID, allyTeamID = spGetPlayerInfo(playerID, false)
		local historyName = ((WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(playerID)) or name
		playernames[name] = { allyTeamID, isSpec, teamID, playerID, not isSpec and { spGetTeamColor(teamID) }, ColorIsDark(spGetTeamColor(teamID)), historyName }
		autocompletePlayernames[#autocompletePlayernames+1] = name
		if historyName ~= name then
			autocompletePlayernames[#autocompletePlayernames+1] = historyName
		end
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
	if uiTex then
		gl.DeleteTexture(uiTex)
		uiTex = nil
	end

	widgetHandler.actionHandler:RemoveAction(self, "clearconsole")
	widgetHandler.actionHandler:RemoveAction(self, "hidespecchat")
	widgetHandler.actionHandler:RemoveAction(self, "hidespecchatplayer")
	widgetHandler.actionHandler:RemoveAction(self, "preventhistorymode")
end

function widget:GameOver()
	gameOver = true
end

function widget:GetConfigData(data)
	local inputHistoryLimited = {}
	for k,v in ipairs(inputHistory) do
		if k >= (#inputHistory - 50) then
			inputHistoryLimited[#inputHistoryLimited+1] = v
		end
	end

	local maxOrgLines = orgLineCleanupTarget
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
		playernames = playernames,
		version = 1,
	}
end

function widget:SetConfigData(data)
	if data.orgLines ~= nil then
		if Spring.GetGameFrame() > 0 or (data.gameID and data.gameID == (Game.gameID and Game.gameID or Spring.GetGameRulesParam("GameID"))) then
			if data.playernames then
				playernames = data.playernames
			end
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
