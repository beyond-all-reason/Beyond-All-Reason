
function gadget:GetInfo()
    return {
        name      = 'Initial Spawn',
        desc      = 'Handles initial spawning of units',
        author    = 'Niobium',
        version   = 'v1.0',
        date      = 'April 2011',
        license   = 'GNU GPL, v2 or later',
        layer     = 0,
        enabled   = true
    }
end

-- 31/03/13, mo_coop_II deals with the extra startpoints etc needed for teamsIDs with more than one playerID.

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
    return false
end

----------------------------------------------------------------
-- Config
----------------------------------------------------------------
local changeStartUnitRegex = '^\138(%d+)$'
local startUnitParamName = 'startUnit'

----------------------------------------------------------------
-- Var
----------------------------------------------------------------
local armcomDefID = UnitDefNames.armcom.id
local corcomDefID = UnitDefNames.corcom.id

local validStartUnits = {
    [armcomDefID] = true,
    [corcomDefID] = true,
}
local spawnTeams = {} -- spawnTeams[teamID] = allyID

local modOptions = Spring.GetModOptions() or {}
local comStorage = false
if ((modOptions.mo_storageowner) and (modOptions.mo_storageowner == "com")) then
  comStorage = true
end
local startMetal  = tonumber(modOptions.startmetal)  or 1000
local startEnergy = tonumber(modOptions.startenergy) or 1000

local StartPointTable = {}
local claimradius = 250*2.5 -- the radius about your own startpoint which the startpoint guesser regards as containing mexes that you've claimed for yourself (dgun range=250)
local claimheight = 300 -- the height difference relative your own startpoint in which, within the claimradius, the startpoint guesser regards you as claiming mexes (coms can build up a claiff ~200 high but not 250).

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
-- Callins
----------------------------------------------------------------
function gadget:Initialize()
    local gaiaTeamID = Spring.GetGaiaTeamID()
    local teamList = Spring.GetTeamList()
    for i = 1, #teamList do
        local teamID = teamList[i]
        if teamID ~= gaiaTeamID then
            local _, _, _, _, teamSide, teamAllyID = spGetTeamInfo(teamID)
            if teamSide == 'core' then
                spSetTeamRulesParam(teamID, startUnitParamName, corcomDefID)
            else
                spSetTeamRulesParam(teamID, startUnitParamName, armcomDefID)
            end
            spawnTeams[teamID] = teamAllyID
        end
    end
end

if tonumber((Spring.GetModOptions() or {}).mo_allowfactionchange) == 1 then
    function gadget:RecvLuaMsg(msg, playerID)
        local startUnit = tonumber(msg:match(changeStartUnitRegex))
        if startUnit and validStartUnits[startUnit] then
            local _, _, playerIsSpec, playerTeam = spGetPlayerInfo(playerID)
            if not playerIsSpec then
                spSetTeamRulesParam(playerTeam, startUnitParamName, startUnit)
                return true
            end
        end
    end
end

-- Construct a table of startpoints that have actually been placed, somewhat hackily because engine does not have the appropriate callins; see http://springrts.com/mantis/view.php?id=3665
local function MakeStartPointTable()
	local GaiateamID = Spring.GetGaiaTeamID()
	local allyTeamIDs = Spring.GetAllyTeamList()
	for j=1,#allyTeamIDs do
		local teamIDs = Spring.GetTeamList(allyTeamIDs[j])
		--Spring.Echo("teams",j)--DEBUG
		--Spring.Echo(teamIDs)--DEBUG
		local xmin, zmin, xmax, zmax = spGetAllyTeamStartBox(allyTeamIDs[j]) 
		for i=1,#teamIDs do
			local isactive,isspec = true,false
			local _,_,_,isAIteam,_,_,_,_ = Spring.GetTeamInfo(teamIDs[i]) 
			local x,_,z = Spring.GetTeamStartPosition(teamIDs[i])
			local isGaiateam = (teamIDs[i] == GaiateamID)
			playerIDs = Spring.GetPlayerList(teamIDs[i])
			--Spring.Echo("players", i)
			--Spring.Echo(playerIDs)--DEBUG
			if #playerIDs ~= 0 then
				if playerIDs[1] ~= nil then
					local _,isactive,isspec,_,_,_,_,_,_,_ = Spring.GetPlayerInfo(playerIDs[1])
				end
			end
			if (not isAIteam) and (isactive and (not isspec) and (not isGaiateam) and ((xmin ~= x) or (zmin ~= z))) then 
				StartPointTable[teamIDs[i]]={x,z} --we believe this startpoint is genuine!
			else
				if (not isGaiateam) then
					StartPointTable[teamIDs[i]]={-1,-1}
				end
			end
		end
	end
	return StartPointTable
