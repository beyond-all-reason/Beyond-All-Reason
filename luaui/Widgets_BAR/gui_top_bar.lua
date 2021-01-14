function widget:GetInfo()
	return {
		name = "Top Bar",
		desc = "Shows Resources, wind speed, commander counter, and various options.",
		author = "Floris",
		date = "Feb, 2017",
		license = "GNU GPL, v2 or later",
		layer = -9999999,
		enabled = true, --enabled by default
		handler = true, --can use widgetHandler:x()
	}
end

local texts = {        -- fallback (if you want to change this, also update: language/en.lua, or it will be overwritten)
	button = {
		quit = 'Quit',
		resign = 'Resign',
		lobby = 'Lobby',
		settings = 'Settings',
		changes = 'Changes',
		commands = 'Cmd',
		keys = 'Keys',
		scavengers = 'Scavengers',
		stats = 'Stats',
	},
	quit = {
		quit = 'Quit',
		resign = 'Resign',
		really_quit = 'Really want to quit?',
		really_quitresign = 'Want to resign or quit to desktop?',
		really_resign = 'Sure you want to give up?',
		really_resign2 = 'Sure you want to give up and spectate?',
	},
	catchingup = 'Catching up',
	catchingup_tooltip = 'Displays the catchup progress',
	comcount_tooltip = '\255\215\255\215Commander Counter\n\255\240\240\240Displays the number of ally\nand enemy commanders',
	wind = {
		nowind1 = 'no',
		nowind2 = 'wind',
		tooltip = '\255\215\255\215Wind Display\n\255\240\240\240Displays current wind strength (small numbers are minimum and maximum)\n\255\255\215\215Rather build solars when average\n\255\255\215\215wind is below 5 (armada) or 6 (cortex)',
		worth1 = 'Wind isnt worth',
		worth2 = 'Wind is viable',
		worth3 = 'Average wind is okay',
		worth4 = 'Average wind is good',
		worth5 = 'Average wind is really good',
		worth6 = 'Wind is insanely good',
	},
	resbar = {
		metal = 'metal',
		energy = 'energy',
		overflowing = 'Overflowing',
		wastingmetal = 'Wasting Metal',
		wastingenergy = 'Wasting Energy',
		overflowing_energy_tooltip = 'Energy Share Slider\n\255\240\240\240Overflowing to your team when energy goes beyond this point',
		overflowing_metal_tooltip = 'Metal Share Slider\n\255\240\240\240Overflowing to your team when metal goes beyond this point',
		energyconversion_tooltip = '\255\215\255\215Energy Conversion slider\n\255\240\240\240Excess energy beyond this point will be\nconverted to metal\n(by your Energy Converter units)',
		pull_tooltip = 'spending (per second)',
		income_tooltip = 'income (per second)',
		expense_tooltip = 'potential spending  (per second)',
		storage_tooltip = 'storage',
		conversion_tooltip = '\255\215\255\215Energy Conversion slider\n\255\240\240\240Excess energy beyond this point will be\nconverted to metal\n(by your Energy Converter units)',
		current_energy_tooltip = 'Share to a specific player by...\n1) Using the (adv)playerlist,\n    dragging up the energy icon at the rightside.\n2) An interface brought up with the H key.',
		current_metal_tooltip = 'Share to a specific player by...\n1) Using the (adv)playerlist,\n    dragging up the metal icon at the rightside.\n2) An interface brought up with the H key.',
	},
}

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity", 0.6) or 0.6)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")

local vsx, vsy = Spring.GetViewGeometry()

local orgHeight = 46
local height = orgHeight * (1 + (ui_scale - 1) / 1.7)

local escapeKeyPressesQuit = false

local relXpos = 0.3
local borderPadding = 5
local showConversionSlider = true
local bladeSpeedMultiplier = 0.2

local noiseBackgroundTexture = ":g:LuaUI/Images/rgbnoise.png"
local stripesTexture = "LuaUI/Images/stripes.png"
local buttonBackgroundTexture = "LuaUI/Images/vr_grid.png"
local buttonBgtexScale = 1.9	-- lower = smaller tiles
local buttonBgtexOpacity = 0
local buttonBgtexSize
local backgroundTexture = "LuaUI/Images/backgroundtile.png"
local ui_tileopacity = tonumber(Spring.GetConfigFloat("ui_tileopacity", 0.012) or 0.012)
local bgtexScale = tonumber(Spring.GetConfigFloat("ui_tilescale", 7) or 7)	-- lower = smaller tiles
local bgtexSize

local armcomDefID = UnitDefNames.armcom.id
local corcomDefID = UnitDefNames.corcom.id

local playSounds = true
local leftclick = 'LuaUI/Sounds/tock.wav'
local resourceclick = 'LuaUI/Sounds/buildbar_click.wav'
local middleclick = 'LuaUI/Sounds/buildbar_click.wav'
local rightclick = 'LuaUI/Sounds/buildbar_rem.wav'

local barGlowCenterTexture = ":l:LuaUI/Images/barglow-center.png"
local barGlowEdgeTexture = ":l:LuaUI/Images/barglow-edge.png"
local bladesTexture = "LuaUI/Images/wind-blades.png"
local comTexture = ":l:Icons/corcom.png"		-- will be changed later to unit icon depending on faction
local glowTexture = ":l:LuaUI/Images/glow.dds"

local math_floor = math.floor
local math_min = math.min

local widgetScale = (0.80 + (vsx * vsy / 6000000))
local xPos = math_floor(vsx * relXpos)
local currentWind = 0
local currentTidal = 0
local gameStarted = (Spring.GetGameFrame() > 0)
local displayComCounter = false

local glTranslate = gl.Translate
local glColor = gl.Color
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTexture = gl.Texture
local glRect = gl.Rect
local glTexRect = gl.TexRect
local glText = gl.Text
local glRotate = gl.Rotate
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList

local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local spGetSpectatingState = Spring.GetSpectatingState
local spGetTeamResources = Spring.GetTeamResources
local spGetMyTeamID = Spring.GetMyTeamID
local spGetMouseState = Spring.GetMouseState
local spGetWind = Spring.GetWind


local widgetSpaceMargin = Spring.FlowUI.elementMargin
local bgpadding = Spring.FlowUI.elementPadding
local RectRound = Spring.FlowUI.Draw.RectRound
local TexturedRectRound = Spring.FlowUI.Draw.TexturedRectRound
local UiElement = Spring.FlowUI.Draw.Element
local UiButton = Spring.FlowUI.Draw.Button
local UiSliderKnob = Spring.FlowUI.Draw.SliderKnob


local gaiaTeamID = Spring.GetGaiaTeamID()
local spec = spGetSpectatingState()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local myTeamID = Spring.GetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()
local isReplay = Spring.IsReplay()
comTexture = ':l:Icons/'..UnitDefs[Spring.GetTeamRulesParam(myTeamID, 'startUnit')].name..'.png'

local numTeamsInAllyTeam = #Spring.GetTeamList(myAllyTeamID)

local sformat = string.format

local minWind = Game.windMin
local maxWind = Game.windMax
local windRotation = 0

local startComs = 0
local lastFrame = -1
local topbarArea = {}
local resbarArea = { metal = {}, energy = {} }
local resbarDrawinfo = { metal = {}, energy = {} }
local shareIndicatorArea = { metal = {}, energy = {} }
local dlistResbar = { metal = {}, energy = {} }
local energyconvArea = {}
local windArea = {}
local comsArea = {}
local rejoinArea = {}
local buttonsArea = {}
local dlistWindText = {}
local dlistResValues = { metal = {}, energy = {} }
local currentResValue = { metal = 1000, energy = 1000 }
local currentStorageValue = { metal = -1, energy = -1 }

local r = { metal = { spGetTeamResources(myTeamID, 'metal') }, energy = { spGetTeamResources(myTeamID, 'energy') } }

local showOverflowTooltip = {}

local allyComs = 0
local enemyComs = 0 -- if we are counting ourselves because we are a spec
local enemyComCount = 0 -- if we are receiving a count from the gadget part (needs modoption on)
local prevEnemyComCount = 0

local guishaderEnabled = false
local guishaderCheckUpdateRate = 0.5
local nextGuishaderCheck = guishaderCheckUpdateRate
local now = os.clock()
local gameFrame = Spring.GetGameFrame()

local draggingShareIndicatorValue = {}

local font, font2, bgpadding, chobbyInterface, firstButton, fontSize, comcountChanged, showQuitscreen, resbarHover
local draggingConversionIndicatorValue, draggingShareIndicator, draggingConversionIndicator
local conversionIndicatorArea, quitscreenArea, quitscreenQuitArea, quitscreenResignArea, hoveringTopbar, hideQuitWindow
local dlistButtonsGuishader, dlistRejoinGuishader, dlistComsGuishader, dlistButtonsGuishader, dlistWindGuishader, dlistQuit
--local dlistButtons1, dlistButtons2, dlistRejoin, dlistComs1, dlistComs2, dlistWind1, dlistWind2

local chobbyLoaded = false
if Spring.GetMenuName and string.find(string.lower(Spring.GetMenuName()), 'chobby') ~= nil then
	chobbyLoaded = true
	Spring.SendLuaMenuMsg("disableLobbyButton")
end

local numPlayers = 0
local numAllyTeams = #Spring.GetAllyTeamList() - 1
local singleTeams = false
local teams = Spring.GetTeamList()
if #teams - 1 == numAllyTeams then
	singleTeams = true
end
for i = 1, #teams do
	local _,_,_, isAiTeam = Spring.GetTeamInfo(teams[i], false)
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if (not luaAI or luaAI == '') and not isAiTeam and teams[i] ~= gaiaTeamID then
		numPlayers = numPlayers + 1
	end
end
local isSinglePlayer = numPlayers == 1

local allyteamOverflowingMetal = false
local allyteamOverflowingEnergy = false
local overflowingMetal = false
local overflowingEnergy = false

local isCommander = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.iscommander then
		isCommander[unitDefID] = true
	end
end

--------------------------------------------------------------------------------
-- Rejoin
--------------------------------------------------------------------------------

local showRejoinUI = false    -- indicate whether UI is shown or hidden.
local CATCH_UP_THRESHOLD = 6 * Game.gameSpeed    -- only show the window if behind this much
local UPDATE_RATE_F = 4 -- frames
local UPDATE_RATE_S = UPDATE_RATE_F / Game.gameSpeed
local serverFrame

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function isInBox(mx, my, box)
	return mx > box[1] and my > box[2] and mx < box[3] and my < box[4]
end

function widget:ViewResize()
	vsx, vsy = gl.GetViewSizes()
	widgetScale = (vsy / height) * 0.0425
	widgetScale = widgetScale * ui_scale
	xPos = math_floor(vsx * relXpos)

	widgetSpaceMargin = Spring.FlowUI.elementMargin
	bgpadding = Spring.FlowUI.elementPadding

	bgtexSize = bgpadding * bgtexScale
	buttonBgtexSize = bgpadding * buttonBgtexScale

	font = WG['fonts'].getFont(fontfile)
	font2 = WG['fonts'].getFont(fontfile2)

	for n, _ in pairs(dlistWindText) do
		dlistWindText[n] = glDeleteList(dlistWindText[n])
	end
	for n, _ in pairs(dlistResValues['metal']) do
		dlistResValues['metal'][n] = glDeleteList(dlistResValues['metal'][n])
	end
	for n, _ in pairs(dlistResValues['energy']) do
		dlistResValues['energy'][n] = glDeleteList(dlistResValues['energy'][n])
	end

	init()
end

