local upget = gadget or widget ---@type Addon
local globalScope = gadget and GG or WG

-- gadget side must be layered after gadgets/map_metal_spot_placer.lua
-- so that it works with maps with side-configured metal spots
local layer = gadget and -9 or -999999

function upget:GetInfo()
	return {
		name = "API Resource Spot Finder (mex/geo)",
		desc = "Finds metal and geothermal spots for other upgets",
		author = "Niobium, Tarte (added geothermal)",
		version = "2.0",
		date = "November 2010: last update: April 13, 2022",
		license = "GNU GPL, v2 or later",
		layer = layer,
		enabled = true,
	}
end

if gadget then
	if not gadgetHandler:IsSyncedCode() then
		return
	end
end

local metalMapSquareSize = Game.metalMapSquareSize -- Resolution of metal map
local squareSize = Game.squareSize -- Resolution of build positions
local precision = Game.footprintScale * Game.squareSize -- (footprint 1 = 16 map distance)

-- Some of these maps have more than 2 metal spots, disable mex denier
local metalMaps = {
	["Oort_Cloud_V2"] = true,
	["Asteroid_Mines_V2.1"] = true,
	["Cloud9_V2"] = true,
	["Iron_Isle_V1"] = true,
	["Nine_Metal_Islands_V1"] = true,
	["SpeedMetal BAR V2"] = true,
}
local isMetalMap = false

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
local spSetGameRulesParam = Spring.SetGameRulesParam

local extractorRadius = Game.extractorRadius
local extractorRadiusSqr = extractorRadius * extractorRadius

local buildmapSizeX = Game.mapSizeX - squareSize
local buildmapSizeZ = Game.mapSizeZ - squareSize
local buildmapStartX = squareSize
local buildmapStartZ = squareSize

local metalmapSizeX = Game.mapSizeX - 1.5 * metalMapSquareSize
local metalmapSizeZ = Game.mapSizeZ - 1.5 * metalMapSquareSize
local metalmapStartX = 1.5 * metalMapSquareSize
local metalmapStartZ = 1.5 * metalMapSquareSize

local unitXoff = {}
local unitZoff = {}
for udefID, def in ipairs(UnitDefs) do
	unitXoff[udefID] = (4 * def.xsize) % 16
	unitZoff[udefID] = (4 * def.zsize) % 16
end

local metalSpots
local geoSpots

------------------------------------------------------------
-- Find geothermal spots
------------------------------------------------------------

local function GetFootprintPos(value) -- not entirely acurate, unsure why
	return (math.round(value / precision) * precision)
end

local function getClosestGeo(x, z)
	return math.getClosestPosition(x, z, geoSpots)
end

local function GetSpotsGeo()
	local geoFeatureDefs = {}
	for defID, def in pairs(FeatureDefs) do
		if def.geoThermal then
			geoFeatureDefs[defID] = true
		end
	end
	local spots = {}
	local features = Spring.GetAllFeatures()
	local spotCount = 0
	for i = 1, #features do
		if geoFeatureDefs[Spring.GetFeatureDefID(features[i])] then
			local x, y, z = Spring.GetFeaturePosition(features[i])
			spotCount = spotCount + 1
			spots[spotCount] = {
				isGeo = true,
				x = GetFootprintPos(x),
				y = y,
				z = GetFootprintPos(z),
				minX = GetFootprintPos(x) - (precision / 2),
				maxX = GetFootprintPos(x) + (precision / 2),
				minZ = GetFootprintPos(z) - (precision / 2),
				maxZ = GetFootprintPos(z) + (precision / 2),
			}
		end
	end
	return spots
end

------------------------------------------------------------
-- Shared functions
------------------------------------------------------------

