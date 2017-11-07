-------------------------------------------------------------------------------
--		   DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
--				   Version 2, December 2004
--
--Copyright (C) 2010 BrainDamage
--Everyone is permitted to copy and distribute verbatim or modified
--copies of this license document, and changing it is allowed as long
--as the name is changed.
--
--		   DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
--  TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
--
-- 0. You just DO WHAT THE FUCK YOU WANT TO.
-------------------------------------------------------------------------------

--[[
how the game works:
you bet as spectator the time when a player or an unit dies
your starting score is number of players -1
you can bet multiple times on the same thing, each time the cost will increase by 1
for the bet to be valid, it has to be placed at least x time before the actual death
when the player dies, the better who got closest collects the victory
the reward is equal to number of bets being made on the player
]]--

function gadget:GetInfo()
	return {
		name		= "Bet Engine",
		desc		= "Handles low level logic for spectator bets",
		author		= "BrainDamage",
		date		= "Dec,2010",
		license		= "WTFPL",
		layer		= 0,
		enabled		= true,
	}
end

local chipsOnUnitDeath = true
local chipsLifeTime = 25*20
local chipsLifeTimeVariation = 30*5
local chips = {}
local chipTerminal = {}

local simSpeed = Game.gameSpeed
local MIN_BET_TIME = 5*60*simSpeed -- frames
local MIN_BET_TIME_SCALE = 10*60*simSpeed --frames, the time of bet will be slowly increased from 0 to MIN_BET_TIME during this period
local BET_GRANULARITY = 1*60*simSpeed -- frames
local BET_COST = {team=-1,unit=-1} -- if negative, cost BET_COST*numbets, if 0 or positive it's fixed
local POINTS_PRIZE_PER_BET = {team=1,unit=1} -- negative values instead assign the bet cost times prize to the winner
local STARTING_SCORE = 7 + #Spring.GetTeamList() -1 -(Spring.GetGaiaTeamID() and 1 or 0) -- minus one to leave last "survivor" in FFA, and minus another because of gaia
local _G_INDEX = "betengine"

