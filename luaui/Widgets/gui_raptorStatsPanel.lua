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

local useWaveMsg        = VFS.Include('LuaRules/Configs/raptor_spawn_defs.lua').useWaveMsg

local DiffTimers        = Spring.DiffTimers
local GetAIInfo         = Spring.GetAIInfo
local GetGameRulesParam = Spring.GetGameRulesParam
local GetGameSeconds    = Spring.GetGameSeconds

local GetMyTeamID       = Spring.GetMyTeamID
local GetPlayerInfo     = Spring.GetPlayerInfo
local GetPlayerList     = Spring.GetPlayerList
local GetTeamList       = Spring.GetTeamList
local GetTimer          = Spring.GetTimer
local I18N              = Spring.I18N
local UnitDefs          = UnitDefs

-- to be deleted pending PR #2572
local WALLS             = {
	armdrag  = true,
	armfort  = true,
	cordrag  = true,
	corfort  = true,
	scavdrag = true,
	scavfort = true,
}
local raptorTeamID
local teams             = GetTeamList()
for _, teamID in ipairs(teams) do
	local teamLuaAI = Spring.GetTeamLuaAI(teamID)
	if (teamLuaAI and string.find(teamLuaAI, "Raptors")) then
		raptorTeamID = teamID
	end
end
if not raptorTeamID then
	raptorTeamID = Spring.GetGaiaTeamID()
end

local function IsValidEcoUnitDef(unitDef, teamID)
	-- skip Raptor AI, moving units and player built walls
	if teamID == raptorTeamID or unitDef.canMove or WALLS[unitDef.name] then
		return false
	end
	return true
end

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
local function EcoValueDef(unitDef)
	if not IsValidEcoUnitDef(unitDef) then
		return 0
	end

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

local RaptorCommon
if io.open('LuaRules/gadgets/raptors/common.lua', "r") == nil then
	RaptorCommon = {
		EcoValueDef       = EcoValueDef,
		IsValidEcoUnitDef = IsValidEcoUnitDef
	}
else
	RaptorCommon = VFS.Include('LuaRules/gadgets/raptors/common.lua')
end

local customScale           = 1
local widgetScale           = customScale
local font, font2
local messageArgs, marqueeMessage
local refreshMarqueeMessage = false
local showMarqueeMessage    = false

if not Spring.Utilities.Gametype.IsRaptors() then
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
local ecoAggrosByPlayerRaw      = {}
local ecoAggrosByPlayerRender   = {}
local stageGrace                = 0
local stageMain                 = 1
local stageQueen                = 2

local guiPanel --// a displayList
local updatePanel
local hasRaptorEvent            = false

local modOptions                = Spring.GetModOptions()

local rules                     = {
	"lagging",
	"raptorDifficulty",
	"raptorGracePeriod",
	"raptorQueenAnger",
	"RaptorQueenAngerGain_Aggression",
	"RaptorQueenAngerGain_Base",
	"RaptorQueenAngerGain_Eco",
	"raptorQueenHealth",
	"raptorQueenTime",
	"raptorTechAnger",
}

local function updatePos(x, y)
	local x0 = (viewSizeX * 0.94) - (w * widgetScale) / 2
	local y0 = (viewSizeY * 0.89) - (h * widgetScale) / 2
	x1 = x0 < x and x0 or x
	y1 = y0 < y and y0 or y

	updatePanel = true
end
local function EcoAggroPlayerAggregation()
	local myTeamId      = GetMyTeamID()
	local teamList      = GetTeamList()
	local playerAggros  = {}
	local sum           = 0
	local nPlayerAggros = 0

	for i = 1, #teamList do
		local teamID = teamList[i]
		local playerName
		local playerList = GetPlayerList(teamID)
		if playerList[1] then
			playerName = GetPlayerInfo(playerList[1])
		else
			_, playerName = GetAIInfo(teamID)
		end

		local aggroEcoValue = ecoAggrosByPlayerRaw[teamID] or 0
		if playerName and not playerName:find("Raptors") then
			sum = sum + aggroEcoValue
			nPlayerAggros = nPlayerAggros + 1
			playerAggros[nPlayerAggros] = {
				value = aggroEcoValue,
				name = playerName,
				teamID = teamID,
				me = myTeamId == teamID,
				forced = false,
			}
		end
	end
	return playerAggros, sum
end

local function RaptorStage(currentTime)
	local stage = stageGrace
	if (currentTime and currentTime or GetGameSeconds()) > gameInfo.raptorGracePeriod then
		if gameInfo.raptorQueenAnger < 100 then
			stage = stageMain
		else
			stage = stageQueen
		end
	end
	return stage
