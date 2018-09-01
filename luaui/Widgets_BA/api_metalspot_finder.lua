
function widget:GetInfo()
	return {
		name      = "Metalspot Finder",
		desc      = "Finds metal spots for other widgets",
		author    = "Niobium",
		version   = "v1.1",
		date      = "November 2010",
		license   = "GNU GPL, v2 or later",
		layer     = -30000,
		enabled   = true
	}
end

------------------------------------------------------------
-- Config
------------------------------------------------------------
local gridSize = 16 -- Resolution of metal map
local buildGridSize = 8 -- Resolution of build positions

------------------------------------------------------------
-- Speedups
------------------------------------------------------------
local min, max = math.min, math.max
local floor, ceil = math.floor, math.ceil
local sqrt = math.sqrt
local huge = math.huge

local spGetGroundInfo = Spring.GetGroundInfo
local spGetGroundHeight = Spring.GetGroundHeight
local spTestBuildOrder = Spring.TestBuildOrder

local extractorRadius = Game.extractorRadius
local extractorRadiusSqr = extractorRadius * extractorRadius
 
local buildmapSizeX = Game.mapSizeX - buildGridSize
local buildmapSizeZ = Game.mapSizeZ - buildGridSize
local buildmapStartX = buildGridSize
local buildmapStartZ = buildGridSize

local metalmapSizeX = Game.mapSizeX - 1.5 * gridSize
local metalmapSizeZ = Game.mapSizeZ - 1.5 * gridSize
local metalmapStartX = 1.5 * gridSize
local metalmapStartZ = 1.5 * gridSize

------------------------------------------------------------
-- Callins
------------------------------------------------------------
function widget:Initialize()
	WG.metalSpots = GetSpots()
	WG.GetMexPositions = GetMexPositions
	WG.IsMexPositionValid = IsMexPositionValid
	widgetHandler:RemoveWidget(self)
end

