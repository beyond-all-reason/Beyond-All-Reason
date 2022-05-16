function widget:GetInfo()
	return {
		name = "Options",
		desc = "",
		author = "Floris",
		date = "September 2016",
		layer = -99990,
		enabled = true,
		handler = true,
	}
end

-- Add new options at: function init

local types = {
	basic    = 1,
	advanced = 2,
	dev      = 3,
}

local version = 1.2	-- used to toggle previously default enabled/disabled widgets to the newer default in widget:initialize()
local newerVersion = false	-- configdata will set this true if it's a newer version

local texts = {}    -- loaded from external language file

local languageCodes = { 'en', 'fr', 'zh' }
languageCodes = table.merge(languageCodes, table.invert(languageCodes))

local keyLayouts = VFS.Include("luaui/configs/keyboard_layouts.lua").layouts

local languageNames = {}
for key, code in ipairs(languageCodes) do
	languageNames[key] = Spring.I18N.languages[code]
end

local ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.6)

local devMode = Spring.Utilities.IsDevMode() or Spring.Utilities.ShowDevUI()
local advSettings = false
local initialized = false
local pauseGameWhenSingleplayer = true

local cameraTransitionTime = 0.12
local cameraPanTransitionTime = 0.03

local widgetOptionColor = '\255\160\160\160'
local musicOptionColor = '\255\130\160\130'

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

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")

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

local wsx, wsy, wpx, wpy = Spring.GetWindowGeometry()
local ssx, ssy, spx, spy = Spring.GetScreenGeometry()

local changesRequireRestart = false
local useNetworkSmoothing = false

local show = false
local prevShow = show
local manualChange = true

local guishaderIntensity = 0.0035

local spIsGUIHidden = Spring.IsGUIHidden
local spGetGroundHeight = Spring.GetGroundHeight

local os_clock = os.clock
local math_isInRect = math.isInRect

local chobbyInterface, font, font2, font3, backgroundGuishader, currentGroupTab, windowList, optionButtonBackward, optionButtonForward
local groupRect, titleRect, countDownOptionID, countDownOptionClock, sceduleOptionApply, checkedForWaterAfterGamestart, checkedWidgetDataChanges
local savedConfig, forceUpdate, sliderValueChanged, selectOptionsList, showSelectOptions, prevSelectHover
local fontOption, draggingSlider, lastSliderSound, selectClickAllowHide, draggingSliderPreDragValue

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

local RectRound, elementCorner, UiElement, UiButton, UiSlider, UiSliderKnob, UiToggle, UiSelector, UiSelectHighlight, bgpadding

local scavengersAIEnabled = Spring.Utilities.Gametype.IsScavengers()
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
local defaultMapFog = {
	fogStart = gl.GetAtmosphere("fogStart"),
	fogEnd = gl.GetAtmosphere("fogEnd"),
	fogColor = { gl.GetAtmosphere("fogColor") },
}
local options = {}
local optionGroups = {}
local optionButtons = {}
local optionHover = {}
local optionSelect = {}
local windowRect = { 0, 0, 0, 0 }
local showOnceMore = false        -- used because of GUI shader delay
local resettedTonemapDefault = false
local heightmapChangeClock

local presetCodes = {}
local presetNames = {}
local presets = {}

local startScript = VFS.LoadFile("_script.txt")
if not startScript then
	local modoptions = ''
	for key, value in pairs(Spring.GetModOptions()) do
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
		or (devMode and option.group == "dev")
		or Spring.Utilities.ShowDevUI() then

		return true
	end
	return false
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

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiButton = WG.FlowUI.Draw.Button
	UiSlider = WG.FlowUI.Draw.Slider
	UiSliderKnob = WG.FlowUI.Draw.SliderKnob
	UiToggle = WG.FlowUI.Draw.Toggle
	UiSelector = WG.FlowUI.Draw.Selector
	UiSelectHighlight = WG.FlowUI.Draw.SelectHighlight

	font = WG['fonts'].getFont(fontfile)
	font2 = WG['fonts'].getFont(fontfile2)
	font3 = WG['fonts'].getFont(fontfile2, 1.4, 0.2, 1.3)
	local newFontfileScale = (0.5 + (vsx * vsy / 5700000))
	if fontfileScale ~= newFontfileScale then
		fontfileScale = newFontfileScale
		setEngineFont()
	end

	if windowList then
		gl.DeleteList(windowList)
	end
	windowList = gl.CreateList(DrawWindow)

	if backgroundGuishader ~= nil then
		backgroundGuishader = glDeleteList(backgroundGuishader)
	end
end

local function detectWater()
	local _, _, mapMinHeight, mapMaxHeight = Spring.GetGroundExtremes()
	if mapMinHeight <= -2 then
		waterDetected = true
		Spring.SendCommands("water " .. desiredWaterValue)
	end
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
		local grOptions = groupOptions[group.id]
		if #grOptions > 0 then
			local name = group.name
			if group.id == 'gfx' then
				name = group.name .. '                                          \255\130\130\130' .. vsx .. ' x ' .. vsy
			end
			newOptionsCount = newOptionsCount + 1
			newOptions[newOptionsCount] = { id = "group_" .. group.id, name = name, type = "label" }
		end
		for i, option in pairs(grOptions) do
			newOptionsCount = newOptionsCount + 1
			newOptions[newOptionsCount] = option
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
	UiElement(screenX, screenY - screenHeight, screenX + screenWidth, screenY, 0, 0, 1, 1, 1, 1, 1, 1, ui_opacity + 0.2)

	-- title
	local groupMargin = math.floor(bgpadding * 0.8)
	local color = '\255\255\255\255'
	local color2 = '\255\125\125\125'
	local title = "" .. color .. texts.basic .. color2 .. "  /  " .. texts.advanced
	if advSettings then
		title = "" .. color2 .. texts.basic .. "  /  " .. color .. texts.advanced
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
	local tabFontSize = 16 * widgetScale
	local xpos = screenX
	local groupPadding = 1
	groupRect = {}
	for id, group in pairs(optionGroups) do
		groupRect[id] = { xpos, titleRect[2], math.floor(xpos + (font2:GetTextWidth(group.name) * tabFontSize) + (33 * widgetScale)), titleRect[4] }
		if devMode or group.id ~= 'dev' then
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

	font:Begin()

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

	maxColumnRows = math.floor((y - yPosMax + oPadding) / (oHeight + oPadding + oPadding))
	local numOptions = #options

	if currentGroupTab ~= nil then
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

	-- require restart notification
	if changesRequireRestart then
		font:SetTextColor(1, 0.35, 0.35, 1)
		font:SetOutlineColor(0, 0, 0, 0.4)
		font:Print(texts.madechanges, screenX + math.floor(bgpadding * 2.5), screenY - screenHeight + (3 * widgetScale) + math.floor(bgpadding * 2), 15 * widgetScale, "n")
	end

	-- draw options
	local yPos
	for oid, option in pairs(options) do
		if showOption(option) then
			if currentGroupTab == nil or option.group == currentGroupTab then
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
							font3:Print('\255\255\200\130' .. option.name, xPos + (oPadding * 0.5), yPos - (oHeight * 1.8) - oPadding, oHeight * 1.5, "no")
							font3:End()
							font:Begin()
						else
							font:Print(color .. option.name, xPos + (oPadding * 2), yPos - (oHeight / 2.4) - oPadding, oHeight, "no")
						end

						-- define hover area
						optionHover[oid] = { math.floor(xPos), math.floor(yPos - oHeight - oPadding), math.floor(xPosMax), math.floor(yPos + oPadding) }

						-- option controller
						local rightPadding = 4
						if option.type == 'bool' then
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
								end
								if option.id == 'font2' then
									font:End()
									font2:Begin()
									font2:SetTextColor(1, 1, 1, 1)
									font2:Print(text, xPosMax - selectWidth + 5 - rightPadding, yPos - (fontSize / 2) - oPadding, fontSize, "no")
									font2:End()
									font:Begin()
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
	if Spring.GetConfigInt('grabinput', 1) == 1 then
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
	end

end

local sec = 0
local lastUpdate = 0
local ambientplayerCheck = false

function widget:Update(dt)
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
			applyOptionValue(sceduleOptionApply[2], true, true)
			sceduleOptionApply = nil
		end
	end

	if tonumber(Spring.GetConfigInt("CameraSmoothing", 0)) == 1 then
		Spring.SetCameraState(nil, 1)
	else
		if WG['advplayerlist_api'] and not WG['advplayerlist_api'].GetLockPlayerID() and WG['setcamera_bugfix'] == true then
			Spring.SetCameraState(nil, cameraTransitionTime)
		end
	end

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

	sec = sec + dt
	if show and (sec > lastUpdate + 0.6 or forceUpdate) then
		sec = 0
		forceUpdate = nil
		lastUpdate = sec

		local changes = true
		for i, option in ipairs(options) do
			if options[i].widget ~= nil and options[i].type == 'bool' and options[i].value ~= GetWidgetToggleValue(options[i].widget) then
				options[i].value = GetWidgetToggleValue(options[i].widget)
				changes = true
			end
		end
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity", 0.6) then
			ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.6)
			changes = true
		end
		if changes then
			if windowList then
				gl.DeleteList(windowList)
			end
			windowList = gl.CreateList(DrawWindow)
		end
		options[getOptionByID('sndvolmaster')].value = tonumber(Spring.GetConfigInt("snd_volmaster", 40) or 40)    -- update value because other widgets can adjust this too
		if getOptionByID('sndvolmusic') then
			if WG['music'] and WG['music'].GetMusicVolume then
				options[getOptionByID('sndvolmusic')].value = WG['music'].GetMusicVolume()
			else
				options[getOptionByID('sndvolmusic')].value = tonumber(Spring.GetConfigInt("snd_volmusic", 20) or 20)
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
				if devMode or group.id ~= 'dev' then
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
				Spring.SetConfigInt('VSync', Spring.GetConfigInt("VSyncGame", 0))
			end
		end
	end
end

local quitscreen = false
local prevQuitscreen = false

function widget:DrawScreen()
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

	-- doing it here so other widgets having higher layer number value are also loaded
	if not initialized then
		init()
		initialized = true
	else
		if chobbyInterface then
			return
		end
		if spIsGUIHidden() then
			return
		end

		-- update new slider value
		if sliderValueChanged then
			gl.DeleteList(windowList)
			windowList = gl.CreateList(DrawWindow)
			sliderValueChanged = nil
		end

		if selectOptionsList then
			if WG['guishader'] then
				WG['guishader'].RemoveScreenRect('options_select')
				WG['guishader'].RemoveScreenRect('options_select_options')
				WG['guishader'].removeRenderDlist(selectOptionsList)
			end
			glDeleteList(selectOptionsList)
			selectOptionsList = nil
		end

		if (show or showOnceMore) and windowList then

			--on window
			local mx, my, ml = Spring.GetMouseState()
			if math_isInRect(mx, my, windowRect[1], windowRect[2], windowRect[3], windowRect[4]) then
				Spring.SetMouseCursor('cursornormal')
			end
			if groupRect ~= nil then
				for id, group in pairs(optionGroups) do
					if devMode or group.id ~= 'dev' then
						if math_isInRect(mx, my, groupRect[id][1], groupRect[id][2], groupRect[id][3], groupRect[id][4]) then
							Spring.SetMouseCursor('cursornormal')
							break
						end
					end
				end
			end
			if titleRect ~= nil and math_isInRect(mx, my, titleRect[1], titleRect[2], titleRect[3], titleRect[4]) then
				Spring.SetMouseCursor('cursornormal')
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
						for id, group in pairs(optionGroups) do
							if devMode or group.id ~= 'dev' then
								if groupRect[id] then
									RectRound(groupRect[id][1], groupRect[id][2], groupRect[id][3], groupRect[id][4], elementCorner, 1, 1, 0, 0)
								end
							end
						end
					end)
				end
				WG['guishader'].InsertDlist(backgroundGuishader, 'options')
			end
			showOnceMore = false

			-- mouseover (highlight and tooltip)
			local description = ''
			if titleRect ~= nil and math_isInRect(mx, my, titleRect[1], titleRect[2], titleRect[3], titleRect[4]) then
				local groupMargin = math.floor(bgpadding * 0.8)
				-- gloss
				glBlending(GL_SRC_ALPHA, GL_ONE)
				RectRound(titleRect[1] + groupMargin, titleRect[2], titleRect[3] - groupMargin, titleRect[4] - groupMargin, groupMargin * 1.8, 1, 1, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.12 })
				RectRound(titleRect[1] + groupMargin, titleRect[4] - groupMargin - ((titleRect[4] - titleRect[2]) * 0.5), titleRect[3] - groupMargin, titleRect[4] - groupMargin, groupMargin * 1.8, 1, 1, 0, 0, { 1, 0.88, 0.66, 0 }, { 1, 0.88, 0.66, 0.09 })
				glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
			end
			if groupRect ~= nil then
				for id, group in pairs(optionGroups) do
					if devMode or group.id ~= 'dev' then
						if math_isInRect(mx, my, groupRect[id][1], groupRect[id][2], groupRect[id][3], groupRect[id][4]) then
							mouseoverGroupTab(id)
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
					if math_isInRect(mx, my, o[1], o[2], o[3], o[4]) then
						RectRound(o[1], o[2], o[3], o[4], 1, 2, 2, 2, 2, { 0.5, 0.5, 0.5, 0.22 }, { 1, 1, 1, 0.22 })
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
						if math_isInRect(mx, my, o[1], o[2], o[3], o[4]) and options[i].type and options[i].type ~= 'label' then
							-- display console command at the bottom
							if advSettings then
								font:Begin()
								font:SetTextColor(0.5, 0.5, 0.5, 0.27)
								font:Print('/option ' .. options[i].id, screenX + (8 * widgetScale), screenY - screenHeight + (11 * widgetScale), 14 * widgetScale, "n")
								font:End()
							end
							-- highlight option
							UiSelectHighlight(o[1] - 4, o[2], o[3] + 4, o[4], nil, options[i].onclick and (ml and 0.35 or 0.22) or 0.14, options[i].onclick and { 0.5, 1, 0.25 })
							if WG.tooltip and options[i].description and options[i].description ~= '' then
								WG.tooltip.ShowTooltip('options_description', options[i].description)
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
						if options[showSelectOptions].optionsFont and fontOption then
							fontOption[i]:Begin()
							fontOption[i]:Print('\255\255\255\255' .. option, optionButtons[showSelectOptions][1] + 7, yPos - (oHeight / 2) - oPadding, fontSize, "no")
							fontOption[i]:End()
						else
							font:Begin()
							font:Print('\255\255\255\255' .. option, optionButtons[showSelectOptions][1] + 7, yPos - (oHeight / 2) - oPadding, fontSize, "no")
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
		else
			if WG['guishader'] then
				WG['guishader'].DeleteDlist('options')
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

function loadPreset(preset)
	for optionID, value in pairs(presets[preset]) do
		local i = getOptionByID(optionID)
		if options[i] ~= nil then
			options[i].value = value
			applyOptionValue(i, true)
		end
	end

	if windowList then
		gl.DeleteList(windowList)
	end
	windowList = gl.CreateList(DrawWindow)
end

function widget:KeyPress(key)
	if key == 27 then
		-- ESC
		if showSelectOptions then
			showSelectOptions = nil
		else
			show = false
		end
	end
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
			options[draggingSlider].value = newValue
			sliderValueChanged = true
			applyOptionValue(draggingSlider)    -- disabled so only on release it gets applied
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
	if spIsGUIHidden() then
		return false
	end

	if show then
		local returnTrue
		if button == 3 then
			if titleRect ~= nil and math_isInRect(mx, my, titleRect[1], titleRect[2], titleRect[3], titleRect[4]) then
				return
			end
		elseif button == 1 then
			if release then
				if titleRect ~= nil and math_isInRect(mx, my, titleRect[1], titleRect[2], titleRect[3], titleRect[4]) then
					-- showhow rightmouse doesnt get triggered :S
					advSettings = not advSettings
					startColumn = 1
					return
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
					if windowList then
						gl.DeleteList(windowList)
					end
					windowList = gl.CreateList(DrawWindow)
					return
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
					if windowList then
						gl.DeleteList(windowList)
					end
					windowList = gl.CreateList(DrawWindow)
					return
				end

				-- apply new slider value
				if draggingSlider ~= nil then
					options[draggingSlider].value = getSliderValue(draggingSlider, mx)
					applyOptionValue(draggingSlider)
					draggingSlider = nil
					draggingSliderPreDragValue = nil
					return
				end

				-- select option
				if showSelectOptions ~= nil then
					for i, o in pairs(optionSelect) do
						if math_isInRect(mx, my, o[1], o[2], o[3], o[4]) then
							options[showSelectOptions].value = o[5]
							applyOptionValue(showSelectOptions)
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

			local tabClicked = false
			if show and groupRect ~= nil then
				for id, group in pairs(optionGroups) do
					if devMode or group.id ~= 'dev' then
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
							tabClicked = true
							returnTrue = true
						end
					end
				end
			end

			if tabClicked then

			elseif math_isInRect(mx, my, windowRect[1], windowRect[2], windowRect[3], windowRect[4]) then
				-- on window
				if release then
					-- select option
					if showSelectOptions == nil then
						for i, o in pairs(optionButtons) do

							if options[i].type == 'bool' and math_isInRect(mx, my, o[1], o[2], o[3], o[4]) then
								options[i].value = not options[i].value
								applyOptionValue(i)
								if playSounds then
									if options[i].value then
										Spring.PlaySoundFile(sounds.toggleOnClick, 0.75, 'ui')
									else
										Spring.PlaySoundFile(sounds.toggleOffClick, 0.75, 'ui')
									end
								end
							elseif options[i].type == 'slider' and math_isInRect(mx, my, o[1], o[2], o[3], o[4]) then

							elseif options[i].type == 'select' and math_isInRect(mx, my, o[1], o[2], o[3], o[4]) then

							elseif options[i].onclick ~= nil and math_isInRect(mx, my, optionHover[i][1], optionHover[i][2], optionHover[i][3], optionHover[i][4]) then
								options[i].onclick(i)
							end
						end
					end
				else
					-- mousepress
					if not showSelectOptions then
						for i, o in pairs(optionButtons) do
							if options[i].type == 'slider' and (math_isInRect(mx, my, o.sliderXpos[1], o[2], o.sliderXpos[2], o[4]) or math_isInRect(mx, my, o[1], o[2], o[3], o[4])) then
								draggingSlider = i
								draggingSliderPreDragValue = options[draggingSlider].value
								local newValue = getSliderValue(draggingSlider, mx)
								if options[draggingSlider].value ~= newValue then
									options[draggingSlider].value = getSliderValue(draggingSlider, mx)
									applyOptionValue(draggingSlider)    -- disabled so only on release it gets applied
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

				if button == 1 or button == 3 then
					return true
				end
				-- on title
			elseif titleRect ~= nil and math_isInRect(mx, my, (titleRect[1] * widgetScale) - ((vsx * (widgetScale - 1)) / 2), (titleRect[2] * widgetScale) - ((vsy * (widgetScale - 1)) / 2), (titleRect[3] * widgetScale) - ((vsx * (widgetScale - 1)) / 2), (titleRect[4] * widgetScale) - ((vsy * (widgetScale - 1)) / 2)) then
				returnTrue = true
			elseif not tabClicked then
				if release and draggingSlider == nil then
					showOnceMore = true        -- show once more because the guishader lags behind, though this will not fully fix it
					show = false
				end
				return true
			end

			if show then
				if windowList then
					gl.DeleteList(windowList)
				end
				windowList = gl.CreateList(DrawWindow)
			end
			if returnTrue then
				return true
			end
		end

		if math_isInRect(mx, my, windowRect[1], windowRect[2], windowRect[3], windowRect[4]) then
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
	if getOptionByID(optionId) and widgetHandler.configData[widgetName] ~= nil and widgetHandler.configData[widgetName][configVar[1]] ~= nil then
		if configVar[2] ~= nil and widgetHandler.configData[widgetName][configVar[1]][configVar[2]] ~= nil then
			if configVar[3] ~= nil and widgetHandler.configData[widgetName][configVar[1]][configVar[2]][configVar[3]] ~= nil then
				options[getOptionByID(optionId)].value = widgetHandler.configData[widgetName][configVar[1]][configVar[2]][configVar[3]]
				return true
			else
				options[getOptionByID(optionId)].value = widgetHandler.configData[widgetName][configVar[1]][configVar[2]]
				return true
			end
		elseif options[getOptionByID(optionId)].value ~= widgetHandler.configData[widgetName][configVar[1]] then
			options[getOptionByID(optionId)].value = widgetHandler.configData[widgetName][configVar[1]]
			return true
		end
	end
