
if not gadgetHandler:IsSyncedCode() then return end

function gadget:GetInfo()
	return {
		name      = "Metalspot Finder Gadget",
		desc      = "Finds metal spots",
		author    = "Niobium, modified by Google Frog",
		version   = "v1.1",
		date      = "November 2010",
		license   = "GNU GPL, v2 or later",
		layer     = -math.huge + 5,
		enabled   = true
	}
end

------------------------------------------------------------
-- Config
------------------------------------------------------------
local MAPSIDE_METALMAP = "mapconfig/map_metal_layout.lua"
local GAMESIDE_METALMAP = "LuaRules/Configs/MetalSpots/" .. (Game.mapName or "") .. ".lua"

local DEFAULT_MEX_INCOME = 2
local MINIMUN_MEX_INCOME = 0.2

local gridSize = 16 -- Resolution of metal map
local buildGridSize = 8 -- Resolution of build positions

local METAL_MAP_SQUARE_SIZE = 16
local MEX_RADIUS = Game.extractorRadius
local MAP_SIZE_X = Game.mapSizeX
local MAP_SIZE_X_SCALED = MAP_SIZE_X / METAL_MAP_SQUARE_SIZE
local MAP_SIZE_Z = Game.mapSizeZ
local MAP_SIZE_Z_SCALED = MAP_SIZE_Z / METAL_MAP_SQUARE_SIZE

local gameConfig = VFS.FileExists(GAMESIDE_METALMAP) and VFS.Include(GAMESIDE_METALMAP) or false
local mapConfig = VFS.FileExists(MAPSIDE_METALMAP) and VFS.Include(MAPSIDE_METALMAP) or false

------------------------------------------------------------
-- Speedups
------------------------------------------------------------
local min, max = math.min, math.max
local floor, ceil = math.floor, math.ceil
local sqrt = math.sqrt
local huge = math.huge

local spGetGroundInfo     = Spring.GetGroundInfo
local spGetGroundHeight   = Spring.GetGroundHeight
local spSetGameRulesParam = Spring.SetGameRulesParam

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
-- Variables
------------------------------------------------------------

local modOptions
if (Spring.GetModOptions) then
  modOptions = Spring.GetModOptions()
end


------------------------------------------------------------
-- Speedup
------------------------------------------------------------
local function GetSpotsByPos(spots)
	local spotPos = {}
	for i = 1, #spots do
		local spot = spots[i]
		local x = spot.x
		local z = spot.z
		--Spring.MarkerAddPoint(x,0,z,x .. ", " .. z)
		spotPos[x] = spotPos[x] or {}
		spotPos[x][z] = i
	end
	return spotPos
end

------------------------------------------------------------
-- Set Game Rules so widgets can read metal spots
------------------------------------------------------------
local function SetMexGameRulesParams(metalSpots)
	if not metalSpots then -- Mexes can be built anywhere
		spSetGameRulesParam("mex_count", -1)
		return
	end
	
	local mexCount = #metalSpots
	spSetGameRulesParam("mex_count", mexCount)
	
	for i = 1, mexCount do
		local mex = metalSpots[i]
		spSetGameRulesParam("mex_x" .. i, mex.x)
		spSetGameRulesParam("mex_y" .. i, mex.y)
		spSetGameRulesParam("mex_z" .. i, mex.z)
		spSetGameRulesParam("mex_metal" .. i, mex.metal)
	end
end

