MetalSpotHandler = class(Module)


function MetalSpotHandler:Name()
	return "MetalSpotHandler"
end

function MetalSpotHandler:internalName()
	return "metalspothandler"
end

function MetalSpotHandler:Init()
	self.spots = self.game.map:GetMetalSpots()
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
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
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

function GetValidStrips(spot)
		spot.left = {}
	spot.right = {}
	spot.minX = spot.x - 16
	spot.minZ = spot.z - 16
	spot.maxX = spot.x + 16
	spot.maxZ = spot.z + 16
	
	for iz = spot.minZ, spot.maxZ do
		spot.left[iz] = spot.minX
		spot.right[iz] = spot.maxX
	end
	
	
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


function distance(pos1,pos2)
	local xd = pos1.x-pos2.x
	local zd = pos1.z-pos2.z
	local yd = pos1.y-pos2.y
	if yd < 0 then
		yd = -yd
	end
	dist = math.sqrt(xd*xd + zd*zd + yd*yd*yd)
	return dist
end
function NoMex(x,z, batchextracts,teamID) -- Is there any better mex at this location (returns false if there is)
	local mexesatspot = Spring.GetUnitsInCylinder(x,z, Game.extractorRadius+16)
		for ct, uid in pairs(mexesatspot) do
			if UnitDefs[Spring.GetUnitDefID(uid)].extractsMetal >= batchextracts and (teamID and Spring.AreTeamsAllied(Spring.GetUnitTeam(uid), teamID)) then
				return false
			end	
		end
	return true
end

function EnemyMex(x,z, batchextracts,teamID) -- Is there any better mex at this location (returns false if there is)
	local mexesatspot = Spring.GetUnitsInCylinder(x,z, Game.extractorRadius+16)
		for ct, uid in pairs(mexesatspot) do
			if UnitDefs[Spring.GetUnitDefID(uid)].extractsMetal > 0 and (teamID and not Spring.AreTeamsAllied(Spring.GetUnitTeam(uid), teamID)) then
				return true
			end	
		end
	return false
end

function MetalSpotHandler:ClosestFreeSpot(unittype,position,maxdis)
    local pos = nil
    local bestDistance = maxdis or 100000
    spotCount = self.game.map:SpotCount()
	local teamID = self.ai.id
    for i,v in ipairs(self.spots) do
        local p = v
        local dist = distance(position,p)
        if NoMex(p.x, p.z, UnitDefs[unittype.id].extractsMetal, teamID) == true then
		    if dist < bestDistance then
                bestDistance = dist
                pos = p
            end
        end
    end
    return pos
end

function MetalSpotHandler:ClosestEnemySpot(unittype,position)
    local pos = nil
    local bestDistance = 100000
    spotCount = self.game.map:SpotCount()
	local teamID = self.ai.id
    for i,v in ipairs(self.spots) do
        local p = v
        local dist = distance(position,p)
        if EnemyMex(p.x, p.z, UnitDefs[unittype.id].extractsMetal, teamID) == true then
		    if dist < bestDistance then
                bestDistance = dist
                pos = p
            end
        end
    end
    return pos
end

function MetalSpotHandler:GetClosestMexPosition(spot, x, z, uDefID, facing)
	x, z = spot.x + 200, spot.z + 200 
	local bestPos
	local bestDist = math.huge
	local positions = GetMexPositions(spot, uDefID, facing, true)
	for i = 1, #positions do
		local pos = positions[i]
		local dx, dz = x - pos[1], z - pos[3]
		local dist = dx*dx + dz*dz
		if dist < bestDist then
			bestPos = pos
			bestDist = dist
		end
	end
	if bestPos then bestPos = {x = bestPos[1], y = bestPos[2], z = bestPos[3]} end
	return bestPos
end