local function DrawRectRoundCircle(x, y, z, radius, cs, centerOffset, color1, color2)
	if not color2 then
		color2 = color1
	end
	--centerOffset = 0
	local coords = {
		{ x - radius + cs, z + radius, y }, -- top left
		{ x + radius - cs, z + radius, y }, -- top right
		{ x + radius, z + radius - cs, y }, -- right top
		{ x + radius, z - radius + cs, y }, -- right bottom
		{ x + radius - cs, z - radius, y }, -- bottom right
		{ x - radius + cs, z - radius, y }, -- bottom left
		{ x - radius, z - radius + cs, y }, -- left bottom
		{ x - radius, z + radius - cs, y }, -- left top
	}
	local cs2 = cs * (centerOffset / radius)
	local coords2 = {
		{ x - centerOffset + cs2, z + centerOffset, y }, -- top left
		{ x + centerOffset - cs2, z + centerOffset, y }, -- top right
		{ x + centerOffset, z + centerOffset - cs2, y }, -- right top
		{ x + centerOffset, z - centerOffset + cs2, y }, -- right bottom
		{ x + centerOffset - cs2, z - centerOffset, y }, -- bottom right
		{ x - centerOffset + cs2, z - centerOffset, y }, -- bottom left
		{ x - centerOffset, z - centerOffset + cs2, y }, -- left bottom
		{ x - centerOffset, z + centerOffset - cs2, y }, -- left top
	}
	for i = 1, 8 do
		local i2 = (i >= 8 and 1 or i + 1)
		gl.Color(color2)
		gl.Vertex(coords[i][1], coords[i][2], coords[i][3])
		gl.Vertex(coords[i2][1], coords[i2][2], coords[i2][3])
		gl.Color(color1)
		gl.Vertex(coords2[i2][1], coords2[i2][2], coords2[i2][3])
		gl.Vertex(coords2[i][1], coords2[i][2], coords2[i][3])
	end
end
local function RectRoundCircle(x, y, z, radius, cs, centerOffset, color1, color2)
	gl.BeginEnd(GL.QUADS, DrawRectRoundCircle, x, y, z, radius, cs, centerOffset, color1, color2)
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
function DrawRect(px, py, sx, sy, zoom)
	gl.BeginEnd(GL.QUADS, RectQuad, px, py, sx, sy, zoom)
end

local function short(n, f)
	if (f == nil) then
		f = 0
	end
	if (n > 9999999) then
		return sformat("%." .. f .. "fm", n / 1000000)
	elseif (n > 9999) then
		return sformat("%." .. f .. "fk", n / 1000)
	else
		return sformat("%." .. f .. "f", n)
	end
end

local function updateRejoin()
	local area = rejoinArea

	local catchup = gameFrame / serverFrame

	-- add background blur
	if dlistRejoinGuishader ~= nil then
		if WG['guishader'] then
			WG['guishader'].RemoveDlist('topbar_rejoin')
		end
		glDeleteList(dlistRejoinGuishader)
	end
	dlistRejoinGuishader = glCreateList(function()
		RectRound(area[1], area[2], area[3], area[4], 5.5 * widgetScale, 0,0,1,1)
	end)

	if dlistRejoin ~= nil then
		glDeleteList(dlistRejoin)
	end
	dlistRejoin = glCreateList(function()

		UiElement(area[1], area[2], area[3], area[4], 0, 0, 1, 1)

		if WG['guishader'] then
			WG['guishader'].InsertDlist(dlistRejoinGuishader, 'topbar_rejoin')
		end

		local barHeight = math_floor((height * widgetScale / 7.5) + 0.5)
		local barHeightPadding = math_floor((9 * widgetScale) + 0.5) --((height/2) * widgetScale) - (barHeight/2)
		local barLeftPadding = barHeightPadding
		local barRightPadding = barHeightPadding
		local barArea = { area[1] + barLeftPadding, area[2] + barHeightPadding, area[3] - barRightPadding, area[2] + barHeight + barHeightPadding }
		local barWidth = barArea[3] - barArea[1]

		-- Bar background
		local edgeWidth = math.max(1, math_floor(vsy / 1100))
		local addedSize = math_floor(((barArea[4] - barArea[2]) * 0.15) + 0.5)
		RectRound(barArea[1] - addedSize - edgeWidth, barArea[2] - addedSize - edgeWidth, barArea[3] + addedSize + edgeWidth, barArea[4] + addedSize + edgeWidth, barHeight * 0.33, 1, 1, 1, 1, { 0, 0, 0, 0.03 }, { 0, 0, 0, 0.03 })
		RectRound(barArea[1] - addedSize, barArea[2] - addedSize, barArea[3] + addedSize, barArea[4] + addedSize, barHeight * 0.33, 1, 1, 1, 1, { 0.15, 0.15, 0.15, 0.2 }, { 0.8, 0.8, 0.8, 0.16 })

		gl.Texture(noiseBackgroundTexture)
		gl.Color(1,1,1, 0.18)
		TexturedRectRound(barArea[1] - addedSize - edgeWidth, barArea[2] - addedSize - edgeWidth, barArea[3] + addedSize + edgeWidth, barArea[4] + addedSize + edgeWidth, barHeight * 0.33, barWidth*0.6, 0)
		gl.Texture(false)

		-- gloss
		glBlending(GL_SRC_ALPHA, GL_ONE)
		RectRound(barArea[1] - addedSize, barArea[2] + addedSize, barArea[3] + addedSize, barArea[4] + addedSize, barHeight * 0.33, 1, 1, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.07 })
		RectRound(barArea[1] - addedSize, barArea[2] - addedSize, barArea[3] + addedSize, barArea[2] + addedSize + addedSize + addedSize, barHeight * 0.2, 0, 0, 1, 1, { 1, 1, 1, 0.1 }, { 1, 1, 1, 0.0 })
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

		-- Bar value
		local valueWidth = catchup * barWidth
		glColor(0, 1, 0, 1)
		RectRound(barArea[1], barArea[2], barArea[1] + valueWidth, barArea[4], barHeight * 0.2, 1, 1, 1, 1, { 0, 0.55, 0, 1 }, { 0, 1, 0, 1 })

		gl.Texture(stripesTexture)
		gl.Color(1,1,1, 0.16)
		TexturedRectRound(barArea[1], barArea[2], barArea[1] + valueWidth, barArea[4], barHeight * 0.2, 1, 1, 1, 1, (barArea[3]-barArea[1]) * 0.66, -os.clock()*0.06)
		gl.Texture(false)

		gl.Texture(noiseBackgroundTexture)
		gl.Color(1,1,1, 0.25)
		TexturedRectRound(barArea[1], barArea[2], barArea[1] + valueWidth, barArea[4], barHeight * 0.2, barWidth*0.6, 0)
		gl.Texture(false)

		-- Bar value highlight
		glBlending(GL_SRC_ALPHA, GL_ONE)
		RectRound(barArea[1], barArea[4] - ((barArea[4] - barArea[2]) / 1.5), barArea[1] + valueWidth, barArea[4], barHeight * 0.2, 1, 1, 1, 1, { 0, 0, 0, 0 }, { 1, 1, 1, 0.13 })
		RectRound(barArea[1], barArea[2], barArea[1] + valueWidth, barArea[2] + ((barArea[4] - barArea[2]) / 2), barHeight * 0.2, 1, 1, 1, 1, { 1, 1, 1, 0.13 }, { 0, 0, 0, 0 })

		-- Bar value glow
		local glowSize = barHeight * 6
		glColor(0, 1, 0, 0.08)
		glTexture(barGlowCenterTexture)
		DrawRect(barArea[1], barArea[2] - glowSize, barArea[1] + (catchup * barWidth), barArea[4] + glowSize, 0.008)
		glTexture(barGlowEdgeTexture)
		DrawRect(barArea[1] - (glowSize * 2), barArea[2] - glowSize, barArea[1], barArea[4] + glowSize, 0.008)
		DrawRect((barArea[1] + (catchup * barWidth)) + (glowSize * 2), barArea[2] - glowSize, barArea[1] + (catchup * barWidth), barArea[4] + glowSize, 0.008)
		glTexture(false)
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

		-- Text
		local fontsize = math.min(14 * widgetScale, ((area[3] - area[1])*0.88) / font:GetTextWidth(texts.catchingup))
		font2:Begin()
		font2:Print('\255\225\255\225'..texts.catchingup, area[1] + ((area[3] - area[1]) / 2), area[2] + barHeight * 2 + fontsize, fontsize, 'cor')
		font2:End()

	end)
	if WG['tooltip'] ~= nil then
		WG['tooltip'].AddTooltip('rejoin', area, texts.catchingup_tooltip)
	end
end

local function updateButtons()
	local area = buttonsArea

	local totalWidth = area[3] - area[1]

	local text = '    '

	if WG['scavengerinfo'] ~= nil then
		text = text .. texts.button.scavengers..'   '
	end
	if WG['teamstats'] ~= nil then
		text = text .. texts.button.stats..'   '
	end
	if WG['commands'] ~= nil then
		text = text .. texts.button.commands..'   '
	end
	if WG['keybinds'] ~= nil then
		text = text .. texts.button.keys..'   '
	end
	if WG['changelog'] ~= nil then
		text = text .. texts.button.changes..'   '
	end
	if WG['options'] ~= nil then
		text = text .. texts.button.settings..'   '
	end
	if chobbyLoaded then
		if not spec and gameStarted and not isSinglePlayer then
			text = text .. texts.button.resign..'  '
		end
		text = text .. texts.button.lobby..'  '
	else
		text = text .. texts.button.quit..'  '
	end

	local fontsize = totalWidth / font2:GetTextWidth(text)
	if fontsize > (height * widgetScale) / 3 then
		fontsize = (height * widgetScale) / 3
	end

	-- add background blur
	if dlistButtonsGuishader ~= nil then
		if WG['guishader'] then
			WG['guishader'].RemoveDlist('topbar_buttons')
		end
		glDeleteList(dlistButtonsGuishader)
	end
	dlistButtonsGuishader = glCreateList(function()
		RectRound(area[1], area[2], area[3], area[4], 5.5 * widgetScale, 0,0,1,1)
	end)

	if dlistButtons1 ~= nil then
		glDeleteList(dlistButtons1)
	end
	dlistButtons1 = glCreateList(function()

		UiElement(area[1], area[2], area[3], area[4], 0, 0, 0, 1)

		if WG['guishader'] then
			WG['guishader'].InsertDlist(dlistButtonsGuishader, 'topbar_buttons')
		end

		if buttonsArea['buttons'] == nil then
			buttonsArea['buttons'] = {}

			local margin = math_floor(3 * widgetScale)
			local offset = margin
			local width = 0
			local buttons = 0
			firstButton = nil
			if WG['scavengerinfo'] ~= nil then
				buttons = buttons + 1
				if buttons > 1 then
					offset = math_floor(offset + width + 0.5)
				end
				width = math_floor((font2:GetTextWidth('   '..texts.button.scavengers) * fontsize) + 0.5)
				buttonsArea['buttons']['scavengers'] = { area[1] + offset, area[2] + margin, area[1] + offset + width, area[4] }
				if not firstButton then
					firstButton = 'scavengers'
				end
			end
			if WG['teamstats'] ~= nil then
				buttons = buttons + 1
				if buttons > 1 then
					offset = math_floor(offset + width + 0.5)
				end
				width = math_floor((font2:GetTextWidth('    '..texts.button.stats) * fontsize) + 0.5)
				buttonsArea['buttons']['stats'] = { area[1] + offset, area[2] + margin, area[1] + offset + width, area[4] }
				if not firstButton then
					firstButton = 'stats'
				end
			end
			if WG['commands'] ~= nil then
				buttons = buttons + 1
				if buttons > 1 then
					offset = math_floor(offset + width + 0.5)
				end
				width = math_floor((font2:GetTextWidth('   '..texts.button.commands) * fontsize) + 0.5)
				buttonsArea['buttons']['commands'] = { area[1] + offset, area[2] + margin, area[1] + offset + width, area[4] }
				if not firstButton then
					firstButton = 'commands'
				end
			end
			if WG['keybinds'] ~= nil then
				buttons = buttons + 1
				if buttons > 1 then
					offset = math_floor(offset + width + 0.5)
				end
				width = math_floor((font2:GetTextWidth('   '..texts.button.keys) * fontsize) + 0.5)
				buttonsArea['buttons']['keybinds'] = { area[1] + offset, area[2] + margin, area[1] + offset + width, area[4] }
				if not firstButton then
					firstButton = 'keybinds'
				end
			end
			if WG['changelog'] ~= nil then
				buttons = buttons + 1
				if buttons > 1 then
					offset = math_floor(offset + width + 0.5)
				end
				width = math_floor((font2:GetTextWidth('   '..texts.button.changes) * fontsize) + 0.5)
				buttonsArea['buttons']['changelog'] = { area[1] + offset, area[2] + margin, area[1] + offset + width, area[4] }
				if not firstButton then
					firstButton = 'changelog'
				end
			end
			if WG['options'] ~= nil then
				buttons = buttons + 1
				if buttons > 1 then
					offset = math_floor(offset + width + 0.5)
				end
				width = math_floor((font2:GetTextWidth('   '..texts.button.settings) * fontsize) + 0.5)
				buttonsArea['buttons']['options'] = { area[1] + offset, area[2] + margin, area[1] + offset + width, area[4] }
				if not firstButton then
					firstButton = 'settings'
				end
			end
			if chobbyLoaded then
				if not spec and gameStarted and not isSinglePlayer then
					buttons = buttons + 1
					offset = math_floor(offset + width + 0.5)
					width = math_floor((font2:GetTextWidth('   '..texts.button.resign) * fontsize) + 0.5)
					buttonsArea['buttons']['resign'] = { area[1] + offset, area[2] + margin, area[1] + offset + width, area[4] }
				end
				offset = math_floor(offset + width + 0.5)
				width = math_floor((font2:GetTextWidth('    '..texts.button.lobby) * fontsize) + 0.5)
				buttonsArea['buttons']['quit'] = { area[1] + offset, area[2] + margin, area[3], area[4] }
			else
				offset = math_floor(offset + width + 0.5)
				width = math_floor((font2:GetTextWidth('    '..texts.button.quit) * fontsize) + 0.5)
				buttonsArea['buttons']['quit'] = { area[1] + offset, area[2] + margin, area[3], area[4] }
			end
		end
	end)

	if dlistButtons2 ~= nil then
		glDeleteList(dlistButtons2)
	end
	dlistButtons2 = glCreateList(function()
		font2:Begin()
		font2:Print('\255\240\240\240' .. text, area[1], area[2] + ((area[4] - area[2]) * 0.52) - (fontsize / 5), fontsize, 'o')
		font2:End()
	end)
