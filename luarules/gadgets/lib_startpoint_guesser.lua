-- Start Point Guessing functions used by initial_spawn

local claimRadius = 250*2.3 -- the radius about your own startpoint which the startpoint guesser regards as containing mexes that you've claimed for yourself (dgun range=250)
local claimRadius2 = 250*1.5 -- as above, but for continuous metal dist instead of spots
local claimHeight = 300 -- the height difference relative your own startpoint in which, within the claimRadius, the startpoint guesser regards you as claiming mexes (coms can build up a cliff ~200 high but not much more).
local walkRadius = 250*3 -- the radius outside of the startbox that we regard as being able to walk to a mex on

-- format of startPointTable passed in should be startPointTable(teamID) = {x,z}, where x,z<=-500 if team does not yet have a startpoint

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


function GuessOne(teamID, allyID, xmin, zmin, xmax, zmax, startPointTable) 	
	-- guess based on metal spots within startbox --

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
		local bx,bz = -1,-1 -- will contain nearest point in startbox to nearest walkable mex
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



function GuessTwo(teamID, allyID, xmin, zmin, xmax, zmax, startPointTable) --TODO: make this more efficient, atm it akes 1-2 sec to run
	-- search over metal map and find a point with a reasonable amount of non-claimed metal near to it
    local mmapx,mmapz = Spring.GetMetalMapSize() -- metal map cords * 16 = world coords
    local xres = math.max(1,math.floor(mmapx/16))
    local zres = math.max(1,math.floor(mmapz/16))
    
    local points = {} --possible startpoints point[id] = {x,z,metal}, grid over metalmap of sidelength res
    local x = xres
    local z = zres
    while true do --i hate lua
        local y = Spring.GetGroundHeight(x*16,z*16)
        local isWithinStartBox = (xmin < 16*x) and (16*x < xmax) and (zmin < 16*z) and (16*z < zmax)
        if isWithinStartBox then
            points[#points+1] = {x=x, y=y, z=z, m=0}
        end
        x = x + xres       
        if x > mmapx then
            x = 1
            z = z + zres
        end
        if z > mmapz then
            break
        end
    end
    
    -- count metal for each point (sample metalmap at points in square grid of sidelength res2)
    local xres2 = math.max(1,math.floor(xres/4))
    local zres2 = math.max(1,math.floor(zres/4))
    for x=1,mmapx,xres2 do
    for z=1,mmapz,zres2 do
        -- is this metal aready claimed?
        local isFree = true
        for _,startpoint in pairs(startPointTable) do -- we avoid enemy startpoints too, to prevent unnecessary explosions and to deal with the case of having no startboxes
            local sx,sz = startpoint[1],startpoint[2]
            local sy = Spring.GetGroundHeight(sx,sz)
            local y = Spring.GetGroundHeight(x*16,z*16)
            local isWithinClaimRadius = ((sx-x*16)*(sx-x*16)+(sz-z*16)*(sz-z*16) <= (claimRadius2)*(claimRadius2))
            local isWithinClaimHeight = (math.abs(sy-y) <= claimHeight)
            if isWithinClaimRadius and isWithinClaimHeight then 
                isFree = false 
                break
            end
        end		
        
        -- if it is, add this metal into points 
        local m = Spring.GetMetalAmount(x,z)
		if isFree and m > 0.1 then
            local y = Spring.GetGroundHeight(x*16,z*16)
            for _,p in ipairs(points) do
                if m and (p.x-x)*(p.x-x)+(p.z-z)*(p.z-z) <= (claimRadius2/16)*(claimRadius2/16) and math.abs(p.y-y) <= claimHeight then
                    p.m = p.m + m 
                end
            end
        end 
    end
    end
    
    -- find which point within the startbox that has the most metal
    local best 
    local bestM = 0
    for id,p in ipairs(points) do
        if bestM < p.m then
            best = id
            bestM = p.m
        end
    end
    
    -- return best
    if best then
        return (points[best].x)*16, (points[best].z)*16
    end
    
    -- give up
    return -1,-1 
end


function GuessStartSpot(teamID, allyID, xmin, zmin, xmax, zmax, startPointTable)
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