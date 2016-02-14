
function widget:GetInfo()
	return {
		name		= "Bet-Frontend",
		desc		= "Use player console and markers to place bets",
		author		= "BrainDamage",
		date		= "Jan,2013",
		license		= "WTFPL",
		layer		= 1,
		enabled		= true,
	}
end

local chipTexture = ':n:'..LUAUI_DIRNAME..'Images/chip.dds'
local backwardTexture = ':n:'..LUAUI_DIRNAME..'Images/backward.dds'
local forwardTexture = ':n:'..LUAUI_DIRNAME..'Images/forward.dds'
local buttonHighlightTexture = ':n:'..LUAUI_DIRNAME..'Images/button-highlight.dds'
local bgcorner = ":n:"..LUAUI_DIRNAME.."Images/bgcorner.png"
local betString = {"fail at ", "fails at ", "dead at ", "dies at ", "dead by ", "die at ", "death at"}
local playerString = {"player","pro","pr0","noob","newbie","idiot","n00b","tard", "autist","retard"}
local searchRadius = 300
local myPlayerID = Spring.GetMyPlayerID()
local GetUnitsInCylinder = Spring.GetUnitsInCylinder
local GetUnitPosition = Spring.GetUnitPosition
local GetUnitTeam = Spring.GetUnitTeam
local GetTeamList = Spring.GetTeamList
local GetGameFrame = Spring.GetGameFrame
local GetTeamStartPosition = Spring.GetTeamStartPosition
local GetPlayerInfo = Spring.GetPlayerInfo
local GetTeamInfo = Spring.GetTeamInfo
local GetTeamList = Spring.GetTeamList
local GetPlayerList = Spring.GetPlayerList
local GetUnitDefID = Spring.GetUnitDefID
local GetSelectedUnits = Spring.GetSelectedUnits
local SendCommands = Spring.SendCommands
local GetUnitRadius = Spring.GetUnitRadius
local IsUnitSelected = Spring.IsUnitSelected
local GetUnitDirection = Spring.GetUnitDirection
local GetGameRulesParam = Spring.GetGameRulesParam
local GetSpectatingState = Spring.GetSpectatingState
local GetUnitIsDead = Spring.GetUnitIsDead
local GetCameraPosition = Spring.GetCameraPosition
local GetMouseState = Spring.GetMouseState
local Echo = Spring.Echo
local min = math.min
local max = math.max
local cos = math.cos
local sin = math.sin
local abs = math.abs 
local diag = math.diag
local random = math.random
local pi = math.pi
local floor = math.floor
local random = math.random
local ceil = math.ceil
local callbackIndexOver
local callbackIndexBet
local unitHumanNames = {} -- indexed by unitID
local unitDisplayList = {}
local chipStackOffset = {}
local viewBets = true
local simSpeed = Game.gameSpeed
local serverGameFrame = 0
local AllowBets = true
local canAfford = true
local IsReplay = Spring.IsReplay()
local IsSpec = GetSpectatingState()
local IsPaused = false

local _G_INDEX = "betengine"
local MIN_BET_TIME = GetGameRulesParam(_G_INDEX.."MIN_BET_TIME")
local MIN_BET_TIME_SCALE = GetGameRulesParam(_G_INDEX.."MIN_BET_TIME_SCALE")
local BET_GRANULARITY = GetGameRulesParam(_G_INDEX.."BET_GRANULARITY")
local POINTS_PRIZE_PER_BET = {unit=GetGameRulesParam(_G_INDEX.."POINTS_PRIZE_PER_BET".."unit"),team=GetGameRulesParam(_G_INDEX.."POINTS_PRIZE_PER_BET".."team")}
local BET_COST = {unit=GetGameRulesParam(_G_INDEX.."BET_COST".."unit"),team=GetGameRulesParam(_G_INDEX.."BET_COST".."team")}
local STARTING_SCORE = GetGameRulesParam(_G_INDEX.."STARTING_SCORE")

local betStats = {}
local playerScores = {}
local betList = {}
local playerBetList = {}

local numBetUnits = 0

local glDepthTest = gl.DepthTest
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glDeleteList = gl.DeleteList
local glBeginEnd = gl.BeginEnd
local glColor = gl.Color
local glText = gl.Text
local glTranslate = gl.Translate
local glBillboard = gl.Billboard
local glRotate = gl.Rotate
local glScale = gl.Scale
local glVertex = gl.Vertex
local glTexRect = gl.TexRect
local glTexture = gl.Texture
local glTexCoord = gl.TexCoord
local glRect = gl.Rect
local glGetTextWidth = gl.GetTextWidth
local IsGameOver = false

local xRelPos, yRelPos		= 0.5, 0.12
local vsx, vsy				= gl.GetViewSizes()
local xPos, yPos            = xRelPos*vsx, yRelPos*vsy

local showSelectBets = true
local panelDelay = 0.3
local panelWidth = 215;
local panelHeight = 50;
local borderPadding = 4
local contentMargin = 4
local customScale = 1
local sizeMultiplier = 1
local maxBetPing = 3000
local graceGameframes = 90

local square = panelHeight-borderPadding-borderPadding-contentMargin-contentMargin


local lastSelectedUnit = -1
local lastSelectedUnitTime = -1
local lastBetTime = -1
local showingPanel = false
local mouseoverPlacebetBox = false


local function sqDist(x1,x2,y1,y2,z1,z2)
	return (x1-x2)^2+(y1-y2)^2+(z1-z2)^2
end

local function PlayerIDtoName(playerID)
	return not playerID and "none" or GetPlayerInfo(playerID) or playerID
end

