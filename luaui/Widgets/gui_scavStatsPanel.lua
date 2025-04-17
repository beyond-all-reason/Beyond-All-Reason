if not (Spring.Utilities.Gametype.IsScavengers() and not Spring.Utilities.Gametype.IsRaptors()) then
	return false
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Scav Stats Panel",
		desc = "Shows statistics and progress when fighting vs Scavs",
		author = "quantum",
		date = "May 04, 2008",
		license = "GNU GPL, v2 or later",
		layer = -9,
		enabled = true
	}
end

local config = VFS.Include('LuaRules/Configs/scav_spawn_defs.lua')

local customScale = 1
local widgetScale = customScale
local font, font2
local messageArgs, marqueeMessage
local refreshMarqueeMessage = false
local showMarqueeMessage = false

if not Spring.Utilities.Gametype.IsScavengers() then
	return false
end

if not Spring.GetGameRulesParam("scavDifficulty") then
	return false
end

local GetGameSeconds = Spring.GetGameSeconds

local displayList
local panelTexture = ":n:LuaUI/Images/scavpanel.png"

local panelFontSize = 14
local waveFontSize = 36

local vsx, vsy = Spring.GetViewGeometry()
local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")

local viewSizeX, viewSizeY = 0, 0
local w = 300
local h = 210
local x1 = 0
local y1 = 0
local panelMarginX = 15
local panelMarginY = 25
local panelSpacingY = 5
local waveSpacingY = 7
local moving
local capture
local gameInfo
local waveSpeed = 0.1
local waveCount = 0
local waveTime
local bossToastTimer = Spring.GetTimer()
local enabled
local gotScore
local scoreCount = 0
local resistancesTable = {}
local currentlyResistantTo = {}
local currentlyResistantToNames = {}

local guiPanel --// a displayList
local updatePanel
local hasScavEvent = false

local difficultyOption = Spring.GetModOptions().scav_difficulty
local nBosses = Spring.GetModOptions().scav_boss_count

local rules = {
	"scavBossTime",
	"scavBossAnger",
	"scavBossesKilled",
	"scavTechAnger",
	"scavGracePeriod",
	"scavBossHealth",
	"lagging",
	"scavDifficulty",
	"scavCount",
}

local waveColor = "\255\255\0\0"
local textColor = "\255\255\255\255"

local function commaValue(amount)
	local formatted = amount
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if k == 0 then
			break
		end
	end
	return formatted
end

local function getScavCounts(type)
	local total = 0
	local subtotal

	return total
end

local function updatePos(x, y)
	x1 = math.min((viewSizeX * 0.94) - (w * widgetScale) / 2, x)
	y1 = math.min((viewSizeY * 0.89) - (h * widgetScale) / 2, y)
	updatePanel = true
end

local function PanelRow(n)
	return h - panelMarginY - (n - 1) * (panelFontSize + panelSpacingY)
end

local function WaveRow(n)
	return n * (waveFontSize + waveSpacingY)
end

