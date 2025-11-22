local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Top Bar",
		desc = "Shows Resources, wind speed, commander counter, and various options.",
		author = "Floris",
		date = "Feb, 2017",
		license = "GNU GPL, v2 or later",
		layer = -999999,
		enabled = true,
		handler = true, --can use widgetHandler:x()
	}
end

-- Localized functions for performance
local mathCeil = math.ceil
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local mathIsInRect = math.isInRect

-- Localized string functions
local stringFormat = string.format

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetTeamList = Spring.GetTeamList
local spSetMouseCursor = Spring.SetMouseCursor
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetTeamUnitDefCount = Spring.GetTeamUnitDefCount
local spGetSpectatingState = Spring.GetSpectatingState
local spGetTeamResources = Spring.GetTeamResources
local spGetMyTeamID = Spring.GetMyTeamID
local spGetMouseState = Spring.GetMouseState
local spGetWind = Spring.GetWind
local spGetGameSpeed = Spring.GetGameSpeed

local useRenderToTexture = Spring.GetConfigFloat("ui_rendertotexture", 1) == 1		-- much faster than drawing via DisplayLists only

-- Configuration
local relXpos = 0.3
local borderPadding = 5
local bladeSpeedMultiplier = 0.2
local escapeKeyPressesQuit = false
local allowSavegame = true -- Spring.Utilities.ShowDevUI()

-- System
local guishaderEnabled = false
local gaiaTeamID = Spring.GetGaiaTeamID()
local spec = spGetSpectatingState()
local myAllyTeamID = spGetMyAllyTeamID()
local myTeamID = spGetMyTeamID()
local mmLevel = spGetTeamRulesParam(myTeamID, 'mmLevel')
local myAllyTeamList = spGetTeamList(myAllyTeamID)
local numTeamsInAllyTeam = #myAllyTeamList

-- Game mode / state
local numPlayers = Spring.Utilities.GetPlayerCount()
local isSinglePlayer = Spring.Utilities.Gametype.IsSinglePlayer()
local chobbyLoaded = false
local isSingle = false
local gameStarted = (spGetGameFrame() > 0)
local gameFrame = spGetGameFrame()
local gameIsOver = false
local graphsWindowVisible = false

-- Resources
local r = { metal = { spGetTeamResources(myTeamID, 'metal') }, energy = { spGetTeamResources(myTeamID, 'energy') } }
local energyOverflowLevel, metalOverflowLevel
local allyteamOverflowingMetal = false
local allyteamOverflowingEnergy = false
local overflowingMetal = false
local overflowingEnergy = false
local showOverflowTooltip = {}
local supressOverflowNotifs = false
local isMetalmap = false

-- Wind + tide
local avgWindValue, riskWindValue
local currentWind = 0
local displayTidalSpeed = not Spring.Lava.isLavaMap
local tidalSpeed = Spring.GetTidal() -- for now assumed that it is not dynamically changed
local tidalWaveAnimationHeight = 10
local windRotation = 0
local minWind = Game.windMin
local maxWind = Game.windMax
local windFunctions = VFS.Include('common/wind_functions.lua')

-- Commanders
local allyComs = 0
local enemyComs = 0 -- if we are counting ourselves because we are a spec
local enemyComCount = 0 -- if we are receiving a count from the gadget part (needs modoption on)
local prevEnemyComCount = 0
local isCommander = {}
local commanderUnitDefIDs = {}  -- Array of commander unitDefIDs for faster iteration
local displayComCounter = false

-- OpenGL (only localize functions used in hot paths)
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glBlending = gl.Blending

-- Graphics
local textures = {
	noiseBackground = ":g:LuaUI/Images/rgbnoise.png",
	barGlowCenter = ":l:LuaUI/Images/barglow-center.png",
	barGlowEdge = ":l:LuaUI/Images/barglow-edge.png",
	energyGlow = "LuaUI/Images/paralyzed.png",
	blades = ":n:LuaUI/Images/wind-blades.png",
	waves = ":n:LuaUI/Images/tidal-waves.png",
	com = ":n:Icons/corcom.png"
}
local textWarnColor = "\255\255\215\215"

-- UI Elements
local topbarArea = {}
local resbarArea = { metal = {}, energy = {} }
local resbarDrawinfo = { metal = {}, energy = {} }
local shareIndicatorArea = { metal = {}, energy = {} }
local windArea = {}
local tidalarea = {}
local comsArea = {}
local buttonsArea = {}

-- UI State
local orgHeight = 46
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)
local ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.7)
local height = orgHeight * (1 + (ui_scale - 1) / 1.7)
local vsx, vsy = Spring.GetViewGeometry()
local mx = -1
local my = -1
local widgetScale = (0.80 + (vsx * vsy / 6000000))
local xPos = mathFloor(vsx * relXpos)
local showButtons = true
local autoHideButtons = false
local showResourceBars = true
local widgetSpaceMargin, bgpadding, RectRound, RectRoundOutline, TexturedRectRound, UiElement, UiButton, UiSliderKnob
local updateRes = { metal = {false,false,false,false}, energy = {false,false,false,false} }

-- Display Lists
local dlistWindText = {}
local dlistResValuesBar = {}
local dlistResValues = {}
local dlistResbar = { metal = {}, energy = {} }
local dlistEnergyGlow
local dlistQuit
local dlistButtons, dlistComs, dlistWind1, dlistWind2

-- Caching
local lastPullIncomeText =  { metal = -1, energy = -1 }
local lastStorageValue = { metal = -1, energy = -1 }
local lastStorageText = { metal = '', energy = '' }
local lastWarning = { metal = nil, energy = nil }
local lastValueWidth = { metal = -1, energy = -1 }
local lastResbarValueWidth = { metal = 1, energy = 1 }
local prevShowButtons = showButtons


-- Smoothing
local smoothedResources = {
    metal = {0, 0, 0, 0, 0, 0},  -- Init
    energy = {0, 0, 0, 0, 0, 0}  -- Init
}
local smoothingFactor = 0.5
local function smoothResources()
    local currentResources = r
    local resTypes = {'metal', 'energy'}
    for resIdx = 1, 2 do
        local resType = resTypes[resIdx]
        for i = 1, 6 do
            if smoothedResources[resType][i] == 0 then
                smoothedResources[resType][i] = currentResources[resType][i]
            else
                smoothedResources[resType][i] = smoothingFactor * currentResources[resType][i] + (1 - smoothingFactor) * smoothedResources[resType][i]
            end
        end
    end
    return
end


-- Interactions
local draggingShareIndicatorValue = {}
local draggingConversionIndicatorValue, draggingShareIndicator, draggingConversionIndicator
local conversionIndicatorArea, quitscreenArea, quitscreenStayArea, quitscreenQuitArea, quitscreenResignArea, quitscreenTeamResignArea, hoveringTopbar, hideQuitWindow
local font, font2, firstButton, fontSize, comcountChanged, showQuitscreen, resbarHover, teamResign

-- Audio
local playSounds = true
local leftclick = 'LuaUI/Sounds/tock.wav'
local resourceclick = 'LuaUI/Sounds/buildbar_click.wav'

-- Timers + intervals
local now = os.clock()
local nextStateCheck = 0
local nextGuishaderCheck = 0
local nextResBarUpdate = 0
local nextSlowUpdate = 0
local nextBarsUpdate = 0

local blinkDirection = true
local blinkProgress = 0
local guishaderCheckUpdateRate = 0.5

local nextSmoothUpdate = 0
--------------------------------------------------------------------------------

local function getPlayerLiveAllyCount()
	local nAllies = 0
	for _, teamID in ipairs(myAllyTeamList) do
		if teamID ~= myTeamID then
			local _, _, isDead, hasAI = Spring.GetTeamInfo(teamID,false)
			if not isDead and not hasAI then
				nAllies = nAllies + 1
			end
		end
	end
	return nAllies
end

local function RectQuad(px, py, sx, sy, offset)
	gl.TexCoord(offset, 1 - offset)
	gl.Vertex(px, py, 0)
	gl.TexCoord(1 - offset, 1 - offset)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(1 - offset, offset)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(offset, offset)
	gl.Vertex(px, sy, 0)
end

local function DrawRect(px, py, sx, sy, zoom)
	gl.BeginEnd(GL.QUADS, RectQuad, px, py, sx, sy, zoom)
end

function widget:ViewResize()
	vsx, vsy = gl.GetViewSizes()
	widgetScale = (vsy / height) * 0.0425 * ui_scale
	xPos = mathFloor(vsx * relXpos)

	widgetSpaceMargin = WG.FlowUI.elementMargin
	bgpadding = WG.FlowUI.elementPadding
	RectRound = WG.FlowUI.Draw.RectRound
	RectRoundOutline = WG.FlowUI.Draw.RectRoundOutline
	TexturedRectRound = WG.FlowUI.Draw.TexturedRectRound
	UiElement = WG.FlowUI.Draw.Element
	UiButton = WG.FlowUI.Draw.Button
	UiSliderKnob = WG.FlowUI.Draw.SliderKnob

	font = WG['fonts'].getFont()
	font2 = WG['fonts'].getFont(2)

	for n, _ in pairs(dlistWindText) do
		dlistWindText[n] = glDeleteList(dlistWindText[n])
	end
	for res, _ in pairs(dlistResValues) do
		dlistResValues[res] = glDeleteList(dlistResValues[res])
	end
	for res, _ in pairs(dlistResValuesBar) do
		dlistResValuesBar[res] = glDeleteList(dlistResValuesBar[res])
	end

	-- Reset lastValueWidth so display lists are recreated with new dimensions
	lastValueWidth = { metal = -1, energy = -1 }

	init()
end

-- --- OPTIMIZATION: Memoized short() function to reduce string allocations.
local shortCache = {}
local shortCacheCount = 0
local function short(n, f)
	f = f or 0
	local key = n .. ':' .. f
	if shortCache[key] then
		return shortCache[key]
	end

	local result
	if n > 9999999 then
		result = stringFormat("%." .. f .. "fm", n / 1000000)
	elseif n > 9999 then
		result = stringFormat("%." .. f .. "fk", n / 1000)
	else
		result = stringFormat("%." .. f .. "f", n)
	end

	-- Safety net to prevent the cache from growing indefinitely over a very long game.
	if shortCacheCount > 500 then
		shortCache = {}
		shortCacheCount = 0
	end

	shortCache[key] = result
	shortCacheCount = shortCacheCount + 1
	return result
end

local function updateButtons()
	local fontsize = (height * widgetScale) / 3
	local prevButtonsArea = buttonsArea

	-- if not buttonsArea['buttons'] then -- With this condition it doesn't actually update buttons if they were already added
	buttonsArea['buttons'] = {}

	local margin = bgpadding
	local textPadding = mathFloor(fontsize*0.8)
	local sidePadding = textPadding
	local offset = sidePadding
	local lastbutton

	local function addButton(name, text)
		local width = mathFloor((font2:GetTextWidth(text) * fontsize) + textPadding)
		buttonsArea['buttons'][name] = { buttonsArea[3] - offset - width, buttonsArea[2] + margin, buttonsArea[3] - offset, buttonsArea[4], text, buttonsArea[3] - offset - (width/2) }
		if not lastbutton then buttonsArea['buttons'][name][3] = buttonsArea[3] end
		offset = mathFloor(offset + width + 0.5)
		lastbutton = name
	end

	if not gameIsOver and chobbyLoaded then
		addButton('quit', Spring.I18N('ui.topbar.button.lobby'))
	else
		addButton('quit', Spring.I18N('ui.topbar.button.quit'))
	end
	if not gameIsOver and not spec and gameStarted and not isSinglePlayer then
		addButton('resign', Spring.I18N('ui.topbar.button.resign'))
	end

	if WG['options'] then addButton('options', Spring.I18N('ui.topbar.button.settings')) end
	if WG['keybinds'] then addButton('keybinds', Spring.I18N('ui.topbar.button.keys')) end
	if WG['changelog'] then addButton('changelog', Spring.I18N('ui.topbar.button.changes')) end
	if WG['teamstats'] then addButton('stats', Spring.I18N('ui.topbar.button.stats')) end
	if gameIsOver then addButton('graphs', Spring.I18N('ui.topbar.button.graphs')) end
	if WG['scavengerinfo'] then addButton('scavengers', Spring.I18N('ui.topbar.button.scavengers')) end
	if isSinglePlayer and allowSavegame and WG['savegame'] then addButton('save', Spring.I18N('ui.topbar.button.save')) end

	buttonsArea['buttons'][lastbutton][1] = buttonsArea['buttons'][lastbutton][1] - sidePadding
	offset = offset + sidePadding
	buttonsArea[1] = buttonsArea[3]-offset-margin

	-- sometimes its gets wider when (stats) button gets added
	if prevButtonsArea[1] and buttonsArea[1] ~= prevButtonsArea[1] then
		refreshUi = true
	end
	prevButtonsArea = buttonsArea

	if dlistButtons then glDeleteList(dlistButtons) end
	dlistButtons = glCreateList(function()
		font2:Begin(useRenderToTexture)
		font2:SetTextColor(0.92, 0.92, 0.92, 1)
		font2:SetOutlineColor(0, 0, 0, 1)
		for name, params in pairs(buttonsArea['buttons']) do
			font2:Print(params[5], params[6], params[2] + ((params[4] - params[2]) * 0.5) - (fontsize / 5), fontsize, 'co')
		end
		font2:End()
	end)
end