end

local function updateComs(forceText)
	local area = comsArea

	-- add background blur
	if dlistComsGuishader ~= nil then
		if WG['guishader'] then
			WG['guishader'].RemoveDlist('topbar_coms')
		end
		glDeleteList(dlistComsGuishader)
	end
	dlistComsGuishader = glCreateList(function()
		RectRound(area[1], area[2], area[3], area[4], 5.5 * widgetScale, 0,0,1,1)
	end)

	if dlistComs1 ~= nil then
		glDeleteList(dlistComs1)
	end
	dlistComs1 = glCreateList(function()

		UiElement(area[1], area[2], area[3], area[4], 0, 0, 1, 1)

		if WG['guishader'] then
			WG['guishader'].InsertDlist(dlistComsGuishader, 'topbar_coms')
		end
	end)

	if dlistComs2 ~= nil then
		glDeleteList(dlistComs2)
	end
	dlistComs2 = glCreateList(function()
		-- Commander icon
		local sizeHalf = (height / 2.44) * widgetScale
		local yOffset = ((area[3] - area[1]) * 0.025)
		glTexture(comTexture)
		glTexRect(area[1] + ((area[3] - area[1]) / 2) - sizeHalf, area[2] + ((area[4] - area[2]) / 2) - sizeHalf +yOffset, area[1] + ((area[3] - area[1]) / 2) + sizeHalf, area[2] + ((area[4] - area[2]) / 2) + sizeHalf+yOffset)
		glTexture(false)

		-- Text
		if gameFrame > 0 or forceText then
			font2:Begin()
			local fontsize = (height / 2.85) * widgetScale
			font2:Print('\255\255\000\000' .. enemyComCount, area[3] - (2.8 * widgetScale), area[2] + (4.5 * widgetScale), fontsize, 'or')

			fontSize = (height / 2.15) * widgetScale
			font2:Print("\255\000\255\000" .. allyComs, area[1] + ((area[3] - area[1]) / 2), area[2] + ((area[4] - area[2]) / 2.05) - (fontSize / 5), fontSize, 'oc')
			font2:End()
		end
	end)
	comcountChanged = nil

	if WG['tooltip'] ~= nil then
		WG['tooltip'].AddTooltip('coms', area, texts.comcount_tooltip)
	end
end

local function updateWind()
	local area = windArea

	local bladesSize = height*0.53 * widgetScale

	-- add background blur
	if dlistWindGuishader ~= nil then
		if WG['guishader'] then
			WG['guishader'].RemoveDlist('topbar_wind')
		end
		glDeleteList(dlistWindGuishader)
	end
	dlistWindGuishader = glCreateList(function()
		RectRound(area[1], area[2], area[3], area[4], 5.5 * widgetScale, 0,0,1,1)
	end)

	if dlistWind1 ~= nil then
		glDeleteList(dlistWind1)
	end
	dlistWind1 = glCreateList(function()

		UiElement(area[1], area[2], area[3], area[4], 0, 0, 1, 1)

		if WG['guishader'] then
			WG['guishader'].InsertDlist(dlistWindGuishader, 'topbar_wind')
		end

		-- blades icon
		glPushMatrix()
		glTranslate(area[1] + ((area[3] - area[1]) / 2), area[2] + (bgpadding/2) + ((area[4] - area[2]) / 2), 0)
		glColor(1, 1, 1, 0.2)
		glTexture(bladesTexture)
		-- glRotate is done after displaying this dl, and before dl2
	end)

	if dlistWind2 ~= nil then
		glDeleteList(dlistWind2)
	end
	dlistWind2 = glCreateList(function()
		glTexRect(-bladesSize, -bladesSize, bladesSize, bladesSize)
		glTexture(false)
		glPopMatrix()

		-- min and max wind
		local fontsize = (height / 3.7) * widgetScale
		if minWind+maxWind >= 0.5 then
			font2:Begin()
			font2:Print("\255\210\210\210" .. minWind, area[3] - (2.8 * widgetScale), area[4] - (4.5 * widgetScale) - (fontsize / 2), fontsize, 'or')
			font2:Print("\255\210\210\210" .. maxWind, area[3] - (2.8 * widgetScale), area[2] + (4.5 * widgetScale), fontsize, 'or')
			font2:Print("\255\210\210\210" .. maxWind, area[3] - (2.8 * widgetScale), area[2] + (4.5 * widgetScale), fontsize, 'or')
			font2:End()
		else
			font2:Begin()
			--font2:Print("\255\200\200\200no wind", windArea[1] + ((windArea[3] - windArea[1]) / 2), windArea[2] + ((windArea[4] - windArea[2]) / 2.05) - (fontsize / 5), fontsize, 'oc') -- Wind speed text
			font2:Print("\255\200\200\200"..texts.wind.nowind1, windArea[1] + ((windArea[3] - windArea[1]) / 2), windArea[2] + ((windArea[4] - windArea[2]) / 1.5) - (fontsize / 5), fontsize*1.06, 'oc') -- Wind speed text
			font2:Print("\255\200\200\200"..texts.wind.nowind2, windArea[1] + ((windArea[3] - windArea[1]) / 2), windArea[2] + ((windArea[4] - windArea[2]) / 2.8) - (fontsize / 5), fontsize*1.06, 'oc') -- Wind speed text
			font2:End()
		end
	end)

	if WG['tooltip'] ~= nil then
		WG['tooltip'].AddTooltip('wind', area, texts.wind.tooltip)
	end
end

local function updateResbarText(res)

	if dlistResbar[res][4] ~= nil then
		glDeleteList(dlistResbar[res][4])
	end
	dlistResbar[res][4] = glCreateList(function()
		RectRound(resbarArea[res][1] + bgpadding, resbarArea[res][2] + bgpadding, resbarArea[res][3] - bgpadding, resbarArea[res][4], bgpadding * 1.25, 0,0,1,1)
		RectRound(resbarArea[res][1], resbarArea[res][2], resbarArea[res][3], resbarArea[res][4], 5.5 * widgetScale, 0,0,1,1)
	end)
	if dlistResbar[res][5] ~= nil then
		glDeleteList(dlistResbar[res][5])
	end
	dlistResbar[res][5] = glCreateList(function()
		RectRound(resbarArea[res][1], resbarArea[res][2], resbarArea[res][3], resbarArea[res][4], 5.5 * widgetScale, 0,0,1,1)
	end)

	-- storage changed!
	if currentStorageValue[res] ~= r[res][2] then
		-- flush old dlist caches
		for n, _ in pairs(dlistResValues[res]) do
			glDeleteList(dlistResValues[res][n])
		end
		dlistResValues[res] = {}

		-- storage
		if dlistResbar[res][6] ~= nil then
			glDeleteList(dlistResbar[res][6])
		end
		dlistResbar[res][6] = glCreateList(function()
			font2:Begin()
			font2:Print("\255\210\210\210" .. short(r[res][2]), resbarDrawinfo[res].textStorage[2], resbarDrawinfo[res].textStorage[3], resbarDrawinfo[res].textStorage[4], resbarDrawinfo[res].textStorage[5])
			font2:End()
		end)
	end

	if dlistResbar[res][3] ~= nil then
		glDeleteList(dlistResbar[res][3])
	end
	dlistResbar[res][3] = glCreateList(function()
		font2:Begin()
		-- Text: pull
		font2:Print("\255\240\125\125" .. "-" .. short(r[res][3]), resbarDrawinfo[res].textPull[2], resbarDrawinfo[res].textPull[3], resbarDrawinfo[res].textPull[4], resbarDrawinfo[res].textPull[5])
		-- Text: expense
		local textcolor = "\255\240\180\145"
		if r[res][3] == r[res][5] then
			textcolor = "\255\200\140\130"
		end
		font2:Print(textcolor .. "-" .. short(r[res][5]), resbarDrawinfo[res].textExpense[2], resbarDrawinfo[res].textExpense[3], resbarDrawinfo[res].textExpense[4], resbarDrawinfo[res].textExpense[5])
		-- income
		font2:Print("\255\120\235\120" .. "+" .. short(r[res][4]), resbarDrawinfo[res].textIncome[2], resbarDrawinfo[res].textIncome[3], resbarDrawinfo[res].textIncome[4], resbarDrawinfo[res].textIncome[5])
		font2:End()

		if not spec and gameFrame > 90 then

			-- display overflow notification
			if (res == 'metal' and (allyteamOverflowingMetal or overflowingMetal)) or (res == 'energy' and (allyteamOverflowingEnergy or overflowingEnergy)) then
				if showOverflowTooltip[res] == nil then
					showOverflowTooltip[res] = os.clock() + 0.5
				end
				if showOverflowTooltip[res] < os.clock() then
					local bgpadding2 = 2.2 * widgetScale
					local text = ''
					if res == 'metal' then
						text = (allyteamOverflowingMetal and '   '..texts.resbar.wastingmetal..'   ' or '   '..texts.resbar.overflowing..'   ')
						if WG['notifications'] then
							if allyteamOverflowingMetal then
								if numTeamsInAllyTeam > 1 then
									WG['notifications'].addEvent('WholeTeamWastingMetal')
								else
									--WG['notifications'].addEvent('YouAreWastingMetal')
								end
							else
								WG['notifications'].addEvent('YouAreOverflowingMetal')
							end
						end
					else
						text = (allyteamOverflowingEnergy and '   '..texts.resbar.wastingenergy..'   '  or '   '..texts.resbar.overflowing..'   ')
						if WG['notifications'] then
							if allyteamOverflowingEnergy then
								if numTeamsInAllyTeam > 3 then
									WG['notifications'].addEvent('WholeTeamWastingEnergy')
								else
									--WG['notifications'].addEvent('YouAreWastingEnergy')
								end
							else
								--WG['notifications'].addEvent('YouAreOverflowingEnergy')	-- this annoys the fuck out of em and makes them build energystoages too much
							end
						end
					end
					local fontSize = (orgHeight * (1 + (ui_scale - 1) / 1.33) / 4) * widgetScale
					local textWidth = font2:GetTextWidth(text) * fontSize

					-- background
					local color1, color2
					if res == 'metal' then
						if allyteamOverflowingMetal then
							color1 = { 0.35, 0.1, 0.1, 0.8 }
							color2 = { 0.25, 0.05, 0.05, 0.8 }
						else
							color1 = { 0.35, 0.35, 0.35, 0.55 }
							color2 = { 0.25, 0.25, 0.25, 0.55 }
						end
					else
						if allyteamOverflowingEnergy then
							color1 = { 0.35, 0.1, 0.1, 0.8 }
							color2 = { 0.25, 0.05, 0.05, 0.8 }
						else
							color1 = { 0.35, 0.25, 0, 0.8 }
							color2 = { 0.25, 0.16, 0, 0.8 }
						end
					end
					RectRound(resbarArea[res][3] - textWidth, resbarArea[res][4] - 15.5 * widgetScale, resbarArea[res][3], resbarArea[res][4], 3.7 * widgetScale, 0, 0, 1, 1, color1, color2)
					if res == 'metal' then
						if allyteamOverflowingMetal then
							color1 = { 1, 0.3, 0.3, 0.25 }
							color2 = { 1, 0.3, 0.3, 0.44 }
						else
							color1 = { 1, 1, 1, 0.25 }
							color2 = { 1, 1, 1, 0.44 }
						end
					else
						if allyteamOverflowingEnergy then
							color1 = { 1, 0.3, 0.3, 0.25 }
							color2 = { 1, 0.3, 0.3, 0.44 }
						else
							color1 = { 1, 0.88, 0, 0.25 }
							color2 = { 1, 0.88, 0, 0.44 }
						end
					end
					RectRound(resbarArea[res][3] - textWidth + bgpadding2, resbarArea[res][4] - 15.5 * widgetScale + bgpadding2, resbarArea[res][3] - bgpadding2, resbarArea[res][4], 2.8 * widgetScale, 0, 0, 1, 1, color1, color2)

					font2:Begin()
					font2:SetTextColor(1, 0.88, 0.88, 1)
					font2:SetOutlineColor(0.2, 0, 0, 0.6)
					font2:Print(text, resbarArea[res][3], resbarArea[res][4] - 9.3 * widgetScale, fontSize, 'or')
					font2:End()
				end
			else
				showOverflowTooltip[res] = nil
			end
		end
	end)