local function CreatePanelDisplayList()
	gl.PushMatrix()
	gl.Translate(x1, y1, 0)
	gl.Scale(widgetScale, widgetScale, 1)
	gl.CallList(displayList)
	font:Begin()
	font:SetTextColor(1, 1, 1, 1)
	font:SetOutlineColor(0, 0, 0, 1)
	local currentTime = GetGameSeconds()
	--if currentTime > gameInfo.scavGracePeriod then
		if gameInfo.scavBossAnger < 100 then

			local gain = 0
			if Spring.GetGameRulesParam("ScavBossAngerGain_Base") then
				font:Print(textColor .. Spring.I18N('ui.scavs.bossAngerBase', { value = math.round(Spring.GetGameRulesParam("ScavBossAngerGain_Base"), 3) }), panelMarginX+5, PanelRow(3), panelFontSize, "")
				font:Print(textColor .. Spring.I18N('ui.scavs.bossAngerAggression', { value = math.round(Spring.GetGameRulesParam("ScavBossAngerGain_Aggression"), 3) }), panelMarginX+5, PanelRow(4), panelFontSize, "")
				--font:Print(textColor .. Spring.I18N('ui.scavs.bossAngerEco', { value = math.round(Spring.GetGameRulesParam("ScavBossAngerGain_Eco"), 3) }), panelMarginX+5, PanelRow(5), panelFontSize, "")
				gain = math.round(Spring.GetGameRulesParam("ScavBossAngerGain_Base"), 3) + math.round(Spring.GetGameRulesParam("ScavBossAngerGain_Aggression"), 3) + math.round(Spring.GetGameRulesParam("ScavBossAngerGain_Eco"), 3)
			end
			--font:Print(textColor .. Spring.I18N('ui.scavs.bossAngerWithGain', { anger = gameInfo.scavBossAnger, gain = math.round(gain, 3) }), panelMarginX, PanelRow(1), panelFontSize, "")
			font:Print(textColor .. Spring.I18N('ui.scavs.bossAngerWithTech', { anger = math.floor(0.5+gameInfo.scavBossAnger), techAnger = gameInfo.scavTechAnger}), panelMarginX, PanelRow(1), panelFontSize, "")

			local totalSeconds = ((100 - gameInfo.scavBossAnger) / gain)
			if currentTime <= gameInfo.scavGracePeriod then
				totalSeconds = totalSeconds - math.min(30, (currentTime - gameInfo.scavGracePeriod + 30))
			end
			time = string.formatTime(totalSeconds)
			if totalSeconds < 1800 or revealedBossEta then
				if not revealedBossEta then revealedBossEta = true end
				font:Print(textColor .. Spring.I18N('ui.scavs.bossETA', { count = nBosses, time = time }), panelMarginX+5, PanelRow(2), panelFontSize, "")
			end
			if #currentlyResistantToNames > 0 then
				currentlyResistantToNames = {}
				currentlyResistantTo = {}
			end
		else
			font:Print(textColor .. Spring.I18N('ui.scavs.bossHealth', { count = nBosses, health = gameInfo.scavBossHealth }), panelMarginX, PanelRow(1), panelFontSize, "")
			if nBosses > 1 then
				font:Print(textColor .. Spring.I18N('ui.scavs.bossesKilled', { nKilled = gameInfo.scavBossesKilled, nTotal = nBosses }), panelMarginX, PanelRow(2), panelFontSize, "")
			end
			for i = 1,#currentlyResistantToNames do
				if i == 1 then
					font:Print(textColor .. Spring.I18N('ui.scavs.bossResistantToList', { count = nBosses}), panelMarginX, PanelRow(12), panelFontSize, "")
				end
				font:Print(textColor .. currentlyResistantToNames[i], panelMarginX+20, PanelRow(12+i), panelFontSize, "")
			end
		end
	--else
	--	font:Print(textColor .. Spring.I18N('ui.scavs.gracePeriod', { time = string.formatTime(math.ceil(((currentTime - gameInfo.scavGracePeriod) * -1) - 0.5)) }), panelMarginX, PanelRow(1), panelFontSize, "")
	--end

	-- font:Print(textColor .. Spring.I18N('ui.scavs.scavKillCount', { count = gameInfo.scavKills }), panelMarginX, PanelRow(6), panelFontSize, "")
	local endless = ""
	if Spring.GetModOptions().scav_endless then
		endless = ' (' .. Spring.I18N('ui.scavs.difficulty.endless') .. ')'
	end
	local difficultyCaption = Spring.I18N('ui.scavs.difficulty.' .. difficultyOption)
	font:Print(textColor .. Spring.I18N('ui.scavs.mode', { mode = difficultyCaption }) .. endless, panelMarginX, h - 195, panelFontSize, "")
	font:End()

	gl.Texture(false)
	gl.PopMatrix()
end