local function GetValidStrips(spot)
	local sMinZ, sMaxZ = spot.minZ, spot.maxZ
	local sLeft, sRight = spot.left, spot.right
	local validLeft = {}
	local validRight = {}
	local maxZOffset = squareSize * ceil(extractorRadius / squareSize - 1)
	for mz = max(sMaxZ - maxZOffset, buildmapStartZ), min(sMinZ + maxZOffset, buildmapSizeZ), squareSize do
		local vLeft, vRight = buildmapStartX, buildmapSizeX
		if spot.left and spot.right then
			for sz = sMinZ, sMaxZ, metalMapSquareSize do
				local dz = sz - mz
				local maxXOffset = squareSize * ceil(sqrt(extractorRadiusSqr - dz * dz) / squareSize - 1) -- Test for metal being included is dist < extractorRadius
				local left, right = sRight[sz] - maxXOffset, sLeft[sz] + maxXOffset
				if left > vLeft then
					vLeft = left
				end
				if right < vRight then
					vRight = right
				end
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
			for x = metalMapSquareSize * ceil((vLeft + xoff) / metalMapSquareSize) - xoff, metalMapSquareSize * floor((validRight[z] + xoff) / metalMapSquareSize) - xoff, metalMapSquareSize do
				local y = spGetGroundHeight(x, z)
				if not (testBuild and spTestBuildOrder(uDefID, x, y, z, facing) == 0) then
					positions[#positions + 1] = { x = x, y = y, z = z }
				end
			end
		end
	end

	return positions
end


local function IsBuildingPositionValid(spot, x, z)
	if z <= spot.maxZ - extractorRadius or z >= spot.minZ + extractorRadius then -- Test for metal being included is dist < extractorRadius
		return false
	end

	local sLeft, sRight = spot.left, spot.right
	for sz = spot.minZ, spot.maxZ, metalMapSquareSize do
		local dz = sz - z
		local maxXOffset = sqrt(extractorRadiusSqr - dz * dz) -- Test for metal being included is dist < extractorRadius
		if x <= sRight[sz] - maxXOffset or x >= sLeft[sz] + maxXOffset then
			return false
		end
	end

	return true
end

------------------------------------------------------------
-- Find metal spots
------------------------------------------------------------

local function setMexGameRules(spots)
	-- Set gamerules values for mex spots, used by AI
	if spots and #spots > 0 then
		local mexCount = #spots
		spSetGameRulesParam("mex_count", mexCount)

		for i = 1, mexCount do
			local mex = spots[i]
			spSetGameRulesParam("mex_x" .. i, mex.x)
			spSetGameRulesParam("mex_y" .. i, mex.y)
			spSetGameRulesParam("mex_z" .. i, mex.z)
			spSetGameRulesParam("mex_metal" .. i, mex.worth)
		end
	else
		Spring.SetGameRulesParam("mex_count", -1)
	end
end

---Returns the nearest mex spot to the given coordinates. Does not consider if the spot is taken
---@param x table
---@param z table
local function getClosestMex(x, z)
	return math.getClosestPosition(x, z, metalSpots)
end

local function GetSpotsMetal()
	-- Main group collection
	local uniqueGroups = {}

	-- Strip info
	local nStrips = 0
	local stripLeft = {}
	local stripRight = {}
	local stripGroup = {}
	local maxStripLength = extractorRadius * 6

	-- Indexes
	local aboveIdx
	local workingIdx

	-- Strip processing function (To avoid some code duplication)
	local function DoStrip(x1, x2, z, worth)
		local assignedTo

		for i = aboveIdx, workingIdx - 1 do
			if stripLeft[i] > x2 + metalMapSquareSize then
				break
			elseif stripRight[i] + metalMapSquareSize >= x1 then
				local matchGroup = stripGroup[i]
				if assignedTo then
					if matchGroup ~= assignedTo then
						for iz = matchGroup.minZ, assignedTo.minZ - metalMapSquareSize, metalMapSquareSize do
							assignedTo.left[iz] = matchGroup.left[iz]
						end
						for iz = matchGroup.minZ, matchGroup.maxZ, metalMapSquareSize do
							assignedTo.right[iz] = matchGroup.right[iz]
						end
						if matchGroup.minZ < assignedTo.minZ then
							assignedTo.minZ = matchGroup.minZ
						end
						assignedTo.maxZ = z
						assignedTo.worth = assignedTo.worth + matchGroup.worth
						table.removeFirst(uniqueGroups, matchGroup)
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
				left = { [z] = x1 },
				right = { [z] = x2 },
				minZ = z,
				maxZ = z,
				worth = worth,
			}
			stripGroup[nStrips] = newGroup
			table.insert(uniqueGroups, newGroup)
		end
	end

	-- Strip finding
	workingIdx = huge
	for mz = metalmapStartX, metalmapSizeZ, metalMapSquareSize do
		aboveIdx = workingIdx
		workingIdx = nStrips + 1

		local stripStart = nil
		local stripWorth = 0

		for mx = metalmapStartZ, metalmapSizeX, metalMapSquareSize do
			local _, _, groundMetal = spGetGroundInfo(mx, mz)
			if groundMetal > 0 then
				stripStart = stripStart or mx
				stripWorth = stripWorth + groundMetal
			elseif stripStart then
				DoStrip(stripStart, mx - metalMapSquareSize, mz, stripWorth)
				stripStart = nil
				stripWorth = 0
			end
		end

		if stripStart then
			DoStrip(stripStart, metalmapSizeX, mz, stripWorth)
		end
	end

	-- Final processing
	-- armmex used as representative unit for placement checking, since all metal extractors are the same size
	local uDefID = UnitDefNames["armmex"].id
	local spots = {}
	for _, g in ipairs(uniqueGroups) do
		local gMinX, gMaxX = huge, -1
		local gLeft, gRight = g.left, g.right
		for iz = g.minZ, g.maxZ, metalMapSquareSize do
			if gLeft[iz] < gMinX then
				gMinX = gLeft[iz]
			end
			if gRight[iz] > gMaxX then
				gMaxX = gRight[iz]
			end
		end
		g.minX = gMinX
		g.maxX = gMaxX

		g.x = (gMinX + gMaxX) * 0.5
		g.z = (g.minZ + g.maxZ) * 0.5
		g.y = spGetGroundHeight(g.x, g.z)

		g.isMex = true

		spots[#spots + 1] = g

		if gMaxX - gMinX > maxStripLength or g.maxZ - g.minZ > maxStripLength then
			return false, true
		end

		local positions = GetBuildingPositions(g, uDefID, 0, false)
		local pos = positions[floor(#positions / 2 + 1)]
		g.x = pos.x
		g.y = pos.y
		g.z = pos.z
	end

	--for i = 1, #spots do
	--	Spring.MarkerAddPoint(spots[i].x,spots[i].y,spots[i].z,"")
	--end

	return spots, false
end



------------------------------------------------------------
-- Callins
------------------------------------------------------------

function upget:Initialize()
	if(gadget) then
		-- With armmex.extractsMetal=0.001 and armmoho.extractsMetal=0.004
		-- base_extraction=0.001 is meant to say that T1 mex is baseline x1, and T2 is baseline x4
		-- as opposed to T1 being x0.5 and T2 being x2.
		-- Unused now.
		Spring.SetGameRulesParam("base_extraction", 1.0)
	end

	if metalMaps[Game.mapName] then
		metalSpots, isMetalMap = false, true
	else
		metalSpots, isMetalMap = GetSpotsMetal()
	end

	geoSpots = GetSpotsGeo()
	globalScope["resource_spot_finder"] = {}
	globalScope["resource_spot_finder"].metalSpotsList = metalSpots
	globalScope["resource_spot_finder"].geoSpotsList = geoSpots
	globalScope["resource_spot_finder"].isMetalMap = isMetalMap
	globalScope["resource_spot_finder"].GetClosestMexSpot = getClosestMex
	globalScope["resource_spot_finder"].GetClosestGeoSpot = getClosestGeo
	globalScope["resource_spot_finder"].GetBuildingPositions = GetBuildingPositions
	globalScope["resource_spot_finder"].IsMexPositionValid = IsBuildingPositionValid

	if(gadget) then
		setMexGameRules(metalSpots)
	end
end
