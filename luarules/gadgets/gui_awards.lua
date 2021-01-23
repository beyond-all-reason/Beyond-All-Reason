function gadget:GetInfo()
	return {
		name = "Awards",
		desc = "Awards Awards",
		author = "Bluestone",
		date = "2013-07-06",
		license = "GPLv2",
		layer = -1,
		enabled = true -- loaded by default?
	}
end

--local localtestDebug = false        -- when true: ends game after 30 secs
local showGraphsButton = true    -- when chobby is loaded this will be false

if gadgetHandler:IsSyncedCode() then

	local spAreTeamsAllied = Spring.AreTeamsAllied
	local gaiaTeamID = Spring.GetGaiaTeamID()

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
		for _, teamID in pairs(teamList) do
			local playerList = Spring.GetPlayerList(teamID)
			local list = {} --without specs
			for _, playerID in pairs(playerList) do
				local name, _, isSpec = Spring.GetPlayerInfo(playerID, false)
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
		-- make table of teams eligible for awards
		local allyTeamIDs = Spring.GetAllyTeamList()
		for i = 1, #allyTeamIDs do
			local teamIDs = Spring.GetTeamList(allyTeamIDs[i])
			for j = 1, #teamIDs do
				local isLuaAI = (Spring.GetTeamLuaAI(teamIDs[j]) ~= nil)
				local isAiTeam = select(4, Spring.GetTeamInfo(teamIDs[j]))
				if not (isLuaAI or isAiTeam or teamIDs[j] == gaiaTeamID) then
					local playerIDs = Spring.GetPlayerList(teamIDs[j])
					local numPlayers = 0
					for _, playerID in pairs(playerIDs) do
						if not select(3, Spring.GetPlayerInfo(playerID, false)) then
							numPlayers = numPlayers + 1
						end
					end
					if numPlayers > 0 then
						present[teamIDs[j]] = true
						teamInfo[teamIDs[j]] = { allDmg = 0, ecoDmg = 0, fightDmg = 0, otherDmg = 0, dmgDealt = 0, ecoUsed = 0, effScore = 0, ecoProd = 0, lastKill = 0, dmgRec = 0, sleepTime = 0, present = true, teamDmg = 0, }
						coopInfo[teamIDs[j]] = { players = numPlayers, }
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
		if not attackerTeamID then
			return
		end
		if attackerTeamID == gaiaTeamID then
			return
		end
		if not present[attackerTeamID] then
			return
		end
		if not unitDefID or not teamID then
			return
		end
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
		if curTime - teamInfo[attackerTeamID].lastKill > teamInfo[attackerTeamID].sleepTime then
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
		for tID, _ in pairs(teamInfo) do
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
		for teamID, _ in pairs(teamInfo) do
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
		for teamID, _ in pairs(teamInfo) do
			teamInfo[teamID].allDmg = teamInfo[teamID].allDmg / coopInfo[teamID].players
			teamInfo[teamID].ecoDmg = teamInfo[teamID].ecoDmg / coopInfo[teamID].players
			teamInfo[teamID].fightDmg = teamInfo[teamID].fightDmg / coopInfo[teamID].players
			teamInfo[teamID].otherDmg = teamInfo[teamID].otherDmg / coopInfo[teamID].players
			teamInfo[teamID].dmgRec = teamInfo[teamID].dmgRec / coopInfo[teamID].players

			nDmg = nDmg + teamInfo[teamID].allDmg
			nTeams = nTeams + 1
		end

		-- calculate efficiencies
		for teamID, _ in pairs(teamInfo) do
			local eff = CalculateEfficiency(teamID)
			if nDmg > 7500 * nTeams then
				teamInfo[teamID].effScore = eff
			else
				teamInfo[teamID].effScore = -1
			end
		end

		--award awards
		local ecoKillAward, ecoKillAwardSec, ecoKillAwardThi, ecoKillScore, ecoKillScoreSec, ecoKillScoreThi = -1, -1, -1, 0, 0, 0
		local fightKillAward, fightKillAwardSec, fightKillAwardThi, fightKillScore, fightKillScoreSec, fightKillScoreThi = -1, -1, -1, 0, 0, 0
		local effKillAward, effKillAwardSec, effKillAwardThi, effKillScore, effKillScoreSec, effKillScoreThi = -1, -1, -1, 0, 0, 0
		local ecoAward, ecoScore = -1, 0
		local dmgRecAward, dmgRecScore = -1, 0
		local sleepAward, sleepScore = -1, 0
		local traitorAward, traitorAwardSec, traitorAwardThi, traitorScore, traitorScoreSec, traitorScoreThi = -1, -1, -1, 0, 0, 0
		for teamID, _ in pairs(teamInfo) do
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
			if sleepScore < teamInfo[teamID].sleepTime and teamInfo[teamID].sleepTime > 12 * 60 then
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
		if ecoKillAward ~= -1 and (ecoKillAward == fightKillAward) and (fightKillAward == effKillAward) and ecoKillAward ~= -1 and nTeams > 3 then
			--check if some team got all the awards + if more than 3 teams in the game
			if winningAllyTeams and winningAllyTeams[1] then
				local won = false
				local _, _, _, _, _, cowAllyTeamID = Spring.GetTeamInfo(ecoKillAward, false)
				for _, allyTeamID in pairs(winningAllyTeams) do
					if cowAllyTeamID == allyTeamID then
						--check if this team won the game
						cowAward = ecoKillAward
						break
					end
				end
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
			traitorAward, traitorAwardSec, traitorAwardThi, traitorScore, traitorScoreSec, traitorScoreThi)

	end


	-------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------