end

function applyOptionValue(i, skipRedrawWindow, force)
	if options[i] == nil then
		return
	end

	if options[i].id ~= 'preset' and presets.lowest[options[i].id] ~= nil and manualChange then
		options[getOptionByID('preset')].value = presetCodes.custom
		Spring.SetConfigString('graphicsPreset', presetCodes[presetCodes.custom])
	end

	if options[i].restart then
		changesRequireRestart = true
	end

	local id = options[i].id

	if options[i].widget ~= nil then
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

-- detect potatos
local isPotatoCpu = false
local isPotatoGpu = false
local gpuMem = (Platform.gpuMemorySize and Platform.gpuMemorySize or 1000) / 1000
--if Platform ~= nil and Platform.gpuVendor == 'Intel' then
--	isPotatoGpu = true
--end
if gpuMem and gpuMem > 0 and gpuMem < 1800 then
	isPotatoGpu = true
end
if not Platform.glHaveGL4 then
	isPotatoGpu = true
end

function init()
	presetCodes = { 'lowest', 'low', 'medium', 'high', 'ultra', 'custom', }
	presetCodes = table.merge(presetCodes, table.invert(presetCodes))

	for index, name in ipairs(presetCodes) do
		presetNames[index] = texts.option['preset_' .. name]
	end

	presets = {
		lowest = {
			bloomdeferred = false,
			bloomdeferred_quality = 1,
			ssao = false,
			ssao_quality = 1,
			mapedgeextension = false,
			lighteffects = false,
			lighteffects_additionalflashes = false,
			heatdistortion = false,
			snow = false,
			particles = 9000,
			treeradius = 0,
			guishader = 0,
			decals = false,
			shadowslider = 1,
			grass = false,
			cusgl4 = false,
		},
		low = {
			bloomdeferred = true,
			bloomdeferred_quality = 1,
			ssao = false,
			ssao_quality = 1,
			mapedgeextension = false,
			lighteffects = true,
			lighteffects_additionalflashes = false,
			heatdistortion = true,
			snow = false,
			particles = 12000,
			treeradius = 200,
			guishader = 0,
			decals = true,
			shadowslider = 2,
			grass = false,
			cusgl4 = true,
		},
		medium = {
		 	bloomdeferred = true,
			bloomdeferred_quality = 1,
		 	ssao = true,
			ssao_quality = 2,
		 	mapedgeextension = true,
		 	lighteffects = true,
		 	lighteffects_additionalflashes = true,
		 	heatdistortion = true,
		 	snow = true,
		 	particles = 15000,
		 	treeradius = 400,
		 	guishader = guishaderIntensity,
		 	decals = true,
			shadowslider = 3,
		 	grass = true,
			cusgl4 = true,
		},
		high = {
			bloomdeferred = true,
			bloomdeferred_quality = 2,
			ssao = true,
			ssao_quality = 2,
			mapedgeextension = true,
			lighteffects = true,
			lighteffects_additionalflashes = true,
			heatdistortion = true,
			snow = true,
			particles = 20000,
			treeradius = 800,
			guishader = guishaderIntensity,
			decals = true,
			shadowslider = 4,
			grass = true,
			cusgl4 = true,
		},
		ultra = {
			bloomdeferred = true,
			bloomdeferred_quality = 3,
			ssao = true,
			ssao_quality = 3,
			mapedgeextension = true,
			lighteffects = true,
			lighteffects_additionalflashes = true,
			heatdistortion = true,
			snow = true,
			particles = 25000,
			treeradius = 800,
			guishader = guishaderIntensity,
			decals = true,
			shadowslider = 5,
			grass = true,
			cusgl4 = true,
		},
		custom = {},
	}

	local screenModes = WG['screenMode'] and WG['screenMode'].GetScreenModes() or {}
	local displays = WG['screenMode'] and WG['screenMode'].GetDisplays() or {}

	local displayNames = {}
	for index, display in ipairs(displays) do
		displayNames[index] = display.name .. " " .. display.width .. " × " .. display.height
	end

	local resolutionNames = {}
	for _, screenMode in ipairs(screenModes) do
		table.insert(resolutionNames, screenMode.name)
	end

	local soundDevices = { 'default' }
	local soundDevicesByName = { [''] = 1 }
	local infolog = VFS.LoadFile("infolog.txt")
	if infolog then
		local fileLines = string.lines(infolog)
		for i, line in ipairs(fileLines) do
			if string.find(line, 'Main thread CPU') or string.find(line, '%[f=-00000') then
				break
			end
			if string.find(line, '     %[') then
				local device = string.sub(string.match(line, '     %[([0-9a-zA-Z _%/%%-%(%)]*)'), 1)
				soundDevices[#soundDevices + 1] = device
				soundDevicesByName[device] = #soundDevices
			end
			-- scan for shader version error
			if string.find(line, 'error: GLSL 1.50 is not supported') then
				Spring.SetConfigInt("LuaShaders", 0)
			end

			-- look for system hardware
			if string.find(line, 'Physical CPU Cores') then
				if tonumber(string.match(line, '([0-9].*)')) and tonumber(string.match(line, '([0-9].*)')) <= 2 then
					isPotatoCpu = true
				end
			end

			if string.find(line, 'Logical CPU Cores') then
				if tonumber(string.match(line, '([0-9].*)')) and tonumber(string.match(line, '([0-9].*)')) <= 2 then
					isPotatoCpu = true
				end
			end

			if string.find(line:lower(), 'hardware config: ') then
				local s_ram = string.match(line, '([0-9]*MB RAM)')
				if s_ram ~= nil then
					s_ram = string.gsub(s_ram, " RAM", "")
					if tonumber(s_ram) and tonumber(s_ram) > 0 and tonumber(s_ram) < 6500 then
						isPotatoCpu = true
					end
				end
			end

			if string.find(line, "Loading widget:") then
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
		presetNames = { texts.option.preset_lowest, texts.option.preset_low, texts.option.preset_medium, texts.option.preset_custom }
	end

	-- if you want to add an option it should be added here, and in applyOptionValue(), if option needs shaders than see the code below the options definition
	optionGroups = {
		{ id = 'gfx', name = texts.group.graphics },
		{ id = 'ui', name = texts.group.interface },
		{ id = 'game', name = texts.group.game },
		{ id = 'control', name = texts.group.control },
		{ id = 'sound', name = texts.group.audio },
		{ id = 'notif', name = texts.group.notifications },
		{ id = 'accessibility', name = texts.group.accessibility },
		{ id = 'dev', name = texts.group.dev },
	}

	if not currentGroupTab or Spring.GetGameFrame() == 0 then
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

	options = {
		--GFX
		{ id = "preset", group = "gfx", category = types.basic, name = texts.option.preset, type = "select", options = presetNames, value = presetCodes[Spring.GetConfigString('graphicsPreset')],
			onload = function(i)
			end,
			onchange = function(i, value)
				Spring.SetConfigString('graphicsPreset', presetCodes[value])

				if value == presetCodes.custom then return end

				Spring.Echo('Loading preset:   ' .. options[i].options[value])
				manualChange = false
				loadPreset(presetCodes[value])
				manualChange = true
			end,
		},
		{ id = "label_gfx_screen", group = "gfx", name = texts.option.label_screen, category = types.basic },
		{ id = "label_gfx_screen_spacer", group = "gfx", category = types.basic },
		{ id = "display", group = "gfx", category = types.dev, name = texts.option.display, type = "select", options = displayNames, value = 0,
			onchange = function(i, value)
			end,
		},
		{ id = "resolution", group = "gfx", category = types.basic, name = texts.option.resolution, type = "select", options = resolutionNames, value = Spring.GetConfigInt('SelectedScreenMode', 1), description = texts.option.resolution_descr,
			onchange = function(i, value)
				Spring.SetConfigInt('SelectedScreenMode', value)

				if WG['screenMode'] then
					WG['screenMode'].SetScreenMode(value)
				end
			end,
		},
		{ id = "vsync", group = "gfx", category = types.basic, name = texts.option.vsync,  type = "select", options = { 'off', 'enabled', 'adaptive'}, value = 1, description = texts.option.vsync_descr,
		  onload = function(i)
			  local vsync =  Spring.GetConfigInt("VSyncGame", 0)
			  if vsync == 1 then
			  	options[getOptionByID('vsync')].value = 2
			  elseif vsync == -1 then
			  	options[getOptionByID('vsync')].value = 3
			  else
				options[getOptionByID('vsync')].value = 1
			  end
			  Spring.SetConfigInt("VSyncGame", vsync)
		  end,
		  onchange = function(i, value)
			  local vsync = 0
			  if value == 2 then
				  vsync = 1
			  elseif value == 3 then
				  vsync = -1
			  end
			  Spring.SetConfigInt("VSync", vsync)
			  Spring.SetConfigInt("VSyncGame", vsync)    -- stored here as assurance cause lobby/game also changes vsync when idle and lobby could think game has set vsync 4 after a hard crash
		  end,
		},
		{ id = "limitidlefps", group = "gfx", category = types.advanced, widget = "Limit idle FPS", name = texts.option.limitidlefps, type = "bool", value = GetWidgetToggleValue("Limit idle FPS"), description = texts.option.limitidlefps_descr },

		{ id = "msaa", group = "gfx", category = types.basic, name = texts.option.msaa, type = "select", options = { 'off', 'x2', 'x4', 'x8'}, restart = true, value = tonumber(Spring.GetConfigInt("MSAALevel", 0) or 0), description = texts.option.msaa_descr,
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

		{ id = "cas_sharpness", group = "gfx", category = types.advanced, name = texts.option.cas_sharpness, min = 0.75, max = 1.1, step = 0.01, type = "slider", value = 1.0, description = texts.option.cas_sharpness_descr,
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

		{ id = "label_gfx_lighting", group = "gfx", name = texts.option.label_lighting, category = types.basic },
		{ id = "label_gfx_lighting_spacer", group = "gfx", category = types.basic },


		{ id = "advmapshading", group = "gfx", category = types.dev, name = texts.option.advmapshading, type = "bool", value = (Spring.GetConfigInt("AdvMapShading", 1) == 1), description = texts.option.advmapshading_descr,
		  onchange = function(i, value)
			  Spring.SetConfigInt("AdvMapShading", (value and 1 or 0))
			  Spring.SendCommands("advmapshading "..(value and '1' or '0'))
		  end,
		},

		{ id = "grounddetail", group = "gfx", category = types.dev, name = texts.option.grounddetail, type = "slider", min = 50, max = 200, step = 1, value = tonumber(Spring.GetConfigInt("GroundDetail", 150) or 150), description = texts.option.grounddetail_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("GroundDetail", value)
			  Spring.SendCommands("GroundDetail " .. value)
		  end,
		},

		{ id = "cusgl4", group = "gfx", name = texts.option.cus, category = types.advanced, type = "bool", value = (Spring.GetConfigInt("cus2", 1) == 1), description = texts.option.cus_descr,
		  onchange = function(i, value)
			  if value == 0.5 then
				  Spring.SendCommands("luarules disablecusgl4")
			  else
				  Spring.SetConfigInt("cus2", (value and 1 or 0))
				  Spring.SendCommands("luarules "..(value and 'reloadcusgl4' or 'disablecusgl4'))
			  end
		  end,
		},

		{ id = "shadowslider", group = "gfx", category = types.basic, name = texts.option.shadowslider, type = "select", options = { 'lowest', 'low', 'medium', 'high', 'ultra'}, value = tonumber(Spring.GetConfigInt("ShadowMapSize", 1) or 4096), description = texts.option.shadowslider_descr,
		  onload = function(i)
			  local ShadowMapSize = tonumber(Spring.GetConfigInt("ShadowMapSize", 4096) or 4096)
			  if devMode then
				  options[getOptionByID('shadowslider')].options[6] = 'insane'
			  end
			  local quality = {
				  ['lowest'] = 2048, ['low'] = 3584, ['medium'] = 6144, ['high'] = 8192, ['ultra'] = 10240, ['insane'] = 12288
			  }
			  if ShadowMapSize == 0 then
				  --options[getOptionByID('shadowslider')].value = 1
			  elseif ShadowMapSize ~= nil then
				  for k,v in pairs( options[getOptionByID('shadowslider')].options) do
					  if quality[v] ~= nil and quality[v] <= ShadowMapSize then
						  options[getOptionByID('shadowslider')].value = k
					  end
				  end
			  end
		  end,
		  onchange = function(i, value)
			  local quality = {
				  [1] = 2048, [2] = 3072, [3] = 4096, [4] = 6144, [5] = 10240, [6] = 16384
			  }
			  value = quality[value]
			  Spring.SendCommands("shadows 1 " .. value)
			  Spring.SetConfigInt("Shadows", 1)
			  Spring.SetConfigInt("ShadowMapSize", value)
		  end,
		},

		{ id = "shadows_opacity", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.shadows_opacity, type = "slider", min = 0.3, max = 1, step = 0.01, value = gl.GetSun("shadowDensity"), description = '',
		  onchange = function(i, value)
			  Spring.SetSunLighting({ groundShadowDensity = value, modelShadowDensity = value })
		  end,
		},

		{ id = "ssao", group = "gfx", category = types.basic, widget = "SSAO", name = texts.option.ssao, type = "bool", value = GetWidgetToggleValue("SSAO"), description = texts.option.ssao_descr },
		{ id = "ssao_strength", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.ssao_strength, type = "slider", min = 5, max = 11, step = 1, value = 8, description = '',
		  onload = function(i)
			  loadWidgetData("SSAO", "ssao_strength", { 'strength' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('SSAO', 'ssao', 'setStrength', { 'strength' }, value)
		  end,
		},
		{ id = "ssao_quality", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.ssao_quality, type = "select", options = { 'low', 'medium', 'high'}, value = (WG['ssao'] ~= nil and WG['ssao'].getPreset() or 2), description = texts.option.ssao_quality_descr,
		  onload = function(i)
			  if widgetHandler.configData["SSAO"] ~= nil and widgetHandler.configData["SSAO"].preset ~= nil then
				  options[getOptionByID('ssao_quality')].value = widgetHandler.configData["SSAO"].preset
			  end
		  end,
		  onchange = function(i, value)
			  saveOptionValue('SSAO', 'ssao', 'setPreset', { 'preset' }, value)
		  end,
		},

		{ id = "bloomdeferred", group = "gfx", category = types.basic, widget = "Bloom Shader Deferred", name = texts.option.bloomdeferred, type = "bool", value = GetWidgetToggleValue("Bloom Shader Deferred"), description = texts.option.bloomdeferred_descr },
		{ id = "bloomdeferredbrightness", group = "gfx", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.bloomdeferredbrightness, type = "slider", min = 0.4, max = 1.4, step = 0.05, value = 0.9, description = '',
		  onload = function(i)
			  loadWidgetData("Bloom Shader Deferred", "bloomdeferredbrightness", { 'glowAmplifier' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Bloom Shader Deferred', 'bloomdeferred', 'setBrightness', { 'glowAmplifier' }, value)
		  end,
		},
		{ id = "bloomdeferred_quality", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.bloomdeferred_quality, type = "select", options = { 'low', 'medium', 'high'}, value = (WG['bloomdeferred'] ~= nil and WG['bloomdeferred'].getPreset() or 2), description = texts.option.bloomdeferred_quality_descr,
		  onload = function(i)
			  if widgetHandler.configData["Bloom Shader Deferred"] ~= nil and widgetHandler.configData["Bloom Shader Deferred"].preset ~= nil then
				  options[getOptionByID('bloomdeferred_quality')].value = widgetHandler.configData["Bloom Shader Deferred"].preset
			  end
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Bloom Shader Deferred', 'bloomdeferred', 'setPreset', { 'preset' }, value)
		  end,
		},


		{ id = "lighteffects", group = "gfx", category = types.basic, name = texts.option.lighteffects, type = "bool", value = GetWidgetToggleValue("Light Effects"), description = texts.option.lighteffects_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  if value then
				  if widgetHandler.orderList["Deferred rendering"] ~= nil then
					  widgetHandler:EnableWidget("Deferred rendering")
				  end
				  widgetHandler:EnableWidget("Light Effects")
			  else
				  if widgetHandler.orderList["Deferred rendering"] ~= nil then
					  widgetHandler:DisableWidget("Deferred rendering")
				  end
				  widgetHandler:DisableWidget("Light Effects")
			  end
		  end,
		},
		{ id = "lighteffects_brightness", group = "gfx", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.lighteffects_brightness, min = 0.65, max = 2, step = 0.05, type = "slider", value = 1.4, description = texts.option.lighteffects_brightness_descr,
		  onload = function(i)
			  loadWidgetData("Light Effects", "lighteffects_brightness", { 'globalLightMult' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Light Effects', 'lighteffects', 'setGlobalBrightness', { 'globalLightMult' }, value)
		  end,
		},
		{ id = "lighteffects_additionalflashes", category = types.dev, group = "gfx", name = widgetOptionColor .. "   " .. texts.option.lighteffects_additionalflashes, type = "bool", value = true, description = texts.option.lighteffects_additionalflashes_descr,
		  onload = function(i)
			  loadWidgetData("Light Effects", "lighteffects_additionalflashes", { 'additionalLightingFlashes' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Light Effects', 'lighteffects', 'setAdditionalFlashes', { 'additionalLightingFlashes' }, value)
		  end,
		},

		{ id = "heatdistortion", group = "gfx", category = types.dev, widget = "Lups", name = texts.option.heatdistortion, type = "bool", value = GetWidgetToggleValue("Lups"), description = texts.option.heatdistortion_descr },


		{ id = "label_gfx_environment", group = "gfx", name = texts.option.label_environment, category = types.basic },
		{ id = "label_gfx_environment_spacer", group = "gfx", category = types.basic },

		--{ id = "losopacity", group = "gfx", category = types.advanced, name = texts.option.lineofsight..widgetOptionColor .. "  " .. texts.option.losopacity, type = "slider", min = 0.5, max = 3, step = 0.1, value = (WG['los'] ~= nil and WG['los'].getOpacity ~= nil and WG['los'].getOpacity()) or 1, description = '',
		--  onload = function(i)
		--	  loadWidgetData("LOS colors", "losopacity", { 'opacity' })
		--  end,
		--  onchange = function(i, value)
		--	  saveOptionValue('LOS colors', 'los', 'setOpacity', { 'opacity' }, value)
		--  end,
		--},

		{ id = "water", group = "gfx", category = types.basic, name = texts.option.water, type = "select", options = { 'basic', 'reflective', 'dynamic', 'reflective&refractive', 'bump-mapped' }, value = desiredWaterValue + 1,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  desiredWaterValue = value - 1
			  if waterDetected then
				  Spring.SendCommands("water " .. desiredWaterValue)
			  end
		  end,
		},

		{ id = "mapedgeextension", group = "gfx", category = types.advanced, widget = "Map Edge Extension", name = texts.option.mapedgeextension, type = "bool", value = GetWidgetToggleValue("Map Edge Extension"), description = texts.option.mapedgeextension_descr },

		{ id = "mapedgeextension_brightness", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.mapedgeextension_brightness, min = 0.2, max = 1, step = 0.01, type = "slider", value = 0.3, description = '',
		  onload = function(i)
			  loadWidgetData("Map Edge Extension", "mapedgeextension_brightness", { 'brightness' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Map Edge Extension', 'mapedgeextension', 'setBrightness', { 'brightness' }, value)
		  end,
		},
		{ id = "mapedgeextension_curvature", category = types.dev, group = "gfx", name = widgetOptionColor .. "   " .. texts.option.mapedgeextension_curvature, type = "bool", value = true, description = texts.option.mapedgeextension_curvature_descr,
		  onload = function(i)
			  loadWidgetData("Map Edge Extension", "mapedgeextension_curvature", { 'curvature' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Map Edge Extension', 'mapedgeextension', 'setCurvature', { 'curvature' }, value)
		  end,
		},

		{ id = "decals", group = "gfx", category = types.advanced, name = texts.option.decals, restart = true, type = "bool", value = tonumber(Spring.GetConfigInt("GroundDecals", 4) or 4) >= 1, description = texts.option.decals_descr,
		  onchange = function(i, value)
			  Spring.SetConfigInt("GroundDecals", (value and 4 or 0))
			  Spring.SendCommands("GroundDecals " .. (value and 4 or 0))
			  Spring.SetConfigInt("GroundScarAlphaFade", 1)
		  end,
		},

		{ id = "grass", group = "gfx", category = types.basic, widget = "Map Grass GL4", name = texts.option.grass, type = "bool", value = GetWidgetToggleValue("Map Grass GL4"), description = texts.option.grass_desc },

		{ id = "treewind", group = "gfx", category = types.dev, name = texts.option.treewind, type = "bool", value = tonumber(Spring.GetConfigInt("TreeWind", 1) or 1) == 1, description = texts.option.treewind_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SendCommands("luarules treewind " .. (value and 1 or 0))
			  Spring.SetConfigInt("TreeWind", (value and 1 or 0))
		  end,
		},

		{ id = "snow", group = "gfx", category = types.basic, widget = "Snow", name = texts.option.snow, type = "bool", value = GetWidgetToggleValue("Snow"), description = texts.option.snow_descr },
		{ id = "snowmap", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.snowmap, type = "bool", value = true, description = texts.option.snowmap_descr,
		  onload = function(i)
			  loadWidgetData("Snow", "snowmap", { 'snowMaps', Game.mapName:lower() })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Snow', 'snow', 'setSnowMap', { 'snowMaps', Game.mapName:lower() }, value)
		  end,
		},
		{ id = "snowautoreduce", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.snowautoreduce, type = "bool", value = true, description = texts.option.snowautoreduce_descr,
		  onload = function(i)
			  loadWidgetData("Snow", "snowautoreduce", { 'autoReduce' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Snow', 'snow', 'setAutoReduce', { 'autoReduce' }, value)
		  end,
		},
		{ id = "snowamount", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.snowamount, type = "slider", min = 0.2, max = 3, step = 0.2, value = 1, description = texts.option.snowamount_descr,
		  onload = function(i)
			  loadWidgetData("Snow", "snowamount", { 'customParticleMultiplier' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Snow', 'snow', 'setMultiplier', { 'customParticleMultiplier' }, value)
		  end,
		},

		{ id = "clouds", group = "gfx", category = types.advanced, widget = "Volumetric Clouds", name = texts.option.clouds, type = "bool", value = GetWidgetToggleValue("Volumetric Clouds"), description = '' },
		{ id = "clouds_opacity", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.clouds_opacity, type = "slider", min = 0.2, max = 1.4, step = 0.05, value = 1, description = '',
		  onload = function(i)
			  loadWidgetData("Volumetric Clouds", "clouds_opacity", { 'opacityMult' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Volumetric Clouds', 'clouds', 'setOpacity', { 'opacityMult' }, value)
		  end,
		},
		{ id = "fogmult", group = "gfx", category = types.advanced, name = texts.option.fog, type = "slider", min = 0, max = 1, step = 0.01, value = Spring.GetConfigFloat("FogMult", 1), description = texts.option.fogmult_descr,
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

		{ id = "label_gfx_effects", group = "gfx", name = texts.option.label_effects, category = types.basic },
		{ id = "label_gfx_effects_spacer", group = "gfx", category = types.basic },

		{ id = "particles", group = "gfx", category = types.basic, name = texts.option.particles, type = "slider", min = 9000, max = 25000, step = 1000, value = tonumber(Spring.GetConfigInt("MaxParticles", 1) or 15000), description = texts.option.particles_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("MaxParticles", value)
			  Spring.SetConfigInt("MaxNanoParticles", math.floor(value*0.34))
		  end,
		},

		{ id = "unitRotation", group = "gfx", category = types.advanced, name = texts.option.unitrotation, min = 0, max = 10, step = 1, type = "slider", value = tonumber(Spring.GetConfigInt("unitRotation", 0)), description = texts.option.unitrotation_descr,
		  onchange = function(i, value)
			  Spring.SetConfigInt("unitRotation", value)
		  end
		},

		{ id = "unitScale", group = "gfx", category = types.dev, name = "Unit Scale", min = 0.85, max = 1, step = 0.01, type = "slider", value = tonumber(Spring.GetConfigFloat("unitScale", 1)),
		  onchange = function(i, value)
			  Spring.SetConfigFloat("unitScale", value)
		  end
		},

		{ id = "dof", group = "gfx", category = types.advanced, widget = "Depth of Field", name = texts.option.dof, type = "bool", value = GetWidgetToggleValue("Depth of Field"), description = texts.option.dof_descr },
		{ id = "dof_autofocus", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.dof_autofocus, type = "bool", value = true, description = texts.option.dof_autofocus_descr,
		  onload = function(i)
			  loadWidgetData("Depth of Field", "dof_autofocus", { 'autofocus' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Depth of Field', 'dof', 'setAutofocus', { 'autofocus' }, value)
		  end,
		},
		{ id = "dof_fstop", group = "gfx", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.dof_fstop, type = "slider", min = 1, max = 6, step = 0.1, value = 2, description = texts.option.dof_fstop_descr,
		  onload = function(i)
			  loadWidgetData("Depth of Field", "dof_fstop", { 'fStop' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Depth of Field', 'dof', 'setFstop', { 'fStop' }, value)
		  end,
		},

		{ id = "label_gfx_game", group = "gfx", name = texts.option.label_game, category = types.advanced },
		{ id = "label_gfx_game_spacer", group = "gfx", category = types.basic },
		{ id = "resurrectionhalos", group = "gfx", category = types.advanced, widget = "Resurrection Halos GL4", name = texts.option.resurrectionhalos, type = "bool", value = GetWidgetToggleValue("Resurrection Halos GL4"), description = texts.option.resurrectionhalos_descr },
		{ id = "tombstones", group = "gfx", category = types.advanced, name = texts.option.tombstones, type = "bool", value = (Spring.GetConfigInt("tombstones", 1) == 1), description = texts.option.tombstones_descr,
		  onchange = function(i, value)
			  Spring.SetConfigInt("tombstones", (value and 1 or 0))
		  end,
		},

		{ id = "xmas", group = "gfx", name = texts.option.xmas, category = types.basic, type = "bool", value = (Spring.GetConfigFloat("decorationsize", 1) == 1), description = texts.option.xmas_descr,
		  onchange = function(i, value)
			  Spring.SetConfigFloat("decorationsize", (value and 1 or 0))
		  end,
		},


		-- SOUND
		{ id = "snddevice", group = "sound", category = types.advanced, name = texts.option.snddevice, type = "select", restart = true, options = soundDevices, value = soundDevicesByName[Spring.GetConfigString("snd_device")], description = texts.option.snddevice_descr,
		  onchange = function(i, value)
			  if options[i].options[options[i].value] == 'default' then
				  Spring.SetConfigString("snd_device", '')
			  else
				  Spring.SetConfigString("snd_device", options[i].options[options[i].value])
			  end
		  end,
		},

		{ id = "sndvolmaster", group = "sound", category = types.basic, name = texts.option.volume .. widgetOptionColor .. "  " .. texts.option.sndvolmaster, type = "slider", min = 0, max = 200, step = 2, value = tonumber(Spring.GetConfigInt("snd_volmaster", 1) or 100),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("snd_volmaster", value)
		  end,
		},
		{ id = "sndvolgeneral", group = "sound", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.sndvolgeneral, type = "slider", min = 0, max = 100, step = 2, value = tonumber(Spring.GetConfigInt("snd_volgeneral", 1) or 100),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("snd_volgeneral", value)
		  end,
		},
		{ id = "sndvolbattle", group = "sound", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.sndvolbattle, type = "slider", min = 0, max = 100, step = 2, value = tonumber(Spring.GetConfigInt("snd_volbattle", 1) or 100),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("snd_volbattle", value)
		  end,
		},
		{ id = "sndvolui", group = "sound", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.sndvolui, type = "slider", min = 0, max = 100, step = 2, value = tonumber(Spring.GetConfigInt("snd_volui", 1) or 100),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("snd_volui", value)
		  end,
		},
		--{ id = "sndvolunitreply", group = "sound", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.sndvolunitreply, type = "slider", min = 0, max = 100, step = 2, value = tonumber(Spring.GetConfigInt("snd_volunitreply", 1) or 100),
		--  onload = function(i)
		--  end,
		--  onchange = function(i, value)
		--	  Spring.SetConfigInt("snd_volunitreply", value)
		--  end,
		--},
		{ id = "console_chatvolume", group = "sound", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.console_chatvolume, type = "slider", min = 0, max = 1, step = 0.01, value = (WG['chat'] ~= nil and WG['chat'].getChatVolume() or 0), description = texts.option.console_chatvolume_descr,
		  onload = function(i)
			  loadWidgetData("Chat", "console_chatvolume", { 'sndChatFileVolume' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Chat', 'chat', 'setChatVolume', { 'sndChatFileVolume' }, value)
		  end,
		},
		{ id = "sndvolmusic", group = "sound", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.sndvolmusic, type = "slider", min = 0, max = 100, step = 1, value = tonumber(Spring.GetConfigInt("snd_volmusic", 20) or 20),
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

		{ id = "sndairabsorption", group = "sound", category = types.advanced, name = texts.option.sndairabsorption, type = "slider", min = 0, max = 0.4, step = 0.01, value = tonumber(Spring.GetConfigFloat("snd_airAbsorption", .35) or .35), description = texts.option.sndairabsorption_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigFloat("snd_airAbsorption", value)
		  end,
		},

		{ id = "soundtrackNew", group = "sound", category = types.basic, name = texts.option.soundtrack.. widgetOptionColor .. "  " .. texts.option.soundtracknew, type = "bool", value = Spring.GetConfigInt('UseSoundtrackNew', 1) == 1, description = texts.option.soundtrack_descr,
			onchange = function(i, value)
				Spring.SetConfigInt('UseSoundtrackNew', value and 1 or 0)
				if WG['music'] and WG['music'].RefreshTrackList then
					WG['music'].RefreshTrackList()
				end
			end
		},
		{ id = "soundtrackOld", group = "sound", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.soundtrackold, type = "bool", value = Spring.GetConfigInt('UseSoundtrackOld', 0) == 1,
			onchange = function(i, value)
				Spring.SetConfigInt('UseSoundtrackOld', value and 1 or 0)
				if WG['music'] and WG['music'].RefreshTrackList then
					WG['music'].RefreshTrackList()
				end
			end
		},
		{ id = "soundtrackCustom", group = "sound", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.soundtrackcustom, type = "bool", value = Spring.GetConfigInt('UseSoundtrackCustom', 1) == 1,
			onchange = function(i, value)
				Spring.SetConfigInt('UseSoundtrackCustom', value and 1 or 0)
				if WG['music'] and WG['music'].RefreshTrackList then
					WG['music'].RefreshTrackList()
				end
			end
		},
		{ id = "soundtrackSilenceTimer", group = "sound", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.soundtracksilence, type = "bool", value = Spring.GetConfigInt('UseSoundtrackSilenceTimer', 1) == 1, description = texts.option.soundtracksilence_descr,
			onchange = function(i, value)
				Spring.SetConfigInt('UseSoundtrackSilenceTimer', value and 1 or 0)
				if WG['music'] and WG['music'].RefreshTrackList then
					WG['music'].RefreshTrackList()
				end
			end
		},
		{ id = "soundtrackInterruption", group = "sound", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.soundtrackinterruption, type = "bool", value = Spring.GetConfigInt('UseSoundtrackInterruption', 1) == 1, description = texts.option.soundtrackinterruption_descr,
			onchange = function(i, value)
				Spring.SetConfigInt('UseSoundtrackInterruption', value and 1 or 0)
				if WG['music'] and WG['music'].RefreshTrackList then
					WG['music'].RefreshTrackList()
				end
			end
		},

		{ id = "loadscreen_music", group = "sound", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.loadscreen_music, type = "bool", value = (Spring.GetConfigInt("music_loadscreen", 1) == 1), description = texts.option.loadscreen_music_descr,
		  onchange = function(i, value)
			  Spring.SetConfigInt("music_loadscreen", (value and 1 or 0))
		  end,
		},

		{ id = "scav_messages", group = "notif", category = types.basic, name = texts.option.scav_messages, type = "bool", value = tonumber(Spring.GetConfigInt("scavmessages", 1) or 1) == 1, description = "",
		  onchange = function(i, value)
			  Spring.SetConfigInt("scavmessages", (value and 1 or 0))
		  end,
		},
		{ id = "scav_voicenotifs", group = "notif", category = types.basic, widget = "Scavenger Audio Reciever", name = texts.option.scav_voicenotifs, type = "bool", value = GetWidgetToggleValue("Scavenger Audio Reciever"), description = texts.option.scav_voicenotifs_descr },

		{ id = "notifications_tutorial", group = "notif", name = texts.option.notifications_tutorial, category = types.basic, type = "bool", value = (WG['notifications'] ~= nil and WG['notifications'].getTutorial()), description = texts.option.notifications_tutorial_desc,
		  onload = function(i)
			  loadWidgetData("Notifications", "notifications_tutorial", { 'tutorialMode' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Notifications', 'notifications', 'setTutorial', { 'tutorialMode' }, value)
		  end,
		},
		{ id = "notifications_messages", group = "notif", name = texts.option.notifications_messages, category = types.basic, type = "bool", value = (WG['notifications'] ~= nil and WG['notifications'].getMessages()), description = texts.option.notifications_messages_descr,
		  onload = function(i)
			  loadWidgetData("Notifications", "notifications_messages", { 'displayMessages' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Notifications', 'notifications', 'setMessages', { 'displayMessages' }, value)
		  end,
		},
		{ id = "notifications_spoken", group = "notif", name = texts.option.notifications_spoken, category = types.basic, type = "bool", value = (WG['notifications'] ~= nil and WG['notifications'].getSpoken()), description = texts.option.notifications_spoken_descr,
		  onload = function(i)
			  loadWidgetData("Notifications", "notifications_spoken", { 'spoken' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Notifications', 'notifications', 'setSpoken', { 'spoken' }, value)
		  end,
		},
		{ id = "notifications_volume", group = "notif", category = types.basic, name = texts.option.notifications_volume, type = "slider", min = 0.05, max = 1, step = 0.05, value = 1, description = texts.option.notifications_volume_descr,
		  onload = function(i)
			  loadWidgetData("Notifications", "notifications_volume", { 'volume' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Notifications', 'notifications', 'setVolume', { 'volume' }, value)
		  end,
		},
		{ id = "notifications_playtrackedplayernotifs", category = types.basic, group = "notif", name = texts.option.notifications_playtrackedplayernotifs, type = "bool", value = (WG['notifications'] ~= nil and WG['notifications'].getPlayTrackedPlayerNotifs()), description = texts.option.notifications_playtrackedplayernotifs_descr,
		  onload = function(i)
			  loadWidgetData("Notifications", "notifications_playtrackedplayernotifs", { 'playTrackedPlayerNotifs' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Notifications', 'notifications', 'setPlayTrackedPlayerNotifs', { 'playTrackedPlayerNotifs' }, value)
		  end,
		},


		{ id = "label_notif_messages", group = "notif", name = texts.option.label_messages, category = types.basic },
		{ id = "label_notif_messages_spacer", group = "notif", category = types.basic },

		-- CONTROL
		{ id = "hwcursor", group = "control", category = types.basic, name = texts.option.hwcursor, type = "bool", value = tonumber(Spring.GetConfigInt("hardwareCursor", 1) or 1) == 1, description = texts.option.hwcursor_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SendCommands("HardwareCursor " .. (value and 1 or 0))
			  Spring.SetConfigInt("HardwareCursor", (value and 1 or 0))
		  end,
		},
		{ id = "setcamera_bugfix", group = "control", category = types.advanced, name = texts.option.setcamera_bugfix, type = "bool", value = true, description = texts.option.setcamera_bugfix_descr,
		  onload = function(i)
			WG['setcamera_bugfix'] = true
		  end,
		  onchange = function(i, value)
			WG['setcamera_bugfix'] = value
		  end,
		},
		{ id = "cursorsize", group = "control", category = types.basic, name = texts.option.cursorsize, type = "slider", min = 0.3, max = 1.7, step = 0.1, value = 1, description = texts.option.cursorsize_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  if WG['cursors'] then
				  WG['cursors'].setsizemult(value)
			  end
		  end,
		},

		{ id = "containmouse", group = "control", category = types.basic, widget = "Grabinput", name = texts.option.containmouse, type = "bool", value = GetWidgetToggleValue("Grabinput"), description = texts.option.containmouse_descr },

		{ id = "doubleclicktime", group = "control", category = types.advanced, restart = true, name = texts.option.doubleclicktime, type = "slider", min = 150, max = 400, step = 10, value = Spring.GetConfigInt("DoubleClickTime", 200), description = "",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("DoubleClickTime", value)
		  end,
		},

		{ id = "keylayout", group = "control", category = types.basic, name = texts.option.keylayout, type = "select", options = keyLayouts, value = 1, description = texts.option.keylayout_descr,
			onload = function()
				local keyLayout = Spring.GetConfigString("KeyboardLayout")

				if not keyLayout or keyLayout == '' then
					keyLayout = keyLayouts[1]
					Spring.SetConfigString("KeyboardLayout", keyLayouts[1])
				end

				local value = 1
				for i, v in ipairs(keyLayouts) do
					if v == keyLayout then
						value = i
						break
					end
				end

				options[getOptionByID('keylayout')].value = value
			end,
			onchange = function(_, value)
				Spring.SetConfigString("KeyboardLayout", keyLayouts[value])
				if WG['buildmenu'] and WG['buildmenu'].reloadBindings then
					WG['buildmenu'].reloadBindings()
				end
			end,
		},

		{ id = "label_ui_camera", group = "control", name = texts.option.label_camera, category = types.basic },
		{ id = "label_ui_camera_spacer", group = "control", category = types.basic },

		{ id = "middleclicktoggle", group = "control", category = types.basic, name = texts.option.middleclicktoggle, type = "bool", value = (Spring.GetConfigFloat("MouseDragScrollThreshold", 0.3) ~= 0), description = texts.option.middleclicktoggle_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigFloat("MouseDragScrollThreshold", (value and 0.3 or 0))
		  end,
		},

		{ id = "screenedgemove", group = "control", category = types.basic, name = texts.option.screenedgemove, type = "bool", restart = true, value = tonumber(Spring.GetConfigInt("FullscreenEdgeMove", 1) or 1) == 1, description = texts.option.screenedgemove_descr,
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
		{ id = "screenedgemovewidth", group = "control", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.screenedgemovewidth, type = "slider", min = 0, max = 0.1, step = 0.01, value = edgeMoveWidth, description = texts.option.screenedgemovewidth_descr,
		  onchange = function(i, value)
			  edgeMoveWidth = value
			  Spring.SetConfigFloat("EdgeMoveWidth", value)
		  end,
		},
		{ id = "screenedgemovedynamic", group = "control", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.screenedgemovedynamic, type = "bool", restart = true, value = tonumber(Spring.GetConfigInt("EdgeMoveDynamic", 1) or 1) == 1, description = texts.option.screenedgemovedynamic_descr,
		  onchange = function(i, value)
			  Spring.SetConfigInt("EdgeMoveDynamic", (value and 1 or 0))
		  end,
		},

		{ id = "camera", group = "control", category = types.basic, name = texts.option.camera, type = "select", options = { 'fps', 'overhead', 'spring', 'rot overhead', 'free' }, value = (tonumber((Spring.GetConfigInt("CamMode", 1) + 1) or 2)),
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
		  end,
		},
		{ id = "camerashake", group = "control", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.camerashake, type = "slider", min = 0, max = 200, step = 10, value = 80, description = texts.option.camerashake_descr,
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
		{ id = "camerasmoothing", group = "control", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.camerasmoothing, type = "bool", value = (tonumber(Spring.GetConfigInt("CameraSmoothing", 0)) == 1), description = "",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("CameraSmoothing", (value and 1 or 0))
			  if value then
				  Spring.SendCommands("set CamFrameTimeCorrection 1")
				  Spring.SendCommands("set SmoothTimeOffset 2")
				else
				  Spring.SendCommands("set CamFrameTimeCorrection 0")
				  Spring.SendCommands("set SmoothTimeOffset 0")
			  end
		  end,
		},
		{ id = "camerasmoothness", group = "control", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.camerasmoothness, type = "slider", min = 0.04, max = 2, step = 0.01, value = cameraTransitionTime, description = texts.option.camerasmoothness_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  cameraTransitionTime = value
		  end,
		},
		{ id = "camerapanspeed", group = "control", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.camerapanspeed, type = "slider", min = -0.01, max = -0.00195, step = 0.0001, value = Spring.GetConfigFloat("MiddleClickScrollSpeed", 0.0035), description = texts.option.camerapanspeed_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigFloat("MiddleClickScrollSpeed", value)
		  end,
		},
		{ id = "cameramovespeed", group = "control", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.cameramovespeed, type = "slider", min = 0, max = 50, step = 1, value = Spring.GetConfigInt("CamSpringScrollSpeed", 10), description = texts.option.cameramovespeed_descr,
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
		{ id = "scrollspeed", group = "control", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.scrollspeed, type = "slider", min = 1, max = 50, step = 1, value = math.abs(tonumber(Spring.GetConfigInt("ScrollWheelSpeed", 1) or 25)), description = '',
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
		{ id = "scrollinverse", group = "control", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.scrollinverse, type = "bool", value = (tonumber(Spring.GetConfigInt("ScrollWheelSpeed", 1) or 25) < 0), description = "",
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

		{ id = "lockcamera_transitiontime", group = "control", category = types.advanced, name = texts.option.lockcamera..widgetOptionColor .. "   " ..texts.option.lockcamera_transitiontime, type = "slider", min = 0.5, max = 1.7, step = 0.01, value = (WG['advplayerlist_api'] ~= nil and WG['advplayerlist_api'].GetLockTransitionTime ~= nil and WG['advplayerlist_api'].GetLockTransitionTime()), description = texts.option.lockcamera_transitiontime_descr,
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "lockcamera_transitiontime", { 'transitionTime' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetLockTransitionTime', { 'transitionTime' }, value)
		  end,
		},


		{ id = "allyselunits_select", group = "control", category = types.advanced, name = widgetOptionColor .. "   " ..texts.option.allyselunits_select, type = "bool", value = (WG['allyselectedunits'] ~= nil and WG['allyselectedunits'].getSelectPlayerUnits()), description = texts.option.allyselunits_select_descr,
		  onload = function(i)
			  loadWidgetData("Ally Selected Units", "allyselunits_select", { 'selectPlayerUnits' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Ally Selected Units', 'allyselectedunits', 'setSelectPlayerUnits', { 'selectPlayerUnits' }, value)
		  end,
		},
		{ id = "lockcamera_hideenemies", group = "control", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.lockcamera_hideenemies, type = "bool", value = (WG['advplayerlist_api'] ~= nil and WG['advplayerlist_api'].GetLockHideEnemies()), description = texts.option.lockcamera_hideenemies_descr,
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "lockcamera_hideenemies", { 'lockcameraHideEnemies' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetLockHideEnemies', { 'lockcameraHideEnemies' }, value)
		  end,
		},
		{ id = "lockcamera_los", group = "control", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.lockcamera_los, type = "bool", value = (WG['advplayerlist_api'] ~= nil and WG['advplayerlist_api'].GetLockLos()), description = texts.option.lockcamera_los_descr,
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "lockcamera_los", { 'lockcameraLos' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetLockLos', { 'lockcameraLos' }, value)
		  end,
		},

		-- INTERFACE
		{ id = "label_ui_interface", group = "ui", name = texts.option.label_interface, category = types.basic },
		{ id = "label_ui_interface_spacer", group = "ui", category = types.basic },
		{ id = "uiscale", group = "ui", category = types.basic, name = texts.option.interface .. widgetOptionColor .. "  " .. texts.option.uiscale, type = "slider", min = 0.8, max = 1.15, step = 0.01, value = Spring.GetConfigFloat("ui_scale", 1), description = '',
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
		{ id = "guiopacity", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.guiopacity, type = "slider", min = 0.3, max = 1, step = 0.01, value = Spring.GetConfigFloat("ui_opacity", 0.6), description = '',
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigFloat("ui_opacity", value)
		  end,
		},
		{ id = "guitilescale", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.guitilescale, type = "slider", min = 4, max = 40, step = 1, value = Spring.GetConfigFloat("ui_tilescale", 7), description = '',
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
		{ id = "guitileopacity", group = "ui", category = types.dev, name = widgetOptionColor .. "      " .. texts.option.guitileopacity, type = "slider", min = 0, max = 0.03, step = 0.001, value = Spring.GetConfigFloat("ui_tileopacity", 0.011), description = '',
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

		{ id = "guishader", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.guishader, type = "slider", min = 0, max = 0.005, steps = {0, 0.001, 0.0015, 0.002, 0.0025, 0.003, 0.0035, 0.004}, value = guishaderIntensity, description = '',
		  onload = function(i)
			  loadWidgetData("GUI Shader", "guishader", { 'blurIntensity' })
			  if type(options[getOptionByID('guishader')].value) ~= 'number' then
				  options[getOptionByID('guishader')].value = 0
			  end
		  end,
		  onchange = function(i, value)
			  if type(value) == 'number' then
				  guishaderIntensity = value
				  saveOptionValue('GUI Shader', 'guishader', 'setBlurIntensity', { 'blurIntensity' }, value)
			  end
			  if value <= 0.000001 then
				  if GetWidgetToggleValue('GUI Shader') then
				 	 widgetHandler:DisableWidget('GUI Shader')
				  end
			  else
				  if not GetWidgetToggleValue('GUI Shader') then
				  	widgetHandler:EnableWidget('GUI Shader')
				  end
			  end
		  end,
		},

		{ id = "minimap_maxheight", group = "ui", category = types.advanced, name = texts.option.minimap .. widgetOptionColor .. "  " .. texts.option.minimap_maxheight, type = "slider", min = 0.2, max = 0.4, step = 0.01, value = 0.35, description = texts.option.minimap_maxheight_descr,
		  onload = function(i)
			  loadWidgetData("Minimap", "minimap_maxheight", { 'maxHeight' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Minimap', 'minimap', 'setMaxHeight', { 'maxHeight' }, value)
		  end,
		},
		{ id = "minimapleftclick", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.minimapleftclick, type = "bool", value = (WG['minimap'] ~= nil and WG['minimap'].getLeftClickMove ~= nil and WG['minimap'].getLeftClickMove()), description = texts.option.minimapleftclick_descr,
		  onchange = function(i, value)
			  saveOptionValue('Minimap', 'minimap', 'setLeftClickMove', { 'leftClickMove' }, value)
		  end,
		},
		{ id = "minimapiconsize", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.minimapiconsize, type = "slider", min = 2, max = 5, step = 0.25, value = tonumber(Spring.GetConfigFloat("MinimapIconScale", 3.5) or 1), description = '',
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigFloat("MinimapIconScale", value)
			  Spring.SendCommands("minimap unitsize " .. value)        -- spring wont remember what you set with '/minimap iconssize #'
		  end,
		},

		{ id = "buildmenu_bottom", group = "ui", category = types.basic, name = texts.option.buildmenu ..widgetOptionColor.. "  " .. texts.option.buildmenu_bottom, type = "bool", value = (WG['buildmenu'] ~= nil and WG['buildmenu'].getBottomPosition ~= nil and WG['buildmenu'].getBottomPosition()), description = texts.option.buildmenu_bottom_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Build menu', 'buildmenu', 'setBottomPosition', { 'stickToBottom' }, value)
		  end,
		},
		{ id = "gridmenu", group = "ui", category = types.advanced, name = widgetOptionColor.."   " .. texts.option.gridmenu, type = "bool", value = GetWidgetToggleValue("Grid menu"), description = texts.option.gridmenu_descr,
		  onchange = function(i, value)
			  if value then
				  widgetHandler:DisableWidget('Build menu')
				  widgetHandler:EnableWidget('Grid menu')
			  else
				  widgetHandler:DisableWidget('Grid menu')
				  widgetHandler:EnableWidget('Build menu')
			  end
		  end,
		},
		{ id = "buildmenu_maxposy", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.buildmenu_maxposy, type = "slider", min = 0.66, max = 0.88, step = 0.01, value = 0.74, description = texts.option.buildmenu_maxposy_descr,
		  onload = function(i)
			  loadWidgetData("Build menu", "buildmenu_maxposy", { 'maxPosY' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Build menu', 'buildmenu', 'setMaxPosY', { 'maxPosY' }, value)
		  end,
		},
		{ id = "buildmenu_alwaysshow", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.buildmenu_alwaysshow, type = "bool", value = (WG['buildmenu'] ~= nil and WG['buildmenu'].getAlwaysShow ~= nil and WG['buildmenu'].getAlwaysShow()), description = texts.option.buildmenu_alwaysshow_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Build menu', 'buildmenu', 'setAlwaysShow', { 'alwaysShow' }, value)
		  end,
		},
		{ id = "buildmenu_prices", group = "ui", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.buildmenu_prices, type = "bool", value = (WG['buildmenu'] ~= nil and WG['buildmenu'].getShowPrice ~= nil and WG['buildmenu'].getShowPrice()), description = texts.option.buildmenu_prices_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Build menu', 'buildmenu', 'setShowPrice', { 'showPrice' }, value)
		  end,
		},
		{ id = "buildmenu_groupicon", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.buildmenu_groupicon, type = "bool", value = (WG['buildmenu'] ~= nil and WG['buildmenu'].getShowGroupIcon ~= nil and WG['buildmenu'].getShowGroupIcon()), description = texts.option.buildmenu_groupicon_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Build menu', 'buildmenu', 'setShowGroupIcon', { 'showGroupIcon' }, value)
		  end,
		},
		{ id = "buildmenu_radaricon", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.buildmenu_radaricon, type = "bool", value = (WG['buildmenu'] ~= nil and WG['buildmenu'].getShowRadarIcon ~= nil and WG['buildmenu'].getShowRadarIcon()), description = texts.option.buildmenu_radaricon_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Build menu', 'buildmenu', 'setShowRadarIcon', { 'showRadarIcon' }, value)
		  end,
		},

		{ id = "ordermenu_bottompos", group = "ui", category = types.basic, name = texts.option.ordermenu..widgetOptionColor .. "  " .. texts.option.ordermenu_bottompos, type = "bool", value = (WG['ordermenu'] ~= nil and WG['ordermenu'].getBottomPosition ~= nil and WG['ordermenu'].getBottomPosition()), description = texts.option.ordermenu_bottompos_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Order menu', 'ordermenu', 'setBottomPosition', { 'stickToBottom' }, value)
		  end,
		},
		{ id = "ordermenu_colorize", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.ordermenu_colorize, type = "slider", min = 0, max = 1, step = 0.1, value = 0, description = '',
		  onload = function(i)
			  loadWidgetData("Order menu", "ordermenu_colorize", { 'colorize' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Order menu', 'ordermenu', 'setColorize', { 'colorize' }, value)
		  end,
		},
		{ id = "ordermenu_alwaysshow", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.ordermenu_alwaysshow, type = "bool", value = (WG['ordermenu'] ~= nil and WG['ordermenu'].getAlwaysShow ~= nil and WG['ordermenu'].getAlwaysShow()), description = texts.option.ordermenu_alwaysshow_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Order menu', 'ordermenu', 'setAlwaysShow', { 'alwaysShow' }, value)
		  end,
		},
		{ id = "ordermenu_hideset", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.ordermenu_hideset, type = "bool", value = (WG['ordermenu'] ~= nil and WG['ordermenu'].getDisabledCmd ~= nil and WG['ordermenu'].getDisabledCmd('Move')), description = texts.option.ordermenu_hideset_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  local cmds = { 'Move', 'Stop', 'Attack', 'Patrol', 'Fight', 'Wait', 'Guard', 'Reclaim', 'Repair', 'ManualFire' }
			  for k, cmd in pairs(cmds) do
				  saveOptionValue('Order menu', 'ordermenu', 'setDisabledCmd', { 'disabledCmd', cmd }, value, { cmd, value })
			  end
		  end,
		},

		{ id = "info", group = "ui", category = types.advanced, name = texts.option.info .. widgetOptionColor .. "  " .. texts.option.info_buildlist, type = "bool", value = (WG['info'] and WG['info'].getShowBuilderBuildlist ~= nil and WG['info'].getShowBuilderBuildlist()), description = texts.option.info_buildlist_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Info', 'info', 'setShowBuilderBuildlist', { 'showBuilderBuildlist' }, value)
		  end,
		},

		{ id = "advplayerlist_scale", group = "ui", category = types.basic, name = texts.option.advplayerlist .. widgetOptionColor .. "  " .. texts.option.advplayerlist_scale, min = 0.85, max = 1.2, step = 0.01, type = "slider", value = 1, description = texts.option.advplayerlist_scale_descr,
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "advplayerlist_scale", { 'customScale' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetScale', { 'customScale' }, value)
		  end,
		},
		{ id = "advplayerlist_showid", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.advplayerlist_showid, type = "bool", value = false, description = texts.option.advplayerlist_showid_descr,
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "advplayerlist_showid", { 'm_active_Table', 'id' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'id' }, value, { 'id', value })
		  end,
		},
		{ id = "advplayerlist_country", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.advplayerlist_country, type = "bool", value = true, description = texts.option.advplayerlist_country_descr,
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "advplayerlist_country", { 'm_active_Table', 'country' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'country' }, value, { 'country', value })
		  end,
		},
		{ id = "advplayerlist_rank", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.advplayerlist_rank, type = "bool", value = true, description = texts.option.advplayerlist_rank_descr,
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "advplayerlist_rank", { 'm_active_Table', 'rank' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'rank' }, value, { 'rank', value })
		  end,
		},
		{ id = "advplayerlist_side", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.advplayerlist_side, type = "bool", value = true, description = texts.option.advplayerlist_side_descr,
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "advplayerlist_side", { 'm_active_Table', 'side' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'side' }, value, { 'side', value })
		  end,
		},
		{ id = "advplayerlist_skill", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.advplayerlist_skill, type = "bool", value = true, description = texts.option.advplayerlist_skill_descr,
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "advplayerlist_skill", { 'm_active_Table', 'skill' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'skill' }, value, { 'skill', value })
		  end,
		},
		{ id = "advplayerlist_cpuping", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.advplayerlist_cpuping, type = "bool", value = true, description = texts.option.advplayerlist_cpuping_descr,
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "advplayerlist_cpuping", { 'm_active_Table', 'cpuping' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'cpuping' }, value, { 'cpuping', value })
		  end,
		},
		{ id = "advplayerlist_share", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.advplayerlist_share, type = "bool", value = true, description = texts.option.advplayerlist_share_descr,
		  onload = function(i)
			  loadWidgetData("AdvPlayersList", "advplayerlist_share", { 'm_active_Table', 'share' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'share' }, value, { 'share', value })
		  end,
		},
		{ id = "unittotals", group = "ui", category = types.basic, widget = "AdvPlayersList Unit Totals", name = widgetOptionColor .. "   " .. texts.option.unittotals, type = "bool", value = GetWidgetToggleValue("AdvPlayersList Unit Totals"), description = texts.option.unittotals_descr },
		{ id = "mascot", group = "ui", category = types.advanced, widget = "AdvPlayersList Mascot", name = widgetOptionColor .. "   " .. texts.option.mascot, type = "bool", value = GetWidgetToggleValue("AdvPlayersList Mascot"), description = texts.option.mascot_descr },

		{ id = "console_hidespecchat", group = "ui", category = types.basic, name = texts.option.console .. "   " .. widgetOptionColor .. texts.option.console_hidespecchat, type = "bool", value = (Spring.GetConfigInt("HideSpecChat", 0) == 1), description = texts.option.console_hidespecchat_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("HideSpecChat", value and 1 or 0)
		  end,
		},
		{ id = "console_hide", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. widgetOptionColor .. texts.option.console_hide, type = "bool", value = (WG['chat'] ~= nil and WG['chat'].getHide() or false), description = texts.option.console_hide_descr,
		  onload = function(i)
			  loadWidgetData("Chat", "console_hide", { 'hide' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Chat', 'chat', 'setHide', { 'hide' }, value)
		  end,
		},
		{ id = "console_maxlines", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.console_maxlines, type = "slider", min = 3, max = 7, step = 1, value = (WG['chat'] ~= nil and WG['chat'].getMaxLines() or 5), description = '',
		  onload = function(i)
			  loadWidgetData("Chat", "console_maxlines", { 'maxLines' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Chat', 'chat', 'setMaxLines', { 'maxLines' }, value)
		  end,
		},
		{ id = "console_maxconsolelines", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.console_maxconsolelines, type = "slider", min = 2, max = 12, step = 1, value = (WG['chat'] ~= nil and WG['chat'].getMaxConsoleLines() or 2), description = '',
		  onload = function(i)
			  loadWidgetData("Chat", "console_maxconsolelines", { 'maxConsoleLines' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Chat', 'chat', 'setMaxConsoleLines', { 'maxConsoleLines' }, value)
		  end,
		},
		{ id = "console_fontsize", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.console_fontsize, type = "slider", min = 0.92, max = 1.12, step = 0.02, value = (WG['chat'] ~= nil and WG['chat'].getFontsize() or 1), description = '',
		  onload = function(i)
			  loadWidgetData("Chat", "console_fontsize", { 'fontsizeMult' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Chat', 'chat', 'setFontsize', { 'fontsizeMult' }, value)
		  end,
		},
		{ id = "console_backgroundopacity", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.console_backgroundopacity, type = "slider", min = 0, max = 0.35, step = 0.01, value = (WG['chat'] ~= nil and WG['chat'].getBackgroundOpacity() or 0), description = texts.option.console_backgroundopacity_descr,
		  onload = function(i)
			  loadWidgetData("Chat", "console_backgroundopacity", { 'chatBackgroundOpacity' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Chat', 'chat', 'setBackgroundOpacity', { 'chatBackgroundOpacity' }, value)
		  end,
		},
		{ id = "console_handleinput", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.console_handleinput, type = "bool", value = (WG['chat'] ~= nil and WG['chat'].getHandleInput() or 0), description = texts.option.console_handleinput_descr,
		  onload = function(i)
			  loadWidgetData("Chat", "console_handleinput", { 'handleTextInput' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Chat', 'chat', 'setHandleInput', { 'handleTextInput' }, value)
		  end,
		},
		{ id = "console_inputbutton", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.console_inputbutton, type = "bool", value = (WG['chat'] ~= nil and WG['chat'].getInputButton() or 0), description = texts.option.console_inputbutton_descr,
		  onload = function(i)
			  loadWidgetData("Chat", "console_inputbutton", { 'inputButton' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Chat', 'chat', 'setInputButton', { 'inputButton' }, value)
		  end,
		},

		{ id = "unitgroups", group = "ui", category = types.basic, widget = "Unit Groups", name = texts.option.unitgroups, type = "bool", value = GetWidgetToggleValue("Unit Groups"), description = texts.option.unitgroups_descr },
		{ id = "idlebuilders", group = "ui", category = types.basic, widget = "Idle Builders", name = texts.option.idlebuilders, type = "bool", value = GetWidgetToggleValue("Idle Builders"), description = texts.option.idlebuilders_descr },
		{ id = "buildbar", group = "ui", category = types.basic, widget = "BuildBar", name = texts.option.buildbar, type = "bool", value = GetWidgetToggleValue("BuildBar"), description = texts.option.buildbar_descr },


		{ id = "label_ui_visuals", group = "ui", name = texts.option.label_visuals, category = types.basic },
		{ id = "label_ui_visuals_spacer", group = "ui", category = types.basic },

		{ id = "uniticon_scaleui", group = "ui", category = types.basic, name = texts.option.uniticonscaleui, type = "slider", min = 0.85, max = 2, step = 0.05, value = tonumber(Spring.GetConfigFloat("UnitIconScaleUI", 1) or 1), description = texts.option.uniticonscaleui_descr,
		  onchange = function(i, value)
			  Spring.SendCommands("iconscaleui " .. value)
			  Spring.SetConfigFloat("UnitIconScaleUI", value)
		  end,
		},
		{ id = "uniticon_distance", group = "ui", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.uniticondistance, type = "slider", min = 1, max = 12000, step = 50, value = tonumber(Spring.GetConfigInt("UnitIconFadeVanish", 2700) or 1), description = texts.option.uniticondistance_descr,
		  onchange = function(i, value)
			  Spring.SendCommands("iconfadestart " .. value)
			  Spring.SetConfigInt("UnitIconFadeStart", value)
			  -- update UnitIconFadeVanish too
			  Spring.SendCommands("iconfadevanish " .. value)
			  Spring.SetConfigInt("UnitIconFadeVanish", value)
		  end,
		},
		{ id = "uniticon_hidewithui", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.uniticonhidewithui, type = "bool", value = (Spring.GetConfigInt("UnitIconsHideWithUI", 0) == 1), description = texts.option.uniticonhidewithui_descr,
		  onchange = function(i, value)
			  Spring.SendCommands("iconshidewithui " .. (value and 1 or 0))
			  Spring.SetConfigInt("UnitIconsHideWithUI", (value and 1 or 0))
		  end,
		},

		{ id = "featuredrawdist", group = "ui", category = types.advanced, name = texts.option.featuredrawdist, type = "slider", min = 2500, max = 15000, step = 500, value = tonumber(Spring.GetConfigInt("FeatureDrawDistance", 10000)), description = texts.option.featuredrawdist_descr,
		  onchange = function(i, value)
			  Spring.SetConfigInt("FeatureFadeDistance", math.floor(value * 0.8))
			  Spring.SetConfigInt("FeatureDrawDistance", value)
		  end,
		},

		-- { id = "teamcolors", group = "ui", category = types.basic, widget = "Player Color Palette", name = texts.option.teamcolors, type = "bool", value = GetWidgetToggleValue("Player Color Palette"), description = texts.option.teamcolors_descr },
		-- { id = "sameteamcolors", group = "ui", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.sameteamcolors, type = "bool", value = (WG['playercolorpalette'] ~= nil and WG['playercolorpalette'].getSameTeamColors ~= nil and WG['playercolorpalette'].getSameTeamColors()), description = texts.option.sameteamcolors_descr,
		--   onchange = function(i, value)
		-- 	  saveOptionValue('Player Color Palette', 'playercolorpalette', 'setSameTeamColors', { 'useSameTeamColors' }, value)
		--   end,
		-- },


		{ id = "teamplatter", group = "ui", category = types.basic, widget = "TeamPlatter", name = texts.option.teamplatter, type = "bool", value = GetWidgetToggleValue("TeamPlatter"), description = texts.option.teamplatter_descr },
		{ id = "teamplatter_opacity", category = types.advanced, group = "ui", name = widgetOptionColor .. "   " .. texts.option.teamplatter_opacity, min = 0.05, max = 0.4, step = 0.01, type = "slider", value = 0.25, description = texts.option.teamplatter_opacity_descr,
		  onload = function(i)
			  loadWidgetData("TeamPlatter", "teamplatter_opacity", { 'opacity' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('TeamPlatter', 'teamplatter', 'setOpacity', { 'opacity' }, value)
		  end,
		},
		{ id = "teamplatter_skipownteam", category = types.advanced, group = "ui", name = widgetOptionColor .. "   " .. texts.option.teamplatter_skipownteam, type = "bool", value = false, description = texts.option.teamplatter_skipownteam_descr,
		  onload = function(i)
			  loadWidgetData("TeamPlatter", "teamplatter_skipownteam", { 'skipOwnTeam' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('TeamPlatter', 'teamplatter', 'setSkipOwnTeam', { 'skipOwnTeam' }, value)
		  end,
		},

		{ id = "enemyspotter", group = "ui", category = types.basic, widget = "EnemySpotter", name = texts.option.enemyspotter, type = "bool", value = GetWidgetToggleValue("EnemySpotter"), description = texts.option.enemyspotter_descr },
		{ id = "enemyspotter_opacity", category = types.advanced, group = "ui", name = widgetOptionColor .. "   " .. texts.option.enemyspotter_opacity, min = 0.12, max = 0.4, step = 0.01, type = "slider", value = 0.15, description = texts.option.enemyspotter_opacity_descr,
		  onload = function(i)
			  loadWidgetData("EnemySpotter", "enemyspotter_opacity", { 'opacity' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('EnemySpotter', 'enemyspotter', 'setOpacity', { 'opacity' }, value)
		  end,
		},

		--{ id = "selectedunits", group = "ui", category = types.basic, widget = "Selected Units GL4", name = "Selection", type = "bool", value = GetWidgetToggleValue("Selected Units GL4"), description = texts.option.selectedunits_descr },
		{ id = "selectedunits_opacity", group = "ui", category = types.advanced, name = texts.option.selectedunits..widgetOptionColor .. "  " .. texts.option.selectedunits_opacity, min = 0, max = 0.5, step = 0.01, type = "slider", value = 0.19, description = texts.option.selectedunits_opacity_descr,
		  onload = function(i)
			  loadWidgetData("Selected Units GL4", "selectedunits_opacity", { 'opacity' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Selected Units GL4', 'selectedunits', 'setOpacity', { 'opacity' }, value)
		  end,
		},
		{ id = "selectedunits_teamcoloropacity", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.selectedunits_teamcoloropacity, min = 0, max = 1, step = 0.01, type = "slider", value = 0.6, description = texts.option.selectedunits_teamcoloropacity_descr,
		  onload = function(i)
			  loadWidgetData("Selected Units GL4", "selectedunits_teamcoloropacity", { 'teamcolorOpacity' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Selected Units GL4', 'selectedunits', 'setTeamcolorOpacity', { 'teamcolorOpacity' }, value)
		  end,
		},

		{ id = "highlightselunits", group = "ui", category = types.basic, widget = "Highlight Selected Units GL4", name = texts.option.highlightselunits, type = "bool", value = GetWidgetToggleValue("Highlight Selected Units GL4"), description = texts.option.highlightselunits_descr },
		{ id = "highlightselunits_opacity", group = "ui", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.highlightselunits_opacity, min = 0.02, max = 0.2, step = 0.01, type = "slider", value = 0.05, description = texts.option.highlightselunits_opacity_descr,
		  onload = function(i)
			  loadWidgetData("Highlight Selected Units GL4", "highlightselunits_opacity", { 'highlightAlpha' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Highlight Selected Units GL4', 'highlightselunits', 'setOpacity', { 'highlightAlpha' }, value)
		  end,
		},
		{ id = "highlightselunits_teamcolor", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.highlightselunits_teamcolor, type = "bool", value = false, description = texts.option.highlightselunits_teamcolor_descr,
		  onload = function(i)
			  loadWidgetData("Highlight Selected Units GL4", "highlightselunits_teamcolor", { 'useTeamcolor' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Highlight Selected Units GL4', 'highlightselunits', 'setTeamcolor', { 'useTeamcolor' }, value)
		  end,
		},

		{ id = "cursorlight", group = "ui", category = types.advanced, widget = "Cursor Light", name = texts.option.cursorlight, type = "bool", value = GetWidgetToggleValue("Cursor Light"), description = texts.option.cursorlight_descr },
		{ id = "cursorlight_lightradius", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.cursorlight_lightradius, type = "slider", min = 0.15, max = 1, step = 0.05, value = 1.5, description = '',
		  onload = function(i)
			  loadWidgetData("Cursor Light", "cursorlight_lightradius", { 'lightRadiusMult' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Cursor Light', 'cursorlight', 'setLightRadius', { 'lightRadiusMult' }, value)
		  end,
		},
		{ id = "cursorlight_lightstrength", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.cursorlight_lightstrength, type = "slider", min = 0.1, max = 1.2, step = 0.05, value = 0.2, description = '',
		  onload = function(i)
			  loadWidgetData("Cursor Light", "cursorlight_lightstrength", { 'lightStrengthMult' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Cursor Light', 'cursorlight', 'setLightStrength', { 'lightStrengthMult' }, value)
		  end,
		},


		{ id = "label_ui_info", group = "ui", name = texts.option.label_info, category = types.basic },
		{ id = "label_ui_info_spacer", group = "ui", category = types.basic },

		{ id = "metalspots_values", group = "ui", category = types.advanced, name = texts.option.metalspots..widgetOptionColor .. "   " .. texts.option.metalspots_values, type = "bool", value = (WG['metalspots'] ~= nil and WG['metalspots'].getShowValue()), description = texts.option.metalspots_values_descr,
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
		{ id = "metalspots_metalviewonly", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.metalspots_metalviewonly, type = "bool", value = false, description = texts.option.metalspots_metalviewonly_descr,
		  onload = function(i)
			  loadWidgetData("Metalspots", "metalspots_metalviewonly", { 'metalViewOnly' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Metalspots', 'metalspots', 'setMetalViewOnly', { 'showValue' }, options[getOptionByID('metalspots_metalviewonly')].value)
		  end,
		},

		{ id = "geospots", group = "ui", category = types.dev, widget = "Geothermalspots", name = texts.option.geospots, type = "bool", value = GetWidgetToggleValue("Metalspots"), description = texts.option.geospots_descr },

    { id = "healthbarsscale", group = "ui", category = types.advanced, name = texts.option.healthbars .. widgetOptionColor .. "  " .. texts.option.healthbarsscale, type = "slider", min = 0.6, max = 2.0, step = 0.1, value = 1, description = '',
		  onload = function(i)
			  loadWidgetData("Health Bars GL4", "healthbarsscale", { 'barScale' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Health Bars GL4', 'healthbars', 'setScale', { 'barScale' }, value)
		  end,
		},
		{ id = "healthbarsvariable", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.healthbarsvariable, type = "bool", value = (WG['healthbar'] ~= nil and WG['healthbar'].getVariableSizes()), description = texts.option.healthbarsvariable_descr,
		  onload = function(i)
			  loadWidgetData("Health Bars GL4", "healthbarsvariable", { "variableBarSizes" })
		  end,
		  onchange = function(i, value)
			  saveOptionValue("Health Bars GL4", "healthbars", "setVariableSizes", { "variableBarSizes" }, value)
		  end,
		},
		{ id = "rankicons", group = "ui", category = types.advanced, widget = "Rank Icons GL4", name = texts.option.rankicons, type = "bool", value = GetWidgetToggleValue("Rank Icons GL4"), description = texts.option.rankicons_descr },
		{ id = "rankicons_distance", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.rankicons_distance, type = "slider", min = 0.4, max = 2, step = 0.1, value = (WG['rankicons'] ~= nil and WG['rankicons'].getDrawDistance ~= nil and WG['rankicons'].getDrawDistance()), description = '',
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Rank Icons', 'rankicons', 'setDrawDistance', { 'distanceMult' }, value)
		  end,
		},
		{ id = "rankicons_scale", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.rankicons_scale, type = "slider", min = 0.3, max = 3, step = 0.1, value = (WG['rankicons'] ~= nil and WG['rankicons'].getScale ~= nil and WG['rankicons'].getScale()), description = '',
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Rank Icons', 'rankicons', 'setScale', { 'iconsizeMult' }, value)
		  end,
		},

		{ id = "allycursors", group = "ui", category = types.basic, widget = "AllyCursors", name = texts.option.allycursors, type = "bool", value = GetWidgetToggleValue("AllyCursors"), description = texts.option.allycursors_descr },
		{ id = "allycursors_playername", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.allycursors_playername, type = "bool", value = true, description = texts.option.allycursors_playername_descr,
		  onload = function(i)
			  loadWidgetData("AllyCursors", "allycursors_playername", { 'showPlayerName' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AllyCursors', 'allycursors', 'setPlayerNames', { 'showPlayerName' }, value)
		  end,
		},
		{ id = "allycursors_showdot", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.allycursors_showdot, type = "bool", value = true, description = texts.option.allycursors_showdot_descr,
		  onload = function(i)
			  loadWidgetData("AllyCursors", "allycursors_showdot", { 'showCursorDot' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AllyCursors', 'allycursors', 'setCursorDot', { 'showCursorDot' }, value)
		  end,
		},
		{ id = "allycursors_spectatorname", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.allycursors_spectatorname, type = "bool", value = true, description = texts.option.allycursors_spectatorname_descr,
		  onload = function(i)
			  loadWidgetData("AllyCursors", "allycursors_spectatorname", { 'showSpectatorName' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AllyCursors', 'allycursors', 'setSpectatorNames', { 'showSpectatorName' }, value)
		  end,
		},
		{ id = "allycursors_lights", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.allycursors_lights, type = "bool", value = true, description = texts.option.allycursors_lights_descr,
		  onload = function(i)
			  loadWidgetData("AllyCursors", "allycursors_lights", { 'addLights' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AllyCursors', 'allycursors', 'setLights', { 'addLights' }, options[getOptionByID('allycursors_lights')].value)
		  end,
		},
		{ id = "allycursors_lightradius", group = "ui", category = types.dev, name = widgetOptionColor .. "      " .. texts.option.allycursors_lightradius, type = "slider", min = 0.15, max = 1, step = 0.05, value = 0.5, description = '',
		  onload = function(i)
			  loadWidgetData("AllyCursors", "allycursors_lightradius", { 'lightRadiusMult' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AllyCursors', 'allycursors', 'setLightRadius', { 'lightRadiusMult' }, value)
		  end,
		},
		{ id = "allycursors_lightstrength", group = "ui", category = types.dev , name = widgetOptionColor .. "      " .. texts.option.allycursors_lightstrength, type = "slider", min = 0.1, max = 1.2, step = 0.05, value = 0.85, description = '',
		  onload = function(i)
			  loadWidgetData("AllyCursors", "allycursors_lightstrength", { 'lightStrengthMult' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('AllyCursors', 'allycursors', 'setLightStrength', { 'lightStrengthMult' }, value)
		  end,
		},

		{ id = "showbuilderqueue", group = "ui", category = types.advanced, widget = "Show Builder Queue", name = texts.option.showbuilderqueue, type = "bool", value = GetWidgetToggleValue("Show Builder Queue"), description = texts.option.showbuilderqueue_descr },

		{ id = "unitenergyicons", group = "ui", category = types.advanced, widget = "Unit Energy Icons", name = texts.option.unitenergyicons, type = "bool", value = GetWidgetToggleValue("Unit Energy Icons"), description = texts.option.unitenergyicons_descr },

		{ id = "commandsfx", group = "ui", category = types.basic, widget = "Commands FX", name = texts.option.commandsfx, type = "bool", value = GetWidgetToggleValue("Commands FX"), description = texts.option.commandsfx_descr },

		{ id = "commandsfxopacity", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.commandsfxopacity, type = "slider", min = 0.25, max = 1, step = 0.1, value = 1, description = '',
		  onload = function(i)
			  loadWidgetData("Commands FX", "commandsfxopacity", { 'opacity' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Commands FX', 'commandsfx', 'setOpacity', { 'opacity' }, value)
		  end,
		},
		{ id = "commandsfxfilterai", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.commandsfxfilterai, type = "bool", value = true, description = texts.option.commandsfxfilterai_descr,
		  onload = function(i)
			  loadWidgetData("Commands FX", "commandsfxfilterai", { 'filterAIteams' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Commands FX', 'commandsfx', 'setFilterAI', { 'filterAIteams' }, value)
		  end,
		},


		{ id = "flankingicons", group = "ui", category = types.advanced, widget = "Flanking Icons GL4", name = texts.option.flankingicons, type = "bool", value = GetWidgetToggleValue("Flanking Icons GL4"), description = texts.option.flankingicons_descr },

		{ id = "displaydps", group = "ui", category = types.basic, name = texts.option.displaydps, type = "bool", value = tonumber(Spring.GetConfigInt("DisplayDPS", 0) or 0) == 1, description = texts.option.displaydps_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("DisplayDPS", (value and 1 or 0))
		  end,
		},
		{ id = "givenunits", group = "ui", category = types.advanced, widget = "Given Units", name = texts.option.givenunits, type = "bool", value = GetWidgetToggleValue("Given Units"), description = texts.option.giveunits_descr },


		{ id = "label_ui_ranges", group = "ui", name = texts.option.label_ranges, category = types.basic },
		{ id = "label_ui_ranges_spacer", group = "ui", category = types.basic },


		-- Radar range rings:
		{ id = "radarrange", group = "ui", category = types.advanced, widget = "Sensor Ranges Radar", name = texts.option.radarrange, type = "bool", value = GetWidgetToggleValue("Sensor Ranges Radar"), description = texts.option.radarrange_descr },

		{ id = "radarrangeopacity", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.radarrangeopacity, type = "slider", min = 0.01, max = 0.33, step = 0.01, value = (WG['radarrange'] ~= nil and WG['radarrange'].getOpacity ~= nil and WG['radarrange'].getOpacity()) or 0.08, description = '',
		  onload = function(i)
			  loadWidgetData("Sensor Ranges Radar", "radarrangeopacity", { 'opacity' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Sensor Ranges Radar', 'radarrange', 'setOpacity', { 'opacity' }, value)
		  end,
		},
		-- Sonar range
		{ id = "sonarrange", group = "ui", category = types.advanced, widget = "Sensor Ranges Sonar", name = texts.option.sonarrange, type = "bool", value = GetWidgetToggleValue("Sensor Ranges Sonar"), description = texts.option.sonarrange_descr },

		{ id = "sonarrangeopacity", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.sonarrangeopacity, type = "slider", min = 0.01, max = 0.33, step = 0.01, value = (WG['sonarrange'] ~= nil and WG['sonarrange'].getOpacity ~= nil and WG['sonarrange'].getOpacity()) or 0.08, description = '',
		  onload = function(i)
			  loadWidgetData("Sensor Ranges Sonar", "sonarrangeopacity", { 'opacity' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Sensor Ranges Sonar', 'sonarrange', 'setOpacity', { 'opacity' }, value)
		  end,
		},
		-- Jammer range
		{ id = "jammerrange", group = "ui", category = types.advanced, widget = "Sensor Ranges Jammer", name = texts.option.jammerrange, type = "bool", value = GetWidgetToggleValue("Sensor Ranges Jammer"), description = texts.option.jammerrange_descr },

		{ id = "jammerrangeopacity", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.jammerrangeopacity, type = "slider", min = 0.01, max = 0.66, step = 0.01, value = (WG['jammerrange'] ~= nil and WG['jammerrange'].getOpacity ~= nil and WG['jammerrange'].getOpacity()) or 0.08, description = '',
		  onload = function(i)
			  loadWidgetData("Sensor Ranges Jammer", "jammerrangeopacity", { 'opacity' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Sensor Ranges Jammer', 'jammerrange', 'setOpacity', { 'opacity' }, value)
		  end,
		},
		-- LOS Range:
		{ id = "losrange", group = "ui", category = types.advanced, widget = "Sensor Ranges LOS", name = texts.option.losrange, type = "bool", value = GetWidgetToggleValue("Sensor Ranges LOS"), description = texts.option.losrange_descr },

		{ id = "losrangeopacity", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.losrangeopacity, type = "slider", min = 0.01, max = 0.33, step = 0.01, value = (WG['losrange'] ~= nil and WG['losrange'].getOpacity ~= nil and WG['losrange'].getOpacity()) or 0.08, description = '',
		  onload = function(i)
			  loadWidgetData("Sensor Ranges LOS", "losrangeopacity", { 'opacity' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Sensor Ranges LOS', 'losrange', 'setOpacity', { 'opacity' }, value)
		  end,
		},
		{ id = "losrangeteamcolors", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.losrangeteamcolors, type = "bool", value = (WG['losrange'] ~= nil and WG['losrange'].getUseTeamColors ~= nil and WG['losrange'].getUseTeamColors()), description = '',
		  onload = function(i)
			  loadWidgetData("Sensor Ranges LOS", "losrangeteamcolors", { 'useteamcolors' })
		  end,
		  onchange = function(i, value)
			  saveOptionValue('Sensor Ranges LOS', 'losrange', 'setUseTeamColors', { 'useteamcolors' }, value)
		  end,
		},

		{ id = "defrange", group = "ui", category = types.basic, widget = "Defense Range", name = texts.option.defrange, type = "bool", value = GetWidgetToggleValue("Defense Range"), description = texts.option.defrange_descr },
		{ id = "defrange_allyair", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.defrange_allyair, type = "bool", value = (WG['defrange'] ~= nil and WG['defrange'].getAllyAir ~= nil and WG['defrange'].getAllyAir()), description = texts.option.defrange_allyair_descr,
		  onload = function(i)
			  loadWidgetData("Defense Range", "defrange_allyair", { 'enabled', 'ally', 'air' })
		  end,
		  onchange = function(i, value)
			  if widgetHandler.configData["Defense Range"] == nil then
				  widgetHandler.configData["Defense Range"] = {}
			  end
			  if widgetHandler.configData["Defense Range"].enabled == nil then
				  widgetHandler.configData["Defense Range"].enabled = { ally = { air = false, ground = false, nuke = false }, enemy = { air = true, ground = true, nuke = true } }
			  end
			  saveOptionValue('Defense Range', 'defrange', 'setAllyAir', { 'enabled', 'ally', 'air' }, value)
		  end,
		},
		{ id = "defrange_allyground", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.defrange_allyground, type = "bool", value = (WG['defrange'] ~= nil and WG['defrange'].getAllyGround ~= nil and WG['defrange'].getAllyGround()), description = texts.option.defrange_allyground_descr,
		  onload = function(i)
			  loadWidgetData("Defense Range", "defrange_allyground", { 'enabled', 'ally', 'ground' })
		  end,
		  onchange = function(i, value)
			  if widgetHandler.configData["Defense Range"] == nil then
				  widgetHandler.configData["Defense Range"] = {}
			  end
			  if widgetHandler.configData["Defense Range"].enabled == nil then
				  widgetHandler.configData["Defense Range"].enabled = { ally = { air = false, ground = false, nuke = false }, enemy = { air = true, ground = true, nuke = true } }
			  end
			  saveOptionValue('Defense Range', 'defrange', 'setAllyGround', { 'enabled', 'ally', 'ground' }, value)
		  end,
		},
		{ id = "defrange_allynuke", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.defrange_allynuke, type = "bool", value = (WG['defrange'] ~= nil and WG['defrange'].getAllyNuke ~= nil and WG['defrange'].getAllyNuke()), description = texts.option.defrange_allynuke_descr,
		  onload = function(i)
			  loadWidgetData("Defense Range", "defrange_allynuke", { 'enabled', 'ally', 'nuke' })
		  end,
		  onchange = function(i, value)
			  if widgetHandler.configData["Defense Range"] == nil then
				  widgetHandler.configData["Defense Range"] = {}
			  end
			  if widgetHandler.configData["Defense Range"].enabled == nil then
				  widgetHandler.configData["Defense Range"].enabled = { ally = { air = false, ground = false, nuke = false }, enemy = { air = true, ground = true, nuke = true } }
			  end
			  saveOptionValue('Defense Range', 'defrange', 'setAllyNuke', { 'enabled', 'ally', 'nuke' }, value)
		  end,
		},
		{ id = "defrange_enemyair", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.defrange_enemyair, type = "bool", value = (WG['defrange'] ~= nil and WG['defrange'].getEnemyAir ~= nil and WG['defrange'].getEnemyAir()), description = texts.option.defrange_enemyair_descr,
		  onload = function(i)
			  loadWidgetData("Defense Range", "defrange_enemyair", { 'enabled', 'enemy', 'air' })
		  end,
		  onchange = function(i, value)
			  if widgetHandler.configData["Defense Range"] == nil then
				  widgetHandler.configData["Defense Range"] = {}
			  end
			  if widgetHandler.configData["Defense Range"].enabled == nil then
				  widgetHandler.configData["Defense Range"].enabled = { ally = { air = false, ground = false, nuke = false }, enemy = { air = true, ground = true, nuke = true } }
			  end
			  saveOptionValue('Defense Range', 'defrange', 'setEnemyAir', { 'enabled', 'enemy', 'air' }, value)
		  end,
		},
		{ id = "defrange_enemyground", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.defrange_enemyground, type = "bool", value = (WG['defrange'] ~= nil and WG['defrange'].getEnemyGround ~= nil and WG['defrange'].getEnemyGround()), description = texts.option.defrange_enemyground_descr,
		  onload = function(i)
			  loadWidgetData("Defense Range", "defrange_enemyground", { 'enabled', 'enemy', 'ground' })
		  end,
		  onchange = function(i, value)
			  if widgetHandler.configData["Defense Range"] == nil then
				  widgetHandler.configData["Defense Range"] = {}
			  end
			  if widgetHandler.configData["Defense Range"].enabled == nil then
				  widgetHandler.configData["Defense Range"].enabled = { ally = { air = false, ground = false, nuke = false }, enemy = { air = true, ground = true, nuke = true } }
			  end
			  saveOptionValue('Defense Range', 'defrange', 'setEnemyGround', { 'enabled', 'enemy', 'ground' }, value)
		  end,
		},
		{ id = "defrange_enemynuke", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. texts.option.defrange_enemynuke, type = "bool", value = (WG['defrange'] ~= nil and WG['defrange'].getEnemyNuke ~= nil and WG['defrange'].getEnemyNuke()), description = texts.option.defrange_enemynuke_descr,
		  onload = function(i)
			  loadWidgetData("Defense Range", "defrange_enemynuke", { 'enabled', 'enemy', 'nuke' })
		  end,
		  onchange = function(i, value)
			  if widgetHandler.configData["Defense Range"] == nil then
				  widgetHandler.configData["Defense Range"] = {}
			  end
			  if widgetHandler.configData["Defense Range"].enabled == nil then
				  widgetHandler.configData["Defense Range"].enabled = { ally = { air = false, ground = false, nuke = false }, enemy = { air = true, ground = true, nuke = true } }
			  end
			  saveOptionValue('Defense Range', 'defrange', 'setEnemyNuke', { 'enabled', 'enemy', 'nuke' }, value)
		  end,
		},

		{ id = "antiranges", group = "ui", category = types.advanced, widget = "Anti Ranges", name = texts.option.antiranges, type = "bool", value = GetWidgetToggleValue("Anti Ranges"), description = texts.option.antiranges_descr },

		-- GAME
		{ id = "networksmoothing", restart = true, category = types.basic, group = "game", name = texts.option.networksmoothing, type = "bool", value = useNetworkSmoothing, description = texts.option.networksmoothing_descr,
		  onload = function(i)
			  options[i].onchange(i, options[i].value)
		  end,
		  onchange = function(i, value)
			  useNetworkSmoothing = value
			  if useNetworkSmoothing then
				  Spring.SetConfigInt("UseNetMessageSmoothingBuffer", 1)
				  Spring.SetConfigInt("NetworkLossFactor", 0)
				  Spring.SetConfigInt("LinkOutgoingBandwidth", 98304)
				  Spring.SetConfigInt("LinkIncomingSustainedBandwidth", 98304)
				  Spring.SetConfigInt("LinkIncomingPeakBandwidth", 98304)
				  Spring.SetConfigInt("LinkIncomingMaxPacketRate", 128)
			  else
				  Spring.SetConfigInt("UseNetMessageSmoothingBuffer", 1)
				  Spring.SetConfigInt("NetworkLossFactor", 2)
				  Spring.SetConfigInt("LinkOutgoingBandwidth", 196608)
				  Spring.SetConfigInt("LinkIncomingSustainedBandwidth", 196608)
				  Spring.SetConfigInt("LinkIncomingPeakBandwidth", 196608)
				  Spring.SetConfigInt("LinkIncomingMaxPacketRate", 1024)
			  end
		  end,
		},
		{ id = "autoquit", group = "game", category = types.basic, widget = "Autoquit", name = texts.option.autoquit, type = "bool", value = GetWidgetToggleValue("Autoquit"), description = texts.option.autoquit_descr },

		{ id = "singleplayerpause", group = "game", category = types.advanced, name = texts.option.singleplayerpause, type = "bool", value = pauseGameWhenSingleplayer, description = texts.option.singleplayerpause_descr,
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

		{ id = "label_ui_behavior", group = "game", name = texts.option.label_behavior, category = types.basic },
		{ id = "label_ui_behavior_spacer", group = "game", category = types.basic },


		{ id = "smartselect_includebuildings", group = "game", category = types.basic, name = texts.option.smartselect_includebuildings, type = "bool", value = false, description = texts.option.smartselect_includebuildings_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('SmartSelect', 'smartselect', 'setIncludeBuildings', { 'selectBuildingsWithMobile' }, value)
		  end,
		},
		{ id = "smartselect_includebuilders", group = "game", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.smartselect_includebuilders, type = "bool", value = false, description = texts.option.smartselect_includebuilders_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  saveOptionValue('SmartSelect', 'smartselect', 'setIncludeBuilders', { 'includeBuilders' }, value)
		  end,
		},

		{
			id = "builderpriority",
			group = "game",
			category = types.basic,
			widget = "Builder Priority",
			name = texts.option.builderpriority,
			type = "bool",
			value = GetWidgetToggleValue("Builder Priority"),
			description = texts.option.builderpriority_descr,
		},

		{
			id = "builderpriority_nanos",
			group = "game",
			category = types.advanced,
			name = widgetOptionColor .. "   " .. texts.option.builderpriority_nanos,
			type = "bool",
			value = (
					WG['builderpriority'] ~= nil
							and WG['builderpriority'].getLowPriorityNanos ~= nil
							and WG['builderpriority'].getLowPriorityNanos()
			),
			description = texts.option.builderpriority_nanos_descr,
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
			name = widgetOptionColor .. "   " .. texts.option.builderpriority_cons,
			type = "bool",
			value = (
					WG['builderpriority'] ~= nil
							and WG['builderpriority'].getLowPriorityCons ~= nil
							and WG['builderpriority'].getLowPriorityCons()
			),
			description = texts.option.builderpriority_cons_descr,
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
			name = widgetOptionColor .. "   " .. texts.option.builderpriority_labs,
			type = "bool",
			value = (
					WG['builderpriority'] ~= nil
							and WG['builderpriority'].getLowPriorityLabs ~= nil
							and WG['builderpriority'].getLowPriorityLabs()
			),
			description = texts.option.builderpriority_labs_descr,
			onload = function(i)
				loadWidgetData("Builder Priority", "builderpriority_labs", { 'lowpriorityLabs' })
			end,
			onchange = function(i, value)
				saveOptionValue('Builder Priority', 'builderpriority', 'setLowPriorityLabs', { 'lowpriorityLabs' }, value)
			end,
		},

		{ id = "factoryguard", group = "game", category = types.basic, widget = "FactoryGuard", name = texts.option.factory .. widgetOptionColor .. "  " .. texts.option.factoryguard, type = "bool", value = GetWidgetToggleValue("FactoryGuard"), description = texts.option.factoryguard_descr },
		{ id = "factoryholdpos", group = "game", category = types.basic, widget = "Factory hold position", name = widgetOptionColor .. "   " .. texts.option.factoryholdpos, type = "bool", value = GetWidgetToggleValue("Factory hold position"), description = texts.option.factoryholdpos_descr },
		{ id = "factoryrepeat", group = "game", category = types.basic, widget = "Factory Auto-Repeat", name = widgetOptionColor .. "   " .. texts.option.factoryrepeat, type = "bool", value = GetWidgetToggleValue("Factory Auto-Repeat"), description = texts.option.factoryrepeat_descr },


		{ id = "transportai", group = "game", category = types.basic, widget = "Transport AI", name = texts.option.transportai, type = "bool", value = GetWidgetToggleValue("Transport AI"), description = texts.option.transportai_descr },

		{ id = "onlyfighterspatrol", group = "game", category = types.basic, widget = "OnlyFightersPatrol", name = texts.option.onlyfighterspatrol, type = "bool", value = GetWidgetToggleValue("Autoquit"), description = texts.option.onlyfighterspatrol_descr },
		{ id = "fightersfly", group = "game", category = types.basic, widget = "Set fighters on Fly mode", name = texts.option.fightersfly, type = "bool", value = GetWidgetToggleValue("Set fighters on Fly mode"), description = texts.option.fightersfly_descr },

		{ id = "settargetdefault", group = "game", category = types.basic, widget = "Set target default", name = texts.option.settargetdefault, type = "bool", value = GetWidgetToggleValue("Set target default"), description = texts.option.settargetdefault_descr },
		{ id = "dgunnogroundenemies", group = "game", category = types.advanced, widget = "DGun no ground enemies", name = texts.option.dgunnogroundenemies, type = "bool", value = GetWidgetToggleValue("DGun no ground enemies"), description = texts.option.dgunnogroundenemies_descr },
		{ id = "dgunstallassist", group = "game", category = types.advanced, widget = "DGun Stall Assist", name = texts.option.dgunstallassist, type = "bool", value = GetWidgetToggleValue("DGun Stall Assist"), description = texts.option.dgunstallassist_descr },

		{ id = "autocloakpopups", group = "game", category = types.basic, widget = "Auto Cloak Popups", name = texts.option.autocloakpopups, type = "bool", value = GetWidgetToggleValue("Auto Cloak Popups"), description = texts.option.autocloakpopups_descr },

		{ id = "unitreclaimer", group = "game", category = types.basic, widget = "Specific Unit Reclaimer", name = texts.option.unitreclaimer, type = "bool", value = GetWidgetToggleValue("Specific Unit Reclaimer"), description = texts.option.unitreclaimer_descr },

		{ id = "autogroup_immediate", group = "game", category = types.basic, name = texts.option.autogroup_immediate, type = "bool", value = (WG['autogroup'] ~= nil and WG['autogroup'].getImmediate ~= nil and WG['autogroup'].getImmediate()), description = texts.option.autogroup_immediate_descr,
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

		{ id = "autogroup_persist", group = "game", category = types.basic, name = texts.option.autogroup_persist, type = "bool", value = (WG['autogroup'] ~= nil and WG['autogroup'].getPersist ~= nil and WG['autogroup'].getPersist()), description = texts.option.autogroup_persist_descr,
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

		-- ACCESSIBILITY

		{ id = "label_teamcolors", group = "accessibility", name = texts.option.label_teamcolors, category = types.basic },
		{ id = "label_teamcolors_spacer", group = "accessibility", category = types.basic },

		{ id = "simpleteamcolors", group = "accessibility", category = types.basic, name = texts.option.playercolors, type = "bool", value = tonumber(Spring.GetConfigInt("SimpleTeamColors", 0) or 0) == 1, description = texts.option.simpleteamcolors_descr,
		  onchange = function(i, value)
			  Spring.SetConfigInt("SimpleTeamColors", (value and 1 or 0))
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},

		{ id = "simpleteamcolors_reset", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " ..  texts.option.simpleteamcolors_reset, type = "bool", value = tonumber(Spring.GetConfigInt("SimpleTeamColors_Reset", 0) or 0) == 1,
		  onchange = function(i, value)
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

		{ id = "simpleteamcolors_player_r", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.simpleteamcolors_player_r, type = "slider", min = 0, max = 255, step = 1, value = tonumber(Spring.GetConfigInt("SimpleTeamColorsPlayerR", 0)),
		  onchange = function(i, value)
			  Spring.SetConfigInt("SimpleTeamColorsPlayerR", value)
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},
		{ id = "simpleteamcolors_player_g", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.simpleteamcolors_player_g, type = "slider", min = 0, max = 255, step = 1, value = tonumber(Spring.GetConfigInt("SimpleTeamColorsPlayerG", 77)),
		  onchange = function(i, value)
			  Spring.SetConfigInt("SimpleTeamColorsPlayerG", value)
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},
		{ id = "simpleteamcolors_player_b", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.simpleteamcolors_player_b, type = "slider", min = 0, max = 255, step = 1, value = tonumber(Spring.GetConfigInt("SimpleTeamColorsPlayerB", 255)),
		  onchange = function(i, value)
			  Spring.SetConfigInt("SimpleTeamColorsPlayerB", value)
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},

		{ id = "simpleteamcolors_ally_r", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.simpleteamcolors_ally_r, type = "slider", min = 0, max = 255, step = 1, value = tonumber(Spring.GetConfigInt("SimpleTeamColorsAllyR", 0)),
		  onchange = function(i, value)
			  Spring.SetConfigInt("SimpleTeamColorsAllyR", value)
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},
		{ id = "simpleteamcolors_ally_g", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.simpleteamcolors_ally_g, type = "slider", min = 0, max = 255, step = 1, value = tonumber(Spring.GetConfigInt("SimpleTeamColorsAllyG", 255)),
		  onchange = function(i, value)
			  Spring.SetConfigInt("SimpleTeamColorsAllyG", value)
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},
		{ id = "simpleteamcolors_ally_b", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.simpleteamcolors_ally_b, type = "slider", min = 0, max = 255, step = 1, value = tonumber(Spring.GetConfigInt("SimpleTeamColorsAllyB", 0)),
		  onchange = function(i, value)
			  Spring.SetConfigInt("SimpleTeamColorsAllyB", value)
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},

		{ id = "simpleteamcolors_enemy_r", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.simpleteamcolors_enemy_r, type = "slider", min = 0, max = 255, step = 1, value = tonumber(Spring.GetConfigInt("SimpleTeamColorsEnemyR", 255)),
		  onchange = function(i, value)
			  Spring.SetConfigInt("SimpleTeamColorsEnemyR", value)
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},
		{ id = "simpleteamcolors_enemy_g", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.simpleteamcolors_enemy_g, type = "slider", min = 0, max = 255, step = 1, value = tonumber(Spring.GetConfigInt("SimpleTeamColorsEnemyG", 16)),
		  onchange = function(i, value)
			  Spring.SetConfigInt("SimpleTeamColorsEnemyG", value)
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},
		{ id = "simpleteamcolors_enemy_b", group = "accessibility", category = types.basic, name = widgetOptionColor .. "   " .. texts.option.simpleteamcolors_enemy_b, type = "slider", min = 0, max = 255, step = 1, value = tonumber(Spring.GetConfigInt("SimpleTeamColorsEnemyB", 5)),
		  onchange = function(i, value)
			  Spring.SetConfigInt("SimpleTeamColorsEnemyB", value)
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},

		-- DEV
		{ id = "usePlayerUI", group = "dev", category = types.dev, name = "View UI as player", type = "bool", value = not Spring.Utilities.ShowDevUI(),
			onchange = function(i, value)
				Spring.SetConfigInt("DevUI", value and 0 or 1)
				Spring.SendCommands("luaui reload")
			end,
		},
		{ id = "customwidgets", group = "dev", category = types.dev, name = texts.option.customwidgets, type = "bool", value = widgetHandler.allowUserWidgets, description = texts.option.customwidgets_descr,
		  onchange = function(i, value)
			  widgetHandler.__allowUserWidgets = value
			  Spring.SendCommands("luarules reloadluaui")
		  end,
		},

		{ id = "autocheat", group = "dev", category = types.dev, widget = "Auto cheat", name = texts.option.autocheat, type = "bool", value = GetWidgetToggleValue("Auto cheat"), description = texts.option.autocheat_descr },
		{ id = "restart", group = "dev", category = types.dev, name = texts.option.restart, type = "bool", value = false, description = texts.option.restart_descr,
		  onchange = function(i, value)
			  options[getOptionByID('restart')].value = false
			  Spring.Restart("", startScript)
		  end,
		},

		{ id = "label_dev_debug", group = "dev", name = texts.option.label_debug, category = types.dev },
		{ id = "label_dev_debug_spacer", group = "dev", category = types.dev },

		{ id = "profiler", group = "dev", category = types.dev, widget = "Widget Profiler", name = texts.option.profiler, type = "bool", value = GetWidgetToggleValue("Widget Profiler"), description = "" },
		{ id = "framegrapher", group = "dev", category = types.dev, widget = "Frame Grapher", name = texts.option.framegrapher, type = "bool", value = GetWidgetToggleValue("Frame Grapher"), description = "" },

		{ id = "debugcolvol", group = "dev", category = types.dev, name = texts.option.debugcolvol, type = "bool", value = false, description = "",
		  onchange = function(i, value)
			  Spring.SendCommands("DebugColVol " .. (value and '1' or '0'))
		  end,
		},
		{ id = "echocamerastate", group = "dev", category = types.dev, name = texts.option.echocamerastate, type = "bool", value = false, description = texts.option.echocamerastate_descr,
		  onchange = function(i, value)
			  options[getOptionByID('echocamerastate')].value = false
			  Spring.Debug.TableEcho(Spring.GetCameraState())
		  end,
		},


		{ id = "label_dev_other", group = "dev", name = texts.option.label_other, category = types.dev },
		{ id = "label_dev_other_spacer", group = "dev", category = types.dev },

		{ id = "startboxeditor", group = "dev", category = types.dev, widget = "Startbox Editor", name = texts.option.startboxeditor, type = "bool", value = GetWidgetToggleValue("Startbox Editor"), description = texts.option.startboxeditor_descr },

		{ id = "language", group = "dev", category = types.dev, name = texts.option.language, type = "select", options = languageNames, value = languageCodes[Spring.I18N.getLocale()],
			onchange = function(i, value)
				if WG['language'] then
					WG['language'].setLanguage(languageCodes[value])
				end
			end
		},
		{ id = "font", group = "dev", category = types.dev, name = texts.option.font, type = "select", options = {}, value = 1, description = texts.option.font_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  if VFS.FileExists('fonts/' .. options[i].optionsFont[value]) then
				  Spring.SetConfigString("bar_font", options[i].optionsFont[value])
				  Spring.SendCommands("luarules reloadluaui")
			  end
		  end,
		},
		{ id = "font2", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.font2, type = "select", options = {}, value = 1, description = texts.option.font2_descr,
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  if VFS.FileExists('fonts/' .. options[i].optionsFont[value]) then
				  Spring.SetConfigString("bar_font2", options[i].optionsFont[value])
				  Spring.SendCommands("luarules reloadluaui")
			  end
		  end,
		},

		{ id = "label_dev_unit", group = "dev", name = texts.option.label_unit, category = types.dev },
		{ id = "label_dev_unit_spacer", group = "dev", category = types.dev },

		{ id = "tonemapA", group = "dev", category = types.dev, name = texts.option.tonemap .. widgetOptionColor .. "  1", type = "slider", min = 0, max = 7, step = 0.01, value = Spring.GetConfigFloat("tonemapA", 4.8), description = "",
		  onchange = function(i, value)
			  Spring.SetConfigFloat("tonemapA", value)
			  Spring.SendCommands("luarules updatesun")
			  Spring.SendCommands("luarules GlassUpdateSun")
		  end,
		},
		{ id = "tonemapB", group = "dev", category = types.dev, name = widgetOptionColor .. "   2", type = "slider", min = 0, max = 2, step = 0.01, value = Spring.GetConfigFloat("tonemapB", 0.75), description = "",
		  onchange = function(i, value)
			  Spring.SetConfigFloat("tonemapB", value)
			  Spring.SendCommands("luarules updatesun")
			  Spring.SendCommands("luarules GlassUpdateSun")
		  end,
		},
		{ id = "tonemapC", group = "dev", category = types.dev, name = widgetOptionColor .. "   3", type = "slider", min = 0, max = 5, step = 0.01, value = Spring.GetConfigFloat("tonemapC", 3.5), description = "",
		  onchange = function(i, value)
			  Spring.SetConfigFloat("tonemapC", value)
			  Spring.SendCommands("luarules updatesun")
			  Spring.SendCommands("luarules GlassUpdateSun")
		  end,
		},
		{ id = "tonemapD", group = "dev", category = types.dev, name = widgetOptionColor .. "   4", type = "slider", min = 0, max = 3, step = 0.01, value = Spring.GetConfigFloat("tonemapD", 0.85), description = "",
		  onchange = function(i, value)
			  Spring.SetConfigFloat("tonemapD", value)
			  Spring.SendCommands("luarules updatesun")
			  Spring.SendCommands("luarules GlassUpdateSun")
		  end,
		},
		{ id = "tonemapE", group = "dev", category = types.dev, name = widgetOptionColor .. "   5", type = "slider", min = 0.75, max = 1.5, step = 0.01, value = Spring.GetConfigFloat("tonemapE", 1.0), description = "",
		  onchange = function(i, value)
			  Spring.SetConfigFloat("tonemapE", value)
			  Spring.SendCommands("luarules updatesun")
			  Spring.SendCommands("luarules GlassUpdateSun")
		  end,
		},
		{ id = "envAmbient", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.envAmbient, type = "slider", min = 0, max = 1, step = 0.01, value = Spring.GetConfigFloat("envAmbient", 0.25), description = "",
		  onchange = function(i, value)
			  Spring.SetConfigFloat("envAmbient", value)
			  Spring.SendCommands("luarules updatesun")
			  Spring.SendCommands("luarules GlassUpdateSun")
		  end,
		},
		{ id = "unitSunMult", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.unitSunMult, type = "slider", min = 0.7, max = 1.6, step = 0.01, value = Spring.GetConfigFloat("unitSunMult", 1.0), description = "",
		  onchange = function(i, value)
			  Spring.SetConfigFloat("unitSunMult", value)
			  Spring.SendCommands("luarules updatesun")
			  Spring.SendCommands("luarules GlassUpdateSun")
		  end,
		},
		{ id = "unitExposureMult", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.unitExposureMult, type = "slider", min = 0.6, max = 1.25, step = 0.01, value = Spring.GetConfigFloat("unitExposureMult", 1.0), description = "",
		  onchange = function(i, value)
			  Spring.SetConfigFloat("unitExposureMult", value)
			  Spring.SendCommands("luarules updatesun")
			  Spring.SendCommands("luarules GlassUpdateSun")
		  end,
		},
		{ id = "modelGamma", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.modelGamma, type = "slider", min = 0.7, max = 1.7, step = 0.01, value = Spring.GetConfigFloat("modelGamma", 1.0), description = "",
		  onchange = function(i, value)
			  Spring.SetConfigFloat("modelGamma", value)
			  Spring.SendCommands("luarules updatesun")
			  Spring.SendCommands("luarules GlassUpdateSun")
		  end,
		},
		{ id = "tonemapDefaults", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.tonemapDefaults, type = "bool", value = GetWidgetToggleValue("Unit Reclaimer"), description = "",
		  onchange = function(i, value)
			  Spring.SetConfigFloat("tonemapA", 4.75)
			  Spring.SetConfigFloat("tonemapB", 0.75)
			  Spring.SetConfigFloat("tonemapC", 3.5)
			  Spring.SetConfigFloat("tonemapD", 0.85)
			  Spring.SetConfigFloat("tonemapE", 1.0)
			  Spring.SetConfigFloat("envAmbient", 0.25)
			  Spring.SetConfigFloat("unitSunMult", 1.0)
			  Spring.SetConfigFloat("unitExposureMult", 1.0)
			  Spring.SetConfigFloat("modelGamma", 1.0)
			  options[getOptionByID('tonemapA')].value = Spring.GetConfigFloat("tonemapA")
			  options[getOptionByID('tonemapB')].value = Spring.GetConfigFloat("tonemapB")
			  options[getOptionByID('tonemapC')].value = Spring.GetConfigFloat("tonemapC")
			  options[getOptionByID('tonemapD')].value = Spring.GetConfigFloat("tonemapD")
			  options[getOptionByID('tonemapE')].value = Spring.GetConfigFloat("tonemapE")
			  options[getOptionByID('envAmbient')].value = Spring.GetConfigFloat("envAmbient")
			  options[getOptionByID('unitSunMult')].value = Spring.GetConfigFloat("unitSunMult")
			  options[getOptionByID('unitExposureMult')].value = Spring.GetConfigFloat("unitExposureMult")
			  options[getOptionByID('modelGamma')].value = Spring.GetConfigFloat("modelGamma")
			  Spring.SendCommands("luarules updatesun")
			  Spring.SendCommands("luarules GlassUpdateSun")
			  options[getOptionByID('tonemapDefaults')].value = false
		  end,
		},

		{ id = "label_dev_map", group = "dev", name = texts.option.label_map, category = types.dev },
		{ id = "label_dev_map_spacer", group = "dev", category = types.dev },

		{ id = "sun_y", group = "dev", category = types.dev, name = texts.option.sun .. widgetOptionColor .. "  " .. texts.option.sun_y, type = "slider", min = 0.05, max = 0.9999, step = 0.0001, value = select(2, gl.GetSun("pos")),
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
		{ id = "sun_x", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.sun_x, type = "slider", min = -0.9999, max = 0.9999, step = 0.0001, value = select(1, gl.GetSun("pos")),
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
		{ id = "sun_z", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.sun_z, type = "slider", min = -0.9999, max = 0.9999, step = 0.0001, value = select(3, gl.GetSun("pos")),
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
		{ id = "sun_reset", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.sun_reset, type = "bool", value = false,
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

		{ id = "fog_start", group = "dev", category = types.dev, name = texts.option.fog .. widgetOptionColor .. "  " .. texts.option.fog_start, type = "slider", min = 0, max = 1.99, step = 0.01, value = gl.GetAtmosphere("fogStart"),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  if getOptionByID('fog_end') and value >= options[getOptionByID('fog_end')].value then
				  options[getOptionByID('fog_end')].value = value + 0.01
				  applyOptionValue(getOptionByID('fog_end'))
			  end
			  Spring.SetAtmosphere({ fogStart = value })
		  end,
		},
		{ id = "fog_end", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.fog_end, type = "slider", min = 0.5, max = 2, step = 0.01, value = gl.GetAtmosphere("fogEnd"),
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  if getOptionByID('fog_start') and value <= options[getOptionByID('fog_start')].value then
				  options[getOptionByID('fog_start')].value = value - 0.01
				  applyOptionValue(getOptionByID('fog_start'))
			  end
			  Spring.SetAtmosphere({ fogEnd = value })
		  end,
		},
		{ id = "fog_reset", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.fog_reset, type = "bool", value = false, description = '',
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

		{ id = "fog_r", group = "dev", category = types.dev, name = texts.option.fog .. widgetOptionColor .. "  " .. texts.option.red, type = "slider", min = 0, max = 1, step = 0.01, value = select(1, gl.GetAtmosphere("fogColor")), description = '',
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  local fogColor = { gl.GetAtmosphere("fogColor") }
			  Spring.SetAtmosphere({ fogColor = { value, fogColor[2], fogColor[3], fogColor[4] } })
		  end,
		},
		{ id = "fog_g", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.green, type = "slider", min = 0, max = 1, step = 0.01, value = select(2, gl.GetAtmosphere("fogColor")), description = '',
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  local fogColor = { gl.GetAtmosphere("fogColor") }
			  Spring.SetAtmosphere({ fogColor = { fogColor[1], value, fogColor[3], fogColor[4] } })
		  end,
		},
		{ id = "fog_b", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.blue, type = "slider", min = 0, max = 1, step = 0.01, value = select(3, gl.GetAtmosphere("fogColor")), description = '',
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  local fogColor = { gl.GetAtmosphere("fogColor") }
			  Spring.SetAtmosphere({ fogColor = { fogColor[1], fogColor[2], value, fogColor[4] } })
		  end,
		},
		{ id = "fog_color_reset", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.fog_color_reset, type = "bool", value = false, description = '',
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

		{ id = "map_voidwater", group = "dev", category = types.dev, name = texts.option.map_voidwater, type = "bool", value = false, description = "",
		  onload = function(i)
			  options[i].value = gl.GetMapRendering("voidWater")
		  end,
		  onchange = function(i, value)
			  Spring.SetMapRenderingParams({ voidWater = value })
		  end,
		},
		{ id = "map_voidground", group = "dev", category = types.dev, name = texts.option.map_voidground, type = "bool", value = false, description = "",
		  onload = function(i)
			  options[i].value = gl.GetMapRendering("voidGround")
		  end,
		  onchange = function(i, value)
			  Spring.SetMapRenderingParams({ voidGround = value })
		  end,
		},

		{ id = "map_splatdetailnormaldiffusealpha", group = "dev", category = types.dev, name = texts.option.map_splatdetailnormaldiffusealpha, type = "bool", value = false, description = "",
		  onload = function(i)
			  options[i].value = gl.GetMapRendering("splatDetailNormalDiffuseAlpha")
		  end,
		  onchange = function(i, value)
			  Spring.SetMapRenderingParams({ splatDetailNormalDiffuseAlpha = value })
		  end,
		},

		{ id = "map_splattexmults_r", group = "dev", category = types.dev, name = texts.option.map_splattexmults .. widgetOptionColor .. "   0", type = "slider", min = 0, max = 1.5, step = 0.001, value = 0, description = "",
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

		{ id = "map_splattexacales_r", group = "dev", category = types.dev, name = texts.option.map_splattexacales .. widgetOptionColor .. "   0", type = "slider", min = 0, max = 0.02, step = 0.0001, value = 0, description = "",
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
		}, { id = "map_splattexacales_a", group = "dev", category = types.dev, name = widgetOptionColor .. "   3", type = "slider", min = 0, max = 0.02, step = 0.0001, value = 0, description = "",
			 onload = function(i)
				 local r, g, b, a = gl.GetMapRendering("splatTexScales")
				 options[i].value = a
			 end,
			 onchange = function(i, value)
				 local r, g, b, a = gl.GetMapRendering("splatTexScales")
				 Spring.SetMapRenderingParams({ splatTexScales = { r, g, b, value } })
			 end,
		},

		{ id = "GroundShadowDensity", group = "dev", category = types.dev, name = texts.option.GroundShadowDensity .. widgetOptionColor .. "  ", type = "slider", min = 0, max = 1.5, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local groundshadowDensity = gl.GetSun("shadowDensity", "ground")
			  options[i].value = groundshadowDensity
		  end,
		  onchange = function(i, value)
			  Spring.SetSunLighting({ groundShadowDensity = value })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},

		{ id = "UnitShadowDensity", group = "dev", category = types.dev, name = texts.option.UnitShadowDensity .. widgetOptionColor .. "  ", type = "slider", min = 0, max = 1.5, step = 0.001, value = 0, description = "",
		  onload = function(i)
			  local groundshadowDensity = gl.GetSun("shadowDensity", "unit")
			  options[i].value = groundshadowDensity
		  end,
		  onchange = function(i, value)
			  Spring.SetSunLighting({ modelShadowDensity = value })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},

		{ id = "color_groundambient_r", group = "dev", category = types.dev, name = texts.option.color_groundambient .. widgetOptionColor .. "  " .. texts.option.red, type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
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
		{ id = "color_groundambient_g", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.green, type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
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
		{ id = "color_groundambient_b", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.blue, type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
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

		{ id = "color_grounddiffuse_r", group = "dev", category = types.dev, name = texts.option.color_grounddiffuse .. widgetOptionColor .. "  " .. texts.option.red, type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
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
		{ id = "color_grounddiffuse_g", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.green, type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
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
		{ id = "color_grounddiffuse_b", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.blue, type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
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

		{ id = "color_groundspecular_r", group = "dev", category = types.dev, name = texts.option.color_groundspecular .. widgetOptionColor .. "  " .. texts.option.red, type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
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
		{ id = "color_groundspecular_g", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.green, type = "slider", min = 0, max = 1, step = 0.001, value = 0, description = "",
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
		{ id = "color_groundspecular_b", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.blue, type = "slider", min = 0, max = 1, step = 0.001, value = 0, description = "",
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


		{ id = "color_unitambient_r", group = "dev", category = types.dev, name = texts.option.color_unitambient .. widgetOptionColor .. "  " .. texts.option.red, type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
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
		{ id = "color_unitambient_g", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.green, type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
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
		{ id = "color_unitambient_b", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.blue, type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
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

		{ id = "color_unitdiffuse_r", group = "dev", category = types.dev, name = texts.option.color_unitdiffuse .. widgetOptionColor .. "  " .. texts.option.red, type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
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
		{ id = "color_unitdiffuse_g", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.green, type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
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
		{ id = "color_unitdiffuse_b", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.blue, type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
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

		{ id = "color_unitspecular_r", group = "dev", category = types.dev, name = texts.option.color_unitspecular .. widgetOptionColor .. "  " .. texts.option.red, type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
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
		{ id = "color_unitspecular_g", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.green, type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
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
		{ id = "color_unitspecular_b", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.blue, type = "slider", min = 0, max = 2, step = 0.001, value = 0, description = "",
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

		{ id = "suncolor_r", group = "dev", category = types.dev, name = "Sun" .. widgetOptionColor .. "  " .. texts.option.red, type = "slider", min = 0, max = 1, step = 0.001, value = 0, description = "",
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
		{ id = "suncolor_g", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.green, type = "slider", min = 0, max = 1, step = 0.001, value = 0, description = "",
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
		{ id = "suncolor_b", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.blue, type = "slider", min = 0, max = 1, step = 0.001, value = 0, description = "",
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

		{ id = "skycolor_r", group = "dev", category = types.dev, name = texts.option.skycolor .. widgetOptionColor .. "  " .. texts.option.red, type = "slider", min = 0, max = 1, step = 0.001, value = 0, description = "",
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
		{ id = "skycolor_g", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.green, type = "slider", min = 0, max = 1, step = 0.001, value = 0, description = "",
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
		{ id = "skycolor_b", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. texts.option.blue, type = "slider", min = 0, max = 1, step = 0.001, value = 0, description = "",
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

		{ id = "sunlighting_reset", group = "dev", category = types.dev, name = texts.option.sunlighting_reset, type = "bool", value = false, description = texts.option.sunlighting_reset_descr,
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

		{ id = "label_dev_water", group = "dev", name = texts.option.label_water, category = types.dev },
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
		{ id = "water_windspeed", group = "dev", category = types.dev, name = widgetOptionColor .. "   windspeed", type = "slider", min = 0.0, max = 2.0, step = 0.01, value = gl.GetWaterRendering("windSpeed"), description = "The speed of bumpwater tiles moving",
		  onload = function(i)
		  end,
		  onchange = function(i, value)
			  Spring.SetWaterParams({ windSpeed = value })
			  Spring.SendCommands("water 4")
		  end,
		},
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

	if os.date("%m") ~= "12"  or  os.date("%d") < "12" then
		options[getOptionByID('xmas')] = nil
	end

	-- reset tonemap defaults (only once)
	if not resettedTonemapDefault then
		local optionID = getOptionByID('tonemapDefaults')
		options[optionID].value = true
		applyOptionValue(optionID)
		resettedTonemapDefault = true
	end

	if not devMode then
		options[getOptionByID('restart')] = nil
	end

	if not scavengersAIEnabled then
		options[getOptionByID('scav_voicenotifs')] = nil
		options[getOptionByID('scav_messages')] = nil
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

	-- set sun minimal height
	if getOptionByID('cus') then
		if options[getOptionByID('cus')].value then
			if WG.disabledCus ~= nil and WG.disabledCus then
				options[getOptionByID('cus')].value = 0.5
			end
		end
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


	if Spring.GetGameFrame() == 0 then
		detectWater()

		-- set vsync
		Spring.SetConfigInt("VSync", Spring.GetConfigInt("VSyncGame", 0))

		-- disable old cus
		if Spring.GetConfigInt("cus", 0) == 1 then
			Spring.SetConfigInt("cus", 0)
		end
		Spring.SendCommands("luarules disablecus")

		if not isPotatoGpu then	-- will disable later

			-- enable CUS GL4
			if tonumber(Spring.GetConfigInt("cus2", 1) or 1) == 1 then
				Spring.SendCommands("luarules reloadcusgl4")
			end
		end
	end
	if not waterDetected then
		Spring.SendCommands("water 0")
	end

	-- reduce options for potatoes
	if isPotatoGpu or isPotatoCpu then
		local id = getOptionByID('shadowslider')
		options[id].options = { 1, 2 }
		if options[id].value > 2 then
			options[id].value = 2
			options[id].onchange(id, options[id].value)
		end

		if isPotatoGpu then
			Spring.SendCommands("luarules disablecus")
			Spring.SendCommands("luarules disablecusgl4")
			options[getOptionByID('cus')] = nil
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
			options[getOptionByID('guishader')] = nil

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
			if Platform ~= nil and Platform.gpuVendor == 'Intel' and gpuMem < 1800 then
				options[getOptionByID('shadowslider')] = nil
				options[getOptionByID('shadows_opacity')] = nil

				Spring.SendCommands("advmapshading 0")
				Spring.SendCommands("Shadows 0 1024")
			end
		end
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

	-- add sound notification widget sound toggle options
	local soundList
	if WG['notifications'] ~= nil then
		soundList = WG['notifications'].getSoundList()
	elseif widgetHandler.configData["Notifications"] ~= nil and widgetHandler.configData["Notifications"].soundList ~= nil then
		soundList = widgetHandler.configData["Notifications"].soundList
	end
	if type(soundList) == 'table' then
		local newOptions = {}
		local count = 0
		for i, option in pairs(options) do
			count = count + 1
			newOptions[count] = option
			if option.id == 'label_notif_messages_spacer' then
				for k, v in pairs(soundList) do
					count = count + 1
					newOptions[count] = { id = "notifications_notif_" .. v[1], group = "notif", category = types.basic, name = widgetOptionColor .. "   " .. v[1], type = "bool", value = v[2], description = v[3] and Spring.I18N(v[3]) or "",
											onchange = function(i, value)
												saveOptionValue('Notifications', 'notifications', 'setSound' .. v[1], { 'soundList' }, value)
											end,
					}
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

	if WG['advplayerlist_api'] == nil or WG['advplayerlist_api'].GetLockTransitionTime == nil then
		options[getOptionByID('lockcamera_transitiontime')] = nil
	end

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

		processedOptionsCount = processedOptionsCount + 1
		processedOptions[processedOptionsCount] = option
	end
	options = processedOptions

	if windowList then
		gl.DeleteList(windowList)
	end
	windowList = gl.CreateList(DrawWindow)
end

function widget:UnsyncedHeightMapUpdate(x1, z1, x2, z2)
	if not waterDetected and Spring.GetGameFrame() > 30 then
		if heightmapChangeClock == nil then
			heightmapChangeClock = os_clock()
		end
		heightmapChangeBuffer[#heightmapChangeBuffer + 1] = { x1 * 8, z1 * 8, x2 * 8, z2 * 8 }
	end
end

function widget:Initialize()
	-- disable ambient player widget
	if widgetHandler:IsWidgetKnown("Ambient Player") then
		widgetHandler:DisableWidget("Ambient Player")
	end

	-- enable previous default disabled widgets to their new default state
	if newerVersion then
		if version <= 1 then
			if widgetHandler.orderList["DrawUnitShape GL4"] and widgetHandler.orderList["DrawUnitShape GL4"] < 0.5 then
				widgetHandler:EnableWidget("DrawUnitShape GL4")
			end
			if widgetHandler.orderList["HighlightUnit GL4"] and widgetHandler.orderList["HighlightUnit GL4"] < 0.5 then
				widgetHandler:EnableWidget("HighlightUnit GL4")
			end
			if widgetHandler.orderList["Rank Icons GL4"] and widgetHandler.orderList["Rank Icons GL4"] < 0.5 then
				widgetHandler:EnableWidget("Rank Icons GL4")
			end
		end
		if version <= 1.1 then
			if widgetHandler.orderList["Health Bars GL4"] and widgetHandler.orderList["Health Bars GL4"] < 0.5 then
				widgetHandler:EnableWidget("Health Bars GL4")
			end
		end
		if version <= 1.2 then
			if widgetHandler.orderList["Resurrection Halos GL4"] and widgetHandler.orderList["Resurrection Halos GL4"] < 0.5 then
				widgetHandler:EnableWidget("Resurrection Halos GL4")
			end
		end
	end

	if widgetHandler.orderList["FlowUI"] and widgetHandler.orderList["FlowUI"] < 0.5 then
		widgetHandler:EnableWidget("FlowUI")
	end
	if widgetHandler.orderList["Language"] and widgetHandler.orderList["Language"] < 0.5 then
		widgetHandler:EnableWidget("Language")
	end


	if WG['lang'] then
		texts = WG['lang'].getText('options')
	end

	-- set nano particle rotation: rotValue, rotVelocity, rotAcceleration, rotValueRNG, rotVelocityRNG, rotAccelerationRNG (in degrees)
	Spring.SetNanoProjectileParams(-180, -50, -50, 360, 100, 100)

	-- just making sure
	if widgetHandler.orderList["Pregame UI"] < 0.5 then
		widgetHandler:EnableWidget("Pregame UI")
	end

	updateGrabinput()
	widget:ViewResize()

	prevShow = show

	if tonumber(Spring.GetConfigInt("CameraSmoothing", 0)) == 1 then
		Spring.SendCommands("set CamFrameTimeCorrection 1")
		Spring.SendCommands("set SmoothTimeOffset 2")
	else
		Spring.SendCommands("set CamFrameTimeCorrection 0")
		Spring.SendCommands("set SmoothTimeOffset 0")
	end

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
		if gpuMem and gpuMem < 3300 then
			Spring.SetConfigInt("MSAALevel", 2)
		end
		if isPotatoGpu then
			Spring.SendCommands("water 0")
			Spring.SetConfigInt("Water", 0)

			Spring.SetConfigInt("AdvMapShading", 0)
			Spring.SendCommands("advmapshading 0")
			Spring.SendCommands("Shadows 0 1024")
			Spring.SetConfigInt("ShadowMapSize", 1024)
			Spring.SetConfigInt("Shadows", 0)
			Spring.SetConfigInt("MSAALevel", 0)
			Spring.SetConfigFloat("ui_opacity", 0.66)    -- set to be more opaque cause guishader isnt availible
		else
			Spring.SendCommands("water 4")
			Spring.SetConfigInt("Water", 4)

		end

		local minMaxparticles = 12000
		if tonumber(Spring.GetConfigInt("MaxParticles", 1) or 0) < minMaxparticles then
			Spring.SetConfigInt("MaxParticles", minMaxparticles)
			Spring.Echo('First time setup:  setting MaxParticles config value to ' .. minMaxparticles)
		end
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

		-- limit music volume
		if Spring.GetConfigInt("snd_volmusic", 20) > 50 then
			Spring.SetConfigInt("snd_volmusic", 50)
		end

		-- enable advanced model shading
		if Spring.GetConfigInt("AdvModelShading", 0) ~= 1 then
			Spring.SetConfigInt("AdvModelShading", 1)
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

	-- make sure fog-start is smaller than fog-end in case maps have configured it this way
	if gl.GetAtmosphere("fogEnd") <= gl.GetAtmosphere("fogStart") then
		Spring.SetAtmosphere({ fogEnd = gl.GetAtmosphere("fogStart") + 0.01 })
	end

	Spring.SendCommands("minimap unitsize " .. (Spring.GetConfigFloat("MinimapIconScale", 3.5)))        -- spring wont remember what you set with '/minimap iconssize #'
	Spring.SendCommands({ "bind f10 options" })

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
end

function widget:Shutdown()
	if windowList then
		glDeleteList(windowList)
	end
	if fontOption then
		for i, font in pairs(fontOption) do
			gl.DeleteFont(fontOption[i])
		end
	end
	if WG['guishader'] then
		WG['guishader'].DeleteDlist('options')
	end
	if selectOptionsList then
		if WG['guishader'] then
			WG['guishader'].RemoveScreenRect('options_select')
			WG['guishader'].RemoveScreenRect('options_select_options')
			WG['guishader'].removeRenderDlist(selectOptionsList)
		end
		glDeleteList(selectOptionsList)
		selectOptionsList = nil
	end
	WG['options'] = nil
end

local lastOptionCommand = 0

function widget:TextCommand(command)
	if string.find(command, "options", nil, true) == 1 and string.len(command) == 7 then
		local newShow = not show
		if newShow and WG['topbar'] then
			WG['topbar'].hideWindows()
		end
		show = newShow
	end

	if command == "devmode" then
		Spring.SendCommands("option usePlayerUI")
	end
	if command == "profile" and widgetHandler:IsWidgetKnown("Widget Profiler") then
		widgetHandler:ToggleWidget("Widget Profiler")
	end
	if command == "grapher" and widgetHandler:IsWidgetKnown("Frame Grapher") then
		widgetHandler:ToggleWidget("Frame Grapher")
	end
	if os_clock() > lastOptionCommand + 1 and string.sub(command, 1, 7) == "option " then
		-- clock check is needed because toggling widget will somehow do an identical call of widget:TextCommand(command)
		local option = string.sub(command, 8)
		local optionID = getOptionByID(option)
		if optionID then
			if options[optionID].type == 'bool' then
				lastOptionCommand = os_clock()
				options[optionID].value = not options[optionID].value
				applyOptionValue(optionID)
			else
				show = true
			end
		else
			option = string.split(option, ' ')
			optionID = option[1]
			if optionID then
				optionID = getOptionByID(optionID)
				if optionID and option[2] then
					lastOptionCommand = os_clock()
					if options[optionID].type == 'select' then
						local selectKey = getSelectKey(optionID, option[2])
						if selectKey then
							options[optionID].value = selectKey
							applyOptionValue(optionID)
						end
					elseif options[optionID].type == 'bool' then
						if option[2] == '0' then
							options[optionID].value = false
						elseif option[2] == '0.5' then
							options[optionID].value = 0.5
						else
							options[optionID].value = true
						end
						applyOptionValue(optionID)
					else
						options[optionID].value = tonumber(option[2])
						applyOptionValue(optionID)
					end
				end
			end
		end
	end
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
		guishaderIntensity = guishaderIntensity,

		-- to restore init defaults
		mapChecksum = Game.mapChecksum,
		defaultMapFog = defaultMapFog,
		defaultMapSunPos = defaultMapSunPos,
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
	if data.currentGroupTab ~= nil then
		currentGroupTab = data.currentGroupTab
	end
	if data.guishaderIntensity then
		guishaderIntensity = data.guishaderIntensity
	end
	if data.edgeMoveWidth then
		edgeMoveWidth = data.edgeMoveWidth
	end
	if Spring.GetGameFrame() > 0 then
		if data.show ~= nil then
			show = data.show
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
	end
	if data.useNetworkSmoothing then
		useNetworkSmoothing = data.useNetworkSmoothing
	end
end
