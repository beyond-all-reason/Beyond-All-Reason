
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

-- Note: (31/03/13) mo_coop_II deals with the extra startpoints etc needed for teamsIDs with more than one playerID.

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
local spGetTeamStartPosition = Spring.GetTeamStartPosition
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

--each player gets to choose a faction
local playerStartingUnits = {} -- playerStartingUnits[unitID] = unitDefID
GG.playerStartingUnits = playerStartingUnits 

--each team gets one startpos. if coop mode is on, extra startpoints are placed in GG.coopStartPoints by mo_coop
local teamStartPoints = {} -- teamStartPoints[teamID] = {x,y,z}
GG.teamStartPoints = teamStartPoints 
local startPointTable = {} --temporary, only for use within this gadget

----------------------------------------------------------------
-- Libs
----------------------------------------------------------------

include("luarules/gadgets/lib_startpoint_guesser.lua") --start point guessing routines

----------------------------------------------------------------
-- NewbiePlacer (modoption)
----------------------------------------------------------------

--Newbie Placer (prevents newbies from choosing their own a startpoint and faction)
local NewbiePlacer
local processedNewbies = false
if (tonumber((Spring.GetModOptions() or {}).mo_newbie_placer) == 1) and (Game.startPosType == 2) then
	NewbiePlacer = true
else
	NewbiePlacer = false
end

--check if a player is to be considered as a 'newbie', in terms of startpoint placements
function isPlayerNewbie(pID)
	local customtable
	local name,_,isSpec,tID,_,_,_,_,pRank = Spring.GetPlayerInfo(pID) 
	playerRank = tonumber(pRank) or 0
	customtable = select(10,Spring.GetPlayerInfo(pID)) or {}
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
function isNewbie(teamID)
	if not NewbiePlacer then return false end
	local playerList = Spring.GetPlayerList(teamID) or {}
	local isNewbie = false
	for _,playerID in pairs(playerList) do
		if playerID then
		local _,_,isSpec,_ = Spring.GetPlayerInfo(playerID) 
			if not isSpec then
				isNewbie = isNewbie or isPlayerNewbie(playerID)
			end
		end
	end
	return isNewbie
end

----------------------------------------------------------------
-- NoCloseSpawns (modoption)
----------------------------------------------------------------

local NoCloseSpawns
local closeSpawnDist = 350
local mapx = Game.mapX
local mapz = Game.mapY -- misnomer in API
local smallmap = (mapx^2 + mapz^2 < 6^2) --TODO: improve this
if (tonumber(Spring.GetModOptions().mo_no_close_spawns) or 1) and (Game.startPosType ~= 2) and smallmap then --don't load if modoptions says not too or if start pos placement is not 'choose in game' or if map is small
	NoCloseSpawns = true
else
	NoCloseSpawns = false
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
			local _, _, _, _, teamSide, teamAllyID = spGetTeamInfo(teamID)
			if teamSide == 'core' then
				spSetTeamRulesParam(teamID, startUnitParamName, corcomDefID)
			else
				spSetTeamRulesParam(teamID, startUnitParamName, armcomDefID)
			end
			spawnTeams[teamID] = teamAllyID
			
			--broadcast if newbie
			local newbieParam 
			if isNewbie(teamID) then
				newbieParam = 1
			else
				newbieParam = 0
			end
			spSetTeamRulesParam(teamID, 'isNewbie', newbieParam, {public=true}) --visible to all; some widgets (faction choose, initial queue) need to know if its a newbie -> they unload
		end
	end
	processedNewbies = true
end


----------------------------------------------------------------
-- Factions
----------------------------------------------------------------

-- keep track of choosing faction ingame
function gadget:RecvLuaMsg(msg, playerID)
	local startUnit = tonumber(msg:match(changeStartUnitRegex))
	if startUnit and validStartUnits[startUnit] then
		local _, _, playerIsSpec, playerTeam = spGetPlayerInfo(playerID)
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