local function updateComs(forceText)
	local area = comsArea

	if dlistComs then glDeleteList(dlistComs) end
	comsDlistUpdate = true
	dlistComs = glCreateList(function()
		-- Commander icon
		local sizeHalf = (height / 2.44) * widgetScale
		local yOffset = ((area[3] - area[1]) * 0.025)
		if VFS.FileExists(string.lower(string.gsub(textures.com, ":.:", ""))) then
			glTexture(textures.com)
			glTexRect(area[1] + ((area[3] - area[1]) / 2) - sizeHalf, area[2] + ((area[4] - area[2]) / 2) - sizeHalf +yOffset, area[1] + ((area[3] - area[1]) / 2) + sizeHalf, area[2] + ((area[4] - area[2]) / 2) + sizeHalf+yOffset)
			glTexture(false)
		end
		-- Text
		if gameFrame > 0 or forceText then
			font2:Begin(useRenderToTexture)
			local fontsize = (height / 2.85) * widgetScale
			font2:SetOutlineColor(0,0,0,1)
			font2:Print('\255\255\000\000' .. enemyComCount, area[3] - (2.8 * widgetScale), area[2] + (4.5 * widgetScale), fontsize, 'or')
			fontSize = (height / 2.15) * widgetScale
			font2:Print("\255\000\255\000" .. allyComs, area[1] + ((area[3] - area[1]) / 2), area[2] + ((area[4] - area[2]) / 2.05) - (fontSize / 5), fontSize, 'oc')
			font2:End()
		end
	end)

	comcountChanged = nil

	if WG['tooltip'] and refreshUi then
		WG['tooltip'].AddTooltip('coms', area, Spring.I18N('ui.topbar.commanderCountTooltip'), nil, Spring.I18N('ui.topbar.commanderCount'))
	end
end

local function updateWindRisk()
	riskWindValue = windFunctions.getWindRisk()
end

local function updateAvgWind()
	-- precomputed average wind values, from wind random monte carlo simulation, given minWind and maxWind
	local avgWind = windFunctions.averageWindLookup

	-- pull average wind from precomputed table, if it exists
	if avgWind[minWind] then avgWindValue = avgWind[minWind][maxWind] end

	-- fallback approximation
	if not avgWindValue then avgWindValue = "~" .. tostring(mathMax(minWind, maxWind * 0.75)) end
end

local function updateWind()
	local area = windArea

	local bladesSize = height*0.53 * widgetScale

	if dlistWind1 then glDeleteList(dlistWind1) end
	dlistWind1 = glCreateList(function()
		-- blades icon
		gl.PushMatrix()
		gl.Translate(area[1] + ((area[3] - area[1]) / 2), area[2] + (bgpadding/2) + ((area[4] - area[2]) / 2), 0)
		gl.Color(1, 1, 1, 0.2)
		glTexture(textures.blades)
		-- gl.Rotate is done after displaying this dl, and before dl2
	end)

	if dlistWind2 then glDeleteList(dlistWind2) end
	dlistWind2 = glCreateList(function()
		glTexRect(-bladesSize, -bladesSize, bladesSize, bladesSize)
		glTexture(false)
		gl.PopMatrix()

		if not useRenderToTexture then
			-- min and max wind
			local fontsize = (height / 3.7) * widgetScale
			if not windFunctions.isNoWind() then
				font2:Begin(useRenderToTexture)
				font2:SetOutlineColor(0,0,0,1)
				font2:Print("\255\210\210\210" .. minWind, windArea[3] - (2.8 * widgetScale), windArea[4] - (4.5 * widgetScale) - (fontsize / 2), fontsize, 'or')
				font2:Print("\255\210\210\210" .. maxWind, windArea[3] - (2.8 * widgetScale), windArea[2] + (4.5 * widgetScale), fontsize, 'or')
				-- uncomment below to display average wind speed on UI
				-- font2:Print("\255\210\210\210" .. avgWindValue, area[1] + (2.8 * widgetScale), area[2] + (4.5 * widgetScale), fontsize, '')
				font2:End()
			else
				font2:Begin(useRenderToTexture)
				font2:SetOutlineColor(0,0,0,1)
				--font2:Print("\255\200\200\200no wind", windArea[1] + ((windArea[3] - windArea[1]) / 2), windArea[2] + ((windArea[4] - windArea[2]) / 2.05) - (fontsize / 5), fontsize, 'oc') -- Wind speed text
				font2:Print("\255\200\200\200" .. Spring.I18N('ui.topbar.wind.nowind1'), windArea[1] + ((windArea[3] - windArea[1]) / 2), windArea[2] + ((windArea[4] - windArea[2]) / 1.5) - (fontsize / 5), fontsize*1.06, 'oc') -- Wind speed text
				font2:Print("\255\200\200\200" .. Spring.I18N('ui.topbar.wind.nowind2'), windArea[1] + ((windArea[3] - windArea[1]) / 2), windArea[2] + ((windArea[4] - windArea[2]) / 2.8) - (fontsize / 5), fontsize*1.06, 'oc') -- Wind speed text
				font2:End()
			end
		end
	end)

	if WG['tooltip'] and refreshUi then
		if not windFunctions.isNoWind() then
			WG['tooltip'].AddTooltip('wind', area, Spring.I18N('ui.topbar.windspeedTooltip', { avgWindValue = avgWindValue, riskWindValue = riskWindValue, warnColor = textWarnColor }), nil, Spring.I18N('ui.topbar.windspeed'))
		else
			WG['tooltip'].AddTooltip('wind', area, Spring.I18N('ui.topbar.windspeedTooltip', { avgWindValue = Spring.I18N('ui.topbar.wind.nowind1'), riskWindValue = riskWindValue, warnColor = textWarnColor }), nil, Spring.I18N('ui.topbar.windspeed'))
		end
	end
end

-- return true if tidal speed is *relevant*, enough water in the world (>= 10%)
local function checkTidalRelevant()
	local mapMinHeight = 0

	-- account for invertmap to the best of our abiltiy
	if string.find(Spring.GetModOptions().debugcommands,"invertmap") then
		if string.find(Spring.GetModOptions().debugcommands,"wet") then
			-- assume that they want water if keyword "wet" is involved, too violitile between initilization and subsequent post terraform checks
			return true
		--else
		--	mapMinHeight = 0
		end
	else
		mapMinHeight = select(3,Spring.GetGroundExtremes())
	end

	mapMinHeight = mapMinHeight - (Spring.GetModOptions().map_waterlevel or 0)
	return mapMinHeight <= -20	-- armtide/cortide can be built from 20 waterdepth (hardcoded here cause am too lazy to auto cycle trhough unitdefs and read it from there)
end

local function updateTidal()
	local area = tidalarea

	if tidaldlist2 then glDeleteList(tidaldlist2) end
	local wavesSize = height*0.53 * widgetScale
	tidalWaveAnimationHeight = height*0.1 * widgetScale

	tidaldlist2 = glCreateList(function()
		gl.Color(1, 1, 1, 0.2)
		glTexture(textures.waves)
		glTexRect(-wavesSize, -wavesSize, wavesSize, wavesSize)
		glTexture(false)
		gl.PopMatrix()
		if not useRenderToTexture then
			local fontSize = (height / 2.66) * widgetScale
			font2:Begin(useRenderToTexture)
			font2:SetOutlineColor(0,0,0,1)
			font2:Print("\255\255\255\255" .. tidalSpeed, tidalarea[1] + ((tidalarea[3] - tidalarea[1]) / 2), tidalarea[2] + ((tidalarea[4] - tidalarea[2]) / 2.05) - (fontSize / 5), fontSize, 'oc') -- Tidal speed text
			font2:End()
		end
	end)

	if WG['tooltip'] and refreshUi then
		WG['tooltip'].AddTooltip('tidal', area, Spring.I18N('ui.topbar.tidalspeedTooltip'), nil, Spring.I18N('ui.topbar.tidalspeed'))
	end
end

local function drawResbarPullIncome(res)
	font2:Begin(useRenderToTexture)
	font2:SetOutlineColor(0,0,0,1)
	-- Text: pull
	font2:Print("\255\240\125\125" .. "-" .. short(r[res][3]), resbarDrawinfo[res].textPull[2], resbarDrawinfo[res].textPull[3], resbarDrawinfo[res].textPull[4], resbarDrawinfo[res].textPull[5])
	-- Text: expense
	--font2:Print("\255\240\180\145" .. "-" .. short(r[res][5]), resbarDrawinfo[res].textExpense[2], resbarDrawinfo[res].textExpense[3], resbarDrawinfo[res].textExpense[4], resbarDrawinfo[res].textExpense[5])
	-- income
	font2:Print("\255\120\235\120" .. "+" .. short(r[res][4]), resbarDrawinfo[res].textIncome[2], resbarDrawinfo[res].textIncome[3], resbarDrawinfo[res].textIncome[4], resbarDrawinfo[res].textIncome[5])
	font2:End()
end

local function drawResbarStorage(res)
	font2:Begin(useRenderToTexture)
	font2:SetOutlineColor(0,0,0,1)
	if res == 'metal' then
		font2:SetTextColor(0.55, 0.55, 0.55, 1)
	else
		font2:SetTextColor(0.57, 0.57, 0.45, 1)
	end
	font2:Print(lastStorageText[res], resbarDrawinfo[res].textStorage[2], resbarDrawinfo[res].textStorage[3], resbarDrawinfo[res].textStorage[4], resbarDrawinfo[res].textStorage[5])
	font2:End()
end

local function updateResbarText(res, force)
	if not showResourceBars then
		return
	end

	-- used to flashing resbar area (tinting)
	if not dlistResbar[res][4] or force then
		if dlistResbar[res][4] then
			glDeleteList(dlistResbar[res][4])
		end
		dlistResbar[res][4] = glCreateList(function()
			RectRound(resbarArea[res][1] + bgpadding, resbarArea[res][2] + bgpadding, resbarArea[res][3] - bgpadding, resbarArea[res][4], bgpadding * 1.25, 0,0,1,1)
			RectRound(resbarArea[res][1], resbarArea[res][2], resbarArea[res][3], resbarArea[res][4], 5.5 * widgetScale, 0,0,1,1)
		end)
	end

	-- storage changed!
	if lastStorageValue[res] ~= r[res][2] or force then
		lastStorageValue[res] = r[res][2]

		-- storage
		local storageText = short(r[res][2])
		if lastStorageText[res] ~= storageText or force then
			lastStorageText[res] = storageText
			updateRes[res][3] = true
			if not useRenderToTexture then
				if dlistResbar[res][6] then glDeleteList(dlistResbar[res][6]) end
				dlistResbar[res][6] = glCreateList(function()
					drawResbarStorage(res)
				end)
			end
		end
	end

	if lastPullIncomeText[res] ~= short(r[res][3])..' '..short(r[res][4]) then
		lastPullIncomeText[res] = short(r[res][3])..' '..short(r[res][4])
		updateRes[res][2] = true
		if not useRenderToTexture then
			if dlistResbar[res][3] then glDeleteList(dlistResbar[res][3]) end
			dlistResbar[res][3] = glCreateList(function()
				drawResbarPullIncome(res)
			end)
		end
	end

	if not spec and gameFrame > 90 then
		-- display overflow notification
		if (res == 'metal' and (allyteamOverflowingMetal or overflowingMetal)) or (res == 'energy' and (allyteamOverflowingEnergy or overflowingEnergy)) then
			if not showOverflowTooltip[res] then showOverflowTooltip[res] = now + 1.1 end

			if showOverflowTooltip[res] < now then
				local bgpadding2 = 2.2 * widgetScale
				local text = ''

				if res == 'metal' then
					text = (allyteamOverflowingMetal and '   ' .. Spring.I18N('ui.topbar.resources.wastingMetal') .. '   ' or '   ' .. Spring.I18N('ui.topbar.resources.overflowing') .. '   ')
					if not supressOverflowNotifs and  WG['notifications'] and not isMetalmap and (not WG.sharedMetalFrame or WG.sharedMetalFrame+60 < gameFrame) then
						if allyteamOverflowingMetal then
							if numTeamsInAllyTeam > 1 then
								WG['notifications'].queueNotification('WholeTeamWastingMetal')
							else
								WG['notifications'].queueNotification('YouAreWastingMetal')
							end
						elseif r[res][6] > 0.75 then	-- supress if you are deliberately overflowing by adjustingthe share slider down
							WG['notifications'].queueNotification('YouAreOverflowingMetal')
						end
					end
				else
					text = (allyteamOverflowingEnergy and '   ' .. Spring.I18N('ui.topbar.resources.wastingEnergy') .. '   '  or '   ' .. Spring.I18N('ui.topbar.resources.overflowing') .. '   ')
					if not supressOverflowNotifs and  WG['notifications'] and (not WG.sharedEnergyFrame or WG.sharedEnergyFrame+60 < gameFrame) then
						if allyteamOverflowingEnergy then
							if numTeamsInAllyTeam > 1 then
								WG['notifications'].queueNotification('WholeTeamWastingEnergy')
							else
								WG['notifications'].queueNotification('YouAreWastingEnergy')
							end
						end
					end

				end

				if lastWarning[res] ~= text or force then
					lastWarning[res] = text

					if dlistResbar[res][7] then glDeleteList(dlistResbar[res][7]) end

					dlistResbar[res][7] = glCreateList(function()
						local fontSize = (orgHeight * (1 + (ui_scale - 1) / 1.33) / 4) * widgetScale
						local textWidth = font2:GetTextWidth(text) * fontSize

						-- background
						local color1, color2, color3, color4
						if res == 'metal' then
							if allyteamOverflowingMetal then
								color1 = { 0.35, 0.1, 0.1, 1 }
								color2 = { 0.25, 0.05, 0.05, 1 }
								color3 = { 1, 0.3, 0.3, 0.25 }
								color4 = { 1, 0.3, 0.3, 0.44 }
							else
								color1 = { 0.35, 0.35, 0.35, 1 }
								color2 = { 0.25, 0.25, 0.25, 1 }
								color3 = { 1, 1, 1, 0.25 }
								color4 = { 1, 1, 1, 0.44 }
							end
						else
							if allyteamOverflowingEnergy then
								color1 = { 0.35, 0.1, 0.1, 1 }
								color2 = { 0.25, 0.05, 0.05, 1 }
								color3 = { 1, 0.3, 0.3, 0.25 }
								color4 = { 1, 0.3, 0.3, 0.44 }
							else
								color1 = { 0.35, 0.25, 0, 1 }
								color2 = { 0.25, 0.16, 0, 1 }
								color3 = { 1, 0.88, 0, 0.25 }
								color4 = { 1, 0.88, 0, 0.44 }
							end
						end

						RectRound(resbarArea[res][3] - textWidth, resbarArea[res][4] - 15.5 * widgetScale, resbarArea[res][3], resbarArea[res][4], 3.7 * widgetScale, 0, 0, 1, 1, color1, color2)
						RectRound(resbarArea[res][3] - textWidth + bgpadding2, resbarArea[res][4] - 15.5 * widgetScale + bgpadding2, resbarArea[res][3] - bgpadding2, resbarArea[res][4], 2.8 * widgetScale, 0, 0, 1, 1, color3, color4)
						RectRoundOutline(resbarArea[res][3] - textWidth + bgpadding2, resbarArea[res][4] - 15.5 * widgetScale + bgpadding2, resbarArea[res][3] - bgpadding2, resbarArea[res][4]+10, 2.8 * widgetScale, bgpadding2*1.33, 0, 0, 1, 1, {1, 1, 1, 0.15}, {1, 1, 1, 0})

						font2:Begin(useRenderToTexture)
						font2:SetTextColor(1, 0.88, 0.88, 1)
						font2:SetOutlineColor(0.2, 0, 0, 0.6)
						font2:Print(text, resbarArea[res][3], resbarArea[res][4] - 9.3 * widgetScale, fontSize, 'or')
						font2:End()
					end)
				end
			end
		else
			if force then
				if dlistResbar[res][7] then glDeleteList(dlistResbar[res][7]) end
				lastWarning[res] = nil
			end

			showOverflowTooltip[res] = nil
		end
	end
