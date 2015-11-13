
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
local Echo = Spring.Echo
local min = math.min
local max = math.max
local cos = math.cos
local sin = math.sin
local abs = math.abs 
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
end

function widget:GetConfigData()
	return
	{
		viewBets = viewBets
	}
end

function RecvBetStats(newBetStats)
	betStats = newBetStats or {}
	widget:GameFrame(GetGameFrame())
end

function RecvPlayerScores(newPlayerScores)
	playerScores = newPlayerScores or {}
end

function RecvBetList(newBetList)
	betList = newBetList or {}
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

	SendCommands({"bind ctrl+alt+b bet unit","bind ctrl+shift+alt+b bet team"})

	--FIXME: why is the engine retarded and blocks commands to luarules before frame2???
	if GetGameFrame() > 2 then
		SendCommands({"luarules getbetsstats","luarules getplayerscores", "luarules getbetlist", "luarules getplayerbetlist"})
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
	return " \255\225\225\225"..(validBet and "-" or "x") .. "  time: " .. (betEntry.betTime/(BET_GRANULARITY)) .. "   \255\255\255\255" .. playerName .. "\255\225\225\225".. (validBet and "" or ("   valid from: " .. floor(betEntry.validFrom/BET_GRANULARITY+0.5)) ) .. "  cost: " .. betEntry.betCost
end

function getTotalText(numBets,totalScore,totalWin,betValue)
	return "\255\255\55\1Bets: " .. numBets .. "   \255\255\180\1Total points bet: " .. totalScore .. "   \255\255\255\1Prize: " .. totalWin .. "   \255\55\255\1Betting cost: " .. betValue
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
				glTranslate(unitPos[4],unitPos[5]+GetUnitRadius(unitID),unitPos[6])
				if IsUnitSelected(unitID) then
					glTranslate(25,25,25)
					glBillboard()
					local betCost = getBetCost(myPlayerID,"unit",unitID)
					local titleText = getTotalText(numBets,totalScore,totalWin,betCost)
					local textWidth = glGetTextWidth(titleText)*stepSize
					local totalBgHeight = (numBets*stepSize)+stepSize
					local padding = 8
					glColor(0,0,0,0.5)
					RectRound(-padding, -padding+stepSize, textWidth+padding, totalBgHeight+padding+(stepSize*0.65)+1, padding*0.66)
					for timeSlot,betEntry in pairs(betInfo) do
						glTranslate(0,stepSize,0)
						glText(getBetLineText(betEntry), 0, 0,stepSize, "o")
					end
					glTranslate(0,stepSize+1,0)
					local betCost = getBetCost(myPlayerID,"unit",unitID)
					glText(titleText, 0, 0,stepSize, "o")
				else
					
					--glColor({1,1,0,0.4})
					--glTranslate(0,cubeShift+cubeFactor,0)
					--drawCylinder(3*cubeFactor, cubeFactor)
					
					local iconSize = 26
					local chipHeight = 8
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
				end
			glPopMatrix()
		end)
	else
		unitDisplayList[unitID] = nil
	end
end

function widget:GameFrame(n)
	if not viewBets or not betList.unit then
		return
	end
	for unitID, betInfo in pairs(betList.unit) do
		updateDisplayList(unitID,betInfo)
	end
end


function widget:DrawWorld()
	glPushMatrix()
		for _,displayList in pairs(unitDisplayList) do
			glCallList(displayList)
		end
	glPopMatrix()
end
