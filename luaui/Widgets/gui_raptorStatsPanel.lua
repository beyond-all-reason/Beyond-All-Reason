if not (Spring.Utilities.Gametype.IsRaptors() and not Spring.Utilities.Gametype.IsScavengers()) then
	return false
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Raptor Stats Panel",
		desc = "Shows statistics and progress when fighting vs Raptors",
		author = "quantum",
		date = "May 04, 2008",
		license = "GNU GPL, v2 or later",
		layer = -9,
		enabled = true
	}
end

local config = VFS.Include('LuaRules/Configs/raptor_spawn_defs.lua')
VFS.Include('luaui/Headers/keysym.h.lua')

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
local bossInfoMarginX = panelMarginX - 15
local bossInfoSubLabelMarginX = bossInfoMarginX + 35
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
local hasRaptorEvent = false

local difficultyOption = Spring.GetModOptions().raptor_difficulty
local nBosses = Spring.GetModOptions().raptor_queen_count

local rules = {
	"raptorQueenTime",
	"raptorQueenAnger",
	"raptorQueensKilled",
	"raptorTechAnger",
	"raptorGracePeriod",
	"raptorQueenHealth",
	"raptorDifficulty",
	"raptorKills",
}


local textColor = "\255\255\255\255"

local modOptions = Spring.GetModOptions()
local isRaptors = Spring.Utilities.Gametype.IsRaptors()
local bossDefName = isRaptors and ('raptor_queen_' .. modOptions.raptor_difficulty ) or ('scavengerbossv4_'.. modOptions.scav_difficulty ..'_scav')
local totalBossHealth = UnitDefNames[bossDefName] and UnitDefs[UnitDefNames[bossDefName].id] and UnitDefs[UnitDefNames[bossDefName].id].health or (1250000 * 1.5)
local isBossInfoExpanded = false
local isAboveBossInfo = false
local stageGrace = 0
local stageMain = 1
local stageBoss = 2
local nPanelRows
local bossInfo

local cachedPlayerNames
if not cachedPlayerNames then
	cachedPlayerNames = {}
end

local function PveStage(currentTime)
	local stage = stageGrace
	if (currentTime and currentTime or Spring.GetGameSeconds()) > gameInfo.raptorGracePeriod then
		if (isRaptors and (gameInfo.raptorQueenAnger < 100)) or (not isRaptors and (gameInfo.scavBossAnger < 100)) then
			stage = stageMain
		else
			stage = stageBoss
		end
	end
	return stage
end