end

local function drawResbarValue(res)
	local value = short(smoothedResources[res][1])
	lastResbarValueWidth[res] = font2:GetTextWidth(value) * resbarDrawinfo[res].textCurrent[4]
	font2:Begin(useRenderToTexture)
	if res == 'metal' then
		font2:SetTextColor(0.95, 0.95, 0.95, 1)
	else
		font2:SetTextColor(1, 1, 0.74, 1)
	end
	font2:SetOutlineColor(0, 0, 0, 1)
	font2:Print(value, resbarDrawinfo[res].textCurrent[2], resbarDrawinfo[res].textCurrent[3], resbarDrawinfo[res].textCurrent[4], resbarDrawinfo[res].textCurrent[5])
	font2:End()
end

local function updateResbar(res)
	if not showResourceBars then
		return
	end

	local area = resbarArea[res]

	if dlistResbar[res][1] then
		glDeleteList(dlistResbar[res][1])
		glDeleteList(dlistResbar[res][2])
	end

	local barHeight = mathFloor((height * widgetScale / 7) + 0.5)
	local barHeightPadding = mathFloor(((height / 4.4) * widgetScale) + 0.5)
	local barLeftPadding = mathFloor(53 * widgetScale)
	local barRightPadding = mathFloor(14.5 * widgetScale)
	local barArea = { area[1] + mathFloor((height * widgetScale) + barLeftPadding), area[2] + barHeightPadding, area[3] - barRightPadding, area[2] + barHeight + barHeightPadding }
	local sliderHeightAdd = mathFloor(barHeight / 1.55)
	local shareSliderWidth = barHeight + sliderHeightAdd + sliderHeightAdd
	local barWidth = barArea[3] - barArea[1]
	local glowSize = barHeight * 7
	local edgeWidth = mathMax(1, mathFloor(vsy / 1100))

	if not showQuitscreen and resbarHover and resbarHover == res then
		sliderHeightAdd = barHeight / 0.75
		shareSliderWidth = barHeight + sliderHeightAdd + sliderHeightAdd
	end
	shareSliderWidth = mathCeil(shareSliderWidth)

	-- Always update barArea so glow calculations work correctly even when refreshUi is false
	if not resbarDrawinfo[res] then
		resbarDrawinfo[res] = {}
	end
	resbarDrawinfo[res].barArea = barArea
	-- Always update barTexRect so it has current coordinates
	resbarDrawinfo[res].barTexRect = { barArea[1], barArea[2], barArea[1] + ((r[res][1] / r[res][2]) * barWidth), barArea[4] }

	-- Ensure barColor is initialized
	if not resbarDrawinfo[res].barColor then
		if res == 'metal' then
			resbarDrawinfo[res].barColor = { 1, 1, 1, 1 }
		else
			resbarDrawinfo[res].barColor = { 1, 1, 0, 1 }
		end
	end

	if refreshUi then
		if res == 'metal' then
			resbarDrawinfo[res].barColor = { 1, 1, 1, 1 }
		else
			resbarDrawinfo[res].barColor = { 1, 1, 0, 1 }
		end
		resbarDrawinfo[res].barArea = barArea

		resbarDrawinfo[res].barTexRect = { barArea[1], barArea[2], barArea[1] + ((r[res][1] / r[res][2]) * barWidth), barArea[4] }
		-- Glow rectangles should be relative to barArea, not barTexRect, so they don't shift when resource values change
		resbarDrawinfo[res].barGlowMiddleTexRect = { barArea[1], barArea[2] - glowSize, barArea[3], barArea[4] + glowSize }
		resbarDrawinfo[res].barGlowLeftTexRect = { barArea[1] - (glowSize * 2.5), barArea[2] - glowSize, barArea[1], barArea[4] + glowSize }
		resbarDrawinfo[res].barGlowRightTexRect = { barArea[3], barArea[2] - glowSize, barArea[3] + (glowSize * 2.5), barArea[4] + glowSize }

		resbarDrawinfo[res].textCurrent = { short(r[res][1]), barArea[1] + barWidth / 2, barArea[2] + barHeight * 1.8, (height / 2.5) * widgetScale, 'ocd' }
		resbarDrawinfo[res].textStorage = { "\255\150\150\150" .. short(r[res][2]), barArea[3], barArea[2] + barHeight * 2.1, (height / 3.2) * widgetScale, 'ord' }
		resbarDrawinfo[res].textPull = { "\255\210\100\100" .. short(r[res][3]), barArea[1] - (10 * widgetScale), barArea[2] + barHeight * 2.15, (height / 3) * widgetScale, 'ord' }
		resbarDrawinfo[res].textExpense = { "\255\210\100\100" .. short(r[res][5]), barArea[1] + (10 * widgetScale), barArea[2] + barHeight * 2.15, (height / 3) * widgetScale, 'old' }
		resbarDrawinfo[res].textIncome = { "\255\100\210\100" .. short(r[res][4]), barArea[1] - (10 * widgetScale), barArea[2] - (barHeight * 0.55), (height / 3) * widgetScale, 'ord' }

	else	-- just update values
		resbarDrawinfo[res].textCurrent[1] = short(r[res][1])
		resbarDrawinfo[res].textStorage[1] = "\255\150\150\150" .. short(r[res][2])
		resbarDrawinfo[res].textPull[1] = "\255\210\100\100" .. short(r[res][3])
		resbarDrawinfo[res].textExpense[1] = "\255\210\100\100" .. short(r[res][5])
		resbarDrawinfo[res].textIncome[1] = "\255\100\210\100" .. short(r[res][4])
	end

	dlistResbar[res][1] = glCreateList(function()
		glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

		-- Icon
		gl.Color(1, 1, 1, 1)
		local iconPadding = mathFloor((area[4] - area[2]) / 7)
		local iconSize = mathFloor(area[4] - area[2] - iconPadding - iconPadding)
		local bgpaddingHalf = mathFloor((bgpadding * 0.5) + 0.5)
		local texSize = mathFloor(iconSize * 2)

		if res == 'metal' then
			glTexture(":lr" .. texSize .. "," .. texSize .. ":LuaUI/Images/metal.png")
		else
			glTexture(":lr" .. texSize .. "," .. texSize .. ":LuaUI/Images/energy.png")
		end

		glTexRect(area[1] + bgpaddingHalf + iconPadding, area[2] + bgpaddingHalf + iconPadding, area[1] + bgpaddingHalf + iconPadding + iconSize, area[4] + bgpaddingHalf - iconPadding)
		glTexture(false)

		-- Bar background
		local addedSize = mathFloor(((barArea[4] - barArea[2]) * 0.15) + 0.5)
		local borderSize = 1
		RectRound(barArea[1] - edgeWidth + borderSize, barArea[2] - edgeWidth + borderSize, barArea[3] + edgeWidth - borderSize, barArea[4] + edgeWidth - borderSize, barHeight * 0.2, 1, 1, 1, 1, { 0,0,0, 0.15 }, { 0,0,0, 0.2 })

		-- bar dark outline
		local featherHeight = addedSize*4
		WG.FlowUI.Draw.RectRoundOutline(
			barArea[1] - addedSize - featherHeight - edgeWidth, barArea[2] - addedSize - featherHeight - edgeWidth, barArea[3] + addedSize + featherHeight + edgeWidth, barArea[4] + addedSize + featherHeight + edgeWidth,
			barHeight * 0.8, featherHeight,
			1,1,1,1,
			{ 0,0,0, 0 }, { 0,0,0, 0.22 }
		)
		featherHeight = addedSize
		WG.FlowUI.Draw.RectRoundOutline(
			barArea[1] - addedSize - featherHeight - edgeWidth, barArea[2] - addedSize - featherHeight - edgeWidth, barArea[3] + addedSize + featherHeight + edgeWidth, barArea[4] + addedSize + featherHeight + edgeWidth,
			featherHeight*1.5, featherHeight,
			1,1,1,1,
			{ 0,0,0, 0 }, { 0,0,0, 0.66 }
		)

		-- bar inner light outline
		WG.FlowUI.Draw.RectRoundOutline(
			barArea[1] - addedSize - edgeWidth, barArea[2] - addedSize - edgeWidth, barArea[3] + addedSize + edgeWidth, barArea[4] + addedSize + edgeWidth,
			barHeight * 0.33, barHeight * 0.1,
			1,1,1,1,
			{ 1, 1, 1, 0.3 }, { 1, 1, 1, 0 }
		)

		glBlending(GL.SRC_ALPHA, GL.ONE)
		glTexture(textures.noiseBackground)
		gl.Color(1,1,1, 0.88)
		TexturedRectRound(barArea[1] - edgeWidth, barArea[2] - edgeWidth, barArea[3] + edgeWidth, barArea[4] + edgeWidth, barHeight * 0.33, 1, 1, 1, 1, barWidth*0.33, 0)
		glTexture(false)
		RectRound(barArea[1] - addedSize - edgeWidth, barArea[2] - addedSize - edgeWidth, barArea[3] + addedSize + edgeWidth, barArea[4] + addedSize + edgeWidth, barHeight * 0.33, 1, 1, 1, 1, { 0, 0, 0, 0.1 }, { 0, 0, 0, 0.1 })
		RectRound(barArea[1] - addedSize, barArea[2] - addedSize, barArea[3] + addedSize, barArea[4] + addedSize, barHeight * 0.33, 1, 1, 1, 1, { 0.15, 0.15, 0.15, 0.17 }, { 0.8, 0.8, 0.8, 0.13 })
		-- -- gloss
		RectRound(barArea[1] - addedSize, barArea[2] + addedSize, barArea[3] + addedSize, barArea[4] + addedSize, barHeight * 0.33, 1, 1, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.05 })
		RectRound(barArea[1] - addedSize, barArea[2] - addedSize, barArea[3] + addedSize, barArea[2] + addedSize + (addedSize*1.5), barHeight * 0.2, 0, 0, 1, 1, { 1, 1, 1, 0.08 }, { 1, 1, 1, 0.0 })
		glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	end)

	dlistResbar[res][2] = glCreateList(function()
		-- Metalmaker Conversion slider
		if res == 'energy' then
			mmLevel = Spring.GetTeamRulesParam(myTeamID, 'mmLevel')
			local convValue = mmLevel
			if draggingConversionIndicatorValue then convValue = draggingConversionIndicatorValue / 100 end
			if convValue == nil then convValue = 1 end

			conversionIndicatorArea = { mathFloor(barArea[1] + (convValue * barWidth) - (shareSliderWidth / 2)), mathFloor(barArea[2] - sliderHeightAdd), mathFloor(barArea[1] + (convValue * barWidth) + (shareSliderWidth / 2)), mathFloor(barArea[4] + sliderHeightAdd) }

			UiSliderKnob(mathFloor(conversionIndicatorArea[1]+((conversionIndicatorArea[3]-conversionIndicatorArea[1])/2)), mathFloor(conversionIndicatorArea[2]+((conversionIndicatorArea[4]-conversionIndicatorArea[2])/2)), mathFloor((conversionIndicatorArea[3]-conversionIndicatorArea[1])/2), { 0.95, 0.95, 0.7, 1 })
		end

		-- Share slider
		if not isSingle then
			if res == 'energy' then
				energyOverflowLevel = r[res][6]
			else
				metalOverflowLevel = r[res][6]
			end

			local value = r[res][6]

			if draggingShareIndicator and draggingShareIndicatorValue[res] then
				value = draggingShareIndicatorValue[res]
			else
				draggingShareIndicatorValue[res] = value
			end

			shareIndicatorArea[res] = { mathFloor(barArea[1] + (value * barWidth) - (shareSliderWidth / 2)), mathFloor(barArea[2] - sliderHeightAdd), mathFloor(barArea[1] + (value * barWidth) + (shareSliderWidth / 2)), mathFloor(barArea[4] + sliderHeightAdd) }

			UiSliderKnob(mathFloor(shareIndicatorArea[res][1]+((shareIndicatorArea[res][3]-shareIndicatorArea[res][1])/2)), mathFloor(shareIndicatorArea[res][2]+((shareIndicatorArea[res][4]-shareIndicatorArea[res][2])/2)), mathFloor((shareIndicatorArea[res][3]-shareIndicatorArea[res][1])/2), { 0.85, 0, 0, 1 })
		end
	end)

	local resourceTranslations = {
		metal = Spring.I18N('ui.topbar.resources.metal'),
		energy =  Spring.I18N('ui.topbar.resources.energy')
	}

	local resourceName = resourceTranslations[res]

	-- add/update tooltips
	if WG['tooltip'] and conversionIndicatorArea then

		-- always update for now
		if res == 'energy' then
			WG['tooltip'].AddTooltip(res .. '_share_slider', { resbarDrawinfo[res].barArea[1], shareIndicatorArea[res][2], conversionIndicatorArea[1], shareIndicatorArea[res][4] }, Spring.I18N('ui.topbar.resources.shareEnergyTooltip'), nil, Spring.I18N('ui.topbar.resources.shareEnergyTooltipTitle'))
			WG['tooltip'].AddTooltip(res .. '_share_slider2', { conversionIndicatorArea[3], shareIndicatorArea[res][2], resbarDrawinfo[res].barArea[3], shareIndicatorArea[res][4] }, Spring.I18N('ui.topbar.resources.shareEnergyTooltip'), nil, Spring.I18N('ui.topbar.resources.shareEnergyTooltipTitle'))
			WG['tooltip'].AddTooltip(res .. '_metalmaker_slider', conversionIndicatorArea, Spring.I18N('ui.topbar.resources.conversionTooltip'), nil, Spring.I18N('ui.topbar.resources.conversionTooltipTitle'))
		else
			WG['tooltip'].AddTooltip(res .. '_share_slider', { resbarDrawinfo[res].barArea[1], shareIndicatorArea[res][2], resbarDrawinfo[res].barArea[3], shareIndicatorArea[res][4] }, Spring.I18N('ui.topbar.resources.shareMetalTooltip'), nil, Spring.I18N('ui.topbar.resources.shareMetalTooltipTitle'))
		end

		if refreshUi then
			WG['tooltip'].AddTooltip(res .. '_pull', { resbarDrawinfo[res].textPull[2] - (resbarDrawinfo[res].textPull[4] * 2.5), resbarDrawinfo[res].textPull[3], resbarDrawinfo[res].textPull[2] + (resbarDrawinfo[res].textPull[4] * 0.5), resbarDrawinfo[res].textPull[3] + resbarDrawinfo[res].textPull[4] }, Spring.I18N('ui.topbar.resources.pullTooltip', { resource = resourceName }))
			WG['tooltip'].AddTooltip(res .. '_income', { resbarDrawinfo[res].textIncome[2] - (resbarDrawinfo[res].textIncome[4] * 2.5), resbarDrawinfo[res].textIncome[3], resbarDrawinfo[res].textIncome[2] + (resbarDrawinfo[res].textIncome[4] * 0.5), resbarDrawinfo[res].textIncome[3] + resbarDrawinfo[res].textIncome[4] }, Spring.I18N('ui.topbar.resources.incomeTooltip', { resource = resourceName }))
			--WG['tooltip'].AddTooltip(res .. '_expense', { resbarDrawinfo[res].textExpense[2] - (4 * widgetScale), resbarDrawinfo[res].textExpense[3], resbarDrawinfo[res].textExpense[2] + (30 * widgetScale), resbarDrawinfo[res].textExpense[3] + resbarDrawinfo[res].textExpense[4] }, Spring.I18N('ui.topbar.resources.expenseTooltip', { resource = resourceName }))
			WG['tooltip'].AddTooltip(res .. '_storage', { resbarDrawinfo[res].textStorage[2] - (resbarDrawinfo[res].textStorage[4] * 2.75), resbarDrawinfo[res].textStorage[3], resbarDrawinfo[res].textStorage[2], resbarDrawinfo[res].textStorage[3] + resbarDrawinfo[res].textStorage[4] }, Spring.I18N('ui.topbar.resources.storageTooltip', { resource = resourceName }))
		end
	end