end

local function updateResbar(res)
	local area = resbarArea[res]

	if dlistResbar[res][1] ~= nil then
		glDeleteList(dlistResbar[res][1])
		glDeleteList(dlistResbar[res][2])
	end
	local barHeight = math_floor((height * widgetScale / 7) + 0.5)
	local barHeightPadding = math_floor(((height / 4.4) * widgetScale) + 0.5) --((height/2) * widgetScale) - (barHeight/2)
	--local barLeftPadding = 2 * widgetScale
	local barLeftPadding = math_floor(45 * widgetScale)
	local barRightPadding = math_floor(14.5 * widgetScale)
	local barArea = { area[1] + math_floor((height * widgetScale) + barLeftPadding), area[2] + barHeightPadding, area[3] - barRightPadding, area[2] + barHeight + barHeightPadding }
	local sliderHeightAdd = math_floor(barHeight / 1.55)
	local shareSliderWidth = barHeight + sliderHeightAdd + sliderHeightAdd
	local barWidth = barArea[3] - barArea[1]
	local glowSize = barHeight * 7
	local edgeWidth = math.max(1, math_floor(vsy / 1100))

	if not showQuitscreen and resbarHover ~= nil and resbarHover == res then
		sliderHeightAdd = barHeight / 0.75
		shareSliderWidth = barHeight + sliderHeightAdd + sliderHeightAdd
	end
	shareSliderWidth = math.ceil(shareSliderWidth)

	if res == 'metal' then
		resbarDrawinfo[res].barColor = { 1, 1, 1, 1 }
	else
		resbarDrawinfo[res].barColor = { 1, 1, 0, 1 }
	end
	resbarDrawinfo[res].barArea = barArea

	resbarDrawinfo[res].barTexRect = { barArea[1], barArea[2], barArea[1] + ((r[res][1] / r[res][2]) * barWidth), barArea[4] }
	resbarDrawinfo[res].barGlowMiddleTexRect = { resbarDrawinfo[res].barTexRect[1], resbarDrawinfo[res].barTexRect[2] - glowSize, resbarDrawinfo[res].barTexRect[3], resbarDrawinfo[res].barTexRect[4] + glowSize }
	resbarDrawinfo[res].barGlowLeftTexRect = { resbarDrawinfo[res].barTexRect[1] - (glowSize * 2.5), resbarDrawinfo[res].barTexRect[2] - glowSize, resbarDrawinfo[res].barTexRect[1], resbarDrawinfo[res].barTexRect[4] + glowSize }
	resbarDrawinfo[res].barGlowRightTexRect = { resbarDrawinfo[res].barTexRect[3] + (glowSize * 2.5), resbarDrawinfo[res].barTexRect[2] - glowSize, resbarDrawinfo[res].barTexRect[3], resbarDrawinfo[res].barTexRect[4] + glowSize }

	resbarDrawinfo[res].textCurrent = { short(r[res][1]), barArea[1] + barWidth / 2, barArea[2] + barHeight * 1.8, (height / 2.6) * widgetScale, 'ocd' }
	resbarDrawinfo[res].textStorage = { "\255\150\150\150" .. short(r[res][2]), barArea[3], barArea[2] + barHeight * 2.1, (height / 3.2) * widgetScale, 'ord' }
	resbarDrawinfo[res].textPull = { "\255\210\100\100" .. short(r[res][3]), barArea[1] - (10 * widgetScale), barArea[2] + barHeight * 2.15, (height / 3) * widgetScale, 'ord' }
	resbarDrawinfo[res].textExpense = { "\255\210\100\100" .. short(r[res][5]), barArea[1] + (10 * widgetScale), barArea[2] + barHeight * 2.15, (height / 3) * widgetScale, 'old' }
	resbarDrawinfo[res].textIncome = { "\255\100\210\100" .. short(r[res][4]), barArea[1] - (10 * widgetScale), barArea[2] - (barHeight * 0.55), (height / 3) * widgetScale, 'ord' }

	-- add background blur
	if dlistResbar[res][0] ~= nil then
		if WG['guishader'] then
			WG['guishader'].RemoveDlist('topbar_' .. res)
		end
		glDeleteList(dlistResbar[res][0])
	end
	dlistResbar[res][0] = glCreateList(function()
		RectRound(area[1], area[2], area[3], area[4], 5.5 * widgetScale, 0,0,1,1)
	end)

	dlistResbar[res][1] = glCreateList(function()
		UiElement(area[1], area[2], area[3], area[4], 0, 0, 1, 1)

		if WG['guishader'] then
			WG['guishader'].InsertDlist(dlistResbar[res][0], 'topbar_' .. res)
		end

		-- Icon
		glColor(1, 1, 1, 1)
		local iconPadding = math_floor((area[4] - area[2]) / 7)
		local iconSize = math_floor(area[4] - area[2] - iconPadding - iconPadding)
		local bgpaddingHalf = math_floor((bgpadding * 0.5) + 0.5)
		local texSize = math_floor(iconSize * 2)
		if res == 'metal' then
			glTexture(":lr" .. texSize .. "," .. texSize .. ":LuaUI/Images/metal.png")
		else
			glTexture(":lr" .. texSize .. "," .. texSize .. ":LuaUI/Images/energy.png")
		end
		glTexRect(area[1] + bgpaddingHalf + iconPadding, area[2] + bgpaddingHalf + iconPadding, area[1] + bgpaddingHalf + iconPadding + iconSize, area[4] + bgpaddingHalf - iconPadding)
		glTexture(false)

		-- Bar background
		local addedSize = math_floor(((barArea[4] - barArea[2]) * 0.15) + 0.5)
		--RectRound(barArea[1] - edgeWidth, barArea[2] - edgeWidth, barArea[3] + edgeWidth, barArea[4] + edgeWidth, barHeight * 0.33, 1, 1, 1, 1, { 1,1,1, 0.03 }, { 1,1,1, 0.03 })
		gl.Texture(noiseBackgroundTexture)
		gl.Color(1,1,1, 0.22)
		TexturedRectRound(barArea[1] - edgeWidth, barArea[2] - edgeWidth, barArea[3] + edgeWidth, barArea[4] + edgeWidth, barHeight * 0.33, 1, 1, 1, 1, barWidth*0.33, 0)
		gl.Texture(false)

		glBlending(GL_SRC_ALPHA, GL_ONE)
		RectRound(barArea[1] - addedSize - edgeWidth, barArea[2] - addedSize - edgeWidth, barArea[3] + addedSize + edgeWidth, barArea[4] + addedSize + edgeWidth, barHeight * 0.33, 1, 1, 1, 1, { 0, 0, 0, 0.1 }, { 0, 0, 0, 0.1 })
		RectRound(barArea[1] - addedSize, barArea[2] - addedSize, barArea[3] + addedSize, barArea[4] + addedSize, barHeight * 0.33, 1, 1, 1, 1, { 0.15, 0.15, 0.15, 0.2 }, { 0.8, 0.8, 0.8, 0.16 })
		-- gloss
		RectRound(barArea[1] - addedSize, barArea[2] + addedSize, barArea[3] + addedSize, barArea[4] + addedSize, barHeight * 0.33, 1, 1, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.07 })
		RectRound(barArea[1] - addedSize, barArea[2] - addedSize, barArea[3] + addedSize, barArea[2] + addedSize + addedSize + addedSize, barHeight * 0.2, 0, 0, 1, 1, { 1, 1, 1, 0.1 }, { 1, 1, 1, 0.0 })
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	end)

	dlistResbar[res][2] = glCreateList(function()
		-- Metalmaker Conversion slider
		if showConversionSlider and res == 'energy' then
			local convValue = Spring.GetTeamRulesParam(myTeamID, 'mmLevel')
			if draggingConversionIndicatorValue ~= nil then
				convValue = draggingConversionIndicatorValue / 100
			end
			if convValue == nil then
				convValue = 1
			end
			conversionIndicatorArea = { math_floor(barArea[1] + (convValue * barWidth) - (shareSliderWidth / 2)), math_floor(barArea[2] - sliderHeightAdd), math_floor(barArea[1] + (convValue * barWidth) + (shareSliderWidth / 2)), math_floor(barArea[4] + sliderHeightAdd) }
			local cornerSize
			if not showQuitscreen and resbarHover ~= nil and resbarHover == res then
				cornerSize = 2 * widgetScale
			else
				cornerSize = 1.33 * widgetScale
			end
			UiSliderKnob(conversionIndicatorArea[1]+((conversionIndicatorArea[3]-conversionIndicatorArea[1])/2), conversionIndicatorArea[2]+((conversionIndicatorArea[4]-conversionIndicatorArea[2])/2), (conversionIndicatorArea[3]-conversionIndicatorArea[1])/2, { 0.95, 0.95, 0.7, 1 })

			if buttonBgtexOpacity > 0 then
				gl.Texture(buttonBackgroundTexture)
				gl.Color(1,1,1, buttonBgtexOpacity*0.6)
				TexturedRectRound(conversionIndicatorArea[1], conversionIndicatorArea[2], conversionIndicatorArea[3], conversionIndicatorArea[4], cornerSize, 1, 1, 1, 1, buttonBgtexSize*0.82, 0)
				gl.Texture(false)
			end
		end
		-- Share slider
		local value = r[res][6]
		if draggingShareIndicatorValue[res] ~= nil then
			value = draggingShareIndicatorValue[res]
		end
		shareIndicatorArea[res] = { math_floor(barArea[1] + (value * barWidth) - (shareSliderWidth / 2)), math_floor(barArea[2] - sliderHeightAdd), math_floor(barArea[1] + (value * barWidth) + (shareSliderWidth / 2)), math_floor(barArea[4] + sliderHeightAdd) }
		local cornerSize
		if not showQuitscreen and resbarHover ~= nil and resbarHover == res then
			cornerSize = 2 * widgetScale
		else
			cornerSize = 1.33 * widgetScale
		end
		UiSliderKnob(shareIndicatorArea[res][1]+((shareIndicatorArea[res][3]-shareIndicatorArea[res][1])/2), shareIndicatorArea[res][2]+((shareIndicatorArea[res][4]-shareIndicatorArea[res][2])/2), (shareIndicatorArea[res][3]-shareIndicatorArea[res][1])/2, { 0.85, 0, 0, 1 })

		if buttonBgtexOpacity > 0 then
			gl.Texture(buttonBackgroundTexture)
			gl.Color(1,1,1, buttonBgtexOpacity*0.7)
			TexturedRectRound(shareIndicatorArea[res][1], shareIndicatorArea[res][2], shareIndicatorArea[res][3], shareIndicatorArea[res][4], cornerSize, 1, 1, 1, 1, buttonBgtexSize*0.82, 0)
			gl.Texture(false)
		end
	end)

	-- add tooltips
	if WG['tooltip'] ~= nil and conversionIndicatorArea then
		if res == 'energy' then
			WG['tooltip'].AddTooltip(res .. '_share_slider', { resbarDrawinfo[res].barArea[1], shareIndicatorArea[res][2], conversionIndicatorArea[1], shareIndicatorArea[res][4] }, "\255\215\255\215" .. (res == 'energy' and texts.resbar.overflowing_energy_tooltip or texts.resbar.overflowing_metal_tooltip))
			WG['tooltip'].AddTooltip(res .. '_share_slider2', { conversionIndicatorArea[3], shareIndicatorArea[res][2], resbarDrawinfo[res].barArea[3], shareIndicatorArea[res][4] }, "\255\215\255\215" .. (res == 'energy' and texts.resbar.overflowing_energy_tooltip or texts.resbar.overflowing_metal_tooltip))

			WG['tooltip'].AddTooltip(res .. '_metalmaker_slider', conversionIndicatorArea, texts.resbar.conversion_tooltip)
		else
			WG['tooltip'].AddTooltip(res .. '_share_slider', { resbarDrawinfo[res].barArea[1], shareIndicatorArea[res][2], resbarDrawinfo[res].barArea[3], shareIndicatorArea[res][4] }, "\255\215\255\215" .. (res == 'energy' and texts.resbar.overflowing_energy_tooltip or texts.resbar.overflowing_metal_tooltip))
		end
		WG['tooltip'].AddTooltip(res .. '_pull', { resbarDrawinfo[res].textPull[2] - (resbarDrawinfo[res].textPull[4] * 2.5), resbarDrawinfo[res].textPull[3], resbarDrawinfo[res].textPull[2] + (resbarDrawinfo[res].textPull[4] * 0.5), resbarDrawinfo[res].textPull[3] + resbarDrawinfo[res].textPull[4] }, "" .. res .. " "..texts.resbar.pull_tooltip)
		WG['tooltip'].AddTooltip(res .. '_income', { resbarDrawinfo[res].textIncome[2] - (resbarDrawinfo[res].textIncome[4] * 2.5), resbarDrawinfo[res].textIncome[3], resbarDrawinfo[res].textIncome[2] + (resbarDrawinfo[res].textIncome[4] * 0.5), resbarDrawinfo[res].textIncome[3] + resbarDrawinfo[res].textIncome[4] }, "" .. res .. " "..texts.resbar.income_tooltip)
		WG['tooltip'].AddTooltip(res .. '_expense', { resbarDrawinfo[res].textExpense[2] - (4 * widgetScale), resbarDrawinfo[res].textExpense[3], resbarDrawinfo[res].textExpense[2] + (30 * widgetScale), resbarDrawinfo[res].textExpense[3] + resbarDrawinfo[res].textExpense[4] }, "" .. res .. " "..texts.resbar.expense_tooltip)
		WG['tooltip'].AddTooltip(res .. '_storage', { resbarDrawinfo[res].textStorage[2] - (resbarDrawinfo[res].textStorage[4] * 2.75), resbarDrawinfo[res].textStorage[3], resbarDrawinfo[res].textStorage[2], resbarDrawinfo[res].textStorage[3] + resbarDrawinfo[res].textStorage[4] }, "" .. res .. " "..texts.resbar.storage_tooltip)
		WG['tooltip'].AddTooltip(res .. '_current', { resbarDrawinfo[res].textCurrent[2] - (resbarDrawinfo[res].textCurrent[4] * 1.75), resbarDrawinfo[res].textCurrent[3], resbarDrawinfo[res].textCurrent[2] + (resbarDrawinfo[res].textCurrent[4] * 1.75), resbarDrawinfo[res].textCurrent[3] + resbarDrawinfo[res].textCurrent[4] }, "\255\215\255\215" .. string.upper(res) .. "\n\255\240\240\240"..(res == 'energy' and texts.resbar.current_energy_tooltip or texts.resbar.current_metal_tooltip))
	end