function gadget:AllowStartPosition(x,y,z,playerID,readyState)

	if Game.startPosType == 3 then return true end --choose before game mode

	local _,_,_,teamID,allyTeamID,_,_,_,_,_ = Spring.GetPlayerInfo(playerID)
	if not teamID or not allyTeamID then return false end
	
	-- NewbiePlacer
	if NewbiePlacer then
		if not processedNewbies then return false end
		if readyState == 0 and Spring.GetTeamRulesParam(teamID, 'isNewbie') == 1 then return false end
	end
	
	-- don't allow player to place startpoint unless its inside the startbox, if we have a startbox
	if readyState ~= 2 then
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
	end
	
	-- NoCloseSpawns
	for otherTeamID,startpoint in pairs(startPointTable) do
		local sx,sz = startpoint[1],startpoint[2]
		local tooClose = ((x-sx)^2+(z-sz)^2 <= closeSpawnDist^2)
		local sameTeam = (teamID == otherTeamID)
		local _,_,_,_,_,otherAllyTeamID = Spring.GetTeamInfo(otherTeamID)
		local sameAllyTeam = (allyTeamID == otherAllyTeamID)
		if (sx>0) and tooClose and sameAllyTeam and not sameTeam then
			Spring.SendMessageToPlayer(playerID,"You cannot place your start position too close to another player")
			return false
		end
	end
		
	-- record table of starting points for startpoint assist to use
	if readyState == 2 then 
		startPointTable[teamID]={-5000,-5000} --player readied or game was forced started, but player did not place a startpoint.  make a point far away enough not to bother anything else
	else		
		startPointTable[teamID]={x,z} --player placed startpoint (may or may not have clicked ready)
	end	

	return true
end

----------------------------------------------------------------
-- Spawning
----------------------------------------------------------------

-- cycle through teams and call spawn starting unit
function gadget:GameStart() 
	for teamID, allyID in pairs(spawnTeams) do
		SpawnTeamStartUnit(teamID, allyID) 
	end
	gadgetHandler:RemoveGadget()
end


function SpawnTeamStartUnit(teamID, allyID)
	local x,_,z = Spring.GetTeamStartPosition(teamID)
	local startUnit = spGetTeamRulesParam(teamID, startUnitParamName)
	local xmin, zmin, xmax, zmax = spGetAllyTeamStartBox(allyID) 

	--pick location if didn't place
	local isAIStartPoint = (Game.startPosType == 3) and ((x>0) or (z>0)) --AIs only place startpoints of their own with choose-before-game mode
	if not isAIStartPoint then
		if ((not startPointTable[teamID]) or (startPointTable[teamID][1] < 0)) then
			-- guess points for the classified in startPointTable as not genuine (newbies will not have a genuine startpoint)
			x,z=GuessStartSpot(teamID, allyID, xmin, zmin, xmax, zmax)
		else
			--fallback 
			if (x<=0) or (z<=0) then
				x = (xmin + xmax) / 2
				z = (zmin + zmax) / 2
			end
		end
	end
	
	--overwrite startUnit with random faction for newbies 
	if Spring.GetTeamRulesParam(teamID, 'isNewbie') == 1 then
		if math.random() > 0.5 then
			startUnit = corcomDefID
		else
			startUnit = armcomDefID
		end
	end
	
	spSetTeamRulesParam(teamID, startUnitParamName, startUnit, {public=true}) -- visible to all (and picked up by advpllist)

	--spawn starting unit
	local y = spGetGroundHeight(x,z)
	local unitID = spCreateUnit(startUnit, x, y, z, 0, teamID) 
	teamStartPoints[teamID] = {x,y,z}
	
	--team storage is set up by game_team_resources
end


----------------------------------------------------------------
--- StartPoint Guessing ---
----------------------------------------------------------------


function GuessStartSpot(teamID, allyID, xmin, zmin, xmax, zmax)
	--Sanity check
	if (xmin >= xmax) or (zmin>=zmax) then return 0,0 end 
	
	-- Try our guesses
	local x,z = GuessOne(teamID, allyID, xmin, zmin, xmax, zmax, startPointTable)
	if x>=0 and z>=0 then
		startPointTable[teamID]={x,z} 
		return x,z 
	end
	
	x,z = GuessTwo(teamID, allyID, xmin, zmin, xmax, zmax, startPointTable)
	if x>=0 and z>=0 then 
		startPointTable[teamID]={x,z} 
		return x,z 
	end
	
	
	-- GIVE UP, fuuuuuuuuuuuuu --
	x = (xmin + xmax) / 2
	z = (zmin + zmax) / 2
	startPointTable[teamID]={x,z} 
	return x,z
