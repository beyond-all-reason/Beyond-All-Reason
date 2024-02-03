function widget:GetInfo()
	return {
		name = "Raptor Stats Panel",
		desc = "Shows statistics and progress when fighting vs Raptors",
		author = "quantum",
		date = "May 04, 2008",
		license = "GNU GPL, v2 or later",
		layer = -9,
		enabled = true --  loaded by default?
	}
end

local config                = VFS.Include('LuaRules/Configs/raptor_spawn_defs.lua')
local Set                   = VFS.Include('common/SetList.lua').NewSetListMin

local GetTeamColor          = Spring.GetTeamColor
local DiffTimers            = Spring.DiffTimers
local GetAIInfo             = Spring.GetAIInfo
local GetAllUnits           = Spring.GetAllUnits
local GetGaiaTeamID         = Spring.GetGaiaTeamID
local GetGameRulesParam     = Spring.GetGameRulesParam
local GetGameSeconds        = Spring.GetGameSeconds
local GetModOptions         = Spring.GetModOptions
local GetMyTeamID           = Spring.GetMyTeamID
local GetPlayerInfo         = Spring.GetPlayerInfo
local GetPlayerList         = Spring.GetPlayerList
local GetTeamList           = Spring.GetTeamList
local GetTeamLuaAI          = Spring.GetTeamLuaAI
local GetTimer              = Spring.GetTimer
local GetUnitDefID          = Spring.GetUnitDefID
local GetUnitTeam           = Spring.GetUnitTeam
local GetViewGeometry       = Spring.GetViewGeometry
local I18N                  = Spring.I18N
local SendCommands          = Spring.SendCommands
local UnitDefs              = UnitDefs
local Utilities             = Spring.Utilities

local customScale           = 1
local widgetScale           = customScale
local font, font2
local messageArgs, marqueeMessage
local refreshMarqueeMessage = false
local showMarqueeMessage    = false

if not Utilities.Gametype.IsRaptors() then
	return false
end

if not GetGameRulesParam("raptorDifficulty") then
	return false
end

local displayList
local panelTexture              = ":n:LuaUI/Images/raptorpanel.tga"

local panelFontSize             = 14
local waveFontSize              = 36

local vsx, vsy                  = Spring.GetViewGeometry()
local fontfile2                 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")

local viewSizeX, viewSizeY      = 0, 0
local w                         = 300
local h                         = 210
local x1                        = 0
local y1                        = 0
local panelMarginX              = 30
local panelMarginY              = 40
local panelSpacingY             = 5
local waveSpacingY              = 7
local moving
local capture
local gameInfo
local waveSpeed                 = 0.1
local waveCount                 = 0
local waveTime
local enabled
local gotScore
local scoreCount                = 0
local resistancesTable          = {}
local currentlyResistantTo      = {}
local currentlyResistantToNames = {}

local playersAggroEcos          = {}

local guiPanel --// a displayList
local updatePanel
local hasRaptorEvent            = false

local difficultyOption          = GetModOptions().raptor_difficulty