end

function drawResbarValues(res)
	local barHeight = resbarDrawinfo[res].barArea[4] - resbarDrawinfo[res].barArea[2]
	local barWidth = resbarDrawinfo[res].barArea[3] - resbarDrawinfo[res].barArea[1]
	local glowSize = (resbarDrawinfo[res].barArea[4] - resbarDrawinfo[res].barArea[2]) * 7

	local cappedCurRes = r[res][1]    -- limit so when production dies the value wont be much larger than what you can store
	if r[res][1] > r[res][2] * 1.07 then
		cappedCurRes = r[res][2] * 1.07
	end
	if res == 'energy' then
		glColor(1, 1, 0, 0.04)
		local iconPadding = (resbarArea[res][4] - resbarArea[res][2])
		glTexture(glowTexture)
		glTexRect(resbarArea[res][1] + iconPadding, resbarArea[res][2] + iconPadding, resbarArea[res][1] + (height * widgetScale) - iconPadding, resbarArea[res][4] - iconPadding)
		glTexture(false)
	end

	-- Bar value
	local valueWidth = math_floor(((cappedCurRes / r[res][2]) * barWidth))
	if valueWidth < math.ceil(barHeight * 0.2) then
		valueWidth = math.ceil(barHeight * 0.2)
	end
	local color1, color2, glowAlpha
	if res == 'metal' then
		color1 = { 0.51, 0.51, 0.5, 1 }
		color2 = { 0.95, 0.95, 0.95, 1 }
		glowAlpha = 0.025 + (0.05 * math_min(1, cappedCurRes / r[res][2] * 40))
	else
		color1 = { 0.5, 0.45, 0, 1 }
		color2 = { 0.8, 0.75, 0, 1 }
		glowAlpha = 0.035 + (0.07 * math_min(1, cappedCurRes / r[res][2] * 40))
	end
	RectRound(resbarDrawinfo[res].barTexRect[1], resbarDrawinfo[res].barTexRect[2], resbarDrawinfo[res].barTexRect[1] + valueWidth, resbarDrawinfo[res].barTexRect[4], barHeight * 0.2, 1, 1, 1, 1, color1, color2)

	-- bar value highlight
	glBlending(GL_SRC_ALPHA, GL_ONE)
	RectRound(resbarDrawinfo[res].barTexRect[1], resbarDrawinfo[res].barTexRect[4] - ((resbarDrawinfo[res].barTexRect[4] - resbarDrawinfo[res].barTexRect[2]) / 1.5), resbarDrawinfo[res].barTexRect[1] + valueWidth, resbarDrawinfo[res].barTexRect[4], barHeight * 0.2, 1, 1, 1, 1, { 0, 0, 0, 0 }, { 1, 1, 1, 0.11 })
	RectRound(resbarDrawinfo[res].barTexRect[1], resbarDrawinfo[res].barTexRect[2], resbarDrawinfo[res].barTexRect[1] + valueWidth, resbarDrawinfo[res].barTexRect[2] + ((resbarDrawinfo[res].barTexRect[4] - resbarDrawinfo[res].barTexRect[2]) / 1.75), barHeight * 0.2, 1, 1, 1, 1, { 1, 1, 1, 0.11 }, { 0, 0, 0, 0 })

	-- Bar value glow
	glColor(resbarDrawinfo[res].barColor[1], resbarDrawinfo[res].barColor[2], resbarDrawinfo[res].barColor[3], glowAlpha)
	glTexture(barGlowCenterTexture)
	DrawRect(resbarDrawinfo[res].barGlowMiddleTexRect[1], resbarDrawinfo[res].barGlowMiddleTexRect[2], resbarDrawinfo[res].barGlowMiddleTexRect[1] + valueWidth, resbarDrawinfo[res].barGlowMiddleTexRect[4], 0.008)
	glTexture(barGlowEdgeTexture)
	DrawRect(resbarDrawinfo[res].barGlowLeftTexRect[1], resbarDrawinfo[res].barGlowLeftTexRect[2], resbarDrawinfo[res].barGlowLeftTexRect[3], resbarDrawinfo[res].barGlowLeftTexRect[4], 0.008)
	DrawRect((resbarDrawinfo[res].barGlowMiddleTexRect[1] + valueWidth) + (glowSize * 3), resbarDrawinfo[res].barGlowRightTexRect[2], resbarDrawinfo[res].barGlowMiddleTexRect[1] + valueWidth, resbarDrawinfo[res].barGlowRightTexRect[4], 0.008)
	glTexture(false)

	-- noise
	gl.Texture(noiseBackgroundTexture)
	gl.Color(1,1,1, 0.45)
	TexturedRectRound(resbarDrawinfo[res].barTexRect[1], resbarDrawinfo[res].barTexRect[2], resbarDrawinfo[res].barTexRect[1] + valueWidth, resbarDrawinfo[res].barTexRect[4], barHeight * 0.2, 1, 1, 1, 1, barWidth*0.33, 0)
	gl.Texture(false)

	if res == 'energy' then
		-- energy flow effect
		gl.Color(1,1,1, 0.32)
		glTexture("LuaUI/Images/paralyzed.png")
		TexturedRectRound(resbarDrawinfo[res].barTexRect[1], resbarDrawinfo[res].barTexRect[2], resbarDrawinfo[res].barTexRect[1] + valueWidth, resbarDrawinfo[res].barTexRect[4], barHeight * 0.2, 0, 0, 1, 1, barWidth/0.5, -os.clock()/80)
		TexturedRectRound(resbarDrawinfo[res].barTexRect[1], resbarDrawinfo[res].barTexRect[2], resbarDrawinfo[res].barTexRect[1] + valueWidth, resbarDrawinfo[res].barTexRect[4], barHeight * 0.2, 0, 0, 1, 1, barWidth/0.33, os.clock()/70)
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
		gl.Color(1,1,1, 0.26)
		TexturedRectRound(resbarDrawinfo[res].barTexRect[1], resbarDrawinfo[res].barTexRect[2], resbarDrawinfo[res].barTexRect[1] + valueWidth, resbarDrawinfo[res].barTexRect[4], barHeight * 0.2, 0, 0, 1, 1, barWidth/0.45, -os.clock()/55)
		TexturedRectRound(resbarDrawinfo[res].barTexRect[1], resbarDrawinfo[res].barTexRect[2], resbarDrawinfo[res].barTexRect[1] + valueWidth, resbarDrawinfo[res].barTexRect[4], barHeight * 0.2, 0, 0, 1, 1, barWidth/0.7, os.clock()/80)
		glTexture(false)
	else
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	end

	currentResValue[res] = short(cappedCurRes)
	if not dlistResValues[res][currentResValue[res]] then
		dlistResValues[res][currentResValue[res]] = glCreateList(function()
			-- Text: current
			font2:Begin()
			font2:Print(currentResValue[res], resbarDrawinfo[res].textCurrent[2], resbarDrawinfo[res].textCurrent[3], resbarDrawinfo[res].textCurrent[4], resbarDrawinfo[res].textCurrent[5])
			font2:End()
		end)
	end
	glCallList(dlistResValues[res][currentResValue[res]])
end

