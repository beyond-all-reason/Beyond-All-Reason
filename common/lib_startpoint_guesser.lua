-- Start Point Guessing functions used by initial_spawn

local claimRadius = 250 * 2.3 -- the radius about your own startpoint which the startpoint guesser regards as containing mexes that you've claimed for yourself (dgun range=250)
local claimRadius2 = 250 * 1.5 -- as above, but for continuous metal dist instead of spots
local claimHeight = 300 -- the height difference relative your own startpoint in which, within the claimRadius, the startpoint guesser regards you as claiming mexes (coms can build up a cliff ~200 high but not much more).
local walkRadius = 250 * 3 -- the radius outside of the startbox that we regard as being able to walk to a mex on

local mathAbs = math.abs
local mathAtan = math.atan
local mathAcos = math.acos
local mathSqrt = math.sqrt
local mathFloor = math.floor
local mathMax = math.max
local mathClamp = math.clamp
local spGetGroundHeight = Spring.GetGroundHeight

local ParseBoxes = VFS.Include("luarules/gadgets/include/startbox_utilities.lua")
local PolygonLib = VFS.Include("common/lib_polygon.lua")

local startboxConfig, startboxConfigExplicit, startboxConfigParsed

-- The bounds handed to these functions are the polygon's bounding box, so a box that is not
-- a rectangle needs the shape itself to decide what is inside it.
local function GetStartboxEntry(allyID)
	if not startboxConfigParsed then
		startboxConfigParsed = true
		local ok, config, _, explicit = pcall(ParseBoxes)
		if ok then
			startboxConfig, startboxConfigExplicit = config, explicit
		end
	end

	if not (startboxConfigExplicit and startboxConfig) then
		return nil
	end

	return startboxConfig[allyID]
end

local function IsInStartbox(allyID, x, z, xmin, zmin, xmax, zmax)
	local entry = GetStartboxEntry(allyID)
	if entry then
		return PolygonLib.PointInStartbox(x, z, entry)
	end

	return (xmin < x) and (x < xmax) and (zmin < z) and (z < zmax)
end

local samplesByAllyID = {}