end

local function updateResbarValues(res, update)
	if not showResourceBars then
		return
	end

	if update then
		local barHeight = resbarDrawinfo[res].barArea[4] - resbarDrawinfo[res].barArea[2] -- only read values if update is needed
		local barWidth = resbarDrawinfo[res].barArea[3] - resbarDrawinfo[res].barArea[1] -- only read values if update is needed
		updateRes[res][1] = true
		local maxStorageRes = smoothedResources[res][2]
		local cappedCurRes = smoothedResources[res][1]    -- limit so when production dies the value wont be much larger than what you can store
		if cappedCurRes >maxStorageRes * 1.07 then cappedCurRes =maxStorageRes * 1.07 end
		local barSize = barHeight * 0.2
		local valueWidth = mathFloor(((cappedCurRes /maxStorageRes) * barWidth))
		if valueWidth < mathCeil(barSize) then valueWidth = mathCeil(barSize) end
		if valueWidth ~= lastValueWidth[res] then  -- only recalc if the width changed
			lastValueWidth[res] = valueWidth

			-- resbar
			if dlistResValuesBar[res] then  glDeleteList(dlistResValuesBar[res]) end
			dlistResValuesBar[res] = glCreateList(function()
				local glowSize = barHeight * 7
				local color1, color2, glowAlpha

				if res == 'metal' then
					color1 = { 0.51, 0.51, 0.5, 1 }
					color2 = { 0.95, 0.95, 0.95, 1 }
					glowAlpha = 0.025 + (0.05 * mathMin(1, cappedCurRes / r[res][2] * 40))
				else
					color1 = { 0.5, 0.45, 0, 1 }
					color2 = { 0.8, 0.75, 0, 1 }
					glowAlpha = 0.035 + (0.07 * mathMin(1, cappedCurRes / r[res][2] * 40))
				end

				RectRound(resbarDrawinfo[res].barTexRect[1], resbarDrawinfo[res].barTexRect[2], resbarDrawinfo[res].barTexRect[1] + valueWidth, resbarDrawinfo[res].barTexRect[4], barSize, 1, 1, 1, 1, color1, color2)
				local borderSize = 1
				RectRound(resbarDrawinfo[res].barTexRect[1]+borderSize, resbarDrawinfo[res].barTexRect[2]+borderSize, resbarDrawinfo[res].barTexRect[1] + valueWidth-borderSize, resbarDrawinfo[res].barTexRect[4]-borderSize, barSize, 1, 1, 1, 1, { 0,0,0, 0.1 }, { 0,0,0, 0.17 })

				-- Bar value glow (recalculate glow rects dynamically based on current bar fill)
				local barLeft = resbarDrawinfo[res].barArea[1]
				local barTop = resbarDrawinfo[res].barArea[2]
				local barBottom = resbarDrawinfo[res].barArea[4]
				local currentGlowRight = barLeft + valueWidth

				glBlending(GL.SRC_ALPHA, GL.ONE)
				gl.Color(resbarDrawinfo[res].barColor[1], resbarDrawinfo[res].barColor[2], resbarDrawinfo[res].barColor[3], glowAlpha)
				glTexture(textures.barGlowCenter)
				-- Middle glow follows the filled portion
				DrawRect(barLeft, barTop - glowSize, currentGlowRight, barBottom + glowSize, 0.008)
				glTexture(textures.barGlowEdge)
				-- Left edge glow
				DrawRect(barLeft - (glowSize * 2.5), barTop - glowSize, barLeft, barBottom + glowSize, 0.008)
				-- Right edge glow follows the filled portion
				DrawRect(currentGlowRight + (glowSize * 3), barTop - glowSize, currentGlowRight, barBottom + glowSize, 0.008)
				glTexture(false)

				if res == 'metal' then
					glTexture(textures.noiseBackground)
					gl.Color(1,1,1, 0.37)
					TexturedRectRound(resbarDrawinfo[res].barTexRect[1], resbarDrawinfo[res].barTexRect[2], resbarDrawinfo[res].barTexRect[1] + valueWidth, resbarDrawinfo[res].barTexRect[4], barSize, 1, 1, 1, 1, barWidth*0.33, 0)
					glTexture(false)
				end

				glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
			end)
		end

		-- energy glow effect
		if res == 'energy' then
			if dlistEnergyGlow then glDeleteList(dlistEnergyGlow) end

			dlistEnergyGlow = glCreateList(function()
				-- energy glow effect
				gl.Color(1,1,1, 0.33)
				glBlending(GL.SRC_ALPHA, GL.ONE)
				glTexture(textures.energyGlow)
				TexturedRectRound(resbarDrawinfo[res].barTexRect[1], resbarDrawinfo[res].barTexRect[2], resbarDrawinfo[res].barTexRect[1] + valueWidth, resbarDrawinfo[res].barTexRect[4], barSize, 0, 0, 1, 1, barWidth/0.5, -now/80)
				TexturedRectRound(resbarDrawinfo[res].barTexRect[1], resbarDrawinfo[res].barTexRect[2], resbarDrawinfo[res].barTexRect[1] + valueWidth, resbarDrawinfo[res].barTexRect[4], barSize, 0, 0, 1, 1, barWidth/0.33, now/70)
				TexturedRectRound(resbarDrawinfo[res].barTexRect[1], resbarDrawinfo[res].barTexRect[2], resbarDrawinfo[res].barTexRect[1] + valueWidth, resbarDrawinfo[res].barTexRect[4], barSize, 0, 0, 1, 1, barWidth/0.45,-now/55)
				glTexture(false)

				-- colorize a bit more (with added size)
				local addedSize = mathFloor((barHeight * 0.15) + 0.5)
				gl.Color(1,1,0, 0.14)
				RectRound(resbarDrawinfo[res].barTexRect[1]-addedSize, resbarDrawinfo[res].barTexRect[2]-addedSize, resbarDrawinfo[res].barTexRect[1] + valueWidth + addedSize, resbarDrawinfo[res].barTexRect[4] + addedSize, barHeight * 0.33)
				glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
			end)
		end

		-- resbar text
		if not useRenderToTexture then
			if dlistResValues[res] then
				glDeleteList(dlistResValues[res])
			end
			dlistResValues[res] = glCreateList(function()
				drawResbarValue(res)
			end)
		end
   	end
end

function init()
	refreshUi = true

	r = { metal = { spGetTeamResources(myTeamID, 'metal') }, energy = { spGetTeamResources(myTeamID, 'energy') } }
	topbarArea = { mathFloor(xPos + (borderPadding * widgetScale)), mathFloor(vsy - (height * widgetScale)), vsx, vsy }

	local filledWidth = 0
	local totalWidth = topbarArea[3] - topbarArea[1]

	-- metal
	local width = mathFloor(totalWidth / 4.4)
	resbarArea['metal'] = { topbarArea[1] + filledWidth, topbarArea[2], topbarArea[1] + filledWidth + width, topbarArea[4] }
	filledWidth = filledWidth + width + widgetSpaceMargin
	updateResbar('metal')

	--energy
	resbarArea['energy'] = { topbarArea[1] + filledWidth, topbarArea[2], topbarArea[1] + filledWidth + width, topbarArea[4] }
	filledWidth = filledWidth + width + widgetSpaceMargin
	updateResbar('energy')

	-- wind
	width = mathFloor((height * 1.18) * widgetScale)
	windArea = { topbarArea[1] + filledWidth, topbarArea[2], topbarArea[1] + filledWidth + width, topbarArea[4] }
	filledWidth = filledWidth + width + widgetSpaceMargin
	updateWind()

	-- tidal
	if displayTidalSpeed then
		if not checkTidalRelevant() then
			displayTidalSpeed = false
		else
			width = mathFloor((height * 1.18) * widgetScale)
			tidalarea = { topbarArea[1] + filledWidth, topbarArea[2], topbarArea[1] + filledWidth + width, topbarArea[4] }
			filledWidth = filledWidth + width + widgetSpaceMargin
			updateTidal()
       	end
	end

	-- coms
	if displayComCounter then
		comsArea = { topbarArea[1] + filledWidth, topbarArea[2], topbarArea[1] + filledWidth + width, topbarArea[4] }
		filledWidth = filledWidth + width + widgetSpaceMargin
		updateComs()
	end

	-- buttons
	width = mathFloor(totalWidth / 4)
	buttonsArea = { topbarArea[3] - width, topbarArea[2], topbarArea[3], topbarArea[4] }
	updateButtons()

	if WG['topbar'] then
		WG['topbar'].GetPosition = function()
			return { topbarArea[1], topbarArea[2], topbarArea[3], topbarArea[4], widgetScale}
		end

		WG['topbar'].GetFreeArea = function()
			return { topbarArea[1] + filledWidth, topbarArea[2], topbarArea[3] - width - widgetSpaceMargin, topbarArea[4], widgetScale}
		end
	end

	updateResbarText('metal', true)
	updateResbarText('energy', true)

	updateRes = { metal = {true,true,true,true}, energy = {true,true,true,true} }
	prevComAlert = nil
end

local function checkSelfStatus()
	myAllyTeamID = spGetMyAllyTeamID()
	myAllyTeamList = spGetTeamList(myAllyTeamID)
	myTeamID = spGetMyTeamID()

	local startUnit = spGetTeamRulesParam(myTeamID, 'startUnit')
	if myTeamID ~= gaiaTeamID and UnitDefs[startUnit] then
		textures.com = ':n:Icons/'..UnitDefs[startUnit].name..'.png'
	end
end

local function countComs(forceUpdate)
	-- recount my own ally team coms
	local prevAllyComs = allyComs
	local prevEnemyComs = enemyComs
	allyComs = 0

	local myAllyTeamListLen = #myAllyTeamList
	local commanderUnitDefIDsLen = #commanderUnitDefIDs
	for i = 1, myAllyTeamListLen do
		local teamID = myAllyTeamList[i]
		for j = 1, commanderUnitDefIDsLen do
			local unitDefID = commanderUnitDefIDs[j]
			allyComs = allyComs + spGetTeamUnitDefCount(teamID, unitDefID)
		end
	end

	local newEnemyComCount = spGetTeamRulesParam(myTeamID, "enemyComCount")
	if type(newEnemyComCount) == 'number' then
		enemyComCount = newEnemyComCount
		if enemyComCount ~= prevEnemyComCount then
			comcountChanged = true
			prevEnemyComCount = enemyComCount
		end
	end

	if forceUpdate or allyComs ~= prevAllyComs or enemyComs ~= prevEnemyComs then
		comcountChanged = true
	end

	if comcountChanged then
		updateComs()
	end
