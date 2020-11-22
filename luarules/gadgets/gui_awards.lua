function gadget:GetInfo()
	return {
		name      = "Awards",
		desc      = "Awards Awards",
		author    = "Bluestone",
		date      = "2013-07-06",
		license   = "GPLv2",
		layer     = -1,
		enabled   = true -- loaded by default?
	}
end

local localtestDebug = false		-- when true: ends game after 30 secs
local showGraphsButton = true	-- when chobby is loaded this will be false

if gadgetHandler:IsSyncedCode() then

local spAreTeamsAllied = Spring.AreTeamsAllied

local teamInfo = {}
local coopInfo = {}
local present = {}

local playerListByTeam = {}

local isEcon = {
	--land t1
	[UnitDefNames.armsolar.id] = true,
	[UnitDefNames.corsolar.id] = true,
	[UnitDefNames.armadvsol.id] = true,
	[UnitDefNames.coradvsol.id] = true,
	[UnitDefNames.armwin.id] = true,
	[UnitDefNames.corwin.id] = true,
	[UnitDefNames.armmakr.id] = true,
	[UnitDefNames.cormakr.id] = true,
	--sea t1
	[UnitDefNames.armtide.id] = true,
	[UnitDefNames.cortide.id] = true,
	[UnitDefNames.armfmkr.id] = true,
	[UnitDefNames.corfmkr.id] = true,
	--land t2
	[UnitDefNames.armmmkr.id] = true,
	[UnitDefNames.cormmkr.id] = true,
	[UnitDefNames.corfus.id] = true,
	[UnitDefNames.armfus.id] = true,
	[UnitDefNames.armafus.id] = true,
	[UnitDefNames.corafus.id] = true,
	--sea t2
	[UnitDefNames.armuwfus.id] = true,
	[UnitDefNames.coruwfus.id] = true,
	[UnitDefNames.armuwmmm.id] = true,
	[UnitDefNames.coruwmmm.id] = true,
}
for udid, ud in pairs(UnitDefs) do
	for id, v in pairs(isEcon) do
		if string.find(ud.name, UnitDefs[id].name) then
			isEcon[udid] = v
		end
	end
end

local unitNumWeapons = {}
local unitCombinedCost = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if #unitDef.weapons > 0 then
		unitNumWeapons[unitDefID] = #unitDef.weapons
	end
	unitCombinedCost[unitDefID] = unitDef.energyCost + (60 * unitDef.metalCost)
end

function gadget:Initialize()
    -- helpful for debugging/testing
	local teamList = Spring.GetTeamList()
	for _,teamID in pairs(teamList) do
		local playerList = Spring.GetPlayerList(teamID)
		local list = {} --without specs
		for _,playerID in pairs(playerList) do
			local name, _, isSpec = Spring.GetPlayerInfo(playerID,false)
			if not isSpec then
				table.insert(list, name)
			end
		end
		playerListByTeam[teamID] = list
	end
end


-----------------------------------
-- set up book keeping
-----------------------------------

function gadget:GameStart()
	--make table of teams eligible for awards
	local allyTeamIDs = Spring.GetAllyTeamList()
	local gaiaTeamID = Spring.GetGaiaTeamID()
	for i=1,#allyTeamIDs do
		local teamIDs = Spring.GetTeamList(allyTeamIDs[i])
		for j=1,#teamIDs do
			local isLuaAI = (Spring.GetTeamLuaAI(teamIDs[j]) ~= "")
			local isGaiaTeam = (teamIDs[j] == gaiaTeamID)
			if ((not select(4,Spring.GetTeamInfo(teamIDs[j],false))) and (not isLuaAi) and (not isGaiaTeam)) then
				local playerIDs = Spring.GetPlayerList(teamIDs[j])
				local numPlayers = 0
				for _,playerID in pairs(playerIDs) do
					if not select(3,Spring.GetPlayerInfo(playerID,false)) then
						numPlayers = numPlayers + 1
					end
				end

				if numPlayers > 0 then
					present[teamIDs[j]] = true
					teamInfo[teamIDs[j]] = {allDmg=0, ecoDmg=0, fightDmg=0, otherDmg=0, dmgDealt=0, ecoUsed=0, effScore=0, ecoProd=0, lastKill=0, dmgRec=0, sleepTime=0, present=true, teamDmg = 0,}
					coopInfo[teamIDs[j]] = {players=numPlayers,}
				else
					present[teamIDs[j]] = false
				end
			else
				present[teamIDs[j]] = false
			end
		end
	end
end