function init()

	r = { metal = { spGetTeamResources(myTeamID, 'metal') }, energy = { spGetTeamResources(myTeamID, 'energy') } }

	topbarArea = { math_floor(xPos + (borderPadding * widgetScale)), math_floor(vsy - (height * widgetScale)), vsx, vsy }

	local filledWidth = 0
	local totalWidth = topbarArea[3] - topbarArea[1]

	-- metal
	local width = math_floor(totalWidth / 4)
	resbarArea['metal'] = { topbarArea[1] + filledWidth, topbarArea[2], topbarArea[1] + filledWidth + width, topbarArea[4] }
	filledWidth = filledWidth + width + widgetSpaceMargin
	updateResbar('metal')

	--energy
	resbarArea['energy'] = { topbarArea[1] + filledWidth, topbarArea[2], topbarArea[1] + filledWidth + width, topbarArea[4] }
	filledWidth = filledWidth + width + widgetSpaceMargin
	updateResbar('energy')

	-- wind
	width = math_floor((height * 1.18) * widgetScale)
	windArea = { topbarArea[1] + filledWidth, topbarArea[2], topbarArea[1] + filledWidth + width, topbarArea[4] }
	filledWidth = filledWidth + width + widgetSpaceMargin
	updateWind()

	-- coms
	if displayComCounter then
		comsArea = { topbarArea[1] + filledWidth, topbarArea[2], topbarArea[1] + filledWidth + width, topbarArea[4] }
		filledWidth = filledWidth + width + widgetSpaceMargin
		updateComs()
	end

	-- rejoin
	width = math_floor(totalWidth / 4) / 3.3
	rejoinArea = { topbarArea[1] + filledWidth, topbarArea[2], topbarArea[1] + filledWidth + width, topbarArea[4] }
	filledWidth = filledWidth + width + widgetSpaceMargin

	-- buttons
	width = math_floor(totalWidth / 4)
	buttonsArea = { topbarArea[3] - width, topbarArea[2], topbarArea[3], topbarArea[4] }
	filledWidth = filledWidth + width + widgetSpaceMargin
	updateButtons()

	if WG['topbar'] then
		WG['topbar'].GetPosition = function()
			return { topbarArea[1], topbarArea[2], topbarArea[3], topbarArea[4], widgetScale}
		end
	end

	updateResbarText('metal')
	updateResbarText('energy')
end

function checkStatus()
	myAllyTeamID = Spring.GetMyAllyTeamID()
	myTeamID = Spring.GetMyTeamID()
	myPlayerID = Spring.GetMyPlayerID()
	if myTeamID ~= gaiaTeamID and UnitDefs[Spring.GetTeamRulesParam(myTeamID, 'startUnit')] then
		comTexture = 'Icons/'..UnitDefs[Spring.GetTeamRulesParam(myTeamID, 'startUnit')].name..'.png'
	end
end

function widget:GameStart()
	gameStarted = true
	checkStatus()
	if displayComCounter then
		countComs(true)
	end
	init()
end

function widget:GameFrame(n)
	spec = spGetSpectatingState()

	windRotation = windRotation + (currentWind * bladeSpeedMultiplier)
	gameFrame = n
end

local uiOpacitySec = 0
local sec = 0
local sec2 = 0
local secComCount = 0
local t = UPDATE_RATE_S
local blinkDirection = true
local blinkProgress = 0
function widget:Update(dt)
	if chobbyInterface then
		return
	end

	local prevMyTeamID = myTeamID
	if spec and spGetMyTeamID() ~= prevMyTeamID then
		-- check if the team that we are spectating changed
		checkStatus()
	end

	local mx, my = spGetMouseState()
	local speedFactor, _, isPaused = Spring.GetGameSpeed()
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

	now = os.clock()
	if now > nextGuishaderCheck and widgetHandler.orderList["GUI Shader"] ~= nil then
		nextGuishaderCheck = now + guishaderCheckUpdateRate
		if guishaderEnabled == false and widgetHandler.orderList["GUI Shader"] ~= 0 then
			guishaderEnabled = true
			init()
		elseif guishaderEnabled and (widgetHandler.orderList["GUI Shader"] == 0) then
			guishaderEnabled = false
		end
	end

	sec = sec + dt
	if sec > 0.033 then
		sec = 0
		r = { metal = { spGetTeamResources(myTeamID, 'metal') }, energy = { spGetTeamResources(myTeamID, 'energy') } }
		if not spec and not showQuitscreen then
			if isInBox(mx, my, resbarArea['energy']) then
				if resbarHover == nil then
					resbarHover = 'energy'
					updateResbar('energy')
				end
			elseif resbarHover ~= nil and resbarHover == 'energy' then
				resbarHover = nil
				updateResbar('energy')
			end
			if isInBox(mx, my, resbarArea['metal']) then
				if resbarHover == nil then
					resbarHover = 'metal'
					updateResbar('metal')
				end
			elseif resbarHover ~= nil and resbarHover == 'metal' then
				resbarHover = nil
				updateResbar('metal')
			end
		elseif spec and myTeamID ~= prevMyTeamID then
			-- check if the team that we are spectating changed
			draggingShareIndicatorValue = {}
			draggingConversionIndicatorValue = nil
			updateResbar('metal')
			updateResbar('energy')
		end
	end

	sec2 = sec2 + dt
	if sec2 >= 1 then
		sec2 = 0
		updateResbarText('metal')
		updateResbarText('energy')
		updateAllyTeamOverflowing()
	end

	-- wind
	if gameFrame ~= lastFrame then
		currentWind = sformat('%.1f', select(4, spGetWind()))
	end

	-- coms
	if displayComCounter then
		secComCount = secComCount + dt
		if secComCount > 0.5 then
			secComCount = 0
			countComs()
		end
	end

	-- rejoin
	if not isReplay and serverFrame then
		t = t - dt
		if t <= 0 then
			t = t + UPDATE_RATE_S

			--Estimate Server Frame
			if gameStarted and not isPaused then
				serverFrame = serverFrame + math.ceil(speedFactor * UPDATE_RATE_F)
			end

			local framesLeft = serverFrame - gameFrame
			if framesLeft > CATCH_UP_THRESHOLD then
				showRejoinUI = true
				updateRejoin()
			elseif showRejoinUI then
				showRejoinUI = false
				updateRejoin()
			end
		end
	end

	uiOpacitySec = uiOpacitySec + dt
	if uiOpacitySec > 0.5 then
		uiOpacitySec = 0
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity", 0.6) then
			ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.6)
			init()
		end
		if ui_scale ~= Spring.GetConfigFloat("ui_scale", 1) then
			ui_scale = Spring.GetConfigFloat("ui_scale", 1)
			height = orgHeight * (1 + (ui_scale - 1) / 1.7)
			shutdown()
			widget:ViewResize()
		end
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

function updateAllyTeamOverflowing()
	allyteamOverflowingMetal = false
	allyteamOverflowingEnergy = false
	overflowingMetal = false
	overflowingEnergy = false
	local totalEnergy = 0
	local totalEnergyStorage = 0
	local totalMetal = 0
	local totalMetalStorage = 0
	local energyPercentile, metalPercentile
	for i, teamID in pairs(Spring.GetTeamList(Spring.GetMyAllyTeamID())) do
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
				overflowingEnergy = energyPercentile * (1 / 0.025)
				if overflowingEnergy > 1 then
					overflowingEnergy = 1
				end
			end
			if metalPercentile > 0.0001 then
				overflowingMetal = metalPercentile * (1 / 0.025)
				if overflowingMetal > 1 then
					overflowingMetal = 1
				end
			end
		end
	end
	energyPercentile = totalEnergy / totalEnergyStorage
	metalPercentile = totalMetal / totalMetalStorage
	if energyPercentile > 0.975 then
		allyteamOverflowingEnergy = (energyPercentile - 0.975) * (1 / 0.025)
		if allyteamOverflowingEnergy > 1 then
			allyteamOverflowingEnergy = 1
		end
	end
	if metalPercentile > 0.975 then
		allyteamOverflowingMetal = (metalPercentile - 0.975) * (1 / 0.025)
		if allyteamOverflowingMetal > 1 then
			allyteamOverflowingMetal = 1
		end
	end
end

function hoveringElement(x, y)
	if IsOnRect(x, y, topbarArea[1], topbarArea[2], topbarArea[3], topbarArea[4]) then
		if resbarArea.metal[1] and IsOnRect(x, y, resbarArea.metal[1], resbarArea.metal[2], resbarArea.metal[3], resbarArea.metal[4]) then
			return true
		end
		if resbarArea.energy[1] and IsOnRect(x, y, resbarArea.energy[1], resbarArea.energy[2], resbarArea.energy[3], resbarArea.energy[4]) then
			return true
		end
		if windArea[1] and IsOnRect(x, y, windArea[1], windArea[2], windArea[3], windArea[4]) then
			return true
		end
		if displayComCounter and comsArea[1] and IsOnRect(x, y, comsArea[1], comsArea[2], comsArea[3], comsArea[4]) then
			return true
		end
		if showRejoinUI and rejoinArea[1] and IsOnRect(x, y, rejoinArea[1], rejoinArea[2], rejoinArea[3], rejoinArea[4]) then
			return true
		end
		if buttonsArea[1] and IsOnRect(x, y, buttonsArea[1], buttonsArea[2], buttonsArea[3], buttonsArea[4]) then
			return true
		end
		return false
	end
	return false
end