end

function widget:GameStart()
	gameStarted = true
	checkSelfStatus()
	if displayComCounter then countComs(true) end
	init()
end

function widget:GameFrame(n)
	spec = spGetSpectatingState()
	gameFrame = n
	if n == 2 then
		init()
	end
end

local function updateAllyTeamOverflowing()
	allyteamOverflowingMetal = false
	allyteamOverflowingEnergy = false
	overflowingMetal = false
	overflowingEnergy = false
	local totalEnergy = 0
	local totalEnergyStorage = 0
	local totalMetal = 0
	local totalMetalStorage = 0
	local energyPercentile, metalPercentile
	local teams = spGetTeamList(myAllyTeamID)
	local teamsLen = #teams

	for i = 1, teamsLen do
		local teamID = teams[i]
		local energy, energyStorage, _, _, _, energyShare, energySent = spGetTeamResources(teamID, "energy")
		totalEnergy = totalEnergy + energy
		totalEnergyStorage = totalEnergyStorage + energyStorage
		local metal, metalStorage, _, _, _, metalShare, metalSent = spGetTeamResources(teamID, "metal")
		totalMetal = totalMetal + metal
		totalMetalStorage = totalMetalStorage + metalStorage
		if teamID == myTeamID then
			energyPercentile = energySent / totalEnergyStorage
			metalPercentile = metalSent / totalMetalStorage

			if energyPercentile > 0.0001 then
				overflowingEnergy = energyPercentile * 40 -- (1 / 0.025) = 40
				if overflowingEnergy > 1 then overflowingEnergy = 1 end
			end

			if metalPercentile > 0.0001 then
				overflowingMetal = metalPercentile * 40 -- (1 / 0.025) = 40
				if overflowingMetal > 1 then overflowingMetal = 1 end
			end
		end
	end

	energyPercentile = totalEnergy / totalEnergyStorage
	metalPercentile = totalMetal / totalMetalStorage

	if energyPercentile > 0.975 then
		allyteamOverflowingEnergy = (energyPercentile - 0.975) * 40 -- (1 / 0.025) = 40
		if allyteamOverflowingEnergy > 1 then allyteamOverflowingEnergy = 1 end
	end

	if metalPercentile > 0.975 then
		allyteamOverflowingMetal = (metalPercentile - 0.975) * 40 -- (1 / 0.025) = 40
		if allyteamOverflowingMetal > 1 then allyteamOverflowingMetal = 1 end
	end
end

local function hoveringElement(x, y)
	if resbarArea.metal[1] and mathIsInRect(x, y, resbarArea.metal[1], resbarArea.metal[2], resbarArea.metal[3], resbarArea.metal[4]) then return 'metal' end
	if resbarArea.energy[1] and mathIsInRect(x, y, resbarArea.energy[1], resbarArea.energy[2], resbarArea.energy[3], resbarArea.energy[4]) then return 'energy' end
	if windArea[1] and mathIsInRect(x, y, windArea[1], windArea[2], windArea[3], windArea[4]) then return 'wind' end
	if displayTidalSpeed and tidalarea[1] and mathIsInRect(x, y, tidalarea[1], tidalarea[2], tidalarea[3], tidalarea[4]) then return 'tidal' end
	if displayComCounter and comsArea[1] and mathIsInRect(x, y, comsArea[1], comsArea[2], comsArea[3], comsArea[4]) then return 'com' end
	if buttonsArea[1] and mathIsInRect(x, y, buttonsArea[1], buttonsArea[2], buttonsArea[3], buttonsArea[4]) then return 'menu' end

	return false
end

function widget:Update(dt)
	now = os.clock()

	windRotation = windRotation + (currentWind * bladeSpeedMultiplier * dt * 30)

	if now > nextStateCheck then
		nextStateCheck = now + 0.0333

		local prevMyTeamID = myTeamID
		local newMyTeamID = spGetMyTeamID()
		if spec and newMyTeamID ~= prevMyTeamID then
			-- check if the team that we are spectating changed
			myTeamID = newMyTeamID
			checkSelfStatus()
			init()
		end

		mx, my = spGetMouseState()

		hoveringTopbar = false
		if mx > topbarArea[1] and my > topbarArea[2] then -- checking if the curser is high enough, too
			hoveringTopbar = hoveringElement(mx, my)
			if hoveringTopbar then
				spSetMouseCursor('cursornormal')
			end
		end

		local _, _, isPaused = spGetGameSpeed()

		if not isPaused then
			if blinkDirection then
				blinkProgress = blinkProgress + (dt * 9)
				if blinkProgress > 1 then
					blinkProgress = 1
					blinkDirection = false
				end
			else
				blinkProgress = blinkProgress - (dt / (blinkProgress * 1.5))
				if blinkProgress < 0 then
					blinkProgress = 0
					blinkDirection = true
				end
			end
		end
	end

	if now > nextGuishaderCheck and widgetHandler.orderList["GUI Shader"] then
		nextGuishaderCheck = now + guishaderCheckUpdateRate
		if not guishaderEnabled and widgetHandler.orderList["GUI Shader"] ~= 0 then
			guishaderEnabled = true
			init()
		elseif guishaderEnabled and (widgetHandler.orderList["GUI Shader"] == 0) then
			guishaderEnabled = false
		end
	end

	if now > nextResBarUpdate then
		nextResBarUpdate = now + 0.05
		if not spec and not showQuitscreen then
			if hoveringTopbar == 'energy' then
				if not resbarHover then
					resbarHover = 'energy'
					updateResbar('energy')
				end
			elseif resbarHover and resbarHover == 'energy' then
				resbarHover = nil
				updateResbar('energy')
			end
			if hoveringTopbar == 'metal' then
				if not resbarHover then
					resbarHover = 'metal'
					updateResbar('metal')
				end
			elseif resbarHover and resbarHover == 'metal' then
				resbarHover = nil
				updateResbar('metal')
			end
		elseif spec then
			local prevMyTeamID = myTeamID
			local newMyTeamID = spGetMyTeamID()
			if newMyTeamID ~= prevMyTeamID then
				-- check if the team that we are spectating changed
				myTeamID = newMyTeamID
				draggingShareIndicatorValue = {}
				draggingConversionIndicatorValue = nil
				updateResbar('metal')
				updateResbar('energy')
			else
				-- make sure conversion/overflow sliders are adjusted
				if mmLevel then
					local currentMmLevel = spGetTeamRulesParam(myTeamID, 'mmLevel')
					if mmLevel ~= currentMmLevel or energyOverflowLevel ~= r['energy'][6] then
						mmLevel = currentMmLevel
						updateResbar('energy')
					end
					if metalOverflowLevel ~= r['metal'][6] then
						updateResbar('metal')
					end
				end
			end
		else
			-- make sure conversion/overflow sliders are adjusted
			if mmLevel then
				local currentMmLevel = spGetTeamRulesParam(myTeamID, 'mmLevel')
				if mmLevel ~= currentMmLevel or energyOverflowLevel ~= r['energy'][6] then
					mmLevel = currentMmLevel
					updateResbar('energy')
				end
				if metalOverflowLevel ~= r['metal'][6] then
					updateResbar('metal')
				end
			end
		end
	end

	if now > nextSmoothUpdate then
		nextSmoothUpdate = now + 0.07
		smoothResources()
	end

	if now > nextSlowUpdate then
		nextSlowUpdate = now + 0.25
		local prevR = r
		r = { metal = { spGetTeamResources(myTeamID, 'metal') }, energy = { spGetTeamResources(myTeamID, 'energy') } }
		-- check if we need to smooth the resources
		local metalDiff7 = r['metal'][7] - prevR['metal'][7]
		local metalDiff8 = r['metal'][8] - prevR['metal'][8]
		local energyDiff7 = r['energy'][7] - prevR['energy'][7]
		local energyDiff8 = r['energy'][8] - prevR['energy'][8]
		local metalStorage = r['metal'][2]
		local energyStorage = r['energy'][2]

		if (r['metal'][7] > 1 and metalDiff7 ~= 0 and r['metal'][7] / metalStorage > 0.05) or
			(r['metal'][8] > 1 and metalDiff8 ~= 0 and r['metal'][8] / metalStorage > 0.05) or
			(r['energy'][7] > 1 and energyDiff7 ~= 0 and r['energy'][7] / energyStorage > 0.05) or
			(r['energy'][8] > 1 and energyDiff8 ~= 0 and r['energy'][8] / energyStorage > 0.05)
		then
			smoothedResources = r
		end

		-- resbar values and overflow
		updateAllyTeamOverflowing()
		updateResbarText('metal')
		updateResbarText('energy')

		-- wind
		currentWind = stringFormat('%.1f', select(4, spGetWind()))

		-- coms
		if displayComCounter then
			countComs()
		end
	end
end

-- --- OPTIMIZATION: Pre-defined function for RenderToTexture to avoid creating a closure.
local function renderResbarText()
	gl.Translate(-1, -1, 0)
	gl.Scale(2 / (topbarArea[3]-topbarArea[1]), 2 / (topbarArea[4]-topbarArea[2]),	0)
	gl.Translate(-topbarArea[1], -topbarArea[2], 0)

	local res = 'metal'
	drawResbarValue(res)
	if updateRes[res][2] then
		updateRes[res][2] = false
		drawResbarPullIncome(res)
	end
	if updateRes[res][3] then
		updateRes[res][3] = false
		drawResbarStorage(res)
	end

	res = 'energy'
	drawResbarValue(res)
	if updateRes[res][2] then
		updateRes[res][2] = false
		drawResbarPullIncome(res)
	end
	if updateRes[res][3] then
		updateRes[res][3] = false
		drawResbarStorage(res)
	end
end

local function drawResBars()
	if not showResourceBars then
		return
	end

	gl.PushMatrix()

	local update = false

	if now > nextBarsUpdate then
		nextBarsUpdate = now + 0.05
		update = true
	end

	local res = 'metal'
	if dlistResbar[res][1] and dlistResbar[res][2] then
		if not useRenderToTexture then
			glCallList(dlistResbar[res][1])
		end
		if not spec and gameFrame > 90 and dlistResbar[res][4] then
			glBlending(GL.SRC_ALPHA, GL.ONE)
			if allyteamOverflowingMetal then
				gl.Color(1, 0, 0, 0.1 * allyteamOverflowingMetal * blinkProgress)
				glCallList(dlistResbar[res][4]) -- flash bar
			elseif overflowingMetal then
				gl.Color(1, 1, 1, 0.04 * overflowingMetal * (0.6 + (blinkProgress * 0.4)))
				glCallList(dlistResbar[res][4]) -- flash bar
			elseif r[res][1] < 1000 then
				local process = (r[res][1] / r[res][2]) * 13
				if process < 1 then
					process = 1 - process
					gl.Color(0.9, 0.4, 1, 0.045 * process)
					glCallList(dlistResbar[res][4])  -- flash bar
				end
			end
			glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		end

		updateResbarValues(res, update)
		if dlistResValuesBar[res] then
			glCallList(dlistResValuesBar[res]) -- res bar
		end
		if dlistResbar[res][2] then
			glCallList(dlistResbar[res][2]) -- sliders
		end

		if not useRenderToTexture then
			if dlistResValues[res] then
				glCallList(dlistResValues[res])	-- res bar value
			end
			if dlistResbar[res][6] then
				glCallList(dlistResbar[res][6]) -- storage
			end
			if dlistResbar[res][3] then
				glCallList(dlistResbar[res][3]) -- pull, expense, income
			end
		end
		if showOverflowTooltip[res] and dlistResbar[res][7] then glCallList(dlistResbar[res][7]) end -- overflow warning
	end

	res = 'energy'
	if dlistResbar[res][1] and dlistResbar[res][2]  then
		if not useRenderToTexture then
			glCallList(dlistResbar[res][1])
		end

		if not spec and gameFrame > 90 and dlistResbar[res][4] then
			glBlending(GL.SRC_ALPHA, GL.ONE)
			if allyteamOverflowingEnergy then
				gl.Color(1, 0, 0, 0.1 * allyteamOverflowingEnergy * blinkProgress)
				glCallList(dlistResbar[res][4]) -- flash bar
			elseif overflowingEnergy then
				gl.Color(1, 1, 0, 0.04 * overflowingEnergy * (0.6 + (blinkProgress * 0.4)))
				glCallList(dlistResbar[res][4]) -- flash bar
			elseif r[res][1] < 2000 then
				local process = (r[res][1] / r[res][2]) * 13
				if process < 1 then
					process = 1 - process
					gl.Color(0.9, 0.55, 1, 0.045 * process)
					glCallList(dlistResbar[res][4]) -- flash bar
				end
			end
			glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		end

		updateResbarValues(res, update)
		if dlistResValuesBar[res] then
			glCallList(dlistResValuesBar[res]) -- res bar
		end
		if dlistEnergyGlow then
			glCallList(dlistEnergyGlow)
		end
		if dlistResbar[res][2] then
			glCallList(dlistResbar[res][2]) -- sliders
		end

		if not useRenderToTexture then
			if dlistResValues[res] then
				glCallList(dlistResValues[res])	-- res bar value
			end
			if dlistResbar[res][6] then
				glCallList(dlistResbar[res][6]) -- storage
			end
			if dlistResbar[res][3] then
				glCallList(dlistResbar[res][3]) -- pull, expense, income
			end
		end
		if showOverflowTooltip[res] and dlistResbar[res][7] then glCallList(dlistResbar[res][7]) end -- overflow warning
	end
	gl.PopMatrix()

	if useRenderToTexture then
		if update then
			local scissors = {}
			res = 'metal'
			if updateRes[res][1] then
				scissors[#scissors+1] = {
					(resbarDrawinfo[res].textCurrent[2]-topbarArea[1])-(lastResbarValueWidth[res]*0.75),
					(topbarArea[4]-topbarArea[2])*0.48,
					resbarDrawinfo[res].textCurrent[4]+lastResbarValueWidth[res],
					topbarArea[4]-topbarArea[2]
				}
			end
			if updateRes[res][2] then
				scissors[#scissors+1] = {
					(resbarDrawinfo[res].textPull[2]-topbarArea[1])-(resbarDrawinfo[res].textPull[4]*3.4),
					0,
					resbarDrawinfo[res].textPull[4]*3.5,
					topbarArea[4]-topbarArea[2]
				}
			end
			if updateRes[res][3] then
				scissors[#scissors+1] = {
					(resbarDrawinfo[res].textStorage[2]-topbarArea[1])-(resbarDrawinfo[res].textStorage[4]*4),
					(topbarArea[4]-topbarArea[2])*0.48,
					resbarDrawinfo[res].textStorage[4]*4.1,
					topbarArea[4]-topbarArea[2]
				}
			end
			res = 'energy'
			if updateRes[res][1] then
				scissors[#scissors+1] = {
					(resbarDrawinfo[res].textCurrent[2]-topbarArea[1])-(lastResbarValueWidth[res]*0.75),
					(topbarArea[4]-topbarArea[2])*0.48,
					resbarDrawinfo[res].textCurrent[4]+lastResbarValueWidth[res],
					topbarArea[4]-topbarArea[2]
				}
			end
			if updateRes[res][2] then
				scissors[#scissors+1] = {
					(resbarDrawinfo[res].textPull[2]-topbarArea[1])-(resbarDrawinfo[res].textPull[4]*3.4),
					0,
					resbarDrawinfo[res].textPull[4]*3.5,
					topbarArea[4]-topbarArea[2]
				}
			end
			if updateRes[res][3] then
				scissors[#scissors+1] = {
					(resbarDrawinfo[res].textStorage[2]-topbarArea[1])-(resbarDrawinfo[res].textStorage[4]*4),
					(topbarArea[4]-topbarArea[2])*0.48,
					resbarDrawinfo[res].textStorage[4]*4.1,
					topbarArea[4]-topbarArea[2]
				}
			end

			gl.R2tHelper.RenderToTexture(uiTex, renderResbarText, useRenderToTexture, scissors)
		end
	end
