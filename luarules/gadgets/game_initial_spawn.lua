
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

--TODO: once startpointassist is properly tested, remove its modoption 

----------------------------------------------------------------
-- Synced 
----------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then


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

local playerStartingUnits = {} -- playerStartingUnits[unitID] = unitDefID
GG.playerStartingUnits = playerStartingUnits -- Share it to other gadgets

-- guessing vars for StartPointAssist
local claimradius = 250*2.3 -- the radius about your own startpoint which the startpoint guesser regards as containing mexes that you've claimed for yourself (dgun range=250)
local claimheight = 300 -- the height difference relative your own startpoint in which, within the claimradius, the startpoint guesser regards you as claiming mexes (coms can build up a cliff ~200 high but not much more).

----------------------------------------------------------------
-- Modoptions
----------------------------------------------------------------

local modOptions = Spring.GetModOptions() or {}

--starting res
local startMetal  = tonumber(modOptions.startmetal)  or 1000
local startEnergy = tonumber(modOptions.startenergy) or 1000

--whether storage is owned by com or team
local comStorage 
if ((modOptions.mo_storageowner) and (modOptions.mo_storageowner == "com")) then
	comStorage = true
else
	comStorage = false
end

--Start Point Assist (places sensible startpoints for players who don't do it themselves)
local StartPointAssist 
local StartPointTable = {}
if (tonumber((Spring.GetModOptions() or {}).mo_startpoint_assist) == 1) and (Game.startPosType == 2) then --type 2 is choose ingame
	StartPointAssist = true
else
	StartPointAssist = false
end

--Newbie Placer (prevents newbies from choosing their own a startpoint and faction)
local NewbiePlacer
local processedNewbies = false
if (tonumber((Spring.GetModOptions() or {}).mo_newbie_placer) == 1) and (Game.startPosType == 2) then
	NewbiePlacer = true
else
	NewbiePlacer = false
end

--check if a player is to be considered as a 'newbie', in terms of startpoint placements
function isNewbie(teamID)
	if not NewbiePlacer then return false end
	local playerList = Spring.GetPlayerList(teamID) or {}
	local playerID, playerRank 
	for _,pID in pairs(playerList) do
		local name,_,isSpec,tID,_,_,_,_,pRank = Spring.GetPlayerInfo(pID) 
		if not isSpec then
			playerID = pID 
			playerRank = tonumber(pRank) or 0
			break
		end
	end
	local customtable
	if playerID then 
		customtable = select(10,Spring.GetPlayerInfo(playerID)) or {}
	else
		customtable = {}
	end
	local tsMu = tostring(customtable.skill) or ""
	local tsSigma = tonumber(customtable.skilluncertainty) or 3
	local isNewbie
	if playerRank == 0 and (string.find(tsMu, ")") or tsSigma >= 3) then --rank 0 and not enough ts data
		isNewbie = true
	else
		isNewbie = false
	end
	return isNewbie
end


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

-- keep track of choosing faction ingame
if tonumber((Spring.GetModOptions() or {}).mo_allowfactionchange) == 1 then
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
end

----------------------------------------------------------------
-- Startpoints
----------------------------------------------------------------

function gadget:AllowStartPosition(x,y,z,playerID,readyState)
	local _,_,_,teamID,allyteamID,_,_,_,_,_ = Spring.GetPlayerInfo(playerID)
	if not teamID or not allyteamID then return false end
	
	-- no placing by 'newbies'
	if NewbiePlacer then
		if not processedNewbies then return false end
		if readyState == 0 and Spring.GetTeamRulesParam(teamID, 'isNewbie') == 1 then return false end
	end
	
	-- don't allow player to place startpoint unless its inside the startbox, if we have a startbox
	if readyState ~= 2 then
		if allyteamID == nil then return false end
		local xmin, zmin, xmax, zmax = spGetAllyTeamStartBox(allyteamID)
		if xmin>=xmax or zmin>=zmax then 
			StartPointAssist = false --if we get here, something is very wrong
			return true 
		else
			local isOutsideStartbox = (xmin+1 >= x) or (x >= xmax-1) or (zmin+1 >= z) or (z >= zmax-1) -- the engine rounds startpoints to integers but does not round the startbox (wtf)
			if isOutsideStartbox then 
				return false
			end
		end
	end
	
	
	-- record table of starting points for startpoint assist to use
	if StartPointAssist == false then return true end
	if readyState == 2 then 
		StartPointTable[teamID]={-3*claimradius,-3*claimradius} --player readied or game was forced started, but player did not place a startpoint.  make a point far away enough not to bother the placer
	else		
		StartPointTable[teamID]={x,z} --player placed startpoint (may or may not have clicked ready)
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
	if StartPointAssist then 
		-- guess points for the classified in StartPointTable as not genuine (newbies will not have a genuine startpoint)
		if (not StartPointTable[teamID]) or (StartPointTable[teamID][1] < 0) then
			x,z=GuessStartSpot(teamID, allyID, xmin, zmin, xmax, zmax)
		end
	else
		--fallback 
		if (x<=0) or (z<=0) then
			x = (xmin + xmax) / 2
			z = (zmin + zmax) / 2
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
	local unitID = spCreateUnit(startUnit, x, spGetGroundHeight(x, z), z, 0, teamID) 
	
	--set up starting storage
	if (comStorage) then
	  Spring.AddUnitResource(unitID, 'm', startMetal)
	  Spring.AddUnitResource(unitID, 'e', startEnergy)
	end
end


----------------------------------------------------------------
--- StartPointAssist Placing Routines ---
----------------------------------------------------------------

function GuessStartSpot(teamID, allyID, xmin, zmin, xmax, zmax)
	--Sanity check
	if (xmin >= xmax) or (zmin>=zmax) then return 0,0 end 
	
	-- Try our guesses
	local x,z = GuessOne(teamID, allyID, xmin, zmin, xmax, zmax)
	if x>=0 and z>=0 then
		StartPointTable[teamID]={x,z} 
		return x,z 
	else
		x,z = GuessTwo(teamID, allyID, xmin, zmin, xmax, zmax)
		if x>=0 and z>=0 then 
				StartPointTable[teamID]={x,z} 
			return x,z 
		end
	end
	

	-- GIVE UP, fuuuuuuuuuuuuu --
	x = (xmin + xmax) / 2
	z = (zmin + zmax) / 2
	StartPointTable[teamID]={x,z} 
	return x,z
end

-- guess based on metal spots --
function GuessOne(teamID, allyID, xmin, zmin, xmax, zmax) 	

	-- Note: This code is deliberately easy to read and not optimized in its logic since there is no pressure on its runtime.
	-- It's also got magic number style guesswork in it.

	-- check if mex list generation worked and retrieve if so
	if not GG.metalSpots then
		return -1,-1
	end
	local metalspots = GG.metalSpots
	if metalspots == false then 
		return -1,-1 
	end

	-- find free metal spots
	local freemetalspots = {} -- will contain all metalspots that are within teamIDs startbox and are not within one of the cylinders given by (claimradius,claimheight) about an already existing startpoint
	local k,j = 1,1
	for i=1,#metalspots do 
		local spot = metalspots[i]
		local mx,mz = spot.x,spot.z
		local my = Spring.GetGroundHeight(mx,mz)
		local iswithinstartbox = (xmin < mx) and (mx < xmax) and (zmin < mz) and (mz < zmax)
		
		local isfree = true
		for _,startpoint in pairs(StartPointTable) do -- we avoid enemy startpoints too, to prevent unnecessary explosions and to deal with the case of having no startboxes
			local sx,sz = startpoint[1],startpoint[2]
			local sy = Spring.GetGroundHeight(sx,sz)
			local iswithinclaimradius = ((sx-mx)*(sx-mx)+(sz-mz)*(sz-mz) <= (claimradius)*(claimradius))
			local iswithinclaimheight = (math.abs(my-sy) <= claimheight)
			if iswithinclaimradius and iswithinclaimheight then 
				isfree = false 
				break
			end
		end		
		
		if isfree and iswithinstartbox then
			freemetalspots[k] = {mx,mz}
			k = k + 1		
		end
	end

	if k==1 then --found no free metal spots
		return -1,-1
	end
		
	-- score each free metal spot
	local freemetalspotscores = {}
	for i=1,#freemetalspots do freemetalspotscores[i]=0 end 	
	
	for i=1,#freemetalspots do
		local ix,iz = freemetalspots[i][1], freemetalspots[i][2]
		for j=1,#freemetalspots do
			local jx,jz = freemetalspots[j][1],freemetalspots[j][2]
			if ix ~= jx or iz ~= jz then
				local r = ((math.abs(ix-jx))^2+(math.abs(iz-jz))^2)^(1/2)
				local iy = Spring.GetGroundHeight(ix,iz)
				local jy = Spring.GetGroundHeight(jx,jz)
				local iswithinclaimradius = (r <= claimradius)
				local iswithinclaimheight = (math.abs(iy-jy) <= claimheight)
				local score -- Magic formula. Assumes all metal spots are of equal production value, TODO...
				if iswithinclaimradius and iswithinclaimheight then
					score = 10
				else
					score = r^(-1/2)
				end
				freemetalspotscores[i] = freemetalspotscores[i] + score
			end
		end
	end
	
	-- find free metal spot with highest score
	local bestindex = 1
	for i=2,#freemetalspotscores do
		if freemetalspotscores[i] >= freemetalspotscores[bestindex] then
			bestindex = i
		end	
	end
	
	-- find nearest free spot closest to best 
	local bx,bz = freemetalspots[bestindex][1],freemetalspots[bestindex][2]
	local nx,nz 
	local bestdistance = (xmax)*(xmax)+(zmax)*(zmax) -- meh, just need to be big

	for i=1,#freemetalspots do
		if i ~= bestindex then
			local mx,mz = freemetalspots[i][1],freemetalspots[i][2]
			local thisdistance = (bx-mx)*(bx-mx)+(bz-mz)*(bz-mz) --no need to squareroot, we care only about the order 
			if thisdistance < bestdistance then
				bestdistance = thisdistance
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
	
	--see how steep the terrain around (x,z) is
	--fixme!
	local steep
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
		steep = true
	else
		steep = false
	end
	--Spring.Echo(teamID,y-y1,y-y2,y-y3,y-y4,a1,a2,a3,a4,mtta,steep) --debug
	--Spring.MarkerAddPoint(x,y,z,tostring(teamID))
	
	-- if the terrain nearby was too steep, just start on the mex (-> assume mex is passable)
	if steep then
		x = bx
		z = bz
	end
	
	return x,z
end

-- guess based on map startpoints --
function GuessTwo(teamID, allyID, xmin, zmin, xmax, zmax)
	return -1,-1 --TODO: cycle through map startpoints looking for one that isn't close to an already placed startpoint
end



----------------------------------------------------------------
-- Unsynced
else
----------------------------------------------------------------

local myPlayerID = Spring.GetMyPlayerID()
local _,_,_,myTeamID = Spring.GetPlayerInfo(myPlayerID) 

--set my readystate to true if i am a newbie
function gadget:GameSetup(state,ready,playerStates)
	if (not ready) then 
		amNewbie = (Spring.GetTeamRulesParam(myTeamID, 'isNewbie') == 1)
		if amNewbie then 
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
			Spring.Echo("In this game, newbies (rank 0) will have a faction and startpoint chosen for them!")
		end
	end
end


----------------------------------------------------------------
end
----------------------------------------------------------------