local function getMarqueeMessage(scavEventArgs)
	local messages = {}
	--if scavEventArgs.type == "firstWave" then
	--	messages[1] = textColor .. Spring.I18N('ui.scavs.firstWave1')
	--	messages[2] = textColor .. Spring.I18N('ui.scavs.firstWave2')
	--else
	if scavEventArgs.type == "boss" then
		messages[1] = textColor .. Spring.I18N('ui.scavs.bossIsAngry1', { count = nBosses })
		messages[2] = textColor .. Spring.I18N('ui.scavs.bossIsAngry2')
	elseif scavEventArgs.type == "airWave" then
		messages[1] = textColor .. Spring.I18N('ui.scavs.wave1', {waveNumber = scavEventArgs.waveCount})
		messages[2] = textColor .. Spring.I18N('ui.scavs.airWave1')
		messages[3] = textColor .. Spring.I18N('ui.scavs.airWave2', {unitCount = scavEventArgs.number})
	elseif scavEventArgs.type == "wave" then
		messages[1] = textColor .. Spring.I18N('ui.scavs.wave1', {waveNumber = scavEventArgs.waveCount})
		messages[2] = textColor .. Spring.I18N('ui.scavs.wave2', {unitCount = scavEventArgs.number})
	end

	refreshMarqueeMessage = false

	return messages
end