-----------------------------------
-- track kill damages (measure by cost of killed unit)
-----------------------------------

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	-- add destroyed unitID cost to stats for attackerTeamID
	if not attackerTeamID then return end
	if attackerTeamID == gaiaTeamID then return end
	if not present[attackerTeamID] then return end
	if not unitDefID or not teamID then return end
	if spAreTeamsAllied(teamID, attackerTeamID) then
		if teamID ~= attackerTeamID then
			local curTime = Spring.GetGameSeconds()
			--keep track of teamkilling
			teamInfo[attackerTeamID].teamDmg = teamInfo[attackerTeamID].teamDmg + unitCombinedCost[unitDefID]
		end
		return
	end

	--keep track of who didn't kill for longest (sleeptimes)
	local curTime = Spring.GetGameSeconds()
	if (curTime - teamInfo[attackerTeamID].lastKill > teamInfo[attackerTeamID].sleepTime) then
		teamInfo[attackerTeamID].sleepTime = curTime - teamInfo[attackerTeamID].lastKill
	end
	teamInfo[attackerTeamID].lastKill = curTime

	local cost = unitCombinedCost[unitDefID]

	--keep track of killing
	teamInfo[attackerTeamID].allDmg = teamInfo[attackerTeamID].allDmg + cost
	if unitNumWeapons[unitDefID] then
		teamInfo[attackerTeamID].fightDmg = teamInfo[attackerTeamID].fightDmg + cost
	elseif isEcon[unitDefID] then
		teamInfo[attackerTeamID].ecoDmg = teamInfo[attackerTeamID].ecoDmg + cost
	else
		teamInfo[attackerTeamID].otherDmg = teamInfo[attackerTeamID].otherDmg + cost --currently not using this but recording it for interest
	end

	--Spring.Echo(teamInfo[attackerTeamID].fightDmg, teamInfo[attackerTeamID].ecoDmg, teamInfo[attackerTeamID].otherDmg)
end

---------------------------------
-- for debugging/testing
--[[
function FindPlayerName(teamID)
    local plList = playerListByTeam[teamID]
	local name
	if plList[1] then
		name = plList[1]
		if #plList > 1 then
			name = name .. " (coop)"
		end
	else
		name = "(unknown)"
	end
	return name
end
local effSampleRate = 15
function gadget:GameFrame(n)
    if n%(30*effSampleRate)~=0 or n==0 then return end
     	local topScore = -1
    local topTeam = 0
    local nDmg = 0
    local nTeams = 0
    for teamID,_ in pairs(teamInfo) do
        local eff = CalculateEfficiency(teamID)
        if eff > topScore then
            topScore = eff
            topTeam = teamID
        end
        nDmg = nDmg + teamInfo[teamID].allDmg
        nTeams = nTeams + 1
    end
    Spring.Echo("> most eff: " .. FindPlayerName(topTeam) .. ", score " .. topScore, "nTeamDmg = " .. nDmg/nTeams)
    if localtestDebug and n==900 then
        Spring.GameOver({1,0})
    end
end
]]

-----------------------------------
-- work out who wins the awards
-----------------------------------

function CalculateEfficiency(teamID)
   	--calculate total damage dealt and unitsDeadCost
	local totalDmg = 1 -- minor hack, avoid div0
    local totalEco = 1
    local nTeams = 0
	for tID,_ in pairs(teamInfo) do
		local cur_max = Spring.GetTeamStatsHistory(tID)
		local stats = Spring.GetTeamStatsHistory(tID, cur_max, cur_max)
		totalDmg = totalDmg + teamInfo[tID].allDmg
		totalEco = totalEco + stats[1].energyUsed + 60 * stats[1].metalUsed -- don't count excessed & reclaimed res
        nTeams = nTeams + 1
    end

    -- calculate efficiency score
    local cur_max = Spring.GetTeamStatsHistory(teamID)
    local stats = Spring.GetTeamStatsHistory(teamID, cur_max, cur_max)
	local teamEco = stats[1].energyProduced + 60 * stats[1].metalProduced -- do count excessed & reclaimed res
    local pEco = teamEco / totalEco -- [0,1]
    local pDmg = teamInfo[teamID].allDmg / totalDmg -- [0,infty), due to m/e excessed, but typically [0,1]
    local effScore = nTeams * (pDmg - pEco)

    --Spring.Echo("eff: scores " .. effScore, pDmg, pEco, " for " .. FindPlayerName(teamID))
    return effScore
end


