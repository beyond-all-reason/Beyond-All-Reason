function gadget:GetInfo()
	return {
		name = 'Initial Spawn',
		desc = 'Handles initial spawning of units',
		author = 'Niobium',
		version = 'v1.0',
		date = 'April 2011',
		license = 'GNU GPL, v2 or later',
		layer = 0,
		enabled = true
	}
end

-- Note: (31/03/13) coop_II deals with the extra startpoints etc needed for teamsIDs with more than one playerID.

----------------------------------------------------------------
-- Synced
----------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then
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
	local closeSpawnDist = 350

	----------------------------------------------------------------
	-- Vars
	----------------------------------------------------------------
	local armcomDefID = UnitDefNames.armcom.id
	local corcomDefID = UnitDefNames.corcom.id
	local legcomDefID = UnitDefNames.legcomdef.id
	local validStartUnits = {
		[armcomDefID] = true,
		[corcomDefID] = true,
		[legcomDefID] = true,
	}
	if Spring.GetModOptions().experimentallegionfaction == true then
		validStartUnits[legcomDefID] = true
	end
	local spawnTeams = {} -- spawnTeams[teamID] = allyID
	local spawnTeamsCount

	-- each player gets to choose a faction
	local playerStartingUnits = {} -- playerStartingUnits[unitID] = unitDefID
	GG.playerStartingUnits = playerStartingUnits

	-- each team gets one startpos. if coop mode is on, extra startpoints are placed in GG.coopStartPoints by coop
	local teamStartPoints = {} -- teamStartPoints[teamID] = {x,y,z}
	GG.teamStartPoints = teamStartPoints
	local startPointTable = {}

	local allyTeamsCount
	local allyTeams = {} --allyTeams[allyTeamID] is non-nil if this allyTeam will spawn at least one starting unit

	----------------------------------------------------------------
	-- Start Point Guesser
	----------------------------------------------------------------
	include("luarules/gadgets/lib_startpoint_guesser.lua") -- start point guessing routines

	----------------------------------------------------------------
	-- FFA Startpoints (modoption)
	----------------------------------------------------------------
	-- ffaStartPoints is "global"
	local useFFAStartPoints = false
	if Spring.GetModOptions().ffa_mode then
		useFFAStartPoints = true
	end

	local function getFFAStartPoints()
		include("luarules/configs/ffa_startpoints/ffa_startpoints.lua") -- if we have a ffa start points config for this map, use it
		if not ffaStartPoints and VFS.FileExists("luarules/configs/ffa_startpoints.lua") then
			include("luarules/configs/ffa_startpoints.lua") -- if we don't have one, see if the map has one
		end
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
				-- set & broadcast (current) start unit
				local _, _, _, _, teamSide, teamAllyID = spGetTeamInfo(teamID, false)
				spSetTeamRulesParam(teamID, startUnitParamName, teamSide == 'cortex' and corcomDefID or armcomDefID or legcomDefID)
				spawnTeams[teamID] = teamAllyID

				-- record that this allyteam will spawn something
				local _, _, _, _, _, allyTeamID = Spring.GetTeamInfo(teamID, false)
				allyTeams[allyTeamID] = allyTeamID
			end
		end

		allyTeamsCount = 0
		for k, v in pairs(allyTeams) do
			allyTeamsCount = allyTeamsCount + 1
		end

		spawnTeamsCount = 0
		for k, v in pairs(spawnTeams) do
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
		for _, playerID in pairs(playerList) do
			Spring.SetGameRulesParam("player_" .. playerID .. "_readyState", initState)
		end
	end

	----------------------------------------------------------------
	-- Factions
	----------------------------------------------------------------
	-- keep track of choosing faction ingame
	function gadget:RecvLuaMsg(msg, playerID)
		local startUnit = tonumber(msg:match(changeStartUnitRegex))
		if startUnit and validStartUnits[startUnit] then
			local _, _, playerIsSpec, playerTeam = spGetPlayerInfo(playerID, false)
			if not playerIsSpec then
				playerStartingUnits[playerID] = startUnit
				spSetTeamRulesParam(playerTeam, startUnitParamName, startUnit, { allied = true, public = false }) -- visible to allies only, set visible to all on GameStart
				return true
			end
		end
	end

	----------------------------------------------------------------
	-- Startpoints
	----------------------------------------------------------------
	function gadget:AllowStartPosition(playerID, teamID, readyState, x, y, z)
		-- readyState:
		-- 0: player did not place startpoint, is unready
		-- 1: game starting, player is ready
		-- 2: player pressed ready OR game is starting and player is forcibly readied (note: if the player chose a startpoint, reconnected and pressed ready without re-placing, this case will have the wrong x,z)
		-- 3: game forcestarted & player absent

		-- we also add the following
		-- -1: players will not be allowed to place startpoints; automatically readied once ingame
		--  4: player has placed a startpoint but is not yet ready

		-- communicate readyState to all
		Spring.SetGameRulesParam("player_" .. playerID .. "_readyState", readyState)

		--[[
		-- for debugging
		local name,_,_,tID = Spring.GetPlayerInfo(playerID,false)
		Spring.Echo(name,tID,x,z,readyState, (startPointTable[tID]~=nil))
		Spring.MarkerAddPoint(x,y,z,name .. " " .. readyState)
		--]]

		if Game.startPosType ~= 2 then
			return true
		end -- accept blindly unless we are in choose-in-game mode
		if useFFAStartPoints then
			return true
		end
		if select(4, Spring.GetTeamInfo(teamID)) then  -- isAiTeam
			return false
		end

		local _, _, _, teamID, allyTeamID = Spring.GetPlayerInfo(playerID, false)
		if not teamID or not allyTeamID then
			return false
		end --fail

		-- don't allow player to place startpoint unless its inside the startbox, if we have a startbox
		if allyTeamID == nil then
			return false
		end
		local xmin, zmin, xmax, zmax = spGetAllyTeamStartBox(allyTeamID)
		if xmin >= xmax or zmin >= zmax then
			return true
		else
			local isOutsideStartbox = (xmin + 1 >= x) or (x >= xmax - 1) or (zmin + 1 >= z) or (z >= zmax - 1) -- the engine rounds startpoints to integers but does not round the startbox (wtf)
			if isOutsideStartbox then
				return false
			end
		end

		for otherTeamID, startpoint in pairs(startPointTable) do
			local sx, sz = startpoint[1], startpoint[2]
			local tooClose = ((x - sx) ^ 2 + (z - sz) ^ 2 <= closeSpawnDist ^ 2)
			local sameTeam = (teamID == otherTeamID)
			local sameAllyTeam = (allyTeamID == select(6, Spring.GetTeamInfo(otherTeamID, false)))
			if (sx > 0) and tooClose and sameAllyTeam and not sameTeam then
				SendToUnsynced("PositionTooClose", playerID)
				return false
			end
		end

		-- record table of starting points for startpoint assist to use
		if readyState == 2 then
			-- player pressed ready (we have already recorded their startpoint when they placed it) OR game was force started and player is forcibly readied
			if not startPointTable[teamID] then
				startPointTable[teamID] = { -5000, -5000 } -- if the player was forcibly readied without having placed a startpoint, place an invalid one far away (thats what the StartPointGuesser wants)
			end
		else
			-- player placed startpoint OR game is starting and player is ready
			startPointTable[teamID] = { x, z }
			if readyState ~= 1 then
				-- game is not starting (therefore, player cannot yet have pressed ready)
				Spring.SetGameRulesParam("player_" .. playerID .. "_readyState", 4)
			end
		end

		return true
	end

	local function setPermutedSpawns(nSpawns, idsToSpawn)
		-- this function assumes that idsToSpawn is a hash table with nSpawns elements
		-- returns a bijective random map from key values of idsToSpawn to [1,...,nSpawns]

		-- first, construct a random permutation of [1,...,nSpawns] using a Knuth shuffle
		local perm = {}
		for i = 1, nSpawns do
			perm[i] = i
		end
		for i = 1, nSpawns - 1 do
			local j = math.random(i, nSpawns)
			local temp = perm[i]
			perm[i] = perm[j]
			perm[j] = temp
		end

		local permutedSpawns = {}
		local slot = 1
		for id, _ in pairs(idsToSpawn) do
			permutedSpawns[id] = perm[slot]
			slot = slot + 1
		end
		return permutedSpawns
	end

	local startUnitList = {}
	local function spawnStartUnit(teamID, x, z)
		local startUnit = spGetTeamRulesParam(teamID, startUnitParamName)
		local luaAI = Spring.GetTeamLuaAI (teamID)

		local _, _, _, isAI, sideName = Spring.GetTeamInfo(teamID)
		if sideName == "random" then
			if math.random() > 0.5 then
				startUnit = corcomDefID
			else
				startUnit = armcomDefID
			end
		end

		-- spawn starting unit
		local y = spGetGroundHeight(x, z)
		local scenarioSpawnsUnits = false

		if Spring.GetModOptions().scenariooptions then
			local scenariooptions = Json.decode(string.base64Decode(Spring.GetModOptions().scenariooptions))
			if scenariooptions and scenariooptions.unitloadout and next(scenariooptions.unitloadout) then
				Spring.Echo("Scenario: Spawning loadout instead of regular commanders")
				scenarioSpawnsUnits = true
			end
		end


		if not scenarioSpawnsUnits then
			if not (luaAI and (string.find(luaAI, "Scavengers") or luaAI == "ChickensAI" or luaAI == "ScavReduxAI"))  then
				local unitID = spCreateUnit(startUnit, x, y, z, 0, teamID)
				if unitID then
					startUnitList[#startUnitList+1] = {unitID = unitID, teamID = teamID, x = x, y = y, z = z}
					if not isAI then
						Spring.MoveCtrl.Enable(unitID)
					end
					Spring.SetUnitNoDraw(unitID, true)
					local uhealth, umaxhealth, uparalyze = Spring.GetUnitHealth(unitID)
					local paralyzemult = 3*0.025 -- 3 seconds of paralyze
					local paralyzedamage = (umaxhealth-uparalyze)+(umaxhealth*paralyzemult)
					Spring.SetUnitHealth(unitID, {paralyze = paralyzedamage})
				end
			end
		end

		-- share info
		teamStartPoints[teamID] = { x, y, z }
		spSetTeamRulesParam(teamID, startUnitParamName, startUnit, { public = true }) -- visible to all (and picked up by advpllist)

		-- team storage is set up by game_team_resources
	end

	local function spawnFFAStartUnit(nSpawns, spawnID, teamID)
		-- get allyTeam start pos
		local startPos = ffaStartPoints[nSpawns][spawnID]
		local x = startPos.x
		local z = startPos.z

		-- get team start pos; randomly move slightly to make it look nicer and (w.h.p.) avoid coms in same place in team ffa
		local r = math.random(50, 120)
		local theta = math.random(100) / 100 * 2 * math.pi
		local cx = x + r * math.cos(theta)
		local cz = z + r * math.sin(theta)
		if not IsSteep(cx, cz) then
			-- IsSteep comes from lib_startpoint_guesser, returns true if pos is too steep for com to walk on
			x = cx
			z = cz
		end

		spawnStartUnit(teamID, x, z)
	end

	local function spawnTeamStartUnit(teamID, allyTeamID)
		local x, _, z = Spring.GetTeamStartPosition(teamID)
		local xmin, zmin, xmax, zmax = spGetAllyTeamStartBox(allyTeamID)

		-- if its choose-in-game mode, see if we need to autoplace anyone
		if Game.startPosType == 2 then
			if not startPointTable[teamID] or startPointTable[teamID][1] < 0 then
				-- guess points for the ones classified in startPointTable as not genuine
				x, z = GuessStartSpot(teamID, allyTeamID, xmin, zmin, xmax, zmax, startPointTable)
			else
				-- fallback
				if x <= 0 or z <= 0 then
					x = (xmin + xmax) / 2
					z = (zmin + zmax) / 2
				end
			end
		end

		spawnStartUnit(teamID, x, z)
	end

	----------------------------------------------------------------
	-- Spawning
	----------------------------------------------------------------
	function gadget:GameStart()

		-- ffa mode spawning
		if useFFAStartPoints and ffaStartPoints and ffaStartPoints[allyTeamsCount] and #(ffaStartPoints[allyTeamsCount]) == allyTeamsCount then
			-- cycle over ally teams and spawn starting units
			local allyTeamSpawn = setPermutedSpawns(allyTeamsCount, allyTeams)
			for teamID, allyTeamID in pairs(spawnTeams) do
				spawnFFAStartUnit(allyTeamsCount, allyTeamSpawn[allyTeamID], teamID)
			end
			return
		end

		-- use ffa mode startpoints for random spawning, if possible, but per team instead of per allyTeam
		if Game.startPosType == 1 and ffaStartPoints and ffaStartPoints[spawnTeamsCount] and #(ffaStartPoints[spawnTeamsCount]) == spawnTeamsCount then
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

	function gadget:GameFrame(n)
		if not scenarioSpawnsUnits then
			if Spring.GetModOptions().scoremode == "disabled" or Spring.GetModOptions().scoremode_chess == false then
				if n == 60 then
					for i = 1,#startUnitList do
						local x = startUnitList[i].x
						local y = startUnitList[i].y
						local z = startUnitList[i].z
						Spring.SpawnCEG("commander-spawn",x,y,z,0,0,0)
					end
				end
				if n == 90 then
					for i = 1,#startUnitList do
						local unitID = startUnitList[i].unitID
						Spring.MoveCtrl.Disable(unitID)
						Spring.SetUnitNoDraw(unitID, false)
						Spring.SetUnitHealth(unitID, {paralyze = 0})
					end
				end
			end
		end
		if n == 91 then
			gadgetHandler:RemoveGadget(self)
		end
	end


else  -- UNSYNCED


	local function positionTooClose(_, playerID)
		if Script.LuaUI('GadgetMessageProxy') then
			local message = Script.LuaUI.GadgetMessageProxy('ui.initialSpawn.tooClose')
			Spring.SendMessageToPlayer(playerID, message)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("PositionTooClose", positionTooClose)
	end

	function gadget:GameFrame(n)
		if n == 60 then
			Spring.PlaySoundFile("commanderspawn", 0.6, 'ui')
		end
		if n == 91 then
			gadgetHandler:RemoveGadget(self)
		end
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("PositionTooClose")
	end
end

