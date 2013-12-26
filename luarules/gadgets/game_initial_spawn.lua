
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

-- guessing vars for StartPointAssist
local claimRadius = 250*2.3 -- the radius about your own startpoint which the startpoint guesser regards as containing mexes that you've claimed for yourself (dgun range=250)
local claimHeight = 300 -- the height difference relative your own startpoint in which, within the claimRadius, the startpoint guesser regards you as claiming mexes (coms can build up a cliff ~200 high but not much more).
local walkRadius = 250*3 -- the radius outside of the startbox that we regard as being able to walk to a mex on
local startPointTable = {} --temporary, only for use within this gadget

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
			spSetTeamRulesParam(teamID, 'isNewbie', newbieParam, public) --some widgets (faction choose, initial queue) need to know if its a newbie -> they unload
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
			spSetTeamRulesParam(playerTeam, startUnitParamName, startUnit, public) --public so as advplayerlist can check faction at GameStart (todo: don't make public until gamestart?)
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
		startPointTable[teamID]={-3*claimRadius,-3*claimRadius} --player readied or game was forced started, but player did not place a startpoint.  make a point far away enough not to bother anything else
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
			spSetTeamRulesParam(teamID, startUnitParamName, corcomDefID)
		else
			startUnit = armcomDefID
			spSetTeamRulesParam(teamID, startUnitParamName, armcomDefID)
		end
	end

	--spawn starting unit
	local y = spGetGroundHeight(x,z)
	local unitID = spCreateUnit(startUnit, x, y, z, 0, teamID) 
	teamStartPoints[teamID] = {x,y,z}
	
	--team storage is set up in basecontent gadget
end


----------------------------------------------------------------
--- StartPoint Placing Routines ---
----------------------------------------------------------------


function GuessStartSpot(teamID, allyID, xmin, zmin, xmax, zmax)
	--Sanity check
	if (xmin >= xmax) or (zmin>=zmax) then return 0,0 end 
	
	-- Try our guesses
	local x,z = GuessOne(teamID, allyID, xmin, zmin, xmax, zmax)
	if x>=0 and z>=0 then
		startPointTable[teamID]={x,z} 
		return x,z 
	end
	
	x,z = GuessTwo(teamID, allyID, xmin, zmin, xmax, zmax)
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



function IsSteep(x,z)
	--check if the position (x,z) is too step to start a commander on or not
	local mtta = math.acos(1.0 - 0.41221) - 0.02 --http://springrts.com/wiki/Movedefs.lua#How_slope_is_determined & the -0.02 is for safety 
	local a1,a2,a3,a4 = 0,0,0,0
	local d = 5
	local y = Spring.GetGroundHeight(x,z)
	local y1 = Spring.GetGroundHeight(x+d,z)
	if math.abs(y1 - y) > 0.1 then a1 = math.atan((y1-y)/d) end
	local y2 = Spring.GetGroundHeight(x,z+d)
	if math.abs(y2 - y) > 0.1 then a2 = math.atan((y2-y)/d) end
	local y3 = Spring.GetGroundHeight(x-d,z)
	if math.abs(y3 - y) > 0.1 then a3 = math.atan((y3-y)/d) end
	local y4 = Spring.GetGroundHeight(x,z+d)
	if math.abs(y4 - y) > 0.1 then a4 = math.atan((y4-y)/d) end
	if math.abs(a1) > mtta or math.abs(a2) > mtta or math.abs(a3) > mtta or math.abs(a4) > mtta then 
		return true --too steep
	else
		return false --ok
	end	
	
end



-- guess based on metal spots within startbox --
function GuessOne(teamID, allyID, xmin, zmin, xmax, zmax) 	


	-- check if mex list generation worked and retrieve if so
	if not GG.metalSpots then
		return -1,-1
	end
	local metalSpots = GG.metalSpots
	if metalSpots == false then 
		return -1,-1 
	end

	-- find free metal spots
	local freeMetalSpots = {} 		-- will contain all metalspots that are within teamIDs startbox and are not within one of the cylinders given by (claimradius,claimheight) about an already existing startpoint
	local walkableMetalSpots = {} -- will contain all metalspots that are NOT within teamIDs startbox and are not within one of the cylinders given by (claimradius,claimheight) about an already existing startpoint, but are within walkradius of the startbox
	local k,j = 1,1
	for i=1,#metalSpots do 
		local spot = metalSpots[i]
		local mx,mz = spot.x,spot.z
		local my = Spring.GetGroundHeight(mx,mz)
		local isWithinStartBox = (xmin < mx) and (mx < xmax) and (zmin < mz) and (mz < zmax)
		local isWithinWalkRadius = (mx >= xmin - walkRadius) and (mx <= xmax + walkRadius) and (mz >= zmin - walkRadius) and (mz <= zmax + walkRadius)
		
		local isFree = true
		for _,startpoint in pairs(startPointTable) do -- we avoid enemy startpoints too, to prevent unnecessary explosions and to deal with the case of having no startboxes
			local sx,sz = startpoint[1],startpoint[2]
			local sy = Spring.GetGroundHeight(sx,sz)
			local isWithinClaimRadius = ((sx-mx)*(sx-mx)+(sz-mz)*(sz-mz) <= (claimRadius)*(claimRadius))
			local isWithinClaimHeight = (math.abs(my-sy) <= claimHeight)
			if isWithinClaimRadius and isWithinClaimHeight then 
				isFree = false 
				break
			end
		end		
		
		if isFree then
			if isWithinStartBox then
				freeMetalSpots[k] = {mx,mz}
				k = k + 1		
			elseif isWithinWalkRadius then
				walkableMetalSpots[j] = {mx,mz}
				j = j + 1
			end
		end
	end

	if k==1 then --found no free metal spots within startbox
		if j==1 then --found no walkable spots either -> give up
			return -1,-1
		end
		
		-- find nearest walkable metal spot to startbox
		local bx,bz -- will contain nearest point in startbox to nearest walkable mex
		local bestDist = 2*walkRadius
		for i=1,#walkableMetalSpots do
			local mx,mz = walkableMetalSpots[i][1], walkableMetalSpots[i][2]
			local nx = math.max(math.min(mx,xmax),xmin)
			local nz = math.max(math.min(mz,zmax),zmin)
			local dist = math.sqrt((mx-nx)^2 + (mz-nz)^2)
			
			if not IsSteep(nx,nz) and dist < bestDist then
				bx = nx
				bz = nz
			end		
		end
		
		return bx,bz
	end
		
	-- score each free metal spot
	local freeMetalSpotScores = {}
	for i=1,#freeMetalSpots do freeMetalSpotScores[i]=0 end 	
	
	for i=1,#freeMetalSpots do
		local ix,iz = freeMetalSpots[i][1], freeMetalSpots[i][2]
		for j=1,#freeMetalSpots do
			local jx,jz = freeMetalSpots[j][1],freeMetalSpots[j][2]
			if ix ~= jx or iz ~= jz then
				local r = math.sqrt((ix-jx)^2+(iz-jz)^2)
				local iy = Spring.GetGroundHeight(ix,iz)
				local jy = Spring.GetGroundHeight(jx,jz)
				local isWithinClaimRadius = (r <= claimRadius)
				local isWithinClaimHeight = (math.abs(iy-jy) <= claimHeight)
				local score -- Magic formula. Assumes all metal spots are of equal production value, TODO...
				if isWithinClaimRadius and isWithinClaimHeight then
					score = 10
				else
					score = r^(-1/2)
				end
				freeMetalSpotScores[i] = freeMetalSpotScores[i] + score
			end
		end
	end
	
	-- find free metal spot with highest score
	local bestIndex = 1
	for i=2,#freeMetalSpotScores do
		if freeMetalSpotScores[i] >= freeMetalSpotScores[bestIndex] then
			bestIndex = i
		end	
	end
	
	-- find nearest free spot closest to best 
	local bx,bz = freeMetalSpots[bestIndex][1],freeMetalSpots[bestIndex][2]
	local nx,nz 
	local bestDistance = (xmax)*(xmax)+(zmax)*(zmax) -- meh, just need to be big

	for i=1,#freeMetalSpots do
		if i ~= bestIndex then
			local mx,mz = freeMetalSpots[i][1],freeMetalSpots[i][2]
			local thisDistance = (bx-mx)*(bx-mx)+(bz-mz)*(bz-mz) --no need to squareroot, we care only about the order 
			if thisDistance < bestDistance then
				bestDistance = thisDistance
				nx = mx
				nz = mz
			end
		end
	end
	
	-- if it wasn't possible to find a nearest free spot
	if nx==nil or nx==bx or nz==nil or nz==bz then 
		nx=bx+1
		nz=bx+1
	end
			
	-- move slightly towards nearest from best 
	local norm = math.sqrt((bx-nx)*(bx-nx)+(bz-nz)*(bz-nz))
	local dispx = (nx-bx)/norm
	local dispz = (nz-bz)/norm
	local disp = 120
	x = bx + disp * (dispx)
	z = bz + disp * (dispz)
	
	-- if the terrain nearby was too steep, just start on the mex (-> assume mex is passable)
	if IsSteep(x,z) then
		x = bx
		z = bz
	end
	
	return x,z
end



function GuessTwo(teamID, allyID, xmin, zmin, xmax, zmax)
	return -1,-1 --TODO: 
				 -- cycle through map startpoints looking for one that isn't close to an already placed startpoint
end


----------------------------------------------------------------
-- Unsynced
else
----------------------------------------------------------------

local myPlayerID = Spring.GetMyPlayerID()
local _,_,_,myTeamID = Spring.GetPlayerInfo(myPlayerID) 
local amNewbie
local readied = false --make sure we return true,true for newbies at least once

--set my readystate to true if i am a newbie
function gadget:GameSetup(state,ready,playerStates)
	if not readied or not ready then 
		amNewbie = (Spring.GetTeamRulesParam(myTeamID, 'isNewbie') == 1)
		if amNewbie then
			readied = true
			return true, true 
		end
	end
end

--message when trying to place startpoint but can't
function gadget:MousePress(sx,sy)
	if Spring.GetGameFrame() > 0 then 
		gadgetHandler:RemoveGadget()
		return
	end
	
	if amNewbie then
		local target,_ = Spring.TraceScreenRay(sx,sy)
		if target == "ground" then
			Spring.Echo("In this match, newbies (rank 0) will have a faction and startpoint chosen for them!")
		end
	end
end


----------------------------------------------------------------
end
----------------------------------------------------------------

