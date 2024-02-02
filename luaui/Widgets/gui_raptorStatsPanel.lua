function widget:GetInfo()
	return {
		name = "Raptor Stats Panel",
		desc = "Shows statistics and progress when fighting vs Raptors",
		author = "quantum",
		date = "May 04, 2008",
		license = "GNU GPL, v2 or later",
		layer = -9,
		enabled = true  --  loaded by default?
	}
end

local config = VFS.Include('LuaRules/Configs/raptor_spawn_defs.lua')

local customScale = 1
local widgetScale = customScale
local font, font2
local messageArgs, marqueeMessage
local refreshMarqueeMessage = false
local showMarqueeMessage = false

if not Spring.Utilities.Gametype.IsRaptors() then
	return false
end

if not Spring.GetGameRulesParam("raptorDifficulty") then
	return false
end

local GetGameSeconds = Spring.GetGameSeconds

local displayList
local panelTexture = ":n:LuaUI/Images/raptorpanel.tga"

local panelFontSize = 14
local waveFontSize = 36

local vsx, vsy = Spring.GetViewGeometry()
local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")

local viewSizeX, viewSizeY = 0, 0
local w = 300
local h = 210
local x1 = 0
local y1 = 0
local panelMarginX = 30
local panelMarginY = 40
local panelSpacingY = 5
local waveSpacingY = 7
local moving
local capture
local gameInfo
local waveSpeed = 0.1
local waveCount = 0
local waveTime
local enabled
local gotScore
local scoreCount = 0
local resistancesTable = {}
local currentlyResistantTo = {}
local currentlyResistantToNames = {}

local guiPanel --// a displayList
local updatePanel
local hasRaptorEvent = false

local difficultyOption = Spring.GetModOptions().raptor_difficulty

local rules = {
	"raptorQueenTime",
	"raptorQueenAnger",
	"raptorTechAnger",
	"raptorGracePeriod",
	"raptorQueenHealth",
	"lagging",
	"raptorDifficulty",
	"raptorCount",
	"raptoraCount",
	"raptorsCount",
	"raptorfCount",
	"raptorrCount",
	"raptorwCount",
	"raptorcCount",
	"raptorpCount",
	"raptorhCount",
	"raptor_turretCount",
	"raptor_dodoCount",
	"raptor_hiveCount",
	"raptorKills",
	"raptoraKills",
	"raptorsKills",
	"raptorfKills",
	"raptorrKills",
	"raptorwKills",
	"raptorcKills",
	"raptorpKills",
	"raptorhKills",
	"raptor_turretKills",
	"raptor_dodoKills",
	"raptor_hiveKills",
}

local waveColor = "\255\255\0\0"
local textColor = "\255\255\255\255"


local raptorTypes = {
	"raptor",
	"raptora",
	"raptorh",
	"raptors",
	"raptorw",
	"raptor_dodo",
	"raptorp",
	"raptorf",
	"raptorc",
	"raptorr",
	"raptor_turret",
}

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

local function getRaptorCounts(type)
	local total = 0
	local subtotal

	for _, raptorType in ipairs(raptorTypes) do
		subtotal = gameInfo[raptorType .. type]
		total = total + subtotal
	end

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

function Interpolate(value, inMin, inMax, outMin, outMax)
	-- Define the range of input values (100 to 500)
	local minValue = inMin
	local maxValue = inMax

	-- Define the range of output values (1 to 0.4)
	local minOutputValue = outMin
	local maxOutputValue = outMax

	-- Ensure the value is within the specified range
	value = math.max(minValue, math.min(maxValue, value))

	-- Calculate the interpolation
	local t = (value - minValue) / (maxValue - minValue)
	local result = minOutputValue + t * (maxOutputValue - minOutputValue)

	return result
end

function TruncateTextToPixelWidth(text, width)
	while font:GetTextWidth(text) * panelFontSize > width and text:len() >= 0 do
		text = text:sub(1, -2)
	end
	return text