end

local function drawQuitScreen()
	local fadeTime = 0.2
	local fadeProgress = (now - showQuitscreen) / fadeTime
	if fadeProgress > 1 then fadeProgress = 1 end

	Spring.SetMouseCursor('cursornormal')

	dlistQuit = glCreateList(function()
		if WG['guishader'] then
			gl.Color(0, 0, 0, (0.18 * fadeProgress))
		else
			gl.Color(0, 0, 0, (0.35 * fadeProgress))
		end

		gl.Rect(0, 0, vsx, vsy)

		if not hideQuitWindow then
			-- when terminating spring, keep the faded screen

			local w = mathFloor(320 * widgetScale)
			local h = mathFloor(w / 3.5)

			local fontSize = h / 6
			local text = Spring.I18N('ui.topbar.quit.reallyQuit')
			teamResign = false

			if not spec then
				text = Spring.I18N('ui.topbar.quit.reallyQuitResign')
				if not gameIsOver and chobbyLoaded then
					if numPlayers < 3 then
						text = Spring.I18N('ui.topbar.quit.reallyResign')
					else
						if getPlayerLiveAllyCount() >= 1 then
							teamResign = true
						end
						text = Spring.I18N('ui.topbar.quit.reallyResignSpectate')
					end
				end
			end

			local padding = mathFloor(w / 90)
			local textTopPadding = padding + padding + padding + padding + padding + fontSize
			local txtWidth = font:GetTextWidth(text) * fontSize
			w = mathMax(w, txtWidth + textTopPadding + textTopPadding)

			local x = mathFloor((vsx / 2) - (w / 2))
			local y = mathFloor((vsy / 1.8) - (h / 2))
			local maxButtons = teamResign and 5 or 4
			local buttonMargin = mathFloor(h / 9)
			local buttonWidth = mathFloor((w - buttonMargin * maxButtons) / (maxButtons-1)) -- maxButtons+1 margins for maxButtons buttons
			local buttonHeight = mathFloor(h * 0.30)

			quitscreenArea = { x, y, x + w, y + h }

			if teamResign then
				quitscreenArea[2] = quitscreenArea[2] - mathFloor(fontSize*1.7)
			end

			quitscreenStayArea   = { x + buttonMargin + 0 * (buttonWidth + buttonMargin), y + buttonMargin, x + buttonMargin + 0 * (buttonWidth + buttonMargin) + buttonWidth, y + buttonMargin + buttonHeight }
			quitscreenResignArea = { x + buttonMargin + 1 * (buttonWidth + buttonMargin), y + buttonMargin, x + buttonMargin + 1 * (buttonWidth + buttonMargin) + buttonWidth, y + buttonMargin + buttonHeight }
			local nextButton = 2
			if teamResign then
				quitscreenTeamResignArea = { x + buttonMargin + nextButton * (buttonWidth + buttonMargin), y + buttonMargin, x + buttonMargin + nextButton * (buttonWidth + buttonMargin) + buttonWidth, y + buttonMargin + buttonHeight }
				nextButton = nextButton + 1
			end
			quitscreenQuitArea   = { x + buttonMargin + nextButton * (buttonWidth + buttonMargin), y + buttonMargin, x + buttonMargin + nextButton * (buttonWidth + buttonMargin) + buttonWidth, y + buttonMargin + buttonHeight }

			-- window
			UiElement(quitscreenArea[1], quitscreenArea[2], quitscreenArea[3], quitscreenArea[4], 1,1,1,1, 1,1,1,1, nil, {1, 1, 1, 0.6 + (0.34 * fadeProgress)}, {0.45, 0.45, 0.4, 0.025 + (0.025 * fadeProgress)}, nil)--, useRenderToTexture)
			local color1, color2

			font:Begin(useRenderToTexture)
			font:SetTextColor(0, 0, 0, 1)
			font:Print(text, quitscreenArea[1] + ((quitscreenArea[3] - quitscreenArea[1]) / 2), quitscreenArea[4]-textTopPadding, fontSize, "cn")
			font:End()

			font2:Begin(useRenderToTexture)
			font2:SetTextColor(1, 1, 1, 1)
			font2:SetOutlineColor(0, 0, 0, 0.23)

			fontSize = fontSize * 0.92

			-- stay button
			if gameIsOver or not chobbyLoaded then
				if mathIsInRect(mx, my, quitscreenStayArea[1], quitscreenStayArea[2], quitscreenStayArea[3], quitscreenStayArea[4]) then
					color1 = { 0, 0.4, 0, 0.4 + (0.5 * fadeProgress) }
					color2 = { 0.05, 0.6, 0.05, 0.4 + (0.5 * fadeProgress) }
				else
					color1 = { 0, 0.25, 0, 0.35 + (0.5 * fadeProgress) }
					color2 = { 0, 0.5, 0, 0.35 + (0.5 * fadeProgress) }
				end
				UiButton(quitscreenStayArea[1], quitscreenStayArea[2], quitscreenStayArea[3], quitscreenStayArea[4], 1,1,1,1, 1,1,1,1, nil, color1, color2, padding * 0.5)
				font2:Print(Spring.I18N('ui.topbar.quit.stay'), quitscreenStayArea[1] + ((quitscreenStayArea[3] - quitscreenStayArea[1]) / 2), quitscreenStayArea[2] + ((quitscreenStayArea[4] - quitscreenStayArea[2]) / 2) - (fontSize / 3), fontSize, "con")
			end

			-- resign button
			if not spec and not gameIsOver then
				local mouseOver = false
				if mathIsInRect(mx, my, quitscreenResignArea[1], quitscreenResignArea[2], quitscreenResignArea[3], quitscreenResignArea[4]) then
					color1 = { 0.4, 0, 0, 0.4 + (0.5 * fadeProgress) }
					color2 = { 0.6, 0.05, 0.05, 0.4 + (0.5 * fadeProgress) }
					mouseOver = 'resign'
				else
					color1 = { 0.25, 0, 0, 0.35 + (0.5 * fadeProgress) }
					color2 = { 0.5, 0, 0, 0.35 + (0.5 * fadeProgress) }
				end
				UiButton(quitscreenResignArea[1], quitscreenResignArea[2], quitscreenResignArea[3], quitscreenResignArea[4], 1,1,1,1, 1,1,1,1, nil, color1, color2, padding * 0.5)
				font2:Print(Spring.I18N('ui.topbar.quit.resign'), quitscreenResignArea[1] + ((quitscreenResignArea[3] - quitscreenResignArea[1]) / 2), quitscreenResignArea[2] + ((quitscreenResignArea[4] - quitscreenResignArea[2]) / 2) - (fontSize / 3), fontSize, "con")

				if teamResign then
					if mathIsInRect(mx, my, quitscreenTeamResignArea[1], quitscreenTeamResignArea[2], quitscreenTeamResignArea[3], quitscreenTeamResignArea[4]) then
						color1 = { 0.28, 0.28, 0.28, 0.4 + (0.5 * fadeProgress) }
						color2 = { 0.45, 0.45, 0.45, 0.4 + (0.5 * fadeProgress) }
						mouseOver = 'teamResign'
					else
						color1 = { 0.18, 0.18, 0.18, 0.4 + (0.5 * fadeProgress) }
						color2 = { 0.33, 0.33, 0.33, 0.4 + (0.5 * fadeProgress) }
					end
					UiButton(quitscreenTeamResignArea[1], quitscreenTeamResignArea[2], quitscreenTeamResignArea[3], quitscreenTeamResignArea[4], 1,1,1,1, 1,1,1,1, nil, color1, color2, padding * 0.5)
					font2:Print(Spring.I18N('ui.topbar.quit.teamResign'), quitscreenTeamResignArea[1] + ((quitscreenTeamResignArea[3] - quitscreenTeamResignArea[1]) / 2), quitscreenTeamResignArea[2] + ((quitscreenTeamResignArea[4] - quitscreenTeamResignArea[2]) / 2) - (fontSize / 3), fontSize, "con")
				end
				if mouseOver and teamResign then
					font:Print(Spring.I18N('ui.topbar.hint.'..mouseOver), quitscreenTeamResignArea[1] - buttonMargin , quitscreenArea[2] + (2.5*fontSize / 3), fontSize*0.9, "cn")
				end
			end

			-- quit button
			if gameIsOver or not chobbyLoaded then
				if mathIsInRect(mx, my, quitscreenQuitArea[1], quitscreenQuitArea[2], quitscreenQuitArea[3], quitscreenQuitArea[4]) then
					color1 = { 0.4, 0, 0, 0.4 + (0.5 * fadeProgress) }
					color2 = { 0.6, 0.05, 0.05, 0.4 + (0.5 * fadeProgress) }
				else
					color1 = { 0.25, 0, 0, 0.35 + (0.5 * fadeProgress) }
					color2 = { 0.5, 0, 0, 0.35 + (0.5 * fadeProgress) }
				end
				UiButton(quitscreenQuitArea[1], quitscreenQuitArea[2], quitscreenQuitArea[3], quitscreenQuitArea[4], 1,1,1,1, 1,1,1,1, nil, color1, color2, padding * 0.5)
				font2:Print(Spring.I18N('ui.topbar.quit.quit'), quitscreenQuitArea[1] + ((quitscreenQuitArea[3] - quitscreenQuitArea[1]) / 2), quitscreenQuitArea[2] + ((quitscreenQuitArea[4] - quitscreenQuitArea[2]) / 2) - (fontSize / 3), fontSize, "con")
			end

			font2:End()
		end
	end)

	-- background
	if WG['guishader'] then
		WG['guishader'].setScreenBlur(true)
		WG['guishader'].insertRenderDlist(dlistQuit)
	else
		glCallList(dlistQuit)
	end
end

local function drawUiBackground()
	if showResourceBars then
		if resbarArea.energy[1] then
			UiElement(resbarArea.energy[1], resbarArea.energy[2], resbarArea.energy[3], resbarArea.energy[4], 0, 0, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil)
		end
		if resbarArea.metal[1] then
			UiElement(resbarArea.metal[1], resbarArea.metal[2], resbarArea.metal[3], resbarArea.metal[4], 0, 0, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil)
		end
	end
	if comsArea[1] then
		UiElement(comsArea[1], comsArea[2], comsArea[3], comsArea[4], 0, 0, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil)
	end
	if windArea[1] then
		UiElement(windArea[1], windArea[2], windArea[3], windArea[4], 0, 0, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil)
	end
	if displayTidalSpeed and tidalarea[1] then
		UiElement(tidalarea[1], tidalarea[2], tidalarea[3], tidalarea[4], 0, 0, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil)
	end
	if showButtons and buttonsArea[1] then
		UiElement(buttonsArea[1], buttonsArea[2], buttonsArea[3], buttonsArea[4], 0, 0, 0, 1, nil, nil, nil, nil, nil, nil, nil, nil)
	end
end