local function getResistancesMessage()
	local messages = {}
	messages[1] = textColor .. (Spring.I18N('ui.scavs.resistanceUnits', { count = nBosses }))
	for i = 1,#resistancesTable do
		local attackerName = UnitDefs[resistancesTable[i]].name
		if string.sub(attackerName, -5,-1) == "_scav" then
			local attackerNameNonScav = string.sub(attackerName, 1, -6)
			if UnitDefNames[attackerNameNonScav].customParams.i18nfromunit then
				attackerNameNonScav = UnitDefNames[attackerNameNonScav].customParams.i18nfromunit
			end
			messages[i+1] = textColor .. "Scav " .. Spring.I18N('units.names.' .. attackerNameNonScav)
			currentlyResistantToNames[#currentlyResistantToNames+1] = "Scav " .. Spring.I18N('units.names.' .. attackerNameNonScav)
		else
			if UnitDefNames[attackerName].customParams.i18nfromunit then
				attackerName = UnitDefNames[attackerName].customParams.i18nfromunit
			end
			messages[i+1] = textColor .. Spring.I18N('units.names.' .. attackerName)
			currentlyResistantToNames[#currentlyResistantToNames+1] = Spring.I18N('units.names.' .. attackerName)
		end
	end
	resistancesTable = {}

	refreshMarqueeMessage = false


	return messages
end

local function Draw()
	if not enabled or not gameInfo then
		return
	end

	if updatePanel then
		if (guiPanel) then
			gl.DeleteList(guiPanel);
			guiPanel = nil
		end
		guiPanel = gl.CreateList(CreatePanelDisplayList)
		updatePanel = false
	end

	if guiPanel then
		gl.CallList(guiPanel)
	end

	if showMarqueeMessage then
		local t = Spring.GetTimer()

		local waveY = viewSizeY - Spring.DiffTimers(t, waveTime) * waveSpeed * viewSizeY
		if waveY > 0 then
			if refreshMarqueeMessage or not marqueeMessage then
				marqueeMessage = getMarqueeMessage(messageArgs)
			end

			font2:Begin()
			for i, message in ipairs(marqueeMessage) do
				font2:Print(message, viewSizeX / 2, waveY - (WaveRow(i) * widgetScale), waveFontSize * widgetScale, "co")
			end
			font2:End()
		else
			showMarqueeMessage = false
			messageArgs = nil
			waveY = viewSizeY
		end
	elseif #resistancesTable > 0 then
		marqueeMessage = getResistancesMessage()
		waveTime = Spring.GetTimer()
		showMarqueeMessage = true
	end
end

local function UpdateRules()
	if not gameInfo then
		gameInfo = {}
	end

	for _, rule in ipairs(rules) do
		gameInfo[rule] = Spring.GetGameRulesParam(rule) or 0
	end
	gameInfo.scavCounts = getScavCounts('Count')
	gameInfo.scavKills = getScavCounts('Kills')

	updatePanel = true
end

function ScavEvent(scavEventArgs)
	if scavEventArgs.type == "firstWave" or (scavEventArgs.type == "boss" and Spring.DiffTimers(Spring.GetTimer(), bossToastTimer) > 10) then
		showMarqueeMessage = true
		refreshMarqueeMessage = true
		messageArgs = scavEventArgs
		waveTime = Spring.GetTimer()
		if scavEventArgs.type == "boss" then
			bossToastTimer = Spring.GetTimer()
		end
	end

	if scavEventArgs.type == "bossResistance" then
		if scavEventArgs.number then
			if not currentlyResistantTo[scavEventArgs.number] then
				table.insert(resistancesTable, scavEventArgs.number)
				currentlyResistantTo[scavEventArgs.number] = true
			end
		end
	end

	if (scavEventArgs.type == "wave" or scavEventArgs.type == "airWave") and config.useWaveMsg and gameInfo.scavBossAnger <= 99 then
		waveCount = waveCount + 1
		scavEventArgs.waveCount = waveCount
		showMarqueeMessage = true
		refreshMarqueeMessage = true
		messageArgs = scavEventArgs
		waveTime = Spring.GetTimer()
	end
end

function widget:Initialize()
	widget:ViewResize()

	displayList = gl.CreateList(function()
		gl.Blending(true)
		gl.Color(1, 1, 1, 1)
		gl.Texture(panelTexture)
		gl.TexRect(0, 0, w, h)
	end)

	widgetHandler:RegisterGlobal("ScavEvent", ScavEvent)
	UpdateRules()
	viewSizeX, viewSizeY = gl.GetViewSizes()
	local x = math.abs(math.floor(viewSizeX - 320))
	local y = math.abs(math.floor(viewSizeY - 300))

	-- reposition if raptors panel is shown as well
	--if Spring.Utilities.Gametype.IsRaptors() then
	--	x = x - 315
	--end

	updatePos(x, y)
end

function widget:Shutdown()
	if hasScavEvent then
		Spring.SendCommands({ "luarules HasScavEvent 0" })
	end

	if guiPanel then
		gl.DeleteList(guiPanel);
		guiPanel = nil
	end

	gl.DeleteList(displayList)
	gl.DeleteTexture(panelTexture)
	widgetHandler:DeregisterGlobal("ScavEvent")
end

function widget:GameFrame(n)
	if not hasScavEvent and n > 1 then
		Spring.SendCommands({ "luarules HasScavEvent 1" })
		hasScavEvent = true
	end
	if n % 30 < 1 then
		UpdateRules()
		if not enabled and n > 1 then
			enabled = true
		end
	end
	if gotScore then
		local sDif = gotScore - scoreCount
		if sDif > 0 then
			scoreCount = scoreCount + math.ceil(sDif / 7.654321)
			if scoreCount > gotScore then
				scoreCount = gotScore
			else
				updatePanel = true
			end
		end
	end
end



function widget:DrawScreen()
	Draw()
end

function widget:MouseMove(x, y, dx, dy, button)
	if enabled and moving then
		updatePos(x1 + dx, y1 + dy)
	end
end

function widget:MousePress(x, y, button)
	if enabled and
		x > x1 and x < x1 + (w * widgetScale) and
		y > y1 and y < y1 + (h * widgetScale)
	then
		capture = true
		moving = true
	end
	return capture
end

function widget:MouseRelease(x, y, button)
	if not enabled then
		return
	end
	capture = nil
	moving = nil
	return capture
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()

	font = WG['fonts'].getFont()
	font2 = WG['fonts'].getFont(fontfile2)

	x1 = math.floor(x1 - viewSizeX)
	y1 = math.floor(y1 - viewSizeY)
	viewSizeX, viewSizeY = vsx, vsy
	widgetScale = (0.75 + (viewSizeX * viewSizeY / 10000000)) * customScale
	x1 = viewSizeX + x1 + ((x1 / 2) * (widgetScale - 1))
	y1 = viewSizeY + y1 + ((y1 / 2) * (widgetScale - 1))
end

function widget:LanguageChanged()
	refreshMarqueeMessage = true
	updatePanel = true
end
