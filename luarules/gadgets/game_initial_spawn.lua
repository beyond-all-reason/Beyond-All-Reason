function gadget:GetInfo()
	return {
		name	= 'Initial Spawn',
		desc	= 'Handles initial spawning of units',
		author	= 'Niobium',
		version	= 'v1.0',
		date	= 'April 2011',
		license	= 'GNU GPL, v2 or later',
		layer	= 0,
		enabled	= true
	}
end

-- Note: (31/03/13) coop_II deals with the extra startpoints etc needed for teamsIDs with more than one playerID.

----------------------------------------------------------------
-- Synced
----------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then
	----------------------------------------------------------------
	-- Speedups
	----------------------------------------------------------------
	local spGetPlayerInfo = Spring.GetPlayerInfo
	local spGetTeamInfo = Spring.GetTeamInfo
	local spGetTeamRulesParam = Spring.GetTeamRulesParam
	local spSetTeamRulesParam = Spring.SetTeamRulesParam
	local spGetAllyTeamStartBox = Spring.GetAllyTeamStartBox
	local spCreateUnit = Spring.CreateUnit
	local spGetGroundHeight = Spring.GetGroundHeight

	----------------------------------------------------------------
	-- Config
	----------------------------------------------------------------
	local changeStartUnitRegex = '^\138(%d+)$'
	local startUnitParamName = 'startUnit'

	----------------------------------------------------------------
	-- Vars
	----------------------------------------------------------------
	local armcomDefID = UnitDefNames.armcom.id
	local corcomDefID = UnitDefNames.corcom.id

	local validStartUnits = {
		[armcomDefID] = true,
		[corcomDefID] = true,
	}
	local spawnTeams = {} -- spawnTeams[teamID] = allyID
	local spawnTeamsCount

	--each player gets to choose a faction
	local playerStartingUnits = {} -- playerStartingUnits[unitID] = unitDefID
	GG.playerStartingUnits = playerStartingUnits

	--each team gets one startpos. if coop mode is on, extra startpoints are placed in GG.coopStartPoints by coop
	local teamStartPoints = {} -- teamStartPoints[teamID] = {x,y,z}
	GG.teamStartPoints = teamStartPoints
	local startPointTable = {}

	local allyTeamsCount
	local allyTeams = {} --allyTeams[allyTeamID] is non-nil if this allyTeam will spawn at least one starting unit

	----------------------------------------------------------------
	-- Start Point Guesser
	----------------------------------------------------------------
	include("luarules/gadgets/lib_startpoint_guesser.lua") --start point guessing routines

	----------------------------------------------------------------
	-- FFA Startpoints (modoption)
	----------------------------------------------------------------
	-- ffaStartPoints is "global"
	local useFFAStartPoints = false
	if (tonumber(Spring.GetModOptions().ffa_mode) or 0) == 1 then
		useFFAStartPoints = true
	end

	local function getFFAStartPoints()
		include("luarules/configs/ffa_startpoints/ffa_startpoints.lua") -- if we have a ffa start points config for this map, use it
		if not ffaStartPoints and VFS.FileExists("luarules/configs/ffa_startpoints.lua") then
			include("luarules/configs/ffa_startpoints.lua") -- if we don't have one, see if the map has one
		end
	end

	----------------------------------------------------------------
	-- NewbiePlacer (modoption)
	----------------------------------------------------------------
	--Newbie Placer (prevents newbies from choosing their own a startpoint and faction)
	local NewbiePlacer
	local processedNewbies = false
	if (tonumber((Spring.GetModOptions() or {}).newbie_placer) == 1) and (Game.startPosType == 2) then
		NewbiePlacer = true
	else
		NewbiePlacer = false
	end

	--check if a player is to be considered as a 'newbie', in terms of startpoint placements
	local function isPlayerNewbie(pID)
		local name,_,isSpec,tID,_,_,_,_,pRank = Spring.GetPlayerInfo(pID,false)
		pRank = tonumber(pRank) or 0
		local customtable = select(11,Spring.GetPlayerInfo(pID)) or {} -- player custom table
		local tsMu = tostring(customtable.skill) or ""
		local tsSigma = tonumber(customtable.skilluncertainty) or 3
		local isNewbie
		if pRank == 0 and (string.find(tsMu, ")") or tsSigma >= 3) then --rank 0 and not enough ts data
			isNewbie = true
		else
			isNewbie = false
		end
		return isNewbie
	end

	--a team is a newbie team if it contains at least one newbie player
	local function isTeamNewbie(teamID)
		if not NewbiePlacer then return false end
		local playerList = Spring.GetPlayerList(teamID) or {}
		local isNewbie = false
		for _,playerID in pairs(playerList) do
			if playerID then
				if not select(3,Spring.GetPlayerInfo(playerID,false)) then
					isNewbie = isNewbie or isPlayerNewbie(playerID)
				end
			end
		end
		return isNewbie
	end

	----------------------------------------------------------------
	-- Initialize
	----------------------------------------------------------------
	function gadget:Initialize()
		local gaiaTeamID = Spring.GetGaiaTeamID()
		local teamList = Spring.GetTeamList()
		for i = 1, #teamList do
			local teamID = teamList[i]
			if teamID ~= gaiaTeamID then
				--set & broadcast (current) start unit
				local _, _, _, _, teamSide, teamAllyID = spGetTeamInfo(teamID,false)
				if teamSide == 'cortex' then
					spSetTeamRulesParam(teamID, startUnitParamName, corcomDefID)
				else
					spSetTeamRulesParam(teamID, startUnitParamName, armcomDefID)
				end
				spawnTeams[teamID] = teamAllyID

				--broadcast if newbie
				local newbieParam
				if isTeamNewbie(teamID) then
					newbieParam = 1
				else
					newbieParam = 0
				end
				spSetTeamRulesParam(teamID, 'isNewbie', newbieParam, {public=true}) --visible to all; some widgets (faction choose, initial queue) need to know if its a newbie -> they unload

				--record that this allyteam will spawn something
				local _,_,_,_,_,allyTeamID = Spring.GetTeamInfo(teamID,false)
				allyTeams[allyTeamID] = allyTeamID
			end
		end
		processedNewbies = true

		allyTeamsCount = 0
		for k,v in pairs(allyTeams) do
			allyTeamsCount = allyTeamsCount + 1
		end

		spawnTeamsCount = 0
		for k,v in pairs(spawnTeams) do
			spawnTeamsCount = spawnTeamsCount + 1
		end

		-- create the ffaStartPoints table, if we need it & can get it
		if useFFAStartPoints then
			getFFAStartPoints()
		end
		-- make the relevant part of ffaStartPoints accessible to all, if it is use-able
		if ffaStartPoints then
			GG.ffaStartPoints = ffaStartPoints[allyTeamsCount] -- NOT indexed by allyTeamID
		end

		-- mark all players as 'not yet placed'
		local initState
		if Game.startPosType ~= 2 or ffaStartPoints then
			initState = -1 -- if players won't be allowed to place startpoints
		else
			initState = 0 -- players will be allowed to place startpoints
		end
		local playerList = Spring.GetPlayerList()
		for _,playerID in pairs(playerList) do
			Spring.SetGameRulesParam("player_" .. playerID .. "_readyState" , initState)
		end
	end

	----------------------------------------------------------------
	-- Factions
	----------------------------------------------------------------
	-- keep track of choosing faction ingame
	function gadget:RecvLuaMsg(msg, playerID)
		local startUnit = tonumber(msg:match(changeStartUnitRegex))
		if startUnit and validStartUnits[startUnit] then
			local _, _, playerIsSpec, playerTeam = spGetPlayerInfo(playerID,false)
			if not playerIsSpec then
				playerStartingUnits[playerID] = startUnit
				spSetTeamRulesParam(playerTeam, startUnitParamName, startUnit, {allied=true, public=false}) -- visible to allies only, set visible to all on GameStart
				return true
			end
		end
	end

	----------------------------------------------------------------
	-- Startpoints
	----------------------------------------------------------------
	function gadget:AllowStartPosition(playerID,teamID,readyState,x,y,z)
		-- readyState:
		-- 0: player did not place startpoint, is unready
		-- 1: game starting, player is ready
		-- 2: player pressed ready OR game is starting and player is forcibly readied (note: if the player chose a startpoint, reconnected and pressed ready without re-placing, this case will have the wrong x,z)
		-- 3: game forcestarted & player absent

		-- we also add the following
		-- -1: players will not be allowed to place startpoints; automatically readied once ingame
		--  4: player has placed a startpoint but is not yet ready

		-- communicate readyState to all
		Spring.SetGameRulesParam("player_" .. playerID .. "_readyState" , readyState)

		--[[
		-- for debugging
		local name,_,_,tID = Spring.GetPlayerInfo(playerID,false)
		Spring.Echo(name,tID,x,z,readyState, (startPointTable[tID]~=nil))
		Spring.MarkerAddPoint(x,y,z,name .. " " .. readyState)
		--]]

		if Game.startPosType ~= 2 then return true end -- accept blindly unless we are in choose-in-game mode
		if useFFAStartPoints then return true end

		local _,_,_,teamID,allyTeamID = Spring.GetPlayerInfo(playerID,false)
		if not teamID or not allyTeamID then return false end --fail

		-- NewbiePlacer
		if NewbiePlacer then
			if not processedNewbies then return false end
			if readyState == 0 and Spring.GetTeamRulesParam(teamID, 'isNewbie') == 1 then
				return false
			end
		end

		-- don't allow player to place startpoint unless its inside the startbox, if we have a startbox
		if allyTeamID == nil then return false end
		local xmin, zmin, xmax, zmax = spGetAllyTeamStartBox(allyTeamID)
		if xmin>=xmax or zmin>=zmax then
			return true
		else
			local isOutsideStartbox = (xmin+1 >= x) or (x >= xmax-1) or (zmin+1 >= z) or (z >= zmax-1) -- the engine rounds startpoints to integers but does not round the startbox (wtf)
			if isOutsideStartbox then
				return false
			end
		end

		-- NoCloseSpawns
		local closeSpawnDist = 350

		for otherTeamID,startpoint in pairs(startPointTable) do
			local sx,sz = startpoint[1],startpoint[2]
			local tooClose = ((x-sx)^2+(z-sz)^2 <= closeSpawnDist^2)
			local sameTeam = (teamID == otherTeamID)
			local sameAllyTeam = (allyTeamID == select(6,Spring.GetTeamInfo(otherTeamID,false)))
			if (sx>0) and tooClose and sameAllyTeam and not sameTeam then
				Spring.SendMessageToPlayer(playerID, Spring.I18N('ui.initialSpawn.tooClose'))
				return false
			end
		end

		-- record table of starting points for startpoint assist to use
		if readyState == 2 then
			-- player pressed ready (we have already recorded their startpoint when they placed it) OR game was force started and player is forcibly readied
			if not startPointTable[teamID] then
				startPointTable[teamID]={-5000,-5000} -- if the player was forcibly readied without having placed a startpoint, place an invalid one far away (thats what the StartPointGuesser wants)
			end
		else
			-- player placed startpoint OR game is starting and player is ready
			startPointTable[teamID]={x,z}
			if readyState ~= 1 then
				-- game is not starting (therefore, player cannot yet have pressed ready)
				Spring.SetGameRulesParam("player_" .. playerID .. "_readyState" , 4)
				SendToUnsynced("StartPointChosen", playerID)
			end
		end

		return true
	end

	local function setPermutedSpawns(nSpawns, idsToSpawn)
		-- this function assumes that idsToSpawn is a hash table with nSpawns elements
		-- returns a bijective random map from key values of idsToSpawn to [1,...,nSpawns]

		-- first, construct a random permutation of [1,...,nSpawns] using a Knuth shuffle
		local perm = {}
		for i=1,nSpawns do
			perm[i] = i
		end
		for i=1,nSpawns-1 do
			local j = math.random(i,nSpawns)
			local temp = perm[i]
			perm[i] = perm[j]
			perm[j] = temp
		end

		local permutedSpawns = {}
		local slot = 1
		for id,_ in pairs(idsToSpawn) do
			permutedSpawns[id] = perm[slot]
			slot = slot + 1
		end
		return permutedSpawns
	end

	local function spawnStartUnit(teamID, x, z)
		--get starting unit
		local startUnit = spGetTeamRulesParam(teamID, startUnitParamName)

		--overwrite startUnit with random faction for newbies
		local _,_,_,isAI,sideName = Spring.GetTeamInfo(teamID)
		if Spring.GetTeamRulesParam(teamID, 'isNewbie') == 1 or sideName == "random" then
			if math.random() > 0.5 then
				startUnit = corcomDefID
			else
				startUnit = armcomDefID
			end
		end

		--spawn starting unit
		local y = spGetGroundHeight(x,z)
    local scenarioSpawnsUnits = false
    
    if  Spring.GetModOptions and  Spring.GetModOptions().scenariooptions then
      local scenariooptions = Spring.Utilities.json.decode(Spring.Utilities.Base64Decode(Spring.GetModOptions().scenariooptions))
      if scenariooptions and scenariooptions.unitloadout and next(scenariooptions.unitloadout) then
        Spring.Echo("Scenario: Spawning loadout instead of regular commanders")
        scenarioSpawnsUnits = true
      end
    end
    
    if not scenarioSpawnsUnits then
      local unitID = spCreateUnit(startUnit, x, y, z, 0, teamID)
    end

		--share info
		teamStartPoints[teamID] = {x,y,z}
		spSetTeamRulesParam(teamID, startUnitParamName, startUnit, {public=true}) -- visible to all (and picked up by advpllist)

		--team storage is set up by game_team_resources
	end

	local function spawnFFAStartUnit(nSpawns, spawnID, teamID)
		-- get allyTeam start pos
		local startPos = ffaStartPoints[nSpawns][spawnID]
		local x = startPos.x
		local z = startPos.z

		-- get team start pos; randomly move slightly to make it look nicer and (w.h.p.) avoid coms in same place in team ffa
		local r = math.random(50,120)
		local theta = math.random(100) / 100 * 2 * math.pi
		local cx = x + r*math.cos(theta)
		local cz = z + r*math.sin(theta)
		if not IsSteep(cx,cz) then --IsSteep comes from lib_startpoint_guesser, returns true if pos is too steep for com to walk on
			x = cx
			z = cz
		end

		-- spawn
		spawnStartUnit(teamID, x, z)
	end

	local function spawnTeamStartUnit(teamID, allyTeamID)
		local x,_,z = Spring.GetTeamStartPosition(teamID)
		local xmin, zmin, xmax, zmax = spGetAllyTeamStartBox(allyTeamID)

		-- if its choose-in-game mode, see if we need to autoplace anyone
		if Game.startPosType==2 then
			if not startPointTable[teamID] or startPointTable[teamID][1] < 0 then
				-- guess points for the ones classified in startPointTable as not genuine (newbies will not have a genuine startpoint)
				x,z=GuessStartSpot(teamID, allyTeamID, xmin, zmin, xmax, zmax, startPointTable)
			else
				--fallback
				if x<=0 or z<=0 then
					x = (xmin + xmax) / 2
					z = (zmin + zmax) / 2
				end
			end
		end

		--spawn
		spawnStartUnit(teamID, x, z)
	end

	----------------------------------------------------------------
	-- Spawning
	----------------------------------------------------------------
	function gadget:GameStart()

		-- ffa mode spawning
		if useFFAStartPoints and ffaStartPoints and ffaStartPoints[allyTeamsCount] and #(ffaStartPoints[allyTeamsCount])==allyTeamsCount then
			-- cycle over ally teams and spawn starting units
			local allyTeamSpawn = setPermutedSpawns(allyTeamsCount, allyTeams)
				for teamID, allyTeamID in pairs(spawnTeams) do
				spawnFFAStartUnit(allyTeamsCount, allyTeamSpawn[allyTeamID], teamID)
				end
				return
			end

		-- use ffa mode startpoints for random spawning, if possible, but per team instead of per allyTeam
		if Game.startPosType==1 and ffaStartPoints and ffaStartPoints[spawnTeamsCount] and #(ffaStartPoints[spawnTeamsCount])==spawnTeamsCount then
			local teamSpawn = setPermutedSpawns(spawnTeamsCount, spawnTeams)
			for teamID, allyTeamID in pairs(spawnTeams) do
				spawnFFAStartUnit(spawnTeamsCount, teamSpawn[teamID], teamID)
			end
			return
		end

		-- normal spawning (also used as fallback if ffaStartPoints fails)
		-- cycle through teams and call spawn team starting unit
		for teamID, allyTeamID in pairs(spawnTeams) do
			spawnTeamStartUnit(teamID, allyTeamID)
		end
	end

	function gadget:GameFrame()
		gadgetHandler:RemoveGadget(self)
	end