function gadget:GameOver(winningAllyTeams)

    --get stuff from engine stats (not all of which is currently used)
	for teamID,_ in pairs(teamInfo) do
		local cur_max = Spring.GetTeamStatsHistory(teamID)
		local stats = Spring.GetTeamStatsHistory(teamID, cur_max, cur_max)
		teamInfo[teamID].ecoUsed = teamInfo[teamID].ecoUsed + stats[1].energyUsed + 60 * stats[1].metalUsed -- might already be non-zero due to accounting in UnitTaken
		teamInfo[teamID].ecoProd = stats[1].energyProduced + 60 * stats[1].metalProduced
		teamInfo[teamID].dmgDealt = stats[1].damageDealt
		teamInfo[teamID].dmgRec = stats[1].damageReceived
	end

	--take account of coop, calculate total damage and nTeams
    local nDmg = 1
    local nTeams = 0
	for teamID,_ in pairs(teamInfo) do
		teamInfo[teamID].allDmg = teamInfo[teamID].allDmg / coopInfo[teamID].players
		teamInfo[teamID].ecoDmg = teamInfo[teamID].ecoDmg / coopInfo[teamID].players
		teamInfo[teamID].fightDmg = teamInfo[teamID].fightDmg / coopInfo[teamID].players
		teamInfo[teamID].otherDmg = teamInfo[teamID].otherDmg / coopInfo[teamID].players
		teamInfo[teamID].dmgRec = teamInfo[teamID].dmgRec / coopInfo[teamID].players

        nDmg = nDmg + teamInfo[teamID].allDmg
        nTeams = nTeams + 1
    end

    -- calculate efficiencies
	for teamID,_ in pairs(teamInfo) do
        local eff = CalculateEfficiency(teamID)
        if nDmg > 7500 * nTeams  then
            teamInfo[teamID].effScore = eff
        else
            teamInfo[teamID].effScore = -1
        end
    end

	--award awards
	local ecoKillAward, ecoKillAwardSec, ecoKillAwardThi, ecoKillScore, ecoKillScoreSec, ecoKillScoreThi = -1,-1,-1,0,0,0
	local fightKillAward, fightKillAwardSec, fightKillAwardThi, fightKillScore, fightKillScoreSec, fightKillScoreThi = -1,-1,-1,0,0,0
	local effKillAward, effKillAwardSec, effKillAwardThi, effKillScore, effKillScoreSec, effKillScoreThi = -1,-1,-1,0,0,0
	local ecoAward, ecoScore = -1,0
	local dmgRecAward, dmgRecScore = -1,0
	local sleepAward, sleepScore = -1,0
	local traitorAward, traitorAwardSec, traitorAwardThi, traitorScore, traitorScoreSec, traitorScoreThi = -1,-1,-1,0,0,0
	for teamID,_ in pairs(teamInfo) do
		--deal with sleep times
		local curTime = Spring.GetGameSeconds()
		if (curTime - teamInfo[teamID].lastKill > teamInfo[teamID].sleepTime) then
			teamInfo[teamID].sleepTime = curTime - teamInfo[teamID].lastKill
		end
		--eco killing award
		if ecoKillScore < teamInfo[teamID].ecoDmg then
			ecoKillScoreThi = ecoKillScoreSec
			ecoKillAwardThi = ecoKillAwardSec
			ecoKillScoreSec = ecoKillScore
			ecoKillAwardSec = ecoKillAward
			ecoKillScore = teamInfo[teamID].ecoDmg
			ecoKillAward = teamID
		elseif ecoKillScoreSec < teamInfo[teamID].ecoDmg then
			ecoKillScoreThi = ecoKillScoreSec
			ecoKillAwardThi = ecoKillAwardSec
			ecoKillScoreSec = teamInfo[teamID].ecoDmg
			ecoKillAwardSec = teamID
		elseif ecoKillScoreThi < teamInfo[teamID].ecoDmg then
			ecoKillScoreThi = teamInfo[teamID].ecoDmg
			ecoKillAwardThi = teamID
		end
		--fight killing award
		if fightKillScore < teamInfo[teamID].fightDmg then
			fightKillScoreThi = fightKillScoreSec
			fightKillAwardThi = fightKillAwardSec
			fightKillScoreSec = fightKillScore
			fightKillAwardSec = fightKillAward
			fightKillScore = teamInfo[teamID].fightDmg
			fightKillAward = teamID
		elseif fightKillScoreSec < teamInfo[teamID].fightDmg then
			fightKillScoreThi = fightKillScoreSec
			fightKillAwardThi = fightKillAwardSec
			fightKillScoreSec = teamInfo[teamID].fightDmg
			fightKillAwardSec = teamID
		elseif fightKillScoreThi < teamInfo[teamID].fightDmg then
			fightKillScoreThi = teamInfo[teamID].fightDmg
			fightKillAwardThi = teamID
		end
		--efficiency ratio award
		if effKillScore < teamInfo[teamID].effScore then
			effKillScoreThi = effKillScoreSec
			effKillAwardThi = effKillAwardSec
			effKillScoreSec = effKillScore
			effKillAwardSec = effKillAward
			effKillScore = teamInfo[teamID].effScore
			effKillAward = teamID
		elseif effKillScoreSec < teamInfo[teamID].effScore then
			effKillScoreThi = effKillScoreSec
			effKillAwardThi = effKillAwardSec
			effKillScoreSec = teamInfo[teamID].effScore
			effKillAwardSec = teamID
		elseif effKillScoreThi < teamInfo[teamID].effScore then
			effKillScoreThi = teamInfo[teamID].effScore
			effKillAwardThi = teamID
		end

		--eco prod award
		if ecoScore < teamInfo[teamID].ecoProd then
			ecoScore = teamInfo[teamID].ecoProd
			ecoAward = teamID
		end
		--most damage rec award
		if dmgRecScore < teamInfo[teamID].dmgRec then
			dmgRecScore = teamInfo[teamID].dmgRec
			dmgRecAward = teamID
		end
		--longest sleeper award
		if sleepScore < teamInfo[teamID].sleepTime and teamInfo[teamID].sleepTime > 12*60 then
			sleepScore = teamInfo[teamID].sleepTime
			sleepAward = teamID
		end
		--traitor award
		if traitorScore < teamInfo[teamID].teamDmg then
			traitorScoreThi = traitorScoreSec
			traitorAwardThi = traitorAwardSec
			traitorScoreSec = traitorScore
			traitorAwardSec = traitorAward
			traitorScore = teamInfo[teamID].teamDmg
			traitorAward = teamID
		elseif traitorScoreSec < teamInfo[teamID].teamDmg then
			traitorScoreThi = traitorScoreSec
			traitorAwardThi = traitorAwardSec
			traitorScoreSec = teamInfo[teamID].teamDmg
			traitorAwardSec = teamID
		elseif traitorScoreThi < teamInfo[teamID].teamDmg then
			traitorScoreThi = teamInfo[teamID].teamDmg
			traitorAwardThi = teamID
		end
	end

	--is the cow awarded?
	local cowAward = -1
	if ecoKillAward ~= -1 and (ecoKillAward == fightKillAward) and (fightKillAward == effKillAward) and ecoKillAward ~= -1 and nTeams > 3 then --check if some team got all the awards + if more than 3 teams in the game
		if winningAllyTeams and winningAllyTeams[1] then
			local won = false
			local _,_,_,_,_,cowAllyTeamID = Spring.GetTeamInfo(ecoKillAward,false)
			for _,allyTeamID in pairs(winningAllyTeams) do
				if cowAllyTeamID == allyTeamID then --check if this team won the game
					cowAward = ecoKillAward
					break
				end
			end
		end
	end

	local bettingWinners = ''
	local bettingScore = 0
	local bettingParticipants = 0
	if GG['betengine'] ~= nil and GG['betengine'].playerScores ~= nil then
		for playerID, info in pairs(GG['betengine'].playerScores) do
			bettingParticipants = bettingParticipants + 1
			if info.won > 0 then
				local playerName, _, isSpec = Spring.GetPlayerInfo(playerID,false)
				if info.score > bettingScore then
					bettingScore = info.score
					bettingWinners = playerName
				elseif info.score == bettingScore then
					bettingWinners = bettingWinners .. ', ' .. playerName
				end
			end
		end
		if bettingParticipants <= 1 and not localtestDebug then
			bettingWinners = ''
		end
	end

	--tell unsynced
	SendToUnsynced("ReceiveAwards", ecoKillAward, ecoKillAwardSec, ecoKillAwardThi, ecoKillScore, ecoKillScoreSec, ecoKillScoreThi,
									fightKillAward, fightKillAwardSec, fightKillAwardThi, fightKillScore, fightKillScoreSec, fightKillScoreThi,
									effKillAward, effKillAwardSec, effKillAwardThi, effKillScore, effKillScoreSec, effKillScoreThi,
									ecoAward, ecoScore,
									dmgRecAward, dmgRecScore,
									sleepAward, sleepScore,
									cowAward,
									bettingWinners, bettingScore, bettingParticipants,
									traitorAward, traitorAwardSec, traitorAwardThi, traitorScore, traitorScoreSec, traitorScoreThi)