end

----------------------------------------------------------------
-- Unsynced
else
----------------------------------------------------------------

local myPlayerID = Spring.GetMyPlayerID()
local _,_,_,myTeamID = Spring.GetPlayerInfo(myPlayerID) 
local amNewbie
local readied = false --make sure we return true,true for newbies at least once
local vsx,vsy = Spring.GetViewGeometry()
local keyList --glList for keybind info

--set my readystate to true if i am a newbie
function gadget:GameSetup(state,ready,playerStates)
	if not readied or not ready then 
		amNewbie = (Spring.GetTeamRulesParam(myTeamID, 'isNewbie') == 1)
		if amNewbie then
			readied = true
			return true, true --ready up
		end
	end
end

function gadget:MousePress(sx,sy)
	--message when trying to place startpoint but can't
	if amNewbie then
		local target,_ = Spring.TraceScreenRay(sx,sy)
		if target == "ground" then
			Spring.Echo("In this match, newbies (rank 0) will have a faction and startpoint chosen for them!")
		end
	end
end

function gadget:DrawScreen()
	--remove if after gamestart
	if Spring.GetGameFrame() > 0 then 
		if keyList then 
			gl.DeleteList(keyList)
		end
		gadgetHandler:RemoveGadget()
		return
	end

	--draw key bind info for newbies
	if amNewbie and keyInfo then
		gl.CallList(keyInfo)
	end
end

-- make draw list for newbie info (TODO: for ba:r, transfer to chili)
function gadget:Initialize()
	local indent = 15
	local textSize = 16

	local gaps = 4
	local lines = 8
	local width = 650

	local gapSize = textSize*1.5
	local lineHeight = textSize*1.15
	local height = gaps*gapSize + (lines+1)*lineHeight
	local dx = vsx*0.5-width/2
	local dy = vsy*0.5 + height/2
	local curPos = 0
	
	keyInfo = gl.CreateList(function()
		-- draws background rectangle
		gl.Color(0.1,0.1,.45,0.18)                              
		gl.Rect(dx-5,dy+textSize, dx+width, dy-height)
	
		-- draws black border
		gl.Color(0,0,0,1)
		gl.BeginEnd(GL.LINE_LOOP, function()
			gl.Vertex(dx-5,dy+textSize)
			gl.Vertex(dx-5,dy-height)
			gl.Vertex(dx+width,dy-height)
			gl.Vertex(dx+width,dy+textSize)
		end)
		gl.Color(1,1,1,1)
	
		-- draws text
		gl.Text("Welcome to BA! Some useful info:", dx, dy, textSize, "o")
		curPos = curPos + gapSize
		gl.Text("Click left mouse and drag to select units.", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + lineHeight
		gl.Text("Click the right mouse to move units", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + lineHeight
		gl.Text("To give other orders or build commands, use the unit menu and the left mouse", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + lineHeight
		gl.Text("Select multiple units and drag to give a formation command", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + gapSize
		gl.Text("\255\250\250\0Energy\255\255\255\255 comes from solar collectors, wind/tidal generators and fusions", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + lineHeight
		gl.Text("\255\20\20\20Metal\255\255\255\255 comes from metal extractors, which should be placed onto metal spots", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + lineHeight
		gl.Text("You can also get metal by using constructors to reclaim dead units!", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + gapSize
		gl.Text("BA has many keybinds", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + lineHeight
		gl.Text("Check out the Balanced Annihilation forum on springrts.com for a list of them", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + gapSize	
		gl.Text("For your first few games, a faction and start position will be chosen for you", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + lineHeight
		gl.Text("After that you will be able to choose your own", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + lineHeight
		gl.Text("Good luck!", dx+indent, dy-curPos, textSize, "o")

	end)
end


----------------------------------------------------------------
end
----------------------------------------------------------------