local function TeamIDtoName(teamID)
	return not select(2,GetTeamInfo(teamID)) and teamID or GetPlayerInfo(select(2,GetTeamInfo(teamID))) or teamID
end

function widget:MapDrawCmd(playerID, cmdType, px, py, pz, labeltext)
	if playerID ~= myPlayerID then
		return
	end
	if cmdType ~= "point" then
		return
	end
	labeltext = labeltext:lower()
	local isPlayerBet = false
	for _,tempPlayerID in pairs(GetPlayerList()) do
		isPlayerBet = isPlayerBet or labeltext:find(PlayerIDtoName(tempPlayerID):lower())
		if isPlayerBet then
			break
		end
	end
	for _,string in ipairs(playerString) do
		isPlayerBet = isPlayerBet or labeltext:find(string)
		if isPlayerBet then
			break
		end
	end
	local start
	local stop
	for _,string in ipairs(betString) do
		start,stop = labeltext:find(string)
		if start and stop then
			break
		end
	end
	if not start or not stop then
		-- not a bet label
		return
	end
	local timeLabel = labeltext:sub(stop+1,#labeltext)
	local spacepos = timeLabel:find(" ")
	if spacepos then
		timeLabel = timeLabel:sub(1,spacepos) -- truncate at the first space if present
	end
	local time = tonumber(timeLabel)
	if not time then
		Echo("malformed time")
		return
	end
	time = time*BET_GRANULARITY -- conver to minutes

	local betID
	local betType

	if GetGameFrame() == 0 then
		local closest
		local mindist
		for _,teamID in ipairs(GetTeamList()) do
			local teamX,teamY,teamZ = GetTeamStartPosition(teamID)
			local dist = sqDist(px,teamX,py,teamY,pz,teamZ)
			if not mindist then
				closest = teamID
				mindist = dist
			else
				if mindist > dist then
					closest = teamID
					mindist = dist
				end
			end
		end
		if not closest then
			-- no start pos were found
			Echo("no nearbry players to chose a target from")
			return
		end
		betType = "team"
		betID = closest
	else
		local closest
		local mindist
		-- find closest unit
		for _,unitID in ipairs(GetUnitsInCylinder(px,pz,searchRadius)) do
			local unitX,unitY,unitZ = GetUnitPosition(unitID)
			local dist = sqDist(px,unitX,py,unitY,pz,unitZ)
			if not mindist then
				closest = unitID
				mindist = dist
			else
				if mindist > dist then	
					closest = unitID
					mindist = dist
				end
			end
		end
		if not closest then
			-- no units were found
			Echo("no nearbry units to chose a target from")
			return
		end
		if isPlayerBet then
			betID = GetUnitTeam(closest)
			betType = "team"
		else
			betID = closest
			betType = "unit"
		end
	end
	SendCommands("luarules placebet " .. betType .. " " .. betID .. " " .. time)
end

function RecvPlaceBet(ok,reason)
	if not ok and reason then
		Echo(reason)
	end
end

local function playerNameToTeamID(playerName)
	for _,teamID in pairs(GetTeamList()) do
		for _,playerID in pairs(GetPlayerList(teamID)) do
			local name,_,spectator = GetPlayerInfo(playerID)
			if not spectator and name == playerName then
				return teamID
			end
		end
	end
	-- if not found
	return nil
end


local function unitIDtoMeaningfulName(unitID)
	local unitOwner = GetUnitTeam(unitID)
	local unitDefID = GetUnitDefID(unitID)
	local unitName = unitID
	local playerName = ""
	if unitDefID then
		local unitDef = UnitDefs[unitDefID]
		if unitDef and unitDef.humanName then
			unitName = unitDef.humanName
		end
	end
	if unitOwner then
		local _,teamLeader = GetTeamInfo(unitOwner)
		if unitOwner then
			playerName = unitOwner
		end
		local leaderName = GetPlayerInfo(teamLeader)
		if leaderName then
			playerName = leaderName
		end
	end
	return playerName .. " \'s " .. unitName
end

function betKey(_,_,params)
	local betType = params[1]
	if not betType then
		Echo("betting: wrong input params, espect betType")
		return
	end
	local selUnits = GetSelectedUnits()
	if #selUnits == 0 then
		Echo("betting: you need to select a unit to bet")
		return
	end
	if #selUnits > 1 then
		Echo("betting: too many units selected")
		return
	end
	local selUnit = selUnits[1]
	if betType == "team" then
		betID = GetUnitTeam(selUnit)
	else
		betID = selUnit
	end
	
	SendCommands({"chatall", "pastetext /placebet " .. betType .. " " .. betID .. " "})
end

local function getMinBetTimeDelta()
	--the min time of bet will be slowly increased from 0 to MIN_BET_TIME in the period from game start to MIN_BET_TIME_SCALE
	return floor(min(1,GetGameFrame()/MIN_BET_TIME_SCALE)*max(MIN_BET_TIME,0))
end


--copied off directly because handling callback is such a pain
local function getMinBetTime()
	return GetGameFrame() + getMinBetTimeDelta(), getMinBetTimeDelta()
end

function getBetTime(_,_,params)
	local absTime, relTime = getMinBetTime()
	Echo("min absolute bet time: " .. ceil(absTime/BET_GRANULARITY) .. " min bet time increment: " .. floor(relTime/BET_GRANULARITY+0.5))
end

--copied off directly because handling callback is such a pain
local function getBetCost(playerID,betType,betID)
	if not playerID or not betType or not betID then
		return
	end
	if not BET_COST[betType] then
		return
	end
	local betCount = 0
	if playerBetList[playerID] and playerBetList[playerID][betType] and playerBetList[playerID][betType][betID] then
		betCount = #playerBetList[playerID][betType][betID]
	end
	 -- with negative best costs, first bet on the same element costs abs(BET_COST), second 2*abs(BET_COST), etc
	return BET_COST[betType] >= 0 and BET_COST[betType] or (betCount+1)*abs(BET_COST[betType])
end

function toggleViewBets(_,_,params)
	local oldVal = viewBets
	viewBets = not viewBets
	if tonumber(params[1]) then
		viewBets = params[1] ~= 0
	end
	if viewBets then
		Echo("displaying bets over units")
	else
		Echo("disabled display of bets over units")
	end
	if oldVal == true and viewBets == false then
		--delete all display lists
		for _,displayList in pairs(unitDisplayList) do
			glDeleteList(displayList)
			displayList = nil
		end
	end
	if oldVal == false and viewBets == true then
		for unitID, betInfo in pairs(betList.unit or {}) do
			updateDisplayList(unitID,betInfo)
		end
	end
end

function placeBet(_,_,params)
	if #params < 3 then
		Echo("too few params: betType betID time")
		return
	end
	local betType = params[1]
	local betID = params[2]
	if betType == "team" then
		if not tonumber(betID) then
			betID = playerNameToTeamID(betID)
		end
	end
	local time
	if params[3] == "soon" then
		time = floor(getMinBetTime()/BET_GRANULARITY+0.5)*BET_GRANULARITY
	elseif params[3]:find("+") then -- it's a time displacement
		local displacement = tonumber(params[3]:sub(2))
		if not time then
			Echo("invalid bet time")
			return
		end
		time = ceil(GetGameFrame()/BET_GRANULARITY)*BET_GRANULARITY + displacement*BET_GRANULARITY
	else 
		time = tonumber(params[3])
		if not time then
			Echo("invalid bet time")
			return
		end
		time = time*BET_GRANULARITY
	end
	SendCommands("luarules placebet " .. betType .. " " .. betID .. " " .. time) 
end

function printbets(_,_,params)
	local bets =  betList
	-- filter to only 1 betType if params is fed
	if params[1] then
		local tempBets = bets
		local betType = params[1]
		bets = {}
		bets[betType] = tempBets[betType]
		if not bets then
			Echo("invalid betType or no bets placed of that type")
			return
		end
	end
	for betType, betArray in pairs(bets) do
		local tempBetList = betArray
		-- filter to only 1 element if params is fed
		if betType == "team" then
			if params[2] then
				local index = playerNameToTeamID(params[2])
				if not index then
					Echo("Invalid playername")
					return
				end
				betArray = {}
				betArray[index] = tempBetList[index]
				if not betArray[index] then
					Echo("No bets available for selected player")
					return
				end
			end
		elseif betType == "unit" then
			if params[2] then
				local index = params[2]
				if not index then
					Echo("Invalid unitID")
					return
				end
				betArray = {}
				betArray[index] = tempBetList[index]
				if not betArray[index] then
					Echo("No bets available for selected unit")
					return
				end
			end
		end
		for betID, betsinfo in pairs(betArray) do
			if betType == "team" then
				local humanName = betID
				local _,teamLeader = GetTeamInfo(betID)
				local leaderName = GetPlayerInfo(teamLeader)
				if leaderName then
					humanName = leaderName
				end
				Echo("bets for player: " .. humanName )
			elseif betType == "unit" then
				local humanName
				if unitHumanNames[betID] then
					humanName = unitHumanNames[betID]
				else
					-- try to generate it anwyay
					humanName = unitIDtoMeaningfulName(betID)
				end
				Echo("bets for " .. humanName )
			end
			for timeSlot,betEntry in pairs(betsinfo) do
				Echo(getBetLineText(betEntry))
			end
			local numBets, totalScore, totalWin = betStats[betType][betID].numBets, betStats[betType][betID].totalSpent, betStats[betType][betID].prizePoints 
			local betCost = getBetCost(myPlayerID,betType,betID)
			Echo(getTotalText(numBets,totalScore,totalWin,betCost))
		end
	end
end

function selectBetUnits()
	local units = {}
	for unitID,displayList in pairs(unitDisplayList) do
		table.insert(units, unitID)
	end
	Spring.SelectUnitArray(units)
	Echo("Units with bets on them: "..#units)
end

function printscores()
	for playerID, score in pairs(playerScores) do
		playerID = PlayerIDtoName(playerID)
		Echo("\255\200\255\200"..playerID .. "\255\200\200\200: score: \255\255\235\200" .. score.score .. " \255\200\200\200currently running bets: \255\255\235\200" .. score.currentlyRunning .." \255\200\200\200won: \255\255\235\200" .. score.won .. " \255\200\200\200lost: \255\255\235\200" .. score.lost .. " \255\200\200\200total bets placed: \255\255\235\200" .. score.totalPlaced)
	end
end

function widget:GameOver()
	if next(playerScores) ~= nil then
		Echo("Betting game over! Scores are:")
	end
	if #playerScores > 0 then
		printscores()
	end
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].RemoveRect('betfrontend')
	end
	IsGameOver = true
end

function betOverCallback(betType, betID, winnerID, prizePoints)
	winnerID = PlayerIDtoName(winnerID)
	local textstring = ""
	if betType == "team" then
		textstring = "team " .. TeamIDtoName(betID)
	elseif betType == "unit" then
		textstring = unitHumanNames[betID] or unitIDtoMeaningfulName(betID)
		-- delete to avoid errors when recycling ids
		unitHumanNames[betID] = nil
	end
	Echo( textstring .. " has died! " .. winnerID .. " has won " .. prizePoints .. " points.")
	if betType == "unit" then
		updateDisplayList(betID,betList[betType][betID])
	end
end

function receivedBetCallback(playerID, betType, betID, betTime, betCost)
	playerID = PlayerIDtoName(playerID)
	local textstring = ""
	if betType == "team" then
		textstring = "team " .. TeamIDtoName(betID)
	elseif betType == "unit" then
		textstring = unitIDtoMeaningfulName(betID)
		-- save the unit's text string because unitID will be invalid after it dies
		-- and we won't be able to fetch infos
		unitHumanNames[betID] = textstring
	end
	Echo( playerID .. " has bet " .. betCost .. " points on " .. textstring .. " to die at " .. betTime/(BET_GRANULARITY) .. " minutes")
	if betType == "unit" then
		updateDisplayList(betID,betList[betType][betID])
	end
end

function betValidCallback(playerID, betType, betID, timeSlot)
	if betType == "unit" then
		updateDisplayList(betID,betList[betType][betID])
	end
end

function widget:SetConfigData(data)
	viewBets = data.viewBets
	if data.xRelPos ~= nil then
		xRelPos = data.xRelPos or xRelPos
		yRelPos1 = data.yRelPos or yRelPos
		xPos = xRelPos * vsx
		yPos = yRelPos * vsy
	end
end

function widget:GetConfigData()
	return
	{
		viewBets = viewBets,
		xRelPos = xRelPos,
		yRelPos = yRelPos1
	}
end

function processScaling()
  vsx,vsy = Spring.GetViewGeometry()
  if customScale == nil then
	customScale = 1
  end
  sizeMultiplier   = 0.4 + (vsx*vsy / 7500000) * customScale
end

function processBoxes()
	panelBox = {xPos-((panelWidth/2)*sizeMultiplier), yPos-((panelHeight/2)*sizeMultiplier), xPos+((panelWidth/2)*sizeMultiplier), yPos+((panelHeight/2)*sizeMultiplier)}
	panelBoxContent = {panelBox[1]+((borderPadding+contentMargin)*sizeMultiplier), panelBox[2]+((borderPadding+contentMargin)*sizeMultiplier), panelBox[3]-((borderPadding+contentMargin)*sizeMultiplier), panelBox[4]-((borderPadding+contentMargin)*sizeMultiplier)}
	panelBoxForward = {panelBoxContent[3]-(square*sizeMultiplier), panelBoxContent[2], panelBoxContent[3], panelBoxContent[4]}
	panelBoxBackward = {panelBoxContent[3]-((square+square+contentMargin)*sizeMultiplier), panelBoxContent[2], panelBoxContent[3]-((square+contentMargin)*sizeMultiplier), panelBoxContent[4]}
	placebetBox = {panelBox[3], panelBox[2], panelBox[3]+(120*sizeMultiplier), panelBox[4]}
end
processBoxes()

function widget:ViewResize(vsx, vsx)
	vsx,vsy = gl.GetViewSizes()
	xPos = xRelPos * vsx
	yPos = yRelPos * vsy
	processScaling()
	processBoxes()
end
function RecvBetStats(newBetStats)
	betStats = newBetStats or {}
	widget:GameFrame(GetGameFrame())
end

function RecvPlayerScores(newPlayerScores)
	playerScores = newPlayerScores or {}
end

function spairs(t, order)	-- http://stackoverflow.com/questions/15706270/sort-a-table-in-lua
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

function RecvBetList(newBetList)
	betList = newBetList or {}
	--[[for unitID, betInfo in pairs(newBetList.unit) do
		betList.unit[unitID] = {}
		for timeSlot,bets in spairs(betInfo) do
			betList.unit[unitID][timeSlot] = bets
		end
	end]]--
	widget:GameFrame(GetGameFrame())
end

function RecvPlayerBetList(newPlayerBetList)
	playerBetList = newPlayerBetList or {}
end

function widget:Initialize()
	widgetHandler:RegisterGlobal('getBetsStats', RecvBetStats)
	widgetHandler:RegisterGlobal('getPlayerScores', RecvPlayerScores)
	widgetHandler:RegisterGlobal('getBetList', RecvBetList)
	widgetHandler:RegisterGlobal('getPlayerBetList', RecvPlayerBetList)
	widgetHandler:RegisterGlobal('placeBet', RecvPlaceBet)

	widgetHandler:RegisterGlobal('betOverCallback', betOverCallback)
	widgetHandler:RegisterGlobal('receivedBetCallback', receivedBetCallback)
	widgetHandler:RegisterGlobal('betValidCallback', betValidCallback)

	widgetHandler:AddAction("placebet", placeBet, nil, "t")
	widgetHandler:AddAction("printbets", printbets, nil, "t")
	widgetHandler:AddAction("printscores", printscores, nil, "t")
	widgetHandler:AddAction("viewbets", toggleViewBets, nil, "t")
	widgetHandler:AddAction("bettime", getBetTime, nil, "t")
	widgetHandler:AddAction("bet", betKey, nil, "t")
	widgetHandler:AddAction("selectbets", selectBetUnits, nil, "t")

	SendCommands({"bind ctrl+alt+b bet unit","bind ctrl+shift+alt+b bet team"})

	--FIXME: why is the engine retarded and blocks commands to luarules before frame2???
	if GetGameFrame() > 2 then
		SendCommands({"luarules getbetsstats","luarules getplayerscores", "luarules getbetlist", "luarules getplayerbetlist"})
	end
	
	
	
	WG['betfrontend'] = {}
	WG['betfrontend'].GetPlayerScores = function()
		return playerScores
	end
end

function widget:Shutdown()

	widgetHandler:DeregisterGlobal('betOverCallback')
	widgetHandler:DeregisterGlobal('receivedBetCallback')
	widgetHandler:DeregisterGlobal('betValidCallback')

	widgetHandler:DeregisterGlobal('getBetsStats')
	widgetHandler:DeregisterGlobal('getPlayerScores')
	widgetHandler:DeregisterGlobal('getBetList')
	widgetHandler:DeregisterGlobal('getPlayerBetList')
	widgetHandler:DeregisterGlobal('placeBet')

	for _,displayList in pairs(unitDisplayList) do
		glDeleteList(displayList)
		displayList = nil
	end
end

function widget:PlayerChanged(playerID)
	IsSpec = GetSpectatingState()
end

function widget:UnitDestroyed(unitID)
	if unitDisplayList[unitID] then
		glDeleteList(unitDisplayList[unitID])
		unitDisplayList[unitID] = nil
	end
end


function drawCylinder(radius, halfLength)
	local slices = 20
	gl.MatrixMode(GL.MODELVIEW)
	for i = 0, slices do
		local theta = i*(2.0*pi/slices)
		local nextTheta = (i+1)*(2.0*pi/slices)
		glBeginEnd(GL.TRIANGLE_STRIP, function()
			--vertex at middle of end
			glVertex(0.0, halfLength, 0.0)
			--vertices at edges of circle*
			glVertex(radius*cos(theta), halfLength, radius*sin(theta))
			glVertex(radius*cos(nextTheta), halfLength, radius*sin(nextTheta))
			--the same vertices at the bottom of the cylinder
			glVertex(radius*cos(nextTheta), -halfLength, radius*sin(nextTheta))
			glVertex(radius*cos(theta), -halfLength, radius*sin(theta))
			glVertex(0.0, -halfLength, 0.0)
		end)
	end
end


local function DrawRectRound(px,py,sx,sy,cs)
	glTexCoord(0.8,0.8)
	glVertex(px+cs, py, 0)
	glVertex(sx-cs, py, 0)
	glVertex(sx-cs, sy, 0)
	glVertex(px+cs, sy, 0)
	
	glVertex(px, py+cs, 0)
	glVertex(px+cs, py+cs, 0)
	glVertex(px+cs, sy-cs, 0)
	glVertex(px, sy-cs, 0)
	
	glVertex(sx, py+cs, 0)
	glVertex(sx-cs, py+cs, 0)
	glVertex(sx-cs, sy-cs, 0)
	glVertex(sx, sy-cs, 0)
	
	local o = 0.07		-- texture offset, because else gaps could show
	
	-- top left
	glTexCoord(o,o)
	glVertex(px, py, 0)
	glTexCoord(o,1-o)
	glVertex(px+cs, py, 0)
	glTexCoord(1-o,1-o)
	glVertex(px+cs, py+cs, 0)
	glTexCoord(1-o,o)
	glVertex(px, py+cs, 0)
	-- top right
	glTexCoord(o,o)
	glVertex(sx, py, 0)
	glTexCoord(o,1-o)
	glVertex(sx-cs, py, 0)
	glTexCoord(1-o,1-o)
	glVertex(sx-cs, py+cs, 0)
	glTexCoord(1-o,o)
	glVertex(sx, py+cs, 0)
	-- bottom left
	glTexCoord(o,o)
	glVertex(px, sy, 0)
	glTexCoord(o,1-o)
	glVertex(px+cs, sy, 0)
	glTexCoord(1-o,1-o)
	glVertex(px+cs, sy-cs, 0)
	glTexCoord(1-o,o)
	glVertex(px, sy-cs, 0)
	-- bottom right
	glTexCoord(o,o)
	glVertex(sx, sy, 0)
	glTexCoord(o,1-o)
	glVertex(sx-cs, sy, 0)
	glTexCoord(1-o,1-o)
	glVertex(sx-cs, sy-cs, 0)
	glTexCoord(1-o,o)
	glVertex(sx, sy-cs, 0)
end

local function RectRound(px,py,sx,sy,cs)
	glTexture(bgcorner)
	glBeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs)
	glTexture(false)