end


-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
else  -- UNSYNCED
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glBeginEnd = gl.BeginEnd
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glColor = gl.Color
local glScale = gl.Scale
local glVertex = gl.Vertex
local glRect = gl.Rect
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local GL_LINE_LOOP = GL.LINE_LOOP
local glText = gl.Text


local widgetScale = 1

local drawAwards = false
local cx,cy --coords for center of screen
local bx,by,bxScaled,byScaled --coords for top left hand corner of box
local w = 800
local h = 500
local bgMargin = 6

--h = 520-bgMargin-bgMargin
--w = 1050-bgMargin-bgMargin

local Background
local FirstAward
local SecondAward
local ThirdAward
local FourthAward
local threshold = 150000
local CowAward
local OtherAwards

local red = "\255"..string.char(171)..string.char(51)..string.char(51)
local blue = "\255"..string.char(51)..string.char(51)..string.char(151)
local green = "\255"..string.char(51)..string.char(151)..string.char(51)
local white = "\255"..string.char(251)..string.char(251)..string.char(251)
local yellow = "\255"..string.char(251)..string.char(251)..string.char(11)

local playerListByTeam = {} --does not contain specs
local myPlayerID = Spring.GetMyPlayerID()

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local vsx,vsy = Spring.GetViewGeometry()
local fontfileScale = (0.7 + (vsx*vsy / 7000000))
local fontfileSize = 40
local fontfileOutlineSize = 8
local fontfileOutlineStrength = 1.45
local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local font2 = gl.LoadFont(fontfile2, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)