local rules                     = {
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

local raptorTypes               = {
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

local WALLS                     = Set()
WALLS:Add("armdrag")
WALLS:Add("armfort")
WALLS:Add("cordrag")
WALLS:Add("corfort")
WALLS:Add("scavdrag")
WALLS:Add("scavfort")

local raptorTeamID

local teams = GetTeamList()
for _, teamID in ipairs(teams) do
	local teamLuaAI = GetTeamLuaAI(teamID)
	if (teamLuaAI and string.find(teamLuaAI, "Raptors")) then
		raptorTeamID = teamID
	end
end

local gaiaTeamID = GetGaiaTeamID()
if not raptorTeamID then
	raptorTeamID = gaiaTeamID
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

function CutStringAtPixelWidth(text, width)
	while font:GetTextWidth(text) * panelFontSize > width and text:len() >= 0 do
		text = text:sub(1, -2)
	end
	return text
end

function DrawPlayerEcoInfos(row)
	font:Print('Player Aggros:', panelMarginX, PanelRow(row), panelFontSize, "")
	local playersEcoInfo = GetPlayersEcoInfo(7 - row)

	for i = 1, #playersEcoInfo do
		local playerEcoInfo = playersEcoInfo[i]
		if playerEcoInfo.name then
			local gb = 1
			local alpha = 1
			if playerEcoInfo.valueRatio > 1.7 then
				gb = Interpolate(playerEcoInfo.valueRatio, 1.7, 6, 0.5, 0.3)
			elseif playerEcoInfo.valueRatio > 1.2 then
				gb = Interpolate(playerEcoInfo.valueRatio, 1.2, 1.7, 0.8, 0.5)
			elseif playerEcoInfo.valueRatio < 0.8 then
				alpha = Interpolate(playerEcoInfo.valueRatio, 0, 0.7, 1, 0.8)
			end
			font:SetTextColor(1, gb, gb, playerEcoInfo.forced and 0.6 or alpha)

			-- Spring.Echo(playerEcoInfo.name .. ' forced ' .. tostring(playerEcoInfo.forced))

			local namePosX = i == #playersEcoInfo and 80 or panelMarginX + 11
			local normalizedStringWidth = math.floor(font:GetTextWidth(playerEcoInfo.valueNormalizedString) * panelFontSize)
			local valuesRightX = panelMarginX + 220
			local valuesLeftX = panelMarginX + 145
			local rowY = PanelRow(row + i)
			font:SetTextColor(1, gb, gb, playerEcoInfo.forced and 0.6 or alpha)
			font:Print(CutStringAtPixelWidth(playerEcoInfo.name, valuesLeftX - namePosX - 2), namePosX, rowY, panelFontSize, "")
			font:Print(playerEcoInfo.valueRatioString, valuesLeftX, rowY, panelFontSize, "")
			font:Print(playerEcoInfo.valueNormalizedString, valuesRightX - normalizedStringWidth, rowY, panelFontSize, "")
		end
	end
	font:SetTextColor(1, 1, 1, 1)
	font:SetOutlineColor(0, 0, 0, 1)
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
			if GetGameRulesParam("RaptorQueenAngerGain_Base") then
				-- font:Print(I18N('ui.raptors.queenAngerBase', { value = math.round(GetGameRulesParam("RaptorQueenAngerGain_Base"), 3) }), panelMarginX, PanelRow(3), panelFontSize, "")
				-- font:Print(I18N('ui.raptors.queenAngerAggression', { value = math.round(GetGameRulesParam("RaptorQueenAngerGain_Aggression"), 3) }), panelMarginX, PanelRow(4), panelFontSize, "")
				--font:Print(I18N('ui.raptors.queenAngerEco', { value = math.round(GetGameRulesParam("RaptorQueenAngerGain_Eco"), 3) }), panelMarginX+5, PanelRow(5), panelFontSize, "")
				gain = math.round(GetGameRulesParam("RaptorQueenAngerGain_Base"), 3) +
					math.round(GetGameRulesParam("RaptorQueenAngerGain_Aggression"), 3) +
					math.round(GetGameRulesParam("RaptorQueenAngerGain_Eco"), 3)
			end
			--font:Print(I18N('ui.raptors.queenAngerWithGain', { anger = gameInfo.raptorQueenAnger, gain = math.round(gain, 3) }), panelMarginX, PanelRow(1), panelFontSize, "")
			font:Print(I18N('ui.raptors.queenAngerWithTech', { anger = gameInfo.raptorQueenAnger, techAnger = gameInfo.raptorTechAnger }):gsub('ution', 'ved'), panelMarginX, PanelRow(1), panelFontSize, "")

			local totalSeconds = (100 - gameInfo.raptorQueenAnger) / gain
			font:Print(I18N('ui.raptors.queenETA', { time = '' }):gsub('%.', ''), panelMarginX, PanelRow(2), panelFontSize, "")
			local time = string.formatTime(totalSeconds)
			font:Print(time, panelMarginX + 200 - font:GetTextWidth(time:gsub(':.*', '')) * panelFontSize, PanelRow(2), panelFontSize, "")

			DrawPlayerEcoInfos(3)

			if #currentlyResistantToNames > 0 then
				currentlyResistantToNames = {}
				currentlyResistantTo = {}
			end
		else
			font:Print(I18N('ui.raptors.queenHealth', { health = '' }):gsub('%%', ''), panelMarginX, PanelRow(1), panelFontSize, "")
			local healthText = tostring(gameInfo.raptorQueenHealth)
			font:Print(gameInfo.raptorQueenHealth .. '%', panelMarginX + 220 - font:GetTextWidth(healthText) * panelFontSize, PanelRow(1), panelFontSize, "")

			DrawPlayerEcoInfos(2)

			for i = 1, #currentlyResistantToNames do
				if i == 1 then
					font:Print(I18N('ui.raptors.queenResistantToList'), panelMarginX, PanelRow(11), panelFontSize, "")
				end
				font:Print(currentlyResistantToNames[i], panelMarginX + 20, PanelRow(11 + i), panelFontSize, "")
			end
		end
	else
		font:Print(I18N('ui.raptors.gracePeriod', { time = '' }), panelMarginX, PanelRow(1), panelFontSize, "")
		local timeText = string.formatTime(((currentTime - gameInfo.raptorGracePeriod) * -1) - 0.5)
		font:Print(timeText, panelMarginX + 220 - font:GetTextWidth(timeText) * panelFontSize, PanelRow(1), panelFontSize, "")
		DrawPlayerEcoInfos(2)
	end

	local endless = ""
	if GetModOptions().raptor_endless then
		endless = ' (' .. I18N('ui.raptors.difficulty.endless') .. ')'
	end
	local difficultyCaption = I18N('ui.raptors.difficulty.' .. difficultyOption)
	font:Print(I18N('ui.raptors.mode', { mode = difficultyCaption }) .. endless, 80, h - 170, panelFontSize, "")
	font:End()

	gl.Texture(false)
	gl.PopMatrix()
end

local function getMarqueeMessage(raptorEventArgs)
	local messages = {}
	if raptorEventArgs.type == "firstWave" then
		messages[1] = I18N('ui.raptors.firstWave1')
		messages[2] = I18N('ui.raptors.firstWave2')
	elseif raptorEventArgs.type == "queen" then
		messages[1] = I18N('ui.raptors.queenIsAngry1')
		messages[2] = I18N('ui.raptors.queenIsAngry2')
	elseif raptorEventArgs.type == "airWave" then
		messages[1] = I18N('ui.raptors.wave1', { waveNumber = raptorEventArgs.waveCount })
		messages[2] = I18N('ui.raptors.airWave1')
		messages[3] = I18N('ui.raptors.airWave2', { unitCount = raptorEventArgs.number })
	elseif raptorEventArgs.type == "wave" then
		messages[1] = I18N('ui.raptors.wave1', { waveNumber = raptorEventArgs.waveCount })
		messages[2] = I18N('ui.raptors.wave2', { unitCount = raptorEventArgs.number })
	end

	refreshMarqueeMessage = false

	return messages
end

local function getResistancesMessage()
	local messages = {}
	messages[1] = I18N('ui.raptors.resistanceUnits')
	for i = 1, #resistancesTable do
		local attackerName = UnitDefs[resistancesTable[i]].name
		messages[i + 1] = I18N('units.names.' .. attackerName)
		currentlyResistantToNames[#currentlyResistantToNames + 1] = I18N('units.names.' .. attackerName)
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
		local t = GetTimer()

		local waveY = viewSizeY - DiffTimers(t, waveTime) * waveSpeed * viewSizeY
		if waveY > 0 then
			if refreshMarqueeMessage or not marqueeMessage then
				marqueeMessage = getMarqueeMessage(messageArgs)
			end

			font2:Begin()
			font:SetTextColor(1, 1, 1, 1)
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
		waveTime = GetTimer()
		showMarqueeMessage = true
	end
end

local function UpdateRules()
	if not gameInfo then
		gameInfo = {}
	end

	for _, rule in ipairs(rules) do
		gameInfo[rule] = GetGameRulesParam(rule) or 0
	end
	gameInfo.raptorCounts = getRaptorCounts('Count')
	gameInfo.raptorKills = getRaptorCounts('Kills')

	updatePanel = true
end

function PlayerAggroEcoDistribution()
	local myTeamId       = GetMyTeamID()
	local teamList       = GetTeamList()
	local playerEcoInfos = {}
	local sum            = 0

	for i = 1, #teamList do
		local teamID = teamList[i]
		local playerName
		local playerList = GetPlayerList(teamID)
		if playerList[1] then
			playerName = GetPlayerInfo(playerList[1])
		else
			_, playerName = GetAIInfo(teamID)
		end

		local aggroEcoValue = playersAggroEcos[teamID]
		if playerName and not playerName:find("Raptors") and aggroEcoValue and aggroEcoValue > 0 then
			sum = sum + aggroEcoValue
			table.insert(playerEcoInfos, {
				value = aggroEcoValue,
				name = playerName,
				teamID = teamID,
				me = myTeamId == teamID,
				forced = false,
				color = { GetTeamColor(teamID) }
			})
		end
	end
	return playerEcoInfos, sum
end

function GetPlayersEcoInfo(maxRows)
	maxRows                   = (maxRows or 3) - 1
	local playerEcoInfos, sum = PlayerAggroEcoDistribution()

	if sum == 0 then
		return {}
	end

	-- normalize and add text formatting
	local nPlayerEcoInfos = #playerEcoInfos
	for i = 1, nPlayerEcoInfos do
		local playerEcoInfo                 = playerEcoInfos[i]
		playerEcoInfo.valueRatio            = nPlayerEcoInfos * playerEcoInfo.value / sum
		playerEcoInfo.valueNormalized       = playerEcoInfo.value * 100 / sum
		playerEcoInfo.valueRatioString      = string.format("%.1fX", playerEcoInfo.valueRatio)
		playerEcoInfo.valueNormalizedString = string.format(" (%.0f%%)", playerEcoInfo.valueNormalized)
	end

	table.sort(playerEcoInfos, function(a, b) return a.value > b.value end)

	-- limit rows and add player forced flag
	local playerEcoInfosLimited = {}
	local playerEcoInfo
	for i = 1, #playerEcoInfos do
		playerEcoInfo = playerEcoInfos[i]
		if playerEcoInfo.me or #playerEcoInfosLimited < maxRows then
			if playerEcoInfo.me then
				maxRows = maxRows + 1
			end
			if playerEcoInfo.me and i > #playerEcoInfosLimited + 1 then
				playerEcoInfo.forced = true
			end
			table.insert(playerEcoInfosLimited, playerEcoInfo)
		end
	end

	return playerEcoInfosLimited
end

function RaptorEvent(raptorEventArgs)
	if raptorEventArgs.type == "firstWave" or raptorEventArgs.type == "queen" then
		showMarqueeMessage = true
		refreshMarqueeMessage = true
		messageArgs = raptorEventArgs
		waveTime = GetTimer()
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
		waveTime = GetTimer()
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
	if Utilities.Gametype.IsScavengers() then
		x = x - 315
	end

	updatePos(x, y)

	local allUnits = GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		local unitDefID = GetUnitDefID(unitID)
		RegisterUnit(unitID, unitDefID, GetUnitTeam(unitID))
	end
end

function widget:Shutdown()
	if hasRaptorEvent then
		SendCommands({ "luarules HasRaptorEvent 0" })
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
		SendCommands({ "luarules HasRaptorEvent 1" })
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
	vsx, vsy = GetViewGeometry()

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

function EcoValueByDef(unitDef)
	-- Calculate an eco value based on energy and metal production
	-- Echo("Built units eco value: " .. ecoValue)

	-- Ends up building an object like:
	-- {
	--  0: [non-eco]
	--	25: [t1 windmill, t1 solar, t1 mex],
	--	75: [adv solar]
	--	1000: [fusion]
	--	3000: [adv fusion]
	-- }

	local ecoValue = 1
	if unitDef.energyMake then
		ecoValue = ecoValue + unitDef.energyMake
	end
	if unitDef.energyUpkeep and unitDef.energyUpkeep < 0 then
		ecoValue = ecoValue - unitDef.energyUpkeep
	end
	if unitDef.windGenerator then
		ecoValue = ecoValue + unitDef.windGenerator * 0.75
	end
	if unitDef.tidalGenerator then
		ecoValue = ecoValue + unitDef.tidalGenerator * 15
	end
	if unitDef.extractsMetal and unitDef.extractsMetal > 0 then
		ecoValue = ecoValue + 200
	end
	if unitDef.customParams and unitDef.customParams.energyconv_capacity then
		ecoValue = ecoValue + tonumber(unitDef.customParams.energyconv_capacity) / 2
	end

	-- Decoy fusion support
	if unitDef.customParams and unitDef.customParams.decoyfor == "armfus" then
		ecoValue = ecoValue + 1000
	end

	-- Make it extra risky to build T2 eco
	if unitDef.customParams and unitDef.customParams.techlevel and tonumber(unitDef.customParams.techlevel) > 1 then
		ecoValue = ecoValue * tonumber(unitDef.customParams.techlevel) * 2
	end

	-- Anti-nuke - add value to force players to go T2 economy, rather than staying T1
	if unitDef.customParams and (unitDef.customParams.unitgroup == "antinuke" or unitDef.customParams.unitgroup == "nuke") then
		ecoValue = 1000
	end

	return ecoValue
end

function ValidEcoUnitDef(unitDef, teamID)
	-- skip Raptor AI, moving units and player built walls
	if teamID == raptorTeamID or not unitDef.canMove or WALLS.hash[unitDef.name] ~= nil then
		return false
	end
	return true
end

function RegisterUnit(unitID, unitDefID, unitTeam)
	local unitDef = UnitDefs[unitDefID]

	if ValidEcoUnitDef(unitDef, unitTeam) then
		playersAggroEcos[unitTeam] = (playersAggroEcos[unitTeam] or 0) + EcoValueByDef(unitDef)
	end
end

function DeregisterUnit(unitID, unitDefID, unitTeam)
	local unitDef = UnitDefs[unitDefID]

	if ValidEcoUnitDef(unitDef, unitTeam) then
		playersAggroEcos[unitTeam] = (playersAggroEcos[unitTeam] or 0) - EcoValueByDef(unitDef)
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	RegisterUnit(unitID, unitDefID, unitTeam)
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	RegisterUnit(unitID, unitDefID, unitTeam)
	DeregisterUnit(unitID, unitDefID, oldTeam)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	DeregisterUnit(unitID, unitDefID, unitTeam)
end