local function drawUi()
	if showButtons and dlistButtons then
		glCallList(dlistButtons)
	end
	if showResourceBars and dlistResbar.energy and dlistResbar.energy[1] then
		glCallList(dlistResbar.energy[1])
		glCallList(dlistResbar.metal[1])
	end

	-- min and max wind
	local fontsize = (height / 3.7) * widgetScale
	if not windFunctions.isNoWind() then
		font2:Begin(useRenderToTexture)
		font2:Print("\255\210\210\210" .. minWind, windArea[3] - (2.8 * widgetScale), windArea[4] - (4.5 * widgetScale) - (fontsize / 2), fontsize, 'or')
		font2:Print("\255\210\210\210" .. maxWind, windArea[3] - (2.8 * widgetScale), windArea[2] + (4.5 * widgetScale), fontsize, 'or')
		-- uncomment below to display average wind speed on UI
		-- font2:Print("\255\210\210\210" .. avgWindValue, area[1] + (2.8 * widgetScale), area[2] + (4.5 * widgetScale), fontsize, '')
		font2:End()
	else
		font2:Begin(useRenderToTexture)
		--font2:Print("\255\200\200\200no wind", windArea[1] + ((windArea[3] - windArea[1]) / 2), windArea[2] + ((windArea[4] - windArea[2]) / 2.05) - (fontsize / 5), fontsize, 'oc') -- Wind speed text
		font2:Print("\255\200\200\200" .. Spring.I18N('ui.topbar.wind.nowind1'), windArea[1] + ((windArea[3] - windArea[1]) / 2), windArea[2] + ((windArea[4] - windArea[2]) / 1.5) - (fontsize / 5), fontsize*1.06, 'oc') -- Wind speed text
		font2:Print("\255\200\200\200" .. Spring.I18N('ui.topbar.wind.nowind2'), windArea[1] + ((windArea[3] - windArea[1]) / 2), windArea[2] + ((windArea[4] - windArea[2]) / 2.8) - (fontsize / 5), fontsize*1.06, 'oc') -- Wind speed text
		font2:End()
	end

	-- tidal speed
	if displayTidalSpeed then
		local fontSize = (height / 2.66) * widgetScale
		font2:Begin(useRenderToTexture)
		font2:Print("\255\255\255\255" .. tidalSpeed, tidalarea[1] + ((tidalarea[3] - tidalarea[1]) / 2), tidalarea[2] + ((tidalarea[4] - tidalarea[2]) / 2.05) - (fontSize / 5), fontSize, 'oc') -- Tidal speed text
		font2:End()
	end
end

-- --- OPTIMIZATION: Pre-defined functions for RenderToTexture to avoid creating closures.
local function renderUiBackground()
	gl.Translate(-1, -1, 0)
	gl.Scale(2 / (topbarArea[3]-topbarArea[1]), 2 / (topbarArea[4]-topbarArea[2]),	0)
	gl.Translate(-topbarArea[1], -topbarArea[2], 0)
	drawUiBackground()
end

local function renderUi()
	gl.Translate(-1, -1, 0)
	gl.Scale(2 / (topbarArea[3]-topbarArea[1]), 2 / (topbarArea[4]-topbarArea[2]),	0)
	gl.Translate(-topbarArea[1], -topbarArea[2], 0)
	drawUi()
end

local function renderWindText()
    gl.Translate(-1, -1, 0)
    gl.Scale(2 / (topbarArea[3]-topbarArea[1]), 2 / (topbarArea[4]-topbarArea[2]),	0)
    gl.Translate(-topbarArea[1], -topbarArea[2], 0)

    local fontSize = (height / 2.66) * widgetScale
    font2:Begin(useRenderToTexture)
    font2:SetOutlineColor(0,0,0,1)
    font2:Print("\255\255\255\255" .. currentWind, windArea[1] + ((windArea[3] - windArea[1]) / 2), windArea[2] + ((windArea[4] - windArea[2]) / 2.05) - (fontSize / 5), fontSize, 'oc') -- Wind speed text
    font2:End()
end

local function renderComCounter()
    gl.Translate(-1, -1, 0)
    gl.Scale(2 / (topbarArea[3]-topbarArea[1]), 2 / (topbarArea[4]-topbarArea[2]),	0)
    gl.Translate(-topbarArea[1], -topbarArea[2], 0)

    if allyComs == 1 and (gameFrame % 12 < 6) then
        gl.Color(1, 0.6, 0, 0.45)
    else
        gl.Color(1, 1, 1, 0.22)
    end
    glCallList(dlistComs)
end

function widget:DrawScreen()
	now = os.clock()

	if showButtons ~= prevShowButtons then
		prevShowButtons = showButtons
		refreshUi = true
	end

	if useRenderToTexture then
		if refreshUi then
			if uiBgTex then
				gl.DeleteTexture(uiBgTex)
			end
			uiBgTex = gl.CreateTexture(mathFloor(topbarArea[3]-topbarArea[1]), mathFloor(topbarArea[4]-topbarArea[2]), {
				target = GL.TEXTURE_2D,
				format = GL.ALPHA,
				fbo = true,
			})
			if uiTex then
				gl.DeleteTexture(uiTex)
			end
			uiTex = gl.CreateTexture(mathFloor(topbarArea[3]-topbarArea[1]), mathFloor(topbarArea[4]-topbarArea[2]), {	--*(vsy<1400 and 2 or 1)
				target = GL.TEXTURE_2D,
				format = GL.ALPHA,
				fbo = true,
			})

			if uiBgTex then
				gl.R2tHelper.RenderToTexture(uiBgTex, renderUiBackground, useRenderToTexture)
			end
			if uiTex then
				gl.R2tHelper.RenderToTexture(uiTex, renderUi, useRenderToTexture)
			end

			if WG['guishader'] then
				if uiBgList then glDeleteList(uiBgList) end
				uiBgList = glCreateList(function()
					gl.Color(1,1,1,1)
					gl.Texture(uiBgTex)
					gl.TexRect(topbarArea[1], topbarArea[2], topbarArea[3], topbarArea[4], false, true)
					gl.Texture(false)
				end)
				WG['guishader'].InsertDlist(uiBgList, 'topbar_background')
			end

		end

		if uiBgTex then
			gl.R2tHelper.BlendTexRect(uiBgTex, topbarArea[1], topbarArea[2], topbarArea[3], topbarArea[4], useRenderToTexture)
			-- gl.Color(1, 1, 1, ui_opacity * 1.1)
			-- gl.Texture(uiBgTex)
			-- gl.TexRect(topbarArea[1], topbarArea[2], topbarArea[3], topbarArea[4], false, true)
		end

	else	-- not useRenderToTexture

		if refreshUi then
			if uiBgList then glDeleteList(uiBgList) end
			uiBgList = glCreateList(function()
				drawUiBackground()
				gl.Color(1, 1, 1, 1)	-- withouth this no guishader effects for other elements
			end)
			if WG['guishader'] then
				WG['guishader'].InsertDlist(uiBgList, 'topbar_background')
			end
		end

		glCallList(uiBgList)
	end

	if dlistWind1 then
		gl.PushMatrix()
		glCallList(dlistWind1)
		gl.Rotate(windRotation, 0, 0, 1)
		glCallList(dlistWind2)
		gl.PopMatrix()

		-- current wind
		if not useRenderToTexture then
			if gameFrame > 0 and not windFunctions.isNoWind() then
				if not dlistWindText[currentWind] then
					local fontSize = (height / 2.66) * widgetScale
					dlistWindText[currentWind] = glCreateList(function()
						font2:Begin(useRenderToTexture)
						font2:SetOutlineColor(0,0,0,1)
						font2:Print("\255\255\255\255" .. currentWind, windArea[1] + ((windArea[3] - windArea[1]) / 2), windArea[2] + ((windArea[4] - windArea[2]) / 2.05) - (fontSize / 5), fontSize, 'oc') -- Wind speed text
						font2:End()
					end)
				end
				glCallList(dlistWindText[currentWind])
			end
		end
	end

	if displayTidalSpeed and tidaldlist2 then
		gl.PushMatrix()
		gl.Translate(tidalarea[1] + ((tidalarea[3] - tidalarea[1]) / 2), math.sin(now/math.pi) * tidalWaveAnimationHeight + tidalarea[2] + (bgpadding/2) + ((tidalarea[4] - tidalarea[2]) / 2), 0)
		glCallList(tidaldlist2)
	end

	if useRenderToTexture and uiTex then
		gl.R2tHelper.BlendTexRect(uiTex, topbarArea[1], topbarArea[2], topbarArea[3], topbarArea[4], useRenderToTexture)
	end

	-- current wind
	if gameFrame > 0 and not windFunctions.isNoWind() then
		if useRenderToTexture then
			if currentWind ~= prevWind or refreshUi then
				prevWind = currentWind

				gl.R2tHelper.RenderToTexture(uiTex,
					renderWindText,
					useRenderToTexture,
					{windArea[1]-topbarArea[1], (topbarArea[4]-topbarArea[2])*0.33, windArea[3]-windArea[1], (topbarArea[4]-topbarArea[2])*0.4}
				)
			end
		end
	end

	drawResBars()

	gl.PushMatrix()
	if displayComCounter and dlistComs then

		-- commander counter
		if useRenderToTexture then
			if comsDlistUpdate or prevComAlert == nil or (prevComAlert ~= (allyComs == 1 and (gameFrame % 12 < 6))) then
				prevComAlert = (allyComs == 1 and (gameFrame % 12 < 6))
				comsDlistUpdate = nil

				gl.R2tHelper.RenderToTexture(uiTex,
					renderComCounter,
					useRenderToTexture,
					{comsArea[1]-topbarArea[1], 0, comsArea[3]-comsArea[1], (topbarArea[4]-topbarArea[2])}
				)
			end
		else
			if allyComs == 1 and (gameFrame % 12 < 6) then
				gl.Color(1, 0.6, 0, 0.45)
			else
				gl.Color(1, 1, 1, 0.22)
			end
			glCallList(dlistComs)
		end
	end

	if autoHideButtons then
		if buttonsArea[1] and hoveringTopbar == 'menu' then
			if not showButtons then
				showButtons = true
			end
		elseif showButtons then
			showButtons = false
		end
	end

	if showButtons and dlistButtons and buttonsArea['buttons'] then
		if not useRenderToTexture then
			glCallList(dlistButtons)
		end

		-- changelog changes highlight
		if WG['changelog'] and WG['changelog'].haschanges() then
			local button = 'changelog'
			local paddingsize = 1
			RectRound(buttonsArea['buttons'][button][1]+paddingsize, buttonsArea['buttons'][button][2]+paddingsize, buttonsArea['buttons'][button][3]-paddingsize, buttonsArea['buttons'][button][4]-paddingsize, 3.5 * widgetScale, 0, 0, 0, button == firstButton and 1 or 0, { 1,1,1, 0.1*blinkProgress })
		end

		-- hovered?
		if not showQuitscreen and buttonsArea['buttons'] and hoveringTopbar == 'menu' then
			for button, pos in pairs(buttonsArea['buttons']) do
				if mathIsInRect(mx, my, pos[1], pos[2], pos[3], pos[4]) then
					local paddingsize = 1
					RectRound(buttonsArea['buttons'][button][1]+paddingsize, buttonsArea['buttons'][button][2]+paddingsize, buttonsArea['buttons'][button][3]-paddingsize, buttonsArea['buttons'][button][4]-paddingsize, 3.5 * widgetScale, 0, 0, 0, button == firstButton and 1 or 0, { 0,0,0, 0.06 })
					glBlending(GL.SRC_ALPHA, GL.ONE)
					RectRound(buttonsArea['buttons'][button][1], buttonsArea['buttons'][button][2], buttonsArea['buttons'][button][3], buttonsArea['buttons'][button][4], 3.5 * widgetScale, 0, 0, 0, button == firstButton and 1 or 0, { 1, 1, 1, mb and 0.13 or 0.03 }, { 0.44, 0.44, 0.44, mb and 0.4 or 0.2 })
					local mult = 1
					RectRound(buttonsArea['buttons'][button][1], buttonsArea['buttons'][button][4] - ((buttonsArea['buttons'][button][4] - buttonsArea['buttons'][button][2]) * 0.4), buttonsArea['buttons'][button][3], buttonsArea['buttons'][button][4], 3.3 * widgetScale, 0, 0, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.18 * mult })
					RectRound(buttonsArea['buttons'][button][1], buttonsArea['buttons'][button][2], buttonsArea['buttons'][button][3], buttonsArea['buttons'][button][2] + ((buttonsArea['buttons'][button][4] - buttonsArea['buttons'][button][2]) * 0.25), 3.3 * widgetScale, 0, 0, 0, button == firstButton and 1 or 0, { 1, 1, 1, 0.045 * mult }, { 1, 1, 1, 0 })
					glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
					break
				end
			end
		end
	end

	if dlistQuit then
		if WG['guishader'] then WG['guishader'].removeRenderDlist(dlistQuit) end
		glDeleteList(dlistQuit)
		dlistQuit = nil
	end

	if showQuitscreen then
		drawQuitScreen()
	end

	gl.Color(1, 1, 1, 1)
	gl.PopMatrix()

	refreshUi = false
end

local function adjustSliders(x, y)
	if draggingShareIndicator and not spec then
		local shareValue = (x - resbarDrawinfo[draggingShareIndicator]['barArea'][1]) / (resbarDrawinfo[draggingShareIndicator]['barArea'][3] - resbarDrawinfo[draggingShareIndicator]['barArea'][1])
		if shareValue < 0 then shareValue = 0 end
		if shareValue > 1 then shareValue = 1 end
		Spring.SetShareLevel(draggingShareIndicator, shareValue)
		draggingShareIndicatorValue[draggingShareIndicator] = shareValue
		updateResbar(draggingShareIndicator)
	end

	if draggingConversionIndicator and not spec then
		local convValue = mathFloor((x - resbarDrawinfo['energy']['barArea'][1]) / (resbarDrawinfo['energy']['barArea'][3] - resbarDrawinfo['energy']['barArea'][1]) * 100)
		if convValue < 12 then convValue = 12 end
		if convValue > 88 then convValue = 88 end
		Spring.SendLuaRulesMsg(stringFormat(string.char(137) .. '%i', convValue))
		draggingConversionIndicatorValue = convValue
		updateResbar('energy')
	end
end

function widget:MouseMove(x, y)
	adjustSliders(x, y)
end

local function closeWindow(name)
	if WG[name] ~= nil and WG[name].isvisible() then
		WG[name].toggle(false)
		return true
	end
	return false
end