function gadget:ViewResize(viewSizeX, viewSizeY)
	vsx,vsy = Spring.GetViewGeometry()
	local newFontfileScale = (0.5 + (vsx*vsy / 5700000))
	if (fontfileScale ~= newFontfileScale) then
		fontfileScale = newFontfileScale
		gl.DeleteFont(font)
		font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
		gl.DeleteFont(font2)
		font2 = gl.LoadFont(fontfile2, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
	end
	--fix geometry
	widgetScale = (0.75 + (vsx*vsy / 7500000))
	cx = vsx/2
	cy = vsy/2
	bx = cx - w/2
	by = cy - h/2 - 50
	bxScaled = cx - (w*widgetScale)/2
	byScaled = cy - (h*widgetScale)/2 - (50*widgetScale)
	--CreateBackground()
	--drawAwards = true
end

local chobbyLoaded = false
if Spring.GetMenuName and string.find(string.lower(Spring.GetMenuName()), 'chobby') ~= nil then
	chobbyLoaded = true
	showGraphsButton = false	-- false -> Close button
end

function gadget:Initialize()
	if chobbyLoaded then
		Spring.SendCommands('endgraph 0')
	end

	gadget:ViewResize()
	--register actions to SendToUnsynced messages
	gadgetHandler:AddSyncAction("ReceiveAwards", ProcessAwards)

	--for testing
	--FirstAward = CreateAward('fuscup',0,'Destroying enemy resource production', white, 1,1,1,24378,1324,132,100)
	--SecondAward = CreateAward('bullcup',0,'Destroying enemy units and defences',white, 1,1,1,24378,1324,132,200)
	--ThirdAward = CreateAward('comwreath',0,'Effective use of resources',white,1,1,1,24378,1324,132,300)
	--CowAward = CreateAward('cow',1,'Doing everything',white,1,1,1,24378,1324,132,400)
	--OtherAwards = CreateAward('',2,'',white,1,1,1,3,100,1000,400)

	--load a list of players for each team into playerListByTeam
	local teamList = Spring.GetTeamList()
	for _,teamID in pairs(teamList) do
		local playerList = Spring.GetPlayerList(teamID)
		local list = {} --without specs
		for _,playerID in pairs(playerList) do
			local name, _, isSpec = Spring.GetPlayerInfo(playerID,false)
			if not isSpec then
				table.insert(list, name)
			end
		end
		playerListByTeam[teamID] = list
	end
end

function ProcessAwards(_,ecoKillAward, ecoKillAwardSec, ecoKillAwardThi, ecoKillScore, ecoKillScoreSec, ecoKillScoreThi,
						fightKillAward, fightKillAwardSec, fightKillAwardThi, fightKillScore, fightKillScoreSec, fightKillScoreThi,
						effKillAward, effKillAwardSec, effKillAwardThi, effKillScore, effKillScoreSec, effKillScoreThi,
						ecoAward, ecoScore,
						dmgRecAward, dmgRecScore,
						sleepAward, sleepScore,
						cowAward,
						bettingWinners, bettingScore, bettingParticipants,
						traitorAward, traitorAwardSec, traitorAwardThi, traitorScore, traitorScoreSec, traitorScoreThi)

	bettingScores = {bettingWinners, bettingScore, bettingParticipants}

    --record who won which awards in chat message (for demo parsing by replays.springrts.com)
	--make all values positive, as unsigned ints are easier to parse
	local ecoKillLine    = '\161' .. tostring(1+ecoKillAward) .. ':' .. tostring(ecoKillScore) .. '\161' .. tostring(1+ecoKillAwardSec) .. ':' .. tostring(ecoKillScoreSec) .. '\161' .. tostring(1+ecoKillAwardThi) .. ':' .. tostring(ecoKillScoreThi)
	local fightKillLine  = '\162' .. tostring(1+fightKillAward) .. ':' .. tostring(fightKillScore) .. '\162' .. tostring(1+fightKillAwardSec) .. ':' .. tostring(fightKillScoreSec) .. '\162' .. tostring(1+fightKillAwardThi) .. ':' .. tostring(fightKillScoreThi)
	local effKillLine    = '\163' .. tostring(1+effKillAward) ..  ':' .. tostring(effKillScore) .. '\163' .. tostring(1+effKillAwardSec) .. ':' .. tostring(effKillScoreSec) .. '\163' .. tostring(1+effKillAwardThi) .. ':' .. tostring(effKillScoreThi)
	local otherLine      = '\164' .. tostring(1+cowAward) .. '\165' ..  tostring(1+ecoAward) .. ':' .. tostring(ecoScore).. '\166' .. tostring(1+dmgRecAward) .. ':' .. tostring(dmgRecScore) ..'\167' .. tostring(1+sleepAward) .. ':' .. tostring(sleepScore)
	local awardsMsg = ecoKillLine .. fightKillLine .. effKillLine .. otherLine
	Spring.SendLuaRulesMsg(awardsMsg)

	--create awards
	addy = 0
	if traitorScore > threshold then
		addy = 100
		h = 600
	end
	CreateBackground()
	FirstAward = CreateAward('fuscup',0,'Destroying enemy resource production', white, ecoKillAward, ecoKillAwardSec, ecoKillAwardThi, ecoKillScore, ecoKillScoreSec, ecoKillScoreThi, 100)
	SecondAward = CreateAward('bullcup',0,'Destroying enemy units and defences',white, fightKillAward, fightKillAwardSec, fightKillAwardThi, fightKillScore, fightKillScoreSec, fightKillScoreThi, 200)
	ThirdAward = CreateAward('comwreath',0,'Efficient use of resources',white,effKillAward, effKillAwardSec, effKillAwardThi, effKillScore, effKillScoreSec, effKillScoreThi, 300)
	if cowAward ~= -1 then
		CowAward = CreateAward('cow',1,'Doing everything',white, ecoKillAward, 1,1,1,1,1, 400 + addy)
	else
		OtherAwards = CreateAward('',2,'',white, ecoAward, dmgRecAward, sleepAward, ecoScore, dmgRecScore, sleepScore, 400 + addy)
	end
	if traitorScore > threshold then
		FourthAward = CreateAward('traitor',0,'The Traitor - Destroying allied units',white, traitorAward, traitorAwardSec, traitorAwardThi, traitorScore, traitorScoreSec, traitorScoreThi, 400)
	end
	drawAwards = true

	--don't show graph
	Spring.SendCommands('endgraph 0')
end



local function DrawRectRound(px,py,sx,sy,cs, tl,tr,br,bl, c1,c2)
	local csyMult = 1 / ((sy-py)/cs)

	if c2 then
		gl.Color(c1[1],c1[2],c1[3],c1[4])
	end
	gl.Vertex(px+cs, py, 0)
	gl.Vertex(sx-cs, py, 0)
	if c2 then
		gl.Color(c2[1],c2[2],c2[3],c2[4])
	end
	gl.Vertex(sx-cs, sy, 0)
	gl.Vertex(px+cs, sy, 0)

	-- left side
	if c2 then
		gl.Color(c1[1]*(1-csyMult)+(c2[1]*csyMult),c1[2]*(1-csyMult)+(c2[2]*csyMult),c1[3]*(1-csyMult)+(c2[3]*csyMult),c1[4]*(1-csyMult)+(c2[4]*csyMult))
	end
	gl.Vertex(px, py+cs, 0)
	gl.Vertex(px+cs, py+cs, 0)
	if c2 then
		gl.Color(c2[1]*(1-csyMult)+(c1[1]*csyMult),c2[2]*(1-csyMult)+(c1[2]*csyMult),c2[3]*(1-csyMult)+(c1[3]*csyMult),c2[4]*(1-csyMult)+(c1[4]*csyMult))
	end
	gl.Vertex(px+cs, sy-cs, 0)
	gl.Vertex(px, sy-cs, 0)

	-- right side
	if c2 then
		gl.Color(c1[1]*(1-csyMult)+(c2[1]*csyMult),c1[2]*(1-csyMult)+(c2[2]*csyMult),c1[3]*(1-csyMult)+(c2[3]*csyMult),c1[4]*(1-csyMult)+(c2[4]*csyMult))
	end
	gl.Vertex(sx, py+cs, 0)
	gl.Vertex(sx-cs, py+cs, 0)
	if c2 then
		gl.Color(c2[1]*(1-csyMult)+(c1[1]*csyMult),c2[2]*(1-csyMult)+(c1[2]*csyMult),c2[3]*(1-csyMult)+(c1[3]*csyMult),c2[4]*(1-csyMult)+(c1[4]*csyMult))
	end
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.Vertex(sx, sy-cs, 0)

	local offset = 0.15		-- texture offset, because else gaps could show

	-- bottom left
	if c2 then
		gl.Color(c1[1],c1[2],c1[3],c1[4])
	end
	if ((py <= 0 or px <= 0)  or (bl ~= nil and bl == 0)) and bl ~= 2   then
		gl.Vertex(px, py, 0)
	else
		gl.Vertex(px+cs, py, 0)
	end
	gl.Vertex(px+cs, py, 0)
	if c2 then
		gl.Color(c1[1]*(1-csyMult)+(c2[1]*csyMult),c1[2]*(1-csyMult)+(c2[2]*csyMult),c1[3]*(1-csyMult)+(c2[3]*csyMult),c1[4]*(1-csyMult)+(c2[4]*csyMult))
	end
	gl.Vertex(px+cs, py+cs, 0)
	gl.Vertex(px, py+cs, 0)
	-- bottom right
	if c2 then
		gl.Color(c1[1],c1[2],c1[3],c1[4])
	end
	if ((py <= 0 or sx >= vsx) or (br ~= nil and br == 0)) and br ~= 2 then
		gl.Vertex(sx, py, 0)
	else
		gl.Vertex(sx-cs, py, 0)
	end
	gl.Vertex(sx-cs, py, 0)
	if c2 then
		gl.Color(c1[1]*(1-csyMult)+(c2[1]*csyMult),c1[2]*(1-csyMult)+(c2[2]*csyMult),c1[3]*(1-csyMult)+(c2[3]*csyMult),c1[4]*(1-csyMult)+(c2[4]*csyMult))
	end
	gl.Vertex(sx-cs, py+cs, 0)
	gl.Vertex(sx, py+cs, 0)
	-- top left
	if c2 then
		gl.Color(c2[1],c2[2],c2[3],c2[4])
	end
	if ((sy >= vsy or px <= 0) or (tl ~= nil and tl == 0)) and tl ~= 2 then
		gl.Vertex(px, sy, 0)
	else
		gl.Vertex(px+cs, sy, 0)
	end
	gl.Vertex(px+cs, sy, 0)
	if c2 then
		gl.Color(c2[1]*(1-csyMult)+(c1[1]*csyMult),c2[2]*(1-csyMult)+(c1[2]*csyMult),c2[3]*(1-csyMult)+(c1[3]*csyMult),c2[4]*(1-csyMult)+(c1[4]*csyMult))
	end
	gl.Vertex(px+cs, sy-cs, 0)
	gl.Vertex(px, sy-cs, 0)
	-- top right
	if c2 then
		gl.Color(c2[1],c2[2],c2[3],c2[4])
	end
	if ((sy >= vsy or sx >= vsx)  or (tr ~= nil and tr == 0)) and tr ~= 2 then
		gl.Vertex(sx, sy, 0)
	else
		gl.Vertex(sx-cs, sy, 0)
	end
	gl.Vertex(sx-cs, sy, 0)
	if c2 then
		gl.Color(c2[1]*(1-csyMult)+(c1[1]*csyMult),c2[2]*(1-csyMult)+(c1[2]*csyMult),c2[3]*(1-csyMult)+(c1[3]*csyMult),c2[4]*(1-csyMult)+(c1[4]*csyMult))
	end
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.Vertex(sx, sy-cs, 0)
end
function RectRound(px,py,sx,sy,cs, tl,tr,br,bl, c1,c2)		-- (coordinates work differently than the RectRound func in other widgets)
	gl.Texture(false)
	gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs, tl,tr,br,bl, c1,c2)