else
	-- UNSYNCED
	-------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------

	local texts = {        -- fallback (if you want to change this, also update: language/en.lua, or it will be overwritten)
		awards = 'Awards',
		score = 'Score',
		producedthemostresources = 'produced the most resources',
		notawarded = 'not awarded',
		unknown = 'unknown',
		coop = 'coop',
		tookthemostdamage = 'took the most damage',
		sleptlongestfor = 'slept longest, for',
		runnersup = 'Runners up',
		leave = 'Leave',
		quit = 'Quit',
		close = 'Close',
		showgraphs = 'Show Graphs',
		minutes = 'minutes',
		destroyingresourceproduction = 'Destroying enemy resource production',
		destroyingunitsdefences = 'Destroying enemy units and defences',
		efficientuseofresources = 'Efficient use of resources',
		doingeverything = 'Doing everything',
		thetraitor = 'The Traitor - Destroying allied units',
	}

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

	local RectRound = Spring.FlowUI.Draw.RectRound
	local TexturedRectRound = Spring.FlowUI.Draw.TexturedRectRound
	local UiElement = Spring.FlowUI.Draw.Element

	local thisAward

	local widgetScale = 1

	local drawAwards = false
	local cx, cy --coords for center of screen
	local bx, by --coords for top left hand corner of box
	local width = 880
	local height = 550
	local bgMargin = 6
	local w = math.floor(width * widgetScale)
	local h = math.floor(height * widgetScale)
	local quitX = math.floor(100 * widgetScale)
	local graphsX = math.floor(250 * widgetScale)

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

	local red = "\255" .. string.char(171) .. string.char(51) .. string.char(51)
	local blue = "\255" .. string.char(51) .. string.char(51) .. string.char(151)
	local green = "\255" .. string.char(51) .. string.char(151) .. string.char(51)
	local white = "\255" .. string.char(251) .. string.char(251) .. string.char(251)
	local yellow = "\255" .. string.char(251) .. string.char(251) .. string.char(11)

	local playerListByTeam = {} --does not contain specs
	local myPlayerID = Spring.GetMyPlayerID()

	local fontfile = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
	local vsx, vsy = Spring.GetViewGeometry()
	local fontfileScale = (0.7 + (vsx * vsy / 7000000))
	local fontfileSize = 40
	local fontfileOutlineSize = 8
	local fontfileOutlineStrength = 1.45
	local font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
	local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
	local font2 = gl.LoadFont(fontfile2, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)

	function gadget:ViewResize(viewSizeX, viewSizeY)
		vsx, vsy = Spring.GetViewGeometry()
		local newFontfileScale = (0.5 + (vsx * vsy / 5700000))
		if fontfileScale ~= newFontfileScale then
			fontfileScale = newFontfileScale
			gl.DeleteFont(font)
			font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
			gl.DeleteFont(font2)
			font2 = gl.LoadFont(fontfile2, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
		end

		local ui_scale = Spring.GetConfigFloat("ui_scale", 1)
		local widgetSpaceMargin = math.floor((0.0045 * (vsy/vsx))*vsx * ui_scale)
		local bgpadding = math.ceil(widgetSpaceMargin * 0.66)

		--fix geometry
		widgetScale = (0.75 + (vsx * vsy / 7500000))
		w = math.floor(width * widgetScale)
		h = math.floor(height * widgetScale)
		cx = math.floor(vsx / 2)
		cy = math.floor(vsy / 2)
		bx = math.floor(cx - (w / 2))
		by = math.floor(cy - (h / 2))

		quitX = math.floor(100 * widgetScale)
		graphsX = math.floor(250 * widgetScale)

		--CreateBackground()
		--drawAwards = true
	end

	local chobbyLoaded = false
	if Spring.GetMenuName and string.find(string.lower(Spring.GetMenuName()), 'chobby') ~= nil then
		chobbyLoaded = true
		--showGraphsButton = false    -- false -> Close button
	end

	function gadget:Initialize()
		if GG.lang then
			texts = GG.lang.getText('awards')
		end
		if chobbyLoaded and showGraphsButton then
			Spring.SendCommands('endgraph 2')
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
		for _, teamID in pairs(teamList) do
			local playerList = Spring.GetPlayerList(teamID)
			local list = {} --without specs
			for _, playerID in pairs(playerList) do
				local name, _, isSpec = Spring.GetPlayerInfo(playerID, false)
				if not isSpec then
					table.insert(list, name)
				end
			end
			playerListByTeam[teamID] = list
		end
	end

	function ProcessAwards(_, ecoKillAward, ecoKillAwardSec, ecoKillAwardThi, ecoKillScore, ecoKillScoreSec, ecoKillScoreThi,
						   fightKillAward, fightKillAwardSec, fightKillAwardThi, fightKillScore, fightKillScoreSec, fightKillScoreThi,
						   effKillAward, effKillAwardSec, effKillAwardThi, effKillScore, effKillScoreSec, effKillScoreThi,
						   ecoAward, ecoScore,
						   dmgRecAward, dmgRecScore,
						   sleepAward, sleepScore,
						   cowAward,
						   traitorAward, traitorAwardSec, traitorAwardThi, traitorScore, traitorScoreSec, traitorScoreThi)

		--record who won which awards in chat message (for demo parsing by replays.springrts.com)
		--make all values positive, as unsigned ints are easier to parse
		local ecoKillLine = '\161' .. tostring(1 + ecoKillAward) .. ':' .. tostring(ecoKillScore) .. '\161' .. tostring(1 + ecoKillAwardSec) .. ':' .. tostring(ecoKillScoreSec) .. '\161' .. tostring(1 + ecoKillAwardThi) .. ':' .. tostring(ecoKillScoreThi)
		local fightKillLine = '\162' .. tostring(1 + fightKillAward) .. ':' .. tostring(fightKillScore) .. '\162' .. tostring(1 + fightKillAwardSec) .. ':' .. tostring(fightKillScoreSec) .. '\162' .. tostring(1 + fightKillAwardThi) .. ':' .. tostring(fightKillScoreThi)
		local effKillLine = '\163' .. tostring(1 + effKillAward) .. ':' .. tostring(effKillScore) .. '\163' .. tostring(1 + effKillAwardSec) .. ':' .. tostring(effKillScoreSec) .. '\163' .. tostring(1 + effKillAwardThi) .. ':' .. tostring(effKillScoreThi)
		local otherLine = '\164' .. tostring(1 + cowAward) .. '\165' .. tostring(1 + ecoAward) .. ':' .. tostring(ecoScore) .. '\166' .. tostring(1 + dmgRecAward) .. ':' .. tostring(dmgRecScore) .. '\167' .. tostring(1 + sleepAward) .. ':' .. tostring(sleepScore)
		local awardsMsg = ecoKillLine .. fightKillLine .. effKillLine .. otherLine
		Spring.SendLuaRulesMsg(awardsMsg)

		--create awards
		local addy = 0
		if traitorScore > threshold then
			addy = 100
			h = 600
		end
		CreateBackground()
		FirstAward = CreateAward('fuscup', 0, texts.destroyingresourceproduction, white, ecoKillAward, ecoKillAwardSec, ecoKillAwardThi, ecoKillScore, ecoKillScoreSec, ecoKillScoreThi, 100)
		SecondAward = CreateAward('bullcup', 0, texts.destroyingunitsdefences, white, fightKillAward, fightKillAwardSec, fightKillAwardThi, fightKillScore, fightKillScoreSec, fightKillScoreThi, 200)
		ThirdAward = CreateAward('comwreath', 0, texts.efficientuseofresources, white, effKillAward, effKillAwardSec, effKillAwardThi, effKillScore, effKillScoreSec, effKillScoreThi, 300)
		if cowAward ~= -1 then
			CowAward = CreateAward('cow', 1, texts.doingeverything, white, ecoKillAward, 1, 1, 1, 1, 1, 400 + addy)
		else
			OtherAwards = CreateAward('', 2, '', white, ecoAward, dmgRecAward, sleepAward, ecoScore, dmgRecScore, sleepScore, 400 + addy)
		end
		if traitorScore > threshold then
			FourthAward = CreateAward('traitor', 0, texts.thetraitor, white, traitorAward, traitorAwardSec, traitorAwardThi, traitorScore, traitorScoreSec, traitorScoreThi, 400)
		end
		drawAwards = true

		--don't show graph
		Spring.SendCommands('endgraph 0')
	end

	function CreateBackground()
		if Background then
			glDeleteList(Background)
		end
		if Script.LuaUI("GuishaderInsertRect") then
			Script.LuaUI.GuishaderInsertRect(bx, by, bx + w, by + h, 'awards')
		end

		Background = glCreateList(function()

			UiElement(bx, by, bx + w, by + h, 1,1,1,1, 1,1,1,1, Spring.GetConfigFloat("ui_opacity", 0.6) + 0.2)

			glColor(1, 1, 1, 1)
			glTexture(':l:LuaRules/Images/awards.png')
			glTexRect(bx + w / 2 - math.floor(220*widgetScale), by + h - math.floor(75*widgetScale), bx + w / 2 + math.floor(120*widgetScale), by + h - math.floor(5*widgetScale))

			font:Begin()
			font:Print(texts.score, bx + w / 2 + math.floor(275*widgetScale), by + h - math.floor(65*widgetScale), 16*widgetScale, "o")
			font:End()
		end)
	end

	function colourNames(teamID)
		if teamID < 0 then
			return ""
		end
		local nameColourR, nameColourG, nameColourB, nameColourA = Spring.GetTeamColor(teamID)
		local R255 = math.floor(nameColourR * 255)  --the first \255 is just a tag (not colour setting) no part can end with a zero due to engine limitation (C)
		local G255 = math.floor(nameColourG * 255)
		local B255 = math.floor(nameColourB * 255)
		if R255 % 10 == 0 then
			R255 = R255 + 1
		end
		if G255 % 10 == 0 then
			G255 = G255 + 1
		end
		if B255 % 10 == 0 then
			B255 = B255 + 1
		end
		return "\255" .. string.char(R255) .. string.char(G255) .. string.char(B255) --works thanks to zwzsg
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
				name = name .. '( '..texts.coop..')'
			end
		else
			name = '('..texts.unknown..')'
		end

		return name
	end

	function CreateAward(pic, award, note, noteColour, winnerID, secondID, thirdID, winnerScore, secondScore, thirdScore, offset)
		local winnerName, secondName, thirdName

		--award is: 0 for a normal award, 1 for the cow award, 2 for the no-cow awards

		if winnerID >= 0 then
			winnerName = FindPlayerName(winnerID)
		else
			winnerName = '('..texts.notawarded..')'
		end

		if secondID >= 0 then
			secondName = FindPlayerName(secondID)
		else
			secondName = '('..texts.notawarded..')'
		end

		if thirdID >= 0 then
			thirdName = FindPlayerName(thirdID)
		else
			thirdName = '('..texts.notawarded..')'
		end

		thisAward = glCreateList(function()

			font:Begin()
			--names
			if award ~= 2 then
				--if its a normal award or a cow award
				glColor(1, 1, 1, 1)
				local pic = ':l:LuaRules/Images/' .. pic .. '.png'
				glTexture(pic)
				glTexRect(bx + math.floor(12*widgetScale), by + h - offset - math.floor(70*widgetScale), bx + math.floor(108*widgetScale), by + h - offset + math.floor(25*widgetScale))

				font:Print(colourNames(winnerID) .. winnerName, bx + math.floor(120*widgetScale), by + h - offset - math.floor(10*widgetScale), 20*widgetScale, "o")
				font:Print(noteColour .. note, bx + math.floor(120*widgetScale), by + h - offset - math.floor(50*widgetScale), 16*widgetScale, "o")
			else
				--if the cow is not awarded, we replace it with minor awards (just text)
				local heightoffset = 0
				if winnerID >= 0 then
					font:Print(colourNames(winnerID) .. winnerName .. white .. ' '..texts.producedthemostresources..' (' .. math.floor(winnerScore) .. ').', bx + math.floor(70*widgetScale), by + h - offset - math.floor(10*widgetScale) - heightoffset, 14*widgetScale, "o")
					heightoffset = heightoffset + (17 * widgetScale)
				end
				if secondID >= 0 then
					font:Print(colourNames(secondID) .. secondName .. white .. ' '..texts.tookthemostdamage..' (' .. math.floor(secondScore) .. ').', bx + math.floor(70*widgetScale), by + h - offset - math.floor(10*widgetScale) - heightoffset, 14*widgetScale, "o")
					heightoffset = heightoffset + (17 * widgetScale)
				end
				if thirdID >= 0 then
					font:Print(colourNames(thirdID) .. thirdName .. white .. ' '..texts.sleptlongestfor..' ' .. math.floor(thirdScore / 60) .. ' '..texts.minutes..'.', bx + math.floor(70*widgetScale), by + h - offset - math.floor(10*widgetScale) - heightoffset, 14*widgetScale, "o")
				end
			end

			--scores
			if award == 0 then
				--normal awards
				if winnerID >= 0 then
					if pic == 'comwreath' then
						winnerScore = round(winnerScore, 2)
					else
						winnerScore = math.floor(winnerScore)
					end
					font:Print(colourNames(winnerID) .. winnerScore, bx + w / 2 + math.floor(275*widgetScale), by + h - offset - 5, 14*widgetScale, "o")
				else
					font:Print('-', bx + w / 2 + math.floor(275*widgetScale), by + h - offset - math.floor(5*widgetScale), 17*widgetScale, "o")
				end
				font:Print(texts.runnersup..':', bx + math.floor(500*widgetScale), by + h - offset - 5, 14*widgetScale, "o")

				if secondScore > 0 then
					if pic == 'comwreath' then
						secondScore = round(secondScore, 2)
					else
						secondScore = math.floor(secondScore)
					end
					font:Print(colourNames(secondID) .. secondName, bx + math.floor(520*widgetScale), by + h - offset - math.floor(25*widgetScale), 14*widgetScale, "o")
					font:Print(colourNames(secondID) .. secondScore, bx + w / 2 + math.floor(275*widgetScale), by + h - offset - math.floor(25*widgetScale), 14*widgetScale, "o")
				end

				if thirdScore > 0 then
					if pic == 'comwreath' then
						thirdScore = round(thirdScore, 2)
					else
						thirdScore = math.floor(thirdScore)
					end
					font:Print(colourNames(thirdID) .. thirdName, bx + math.floor(520*widgetScale), by + h - offset - math.floor(45*widgetScale), 14*widgetScale, "o")
					font:Print(colourNames(thirdID) .. thirdScore, bx + w / 2 + math.floor(275*widgetScale), by + h - offset - 45, 14*widgetScale, "o")
				end
			end
			font:End()

		end)

		return thisAward
	end

	function gadget:MousePress(x, y, button)
		if drawAwards then
			if button ~= 1 then
				return
			end
			if chobbyLoaded then
				if (x > bx + w - quitX - math.floor(5*widgetScale) and (x < bx + w - quitX + math.floor(20*widgetScale) * font:GetTextWidth('Leave') + math.floor(5*widgetScale)) and (y > by + math.floor(45*widgetScale)) and (y < by + math.floor((50 + 16 + 5)*widgetScale))) then
					--leave button
					Spring.Reload("")
				end
			else
				if (x > bx + w - quitX - math.floor(5*widgetScale)) and (x < bx + w - quitX + math.floor(20*widgetScale) * font:GetTextWidth('Quit') + math.floor(5*widgetScale)) and (y > by + math.floor((50 - 5)*widgetScale) and (y < by + math.floor((50 + 16 + 5)*widgetScale))) then
					--quit button
					Spring.SendCommands("quitforce")
				end
			end
			if (x > bx + w - graphsX - math.floor(5*widgetScale)) and (x < bx + w - graphsX + math.floor(20*widgetScale) * font:GetTextWidth((showGraphsButton and 'Show Graphs' or 'Close')) + math.floor(5*widgetScale)) and (y > by + math.floor((50 - 5)*widgetScale) and (y < by + math.floor((50 + 16 + 5)*widgetScale))) then
				if showGraphsButton then
					if chobbyLoaded then
						Spring.SendCommands('endgraph 2')
					else
						Spring.SendCommands('endgraph 1')
					end
				end
				if Script.LuaUI("GuishaderRemoveRect") then
					Script.LuaUI.GuishaderRemoveRect('awards')
				end
				drawAwards = false
			end
		end
	end

	local chipStackOffsets = {}
	function gadget:DrawScreen()

		if not drawAwards then
			return
		end

		glPushMatrix()
		--glTranslate(-(vsx * (widgetScale - 1)) / 2, -(vsy * (widgetScale - 1)) / 2, 0)
		--glScale(widgetScale, widgetScale, 1)


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
		local x, y = Spring.GetMouseState()

		local quitColour
		local graphColour

		if (x > bx + w - quitX - math.floor(5*widgetScale)) and (x < bx + w - quitX + math.floor(20*widgetScale) * font2:GetTextWidth(texts.quit) + math.floor(5*widgetScale)) and (y > by + math.floor((50 - 5)*widgetScale)) and (y < by + math.floor((50 + 17 + 5)*widgetScale)) then
			quitColour = "\255" .. string.char(201) .. string.char(51) .. string.char(51)
		else
			quitColour = "\255" .. string.char(201) .. string.char(201) .. string.char(201)
		end
		font2:Begin()
		font2:Print(quitColour .. (chobbyLoaded and texts.leave or texts.quit), bx + w - quitX, by + math.floor(50*widgetScale), 20*widgetScale, "o")
		if (x > bx + w - graphsX - (5*widgetScale)) and (x < bx + w - graphsX + math.floor(20*widgetScale) * font2:GetTextWidth((showGraphsButton and texts.showgraphs or texts.close)) + math.floor(5*widgetScale)) and (y > by + math.floor((50 - 5)*widgetScale)) and (y < by + math.floor((50 + 17 + 5))*widgetScale) then
			graphColour = "\255" .. string.char(201) .. string.char(51) .. string.char(51)
		else
			graphColour = "\255" .. string.char(201) .. string.char(201) .. string.char(201)
		end
		font2:Print(graphColour .. (showGraphsButton and texts.showgraphs or texts.close), bx + w - graphsX, by + math.floor(50*widgetScale), 20*widgetScale, "o")
		font2:End()

		glPopMatrix()
	end

	function gadget:Shutdown()
		if chobbyLoaded then
			Spring.SendCommands('endgraph 2')
		else
			Spring.SendCommands('endgraph 1')
		end
		if Script.LuaUI("GuishaderRemoveRect") then
			Script.LuaUI.GuishaderRemoveRect('awards')
		end
		gl.DeleteFont(font)
	end

end
