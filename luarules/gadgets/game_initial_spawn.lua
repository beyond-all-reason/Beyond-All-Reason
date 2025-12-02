local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = 'Initial Spawn',
		desc = 'Handles initial spawning of units',
		author = 'Niobium, nbusseneau',
		version = 'v2.0',
		date = 'April 2011',
		license = 'GNU GPL, v2 or later',
		layer = 0,
		enabled = true
	}
end

-- Note: (31/03/13) coop_II deals with the extra startpoints etc needed for teamsIDs with more than one playerID.

-- 2023-08-19: FFA start points configuration is now offloaded to a dedicated `game_ffa_start_setup` gadget and has been
-- reworked with a new format without global variables. The `game_initial_spawn` gadget is now consuming the data
-- provided by `game_ffa_start_setup` instead of also handling FFA start points. Backwards compatibility to the previous
-- FFA start points config format is handled by `game_ffa_start_setup`.

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
	local mathRandom = math.random
	local mathFloor = math.floor
	local mathBitOr = math.bit_or
	local mathBitAnd = math.bit_and
	local tableContains = table.contains

	----------------------------------------------------------------
	-- Config
	----------------------------------------------------------------
	local changeStartUnitRegex = 'changeStartUnit(%d+)$'
	local startUnitParamName = 'startUnit'
	local closeSpawnDist = 350

	----------------------------------------------------------------
	-- Vars
	----------------------------------------------------------------
	local validStartUnits = {}

	local RANDOM_DUMMY = UnitDefNames.dummycom and UnitDefNames.dummycom.id

	local getValidRandom, isUnitValid

	do
		local modoptions = Spring.GetModOptions()
		local factionlimiter = tonumber(modoptions.factionlimiter) or 0
		if factionlimiter > 0 then
			local legcomDefID = modoptions.experimentallegionfaction and UnitDefNames.legcom and UnitDefNames.legcom.id
			local armcomDefID = UnitDefNames.armcom and UnitDefNames.armcom.id
			local corcomDefID = UnitDefNames.corcom and UnitDefNames.corcom.id
			local ARM_MASK = 2^0
			local COR_MASK = 2^1
			local LEG_MASK = 2^2
			local FULL_BITMASK = mathBitOr(ARM_MASK, COR_MASK, LEG_MASK)

			local allyTeams = Spring.GetAllyTeamList()
			for i = 1, #allyTeams do
				local allyTeam = allyTeams[i]
				local allyStartUnits = {}
				local unitsCount = 1

				local allyTeamBitmask = mathBitAnd(mathFloor(factionlimiter/2^(allyTeam*3)), FULL_BITMASK)
				allyTeamBitmask = allyTeamBitmask == 0 and FULL_BITMASK or allyTeamBitmask

				if legcomDefID then
					if mathBitAnd(allyTeamBitmask, LEG_MASK) ~= 0 then
						allyStartUnits[unitsCount] = legcomDefID
						unitsCount = unitsCount + 1
					end
				elseif allyTeamBitmask == LEG_MASK then
					allyTeamBitmask = FULL_BITMASK
				end

				if armcomDefID and mathBitAnd(allyTeamBitmask, ARM_MASK) ~= 0 then
					allyStartUnits[unitsCount] = armcomDefID
					unitsCount = unitsCount + 1
				end
				if corcomDefID and mathBitAnd(allyTeamBitmask, COR_MASK) ~= 0 then
					allyStartUnits[unitsCount] = corcomDefID
					unitsCount = unitsCount + 1
				end

				local packedOptions = allyStartUnits[1]
				if unitsCount > 1 then
					for j = 2, #allyStartUnits do
						packedOptions = packedOptions.."|"..allyStartUnits[j]
					end
					packedOptions = packedOptions.."|"..RANDOM_DUMMY
				end

				validStartUnits[allyTeam] = allyStartUnits

				local allyTeamList = Spring.GetTeamList(allyTeam)
				---@diagnostic disable-next-line: param-type-mismatch
				for _, teamID in ipairs(allyTeamList) do
					Spring.SetTeamRulesParam(teamID, "validStartUnits", packedOptions)
				end
			end

			getValidRandom = function(allyTeamID)
				local roll = mathRandom(#validStartUnits[allyTeamID])
				return validStartUnits[allyTeamID][roll]
			end

			isUnitValid = function(unitDefID, allyTeamID)
				if not unitDefID then
					return false
				end
				if tableContains(validStartUnits[allyTeamID], unitDefID) then
					return true
				end
				if unitDefID == RANDOM_DUMMY then
					return true
				end
			end

		else
			local armcomDefID = UnitDefNames.armcom and UnitDefNames.armcom.id
			if armcomDefID then
				validStartUnits[#validStartUnits+1] = armcomDefID
			end
			local corcomDefID = UnitDefNames.corcom and UnitDefNames.corcom.id
			if corcomDefID then
				validStartUnits[#validStartUnits+1] = corcomDefID
			end
			local legcomDefID = modoptions.experimentallegionfaction and UnitDefNames.legcom and UnitDefNames.legcom.id
			if legcomDefID then
				validStartUnits[#validStartUnits+1] = legcomDefID
			end

			getValidRandom = function(allyTeamID)
				local roll = mathRandom(#validStartUnits)
				return validStartUnits[roll]
			end

			isUnitValid = function(unitDefID, allyTeamID)
				if not unitDefID then
					return false
				end
				if tableContains(validStartUnits, unitDefID) then
					return true
				end
				if unitDefID == RANDOM_DUMMY then
					return true
				end
			end

			local packedOptions = validStartUnits[1]
			if #validStartUnits > 1 then
				for j = 2, #validStartUnits do
					packedOptions = packedOptions.."|"..validStartUnits[j]
				end
				packedOptions = packedOptions.."|"..RANDOM_DUMMY
			end
			Spring.SetGameRulesParam("validStartUnits", packedOptions)

		end
	end

	local teams = {} -- teams[teamID] = allyID
	local teamsCount

	-- each player gets to choose a faction
	local playerStartingUnits = {} -- playerStartingUnits[unitID] = unitDefID
	GG.playerStartingUnits = playerStartingUnits

	-- each team gets one startpos. if coop mode is on, extra startpoints are placed in GG.coopStartPoints by coop
	local teamStartPoints = {} -- teamStartPoints[teamID] = {x,y,z}
	GG.teamStartPoints = teamStartPoints
	local startPointTable = {}

	----------------------------------------------------------------
	-- Start Point Guesser
	----------------------------------------------------------------
	VFS.Include("common/lib_startpoint_guesser.lua")

	----------------------------------------------------------------
	-- FFA start points (provided by `game_ffa_start_setup`)
	----------------------------------------------------------------
	local isFFA = Spring.Utilities.Gametype.IsFFA()
	local isTeamFFA = isFFA and Spring.Utilities.Gametype.IsTeams()

	----------------------------------------------------------------
	-- Draft Spawn Order -- only enabled when startPosType is 2
	----------------------------------------------------------------
	local draftMode = Spring.GetModOptions().draft_mode
	if (Game.startPosType == 2) and (draftMode ~= nil and draftMode ~= "disabled") then
		include("luarules/gadgets/game_draft_spawn_order.lua")
	else
		draftMode = nil
	end

	----------------------------------------------------------------
	-- Initialize
	----------------------------------------------------------------
	function gadget:Initialize()
		Spring.SetLogSectionFilterLevel(gadget:GetInfo().name, LOG.INFO)

		local gaiaTeamID = Spring.GetGaiaTeamID()
		local teamList = Spring.GetTeamList()
		for i = 1, #teamList do
			local teamID = teamList[i]
			if teamID ~= gaiaTeamID then
				-- set & broadcast (current) start unit
				local _, _, _, isAI, teamSide, teamAllyID = spGetTeamInfo(teamID, false)
				local comName = Spring.GetSideData(teamSide)
				local comDefID = UnitDefNames[comName] and UnitDefNames[comName].id

				if not isUnitValid(comDefID, teamAllyID) then
					comDefID = getValidRandom(teamAllyID)
				end

				spSetTeamRulesParam(teamID, startUnitParamName, comDefID, { allied = true, public = false })
				teams[teamID] = teamAllyID
			end
		end

		teamsCount = 0
		for k, v in pairs(teams) do
			teamsCount = teamsCount + 1
		end

		-- mark all players as 'not yet placed' and 'not yet readied'
		local initState
		if Game.startPosType ~= 2 then
			initState = -1 -- if players won't be allowed to place startpoints
		else
			initState = 0 -- players will be allowed to place startpoints

			if (draftMode ~= nil and draftMode ~= "disabled") then
				draftModeInitialize()
			end
		end
		local playerList = Spring.GetPlayerList()
		for _, playerID in pairs(playerList) do
			Spring.SetGameRulesParam("player_" .. playerID .. "_readyState", initState)
		end

		-- initializes gameside player readystates
		--local playerList = Spring.GetPlayerList()
		--for _, playerID in pairs(playerList) do
		--	Spring.SetGameRulesParam("player_" .. playerID .. "_ready_status", 0)
		--end
	end

	----------------------------------------------------------------
	-- Factions
	----------------------------------------------------------------
	-- keep track of choosing faction ingame
	function gadget:RecvLuaMsg(msg, playerID)
		local startUnit = false
		if string.sub(msg, 1, string.len("changeStartUnit")) == "changeStartUnit" then
			startUnit = tonumber(msg:match(changeStartUnitRegex))
		end
		local _, _, playerIsSpec, playerTeam, allyTeamID = spGetPlayerInfo(playerID, false)
		if isUnitValid(startUnit, allyTeamID) then
			if not playerIsSpec then
				playerStartingUnits[playerID] = startUnit
				spSetTeamRulesParam(playerTeam, startUnitParamName, startUnit, { allied = true, public = false }) -- visible to allies only, set visible to all on GameStart
				return true
			end
		end

		-- keep track of ready status gameside.
		-- sending ready status in GameSetup early prevents players from repositioning
		-- thus, the plan is to keep track of readystats gameside, and only send through GameSetup
		-- when everyone is ready
		if msg == "ready_to_start_game" then
			Spring.SetGameRulesParam("player_" .. playerID .. "_readyState", 1)
		end

		-- keep track of who has joined
		-- so when last person joins, start the auto-ready countdown
		if msg == "joined_game" then
			Spring.SetGameRulesParam("player_" .. playerID .. "_joined", 1)
			local playerList = Spring.GetPlayerList()
			local all_players_joined = true
			for _, PID in pairs(playerList) do
				local _, _, spectator_flag = spGetPlayerInfo(PID, false)
				if spectator_flag == false then
					if Spring.GetGameRulesParam("player_" .. PID .. "_joined") == nil then
						all_players_joined = false
					end
				end
			end
			if all_players_joined == true then
				Spring.SetGameRulesParam("all_players_joined", 1)
			end
		end

		-- keep track of lock state
		if msg == "locking_in_place" then
			Spring.SetGameRulesParam("player_" .. playerID .. "_lockState", 1)
		end
		if msg == "unlocking_in_place" then
			Spring.SetGameRulesParam("player_" .. playerID .. "_lockState", 0)
		end

		if not playerIsSpec and (draftMode ~= nil and draftMode ~= "disabled") then
			DraftRecvLuaMsg(msg, playerID, playerIsSpec, playerTeam, allyTeamID)
		end
		
		if string.sub(msg, 1, 17) == "aiPlacedPosition:" then
			local data = string.sub(msg, 18)
			local teamID, x, z = string.match(data, "(%d+):([%d%.]+):([%d%.]+)")
			if teamID and x and z then
				teamID = tonumber(teamID)
				x = tonumber(x)
				z = tonumber(z)

			local _, _, _, _, _, aiAllyTeamID = Spring.GetTeamInfo(teamID, false)
			local playerName, _, senderIsSpec, senderTeam, senderAllyTeamID = spGetPlayerInfo(playerID, false)

			if senderIsSpec or (aiAllyTeamID ~= senderAllyTeamID and not Spring.IsCheatingEnabled()) then
				return false
			end

				if x == 0 and z == 0 then
					spSetTeamRulesParam(teamID, "aiPlacedX", nil, { public = true })
					spSetTeamRulesParam(teamID, "aiPlacedZ", nil, { public = true })
				else
					spSetTeamRulesParam(teamID, "aiPlacedX", x, { public = true })
					spSetTeamRulesParam(teamID, "aiPlacedZ", z, { public = true })
				end
				return true
			end
		end
	end

	----------------------------------------------------------------
	-- Startpoints
	----------------------------------------------------------------
	local _unitType = {}
	--- @return boolean untraversable if the unit can not traverse the passed in x/z position
	local function isFootingUntraversable(x, y, z, unitDefID)
		-- type: 1|2|3 : air | ground mobile | building
		local type = _unitType[unitDefID]
		if not type then
			local unitDef = UnitDefs[unitDefID]
			type = unitDef.canFly and 1 or (unitDef.moveDef and unitDef.moveDef.id) and 2 or 3
			_unitType[unitDefID] = type
		end

		if type == 1 then
			return false
		end

		if type == 2 then
			return not (Spring.TestMoveOrder(unitDefID, x, y, z) and
			Spring.TestMoveOrder(unitDefID, x, y, z, 1, 0, 0) and
			Spring.TestMoveOrder(unitDefID, x, y, z, 0, 0, 1) and
			Spring.TestMoveOrder(unitDefID, x, y, z,-1, 0, 0) and
			Spring.TestMoveOrder(unitDefID, x, y, z, 0, 0,-1))
		end

		return Spring.TestBuildOrder(unitDefID, x, y, z, "s") == 0
	end

	function gadget:AllowStartPosition(playerID, teamID, readyState, x, y, z)
		-- readyState:
		-- 0: player did not place startpoint, is unready
		-- 1: game starting, player is ready
		-- 2: player pressed ready OR game is starting and player is forcibly readied (note: if the player chose a startpoint, reconnected and pressed ready without re-placing, this case will have the wrong x,z)
		-- 3: game forcestarted & player absent

		-- we also add the following
		-- -1: players will not be allowed to place startpoints; automatically readied once ingame
		--  4: player has placed a startpoint but is not yet ready

		--[[
		-- for debugging
		local name,_,_,tID = Spring.GetPlayerInfo(playerID,false)
		Spring.Echo(name,tID,x,z,readyState, (startPointTable[tID]~=nil))
		Spring.MarkerAddPoint(x,y,z,name .. " " .. readyState)
		--]]

		-- if startPosType is not set to choose-in-game, we will handle start positions manually
		if Game.startPosType ~= 2 then
			return true
		end

		if select(4, spGetTeamInfo(teamID)) then -- isAiTeam
			return false
		end

		local _, _, _, teamID, allyTeamID = Spring.GetPlayerInfo(playerID, false)
		if not teamID or not allyTeamID then
			return false
		end --fail

		local myTurn
		if (draftMode ~= nil and draftMode ~= "disabled") then
			local allowToPlace
			myTurn, allowToPlace = Draft_PreAllowStartPosition(teamID, allyTeamID)
			if allowToPlace == false then return false end
		end -- The rest of the code remains untouched; it's a simple implementation

		-- don't allow player to place startpoint unless its inside the startbox, if we have a startbox
		if allyTeamID == nil then
			return false
		end
		local xmin, zmin, xmax, zmax = spGetAllyTeamStartBox(allyTeamID)
		if xmin >= xmax or zmin >= zmax then
			return true
		else
			local isOutsideStartbox = (xmin + 1 >= x) or (x >= xmax - 1) or (zmin + 1 >= z) or
					(z >= zmax - 1) -- the engine rounds startpoints to integers but does not round the startbox (wtf)
			if isOutsideStartbox then
				return false
			end
		end

		if isFootingUntraversable(x,y,z, tonumber(spGetTeamRulesParam(teamID, startUnitParamName))) then
			return false
		end

		-- don't allow player to place if locked
		local is_player_locked = Spring.GetGameRulesParam("player_" .. playerID .. "_lockState")
		if is_player_locked == 1 then
			return false
		end

		-- communicate readyState to all
		-- Spring.SetGameRulesParam("player_" .. playerID .. "_readyState", readyState)
		local is_player_ready = Spring.GetGameRulesParam("player_" .. playerID .. "_readyState")

		for otherTeamID, startpoint in pairs(startPointTable) do
			local sx, sz = startpoint[1], startpoint[2]
			local tooClose = ((x - sx) ^ 2 + (z - sz) ^ 2 <= closeSpawnDist ^ 2)
			local sameTeam = (teamID == otherTeamID)
			local sameAllyTeam = (allyTeamID == select(6, spGetTeamInfo(otherTeamID, false)))
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
			if is_player_ready ~= 1 then
				-- game is not starting (therefore, player cannot yet have pressed ready)
				Spring.SetGameRulesParam("player_" .. playerID .. "_readyState", 4)
			end
		end

		if (draftMode ~= nil and draftMode ~= "disabled") then
			Draft_PostAllowStartPosition(myTurn, allyTeamID)
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
	local startUnitBlocking = {}
	local function spawnStartUnit(teamID, x, z)
		local startUnit = spGetTeamRulesParam(teamID, startUnitParamName)
		local luaAI = Spring.GetTeamLuaAI(teamID)

		local _, _, _, isAI, sideName, allyTeadID = spGetTeamInfo(teamID, false)
		if (startUnit or RANDOM_DUMMY) == RANDOM_DUMMY then
			startUnit = getValidRandom(allyTeadID)
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
			if not (luaAI and (string.find(luaAI, "Scavengers") or luaAI == "RaptorsAI")) then
				local unitID = spCreateUnit(startUnit, x, y, z, 0, teamID)
				if unitID then
					startUnitList[#startUnitList + 1] = { unitID = unitID, teamID = teamID, x = x, y = y, z = z }
					if not isAI then
						Spring.MoveCtrl.Enable(unitID)
					end
					Spring.SetUnitNoDraw(unitID, true)
					local uhealth, umaxhealth, uparalyze = Spring.GetUnitHealth(unitID)
					local paralyzemult = 3 * 0.025 -- 3 seconds of paralyze
					local paralyzedamage = (umaxhealth - uparalyze) + (umaxhealth * paralyzemult)
					Spring.SetUnitHealth(unitID, { paralyze = paralyzedamage })
					startUnitBlocking[unitID] = { Spring.GetUnitBlocking(unitID) }
					Spring.SetUnitBlocking(unitID, false, false, false, false, false, false, false)
				end
			end
		end

		-- share info
		teamStartPoints[teamID] = { x, y, z }
		--spSetTeamRulesParam(teamID, startUnitParamName, startUnit, { public = true }) -- visible to all (and picked up by advpllist)
		spSetTeamRulesParam(teamID, startUnitParamName, startUnit, { allied = true, public = false })

		-- team storage is set up by game_team_resources
	end

	local function spawnUsingFFAStartPoints(teamID, allyTeamID)
		-- get ally team start point
		local startPoint = GG.ffaStartPoints[allyTeamID]
		local x = startPoint.x
		local z = startPoint.z

		-- if we are in TeamFFA but still using automatic spawning (i.e. no start boxes), we want to avoid
		-- spawning all commanders in the exact same position
		if isTeamFFA then
			local r = math.random(50, 120)
			local theta = math.random(100) / 100 * 2 * math.pi
			local cx = x + r * math.cos(theta)
			local cz = z + r * math.sin(theta)
			if not IsSteep(cx, cz) then
				-- IsSteep comes from lib_startpoint_guesser, returns true if pos is too steep for com to walk on
				x = cx
				z = cz
			end
		end

		spawnStartUnit(teamID, x, z)
	end

	local function spawnRegularly(teamID, allyTeamID)
		local x, _, z = Spring.GetTeamStartPosition(teamID)
		local xmin, zmin, xmax, zmax = spGetAllyTeamStartBox(allyTeamID)
		
		local aiPlacedX = spGetTeamRulesParam(teamID, "aiPlacedX")
		local aiPlacedZ = spGetTeamRulesParam(teamID, "aiPlacedZ")
		if aiPlacedX and aiPlacedZ then
			x = aiPlacedX
			z = aiPlacedZ
		else
			if Game.startPosType == 2 then
				if not startPointTable[teamID] or startPointTable[teamID][1] < 0 then
					x, z = GuessStartSpot(teamID, allyTeamID, xmin, zmin, xmax, zmax, startPointTable)
				else
					if x <= 0 or z <= 0 then
						x = (xmin + xmax) / 2
						z = (zmin + zmax) / 2
					end
				end
			end
		end

		spawnStartUnit(teamID, x, z)
	end

	----------------------------------------------------------------
	-- Spawning
	----------------------------------------------------------------
	function gadget:GameStart()
		-- Add manually placed AI positions to startPointTable for spacing calculations
		for teamID, allyTeamID in pairs(teams) do
			local aiPlacedX = spGetTeamRulesParam(teamID, "aiPlacedX")
			local aiPlacedZ = spGetTeamRulesParam(teamID, "aiPlacedZ")
			if aiPlacedX and aiPlacedZ then
				startPointTable[teamID] = {aiPlacedX, aiPlacedZ}
			end
		end

		-- if this a FFA match with automatic spawning (i.e. no start boxes) and a list of start points was provided by
		-- `game_ffa_start_setup` for the ally teams in this match
		if isFFA and Game.startPosType == 1 and GG.ffaStartPoints then
			Spring.Log(gadget:GetInfo().name, LOG.INFO, "spawn using FFA start points config")
			for teamID, allyTeamID in pairs(teams) do
				spawnUsingFFAStartPoints(teamID, allyTeamID)
			end
		else
			-- otherwise default to spawning regularly
			if Game.startPosType == 2 then
				Spring.Log(gadget:GetInfo().name, LOG.INFO,
					"manual spawning based on positions chosen by players in start boxes")
			elseif Game.startPosType == 1 then
				Spring.Log(gadget:GetInfo().name, LOG.INFO,
					"automatic spawning using default map start positions, in random order")
			elseif Game.startPosType == 0 then
				Spring.Log(gadget:GetInfo().name, LOG.INFO,
					"automatic spawning using default map start positions, in fixed order")
			end
			for teamID, allyTeamID in pairs(teams) do
				spawnRegularly(teamID, allyTeamID)
			end
		end
	end

	function gadget:GameFrame(n)
		if not scenarioSpawnsUnits then
            if n == 60 then

                for i = 1, #startUnitList do
                    local x = startUnitList[i].x
                    local y = startUnitList[i].y
                    local z = startUnitList[i].z
                    Spring.SpawnCEG("commander-spawn", x, y, z, 0, 0, 0)
					GG.ComSpawnDefoliate(x, y, z)

                end
            end
            if n == 90 then
                for i = 1, #startUnitList do
                    local unitID = startUnitList[i].unitID
                    Spring.MoveCtrl.Disable(unitID)
                    Spring.SetUnitNoDraw(unitID, false)
                    Spring.SetUnitHealth(unitID, { paralyze = 0 })
					local unitBlocking = startUnitBlocking[unitID]
					if unitBlocking then
						Spring.SetUnitBlocking(unitID, unpack(unitBlocking))
					end
                end
            end
		end
		if n > 90 then
			gadgetHandler:RemoveGadget(self)
		end
	end

	------------------------------------------------------------------------------
	------------------------------------------------------------------------------
else -- UNSYNCED
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
		if n > 90 then
			gadgetHandler:RemoveGadget(self)
		end
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("PositionTooClose")

	end
end