end


function CreateBackground()
	if Background then
		glDeleteList(Background)
	end
	if Script.LuaUI("GuishaderInsertRect") then
		Script.LuaUI.GuishaderInsertRect(math.floor(bxScaled), math.floor(byScaled), math.floor(bxScaled + (w*widgetScale)), math.floor(byScaled + (h*widgetScale)), 'awards')
	end

	Background = glCreateList(function()
		-- background
		gl.Color(0,0,0,0.8)
		RectRound(bx-bgMargin, by-bgMargin, bx + w+bgMargin, by + h+bgMargin, 8, 1,1,1,1, {0.05,0.05,0.05,0.85}, {0,0,0,0.85})
		-- content area
		gl.Color(0.33,0.33,0.33,0.15)
		RectRound(bx, by, bx + w, by + h, 6, 1,1,1,1, {0.25,0.25,0.25,0.2}, {0.5,0.5,0.5,0.2})

		glColor(1,1,1,1)
		glTexture(':l:LuaRules/Images/awards.png')
		glTexRect(bx + w/2 - 220, by + h - 75, bx + w/2 + 120, by + h - 5)

		font:Begin()
		font:Print('Score', bx + w/2 + 275, by + h - 65, 15, "o")
		font:End()
	end)
end

function colourNames(teamID)
		if teamID < 0 then return "" end
    	nameColourR,nameColourG,nameColourB,nameColourA = Spring.GetTeamColor(teamID)
		R255 = math.floor(nameColourR*255)  --the first \255 is just a tag (not colour setting) no part can end with a zero due to engine limitation (C)
        G255 = math.floor(nameColourG*255)
        B255 = math.floor(nameColourB*255)
        if ( R255%10 == 0) then
                R255 = R255+1
        end
        if( G255%10 == 0) then
                G255 = G255+1
        end
        if ( B255%10 == 0) then
                B255 = B255+1
        end
	return "\255"..string.char(R255)..string.char(G255)..string.char(B255) --works thanks to zwzsg