end


function getBetLineText(betEntry)
	local playerName = PlayerIDtoName(betEntry.player)
	local validBet = GetGameFrame() >= betEntry.validFrom
	return " \255\200\200\200"..(validBet and "  " or "x") .. "  \255\155\155\155time: \255\200\200\200" .. (betEntry.betTime/(BET_GRANULARITY)) .. "    \255\255\255\255" .. playerName .. (validBet and "" or ("    \255\155\155\155valid from: \255\200\200\200" .. floor(betEntry.validFrom/BET_GRANULARITY+0.5)) )
end

function getTotalText(numBets,totalScore,totalWin,betValue)
	--return "\255\255\55\1Bets: " .. numBets .. "    \255\255\180\1Total points bet: " .. totalScore .. "    \255\255\255\1Prize: " .. totalWin .. "    \255\55\255\1Betting cost: " .. betValue
	return "\255\255\255\1Prize: " .. totalWin .. " chip" .. (totalWin > 1 and "s" or "")
end

function updateDisplayList(unitID,betInfo)
	local stepSize = 15
	--local cubeShift = 25
	if not betStats.unit or not betStats.unit[unitID] then 
		return 
	end 
 	local numBets, totalScore, totalWin = betStats.unit[unitID].numBets, betStats.unit[unitID].totalSpent, betStats.unit[unitID].prizePoints 
	local cubeScaleFactor = (totalWin)^0.5 --while it should be cube root to make the volume linear with the total win, i prefer square, or it grows too little 
	local cubeFactor = 5*cubeScaleFactor
	if unitDisplayList[unitID] then
		glDeleteList(unitDisplayList[unitID])
	end
	if GetUnitIsDead(unitID) == false then
		unitDisplayList[unitID] = glCreateList( function()
			glPushMatrix()
				local unitPos = {GetUnitPosition(unitID,true,true)}
				--glTranslate(unitPos[4],unitPos[5]+GetUnitRadius(unitID),unitPos[6])
				if IsUnitSelected(unitID) then
					glTranslate(25,25,25)
					glBillboard()
					local betCost = getBetCost(myPlayerID,"unit",unitID)
					local titleText = getTotalText(numBets,totalScore,totalWin,betCost)
					local totalBgHeight = (numBets*stepSize)+stepSize
					local padding = 8
					
					local maxWidth =0
					local betLines = {}
					for timeSlot,betEntry in spairs(betInfo) do
						glTranslate(0,stepSize,0)
						betLines[betEntry] = getBetLineText(betEntry)
						maxWidth = math.max(maxWidth, gl.GetTextWidth(betLines[betEntry]))
					end
					maxWidth = maxWidth * stepSize
					
					glColor(0,0,0,0.5)
					RectRound(-padding, -padding+stepSize-totalBgHeight, maxWidth+padding, padding+(stepSize*0.65)+1, padding*0.66)
					
					glTranslate(0,-totalBgHeight,0)
					for timeSlot,betEntry in spairs(betInfo) do
						glTranslate(0,stepSize,0)
						glText(betLines[betEntry], 0, 0,stepSize, "o")
					end
					glTranslate(0,stepSize+1,0)
					local betCost = getBetCost(myPlayerID,"unit",unitID)
					glText(titleText, 0, 0,stepSize, "o")
				else
					local iconSize = 18
					local chipHeight = 5.5
					glTranslate(0,50,0)
					glColor({1,1,1,1})
					glTexture(chipTexture)
					for i = 1, totalWin do
						if chipStackOffset[i] == nil then
							chipStackOffset[i] = {x=random(),z=random(),r=random()}
						end
						local offsetX = chipStackOffset[i].x*1.5
						local offsetZ = chipStackOffset[i].z*1.5
						glTranslate(offsetX,0,offsetZ)
						glRotate(90,1,0,0)
						glPushMatrix()
							glRotate(chipStackOffset[i].r*360,0,0,1)
							glTexRect(-(iconSize/2), -(iconSize/2), (iconSize/2), (iconSize/2))
						glPopMatrix()
						glRotate(90,-1,0,0)
						glTranslate(-offsetX,chipHeight,-offsetZ)
					end
					glTexture(false)
				end
			glPopMatrix()
		end)
	else
		unitDisplayList[unitID] = nil
	end