----------------------------------------------------------------
-- Unsynced
else
----------------------------------------------------------------
	local fontfile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
	local vsx,vsy = Spring.GetViewGeometry()
	local fontfileScale = (0.5 + (vsx*vsy / 5700000))
	local fontfileSize = 50
	local fontfileOutlineSize = 10
	local fontfileOutlineStrength = 1.4
	local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)

	local uiScale = (0.8 + (vsx*vsy / 4500000))
	local myPlayerID = Spring.GetMyPlayerID()
	local _,_,spec,myTeamID = Spring.GetPlayerInfo(myPlayerID,false)
	local amNewbie
	local ffaMode = (tonumber(Spring.GetModOptions().ffa_mode) or 0) == 1
	local isReplay = Spring.IsReplay()

	local readied = false --make sure we return true,true for newbies at least once
	local startPointChosen = false

	local NETMSG_STARTPLAYING = 4 -- see BaseNetProtocol.h, packetID sent during the 3.2.1 countdown
	local SYSTEM_ID = -1 -- see LuaUnsyncedRead::GetPlayerTraffic, playerID to get hosts traffic from
	local gameStarting
	local timer = 0
	local timer2 = 0

	local readyX = vsx * 0.77
	local readyY = vsy * 0.77

	local orgReadyH = 35
	local orgReadyW = 100

	local readyH = orgReadyH * uiScale
	local readyW = orgReadyW * uiScale
	local bgMargin = math.floor(math.max(1, readyH*0.04))

	local readyButton, readyButtonHover

	local RectRound = Spring.FlowUI.Draw.RectRound
	local UiElement = Spring.FlowUI.Draw.Element
	local UiButton = Spring.FlowUI.Draw.Button

	function gadget:ViewResize(viewSizeX, viewSizeY)
		vsx,vsy = Spring.GetViewGeometry()

		uiScale = (0.8 + (vsx*vsy / 4500000))

		readyX = math.floor(vsx * 0.8)
		readyY = math.floor(vsy * 0.8)
		readyW = math.floor(orgReadyW * uiScale / 2) * 2
		readyH =  math.floor(orgReadyH * uiScale / 2) * 2
		bgMargin = math.floor(math.max(1, readyH*0.04))

		local newFontfileScale = (0.5 + (vsx*vsy / 5700000))
		if fontfileScale ~= newFontfileScale then
			fontfileScale = newFontfileScale
			gl.DeleteFont(font)
			font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
		end
	end

	local pStates = {} --local copy of playerStates table

	function StartPointChosen(_,playerID)
		if playerID == myPlayerID then
			startPointChosen = true
			if not readied and Script.LuaUI("PlayerReadyStateChanged") then
				Script.LuaUI.PlayerReadyStateChanged(playerID, 4)
			end
		end
	end

	function gadget:GameSetup(state,ready,playerStates)
		-- check when the 3.2.1 countdown starts
		if gameStarting==nil and ((Spring.GetPlayerTraffic(SYSTEM_ID, NETMSG_STARTPLAYING) or 0) > 0) then --ugly but effective (can also detect by parsing state string)
			gameStarting = true
		end

		-- if we can't choose startpositions, no need for ready button etc
		if Game.startPosType ~= 2 or ffaMode then
			return true,true
		end

		-- notify LuaUI if readyStates have changed
		for playerID,readyState in pairs(playerStates) do
			if pStates[playerID] ~= readyState then
				if Script.LuaUI("PlayerReadyStateChanged") then
					if readyState == "ready" then
						Script.LuaUI.PlayerReadyStateChanged(playerID, 1)
					elseif readyState == "missing" then
						Script.LuaUI.PlayerReadyStateChanged(playerID, 3)
					else
						Script.LuaUI.PlayerReadyStateChanged(playerID, 0) --unready
					end
				end
				pStates[playerID] = readyState
			end
		end

		-- set my readyState to true if i am a newbie, or if ffa
		if not readied or not ready then
			amNewbie = (Spring.GetTeamRulesParam(myTeamID, 'isNewbie') == 1)
			if amNewbie or ffaMode then
				readied = true
				return true, true
			end
		end

		if not ready and readied then -- check if we just readied
			ready = true
		elseif ready and not readied then	-- check if we just reconnected/dropped
			ready = false
		end

		return true, ready
	end

	function gadget:MousePress(sx,sy)
		-- pressing ready
		if sx > readyX-bgMargin and sx < readyX+readyW+bgMargin and sy > readyY-bgMargin and sy < readyY+readyH+bgMargin and Spring.GetGameFrame() <= 0 and Game.startPosType == 2 and gameStarting==nil and not spec then
			if startPointChosen then
				readied = true
				return true
			else
				Spring.Echo(Spring.I18N('ui.initialSpawn.choosePoint'))
			end
		end

		-- message when trying to place startpoint but can't
		if amNewbie then
			local target,_ = Spring.TraceScreenRay(sx,sy)
			if target == "ground" then
				Spring.Echo(Spring.I18N('ui.initialSpawn.newbiePlacer'))
			end
		end
	end

	function gadget:MouseRelease(x,y)
		return false
	end

	function gadget:Initialize()
		gadget:ViewResize(vsx, vsy)

		-- add function to receive when startpoints were chosen
		gadgetHandler:AddSyncAction("StartPointChosen", StartPointChosen)

		-- create ready button
		readyButton = gl.CreateList(function()
			RectRound((-readyW/2)-bgMargin, (-readyH/2)-bgMargin, (readyW/2)+bgMargin, (readyH/2)+bgMargin, bgMargin*2, 1,1,1,1, {1, 0.97, 0.85, 0.85})
			UiButton((-readyW/2), (-readyH/2), (readyW/2), (readyH/2), 1,1,1,1, 1,1,1,1, nil, {0.15, 0.12, 0, 1}, {0.28, 0.23, 0, 1})
		end)
		readyButtonHover = gl.CreateList(function()
			RectRound((-readyW/2)-bgMargin, (-readyH/2)-bgMargin, (readyW/2)+bgMargin, (readyH/2)+bgMargin, bgMargin*2, 1,1,1,1, {1, 0.97, 0.85, 0.85})
			UiButton((-readyW/2), (-readyH/2), (readyW/2), (readyH/2), 1,1,1,1, 1,1,1,1, nil, {0.25, 0.21, 0, 1}, {0.44, 0.37, 0, 1})
		end)
	end

	function gadget:DrawScreen()
		if Script.LuaUI("GuishaderInsertRect") then
			Script.LuaUI.GuishaderRemoveRect('ready')
		end

		gl.PushMatrix()
			gl.Translate(readyX+(readyW/2), readyY+(readyH/2),0)

			if not readied and readyButton and Game.startPosType == 2 and gameStarting==nil and not spec and not isReplay then
			--if not readied and readyButton and not spec and not isReplay then

				if Script.LuaUI("GuishaderInsertRect") then
					Script.LuaUI.GuishaderInsertRect(
						readyX+(readyW/2)-(((readyW/2)+bgMargin)),
						readyY+(readyH/2)-(((readyH/2)+bgMargin)),
						readyX+(readyW/2)+(((readyW/2)+bgMargin)),
						readyY+(readyH/2)+(((readyH/2)+bgMargin)),
						'ready'
					)
				end

				-- draw ready button and text
				local x,y = Spring.GetMouseState()
				local colorString
				if x > readyX-bgMargin and x < readyX+readyW+bgMargin and y > readyY-bgMargin and y < readyY+readyH+bgMargin then
					gl.CallList(readyButtonHover)
					colorString = "\255\255\222\0"
				else
					gl.CallList(readyButton)
					timer2 = timer2 + Spring.GetLastUpdateSeconds()
					if timer2 % 0.75 <= 0.375 then
						colorString = "\255\255\235\50"
					else
						colorString = "\255\255\240\180"
					end
				end
				font:Begin()
				font:Print(colorString .. Spring.I18N('ui.initialSpawn.ready'), 0, -(readyH*0.2), 25*uiScale, "co")
				font:End()
				gl.Color(1,1,1,1)
			end

			if gameStarting and not isReplay then
				timer = timer + Spring.GetLastUpdateSeconds()
				local colorString
				if timer % 0.75 <= 0.375 then
					colorString = "\255\255\235\50"
				else
					colorString = "\255\255\240\180"
				end
				local text = colorString ..  Spring.I18N('ui.initialSpawn.startCountdown', { time = math.max(1,3-math.floor(timer)) })
				font:Begin()
				font:Print(text, vsx*0.5 - font:GetTextWidth(text)/2*17, vsy*0.75, 17*uiScale, "o")
				font:End()
			end
		gl.PopMatrix()

		--remove if after gamestart
		if Spring.GetGameFrame() > 0 then
			gadgetHandler:RemoveGadget(self)
			return
		end
	end

	function gadget:Shutdown()
		gl.DeleteList(readyButton)
		gl.DeleteList(readyButtonHover)
		gl.DeleteFont(font)

		if Script.LuaUI("GuishaderRemoveRect") then
			Script.LuaUI.GuishaderRemoveRect('ready')
		end
	end
----------------------------------------------------------------
end
----------------------------------------------------------------