end

function DrawPlayerEcoInfos(row)
	font:Print(textColor .. 'Player Ecos:', panelMarginX, PanelRow(row), panelFontSize, "")
	local playersEcoInfo = GetPlayersEcoInfo(7 - row)

	for i = 1, #playersEcoInfo do
		local playerEcoInfo = playersEcoInfo[i]
		local gb = 1
		local alpha = 1
		if playerEcoInfo.value > 170 then
			gb = Interpolate(playerEcoInfo.value, 170, 600, 0.5, 0.3)
		elseif playerEcoInfo.value > 100 then
			gb = Interpolate(playerEcoInfo.value, 100, 170, 0.8, 0.5)
		elseif playerEcoInfo.value < 80 then
			alpha = Interpolate(playerEcoInfo.value, 0, 70, 1, 0.8)
		end
		font:SetTextColor(1, gb, gb, playerEcoInfo.forced and 0.6 or alpha)

		local namePosX = panelMarginX + 10 + (i == #playersEcoInfo and 40 or 0)
		local ecoTextWidth = math.floor(font:GetTextWidth(playerEcoInfo.valueString) * panelFontSize)
		local ecoTextRightX = panelMarginX + 220
		font:Print(TruncateTextToPixelWidth(playerEcoInfo.name, (ecoTextRightX - ecoTextWidth) - namePosX), namePosX,
			PanelRow(row + i), panelFontSize, "")
		font:Print(playerEcoInfo.valueString, ecoTextRightX - ecoTextWidth, PanelRow(row + i), panelFontSize, "")
	end
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
	if currentTime > gameInfo.raptorGracePeriod then
		if gameInfo.raptorQueenAnger < 100 then

			local gain = 0
			if Spring.GetGameRulesParam("RaptorQueenAngerGain_Base") then
				-- font:Print(textColor .. Spring.I18N('ui.raptors.queenAngerBase', { value = math.round(Spring.GetGameRulesParam("RaptorQueenAngerGain_Base"), 3) }), panelMarginX, PanelRow(3), panelFontSize, "")
				-- font:Print(textColor .. Spring.I18N('ui.raptors.queenAngerAggression', { value = math.round(Spring.GetGameRulesParam("RaptorQueenAngerGain_Aggression"), 3) }), panelMarginX, PanelRow(4), panelFontSize, "")
				--font:Print(textColor .. Spring.I18N('ui.raptors.queenAngerEco', { value = math.round(Spring.GetGameRulesParam("RaptorQueenAngerGain_Eco"), 3) }), panelMarginX+5, PanelRow(5), panelFontSize, "")
				gain = math.round(Spring.GetGameRulesParam("RaptorQueenAngerGain_Base"), 3) +
						math.round(Spring.GetGameRulesParam("RaptorQueenAngerGain_Aggression"), 3) +
						math.round(Spring.GetGameRulesParam("RaptorQueenAngerGain_Eco"), 3)
			end
			--font:Print(textColor .. Spring.I18N('ui.raptors.queenAngerWithGain', { anger = gameInfo.raptorQueenAnger, gain = math.round(gain, 3) }), panelMarginX, PanelRow(1), panelFontSize, "")
			font:Print(textColor .. Spring.I18N('ui.raptors.queenAngerWithTech', { anger = gameInfo.raptorQueenAnger, techAnger = gameInfo.raptorTechAnger }), panelMarginX, PanelRow(1), panelFontSize, "")

			local totalSeconds = (100 - gameInfo.raptorQueenAnger) / gain
			font:Print(textColor .. Spring.I18N('ui.raptors.queenETA', { time = '' }), panelMarginX, PanelRow(2), panelFontSize, "")
			local time = string.formatTime(totalSeconds)
			font:Print(textColor .. time, panelMarginX + 220 - font:GetTextWidth(time) * panelFontSize, PanelRow(2), panelFontSize, "")

			DrawPlayerEcoInfos(3)

			if #currentlyResistantToNames > 0 then
				currentlyResistantToNames = {}
				currentlyResistantTo = {}
			end
		else
			font:Print(textColor .. Spring.I18N('ui.raptors.queenHealth', { health = gameInfo.raptorQueenHealth }), panelMarginX, PanelRow(1), panelFontSize, "")

			DrawPlayerEcoInfos(2)

			for i = 1, #currentlyResistantToNames do
				if i == 1 then
					font:Print(textColor .. Spring.I18N('ui.raptors.queenResistantToList'), panelMarginX, PanelRow(11), panelFontSize, "")
				end
				font:Print(textColor .. currentlyResistantToNames[i], panelMarginX + 20, PanelRow(11 + i), panelFontSize, "")
			end
		end
	else
		font:Print(textColor .. Spring.I18N('ui.raptors.gracePeriod', { time = '' }), panelMarginX, PanelRow(1), panelFontSize, "")
		local timeText = string.formatTime(math.ceil(((currentTime - gameInfo.raptorGracePeriod) * -1) - 0.5))
		font:Print(textColor .. timeText, panelMarginX + 220 - font:GetTextWidth(timeText) * panelFontSize, PanelRow(1), panelFontSize, "")
		DrawPlayerEcoInfos(2)
	end

	local endless = ""
	if Spring.GetModOptions().raptor_endless then
		endless = ' (' .. Spring.I18N('ui.raptors.difficulty.endless') .. ')'
	end
	local difficultyCaption = Spring.I18N('ui.raptors.difficulty.' .. difficultyOption)
	font:Print(textColor .. Spring.I18N('ui.raptors.mode', { mode = difficultyCaption }) .. endless, 80, h - 170, panelFontSize, "")
	font:End()

	gl.Texture(false)
	gl.PopMatrix()
end

local function getMarqueeMessage(raptorEventArgs)
	local messages = {}
	if raptorEventArgs.type == "firstWave" then
		messages[1] = textColor .. Spring.I18N('ui.raptors.firstWave1')
		messages[2] = textColor .. Spring.I18N('ui.raptors.firstWave2')
	elseif raptorEventArgs.type == "queen" then
		messages[1] = textColor .. Spring.I18N('ui.raptors.queenIsAngry1')
		messages[2] = textColor .. Spring.I18N('ui.raptors.queenIsAngry2')
	elseif raptorEventArgs.type == "airWave" then
		messages[1] = textColor .. Spring.I18N('ui.raptors.wave1', {waveNumber = raptorEventArgs.waveCount})
		messages[2] = textColor .. Spring.I18N('ui.raptors.airWave1')
		messages[3] = textColor .. Spring.I18N('ui.raptors.airWave2', {unitCount = raptorEventArgs.number})
	elseif raptorEventArgs.type == "wave" then
		messages[1] = textColor .. Spring.I18N('ui.raptors.wave1', {waveNumber = raptorEventArgs.waveCount})
		messages[2] = textColor .. Spring.I18N('ui.raptors.wave2', {unitCount = raptorEventArgs.number})
	end

	refreshMarqueeMessage = false

	return messages
end

local function getResistancesMessage()
	local messages = {}
	messages[1] = textColor .. Spring.I18N('ui.raptors.resistanceUnits')
	for i = 1,#resistancesTable do
		local attackerName = UnitDefs[resistancesTable[i]].name
		messages[i+1] = textColor .. Spring.I18N('units.names.' .. attackerName)
		currentlyResistantToNames[#currentlyResistantToNames+1] = Spring.I18N('units.names.' .. attackerName)
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
	gameInfo.raptorCounts = getRaptorCounts('Count')
	gameInfo.raptorKills = getRaptorCounts('Kills')

	updatePanel = true
end

function GetPlayersEcoInfo(maxRows)
	local myTeamId       = Spring.GetMyTeamID()
	local teamList       = Spring.GetTeamList()
	local playerEcoInfos = {}
	maxRows              = (maxRows or 3) - (myTeamId == nil and 0 or 1)
	local sum            = 0

	for i = 1, #teamList do
		local teamID = teamList[i]
		local playerName
		local playerList = Spring.GetPlayerList(teamID)
		if playerList[1] then
			playerName = Spring.GetPlayerInfo(playerList[1])
		else
			_, playerName = Spring.GetAIInfo(teamID)
		end

		local _, _, _, income = Spring.GetTeamResources(playerList[1] or teamID, 'energy')
		if income then
			sum = sum + income
			table.insert(playerEcoInfos, {
				value = income,
				name = playerName,
				teamID = teamID,
				me = myTeamId == teamID,
				forced = false
			})
		end
	end

	-- normalize and add text formatting
	local nplayerEcoInfos = #playerEcoInfos
	for i = 1, nplayerEcoInfos do
		local playerEcoInfo = playerEcoInfos[i]
		playerEcoInfo.value = nplayerEcoInfos * (playerEcoInfo.value or 0) * 100 / sum
		playerEcoInfo.valueString = string.format("%.0f%%", playerEcoInfo.value, 2)
	end

	table.sort(playerEcoInfos, function(a, b) return a.value > b.value end)

	-- limit rows and add player forced flag
	local playerEcoInfosLimited = {}
	for i = 1, #playerEcoInfos do
		local ecoInfo = playerEcoInfos[i]
		if ecoInfo.me or #playerEcoInfosLimited < maxRows then
			if ecoInfo.me then
				if #playerEcoInfosLimited >= maxRows then
					ecoInfo.forced = true
				end
				maxRows = maxRows + 1
			end
			table.insert(playerEcoInfosLimited, ecoInfo)
		end
	end

	return playerEcoInfosLimited
end

function RaptorEvent(raptorEventArgs)
	if raptorEventArgs.type == "firstWave" or raptorEventArgs.type == "queen" then
		showMarqueeMessage = true
		refreshMarqueeMessage = true
		messageArgs = raptorEventArgs
		waveTime = Spring.GetTimer()
	end

	if raptorEventArgs.type == "queenResistance" then
		if raptorEventArgs.number then
			if not currentlyResistantTo[raptorEventArgs.number] then
				table.insert(resistancesTable, raptorEventArgs.number)
				currentlyResistantTo[raptorEventArgs.number] = true
			end
		end
	end

	if (raptorEventArgs.type == "wave" or raptorEventArgs.type == "airWave") and config.useWaveMsg and gameInfo.raptorQueenAnger <= 99 then
		waveCount = waveCount + 1
		raptorEventArgs.waveCount = waveCount
		showMarqueeMessage = true
		refreshMarqueeMessage = true
		messageArgs = raptorEventArgs
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

	widgetHandler:RegisterGlobal("RaptorEvent", RaptorEvent)
	UpdateRules()
	viewSizeX, viewSizeY = gl.GetViewSizes()
	local x = math.abs(math.floor(viewSizeX - 320))
	local y = math.abs(math.floor(viewSizeY - 300))

	-- reposition if scavengers panel is shown as well
	if Spring.Utilities.Gametype.IsScavengers() then
		x = x - 315
	end

	updatePos(x, y)
end

function widget:Shutdown()
	if hasRaptorEvent then
		Spring.SendCommands({ "luarules HasRaptorEvent 0" })
	end

	if guiPanel then
		gl.DeleteList(guiPanel);
		guiPanel = nil
	end

	gl.DeleteList(displayList)
	gl.DeleteTexture(panelTexture)
	widgetHandler:DeregisterGlobal("RaptorEvent")
end

function widget:GameFrame(n)
	if not hasRaptorEvent and n > 1 then
		Spring.SendCommands({ "luarules HasRaptorEvent 1" })
		hasRaptorEvent = true
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