end

function widget:GameProgress(serverFrameNum)
	serverGameFrame = serverFrameNum
	--Spring.Echo(serverGameFrame)
end

function widget:GameFrame(n)
	--[[if serverGameFrame - n < graceGameframes then
		AllowBets = true
	else
		AllowBets = false
	end]]--
end

local sec = 0
function widget:Update(dt)
	if not viewBets or not betList.unit then
		return
	end
	sec=sec+dt
	if sec > 0.2 then
		numBetUnits = 0
		for unitID, betInfo in pairs(betList.unit) do
			updateDisplayList(unitID,betInfo)
			numBetUnits = numBetUnits + 1
		end
		if lastSelectedUnit > 0 and lastBetTime > 0 then
			lastBetTime = getValidBetTime(lastSelectedUnit, (lastBetTime-1), 1)
		end
	end
end

function widget:GamePaused(playerID, paused)
	IsPaused = true
end

function widget:DrawScreen()
	if not IsGameOver and IsSpec then
		local selUnits = GetSelectedUnits()
		if AllowBets and not IsReplay then
			if #selUnits == 1 then
				local unitID = selUnits[1]
				local now = os.clock()
				local absTime, relTime = getMinBetTime()
				if lastSelectedUnit ~= unitID then
					lastSelectedUnitTime = os.clock()
					lastBetTime = getValidBetTime(unitID, (ceil(absTime/BET_GRANULARITY)-1), 1)
					if betList.unit ~= nil and betList.unit[unitID] ~= nil then
						updateDisplayList(unitID,betList.unit[unitID])
					end
				end
				lastSelectedUnit = unitID
				showingPanel = false
				if now-lastSelectedUnitTime > panelDelay then
					lastSelectedUnit = unitID
					showingPanel = true
					local betCost = getBetCost(myPlayerID,"unit",unitID)
					canAfford = (playerScores[myPlayerID] == nil and STARTING_SCORE >= betCost) or (playerScores[myPlayerID].score >= betCost)

					if lastBetTime < ceil(absTime/BET_GRANULARITY) then
						lastBetTime = getValidBetTime(lastSelectedUnit, (ceil(absTime/BET_GRANULARITY)-1), 1)
					end
					
					-- background
					glColor(0, 0, 0, 0.6)
					RectRound(panelBox[1], panelBox[2], panelBox[3], panelBox[4], 8*sizeMultiplier)
					glColor(1,1,1,0.022)
					RectRound(panelBox[1]+(borderPadding*sizeMultiplier), panelBox[2]+(borderPadding*sizeMultiplier), panelBox[3]-(borderPadding*sizeMultiplier), panelBox[4]-(borderPadding*sizeMultiplier), 6*sizeMultiplier)
					glColor(1, 1, 1, 1)
					
					-- place bet
					if canAfford then
						if mouseoverPlacebetBox then
							glColor(0.6, 0, 0, 0.75)
						else
							glColor(0.5, 0, 0, 0.66)
						end
						RectRound(placebetBox[1], placebetBox[2], placebetBox[3], placebetBox[4], 8*sizeMultiplier)
						
						local textcolor = "\255\255\240\240"
						if mouseoverPlacebetBox then
							glColor(1,0.3,0.3,0.4)
							textcolor = "\255\255\255\255"
						else
							glColor(1,0.4,0.4,0.2)
						end
						RectRound(placebetBox[1]+(borderPadding*sizeMultiplier), placebetBox[2]+(borderPadding*sizeMultiplier), placebetBox[3]-(borderPadding*sizeMultiplier), placebetBox[4]-(borderPadding*sizeMultiplier), 6*sizeMultiplier)
						glText(textcolor.."Place bet", placebetBox[1]+((borderPadding+14)*sizeMultiplier), yPos-(6*sizeMultiplier), (19*sizeMultiplier), "nlo")
					end
					
					-- chip cost
					glTexture(chipTexture)
					local offsetAdd = -5
					local addsize = 18
					local offset = offsetAdd * betCost
					for i=1, betCost do
						offset = offset -offsetAdd
						addsize = 18
						glColor(0,0,0,0.2)
						glTexRect(panelBoxContent[1]-(addsize*sizeMultiplier)+offset, panelBoxContent[2]-(addsize*sizeMultiplier), panelBoxContent[1]+((square+addsize)*sizeMultiplier)+offset, panelBoxContent[4]+(addsize*sizeMultiplier))
						addsize = 17
						glColor(0,0,0,0.4)
						glTexRect(panelBoxContent[1]-(addsize*sizeMultiplier)+offset, panelBoxContent[2]-(addsize*sizeMultiplier), panelBoxContent[1]+((square+addsize)*sizeMultiplier)+offset, panelBoxContent[4]+(addsize*sizeMultiplier))
						addsize = 15
						glColor(0.85, 0.85, 0.85, 1)
						glTexRect(panelBoxContent[1]-(addsize*sizeMultiplier)+offset, panelBoxContent[2]-(addsize*sizeMultiplier), panelBoxContent[1]+((square+addsize)*sizeMultiplier)+offset, panelBoxContent[4]+(addsize*sizeMultiplier))
					end
					glText(betCost, panelBox[1]+((borderPadding+(panelHeight/2.66)+(contentMargin/2.66))*sizeMultiplier), yPos-(6*sizeMultiplier), (19+(addsize/6))*sizeMultiplier, "nco")
					
					-- back/forward buttons
					if canAfford then
						if mouseoverForwardBox then
							glColor(1, 1, 1, 1)
						else
							glColor(1, 1, 1, 0.6)
						end
						glTexture(forwardTexture)
						glTexRect(panelBoxForward[1],panelBoxForward[2],panelBoxForward[3],panelBoxForward[4])
						--local timePosX = panelBoxForward[1]-(12*sizeMultiplier)
						local prevAvalibleTime = getValidBetTime(lastSelectedUnit, (lastBetTime), -1)
						if absTime/BET_GRANULARITY < lastBetTime-1 and prevAvalibleTime < lastBetTime and prevAvalibleTime >= (ceil(absTime/BET_GRANULARITY)) then
							if mouseoverBackwardBox then
								glColor(1, 1, 1, 1)
							else
								glColor(1, 1, 1, 0.6)
							end
							glTexture(backwardTexture)
							glTexRect(panelBoxBackward[1],panelBoxBackward[2],panelBoxBackward[3],panelBoxBackward[4])
							--timePosX = panelBoxBackward[1]-(12*sizeMultiplier)
						end
						
						-- bet time
						local timePosX = panelBoxBackward[1]-(12*sizeMultiplier)
						glColor(1, 1, 1, 1)
						glText(lastBetTime, timePosX, yPos-(6*sizeMultiplier), (19*sizeMultiplier), "nro")
					else
						glText('cant afford bet', panelBoxForward[3]-(6*sizeMultiplier), yPos-(6*sizeMultiplier), (19*sizeMultiplier), "nro")
					end
					if (WG['guishader_api'] ~= nil) then
						local x2 = placebetBox[3]
						if not canAfford then
							x2 = panelBox[3]
						end
						WG['guishader_api'].InsertRect(panelBox[1], panelBox[2], x2, panelBox[4], 'betfrontend')
					end
					glTexture(false)
					glColor(1, 1, 1, 1)
				end
			else
				showingPanel = false
				lastSelectedUnit = -1
				lastBetTime = -1
				if showSelectBets and numBetUnits > 0 then
					showingPanel = true
					if mouseoverSelectBetsBox then
						--glColor(0.64, 0.33, 0, 0.55)
						glColor(0, 0, 0, 0.55)
					else
						--glColor(0.6, 0.29, 0, 0.5)
						glColor(0, 0, 0, 0.5)
					end
					RectRound(panelBox[1], panelBox[2], panelBox[3], panelBox[4], 8*sizeMultiplier)
					
					--local textcolor = "\255\255\240\240"
					local textcolor = "\255\233\233\233"
					if mouseoverSelectBetsBox then
						--glColor(1,0.66,0.3,0.26)
						glColor(1,1,1,0.15)
						textcolor = "\255\255\255\255"
					else
						--glColor(1,0.8,0.4,0.15)
						glColor(1,1,1,0.05)
					end
					RectRound(panelBox[1]+(borderPadding*sizeMultiplier), panelBox[2]+(borderPadding*sizeMultiplier), panelBox[3]-(borderPadding*sizeMultiplier), panelBox[4]-(borderPadding*sizeMultiplier), 6*sizeMultiplier)
					local text = "Select unit with bet"
					if numBetUnits > 1 then
						text = ""..numBetUnits.." units with a bet"
					end
					glText(textcolor..text, xPos, yPos-(6*sizeMultiplier), (19*sizeMultiplier), "nco")
					
					if (WG['guishader_api'] ~= nil) then
						WG['guishader_api'].InsertRect(panelBox[1], panelBox[2], panelBox[3], panelBox[4], 'betfrontend')
					end
				end
			end
			if not showingPanel then
				if (WG['guishader_api'] ~= nil) then
					WG['guishader_api'].RemoveRect('betfrontend')
				end
			end
		end
	end