local function printBossInfo(text, x, y)
	font:Print(text or '', x, y, panelFontSize, "o")
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
	if currentTime > gameInfo.raptorGracePeriod then
		if gameInfo.raptorQueenAnger < 100 then

			local gain = 0
			if Spring.GetGameRulesParam("RaptorQueenAngerGain_Base") then
				font:Print(textColor .. Spring.I18N('ui.raptors.queenAngerBase', { value = math.round(Spring.GetGameRulesParam("RaptorQueenAngerGain_Base"), 3) }), panelMarginX+5, PanelRow(3), panelFontSize, "")
				font:Print(textColor .. Spring.I18N('ui.raptors.queenAngerAggression', { value = math.round(Spring.GetGameRulesParam("RaptorQueenAngerGain_Aggression"), 3) }), panelMarginX+5, PanelRow(4), panelFontSize, "")
				--font:Print(textColor .. Spring.I18N('ui.raptors.queenAngerEco', { value = math.round(Spring.GetGameRulesParam("RaptorQueenAngerGain_Eco"), 3) }), panelMarginX+5, PanelRow(5), panelFontSize, "")
				gain = math.round(Spring.GetGameRulesParam("RaptorQueenAngerGain_Base"), 3) + math.round(Spring.GetGameRulesParam("RaptorQueenAngerGain_Aggression"), 3) + math.round(Spring.GetGameRulesParam("RaptorQueenAngerGain_Eco"), 3)
			end
			--font:Print(textColor .. Spring.I18N('ui.raptors.queenAngerWithGain', { anger = gameInfo.raptorQueenAnger, gain = math.round(gain, 3) }), panelMarginX, PanelRow(1), panelFontSize, "")
			font:Print(textColor .. Spring.I18N('ui.raptors.queenAngerWithTech', { anger = math.floor(0.5+gameInfo.raptorQueenAnger), techAnger = gameInfo.raptorTechAnger}), panelMarginX, PanelRow(1), panelFontSize, "")

			local totalSeconds = (100 - gameInfo.raptorQueenAnger) / gain
			time = string.formatTime(totalSeconds)
			if totalSeconds < 1800 or revealedQueenEta then
				if not revealedQueenEta then revealedQueenEta = true end
				font:Print(textColor .. Spring.I18N('ui.raptors.queenETA', { count = nBosses, time = time }), panelMarginX+5, PanelRow(2), panelFontSize, "")
			end
			if #currentlyResistantToNames > 0 then
				currentlyResistantToNames = {}
				currentlyResistantTo = {}
			end
		else
			font:Print(textColor .. Spring.I18N('ui.raptors.queenHealth', {count = nBosses, health = gameInfo.raptorQueenHealth }), panelMarginX, PanelRow(1), panelFontSize, "")
			if nBosses > 1 then
				font:Print(textColor .. Spring.I18N('ui.raptors.queensKilled', { nKilled = gameInfo.raptorQueensKilled, nTotal = nBosses }), panelMarginX, PanelRow(2), panelFontSize, "")
			end

			if bossInfo then
				printBossInfo((isRaptors and 'Queen' or 'Boss') .. ' resistances: (Ctrl+B Expands)', bossInfoMarginX, PanelRow(11))
				local row = 11
				for i, resistance in ipairs(bossInfo.resistances) do
					row = row + 1
					printBossInfo(resistance.name, bossInfoMarginX + 10, PanelRow(row))
					local resistanceString = isAboveBossInfo and resistance.stringAbsolute or resistance.stringPercent
					printBossInfo(resistanceString,bossInfoSubLabelMarginX + bossInfo.labelMaxLength + 40 - font:GetTextWidth(resistanceString) * panelFontSize,PanelRow(row))
					if not isBossInfoExpanded and i > 3 then
						break
					end
				end

				row = row + 1

				printBossInfo('Player '.. (isRaptors and 'Queen' or 'Boss') .. ' Damage: ('.. (isAboveBossInfo and 'absolute' or 'relative') .. ')', bossInfoMarginX, PanelRow(row))
				for i, damage in ipairs(bossInfo.playerDamages) do
					row = row + 1
					printBossInfo(damage.name, bossInfoMarginX + 10, PanelRow(row))
					local damageString = isAboveBossInfo and damage.stringAbsolute or damage.stringRelative
					printBossInfo(damageString,bossInfoSubLabelMarginX + bossInfo.labelMaxLength + 40 - font:GetTextWidth(damageString) * panelFontSize,PanelRow(row))
					if not isBossInfoExpanded and i > 5 then
						break
					end
				end
			end
		end
	else
		font:Print(textColor .. Spring.I18N('ui.raptors.gracePeriod', { time = string.formatTime(math.ceil(((currentTime - gameInfo.raptorGracePeriod) * -1) - 0.5)) }), panelMarginX, PanelRow(1), panelFontSize, "")
	end

	font:Print(textColor .. Spring.I18N('ui.raptors.raptorKillCount', { count = gameInfo.raptorKills }), panelMarginX, PanelRow(6), panelFontSize, "")
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
		messages[1] = textColor .. Spring.I18N('ui.raptors.queenIsAngry1', {count = nBosses})
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
	messages[1] = textColor .. Spring.I18N('ui.raptors.resistanceUnits', {count = nBosses})
	for i = 1,#resistancesTable do
		local attackerName = UnitDefs[resistancesTable[i]].name
		if UnitDefNames[attackerName].customParams.i18nfromunit then
			attackerName = UnitDefNames[attackerName].customParams.i18nfromunit
		end
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

	updatePanel = true
end

function RaptorEvent(raptorEventArgs)
	if raptorEventArgs.type == "firstWave" or (raptorEventArgs.type == "queen" and Spring.DiffTimers(Spring.GetTimer(), bossToastTimer) > 10) then
		showMarqueeMessage = true
		refreshMarqueeMessage = true
		messageArgs = raptorEventArgs
		waveTime = Spring.GetTimer()
		if raptorEventArgs.type == "queen" then
			bossToastTimer = Spring.GetTimer()
		end
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