end

local function SortValueDesc(a, b)
	return a.value > b.value
end

local function Interpolate(value, inMin, inMax, outMin, outMax)
	-- Ensure the value is within the specified range
	value = (value < inMin) and inMin or ((value > inMax) and inMax or value)

	-- Calculate the interpolation
	local t = (value - inMin) / (inMax - inMin)
	local result = outMin + t * (outMax - outMin)

	return result
end

local function EcoAggrosByPlayerRender()
	local maxRows           = RaptorStage() == stageMain and 3 or 4
	local playerAggros, sum = EcoAggroPlayerAggregation()

	if sum == 0 then
		return {}
	end

	table.sort(playerAggros, SortValueDesc)

	-- add string formatting, forced current player result and limit results
	local playerAggrosLimited  = {}
	local nPlayerAggrosLimited = 0
	local nPlayerAggros        = #playerAggros
	local playerAggro
	for i = 1, nPlayerAggros do
		playerAggro = playerAggros[i]

		-- Always include current player
		if playerAggro.me or nPlayerAggrosLimited < maxRows then
			if playerAggro.me then
				maxRows = maxRows + 1
			end
			-- Current player added as last, so forced
			if playerAggro.me and i > nPlayerAggrosLimited + 1 then
				playerAggro.forced = true
			end
			playerAggro.aggroMultiple       = nPlayerAggros * playerAggro.value / sum
			playerAggro.aggroFraction       = playerAggro.value * 100 / sum
			playerAggro.aggroMultipleString = string.format("%.1fX", playerAggro.aggroMultiple)
			playerAggro.aggroFractionString = string.format(" (%.0f%%)", playerAggro.aggroFraction)
			local greenBlue                 = 1
			local alpha                     = 1
			if playerAggro.aggroMultiple > 1.7 then
				greenBlue = Interpolate(playerAggro.aggroMultiple, 1.7, 6, 0.5, 0.3)
			elseif playerAggro.aggroMultiple > 1.2 then
				greenBlue = Interpolate(playerAggro.aggroMultiple, 1.2, 1.7, 0.8, 0.5)
			elseif playerAggro.aggroMultiple < 0.8 then
				alpha = Interpolate(playerAggro.aggroMultiple, 0, 0.7, 1, 0.8)
			end
			playerAggro.color                         = { red = 1, green = greenBlue, blue = greenBlue, alpha = playerAggro.forced and 0.6 or alpha }
			nPlayerAggrosLimited                      = nPlayerAggrosLimited + 1
			playerAggrosLimited[nPlayerAggrosLimited] = playerAggro
		end
	end

	return playerAggrosLimited
end

local function PanelRow(n)
	return h - panelMarginY - (n - 1) * (panelFontSize + panelSpacingY)
end

local function WaveRow(n)
	return n * (waveFontSize + waveSpacingY)
end

local function CutStringAtPixelWidth(text, width)
	while font:GetTextWidth(text) * panelFontSize > width and text:len() >= 0 do
		text = text:sub(1, -2)
	end
	return text
end