end

function getValidBetTime(unitID, value, addition)
	if betList.unit ~= nil and betList.unit[unitID] ~= nil then
		local duplicate = false
		while true do
			value = value + addition
			for timeSlot,_ in pairs(betList.unit[unitID]) do
				if timeSlot/1800 == value then
					duplicate = true
					break
				end
			end
			if not duplicate then
				break
			else
				duplicate = false
			end
		end
		return value
	else
		return value+addition
	end
end


function isInBox(mx, my, box)
    return mx > box[1] and my > box[2] and mx < box[3] and my < box[4]
end

function widget:IsAbove(mx, my)
	if not IsGameOver and showingPanel and IsSpec then
		if lastSelectedUnit > 0 and AllowBets then
			if isInBox(mx, my, placebetBox) then
				mouseoverPlacebetBox = true
			else
				mouseoverPlacebetBox = false
			end
			if isInBox(mx, my, panelBoxForward) then
				mouseoverForwardBox = true
			else
				mouseoverForwardBox = false
			end
			if isInBox(mx, my, panelBoxBackward) then
				mouseoverBackwardBox = true
			else
				mouseoverBackwardBox = false
			end
		else
			if isInBox(mx, my, panelBox) and showSelectBets and numBetUnits > 0 then
				mouseoverSelectBetsBox = true
			else
				mouseoverSelectBetsBox = false
			end
		end
	end
    return (isInBox(mx, my, panelBox) or isInBox(mx, my, placebetBox))