end

function round(num, idp)
  return string.format("%." .. (idp or 0) .. "f", num)
end


function FindPlayerName(teamID)
	local plList = playerListByTeam[teamID]
	local name
	if plList[1] then
		name = plList[1]
		if #plList > 1 then
			name = name .. " (coop)"
		end
	else
		name = "(unknown)"
	end

	return name
end

function CreateAward(pic, award, note, noteColour, winnerID, secondID, thirdID, winnerScore, secondScore, thirdScore, offset)
	local winnerName, secondName, thirdName

	--award is: 0 for a normal award, 1 for the cow award, 2 for the no-cow awards

	if winnerID >= 0 then
		winnerName = FindPlayerName(winnerID)
	else
		winnerName = "(not awarded)"
	end

	if secondID >= 0 then
		secondName = FindPlayerName(secondID)
	else
		secondName = "(not awarded)"
	end

	if thirdID >= 0 then
		thirdName = FindPlayerName(thirdID)
	else
		thirdName = "(not awarded)"
	end

	thisAward = glCreateList(function()

		font:Begin()
		--names
		if award ~= 2 then	--if its a normal award or a cow award
			glColor(1,1,1,1)
			local pic = ':l:LuaRules/Images/' .. pic ..'.png'
			glTexture(pic)
			glTexRect(bx + 12, by + h - offset - 70, bx + 108, by + h - offset + 25)

			font:Print(colourNames(winnerID) .. winnerName, bx + 120, by + h - offset - 10, 20, "o")
			font:Print(noteColour .. note, bx + 120, by + h - offset - 50, 16, "o")
		else --if the cow is not awarded, we replace it with minor awards (just text)
			local heightoffset = 0
			if winnerID >=0 then
				font:Print(colourNames(winnerID) .. winnerName .. white .. ' produced the most resources (' .. math.floor(winnerScore) .. ').', bx + 70, by + h - offset - 10 - heightoffset, 14, "o")
				heightoffset = heightoffset + 17
			end
			if secondID >= 0 then
				font:Print(colourNames(secondID) .. secondName .. white .. ' took the most damage (' .. math.floor(secondScore) .. ').', bx + 70, by + h - offset - 10 - heightoffset, 14, "o")
				heightoffset = heightoffset + 17
			end
			if thirdID >= 0 then
				font:Print(colourNames(thirdID) .. thirdName .. white .. ' slept longest, for ' .. math.floor(thirdScore/60) .. ' minutes.', bx + 70, by + h - offset - 10 - heightoffset, 14, "o")
			end
		end

		--scores
		if award == 0 then --normal awards
			if winnerID >= 0 then
				if pic == 'comwreath' then winnerScore = round(winnerScore, 2) else winnerScore = math.floor(winnerScore) end
				font:Print(colourNames(winnerID) .. winnerScore, bx + w/2 + 275, by + h - offset - 5, 14, "o")
			else
				font:Print('-', bx + w/2 + 275, by + h - offset - 5, 17, "o")
			end
			font:Print('Runners up:', bx + 500, by + h - offset - 5, 14, "o")

			if secondScore > 0 then
				if pic == 'comwreath' then secondScore = round(secondScore, 2) else secondScore = math.floor(secondScore) end
				font:Print(colourNames(secondID) .. secondName, bx + 520, by + h - offset - 25, 14, "o")
				font:Print(colourNames(secondID) .. secondScore, bx + w/2 + 275, by + h - offset - 25, 14, "o")
			end

			if thirdScore > 0 then
				if pic == 'comwreath' then thirdScore = round(thirdScore, 2) else thirdscore = math.floor (thirdScore) end
				font:Print(colourNames(thirdID) .. thirdName, bx + 520, by + h - offset - 45, 14, "o")
				font:Print(colourNames(thirdID) .. thirdScore, bx + w/2 + 275, by + h - offset - 45, 14, "o")
			end
		end
		font:End()

	end)

	return thisAward