------------------------------------------------------------
-- Callins
------------------------------------------------------------
function gadget:Initialize()
	Spring.Log(gadget:GetInfo().name, LOG.INFO, "Mex Spot Finder Initialising")
	Spring.SetGameRulesParam("base_extraction", 0.001)
	local metalSpots, fromEngineMetalmap = GetSpots()
	local metalSpotsByPos = false
	
	if fromEngineMetalmap and #metalSpots < 6 then
		Spring.Log(gadget:GetInfo().name, LOG.INFO, "Indiscrete metal map detected")
		metalSpots = false
	end
	
	local metalValueOverride = gameConfig and gameConfig.metalValueOverride
	
	if metalSpots then
		local mult = (modOptions and modOptions.metalmult) or 1
		local i = 1
		while i <= #metalSpots do
			local spot = metalSpots[i]
			if spot.metal > MINIMUN_MEX_INCOME then
				if metalValueOverride then
					spot.metal = metalValueOverride
				end
				spot.metal = spot.metal*mult
				i = i + 1
			else
				metalSpots[i] = metalSpots[#metalSpots]
				metalSpots[#metalSpots] = nil
			end
		end
		
		metalSpotsByPos = GetSpotsByPos(metalSpots)
	end
	
	SetMexGameRulesParams(metalSpots)

	GG.metalSpots = metalSpots
	GG.metalSpotsByPos = metalSpotsByPos
	
	GG.IntegrateMetal = IntegrateMetal
	
	Spring.Log(gadget:GetInfo().name, LOG.INFO, "Metal Spots found and GGed")
end

------------------------------------------------------------
-- Extractor Income Processing
------------------------------------------------------------

function IntegrateMetal(x, z, radius)
	local centerX, centerZ
	
	radius = radius or MEX_RADIUS
	
	centerX = (floor( x / METAL_MAP_SQUARE_SIZE) + 0.5) * METAL_MAP_SQUARE_SIZE
	centerZ = (floor( z / METAL_MAP_SQUARE_SIZE) + 0.5) * METAL_MAP_SQUARE_SIZE
	
	local startX = floor((centerX - radius) / METAL_MAP_SQUARE_SIZE)
	local startZ = floor((centerZ - radius) / METAL_MAP_SQUARE_SIZE)
	local endX = floor((centerX + radius) / METAL_MAP_SQUARE_SIZE)
	local endZ = floor((centerZ + radius) / METAL_MAP_SQUARE_SIZE)
	startX, startZ = max(startX, 0), max(startZ, 0)
	endX, endZ = min(endX, MAP_SIZE_X_SCALED - 1), min(endZ, MAP_SIZE_Z_SCALED - 1)
	
	local mult = Spring.GetGameRulesParam("base_extraction")
	local result = 0
	
	for i = startX, endX do
		for j = startZ, endZ do
			local cx, cz = (i + 0.5) * METAL_MAP_SQUARE_SIZE, (j + 0.5) * METAL_MAP_SQUARE_SIZE
			local dx, dz = cx - centerX, cz - centerZ
			local dist = sqrt(dx * dx + dz * dz)

			if (dist < radius) then
				result = result + select(3, spGetGroundInfo(cx, cz))
			end
		end
	end
	
	return result * mult, centerX, centerZ
end

------------------------------------------------------------
-- Mex finding
------------------------------------------------------------
local function SanitiseSpots(spots, metalValueOverride)
	local i = 1
	while i <= #spots do
		local spot = spots[i]
		if spot and spot.x and spot.z then
			local metal
			metal, spot.x, spot.z = IntegrateMetal(spot.x, spot.z)
			spot.y = spGetGroundHeight(spot.x, spot.z)
			spot.metal = spot.metal or metalValueOverride or (metal > 0 and metal) or DEFAULT_MEX_INCOME
			i = i + 1
		else
			spot[i] = spot[#spots]
			spot[#spots] = nil
		end
	end
	
	return spots
end

local function makeString(group)
	if group then
		local ret = ""
		for i, v in pairs(group.left) do
			ret = ret .. i .. v
		end
		ret = ret .. " "
		for i, v in pairs(group.right) do
			ret = ret .. i .. v
		end
		ret = ret .. " " .. group.minZ .. " " .. group.maxZ .. " " .. group.worth
		return ret
	else
		return ""
	end
end

function GetSpots()
	
	local spots = {}

	-- Check configs
	if gameConfig then
		Spring.Log(gadget:GetInfo().name, LOG.INFO, "Loading gameside mex config")
		if gameConfig.spots then
			spots = SanitiseSpots(gameConfig.spots, gameConfig.metalValueOverride)
			return spots, false
		end
	end
	
	if mapConfig then
		Spring.Log(gadget:GetInfo().name, LOG.INFO, "Loading mapside mex config")
		loadConfig = true
		spots = SanitiseSpots(mapConfig.spots, mapConfig.metalValueOverride)
		return spots, false
	end
	
	Spring.Log(gadget:GetInfo().name, LOG.INFO, "Detecting mex config from metalmap")

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
						uniqueGroups[makeString(matchGroup)] = nil
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
			uniqueGroups[makeString(newGroup)] = newGroup
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
			local _,_, groundMetal = spGetGroundInfo(mx, mz)
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
	for _, g in pairs(uniqueGroups) do
		local d = {}
		
		local gMinX, gMaxX = huge, -1
		local gLeft, gRight = g.left, g.right
		for iz = g.minZ, g.maxZ, gridSize do
			if gLeft[iz] < gMinX then gMinX = gLeft[iz] end
			if gRight[iz] > gMaxX then gMaxX = gRight[iz] end
		end
		local x = (gMinX + gMaxX) * 0.5
		local z = (g.minZ + g.maxZ) * 0.5
		
		d.metal, d.x, d.z = IntegrateMetal(x,z)
		
		d.y = spGetGroundHeight(d.x, d.z)
		
		local merged = false
		
		for i = 1, #spots do
			local spot = spots[i]
			local dis = (d.x - spot.x)^2 + (d.z - spot.z)^2
			if dis < extractorRadiusSqr*4 then
				local metal, mx, mz = IntegrateMetal((d.x + spot.x) * 0.5, (d.z + spot.z) * 0.5)
				
				if dis < extractorRadiusSqr*1.7 or metal > (d.metal + spot.metal)*0.95 then
					spot.x = mx
					spot.y = spGetGroundHeight(mx, mx)
					spot.z = mz
					spot.metal = metal
					merged = true
					break
				end
			end
		end
		
		if not merged then
			spots[#spots + 1] = d
		end
	end
	
	--for i = 1, #spots do
	--	Spring.MarkerAddPoint(spots[i].x,spots[i].y,spots[i].z,"")
	--end
	
	return spots, true
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