-- A grid of points that are actually in the box, so the callers below can ask for a nearest
-- point or a middle without falling back on the bounding box, which for a box shaped like a
-- ring or a wedge is largely outside it.
local function StartboxSamples(allyID, xmin, zmin, xmax, zmax)
	local cached = samplesByAllyID[allyID]
	if cached ~= nil then
		return cached
	end

	local entry = GetStartboxEntry(allyID)
	if not entry then
		samplesByAllyID[allyID] = false
		return false
	end

	local samples = {}
	local steps = 32
	for i = 0, steps do
		for j = 0, steps do
			local x = xmin + (xmax - xmin) * i / steps
			local z = zmin + (zmax - zmin) * j / steps
			if PolygonLib.PointInStartbox(x, z, entry) then
				samples[#samples + 1] = { x, z }
			end
		end
	end

	samplesByAllyID[allyID] = samples
	return samples
end

local function NearestInStartbox(allyID, x, z, xmin, zmin, xmax, zmax)
	local samples = StartboxSamples(allyID, xmin, zmin, xmax, zmax)
	if not samples or #samples == 0 then
		return mathClamp(x, xmin, xmax), mathClamp(z, zmin, zmax)
	end

	if IsInStartbox(allyID, x, z, xmin, zmin, xmax, zmax) then
		return x, z
	end

	local bestX, bestZ, bestDist = samples[1][1], samples[1][2], math.huge
	for i = 1, #samples do
		local sx, sz = samples[i][1], samples[i][2]
		local dist = (sx - x) * (sx - x) + (sz - z) * (sz - z)
		if dist < bestDist then
			bestX, bestZ, bestDist = sx, sz, dist
		end
	end

	return bestX, bestZ
end

function MiddleOfStartbox(allyID, xmin, zmin, xmax, zmax)
	return NearestInStartbox(allyID, (xmin + xmax) / 2, (zmin + zmax) / 2, xmin, zmin, xmax, zmax)
end

local mtta = mathAcos(1.0 - 0.41221) - 0.02 --http://springrts.com/wiki/Movedefs.lua#How_slope_is_determined & the -0.02 is for safety

-- format of startPointTable passed in should be startPointTable(teamID) = {x,z}, where x,z<=-500 if team does not yet have a startpoint

function IsSteep(x, z)
	--check if the position (x,z) is too step to start a commander on or not
	local a1, a2, a3, a4 = 0, 0, 0, 0
	local d = 5
	local y = spGetGroundHeight(x, z)
	local y1 = spGetGroundHeight(x + d, z)
	if mathAbs(y1 - y) > 0.1 then
		a1 = mathAtan((y1 - y) / d)
	end
	local y2 = spGetGroundHeight(x, z + d)
	if mathAbs(y2 - y) > 0.1 then
		a2 = mathAtan((y2 - y) / d)
	end
	local y3 = spGetGroundHeight(x - d, z)
	if mathAbs(y3 - y) > 0.1 then
		a3 = mathAtan((y3 - y) / d)
	end
	local y4 = spGetGroundHeight(x, z - d)
	if mathAbs(y4 - y) > 0.1 then
		a4 = mathAtan((y4 - y) / d)
	end
	if mathAbs(a1) > mtta or mathAbs(a2) > mtta or mathAbs(a3) > mtta or mathAbs(a4) > mtta then
		return true --too steep
	else
		return false --ok
	end
end

function GuessOne(teamID, allyID, xmin, zmin, xmax, zmax, startPointTable)
	-- guess based on metal spots within startbox --

	-- check if mex list generation worked and retrieve if so
	local resourceSpotFinder = (GG and GG.resource_spot_finder) or (WG and WG.resource_spot_finder)
	local metalSpots = resourceSpotFinder and resourceSpotFinder.metalSpotsList or nil
	if not metalSpots or #metalSpots == 0 then
		return -1, -1
	end

	-- find free metal spots
	local freeMetalSpots = {} -- will contain all metalspots that are within teamIDs startbox and are not within one of the cylinders given by (claimradius,claimheight) about an already existing startpoint
	local walkableMetalSpots = {} -- will contain all metalspots that are NOT within teamIDs startbox and are not within one of the cylinders given by (claimradius,claimheight) about an already existing startpoint, but are within walkradius of the startbox
	local k, j = 1, 1
	for i = 1, #metalSpots do
		local spot = metalSpots[i]
		local mx, mz = spot.x, spot.z
		local my = spGetGroundHeight(mx, mz)
		local isWithinStartBox = IsInStartbox(allyID, mx, mz, xmin, zmin, xmax, zmax)
		local nearX, nearZ = NearestInStartbox(allyID, mx, mz, xmin, zmin, xmax, zmax)
		local isWithinWalkRadius = ((mx - nearX) * (mx - nearX) + (mz - nearZ) * (mz - nearZ))
			<= walkRadius * walkRadius

		local isFree = true
		for _, startpoint in pairs(startPointTable) do -- we avoid enemy startpoints too, to prevent unnecessary explosions and to deal with the case of having no startboxes
			local sx, sz = startpoint[1], startpoint[2]
			local sy = spGetGroundHeight(sx, sz)
			local isWithinClaimRadius = ((sx - mx) * (sx - mx) + (sz - mz) * (sz - mz) <= claimRadius * claimRadius)
			local isWithinClaimHeight = (mathAbs(my - sy) <= claimHeight)
			if isWithinClaimRadius and isWithinClaimHeight then
				isFree = false
				break
			end
		end

		if isFree then
			if isWithinStartBox then
				freeMetalSpots[k] = { mx, mz }
				k = k + 1
			elseif isWithinWalkRadius then
				walkableMetalSpots[j] = { mx, mz }
				j = j + 1
			end
		end
	end

	if k == 1 then --found no free metal spots within startbox
		if j == 1 then --found no walkable spots either -> give up
			return -1, -1
		end

		-- find nearest walkable metal spot to startbox
		local bx, bz = -1, -1 -- will contain nearest point in startbox to nearest walkable mex
		local bestDist = 2 * walkRadius
		for i = 1, #walkableMetalSpots do
			local mx, mz = walkableMetalSpots[i][1], walkableMetalSpots[i][2]
			local nx, nz = NearestInStartbox(allyID, mx, mz, xmin, zmin, xmax, zmax)
			local dist = mathSqrt((mx - nx) ^ 2 + (mz - nz) ^ 2)

			if not IsSteep(nx, nz) and dist < bestDist then
				bx = nx
				bz = nz
			end
		end

		return bx, bz
	end

	-- score each free metal spot
	local freeMetalSpotScores = {}
	local freeMetalSpotHeights = {}
	for i = 1, #freeMetalSpots do
		freeMetalSpotScores[i] = 0
		freeMetalSpotHeights[i] = spGetGroundHeight(freeMetalSpots[i][1], freeMetalSpots[i][2])
	end
	local walkableMetalSpotHeights = {}
	for i = 1, #walkableMetalSpots do
		walkableMetalSpotHeights[i] = spGetGroundHeight(walkableMetalSpots[i][1], walkableMetalSpots[i][2])
	end

	for i = 1, #freeMetalSpots do
		local ix, iz = freeMetalSpots[i][1], freeMetalSpots[i][2]
		local iy = freeMetalSpotHeights[i]
		for j = 1, #freeMetalSpots do
			local jx, jz = freeMetalSpots[j][1], freeMetalSpots[j][2]
			if ix ~= jx or iz ~= jz then
				local r = mathSqrt((ix - jx) ^ 2 + (iz - jz) ^ 2)
				local jy = freeMetalSpotHeights[j]
				local isWithinClaimRadius = (r <= claimRadius)
				local isWithinClaimHeight = (mathAbs(iy - jy) <= claimHeight)
				local score -- Magic formula. Assumes all metal spots are of equal production value, TODO...
				if isWithinClaimRadius and isWithinClaimHeight then
					score = 10
				else
					score = r ^ (-1 / 2)
				end
				freeMetalSpotScores[i] = freeMetalSpotScores[i] + score
			end
		end
		-- Also check all the walkable spots as some may be on the edge of the startbox
		for j = 1, #walkableMetalSpots do
			local jx, jz = walkableMetalSpots[j][1], walkableMetalSpots[j][2]
			if ix ~= jx or iz ~= jz then
				local r = mathSqrt((ix - jx) ^ 2 + (iz - jz) ^ 2)
				local jy = walkableMetalSpotHeights[j]
				local isWithinClaimRadius = (r <= claimRadius)
				local isWithinClaimHeight = (mathAbs(iy - jy) <= claimHeight)
				local score -- Magic formula. Assumes all metal spots are of equal production value, TODO...
				if isWithinClaimRadius and isWithinClaimHeight then
					score = 10
				else
					score = r ^ (-1 / 2)
				end
				freeMetalSpotScores[i] = freeMetalSpotScores[i] + score
			end
		end
	end

	-- find free metal spot with highest score
	local bestIndex = 1
	for i = 2, #freeMetalSpotScores do
		if freeMetalSpotScores[i] >= freeMetalSpotScores[bestIndex] then
			bestIndex = i
		end
	end

	-- find nearest free spot closest to best
	local bx, bz = freeMetalSpots[bestIndex][1], freeMetalSpots[bestIndex][2]
	local nx, nz
	local bestDistance = xmax * xmax + zmax * zmax -- meh, just need to be big

	for i = 1, #freeMetalSpots do
		if i ~= bestIndex then
			local mx, mz = freeMetalSpots[i][1], freeMetalSpots[i][2]
			local thisDistance = (bx - mx) * (bx - mx) + (bz - mz) * (bz - mz) --no need to squareroot, we care only about the order
			if thisDistance < bestDistance then
				bestDistance = thisDistance
				nx = mx
				nz = mz
			end
		end
	end

	-- if it wasn't possible to find a nearest free spot
	if nx == nil or nx == bx or nz == nil or nz == bz then
		nx = bx + 1
		nz = bx + 1
	end

	-- move slightly towards nearest from best
	local norm = mathSqrt((bx - nx) * (bx - nx) + (bz - nz) * (bz - nz))
	local dispx = (nx - bx) / norm
	local dispz = (nz - bz) / norm
	local disp = 120
	local x = bx + disp * dispx
	local z = bz + disp * dispz

	-- if the terrain nearby was too steep, just start on the mex (-> assume mex is passable)
	if IsSteep(x, z) then
		x = bx
		z = bz
	end

	return x, z
end

function GuessTwo(teamID, allyID, xmin, zmin, xmax, zmax, startPointTable) --TODO: make this more efficient, atm it akes 1-2 sec to run
	-- search over metal map and find a point with a reasonable amount of non-claimed metal near to it
	local mmapx, mmapz = Spring.GetMetalMapSize() -- metal map cords * 16 = world coords
	local xres = mathMax(1, mathFloor(mmapx / 16))
	local zres = mathMax(1, mathFloor(mmapz / 16))

	local points = {} --possible startpoints point[id] = {x,z,metal}, grid over metalmap of sidelength res
	local pointCount = 0
	local x = xres
	local z = zres
	while true do --i hate lua
		local y = spGetGroundHeight(x * 16, z * 16)
		local isWithinStartBox = IsInStartbox(allyID, 16 * x, 16 * z, xmin, zmin, xmax, zmax)
		if isWithinStartBox then
			pointCount = pointCount + 1
			points[pointCount] = { x = x, y = y, z = z, m = 0 }
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
	local xres2 = mathMax(1, mathFloor(xres / 4))
	local zres2 = mathMax(1, mathFloor(zres / 4))
	local claimRadius2Sq = claimRadius2 * claimRadius2
	local claimRadius2Div16Sq = (claimRadius2 / 16) * (claimRadius2 / 16)
	for x = 1, mmapx, xres2 do
		for z = 1, mmapz, zres2 do
			-- is this metal already claimed?
			local isFree = true
			for _, startpoint in pairs(startPointTable) do -- we avoid enemy startpoints too, to prevent unnecessary explosions and to deal with the case of having no startboxes
				local sx, sz = startpoint[1], startpoint[2]
				local sy = spGetGroundHeight(sx, sz)
				local y = spGetGroundHeight(x * 16, z * 16)
				local isWithinClaimRadius = (
					(sx - x * 16) * (sx - x * 16) + (sz - z * 16) * (sz - z * 16) <= claimRadius2Sq
				)
				local isWithinClaimHeight = (mathAbs(sy - y) <= claimHeight)
				if isWithinClaimRadius and isWithinClaimHeight then
					isFree = false
					break
				end
			end

			-- if it is, add this metal into points
			local m = Spring.GetMetalAmount(x, z)
			if isFree and m > 0.1 then
				local y = spGetGroundHeight(x * 16, z * 16)
				for _, p in ipairs(points) do
					if
						m
						and (p.x - x) * (p.x - x) + (p.z - z) * (p.z - z) <= claimRadius2Div16Sq
						and mathAbs(p.y - y) <= claimHeight
					then
						p.m = p.m + m
					end
				end
			end
		end
	end

	-- find which point within the startbox that has the most metal
	local best
	local bestM = 0
	for id, p in ipairs(points) do
		if bestM < p.m then
			best = id
			bestM = p.m
		end
	end

	-- return best
	if best then
		return points[best].x * 16, points[best].z * 16
	end

	-- give up
	return -1, -1
end

function GuessStartSpot(teamID, allyID, xmin, zmin, xmax, zmax, startPointTable)
	--Sanity check
	if (xmin >= xmax) or (zmin >= zmax) then
		return 0, 0
	end

	-- Try our guesses
	local x, z = GuessOne(teamID, allyID, xmin, zmin, xmax, zmax, startPointTable)
	if x >= 0 and z >= 0 then
		startPointTable[teamID] = { x, z }
		return x, z
	end

	x, z = GuessTwo(teamID, allyID, xmin, zmin, xmax, zmax, startPointTable)
	if x >= 0 and z >= 0 then
		startPointTable[teamID] = { x, z }
		return x, z
	end

	-- GIVE UP, fuuuuuuuuuuuuu --
	x, z = MiddleOfStartbox(allyID, xmin, zmin, xmax, zmax)
	startPointTable[teamID] = { x, z }
	return x, z
end
