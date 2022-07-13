
function widget:GetInfo()
	return {
		name      = "API Resource Spot Finder",
		desc      = "Finds metal and geothermal spots for other widgets",
		author    = "Niobium, Tarte (added geothermal)",
		version   = "2.0",
		date      = "November 2010: last update: April 13, 2022",
		license   = "GNU GPL, v2 or later",
		layer     = -99999999,
		enabled   = true
	}
end

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

local unitXoff = {}
local unitZoff = {}
for udefID, def in ipairs(UnitDefs) do
	unitXoff[udefID] = (4 * def.xsize) % 16
	unitZoff[udefID] = (4 * def.zsize) % 16
end

------------------------------------------------------------
-- Find geothermal spots
------------------------------------------------------------

local function GetFootprintPos(value)	-- not entirely acurate, unsure why
	local precision = 16		-- (footprint 1 = 16 map distance)
	return (math.floor(value/precision)*precision)+(precision/2)
end

local function GetSpotsGeo()
	local geoFeatureDefs = {}
	for defID, def in pairs(FeatureDefs) do
		if def.geoThermal then
			geoFeatureDefs[defID] = true
		end
	end
	geoSpots = {}
	local features = Spring.GetAllFeatures()
	local spotCount = 0
	for i = 1, #features do
		if geoFeatureDefs[Spring.GetFeatureDefID(features[i])] then
			local x, y, z = Spring.GetFeaturePosition(features[i])
			spotCount = spotCount + 1
			geoSpots[spotCount] = {
				x= GetFootprintPos(x),
				y=y,
				z= GetFootprintPos(z),
				minX= GetFootprintPos(x),
				maxX= GetFootprintPos(x),
				minZ= GetFootprintPos(z),
				maxZ= GetFootprintPos(z)
			}
		end
	end
	return geoSpots
end

------------------------------------------------------------
-- Shared functions
------------------------------------------------------------

local function GetValidStrips(spot)
	local sMinZ, sMaxZ = spot.minZ, spot.maxZ
	local sLeft, sRight = spot.left, spot.right
	local validLeft = {}
	local validRight = {}
	local maxZOffset = buildGridSize * ceil(extractorRadius / buildGridSize - 1)
	for mz = max(sMaxZ - maxZOffset, buildmapStartZ), min(sMinZ + maxZOffset, buildmapSizeZ), buildGridSize do
		local vLeft, vRight = buildmapStartX, buildmapSizeX
		if spot.left and spot.right then
			for sz = sMinZ, sMaxZ, gridSize do
				local dz = sz - mz
				local maxXOffset = buildGridSize * ceil(sqrt(extractorRadiusSqr - dz * dz) / buildGridSize - 1) -- Test for metal being included is dist < extractorRadius
				local left, right = sRight[sz] - maxXOffset, sLeft[sz] + maxXOffset
				if left  > vLeft  then vLeft  = left  end
				if right < vRight then vRight = right end
			end

		end
		validLeft[mz] = vLeft
		validRight[mz] = vRight
	end
	spot.validLeft = validLeft
	spot.validRight = validRight
end

local function GetBuildingPositions(spot, uDefID, facing, testBuild)
	local xoff, zoff
	if facing == 0 or facing == 2 then
		xoff = unitXoff[uDefID]
		zoff = unitZoff[uDefID]
	else
		xoff = unitZoff[uDefID]
		zoff = unitXoff[uDefID]
	end

	if not spot.validLeft then
		GetValidStrips(spot)
	end

	local positions = {}
	local validLeft = spot.validLeft
	local validRight = spot.validRight
	for z, vLeft in pairs(validLeft) do
		if z % 16 == zoff then
			for x = gridSize *  ceil((vLeft + xoff) / gridSize) - xoff,
				gridSize * floor((validRight[z] + xoff) / gridSize) - xoff,
				gridSize do
				local y = spGetGroundHeight(x, z)
				if not (testBuild and spTestBuildOrder(uDefID, x, y, z, facing) == 0) then
					positions[#positions + 1] = {x=x, y=y, z=z}
				end
			end
		end
	end

	return positions
end

local function IsBuildingPositionValid(spot, x, z)
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
-- Find metal spots
------------------------------------------------------------

local function GetSpotsMetal()

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

------------------------------------------------------------
-- Callins
------------------------------------------------------------

function widget:Initialize()
	--make interfaces available to other widgets:
	WG['resource_spot_finder'] = { }
	WG['resource_spot_finder'].metalSpotsList = GetSpotsMetal()

	WG['resource_spot_finder'].GetBuildingPositions = GetBuildingPositions
	WG['resource_spot_finder'].IsMexPositionValid = IsBuildingPositionValid
end

local firstUpdate = true
function widget:Update(dt)
	if firstUpdate then
		--GetSpotsGeo() uses Spring.GetAllFeatures() which is empty at the time of widget:Initialize
		WG['resource_spot_finder'].geoSpotsList = GetSpotsGeo()
		firstUpdate = false
	end
end