------------------------------------------------------------
-- Shared functions
------------------------------------------------------------
function GetMexPositions(spot, uDefID, facing, testBuild)
	
	local positions = {}
	
	local xoff, zoff
	local uDef = UnitDefs[uDefID]
	if facing == 0 or facing == 2 then
		xoff = (4 * uDef.xsize) % 16
		zoff = (4 * uDef.zsize) % 16
	else
		xoff = (4 * uDef.zsize) % 16
		zoff = (4 * uDef.xsize) % 16
	end
	
	if not spot.validLeft then
		GetValidStrips(spot)
	end
	
	local validLeft = spot.validLeft
	local validRight = spot.validRight
	for z, vLeft in pairs(validLeft) do
		if z % 16 == zoff then
			for x = gridSize *  ceil((vLeft         + xoff) / gridSize) - xoff,
					gridSize * floor((validRight[z] + xoff) / gridSize) - xoff,
					gridSize do
				local y = spGetGroundHeight(x, z)
				if not (testBuild and spTestBuildOrder(uDefID, x, y, z, facing) == 0) then
					positions[#positions + 1] = {x, y, z}
				end
			end
		end
	end
	
	return positions
end

function IsMexPositionValid(spot, x, z)
	
	if z <= spot.maxZ - extractorRadius or
	   z >= spot.minZ + extractorRadius then -- Test for metal being included is dist < extractorRadius
		return false
	end
	
	local sLeft, sRight = spot.left, spot.right
	for sz = spot.minZ, spot.maxZ, gridSize do
		local dz = sz - z
		local maxXOffset = sqrt(extractorRadiusSqr - dz * dz) -- Test for metal being included is dist < extractorRadius
		if x <= sRight[sz] - maxXOffset or
		   x >= sLeft[sz] + maxXOffset then
			return false
		end
	end
	
	return true
end

------------------------------------------------------------
-- Mex finding
------------------------------------------------------------
function GetSpots()
	
	-- Main group collection
	local uniqueGroups = {}
	
	-- Strip info
	local nStrips = 0
	local stripLeft = {}
	local stripRight = {}
	local stripGroup = {}
	
	-- Indexes
	local aboveIdx
	local workingIdx
	
	-- Strip processing function (To avoid some code duplication)
	local function DoStrip(x1, x2, z, worth)
		
		local assignedTo
		
		for i = aboveIdx, workingIdx - 1 do
			if stripLeft[i] > x2 + gridSize then
				break
			elseif stripRight[i] + gridSize >= x1 then
				local matchGroup = stripGroup[i]
				if assignedTo then
					if matchGroup ~= assignedTo then
						for iz = matchGroup.minZ, assignedTo.minZ - gridSize, gridSize do
							assignedTo.left[iz] = matchGroup.left[iz]
						end
						for iz = matchGroup.minZ, matchGroup.maxZ, gridSize do
							assignedTo.right[iz] = matchGroup.right[iz]
						end
						if matchGroup.minZ < assignedTo.minZ then
							assignedTo.minZ = matchGroup.minZ
						end
						assignedTo.maxZ = z
						assignedTo.worth = assignedTo.worth + matchGroup.worth
						uniqueGroups[matchGroup] = nil
					end
				else
					assignedTo = matchGroup
					assignedTo.left[z] = assignedTo.left[z] or x1 -- Only accept the first
					assignedTo.right[z] = x2 -- Repeated overwrite gives us result we want
					assignedTo.maxZ = z -- Repeated overwrite gives us result we want
					assignedTo.worth = assignedTo.worth + worth
				end
			else
				aboveIdx = aboveIdx + 1
			end
		end
		
		nStrips = nStrips + 1
		stripLeft[nStrips] = x1
		stripRight[nStrips] = x2
		
		if assignedTo then
			stripGroup[nStrips] = assignedTo
		else
			local newGroup = {
					left = {[z] = x1},
					right = {[z] = x2},
					minZ = z,
					maxZ = z,
					worth = worth
				}
			stripGroup[nStrips] = newGroup
			uniqueGroups[newGroup] = true
		end
	end
	
	-- Strip finding
	workingIdx = huge
	for mz = metalmapStartX, metalmapSizeZ, gridSize do
		
		aboveIdx = workingIdx
		workingIdx = nStrips + 1
		
		local stripStart = nil
		local stripWorth = 0
		
		for mx = metalmapStartZ, metalmapSizeX, gridSize do
			local _, _, groundMetal = spGetGroundInfo(mx, mz)
			if groundMetal > 0 then
				stripStart = stripStart or mx
				stripWorth = stripWorth + groundMetal
			elseif stripStart then
				DoStrip(stripStart, mx - gridSize, mz, stripWorth)
				stripStart = nil
				stripWorth = 0
			end
		end
		
		if stripStart then
			DoStrip(stripStart, metalmapSizeX, mz, stripWorth)
		end
	end
	
	-- Final processing
	local spots = {}
	for g, _ in pairs(uniqueGroups) do
		
		local gMinX, gMaxX = huge, -1
		local gLeft, gRight = g.left, g.right
		for iz = g.minZ, g.maxZ, gridSize do
			if gLeft[iz] < gMinX then gMinX = gLeft[iz] end
			if gRight[iz] > gMaxX then gMaxX = gRight[iz] end
		end
		g.minX = gMinX
		g.maxX = gMaxX
		
		g.x = (gMinX + gMaxX) * 0.5
		g.z = (g.minZ + g.maxZ) * 0.5
		g.y = spGetGroundHeight(g.x, g.z)
		
		spots[#spots + 1] = g
	end
	return spots
end

function GetValidStrips(spot)
	
	local sMinZ, sMaxZ = spot.minZ, spot.maxZ
	local sLeft, sRight = spot.left, spot.right
	
	local validLeft = {}
	local validRight = {}
	
	local maxZOffset = buildGridSize * ceil(extractorRadius / buildGridSize - 1)
	for mz = max(sMaxZ - maxZOffset, buildmapStartZ), min(sMinZ + maxZOffset, buildmapSizeZ), buildGridSize do
		local vLeft, vRight = buildmapStartX, buildmapSizeX
		for sz = sMinZ, sMaxZ, gridSize do
			local dz = sz - mz
			local maxXOffset = buildGridSize * ceil(sqrt(extractorRadiusSqr - dz * dz) / buildGridSize - 1) -- Test for metal being included is dist < extractorRadius
			local left, right = sRight[sz] - maxXOffset, sLeft[sz] + maxXOffset
			if left  > vLeft  then vLeft  = left  end
			if right < vRight then vRight = right end
		end
		validLeft[mz] = vLeft
		validRight[mz] = vRight
	end
	
	spot.validLeft = validLeft
	spot.validRight = validRight
end