function widget:DrawScreen()
	if chobbyInterface then
		return
	end

	glPushMatrix()

	local now = os.clock()
	local x, y, b = spGetMouseState()
	hoveringTopbar = hoveringElement(x, y)

	if hoveringTopbar then
		Spring.SetMouseCursor('cursornormal')
	end

	gl.Texture(false)	-- because some other widget didnt do this

	local res = 'metal'
	if dlistResbar[res][1] and dlistResbar[res][2] and dlistResbar[res][3] then
		glCallList(dlistResbar[res][1])

		if not spec and gameFrame > 90 then
			if allyteamOverflowingMetal then
				glColor(1, 0, 0, 0.13 * allyteamOverflowingMetal * blinkProgress)
			elseif overflowingMetal then
				glColor(1, 1, 1, 0.05 * overflowingMetal * (0.6 + (blinkProgress * 0.4)))
			end
			if allyteamOverflowingMetal or overflowingMetal then
				glCallList(dlistResbar[res][4])
			end
		end
		-- low energy background
		if r[res][1] < 1000 then
			local process = (r[res][1] / r[res][2]) * 13
			if process < 1 then
				process = 1 - process
				glColor(0.9, 0.4, 1, 0.08 * process)
				glCallList(dlistResbar[res][5])
			end
		end
		drawResbarValues(res)
		glCallList(dlistResbar[res][6])
		glCallList(dlistResbar[res][3])
		glCallList(dlistResbar[res][2])
	end
	res = 'energy'
	if dlistResbar[res][1] and dlistResbar[res][2] and dlistResbar[res][3] then
		glCallList(dlistResbar[res][1])

		if not spec and gameFrame > 90 then
			if allyteamOverflowingEnergy then
				glColor(1, 0, 0, 0.13 * allyteamOverflowingEnergy * blinkProgress)
			elseif overflowingEnergy then
				glColor(1, 1, 0, 0.05 * overflowingEnergy * (0.6 + (blinkProgress * 0.4)))
			end
			if allyteamOverflowingEnergy or overflowingEnergy then
				glCallList(dlistResbar[res][4])
			end
			-- low energy background
			if r[res][1] < 2000 then
				local process = (r[res][1] / r[res][2]) * 13
				if process < 1 then
					process = 1 - process
					glColor(0.9, 0.55, 1, 0.08 * process)
					glCallList(dlistResbar[res][5])
				end
			end
		end
		drawResbarValues(res)
		glCallList(dlistResbar[res][6])
		glCallList(dlistResbar[res][3])
		glCallList(dlistResbar[res][2])
	end

	if dlistWind1 then
		glPushMatrix()
		glCallList(dlistWind1)
		glRotate(windRotation, 0, 0, 1)
		glCallList(dlistWind2)
		glPopMatrix()
		-- current wind
		if gameFrame > 0 then
			if minWind+maxWind >= 0.5 then
				local fontSize = (height / 2.66) * widgetScale
				if not dlistWindText[currentWind] then
					dlistWindText[currentWind] = glCreateList(function()
						font2:Begin()
						font2:Print("\255\255\255\255" .. currentWind, windArea[1] + ((windArea[3] - windArea[1]) / 2), windArea[2] + ((windArea[4] - windArea[2]) / 2.05) - (fontSize / 5), fontSize, 'oc') -- Wind speed text
						font2:End()
					end)
				end
				glCallList(dlistWindText[currentWind])
			end
		else
			if now < 90 and WG['tooltip'] ~= nil then
				local minh = height * 0.5
				if (minWind + maxWind) / 2 < 5.5 then
					WG['tooltip'].ShowTooltip('topbar_windinfo', texts.wind.worth1, windArea[1], windArea[2] - minh * widgetScale)
				elseif (minWind + maxWind) / 2 >= 5.5 and (minWind + maxWind) / 2 < 7 then
					WG['tooltip'].ShowTooltip('topbar_windinfo', texts.wind.worth2, windArea[1], windArea[2] - minh * widgetScale)
				elseif (minWind + maxWind) / 2 >= 7 and (minWind + maxWind) / 2 < 8.5 then
					WG['tooltip'].ShowTooltip('topbar_windinfo', texts.wind.worth3, windArea[1], windArea[2] - minh * widgetScale)
				elseif (minWind + maxWind) / 2 >= 8.5 and (minWind + maxWind) / 2 < 10 then
					WG['tooltip'].ShowTooltip('topbar_windinfo', texts.wind.worth4, windArea[1], windArea[2] - minh * widgetScale)
				elseif (minWind + maxWind) / 2 >= 10 and (minWind + maxWind) / 2 < 15 then
					WG['tooltip'].ShowTooltip('topbar_windinfo', texts.wind.worth5, windArea[1], windArea[2] - minh * widgetScale)
				elseif (minWind + maxWind) / 2 >= 15 then
					WG['tooltip'].ShowTooltip('topbar_windinfo', texts.wind.worth6, windArea[1], windArea[2] - minh * widgetScale)
				end
			end
		end
	end

	if displayComCounter and dlistComs1 then
		glCallList(dlistComs1)
		if allyComs == 1 and (gameFrame % 12 < 6) then
			glColor(1, 0.6, 0, 0.45)
		else
			glColor(1, 1, 1, 0.22)
		end
		glCallList(dlistComs2)
	end

	if dlistRejoin and showRejoinUI then
		glCallList(dlistRejoin)
	elseif dlistRejoin ~= nil then
		if dlistRejoin ~= nil then
			glDeleteList(dlistRejoin)
			dlistRejoin = nil
		end
		if WG['guishader'] then
			WG['guishader'].RemoveDlist('topbar_rejoin')
		end
		if WG['tooltip'] ~= nil then
			WG['tooltip'].RemoveTooltip('rejoin')
		end
	end

	if dlistButtons1 then
		glCallList(dlistButtons1)
		-- hovered?
		if not showQuitscreen and buttonsArea['buttons'] ~= nil and IsOnRect(x, y, buttonsArea[1], buttonsArea[2], buttonsArea[3], buttonsArea[4]) then
			for button, pos in pairs(buttonsArea['buttons']) do
				if IsOnRect(x, y, pos[1], pos[2], pos[3], pos[4]) then
					glBlending(GL_SRC_ALPHA, GL_ONE)
					RectRound(buttonsArea['buttons'][button][1], buttonsArea['buttons'][button][2], buttonsArea['buttons'][button][3], buttonsArea['buttons'][button][4], 3.5 * widgetScale, 0, 0, 0, button == firstButton and 1 or 0, { 1, 1, 1, b and 0.13 or 0.03 }, { 0.44, 0.44, 0.44, b and 0.4 or 0.2 })
					local mult = 1
					RectRound(buttonsArea['buttons'][button][1], buttonsArea['buttons'][button][4] - ((buttonsArea['buttons'][button][4] - buttonsArea['buttons'][button][2]) * 0.4), buttonsArea['buttons'][button][3], buttonsArea['buttons'][button][4], 3.3 * widgetScale, 0, 0, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.18 * mult })
					RectRound(buttonsArea['buttons'][button][1], buttonsArea['buttons'][button][2], buttonsArea['buttons'][button][3], buttonsArea['buttons'][button][2] + ((buttonsArea['buttons'][button][4] - buttonsArea['buttons'][button][2]) * 0.25), 3.3 * widgetScale, 0, 0, 0, button == firstButton and 1 or 0, { 1, 1, 1, 0.045 * mult }, { 1, 1, 1, 0 })
					glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
					break
				end
			end
		end
		glCallList(dlistButtons2)
	end

	if dlistQuit ~= nil then
		if WG['guishader'] then
			WG['guishader'].removeRenderDlist(dlistQuit)
		end
		glDeleteList(dlistQuit)
		dlistQuit = nil
	end
	if showQuitscreen ~= nil then
		local fadeoutBonus = 0
		local fadeTime = 0.2
		local fadeProgress = (now - showQuitscreen) / fadeTime
		if fadeProgress > 1 then
			fadeProgress = 1
		end

		Spring.SetMouseCursor('cursornormal')

		dlistQuit = glCreateList(function()
			if WG['guishader'] then
				glColor(0, 0, 0, (0.18 * fadeProgress))
			else
				glColor(0, 0, 0, (0.35 * fadeProgress))
			end
			glRect(0, 0, vsx, vsy)

			if hideQuitWindow == nil then
				-- when terminating spring, keep the faded screen

				local w = math_floor(320 * widgetScale)
				local h = math_floor(w / 3.5)
				local padding = math_floor(w / 90)
				local buttonPadding = math_floor(w / 90)
				local buttonMargin = math_floor(w / 30)
				local buttonHeight = math_floor(h * 0.55)
				local fontSize = h / 6
				local text = texts.quit.really_quit
				if not spec then
					text = texts.quit.really_quitresign
					if chobbyLoaded then
						if numPlayers < 3 then
							text = texts.quit.really_resign
						else
							text = texts.quit.really_resign2
						end
					end
				end
				local textTopPadding = padding + padding + padding + padding + padding + fontSize
				local txtWidth = font:GetTextWidth(text) * fontSize
				w = math.max(w, txtWidth + textTopPadding + textTopPadding)

				quitscreenArea = { math_floor((vsx / 2) - (w / 2)), math_floor((vsy / 1.8) - (h / 2)), math_floor((vsx / 2) + (w / 2)), math_floor((vsy / 1.8) + (h / 2)) }
				quitscreenResignArea = { math_floor((vsx / 2) - (w / 2) + buttonMargin), math_floor((vsy / 1.8) - (h / 2) + buttonMargin), math_floor((vsx / 2) - (buttonMargin / 2)), math_floor((vsy / 1.8) - (h / 2) + buttonHeight - buttonMargin) }
				quitscreenQuitArea = { math_floor((vsx / 2) + (buttonMargin / 2)), math_floor((vsy / 1.8) - (h / 2) + buttonMargin), math_floor((vsx / 2) + (w / 2) - buttonMargin), math_floor((vsy / 1.8) - (h / 2) + buttonHeight - buttonMargin) }

				-- window
				UiElement(quitscreenArea[1], quitscreenArea[2], quitscreenArea[3], quitscreenArea[4], 1,1,1,1, 1,1,1,1, nil, {1, 1, 1, 0.6 + (0.34 * fadeProgress)}, {0.45, 0.45, 0.4, 0.025 + (0.025 * fadeProgress)})

				font:Begin()
				font:SetTextColor(0, 0, 0, 1)
				font:Print(text, quitscreenArea[1] + ((quitscreenArea[3] - quitscreenArea[1]) / 2), quitscreenArea[4]-textTopPadding, fontSize, "cn")

				-- quit button
				local color1, color2
				local mult = 0.85
				if not chobbyLoaded then
					if IsOnRect(x, y, quitscreenQuitArea[1], quitscreenQuitArea[2], quitscreenQuitArea[3], quitscreenQuitArea[4]) then
						color1 = { 0.4, 0, 0, 0.4 + (0.5 * fadeProgress) }
						color2 = { 0.6, 0.05, 0.05, 0.4 + (0.5 * fadeProgress) }
						mult = 1.4
					else
						color1 = { 0.25, 0, 0, 0.35 + (0.5 * fadeProgress) }
						color2 = { 0.5, 0, 0, 0.35 + (0.5 * fadeProgress) }
					end
					UiButton(quitscreenQuitArea[1], quitscreenQuitArea[2], quitscreenQuitArea[3], quitscreenQuitArea[4], 1,1,1,1, 1,1,1,1, nil, color1, color2, padding * 0.5)
				end
				font:End()

				fontSize = fontSize * 0.92
				font2:Begin()
				if not chobbyLoaded then
					font2:SetTextColor(1, 1, 1, 1)
					font2:SetOutlineColor(0, 0, 0, 0.23)
					font2:Print(texts.quit.quit, quitscreenQuitArea[1] + ((quitscreenQuitArea[3] - quitscreenQuitArea[1]) / 2), quitscreenQuitArea[2] + ((quitscreenQuitArea[4] - quitscreenQuitArea[2]) / 2) - (fontSize / 3), fontSize, "con")
				end
				-- resign button
				mult = 0.85
				if not spec then
					if IsOnRect(x, y, quitscreenResignArea[1], quitscreenResignArea[2], quitscreenResignArea[3], quitscreenResignArea[4]) then
						color1 = { 0.28, 0.28, 0.28, 0.4 + (0.5 * fadeProgress) }
						color2 = { 0.45, 0.45, 0.45, 0.4 + (0.5 * fadeProgress) }
						mult = 1.3
					else
						color1 = { 0.18, 0.18, 0.18, 0.4 + (0.5 * fadeProgress) }
						color2 = { 0.33, 0.33, 0.33, 0.4 + (0.5 * fadeProgress) }
					end
					UiButton(quitscreenResignArea[1], quitscreenResignArea[2], quitscreenResignArea[3], quitscreenResignArea[4], 1,1,1,1, 1,1,1,1, nil, color1, color2, padding * 0.5)

					font2:Print(texts.quit.resign, quitscreenResignArea[1] + ((quitscreenResignArea[3] - quitscreenResignArea[1]) / 2), quitscreenResignArea[2] + ((quitscreenResignArea[4] - quitscreenResignArea[2]) / 2) - (fontSize / 3), fontSize, "con")
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
	glColor(1, 1, 1, 1)
	glPopMatrix()
end

function IsOnRect(x, y, BLcornerX, BLcornerY, TRcornerX, TRcornerY)
	return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
end

local function adjustSliders(x, y)
	if draggingShareIndicator ~= nil and not spec then
		local shareValue = (x - resbarDrawinfo[draggingShareIndicator]['barArea'][1]) / (resbarDrawinfo[draggingShareIndicator]['barArea'][3] - resbarDrawinfo[draggingShareIndicator]['barArea'][1])
		if shareValue < 0 then
			shareValue = 0
		end
		if shareValue > 1 then
			shareValue = 1
		end
		Spring.SetShareLevel(draggingShareIndicator, shareValue)
		draggingShareIndicatorValue[draggingShareIndicator] = shareValue
		updateResbar(draggingShareIndicator)
	end
	if showConversionSlider and draggingConversionIndicator and not spec then
		local convValue = math_floor((x - resbarDrawinfo['energy']['barArea'][1]) / (resbarDrawinfo['energy']['barArea'][3] - resbarDrawinfo['energy']['barArea'][1]) * 100)
		if convValue < 12 then
			convValue = 12
		end
		if convValue > 88 then
			convValue = 88
		end
		Spring.SendLuaRulesMsg(sformat(string.char(137) .. '%i', convValue))
		draggingConversionIndicatorValue = convValue
		updateResbar('energy')
	end
end

function widget:MouseMove(x, y)
	adjustSliders(x, y)
end

local function hideWindows()
	local closedWindow = false
	if WG['options'] ~= nil and WG['options'].isvisible() then
		WG['options'].toggle(false)
		closedWindow = true
	end
	if WG['scavengerinfo'] ~= nil and WG['scavengerinfo'].isvisible() then
		WG['scavengerinfo'].toggle(false)
		closedWindow = true
	end
	if WG['changelog'] ~= nil and WG['changelog'].isvisible() then
		WG['changelog'].toggle(false)
		closedWindow = true
	end
	if WG['keybinds'] ~= nil and WG['keybinds'].isvisible() then
		WG['keybinds'].toggle(false)
		closedWindow = true
	end
	if WG['gameinfo'] ~= nil and WG['gameinfo'].isvisible() then
		WG['gameinfo'].toggle(false)
		closedWindow = true
	end
	if WG['teamstats'] ~= nil and WG['teamstats'].isvisible() then
		WG['teamstats'].toggle(false)
		closedWindow = true
	end
	if WG['widgetselector'] ~= nil and WG['widgetselector'].isvisible() then
		WG['widgetselector'].toggle(false)
		closedWindow = true
	end
	if showQuitscreen then
		closedWindow = true
	end
	showQuitscreen = nil
	if WG['guishader'] then
		WG['guishader'].setScreenBlur(false)
	end
	return closedWindow
end

local function applyButtonAction(button)

	if playSounds then
		Spring.PlaySoundFile(leftclick, 0.8, 'ui')
	end

	local isvisible = false
	if button == 'quit' or button == 'resign' then
		if chobbyLoaded and button == 'quit' then
			Spring.SendLuaMenuMsg("showLobby")
		else
			local oldShowQuitscreen
			if showQuitscreen ~= nil then
				oldShowQuitscreen = showQuitscreen
				isvisible = true
			end
			hideWindows()
			if oldShowQuitscreen ~= nil then
				if isvisible ~= true then
					showQuitscreen = oldShowQuitscreen
					if WG['guishader'] then
						WG['guishader'].setScreenBlur(true)
					end
				end
			else
				showQuitscreen = os.clock()
			end
		end
	elseif button == 'options' then
		if WG['options'] ~= nil then
			isvisible = WG['options'].isvisible()
		end
		hideWindows()
		if WG['options'] ~= nil and isvisible ~= true then
			WG['options'].toggle()
		end
	elseif button == 'scavengers' then
		if WG['scavengerinfo'] ~= nil then
			isvisible = WG['scavengerinfo'].isvisible()
		end
		hideWindows()
		if WG['scavengerinfo'] ~= nil and isvisible ~= true then
			WG['scavengerinfo'].toggle()
		end
	elseif button == 'changelog' then
		if WG['changelog'] ~= nil then
			isvisible = WG['changelog'].isvisible()
		end
		hideWindows()
		if WG['changelog'] ~= nil and isvisible ~= true then
			WG['changelog'].toggle()
		end
	elseif button == 'keybinds' then
		if WG['keybinds'] ~= nil then
			isvisible = WG['keybinds'].isvisible()
		end
		hideWindows()
		if WG['keybinds'] ~= nil and isvisible ~= true then
			WG['keybinds'].toggle()
		end
	elseif button == 'commands' then
		if WG['commands'] ~= nil then
			isvisible = WG['commands'].isvisible()
		end
		hideWindows()
		if WG['commands'] ~= nil and isvisible ~= true then
			WG['commands'].toggle()
		end
	elseif button == 'stats' then
		if WG['teamstats'] ~= nil then
			isvisible = WG['teamstats'].isvisible()
		end
		hideWindows()
		if WG['teamstats'] ~= nil and isvisible ~= true then
			WG['teamstats'].toggle()
		end
	end
end

function widget:MouseWheel(up, value)
	--up = true/false , value = -1/1
	if showQuitscreen ~= nil and quitscreenArea ~= nil then
		return true
	end
end

function widget:KeyPress(key)
	if key == 27 then
		-- ESC
		if not WG['options'] or (WG['options'].disallowEsc and not WG['options'].disallowEsc()) then
			local escDidSomething = hideWindows()
			if escapeKeyPressesQuit and not escDidSomething then
				applyButtonAction('quit')
			end
		end
	end
	if showQuitscreen ~= nil and quitscreenArea ~= nil then
		return true
	end
end

function widget:MousePress(x, y, button)
	if button == 1 then
		if showQuitscreen ~= nil and quitscreenArea ~= nil then

			if IsOnRect(x, y, quitscreenArea[1], quitscreenArea[2], quitscreenArea[3], quitscreenArea[4]) then

				if not chobbyLoaded and IsOnRect(x, y, quitscreenQuitArea[1], quitscreenQuitArea[2], quitscreenQuitArea[3], quitscreenQuitArea[4]) then
					if playSounds then
						Spring.PlaySoundFile(leftclick, 0.75, 'ui')
					end
					Spring.SendCommands("QuitForce")
					showQuitscreen = nil
					hideQuitWindow = os.clock()
				end
				if not spec and IsOnRect(x, y, quitscreenResignArea[1], quitscreenResignArea[2], quitscreenResignArea[3], quitscreenResignArea[4]) then
					if playSounds then
						Spring.PlaySoundFile(leftclick, 0.75, 'ui')
					end
					Spring.SendCommands("spectator")
					showQuitscreen = nil
					if WG['guishader'] then
						WG['guishader'].setScreenBlur(false)
					end
				end
			else
				showQuitscreen = nil
				if WG['guishader'] then
					WG['guishader'].setScreenBlur(false)
				end
			end
			return true
		end

		if not spec then
			if IsOnRect(x, y, shareIndicatorArea['metal'][1], shareIndicatorArea['metal'][2], shareIndicatorArea['metal'][3], shareIndicatorArea['metal'][4]) then
				draggingShareIndicator = 'metal'
			end
			if IsOnRect(x, y, resbarDrawinfo['metal'].barArea[1], shareIndicatorArea['metal'][2], resbarDrawinfo['metal'].barArea[3], shareIndicatorArea['metal'][4]) then
				draggingShareIndicator = 'metal'
				adjustSliders(x, y)
			end
			if IsOnRect(x, y, shareIndicatorArea['energy'][1], shareIndicatorArea['energy'][2], shareIndicatorArea['energy'][3], shareIndicatorArea['energy'][4]) then
				draggingShareIndicator = 'energy'
			end
			if draggingShareIndicator == nil and showConversionSlider and IsOnRect(x, y, conversionIndicatorArea[1], conversionIndicatorArea[2], conversionIndicatorArea[3], conversionIndicatorArea[4]) then
				draggingConversionIndicator = true
			end
			if draggingConversionIndicator == nil and IsOnRect(x, y, resbarDrawinfo['energy'].barArea[1], shareIndicatorArea['energy'][2], resbarDrawinfo['energy'].barArea[3], shareIndicatorArea['energy'][4]) then
				draggingShareIndicator = 'energy'
				adjustSliders(x, y)
			end
			if draggingShareIndicator or draggingConversionIndicator then
				if playSounds then
					Spring.PlaySoundFile(resourceclick, 0.7, 'ui')
				end
				return true
			end
		end

		if buttonsArea['buttons'] ~= nil then
			for button, pos in pairs(buttonsArea['buttons']) do
				if IsOnRect(x, y, pos[1], pos[2], pos[3], pos[4]) then
					applyButtonAction(button)
					return true
				end
			end
		end
	else
		if showQuitscreen ~= nil and quitscreenArea ~= nil then
			return true
		end
	end

	if hoveringTopbar then
		return true
	end
end

function widget:MouseRelease(x, y, button)
	if showQuitscreen ~= nil and quitscreenArea ~= nil then
		return true
	end
	if draggingShareIndicator ~= nil then
		adjustSliders(x, y)
		draggingShareIndicator = nil
	end
	if draggingConversionIndicator ~= nil then
		adjustSliders(x, y)
		draggingConversionIndicator = nil
	end

	--if button == 1 then
	--	if buttonsArea['buttons'] ~= nil then	-- reapply again because else the other widgets disable when there is a click outside of their window
	--		for button, pos in pairs(buttonsArea['buttons']) do
	--			if IsOnRect(x, y, pos[1], pos[2], pos[3], pos[4]) then
	--				applyButtonAction(button)
	--			end
	--		end
	--	end
	--end
end

function widget:PlayerChanged()
	local prevSpec = spec
	spec = spGetSpectatingState()
	checkStatus()
	numTeamsInAllyTeam = #Spring.GetTeamList(myAllyTeamID)
	if displayComCounter then
		countComs(true)
	end
	if spec then
		resbarHover = nil
	end
	if not prevSpec and prevSpec ~= spec then
		init()
	end
end

function countComs(forceUpdate)
	-- recount my own ally team coms
	local prevAllyComs = allyComs
	local prevEnemyComs = enemyComs
	allyComs = 0
	local myAllyTeamList = Spring.GetTeamList(myAllyTeamID)
	for _, teamID in ipairs(myAllyTeamList) do
		allyComs = allyComs + Spring.GetTeamUnitDefCount(teamID, armcomDefID) + Spring.GetTeamUnitDefCount(teamID, corcomDefID)
	end

	local newEnemyComCount = Spring.GetTeamRulesParam(myTeamID, "enemyComCount")
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

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if not isCommander[unitDefID] then
		return
	end
	--record com created
	if select(6, Spring.GetTeamInfo(unitTeam, false)) == myAllyTeamID then
		allyComs = allyComs + 1
	elseif spec then
		enemyComs = enemyComs + 1
	end
	comcountChanged = true
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if not isCommander[unitDefID] then
		return
	end
	--record com died
	if select(6, Spring.GetTeamInfo(unitTeam, false)) == myAllyTeamID then
		allyComs = allyComs - 1
	elseif spec then
		enemyComs = enemyComs - 1
	end
	comcountChanged = true
end


-- used for rejoin progress functionality
function widget:GameProgress (n)
	-- happens every 300 frames
	serverFrame = n
end


function widget:Initialize()

	gameFrame = Spring.GetGameFrame()
	Spring.SendCommands("resbar 0")

	-- determine if we want to show comcounter
	local allteams = Spring.GetTeamList()
	local teamN = table.maxn(allteams) - 1               --remove gaia
	if teamN > 2 then
		displayComCounter = true
	end

	WG['topbar'] = {}
	WG['topbar'].showingRejoining = function()
		return showRejoinUI
	end
	WG['topbar'].showingQuit = function()
		return (showQuitscreen ~= nil)
	end
	WG['topbar'].hideWindows = function()
		hideWindows()
	end

	if WG['lang'] then
		texts = WG['lang'].getText('topbar')
	end

	widget:ViewResize()

	if gameFrame > 0 then
		widget:GameStart()
	end
end

function shutdown()
	if dlistButtons1 ~= nil then
		dlistWindGuishader = glDeleteList(dlistWindGuishader)
		dlistWind1 = glDeleteList(dlistWind1)
		dlistWind2 = glDeleteList(dlistWind2)
		dlistComsGuishader = glDeleteList(dlistComsGuishader)
		dlistComs1 = glDeleteList(dlistComs1)
		dlistComs2 = glDeleteList(dlistComs2)
		dlistButtonsGuishader = glDeleteList(dlistButtonsGuishader)
		dlistButtons1 = glDeleteList(dlistButtons1)
		dlistButtons2 = glDeleteList(dlistButtons2)
		dlistRejoinGuishader = glDeleteList(dlistRejoinGuishader)
		dlistRejoin = glDeleteList(dlistRejoin)
		dlistQuit = glDeleteList(dlistQuit)

		for n, _ in pairs(dlistWindText) do
			dlistWindText[n] = glDeleteList(dlistWindText[n])
		end
		for n, _ in pairs(dlistResbar['metal']) do
			dlistResbar['metal'][n] = glDeleteList(dlistResbar['metal'][n])
		end
		for n, _ in pairs(dlistResbar['energy']) do
			dlistResbar['energy'][n] = glDeleteList(dlistResbar['energy'][n])
		end
		for n, _ in pairs(dlistResValues['metal']) do
			dlistResValues['metal'][n] = glDeleteList(dlistResValues['metal'][n])
		end
		for n, _ in pairs(dlistResValues['energy']) do
			dlistResValues['energy'][n] = glDeleteList(dlistResValues['energy'][n])
		end
	end
	if WG['guishader'] then
		WG['guishader'].RemoveDlist('topbar_energy')
		WG['guishader'].RemoveDlist('topbar_metal')
		WG['guishader'].RemoveDlist('topbar_wind')
		WG['guishader'].RemoveDlist('topbar_coms')
		WG['guishader'].RemoveDlist('topbar_buttons')
		WG['guishader'].RemoveDlist('topbar_rejoin')
	end
	if WG['tooltip'] ~= nil then
		WG['tooltip'].RemoveTooltip('coms')
		WG['tooltip'].RemoveTooltip('wind')
		WG['tooltip'].RemoveTooltip('rejoin')
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
end

function widget:Shutdown()
	Spring.SendCommands("resbar 1")
	shutdown()
	WG['topbar'] = nil
end