end


function widget:MousePress(mx, my, mb)
	if not IsGameOver and IsSpec and showingPanel then
		if lastSelectedUnit > 0 and AllowBets then
			if mb == 1 and (isInBox(mx, my, panelBox) or (isInBox(mx, my, placebetBox) and canAfford)) then
				if isInBox(mx, my, panelBoxForward) then
					panelBoxForwardPressed = true
				end
				if isInBox(mx, my, panelBoxBackward) then
					panelBoxBackwardPressed = true
				end
				if isInBox(mx, my, placebetBox) then
					placebetBoxPressed = true
				end
				return true
			end
		else
			if isInBox(mx, my, panelBox) and showSelectBets and numBetUnits > 0 then
				selectbetsBoxPressed = true
				return true
			end
		end
	end
end

function widget:MouseRelease(mx, my, mb)
	if not IsGameOver and IsSpec and showingPanel then
		if lastSelectedUnit > 0 and AllowBets and canAfford then
			if mb == 1 and (isInBox(mx, my, panelBox) or isInBox(mx, my, placebetBox)) then
				if isInBox(mx, my, panelBoxForward) and panelBoxForwardPressed ~= nil then
					panelBoxForwardPressed = nil
					lastBetTime = getValidBetTime(lastSelectedUnit, lastBetTime, 1)
				end
				if isInBox(mx, my, panelBoxBackward) and panelBoxBackwardPressed ~= nil then
					panelBoxBackwardPressed = nil
					local newBetTime = getValidBetTime(lastSelectedUnit, lastBetTime, -1)
					lastBetTime = newBetTime
				end
				if isInBox(mx, my, placebetBox) and placebetBoxPressed ~= nil then
					placebetBoxPressed = nil
					placeBet(_,_,{"unit",lastSelectedUnit,tostring(lastBetTime)})
					lastBetTime = getValidBetTime(lastSelectedUnit, (lastBetTime), 1)
				end
				return true
			end
		else
			if isInBox(mx, my, panelBox) and selectbetsBoxPressed ~= nil and numBetUnits > 0 then
				selectbetsBoxPressed = nil
				SendCommands({"selectbets"})
				return true
			end
		end
	end
end

function widget:TweakMousePress(mx, my, mb)
    if (mb == 2 or mb == 3) and (isInBox(mx, my, panelBox) or isInBox(mx, my, placebetBox)) then
        return true
    end
end

function widget:TweakMouseMove(mx, my, dx, dy)
    if panelBox[1] + dx >= 0 and placebetBox[3] + dx <= vsx then
		xRelPos = xRelPos + dx/vsx
	end
    if panelBox[2] + dy >= 0 and panelBox[4] + dy  <= vsy then 
		yRelPos = yRelPos + dy/vsy
	end
	xPos, yPos = xRelPos * vsx,yRelPos * vsy
	processBoxes()
end

function widget:DrawWorld()
	local camX, camY, camZ = GetCameraPosition()
	glPushMatrix()
		for unitID,displayList in pairs(unitDisplayList) do
			local x,y,z = GetUnitPosition(unitID,true,true)
			local camDistance = diag(camX-x, camY-y, camZ-z) 
			local usedScale = 0.55 + (camDistance/4500)
			glPushMatrix()
			glTranslate(x,y+GetUnitRadius(unitID),z)
			glScale(usedScale,usedScale,usedScale)
			glCallList(displayList)
			glPopMatrix()
		end
	glPopMatrix()
end
