local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Options",
		desc = "",
		author = "Floris",
		date = "September 2016",
		license = "GNU GPL, v2 or later",
		layer = -99990,
		enabled = true,
		handler = true,
	}
end

Spring.SendCommands("resbar 0")

-- Add new options at: function init

local types = {
	basic    = 1,
	advanced = 2,
	dev      = 3,
}

local version = 1.5	-- used to toggle previously default enabled/disabled widgets to the newer default in widget:initialize()
local newerVersion = false	-- configdata will set this true if it's a newer version

local keyLayouts = VFS.Include("luaui/configs/keyboard_layouts.lua")

local languageCodes = { 'en', 'fr', 'ru', 'es' }
languageCodes = table.merge(languageCodes, table.invert(languageCodes))

local languageNames = {}
for key, code in ipairs(languageCodes) do
	languageNames[key] = Spring.I18N.languages[code]
end

local devLanguageCodes = { 'en', 'fr', 'de', 'ru', 'zh', 'es', 'test_unicode', }
devLanguageCodes = table.merge(devLanguageCodes, table.invert(devLanguageCodes))

local devLanguageNames = {}
for key, code in ipairs(devLanguageCodes) do
	devLanguageNames[key] = Spring.I18N.languages[code]
end

-- detect potatos
local isPotatoCpu = false
local isPotatoGpu = false
local gpuMem = (Platform.gpuMemorySize and Platform.gpuMemorySize or 1000) / 1000
if not gpuMem then
	gpuMem = 0
end
if gpuMem > 0 and gpuMem < 2500 then
	isPotatoGpu = true
elseif not Platform.glHaveGL4 then
	isPotatoGpu = true
end

local hideOtherLanguagesVoicepacks = true	-- maybe later allow people to pick other language voicepacks

local ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.7)

local devMode = Spring.Utilities.IsDevMode()
local devUI = Spring.Utilities.ShowDevUI()

local advSettings = false
local initialized = false
local pauseGameWhenSingleplayer = true

local cameraTransitionTime = 0.18
local cameraPanTransitionTime = 0.03

local optionColor = '\255\255\255\255'
local widgetOptionColor = '\255\160\160\160'
local advOptionColor = '\255\180\160\140'
local advMainOptionColor = '\255\255\235\200'
local devOptionColor = '\255\200\110\100'
local devMainOptionColor = '\255\245\166\140'

local firstlaunchsetupDone = false

local playSounds = true
local sounds = {
	buttonClick = 'LuaUI/Sounds/tock.wav',
	paginatorClick = 'LuaUI/Sounds/buildbar_waypoint.wav',
	sliderDrag = 'LuaUI/Sounds/buildbar_rem.wav',
	selectClick = 'LuaUI/Sounds/buildbar_click.wav',
	selectUnfoldClick = 'LuaUI/Sounds/buildbar_hover.wav',
	selectHoverClick = 'LuaUI/Sounds/hover.wav',
	toggleOnClick = 'LuaUI/Sounds/switchon.wav',
	toggleOffClick = 'LuaUI/Sounds/switchoff.wav',
}

local continuouslyClean = Spring.GetConfigInt("ContinuouslyClearMapmarks", 0) == 1

local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode
--local anonymousTeamColor = {Spring.GetConfigInt("anonymousColorR", 255)/255, Spring.GetConfigInt("anonymousColorG", 0)/255, Spring.GetConfigInt("anonymousColorB", 0)/255}

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local fontfile3 = "fonts/" .. Spring.GetConfigString("bar_font3", "SourceCodePro-Medium.otf")

local vsx, vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx * vsy / 5700000))
local fontfileSize = 36
local fontfileOutlineSize = 7

local pauseGameWhenSingleplayerExecuted = false

local backwardTex = ":l:LuaUI/Images/backward.dds"
local forwardTex = ":l:LuaUI/Images/forward.dds"

local screenHeightOrg = 520
local screenWidthOrg = 1050
local screenHeight = screenHeightOrg
local screenWidth = screenWidthOrg

local centerPosX = 0.5
local centerPosY = 0.5
local screenX = math.floor((vsx * centerPosX) - (screenWidth / 2))
local screenY = math.floor((vsy * centerPosY) + (screenHeight / 2))

local changesRequireRestart = false
local useNetworkSmoothing = false

local show = false
local prevShow = show
local manualChange = true

local spGetGroundHeight = Spring.GetGroundHeight

local os_clock = os.clock
local math_isInRect = math.isInRect

local chobbyInterface, font, font2, font3, backgroundGuishader, currentGroupTab, windowList, optionButtonBackward, optionButtonForward
local groupRect, titleRect, countDownOptionID, countDownOptionClock, sceduleOptionApply, checkedForWaterAfterGamestart, checkedWidgetDataChanges
local savedConfig, forceUpdate, sliderValueChanged, selectOptionsList, showSelectOptions, prevSelectHover
local fontOption, draggingSlider, lastSliderSound, selectClickAllowHide

local glColor = gl.Color
local glTexRect = gl.TexRect
local glTexture = gl.Texture
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local RectRound, elementCorner, elementMargin, elementPadding, UiElement, UiButton, UiSlider, UiSliderKnob, UiToggle, UiSelector, UiSelectHighlight, bgpadding

local isSinglePlayer = Spring.Utilities.Gametype.IsSinglePlayer()
local isReplay = Spring.IsReplay()

local skipUnpauseOnHide = false
local skipUnpauseOnLobbyHide = false

local desiredWaterValue = 4
local waterDetected = false
if select(3, Spring.GetGroundExtremes()) < 0 then
	waterDetected = true
end
local heightmapChangeBuffer = {}

local widgetScale = (vsy / 1080)

local edgeMoveWidth = tonumber(Spring.GetConfigFloat("EdgeMoveWidth", 1) or 0.02)

local defaultMapSunPos = { gl.GetSun("pos") }
local defaultSunLighting = {
	groundAmbientColor = { gl.GetSun("ambient") },
	unitAmbientColor = { gl.GetSun("ambient", "unit") },
	groundDiffuseColor = { gl.GetSun("diffuse") },
	unitDiffuseColor = { gl.GetSun("diffuse", "unit") },
	groundSpecularColor = { gl.GetSun("specular") },
	unitSpecularColor = { gl.GetSun("specular", "unit") },
}

local defaultSkyAxisAngle = {
	gl.GetAtmosphere("skyAxisAngle"),
}

-- Correct some maps fog
if Game.mapName == "Nine_Metal_Islands_V1" then
	Spring.SetAtmosphere({ fogStart = 999990, fogEnd = 9999999 })
end
local defaultMapFog = {
	fogStart = gl.GetAtmosphere("fogStart"),
	fogEnd = gl.GetAtmosphere("fogEnd"),
	fogColor = { gl.GetAtmosphere("fogColor") },
}

local options = {}
local customOptions = {}
local optionGroups = {}
local optionButtons = {}
local optionHover = {}
local optionSelect = {}
local windowRect = { 0, 0, 0, 0 }
local showOnceMore = false        -- used because of GUI shader delay
local resettedTonemapDefault = false
local heightmapChangeClock
local requireRestartDefaults = {}
local gameOver = false
local presets = {}

local reclaimFieldHighlightOptions = {
	Spring.I18N('ui.settings.option.reclaimfieldhighlight_always'),
	Spring.I18N('ui.settings.option.reclaimfieldhighlight_resource'),
	Spring.I18N('ui.settings.option.reclaimfieldhighlight_reclaimer'),
	Spring.I18N('ui.settings.option.reclaimfieldhighlight_resbot'),
	Spring.I18N('ui.settings.option.reclaimfieldhighlight_order'),
	Spring.I18N('ui.settings.option.reclaimfieldhighlight_disabled')
}

local spectatorHUDConfigOptions = {
	Spring.I18N('ui.settings.option.spectator_hud_config_basic'),
	Spring.I18N('ui.settings.option.spectator_hud_config_advanced'),
	Spring.I18N('ui.settings.option.spectator_hud_config_expert'),
	Spring.I18N('ui.settings.option.spectator_hud_config_custom'),
}

local startScript = VFS.LoadFile("_script.txt")
if not startScript then
	local modoptions = ''
	for key, value in pairs(Spring.GetModOptionsCopy()) do
		local v = value
		if type(v) == 'boolean' then
			v = (v and '1' or '0')
		end
		modoptions = modoptions .. key .. '=' .. v .. ';';
	end

	startScript = [[[game]
	{
		[allyteam1]
		{
			numallies=0;
		}
		[team1]
		{
			teamleader=0;
			allyteam=1;
		}
		[ai0]
		{
			shortname=Null AI;
			name=AI: Null AI;
			team=1;
			host=0;
		}
		[modoptions]
		{
			]] .. modoptions .. [[
		}
		[allyteam0]
		{
			numallies=0;
		}
		[team0]
		{
			teamleader=0;
			allyteam=0;
		}
		[player0]
		{
			team=0;
			name=]] .. select(1, Spring.GetPlayerInfo(Spring.GetMyPlayerID())) .. [[;
		}
		mapname=]] .. Game.mapName .. [[;
		myplayername=]] .. select(1, Spring.GetPlayerInfo(Spring.GetMyPlayerID())) .. [[;
		ishost=1;
		gametype=]] .. Game.gameName .. ' ' .. Game.gameVersion .. [[;
		nohelperais=0;
	}
	]]
end

local function setEngineFont()
	local relativesize = 1
	--"fonts/FreeSansBold.otf"
	Spring.SetConfigInt("SmallFontSize", fontfileSize * fontfileScale * relativesize)
	Spring.SetConfigInt("SmallFontOutlineWidth", fontfileOutlineSize * fontfileScale * relativesize * 0.85)
	Spring.SetConfigInt("SmallFontOutlineWeight", 2)

	Spring.SetConfigInt("FontSize", fontfileSize * fontfileScale * relativesize)
	Spring.SetConfigInt("FontOutlineWidth", fontfileOutlineSize * fontfileScale * relativesize * 0.85)
	Spring.SetConfigInt("FontOutlineWeight", 2)

	Spring.SendCommands("font " .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf"))

	-- set spring engine default font cause it cant thee game archive fonts on launch
	Spring.SetConfigString("SmallFontFile", "FreeSansBold.otf")
	Spring.SetConfigString("FontFile", "FreeSansBold.otf")
end
setEngineFont()

local function showOption(option)
	if not option.category
		or option.category == types.basic
		or (advSettings and option.category == types.advanced)
		or (devMode or devUI) then
		return true
	end
	return false
end

local function adjustShadowQuality()
	local quality = Spring.GetConfigInt("ShadowQuality", 3)
	local shadowMapSize = 600 + math.min(10240, (vsy+vsx)*0.37)*(quality*0.5)
	Spring.SetConfigInt("Shadows", (quality==0 and 0 or 1))
	Spring.SetConfigInt("ShadowMapSize", shadowMapSize)
	Spring.SendCommands("shadows "..(quality==0 and 0 or 1).." " .. shadowMapSize)
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()

	widgetScale = (vsy / 1080)

	screenHeight = math.floor(screenHeightOrg * widgetScale)
	screenWidth = math.floor(screenWidthOrg * widgetScale)
	screenX = math.floor((vsx * centerPosX) - (screenWidth / 2))
	screenY = math.floor((vsy * centerPosY) + (screenHeight / 2))

	bgpadding = WG.FlowUI.elementPadding
	elementCorner = WG.FlowUI.elementCorner
	elementMargin = WG.FlowUI.elementMargin
	elementPadding = WG.FlowUI.elementPadding

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiButton = WG.FlowUI.Draw.Button
	UiSlider = WG.FlowUI.Draw.Slider
	UiSliderKnob = WG.FlowUI.Draw.SliderKnob
	UiToggle = WG.FlowUI.Draw.Toggle
	UiSelector = WG.FlowUI.Draw.Selector
	UiSelectHighlight = WG.FlowUI.Draw.SelectHighlight

	font = WG['fonts'].getFont()
	font2 = WG['fonts'].getFont(2)
	font3 = WG['fonts'].getFont(2, 1.6)

	local newFontfileScale = (0.5 + (vsx * vsy / 5700000))
	if fontfileScale ~= newFontfileScale then
		fontfileScale = newFontfileScale
		setEngineFont()
	end

	if windowList then
		gl.DeleteList(windowList)
		backgroundGuishader = glDeleteList(backgroundGuishader)
		consoleCmdDlist = glDeleteList(consoleCmdDlist)
		textInputDlist = glDeleteList(textInputDlist)
	end
	windowList = gl.CreateList(DrawWindow)

	if backgroundGuishader ~= nil then
		backgroundGuishader = glDeleteList(backgroundGuishader)
	end

	adjustShadowQuality()
end

local function detectWater()
	local _, _, mapMinHeight, mapMaxHeight = Spring.GetGroundExtremes()
	if mapMinHeight <= -2 then
		waterDetected = true
		Spring.SendCommands("water " .. desiredWaterValue)
	end
end


local utf8 = VFS.Include('common/luaUtilities/utf8.lua')
--local textInputDlist, consoleCmdDlist, textCursorRect
local updateTextInputDlist = true
local showTextInput = true
local inputText = ''
local inputTextPosition = 0
local cursorBlinkTimer = 0
local cursorBlinkDuration = 1
local maxTextInputChars = 127	-- tested 127 as being the true max
local inputTextInsertActive = false
local floor = math.floor
local inputMode = ''

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

		init()
		return true
	end
end

local function clearChatInput()
	inputText = ''
	inputTextPosition = 0
	inputTextInsertActive = false
	init()
end

-- only called when show = false
local function cancelChatInput()
	local doReinit = inputText ~= ''
	backgroundGuishader = glDeleteList(backgroundGuishader)
	if WG['guishader'] then
		WG['guishader'].RemoveDlist('options')
		WG['guishader'].RemoveRect('optionsinput')
		if selectOptionsList then
			WG['guishader'].RemoveScreenRect('options_select')
			WG['guishader'].RemoveScreenRect('options_select_options')
			WG['guishader'].removeRenderDlist(selectOptionsList)
		end
	end
	if selectOptionsList then
		selectOptionsList = glDeleteList(selectOptionsList)
	end
	widgetHandler.textOwner = nil	--widgetHandler:DisownText()
	if doReinit then
		init()
	end
end

function drawChatInputCursor()
	if textCursorRect then
		local a = 1 - (cursorBlinkTimer * (1 / cursorBlinkDuration)) + 0.15
		glColor(0.7,0.7,0.7,a)
		gl.Rect(textCursorRect[1], textCursorRect[2], textCursorRect[3], textCursorRect[4])
		glColor(1,1,1,1)
	end
end

function updateInputDlist()
	updateTextInputDlist = false
	glDeleteList(textInputDlist)
	textInputDlist = glCreateList(function()
		local activationArea = {screenX, screenY - screenHeight, screenX + screenWidth, screenY}
		local usedFontSize = 15 * widgetScale
		local lineHeight = floor(usedFontSize * 1.15)
		local x,y,_ = Spring.GetMouseState()
		local chatlogHeightDiff = 0
		local inputFontSize = floor(usedFontSize * 1.03)
		local inputHeight = floor(inputFontSize * 2.15)
		local leftOffset = floor(lineHeight*0.7)
		local distance = 0 --elementMargin
		local usedFont = font
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
		local x2 = math.max(textPosX+lineHeight+floor(usedFont:GetTextWidth(inputText) * inputFontSize), floor(activationArea[1]+((activationArea[3]-activationArea[1])/5)))
		chatInputArea = { activationArea[1], activationArea[2]+chatlogHeightDiff-distance-inputHeight, x2, activationArea[2]+chatlogHeightDiff-distance }
		UiElement(chatInputArea[1], chatInputArea[2], chatInputArea[3], chatInputArea[4], 0,0,nil,nil, 0,nil,nil,nil, math.max(0.75, Spring.GetConfigFloat("ui_opacity", 0.7)))
		if WG['guishader'] then
			WG['guishader'].InsertRect(activationArea[1], activationArea[2]+chatlogHeightDiff-distance-inputHeight, x2, activationArea[2]+chatlogHeightDiff-distance, 'optionsinput')
		end

		-- button background
		local inputButtonRect = {activationArea[1]+elementPadding, activationArea[2]+chatlogHeightDiff-distance-inputHeight+elementPadding, textPosX-inputFontSize, activationArea[2]+chatlogHeightDiff-distance}
		if inputMode ~= '' then
			glColor(0.03, 0.12, 0.03, 0.3)
		else
			glColor(0, 0, 0, 0.3)
		end
		RectRound(inputButtonRect[1], inputButtonRect[2], inputButtonRect[3], inputButtonRect[4], elementCorner*0.6, 0,0,0,1)
		glColor(1,1,1,0.033)
		gl.Rect(inputButtonRect[3]-1, inputButtonRect[2], inputButtonRect[3], inputButtonRect[4])

		-- button text
		usedFont:Begin()
		usedFont:SetOutlineColor(0,0,0,0.4)
		usedFont:SetTextColor(0.62, 0.62, 0.62, 1)
		usedFont:Print(modeText, modeTextPosX, activationArea[2]+chatlogHeightDiff-distance-(inputHeight*0.61), inputFontSize, "o")

		-- text cursor
		textCursorRect = { textPosX + textCursorPos, activationArea[2]+chatlogHeightDiff-distance-(inputHeight*0.5)-(inputFontSize*0.6), textPosX + textCursorPos + textCursorWidth, activationArea[2]+chatlogHeightDiff-distance-(inputHeight*0.5)+(inputFontSize*0.64) }

		usedFont:SetTextColor(0.95, 0.95, 0.95, 1)
		usedFont:Print(inputText, textPosX, activationArea[2]+chatlogHeightDiff-distance-(inputHeight*0.61), inputFontSize, "o")
		usedFont:End()
	end)
end


function getOptionByID(id)
	for i, option in pairs(options) do
		if option.id == id then
			return i
		end
	end
	return false
end

function orderOptions()
	local groupOptions = {}
	for id, group in pairs(optionGroups) do
		groupOptions[group.id] = {}
	end
	for i, option in pairs(options) do
		if option.type ~= 'label' then
			groupOptions[option.group][#groupOptions[option.group] + 1] = option
		end
	end
	local newOptions = {}
	local newOptionsCount = 0
	for id, group in pairs(optionGroups) do
		if group.numOptions > 0 then
			local grOptions = groupOptions[group.id]
			if #grOptions > 0 then
				local name = group.name
				if group.id == 'gfx' then
					name = group.name .. '                                          \255\130\130\130' .. vsx .. ' x ' .. vsy
				end
				newOptionsCount = newOptionsCount + 1
				newOptions[newOptionsCount] = { id = "group_" .. group.id, name = '\255\255\200\110'..name, type = "label"}
			end
			for i, option in pairs(grOptions) do
				newOptionsCount = newOptionsCount + 1
				newOptions[newOptionsCount] = option
			end
		end
	end
	options = table.copy(newOptions)
end

function mouseoverGroupTab(id)
	if optionGroups[id].id == currentGroupTab then
		return
	end

	local tabFontSize = 16 * widgetScale
	local groupMargin = math.floor(bgpadding * 0.8)
	glBlending(GL_SRC_ALPHA, GL_ONE)
	RectRound(groupRect[id][1] + groupMargin, groupRect[id][2], groupRect[id][3] - groupMargin, groupRect[id][4] - groupMargin, groupMargin * 1.8, 1, 1, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.07 })
	-- gloss
	RectRound(groupRect[id][1] + groupMargin, groupRect[id][4] - groupMargin - ((groupRect[id][4] - groupRect[id][2]) * 0.5), groupRect[id][3] - groupMargin, groupRect[id][4] - groupMargin, groupMargin * 1.8, 1, 1, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.1 })
	RectRound(groupRect[id][1] + groupMargin, groupRect[id][2], groupRect[id][3] - groupMargin, groupRect[id][2] + groupMargin + ((groupRect[id][4] - groupRect[id][2]) * 0.5), groupMargin * 1.25, 0, 0, 0, 0, { 1, 1, 1, 0.05 }, { 0, 0, 0, 0 })
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

	font2:Begin()
	font2:SetTextColor(1, 0.9, 0.66, 1)
	font2:SetOutlineColor(0.4, 0.3, 0.15, 0.4)
	font2:Print(optionGroups[id].name, groupRect[id][1] + ((groupRect[id][3] - groupRect[id][1]) / 2), screenY + (9 * widgetScale), tabFontSize, "con")
	font2:End()
end

local startColumn = 1        -- used for navigation
local maxShownColumns = 3
local maxColumnRows = 0    -- gets calculated
local totalColumns = 0        -- gets calculated

function DrawWindow()
	orderOptions()

	glTexture(false)
	local x = screenX --rightwards
	local y = screenY --upwards
	windowRect = { screenX, screenY - screenHeight, screenX + screenWidth, screenY }

	-- background
	UiElement(screenX, screenY - screenHeight, screenX + screenWidth, screenY, (showTextInput and inputText ~= '' and inputMode == '') and 1 or 0, 0, 1, (showTextInput and 0 or 1), 1, 1, 1, 1, math.max(0.75, Spring.GetConfigFloat("ui_opacity", 0.7)))

	-- title
	local groupMargin = math.floor(bgpadding * 0.8)
	local color2 = '\255\125\125\125'
	local color = '\255\255\255\255'
	local title = ""
	if devMode or devUI then
		title = devOptionColor .. Spring.I18N('ui.settings.option.devmode')
	elseif advSettings then
		title = color2 .. Spring.I18N('ui.settings.basic') .. "  /  " .. color .. Spring.I18N('ui.settings.advanced')
	else
		title = color .. Spring.I18N('ui.settings.basic') .. color2 .. "  /  " .. Spring.I18N('ui.settings.advanced')
	end
	local titleFontSize = 18 * widgetScale
	titleRect = { math.floor((screenX + screenWidth) - ((font2:GetTextWidth(title) * titleFontSize) + (titleFontSize * 1.5))), screenY, screenX + screenWidth, math.floor(screenY + (titleFontSize * 1.7)) }

	-- title drawing
	RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], elementCorner, 1, 1, 0, 0, WG['guishader'] and { 0, 0, 0, 0.8 } or { 0, 0, 0, 0.85 }, WG['guishader'] and { 0.05, 0.05, 0.05, 0.8 } or { 0.05, 0.05, 0.05, 0.85 })
	RectRound(titleRect[1] + groupMargin, titleRect[4] - groupMargin - ((titleRect[4] - titleRect[2]) * 0.5), titleRect[3] - groupMargin, titleRect[4] - groupMargin, elementCorner * 0.66, 1, 1, 0, 0, { 1, 0.95, 0.85, 0.03 }, { 1, 0.95, 0.85, 0.15 })

	font2:Begin()
	font2:SetTextColor(1, 1, 1, 1)
	font2:SetOutlineColor(0, 0, 0, 0.4)
	font2:Print(title, titleRect[1] + (titleFontSize * 0.75), screenY + (8 * widgetScale), titleFontSize, "on")
	font2:End()

	-- group tabs
	if not (showTextInput and inputText ~= '' and inputMode == '') then
		local tabFontSize = 16 * widgetScale
		local xpos = screenX
		local groupPadding = 1
		groupRect = {}
		for id, group in pairs(optionGroups) do
			if group.numOptions > 0 then
				groupRect[id] = { xpos, titleRect[2], math.floor(xpos + (font2:GetTextWidth(group.name) * tabFontSize) + (33 * widgetScale)), titleRect[4] }
				if devMode or devUI or group.id ~= 'dev' then
					xpos = groupRect[id][3]
					if currentGroupTab == nil or currentGroupTab ~= group.id then
						RectRound(groupRect[id][1], groupRect[id][2], groupRect[id][3], groupRect[id][4], elementCorner, 1, 1, 0, 0, WG['guishader'] and { 0, 0, 0, 0.8 } or { 0, 0, 0, 0.85 }, WG['guishader'] and { 0.05, 0.05, 0.05, 0.8 } or { 0.05, 0.05, 0.05, 0.85 })
						RectRound(groupRect[id][1] + groupMargin, groupRect[id][2], groupRect[id][3] - groupMargin, groupRect[id][4] - groupMargin, elementCorner * 0.66, 1, 1, 0, 0, { 0.6, 0.47, 0.24, 0.2 }, { 0.88, 0.68, 0.33, 0.2 })

						RectRound(groupRect[id][1] + groupMargin+groupPadding, groupRect[id][2], groupRect[id][3] - groupMargin-groupPadding, groupRect[id][4] - groupMargin-groupPadding, elementCorner * 0.5, 1, 1, 0, 0, { 0,0,0, 0.13 }, { 0,0,0, 0.13 })

						glBlending(GL_SRC_ALPHA, GL_ONE)
						-- gloss
						RectRound(groupRect[id][1] + groupMargin, groupRect[id][4] - groupMargin - ((groupRect[id][4] - groupRect[id][2]) * 0.5), groupRect[id][3] - groupMargin, groupRect[id][4] - groupMargin, bgpadding * 1.2, 1, 1, 0, 0, { 1, 0.88, 0.66, 0 }, { 1, 0.88, 0.66, 0.1 })
						glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

						font2:Begin()
						font2:SetTextColor(0.7, 0.58, 0.44, 1)
						font2:SetOutlineColor(0, 0, 0, 0.4)
						font2:Print(group.name, groupRect[id][1] + ((groupRect[id][3] - groupRect[id][1]) / 2), screenY + (9 * widgetScale), tabFontSize, "con")
						font2:End()
					else
						RectRound(groupRect[id][1], groupRect[id][2], groupRect[id][3], groupRect[id][4], elementCorner, 1, 1, 0, 0, WG['guishader'] and { 0, 0, 0, 0.8 } or { 0, 0, 0, 0.85 }, WG['guishader'] and { 0.05, 0.05, 0.05, 0.8 } or { 0.05, 0.05, 0.05, 0.85 })
						RectRound(groupRect[id][1] + groupMargin, groupRect[id][2] - bgpadding, groupRect[id][3] - groupMargin, groupRect[id][4] - groupMargin, elementCorner * 0.8, 1, 1, 0, 0, { 0.7, 0.7, 0.7, 0.15 }, { 0.8, 0.8, 0.8, 0.15 })

						font2:Begin()
						font2:SetTextColor(1, 0.75, 0.4, 1)
						font2:SetOutlineColor(0, 0, 0, 0.4)
						font2:Print(group.name, groupRect[id][1] + ((groupRect[id][3] - groupRect[id][1]) / 2), screenY + (9 * widgetScale), tabFontSize, "con")
						font2:End()
					end
				end
			end
		end
	end

	font:Begin()
	font:SetOutlineColor(0,0,0,0.4)

	-- draw options
	local oHeight = math.floor(15 * widgetScale)
	local oPadding = math.floor(6 * widgetScale)
	y = math.floor(math.floor(y - oPadding - (17 * widgetScale)))
	local oWidth = math.floor((screenWidth / 3) - oPadding - oPadding)
	local yHeight = math.floor(screenHeight - (65 * widgetScale) - oPadding)
	local xPos = math.floor(x + oPadding + (5 * widgetScale))
	local xPosMax = xPos + oWidth - oPadding - oPadding
	local yPosMax = y - yHeight
	local boolWidth = math.floor(40 * widgetScale)
	local sliderWidth = math.floor(110 * widgetScale)
	local selectWidth = math.floor(140 * widgetScale)
	local i = 0
	local rows = 0
	local column = 1
	local drawColumnPos = 1

	maxColumnRows = math.ceil((y - yPosMax + oPadding) / (oHeight + oPadding + oPadding))
	local numOptions = #options

	local dontFilterGroup = false
	if inputText and inputText ~= '' and inputMode == '' then
		dontFilterGroup = true
	end
	if currentGroupTab ~= nil and not dontFilterGroup then
		numOptions = 0
		for i, option in pairs(options) do
			if option.group == currentGroupTab and showOption(option) then
				numOptions = numOptions + 1
			end
		end
	end

	totalColumns = math.ceil(numOptions / maxColumnRows)

	optionButtons = {}
	optionHover = {}

	-- require restart notification
	if changesRequireRestart then
		glColor(1,0,0,0.06)
		RectRound(screenX+bgpadding, screenY - screenHeight+bgpadding, screenX + screenWidth-bgpadding, screenY-screenHeight + (31 * widgetScale), elementCorner, 0, 0, 1, 0)
		RectRound(screenX+bgpadding, screenY - screenHeight+bgpadding + (30 * widgetScale)-1, screenX + screenWidth-bgpadding, screenY-screenHeight + (30 * widgetScale), 0, 0, 0, 0, 0)
		font:SetTextColor(0.9, 0.3, 0.3, 1)
		font:SetOutlineColor(0, 0, 0, 0.4)
		font:Print(Spring.I18N('ui.settings.madechanges'), screenX + math.floor(screenWidth*0.5), screenY - screenHeight + (12 * widgetScale), 15 * widgetScale, "cn")
	end

	-- draw navigation... backward/forward
	if totalColumns > maxShownColumns then
		local buttonSize = 35 * widgetScale
		local buttonMargin = 8 * widgetScale
		local startX = x + screenWidth
		local startY = screenY - screenHeight + buttonMargin

		glColor(1, 1, 1, 1)

		if (startColumn - 1) + maxShownColumns < totalColumns then
			optionButtonForward = { startX - buttonSize - buttonMargin, startY, startX - buttonMargin, startY + buttonSize }
			glColor(1, 1, 1, 1)
			glTexture(forwardTex)
			glTexRect(optionButtonForward[1], optionButtonForward[2], optionButtonForward[3], optionButtonForward[4])
			glTexture(false)
			UiButton(optionButtonForward[1], optionButtonForward[2], optionButtonForward[3], optionButtonForward[4])
		else
			optionButtonForward = nil
		end

		font:SetTextColor(1, 1, 1, 0.4)
		font:Print(math.ceil(startColumn / maxShownColumns) .. ' / ' .. math.ceil(totalColumns / maxShownColumns), startX - (buttonSize * 2.6) - buttonMargin, startY + buttonSize / 2.6, buttonSize / 2.4, "rn")
		if startColumn > 1 then
			if optionButtonForward == nil then
				optionButtonBackward = { startX - buttonSize - buttonMargin, startY, startX - buttonMargin, startY + buttonSize }
			else
				optionButtonBackward = { startX - (buttonSize * 2) - buttonMargin - (buttonMargin / 1.5), startY, startX - (buttonSize * 1) - buttonMargin - (buttonMargin / 1.5), startY + buttonSize }
			end
			glColor(1, 1, 1, 1)
			glTexture(backwardTex)
			glTexRect(optionButtonBackward[1], optionButtonBackward[2], optionButtonBackward[3], optionButtonBackward[4])
			glTexture(false)
			UiButton(optionButtonBackward[1], optionButtonBackward[2], optionButtonBackward[3], optionButtonBackward[4])
		else
			optionButtonBackward = nil
		end
	end

	-- draw options
	local yPos
	local prevGroup = ''
	for oid, option in pairs(options) do
		if showOption(option) then
			if currentGroupTab == nil or option.group == currentGroupTab or dontFilterGroup then
				yPos = math.floor(y - (((oHeight + oPadding + oPadding) * i) - oPadding))
				if yPos - oHeight < yPosMax then
					i = 0
					column = column + 1
					if column >= startColumn and rows > 0 then
						drawColumnPos = drawColumnPos + 1
					end
					if drawColumnPos > 3 then
						break
					end
					if rows > 0 then
						xPos = math.floor(x + (((screenWidth / 3)) * (drawColumnPos - 1)))
						xPosMax = math.floor(xPos + oWidth)
					end
					yPos = y - (((oHeight + oPadding + oPadding) * i) - oPadding)
				end

				if column >= startColumn then
					rows = rows + 1
					if option.name then
						color = '\255\225\225\225'

						font:SetTextColor(1, 1, 1, 1)
						font:SetOutlineColor(0, 0, 0, 0.4)

						if option.type == nil then
							font:End()
							font3:Begin()
							font3:SetOutlineColor(0,0,0,0.4)
							font3:Print('\255\255\200\130' .. option.name, xPos + (oPadding * 0.5), yPos - (oHeight * 1.8) - oPadding, oHeight * 1.5, "no")
							font3:End()
							font:Begin()
							font:SetOutlineColor(0,0,0,0.4)
							font:SetTextColor(1, 1, 1, 1)
							font:SetOutlineColor(0, 0, 0, 0.4)
						else
							local text = option.name
							local width = font:GetTextWidth(text) * math.floor(15 * widgetScale)
							local maxWidthMult = 1
							if option.type == 'bool' then
								maxWidthMult = 0.85
							elseif option.type == 'select' then
								maxWidthMult = 0.5
							elseif option.type == 'slider' then
								maxWidthMult = 0.55
							end
							local maxWidth = (xPosMax - xPos - 45) * maxWidthMult
							if width > maxWidth then
								maxWidth = (xPosMax - xPos - 50) * maxWidthMult
								while font:GetTextWidth(text) * math.floor(15 * widgetScale) > maxWidth do
									text = string.sub(text, 1, string.len(text) - 1)
								end
								text = text .. '...'
								if not option.description or option.description == '' then
									option.description = option.name
								elseif option.description ~= option.name and string.sub(option.description, 1, string.len(option.name)) ~= option.name then
									option.description = option.name..'\n\255\255\255\255'..option.description
								end
							end
							if option.restart then
								font:Print('\255\255\090\090*', xPos + (oPadding * 0.3), yPos - (oHeight / 5) - oPadding, oHeight, "no")
							end
							options[oid].nametext = text
							font:Print(color .. text, xPos + (oPadding * 2), yPos - (oHeight / 2.4) - oPadding, oHeight, "no")
						end

						-- define hover area
						optionHover[oid] = { math.floor(xPos), math.floor(yPos - oHeight - oPadding), math.floor(xPosMax), math.floor(yPos + oPadding) }

						-- option controller
						local rightPadding = 4
						if option.type == 'click' then
							optionButtons[oid] = {}
							optionButtons[oid] = { math.floor(xPos + rightPadding), math.floor(yPos - oHeight), math.floor(xPosMax - rightPadding), math.floor(yPos) }

						elseif option.type == 'bool' then
							optionButtons[oid] = {}
							optionButtons[oid] = { math.floor(xPosMax - boolWidth - rightPadding), math.floor(yPos - oHeight), math.floor(xPosMax - rightPadding), math.floor(yPos) }
							UiToggle(optionButtons[oid][1], optionButtons[oid][2], optionButtons[oid][3], optionButtons[oid][4], option.value)

						elseif option.type == 'slider' then
							if type(option.value) == 'number' then	-- just to be safe
								local sliderSize = oHeight * 0.75
								local sliderPos = 0
								if option.steps then
									local min, max = option.steps[1], option.steps[1]
									for k, v in ipairs(option.steps) do
										if v > max then
											max = v
										end
										if v < min then
											min = v
										end
									end
									sliderPos = (option.value - min) / (max - min)
								else
									sliderPos = (option.value - option.min) / (option.max - option.min)
								end
								if type(sliderPos) == 'number' then
									UiSlider(math.floor(xPosMax - (sliderSize / 2) - sliderWidth - rightPadding), math.floor(yPos - ((oHeight / 7) * 4.5)), math.floor(xPosMax - (sliderSize / 2) - rightPadding), math.floor(yPos - ((oHeight / 7) * 2.8)), option.steps and option.steps or option.step, option.min, option.max)
									UiSliderKnob(math.floor(xPosMax - (sliderSize / 2) - sliderWidth + (sliderWidth * sliderPos) - rightPadding), math.floor(yPos - oHeight + ((oHeight) / 2)), math.floor(sliderSize / 2))
									optionButtons[oid] = { xPosMax - (sliderSize / 2) - sliderWidth + (sliderWidth * sliderPos) - (sliderSize / 2) - rightPadding, yPos - oHeight + ((oHeight - sliderSize) / 2), xPosMax - (sliderSize / 2) - sliderWidth + (sliderWidth * sliderPos) + (sliderSize / 2) - rightPadding, yPos - ((oHeight - sliderSize) / 2) }
									optionButtons[oid].sliderXpos = { xPosMax - (sliderSize / 2) - sliderWidth - rightPadding, xPosMax - (sliderSize / 2) - rightPadding }
								end
							end
						elseif option.type == 'select' then
							optionButtons[oid] = { math.floor(xPosMax - selectWidth - rightPadding), math.floor(yPos - oHeight), math.floor(xPosMax - rightPadding), math.floor(yPos) }
							UiSelector(optionButtons[oid][1], optionButtons[oid][2], optionButtons[oid][3], optionButtons[oid][4], option.value)

							if option.options[tonumber(option.value)] ~= nil then
								local fontSize = oHeight * 0.85

								local text = option.options[tonumber(option.value)]
								if font:GetTextWidth(text) * math.floor(15 * widgetScale) > (optionButtons[oid][3] - optionButtons[oid][1]) * 0.93 then
									while font:GetTextWidth(text) * math.floor(15 * widgetScale) > (optionButtons[oid][3] - optionButtons[oid][1]) * 0.9 do
										text = string.sub(text, 1, string.len(text) - 1)
									end
									text = text .. '...'
									if not option.description or option.description == '' then
										option.description = option.name
									elseif option.description ~= option.name and string.sub(option.description, 1, string.len(option.name)) ~= option.name then
										option.description = option.name..'\n\255\255\255\255'..option.description
									end
								end
								options[oid].nametext = text
								if option.id == 'font2' then
									font:End()
									font2:Begin()
									font2:SetOutlineColor(0,0,0,0.4)
									font2:SetTextColor(1, 1, 1, 1)
									font2:Print(text, xPosMax - selectWidth + 5 - rightPadding, yPos - (fontSize / 2) - oPadding, fontSize, "no")
									font2:End()
									font:Begin()
									font:SetOutlineColor(0,0,0,0.4)
								else
									font:SetTextColor(1, 1, 1, 1)
									font:Print(text, xPosMax - selectWidth + 5 - rightPadding, yPos - (fontSize / 2) - oPadding, fontSize, "no")
								end
							end
						end
					end
				end
				i = i + 1
			end
		end
	end
	font:End()
end

local function updateGrabinput()
	-- grabinput makes alt-tabbing harder, so loosen grip a bit when in lobby would be wise
	if Spring.GetConfigInt('grabinput', 1) == 1 and not gameOver then
		if chobbyInterface then
			if enabledGrabinput then
				enabledGrabinput = false
				Spring.SendCommands("grabinput 0")
			end
		else
			if not enabledGrabinput then
				enabledGrabinput = true
				Spring.SendCommands("grabinput 1")
			end
		end
	else
        enabledGrabinput = false
        Spring.SendCommands("grabinput 0")
	end
end

local sec = 0
local sec2 = 0
local lastUpdate = 0
local ambientplayerCheck = false
local muteFadeTime = 0.35
local isOffscreen = false
local isOffscreenTime
local prevOffscreenVolume
local apiUnitTrackerEnabledCount = 0

function resetUserVolume()
	if prevOffscreenVolume then
		Spring.SetConfigInt("snd_volmaster", prevOffscreenVolume)
		prevOffscreenVolume = nil
	end
end

function widget:Update(dt)
	cursorBlinkTimer = cursorBlinkTimer + dt
	if cursorBlinkTimer > cursorBlinkDuration then cursorBlinkTimer = 0 end

	local prevIsOffscreen = isOffscreen
	isOffscreen = select(6, Spring.GetMouseState())
	if isOffscreen and enabledGrabinput then
		enabledGrabinput = false
	end
	if Spring.GetConfigInt("muteOffscreen", 0) == 1 then
		if isOffscreen ~= prevIsOffscreen then
			local prevIsOffscreenTime = isOffscreenTime
			isOffscreenTime = os.clock()
			if isOffscreen and not prevIsOffscreenTime then
				prevOffscreenVolume = tonumber(Spring.GetConfigInt("snd_volmaster", 40) or 40)
			end
		end
		if isOffscreenTime then
			if isOffscreenTime+muteFadeTime > os.clock() then
				if isOffscreen then
					Spring.SetConfigInt("snd_volmaster", prevOffscreenVolume*(1-((os.clock()-isOffscreenTime)/muteFadeTime)))
				else
					Spring.SetConfigInt("snd_volmaster", prevOffscreenVolume*((os.clock()-isOffscreenTime)/muteFadeTime))
				end
			else
				isOffscreenTime = nil
				if isOffscreen then
					Spring.SetConfigInt("snd_volmaster", 0)
				else
					resetUserVolume()
				end
			end
		end
	end

	if countDownOptionID and countDownOptionClock and countDownOptionClock < os_clock() then
		applyOptionValue(countDownOptionID)
		countDownOptionID = nil
		countDownOptionClock = nil
	end

	if not initialized then
		return
	end

		-- disable ambient player widget, also doing this on initialize but hell... players somehow still have this enabled
		if not ambientplayerCheck then
			ambientplayerCheck = true
			if widgetHandler:IsWidgetKnown("Ambient Player") then
				widgetHandler:DisableWidget("Ambient Player")
			end
		end

	if sceduleOptionApply then
		if sceduleOptionApply[1] <= os.clock() then
			applyOptionValue(sceduleOptionApply[2], nil, true, true)
			sceduleOptionApply = nil
		end
	end

	--if tonumber(Spring.GetConfigInt("CameraSmoothing", 0)) == 1 then
	--	Spring.SetCameraState(nil, 1)
	--else
		if WG.lockcamera and not WG.lockcamera.GetPlayerID() and WG.setcamera_bugfix == true then
			Spring.SetCameraState(nil, cameraTransitionTime)
		end
	--end

	-- check if there is water shown 	(we do this because basic water 0 saves perf when no water is rendered)
	if not waterDetected then
		-- in case of modoption waterlevel has been made to show water
		if not checkedForWaterAfterGamestart and Spring.GetGameFrame() <= 30 then
			detectWater()
			checkedForWaterAfterGamestart = true
		end
		if heightmapChangeClock and heightmapChangeClock + 1 < os_clock() then
			for k, coords in pairs(heightmapChangeBuffer) do
				local x = coords[1]
				local z = coords[2]
				while x <= coords[3] do
					z = coords[2]
					while z <= coords[4] do
						if spGetGroundHeight(x, z) <= 0 then
							waterDetected = true
							Spring.SendCommands("water " .. desiredWaterValue)
							break
						end
						z = z + 8
					end
					if waterDetected then
						break
					end
					x = x + 8
				end
			end
			heightmapChangeClock = nil
			heightmapChangeBuffer = {}
		end
	end

	sec2 = sec2 + dt
	if sec2 > 0.5 then
		sec2 = 0
		continuouslyClean = Spring.GetConfigInt("ContinuouslyClearMapmarks", 0) == 1

		-- make sure widget is enabled
		if apiUnitTrackerEnabledCount < 10 and widgetHandler.orderList["API Unit Tracker DEVMODE GL4"] and widgetHandler.orderList["API Unit Tracker DEVMODE GL4"] < 0.5 then
			apiUnitTrackerEnabledCount = apiUnitTrackerEnabledCount + 1
			widgetHandler:EnableWidget("API Unit Tracker DEVMODE GL4")
		end

		updateGrabinput()
	end

	sec = sec + dt
	if show and (sec > lastUpdate + 0.5 or forceUpdate) then
		sec = 0
		forceUpdate = nil
		lastUpdate = sec

		local changes = false
		for i, option in ipairs(options) do
			if options[i].widget ~= nil and options[i].type == 'bool' and options[i].value ~= GetWidgetToggleValue(options[i].widget) then
				options[i].value = GetWidgetToggleValue(options[i].widget)
				changes = true
			end
		end
		if changes then
			if windowList then
				gl.DeleteList(windowList)
			end
			windowList = gl.CreateList(DrawWindow)
		end
		if getOptionByID('sndvolmaster') then
			options[getOptionByID('sndvolmaster')].value = tonumber(Spring.GetConfigInt("snd_volmaster", 40) or 40)    -- update value because other widgets can adjust this too
		end
		if getOptionByID('sndvolmusic') then
			if WG['music'] and WG['music'].GetMusicVolume then
				options[getOptionByID('sndvolmusic')].value = WG['music'].GetMusicVolume()
			else
				options[getOptionByID('sndvolmusic')].value = tonumber(Spring.GetConfigInt("snd_volmusic", 50) or 50)
			end
		end
	end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	if show then
		--on window
		local mx, my, ml = Spring.GetMouseState()
		if math_isInRect(mx, my, windowRect[1], windowRect[2], windowRect[3], windowRect[4]) then
			return true
		elseif titleRect and math_isInRect(mx, my, titleRect[1], titleRect[2], titleRect[3], titleRect[4]) then
			return true
		elseif groupRect ~= nil then
			for id, group in pairs(optionGroups) do
				if devMode or devUI or group.id ~= 'dev' then
					if math_isInRect(mx, my, groupRect[id][1], groupRect[id][2], groupRect[id][3], groupRect[id][4]) then
						return true
					end
				end
			end
		end
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
		updateGrabinput()
		if (isSinglePlayer or isReplay) and pauseGameWhenSingleplayer and not skipUnpauseOnHide then
			local _, _, isClientPaused, _ = Spring.GetGameState()
			if chobbyInterface and isClientPaused then
				skipUnpauseOnLobbyHide = true
			end
			if not skipUnpauseOnLobbyHide then
				Spring.SendCommands("pause " .. (chobbyInterface and '1' or '0'))
				pauseGameWhenSingleplayerExecuted = chobbyInterface
			end
			if not chobbyInterface then
				Spring.SetConfigInt('VSync', Spring.GetConfigInt("VSyncGame", -1) * Spring.GetConfigInt("VSyncFraction", 1))
			end
		end
	end
end

local function checkPause()
	-- pause/unpause when the options/quitscreen interface shows
	local _, _, isClientPaused, _ = Spring.GetGameState()
	if not isClientPaused then
		skipUnpauseOnHide = false
		skipUnpauseOnLobbyHide = false
	end
	local showToggledOff = false
	if (isSinglePlayer or isReplay) and pauseGameWhenSingleplayer and prevShow ~= show then
		if show and isClientPaused then
			skipUnpauseOnHide = true
		end
		if not skipUnpauseOnHide then
			Spring.SendCommands("pause " .. (show and '1' or '0'))    -- cause several widgets are still using old colors
			showToggledOff = not show
			pauseGameWhenSingleplayerExecuted = show
		end
	end
end

local quitscreen = false
local prevQuitscreen = false
local function checkQuitscreen()
	quitscreen = (WG['topbar'] and WG['topbar'].showingQuit() or false)
	if (isSinglePlayer or isReplay) and pauseGameWhenSingleplayer and prevQuitscreen ~= quitscreen then
		if quitscreen and isClientPaused and not showToggledOff then
			skipUnpauseOnHide = true
		end
		if not skipUnpauseOnHide then
			Spring.SendCommands("pause " .. (quitscreen and '1' or '0'))    -- cause several widgets are still using old colors
			pauseGameWhenSingleplayerExecuted = quitscreen
		end
	end
	prevQuitscreen = quitscreen
end

function widget:DrawScreen()
	-- doing in separate functions to prevent a > 60 upvalues error
	checkPause()
	checkQuitscreen()

	-- doing it here so other widgets having higher layer number value are also loaded
	if not initialized then
		init()
		initialized = true
	else

		-- update new slider value
		if sliderValueChanged then
			gl.DeleteList(windowList)
			windowList = gl.CreateList(DrawWindow)
			sliderValueChanged = nil
		end

		if not showSelectOptions and selectOptionsList then
			if WG['guishader'] then
				WG['guishader'].RemoveScreenRect('options_select')
				WG['guishader'].RemoveScreenRect('options_select_options')
				WG['guishader'].removeRenderDlist(selectOptionsList)
			end
			selectOptionsList = glDeleteList(selectOptionsList)
		end

		if (show or showOnceMore) and windowList then

			--on window
			local mx, my, ml = Spring.GetMouseState()
			if (math_isInRect(mx, my, windowRect[1], windowRect[2], windowRect[3], windowRect[4])) or
					(titleRect and math_isInRect(mx, my, titleRect[1], titleRect[2], titleRect[3], titleRect[4])) or
					(chatInputArea and math_isInRect(mx, my, chatInputArea[1], chatInputArea[2], chatInputArea[3], chatInputArea[4]))
			then
				Spring.SetMouseCursor('cursornormal')
			end
			if groupRect ~= nil then
				for id, group in pairs(optionGroups) do
					if group.numOptions > 0 then
						if devMode or devUI or group.id ~= 'dev' then
							if math_isInRect(mx, my, groupRect[id][1], groupRect[id][2], groupRect[id][3], groupRect[id][4]) then
								Spring.SetMouseCursor('cursornormal')
								break
							end
						end
					end
				end
			end

			-- draw the options panel
			glCallList(windowList)
			if WG['guishader'] then
				if not backgroundGuishader then
					backgroundGuishader = glCreateList(function()
						-- background
						RectRound(screenX, screenY - screenHeight, screenX + screenWidth, screenY, elementCorner, 0, 1, 1, 1)
						-- title
						RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], elementCorner, 1, 1, 0, 0)
						-- tabs
						if not (showTextInput and inputText ~= '' and inputMode == '') then
							guishaderedTabs = true
							for id, group in pairs(optionGroups) do
								if group.numOptions > 0 then
									if devMode or devUI or group.id ~= 'dev' then
										if groupRect[id] then
											RectRound(groupRect[id][1], groupRect[id][2], groupRect[id][3], groupRect[id][4], elementCorner, 1, 1, 0, 0)
										end
									end
								end
							end
						else
							guishaderedTabs = false
						end
					end)
					WG['guishader'].InsertDlist(backgroundGuishader, 'options')
				end
			end
			showOnceMore = false

			-- mouseover (highlight and tooltip)
			local description = ''
			if not (devMode or devUI) and titleRect ~= nil and math_isInRect(mx, my, titleRect[1], titleRect[2], titleRect[3], titleRect[4]) then
				local groupMargin = math.floor(bgpadding * 0.8)
				-- gloss
				glBlending(GL_SRC_ALPHA, GL_ONE)
				RectRound(titleRect[1] + groupMargin, titleRect[2], titleRect[3] - groupMargin, titleRect[4] - groupMargin, groupMargin * 1.8, 1, 1, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.12 })
				RectRound(titleRect[1] + groupMargin, titleRect[4] - groupMargin - ((titleRect[4] - titleRect[2]) * 0.5), titleRect[3] - groupMargin, titleRect[4] - groupMargin, groupMargin * 1.8, 1, 1, 0, 0, { 1, 0.88, 0.66, 0 }, { 1, 0.88, 0.66, 0.09 })
				glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
			end
			if not (showTextInput and inputText ~= '' and inputMode == '') then
				if groupRect ~= nil then
					for id, group in pairs(optionGroups) do
						if group.numOptions > 0 then
							if devMode or devUI or group.id ~= 'dev' then
								if math_isInRect(mx, my, groupRect[id][1], groupRect[id][2], groupRect[id][3], groupRect[id][4]) then
									mouseoverGroupTab(id)
								end
							end
						end
					end
				end
			end
			if optionButtonForward ~= nil and math_isInRect(mx, my, optionButtonForward[1], optionButtonForward[2], optionButtonForward[3], optionButtonForward[4]) then
				RectRound(optionButtonForward[1], optionButtonForward[2], optionButtonForward[3], optionButtonForward[4], (optionButtonForward[4] - optionButtonForward[2]) / 12, 2, 2, 2, 2, ml and { 1, 0.91, 0.66, 0.1 } or { 1, 0.91, 0.66, 0.3 }, { 1, 0.91, 0.66, 0.2 })
			end
			if optionButtonBackward ~= nil and math_isInRect(mx, my, optionButtonBackward[1], optionButtonBackward[2], optionButtonBackward[3], optionButtonBackward[4]) then
				RectRound(optionButtonBackward[1], optionButtonBackward[2], optionButtonBackward[3], optionButtonBackward[4], (optionButtonBackward[4] - optionButtonBackward[2]) / 12, 2, 2, 2, 2, ml and { 1, 0.91, 0.66, 0.1 } or { 1, 0.91, 0.66, 0.3 }, { 1, 0.91, 0.66, 0.2 })
			end

			if not showSelectOptions then
				local tooltipShowing = false
				for i, o in pairs(optionButtons) do
					if options[i] and math_isInRect(mx, my, o[1], o[2], o[3], o[4]) then
						if options[i].onclick == nil then
							RectRound(o[1], o[2], o[3], o[4], 1, 2, 2, 2, 2, { 0.5, 0.5, 0.5, 0.22 }, { 1, 1, 1, 0.22 })
						end
						if WG['tooltip'] ~= nil and options[i].type == 'slider' then
							local value = options[i].value
							if options[i].steps then
								value = NearestValue(options[i].steps, value)
							else
								local decimalValue, floatValue = math.modf(options[i].step)
								if floatValue ~= 0 then
									value = string.format("%." .. string.len(string.sub('' .. options[i].step, 3)) .. "f", value)    -- do rounding via a string because floats show rounding errors at times
								end
							end
							WG['tooltip'].ShowTooltip('options_showvalue', value)
							tooltipShowing = true
						end
					end
				end
				if not tooltipShowing then
					for i, o in pairs(optionHover) do
						if options[i] and math_isInRect(mx, my, o[1], o[2], o[3], o[4]) and options[i].type and options[i].type ~= 'label' and options[i].type ~= 'text' then
							-- display console command at the bottom
							if (advSettings or devMode or devUI) and (options[i].onchange ~= nil or options[i].widget) then
								if not consoleCmdDlist or not lastConsoleCmdOption or lastConsoleCmdOption ~= options[i].id then
									if consoleCmdDlist then
										consoleCmdDlist = glDeleteList(consoleCmdDlist)
									end
									consoleCmdDlist = glCreateList(function()
										font:Begin()
										font:SetOutlineColor(0,0,0,0.4)
										font:SetTextColor(0.5, 0.5, 0.5, 0.27)
										font:Print('/option ' .. options[i].id, screenX + (8 * widgetScale), screenY - screenHeight + (11 * widgetScale), 14 * widgetScale, "n")
										font:End()
									end)
								end
								glCallList(consoleCmdDlist)
								lastConsoleCmdOption = options[i].id
							end
							-- highlight option
							UiSelectHighlight(o[1] - 4, o[2], o[3] + 4, o[4], nil, options[i].onclick and (ml and 0.35 or 0.22) or 0.14, options[i].onclick and { 0.5, 1, 0.25 })
							if WG.tooltip and options[i].description and options[i].description ~= '' and options[i].description ~= ' ' then
								local desc = options[i].description
								if options[i].restart then
									desc = desc..'\n\n\255\255\120\120'..Spring.I18N('ui.settings.changesrequirerestart')
								end
								local showTooltip = true
								if options[i].nametext and string.find(options[i].nametext, desc, nil, true) then
									if string.len(desc) == (string.len(options[i].nametext)+1)-string.find(options[i].nametext, desc, nil, true) then
										showTooltip = false
									end
								end
								if showTooltip then
									desc = font:WrapText(desc, WG['tooltip'].getFontsize() * 90)
									WG.tooltip.ShowTooltip('options_description', desc)--, nil, nil, optionColor..options[i].name)
								end
							end
							break
						end
					end
				end
			end

			-- draw select options
			if showSelectOptions ~= nil then

				-- highlight all that are affected by presets
				if options[showSelectOptions].id == 'preset' then
					for optionID, _ in pairs(presets.lowest) do
						local optionKey = getOptionByID(optionID)
						if optionHover[optionKey] ~= nil then
							RectRound(optionHover[optionKey][1], optionHover[optionKey][2] + 1, optionHover[optionKey][3], optionHover[optionKey][4] - 1, 1, 2, 2, 2, 2, { 0, 0, 0, 0.15 }, { 1, 1, 1, 0.15 })
						end
					end
				end

				local oHeight = optionButtons[showSelectOptions][4] - optionButtons[showSelectOptions][2]
				local oPadding = math.floor(4 * widgetScale)
				local y = optionButtons[showSelectOptions][4] - oPadding
				local yPos = y
				optionSelect = {}
				local i = 0
				for k, option in pairs(options[showSelectOptions].options) do
					i = i + 1
					yPos = y - (((oHeight + oPadding + oPadding) * i) - oPadding)
				end

				-- get max text option width
				local fontSize = oHeight * 0.85
				local maxWidth = optionButtons[showSelectOptions][3] - optionButtons[showSelectOptions][1]
				for i, option in pairs(options[showSelectOptions].options) do
					maxWidth = math.max(maxWidth, font:GetTextWidth(option .. '   ') * fontSize)
				end
				if selectOptionsList then
					if WG['guishader'] then
						WG['guishader'].removeRenderDlist(selectOptionsList)
					end
					glDeleteList(selectOptionsList)
				end
				selectOptionsList = glCreateList(function()
					local borderSize = math.max(1, math.floor(vsy / 900))
					RectRound(optionButtons[showSelectOptions][1] - borderSize, yPos - oHeight - oPadding - borderSize, optionButtons[showSelectOptions][1] + maxWidth + borderSize, optionButtons[showSelectOptions][2] + borderSize, (optionButtons[showSelectOptions][4] - optionButtons[showSelectOptions][2]) * 0.1, 1, 1, 1, 1, { 0, 0, 0, 0.25 }, { 0, 0, 0, 0.25 })
					RectRound(optionButtons[showSelectOptions][1], yPos - oHeight - oPadding, optionButtons[showSelectOptions][1] + maxWidth, optionButtons[showSelectOptions][2], (optionButtons[showSelectOptions][4] - optionButtons[showSelectOptions][2]) * 0.1, 1, 1, 1, 1, { 0.3, 0.3, 0.3, WG['guishader'] and 0.84 or 0.94 }, { 0.35, 0.35, 0.35, WG['guishader'] and 0.84 or 0.94 })
					UiSelector(optionButtons[showSelectOptions][1], optionButtons[showSelectOptions][2], optionButtons[showSelectOptions][3], optionButtons[showSelectOptions][4])

					local i = 0
					for k, option in pairs(options[showSelectOptions].options) do
						i = i + 1
						yPos = math.floor(y - (((oHeight + oPadding + oPadding) * i) - oPadding))
						optionSelect[#optionSelect + 1] = { math.floor(optionButtons[showSelectOptions][1]), math.floor(yPos - oHeight - oPadding), math.floor(optionButtons[showSelectOptions][1] + maxWidth), math.floor(yPos + oPadding) - 1, k }

						if math_isInRect(mx, my, optionSelect[#optionSelect][1], optionSelect[#optionSelect][2], optionSelect[#optionSelect][3], optionSelect[#optionSelect][4]) then
							UiSelectHighlight(optionButtons[showSelectOptions][1], math.floor(yPos - oHeight - oPadding), optionButtons[showSelectOptions][1] + maxWidth, math.floor(yPos + oPadding))
							if playSounds and (prevSelectHover == nil or prevSelectHover ~= i) then
								Spring.PlaySoundFile(sounds.selectHoverClick, 0.04, 'ui')
							end
							prevSelectHover = k
						end
						if options[showSelectOptions].optionsFont and fontOption and fontOption[i] then
							fontOption[i]:Begin()
							fontOption[i]:SetOutlineColor(0,0,0,0.4)
							fontOption[i]:Print(optionColor .. option, optionButtons[showSelectOptions][1] + 7, yPos - (oHeight / 2) - oPadding, fontSize, "no")
							fontOption[i]:End()
						else
							font:Begin()
							font:SetOutlineColor(0,0,0,0.4)
							font:Print(optionColor .. option, optionButtons[showSelectOptions][1] + 7, yPos - (oHeight / 2) - oPadding, fontSize, "no")
							font:End()
						end
					end
				end)
				if WG['guishader'] then
					WG['guishader'].InsertScreenRect(optionButtons[showSelectOptions][1], optionButtons[showSelectOptions][2], optionButtons[showSelectOptions][3], optionButtons[showSelectOptions][4], 'options_select')
					WG['guishader'].InsertScreenRect(optionButtons[showSelectOptions][1], yPos - oHeight - oPadding, optionButtons[showSelectOptions][1] + maxWidth, optionButtons[showSelectOptions][2], 'options_select_options')
					WG['guishader'].insertRenderDlist(selectOptionsList)
				else
					glCallList(selectOptionsList)
				end
			elseif prevSelectHover ~= nil then
				prevSelectHover = nil
			end
			if showTextInput then
				if not textInputDlist or inputText ~= prevInputText or updateTextInputDlist then
					prevInputText = inputText
					updateInputDlist()
				end
				if textInputDlist then
					glCallList(textInputDlist)
					drawChatInputCursor()
				elseif WG['guishader'] then
					WG['guishader'].RemoveRect('optionsinput')
					textInputDlist = glDeleteList(textInputDlist)
				end
			end
		else
			if WG['guishader'] then
				if backgroundGuishader then
					WG['guishader'].RemoveDlist('options')
					backgroundGuishader = glDeleteList(backgroundGuishader)
				end
				if textInputDlist then
					WG['guishader'].RemoveRect('optionsinput')
					textInputDlist = glDeleteList(textInputDlist)
				end
			end
		end
		if checkedWidgetDataChanges == nil then
			checkedWidgetDataChanges = true
			loadAllWidgetData()
		end
	end

	prevShow = show
end

function saveOptionValue(widgetName, widgetApiName, widgetApiFunction, configVar, configValue, widgetApiFunctionParam)
	-- if widgetApiFunctionParam not defined then it uses configValue
	if widgetHandler.configData[widgetName] == nil then
		widgetHandler.configData[widgetName] = {}
	end
	if widgetHandler.configData[widgetName][configVar[1]] == nil then
		widgetHandler.configData[widgetName][configVar[1]] = {}
	end
	if configVar[2] ~= nil and widgetHandler.configData[widgetName][configVar[1]][configVar[2]] == nil then
		widgetHandler.configData[widgetName][configVar[1]][configVar[2]] = {}
	end
	if configVar[2] ~= nil then
		if configVar[3] ~= nil then
			widgetHandler.configData[widgetName][configVar[1]][configVar[2]][configVar[3]] = configValue
		else
			widgetHandler.configData[widgetName][configVar[1]][configVar[2]] = configValue
		end
	else
		widgetHandler.configData[widgetName][configVar[1]] = configValue
	end
	if widgetApiName ~= nil and WG[widgetApiName] ~= nil and WG[widgetApiName][widgetApiFunction] ~= nil then
		if widgetApiFunctionParam ~= nil then
			WG[widgetApiName][widgetApiFunction](widgetApiFunctionParam)
		else
			WG[widgetApiName][widgetApiFunction](configValue)
		end
	end
end

function widget:KeyRelease()
	-- Since we grab the keyboard, we need to specify a KeyRelease to make sure other release actions can be triggered
	return false
end

function widget:KeyPress(key)
	if not show then
		return false
	end
	if key == 27 then	-- ESC
		if showTextInput and inputText ~= '' then
			clearChatInput()
			return true
		else
			if showSelectOptions then
				showSelectOptions = nil
			else
				show = false
				cancelChatInput()
			end
			if not guishaderedTabs then
				backgroundGuishader = glDeleteList(backgroundGuishader)
			end
		end
	end

	if key >= 282 and key <= 293 then	-- Function keys
		return false
	end

	if inputText == '' and guishaderedTabs then
		backgroundGuishader = glDeleteList(backgroundGuishader)
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
			init()
		end
	elseif key == 127 then -- DELETE
		if inputTextPosition < utf8.len(inputText) then
			inputText = utf8.sub(inputText, 1, inputTextPosition) .. utf8.sub(inputText, inputTextPosition+2)
		end
		cursorBlinkTimer = 0
		init()
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

function NearestValue(table, number)
	local smallestSoFar, smallestIndex
	for i, y in ipairs(table) do
		if not smallestSoFar or (math.abs(number - y) < smallestSoFar) then
			smallestSoFar = math.abs(number - y)
			smallestIndex = i
		end
	end
	return table[smallestIndex]
end

function getSliderValue(draggingSlider, mx)
	local sliderWidth = optionButtons[draggingSlider].sliderXpos[2] - optionButtons[draggingSlider].sliderXpos[1]
	local value = (mx - optionButtons[draggingSlider].sliderXpos[1]) / sliderWidth
	local min, max
	if options[draggingSlider].steps then
		min, max = options[draggingSlider].steps[1], options[draggingSlider].steps[1]
		for k, v in ipairs(options[draggingSlider].steps) do
			if v > max then
				max = v
			end
			if v < min then
				min = v
			end
		end
	else
		min = options[draggingSlider].min
		max = options[draggingSlider].max
	end
	value = min + ((max - min) * value)
	if value < min then
		value = min
	end
	if value > max then
		value = max
	end
	if options[draggingSlider].steps ~= nil then
		value = NearestValue(options[draggingSlider].steps, value)
	elseif options[draggingSlider].step ~= nil then
		value = math.floor((value + (options[draggingSlider].step / 2)) / options[draggingSlider].step) * options[draggingSlider].step
	end
	return value    -- is a string now :(
end

function widget:MouseWheel(up, value)
	local x, y = Spring.GetMouseState()
	if show then
		return true
	end
end

function widget:MouseMove(mx, my)
	if draggingSlider ~= nil then
		local newValue = getSliderValue(draggingSlider, mx)
		if options[draggingSlider].value ~= newValue then
			sliderValueChanged = true
			applyOptionValue(draggingSlider, newValue)    -- disabled so only on release it gets applied
			if playSounds and (lastSliderSound == nil or os_clock() - lastSliderSound > 0.04) then
				lastSliderSound = os_clock()
				Spring.PlaySoundFile(sounds.sliderDrag, 0.4, 'ui')
			end
		end
	end
end

function widget:MousePress(x, y, button)
	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end

function mouseEvent(mx, my, button, release)
	if Spring.IsGUIHidden() then
		return false
	end

	if show then
		local windowClick = (math_isInRect(mx, my, windowRect[1], windowRect[2], windowRect[3], windowRect[4]))
		local titleClick = (titleRect and math_isInRect(mx, my, titleRect[1], titleRect[2], titleRect[3], titleRect[4]))
		local chatinputClick = (chatInputArea and math_isInRect(mx, my, chatInputArea[1], chatInputArea[2], chatInputArea[3], chatInputArea[4]))
		local tabClick
		if not (inputText and inputText ~= '' and inputMode == '') and groupRect ~= nil then
			for id, group in pairs(optionGroups) do
				if group.numOptions > 0 then
					if devMode or devUI or group.id ~= 'dev' then
						if math_isInRect(mx, my, groupRect[id][1], groupRect[id][2], groupRect[id][3], groupRect[id][4]) then
							if not release then
								currentGroupTab = group.id
								startColumn = 1
								showSelectOptions = nil
								selectClickAllowHide = nil
								if playSounds then
									Spring.PlaySoundFile(sounds.paginatorClick, 0.9, 'ui')
								end
							end
							tabClick = true
						end
					end
				end
			end
		end

		if button == 1 then
			if release then
				if not (devMode or devUI) and titleClick then
					advSettings = not advSettings
					startColumn = 1
				end
				-- navigation buttons
				if optionButtonForward ~= nil and math_isInRect(mx, my, optionButtonForward[1], optionButtonForward[2], optionButtonForward[3], optionButtonForward[4]) then
					startColumn = startColumn + maxShownColumns
					if startColumn > totalColumns + (maxShownColumns - 1) then
						startColumn = (totalColumns - maxShownColumns) + 1
					end
					if playSounds then
						Spring.PlaySoundFile(sounds.paginatorClick, 0.6, 'ui')
					end
					showSelectOptions = nil
					selectClickAllowHide = nil
				end
				if optionButtonBackward ~= nil and math_isInRect(mx, my, optionButtonBackward[1], optionButtonBackward[2], optionButtonBackward[3], optionButtonBackward[4]) then
					startColumn = startColumn - maxShownColumns
					if startColumn < 1 then
						startColumn = 1
					end
					if playSounds then
						Spring.PlaySoundFile(sounds.paginatorClick, 0.6, 'ui')
					end
					showSelectOptions = nil
					selectClickAllowHide = nil
				end

				-- apply new slider value
				if draggingSlider ~= nil then
					applyOptionValue(draggingSlider, getSliderValue(draggingSlider, mx))
					draggingSlider = nil
					draggingSliderPreDragValue = nil
					return
				end

				-- select option
				if showSelectOptions ~= nil then
					for i, o in pairs(optionSelect) do
						if math_isInRect(mx, my, o[1], o[2], o[3], o[4]) then
							applyOptionValue(showSelectOptions, o[5])
							if playSounds then
								Spring.PlaySoundFile(sounds.selectClick, 0.5, 'ui')
							end
						end
					end
					if selectClickAllowHide ~= nil or not math_isInRect(mx, my, optionButtons[showSelectOptions][1], optionButtons[showSelectOptions][2], optionButtons[showSelectOptions][3], optionButtons[showSelectOptions][4]) then
						showSelectOptions = nil
						selectClickAllowHide = nil
					else
						selectClickAllowHide = true
					end
					return
				end
			end

			if not tabClick and windowClick then
				-- on window
				if release then
					-- select option
					if showSelectOptions == nil then
						if optionButtons then
							for i, o in pairs(optionButtons) do

								if options[i].type == 'bool' and math_isInRect(mx, my, o[1], o[2], o[3], o[4]) then
									applyOptionValue(i, not options[i].value)
									if playSounds then
										if options[i].value then
											Spring.PlaySoundFile(sounds.toggleOnClick, 0.75, 'ui')
										else
											Spring.PlaySoundFile(sounds.toggleOffClick, 0.75, 'ui')
										end
									end
								elseif options[i].type == 'slider' and math_isInRect(mx, my, o[1], o[2], o[3], o[4]) then

								elseif options[i].type == 'select' and math_isInRect(mx, my, o[1], o[2], o[3], o[4]) then

								elseif optionHover[i] and options[i].onclick ~= nil and math_isInRect(mx, my, optionHover[i][1], optionHover[i][2], optionHover[i][3], optionHover[i][4]) then
									options[i].onclick(i)
								end
							end
						end

					end
				else	-- press
					if not showSelectOptions then
						for i, o in pairs(optionButtons) do
							if options[i].type == 'slider' and (math_isInRect(mx, my, o.sliderXpos[1], o[2], o.sliderXpos[2], o[4]) or math_isInRect(mx, my, o[1], o[2], o[3], o[4])) then
								draggingSlider = i
								draggingSliderPreDragValue = options[draggingSlider].value
								local newValue = getSliderValue(draggingSlider, mx)
								if options[draggingSlider].value ~= newValue then
									applyOptionValue(draggingSlider, getSliderValue(draggingSlider, mx))    -- disabled so only on release it gets applied
									if playSounds then
										Spring.PlaySoundFile(sounds.sliderDrag, 0.3, 'ui')
									end
								end
							elseif options[i].type == 'select' and math_isInRect(mx, my, o[1], o[2], o[3], o[4]) then

								if playSounds then
									Spring.PlaySoundFile(sounds.selectUnfoldClick, 0.6, 'ui')
								end
								if showSelectOptions == nil then
									showSelectOptions = i
								elseif showSelectOptions == i then
									--showSelectOptions = nil
								end
							end
						end
					end
				end
			end
		end


		if windowList then
			gl.DeleteList(windowList)
		end
		windowList = gl.CreateList(DrawWindow)

		if windowClick or titleClick or chatinputClick or tabClick then
			return true
		elseif not tabClick then
			if release and draggingSlider == nil then
				showOnceMore = true        -- show once more because the guishader lags behind, though this will not fully fix it
				show = false
				cancelChatInput()
			end
			return true
		end
	end
end

function GetWidgetToggleValue(widgetname)
	if widgetHandler.orderList[widgetname] == nil or widgetHandler.orderList[widgetname] == 0 then
		return false
	elseif widgetHandler.orderList[widgetname] >= 1
		and widgetHandler.knownWidgets ~= nil
		and widgetHandler.knownWidgets[widgetname] ~= nil then
		if widgetHandler.knownWidgets[widgetname].active then
			return true
		else
			return 0.5
		end
	end
end

-- configVar = table, add more entries the deeper the configdata table var is: example: {'Config','console','maxlines'}  (limit = 3 deep)
function loadWidgetData(widgetName, optionId, configVar)
	local optionID = getOptionByID(optionId)
	if optionID and widgetHandler.configData[widgetName] ~= nil and widgetHandler.configData[widgetName][configVar[1]] ~= nil then
		if configVar[2] ~= nil and widgetHandler.configData[widgetName][configVar[1]][configVar[2]] ~= nil then
			if configVar[3] ~= nil and widgetHandler.configData[widgetName][configVar[1]][configVar[2]][configVar[3]] ~= nil then
				options[optionID].value = widgetHandler.configData[widgetName][configVar[1]][configVar[2]][configVar[3]]
				return true
			else
				options[optionID].value = widgetHandler.configData[widgetName][configVar[1]][configVar[2]]
				return true
			end
		elseif options[optionID].value ~= widgetHandler.configData[widgetName][configVar[1]] then
			options[optionID].value = widgetHandler.configData[widgetName][configVar[1]]
			return true
		end
	end
end

function checkRequireRestart()
	changesRequireRestart = false
	for id, value in pairs(requireRestartDefaults) do
		local i = getOptionByID(id)
		if options[i] and options[i].value ~= value then
			changesRequireRestart = true
		end
	end
end

function applyOptionValue(i, newValue, skipRedrawWindow, force)
	if options[i] == nil then
		return
	end

	local id = options[i].id

	if newValue ~= nil then
		options[i].value = newValue
	end

	if options[i].restart and requireRestartDefaults[id] ~= nil then
		checkRequireRestart()
	end

	if options[i].id ~= 'preset' and presets.lowest[options[i].id] ~= nil and manualChange then
		if options[getOptionByID('preset')] then
			options[getOptionByID('preset')].value = Spring.I18N('ui.settings.option.preset_custom')
			Spring.SetConfigString('graphicsPreset', 'custom')
		end
	end

	if options[i].widget ~= nil and widgetHandler.orderList[options[i].widget] ~= nil then
		if options[i].value then
			if widgetHandler.orderList[options[i].widget] < 0.5 then
				widgetHandler:EnableWidget(options[i].widget)
			end
		else
			if widgetHandler.orderList[options[i].widget] > 0 then
				widgetHandler:ToggleWidget(options[i].widget)
			else
				widgetHandler:DisableWidget(options[i].widget)
			end
		end
		forceUpdate = true
		if id == "teamcolors" then
			Spring.SendCommands("luarules reloadluaui")    -- cause several widgets are still using old colors
		end
	end

	if options[i].onchange then
		options[i].onchange(i, options[i].value, force)
	end

	if skipRedrawWindow == nil then
		if windowList then
			gl.DeleteList(windowList)
		end
		windowList = gl.CreateList(DrawWindow)
	end
end

-- loads values via stored game config in luaui/configs
function loadAllWidgetData()
	for i, option in pairs(options) do
		if option.onload then
			option.onload(i)
		end
	end
end

function init()
	presets = {
		lowest = {
			bloomdeferred = false,
			bloomdeferred_quality = 1,
			ssao = false,
			ssao_quality = 1,
			mapedgeextension = false,
			lighteffects = false,
			lighteffects_additionalflashes = false,
			lighteffects_screenspaceshadows = 0,
			distortioneffects = false,
			snow = false,
			particles = 10000,
			guishader = 0,
			decalsgl4 = 0,
			decals = 0,
			shadowslider = 1,
			grass = false,
			cusgl4 = false,
			losrange = false,
			attackrange_numrangesmult = 0.3,
		},
		low = {
			bloomdeferred = true,
			bloomdeferred_quality = 1,
			ssao = false,
			ssao_quality = 1,
			mapedgeextension = false,
			lighteffects = true,
			lighteffects_additionalflashes = false,
			lighteffects_screenspaceshadows = 1,
			distortioneffects = true,
			snow = false,
			particles = 15000,
			guishader = 0,
			decalsgl4 = 1,
			decals = 1,
			shadowslider = 3,
			grass = false,
			cusgl4 = true,
			losrange = false,
			attackrange_numrangesmult = 0.5,
		},
		medium = {
		 	bloomdeferred = true,
			bloomdeferred_quality = 1,
		 	ssao = true,
			ssao_quality = 2,
		 	mapedgeextension = true,
		 	lighteffects = true,
		 	lighteffects_additionalflashes = true,
			 lighteffects_screenspaceshadows = 2,
			distortioneffects = true,
		 	snow = true,
		 	particles = 20000,
			decalsgl4 = 1,
		 	decals = 2,
			shadowslider = 4,
		 	grass = true,
			cusgl4 = true,
			losrange = true,
			attackrange_numrangesmult = 0.7,
		},
		high = {
			bloomdeferred = true,
			bloomdeferred_quality = 2,
			ssao = true,
			ssao_quality = 2,
			mapedgeextension = true,
			lighteffects = true,
			lighteffects_additionalflashes = true,
			lighteffects_screenspaceshadows = 3,
			distortioneffects = true,
			snow = true,
			particles = 30000,
			decalsgl4 = 1,
			decals = 3,
			shadowslider = 5,
			grass = true,
			cusgl4 = true,
			losrange = true,
			attackrange_numrangesmult = 0.9,
		},
		ultra = {
			bloomdeferred = true,
			bloomdeferred_quality = 3,
			ssao = true,
			ssao_quality = 3,
			mapedgeextension = true,
			lighteffects = true,
			lighteffects_additionalflashes = true,
			lighteffects_screenspaceshadows = 4,
			distortioneffects = true,
			snow = true,
			particles = 40000,
			decalsgl4 = 1,
			decals = 4,
			shadowslider = 6,
			grass = true,
			cusgl4 = true,
			losrange = true,
			attackrange_numrangesmult = 1,
		},
		custom = {},
	}

	local screenModes = WG['screenMode'] and WG['screenMode'].GetScreenModes() or {}
	local displays = WG['screenMode'] and WG['screenMode'].GetDisplays() or {}

	local currentDisplay = 1
	local v_sx, v_sy, v_px, v_py = Spring.GetViewGeometry()
	local displayNames = {}
	local hasMultiDisplayOption = false
	for index, display in ipairs(displays) do
		if display.width > 0 then
			displayNames[index] = index..":  "..display.name .. " " .. display.width .. " × " .. display.height .. "  (" .. display.hz.."hz)"
			if v_px >= display.x and v_px < display.x + display.width and v_py >= display.y and v_py < display.y + display.height then
				currentDisplay = index
			end
		elseif devMode or devUI then -- advSettings
			displayNames[index] = display.name
			hasMultiDisplayOption = true
		end
	end
	local selectedDisplay = currentDisplay

	local resolutionNames = {}
	local screenmodeOffset = 0
	for _, screenMode in ipairs(screenModes) do
		if screenMode.display == currentDisplay then
			resolutionNames[#resolutionNames+1] = screenMode.name
		elseif #resolutionNames == 0 then
			screenmodeOffset = screenmodeOffset + 1
		end
	end

	-- only allow dualscreen-mode on single displays when super ultrawide screen or Multi Display option shows
	if (#displayNames <= 1 and vsx / vsy < 2.5) or (#displayNames > 1 and #displayNames == Spring.GetNumDisplays()) then
		if Spring.GetConfigInt("DualScreenMode", 0) ~= 0 then
			Spring.SetConfigInt("DualScreenMode", 0)
		end
	end

	local soundDevices = { 'default' }
	local soundDevicesByName = { [''] = 1 }
	local infolog = VFS.LoadFile("infolog.txt")
	if infolog then
		local fileLines = string.lines(infolog)
		for i, line in ipairs(fileLines) do
			if string.find(line, '     [', nil, true) then
				local device = string.sub(string.match(line, '     %[([0-9a-zA-Z _%/%%-%(%)]*)'), 1)
				soundDevices[#soundDevices + 1] = device
				soundDevicesByName[device] = #soundDevices
			end
			-- scan for shader version error
			if string.find(line, 'error: GLSL 1.50 is not supported', nil, true) then
				Spring.SetConfigInt("LuaShaders", 0)
			end

			-- look for system hardware
			if string.find(line, 'Physical CPU Cores', nil, true) then
				if tonumber(string.match(line, '([0-9].*)')) and tonumber(string.match(line, '([0-9].*)')) <= 2 then
					isPotatoCpu = true
				end
			end

			if string.find(line, 'Logical CPU Cores', nil, true) then
				if tonumber(string.match(line, '([0-9].*)')) and tonumber(string.match(line, '([0-9].*)')) <= 2 then
					isPotatoCpu = true
				end
			end

			if string.find(line:lower(), 'hardware config: ', nil, true) then
				local s_ram = string.match(line, '([0-9]*MB RAM)')
				if s_ram ~= nil then
					s_ram = string.gsub(s_ram, " RAM", "")
					if tonumber(s_ram) and tonumber(s_ram) > 0 and tonumber(s_ram) < 6500 then
						isPotatoCpu = true
					end
				end
			end

			if string.find(line, "Loading widget:", nil, true) then
				break
			end
		end
	end

	-- restrict options for potato systems
	if isPotatoCpu or isPotatoGpu then
		if isPotatoCpu then
			Spring.Echo('potato CPU detected')
		end
		if isPotatoGpu then
			Spring.Echo('potato Graphics Card detected')
		end
		presetNames = {
			Spring.I18N('ui.settings.option.preset_lowest'),
			Spring.I18N('ui.settings.option.preset_low'),
			Spring.I18N('ui.settings.option.preset_medium'),
			Spring.I18N('ui.settings.option.preset_custom')
		}
	end

	-- if you want to add an option it should be added here, and in applyOptionValue(), if option needs shaders than see the code below the options definition
	optionGroups = {
		{ id = 'gfx', name = Spring.I18N('ui.settings.group.graphics'), numOptions = 0 },
		{ id = 'ui', name = Spring.I18N('ui.settings.group.interface'), numOptions = 0 },
		{ id = 'game', name = Spring.I18N('ui.settings.group.game'), numOptions = 0 },
		{ id = 'control', name = Spring.I18N('ui.settings.group.control'), numOptions = 0 },
		{ id = 'sound', name = Spring.I18N('ui.settings.group.audio'), numOptions = 0 },
		{ id = 'notif', name = Spring.I18N('ui.settings.group.notifications'), numOptions = 0 },
		{ id = 'accessibility', name = Spring.I18N('ui.settings.group.accessibility'), numOptions = 0 },
		{ id = 'custom', name = Spring.I18N('ui.settings.group.custom'), numOptions = 0 },
		{ id = 'dev', name = Spring.I18N('ui.settings.group.dev'), numOptions = 0 },
	}

	if not currentGroupTab then
		currentGroupTab = optionGroups[1].id
	else
		-- check if group exists
		local found = false
		for id, group in pairs(optionGroups) do
			if group.id == currentGroupTab then
				found = true
				break
			end
		end
		if not found then
			currentGroupTab = optionGroups[1].id
		end
	end

	local oldValues = {}
	for _, option in ipairs(options) do
		oldValues[option.id] = option.value
	end

	options = {
		--GFX
		{ id = "preset", group = "gfx", category = types.basic, name = Spring.I18N('ui.settings.option.preset'), type = "select", options = { Spring.I18N('ui.settings.option.select_lowest'), Spring.I18N('ui.settings.option.select_low'), Spring.I18N('ui.settings.option.select_medium'), Spring.I18N('ui.settings.option.select_high'), Spring.I18N('ui.settings.option.select_ultra'), Spring.I18N('ui.settings.option.select_custom') },
			onload = function(i)
				local preset = Spring.GetConfigString('graphicsPreset', 'custom')
				local configSettingValues = { 'lowest', 'low', 'medium', 'high', 'ultra', 'custom' }
				for k, value in pairs(configSettingValues) do
					if value == preset then
						options[i].value = k
						break
					end
				end
			end,
			onchange = function(i, value)
				local configSetting = 'custom'
				local configSettingValues = { 'lowest', 'low', 'medium', 'high', 'ultra', 'custom' }
				configSetting = configSettingValues[value]
				Spring.SetConfigString('graphicsPreset', configSetting)
				if configSetting == 'custom' then return end

				Spring.Echo('Loading preset:   ' .. options[i].options[value])
				manualChange = false
				for optionID, value in pairs(presets[configSetting]) do
					local i = getOptionByID(optionID)
					if options[i] ~= nil then
						applyOptionValue(i, value, true)
					end
				end

				if windowList then
					gl.DeleteList(windowList)
				end
				windowList = gl.CreateList(DrawWindow)
				manualChange = true
			end,
		},
		{ id = "label_gfx_screen", group = "gfx", name = Spring.I18N('ui.settings.option.label_screen'), category = types.basic },
		{ id = "label_gfx_screen_spacer", group = "gfx", category = types.basic },
		{ id = "display", group = "gfx", category = types.basic, name = Spring.I18N('ui.settings.option.display'), type = "select", options = displayNames, value = currentDisplay,
			onchange = function(i, value)
				--currentDisplay = value
				selectedDisplay = value
				Spring.SetConfigInt('SelectedDisplay', value)
				resolutionNames = {}
				screenmodeOffset = 0
				for _, screenMode in ipairs(screenModes) do
					if screenMode.display == selectedDisplay then
						resolutionNames[#resolutionNames+1] = screenMode.name
					elseif #resolutionNames == 0 then
						screenmodeOffset = screenmodeOffset + 1
					end
				end
				options[getOptionByID('resolution')].options = resolutionNames
				if selectedDisplay == currentDisplay then
					options[getOptionByID('resolution')].value = Spring.GetConfigInt('SelectedScreenMode', 1)
				else
					options[getOptionByID('resolution')].value = 0
				end
				forceUpdate = true
			end,
		},
		{ id = "resolution", group = "gfx", category = types.basic, name = widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.resolution'), type = "select", options = resolutionNames, value = Spring.GetConfigInt('SelectedScreenMode', 1), description = Spring.I18N('ui.settings.option.resolution_descr'),
		  	onload = function(i, value)
				-- FIXME: disabled for now due to "Now whenever i do fullscreen or borderless the game will go to monitor 2 regardless of the chosen option. (I want the game on monitor 1)."
				--if Spring.GetConfigInt('SelectedScreenMode', -1) >= 1 then		-- chobby sets SelectedScreenMode to -1 when it changes game window mode
				--	WG['screenMode'].SetScreenMode(Spring.GetConfigInt('SelectedScreenMode', 1))
				--end
			end,
			onchange = function(i, value)
				Spring.SetConfigInt('SelectedScreenMode', value)

				if WG['screenMode'] then
					WG['screenMode'].SetScreenMode(value+screenmodeOffset)
					currentDisplay = 1
					local v_sx, v_sy, v_px, v_py = Spring.GetViewGeometry()
					for index, display in ipairs(displays) do
						if v_px >= display.x and v_px < display.x + display.width and v_py >= display.y and v_py < display.y + display.height then
							currentDisplay = index
						end
					end
				end
			end,
		},
		{ id = "dualmode_enabled", group = "gfx", category = types.dev, name = Spring.I18N('ui.settings.option.dualmode'), type = "bool", value = Spring.GetConfigInt("DualScreenMode"), description = Spring.I18N('ui.settings.option.dualmode_enabled_descr'),
		  onchange = function(_, value)
			  Spring.SetConfigInt("DualScreenMode", value and 1 or 0)
		  end,
		},
		{ id = "dualmode_left", group = "gfx", category = types.dev, name = widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.dualmode_left'), type = "bool", value = Spring.GetConfigInt("DualScreenMiniMapOnLeft"), description = Spring.I18N('ui.settings.option.dualmode_left_descr'),
		  onchange = function(_, value)
			  Spring.SetConfigInt("DualScreenMiniMapOnLeft", value and 1 or 0)
		  end,
		},
		{ id = "dualmode_minimap_aspectratio", group = "gfx", category = types.dev, name = widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.dualmode_minimap_aspectratio'), type = "bool", value = Spring.GetConfigInt("DualScreenMiniMapAspectRatio"), description = Spring.I18N('ui.settings.option.dualmode_minimap_aspectratio_descr'),
		  onchange = function(_, value)
			  Spring.SetConfigInt("DualScreenMiniMapAspectRatio", value and 1 or 0)
		  end,
		},
		{ id = "vsync", group = "gfx", category = types.basic, name = Spring.I18N('ui.settings.option.vsync'),  type = "select", options = { Spring.I18N('ui.settings.option.select_off'), Spring.I18N('ui.settings.option.select_enabled'), Spring.I18N('ui.settings.option.select_adaptive')}, value = 2, description = Spring.I18N('ui.settings.option.vsync_descr'),
		  onload = function(i)
			  local vsync = Spring.GetConfigInt("VSyncGame", -1)
			  if vsync > 0 then
			  	options[i].value = 2
			  elseif vsync < 0 then
			  	options[i].value = 3
			  else
				options[i].value = 1
			  end
		  end,
		  onchange = function(i, value)
			  local vsync = 0
			  if value == 2 then
				  vsync = Spring.GetConfigInt("VSyncFraction", 1)
			  elseif value == 3 then
				  vsync = -Spring.GetConfigInt("VSyncFraction", 1)
			  end
			  Spring.SetConfigInt("VSync", vsync)
			  Spring.SetConfigInt("VSyncGame", vsync)    -- stored here as assurance cause lobby/game also changes vsync when idle and lobby could think game has set vsync 4 after a hard crash
		  end,
		},
		{ id = "vsync_fraction", group = "gfx", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.vsync_fraction'), min = 1, max = 4, step = 1, type = "slider", value = Spring.GetConfigInt("VSyncFraction", 1), description = Spring.I18N('ui.settings.option.vsync_fraction_descr'),
		  onchange = function(i, value)
			Spring.SetConfigInt("VSyncFraction", value)
			local vsync = Spring.GetConfigInt("VSyncGame", -1)
			if vsync ~= 0 then
				Spring.SetConfigInt("VSync", vsync*value)
			end
		  end,
		},

		{ id = "limitoffscreenfps", group = "gfx", category = types.advanced, widget = "Limit idle FPS", name = Spring.I18N('ui.settings.option.limitoffscreenfps'), type = "bool", value = GetWidgetToggleValue("Limit idle FPS"), description = Spring.I18N('ui.settings.option.limitoffscreenfps_descr') },
		{ id = "limitidlefps", group = "gfx", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.limitidlefps'), type = "bool", value = (Spring.GetConfigInt("LimitIdleFps", 0) == 1), description = Spring.I18N('ui.settings.option.limitidlefps_descr'),
		  onchange = function(i, value)
			  Spring.SetConfigInt("LimitIdleFps", (value and 1 or 0))
		  end,
		},

		{ id = "msaa", group = "gfx", category = types.basic, name = Spring.I18N('ui.settings.option.msaa'), type = "select", options = { Spring.I18N('ui.settings.option.select_off'), 'x2', 'x4', 'x8'}, restart = true, value = tonumber(Spring.GetConfigInt("MSAALevel", 0) or 0), description = Spring.I18N('ui.settings.option.msaa_descr'),
		  onload = function(i)
			  local msaa = tonumber(Spring.GetConfigInt("MSAALevel", 0) or 0)
			  if msaa <= 0 then
				  options[getOptionByID('msaa')].value = 1
			  else
				  for k,v in ipairs( options[getOptionByID('msaa')].options) do
					  if v == 'x'..msaa then
						  options[getOptionByID('msaa')].value = k
						  break
					  end
				  end
			  end
		  end,
		  onchange = function(i, value)
			  if value == 1 then
				  Spring.SetConfigInt("MSAA", 0)
				  Spring.SetConfigInt("MSAALevel", -1)	-- setting 0 will reset it to default x4 :(
			  else
				  Spring.SetConfigInt("MSAA", 1)
				  Spring.SetConfigInt("MSAALevel", tonumber(string.sub(options[getOptionByID('msaa')].options[value], 2)))
			  end
		  end,
		},

		{ id = "supersampling", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.supersampling'), type = "bool", restart = false, value = (Spring.GetConfigFloat("MinSampleShadingRate", 0.0) == 1.0), description = Spring.I18N('ui.settings.option.supersampling_descr'),
		  onchange = function(i, value)
			Spring.SetConfigFloat("MinSampleShadingRate", (value and 1.0 or 0.0))
		  end,
		},

		{ id = "cas_sharpness", group = "gfx", category = types.advanced, name = Spring.I18N('ui.settings.option.cas_sharpness'), min = 0.5, max = 1.1, step = 0.01, type = "slider", value = 1.0, description = Spring.I18N('ui.settings.option.cas_sharpness_descr'),
		  onload = function(i)
			  loadWidgetData("Contrast Adaptive Sharpen", "cas_sharpness", { 'SHARPNESS' })
		  end,
		  onchange = function(i, value)
			  if not GetWidgetToggleValue("Contrast Adaptive Sharpen") then
				  widgetHandler:EnableWidget("Contrast Adaptive Sharpen")
			  end
			  saveOptionValue('Contrast Adaptive Sharpen', 'cas', 'setSharpness', { 'SHARPNESS' }, options[getOptionByID('cas_sharpness')].value)
		  end,
		},

		{ id = "sepiatone", group = "gfx", category = types.advanced, widget = "Sepia Tone", name = Spring.I18N('ui.settings.option.sepiatone'), type = "bool", value = GetWidgetToggleValue("Sepia Tone") },
		{ id = "sepiatone_gamma", group = "gfx", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.sepiatone_gamma'), min = 0.1, max = 0.9, step = 0.02, type = "slider", value = 0.5,
		  onload = function(i)
			  loadWidgetData("Sepia Tone", "sepiatone_gamma", { 'gamma' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Sepia Tone', 'sepia', 'setGamma', { 'gamma' }, value)
		  end,
		},
		{ id = "sepiatone_saturation", group = "gfx", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.sepiatone_saturation'), min = 0, max = 1, step = 0.02, type = "slider", value = 0.5,
		  onload = function(i)
			  loadWidgetData("Sepia Tone", "sepiatone_saturation", { 'saturation' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Sepia Tone', 'sepia', 'setSaturation', { 'saturation' }, value)
		  end,
		},
		{ id = "sepiatone_contrast", group = "gfx", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.sepiatone_contrast'), min = 0.1, max = 0.9, step = 0.02, type = "slider", value = 0.5,
		  onload = function(i)
			  loadWidgetData("Sepia Tone", "sepiatone_contrast", { 'contrast' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Sepia Tone', 'sepia', 'setContrast', { 'contrast' }, value)
		  end,
		},
		{ id = "sepiatone_sepia", group = "gfx", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.sepiatone_sepia'), min = 0, max = 0.5, step = 0.02, type = "slider", value = 0.5, description = Spring.I18N('ui.settings.option.sepiatone_sepia_descr'),
		  onload = function(i)
			  loadWidgetData("Sepia Tone", "sepiatone_sepia", { 'sepia' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Sepia Tone', 'sepia', 'setSepia', { 'sepia' }, value)
		  end,
		},
		{ id = "sepiatone_shadeui", group = "gfx", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.sepiatone_shadeui'), type = "bool", value = 0,
		  onload = function(i)
			  loadWidgetData("Sepia Tone", "sepiatone_shadeui", { 'shadeUI' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Sepia Tone', 'sepia', 'setShadeUI', { 'shadeUI' }, value)
		  end,
		},


		{ id = "label_gfx_lighting", group = "gfx", name = Spring.I18N('ui.settings.option.label_lighting'), category = types.basic },
		{ id = "label_gfx_lighting_spacer", group = "gfx", category = types.basic },


		--{ id = "advmapshading", group = "gfx", category = types.dev, name = Spring.I18N('ui.settings.option.advmapshading'), type = "bool", value = (Spring.GetConfigInt("AdvMapShading", 1) == 1), description = Spring.I18N('ui.settings.option.advmapshading_descr'),
		--  onchange = function(i, value)
		--	  Spring.SetConfigInt("AdvMapShading", (value and 1 or 0))
		--	  Spring.SendCommands("advmapshading "..(value and '1' or '0'))
		--  end,
		--},

		-- luaintro sets grounddetail to 200 every launch anyway
		--{ id = "grounddetail", group = "gfx", category = types.dev, name = Spring.I18N('ui.settings.option.grounddetail'), type = "slider", min = 50, max = 200, step = 1, value = tonumber(Spring.GetConfigInt("GroundDetail", 150) or 150), description = Spring.I18N('ui.settings.option.grounddetail_descr'),
		--  onload = function(i)
		--  end,
		--  onchange = function(i, value)
		--	  Spring.SetConfigInt("GroundDetail", value)
		--	  Spring.SendCommands("GroundDetail " .. value)
		--  end,
		--},

		{ id = "cusgl4", group = "gfx", name = Spring.I18N('ui.settings.option.cus'), category = types.advanced, type = "bool", value = (Spring.GetConfigInt("cus2", 1) == 1), description = Spring.I18N('ui.settings.option.cus_descr'),
		  onchange = function(i, value)
			  if value == 0.5 then
				  Spring.SendCommands("luarules disablecusgl4")
			  else
				  Spring.SetConfigInt("cus2", (value and 1 or 0))
				  Spring.SendCommands("luarules "..(value and 'reloadcusgl4' or 'disablecusgl4'))
			  end
		  end,
		},

		{ id = "shadowslider", group = "gfx", category = types.basic, name = Spring.I18N('ui.settings.option.shadowslider'), type = "select", options = { Spring.I18N('ui.settings.option.select_off'), Spring.I18N('ui.settings.option.select_lowest'), Spring.I18N('ui.settings.option.select_low'), Spring.I18N('ui.settings.option.select_medium'), Spring.I18N('ui.settings.option.select_high'), Spring.I18N('ui.settings.option.select_ultra')}, value = Spring.GetConfigInt("ShadowQuality", 3)+1, description = Spring.I18N('ui.settings.option.shadowslider_descr'),
		  onchange = function(i, value)
			  Spring.SetConfigInt("ShadowQuality", value - 1)
			  adjustShadowQuality()
		  end,
		},

		{ id = "shadows_opacity", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.shadows_opacity'), type = "slider", min = 0.3, max = 1, step = 0.01, value = gl.GetSun("shadowDensity"), description = '',
		  onchange = function(i, value)
			  Spring.SetSunLighting({ groundShadowDensity = value, modelShadowDensity = value })
		  end,
		},

		{ id = "ssao", group = "gfx", category = types.basic, widget = "SSAO", name = Spring.I18N('ui.settings.option.ssao'), type = "bool", value = GetWidgetToggleValue("SSAO"), description = Spring.I18N('ui.settings.option.ssao_descr') },
		{ id = "ssao_strength", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.ssao_strength'), type = "slider", min = 5, max = 11, step = 1, value = 8, description = '',
		  onload = function(i)
			  loadWidgetData("SSAO", "ssao_strength", { 'strength' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('SSAO', 'ssao', 'setStrength', { 'strength' }, value)
		  end,
		},
		{ id = "ssao_quality", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.ssao_quality'), type = "select", options = { Spring.I18N('ui.settings.option.select_low'), Spring.I18N('ui.settings.option.select_medium'), Spring.I18N('ui.settings.option.select_high')}, value = (WG['ssao'] ~= nil and WG['ssao'].getPreset() or 2), description = Spring.I18N('ui.settings.option.ssao_quality_descr'),
		  onload = function(i)
			  if widgetHandler.configData["SSAO"] ~= nil and widgetHandler.configData["SSAO"].preset ~= nil then
				  options[getOptionByID('ssao_quality')].value = widgetHandler.configData["SSAO"].preset
			  end
		  end,
		  onchange = function(i, value)
			  saveOptionValue('SSAO', 'ssao', 'setPreset', { 'preset' }, value)
		  end,
		},

		{ id = "bloomdeferred", group = "gfx", category = types.basic, widget = "Bloom Shader Deferred", name = Spring.I18N('ui.settings.option.bloomdeferred'), type = "bool", value = GetWidgetToggleValue("Bloom Shader Deferred"), description = Spring.I18N('ui.settings.option.bloomdeferred_descr') },
		{ id = "bloomdeferredbrightness", group = "gfx", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.bloomdeferredbrightness'), type = "slider", min = 0.4, max = 1.4, step = 0.05, value = 0.9, description = '',
		  onload = function(i)
			  loadWidgetData("Bloom Shader Deferred", "bloomdeferredbrightness", { 'glowAmplifier' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Bloom Shader Deferred', 'bloomdeferred', 'setBrightness', { 'glowAmplifier' }, value)
		  end,
		},
		{ id = "bloomdeferred_quality", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.bloomdeferred_quality'), type = "select", options = { Spring.I18N('ui.settings.option.select_low'), Spring.I18N('ui.settings.option.select_medium'), Spring.I18N('ui.settings.option.select_high')}, value = (WG['bloomdeferred'] ~= nil and WG['bloomdeferred'].getPreset() or 2), description = Spring.I18N('ui.settings.option.bloomdeferred_quality_descr'),
		  onload = function(i)
			  if widgetHandler.configData["Bloom Shader Deferred"] ~= nil and widgetHandler.configData["Bloom Shader Deferred"].preset ~= nil then
				  options[getOptionByID('bloomdeferred_quality')].value = widgetHandler.configData["Bloom Shader Deferred"].preset
			  end
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Bloom Shader Deferred', 'bloomdeferred', 'setPreset', { 'preset' }, value)
		  end,
		},

		{ id = "lighteffects", group = "gfx", category = types.basic, name = Spring.I18N('ui.settings.option.lighteffects'), type = "bool", value = GetWidgetToggleValue("Deferred rendering GL4"), description = Spring.I18N('ui.settings.option.lighteffects_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  if value then
				  widgetHandler:EnableWidget("Deferred rendering GL4")
			  else
				  widgetHandler:DisableWidget("Deferred rendering GL4")
			  end
		  end,
		},
		{ id = "lighteffects_headlights", group = "gfx", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.lighteffects_headlights'), type = "bool", value = Spring.GetConfigInt("headlights", 1) == 1, description = Spring.I18N('ui.settings.option.lighteffects_headlights_descr'),
		  onchange = function(i, value)
			  Spring.SetConfigInt("headlights", value and 1 or 0)
			  if widgetHandler.orderList["Deferred rendering GL4"] ~= nil then
				  widgetHandler:DisableWidget("Deferred rendering GL4")
				  widgetHandler:EnableWidget("Deferred rendering GL4")
			  end
		  end,
		},
		{ id = "lighteffects_buildlights", group = "gfx", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.lighteffects_buildlights'), type = "bool", value = Spring.GetConfigInt("buildlights", 1) == 1, description = Spring.I18N('ui.settings.option.lighteffects_buildlights_descr'),
		  onchange = function(i, value)
			  Spring.SetConfigInt("buildlights", value and 1 or 0)
			  if widgetHandler.orderList["Deferred rendering GL4"] ~= nil then
				  widgetHandler:DisableWidget("Deferred rendering GL4")
				  widgetHandler:EnableWidget("Deferred rendering GL4")
			  end
		  end,
		},
		{ id = "lighteffects_brightness", group = "gfx", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.lighteffects_brightness'), min = 0.4, max = 1.5, step = 0.05, type = "slider", value = 1, description = Spring.I18N('ui.settings.option.lighteffects_brightness_descr'),
		  onload = function(i)
			  loadWidgetData("Deferred rendering GL4", "lighteffects_brightness", { 'intensityMultiplier' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Deferred rendering GL4', 'lightsgl4', 'IntensityMultiplier', { 'intensityMultiplier' }, value)
		  end,
		},
		{ id = "lighteffects_radius", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.lighteffects_radius'), min = 0.4, max = 1.2, step = 0.05, type = "slider", value = 1, description = Spring.I18N('ui.settings.option.lighteffects_radius_descr'),
		  onload = function(i)
			  loadWidgetData("Deferred rendering GL4", "lighteffects_radius", { 'radiusMultiplier' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Deferred rendering GL4', 'lightsgl4', 'RadiusMultiplier', { 'radiusMultiplier' }, value)
		  end,
		},

		{ id = "lighteffects_screenspaceshadows", group = "gfx", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.lighteffects_screenspaceshadows'), min = 0, max = 4, step = 1, type = "slider", value = 2, description = Spring.I18N('ui.settings.option.lighteffects_screenspaceshadows_descr'),
		  onload = function(i)
			loadWidgetData("Deferred rendering GL4", "lighteffects_screenspaceshadows", { 'screenSpaceShadows' })
		  end,
		  onchange = function(i, value)
			saveOptionValue('Deferred rendering GL4', 'lightsgl4', 'ScreenSpaceShadows', { 'screenSpaceShadows' }, value)
		  end,
	  	},

		{ id = "distortioneffects", group = "gfx", category = types.basic, widget = "Distortion GL4", name = Spring.I18N('ui.settings.option.distortioneffects'), type = "bool", value = GetWidgetToggleValue("Distortion GL4"), description = Spring.I18N('ui.settings.option.distortioneffects_descr') },

		{ id = "darkenmap", group = "gfx", category = types.advanced, name = Spring.I18N('ui.settings.option.darkenmap'), min = 0, max = 0.33, step = 0.01, type = "slider", value = 0, description = Spring.I18N('ui.settings.option.darkenmap_descr'),
		  onload = function(i)
			  loadWidgetData("Darken map", "darkenmap", { 'darknessvalue' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Darken map', 'darkenmap', 'setMapDarkness', { 'darknessvalue' }, value)
		  end,
		},

		{ id = "label_gfx_environment", group = "gfx", name = Spring.I18N('ui.settings.option.label_environment'), category = types.basic },
		{ id = "label_gfx_environment_spacer", group = "gfx", category = types.basic },

		{ id = "featuredrawdist", group = "gfx", category = types.advanced, name = Spring.I18N('ui.settings.option.featuredrawdist'), type = "slider", min = 2500, max = 40000, step = 500, value = tonumber(Spring.GetConfigInt("FeatureDrawDistance", 10000)), description = Spring.I18N('ui.settings.option.featuredrawdist_descr'),
		  onchange = function(i, value)
			  Spring.SetConfigInt("FeatureFadeDistance", math.floor(value * 0.8))
			  Spring.SetConfigInt("FeatureDrawDistance", value)
		  end,
		},

		{ id = "losopacity", group = "gfx", category = types.advanced, name = Spring.I18N('ui.settings.option.lineofsight')..widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.losopacity'), type = "slider", min = 0.01, max = 1, step = 0.01, value = (WG['los'] ~= nil and WG['los'].getOpacity ~= nil and WG['los'].getOpacity()) or 1, description = '',
		  onload = function(i)
			  loadWidgetData("LOS colors", "losopacity", { 'opacity' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('LOS colors', 'los', 'setOpacity', { 'opacity' }, value)
		  end,
		},

		-- { id = "water", group = "gfx", category = types.basic, name = Spring.I18N('ui.settings.option.water'), type = "select", options = { 'basic', 'reflective', 'dynamic', 'reflective&refractive', 'bump-mapped' }, value = desiredWaterValue + 1,
		--   onload = function(i)
		--   end,
		--   onchange = function(i, value)
		-- 	  desiredWaterValue = value - 1
		-- 	  if waterDetected then
		-- 		  Spring.SendCommands("water " .. desiredWaterValue)
		-- 	  end
		--   end,
		-- },

		{ id = "water", group = "gfx", category = types.basic, name = Spring.I18N('ui.settings.option.water'), type = "select", options = { Spring.I18N('ui.settings.option.select_low'), Spring.I18N('ui.settings.option.select_high') }, value = desiredWaterValue == 4 and 2 or 1,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  desiredWaterValue = value > 1 and 4 or 0
			  if waterDetected then
				if desiredWaterValue > 0 then desiredWaterValue = 4 end
				  Spring.SendCommands("water " .. desiredWaterValue)
				  Spring.SetConfigInt("water", 4)
			  end
		  end,
		},

		{ id = "mapedgeextension", group = "gfx", category = types.advanced, widget = "Map Edge Extension", name = Spring.I18N('ui.settings.option.mapedgeextension'), type = "bool", value = GetWidgetToggleValue("Map Edge Extension"), description = Spring.I18N('ui.settings.option.mapedgeextension_descr') },

		{ id = "mapedgeextension_brightness", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.mapedgeextension_brightness'), min = 0.2, max = 1, step = 0.01, type = "slider", value = 0.3, description = '',
		  onload = function(i)
			  loadWidgetData("Map Edge Extension", "mapedgeextension_brightness", { 'brightness' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Map Edge Extension', 'mapedgeextension', 'setBrightness', { 'brightness' }, value)
		  end,
		},
		{ id = "mapedgeextension_curvature", category = types.dev, group = "gfx", name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.mapedgeextension_curvature'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.mapedgeextension_curvature_descr'),
		  onload = function(i)
			  loadWidgetData("Map Edge Extension", "mapedgeextension_curvature", { 'curvature' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Map Edge Extension', 'mapedgeextension', 'setCurvature', { 'curvature' }, value)
		  end,
		},

		{ id = "decalsgl4", group = "gfx", category = types.basic, widget = "Decals GL4", name = Spring.I18N('ui.settings.option.decalsgl4'), type = "bool", value = GetWidgetToggleValue("Decals GL4") },
		{ id = "decalsgl4_lifetime", group = "gfx", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.decalsgl4_lifetime'), min = 0.5, max = 5, step = 0.1, type = "slider", value = 1, description = Spring.I18N('ui.settings.option.decalsgl4_lifetime_descr'),
		  onload = function(i)
			  loadWidgetData("Decals GL4", "decalsgl4_lifetime", { 'lifeTimeMult' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Decals GL4', 'decalsgl4', 'SetLifeTimeMult', { 'lifeTimeMult' }, value)
		  end,
		},
		{ id = "decals", group = "gfx", category = types.basic, name = Spring.I18N('ui.settings.option.decals'), restart = true, min = 0, max = 3, step = 1, type = "slider", value = Spring.GetConfigInt("GroundDecals", 0), description = Spring.I18N('ui.settings.option.decals_descr'),
		  onchange = function(i, value)
			  Spring.SetConfigInt("GroundDecals", value)
			  Spring.SendCommands("GroundDecals " .. value)
		  end,
		},

		{ id = "grass", group = "gfx", category = types.basic, widget = "Map Grass GL4", name = Spring.I18N('ui.settings.option.grass'), type = "bool", value = GetWidgetToggleValue("Map Grass GL4"), description = Spring.I18N('ui.settings.option.grass_desc') },
		{ id = "grassdistance", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.grassdistance'), type = "slider", min = 0.3, max = 1, step = 0.01, value = 1, description = Spring.I18N('ui.settings.option.grassdistance_desc'),
		  onload = function(i)
			  loadWidgetData("Map Grass GL4", "grassdistance", { 'distanceMult' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Map Grass GL4', 'grassgl4', 'setDistanceMult', { 'distanceMult' }, value)
		  end,
		},

		{ id = "treewind", group = "gfx", category = types.dev, name = Spring.I18N('ui.settings.option.treewind'), type = "bool", value = tonumber(Spring.GetConfigInt("TreeWind", 1) or 1) == 1, description = Spring.I18N('ui.settings.option.treewind_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SendCommands("luarules treewind " .. (value and 1 or 0))
			  Spring.SetConfigInt("TreeWind", (value and 1 or 0))
		  end,
		},

		{ id = "snow", group = "gfx", category = types.basic, widget = "Snow", name = Spring.I18N('ui.settings.option.snow'), type = "bool", value = GetWidgetToggleValue("Snow"), description = Spring.I18N('ui.settings.option.snow_descr') },
		{ id = "snowmap", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.snowmap'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.snowmap_descr'),
		  onload = function(i)
			  loadWidgetData("Snow", "snowmap", { 'snowMaps', Game.mapName:lower() })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Snow', 'snow', 'setSnowMap', { 'snowMaps', Game.mapName:lower() }, value)
		  end,
		},
		{ id = "snowautoreduce", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.snowautoreduce'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.snowautoreduce_descr'),
		  onload = function(i)
			  loadWidgetData("Snow", "snowautoreduce", { 'autoReduce' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Snow', 'snow', 'setAutoReduce', { 'autoReduce' }, value)
		  end,
		},
		{ id = "snowamount", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.snowamount'), type = "slider", min = 0.2, max = 3, step = 0.2, value = 1, description = Spring.I18N('ui.settings.option.snowamount_descr'),
		  onload = function(i)
			  loadWidgetData("Snow", "snowamount", { 'customParticleMultiplier' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Snow', 'snow', 'setMultiplier', { 'customParticleMultiplier' }, value)
		  end,
		},

		{ id = "clouds", group = "gfx", category = types.advanced, widget = "Volumetric Clouds", name = Spring.I18N('ui.settings.option.clouds'), type = "bool", value = GetWidgetToggleValue("Volumetric Clouds"), description = '' },
		{ id = "clouds_opacity", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.clouds_opacity'), type = "slider", min = 0.2, max = 1.4, step = 0.05, value = 1, description = '',
		  onload = function(i)
			  loadWidgetData("Volumetric Clouds", "clouds_opacity", { 'opacityMult' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Volumetric Clouds', 'clouds', 'setOpacity', { 'opacityMult' }, value)
		  end,
		},
		{ id = "fogmult", group = "gfx", category = types.advanced, name = Spring.I18N('ui.settings.option.fog'), type = "slider", min = 0, max = 1, step = 0.01, value = Spring.GetConfigFloat("FogMult", 1), description = Spring.I18N('ui.settings.option.fogmult_descr'),
		  onload = function(i)
		  	options[i].onchange(i, options[i].value)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigFloat("FogMult", value)
			  value = 1 / value	-- inverse
			  local newFogStart = math.min(9, (defaultMapFog.fogStart * ((value+4)*0.2)))
			  local newFogEnd = math.min(9, defaultMapFog.fogEnd * ((value+1)*0.5))
			  if newFogStart >= newFogEnd then newFogStart = newFogEnd - 0.01 end
			  Spring.SetAtmosphere({ fogStart = newFogStart, fogEnd = newFogEnd })
		  end,
		},

		{ id = "label_gfx_effects", group = "gfx", name = Spring.I18N('ui.settings.option.label_effects'), category = types.basic },
		{ id = "label_gfx_effects_spacer", group = "gfx", category = types.basic },

		{ id = "particles", group = "gfx", category = types.basic, name = Spring.I18N('ui.settings.option.particles'), type = "slider", min = 10000, max = 40000, step = 1000, value = tonumber(Spring.GetConfigInt("MaxParticles", 1) or 15000), description = Spring.I18N('ui.settings.option.particles_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("MaxParticles", value)
			  Spring.SetConfigInt("MaxNanoParticles", math.floor(value*0.34))
		  end,
		},

		{ id = "dof", group = "gfx", category = types.advanced, widget = "Depth of Field", name = Spring.I18N('ui.settings.option.dof'), type = "bool", value = GetWidgetToggleValue("Depth of Field"), description = Spring.I18N('ui.settings.option.dof_descr') },
		{ id = "dof_autofocus", group = "gfx", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.dof_autofocus'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.dof_autofocus_descr'),
		  onload = function(i)
			  loadWidgetData("Depth of Field", "dof_autofocus", { 'autofocus' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Depth of Field', 'dof', 'setAutofocus', { 'autofocus' }, value)
		  end,
		},
		{ id = "dof_fstop", group = "gfx", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.dof_fstop'), type = "slider", min = 1, max = 6, step = 0.1, value = 2, description = Spring.I18N('ui.settings.option.dof_fstop_descr'),
		  onload = function(i)
			  loadWidgetData("Depth of Field", "dof_fstop", { 'fStop' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Depth of Field', 'dof', 'setFstop', { 'fStop' }, value)
		  end,
		},

		{ id = "label_gfx_game", group = "gfx", name = Spring.I18N('ui.settings.option.label_game'), category = types.advanced },
		{ id = "label_gfx_game_spacer", group = "gfx", category = types.basic },
		{ id = "resurrectionhalos", group = "gfx", category = types.advanced, widget = "Resurrection Halos GL4", name = Spring.I18N('ui.settings.option.resurrectionhalos'), type = "bool", value = GetWidgetToggleValue("Resurrection Halos GL4"), description = Spring.I18N('ui.settings.option.resurrectionhalos_descr') },


		-- SOUND
		{ id = "snddevice", group = "sound", category = types.advanced, name = Spring.I18N('ui.settings.option.snddevice'), type = "select", restart = true, options = soundDevices, value = soundDevicesByName[Spring.GetConfigString("snd_device")], description = Spring.I18N('ui.settings.option.snddevice_descr'),
		  onchange = function(i, value)
			  if options[i].options[options[i].value] == 'default' then
				  Spring.SetConfigString("snd_device", '')
			  else
				  Spring.SetConfigString("snd_device", options[i].options[options[i].value])
			  end
		  end,
		},

		{ id = "sndvolmaster", group = "sound", category = types.basic, name = Spring.I18N('ui.settings.option.volume') .. widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.sndvolmaster'), type = "slider", min = 0, max = 80, step = 2, value = tonumber(Spring.GetConfigInt("snd_volmaster", 1) or 80),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("snd_volmaster", value)
		  end,
		},
		{ id = "sndvolgeneral", group = "sound", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.sndvolgeneral'), type = "slider", min = 0, max = 100, step = 2, value = tonumber(Spring.GetConfigInt("snd_volgeneral", 1) or 100),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("snd_volgeneral", value)
		  end,
		},
		{ id = "sndvolbattle", group = "sound", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.sndvolbattle'), type = "slider", min = 0, max = 100, step = 2, value = tonumber(Spring.GetConfigInt("snd_volbattle", 1) or 100),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("snd_volbattle", value)
		  end,
		},
		{ id = "sndvolui", group = "sound", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.sndvolui'), type = "slider", min = 0, max = 100, step = 2, value = tonumber(Spring.GetConfigInt("snd_volui", 1) or 100),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("snd_volui", value)
		  end,
		},
		--{ id = "sndambient", group = "sound", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.sndvolambient'), type = "slider", min = 0, max = 100, step = 2, value = tonumber(Spring.GetConfigInt("snd_volambient", 1) or 100),
		--  onload = function(i)
		--  end,
		--  onchange = function(i, value)
		--	  Spring.SetConfigInt("snd_volambient", value)
		--  end,
		--},
		--{ id = "sndvolunitreply", group = "sound", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.sndvolunitreply'), type = "slider", min = 0, max = 100, step = 2, value = tonumber(Spring.GetConfigInt("snd_volunitreply", 1) or 100),
		--  onload = function(i)
		--  end,
		--  onchange = function(i, value)
		--	  Spring.SetConfigInt("snd_volunitreply", value)
		--  end,
		--},
		{ id = "console_chatvolume", group = "sound", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.console_chatvolume'), type = "slider", min = 0, max = 1, step = 0.01, value = (WG['chat'] ~= nil and WG['chat'].getChatVolume() or 0), description = Spring.I18N('ui.settings.option.console_chatvolume_descr'),
		  onload = function(i)
			  loadWidgetData("Chat", "console_chatvolume", { 'sndChatFileVolume' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Chat', 'chat', 'setChatVolume', { 'sndChatFileVolume' }, value)
		  end,
		},
		{ id = "mapmarkvolume", group = "sound", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.console_mapmarkvolume'), type = "slider", min = 0, max = 1, step = 0.01, value = (WG['mapmarkping'] ~= nil and WG['mapmarkping'].getMapmarkVolume() or 0.6), description = Spring.I18N('ui.settings.option.console_mapmarkvolume_descr'),
		  onload = function(i)
			  loadWidgetData("Chat", "mapmarkvolume", { 'volume' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Chat', 'mapmarkping', 'setMapmarkVolume', { 'volume' }, value)
		  end,
		},
		{ id = "sndvolmusic", group = "sound", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.sndvolmusic'), type = "slider", min = 0, max = 99, step = 1, value = tonumber(Spring.GetConfigInt("snd_volmusic", 50) or 50),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  if WG['music'] and WG['music'].SetMusicVolume then
				  WG['music'].SetMusicVolume(value)
			  else
				  Spring.SetConfigInt("snd_volmusic", value)
			  end
		  end,
		},

		{ id = "sndunitsound", group = "sound", category = types.advanced, name = Spring.I18N('ui.settings.option.sndunitsound'), type = "bool", value = (Spring.GetConfigInt("snd_unitsound", 1) == 1), description = Spring.I18N('ui.settings.option.sndunitsound_desc'),
		  onchange = function(i, value)
			  Spring.SetConfigInt("snd_unitsound", (value and 1 or 0))
		  end,
		},

		{ id = "sndairabsorption", group = "sound", category = types.advanced, name = Spring.I18N('ui.settings.option.sndairabsorption'), type = "slider", min = 0, max = 0.4, step = 0.01, value = tonumber(Spring.GetConfigFloat("snd_airAbsorption", .35) or .35), description = Spring.I18N('ui.settings.option.sndairabsorption_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigFloat("snd_airAbsorption", value)
		  end,
		},

		{ id = "muteoffscreen", group = "sound", category = types.advanced, name = Spring.I18N('ui.settings.option.muteoffscreen'), type = "bool", value = (Spring.GetConfigInt("muteOffscreen", 0) == 1), description = Spring.I18N('ui.settings.option.muteoffscreen_descr'),
		  onchange = function(i, value)
			  Spring.SetConfigInt("muteOffscreen", (value and 1 or 0))
		  end,
		},


		{ id = "soundtrack", group = "sound", category = types.basic, name = Spring.I18N('ui.settings.option.label_soundtrack') },
		{ id = "soundtrack_spacer", group = "sound", category = types.basic },

		{ id = "soundtrackNew", group = "sound", category = types.basic, name = Spring.I18N('ui.settings.option.soundtracknew'), type = "bool", value = Spring.GetConfigInt('UseSoundtrackNew', 1) == 1, description = Spring.I18N('ui.settings.option.soundtracknew_descr'),
			onchange = function(i, value)
				Spring.SetConfigInt('UseSoundtrackNew', value and 1 or 0)
				if WG['music'] and WG['music'].RefreshTrackList then
					WG['music'].RefreshTrackList()
					init()
				end
			end
		},
		{ id = "soundtrackCustom", group = "sound", category = types.advanced, name = Spring.I18N('ui.settings.option.soundtrackcustom'), type = "bool", value = Spring.GetConfigInt('UseSoundtrackCustom', 1) == 1, description = Spring.I18N('ui.settings.option.soundtrackcustom_descr'),
			onchange = function(i, value)
				Spring.SetConfigInt('UseSoundtrackCustom', value and 1 or 0)
				if WG['music'] and WG['music'].RefreshTrackList then
					WG['music'].RefreshTrackList()
					init()
				end
			end
		},
		{ id = "soundtrackAprilFools", group = "sound", category = types.basic, name = Spring.I18N('ui.settings.option.soundtrackaprilfools'), type = "bool", value = Spring.GetConfigInt('UseSoundtrackAprilFools', 1) == 1, description = Spring.I18N('ui.settings.option.soundtrackaprilfools_descr'),
			onchange = function(i, value)
				Spring.SetConfigInt('UseSoundtrackAprilFools', value and 1 or 0)
				if WG['music'] and WG['music'].RefreshTrackList then
					WG['music'].RefreshTrackList()
					init()
				end
			end
		},
		{ id = "soundtrackAprilFoolsPostEvent", group = "sound", category = types.basic, name = Spring.I18N('ui.settings.option.soundtrackaprilfoolspostevent'), type = "bool", value = Spring.GetConfigInt('UseSoundtrackAprilFoolsPostEvent', 0) == 1, description = Spring.I18N('ui.settings.option.soundtrackaprilfoolspostevent_descr'),
		onchange = function(i, value)
			Spring.SetConfigInt('UseSoundtrackAprilFoolsPostEvent', value and 1 or 0)
			if WG['music'] and WG['music'].RefreshTrackList then
				WG['music'].RefreshTrackList()
				init()
			end
		end
		},
		{ id = "soundtrackHalloween", group = "sound", category = types.basic, name = Spring.I18N('ui.settings.option.soundtrackhalloween'), type = "bool", value = Spring.GetConfigInt('UseSoundtrackHalloween', 1) == 1, description = Spring.I18N('ui.settings.option.soundtrackhalloween_descr'),
			onchange = function(i, value)
				Spring.SetConfigInt('UseSoundtrackHalloween', value and 1 or 0)
				if WG['music'] and WG['music'].RefreshTrackList then
					WG['music'].RefreshTrackList()
					init()
				end
			end
		},
		{ id = "soundtrackHalloweenPostEvent", group = "sound", category = types.basic, name = Spring.I18N('ui.settings.option.soundtrackhalloweenpostevent'), type = "bool", value = Spring.GetConfigInt('UseSoundtrackHalloweenPostEvent', 0) == 1, description = Spring.I18N('ui.settings.option.soundtrackhalloweenpostevent_descr'),
		onchange = function(i, value)
			Spring.SetConfigInt('UseSoundtrackHalloweenPostEvent', value and 1 or 0)
			if WG['music'] and WG['music'].RefreshTrackList then
				WG['music'].RefreshTrackList()
				init()
			end
		end
		},
		{ id = "soundtrackXmas", group = "sound", category = types.basic, name = Spring.I18N('ui.settings.option.soundtrackxmas'), type = "bool", value = Spring.GetConfigInt('UseSoundtrackXmas', 1) == 1, description = Spring.I18N('ui.settings.option.soundtrackxmas_descr'),
			onchange = function(i, value)
				Spring.SetConfigInt('UseSoundtrackXmas', value and 1 or 0)
				if WG['music'] and WG['music'].RefreshTrackList then
					WG['music'].RefreshTrackList()
					init()
				end
			end
		},
		{ id = "soundtrackXmasPostEvent", group = "sound", category = types.basic, name = Spring.I18N('ui.settings.option.soundtrackxmaspostevent'), type = "bool", value = Spring.GetConfigInt('UseSoundtrackXmasPostEvent', 0) == 1, description = Spring.I18N('ui.settings.option.soundtrackxmaspostevent_descr'),
		onchange = function(i, value)
			Spring.SetConfigInt('UseSoundtrackXmasPostEvent', value and 1 or 0)
			if WG['music'] and WG['music'].RefreshTrackList then
				WG['music'].RefreshTrackList()
				init()
			end
		end
		},
		{ id = "soundtrackInterruption", group = "sound", category = types.basic, name = Spring.I18N('ui.settings.option.soundtrackinterruption'), type = "bool", value = Spring.GetConfigInt('UseSoundtrackInterruption', 1) == 1, description = Spring.I18N('ui.settings.option.soundtrackinterruption_descr'),
			onchange = function(i, value)
				Spring.SetConfigInt('UseSoundtrackInterruption', value and 1 or 0)
				if WG['music'] and WG['music'].RefreshSettings then
					WG['music'].RefreshSettings()
				end
			end
		},
		{ id = "soundtrackFades", group = "sound", category = types.basic, name = Spring.I18N('ui.settings.option.soundtrackfades'), type = "bool", value = Spring.GetConfigInt('UseSoundtrackFades', 1) == 1, description = Spring.I18N('ui.settings.option.soundtrackfades_descr'),
		  onchange = function(i, value)
				Spring.SetConfigInt('UseSoundtrackFades', value and 1 or 0)
				if WG['music'] and WG['music'].RefreshSettings then
					WG['music'].RefreshSettings()
				end
			end
		},

		{ id = "loadscreen_music", group = "sound", category = types.basic, name = Spring.I18N('ui.settings.option.loadscreen_music'), type = "bool", value = (Spring.GetConfigInt("music_loadscreen", 1) == 1), description = Spring.I18N('ui.settings.option.loadscreen_music_descr'),
		  onchange = function(i, value)
			  Spring.SetConfigInt("music_loadscreen", (value and 1 or 0))
		  end,
		},

		{ id = "notifications_set", group = "notif", category = types.basic, name = Spring.I18N('ui.settings.option.notifications_set'), type = "select", options = {}, value = 1,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigString("voiceset", (hideOtherLanguagesVoicepacks and Spring.GetConfigString('language', 'en')..'/' or '')..options[i].options[options[i].value])
			  if widgetHandler.orderList["Notifications"] ~= nil then
				  widgetHandler:DisableWidget("Notifications")
				  widgetHandler:EnableWidget("Notifications")
				  init()
			  end
		  end,
		},

		{ id = "notifications_tutorial", group = "notif", name = Spring.I18N('ui.settings.option.notifications_tutorial'), category = types.basic, type = "bool", value = (WG['notifications'] ~= nil and WG['notifications'].getTutorial()), description = Spring.I18N('ui.settings.option.notifications_tutorial_descr'),
		  onload = function(i)
			  loadWidgetData("Notifications", "notifications_tutorial", { 'tutorialMode' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Notifications', 'notifications', 'setTutorial', { 'tutorialMode' }, value)
		  end,
		},
		{ id = "notifications_messages", group = "notif", name = Spring.I18N('ui.settings.option.notifications_messages'), category = types.basic, type = "bool", value = (WG['notifications'] ~= nil and WG['notifications'].getMessages()), description = Spring.I18N('ui.settings.option.notifications_messages_descr'),
		  onload = function(i)
			  loadWidgetData("Notifications", "notifications_messages", { 'displayMessages' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Notifications', 'notifications', 'setMessages', { 'displayMessages' }, value)
		  end,
		},
		{ id = "notifications_spoken", group = "notif", name = Spring.I18N('ui.settings.option.notifications_spoken'), category = types.basic, type = "bool", value = (WG['notifications'] ~= nil and WG['notifications'].getSpoken()), description = Spring.I18N('ui.settings.option.notifications_spoken_descr'),
		  onload = function(i)
			  loadWidgetData("Notifications", "notifications_spoken", { 'spoken' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Notifications', 'notifications', 'setSpoken', { 'spoken' }, value)
		  end,
		},
		{ id = "notifications_volume", group = "notif", category = types.basic, name = Spring.I18N('ui.settings.option.notifications_volume'), type = "slider", min = 0.05, max = 1, step = 0.05, value = 1, description = Spring.I18N('ui.settings.option.notifications_volume_descr'),
		  onload = function(i)
			  loadWidgetData("Notifications", "notifications_volume", { 'volume' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Notifications', 'notifications', 'setVolume', { 'volume' }, value)
		  end,
		},
		{ id = "notifications_playtrackedplayernotifs", category = types.basic, group = "notif", name = Spring.I18N('ui.settings.option.notifications_playtrackedplayernotifs'), type = "bool", value = (WG['notifications'] ~= nil and WG['notifications'].getPlayTrackedPlayerNotifs()), description = Spring.I18N('ui.settings.option.notifications_playtrackedplayernotifs_descr'),
		  onload = function(i)
			  loadWidgetData("Notifications", "notifications_playtrackedplayernotifs", { 'playTrackedPlayerNotifs' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Notifications', 'notifications', 'setPlayTrackedPlayerNotifs', { 'playTrackedPlayerNotifs' }, value)
		  end,
		},


		{ id = "label_notif_messages", group = "notif", name = Spring.I18N('ui.settings.option.label_messages'), category = types.basic },
		{ id = "label_notif_messages_spacer", group = "notif", category = types.basic },

		-- CONTROL
		{ id = "label_ui_hotkeys", group = "control", name = Spring.I18N('ui.settings.option.label_hotkeys'), category = types.basic },
		{ id = "label_ui_hotkeys_spacer", group = "control", category = types.basic },

		{ id = "keylayout", group = "control", category = types.basic, name = Spring.I18N('ui.settings.option.keylayout'), type = "select", options = keyLayouts.layouts, value = 1, description = Spring.I18N('ui.settings.option.keylayout_descr'),
		  onload = function()
			  local keyLayout = Spring.GetConfigString("KeyboardLayout")

			  if not keyLayout or keyLayout == '' then
				  keyLayout = keyLayouts.layouts[1]
				  Spring.SetConfigString("KeyboardLayout", keyLayouts.layouts[1])
			  end

			  local value = 1
			  for i, v in ipairs(keyLayouts.layouts) do
				  if v == keyLayout then
					  value = i
					  break
				  end
			  end

			  options[getOptionByID('keylayout')].value = value
		  end,
		  onchange = function(_, value)
			  Spring.SetConfigString("KeyboardLayout", keyLayouts.layouts[value])
			  if WG['bar_hotkeys'] and WG['bar_hotkeys'].reloadBindings then
				  WG['bar_hotkeys'].reloadBindings()
			  end
		  end,
		},

		{ id = "keybindings", group = "control", category = types.basic, name = Spring.I18N('ui.settings.option.keybindings'), type = "select", options = keyLayouts.keybindingLayouts, value = 1, description = Spring.I18N('ui.settings.option.keybindings_descr'),
		  onload = function()
			  local keyFile = Spring.GetConfigString("KeybindingFile")
			  local value = 1

			  if (not keyFile) or (keyFile == '') or (not VFS.FileExists(keyFile)) then
				  keyFile = keyLayouts.keybindingLayoutFiles[1]
			  end

			  for i, v in ipairs(keyLayouts.keybindingLayoutFiles) do
				  if v == keyFile then
					  value = i
					  break
				  end
			  end

			  options[getOptionByID('keybindings')].value = value
		  end,
		  onchange = function(_, value)
			  local keyFile = keyLayouts.keybindingLayoutFiles[value]

			  if not keyFile or keyFile == '' then
				  return
			  end

			  local isCustom = keyLayouts.keybindingPresets["Custom"] == keyFile

			  if isCustom and not VFS.FileExists(keyFile) then
				  Spring.SendCommands("keysave " .. keyFile)
				  Spring.Echo("Preset Custom selected, file saved at: " .. keyFile)
			  end

			  Spring.SetConfigString("KeybindingFile", keyFile)
			  if isCustom then
				  Spring.Echo("To test your custom bindings after changes type in chat: /keyreload")
			  end
			  -- enable grid menu for grid keybinds
			  local preset = options[getOptionByID('keybindings')].options[value]
			  Spring.Echo(preset)
			  if string.find(string.lower(preset), "grid", nil, true) then
				  widgetHandler:DisableWidget('Build menu')
				  widgetHandler:EnableWidget('Grid menu')
			  elseif preset == 'Custom' then
			  	-- do stuff with custom preset
			  else
				  widgetHandler:DisableWidget('Grid menu')
				  widgetHandler:EnableWidget('Build menu')
			  end

			  if WG['bar_hotkeys'] and WG['bar_hotkeys'].reloadBindings then
				  WG['bar_hotkeys'].reloadBindings()
			  end
			  init()
		  end,
		},

		{ id = "gridmenu", group = "control", category = types.basic, name = Spring.I18N('ui.settings.option.gridmenu'), type = "bool", value = GetWidgetToggleValue("Grid menu"), description = Spring.I18N('ui.settings.option.gridmenu_descr'),
		  onchange = function(i, value)
			  if value then
				  widgetHandler:DisableWidget('Build menu')
				  widgetHandler:EnableWidget('Grid menu')
			  else
				  widgetHandler:DisableWidget('Grid menu')
				  widgetHandler:EnableWidget('Build menu')
			  end
			  init()
		  end,
		},
		{ id = "gridmenu_alwaysreturn", group = "control", category = types.advanced, name = Spring.I18N('ui.settings.option.gridmenu_alwaysreturn'), type = "bool", value = (WG['gridmenu'] ~= nil and WG['gridmenu'].getAlwaysReturn ~= nil and WG['gridmenu'].getAlwaysReturn()), description = Spring.I18N('ui.settings.option.gridmenu_alwaysreturn_descr'),
		  onload = function()
		  end,
		  onchange = function(_, value)
			  saveOptionValue('Grid menu', 'gridmenu', 'setAlwaysReturn', { 'alwaysReturn' }, value)
		  end,
		},
		{ id = "gridmenu_autoselectfirst", group = "control", category = types.advanced, name = Spring.I18N('ui.settings.option.gridmenu_autoselectfirst'), type = "bool", value = (WG['gridmenu'] ~= nil and WG['gridmenu'].getAutoSelectFirst ~= nil and WG['gridmenu'].getAutoSelectFirst()), description = Spring.I18N('ui.settings.option.gridmenu_autoselectfirst_descr'),
		  onload = function()
		  end,
		  onchange = function(_, value)
			  saveOptionValue('Grid menu', 'gridmenu', 'setAutoSelectFirst', { 'autoSelectFirst' }, value)
		  end,
		},
		{ id = "gridmenu_labbuildmode", group = "control", category = types.advanced, name = Spring.I18N('ui.settings.option.gridmenu_labbuildmode'), type = "bool", value = (WG['gridmenu'] ~= nil and WG['gridmenu'].getUseLabBuildMode ~= nil and WG['gridmenu'].getUseLabBuildMode()), description = Spring.I18N('ui.settings.option.gridmenu_labbuildmode_descr'),
		  onload = function()
		  end,
		  onchange = function(_, value)
			  saveOptionValue('Grid menu', 'gridmenu', 'setUseLabBuildMode', { 'useLabBuildMode' }, value)
		  end,
		},

		{ id = "gridmenu_ctrlkeymodifier", group = "control", category = types.advanced, name = Spring.I18N('ui.settings.option.gridmenu_ctrlkeymodifier'), type = "slider", min = -20, max = 100, step = 1, value = (WG['gridmenu'] ~= nil and WG['gridmenu'].getCtrlKeyModifier ~= nil and WG['gridmenu'].getCtrlKeyModifier()), description = Spring.I18N('ui.settings.option.gridmenu_ctrlkeymodifier_descr'),
		  onload = function()
		  end,
		  onchange = function(_, value)
			  saveOptionValue('Grid menu', 'gridmenu', 'setCtrlKeyModifier', { 'ctrlKeyModifier' }, value)
		  end,
		},
		{ id = "gridmenu_shiftkeymodifier", group = "control", category = types.advanced, name = Spring.I18N('ui.settings.option.gridmenu_shiftkeymodifier'), type = "slider", min = -20, max = 100, step = 1, value = (WG['gridmenu'] ~= nil and WG['gridmenu'].getShiftKeyModifier ~= nil and WG['gridmenu'].getShiftKeyModifier()), description = Spring.I18N('ui.settings.option.gridmenu_shiftkeymodifier_descr'),
		  onload = function()
		  end,
		  onchange = function(_, value)
			  saveOptionValue('Grid menu', 'gridmenu', 'setShiftKeyModifier', { 'ShiftKeyModifier' }, value)
		  end,
		},

		{ id = "label_ui_cursor", group = "control", name = Spring.I18N('ui.settings.option.label_cursor'), category = types.basic },
		{ id = "label_ui_cursor_spacer", group = "control", category = types.basic },

		{ id = "hwcursor", group = "control", category = types.basic, name = Spring.I18N('ui.settings.option.hwcursor'), type = "bool", value = tonumber(Spring.GetConfigInt("HardwareCursor", 0) or 0) == 1, description = Spring.I18N('ui.settings.option.hwcursor_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SendCommands("HardwareCursor " .. (value and 1 or 0))
			  Spring.SetConfigInt("HardwareCursor", (value and 1 or 0))
		  end,
		},
		{ id = "setcamera_bugfix", group = "control", category = types.advanced, name = Spring.I18N('ui.settings.option.setcamera_bugfix'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.setcamera_bugfix_descr'),
		  onload = function(i)
			WG['setcamera_bugfix'] = true
		  end,
		  onchange = function(i, value)
			WG['setcamera_bugfix'] = value
		  end,
		},
		{ id = "cursorsize", group = "control", category = types.basic, name = Spring.I18N('ui.settings.option.cursorsize'), type = "slider", min = 0.3, max = 1.7, step = 0.1, value = 1, description = Spring.I18N('ui.settings.option.cursorsize_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  if WG['cursors'] then
				  WG['cursors'].setsizemult(value)
			  end
		  end,
		},

		{ id = "containmouse", group = "control", category = types.basic, name = Spring.I18N('ui.settings.option.containmouse'), type = "bool", value = Spring.GetConfigInt('grabinput', 1) == 1, description = Spring.I18N('ui.settings.option.containmouse_descr'),
          onload = function(i)
          end,
          onchange = function(i, value)
              Spring.SetConfigInt("grabinput", (value and 1 or 0))
              updateGrabinput()
          end,
        },

		{ id = "doubleclicktime", group = "control", category = types.advanced, restart = true, name = Spring.I18N('ui.settings.option.doubleclicktime'), type = "slider", min = 150, max = 400, step = 10, value = Spring.GetConfigInt("DoubleClickTime", 200), description = Spring.I18N('ui.settings.option.doubleclicktime_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("DoubleClickTime", value)
		  end,
		},

		{ id = "dragthreshold", group = "control", category = types.advanced, restart = false, name = Spring.I18N('ui.settings.option.dragthreshold'), type = "slider", min = 4, max = 50, step = 1, value = Spring.GetConfigInt("MouseDragSelectionThreshold", 4), description = Spring.I18N('ui.settings.option.dragthreshold_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("MouseDragSelectionThreshold", value)
			  Spring.SetConfigInt("MouseDragCircleCommandThreshold", value)
			  Spring.SetConfigInt("MouseDragBoxCommandThreshold", value + 12)
			  Spring.SetConfigInt("MouseDragFrontCommandThreshold", value + 26)
		  end,
		},



		{ id = "label_ui_camera", group = "control", name = Spring.I18N('ui.settings.option.label_camera'), category = types.basic },
		{ id = "label_ui_camera_spacer", group = "control", category = types.basic },

		{ id = "middleclicktoggle", group = "control", category = types.basic, name = Spring.I18N('ui.settings.option.middleclicktoggle'), type = "bool", value = (Spring.GetConfigFloat("MouseDragScrollThreshold", 0.3) ~= 0), description = Spring.I18N('ui.settings.option.middleclicktoggle_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigFloat("MouseDragScrollThreshold", (value and 0.3 or 0))
		  end,
		},

		{ id = "screenedgemove", group = "control", category = types.basic, name = Spring.I18N('ui.settings.option.screenedgemove'), type = "bool", restart = true, value = tonumber(Spring.GetConfigInt("FullscreenEdgeMove", 1) or 1) == 1, description = Spring.I18N('ui.settings.option.screenedgemove_descr'),
		  onchange = function(i, value)
			  Spring.SetConfigInt("FullscreenEdgeMove", (value and 1 or 0))
			  Spring.SetConfigInt("WindowedEdgeMove", (value and 1 or 0))
				if value then
					Spring.SetConfigFloat("EdgeMoveWidth", edgeMoveWidth)
				else
					Spring.SetConfigFloat("EdgeMoveWidth", 0)
				end
		  end,
		},
		{ id = "screenedgemovewidth", group = "control", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.screenedgemovewidth'), type = "slider", min = 0, max = 0.1, step = 0.01, value = edgeMoveWidth, description = Spring.I18N('ui.settings.option.screenedgemovewidth_descr'),
		  onchange = function(i, value)
			  edgeMoveWidth = value
			  Spring.SetConfigFloat("EdgeMoveWidth", value)
		  end,
		},
		{ id = "screenedgemovedynamic", group = "control", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.screenedgemovedynamic'), type = "bool", restart = true, value = tonumber(Spring.GetConfigInt("EdgeMoveDynamic", 1) or 1) == 1, description = Spring.I18N('ui.settings.option.screenedgemovedynamic_descr'),
		  onchange = function(i, value)
			  Spring.SetConfigInt("EdgeMoveDynamic", (value and 1 or 0))
		  end,
		},

		{ id = "camera", group = "control", category = types.basic, name = Spring.I18N('ui.settings.option.camera'), type = "select", options = { Spring.I18N('ui.settings.option.select_firstperson'), Spring.I18N('ui.settings.option.select_overhead'), Spring.I18N('ui.settings.option.select_springcam'), Spring.I18N('ui.settings.option.select_rotoverhead'), Spring.I18N('ui.settings.option.select_free') }, value = (tonumber((Spring.GetConfigInt("CamMode", 1) + 1) or 2)),
		  onchange = function(i, value)
			  Spring.SetConfigInt("CamMode", (value - 1))
			  if value == 1 then
				  Spring.SendCommands('viewfps')
			  elseif value == 2 then
				  Spring.SendCommands('viewta')
			  elseif value == 3 then
				  Spring.SendCommands('viewspring')
			  elseif value == 4 then
				  Spring.SendCommands('viewrot')
			  elseif value == 5 then
				  Spring.SendCommands('viewfree')
			  end
			  init()
		  end,
		},
		{ id = "springcamheightmode", group = "control", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.springcamheightmode'), type = "select", options = { Spring.I18N('ui.settings.option.select_constant'), Spring.I18N('ui.settings.option.select_terrain'), Spring.I18N('ui.settings.option.select_smooth')}, value = Spring.GetConfigInt("CamSpringTrackMapHeightMode", 0) + 1, description = Spring.I18N('ui.settings.option.springcamheightmode_descr'),
		  onchange = function(i, value)
			  Spring.SetConfigInt("CamSpringTrackMapHeightMode", value - 1)
		  end,
		},
		{ id = "mincamheight", group = "control", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.mincamheight'), type = "slider", min = 0, max = 1500, step = 1, value = Spring.GetConfigInt("CamSpringMinZoomDistance", 0), description = Spring.I18N('ui.settings.option.mincamheight_descr'),
		  onchange = function(i, value)
			  Spring.SetConfigInt("CamSpringMinZoomDistance", value)
			  Spring.SetConfigInt("OverheadMinZoomDistance", value)
		  end,
		},
		{ id = "camerashake", group = "control", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.camerashake'), type = "slider", min = 0, max = 200, step = 10, value = 80, description = Spring.I18N('ui.settings.option.camerashake_descr'),
		  onload = function(i)
			  loadWidgetData("CameraShake", "camerashake", { 'powerScale' })
			  if options[i].value > 0 then
				  widgetHandler:EnableWidget("CameraShake")
			  end
		  end,
		  onchange = function(i, value)
			  saveOptionValue('CameraShake', 'camerashake', 'setStrength', { 'powerScale' }, value)
			  if value > 0 then
				  widgetHandler:EnableWidget("CameraShake")
			  end
		  end,
		},
		--{ id = "camerasmoothing", group = "control", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.camerasmoothing'), type = "bool", value = (tonumber(Spring.GetConfigInt("CameraSmoothing", 0)) == 1), description = "",
		--  onload = function(i)
		--  end,
		--  onchange = function(i, value)
		--	  Spring.SetConfigInt("CameraSmoothing", (value and 1 or 0))
		--	  if value then
		--		  Spring.SendCommands("set CamFrameTimeCorrection 1")
		--		  Spring.SendCommands("set SmoothTimeOffset 2")
		--		else
		--		  Spring.SendCommands("set CamFrameTimeCorrection 0")
		--		  Spring.SendCommands("set SmoothTimeOffset 0")
		--	  end
		--  end,
		--},
		{ id = "smoothingmode", group = "control", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.smoothingmode'), type = "select", options = { Spring.I18N('ui.settings.option.smoothing_exponential'), Spring.I18N('ui.settings.option.smoothing_spring')}, value = (Spring.GetConfigInt("CamTransitionMode", 1) + 1),
		  onchange = function(i, value)
			  Spring.SetConfigInt("CamTransitionMode", (value - 1))
		  end,
		},
		{ id = "camerasmoothness", group = "control", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.camerasmoothness'), type = "slider", min = 0.04, max = 2, step = 0.01, value = cameraTransitionTime, description = Spring.I18N('ui.settings.option.camerasmoothness_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  cameraTransitionTime = value
			  local halfLife = value
			  if halfLife <= 1 then
				halfLife = halfLife * 200
			  else
				halfLife = halfLife * 600 - 400
			  end
			  Spring.SetConfigFloat("CamSpringHalflife", halfLife)
		  end,
		},
		{ id = "camerapanspeed", group = "control", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.camerapanspeed'), type = "slider", min = -0.01, max = -0.00195, step = 0.0001, value = Spring.GetConfigFloat("MiddleClickScrollSpeed", 0.0035), description = Spring.I18N('ui.settings.option.camerapanspeed_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigFloat("MiddleClickScrollSpeed", value)
		  end,
		},
		{ id = "cameramovespeed", group = "control", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.cameramovespeed'), type = "slider", min = 0, max = 100, step = 1, value = Spring.GetConfigInt("CamSpringScrollSpeed", 10), description = Spring.I18N('ui.settings.option.cameramovespeed_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  --cameraPanTransitionTime = value
			  Spring.SetConfigInt("FPSScrollSpeed", value)            -- spring default: 10
			  Spring.SetConfigInt("OverheadScrollSpeed", value)        -- spring default: 10
			  Spring.SetConfigInt("RotOverheadScrollSpeed", value)    -- spring default: 10
			  Spring.SetConfigFloat("CamFreeScrollSpeed", value * 50)    -- spring default: 500
			  Spring.SetConfigInt("CamSpringScrollSpeed", value)        -- spring default: 10
		  end,
		},
		{ id = "scrollspeed", group = "control", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.scrollspeed'), type = "slider", min = 1, max = 50, step = 1, value = math.abs(tonumber(Spring.GetConfigInt("ScrollWheelSpeed", 1) or 25)), description = '',
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  if getOptionByID('scrollinverse') and options[getOptionByID('scrollinverse')].value then
				  Spring.SetConfigInt("ScrollWheelSpeed", -value)
			  else
				  Spring.SetConfigInt("ScrollWheelSpeed", value)
			  end
		  end,
		},
		{ id = "scrollinverse", group = "control", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.scrollinverse'), type = "bool", value = (tonumber(Spring.GetConfigInt("ScrollWheelSpeed", 1) or 25) < 0), description = "",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  if getOptionByID('scrollspeed') then
				  if value then
					  Spring.SetConfigInt("ScrollWheelSpeed", -options[getOptionByID('scrollspeed')].value)
				  else
					  Spring.SetConfigInt("ScrollWheelSpeed", options[getOptionByID('scrollspeed')].value)
				  end
			  end
		  end,
		},
		{ id = "invertmouse", group = "control", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.invertmouse'), type = "bool", value = tonumber(Spring.GetConfigInt("InvertMouse", 0)) == 1, description = "",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("InvertMouse", value and 1 or 0)
		  end,
		},
		{ id = "scrolltoggleoverview", group = "control", category = types.advanced, widget = "Scrolldown Toggleoverview", name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.scrolltoggleoverview'), type = "bool", value = GetWidgetToggleValue("Scrolldown Toggleoverview"), description = Spring.I18N('ui.settings.option.scrolltoggleoverview_descr') },

		{ id = "camoverviewrestore", group = "control", category = types.advanced, widget = "Overview Camera Keep Position", name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.camoverviewrestore'), type = "bool", value = GetWidgetToggleValue("Overview Camera Keep Position"), description = Spring.I18N('ui.settings.option.camoverviewrestore_descr') },

		{ id = "lockcamera_transitiontime", group = "control", category = types.advanced, name = Spring.I18N('ui.settings.option.lockcamera')..widgetOptionColor .. "   " ..Spring.I18N('ui.settings.option.lockcamera_transitiontime'), type = "slider", min = 0.5, max = 1.7, step = 0.01, value = (WG.lockcamera and WG.lockcamera.GetTransitionTime ~= nil and WG.lockcamera.GetTransitionTime()), description = Spring.I18N('ui.settings.option.lockcamera_transitiontime_descr'),
		  onload = function(i)
			  loadWidgetData("Lockcamera", "lockcamera_transitiontime", { 'transitionTime' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Lockcamera', 'lockcamera', 'SetTransitionTime', { 'transitionTime' }, value)
		  end,
		},

		{ id = "allyselunits_select", group = "control", category = types.advanced, name = widgetOptionColor .. "   " ..Spring.I18N('ui.settings.option.allyselunits_select'), type = "bool", value = (WG['allyselectedunits'] ~= nil and WG['allyselectedunits'].getSelectPlayerUnits()), description = Spring.I18N('ui.settings.option.allyselunits_select_descr'),
		  onload = function(i)
			  loadWidgetData("Ally Selected Units", "allyselunits_select", { 'selectPlayerUnits' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Ally Selected Units', 'allyselectedunits', 'setSelectPlayerUnits', { 'selectPlayerUnits' }, value)
		  end,
		},
		{ id = "lockcamera_hideenemies", group = "control", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.lockcamera_hideenemies'), type = "bool", value = (WG.lockcamera and WG.lockcamera.GetHideEnemies()), description = Spring.I18N('ui.settings.option.lockcamera_hideenemies_descr'),
		  onload = function(i)
			  loadWidgetData("Lockcamera", "lockcamera_hideenemies", { 'lockcameraHideEnemies' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Lockcamera', 'lockcamera', 'SetHideEnemies', { 'lockcameraHideEnemies' }, value)
		  end,
		},
		{ id = "lockcamera_los", group = "control", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.lockcamera_los'), type = "bool", value = (WG.lockcamera and WG.lockcamera.GetLos()), description = Spring.I18N('ui.settings.option.lockcamera_los_descr'),
		  onload = function(i)
			  loadWidgetData("Lockcamera", "lockcamera_los", { 'lockcameraLos' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Lockcamera', 'lockcamera', 'SetLos', { 'lockcameraLos' }, value)
		  end,
		},

		{ id = "label_ui_command", group = "control", name = Spring.I18N('ui.settings.option.label_commands'), category = types.advanced },
		{ id = "label_ui_command_spacer", group = "control", category = types.basic },
		{ id = "drag_multicommand_shift", group = "control", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.drag_multicommand_shift'), type = "bool", value = (WG.customformations ~= nil and WG.customformations.getRepeatForSingleUnit()), description = Spring.I18N('ui.settings.option.drag_multicommand_shift_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('CustomFormations2', 'customformations', 'setRepeatForSingleUnit', { 'repeatForSingleUnit' }, value)
		  end,
		},

		-- INTERFACE
		{ id = "label_ui_interface", group = "ui", name = Spring.I18N('ui.settings.option.label_interface'), category = types.basic },
		{ id = "label_ui_interface_spacer", group = "ui", category = types.basic },
		{ id = "language", group = "ui", category = types.basic, name = Spring.I18N('ui.settings.option.language'), type = "select", options = languageNames, value = languageCodes[Spring.I18N.getLocale()],
			onchange = function(i, value)
				local language = languageCodes[value]
				WG['language'].setLanguage(language)
				if widgetHandler.orderList["Notifications"] ~= nil then
					widgetHandler:DisableWidget("Notifications")
					widgetHandler:EnableWidget("Notifications")
					init()
				end
			end
		},
		{ id = "language_english_unit_names", group = "ui", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.language_english_unit_names'), type = "bool", value = Spring.GetConfigInt("language_english_unit_names", 0) == 1,
			onchange = function(i, value)
				WG['language'].setEnglishUnitNames(value)
			end,
		},
		{ id = "uiscale", group = "ui", category = types.basic, name = Spring.I18N('ui.settings.option.interface') .. widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.uiscale'), type = "slider", min = 0.8, max = 1.3, step = 0.01, value = Spring.GetConfigFloat("ui_scale", 1), description = '',
		  onload = function(i)
		  end,
		  onchange = function(i, value, force)
			  if force then
				  Spring.SetConfigFloat("ui_scale", value)
				  Spring.SendCommands("luarules reloadluaui")
			  else
				  sceduleOptionApply = { os.clock() + 1.5, getOptionByID('uiscale') }
			  end
		  end,
		},
		{ id = "guiopacity", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.guiopacity'), type = "slider", min = 0.3, max = 1, step = 0.01, value = Spring.GetConfigFloat("ui_opacity", 0.7), description = '',
		  onload = function(i)
		  end,
		  onchange = function(i, value, force)
			  Spring.SetConfigFloat("ui_opacity", value)
			  ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.7)
			  forceUpdate = true

			  if force then
				  Spring.SetConfigFloat("ui_opacity", value)
				  Spring.SendCommands("luarules reloadluaui")
			  else
				  sceduleOptionApply = { os.clock() + 1.5, getOptionByID('guiopacity') }
			  end
		  end,
		},
		{ id = "guitilescale", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.guitilescale'), type = "slider", min = 4, max = 40, step = 1, value = Spring.GetConfigFloat("ui_tilescale", 7), description = '',
		  onload = function(i)
		  end,
		  onchange = function(i, value, force)
			  if force then
				  Spring.SetConfigFloat("ui_tilescale", value)
				  Spring.SendCommands("luarules reloadluaui")
			  else
				  sceduleOptionApply = { os.clock() + 1.5, getOptionByID('guitilescale') }
			  end
		  end,
		},
		{ id = "guitileopacity", group = "ui", category = types.dev, name = widgetOptionColor .. "      " .. Spring.I18N('ui.settings.option.guitileopacity'), type = "slider", min = 0, max = 0.03, step = 0.001, value = Spring.GetConfigFloat("ui_tileopacity", 0.014), description = '',
		  onload = function(i)
		  end,
		  onchange = function(i, value, force)
			  if force then
				  Spring.SetConfigFloat("ui_tileopacity", value)
				  Spring.SendCommands("luarules reloadluaui")
			  else
				  sceduleOptionApply = { os.clock() + 1.5, getOptionByID('guitileopacity') }
			  end
		  end,
		},

		{ id = "guishader", group = "ui", category = types.basic, widget = "GUI Shader", name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.guishader'), type = "bool", value = GetWidgetToggleValue("GUI Shader") },

		{ id = "rendertotexture", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.rendertotexture'), type = "bool", value = Spring.GetConfigInt("ui_rendertotexture", 1) == 1, description = Spring.I18N('ui.settings.option.rendertotexture_descr'),
			onchange = function(i, value)
				Spring.SetConfigInt("ui_rendertotexture", (value and '1' or '0'))
				Spring.SendCommands("luaui reload")
			end,
		},

		{ id = "minimap_maxheight", group = "ui", category = types.advanced, name = Spring.I18N('ui.settings.option.minimap') .. widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.minimap_maxheight'), type = "slider", min = 0.2, max = 0.4, step = 0.01, value = 0.35, description = Spring.I18N('ui.settings.option.minimap_maxheight_descr'),
		  onload = function(i)
			  loadWidgetData("Minimap", "minimap_maxheight", { 'maxHeight' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Minimap', 'minimap', 'setMaxHeight', { 'maxHeight' }, value)
		  end,
		},
		{ id = "minimapleftclick", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.minimapleftclick'), type = "bool", value = (WG['minimap'] ~= nil and WG['minimap'].getLeftClickMove ~= nil and WG['minimap'].getLeftClickMove()), description = Spring.I18N('ui.settings.option.minimapleftclick_descr'),
		  onchange = function(i, value)
			  saveOptionValue('Minimap', 'minimap', 'setLeftClickMove', { 'leftClickMove' }, value)
		  end,
		},
		{ id = "minimapiconsize", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.minimapiconsize'), type = "slider", min = 2, max = 5, step = 0.25, value = tonumber(Spring.GetConfigFloat("MinimapIconScale", 3.5) or 1), description = '',
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigFloat("MinimapIconScale", value)
			  Spring.SendCommands("minimap unitsize " .. value)        -- spring wont remember what you set with '/minimap iconssize #'
		  end,
		},
		{ id = "minimap_minimized", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.minimapminimized'), type = "bool", value = Spring.GetConfigInt("MinimapMinimize", 0) == 1, description = Spring.I18N('ui.settings.option.minimapminimized_descr'),
		  onchange = function(i, value)
			  Spring.SendCommands("minimap minimize "..(value and '1' or '0'))
			  Spring.SetConfigInt("MinimapMinimize", (value and '1' or '0'))
		  end,
		},
		{ id = "minimaprotation", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.minimaprotation'), type = "select", options = { Spring.I18N('ui.settings.option.minimaprotation_none'), Spring.I18N('ui.settings.option.minimaprotation_autoflip'), Spring.I18N('ui.settings.option.minimaprotation_autorotate')}, description = Spring.I18N('ui.settings.option.minimaprotation_descr'),
		  onload = function(i)
			  loadWidgetData("Minimap Rotation Manager", "minimaprotation", { 'mode' })
			  if options[i].value == nil then -- first load to migrate from old behavior smoothly, might wanna remove it later
				  options[i].value = Spring.GetConfigInt("MiniMapCanFlip", 0) + 1
			  end
		  end,
		  onchange = function(i, value)
			  if WG['minimaprotationmanager'] ~= nil and WG['minimaprotationmanager'].setMode ~= nil then
				  saveOptionValue("Minimap Rotation Manager", "minimaprotationmanager", "setMode", { 'mode' }, value)
			  else
				  widgetHandler:EnableWidget("Minimap Rotation Manager") -- Widget has auto sync
			  end
		  end,
		},

		{ id = "buildmenu_bottom", group = "ui", category = types.basic, name = Spring.I18N('ui.settings.option.buildmenu') ..widgetOptionColor.. "  " .. Spring.I18N('ui.settings.option.buildmenu_bottom'), type = "bool", value = (WG['buildmenu'] ~= nil and WG['buildmenu'].getBottomPosition ~= nil and WG['buildmenu'].getBottomPosition()), description = Spring.I18N('ui.settings.option.buildmenu_bottom_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Build menu', 'buildmenu', 'setBottomPosition', { 'stickToBottom' }, value)
			  saveOptionValue('Grid menu', 'buildmenu', 'setBottomPosition', { 'stickToBottom' }, value)
		  end,
		},
		{ id = "buildmenu_maxposy", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.buildmenu_maxposy'), type = "slider", min = 0.66, max = 0.88, step = 0.01, value = 0.74, description = Spring.I18N('ui.settings.option.buildmenu_maxposy_descr'),
		  onload = function(i)
			  loadWidgetData("Build menu", "buildmenu_maxposy", { 'maxPosY' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Build menu', 'buildmenu', 'setMaxPosY', { 'maxPosY' }, value)
		  end,
		},
		{ id = "buildmenu_alwaysshow", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.buildmenu_alwaysshow'), type = "bool", value = (WG['buildmenu'] ~= nil and WG['buildmenu'].getAlwaysShow ~= nil and WG['buildmenu'].getAlwaysShow()), description = Spring.I18N('ui.settings.option.buildmenu_alwaysshow_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Build menu', 'buildmenu', 'setAlwaysShow', { 'alwaysShow' }, value)
			  saveOptionValue('Grid menu', 'buildmenu', 'setAlwaysShow', { 'alwaysShow' }, value)
		  end,
		},
		{ id = "buildmenu_prices", group = "ui", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.buildmenu_prices'), type = "bool", value = (WG['buildmenu'] ~= nil and WG['buildmenu'].getShowPrice ~= nil and WG['buildmenu'].getShowPrice()), description = Spring.I18N('ui.settings.option.buildmenu_prices_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Build menu', 'buildmenu', 'setShowPrice', { 'showPrice' }, value)
			  saveOptionValue('Grid menu', 'buildmenu', 'setShowPrice', { 'showPrice' }, value)
		  end,
		},
		{ id = "buildmenu_groupicon", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.buildmenu_groupicon'), type = "bool", value = (WG['buildmenu'] ~= nil and WG['buildmenu'].getShowGroupIcon ~= nil and WG['buildmenu'].getShowGroupIcon()), description = Spring.I18N('ui.settings.option.buildmenu_groupicon_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Build menu', 'buildmenu', 'setShowGroupIcon', { 'showGroupIcon' }, value)
			  saveOptionValue('Grid menu', 'buildmenu', 'setShowGroupIcon', { 'showGroupIcon' }, value)
		  end,
		},
		{ id = "buildmenu_radaricon", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.buildmenu_radaricon'), type = "bool", value = (WG['buildmenu'] ~= nil and WG['buildmenu'].getShowRadarIcon ~= nil and WG['buildmenu'].getShowRadarIcon()), description = Spring.I18N('ui.settings.option.buildmenu_radaricon_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Build menu', 'buildmenu', 'setShowRadarIcon', { 'showRadarIcon' }, value)
			  saveOptionValue('Grid menu', 'buildmenu', 'setShowRadarIcon', { 'showRadarIcon' }, value)
		  end,
		},

		{ id = "ordermenu_bottompos", group = "ui", category = types.basic, name = Spring.I18N('ui.settings.option.ordermenu')..widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.ordermenu_bottompos'), type = "bool", value = (WG['ordermenu'] ~= nil and WG['ordermenu'].getBottomPosition ~= nil and WG['ordermenu'].getBottomPosition()), description = Spring.I18N('ui.settings.option.ordermenu_bottompos_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Order menu', 'ordermenu', 'setBottomPosition', { 'stickToBottom' }, value)
		  end,
		},
		{ id = "ordermenu_colorize", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.ordermenu_colorize'), type = "slider", min = 0, max = 1, step = 0.1, value = 0, description = '',
		  onload = function(i)
			  loadWidgetData("Order menu", "ordermenu_colorize", { 'colorize' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Order menu', 'ordermenu', 'setColorize', { 'colorize' }, value)
		  end,
		},
		{ id = "ordermenu_alwaysshow", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.ordermenu_alwaysshow'), type = "bool", value = (WG['ordermenu'] ~= nil and WG['ordermenu'].getAlwaysShow ~= nil and WG['ordermenu'].getAlwaysShow()), description = Spring.I18N('ui.settings.option.ordermenu_alwaysshow_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Order menu', 'ordermenu', 'setAlwaysShow', { 'alwaysShow' }, value)
		  end,
		},
		{ id = "ordermenu_hideset", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.ordermenu_hideset'), type = "bool", value = (WG['ordermenu'] ~= nil and WG['ordermenu'].getDisabledCmd ~= nil and WG['ordermenu'].getDisabledCmd('Move')), description = Spring.I18N('ui.settings.option.ordermenu_hideset_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  local cmds = { 'Move', 'Stop', 'Attack', 'Patrol', 'Fight', 'Wait', 'Guard', 'Reclaim', 'Repair', 'ManualFire' }
			  for k, cmd in pairs(cmds) do
				  saveOptionValue('Order menu', 'ordermenu', 'setDisabledCmd', { 'disabledCmd', cmd }, value, { cmd, value })
			  end
		  end,
		},

		{ id = "info_buildlist", group = "ui", category = types.advanced, name = Spring.I18N('ui.settings.option.info') .. widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.info_buildlist'), type = "bool", value = (WG['info'] and WG['info'].getShowBuilderBuildlist ~= nil and WG['info'].getShowBuilderBuildlist()), description = Spring.I18N('ui.settings.option.info_buildlist_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Info', 'info', 'setShowBuilderBuildlist', { 'showBuilderBuildlist' }, value)
		  end,
		},
		{ id = "info_mappos", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.info_mappos'), type = "bool", value = (WG['info'] and WG['info'].getDisplayMapPosition ~= nil and WG['info'].getDisplayMapPosition()), description = Spring.I18N('ui.settings.option.info_mappos_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Info', 'info', 'setDisplayMapPosition', { 'displayMapPosition' }, value)
		  end,
		},
		{ id = "info_alwaysshow", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.info_alwaysshow'), type = "bool", value = (WG['info'] ~= nil and WG['info'].getAlwaysShow ~= nil and WG['info'].getAlwaysShow()),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Info', 'info', 'setAlwaysShow', { 'alwaysShow' }, value)
		  end,
		},

		{ id = "advplayerlist_country", group = "ui", category = types.basic, name = Spring.I18N('ui.settings.option.advplayerlist') .. widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.advplayerlist_country'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.advplayerlist_country_descr'),
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "advplayerlist_country", { 'm_active_Table', 'country' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'country' }, value, { 'country', value })
		  end,
		},
		{ id = "advplayerlist_scale", group = "ui", category = types.advanced, name =  widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.advplayerlist_scale'), min = 0.85, max = 1.2, step = 0.01, type = "slider", value = 1, description = Spring.I18N('ui.settings.option.advplayerlist_scale_descr'),
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "advplayerlist_scale", { 'customScale' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetScale', { 'customScale' }, value)
		  end,
		},
		{ id = "advplayerlist_showallyid", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.advplayerlist_showallyid'), type = "bool", value = false, description = Spring.I18N('ui.settings.option.advplayerlist_showallyid_descr'),
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "advplayerlist_showallyid", { 'm_active_Table', 'allyid' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'allyid' }, value, { 'allyid', value })
		  end,
		},
		{ id = "advplayerlist_showid", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.advplayerlist_showid'), type = "bool", value = false, description = Spring.I18N('ui.settings.option.advplayerlist_showid_descr'),
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "advplayerlist_showid", { 'm_active_Table', 'id' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'id' }, value, { 'id', value })
		  end,
		},
		{ id = "advplayerlist_showplayerid", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.advplayerlist_showplayerid'), type = "bool", value = false, description = Spring.I18N('ui.settings.option.advplayerlist_showplayerid_descr'),
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "advplayerlist_showplayerid", { 'm_active_Table', 'playerid' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'playerid' }, value, { 'playerid', value })
		  end,
		},
		{ id = "advplayerlist_rank", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.advplayerlist_rank'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.advplayerlist_rank_descr'),
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "advplayerlist_rank", { 'm_active_Table', 'rank' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'rank' }, value, { 'rank', value })
		  end,
		},
		--{ id = "advplayerlist_side", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.advplayerlist_side'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.advplayerlist_side_descr'),
		--  onload = function(i)
		--	  loadWidgetData("AdvPlayersList", "advplayerlist_side", { 'm_active_Table', 'side' })
		--  end,
		--  onchange = function(i, value)
		--	  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'side' }, value, { 'side', value })
		--  end,
		--},
		{ id = "advplayerlist_skill", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.advplayerlist_skill'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.advplayerlist_skill_descr'),
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "advplayerlist_skill", { 'm_active_Table', 'skill' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'skill' }, value, { 'skill', value })
		  end,
		},
		{ id = "advplayerlist_cpuping", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.advplayerlist_cpuping'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.advplayerlist_cpuping_descr'),
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "advplayerlist_cpuping", { 'm_active_Table', 'cpuping' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'cpuping' }, value, { 'cpuping', value })
		  end,
		},
		{ id = "advplayerlist_resources", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.advplayerlist_resources'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.advplayerlist_resources_descr'),
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "advplayerlist_resources", { 'm_active_Table', 'resources' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'resources' }, value, { 'resources', value })
		  end,
		},
		{ id = "advplayerlist_income", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.advplayerlist_income'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.advplayerlist_income_descr'),
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "advplayerlist_income", { 'm_active_Table', 'income' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'income' }, value, { 'income', value })
		  end,
		},
		{ id = "advplayerlist_absresbars", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.advplayerlist_absresbars'), type = "bool", value = false, description = Spring.I18N('ui.settings.option.advplayerlist_absresbars_descr'),
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "advplayerlist_absresbars", { 'absoluteResbarValues' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetAbsoluteResbars', { 'absoluteResbarValues' }, value)
		  end,
		},
		{ id = "advplayerlist_share", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.advplayerlist_share'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.advplayerlist_share_descr'),
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "advplayerlist_share", { 'm_active_Table', 'share' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'share' }, value, { 'share', value })
		  end,
		},
		{ id = "advplayerlist_hidespecs", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.advplayerlist_hidespecs'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.advplayerlist_hidespecs_descr'),
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "advplayerlist_hidespecs", { 'alwaysHideSpecs' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetAlwaysHideSpecs', { 'alwaysHideSpecs' }, value)
		  end,
		},
		{ id = "unittotals", group = "ui", category = types.advanced, widget = "AdvPlayersList Unit Totals", name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.unittotals'), type = "bool", value = GetWidgetToggleValue("AdvPlayersList Unit Totals"), description = Spring.I18N('ui.settings.option.unittotals_descr') },
		{ id = "musicplayer", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. widgetOptionColor .. Spring.I18N('ui.settings.option.musicplayer'), type = "bool", value = (WG['music'] ~= nil and WG['music'].GetShowGui() or false), description = Spring.I18N('ui.settings.option.musicplayer_descr'),
		  onload = function(i)
			  loadWidgetData("AdvPlayersList Music Player New", "musicplayer", { 'showGUI' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList Music Player New', 'music', 'SetShowGui', { 'showGUI' }, value)
		  end,
		},
		{ id = "mascot", group = "ui", category = types.advanced, widget = "AdvPlayersList Mascot", name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.mascot'), type = "bool", value = GetWidgetToggleValue("AdvPlayersList Mascot"), description = Spring.I18N('ui.settings.option.mascot_descr') },

		{ id = "displayselectedname", group = "ui", category = types.advanced, name = Spring.I18N('ui.settings.option.displayselectedname'), type = "bool", value = (WG['playertv'] ~= nil and WG['playertv'].GetAlwaysDisplayName() or false), description = Spring.I18N('ui.settings.option.displayselectedname_descr'),
		  onload = function(i)
			  loadWidgetData("Player-TV", "displayselectedname", { 'alwaysDisplayName' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Player-TV', 'playertv', 'SetAlwaysDisplayName', { 'alwaysDisplayName' }, value)
		  end,
		},

		{ id = "console_fontsize", group = "ui", category = types.basic, name = Spring.I18N('ui.settings.option.console') .. "   " .. widgetOptionColor .. Spring.I18N('ui.settings.option.console_fontsize'), type = "slider", min = 0.92, max = 1.12, step = 0.02, value = (WG['chat'] ~= nil and WG['chat'].getFontsize() or 1), description = '',
		  onload = function(i)
			  loadWidgetData("Chat", "console_fontsize", { 'fontsizeMult' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Chat', 'chat', 'setFontsize', { 'fontsizeMult' }, value)
		  end,
		},
		{ id = "console_backgroundopacity", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.console_backgroundopacity'), type = "slider", min = 0, max = 0.45, step = 0.01, value = (WG['chat'] ~= nil and WG['chat'].getBackgroundOpacity() or 0), description = Spring.I18N('ui.settings.option.console_backgroundopacity_descr'),
		  onload = function(i)
			  loadWidgetData("Chat", "console_backgroundopacity", { 'chatBackgroundOpacity' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Chat', 'chat', 'setBackgroundOpacity', { 'chatBackgroundOpacity' }, value)
		  end,
		},
		{ id = "console_hidespecchat", group = "ui", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.console_hidespecchat'), type = "bool", value = (Spring.GetConfigInt("HideSpecChat", 0) == 1), description = Spring.I18N('ui.settings.option.console_hidespecchat_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("HideSpecChat", value and 1 or 0)
		  end,
		},
		{ id = "console_hidespecchatplayer", group = "ui", category = types.basic, name = widgetOptionColor .. "      " .. widgetOptionColor .. Spring.I18N('ui.settings.option.console_hidespecchatplayer'), type = "bool", value = (Spring.GetConfigInt("HideSpecChatPlayer", 1) == 1), description = Spring.I18N('ui.settings.option.console_hidespecchatplayer_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("HideSpecChatPlayer", value and 1 or 0)
		  end,
		},
		{ id = "console_hide", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.console_hide'), type = "bool", value = (WG['chat'] ~= nil and WG['chat'].getHide() or false), description = Spring.I18N('ui.settings.option.console_hide_descr'),
		  onload = function(i)
			  loadWidgetData("Chat", "console_hide", { 'hide' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Chat', 'chat', 'setHide', { 'hide' }, value)
		  end,
		},
		{ id = "console_maxlines", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.console_maxlines'), type = "slider", min = 3, max = 7, step = 1, value = (WG['chat'] ~= nil and WG['chat'].getMaxLines() or 5), description = '',
		  onload = function(i)
			  loadWidgetData("Chat", "console_maxlines", { 'maxLines' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Chat', 'chat', 'setMaxLines', { 'maxLines' }, value)
		  end,
		},
		{ id = "console_maxconsolelines", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.console_maxconsolelines'), type = "slider", min = 2, max = 12, step = 1, value = (WG['chat'] ~= nil and WG['chat'].getMaxConsoleLines() or 2), description = '',
		  onload = function(i)
			  loadWidgetData("Chat", "console_maxconsolelines", { 'maxConsoleLines' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Chat', 'chat', 'setMaxConsoleLines', { 'maxConsoleLines' }, value)
		  end,
		},
		--{ id = "console_handleinput", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.console_handleinput'), type = "bool", value = (WG['chat'] ~= nil and WG['chat'].getHandleInput() or 0), description = Spring.I18N('ui.settings.option.console_handleinput_descr'),
		--  onload = function(i)
		--	  loadWidgetData("Chat", "console_handleinput", { 'handleTextInput' })
		--  end,
		--  onchange = function(i, value)
		--	  saveOptionValue('Chat', 'chat', 'setHandleInput', { 'handleTextInput' }, value)
		--  end,
		--},
		--{ id = "console_inputbutton", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.console_inputbutton'), type = "bool", value = (WG['chat'] ~= nil and WG['chat'].getInputButton() or 0), description = Spring.I18N('ui.settings.option.console_inputbutton_descr'),
		--  onload = function(i)
		--	  loadWidgetData("Chat", "console_inputbutton", { 'inputButton' })
		--  end,
		--  onchange = function(i, value)
		--	  saveOptionValue('Chat', 'chat', 'setInputButton', { 'inputButton' }, value)
		--  end,
		--},
		{ id = "autoeraser", group = "ui", category = types.basic, widget = "Auto mapmark eraser", name = Spring.I18N('ui.settings.option.autoeraser'), type = "bool", value = GetWidgetToggleValue("Auto mapmark eraser"), description = Spring.I18N('ui.settings.option.autoeraser_descr') },
		{ id = "autoeraser_erasetime", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.autoeraser_erasetime'), type = "slider", min = 10, max = 200, step = 1, value = 60, description = Spring.I18N('ui.settings.option.autoeraser_erasetime_descr'),
		  onload = function(i)
			  loadWidgetData("Auto mapmark eraser", "autoeraser_erasetime", { 'eraseTime' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Auto mapmark eraser', 'autoeraser', 'setEraseTime', { 'eraseTime' }, value)
		  end,
		},

		{ id = "topbar_hidebuttons", group = "ui", category = types.advanced, name = Spring.I18N('ui.settings.option.topbar')..widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.topbar_hidebuttons'), type = "bool", value = (WG['topbar'] ~= nil and WG['topbar'].getAutoHideButtons() or 0),
		  onload = function(i)
			  loadWidgetData("Top Bar", "topbar_hidebuttons", { 'autoHideButtons' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Top Bar', 'topbar', 'setAutoHideButtons', { 'autoHideButtons' }, value)
		  end,
		},

		{ id = "continuouslyclearmapmarks", group = "ui", category = types.dev, name = Spring.I18N('ui.settings.option.continuouslyclearmapmarks'), type = "bool", value = Spring.GetConfigInt("ContinuouslyClearMapmarks", 0) == 1, description = Spring.I18N('ui.settings.option.continuouslyclearmapmarks_descr'),
		  onchange = function(i, value)
			  Spring.SetConfigInt("ContinuouslyClearMapmarks", (value and 1 or 0))
			  if value then
				  Spring.SendCommands({"clearmapmarks"})
			  end
		  end,
		},

		{ id = "unitgroups", group = "ui", category = types.basic, widget = "Unit Groups", name = Spring.I18N('ui.settings.option.unitgroups'), type = "bool", value = GetWidgetToggleValue("Unit Groups"), description = Spring.I18N('ui.settings.option.unitgroups_descr') },
		{ id = "idlebuilders", group = "ui", category = types.basic, widget = "Idle Builders", name = Spring.I18N('ui.settings.option.idlebuilders'), type = "bool", value = GetWidgetToggleValue("Idle Builders"), description = Spring.I18N('ui.settings.option.idlebuilders_descr') },
		{ id = "buildbar", group = "ui", category = types.basic, widget = "BuildBar", name = Spring.I18N('ui.settings.option.buildbar'), type = "bool", value = GetWidgetToggleValue("BuildBar"), description = Spring.I18N('ui.settings.option.buildbar_descr') },

		{ id = "converterusage", group = "ui", category = types.advanced, widget = "Converter Usage", name = Spring.I18N('ui.settings.option.converterusage'), type = "bool", value = GetWidgetToggleValue("Converter Usage"), description = Spring.I18N('ui.settings.option.converterusage_descr') },

		{ id = "widgetselector", group = "ui", category = types.advanced, name = Spring.I18N('ui.settings.option.widgetselector'), type = "bool", value = Spring.GetConfigInt("widgetselector", 0) == 1, description = Spring.I18N('ui.settings.option.widgetselector_descr'),
		  onchange = function(i, value)
			  Spring.SetConfigInt("widgetselector", (value and 1 or 0))
		  end,
		},


		{ id = "label_ui_visuals", group = "ui", name = Spring.I18N('ui.settings.option.label_visuals'), category = types.basic },
		{ id = "label_ui_visuals_spacer", group = "ui", category = types.basic },

		{ id = "uniticon_scaleui", group = "ui", category = types.basic, name = Spring.I18N('ui.settings.option.uniticonscaleui'), type = "slider", min = 0.85, max = 3, step = 0.05, value = tonumber(Spring.GetConfigFloat("UnitIconScaleUI", 1) or 1), description = Spring.I18N('ui.settings.option.uniticonscaleui_descr'),
		  onchange = function(i, value)
			  Spring.SendCommands("iconscaleui " .. value)
			  Spring.SetConfigFloat("UnitIconScaleUI", value)
		  end,
		},
		{ id = "uniticon_distance", group = "ui", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.uniticondistance'), type = "slider", min = 1, max = 12000, step = 50, value = tonumber(Spring.GetConfigInt("UnitIconFadeVanish", 2700) or 1), description = Spring.I18N('ui.settings.option.uniticondistance_descr'),
		  onchange = function(i, value)
			  Spring.SendCommands("iconfadestart " .. value)
			  Spring.SetConfigInt("UnitIconFadeStart", value)
			  -- update UnitIconFadeVanish too
			  Spring.SendCommands("iconfadevanish " .. value)
			  Spring.SetConfigInt("UnitIconFadeVanish", value)
		  end,
		},
		{ id = "uniticon_hidewithui", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.uniticonhidewithui'), type = "bool", value = (Spring.GetConfigInt("UnitIconsHideWithUI", 0) == 1), description = Spring.I18N('ui.settings.option.uniticonhidewithui_descr'),
		  onchange = function(i, value)
			  Spring.SendCommands("iconshidewithui " .. (value and 1 or 0))
			  Spring.SetConfigInt("UnitIconsHideWithUI", (value and 1 or 0))
		  end,
		},

		-- { id = "teamcolors", group = "ui", category = types.basic, widget = "Player Color Palette", name = Spring.I18N('ui.settings.option.teamcolors'), type = "bool", value = GetWidgetToggleValue("Player Color Palette"), description = Spring.I18N('ui.settings.option.teamcolors_descr') },
		-- { id = "sameteamcolors", group = "ui", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.sameteamcolors'), type = "bool", value = (WG['playercolorpalette'] ~= nil and WG['playercolorpalette'].getSameTeamColors ~= nil and WG['playercolorpalette'].getSameTeamColors()), description = Spring.I18N('ui.settings.option.sameteamcolors_descr'),
		--   onchange = function(i, value)
		-- 	  saveOptionValue('Player Color Palette', 'playercolorpalette', 'setSameTeamColors', { 'useSameTeamColors' }, value)
		--   end,
		-- },


		{ id = "teamplatter", group = "ui", category = types.basic, widget = "TeamPlatter", name = Spring.I18N('ui.settings.option.teamplatter'), type = "bool", value = GetWidgetToggleValue("TeamPlatter"), description = Spring.I18N('ui.settings.option.teamplatter_descr') },
		{ id = "teamplatter_opacity", category = types.advanced, group = "ui", name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.teamplatter_opacity'), min = 0.05, max = 0.4, step = 0.01, type = "slider", value = 0.25, description = Spring.I18N('ui.settings.option.teamplatter_opacity_descr'),
		  onload = function(i)
			  loadWidgetData("TeamPlatter", "teamplatter_opacity", { 'opacity' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('TeamPlatter', 'teamplatter', 'setOpacity', { 'opacity' }, value)
		  end,
		},
		{ id = "teamplatter_skipownteam", category = types.advanced, group = "ui", name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.teamplatter_skipownteam'), type = "bool", value = false, description = Spring.I18N('ui.settings.option.teamplatter_skipownteam_descr'),
		  onload = function(i)
			  loadWidgetData("TeamPlatter", "teamplatter_skipownteam", { 'skipOwnTeam' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('TeamPlatter', 'teamplatter', 'setSkipOwnTeam', { 'skipOwnTeam' }, value)
		  end,
		},

		{ id = "enemyspotter", group = "ui", category = types.basic, widget = "EnemySpotter", name = Spring.I18N('ui.settings.option.enemyspotter'), type = "bool", value = GetWidgetToggleValue("EnemySpotter"), description = Spring.I18N('ui.settings.option.enemyspotter_descr') },
		{ id = "enemyspotter_opacity", category = types.advanced, group = "ui", name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.enemyspotter_opacity'), min = 0.12, max = 0.4, step = 0.01, type = "slider", value = 0.15, description = Spring.I18N('ui.settings.option.enemyspotter_opacity_descr'),
		  onload = function(i)
			  loadWidgetData("EnemySpotter", "enemyspotter_opacity", { 'opacity' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('EnemySpotter', 'enemyspotter', 'setOpacity', { 'opacity' }, value)
		  end,
		},

		--{ id = "selectedunits", group = "ui", category = types.basic, widget = "Selected Units GL4", name = "Selection", type = "bool", value = GetWidgetToggleValue("Selected Units GL4"), description = Spring.I18N('ui.settings.option.selectedunits_descr') },
		{ id = "selectedunits_opacity", group = "ui", category = types.advanced, name = Spring.I18N('ui.settings.option.selectedunits')..widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.selectedunits_opacity'), min = 0, max = 0.5, step = 0.01, type = "slider", value = 0.19, description = Spring.I18N('ui.settings.option.selectedunits_opacity_descr'),
		  onload = function(i)
			  loadWidgetData("Selected Units GL4", "selectedunits_opacity", { 'opacity' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Selected Units GL4', 'selectedunits', 'setOpacity', { 'opacity' }, value)
		  end,
		},
		{ id = "selectedunits_teamcoloropacity", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.selectedunits_teamcoloropacity'), min = 0, max = 1, step = 0.01, type = "slider", value = 0.6, description = Spring.I18N('ui.settings.option.selectedunits_teamcoloropacity_descr'),
		  onload = function(i)
			  loadWidgetData("Selected Units GL4", "selectedunits_teamcoloropacity", { 'teamcolorOpacity' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Selected Units GL4', 'selectedunits', 'setTeamcolorOpacity', { 'teamcolorOpacity' }, value)
		  end,
		},

		--{ id = "highlightselunits", group = "ui", category = types.basic, widget = "Highlight Selected Units GL4", name = Spring.I18N('ui.settings.option.highlightselunits'), type = "bool", value = GetWidgetToggleValue("Highlight Selected Units GL4"), description = Spring.I18N('ui.settings.option.highlightselunits_descr') },

		{ id = "highlightselunits", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.highlightselunits'),  type = "bool", value = true, description = Spring.I18N('ui.settings.option.selectedunits_teamcoloropacity_descr'),
		  onload = function(i)
			  loadWidgetData("Selected Units GL4", "highlightselunits", { 'selectionHighlight' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Selected Units GL4', 'selectedunits', 'setSelectionHighlight', { 'selectionHighlight' }, value)
		  end,
		},
		--{ id = "highlightselunits_opacity", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.highlightselunits_opacity'), min = 0.02, max = 0.12, step = 0.01, type = "slider", value = 0.05, description = Spring.I18N('ui.settings.option.highlightselunits_opacity_descr'),
		--  onload = function(i)
		--	  loadWidgetData("Highlight Selected Units GL4", "highlightselunits_opacity", { 'highlightAlpha' })
		--  end,
		--  onchange = function(i, value)
		--	  saveOptionValue('Highlight Selected Units GL4', 'highlightselunits', 'setOpacity', { 'highlightAlpha' }, value)
		--  end,
		--},
		--{ id = "highlightselunits_teamcolor", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.highlightselunits_teamcolor'), type = "bool", value = false, description = Spring.I18N('ui.settings.option.highlightselunits_teamcolor_descr'),
		--  onload = function(i)
		--	  loadWidgetData("Highlight Selected Units GL4", "highlightselunits_teamcolor", { 'useTeamcolor' })
		--  end,
		--  onchange = function(i, value)
		--	  saveOptionValue('Highlight Selected Units GL4', 'highlightselunits', 'setTeamcolor', { 'useTeamcolor' }, value)
		--  end,
		--},

		-- { id = "highlightunit", group = "ui", category = types.advanced, widget = "Highlight Unit GL4", name = Spring.I18N('ui.settings.option.highlightunit'), type = "bool", value = GetWidgetToggleValue("Highlight Unit GL4"), description = Spring.I18N('ui.settings.option.highlightunit_descr') },

		{ id = "highlightunit", group = "ui", category = types.advanced, name = Spring.I18N('ui.settings.option.highlightunit'),  type = "bool", value = true, description = Spring.I18N('ui.settings.option.highlightunit_descr'),
		  onload = function(i)
			  loadWidgetData("Selected Units GL4", "highlightunit", { 'mouseoverHighlight' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Selected Units GL4', 'selectedunits', 'setMouseoverHighlight', { 'mouseoverHighlight' }, value)
		  end,
		},

		{ id = "ghosticons_brightness", group = "ui", category = types.dev, name = Spring.I18N('ui.settings.option.ghosticons') .. widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.ghosticons_brightness'), min = 0, max = 1.0, step = 0.15, type = "slider", value = Spring.GetConfigFloat("UnitGhostIconsDimming", 0.8), description = Spring.I18N('ui.settings.option.ghosticons_brightness_descr'),
		  onchange = function(i, value)
			  Spring.SetConfigFloat("UnitGhostIconsDimming", value)
		  end,
		},

		{ id = "cursorlight", group = "ui", category = types.advanced, name = Spring.I18N('ui.settings.option.cursorlight'), type = "bool", value = false, description = Spring.I18N('ui.settings.option.cursorlight_descr'),
		  onload = function(i)
			loadWidgetData("Deferred rendering GL4", "cursorlight", { 'showPlayerCursorLight' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Deferred rendering GL4', 'lightsgl4', 'ShowPlayerCursorLight', { 'showPlayerCursorLight' }, value)
		  end,
		},
		{ id = "cursorlight_lightradius", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.cursorlight_lightradius'), type = "slider", min = 0.3, max = 2, step = 0.05, value = 1, description = '',
		  onload = function(i)
			  loadWidgetData("Deferred rendering GL4", "cursorlight_lightradius", { 'playerCursorLightRadius' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Deferred rendering GL4', 'lightsgl4', 'PlayerCursorLightRadius', { 'playerCursorLightRadius' }, value)
		  end,
		},
		{ id = "cursorlight_lightstrength", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.cursorlight_lightstrength'), type = "slider", min = 0.3, max = 2, step = 0.05, value = 1, description = '',
		  onload = function(i)
			  loadWidgetData("Cursor Light", "cursorlight_lightstrength", { 'playerCursorLightBrightness' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Deferred rendering GL4', 'lightsgl4', 'PlayerCursorLightBrightness', { 'playerCursorLightBrightness' }, value)
		  end,
		},


		{ id = "label_ui_info", group = "ui", name = Spring.I18N('ui.settings.option.label_info'), category = types.basic },
		{ id = "label_ui_info_spacer", group = "ui", category = types.basic },

		{ id = "metalspots_values", group = "ui", category = types.advanced, name = Spring.I18N('ui.settings.option.metalspots')..widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.metalspots_values'), type = "bool", value = (WG['metalspots'] ~= nil and WG['metalspots'].getShowValue()), description = Spring.I18N('ui.settings.option.metalspots_values_descr'),
		  onload = function(i)
			  loadWidgetData("Metalspots", "metalspots_values", { 'showValues' })
		  end,
		  onchange = function(i, value)
			  if WG.metalspots then
			  	WG.metalspots.setShowValue(value)
			  end
			  saveOptionValue('Metalspots', 'metalspots', 'setShowValue', { 'showValue' }, options[getOptionByID('metalspots_values')].value)
		  end,
		},
		{ id = "metalspots_metalviewonly", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.metalspots_metalviewonly'), type = "bool", value = false, description = Spring.I18N('ui.settings.option.metalspots_metalviewonly_descr'),
		  onload = function(i)
			  loadWidgetData("Metalspots", "metalspots_metalviewonly", { 'metalViewOnly' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Metalspots', 'metalspots', 'setMetalViewOnly', { 'showValue' }, options[getOptionByID('metalspots_metalviewonly')].value)
		  end,
		},

		{ id = "geospots", group = "ui", category = types.dev, widget = "Geothermalspots", name = Spring.I18N('ui.settings.option.geospots'), type = "bool", value = GetWidgetToggleValue("Metalspots"), description = Spring.I18N('ui.settings.option.geospots_descr') },

		{ id = "healthbarsscale", group = "ui", category = types.advanced, name = Spring.I18N('ui.settings.option.healthbars') .. widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.healthbarsscale'), type = "slider", min = 0.6, max = 2.0, step = 0.1, value = 1, description = '',
		  onload = function(i)
			  loadWidgetData("Health Bars GL4", "healthbarsscale", { 'barScale' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Health Bars GL4', 'healthbars', 'setScale', { 'barScale' }, value)
		  end,
		},
		{ id = "healthbarsheight", group = "ui", category = types.advanced, name = widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.healthbarsheight'), type = "slider", min = 0.7, max = 2, step = 0.1, value = (WG['healthbar'] ~= nil and WG['healthbar'].getHeight() or 0.9), description = '',
		  onload = function(i)
			  loadWidgetData("Health Bars GL4", "healthbarsheight", { 'barHeight' })
		  end,
		  onchange = function(i, value)
			saveOptionValue('Health Bars GL4', "healthbars", "setHeight", { 'barHeight' }, value)
			widgetHandler:DisableWidget("Health Bars GL4")
			widgetHandler:EnableWidget("Health Bars GL4")
		  end,
		},
		{ id = "healthbarsvariable", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.healthbarsvariable'), type = "bool", value = (WG['healthbar'] ~= nil and WG['healthbar'].getVariableSizes()), description = Spring.I18N('ui.settings.option.healthbarsvariable_descr'),
		  onload = function(i)
			  loadWidgetData("Health Bars GL4", "healthbarsvariable", { "variableBarSizes" })
		  end,
		  onchange = function(i, value)
			  saveOptionValue("Health Bars GL4", "healthbars", "setVariableSizes", { "variableBarSizes" }, value)
		  end,
		},
		{ id = "healthbarswhenguihidden", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.healthbarswhenguihidden'), type = "bool", value = (WG['healthbar'] ~= nil and WG['healthbar'].getDrawWhenGuiHidden()), description = Spring.I18N('ui.settings.option.healthbarswhenguihidden_descr'),
		  onload = function(i)
			  loadWidgetData("Health Bars GL4", "healthbarswhenguihidden", { "drawWhenGuiHidden" })
		  end,
		  onchange = function(i, value)
			  saveOptionValue("Health Bars GL4", "healthbars", "setDrawWhenGuiHidden", { "drawWhenGuiHidden" }, value)
		  end,
		},
		{ id = "rankicons", group = "ui", category = types.advanced, widget = "Rank Icons GL4", name = Spring.I18N('ui.settings.option.rankicons'), type = "bool", value = GetWidgetToggleValue("Rank Icons GL4"), description = Spring.I18N('ui.settings.option.rankicons_descr') },
		{ id = "rankicons_distance", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.rankicons_distance'), type = "slider", min = 0.1, max = 1.5, step = 0.05, value = (WG['rankicons'] ~= nil and WG['rankicons'].getDrawDistance ~= nil and WG['rankicons'].getDrawDistance()), description = '',
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Rank Icons', 'rankicons', 'setDrawDistance', { 'distanceMult' }, value)
		  end,
		},
		{ id = "rankicons_scale", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.rankicons_scale'), type = "slider", min = 0.5, max = 2, step = 0.1, value = (WG['rankicons'] ~= nil and WG['rankicons'].getScale ~= nil and WG['rankicons'].getScale()), description = '',
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Rank Icons', 'rankicons', 'setScale', { 'iconsizeMult' }, value)
		  end,
		},

		{ id = "allycursors", group = "ui", category = types.basic, widget = "AllyCursors", name = Spring.I18N('ui.settings.option.allycursors'), type = "bool", value = GetWidgetToggleValue("AllyCursors"), description = Spring.I18N('ui.settings.option.allycursors_descr') },
		{ id = "allycursors_playername", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.allycursors_playername'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.allycursors_playername_descr'),
		  onload = function(i)
			  loadWidgetData("AllyCursors", "allycursors_playername", { 'showPlayerName' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AllyCursors', 'allycursors', 'setPlayerNames', { 'showPlayerName' }, value)
		  end,
		},
		{ id = "allycursors_showdot", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.allycursors_showdot'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.allycursors_showdot_descr'),
		  onload = function(i)
			  loadWidgetData("AllyCursors", "allycursors_showdot", { 'showCursorDot' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AllyCursors', 'allycursors', 'setCursorDot', { 'showCursorDot' }, value)
		  end,
		},
		{ id = "allycursors_spectatorname", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.allycursors_spectatorname'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.allycursors_spectatorname_descr'),
		  onload = function(i)
			  loadWidgetData("AllyCursors", "allycursors_spectatorname", { 'showSpectatorName' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AllyCursors', 'allycursors', 'setSpectatorNames', { 'showSpectatorName' }, value)
		  end,
		},
		{ id = "allycursors_lights", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.allycursors_lights'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.allycursors_lights_descr'),
		  onload = function(i)
			  loadWidgetData("AllyCursors", "allycursors_lights", { 'addLights' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AllyCursors', 'allycursors', 'setLights', { 'addLights' }, options[getOptionByID('allycursors_lights')].value)
		  end,
		},
		{ id = "allycursors_lightradius", group = "ui", category = types.dev, name = widgetOptionColor .. "      " .. Spring.I18N('ui.settings.option.allycursors_lightradius'), type = "slider", min = 0.15, max = 1, step = 0.05, value = 0.5, description = '',
		  onload = function(i)
			  loadWidgetData("AllyCursors", "allycursors_lightradius", { 'lightRadiusMult' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AllyCursors', 'allycursors', 'setLightRadius', { 'lightRadiusMult' }, value)
		  end,
		},
		{ id = "allycursors_lightstrength", group = "ui", category = types.dev , name = widgetOptionColor .. "      " .. Spring.I18N('ui.settings.option.allycursors_lightstrength'), type = "slider", min = 0.1, max = 1.2, step = 0.05, value = 0.85, description = '',
		  onload = function(i)
			  loadWidgetData("AllyCursors", "allycursors_lightstrength", { 'lightStrengthMult' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AllyCursors', 'allycursors', 'setLightStrength', { 'lightStrengthMult' }, value)
		  end,
		},
		{ id = "allycursors_selfshadowing", group = "ui", category = types.dev , name = widgetOptionColor .. "      " .. Spring.I18N('ui.settings.option.allycursors_selfshadowing'), type = "bool", value = false, description = '',
		  onload = function(i)
			  loadWidgetData("AllyCursors", "allycursors_selfshadowing", { 'lightSelfShadowing' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AllyCursors', 'allycursors', 'setLightSelfShadowing', { 'lightSelfShadowing' }, value)
		  end,
		},

		{ id = "showbuilderqueue", group = "ui", category = types.advanced, widget = "Show Builder Queue", name = Spring.I18N('ui.settings.option.showbuilderqueue'), type = "bool", value = GetWidgetToggleValue("Show Builder Queue"), description = Spring.I18N('ui.settings.option.showbuilderqueue_descr') },

		{ id = "unitenergyicons", group = "ui", category = types.advanced, widget = "Unit Energy Icons", name = Spring.I18N('ui.settings.option.unitenergyicons'), type = "bool", value = GetWidgetToggleValue("Unit Energy Icons"), description = Spring.I18N('ui.settings.option.unitenergyicons_descr') },

		{ id = "unitidlebuildericons", group = "ui", category = types.advanced, widget = "Unit Idle Builder Icons", name = Spring.I18N('ui.settings.option.unitidlebuildericons'), type = "bool", value = GetWidgetToggleValue("Unit Idle Builder Icons"), description = Spring.I18N('ui.settings.option.unitidlebuildericons_descr') },

		{ id = "nametags_rank", group = "ui", category = types.advanced, name = Spring.I18N('ui.settings.option.nametags_rank'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.nametags_rank_descr'),
		  onload = function(i)
			  loadWidgetData("Commander Name Tags", "nametags_rank", { 'showPlayerRank' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Commander Name Tags', 'nametags', 'SetShowPlayerRank', { 'showPlayerRank' }, value)
		  end,
		},

		{ id = "commandsfx", group = "ui", category = types.basic, widget = "Commands FX", name = Spring.I18N('ui.settings.option.commandsfx'), type = "bool", value = GetWidgetToggleValue("Commands FX"), description = Spring.I18N('ui.settings.option.commandsfx_descr') },

		{ id = "commandsfxopacity", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.commandsfxopacity'), type = "slider", min = 0.25, max = 1, step = 0.1, value = 1, description = '',
		  onload = function(i)
			  loadWidgetData("Commands FX", "commandsfxopacity", { 'opacity' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Commands FX', 'commandsfx', 'setOpacity', { 'opacity' }, value)
		  end,
		},
		{ id = "commandsfxduration", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.commandsfxduration'), type = "slider", min = 0.5, max = 2, step = 0.01, value = 1, description = '',
		  onload = function(i)
			  loadWidgetData("Commands FX", "commandsfxduration", { 'duration' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Commands FX', 'commandsfx', 'setDuration', { 'duration' }, value)
		  end,
		},
		{ id = "commandsfxfilterai", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.commandsfxfilterai'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.commandsfxfilterai_descr'),
		  onload = function(i)
			  loadWidgetData("Commands FX", "commandsfxfilterai", { 'filterAIteams' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Commands FX', 'commandsfx', 'setFilterAI', { 'filterAIteams' }, value)
		  end,
		},
		{ id = "commandsfxuseteamcolors", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.commandsfxuseteamcolors'), type = "bool", value = false, description = Spring.I18N('ui.settings.option.commandsfxuseteamcolors_descr'),
		  onload = function(i)
			  loadWidgetData("Commands FX", "commandsfxuseteamcolors", { 'useTeamColors' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Commands FX', 'commandsfx', 'setUseTeamColors', { 'useTeamColors' }, value)
		  end,
		},
		{ id = "commandsfxuseteamcolorswhenspec", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.commandsfxuseteamcolorswhenspec'), type = "bool", value = false, description = Spring.I18N('ui.settings.option.commandsfxuseteamcolorswhenspec_descr'),
		  onload = function(i)
			  loadWidgetData("Commands FX", "commandsfxuseteamcolorswhenspec", { 'useTeamColorsWhenSpec' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Commands FX', 'commandsfx', 'setUseTeamColorsWhenSpec', { 'useTeamColorsWhenSpec' }, value)
		  end,
		},


		{ id = "flankingicons", group = "ui", category = types.advanced, widget = "Flanking Icons GL4", name = Spring.I18N('ui.settings.option.flankingicons'), type = "bool", value = GetWidgetToggleValue("Flanking Icons GL4"), description = Spring.I18N('ui.settings.option.flankingicons_descr') },

		{ id = "displaydps", group = "ui", category = types.basic, name = Spring.I18N('ui.settings.option.displaydps'), type = "bool", value = tonumber(Spring.GetConfigInt("DisplayDPS", 0) or 0) == 1, description = Spring.I18N('ui.settings.option.displaydps_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("DisplayDPS", (value and 1 or 0))
		  end,
		},

		{ id = "givenunits", group = "ui", category = types.advanced, widget = "Given Units", name = Spring.I18N('ui.settings.option.givenunits'), type = "bool", value = GetWidgetToggleValue("Given Units"), description = Spring.I18N('ui.settings.option.givenunits_descr') },

		{ id = "reclaimfieldhighlight", group = "ui", category = types.advanced, widget = "Reclaim Field Highlight", name = Spring.I18N('ui.settings.option.reclaimfieldhighlight'), type = "select", options = { Spring.I18N('ui.settings.option.reclaimfieldhighlight_always'), Spring.I18N('ui.settings.option.reclaimfieldhighlight_resource'), Spring.I18N('ui.settings.option.reclaimfieldhighlight_reclaimer'), Spring.I18N('ui.settings.option.reclaimfieldhighlight_resbot'), Spring.I18N('ui.settings.option.reclaimfieldhighlight_order'), Spring.I18N('ui.settings.option.reclaimfieldhighlight_disabled') }, value = 3, description = Spring.I18N('ui.settings.option.reclaimfieldhighlight_descr'),
			onload = function(i)
				loadWidgetData("Reclaim Field Highlight", "reclaimfieldhighlight", { 'showOption' })
			end,
			onchange = function(i, value)
				if widgetHandler.orderList["Reclaim Field Highlight"] and widgetHandler.orderList["Reclaim Field Highlight"] >= 0.5 then
					widgetHandler:EnableWidget("Reclaim Field Highlight")
					saveOptionValue('Reclaim Field Highlight', 'reclaimfieldhighlight', 'setShowOption', { 'showOption' }, value)
				else
					saveOptionValue('Reclaim Field Highlight', 'reclaimfieldhighlight', 'setShowOption', { 'showOption' }, value)
				end
			end,
		},

		{ id = "highlightcomwrecks", group = "ui", category = types.advanced, widget = "Highlight Commander Wrecks", name = Spring.I18N('ui.settings.option.highlightcomwrecks'), type = "bool", value = GetWidgetToggleValue("Highlight Commander Wrecks"), description = Spring.I18N('ui.settings.option.highlightcomwrecks_descr') },
		{ id = "highlightcomwrecks_teamcolor", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.highlightcomwrecks_teamcolor'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.highlightcomwrecks_teamcolor_descr'),
		  onload = function(i)
			  loadWidgetData("Highlight Commander Wrecks", "highlightcomwrecks_teamcolor", { 'useTeamColor' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Highlight Commander Wrecks', 'highlightcomwrecks', 'setUseTeamColor', { 'useTeamColor' }, value)
		  end,
		},

		{ id = "buildinggrid", group = "ui", category = types.basic, widget = "Building Grid GL4", name = Spring.I18N('ui.settings.option.buildinggrid'), type = "bool", value = GetWidgetToggleValue("Building Grid GL4"), description = Spring.I18N('ui.settings.option.buildinggrid_descr') },
		{ id = "buildinggridopacity", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.buildinggridopacity'), type = "slider", min = 0.3, max = 1, step = 0.05, value = (WG['buildinggrid'] ~= nil and WG['buildinggrid'].getOpacity ~= nil and WG['buildinggrid'].getOpacity()) or 1, description = '',
		  onload = function(i)
			  loadWidgetData("Building Grid GL4", "buildinggridopacity", { 'opacity' })
		  end,
		  onchange = function(i, value)
			  if widgetHandler.orderList["Building Grid GL4"] and widgetHandler.orderList["Building Grid GL4"] >= 0.5 then
				  widgetHandler:DisableWidget("Building Grid GL4")
				  saveOptionValue('Building Grid GL4', 'buildinggrid', 'setOpacity', { 'opacity' }, value)
				  widgetHandler:EnableWidget("Building Grid GL4")
			  else
				  saveOptionValue('Building Grid GL4', 'buildinggrid', 'setOpacity', { 'opacity' }, value)
			  end
		  end,
		},
		{ id = "startpositionsuggestions", group = "ui", category = types.basic, widget = "Start Position Suggestions", name = Spring.I18N('ui.settings.option.startpositionsuggestions'), type = "bool", value = GetWidgetToggleValue("Start Position Suggestions"), description = Spring.I18N('ui.settings.option.startpositionsuggestions_descr') },

		{ id = "label_ui_ranges", group = "ui", name = Spring.I18N('ui.settings.option.label_ranges'), category = types.basic },
		{ id = "label_ui_ranges_spacer", group = "ui", category = types.basic },


		-- Radar range rings:
		{ id = "radarrange", group = "ui", category = types.advanced, widget = "Sensor Ranges Radar", name = Spring.I18N('ui.settings.option.radarrange'), type = "bool", value = GetWidgetToggleValue("Sensor Ranges Radar"), description = Spring.I18N('ui.settings.option.radarrange_descr') },

		{ id = "radarrangeopacity", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.radarrangeopacity'), type = "slider", min = 0.01, max = 0.33, step = 0.01, value = (WG['radarrange'] ~= nil and WG['radarrange'].getOpacity ~= nil and WG['radarrange'].getOpacity()) or 0.08, description = '',
		  onload = function(i)
			  loadWidgetData("Sensor Ranges Radar", "radarrangeopacity", { 'opacity' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Sensor Ranges Radar', 'radarrange', 'setOpacity', { 'opacity' }, value)
		  end,
		},
		-- Sonar range
		{ id = "sonarrange", group = "ui", category = types.advanced, widget = "Sensor Ranges Sonar", name = Spring.I18N('ui.settings.option.sonarrange'), type = "bool", value = GetWidgetToggleValue("Sensor Ranges Sonar"), description = Spring.I18N('ui.settings.option.sonarrange_descr') },

		{ id = "sonarrangeopacity", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.sonarrangeopacity'), type = "slider", min = 0.01, max = 0.33, step = 0.01, value = (WG['sonarrange'] ~= nil and WG['sonarrange'].getOpacity ~= nil and WG['sonarrange'].getOpacity()) or 0.08, description = '',
		  onload = function(i)
			  loadWidgetData("Sensor Ranges Sonar", "sonarrangeopacity", { 'opacity' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Sensor Ranges Sonar', 'sonarrange', 'setOpacity', { 'opacity' }, value)
		  end,
		},
		-- Jammer range
		{ id = "jammerrange", group = "ui", category = types.advanced, widget = "Sensor Ranges Jammer", name = Spring.I18N('ui.settings.option.jammerrange'), type = "bool", value = GetWidgetToggleValue("Sensor Ranges Jammer"), description = Spring.I18N('ui.settings.option.jammerrange_descr') },

		{ id = "jammerrangeopacity", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.jammerrangeopacity'), type = "slider", min = 0.01, max = 0.66, step = 0.01, value = (WG['jammerrange'] ~= nil and WG['jammerrange'].getOpacity ~= nil and WG['jammerrange'].getOpacity()) or 0.08, description = '',
		  onload = function(i)
			  loadWidgetData("Sensor Ranges Jammer", "jammerrangeopacity", { 'opacity' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Sensor Ranges Jammer', 'jammerrange', 'setOpacity', { 'opacity' }, value)
		  end,
		},
		-- LOS Range:
		{ id = "losrange", group = "ui", category = types.advanced, widget = "Sensor Ranges LOS", name = Spring.I18N('ui.settings.option.losrange'), type = "bool", value = GetWidgetToggleValue("Sensor Ranges LOS"), description = Spring.I18N('ui.settings.option.losrange_descr') },

		{ id = "losrangeopacity", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.losrangeopacity'), type = "slider", min = 0.01, max = 0.33, step = 0.01, value = (WG['losrange'] ~= nil and WG['losrange'].getOpacity ~= nil and WG['losrange'].getOpacity()) or 0.08, description = '',
		  onload = function(i)
			  loadWidgetData("Sensor Ranges LOS", "losrangeopacity", { 'opacity' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Sensor Ranges LOS', 'losrange', 'setOpacity', { 'opacity' }, value)
		  end,
		},
		{ id = "losrangeteamcolors", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.losrangeteamcolors'), type = "bool", value = (WG['losrange'] ~= nil and WG['losrange'].getUseTeamColors ~= nil and WG['losrange'].getUseTeamColors()), description = '',
		  onload = function(i)
			  loadWidgetData("Sensor Ranges LOS", "losrangeteamcolors", { 'useteamcolors' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Sensor Ranges LOS', 'losrange', 'setUseTeamColors', { 'useteamcolors' }, value)
		  end,
		},

		{ id = "attackrange", group = "ui", category = types.basic, widget = "Attack Range GL4", name = Spring.I18N('ui.settings.option.attackrange'), type = "bool", value = GetWidgetToggleValue("Attack Range GL4"), description = Spring.I18N('ui.settings.option.attackrange_descr') },
		{ id = "attackrange_shiftonly", category = types.dev, group = "ui", name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.attackrange_shiftonly'), type = "bool", value = (WG['attackrange'] ~= nil and WG['attackrange'].getShiftOnly ~= nil and WG['attackrange'].getShiftOnly()), description = Spring.I18N('ui.settings.option.attackrange_shiftonly_descr'),
		  onload = function(i)
			loadWidgetData("Attack Range GL4", "attackrange_shiftonly", { 'shift_only' })
		  end,
		  onchange = function(i, value)
			saveOptionValue('Attack Range GL4', 'attackrange', 'setShiftOnly', { 'shift_only' }, value)
		  end,
		},
		{ id = "attackrange_cursorunitrange", category = types.dev, group = "ui", name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.attackrange_cursorunitrange'), type = "bool", value = (WG['attackrange'] ~= nil and WG['attackrange'].getCursorUnitRange ~= nil and WG['attackrange'].getCursorUnitRange()), description = Spring.I18N('ui.settings.option.attackrange_cursorunitrange_descr'),
		  onload = function(i)
			  loadWidgetData("Attack Range GL4", "attackrange_cursorunitrange", { 'cursor_unit_range' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Attack Range GL4', 'attackrange', 'setCursorUnitRange', { 'cursor_unit_range' }, value)
		  end,
		},
		{ id = "attackrange_numrangesmult", group = "game", category = types.dev, name = Spring.I18N('ui.settings.option.attackrange_numrangesmult'), type = "slider", min = 0.3, max = 1, step = 0.1, value = (WG['attackrange'] ~= nil and WG['attackrange'].getOpacity ~= nil and WG['attackrange'].getNumRangesMult()) or 1, description = Spring.I18N('ui.settings.option.attackrange_numrangesmult_descr'),
		  onload = function(i)
			  loadWidgetData("Attack Range GL4", "attackrange_numrangesmult", { 'selectionDisableThresholdMult' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Attack Range GL4', 'attackrange', 'setNumRangesMult', { 'selectionDisableThresholdMult' }, value)
		  end,
		},

		{ id = "defrange", group = "ui", category = types.basic, widget = "Defense Range GL4", name = Spring.I18N('ui.settings.option.defrange'), type = "bool", value = GetWidgetToggleValue("Defense Range GL4"), description = Spring.I18N('ui.settings.option.defrange_descr') },

		{ id = "defrange_allyair", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.defrange_allyair'), type = "bool", value = (WG['defrange'] ~= nil and WG['defrange'].getAllyAir ~= nil and WG['defrange'].getAllyAir()), description = Spring.I18N('ui.settings.option.defrange_allyair_descr'),
		  onload = function(i)
			  loadWidgetData("Defense Range GL4", "defrange_allyair", { 'enabled', 'ally', 'air' })
		  end,
		  onchange = function(i, value)
			  --saveOptionValue('Defense Range', 'defrange', 'setAllyAir', { 'enabled', 'ally', 'air' }, value)
			  saveOptionValue('Defense Range GL4', 'defrange', 'setAllyAir', { 'enabled', 'ally', 'air' }, value)
		  end,
		},
		{ id = "defrange_allyground", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.defrange_allyground'), type = "bool", value = (WG['defrange'] ~= nil and WG['defrange'].getAllyGround ~= nil and WG['defrange'].getAllyGround()), description = Spring.I18N('ui.settings.option.defrange_allyground_descr'),
		  onload = function(i)
			  loadWidgetData("Defense Range GL4", "defrange_allyground", { 'enabled', 'ally', 'ground' })
			  loadWidgetData("Defense Range GL4", "defrange_allycannon", { 'enabled', 'ally', 'cannon' })
		  end,
		  onchange = function(i, value)
			  --saveOptionValue('Defense Range', 'defrange', 'setAllyGround', { 'enabled', 'ally', 'ground' }, value)
			  saveOptionValue('Defense Range GL4', 'defrange', 'setAllyGround', { 'enabled', 'ally', 'ground' }, value)
			  saveOptionValue('Defense Range GL4', 'defrange', 'setAllyGround', { 'enabled', 'ally', 'cannon' }, value)
		  end,
		},
		{ id = "defrange_allynuke", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.defrange_allynuke'), type = "bool", value = (WG['defrange'] ~= nil and WG['defrange'].getAllyNuke ~= nil and WG['defrange'].getAllyNuke()), description = Spring.I18N('ui.settings.option.defrange_allynuke_descr'),
		  onload = function(i)
			  loadWidgetData("Defense Range GL4", "defrange_allynuke", { 'enabled', 'ally', 'nuke' })
		  end,
		  onchange = function(i, value)
			  --saveOptionValue('Defense Range', 'defrange', 'setAllyNuke', { 'enabled', 'ally', 'nuke' }, value)
			  saveOptionValue('Defense Range GL4', 'defrange', 'setAllyNuke', { 'enabled', 'ally', 'nuke' }, value)
		  end,
		},
		{ id = "defrange_allylrpc", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.defrange_allylrpc'), type = "bool", value = (WG['defrange'] ~= nil and WG['defrange'].getAllyLRPC ~= nil and WG['defrange'].getAllyLRPC()), description = Spring.I18N('ui.settings.option.defrange_allylrpc_descr'),
		  onload = function(i)
			  loadWidgetData("Defense Range GL4", "defrange_allylrpc", { 'enabled', 'ally', 'lrpc' })
		  end,
		  onchange = function(i, value)
			  --saveOptionValue('Defense Range', 'defrange', 'setAllyLRPC', { 'enabled', 'ally', 'lrpc' }, value)
			  saveOptionValue('Defense Range GL4', 'defrange', 'setAllyLRPC', { 'enabled', 'ally', 'lrpc' }, value)
		  end,
		},
		{ id = "defrange_enemyair", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.defrange_enemyair'), type = "bool", value = (WG['defrange'] ~= nil and WG['defrange'].getEnemyAir ~= nil and WG['defrange'].getEnemyAir()), description = Spring.I18N('ui.settings.option.defrange_enemyair_descr'),
		  onload = function(i)
			  loadWidgetData("Defense Range GL4", "defrange_enemyair", { 'enabled', 'enemy', 'air' })
		  end,
		  onchange = function(i, value)
			  --saveOptionValue('Defense Range', 'defrange', 'setEnemyAir', { 'enabled', 'enemy', 'air' }, value)
			  saveOptionValue('Defense Range GL4', 'defrange', 'setEnemyAir', { 'enabled', 'enemy', 'air' }, value)
		  end,
		},
		{ id = "defrange_enemyground", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.defrange_enemyground'), type = "bool", value = (WG['defrange'] ~= nil and WG['defrange'].getEnemyGround ~= nil and WG['defrange'].getEnemyGround()), description = Spring.I18N('ui.settings.option.defrange_enemyground_descr'),
		  onload = function(i)
			  loadWidgetData("Defense Range GL4", "defrange_enemyground", { 'enabled', 'enemy', 'ground' })
			  loadWidgetData("Defense Range GL4", "defrange_enemyground", { 'enabled', 'enemy', 'cannon' })
		  end,
		  onchange = function(i, value)
			  --saveOptionValue('Defense Range', 'defrange', 'setEnemyGround', { 'enabled', 'enemy', 'ground' }, value)
			  saveOptionValue('Defense Range GL4', 'defrange', 'setEnemyGround', { 'enabled', 'enemy', 'ground' }, value)
			  saveOptionValue('Defense Range GL4', 'defrange', 'setEnemyGround', { 'enabled', 'enemy', 'cannon' }, value)
		  end,
		},
		{ id = "defrange_enemynuke", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.defrange_enemynuke'), type = "bool", value = (WG['defrange'] ~= nil and WG['defrange'].getEnemyNuke ~= nil and WG['defrange'].getEnemyNuke()), description = Spring.I18N('ui.settings.option.defrange_enemynuke_descr'),
		  onload = function(i)
			  loadWidgetData("Defense Range GL4", "defrange_enemynuke", { 'enabled', 'enemy', 'nuke' })
		  end,
		  onchange = function(i, value)
			  --saveOptionValue('Defense Range', 'defrange', 'setEnemyNuke', { 'enabled', 'enemy', 'nuke' }, value)
			  saveOptionValue('Defense Range GL4', 'defrange', 'setEnemyNuke', { 'enabled', 'enemy', 'nuke' }, value)
		  end,
		},
		{ id = "defrange_enemylrpc", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.defrange_enemylrpc'), type = "bool", value = (WG['defrange'] ~= nil and WG['defrange'].getEnemyLRPC ~= nil and WG['defrange'].getEnemyLRPC()), description = Spring.I18N('ui.settings.option.defrange_enemylrpc_descr'),
		  onload = function(i)
			  loadWidgetData("Defense Range GL4", "defrange_enemylrpc", { 'enabled', 'enemy', 'lrpc' })
		  end,
		  onchange = function(i, value)
			  --saveOptionValue('Defense Range', 'defrange', 'setEnemyLRPC', { 'enabled', 'enemy', 'lrpc' }, value)
			  saveOptionValue('Defense Range GL4', 'defrange', 'setEnemyLRPC', { 'enabled', 'enemy', 'lrpc' }, value)
		  end,
		},

		{ id = "antiranges", group = "ui", category = types.advanced, widget = "Anti Ranges", name = Spring.I18N('ui.settings.option.antiranges'), type = "bool", value = GetWidgetToggleValue("Anti Ranges"), description = Spring.I18N('ui.settings.option.antiranges_descr') },

		{ id = "label_ui_spectator", group = "ui", name = Spring.I18N('ui.settings.option.label_spectator'), category = types.basic },
		{ id = "label_ui_spectator_spacer", group = "ui", category = types.basic },

		{ id = "spectator_hud", group = "ui", category = types.basic, widget = "Spectator HUD", name = Spring.I18N('ui.settings.option.spectator_hud'), type = "bool", value = GetWidgetToggleValue("Spectator HUD"), description = Spring.I18N('ui.settings.option.spectator_hud_descr') },
		{ id = "spectator_hud_size", group = "ui", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.spectator_hud_size'), type = "slider", min = 0.1, max = 2, step = 0.1, value = (WG['spectator_hud'] ~= nil and WG['spectator_hud'].getWidgetSize ~= nil and WG['spectator_hud'].getWidgetSize()) or 0.8, description = '',
		  onload = function(i)
			  loadWidgetData("Spectator HUD", "spectator_hud_size", { 'widgetScale' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Spectator HUD', 'spectator_hud', 'setWidgetSize', { 'widgetScale' }, value)
		  end,
		},

		{ id = "spectator_hud_config", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.spectator_hud_config'), type = "select", options = spectatorHUDConfigOptions, value = (WG['spectator_hud'] ~= nil and WG['spectator_hud'].getConfig ~= nil and WG['spectator_hud'].getConfig()) or 1, description = Spring.I18N('ui.settings.option.spectator_hud_config_descr'),
			onload = function(i)
				loadWidgetData("Spectator HUD", "spectator_hud_config", { 'config' })
			end,
			onchange = function(i, value)
				saveOptionValue('Spectator HUD', 'spectator_hud', 'setConfig', { 'config' }, value)
				init()
			end,
		},

		{ id = "spectator_hud_metric_metalIncome", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.spectator_hud.metalIncome_title'), type = "bool", value = (WG['spectator_hud'] ~= nil and WG['spectator_hud'].getMetricEnabled~= nil and WG['spectator_hud'].getMetricEnabled('metalIncome')) or 1, description = Spring.I18N('ui.spectator_hud.metalIncome_tooltip'),
			onload = function(i)
				loadWidgetData("Spectator HUD", "spectator_hud_metric_metalIncome", { 'metricsEnabled', 'metalIncome' })
			end,
			onchange = function(i, value)
				saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'metalIncome' }, value, { 'metalIncome', value })
			end,
		},
		{ id = "spectator_hud_metric_energyIncome", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.spectator_hud.energyIncome_title'), type = "bool", value = (WG['spectator_hud'] ~= nil and WG['spectator_hud'].getMetricEnabled~= nil and WG['spectator_hud'].getMetricEnabled('energyIncome')) or 1, description = Spring.I18N('ui.spectator_hud.energyIncome_tooltip'),
			onload = function(i)
				loadWidgetData("Spectator HUD", "spectator_hud_metric_energyIncome", { 'metricsEnabled', 'energyIncome' })
			end,
			onchange = function(i, value)
				saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'energyIncome' }, value, { 'energyIncome', value })
			end,
		},
		{ id = "spectator_hud_metric_buildPower", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.spectator_hud.buildPower_title'), type = "bool", value = (WG['spectator_hud'] ~= nil and WG['spectator_hud'].getMetricEnabled~= nil and WG['spectator_hud'].getMetricEnabled('buildPower')) or 1, description = Spring.I18N('ui.spectator_hud.buildPower_tooltip'),
			onload = function(i)
				loadWidgetData("Spectator HUD", "spectator_hud_metric_buildPower", { 'metricsEnabled', 'buildPower' })
			end,
			onchange = function(i, value)
				saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'buildPower' }, value, { 'buildPower', value })
			end,
		},
		{ id = "spectator_hud_metric_metalProduced", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.spectator_hud.metalProduced_title'), type = "bool", value = (WG['spectator_hud'] ~= nil and WG['spectator_hud'].getMetricEnabled~= nil and WG['spectator_hud'].getMetricEnabled('metalProduced')) or 1, description = Spring.I18N('ui.spectator_hud.metalProduced_tooltip'),
			onload = function(i)
				loadWidgetData("Spectator HUD", "spectator_hud_metric_metalProduced", { 'metricsEnabled', 'metalProduced' })
			end,
			onchange = function(i, value)
				saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'metalProduced' }, value, { 'metalProduced', value })
			end,
		},
		{ id = "spectator_hud_metric_energyProduced", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.spectator_hud.energyProduced_title'), type = "bool", value = (WG['spectator_hud'] ~= nil and WG['spectator_hud'].getMetricEnabled~= nil and WG['spectator_hud'].getMetricEnabled('energyProduced')) or 1, description = Spring.I18N('ui.spectator_hud.energyProduced_tooltip'),
			onload = function(i)
				loadWidgetData("Spectator HUD", "spectator_hud_metric_energyProduced", { 'metricsEnabled', 'energyProduced' })
			end,
			onchange = function(i, value)
				saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'energyProduced' }, value, { 'energyProduced', value })
			end,
		},
		{ id = "spectator_hud_metric_metalExcess", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.spectator_hud.metalExcess_title'), type = "bool", value = (WG['spectator_hud'] ~= nil and WG['spectator_hud'].getMetricEnabled~= nil and WG['spectator_hud'].getMetricEnabled('metalExcess')) or 1, description = Spring.I18N('ui.spectator_hud.metalExcess_tooltip'),
			onload = function(i)
				loadWidgetData("Spectator HUD", "spectator_hud_metric_metalExcess", { 'metricsEnabled', 'metalExcess' })
			end,
			onchange = function(i, value)
				saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'metalExcess' }, value, { 'metalExcess', value })
			end,
		},
		{ id = "spectator_hud_metric_energyExcess", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.spectator_hud.energyExcess_title'), type = "bool", value = (WG['spectator_hud'] ~= nil and WG['spectator_hud'].getMetricEnabled~= nil and WG['spectator_hud'].getMetricEnabled('energyExcess')) or 1, description = Spring.I18N('ui.spectator_hud.energyExcess_tooltip'),
			onload = function(i)
				loadWidgetData("Spectator HUD", "spectator_hud_metric_energyExcess", { 'metricsEnabled', 'energyExcess' })
			end,
			onchange = function(i, value)
				saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'energyExcess' }, value, { 'energyExcess', value })
			end,
		},
		{ id = "spectator_hud_metric_armyValue", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.spectator_hud.armyValue_title'), type = "bool", value = (WG['spectator_hud'] ~= nil and WG['spectator_hud'].getMetricEnabled~= nil and WG['spectator_hud'].getMetricEnabled('armyValue')) or 1, description = Spring.I18N('ui.spectator_hud.armyValue_tooltip'),
			onload = function(i)
				loadWidgetData("Spectator HUD", "spectator_hud_metric_armyValue", { 'metricsEnabled', 'armyValue' })
			end,
			onchange = function(i, value)
				saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'armyValue' }, value, { 'armyValue', value })
			end,
		},
		{ id = "spectator_hud_metric_defenseValue", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.spectator_hud.defenseValue_title'), type = "bool", value = (WG['spectator_hud'] ~= nil and WG['spectator_hud'].getMetricEnabled~= nil and WG['spectator_hud'].getMetricEnabled('defenseValue')) or 1, description = Spring.I18N('ui.spectator_hud.defenseValue_tooltip'),
			onload = function(i)
				loadWidgetData("Spectator HUD", "spectator_hud_metric_defenseValue", { 'metricsEnabled', 'defenseValue' })
			end,
			onchange = function(i, value)
				saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'defenseValue' }, value, { 'defenseValue', value })
			end,
		},
		{ id = "spectator_hud_metric_utilityValue", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.spectator_hud.utilityValue_title'), type = "bool", value = (WG['spectator_hud'] ~= nil and WG['spectator_hud'].getMetricEnabled~= nil and WG['spectator_hud'].getMetricEnabled('utilityValue')) or 1, description = Spring.I18N('ui.spectator_hud.utilityValue_tooltip'),
			onload = function(i)
				loadWidgetData("Spectator HUD", "spectator_hud_metric_utilityValue", { 'metricsEnabled', 'utilityValue' })
			end,
			onchange = function(i, value)
				saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'utilityValue' }, value, { 'utilityValue', value })
			end,
		},
		{ id = "spectator_hud_metric_economyValue", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.spectator_hud.economyValue_title'), type = "bool", value = (WG['spectator_hud'] ~= nil and WG['spectator_hud'].getMetricEnabled~= nil and WG['spectator_hud'].getMetricEnabled('economyValue')) or 1, description = Spring.I18N('ui.spectator_hud.economyValue_tooltip'),
			onload = function(i)
				loadWidgetData("Spectator HUD", "spectator_hud_metric_economyValue", { 'metricsEnabled', 'economyValue' })
			end,
			onchange = function(i, value)
				saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'economyValue' }, value, { 'economyValue', value })
			end,
		},
		{ id = "spectator_hud_metric_damageDealt", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.spectator_hud.damageDealt_title'), type = "bool", value = (WG['spectator_hud'] ~= nil and WG['spectator_hud'].getMetricEnabled~= nil and WG['spectator_hud'].getMetricEnabled('damageDealt')) or 1, description = Spring.I18N('ui.spectator_hud.damageDealt_tooltip'),
			onload = function(i)
				loadWidgetData("Spectator HUD", "spectator_hud_metric_damageDealt", { 'metricsEnabled', 'damageDealt' })
			end,
			onchange = function(i, value)
				saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'damageDealt' }, value, { 'damageDealt', value })
			end,
		},

		{ id = "label_ui_developer", group = "ui", name = Spring.I18N('ui.settings.option.label_developer'), category = types.advanced },
		{ id = "label_ui_developer_spacer", group = "ui", category = types.advanced },

		{ id = "devmode", group = "ui", category = types.advanced, name = Spring.I18N('ui.settings.option.devmode'), type = "bool", value = devUI, description = Spring.I18N('ui.settings.option.devmode_descr'),
		  onchange = function(i, value)
			  devUI = value
			  Spring.SetConfigInt("DevUI", value and 1 or 0)
			  Spring.SendCommands("luaui reload")
		  end,
		},

		-- GAME
		{ id = "networksmoothing", restart = true, category = types.basic, group = "game", name = Spring.I18N('ui.settings.option.networksmoothing'), type = "bool", value = useNetworkSmoothing, description = Spring.I18N('ui.settings.option.networksmoothing_descr'),
		  onload = function(i)
			  options[i].onchange(i, options[i].value)
		  end,
		  onchange = function(i, value)
			  useNetworkSmoothing = value
			  if useNetworkSmoothing then
				  Spring.SetConfigInt("UseNetMessageSmoothingBuffer", 1)
				  Spring.SetConfigInt("NetworkLossFactor", 0)
				  Spring.SetConfigInt("LinkOutgoingBandwidth", 196608)
				  Spring.SetConfigInt("LinkIncomingSustainedBandwidth", 196608)
				  Spring.SetConfigInt("LinkIncomingPeakBandwidth", 196608)
				  Spring.SetConfigInt("LinkIncomingMaxPacketRate", 1024)
			  else
				  Spring.SetConfigInt("UseNetMessageSmoothingBuffer", 0)
				  Spring.SetConfigInt("NetworkLossFactor", 2)
				  Spring.SetConfigInt("LinkOutgoingBandwidth", 196608)
				  Spring.SetConfigInt("LinkIncomingSustainedBandwidth", 1048576)
				  Spring.SetConfigInt("LinkIncomingPeakBandwidth", 1048576)
				  Spring.SetConfigInt("LinkIncomingMaxPacketRate", 2048)
			  end
		  end,
		},
		{ id = "autoquit", group = "game", category = types.basic, widget = "Autoquit", name = Spring.I18N('ui.settings.option.autoquit'), type = "bool", value = GetWidgetToggleValue("Autoquit"), description = Spring.I18N('ui.settings.option.autoquit_descr') },

		{ id = "singleplayerpause", group = "game", category = types.advanced, name = Spring.I18N('ui.settings.option.singleplayerpause'), type = "bool", value = pauseGameWhenSingleplayer, description = Spring.I18N('ui.settings.option.singleplayerpause_descr'),
		  onchange = function(i, value)
			  pauseGameWhenSingleplayer = value
			  if (isSinglePlayer or isReplay) and show then
				  if pauseGameWhenSingleplayer then
					  Spring.SendCommands("pause " .. (pauseGameWhenSingleplayer and '1' or '0'))
					  pauseGameWhenSingleplayerExecuted = pauseGameWhenSingleplayer
				  elseif pauseGameWhenSingleplayerExecuted then
					  Spring.SendCommands("pause 0")
					  pauseGameWhenSingleplayerExecuted = false
				  end
			  end
		  end,
		},

		{ id = "catchupsmoothness", group = "game", category = types.dev, name = Spring.I18N('ui.settings.option.catchupsmoothness'), restart = true, type = "slider", min = 0.05, max = 0.3, step = 0.01, value = Spring.GetConfigFloat("MinSimDrawBalance", 0.15), description = Spring.I18N('ui.settings.option.catchupsmoothness_descr'),
		  onchange = function(i, value)
			  Spring.SetConfigFloat("MinSimDrawBalance", value)
		  end,
		},
		{ id = "catchupminfps", group = "game", category = types.dev, name = Spring.I18N('ui.settings.option.catchupminfps'), restart = true, type = "slider", min = 2, max = 15, step = 1, value = Spring.GetConfigInt("MinDrawFPS", 2), description = Spring.I18N('ui.settings.option.catchupminfps_descr'),
		  onchange = function(i, value)
			  Spring.SetConfigInt("MinDrawFPS", value)
		  end,
		},

		{ id = "label_ui_behavior", group = "game", name = Spring.I18N('ui.settings.option.label_behavior'), category = types.basic },
		{ id = "label_ui_behavior_spacer", group = "game", category = types.basic },


		{ id = "smartselect_includebuildings", group = "game", category = types.basic, name = Spring.I18N('ui.settings.option.smartselect_includebuildings'), type = "bool", value = false, description = Spring.I18N('ui.settings.option.smartselect_includebuildings_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('SmartSelect', 'smartselect', 'setIncludeBuildings', { 'selectBuildingsWithMobile' }, value)
		  end,
		},
		{ id = "smartselect_includebuilders", group = "game", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.smartselect_includebuilders'), type = "bool", value = false, description = Spring.I18N('ui.settings.option.smartselect_includebuilders_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('SmartSelect', 'smartselect', 'setIncludeBuilders', { 'includeBuilders' }, value)
		  end,
		},


		{ id = "prioconturrets", group = "game", category = types.basic, widget = "Priority Construction Turrets", name = Spring.I18N('ui.settings.option.prioconturrets'), type = "bool", value = GetWidgetToggleValue("Priority Construction Turrets"), description = Spring.I18N('ui.settings.option.prioconturrets_descr') },

		{
			id = "builderpriority",
			group = "game",
			category = types.basic,
			widget = "Builder Priority",
			name = Spring.I18N('ui.settings.option.builderpriority'),
			type = "bool",
			value = GetWidgetToggleValue("Builder Priority"),
			description = Spring.I18N('ui.settings.option.builderpriority_descr'),
		},

		{
			id = "builderpriority_nanos",
			group = "game",
			category = types.advanced,
			name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.builderpriority_nanos'),
			type = "bool",
			value = (
					WG['builderpriority'] ~= nil
							and WG['builderpriority'].getLowPriorityNanos ~= nil
							and WG['builderpriority'].getLowPriorityNanos()
			),
			description = Spring.I18N('ui.settings.option.builderpriority_nanos_descr'),
			onload = function(i)
				loadWidgetData("Builder Priority", "builderpriority_nanos", { 'lowpriorityNanos' })
			end,
			onchange = function(i, value)
				saveOptionValue('Builder Priority', 'builderpriority', 'setLowPriorityNanos', { 'lowpriorityNanos' }, value)
			end,
		},

		{
			id = "builderpriority_cons",
			group = "game",
			category = types.advanced,
			name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.builderpriority_cons'),
			type = "bool",
			value = (
					WG['builderpriority'] ~= nil
							and WG['builderpriority'].getLowPriorityCons ~= nil
							and WG['builderpriority'].getLowPriorityCons()
			),
			description = Spring.I18N('ui.settings.option.builderpriority_cons_descr'),
			onload = function(i)
				loadWidgetData("Builder Priority", "builderpriority_cons", { 'lowpriorityCons' })
			end,
			onchange = function(i, value)
				saveOptionValue('Builder Priority', 'builderpriority', 'setLowPriorityCons', { 'lowpriorityCons' }, value)
			end,
		},

		{
			id = "builderpriority_labs",
			group = "game",
			category = types.advanced,
			name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.builderpriority_labs'),
			type = "bool",
			value = (
					WG['builderpriority'] ~= nil
							and WG['builderpriority'].getLowPriorityLabs ~= nil
							and WG['builderpriority'].getLowPriorityLabs()
			),
			description = Spring.I18N('ui.settings.option.builderpriority_labs_descr'),
			onload = function(i)
				loadWidgetData("Builder Priority", "builderpriority_labs", { 'lowpriorityLabs' })
			end,
			onchange = function(i, value)
				saveOptionValue('Builder Priority', 'builderpriority', 'setLowPriorityLabs', { 'lowpriorityLabs' }, value)
			end,
		},

		{ id = "factoryguard", group = "game", category = types.basic, widget = "Factory Guard Default On", name = Spring.I18N('ui.settings.option.factory') .. widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.factoryguard'), type = "bool", value = GetWidgetToggleValue("Factory Guard Default On"), description = Spring.I18N('ui.settings.option.factoryguard_descr') },
		{ id = "factoryholdpos", group = "game", category = types.basic, widget = "Factory hold position", name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.factoryholdpos'), type = "bool", value = GetWidgetToggleValue("Factory hold position"), description = Spring.I18N('ui.settings.option.factoryholdpos_descr') },
		{ id = "factoryrepeat", group = "game", category = types.basic, widget = "Factory Auto-Repeat", name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.factoryrepeat'), type = "bool", value = GetWidgetToggleValue("Factory Auto-Repeat"), description = Spring.I18N('ui.settings.option.factoryrepeat_descr') },

		{ id = "transportai", group = "game", category = types.basic, widget = "Transport AI", name = Spring.I18N('ui.settings.option.transportai'), type = "bool", value = GetWidgetToggleValue("Transport AI"), description = Spring.I18N('ui.settings.option.transportai_descr') },

		{ id = "onlyfighterspatrol", group = "game", category = types.basic, widget = "OnlyFightersPatrol", name = Spring.I18N('ui.settings.option.onlyfighterspatrol'), type = "bool", value = GetWidgetToggleValue("Autoquit"), description = Spring.I18N('ui.settings.option.onlyfighterspatrol_descr') },
		{ id = "fightersfly", group = "game", category = types.basic, widget = "Set fighters on Fly mode", name = Spring.I18N('ui.settings.option.fightersfly'), type = "bool", value = GetWidgetToggleValue("Set fighters on Fly mode"), description = Spring.I18N('ui.settings.option.fightersfly_descr') },

		{ id = "settargetdefault", group = "game", category = types.basic, widget = "Set target default", name = Spring.I18N('ui.settings.option.settargetdefault'), type = "bool", value = GetWidgetToggleValue("Set target default"), description = Spring.I18N('ui.settings.option.settargetdefault_descr') },
		{ id = "dgunnogroundenemies", group = "game", category = types.advanced, widget = "DGun no ground enemies", name = Spring.I18N('ui.settings.option.dgunnogroundenemies'), type = "bool", value = GetWidgetToggleValue("DGun no ground enemies"), description = Spring.I18N('ui.settings.option.dgunnogroundenemies_descr') },
		{ id = "dgunstallassist", group = "game", category = types.advanced, widget = "DGun Stall Assist", name = Spring.I18N('ui.settings.option.dgunstallassist'), type = "bool", value = GetWidgetToggleValue("DGun Stall Assist"), description = Spring.I18N('ui.settings.option.dgunstallassist_descr') },

		{ id = "unitreclaimer", group = "game", category = types.basic, widget = "Specific Unit Reclaimer", name = Spring.I18N('ui.settings.option.unitreclaimer'), type = "bool", value = GetWidgetToggleValue("Specific Unit Reclaimer"), description = Spring.I18N('ui.settings.option.unitreclaimer_descr') },

		{ id = "autogroup_immediate", group = "game", category = types.basic, name = Spring.I18N('ui.settings.option.autogroup_immediate'), type = "bool", value = (WG['autogroup'] ~= nil and WG['autogroup'].getImmediate ~= nil and WG['autogroup'].getImmediate()), description = Spring.I18N('ui.settings.option.autogroup_immediate_descr'),
		  onload = function(i)
			  loadWidgetData("Auto Group", "autogroup_immediate", { 'immediate' })
		  end,
		  onchange = function(i, value)
			  if widgetHandler.configData["Auto Group"] == nil then
				  widgetHandler.configData["Auto Group"] = {}
			  end
			  widgetHandler.configData["Auto Group"].immediate = value
			  saveOptionValue('Auto Group', 'autogroup', 'setImmediate', { 'immediate' }, value)
		  end,
		},

		{ id = "autogroup_persist", group = "game", category = types.basic, name = Spring.I18N('ui.settings.option.autogroup_persist'), type = "bool", value = (WG['autogroup'] ~= nil and WG['autogroup'].getPersist ~= nil and WG['autogroup'].getPersist()), description = Spring.I18N('ui.settings.option.autogroup_persist_descr'),
		  onload = function(i)
			  loadWidgetData("Auto Group", "autogroup_persist", { 'persist' })
		  end,
		  onchange = function(i, value)
			  if widgetHandler.configData["Auto Group"] == nil then
				  widgetHandler.configData["Auto Group"] = {}
			  end
			  widgetHandler.configData["Auto Group"].persist = value
			  saveOptionValue('Auto Group', 'autogroup', 'setPersist', { 'persist' }, value)
		  end,
		},

		{ id = "label_ui_cloak", group = "game", name = Spring.I18N('ui.settings.option.label_cloak'), category = types.basic },
		{ id = "label_ui_cloak_spacer", group = "game", category = types.basic },

		{ id = "autocloak", group = "game", category = types.basic, widget = "Auto Cloak Units", name = Spring.I18N('ui.settings.option.autocloak'), type = "bool", value = GetWidgetToggleValue("Auto Cloak Units") },

		-- ACCESSIBILITY

		{ id = "label_teamcolors", group = "accessibility", name = Spring.I18N('ui.settings.option.label_teamcolors'), category = types.basic },
		{ id = "label_teamcolors_spacer", group = "accessibility", category = types.basic },


		{ id = "anonymous_r", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.anonymous_r'), type = "slider", min = 0, max = 255, step = 1, value = tonumber(Spring.GetConfigInt("anonymousColorR", 255)), description = Spring.I18N('ui.settings.option.anonymous_descr'),
		  onchange = function(i, value, force)
			  if force then
				  Spring.SetConfigInt("anonymousColorR", value)
				  Spring.SendCommands("luarules reloadluaui")
			  else
				  sceduleOptionApply = { os.clock() + 1.5, getOptionByID('anonymous_r') }
			  end
		  end,
		},

		{ id = "anonymous_g", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.anonymous_g'), type = "slider", min = 0, max = 255, step = 1, value = tonumber(Spring.GetConfigInt("anonymousColorG", 0)), description = Spring.I18N('ui.settings.option.anonymous_descr'),
		  onchange = function(i, value, force)
			  if force then
				  Spring.SetConfigInt("anonymousColorG", value)
				  Spring.SendCommands("luarules reloadluaui")
			  else
				  sceduleOptionApply = { os.clock() + 1.5, getOptionByID('anonymous_g') }
			  end
		  end,
		},

		{ id = "anonymous_b", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.anonymous_b'), type = "slider", min = 0, max = 255, step = 1, value = tonumber(Spring.GetConfigInt("anonymousColorB", 0)), description = Spring.I18N('ui.settings.option.anonymous_descr'),
		  onchange = function(i, value, force)
			  if force then
				  Spring.SetConfigInt("anonymousColorB", value)
				  Spring.SendCommands("luarules reloadluaui")
			  else
				  sceduleOptionApply = { os.clock() + 1.5, getOptionByID('anonymous_b') }
			  end
		  end,
		},

		{ id = "simpleteamcolors", group = "accessibility", category = types.basic, name = Spring.I18N('ui.settings.option.playercolors'), type = "bool", value = tonumber(Spring.GetConfigInt("SimpleTeamColors", 0) or 0) == 1, description = Spring.I18N('ui.settings.option.simpleteamcolors_descr'),
		  onchange = function(i, value)
			  Spring.SetConfigInt("SimpleTeamColors", (value and 1 or 0))
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},

		{ id = "simpleteamcolors_reset", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " ..  Spring.I18N('ui.settings.option.simpleteamcolors_reset'), type = "bool", value = tonumber(Spring.GetConfigInt("SimpleTeamColors_Reset", 0) or 0) == 1,
		  onchange = function(i, value)
			Spring.SetConfigInt("SimpleTeamColorsUseGradient", 0)
			Spring.SetConfigInt("SimpleTeamColorsPlayerR", 0)
			Spring.SetConfigInt("SimpleTeamColorsPlayerG", 77)
			Spring.SetConfigInt("SimpleTeamColorsPlayerB", 255)
			Spring.SetConfigInt("SimpleTeamColorsAllyR", 0)
            Spring.SetConfigInt("SimpleTeamColorsAllyG", 255)
            Spring.SetConfigInt("SimpleTeamColorsAllyB", 0)
			Spring.SetConfigInt("SimpleTeamColorsEnemyR", 255)
            Spring.SetConfigInt("SimpleTeamColorsEnemyG", 16)
            Spring.SetConfigInt("SimpleTeamColorsEnemyB", 5)
			Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},
		{ id = "simpleteamcolors_use_gradient", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.simpleteamcolors_use_gradient'), type = "bool", value = tonumber(Spring.GetConfigInt("SimpleTeamColorsUseGradient", 0) or 0) == 1,
		  onchange = function(i, value)
			  Spring.SetConfigInt("SimpleTeamColorsUseGradient", (value and 1 or 0))
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},
		{ id = "simpleteamcolors_player_r", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.simpleteamcolors_player_r'), type = "slider", min = 0, max = 255, step = 1, value = tonumber(Spring.GetConfigInt("SimpleTeamColorsPlayerR", 0)),
		  onchange = function(i, value)
			  Spring.SetConfigInt("SimpleTeamColorsPlayerR", value)
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},
		{ id = "simpleteamcolors_player_g", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.simpleteamcolors_player_g'), type = "slider", min = 0, max = 255, step = 1, value = tonumber(Spring.GetConfigInt("SimpleTeamColorsPlayerG", 77)),
		  onchange = function(i, value)
			  Spring.SetConfigInt("SimpleTeamColorsPlayerG", value)
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},
		{ id = "simpleteamcolors_player_b", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.simpleteamcolors_player_b'), type = "slider", min = 0, max = 255, step = 1, value = tonumber(Spring.GetConfigInt("SimpleTeamColorsPlayerB", 255)),
		  onchange = function(i, value)
			  Spring.SetConfigInt("SimpleTeamColorsPlayerB", value)
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},

		{ id = "simpleteamcolors_ally_r", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.simpleteamcolors_ally_r'), type = "slider", min = 0, max = 255, step = 1, value = tonumber(Spring.GetConfigInt("SimpleTeamColorsAllyR", 0)),
		  onchange = function(i, value)
			  Spring.SetConfigInt("SimpleTeamColorsAllyR", value)
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},
		{ id = "simpleteamcolors_ally_g", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.simpleteamcolors_ally_g'), type = "slider", min = 0, max = 255, step = 1, value = tonumber(Spring.GetConfigInt("SimpleTeamColorsAllyG", 255)),
		  onchange = function(i, value)
			  Spring.SetConfigInt("SimpleTeamColorsAllyG", value)
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},
		{ id = "simpleteamcolors_ally_b", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.simpleteamcolors_ally_b'), type = "slider", min = 0, max = 255, step = 1, value = tonumber(Spring.GetConfigInt("SimpleTeamColorsAllyB", 0)),
		  onchange = function(i, value)
			  Spring.SetConfigInt("SimpleTeamColorsAllyB", value)
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},

		{ id = "simpleteamcolors_enemy_r", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.simpleteamcolors_enemy_r'), type = "slider", min = 0, max = 255, step = 1, value = tonumber(Spring.GetConfigInt("SimpleTeamColorsEnemyR", 255)),
		  onchange = function(i, value)
			  Spring.SetConfigInt("SimpleTeamColorsEnemyR", value)
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},
		{ id = "simpleteamcolors_enemy_g", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.simpleteamcolors_enemy_g'), type = "slider", min = 0, max = 255, step = 1, value = tonumber(Spring.GetConfigInt("SimpleTeamColorsEnemyG", 16)),
		  onchange = function(i, value)
			  Spring.SetConfigInt("SimpleTeamColorsEnemyG", value)
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},
		{ id = "simpleteamcolors_enemy_b", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.simpleteamcolors_enemy_b'), type = "slider", min = 0, max = 255, step = 1, value = tonumber(Spring.GetConfigInt("SimpleTeamColorsEnemyB", 5)),
		  onchange = function(i, value)
			  Spring.SetConfigInt("SimpleTeamColorsEnemyB", value)
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},

		-- DEV
		{ id = "customwidgets", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.customwidgets'), type = "bool", value = widgetHandler.allowUserWidgets, description = Spring.I18N('ui.settings.option.customwidgets_descr'),
		  onchange = function(i, value)
			  widgetHandler.__allowUserWidgets = value
			  Spring.SendCommands("luarules reloadluaui")
		  end,
		},

		{ id = "autocheat", group = "dev", category = types.dev, widget = "Dev Auto cheat", name = Spring.I18N('ui.settings.option.autocheat'), type = "bool", value = GetWidgetToggleValue("Dev Auto cheat"), description = Spring.I18N('ui.settings.option.autocheat_descr') },
		{ id = "restart", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.restart'), type = "bool", value = false, description = Spring.I18N('ui.settings.option.restart_descr'),
		  onchange = function(i, value)
			  options[getOptionByID('restart')].value = false
			  Spring.Restart("", startScript)
		  end,
		},

		{ id = "label_dev_debug", group = "dev", name = Spring.I18N('ui.settings.option.label_debug'), category = types.dev },
		{ id = "label_dev_debug_spacer", group = "dev", category = types.dev },

		{ id = "profiler_widget", group = "dev", category = types.dev, widget = "Widget Profiler", name = Spring.I18N('ui.settings.option.profiler') .. widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.profiler_widget'), type = "bool", value = GetWidgetToggleValue("Widget Profiler") },
		{ id = "profiler_gadget", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.profiler_gadget'), type = "bool", value = false,
		  onchange = function(i, value)
			  Spring.SendCommands("luarules profile")
		  end,
		},
		{ id = "profiler_sort_by_load", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.profiler_sort_by_load'), type = "bool", value = Spring.GetConfigInt("profiler_sort_by_load", 1), description = Spring.I18N('ui.settings.option.profiler_sort_by_load_descr'),
		onchange = function(i, value)
			Spring.SetConfigInt("profiler_sort_by_load", (value and '1' or '0'))
		end,
	  },
	  { id = "profiler_averagetime", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.profiler_averagetime'), type = "slider", min = 0.1, max = 10, step = 0.1, value = Spring.GetConfigFloat("profiler_averagetime", 2), description = Spring.I18N('ui.settings.option.profiler_averagetime_descr'),
		onchange = function(i, value)
			Spring.SetConfigFloat("profiler_averagetime", value)
		end,
	  },
		{ id = "framegrapher", group = "dev", category = types.dev, widget = "Frame Grapher", name = Spring.I18N('ui.settings.option.framegrapher'), type = "bool", value = GetWidgetToggleValue("Frame Grapher"), description = "" },

		{ id = "debugcolvol", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.debugcolvol'), type = "bool", value = false, description = "",
		  onchange = function(i, value)
			  Spring.SendCommands("DebugColVol " .. (value and '1' or '0'))
		  end,
		},
		{ id = "echocamerastate", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.echocamerastate'), type = "bool", value = false, description = Spring.I18N('ui.settings.option.echocamerastate_descr'),
		  onchange = function(i, value)
			  options[getOptionByID('echocamerastate')].value = false
			  Spring.Echo(Spring.GetCameraState())
		  end,
		},


		{ id = "label_dev_other", group = "dev", name = Spring.I18N('ui.settings.option.label_other'), category = types.dev },
		{ id = "label_dev_other_spacer", group = "dev", category = types.dev },

		{ id = "storedefaultsettings", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.storedefaultsettings'), type = "bool", value = tonumber(Spring.GetConfigInt("StoreDefaultSettings", 0) or 0) == 1, description = Spring.I18N('ui.settings.option.storedefaultsettings_descr'),
		  onchange = function(i, value)
			  Spring.SetConfigInt("StoreDefaultSettings", (value and 1 or 0))
		  end,
		},

		{ id = "startboxeditor", group = "dev", category = types.dev, widget = "Startbox Editor", name = Spring.I18N('ui.settings.option.startboxeditor'), type = "bool", value = GetWidgetToggleValue("Startbox Editor"), description = Spring.I18N('ui.settings.option.startboxeditor_descr') },

		{ id = "language_dev", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.language'), type = "select", options = devLanguageNames, value = devLanguageCodes[Spring.I18N.getLocale()],
			onchange = function(i, value)
				local devLanguage = devLanguageCodes[value]
				WG['language'].setLanguage(devLanguage)
			end
		},
		{ id = "font", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.font'), type = "select", options = {}, value = 1, description = Spring.I18N('ui.settings.option.font_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  if VFS.FileExists('fonts/' .. options[i].optionsFont[value]) then
				  Spring.SetConfigString("bar_font", options[i].optionsFont[value])
				  Spring.SendCommands("luarules reloadluaui")
			  end
		  end,
		},
		{ id = "font2", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.font2'), type = "select", options = {}, value = 1, description = Spring.I18N('ui.settings.option.font2_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  if VFS.FileExists('fonts/' .. options[i].optionsFont[value]) then
				  Spring.SetConfigString("bar_font2", options[i].optionsFont[value])
				  Spring.SendCommands("luarules reloadluaui")
			  end
		  end,
		},

		--{ id = "label_dev_unit", group = "dev", name = Spring.I18N('ui.settings.option.label_unit'), category = types.dev },
		--{ id = "label_dev_unit_spacer", group = "dev", category = types.dev },
		--
		--{ id = "tonemapA", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.tonemap') .. widgetOptionColor .. "  1", type = "slider", min = 0, max = 7, step = 0.01, value = Spring.GetConfigFloat("tonemapA", 4.8), description = "",
		--  onchange = function(i, value)
		--	  Spring.SetConfigFloat("tonemapA", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "tonemapB", group = "dev", category = types.dev, name = widgetOptionColor .. "   2", type = "slider", min = 0, max = 2, step = 0.01, value = Spring.GetConfigFloat("tonemapB", 0.75), description = "",
		--  onchange = function(i, value)
		--	  Spring.SetConfigFloat("tonemapB", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "tonemapC", group = "dev", category = types.dev, name = widgetOptionColor .. "   3", type = "slider", min = 0, max = 5, step = 0.01, value = Spring.GetConfigFloat("tonemapC", 3.5), description = "",
		--  onchange = function(i, value)
		--	  Spring.SetConfigFloat("tonemapC", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "tonemapD", group = "dev", category = types.dev, name = widgetOptionColor .. "   4", type = "slider", min = 0, max = 3, step = 0.01, value = Spring.GetConfigFloat("tonemapD", 0.85), description = "",
		--  onchange = function(i, value)
		--	  Spring.SetConfigFloat("tonemapD", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "tonemapE", group = "dev", category = types.dev, name = widgetOptionColor .. "   5", type = "slider", min = 0.75, max = 1.5, step = 0.01, value = Spring.GetConfigFloat("tonemapE", 1.0), description = "",
		--  onchange = function(i, value)
		--	  Spring.SetConfigFloat("tonemapE", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "envAmbient", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.envAmbient'), type = "slider", min = 0, max = 1, step = 0.01, value = Spring.GetConfigFloat("envAmbient", 0.25), description = "",
		--  onchange = function(i, value)
		--	  Spring.SetConfigFloat("envAmbient", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "unitSunMult", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.unitSunMult'), type = "slider", min = 0.7, max = 1.6, step = 0.01, value = Spring.GetConfigFloat("unitSunMult", 1.0), description = "",
		--  onchange = function(i, value)
		--	  Spring.SetConfigFloat("unitSunMult", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "unitExposureMult", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.unitExposureMult'), type = "slider", min = 0.6, max = 1.25, step = 0.01, value = Spring.GetConfigFloat("unitExposureMult", 1.0), description = "",
		--  onchange = function(i, value)
		--	  Spring.SetConfigFloat("unitExposureMult", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "modelGamma", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.modelGamma'), type = "slider", min = 0.7, max = 1.7, step = 0.01, value = Spring.GetConfigFloat("modelGamma", 1.0), description = "",
		--  onchange = function(i, value)
		--	  Spring.SetConfigFloat("modelGamma", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "tonemapDefaults", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.tonemapDefaults'), type = "bool", value = GetWidgetToggleValue("Unit Reclaimer"), description = "",
		--  onchange = function(i, value)
		--	  Spring.SetConfigFloat("tonemapA", 4.75)
		--	  Spring.SetConfigFloat("tonemapB", 0.75)
		--	  Spring.SetConfigFloat("tonemapC", 3.5)
		--	  Spring.SetConfigFloat("tonemapD", 0.85)
		--	  Spring.SetConfigFloat("tonemapE", 1.0)
		--	  Spring.SetConfigFloat("envAmbient", 0.25)
		--	  Spring.SetConfigFloat("unitSunMult", 1.0)
		--	  Spring.SetConfigFloat("unitExposureMult", 1.0)
		--	  Spring.SetConfigFloat("modelGamma", 1.0)
		--	  options[getOptionByID('tonemapA')].value = Spring.GetConfigFloat("tonemapA")
		--	  options[getOptionByID('tonemapB')].value = Spring.GetConfigFloat("tonemapB")
		--	  options[getOptionByID('tonemapC')].value = Spring.GetConfigFloat("tonemapC")
		--	  options[getOptionByID('tonemapD')].value = Spring.GetConfigFloat("tonemapD")
		--	  options[getOptionByID('tonemapE')].value = Spring.GetConfigFloat("tonemapE")
		--	  options[getOptionByID('envAmbient')].value = Spring.GetConfigFloat("envAmbient")
		--	  options[getOptionByID('unitSunMult')].value = Spring.GetConfigFloat("unitSunMult")
		--	  options[getOptionByID('unitExposureMult')].value = Spring.GetConfigFloat("unitExposureMult")
		--	  options[getOptionByID('modelGamma')].value = Spring.GetConfigFloat("modelGamma")
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--	  options[getOptionByID('tonemapDefaults')].value = false
		--  end,
		--},

		{ id = "label_dev_map", group = "dev", name = Spring.I18N('ui.settings.option.label_map'), category = types.dev },
		{ id = "label_dev_map_spacer", group = "dev", category = types.dev },

		{ id = "sun_y", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.sun') .. widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.sun_y'), type = "slider", min = 0.05, max = 0.9999, step = 0.0001, value = select(2, gl.GetSun("pos")),
		  onchange = function(i, value)
			  local sunX, sunY, sunZ = gl.GetSun("pos")
			  sunY = value
			  if sunY < options[getOptionByID('sun_y')].min then
				  sunY = options[getOptionByID('sun_y')].min
			  end
			  if sunY > options[getOptionByID('sun_y')].max then
				  sunY = options[getOptionByID('sun_y')].max
			  end
			  options[getOptionByID('sun_y')].value = sunY
			  Spring.SetSunDirection(sunX, sunY, sunZ)
			  -- just so that map/model lighting gets updated
			  Spring.SetSunLighting({ groundShadowDensity = gl.GetSun("shadowDensity"), modelShadowDensity = gl.GetSun("shadowDensity") })
			  Spring.Echo(gl.GetSun())
		  end,
		},
		{ id = "sun_x", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.sun_x'), type = "slider", min = -0.9999, max = 0.9999, step = 0.0001, value = select(1, gl.GetSun("pos")),
		  onchange = function(i, value)
			  local sunX, sunY, sunZ = gl.GetSun("pos")
			  sunX = value
			  if sunX < options[getOptionByID('sun_x')].min then
				  sunX = options[getOptionByID('sun_x')].min
			  end
			  if sunX > options[getOptionByID('sun_x')].max then
				  sunX = options[getOptionByID('sun_x')].max
			  end
			  options[getOptionByID('sun_x')].value = sunX
			  Spring.SetSunDirection(sunX, sunY, sunZ)
			  -- just so that map/model lighting gets updated
			  Spring.SetSunLighting({ groundShadowDensity = gl.GetSun("shadowDensity"), modelShadowDensity = gl.GetSun("shadowDensity") })
			  Spring.Echo(gl.GetSun())
		  end,
		},
		{ id = "sun_z", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.sun_z'), type = "slider", min = -0.9999, max = 0.9999, step = 0.0001, value = select(3, gl.GetSun("pos")),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  local sunX, sunY, sunZ = gl.GetSun("pos")
			  sunZ = value
			  if sunZ < options[getOptionByID('sun_z')].min then
				  sunZ = options[getOptionByID('sun_z')].min
			  end
			  if sunZ > options[getOptionByID('sun_z')].max then
				  sunZ = options[getOptionByID('sun_z')].max
			  end
			  options[getOptionByID('sun_z')].value = sunZ
			  Spring.SetSunDirection(sunX, sunY, sunZ)
			  -- just so that map/model lighting gets updated
			  Spring.SetSunLighting({ groundShadowDensity = gl.GetSun("shadowDensity"), modelShadowDensity = gl.GetSun("shadowDensity") })
			  Spring.Echo(gl.GetSun())
		  end,
		},
		{ id = "sun_reset", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.sun_reset'), type = "bool", value = false,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  options[getOptionByID('sun_x')].value = defaultMapSunPos[1]
			  options[getOptionByID('sun_y')].value = defaultMapSunPos[2]
			  options[getOptionByID('sun_z')].value = defaultMapSunPos[3]
			  options[getOptionByID('sun_reset')].value = false
			  Spring.SetSunDirection(defaultMapSunPos[1], defaultMapSunPos[2], defaultMapSunPos[3])
			  -- just so that map/model lighting gets updated
			  Spring.SetSunLighting({ groundShadowDensity = gl.GetSun("shadowDensity"), modelShadowDensity = gl.GetSun("shadowDensity") })
			  Spring.Echo(gl.GetSun())
		  end,
		},

		{ id = "fog_start", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.fog') .. widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.fog_start'), type = "slider", min = 0, max = 1.99, step = 0.01, value = gl.GetAtmosphere("fogStart"),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  if getOptionByID('fog_end') and value >= options[getOptionByID('fog_end')].value then
				  applyOptionValue(getOptionByID('fog_end'), value + 0.01)
			  end
			  Spring.SetAtmosphere({ fogStart = value })
		  end,
		},
		{ id = "fog_end", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.fog_end'), type = "slider", min = 0.5, max = 2, step = 0.01, value = gl.GetAtmosphere("fogEnd"),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  if getOptionByID('fog_start') and value <= options[getOptionByID('fog_start')].value then
				  applyOptionValue(getOptionByID('fog_start'), value - 0.01)
			  end
			  Spring.SetAtmosphere({ fogEnd = value })
		  end,
		},
		{ id = "fog_reset", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.fog_reset'), type = "bool", value = false, description = '',
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  if getOptionByID('fog_start') then
				  options[getOptionByID('fog_start')].value = defaultMapFog.fogStart
				  options[getOptionByID('fog_end')].value = defaultMapFog.fogEnd
				  options[getOptionByID('fog_reset')].value = false
			  end
			  Spring.SetAtmosphere({ fogStart = defaultMapFog.fogStart, fogEnd = defaultMapFog.fogEnd })
		  end,
		},

		{ id = "fog_r", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.fog') .. widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.red'), type = "slider", min = 0, max = 1, step = 0.01, value = select(1, gl.GetAtmosphere("fogColor")), description = '',
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  local fogColor = { gl.GetAtmosphere("fogColor") }
			  Spring.SetAtmosphere({ fogColor = { value, fogColor[2], fogColor[3], fogColor[4] } })
		  end,
		},
		{ id = "fog_g", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.green'), type = "slider", min = 0, max = 1, step = 0.01, value = select(2, gl.GetAtmosphere("fogColor")), description = '',
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  local fogColor = { gl.GetAtmosphere("fogColor") }
			  Spring.SetAtmosphere({ fogColor = { fogColor[1], value, fogColor[3], fogColor[4] } })
		  end,
		},
		{ id = "fog_b", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.blue'), type = "slider", min = 0, max = 1, step = 0.01, value = select(3, gl.GetAtmosphere("fogColor")), description = '',
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  local fogColor = { gl.GetAtmosphere("fogColor") }
			  Spring.SetAtmosphere({ fogColor = { fogColor[1], fogColor[2], value, fogColor[4] } })
		  end,
		},
		{ id = "fog_color_reset", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.fog_color_reset'), type = "bool", value = false, description = '',
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  options[getOptionByID('fog_r')].value = defaultMapFog.fogColor[1]
			  options[getOptionByID('fog_g')].value = defaultMapFog.fogColor[2]
			  options[getOptionByID('fog_b')].value = defaultMapFog.fogColor[3]
			  options[getOptionByID('fog_color_reset')].value = false
			  Spring.SetAtmosphere({ fogColor = defaultMapFog.fogColor })
			  Spring.Echo('resetted map fog color defaults')
		  end,
		},

		{ id = "map_voidwater", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.map_voidwater'), type = "bool", value = false, description = "",
		  onload = function(i)
			  options[i].value = gl.GetMapRendering("voidWater")
		  end,
		  onchange = function(i, value)
			  Spring.SetMapRenderingParams({ voidWater = value })
		  end,
		},
		{ id = "map_voidground", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.map_voidground'), type = "bool", value = false, description = "",
		  onload = function(i)
			  options[i].value = gl.GetMapRendering("voidGround")
		  end,
		  onchange = function(i, value)
			  Spring.SetMapRenderingParams({ voidGround = value })
		  end,
		},

		{ id = "map_splatdetailnormaldiffusealpha", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.map_splatdetailnormaldiffusealpha'), type = "bool", value = false, description = "",
		  onload = function(i)
			  options[i].value = gl.GetMapRendering("splatDetailNormalDiffuseAlpha")
		  end,
		  onchange = function(i, value)
			  Spring.SetMapRenderingParams({ splatDetailNormalDiffuseAlpha = value })
		  end,
		},

		{ id = "map_splattexmults_r", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.map_splattexmults') .. widgetOptionColor .. "   0", type = "slider", min = 0, max = 1.5, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b, a = gl.GetMapRendering("splatTexMults")
			  options[i].value = r
		  end,
		  onchange = function(i, value)
			  local r, g, b, a = gl.GetMapRendering("splatTexMults")
			  Spring.SetMapRenderingParams({ splatTexMults = { value, g, b, a } })
		  end,
		},
		{ id = "map_splattexmults_g", group = "dev", category = types.dev, name = widgetOptionColor .. "   1", type = "slider", min = 0, max = 1.5, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b, a = gl.GetMapRendering("splatTexMults")
			  options[i].value = g
		  end,
		  onchange = function(i, value)
			  local r, g, b, a = gl.GetMapRendering("splatTexMults")
			  Spring.SetMapRenderingParams({ splatTexMults = { r, value, b, a } })
		  end,
		},
		{ id = "map_splattexmults_b", group = "dev", category = types.dev, name = widgetOptionColor .. "   2", type = "slider", min = 0, max = 1.5, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b, a = gl.GetMapRendering("splatTexMults")
			  options[i].value = b
		  end,
		  onchange = function(i, value)
			  local r, g, b, a = gl.GetMapRendering("splatTexMults")
			  Spring.SetMapRenderingParams({ splatTexMults = { r, g, value, a } })
		  end,
		},
		{ id = "map_splattexmults_a", group = "dev", category = types.dev, name = widgetOptionColor .. "   3", type = "slider", min = 0, max = 1.5, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b, a = gl.GetMapRendering("splatTexMults")
			  options[i].value = a
		  end,
		  onchange = function(i, value)
			  local r, g, b, a = gl.GetMapRendering("splatTexMults")
			  Spring.SetMapRenderingParams({ splatTexMults = { r, g, b, value } })
		  end,
		},

		{ id = "map_splattexacales_r", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.map_splattexacales') .. widgetOptionColor .. "   0", type = "slider", min = 0, max = 0.02, step = 0.0001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b, a = gl.GetMapRendering("splatTexScales")
			  options[i].value = r
		  end,
		  onchange = function(i, value)
			  local r, g, b, a = gl.GetMapRendering("splatTexScales")
			  Spring.SetMapRenderingParams({ splatTexScales = { value, g, b, a } })
		  end,
		},
		{ id = "map_splattexacales_g", group = "dev", category = types.dev, name = widgetOptionColor .. "   1", type = "slider", min = 0, max = 0.02, step = 0.0001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b, a = gl.GetMapRendering("splatTexScales")
			  options[i].value = g
		  end,
		  onchange = function(i, value)
			  local r, g, b, a = gl.GetMapRendering("splatTexScales")
			  Spring.SetMapRenderingParams({ splatTexScales = { r, value, b, a } })
		  end,
		},
		{ id = "map_splattexacales_b", group = "dev", category = types.dev, name = widgetOptionColor .. "   2", type = "slider", min = 0, max = 0.02, step = 0.0001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b, a = gl.GetMapRendering("splatTexScales")
			  options[i].value = b
		  end,
		  onchange = function(i, value)
			  local r, g, b, a = gl.GetMapRendering("splatTexScales")
			  Spring.SetMapRenderingParams({ splatTexScales = { r, g, value, a } })
		  end,
		},
		{ id = "map_splattexacales_a", group = "dev", category = types.dev, name = widgetOptionColor .. "   3", type = "slider", min = 0, max = 0.02, step = 0.0001, value = 0, description = "",
			 onload = function(i)
				 local r, g, b, a = gl.GetMapRendering("splatTexScales")
				 options[i].value = a
			 end,
			 onchange = function(i, value)
				 local r, g, b, a = gl.GetMapRendering("splatTexScales")
				 Spring.SetMapRenderingParams({ splatTexScales = { r, g, b, value } })
			 end,
		},

		{ id = "GroundShadowDensity", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.GroundShadowDensity') .. widgetOptionColor .. "  ", type = "slider", min = 0, max = 1.5, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local groundshadowDensity = gl.GetSun("shadowDensity", "ground")
			  options[i].value = groundshadowDensity
		  end,
		  onchange = function(i, value)
			  Spring.SetSunLighting({ groundShadowDensity = value })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},

		{ id = "UnitShadowDensity", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.UnitShadowDensity') .. widgetOptionColor .. "  ", type = "slider", min = 0, max = 1.5, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local groundshadowDensity = gl.GetSun("shadowDensity", "unit")
			  options[i].value = groundshadowDensity
		  end,
		  onchange = function(i, value)
			  Spring.SetSunLighting({ modelShadowDensity = value })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},

		{ id = "color_groundambient_r", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.color_groundambient') .. widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.red'), type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetSun("ambient")
			  options[i].value = r
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetSun("ambient")
			  Spring.SetSunLighting({ groundAmbientColor = { value, g, b } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},
		{ id = "color_groundambient_g", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.green'), type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetSun("ambient")
			  options[i].value = g
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetSun("ambient")
			  Spring.SetSunLighting({ groundAmbientColor = { r, value, b } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},
		{ id = "color_groundambient_b", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.blue'), type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetSun("ambient")
			  options[i].value = b
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetSun("ambient")
			  Spring.SetSunLighting({ groundAmbientColor = { r, g, value } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},

		{ id = "color_grounddiffuse_r", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.color_grounddiffuse') .. widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.red'), type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetSun("diffuse")
			  options[i].value = r
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetSun("diffuse")
			  Spring.SetSunLighting({ groundDiffuseColor = { value, g, b } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},
		{ id = "color_grounddiffuse_g", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.green'), type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetSun("diffuse")
			  options[i].value = g
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetSun("diffuse")
			  Spring.SetSunLighting({ groundDiffuseColor = { r, value, b } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},
		{ id = "color_grounddiffuse_b", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.blue'), type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetSun("diffuse")
			  options[i].value = b
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetSun("diffuse")
			  Spring.SetSunLighting({ groundDiffuseColor = { r, g, value } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},

		{ id = "color_groundspecular_r", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.color_groundspecular') .. widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.red'), type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetSun("specular")
			  options[i].value = r
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetSun("specular")
			  Spring.SetSunLighting({ groundSpecularColor = { value, g, b } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},
		{ id = "color_groundspecular_g", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.green'), type = "slider", min = 0, max = 1, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetSun("specular")
			  options[i].value = g
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetSun("specular")
			  Spring.SetSunLighting({ groundSpecularColor = { r, value, b } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},
		{ id = "color_groundspecular_b", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.blue'), type = "slider", min = 0, max = 1, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetSun("specular")
			  options[i].value = b
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetSun("specular")
			  Spring.SetSunLighting({ groundSpecularColor = { r, g, value } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},


		{ id = "color_unitambient_r", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.color_unitambient') .. widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.red'), type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetSun("ambient", "unit")
			  options[i].value = r
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetSun("ambient", "unit")
			  Spring.SetSunLighting({ unitAmbientColor = { value, g, b } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},
		{ id = "color_unitambient_g", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.green'), type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetSun("ambient", "unit")
			  options[i].value = g
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetSun("ambient", "unit")
			  Spring.SetSunLighting({ unitAmbientColor = { r, value, b } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},
		{ id = "color_unitambient_b", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.blue'), type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetSun("ambient", "unit")
			  options[i].value = b
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetSun("ambient", "unit")
			  Spring.SetSunLighting({ unitAmbientColor = { r, g, value } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},

		{ id = "color_unitdiffuse_r", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.color_unitdiffuse') .. widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.red'), type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetSun("diffuse", "unit")
			  options[i].value = r
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetSun("diffuse", "unit")
			  Spring.SetSunLighting({ unitDiffuseColor = { value, g, b } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},
		{ id = "color_unitdiffuse_g", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.green'), type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetSun("diffuse", "unit")
			  options[i].value = g
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetSun("diffuse", "unit")
			  Spring.SetSunLighting({ unitDiffuseColor = { r, value, b } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},
		{ id = "color_unitdiffuse_b", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.blue'), type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetSun("diffuse", "unit")
			  options[i].value = b
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetSun("diffuse", "unit")
			  Spring.SetSunLighting({ unitDiffuseColor = { r, g, value } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},

		{ id = "color_unitspecular_r", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.color_unitspecular') .. widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.red'), type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetSun("specular", "unit")
			  options[i].value = r
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetSun("specular", "unit")
			  Spring.SetSunLighting({ unitSpecularColor = { value, g, b } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},
		{ id = "color_unitspecular_g", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.green'), type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetSun("specular", "unit")
			  options[i].value = g
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetSun("specular", "unit")
			  Spring.SetSunLighting({ unitSpecularColor = { r, value, b } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},
		{ id = "color_unitspecular_b", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.blue'), type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetSun("specular", "unit")
			  options[i].value = b
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetSun("specular", "unit")
			  Spring.SetSunLighting({ unitSpecularColor = { r, g, value } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},

		{ id = "suncolor_r", group = "dev", category = types.dev, name = "Sun" .. widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.red'), type = "slider", min = 0, max = 1, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetAtmosphere("sunColor")
			  options[i].value = r
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetAtmosphere("sunColor")
			  Spring.SetAtmosphere({ sunColor = { value, g, b } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},
		{ id = "suncolor_g", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.green'), type = "slider", min = 0, max = 1, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetAtmosphere("sunColor")
			  options[i].value = g
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetAtmosphere("sunColor")
			  Spring.SetAtmosphere({ sunColor = { r, value, b } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},
		{ id = "suncolor_b", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.blue'), type = "slider", min = 0, max = 1, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetAtmosphere("sunColor")
			  options[i].value = b
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetAtmosphere("sunColor")
			  Spring.SetAtmosphere({ sunColor = { r, g, value } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},

		{ id = "skycolor_r", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.skycolor') .. widgetOptionColor .. "  " .. Spring.I18N('ui.settings.option.red'), type = "slider", min = 0, max = 1, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetAtmosphere("skyColor")
			  options[i].value = r
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetAtmosphere("skyColor")
			  Spring.SetAtmosphere({ skyColor = { value, g, b } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},
		{ id = "skycolor_g", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.green'), type = "slider", min = 0, max = 1, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetAtmosphere("skyColor")
			  options[i].value = g
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetAtmosphere("skyColor")
			  Spring.SetAtmosphere({ skyColor = { r, value, b } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},
		{ id = "skycolor_b", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.blue'), type = "slider", min = 0, max = 1, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local r, g, b = gl.GetAtmosphere("skyColor")
			  options[i].value = b
		  end,
		  onchange = function(i, value)
			  local r, g, b = gl.GetAtmosphere("skyColor")
			  Spring.SetAtmosphere({ skyColor = { r, g, value } })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},

		{ id = "sunlighting_reset", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.sunlighting_reset'), type = "bool", value = false, description = Spring.I18N('ui.settings.option.sunlighting_reset_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  options[getOptionByID('sunlighting_reset')].value = false
			  -- just so that map/model lighting gets updated
			  Spring.SetSunLighting(defaultSunLighting)
			  Spring.Echo('resetted ground/unit coloring')
			  init()
		  end,
		},

		{ id = "skyaxisangle_angle", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.skybox') .. widgetOptionColor .. "  "..Spring.I18N('ui.settings.option.angle'), type = "slider", min = -3.14, max = 3.14, step = 0.01, value = 0, description = "",
		  onload = function(i)
			  local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
			  options[i].value = angle
		  end,
		  onchange = function(i, value)
			  local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
			  angle = value
			  Spring.SetAtmosphere({ skyAxisAngle = { x, y, z, angle } })
		  end,
		},
		{ id = "skyaxisangle_x", group = "dev", category = types.dev, name = widgetOptionColor .. "   x", type = "slider", min = -1, max = 1, step = 0.01, value = 0, description = "",
		  onload = function(i)
			  local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
			  options[i].value = x
		  end,
		  onchange = function(i, value)
			  local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
			  x = value
			  Spring.SetAtmosphere({ skyAxisAngle = { x, y, z, angle } })
		  end,
		},
		{ id = "skyaxisangle_y", group = "dev", category = types.dev, name = widgetOptionColor .. "   y", type = "slider", min = -1, max = 1, step = 0.01, value = 0, description = "",
		  onload = function(i)
			  local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
			  options[i].value = y
		  end,
		  onchange = function(i, value)
			  local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
			  y = value
			  Spring.SetAtmosphere({ skyAxisAngle = { x, y, z, angle } })
		  end,
		},
		{ id = "skyaxisangle_z", group = "dev", category = types.dev, name = widgetOptionColor .. "   z", type = "slider", min = -1, max = 1, step = 0.01, value = 0, description = "",
		  onload = function(i)
			  local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
			  options[i].value = z
		  end,
		  onchange = function(i, value)
			  local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
			  z = value
			  Spring.SetAtmosphere({ skyAxisAngle = { x, y, z, angle } })
		  end,
		},

		{ id = "skyaxisangle_reset", group = "dev", category = types.dev, name = widgetOptionColor .. "   "..Spring.I18N('ui.settings.option.reset'), type = "bool", value = false, description = Spring.I18N('ui.settings.option.sunlighting_reset_descr'),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  options[getOptionByID('skyaxisangle_reset')].value = false
			  Spring.SetAtmosphere({ skyAxisAngle = defaultSkyAxisAngle })
			  Spring.Echo('resetted skyAxisAngle atmosphere')
			  init()
		  end,
		},
		{ id = "label_dev_water", group = "dev", name = Spring.I18N('ui.settings.option.label_water'), category = types.dev },
		{ id = "label_dev_water_spacer", group = "dev", category = types.dev },

		-- springsettings water params
		{ id = "waterconfig_shorewaves", group = "dev", category = types.dev, name = "Bumpwater settings " .. widgetOptionColor .. "  shorewaves", type = "bool", value = Spring.GetConfigInt("BumpWaterShoreWaves", 1) == 1, description = "",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ shoreWaves = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "waterconfig_dynamicwaves", group = "dev", category = types.dev, name = widgetOptionColor .. "   dynamic waves", type = "bool", value = Spring.GetConfigInt("BumpWaterDynamicWaves", 1) == 1, description = "Springsettings.cfg config, Probably requires a restart",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("BumpWaterDynamicWaves", (value and 1 or 0))
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "waterconfig_endless", group = "dev", category = types.dev, name = widgetOptionColor .. "   endless", type = "bool", value = Spring.GetConfigInt("BumpWaterEndlessOcean", 1) == 1, description = "Springsettings.cfg config, Probably requires a restart",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("BumpWaterEndlessOcean", (value and 1 or 0))
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "waterconfig_occlusionquery", group = "dev", category = types.dev, name = widgetOptionColor .. "   occlusion query", type = "bool", value = Spring.GetConfigInt("BumpWaterOcclusionQuery", 1) == 1, description = "Springsettings.cfg config, Probably requires a restart",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("BumpWaterOcclusionQuery", (value and 1 or 0))
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "waterconfig_blurreflection", group = "dev", category = types.dev, name = widgetOptionColor .. "   blur reflection", type = "bool", value = Spring.GetConfigInt("BumpWaterBlurReflection", 1) == 1, description = "Springsettings.cfg config, Probably requires a restart",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("BumpWaterBlurReflection", (value and 1 or 0))
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "waterconfig_anisotropy", group = "dev", category = types.dev, name = widgetOptionColor .. "   anisotropy", type = "bool", value = Spring.GetConfigInt("BumpWaterAnisotropy", 1) == 1, description = "Springsettings.cfg config, Probably requires a restart",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("BumpWaterAnisotropy", (value and 1 or 0))
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "wateconfigr_usedepthtexture", group = "dev", category = types.dev, name = widgetOptionColor .. "   use depth texture", type = "bool", value = Spring.GetConfigInt("BumpWaterUseDepthTexture", 1) == 1, description = "Springsettings.cfg config, Probably requires a restart",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("BumpWaterUseDepthTexture", (value and 1 or 0))
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "waterconfig_useuniforms", group = "dev", category = types.dev, name = widgetOptionColor .. "   use uniforms", type = "bool", value = Spring.GetConfigInt("BumpWaterUseUniforms", 1) == 1, description = "Springsettings.cfg config, Probably requires a restart",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("BumpWaterUseUniforms", (value and 1 or 0))
			  Spring.SendCommands("water 4")
		  end,
		},

		-- GL water params
		{ id = "water_shorewaves", group = "dev", category = types.dev, name = "Bumpwater GL params" .. widgetOptionColor .. "  shorewaves", type = "bool", value = gl.GetWaterRendering("shoreWaves"), description = "Springsettings.cfg config, Probably requires a restart",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ shoreWaves = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_haswaterplane", group = "dev", category = types.dev, name = widgetOptionColor .. "   has waterplane", type = "bool", value = gl.GetWaterRendering("hasWaterPlane"), description = "The WaterPlane is a single Quad beneath the map.\nIt should have the same color as the ocean floor to hide the map -> background boundary. Specifying waterPlaneColor in mapinfo.lua will turn this on.",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ hasWaterPlane = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_forcerendering", group = "dev", category = types.dev, name = widgetOptionColor .. "   force rendering", type = "bool", value = gl.GetWaterRendering("forceRendering"), description = "Should the water be rendered even when minMapHeight>0.\nUse it to avoid the jumpin of the outside-map water rendering (BumpWater: endlessOcean option) when combat explosions reach groundwater.",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ forceRendering = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_repeatx", group = "dev", category = types.dev, name = widgetOptionColor .. "   repeat X", type = "slider", min = 0, max = 20, step = 1, value = gl.GetWaterRendering("repeatX"), description = "water 0 texture repeat horizontal",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ repeatX = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_repeaty", group = "dev", category = types.dev, name = widgetOptionColor .. "   repeat Y", type = "slider", min = 0, max = 20, step = 1, value = gl.GetWaterRendering("repeatY"), description = "water 0 texture repeat vertical",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ repeatY = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_surfacealpha", group = "dev", category = types.dev, name = widgetOptionColor .. "   surface alpha", type = "slider", min = 0, max = 1, step = 0.001, value = gl.GetWaterRendering("surfaceAlpha"), description = "",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ surfaceAlpha = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		-- gl.GetWaterRendering("windSpeed") seems to not exist
		--{ id = "water_windspeed", group = "dev", category = types.dev, name = widgetOptionColor .. "   windspeed", type = "slider", min = 0.0, max = 2.0, step = 0.01, value = gl.GetWaterRendering("windSpeed"), description = "The speed of bumpwater tiles moving",
		--  onload = function(i)
		--  end,
		--  onchange = function(i, value)
		--	  Spring.SetWaterParams({ windSpeed = value })
		--	  Spring.SendCommands("water 4")
		--  end,
		--},
		{ id = "water_ambientfactor", group = "dev", category = types.dev, name = widgetOptionColor .. "   ambient factor", type = "slider", min = 0, max = 2, step = 0.001, value = gl.GetWaterRendering("ambientFactor"), description = "How much ambient lighting the water surface gets (ideally very little)",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ ambientFactor = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_diffusefactor", group = "dev", category = types.dev, name = widgetOptionColor .. "   diffuse factor", type = "slider", min = 0, max = 5, step = 0.001, value = gl.GetWaterRendering("diffuseFactor"), description = "How strong the diffuse lighting should be on the water",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ diffuseFactor = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_specularfactor", group = "dev", category = types.dev, name = widgetOptionColor .. "   specular factor", type = "slider", min = 0, max = 5, step = 0.01, value = gl.GetWaterRendering("specularFactor"), description = "How much light should be reflected straight from the sun",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ specularFactor = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_specularpower", group = "dev", category = types.dev, name = widgetOptionColor .. "   specular power", type = "slider", min = 0, max = 100, step = 0.1, value = gl.GetWaterRendering("specularPower"), description = "How polished the surface of the water is",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ specularPower = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_perlinstartfreq", group = "dev", category = types.dev, name = widgetOptionColor .. "   perlin start freq", type = "slider", min = 10, max = 50, step = 1, value = gl.GetWaterRendering("perlinStartFreq"), description = "The initial frequency of the bump map repetetion rate. Larger numbers mean more tiles",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ perlinStartFreq = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_perlinlacunarity", group = "dev", category = types.dev, name = widgetOptionColor .. "   perlin lacunarity", type = "slider", min = 0.1, max = 4, step = 0.01, value = gl.GetWaterRendering("perlinLacunarity"), description = "How much smaller each additional repetion of the normal map should be. Larger numbers mean smaller",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ perlinLacunarity = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_perlinlamplitude", group = "dev", category = types.dev, name = widgetOptionColor .. "   perlin amplitude", type = "slider", min = 0.1, max = 4, step = 0.01, value = gl.GetWaterRendering("perlinAmplitude"), description = "How strong each additional repetetion of the normal map should be",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ perlinAmplitude = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_fresnelmin", group = "dev", category = types.dev, name = widgetOptionColor .. "   fresnel min", type = "slider", min = 0, max = 2, step = 0.01, value = gl.GetWaterRendering("fresnelMin"), description = "Minimum reflection strength, e.g. the reflectivity of the water when looking straight down on it",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ fresnelMin = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_fresnelmax", group = "dev", category = types.dev, name = widgetOptionColor .. "   fresnel max", type = "slider", min = 0, max = 2, step = 0.01, value = gl.GetWaterRendering("fresnelMax"), description = "Maximum reflection strength, the reflectivity of the water when looking parallel to the water plane",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ fresnelMax = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_fresnelpower", group = "dev", category = types.dev, name = widgetOptionColor .. "   fresnel power", type = "slider", min = 0, max = 16, step = 0.1, value = gl.GetWaterRendering("fresnelPower"), description = "Determines how fast the reflection increases when going from straight down view to parallel.",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ fresnelPower = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_numtiles", group = "dev", category = types.dev, name = widgetOptionColor .. "   num tiles", type = "slider", min = 1.0, max = 8, step = 1.0, value = gl.GetWaterRendering("numTiles"), description = "How many (squared) Tiles does the `normalTexture` have?\nSuch Tiles are used when DynamicWaves are enabled in BumpWater, the more the better.\nCheck the example php script to generate such tiled bumpmaps.",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ numTiles = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_blurbase", group = "dev", category = types.dev, name = widgetOptionColor .. "   blur base", type = "slider", min = 0, max = 3, step = 0.01, value = gl.GetWaterRendering("blurBase"), description = "How much should the reflection be blurred",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ blurBase = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_blurexponent", group = "dev", category = types.dev, name = widgetOptionColor .. "   blur exponent", type = "slider", min = 0, max = 3, step = 0.01, value = gl.GetWaterRendering("blurExponent"), description = "How much should the reflection be blurred",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ blurExponent = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_reflectiondistortion", group = "dev", category = types.dev, name = widgetOptionColor .. "   reflection distortion", type = "slider", min = 0, max = 5, step = 0.01, value = gl.GetWaterRendering("reflectionDistortion"), description = "",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ reflectionDistortion = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		-- new water 4 params since engine 105BAR 582
		{ id = "water_waveoffsetfactor", group = "dev", category = types.dev, name = widgetOptionColor .. "   waveoffsetfactor", type = "slider", min = 0.0, max = 2.0, step = 0.01, value = gl.GetWaterRendering("waveOffsetFactor"), description = "Set this to 0.1 to make waves break shores not all at the same time",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ waveOffsetFactor = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_wavelength", group = "dev", category = types.dev, name = widgetOptionColor .. "   waveLength", type = "slider", min = 0.0, max = 1.0, step = 0.01, value = gl.GetWaterRendering("waveLength"), description = "How long the waves are",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ waveLength = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_wavefoamdistortion", group = "dev", category = types.dev, name = widgetOptionColor .. "   waveFoamDistortion", type = "slider", min = 0.0, max = 0.5, step = 0.01, value = gl.GetWaterRendering("waveFoamDistortion"), description = "How much the waters movement distorts the foam texture",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ waveFoamDistortion = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_wavefoamintensity", group = "dev", category = types.dev, name = widgetOptionColor .. "   waveFoamIntensity", type = "slider", min = 0.0, max = 2.0, step = 0.01, value = gl.GetWaterRendering("waveFoamIntensity"), description = "How strong the foam texture is",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ waveFoamIntensity = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_causticsresolution", group = "dev", category = types.dev, name = widgetOptionColor .. "   causticsResolution", type = "slider", min = 10.0, max = 300.0, step = 1.0, value = gl.GetWaterRendering("causticsResolution"), description = "The tiling rate of the caustics texture",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ causticsResolution = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		{ id = "water_causticsstrength", group = "dev", category = types.dev, name = widgetOptionColor .. "   causticsStrength", type = "slider", min = 0.0, max = 0.5, step = 0.01, value = gl.GetWaterRendering("causticsStrength"), description = "How intense the caustics effects are",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ causticsStrength = value })
			  Spring.SendCommands("water 4")
		  end,
		},
		-- TODO add SetWaterParams:
		--absorb = {number r, number g, number b},
		--baseColor = {number r, number g, number b},
		--minColor = {number r, number g, number b},
		--surfaceColor = {number r, number g, number b},
		--diffuseColor = {number r, number g, number b},
		--specularColor = {number r, number g, number b},
		--planeColor = {number r, number g, number b},
	}

	--if not isPotatoGpu and gpuMem <= 4500 then
	--	options[getOptionByID('advmapshading')].category = types.basic
	--end

	-- reset tonemap defaults (only once)
	if not resettedTonemapDefault then
		local optionID = getOptionByID('tonemapDefaults')
		if optionID then
			applyOptionValue(optionID, true)
			resettedTonemapDefault = true
		end
	end

	local localWidgetCount = 0
	for name, data in pairs(widgetHandler.knownWidgets) do
		if not data.fromZip then
			localWidgetCount = localWidgetCount + 1
		end
	end

	if devMode then
		options[getOptionByID('devmode')] = nil
		options[getOptionByID('label_ui_developer')] = nil
		options[getOptionByID('label_ui_developer_spacer')] = nil
	end

	if devMode or devUI or localWidgetCount == 0 then
		options[getOptionByID('widgetselector')] = nil
	end

	if not GetWidgetToggleValue('Grid menu') then
		options[getOptionByID('gridmenu_alwaysreturn')] = nil
		options[getOptionByID('gridmenu_autoselectfirst')] = nil
		options[getOptionByID('gridmenu_labbuildmode')] = nil
		options[getOptionByID('gridmenu_ctrlclickmodifier')] = nil
		options[getOptionByID('gridmenu_shiftclickmodifier')] = nil
		options[getOptionByID('gridmenu_ctrlkeymodifier')] = nil
		options[getOptionByID('gridmenu_shiftkeymodifier')] = nil
	end

	if spectatorHUDConfigOptions[options[getOptionByID('spectator_hud_config')].value] ~= Spring.I18N('ui.settings.option.spectator_hud_config_custom') then
		options[getOptionByID('spectator_hud_metric_metalIncome')] = nil
		options[getOptionByID('spectator_hud_metric_energyIncome')] = nil
		options[getOptionByID('spectator_hud_metric_buildPower')] = nil
		options[getOptionByID('spectator_hud_metric_metalProduced')] = nil
		options[getOptionByID('spectator_hud_metric_energyProduced')] = nil
		options[getOptionByID('spectator_hud_metric_metalExcess')] = nil
		options[getOptionByID('spectator_hud_metric_energyExcess')] = nil
		options[getOptionByID('spectator_hud_metric_armyValue')] = nil
		options[getOptionByID('spectator_hud_metric_defenseValue')] = nil
		options[getOptionByID('spectator_hud_metric_utilityValue')] = nil
		options[getOptionByID('spectator_hud_metric_economyValue')] = nil
		options[getOptionByID('spectator_hud_metric_damageDealt')] = nil
	end

	if not Spring.Utilities.Gametype.GetCurrentHolidays()["aprilfools"] then
		options[getOptionByID('soundtrackAprilFools')] = nil
		Spring.SetConfigInt("UseSoundtrackAprilFools", 1)
	else
		options[getOptionByID('soundtrackAprilFoolsPostEvent')] = nil
	end

	if not Spring.Utilities.Gametype.GetCurrentHolidays()["halloween"] then
		options[getOptionByID('soundtrackHalloween')] = nil
		Spring.SetConfigInt("UseSoundtrackHalloween", 1)
	else
		options[getOptionByID('soundtrackHalloweenPostEvent')] = nil
	end

	if not Spring.Utilities.Gametype.GetCurrentHolidays()["xmas"] then
		options[getOptionByID('soundtrackXmas')] = nil
		Spring.SetConfigInt("UseSoundtrackXmas", 1)
	else
		options[getOptionByID('soundtrackXmasPostEvent')] = nil
	end

	-- hide English unit names toggle if using English
	if Spring.I18N.getLocale() == 'en' then
		options[getOptionByID('language_english_unit_names')] = nil
	end

	-- add fonts
	if getOptionByID('font') then
		local fonts = {}
		local fontsFull = {}
		local fontsn = {}
		local files = VFS.DirList('fonts', '*')
		fontOption = {}
		for k, file in ipairs(files) do
			local name = string.sub(file, 7)
			local ext = string.sub(name, string.len(name) - 2)
			if ext == 'otf' or ext == 'ttf' or ext == 'ttc' then
				name = string.sub(name, 1, string.len(name) - 4)
				if not fontsn[name:lower()] then
					fonts[#fonts + 1] = name
					fontsFull[#fontsFull + 1] = string.sub(file, 7)
					fontsn[name:lower()] = true
					local fontScale = (0.5 + (vsx * vsy / 5700000))
					fontOption[#fonts] = gl.LoadFont("fonts/" .. fontsFull[#fontsFull], 20 * fontScale, 5 * fontScale, 1.5)
				end
			end
		end

		options[getOptionByID('font')].options = fonts
		options[getOptionByID('font')].optionsFont = fontsFull
		local fname = Spring.GetConfigString("bar_font", "Poppins-Regular.otf"):lower()
		options[getOptionByID('font')].value = getSelectKey(getOptionByID('font'), string.sub(fname, 1, string.len(fname) - 4))

		options[getOptionByID('font2')].options = fonts
		options[getOptionByID('font2')].optionsFont = fontsFull
		local fname = Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf"):lower()
		options[getOptionByID('font2')].value = getSelectKey(getOptionByID('font2'), string.sub(fname, 1, string.len(fname) - 4))
	end

	-- check if cus is disabled by auto disable cus widget (in case options widget has been reloaded)
	if getOptionByID('sun_y') then
		if select(2, gl.GetSun("pos")) < options[getOptionByID('sun_y')].min then
			Spring.SetSunDirection(select(1, gl.GetSun("pos")), options[getOptionByID('sun_y')].min, select(3, gl.GetSun("pos")))
		end
	end

	-- set minimal shadow opacity
	if getOptionByID('shadows_opacity') then
		if gl.GetSun("shadowDensity") < options[getOptionByID('shadows_opacity')].min then
			Spring.SetSunLighting({ groundShadowDensity = options[getOptionByID('shadows_opacity')].min, modelShadowDensity = options[getOptionByID('shadows_opacity')].min })
		end
	end

	-- remove anonymous color sliders
	if anonymousMode == "disabled" then
		options[getOptionByID('anonymous_r')] = nil
		options[getOptionByID('anonymous_g')] = nil
		options[getOptionByID('anonymous_b')] = nil
	end

	if Spring.GetGameFrame() == 0 then
		detectWater()

		-- set vsync
		Spring.SetConfigInt("VSync", Spring.GetConfigInt("VSyncGame", -1) * Spring.GetConfigInt("VSyncFraction", 1))
	end
	if not waterDetected then
		Spring.SendCommands("water 0")
	end

	if #displayNames <= 1 then
		options[getOptionByID('display')] = nil
		options[getOptionByID('resolution')].name = Spring.I18N('ui.settings.option.resolution')
	end

	-- only allow dualscreen-mode on single displays when super ultrawide screen or Multi Display option shows
	if (#displayNames <= 1 and vsx / vsy < 2.5) or (#displayNames > 1 and #displayNames == Spring.GetNumDisplays()) then
		options[getOptionByID('dualmode_enabled')] = nil
		options[getOptionByID('dualmode_left')] = nil
		options[getOptionByID('dualmode_minimap_aspectratio')] = nil
	end

	-- reduce options for potatoes
	if isPotatoGpu or isPotatoCpu then
		--local id = getOptionByID('shadowslider')
		--options[id].options = { 1, 2, 3 }
		--if options[id].value > 3 then
		--	options[id].value = 3
		--	options[id].onchange(id, options[id].value)
		--end

		-- disable engine decals (footprints)
		options[getOptionByID('decals')] = nil
		if Spring.GetConfigInt("GroundDecals", 3) > 0 then
			Spring.SendCommands("GroundDecals 0")
			Spring.SetConfigInt("GroundDecals", 0)
		end

		if isPotatoGpu then
			Spring.SendCommands("luarules disablecusgl4")
			options[getOptionByID('cusgl4')] = nil

			-- limit available msaa levels to 'off' and 'x2'
			if options[getOptionByID('msaa')] then
				for k, v in pairs(options[getOptionByID('msaa')].options) do
					if k >= 3 then
						options[getOptionByID('msaa')].options[k] = nil
					end
				end
			end

			id = getOptionByID('ssao')
			if id and GetWidgetToggleValue(options[id].widget) then
				widgetHandler:DisableWidget(options[id].widget)
			end
			options[id] = nil
			options[getOptionByID('ssao_strength')] = nil
			options[getOptionByID('ssao_quality')] = nil

			id = getOptionByID('bloom')
			if id and GetWidgetToggleValue(options[id].widget) then
				widgetHandler:DisableWidget(options[id].widget)
			end
			options[id] = nil
			options[getOptionByID('bloom_brightness')] = nil
			options[getOptionByID('bloom_quality')] = nil

			id = getOptionByID('guishader')
			if id and GetWidgetToggleValue(options[id].widget) then
				widgetHandler:DisableWidget(options[id].widget)
			end
			options[id] = nil

			id = getOptionByID('dof')
			if id and GetWidgetToggleValue(options[id].widget) then
				widgetHandler:DisableWidget(options[id].widget)
			end
			options[id] = nil
			options[getOptionByID('dof_autofocus')] = nil
			options[getOptionByID('dof_fstop')] = nil

			id = getOptionByID('clouds')
			if id and GetWidgetToggleValue(options[id].widget) then
				widgetHandler:DisableWidget(options[id].widget)
			end
			options[id] = nil
			options[getOptionByID('could_opacity')] = nil

			-- set lowest quality shadows for Intel GPU (they eat fps but dont show)
			--if Platform ~= nil and Platform.gpuVendor == 'Intel' and gpuMem < 2500 then
			--	Spring.SendCommands("advmapshading 0")
			--end

		end

	elseif gpuMem >= 3000 then
		if Spring.GetConfigInt("cus2", 1) ~= 1 then
			local id = getOptionByID('cusgl4')
			options[id].onchange(id, 1)
		end
		options[getOptionByID('cusgl4')] = nil

		--local id = getOptionByID('shadowslider')
		--options[id].options[1] = nil
		--if options[id].value == 1 then
		--	options[id].value = 2
		--	options[id].onchange(id, options[id].value)
		--end

		if Spring.GetConfigInt("Water", 0) ~= 4 then
			Spring.SendCommands("water 4")
			Spring.SetConfigInt("Water", 4)
		end
		options[getOptionByID('water')] = nil
	end

	-- loads values via stored game config in luaui/configs
	loadAllWidgetData()

	-- while we have set config-ints, that isnt enough to have these settings applied ingame
	if savedConfig and Spring.GetGameFrame() == 0 then
		for k, v in pairs(savedConfig) do
			if getOptionByID(k) then
				applyOptionValue(getOptionByID(k))
			end
		end
		changesRequireRestart = false
	end

	-- detect AI
	local aiDetected = false
	local t = Spring.GetTeamList()
	for _, teamID in ipairs(t) do
		if select(4, Spring.GetTeamInfo(teamID, false)) then
			aiDetected = true
		end
	end
	if not aiDetected then
		options[getOptionByID('commandsfxfilterai')] = nil
	end

	-- remove sound device selector if there is only 1 device
	if not soundDevices[2] then
		options[getOptionByID('snddevice')] = nil
	end

	-- add music tracks options
	local trackList
	if WG['music'] ~= nil then
		trackList = WG['music'].getTracksConfig()
	end
	if type(trackList) == 'table' then

		local newOptions = {}
		local count = 0
		local prevCategory = ''
		for i, option in pairs(options) do
			count = count + 1
			newOptions[count] = option
			if option.id == 'loadscreen_music' then
				count = count + 1
				newOptions[count] = { id = "label_sound_music", group = "sound", name = Spring.I18N('ui.settings.option.label_playlist'), category = types.basic }
				count = count + 1
				newOptions[count] = { id = "label_sound_music_spacer", group = "sound", category = types.basic }

				for k, v in pairs(trackList) do
					if prevCategory ~= v[1] then
						prevCategory = v[1]
						count = count + 1
						newOptions[count] = { id="music_track_"..v[2], group="sound", basic=true, name=v[1], type="text"}
					end
					count = count + 1
					newOptions[count] = { id="music_track_"..count, group="sound", basic=true, name=widgetOptionColor.."   "..v[2], type="click",--..'\n'..v[4],
						  onclick = function()
							  if WG['music'] ~= nil and WG['music'].playTrack then
								  WG['music'].playTrack(v[3])
							  end
						  end,
					}
				end
			end
		end
		options = newOptions
	end

	-- add sound notification sets
	if getOptionByID('notifications_set') then
		local voiceset = Spring.GetConfigString("voiceset", 'en/allison')
		local currentVoiceSetOption
		local sets = {}
		local languageDirs = VFS.SubDirs('sounds/voice', '*')
		local setCount = 0
		if hideOtherLanguagesVoicepacks then
			local language = Spring.GetConfigString('language', 'en')
			local files = VFS.SubDirs('sounds/voice/'..language, '*')
			for k, file in ipairs(files) do
				local dirname = string.sub(file, 17, string.len(file)-1)
				sets[#sets+1] = dirname
				setCount = setCount + 1
				if dirname == string.sub(voiceset, 4) then
					currentVoiceSetOption = #sets
				end
			end
		else
			for k, f in ipairs(languageDirs) do
				local langDir = string.sub(f, 14, string.len(f)-1)
				local files = VFS.SubDirs('sounds/voice/'..langDir, '*')
				for k, file in ipairs(files) do
					local dirname = string.sub(file, 14, string.len(file)-1)
					sets[#sets+1] = dirname
					setCount = setCount + 1
					if dirname == voiceset then
						currentVoiceSetOption = #sets
					end
				end
			end
		end
		if setCount == 0 then
			options[getOptionByID('notifications_set')] = nil
			options[getOptionByID('notifications_spoken')] = nil
			options[getOptionByID('notifications_volume')] = nil
		else
			options[getOptionByID('notifications_set')].options = sets
			if currentVoiceSetOption then
				options[getOptionByID('notifications_set')].value = currentVoiceSetOption
			end
		end
	end

	-- add sound notification widget sound toggle options
	local notificationList
	if WG['notifications'] ~= nil then
		notificationList = WG['notifications'].getNotificationList()
	elseif widgetHandler.configData["Notifications"] ~= nil and widgetHandler.configData["Notifications"].notificationList ~= nil then
		notificationList = widgetHandler.configData["Notifications"].notificationList
	end
	if type(notificationList) == 'table' then
		local newOptions = {}
		local count = 0
		for i, option in pairs(options) do
			count = count + 1
			newOptions[count] = option
			if option.id == 'label_notif_messages_spacer' then
				for k, v in pairs(notificationList) do
					if type(v) == 'table' then
						count = count + 1
						local color = widgetOptionColor
						if v[4] and v[4] == 0 then color ='\255\100\100\100' end
						newOptions[count] = { id = "notifications_notif_" .. v[1], group = "notif", category = types.basic, name = color .. "   " .. Spring.I18N(v[3]), type = "bool", value = v[2], --description = v[3] and Spring.I18N(v[3]) or "",
											  onchange = function(i, value)
												  saveOptionValue('Notifications', 'notifications', 'setNotification' .. v[1], { 'notificationList' }, value)
											  end,
											  onclick = function()
												  if WG['notifications'] ~= nil and WG['notifications'].playNotification then
													  WG['notifications'].playNotification(v[1])
												  end
											  end,
						}
					end
				end
			end
		end
		options = newOptions
	end

	-- add auto cloak toggles
	local defaultUnitdefConfig = {	-- copy pasted defaults from the widget
		[UnitDefNames["armdecom"] and UnitDefNames["armdecom"].id or -1] = false,
		[UnitDefNames["cordecom"] and UnitDefNames["cordecom"].id or -1] = false,
		[UnitDefNames["armferret"] and UnitDefNames["armferret"].id or -1] = false,
		[UnitDefNames["armamb"] and UnitDefNames["armamb"].id or -1] = false,
		[UnitDefNames["armpb"] and UnitDefNames["armpb"].id or -1] = false,
		[UnitDefNames["armsnipe"] and UnitDefNames["armsnipe"].id or -1] = false,
		[UnitDefNames["corsktl"] and UnitDefNames["corsktl"].id or -1] = false,
		[UnitDefNames["armgremlin"] and UnitDefNames["armgremlin"].id or -1] = true,
		[UnitDefNames["armamex"] and UnitDefNames["armamex"].id or -1] = true,
		[UnitDefNames["armshockwave"] and UnitDefNames["armshockwave"].id or -1] = true,
		[UnitDefNames["armckfus"] and UnitDefNames["armckfus"].id or -1] = true,
		[UnitDefNames["armspy"] and UnitDefNames["armspy"].id or -1] = true,
		[UnitDefNames["corspy"] and UnitDefNames["corspy"].id or -1] = true,
		[UnitDefNames["corphantom"] and UnitDefNames["corphantom"].id or -1] = true,
		[UnitDefNames["legaspy"] and UnitDefNames["legaspy"].id or -1] = true,
	}
	local unitdefConfig = {}
	if WG['autocloak'] ~= nil then
		unitdefConfig = WG['autocloak'].getUnitdefConfig()
	elseif widgetHandler.configData["Auto Cloak Units"] ~= nil and widgetHandler.configData["Auto Cloak Units"].unitdefConfig ~= nil then
		for unitName, value in pairs(widgetHandler.configData["Auto Cloak Units"].unitdefConfig) do
			if UnitDefNames[unitName] then
				local unitDefID = UnitDefNames[unitName].id
				unitdefConfig[unitDefID] = value
			end
		end
	end
	unitdefConfig = table.merge(defaultUnitdefConfig, unitdefConfig)
	if type(unitdefConfig) == 'table' then
		local newOptions = {}
		local count = 0
		for i, option in pairs(options) do
			count = count + 1
			newOptions[count] = option
			if option.id == 'autocloak' then
				for k, v in pairs(unitdefConfig) do
					if UnitDefs[k] then
						local faction = Spring.I18N('units.factions.' .. string.sub(UnitDefs[k].name,1,3))
						if faction then
							count = count + 1
							newOptions[count] = { id = "autocloak_" .. k, group = "game", category = types.basic, name = widgetOptionColor .. "   " .. UnitDefs[k].translatedHumanName..'  ('..faction..')', type = "bool", value = v, description = UnitDefs[k].translatedTooltip,
							  onchange = function(i, value)
								  saveOptionValue('Auto Cloak Units', 'autocloak', 'setUnitdefConfig', { 'unitdefConfig', k }, value, { k, value } )
							  end,
							}
						end
					end
				end
			end
		end
		options = newOptions
	end

	-- cursors
	if WG['cursors'] == nil then
		options[getOptionByID('cursor')] = nil
		options[getOptionByID('cursorsize')] = nil
	else
		local cursorsets = {}
		local cursor = 1
		local cursoroption
		cursorsets = WG['cursors'].getcursorsets()
		local cursorname = WG['cursors'].getcursor()
		for i, c in pairs(cursorsets) do
			if c == cursorname then
				cursor = i
				break
			end
		end
		if getOptionByID('cursor') then
			options[getOptionByID('cursor')].options = cursorsets
			options[getOptionByID('cursor')].value = cursor
		end
		if WG['cursors'].getsizemult then
			options[getOptionByID('cursorsize')].value = WG['cursors'].getsizemult()
		else
			options[getOptionByID('cursorsize')] = nil
		end
	end

	if WG['smartselect'] == nil then
		options[getOptionByID('smartselect_includebuildings')] = nil
		options[getOptionByID('smartselect_includebuilders')] = nil
	else
		options[getOptionByID('smartselect_includebuildings')].value = WG['smartselect'].getIncludeBuildings()
		options[getOptionByID('smartselect_includebuilders')].value = WG['smartselect'].getIncludeBuilders()
	end

	if WG['snow'] ~= nil and WG['snow'].getSnowMap ~= nil then
		options[getOptionByID('snowmap')].value = WG['snow'].getSnowMap()
	end

	-- not sure if needed: remove vsync option when its done by monitor (freesync/gsync) -> config value is set as 'x'
	if Spring.GetConfigInt("VSync", 1) == 'x' then
		options[getOptionByID('vsync')] = nil
		options[getOptionByID('vsync_spec')] = nil
		options[getOptionByID('vsync_level')] = nil
	else
		-- doing this in order to detect if vsync is actually on due to the only when spectator setting
		local id = getOptionByID('vsync')
		options[id].onchange(id, options[id].value)
	end

	if WG['playercolorpalette'] == nil or WG['playercolorpalette'].getSameTeamColors == nil then
		options[getOptionByID('sameteamcolors')] = nil
	end

	if WG.lockcamera == nil then
		options[getOptionByID('lockcamera_transitiontime')] = nil
		options[getOptionByID('lockcamera_hideenemies')] = nil
	end


	if Spring.GetConfigInt("CamMode", 2) ~= 2 then
		options[getOptionByID('springcamheightmode')] = nil
	end

	if Spring.GetConfigString("KeybindingFile") ~= "uikeys.txt" then
		options[getOptionByID('gridmenu')] = nil
	end

	-- add user widgets


	-- look for custom widget options
	local userwidgetOptions = {}
	local usedCustomOptions = {}
	local customOptionsCount = #customOptions
	if customOptions[1] then
		for k, option in pairs(customOptions) do
			if not getOptionByID(option.name) and option.widgetname then	-- prevent adding duplicate
				if not userwidgetOptions[option.widgetname] then
					userwidgetOptions[option.widgetname] = {}
				end
				userwidgetOptions[option.widgetname][#userwidgetOptions[option.widgetname]+1] = k
				customOptionsCount = customOptionsCount -1
			end
		end
	end
	local userwidgetsDetected = false
	for name, data in pairs(widgetHandler.knownWidgets) do
		if not data.fromZip then
			if not userwidgetsDetected then
				userwidgetsDetected = true
				options[#options+1] = { id = "label_custom_widgets", group = "custom", name = Spring.I18N('ui.settings.option.label_widgets'), category = types.basic }
				options[#options+1] = { id = "label_custom_widgets_spacer", group = "custom", category = types.basic }
			end
			local desc = data.desc or ''
			if desc ~= '' and WG['tooltip'] then
				local maxWidth = WG['tooltip'].getFontsize() * 90
				local textLines, numLines = font:WrapText(desc, maxWidth)
				desc = string.gsub(textLines, '[\n]', '\n')
			end
			if data.author and data.author ~= '' then
				desc = desc .. (desc ~= '' and '\n' or '')..widgetOptionColor..Spring.I18N('ui.settings.option.author')..': '.. data.author
			end
			options[#options+1] = { id = "widget_"..string.gsub(data.basename, ".lua", ""), group = "custom", category = types.basic, widget = name, name = name, type = "bool", value = GetWidgetToggleValue(name), description = desc }
			if userwidgetOptions[name] then
				for k, customOption in pairs(userwidgetOptions[name]) do
					options[#options+1] = table.copy(customOptions[customOption])
					if oldValues[options[#options].id] ~= nil then
						options[#options].value = oldValues[options[#options].id]
					end
					options[#options].name = widgetOptionColor..'  '..options[#options].name
					usedCustomOptions[customOption] = true
				end
			end
		end
	end

	-- add custom added options (done via WG.options.addOption)
	if customOptionsCount > 0 then
		options[#options+1] = { id = "label_custom_options", group = "custom", name = Spring.I18N('ui.settings.option.label_options'), category = types.basic }
		options[#options+1] = { id = "label_custom_options_spacer", group = "custom", category = types.basic }
		for k, option in pairs(customOptions) do
			if not getOptionByID(option.name) and not usedCustomOptions[k] then	-- prevent adding duplicate
				options[#options+1] = option
			end
		end
	end

	-- make sure the slider knobs keeps within their slider's boudaries
	local processedOptions = {}
	local processedOptionsCount = 0
	for i, option in pairs(options) do
		if option.type == 'slider' and not option.steps then
			if type(option.value) ~= 'number' then
				option.value = option.min
			end
			if option.value < option.min then
				option.value = option.min
			end
			if option.value > option.max then
				option.value = option.max
			end
		end
		if option.name then
			if option.category == types.dev then
				option.name = devMainOptionColor..string.gsub(option.name, widgetOptionColor, devOptionColor)
			elseif (devMode or devUI) and option.category == types.advanced then
				option.name = advMainOptionColor..string.gsub(option.name, widgetOptionColor, advOptionColor)
			end
		end
		processedOptionsCount = processedOptionsCount + 1
		processedOptions[processedOptionsCount] = option
	end
	options = processedOptions

	if inputText and inputText ~= '' and inputMode == '' then
		local filteredOptions = {}
		for i, option in pairs(options) do
			if option.name and option.name ~= '' and option.type and option.type ~= 'label' then
				local name = string.gsub(option.name, widgetOptionColor, "")
				name = string.gsub(name, "  ", " ")
				if string.find(string.lower(name), string.lower(inputText), nil, true) then
					filteredOptions[#filteredOptions+1] = option
				elseif option.description and option.description ~= '' and string.find(string.lower(option.description), string.lower(inputText), nil, true) then
					filteredOptions[#filteredOptions+1] = option
				elseif string.find(string.lower(option.id), string.lower(inputText), nil, true) then
					filteredOptions[#filteredOptions+1] = option
				end
			end
		end
		options = filteredOptions
		startColumn = 1
	end

	-- count num options in each group
	local groups = {}
	for id, group in pairs(optionGroups) do
		groups[group.id] = id
	end
	for i, option in pairs(options) do
		if groups[option.group] then
			optionGroups[groups[option.group]].numOptions = optionGroups[groups[option.group]].numOptions + 1
		end
	end

	if not requireRestartDefaultsInit then
		requireRestartDefaultsInit = true
		for i, option in pairs(options) do
			if option.restart and requireRestartDefaults[option.id] == nil then
				requireRestartDefaults[option.id] = option.value
			end
		end
	end

	changesRequireRestart = false
	for id, value in pairs(requireRestartDefaults) do
		if options[getOptionByID(id)] and options[getOptionByID(id)].value ~= value then
			changesRequireRestart = true
		end
	end

	if windowList then
		gl.DeleteList(windowList)
	end
	windowList = gl.CreateList(DrawWindow)

end

function widget:MapDrawCmd(playerID, cmdType, startx, starty, startz, a, b, c)
	if continuouslyClean then
		return true
	end
end

function widget:UnsyncedHeightMapUpdate(x1, z1, x2, z2)
	if not waterDetected and Spring.GetGameFrame() > 30 then
		if heightmapChangeClock == nil then
			heightmapChangeClock = os_clock()
		end
		heightmapChangeBuffer[#heightmapChangeBuffer + 1] = { x1 * 8, z1 * 8, x2 * 8, z2 * 8 }
	end
end

function widget:GameOver()
	gameOver = true
	updateGrabinput()
end


local function optionsCmd(_, _, params)
	local newShow = not show
	if newShow and WG['topbar'] then
		WG['topbar'].hideWindows()
	end
	show = newShow
	if showTextInput then
		if show then
			widgetHandler.textOwner = self		--widgetHandler:OwnText()
			Spring.SDLStartTextInput()	-- because: touch chobby's text edit field once and widget:TextInput is gone for the game, so we make sure its started!
		else
			cancelChatInput()
		end
	end
end

local function optionCmd(_, _, params)
	if not params[1] then return end

	local optionID = getOptionByID(params[1])
	if not optionID then return end

	if not params[2] then
		if options[optionID].type == 'bool' then
			applyOptionValue(optionID, not options[optionID].value)
		else
			show = true
			if showTextInput then
				widgetHandler.textOwner = self		--widgetHandler:OwnText()
				Spring.SDLStartTextInput()	-- because: touch chobby's text edit field once and widget:TextInput is gone for the game, so we make sure its started!
			end
		end
	else
		if options[optionID].type == 'select' then
			local selectKey = getSelectKey(optionID, params[2])
			if selectKey then
				applyOptionValue(optionID, selectKey)
			end
		elseif options[optionID].type == 'bool' then
			local value
			if params[2] == '0' then
				value = false
			elseif params[2] == '0.5' then
				value = 0.5
			else
				value = true
			end
			applyOptionValue(optionID, value)
		else
			applyOptionValue(optionID, tonumber(params[2]))
		end
	end
end

local function devmodeCmd(_, _, params)
	Spring.SendCommands("option devmode")
end

local function profileCmd(_, _, params)
	if widgetHandler:IsWidgetKnown("Widget Profiler") then
		widgetHandler:ToggleWidget("Widget Profiler")
	end
end

local function grapherCmd(_, _, params)
	if widgetHandler:IsWidgetKnown("Frame Grapher") then
		widgetHandler:ToggleWidget("Frame Grapher")
	end
end


function widget:Initialize()

	-- disable ambient player widget
	if widgetHandler:IsWidgetKnown("Ambient Player") then
		widgetHandler:DisableWidget("Ambient Player")
	end
	if widgetHandler:IsWidgetKnown("Fog Volumes Old GL4") then
		widgetHandler:DisableWidget("Fog Volumes Old GL4")
	end
	if widgetHandler.orderList["FlowUI"] and widgetHandler.orderList["FlowUI"] < 0.5 then
		widgetHandler:EnableWidget("FlowUI")
	end
	if widgetHandler.orderList["Language"] and widgetHandler.orderList["Language"] < 0.5 then
		widgetHandler:EnableWidget("Language")
	end

	if widgetHandler.orderList["Infolos API"] and widgetHandler.orderList["Infolos API"] < 0.5 then
		widgetHandler:EnableWidget("Infolos API")
	end

	if widgetHandler.orderList["Mex Snap"] and widgetHandler.orderList["Mex Snap"] < 0.5 then
		widgetHandler:EnableWidget("Mex Snap")
	end
	-- set nano particle rotation: rotValue, rotVelocity, rotAcceleration, rotValueRNG, rotVelocityRNG, rotAccelerationRNG (in degrees)
	Spring.SetNanoProjectileParams(-180, -50, -50, 360, 100, 100)

	-- just making sure
	if widgetHandler.orderList["Pregame UI"] < 0.5 then
		widgetHandler:EnableWidget("Pregame UI")
	end
	if widgetHandler.orderList["Pregame Queue"] < 0.5 then
		widgetHandler:EnableWidget("Pregame Queue")
	end
	if widgetHandler.orderList["Screen Mode/Resolution Switcher"] < 0.5 then
		widgetHandler:EnableWidget("Screen Mode/Resolution Switcher")
	end

	-- enable GL4 unit rendering api's
	if widgetHandler.orderList["DrawUnitShape GL4"] < 0.5 then
		widgetHandler:EnableWidget("DrawUnitShape GL4")
	end
	if widgetHandler.orderList["HighlightUnit API GL4"] < 0.5 then
		widgetHandler:EnableWidget("HighlightUnit API GL4")
	end


	if newerVersion then
		if widgetHandler.orderList["Defense Range GL4"] < 0.5 then
			widgetHandler:EnableWidget("Defense Range GL4")
		end
	end

	updateGrabinput()
	widget:ViewResize()

	prevShow = show

	--if tonumber(Spring.GetConfigInt("CameraSmoothing", 0)) == 1 then
	--	Spring.SendCommands("set CamFrameTimeCorrection 1")
	--	Spring.SendCommands("set SmoothTimeOffset 2")
	--else
	--	Spring.SendCommands("set CamFrameTimeCorrection 0")
	--	Spring.SendCommands("set SmoothTimeOffset 0")
	--end

	-- make sure new icon system is used
	if Spring.GetConfigInt("UnitIconsAsUI", 0) == 0 then
		Spring.SendCommands("iconsasui 1")
		Spring.SetConfigInt("UnitIconsAsUI", 1)
	end

	if firstlaunchsetupDone == false then
		firstlaunchsetupDone = true

		Spring.Echo('First time setup:  done')
		Spring.SetConfigFloat("snd_airAbsorption", 0.35)

		-- Set lower defaults for lower end/potato systems
		if gpuMem < 3300 then
			Spring.SetConfigInt("MSAALevel", 2)
		end
		if isPotatoGpu then
			Spring.SendCommands("water 0")
			Spring.SetConfigInt("Water", 0)

			--Spring.SetConfigInt("AdvMapShading", 0)
			--Spring.SendCommands("advmapshading 0")
			Spring.SendCommands("Shadows 0 1024")
			Spring.GetConfigInt("ShadowQuality", 0)
			Spring.SetConfigInt("ShadowMapSize", 1024)
			Spring.SetConfigInt("Shadows", 0)
			Spring.SetConfigInt("MSAALevel", 0)
			Spring.SetConfigFloat("ui_opacity", 0.7)    -- set to be more opaque cause guishader isnt availible
		else
			Spring.SendCommands("water 4")
			Spring.SetConfigInt("Water", 4)
		end

		local minMaxparticles = 12000
		if tonumber(Spring.GetConfigInt("MaxParticles", 1) or 0) < minMaxparticles then
			Spring.SetConfigInt("MaxParticles", minMaxparticles)
			Spring.Echo('First time setup:  setting MaxParticles config value to ' .. minMaxparticles)
		end

		Spring.SetConfigInt("CamMode", 3)
		Spring.SendCommands('viewspring')
	end

	Spring.SetConfigFloat("CamTimeFactor", 1)
	Spring.SetConfigString("InputTextGeo", "0.35 0.72 0.03 0.04")    -- input chat position posX, posY, ?, ?

	if Spring.GetGameFrame() == 0 then
		-- set minimum particle amount
		if tonumber(Spring.GetConfigInt("MaxParticles", 1) or 10000) <= 10000 then
			Spring.SetConfigInt("MaxParticles", 10000)
		end

		if Spring.GetConfigInt("MaxSounds", 128) < 128 then
			Spring.SetConfigInt("MaxSounds", 128)
		end

		-- limit music volume -- why?
		-- if Spring.GetConfigInt("snd_volmusic", 50) > 50 then
		-- 	Spring.SetConfigInt("snd_volmusic", 50)
		-- end

		-- enable advanced model shading
		if Spring.GetConfigInt("AdvModelShading", 0) ~= 1 then
			Spring.SetConfigInt("AdvModelShading", 1)
			Spring.SendCommands("advmodelshading 1")
		end
		-- enable normal mapping
		if Spring.GetConfigInt("NormalMapping", 0) ~= 1 then
			Spring.SetConfigInt("NormalMapping", 1)
			Spring.SendCommands("luarules normalmapping 1")
		end
		-- disable clouds
		if Spring.GetConfigInt("AdvSky", 0) ~= 0 then
			Spring.SetConfigInt("AdvSky", 0)
		end
		-- disable grass
		if Spring.GetConfigInt("GrassDetail", 0) ~= 0 then
			Spring.SetConfigInt("GrassDetail", 0)
		end
		-- limit MSAA
		if Spring.GetConfigInt("MSAALevel", 0) > 8 then
			Spring.SetConfigInt("MSAALevel", 8)
		end
	end

	-- make sure vertical angle is proper (not horizontal view)
	if Spring.GetGameFrame() == 0 and (Spring.GetConfigInt("CamMode", 2) == 2 or Spring.GetConfigInt("CamMode", 2) == 3) then
		local cameraState = Spring.GetCameraState()
		cameraState.rx = 2.6
		Spring.SetCameraState(cameraState, 0.1)
	end

	-- make sure fog-start is smaller than fog-end in case maps have configured it this way
	if gl.GetAtmosphere("fogEnd") <= gl.GetAtmosphere("fogStart") then
		Spring.SetAtmosphere({ fogEnd = gl.GetAtmosphere("fogStart") + 0.01 })
	end

	Spring.SendCommands("minimap unitsize " .. (Spring.GetConfigFloat("MinimapIconScale", 3.5)))        -- spring wont remember what you set with '/minimap iconssize #'

	WG['options'] = {}
	WG['options'].toggle = function(state)
		local newShow = state
		if newShow == nil then
			newShow = not show
		end
		if newShow and WG['topbar'] then
			WG['topbar'].hideWindows()
		end
		show = newShow
		if showTextInput then
			if show then
				widgetHandler.textOwner = self		--widgetHandler:OwnText()
				Spring.SDLStartTextInput()	-- because: touch chobby's text edit field once and widget:TextInput is gone for the game, so we make sure its started!
			else
				cancelChatInput()
			end
		end
	end
	WG['options'].getOptionsList = function()
		local optionList = {}
		for i, option in pairs(options) do
			optionList[#optionList+1] = option.id
		end
		return optionList
	end
	WG['options'].isvisible = function()
		return show
	end
	WG['options'].getOptionValue = function(option)
		if getOptionByID(option) then
			return options[getOptionByID(option)].value
		end
	end
	WG['options'].getCameraSmoothness = function()
		return cameraTransitionTime
	end
	WG['options'].disallowEsc = function()
		if showSelectOptions then
			--or draggingSlider then
			return true
		else
			return false
		end
	end
	WG['options'].addOptions = function(newOptions)
		for _, option in ipairs(newOptions) do
			option.group = "custom"
			customOptions[#customOptions+1] = option
		end

		init()
	end
	WG['options'].removeOptions = function(names)
		for _, name in ipairs(names) do
			for i, option in pairs(customOptions) do
				if option.id == name then
					customOptions[i] = nil
					break
				end
			end
		end

		init()
	end
	WG['options'].addOption = function(option)
		return WG['options'].addOptions({ option })
	end
	WG['options'].removeOption = function(name)
		return WG['options'].removeOptions({ name })
	end
	WG['options'].applyOptionValue = function(option, value)
		local optionID = getOptionByID(option)
		if not optionID then
			Spring.Echo("Options widget: applyOptionValue: option '" .. option .. "' not found")
			return
		end
			applyOptionValue(optionID, tonumber(value))
	end

	widgetHandler.actionHandler:AddAction(self, "options", optionsCmd, nil, 't')
	widgetHandler.actionHandler:AddAction(self, "option", optionCmd, nil, 't')
	widgetHandler.actionHandler:AddAction(self, "devmode", devmodeCmd, nil, 't')
	widgetHandler.actionHandler:AddAction(self, "profile", profileCmd, nil, 't')
	widgetHandler.actionHandler:AddAction(self, "grapher", grapherCmd, nil, 't')
end

function widget:Shutdown()
	cancelChatInput()
	if windowList then
		glDeleteList(windowList)
		glDeleteList(backgroundGuishader)
	end
	if fontOption then
		for i, font in pairs(fontOption) do
			gl.DeleteFont(fontOption[i])
		end
	end
	if WG['guishader'] then
		WG['guishader'].RemoveDlist('options')
		WG['guishader'].RemoveRect('optionsinput')
		WG['guishader'].RemoveScreenRect('options_select')
		WG['guishader'].RemoveScreenRect('options_select_options')
		if selectOptionsList then
			WG['guishader'].removeRenderDlist(selectOptionsList)
		end
	end
	if selectOptionsList then
		glDeleteList(selectOptionsList)
	end
	glDeleteList(consoleCmdDlist)
	glDeleteList(textInputDlist)
	WG['options'] = nil

	resetUserVolume()
	Spring.SendCommands("grabinput 0")

	widgetHandler.actionHandler:RemoveAction(self, "options")
	widgetHandler.actionHandler:RemoveAction(self, "option")
	widgetHandler.actionHandler:RemoveAction(self, "devmode")
	widgetHandler.actionHandler:RemoveAction(self, "profile")
	widgetHandler.actionHandler:RemoveAction(self, "grapher")
end

function getSelectKey(i, value)
	for k, v in pairs(options[i].options) do
		if v == value then
			return k
		end
	end
	return false
end

function widget:GetConfigData()
	return {
		-- these could be re-implemented as custom springsetting configint/float
		cameraTransitionTime = cameraTransitionTime,
		cameraPanTransitionTime = cameraPanTransitionTime,
		useNetworkSmoothing = useNetworkSmoothing,
		desiredWaterValue = desiredWaterValue,			-- configint water cant be used since we will set water 0 when no water is present
		pauseGameWhenSingleplayerExecuted = pauseGameWhenSingleplayerExecuted,
		pauseGameWhenSingleplayer = pauseGameWhenSingleplayer,

		-- options widget settings
		firsttimesetupDone = firstlaunchsetupDone,
		advSettings = advSettings,
		currentGroupTab = currentGroupTab,
		show = show,
		waterDetected = waterDetected,
		customPresets = customPresets,
		changesRequireRestart = changesRequireRestart,
		requireRestartDefaults = requireRestartDefaults,

		-- to restore init defaults
		mapChecksum = Game.mapChecksum,
		defaultMapFog = defaultMapFog,
		defaultMapSunPos = defaultMapSunPos,
		defaultSkyAxisAngle = defaultSkyAxisAngle,
		defaultSunLighting = defaultSunLighting,
		resettedTonemapDefault = resettedTonemapDefault,
		version = version,
		edgeMoveWidth = edgeMoveWidth,
	}
end

function widget:SetConfigData(data)
	if data.version ~= nil then
		if data.version < version then
			newerVersion = true
		end
	else
		newerVersion = true
	end
	if data.desiredWaterValue ~= nil then
		desiredWaterValue = data.desiredWaterValue
	end
	if data.firsttimesetupDone ~= nil then
		firstlaunchsetupDone = data.firsttimesetupDone
	end
	if data.resettedTonemapDefault ~= nil then
		resettedTonemapDefault = data.resettedTonemapDefault
	end
	if data.cameraTransitionTime ~= nil then
		cameraTransitionTime = data.cameraTransitionTime
	end
	if data.cameraPanTransitionTime ~= nil then
		cameraPanTransitionTime = data.cameraPanTransitionTime
	end
	if data.edgeMoveWidth then
		edgeMoveWidth = data.edgeMoveWidth
	end
	if Spring.GetGameFrame() > 0 then
		if data.requireRestartDefaults then
			requireRestartDefaults = data.requireRestartDefaults
		end
		if data.changesRequireRestart then
			changesRequireRestart = data.changesRequireRestart
		end
		if data.currentGroupTab ~= nil then
			currentGroupTab = data.currentGroupTab
		end
		if data.show ~= nil then
			show = data.show
			if show and showTextInput then
				widgetHandler.textOwner = self		--widgetHandler:OwnText()
				Spring.SDLStartTextInput()	-- because: touch chobby's text edit field once and widget:TextInput is gone for the game, so we make sure its started!
			end
		end
	end
	if data.pauseGameWhenSingleplayerExecuted ~= nil and Spring.GetGameFrame() > 0 then
		pauseGameWhenSingleplayerExecuted = data.pauseGameWhenSingleplayerExecuted
	end
	if data.pauseGameWhenSingleplayer ~= nil then
		pauseGameWhenSingleplayer = data.pauseGameWhenSingleplayer
	end
	if data.advSettings ~= nil then
		advSettings = data.advSettings
	end
	if data.savedConfig ~= nil then
		savedConfig = data.savedConfig
		for k, v in pairs(savedConfig) do
			Spring.SetConfigFloat(v[1], v[2])
		end
	end
	if data.mapChecksum and data.mapChecksum == Game.mapChecksum then
		if data.defaultMapSunPos ~= nil then
			defaultMapSunPos = data.defaultMapSunPos
		end
		if data.defaultSunLighting ~= nil then
			defaultSunLighting = data.defaultSunLighting
		end
		if data.defaultMapFog ~= nil then
			defaultMapFog = data.defaultMapFog
		end
		if data.defaultSkyAxisAngle ~= nil then
			defaultSkyAxisAngle = data.defaultSkyAxisAngle
		end
	end
	if data.useNetworkSmoothing then
		useNetworkSmoothing = data.useNetworkSmoothing
	end
	if data.customOptions then
		--customOptions = data.customOptions
	end
end

function widget:LanguageChanged()
	init()
end