local function DrawPlayerAggros(stage)
	local row = stageMain == stage and 3 or 2
	font:Print(I18N("ui.raptors.playerAggroLabel"):gsub("ui.raptors.playerAggroLabel", 'Player Aggros:'), panelMarginX, PanelRow(row), panelFontSize, "")
	for i = 1, #ecoAggrosByPlayerRender do
		local ecoAggro = ecoAggrosByPlayerRender[i]
		font:SetTextColor(ecoAggro.color.red, ecoAggro.color.green, ecoAggro.color.blue, ecoAggro.color.alpha)

		local namePosX = i == 7 - row and 80 or panelMarginX + 11
		local aggroFractionStringWidth = math.floor(0.5 + font:GetTextWidth(ecoAggro.aggroFractionString) * panelFontSize)
		local valuesRightX = panelMarginX + 220
		local valuesLeftX = panelMarginX + 145
		local rowY = PanelRow(row + i)
		font:Print(CutStringAtPixelWidth(ecoAggro.name, valuesLeftX - namePosX - 2), namePosX, rowY, panelFontSize, "")
		font:Print(ecoAggro.aggroMultipleString, valuesLeftX, rowY, panelFontSize, "")
		font:Print(ecoAggro.aggroFractionString, valuesRightX - aggroFractionStringWidth, rowY, panelFontSize, "")
	end
	font:SetTextColor(1, 1, 1, 1)
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
	local stage = RaptorStage(currentTime)

	if stageGrace == stage then
		font:Print(I18N('ui.raptors.gracePeriod', { time = '' }), panelMarginX, PanelRow(1), panelFontSize, "")
		local timeText = string.formatTime(((currentTime - gameInfo.raptorGracePeriod) * -1) - 0.5)
		font:Print(timeText, panelMarginX + 220 - font:GetTextWidth(timeText) * panelFontSize, PanelRow(1), panelFontSize, "")
		DrawPlayerAggros(stage)
	elseif stageMain == stage then
		local hatchEvolutionString = I18N('ui.raptors.queenAngerWithTech', { anger = gameInfo.raptorQueenAnger, techAnger = gameInfo.raptorTechAnger })
		font:Print(hatchEvolutionString, panelMarginX, PanelRow(1), panelFontSize - Interpolate(font:GetTextWidth(hatchEvolutionString) * panelFontSize, 234, 244, 0, 0.59), "")

		font:Print(I18N('ui.raptors.queenETA', { time = '' }):gsub('%.', ''), panelMarginX, PanelRow(2), panelFontSize, "")
		local gain = gameInfo.RaptorQueenAngerGain_Base + gameInfo.RaptorQueenAngerGain_Aggression + gameInfo.RaptorQueenAngerGain_Eco
		local time = string.formatTime((100 - gameInfo.raptorQueenAnger) / gain)
		font:Print(time, panelMarginX + 200 - font:GetTextWidth(time:gsub(':.*', '')) * panelFontSize, PanelRow(2), panelFontSize, "")

		DrawPlayerAggros(stage)

		if #currentlyResistantToNames > 0 then
			currentlyResistantToNames = {}
			currentlyResistantTo = {}
		end
	elseif stageQueen == stage then
		font:Print(I18N('ui.raptors.queenHealth', { health = '' }):gsub('%%', ''), panelMarginX, PanelRow(1), panelFontSize, "")
		local healthText = tostring(gameInfo.raptorQueenHealth)
		font:Print(gameInfo.raptorQueenHealth .. '%', panelMarginX + 210 - font:GetTextWidth(healthText) * panelFontSize, PanelRow(1), panelFontSize, "")

		DrawPlayerAggros(stage)

		for i = 1, #currentlyResistantToNames do
			if i == 1 then
				font:Print(I18N('ui.raptors.queenResistantToList'), panelMarginX, PanelRow(11), panelFontSize, "")
			end
			font:Print(currentlyResistantToNames[i], panelMarginX + 20, PanelRow(11 + i), panelFontSize, "")
		end
	end

	local endless = ""
	if modOptions.raptor_endless then
		endless = ' (' .. I18N('ui.raptors.difficulty.endless') .. ')'
	end
	local difficultyCaption = I18N('ui.raptors.difficulty.' .. modOptions.raptor_difficulty)
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

	for i = 1, #rules do
		local rule = rules[i]
		gameInfo[rule] = GetGameRulesParam(rule) or 0
	end

	updatePanel = true
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
				resistancesTable[#resistancesTable + 1] = raptorEventArgs.number
				currentlyResistantTo[raptorEventArgs.number] = true
			end
		end
	end

	if (raptorEventArgs.type == "wave" or raptorEventArgs.type == "airWave") and useWaveMsg and gameInfo.raptorQueenAnger <= 99 then
		waveCount = waveCount + 1
		raptorEventArgs.waveCount = waveCount
		showMarqueeMessage = true
		refreshMarqueeMessage = true
		messageArgs = raptorEventArgs
		waveTime = GetTimer()
	end
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
	if n % 10 == 0 then
		ecoAggrosByPlayerRender = EcoAggrosByPlayerRender()
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

local function RegisterUnit(unitID, unitDefID, unitTeam)
	ecoAggrosByPlayerRaw[unitTeam] = (ecoAggrosByPlayerRaw[unitTeam] or 0) + RaptorCommon.EcoValueDef(UnitDefs[unitDefID])
end

local function DeregisterUnit(unitID, unitDefID, unitTeam)
	local newRaw = (ecoAggrosByPlayerRaw[unitTeam] or 0) - RaptorCommon.EcoValueDef(UnitDefs[unitDefID])
	ecoAggrosByPlayerRaw[unitTeam] = newRaw < 0 and 0 or newRaw
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

	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		local unitDefID = Spring.GetUnitDefID(unitID)
		RegisterUnit(unitID, unitDefID, Spring.GetUnitTeam(unitID))
	end
end