local function PlayerName(teamID)
	local playerName = ''

	local playerList = Spring.GetPlayerList(teamID)
	if (not playerList or #playerList == 0) and cachedPlayerNames[teamID] then
		playerName = cachedPlayerNames[teamID]
	elseif #playerList > 1 then
		for _, player in ipairs(playerList) do
			if player then
				playerName = playerName .. (#playerName > 0 and ' & ' or '') .. select(1, Spring.GetPlayerInfo(player))
			end
		end
	elseif #playerList == 1 then
		playerName = select(1,Spring.GetPlayerInfo(playerList[1]))
	else
		_, playerName = Spring.GetAIInfo(teamID)

	end

	if playerName and playerName ~= '' then
		cachedPlayerNames[teamID] = playerName
	end

	return playerName
end

local function sortRawDamageDescNameAsc(a, b)
	if not a or not b then
		return false
	end
	if a.raw == b.raw and a.damage and b.damage then
		if a.damage == b.damage then
			return a.name < b.name
		end
		return a.damage > b.damage
	end
	return a.raw > b.raw
end

local function UpdateBossInfo()
	local bossInfoRaw = Spring.GetGameRulesParam('pveBossInfo')
	if not bossInfoRaw then
		return
	end
	bossInfoRaw = Json.decode(Spring.GetGameRulesParam('pveBossInfo'))
	bossInfo = { resistances = {}, playerDamages = {}, healths = {}, labelMaxLength = 0 }

	local i = 0
	for defID, resistance in pairs(bossInfoRaw.resistances) do
		i = i + 1
		if resistance.percent >= 0.1 then
			local name = UnitDefs[tonumber(defID)].translatedHumanName
			if font:GetTextWidth(name) * panelFontSize > bossInfo.labelMaxLength then
				bossInfo.labelMaxLength = font:GetTextWidth(name) * panelFontSize
			end
			table.insert(
				bossInfo.resistances,
				{
					name = name,
					raw = resistance.percent,
					damage = resistance.damage,
					stringPercent = string.format('%.0f%%', resistance.percent * 100),
					stringAbsolute = string.formatSI(resistance.damage),
				}
			)
		end
	end
	table.sort(bossInfo.resistances, sortRawDamageDescNameAsc)

	for teamID, damage in pairs(bossInfoRaw.playerDamages) do
		local name = PlayerName(teamID)
		if font:GetTextWidth((name or '') .. 'XX') * panelFontSize > bossInfo.labelMaxLength then
			bossInfo.labelMaxLength = font:GetTextWidth((name or '') .. 'XX') * panelFontSize
		end
		damage = math.max(damage, 1)
		table.insert(
			bossInfo.playerDamages,
			{ name = name, raw = damage, stringAbsolute = string.formatSI(damage), stringRelative = string.format('%.1fX', damage / totalBossHealth) }
		)
	end
	table.sort(bossInfo.playerDamages, sortRawDamageDescNameAsc)

	local screenOverflowX = x1 + bossInfo.labelMaxLength + bossInfoSubLabelMarginX + 36 - vsx
	x1 = screenOverflowX > 0 and x1 - screenOverflowX or x1
end

function widget:GameFrame(n)
	if not hasRaptorEvent and n > 1 then
		Spring.SendCommands({ "luarules HasRaptorEvent 1" })
		hasRaptorEvent = true
	end
	if n % 30 < 1 then
		UpdateRules()
		UpdateBossInfo()
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

function widget:KeyPress(key, mods, isRepeat)
	if isRepeat then
		return
	end
	if key == KEYSYMS.B and mods.ctrl and not mods.shift and not mods.alt then
		isBossInfoExpanded = not isBossInfoExpanded
		updatePanel = true
		return
	end
end

function widget:IsAbove(x, y)
	if not bossInfo or PveStage() ~= stageBoss or not nPanelRows then
		return
	end

	local bottomY = y1 + PanelRow(nPanelRows + 1)
	isAboveBossInfo = x > x1 and x < x1 + (w * widgetScale) and y < y1 and y > math.max(0, bottomY)
end