end


local function SpawnTeamStartUnit(teamID, allyID, x, z)
    local startUnit = spGetTeamRulesParam(teamID, startUnitParamName)
    local xmin, zmin, xmax, zmax = spGetAllyTeamStartBox(allyID) 

	--Spring.Echo("Checking team, ",teamID)--DEBUG
	if (StartPointTable[teamID][1] == -1) then 
		--Spring.Echo("Guessing for team, ",teamID)--DEBUG
		x,z=GuessStartSpot(teamID, allyID, xmin, zmin, xmax, zmax)
    end

    local unitID = spCreateUnit(startUnit, x, spGetGroundHeight(x, z), z, 0, teamID) -- feed x=z=0 into this and engine will place in TL corner of startbox, or failing that in center of map
    if (comStorage) then
      Spring.AddUnitResource(unitID, 'm', startMetal)
      Spring.AddUnitResource(unitID, 'e', startEnergy)
    end
end

function gadget:GameStart() -- At this point it seems all playerIDs "without" a startpoint have had a startpoint placed by the engine at the north west point of their startbox.
	local StartPointTable = MakeStartPointTable() --TODO modoption
    for teamID, allyID in pairs(spawnTeams) do
        local startX, _, startZ = Spring.GetTeamStartPosition(teamID)
        SpawnTeamStartUnit(teamID, allyID, startX, startZ) 
    end
end



function GuessStartSpot(teamID, allyID, xmin, zmin, xmax, zmax)
	--Sanity check, covers case when there are no startboxes 
	if (xmin >= xmax) or (zmin>=zmax) then return 0,0 end 
	
	-- Try our guesses
	local x,z = GuessOne(teamID, allyID, xmin, zmin, xmax, zmax)
	Spring.Echo(x,z)
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

	-- TODO check if mex list is sensible
	local metalspots = GG.metalSpots

	-- find free metal spots
	local freemetalspots = {} -- will contain all metalspots that are within teamIDs startbox and are not within one of the cylinders given by (claimradius,claimheight) about an already existing startpoint
	local k = 1
	for i=1,#metalspots do 
		local spot = metalspots[i]
		local mx,mz = spot.x,spot.z
		local my = Spring.GetGroundHeight(mx,mz)
		local iswithinstartbox = ((xmin < mx) and (mx < xmax) and (zmin < mz) and (mz < zmax))

		local isfree = true
		for _,startpoint in pairs(StartPointTable) do -- we avoid enemy startpoints too, to prevent unnecessary explosions
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

	if (not freemetalspots) then 
		return -1,-1
	end
	
	-- score each free metal spot
	local freemetalspotscores = {}
	for i=1,#freemetalspots do freemetalspotscores[i]=0 end 	
	
	for i=1,#freemetalspots do
		local ix,iz = freemetalspots[i][1], freemetalspots[i][2]
		for j=1,i do
			local jx,jz = freemetalspots[j][1],freemetalspots[j][2]
			local score = 1/((ix-jx)*(ix-jx)+(iz-jz)*(iz-jz)) -- Magic formula. (Assumes all metal spots are of equal production value, TODO...)
			freemetalspotscores[i] = freemetalspotscores[i] + score
			freemetalspotscores[j] = freemetalspotscores[j] + score
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
			local thisdistance = (bx-mx)*(bx-mx)+(bz-mz)*(bz-mz)
			if thisdistance < bestdistance then
				bestdistance = thisdistance
				nx = mx
				nz = mz
			end
		end
	end
	
	-- if it wasn't possible to find a nearest free spot, or some error caused us to find ourselves, make a reasonable choice
	if nx==nil or nx==bx or nz==nil or nz==bz then 
		nx=bx+1
		nz=bx+1
	end
			
	-- move slightly towards nearest from best 
	local norm = math.sqrt((bx-nx)*(bx-nx)+(bz-nz)*(bz-nz))
	local dispx = (nx-bx)/norm
	local dispz = (nz-bz)/norm
	local disp = 120 -- magic number
	x = bx + disp * (dispx)
	z = bz + disp * (dispz)
	
	return x,z
end

function GuessTwo(teamID, allyID, xmin, zmin, xmax, zmax)
	return -1,-1 --TODO, cycle through map startpoints looking for one that isn't close to already placed startpoint
end