local function hideWindows()
	local closedWindow = false
	closedWindow = closeWindow('options') or closedWindow
	closedWindow = closeWindow('scavengerinfo') or closedWindow
	closedWindow = closeWindow('keybinds') or closedWindow
	closedWindow = closeWindow('changelog') or closedWindow
	closedWindow = closeWindow('gameinfo') or closedWindow
	closedWindow = closeWindow('teamstats') or closedWindow
	closedWindow = closeWindow('widgetselector') or closedWindow
	if showQuitscreen then closedWindow = true end

	showQuitscreen = nil

	if WG['guishader'] then WG['guishader'].setScreenBlur(false) end

	if gameIsOver then -- Graphs window can only be open after game end
		-- Closing Graphs window if open, no way to tell if it was open or not
		Spring.SendCommands('endgraph 0')
		graphsWindowVisible = false
	end

	return closedWindow
end

local function toggleWindow(name)
	local isvisible = false
	if WG[name] ~= nil then
		isvisible = WG[name].isvisible()
	end
	hideWindows()
	if WG[name] ~= nil and isvisible ~= true then
		WG[name].toggle()
	end
	return isvisible
end

local function applyButtonAction(button)
	if playSounds then Spring.PlaySoundFile(leftclick, 0.8, 'ui') end

	local isvisible = false
	if button == 'quit' or button == 'resign' then
		if not gameIsOver and chobbyLoaded and button == 'quit' then
			Spring.SendLuaMenuMsg("showLobby")
		else
			local oldShowQuitscreen
			if showQuitscreen then
				oldShowQuitscreen = showQuitscreen
				isvisible = true
			end

			hideWindows()

			if oldShowQuitscreen then
				if isvisible ~= true then
					showQuitscreen = oldShowQuitscreen
					if WG['guishader'] then WG['guishader'].setScreenBlur(true) end
				end
			else
				showQuitscreen = now
			end
		end
	elseif button == 'options' then
		toggleWindow('options')
	elseif button == 'save' then
		if isSinglePlayer and allowSavegame and WG['savegame'] then
			local time = os.date("%Y%m%d_%H%M%S")
			Spring.SendCommands("savegame "..time)
		end
	elseif button == 'scavengers' then
		toggleWindow('scavengerinfo')
	elseif button == 'keybinds' then
		toggleWindow('keybinds')
	elseif button == 'changelog' then
		toggleWindow('changelog')
	elseif button == 'stats' then
		toggleWindow('teamstats')
	elseif button == 'graphs' then
		isvisible = graphsWindowVisible
		hideWindows()
		if gameIsOver and not isvisible then
			Spring.SendCommands('endgraph 2')
			graphsWindowVisible = true
		end
	end
end

function widget:GameOver()
	refreshUi = true
	gameIsOver = true
	updateButtons()
end

function widget:MouseWheel(up, value) -- up = true/false , value = -1/1
	if showQuitscreen and quitscreenArea then return true end
end

function widget:KeyPress(key)
	if key == 27 then -- ESC
		if not WG['options'] or (WG['options'].disallowEsc and not WG['options'].disallowEsc()) then
			local escDidSomething = hideWindows()
			if escapeKeyPressesQuit and not escDidSomething then
				applyButtonAction('quit')
			end
		end
	end
	if showQuitscreen and quitscreenArea then return true end
end

function widget:MousePress(x, y, button)
	if button == 1 then
		if showQuitscreen and quitscreenArea then
			if mathIsInRect(x, y, quitscreenArea[1], quitscreenArea[2], quitscreenArea[3], quitscreenArea[4]) then
				if (gameIsOver or not chobbyLoaded or not spec) and mathIsInRect(x, y, quitscreenStayArea[1], quitscreenStayArea[2], quitscreenStayArea[3], quitscreenStayArea[4]) then
					if playSounds then Spring.PlaySoundFile(leftclick, 0.75, 'ui') end

					showQuitscreen = nil
					if WG['guishader'] then WG['guishader'].setScreenBlur(false) end
				end
				if (gameIsOver or not chobbyLoaded) and mathIsInRect(x, y, quitscreenQuitArea[1], quitscreenQuitArea[2], quitscreenQuitArea[3], quitscreenQuitArea[4]) then
					if playSounds then Spring.PlaySoundFile(leftclick, 0.75, 'ui') end

					if not chobbyLoaded then
						Spring.SendCommands("QuitForce") -- Exit the game completely
					else
						Spring.SendCommands("ReloadForce") -- Exit to the lobby
					end

					showQuitscreen = nil
					hideQuitWindow = now
				end
				if not spec and not gameIsOver and mathIsInRect(x, y, quitscreenResignArea[1], quitscreenResignArea[2], quitscreenResignArea[3], quitscreenResignArea[4]) then
					if playSounds then Spring.PlaySoundFile(leftclick, 0.75, 'ui') end
					Spring.SendCommands("spectator")
					showQuitscreen = nil
					if WG['guishader'] then WG['guishader'].setScreenBlur(false) end
				end
				if not spec and not gameIsOver and teamResign and mathIsInRect(x, y, quitscreenTeamResignArea[1], quitscreenTeamResignArea[2], quitscreenTeamResignArea[3], quitscreenTeamResignArea[4]) then
					if playSounds then Spring.PlaySoundFile(leftclick, 0.75, 'ui') end
					Spring.SendCommands("say !cv resign")
					showQuitscreen = nil
					if WG['guishader'] then WG['guishader'].setScreenBlur(false) end
				end
			else
				showQuitscreen = nil
				if WG['guishader'] then WG['guishader'].setScreenBlur(false) end
			end
			return true
		end

		if not spec then
			if not isSingle then
				if mathIsInRect(x, y, shareIndicatorArea['metal'][1], shareIndicatorArea['metal'][2], shareIndicatorArea['metal'][3], shareIndicatorArea['metal'][4]) then
					draggingShareIndicator = 'metal'
				end

				if mathIsInRect(x, y, shareIndicatorArea['energy'][1], shareIndicatorArea['energy'][2], shareIndicatorArea['energy'][3], shareIndicatorArea['energy'][4]) then
					draggingShareIndicator = 'energy'
				end
			end

			if not draggingShareIndicator and mathIsInRect(x, y, conversionIndicatorArea[1], conversionIndicatorArea[2], conversionIndicatorArea[3], conversionIndicatorArea[4]) then
				draggingConversionIndicator = true
			end

			if draggingShareIndicator or draggingConversionIndicator then
				if playSounds then Spring.PlaySoundFile(resourceclick, 0.7, 'ui') end
				return true
			end
		end

		if buttonsArea['buttons'] then
			for button, pos in pairs(buttonsArea['buttons']) do
				if mathIsInRect(x, y, pos[1], pos[2], pos[3], pos[4]) then
					applyButtonAction(button)
					return true
				end
			end
		end
	else
		if showQuitscreen and quitscreenArea then return true end
	end

	if hoveringTopbar then return true end
end

function widget:MouseRelease(x, y, button)
	if showQuitscreen and quitscreenArea then return true end

	if draggingShareIndicator then
		adjustSliders(x, y)
		draggingShareIndicator = nil
	end
	if draggingConversionIndicator then
		adjustSliders(x, y)
		draggingConversionIndicator = nil
	end
end

function widget:PlayerChanged()
	local prevMyTeamID = myTeamID
	local prevSpec = spec
	spec = spGetSpectatingState()
	checkSelfStatus()
	numTeamsInAllyTeam = #Spring.GetTeamList(myAllyTeamID)
	if displayComCounter then countComs(true) end
	if spec then
		resbarHover = nil
		if prevMyTeamID ~= myTeamID then
			r = { metal = { spGetTeamResources(myTeamID, 'metal') }, energy = { spGetTeamResources(myTeamID, 'energy') } }
			smoothedResources = r
		end
	end

	if not prevSpec and prevSpec ~= spec then
		init()
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if isCommander[unitDefID] then
		if select(6, Spring.GetTeamInfo(unitTeam, false)) == myAllyTeamID then
			allyComs = allyComs + 1
		elseif spec then
			enemyComs = enemyComs + 1
		end
		comcountChanged = true
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if isCommander[unitDefID] then
		if select(6, Spring.GetTeamInfo(unitTeam, false)) == myAllyTeamID then
			allyComs = allyComs - 1
		elseif spec then
			enemyComs = enemyComs - 1
		end
		comcountChanged = true
	end
end

function widget:LanguageChanged()
	widget:ViewResize()
end

function widget:Initialize()
	gameFrame = spGetGameFrame()
	Spring.SendCommands("resbar 0")

	-- determine if we want to show comcounter
	local allteams = Spring.GetTeamList()
	local teamN = table.maxn(allteams) - 1               --remove gaia
	if teamN > 2 then displayComCounter = true end

	if UnitDefs[Spring.GetTeamRulesParam(Spring.GetMyTeamID(), 'startUnit')] then
		textures.com = ':n:Icons/'..UnitDefs[Spring.GetTeamRulesParam(Spring.GetMyTeamID(), 'startUnit')].name..'.png'
	end

	for _, teamID in ipairs(myAllyTeamList) do
		if select(4,Spring.GetTeamInfo(teamID,false)) then	-- is AI?
			local luaAI = Spring.GetTeamLuaAI(teamID)
			if luaAI and luaAI ~= "" and (string.find(luaAI, 'Scavengers') or string.find(luaAI, 'Raptors')) then
				supressOverflowNotifs = true
				break
			end
		end
	end

	if Spring.GetMenuName and string.find(string.lower(Spring.GetMenuName()), 'chobby') then
		chobbyLoaded = true
		Spring.SendLuaMenuMsg("disableLobbyButton")
	end

	if not spec then
		local teamList = Spring.GetTeamList(myAllyTeamID) or {}
		isSingle = #teamList == 1
	end

	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.customParams.iscommander or unitDef.customParams.isscavcommander then
			isCommander[unitDefID] = true
			commanderUnitDefIDs[#commanderUnitDefIDs + 1] = unitDefID
		end
	end

	WG['topbar'] = {}

	WG['topbar'].showingQuit = function()
		return (showQuitscreen)
	end

	WG['topbar'].hideWindows = function()
		hideWindows()
	end

	WG['topbar'].setAutoHideButtons = function(value)
		refreshUi = true
		autoHideButtons = value
		showButtons = not value
		updateButtons()
	end

	WG['topbar'].getAutoHideButtons = function()
		return autoHideButtons
	end

	WG['topbar'].getShowButtons = function()
		return showButtons
	end

	WG['topbar'].updateTopBarEnergy = function(value)
		draggingConversionIndicatorValue = value
		updateResbar('energy')
	end

	WG['topbar'].setResourceBarsVisible = function(visible)
		showResourceBars = visible
		refreshUi = true
	end

	WG['topbar'].getResourceBarsVisible = function()
		return showResourceBars
	end

	updateAvgWind()
	updateWindRisk()

	widget:ViewResize()

	if gameFrame > 0 then
		widget:GameStart()
	end

	if WG['resource_spot_finder'] and WG['resource_spot_finder'].metalSpotsList and #WG['resource_spot_finder'].metalSpotsList > 0 and #WG['resource_spot_finder'].metalSpotsList <= 2 then	-- probably speedmetal kind of map
		isMetalmap = true
	end
end

function widget:Shutdown()
	--Spring.SendCommands("resbar 1")

	if dlistButtons then
		dlistWind1 = glDeleteList(dlistWind1)
		dlistWind2 = glDeleteList(dlistWind2)
		tidaldlist2 = glDeleteList(tidaldlist2)
		dlistComs = glDeleteList(dlistComs)
		dlistButtons = glDeleteList(dlistButtons)
		dlistQuit = glDeleteList(dlistQuit)

		for n, _ in pairs(dlistWindText) do dlistWindText[n] = glDeleteList(dlistWindText[n]) end
		for n, _ in pairs(dlistResbar['metal']) do dlistResbar['metal'][n] = glDeleteList(dlistResbar['metal'][n]) end
		for n, _ in pairs(dlistResbar['energy']) do dlistResbar['energy'][n] = glDeleteList(dlistResbar['energy'][n]) end
		for res, _ in pairs(dlistResValues) do dlistResValues[res] = glDeleteList(dlistResValues[res]) end
		for res, _ in pairs(dlistResValuesBar) do dlistResValuesBar[res] = glDeleteList(dlistResValuesBar[res]) end
	end

	if uiBgTex then
		gl.DeleteTexture(uiBgTex)
		uiBgTex = nil
	end
	if uiTex then
		gl.DeleteTexture(uiTex)
		uiTex = nil
	end

	if WG['guishader'] then
		WG['guishader'].DeleteDlist('topbar_background')
	end

	if WG['tooltip'] then
		WG['tooltip'].RemoveTooltip('coms')
		WG['tooltip'].RemoveTooltip('wind')
		local res = 'energy'
		WG['tooltip'].RemoveTooltip(res .. '_share_slider')
		WG['tooltip'].RemoveTooltip(res .. '_share_slider2')
		WG['tooltip'].RemoveTooltip(res .. '_metalmaker_slider')
		WG['tooltip'].RemoveTooltip(res .. '_pull')
		WG['tooltip'].RemoveTooltip(res .. '_income')
		WG['tooltip'].RemoveTooltip(res .. '_storage')
		WG['tooltip'].RemoveTooltip(res .. '_current')
		res = 'metal'
		WG['tooltip'].RemoveTooltip(res .. '_share_slider')
		WG['tooltip'].RemoveTooltip(res .. '_share_slider2')
		WG['tooltip'].RemoveTooltip(res .. '_pull')
		WG['tooltip'].RemoveTooltip(res .. '_income')
		WG['tooltip'].RemoveTooltip(res .. '_storage')
		WG['tooltip'].RemoveTooltip(res .. '_current')
	end

	WG['topbar'] = nil
end

function widget:GetConfigData()
	return { autoHideButtons = autoHideButtons }
end

function widget:SetConfigData(data)
	if data.autoHideButtons then autoHideButtons = data.autoHideButtons end
end




