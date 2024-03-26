if not (Spring.Utilities.Gametype.IsRaptors() and not Spring.Utilities.Gametype.IsScavengers()) then
	return false
end

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

local useWaveMsg                = VFS.Include('LuaRules/Configs/raptor_spawn_defs.lua').useWaveMsg

local I18N                      = Spring.I18N
local GetGameSeconds            = Spring.GetGameSeconds

local customScale               = 1
local widgetScale               = customScale
local font, font2
local messageArgs, marqueeMessage
local refreshMarqueeMessage     = false
local showMarqueeMessage        = false

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
local waveSpeed                 = 0.1
local waveCount                 = 0
local waveTime
local gotScore
local scoreCount                = 0
local gameInfo                  = {}
local resistancesTable          = {}
local currentlyResistantTo      = {}
local currentlyResistantToNames = {}
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
	"raptorKills",
	"raptorQueenAnger",
	"RaptorQueenAngerGain_Aggression",
	"RaptorQueenAngerGain_Base",
	"RaptorQueenAngerGain_Eco",
	"raptorQueenHealth",
	"raptorQueenTime",
	"raptorTechAnger",
}

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

local function Interpolate(value, inMin, inMax, outMin, outMax)
	-- Ensure the value is within the specified range
	value = (value < inMin) and inMin or ((value > inMax) and inMax or value)

	-- Calculate the interpolation
	return outMin + (value - inMin) / (inMax - inMin) * (outMax - outMin)
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
	local stage = RaptorStage(currentTime)

	if stage == stageGrace then
		font:Print(I18N('ui.raptors.gracePeriod', { time = string.formatTime(math.ceil(((currentTime - gameInfo.raptorGracePeriod) * -1) - 0.5)) }), panelMarginX, PanelRow(1), panelFontSize)
	elseif stage == stageMain then
		local hatchEvolutionString = I18N('ui.raptors.queenAngerWithTech', { anger = gameInfo.raptorQueenAnger, techAnger = gameInfo.raptorTechAnger })
		font:Print(hatchEvolutionString, panelMarginX, PanelRow(1), panelFontSize - Interpolate(font:GetTextWidth(hatchEvolutionString) * panelFontSize, 234, 244, 0, 0.59))

		local gain = gameInfo.RaptorQueenAngerGain_Base + gameInfo.RaptorQueenAngerGain_Aggression + gameInfo.RaptorQueenAngerGain_Eco
		font:Print(I18N('ui.raptors.queenETA', { time = string.formatTime((100 - gameInfo.raptorQueenAnger) / gain) }), panelMarginX + 5, PanelRow(2), panelFontSize)
		font:Print(I18N('ui.raptors.queenAngerBase', { value = math.round(gameInfo.RaptorQueenAngerGain_Base, 3) }), panelMarginX + 5, PanelRow(3), panelFontSize)
		font:Print(I18N('ui.raptors.queenAngerAggression', { value = math.round(gameInfo.RaptorQueenAngerGain_Aggression, 3) }), panelMarginX + 5, PanelRow(4), panelFontSize)

		if #currentlyResistantToNames > 0 then
			currentlyResistantToNames = {}
			currentlyResistantTo = {}
		end
	elseif stage == stageQueen then
		font:Print(I18N('ui.raptors.queenHealth', { health = gameInfo.raptorQueenHealth }), panelMarginX, PanelRow(1), panelFontSize)
		for i = 1, #currentlyResistantToNames do
			if i == 1 then
				font:Print(I18N('ui.raptors.queenResistantToList'), panelMarginX, PanelRow(11), panelFontSize)
			end
			font:Print(currentlyResistantToNames[i], panelMarginX + 20, PanelRow(11 + i), panelFontSize)
		end
	end

	font:Print(I18N('ui.raptors.raptorKillCount', { count = gameInfo.raptorKills }), panelMarginX, PanelRow(6), panelFontSize)
	local endless = ""
	if modOptions.raptor_endless then
		endless = ' (' .. I18N('ui.raptors.difficulty.endless') .. ')'
	end
	local difficultyCaption = I18N('ui.raptors.difficulty.' .. modOptions.raptor_difficulty)
	font:Print(I18N('ui.raptors.mode', { mode = difficultyCaption }) .. endless, 80, h - 170, panelFontSize)
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

function widget:DrawScreen()
	if updatePanel then
		if (guiPanel) then
			gl.DeleteList(guiPanel);
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
	for i = 1, #rules do
		local rule = rules[i]
		gameInfo[rule] = Spring.GetGameRulesParam(rule) or 0
	end

	updatePanel = true
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
	if n % 30 == 0 then
		UpdateRules()
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

function widget:MouseMove(x, y, dx, dy, button)
	if moving then
		updatePos(x1 + dx, y1 + dy)
	end
end

function widget:MousePress(x, y, button)
	if x > x1 and x < x1 + (w * widgetScale) and
		y > y1 and y < y1 + (h * widgetScale)
	then
		capture = true
		moving = true
	end
	return capture
end

function widget:MouseRelease(x, y, button)
	capture = nil
	moving = nil
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