end



local quitX = 100
local graphsX = 250

function gadget:MousePress(x,y,button)
	if drawAwards then
		if button ~= 1 then return end
		x,y = correctMouseForScaling(x,y)
		if chobbyLoaded then
			if (x > bx+w-quitX-5) and (x < bx+w-quitX+20*font:GetTextWidth('Leave')+5) and (y>by+50-5) and (y<by+50+16+5) then --leave button
				Spring.Reload("")
			end
		else
			if (x > bx+w-quitX-5) and (x < bx+w-quitX+20*font:GetTextWidth('Quit')+5) and (y>by+50-5) and (y<by+50+16+5) then --quit button
				Spring.SendCommands("quitforce")
			end
		end
		if (x > bx+w-graphsX-5) and (x < bx+w-graphsX+20*font:GetTextWidth((showGraphsButton and 'Show Graphs' or 'Close'))+5) and (y>by+50-5) and (y<by+50+16+5) then
			if showGraphsButton then
				Spring.SendCommands('endgraph 1')
			end
			if Script.LuaUI("GuishaderRemoveRect") then
				Script.LuaUI.GuishaderRemoveRect('awards')
			end
			drawAwards = false
		end
	end
end

function correctMouseForScaling(x,y)
	x = x - (((x/vsx)-0.5) * vsx)*((widgetScale-1)/widgetScale)
	y = y - (((y/vsy)-0.5) * vsy)*((widgetScale-1)/widgetScale)
	return x,y
end

local chipStackOffsets = {}
function gadget:DrawScreen()

	if not drawAwards then return end

	glPushMatrix()
		glTranslate(-(vsx * (widgetScale-1))/2, -(vsy * (widgetScale-1))/2, 0)
		glScale(widgetScale, widgetScale, 1)


		--if Background == nil then
		--	CreateBackground()
		--end
		if Background then
			glCallList(Background)
		end

		if FirstAward and SecondAward and ThirdAward then
			glCallList(FirstAward)
			glCallList(SecondAward)
			glCallList(ThirdAward)
		end

		if CowAward then
			glCallList(CowAward)
		elseif OtherAwards then
			glCallList(OtherAwards)
		end

		if FourthAward then
			glCallList(FourthAward)
		end

		--draw buttons, wastefully, but it doesn't matter now game is over
		local x1,y1 = Spring.GetMouseState()
		local x,y = correctMouseForScaling(x1,y1)

		local quitColour
		local graphColour

		if (x > bx+w-quitX-5) and (x < bx+w-quitX+17*font2:GetTextWidth('Quit')+5) and (y>by+50-5) and (y<by+50+17+5) then
			quitColour = "\255"..string.char(201)..string.char(51)..string.char(51)
		else
			quitColour = "\255"..string.char(201)..string.char(201)..string.char(201)
		end
		font2:Begin()
		font2:Print(quitColour .. (chobbyLoaded and 'Leave' or 'Quit'), bx+w-quitX, by+50, 20, "o")
		if (x > bx+w-graphsX-5) and (x < bx+w-graphsX+17*font2:GetTextWidth((showGraphsButton and 'Show Graphs' or 'Close'))+5) and (y>by+50-5) and (y<by+50+17+5) then
			graphColour = "\255"..string.char(201)..string.char(51)..string.char(51)
		else
			graphColour = "\255"..string.char(201)..string.char(201)..string.char(201)
		end
		font2:Print(graphColour .. (showGraphsButton and 'Show Graphs' or 'Close'), bx+w-graphsX, by+50, 20, "o")
		font2:End()

		if bettingScores ~= nil and bettingScores[1] ~= '' then
			local winners = bettingScores[1]
			local maxscore = bettingScores[2]
			local participants = bettingScores[3]

			local chipSize = 16
			local chipHeight = 3
			local heightOffset = 0
			local xOffset = 0
			glTexture(':l:LuaRules/Images/chip.dds')
			local i = 0
			while i <= maxscore do
				i = i + 1
				if chipStackOffsets[i] == nil then
					chipStackOffsets[i] = math.random()*2.4
				end
				xOffset = chipStackOffsets[i]
				glTexRect(bx+10+xOffset, by+10+heightOffset+chipSize, bx+10+chipSize+xOffset, by+10+heightOffset)
				heightOffset = heightOffset + chipHeight
			end
			font:Begin()
			font:Print('\255\225\225\225'..winners..'\255\150\150\150 became the betting winner(s)     \255\130\130\130...among '..participants..' participants', bx+18+chipSize, by+6+(chipSize/2), 14, "o")
			font:End()
		end
	glPopMatrix()
end



function gadget:Shutdown()
	if not chobbyLoaded then
		Spring.SendCommands('endgraph 1')
	end
	if Script.LuaUI("GuishaderRemoveRect") then
		Script.LuaUI.GuishaderRemoveRect('awards')
	end
	gl.DeleteFont(font)
end

end