-- dynamic data tables, hold infos about bets, scores and other players
local playerBets = {} -- indexed by playerID: {[betType]={[betID]={{[1]=time,[2]=time}, [betID]=... }}
local playerScores = {} -- indexed by playerID: {points,currentlyRunning,won,lost,totalPlaced}
local timeBets = {} -- indexed by betType: {[betID]={[betSlot]={playerID,timestamp,betTime,betCost,betType,validFrom}, [betTime2]=..}
local betStats = {} -- indexed by betType: {[betID]={numBets,totalSpent,prizePoints}
local deadTeams = {} -- indexed by TeamID: {[teamID] = true}
local betValid = {} -- indexed by frame: {1={betType,betID,timeSlot,playerID},2=...}

local GetTeamUnitCount = Spring.GetTeamUnitCount
local GaiaTeam = Spring.GetGaiaTeamID()
local GetGameFrame = Spring.GetGameFrame
local GetPlayerInfo = Spring.GetPlayerInfo
local GetTeamInfo = Spring.GetTeamInfo
local ValidUnitID = Spring.ValidUnitID
local GetUnitIsDead = Spring.GetUnitIsDead
local SetGameRulesParam = Spring.SetGameRulesParam
local abs = math.abs
local min = math.min
local max = math.max
local floor = math.floor
local insert = table.insert

for udefID,def in ipairs(UnitDefs) do
	if def.name == 'chip' then
		chipUdefID = udefID
	end
	if def.name == 'dice' then
		diceUdefID = udefID
	end
end

function getBetCost(playerID,betType,betID)
	if not playerID or not betType or not betID then
		return
	end
	if not BET_COST[betType] then
		return
	end
	local betCount = 0
	if playerBets[playerID] and playerBets[playerID][betType] and playerBets[playerID][betType][betID] then
		betCount = #playerBets[playerID][betType][betID]
	end
	 -- with negative best costs, first bet on the same element costs abs(BET_COST), second 2*abs(BET_COST), etc
	return BET_COST[betType] >= 0 and BET_COST[betType] or (betCount+1)*abs(BET_COST[betType])
end

function isValidBet(playerID, betType, betID, betTime)
	if not playerID then
		return false, "playerID is nil"
	end
	if not betType then
		return false, "betType is nil"
	end
	if not betID then
		return false, "betID is nil"
	end
	if not betTime then
		return false, "betTime is nil"
	end
	if not tonumber(betTime) then
		return false, "betTime must be a number"
	end
	if betTime < 0 then
		return false, "betTime must be positive"
	end
	local _,betteractive,betterspectator = GetPlayerInfo(playerID)
	if betterspectator == nil then
		return false, "betting playerID (" .. playerID .. ") does not exist"
	end
	if betterspectator == false then
		return false, "only spectators can bet"
	end
	if betteractive == false then
		return false, "only active spectators can bet"
	end
	if betType == "team" then
		local _,_,deadTeam = GetTeamInfo(betID)
		if deadTeam == nil then
			return false, "betted teamID (" .. betID .. ") does not exists"
		end
		if deadTeam or deadTeams[betID] then
			return false, "cannot bet on dead teams ..(" .. betID .. ")"
		end
	elseif betType == "unit" then
		local validUnit = ValidUnitID(betID)
		if not validUnit then
			return false, "betted unitID (" .. betID .. ") does not exist"
		end
		local isDead = GetUnitIsDead(betID)
		if isDead then
			return false, "cannot bet on dead units (" .. betID ..  ")"
		end
	else
		return false, "invalid betType (" .. betType .. ")"
	end
	local playerScore = getCreatePlayerScores(playerID)
	local betCost = getBetCost(playerID,betType,betID)
	if playerScore.score-playerScore.currentlyRunning < betCost then
		return false, "not enough points to bet ( got: " ..  playerScore.score-playerScore.currentlyRunning .. " cost: " .. betCost .. " )"
	end
	-- check if there are already existing bets on the player within the same time slot
	local timeSlot = getBetTimeSlot(betTime)
	if timeBets[betType] then
		if timeBets[betType][betID] then
			if timeBets[betType][betID][timeSlot] ~= nil then
				return false, "bet time "  .. betTime .. ": slot already taken"
			end
		end
	end

	return true, ""
end

function getMinBetTimeDelta()
	--the min time of bet will be slowly increased from 0 to MIN_BET_TIME in the period from game start to MIN_BET_TIME_SCALE
	return floor(min(1,GetGameFrame()/MIN_BET_TIME_SCALE)*max(MIN_BET_TIME,0))
end

function getMinBetTime()
	return GetGameFrame() + getMinBetTimeDelta(), getMinBetTimeDelta()
end

function getBetTimeSlot(betTime)
	return floor(betTime/BET_GRANULARITY+0.5)*BET_GRANULARITY
end

function getCreatePlayerScores(playerID)
	if not playerScores[playerID] then
		playerScores[playerID] = {score=STARTING_SCORE,currentlyRunning=0,won=0,lost=0,totalPlaced=0}
	end
	return playerScores[playerID]
end

if gadgetHandler:IsSyncedCode() then




local function getCreateTimeBets(betType,betID)
	if not timeBets[betType] then
		timeBets[betType] = {}
	end
	if not timeBets[betType][betID] then
		timeBets[betType][betID] = {}
	end
	return timeBets[betType][betID]
end

local function getCreatePlayerBets(playerID,betType,betID)
	if not playerBets[playerID] then
		playerBets[playerID] = {}
	end
	if not playerBets[playerID][betType] then
		playerBets[playerID][betType] = {}
	end
	if not playerBets[playerID][betType][betID] then
		playerBets[playerID][betType][betID] = {}
	end
	return playerBets[playerID][betType][betID]
end

local function getCreateBetStats(betType,betID)
	if not betStats[betType] then
		betStats[betType] = {}
	end
	if not betStats[betType][betID] then
		betStats[betType][betID] = {numBets = 0, totalSpent = 0, prizePoints = 0}
	end
	return betStats[betType][betID]
end

local function getCreateBetValid(frame)
	if not betValid[frame] then
		betValid[frame] = {}
	end
	return betValid[frame]
end


local function placedBet(playerID, betType, betID, betTime)
	if not isValidBet(playerID, betType, betID, betTime) then
		return
	end
	local validFrom = getMinBetTime()
	-- decrement points and save infos
	local playerpersonalbets = getCreatePlayerBets(playerID,betType,betID)
	local betCost = getBetCost(playerID,betType,betID)
	local bet = getCreateTimeBets(betType,betID) -- only needed to create the table entry
	local betStat = getCreateBetStats(betType,betID)
	getCreateBetValid(validFrom)
	-- in this case the cost has same value of the next element
	playerpersonalbets[betCost] = betTime
	playerBets[playerID][betType][betID] = playerpersonalbets
	local playerScore = getCreatePlayerScores(playerID)
	playerScores[playerID].score = playerScore.score
	playerScores[playerID].totalPlaced = playerScores[playerID].totalPlaced + 1
	playerScores[playerID].currentlyRunning = playerScores[playerID].currentlyRunning + 1
	local timeSlot = getBetTimeSlot(betTime)
	timeBets[betType][betID][timeSlot] = {player=playerID, betTime = betTime, timestamp=GetGameFrame(), betCost=betCost, betType = betType, validFrom = validFrom}
	betStats[betType][betID].numBets = betStat.numBets + 1
	betStats[betType][betID].totalSpent = betStat.totalSpent + betCost
	betStats[betType][betID].prizePoints = betStat.prizePoints + (POINTS_PRIZE_PER_BET[betType] < 0 and abs(POINTS_PRIZE_PER_BET[betType])*betCost or POINTS_PRIZE_PER_BET[betType])
	insert(betValid[validFrom],{betType = betType, betID = betID, timeSlot = timeSlot, playerID = playerID})
	-- updated exported tables
	local exporttable = _G[_G_INDEX]
	exporttable.playerScores = playerScores
	exporttable.timeBets = timeBets
	exporttable.playerBets = playerBets
	exporttable.betStats = betStats
	_G[_G_INDEX] = exporttable
	-- run received bet callback
	SendToUnsynced("receivedBetCallback",playerID, betType, betID, betTime, betCost, validFrom)
end

local function betOver(betType, betID)
	if not timeBets[betType] then
		return
	end
	if not timeBets[betType][betID] then
		return
	end
	local betList = timeBets[betType][betID]
	local currentFrame = GetGameFrame()
	local minValue = nil
	local winnerID = nil
	--local prizePoints = #betList
	-- give 1 point reward for every bet to the winner
	local prizePoints = 0
	for timeSlot,betEntry in pairs(betList) do
		prizePoints = prizePoints + (POINTS_PRIZE_PER_BET[betEntry.betType] < 0 and abs(POINTS_PRIZE_PER_BET[betEntry.betType])*betEntry.betCost or POINTS_PRIZE_PER_BET[betEntry.betType])
		local validBet = currentFrame >= betEntry.validFrom and select(3,GetPlayerInfo(betEntry.player)) and select(2,GetPlayerInfo(betEntry.player))
		local deltavalue = abs(currentFrame-betEntry.betTime)
		if betValid[betEntry.validFrom] then
			--bet was not valid at gameover, it'll never be, remove from checking queue
			for toDelete,betData in pairs(betValid[betEntry.validFrom]) do
				if betData.betType == betEntry.betType and betData.betID == betEntry.betID and betData.timeSlot == timeSlot then
					betValid[betEntry.validFrom][timeSlot] = nil
					break
				end
			end
		end
		--prevent bet "sniping" ( ignore bets that were made too close to the actual death ), and player must be active and a spec
		if validBet then
			if not minValue then
				minValue = deltavalue
				winnerID = betEntry.player
			else
				if deltavalue < minValue then -- find player who got closest
					minValue = deltavalue
					winnerID = betEntry.player
				end
			end
		end
	end
	if prizePoints == 0 then
		-- no bets were made
		return
	end

	local numPlayers = 0
	for playerID, scores in pairs(playerScores) do
		-- get the amount of bets the player placed on the item
		if playerBets[playerID] then
			if playerBets[playerID][betType] then
				if playerBets[playerID][betType][betID] then
					numPlayers = numPlayers + 1
				end
			end
		end
	end
	if numPlayers > 1 then
		for playerID, scores in pairs(playerScores) do
			-- get the amount of bets the player placed on the item
			if playerBets[playerID] then
				if playerBets[playerID][betType] then
					if playerBets[playerID][betType][betID] then
						local numBets = #playerBets[playerID][betType][betID]
						if numBets > 0 then
							-- update score for the winner, set also win/loss count
							if playerID == winnerID then
								--we got a winner!
								scores.score = scores.score + prizePoints
								scores.won = scores.won + 1
								if betType == 'unit' and chipUdefID ~= nil and chipsOnUnitDeath then
									local x,y,z = Spring.GetUnitPosition(betID)
									local i = 0
									while i < prizePoints do
										Spring.CreateUnit(chipUdefID, x,y,z, 0, GaiaTeam)
										i = i + 1
									end
								end
							else
								scores.lost = scores.lost + 1
								scores.score = scores.score - numBets
							end
							scores.currentlyRunning = scores.currentlyRunning - numBets
							playerScores[playerID] = scores
						end
						--delete the bets at the same time  ( needed because unitID can be recycled )
						playerBets[playerID][betType][betID] = nil
					end
				end
			end
		end
	end

	--delete the bet infos ( needed because unitID can be recycled )
	timeBets[betType][betID] = nil
	betStats[betType][betID] = nil

	-- update shared tables
	_G[_G_INDEX].playerScores = playerScores
	_G[_G_INDEX].timeBets = timeBets
	_G[_G_INDEX].playerBets = playerBets
	_G[_G_INDEX].betStats = betStats
	-- run bet over callback
	SendToUnsynced("betOverCallback", betType, betID, winnerID, prizePoints)
end

function gadget:GameFrame(n)
	if betValid[n] then
		for _,betData in pairs(betValid[n]) do
			if betStats[betData.betType] and betStats[betData.betType][betData.betID] then
				SendToUnsynced("betValidCallback",betData.playerID, betData.betType, betData.betID, betData.timeSlot)
			end
		end
		betValid[n] = nil
	end
	if n % 30 == 1 then
		for unitID, frame in pairs(chips) do
			if frame < n then
				chips[unitID] = nil
				chipTerminal[unitID] = n+250
				local env = Spring.UnitScript.GetScriptEnv(unitID)
				Spring.UnitScript.CallAsUnit(unitID,env.Sink)
			end
		end
	end
	if n % 90 == 1 then
		for unitID, frame in pairs(chipTerminal) do
			if frame < n then
				chipTerminal[unitID] = nil
				if Spring.GetUnitIsDead(unitID) == false then
					Spring.DestroyUnit(unitID, false, false)
				end
			end
		end
	end
end

local function teamDeath(teamID)
	-- ignore gaia
	if teamID == GaiaTeam then
		return
	end
	if deadTeams[teamID] then -- don't count a dead team multiple times
		return
	end
	deadTeams[teamID] = true
	betOver("team",teamID)
end

function gadget:TeamDied(teamID)
	teamDeath(teamID)
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	betOver("unit",unitID)
	if GetTeamUnitCount(teamID) == 0 then
		teamDeath(teamID)
	end
	if unitDefID == chipUdefID then
		if chips[unitID] ~= nil then
			chips[unitID] = nil
		elseif chipTerminal[unitID] ~= nil then
			chipTerminal[unitID] = nil
		end
	end
end


function gadget:RecvLuaMsg(msg, playerID)
	if msg:match("bet %l+ %d+ %d+")then
		msg = msg:sub(#"bet "+1) -- crop the "bet " string
		-- here we receive each player's bets, including our own
		--search for betType, separated by space
		local spaceposition = msg:find(" ")
		local betType = msg:sub(1,spaceposition-1)
		msg = msg:sub(spaceposition+1)
		-- now search for betID
		spaceposition = msg:find(" ")
		local betID = tonumber(msg:sub(1,spaceposition-1))
		--rest is time
		local time = tonumber(msg:sub(spaceposition+1))
		placedBet(playerID,betType,betID,time)
		return true
	end
end

function gadget:Initialize()
	SetGameRulesParam(_G_INDEX.."MIN_BET_TIME",MIN_BET_TIME,{public=true})
	SetGameRulesParam(_G_INDEX.."MIN_BET_TIME_SCALE",MIN_BET_TIME_SCALE,{public=true})
	SetGameRulesParam(_G_INDEX.."BET_GRANULARITY",BET_GRANULARITY,{public=true})
	SetGameRulesParam(_G_INDEX.."POINTS_PRIZE_PER_BET".."unit",POINTS_PRIZE_PER_BET.unit,{public=true})
	SetGameRulesParam(_G_INDEX.."POINTS_PRIZE_PER_BET".."team",POINTS_PRIZE_PER_BET.team,{public=true})
	SetGameRulesParam(_G_INDEX.."BET_COST".."unit",BET_COST.unit,{public=true})
	SetGameRulesParam(_G_INDEX.."BET_COST".."team",BET_COST.team,{public=true})
	SetGameRulesParam(_G_INDEX.."STARTING_SCORE",STARTING_SCORE,{public=true})


	-- publish all available API functions and tables in the gadget shared table
	local exporttable = {}
	-- dynamic data tables
	exporttable.playerScores = playerScores
	exporttable.timeBets = timeBets
	exporttable.playerBets = playerBets
	exporttable.betStats = betStats

	_G[_G_INDEX] = exporttable
	GG[_G_INDEX] = exporttable
end

function gadget:Shutdown()
	_G[_G_INDEX] = nil
	GG[_G_INDEX] = nil
end


local function setGaiaUnitSpecifics(unitID)
	Spring.SetUnitNeutral(unitID, true)
	Spring.SetUnitNoSelect(unitID, true)
	Spring.SetUnitStealth(unitID, true)
	Spring.SetUnitNoMinimap(unitID, true)
	--Spring.SetUnitMaxHealth(unitID, 2)
    Spring.SetUnitBlocking(unitID, true, true, false, false, false, false, false)
	Spring.SetUnitSensorRadius(unitID, 'los', 0)
	Spring.SetUnitSensorRadius(unitID, 'airLos', 0)
	Spring.SetUnitSensorRadius(unitID, 'radar', 0)
	Spring.SetUnitSensorRadius(unitID, 'sonar', 0)
	for weaponID, _ in pairs(UnitDefs[Spring.GetUnitDefID(unitID)].weapons) do
		Spring.UnitWeaponHoldFire(unitID, weaponID)
	end
end


if chipUdefID ~= nil then
	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
		if unitDefID == chipUdefID or (diceUdefID ~= nil and unitDefID == diceUdefID) then
			chips[unitID] = Spring.GetGameFrame() + chipsLifeTime + (math.random()*chipsLifeTimeVariation)
			setGaiaUnitSpecifics(unitID)
			--local x,y,z = Spring.GetUnitPosition(unitID)
			--Spring.SetUnitPosition(unitID,x,y,z)
			--Spring.SetUnitVelocity(unitID,0,math.random()*20,0)
			Spring.SetUnitRotation(unitID,0,math.random()*360,0)
			Spring.AddUnitImpulse(unitID, (math.random()-0.5)*2.5, 4.5+(math.random()*1), (math.random()-0.5)*2.5)
		end
	end
end


else
--- BEGIN UNSYNCED CODE
	
local GetSpectatingState = Spring.GetSpectatingState
local SendLuaRulesMsg = Spring.SendLuaRulesMsg
local myPlayerID = Spring.GetMyPlayerID()
local oldspectatingstate = false

function gadget:Initialize()

	playerScores = SYNCED[_G_INDEX].playerScores
	betStats = SYNCED[_G_INDEX].betStats
	timeBets = SYNCED[_G_INDEX].timeBets
	playerBets = SYNCED[_G_INDEX].playerBets

	gadgetHandler:AddSyncAction("betOverCallback", handleBetOverCallback)
	gadgetHandler:AddSyncAction("receivedBetCallback", handleReceivedBetCallback)
	gadgetHandler:AddSyncAction("betValidCallback", handleBetValidCallback)

	gadgetHandler:AddChatAction("getminbettime", PushGetMinBetTime, nil, "t")
	gadgetHandler:AddChatAction("isvalidbet", PushIsValidBet, nil, "t")
	gadgetHandler:AddChatAction("placebet", PushPlaceBet, nil, "t")
	gadgetHandler:AddChatAction("getbetcost", PushGetBetCost, nil, "t")
	gadgetHandler:AddChatAction("getbetsstats", PushGetBetsStats, nil, "t")
	gadgetHandler:AddChatAction("getplayerscores", PushGetPlayerScores, nil, "t")
	gadgetHandler:AddChatAction("getbetlist", PushGetBetList, nil, "t")
	gadgetHandler:AddChatAction("getplayerbetlist", PushGetPlayerBetList, nil, "t")

	gadget:PlayerChanged()
end

function gadget:Shutdown()
	gadgetHandler:RemoveSyncAction("betOverCallback")
	gadgetHandler:RemoveSyncAction("receivedBetCallback")
	gadgetHandler:RemoveSyncAction("betValidCallback")

	gadgetHandler:RemoveChatAction("getminbettime")
	gadgetHandler:RemoveChatAction("isvalidbet")
	gadgetHandler:RemoveChatAction("placebet")
	gadgetHandler:RemoveChatAction("getbetcost")
	gadgetHandler:RemoveChatAction("getbetsstats")
	gadgetHandler:RemoveChatAction("getplayerscores")
	gadgetHandler:RemoveChatAction("getbetlist")
	gadgetHandler:RemoveChatAction("getplayerbetlist")
end

local function FullView()
	return select(2,GetSpectatingState())
end

function gadget:PlayerChanged()
	local newstate = GetSpectatingState()
	if newstate and oldspectatingstate ~= newstate then
		-- we just become spectators, we can be a player now!
		--refresh information
		PushGetBetsStats(_,_,_,myPlayerID)
		PushGetPlayerScores(_,_,_,myPlayerID)
		PushGetPlayerBetList(_,_,_,myPlayerID)
		PushGetBetList(_,_,_,myPlayerID)
	end
	oldspectatingstate = newstate
end


function PushGetMinBetTime(cmd,line,params,playerID)
	if playerID ~= myPlayerID then
		return
	end
	if Script.LuaUI("getMinBetTime") then
		Script.LuaUI.getMinBetTime(getMinBetTime())
	end
end

function PushIsValidBet(cmd,line,params,playerID)
	if playerID ~= myPlayerID then
		return
	end
	if Script.LuaUI("isValidBet") then
		if not FullView() then
			Script.LuaUI.isValidBet()
		else
			Script.LuaUI.isValidBet(isValidBet(tonumber(params[1]),params[2],tonumber(params[3]),tonumber(params[4])))
		end
	end
end

function PushPlaceBet(cmd,line,params,playerID)
	if playerID ~= myPlayerID then
		return
	end
	if Script.LuaUI("placeBet") then
		if not FullView() then
			Script.LuaUI.placeBet()
		else
			local ok, result = isValidBet(myPlayerID,params[1],tonumber(params[2]),tonumber(params[3]))
			if ok then
				SendLuaRulesMsg("bet " .. params[1] .. " " .. params[2] .. " " .. params[3])
				result = "Bet" .. params[1] .. "sent on " .. params[2] .. "at time " .. params[3]
			end
			Script.LuaUI.placeBet(ok,result)
		end
	end
end

function PushGetBetCost(cmd,line,params,playerID)
	if playerID ~= myPlayerID then
		return
	end
	if Script.LuaUI("getBetCost") then
		if not FullView() then
			Script.LuaUI.getBetCost()
		else
			Script.LuaUI.getBetCost(getBetCost(unpack(params)))
		end
	end
end

function PushGetBetsStats(cmd,line,params,playerID)
	if playerID ~= myPlayerID then
		return
	end
	if Script.LuaUI("getBetsStats") then
		if not FullView() then
			Script.LuaUI.getBetsStats()
		else
			Script.LuaUI.getBetsStats(betStats)
		end
	end
end


function PushGetPlayerScores(cmd,line,params,playerID)
	if playerID ~= myPlayerID then
		return
	end
	if Script.LuaUI("getPlayerScores") then
		if not FullView() then
			Script.LuaUI.getPlayerScores()
		else
			Script.LuaUI.getPlayerScores(playerScores)
		end
	end
	if Script.LuaUI("getPlayerScoresAdvplayerslist") then
		if not FullView() then
			Script.LuaUI.getPlayerScoresAdvplayerslist()
		else
			Script.LuaUI.getPlayerScoresAdvplayerslist(playerScores)
		end
	end
end

function PushGetBetList(cmd,line,params,playerID)
	if playerID ~= myPlayerID then
		return
	end
	timeBets = SYNCED[_G_INDEX].timeBets
	if Script.LuaUI("getBetList") then
		if not FullView() then
			Script.LuaUI.getBetList()
		else
			Script.LuaUI.getBetList(timeBets)
		end
	end
end

function PushGetPlayerBetList(cmd,line,params,playerID)
	if playerID ~= myPlayerID then
		return
	end
	playerBets = SYNCED[_G_INDEX].playerBets
	if Script.LuaUI("getPlayerBetList") then
		if not FullView() then
			Script.LuaUI.getPlayerBetList()
		else
			Script.LuaUI.getPlayerBetList(playerBets)
		end
	end
end


function handleBetOverCallback(_,betType, betID, winnerID, prizePoints)
	playerScores = SYNCED[_G_INDEX].playerScores
	betStats = SYNCED[_G_INDEX].betStats
	timeBets = SYNCED[_G_INDEX].timeBets
	playerBets = SYNCED[_G_INDEX].playerBets
	if not FullView() then
		return
	end
	PushGetBetsStats(_,_,_,myPlayerID)
	PushGetPlayerScores(_,_,_,myPlayerID)
	PushGetPlayerBetList(_,_,_,myPlayerID)
	PushGetBetList(_,_,_,myPlayerID)
	if Script.LuaUI("betOverCallback") then
		Script.LuaUI.betOverCallback(betType, betID, winnerID, prizePoints)
	end
end

function handleReceivedBetCallback(_,playerID, betType, betID, betAtTime, betCost, validFrom)
	playerScores = SYNCED[_G_INDEX].playerScores
	betStats = SYNCED[_G_INDEX].betStats
	timeBets = SYNCED[_G_INDEX].timeBets
	playerBets = SYNCED[_G_INDEX].playerBets
	if not FullView() then
		return
	end
	PushGetBetsStats(_,_,_,myPlayerID)
	PushGetPlayerScores(_,_,_,myPlayerID)
	PushGetPlayerBetList(_,_,_,myPlayerID)
	PushGetBetList(_,_,_,myPlayerID)
	if Script.LuaUI("receivedBetCallback") then
		Script.LuaUI.receivedBetCallback(playerID, betType, betID, betAtTime, betCost, validFrom)
	end
end

function handleBetValidCallback(_,playerID, betType, betID, timeSlot)
	if not FullView() then
		return
	end
	if Script.LuaUI("betValidCallback") then
		Script.LuaUI.betValidCallback(playerID, betType, betID, timeSlot)
	end
end

function gadget:GameStart()
	PushGetBetsStats(_,_,_,myPlayerID)
	PushGetPlayerScores(_,_,_,myPlayerID)
	PushGetPlayerBetList(_,_,_,myPlayerID)
	PushGetBetList(_,_,_,myPlayerID)
end

function gadget:GameOver()
	-- report scores to be stored in the replay
	for playerID, score in pairs(playerScores) do
		SendLuaRulesMsg("betreport: player " .. playerID .. " score " .. score.score .. " unfinished " .. score.currentlyRunning .." won " .. score.won .. " lost " .. score.lost .. " totalplaced " .. score.totalPlaced)
	end
end


end
