MapHST = class(Module)

function MapHST:Name()
	return "MapHST"
end

function MapHST:internalName()
	return "maphst"
end

local pathGraphs = {}

local mCeil = math.ceil





function MapHST:Init()
	self:EchoDebug('MapHST START')
	self.DebugEnabled = true
	self.lastDataResetFrame = 0
	self:basicMapInfo()
	self.GRID = {}
	self.activeMobTypes = {}
	self.ai.factoryListMap = {}
	self.lastDataResetFrame = self.game:Frame()
	self.ai.armyhst.UWMetalSpotCheckUnitType = self.game:GetTypeByName(self.ai.armyhst.UWMetalSpotCheckUnit)
	self.mobilityUnitTypes = {}
	self.topology = nil
	self.mobilityMap = {}
	self.mobilityNetworkMetals = {}
	self.mobilityNets = {}
	self.mobilityRatingFloor = nil
	self.mobilityRating = {}
	self.mobilityCount ={}
	self.scoutSpots = {}
	self.hotSpots = {}

	self.UWMetalSpots = {}
	self.landMetalSpots = {}
	self.metalSpots = map:GetMetalSpots()
	self.geoSpots = map:GetGeoSpots()
	if #self.metalSpots > 1024 then-- metal map is too complex, simplify it
		self.metalSpots = self:SimplifyMetalSpots(self.metalSpots, self.gridSize * 2)-- is a random choice, can be 1 or 9999999999
	end
	self:SpotSimplyfier(self.metalSpots,self.geoSpots)
	for mtype, unames in pairs(self.ai.armyhst.mobUnitNames) do
		self.mobilityUnitTypes[mtype] = {}
		for i, uname in pairs(unames) do
			self.mobilityUnitTypes[mtype][i] = self.game:GetTypeByName(uname)
			print(self.mobilityUnitTypes[mtype][i],self.ai.armyhst.defId)
		end
	end

	self:InitializeTopology()
	self:MapMobility()
	self:MapSpotMobility(self.metalSpots, self.geoSpots)

	self:EchoDebug("total sectors "..self.gridArea)-- now let's see how much water we found
	local wetness = self.mobilityCount["sub"] * 100 / self.gridArea
	self:EchoDebug("map wetness is "..wetness)
	self.waterMap = wetness >= 10
	self:EchoDebug("there is water on the map")
	for mtype, count in pairs(self.mobilityCount) do
		local ness = count * 100 / self.gridArea
		self:EchoDebug("map " .. mtype .. "-ness is " .. ness .. " and total grids: " .. count)
	end


	self:spotPathMobRank(self.scoutSpots.air[1])
	self:EchoDebug('self.spotPathMobRank',self.spotPathMobRank)
	for mtype, mspots in pairs(self.mobSpots) do
		self:EchoDebug('mtype-spots-#spots',mtype .. " spots: " .. #mspots)
	end
	-- self:EchoDebug(" spots sub:" .. #self.mobSpots["sub"] .. " bot:" .. #self.mobSpots["bot"] .. " veh:" .. #self.mobSpots["veh"])
	for mtype, utypes in pairs(self.mobilityUnitTypes) do
		self:EchoDebug(mtype .. "  networks: " .. self.mobilityNets[mtype])
		for n, count in pairs(self.mobNetworkCount[mtype]) do
			self:EchoDebug("network #" .. n .. " has " .. count .. " spots and " .. self.networkSize[mtype][n] .. " grids")
		end
	end
	-- deciding what kind of map it is
	local maxSpots = 0
	local minNetworks = 5
	local best = nil
	local totalRating = 0
	local numberOfRatings = 0
	for mtype, spots in pairs(self.mobSpots) do
		if #spots > maxSpots then
			if self.mobilityNets[mtype] < minNetworks then
				maxSpots = #spots
				minNetworks = self.mobilityNets[mtype]
				best = mtype
			end
		end
		local mostGrids = 0
		local mostSpots = 0
		if self.networkSize[mtype] ~= nil then
			for n, size in pairs(self.networkSize[mtype]) do
				if size > mostGrids and #self.scoutSpots[mtype][n] > mostSpots then
					mostGrids = size
					mostSpots = #self.scoutSpots[mtype][n]
				end
			end
		end
		if self.mobilityNets[mtype] == 0 then
			self.mobilityRating[mtype] = 0
		else
			self.mobilityRating[mtype] = ((mostSpots - self.mobilityNets[mtype]) + ((mostGrids / self.gridArea) * mostSpots * 0.25))
		end
		totalRating = totalRating + self.mobilityRating[mtype]
		numberOfRatings = numberOfRatings + 1
		self:EchoDebug(mtype .. " rating: " .. self.mobilityRating[mtype])
	end
	-- add in bechmark air rating
	-- local airRating = (#self.scoutSpots["air"][1] + (#self.scoutSpots["air"][1] * 0.25)) * 0.5
	local airRating = #self.scoutSpots["air"][1] + (#self.scoutSpots["air"][1] * 0.25)
	self.mobilityRating['air'] = airRating
	totalRating = totalRating + airRating
	numberOfRatings = numberOfRatings + 1
	self:EchoDebug('air rating: ' .. airRating)
	local avgRating = totalRating / numberOfRatings
	local ratingFloor = avgRating * 0.65
	self:EchoDebug('average rating: ' .. avgRating)
	self:EchoDebug('rating floor: ' .. ratingFloor)
	self.mobilityRatingFloor = ratingFloor
	self.hasUWSpots = #self.mobSpots["sub"] > 0
	if self.hasUWSpots then
		self:EchoDebug("MapHST: Submerged metal spots detected")
	end
	-- find start locations (loading them into air's list for later localization)
	self.ai.startLocations = {}
	if self.ai.startLocations["air"] == nil then self.ai.startLocations["air"] = {} end
	self.ai.startLocations["air"][1] = self:GuessStartLocations(self.metalSpots)
	if self.ai.startLocations["air"][1] ~= nil then
		-- localize start locations into mobility networks
		for i, start in pairs(self.ai.startLocations["air"][1]) do
			self:EchoDebug("start location guessed at: " .. start.x .. ", " .. start.z)
			for mtype, networkList in pairs(self.scoutSpots) do
				if mtype ~= "air" then -- air list is already filled
					for n, spots in pairs(networkList) do
						if self.ai.startLocations[mtype] == nil then self.ai.startLocations[mtype] = {} end
						if self.ai.startLocations[mtype][n] == nil then self.ai.startLocations[mtype][n] = {} end
						table.insert(self.ai.startLocations[mtype][n], start)
					end
				end
			end
		end
	end
	-- cleanup
	self.mobilityMap = nil
-- 	self.ai.factoriesRanking, self.ai.ranksByFactories = self:factoriesRating()
	self:DrawDebug()
    self:EchoDebug('MapHST STOP')
end



function MapHST:NewCell(px, pz)
	local x = px * self.elmoMapSizeX - gridSizeHalf
	local z = pz * self.elmoMapSizeZ - gridSizeHalf
	local cellPos = {}
	cellPos.x, cellPos.z = x, z
	cellPos.y = Spring.GetGroundHeight(x, z)
	self.ai.buildsitehst:isInMap(cellPos)--move here ,is in map!!

	local cell = {}
	cell.P = cellPos
	cell.X = px
	cell.Z = pz
	self.GRID[X][Z] = cell
end

function MapHST:createGrid()
	for x = 1, self.mapSize.x / self.gridSize do
		if not self.GRID[x] then
			self.GRID[x] = {}
		end
		for z = 1, self.mapSize.z / self.gridSize do
			self:NewCell(x,z)
		end
	end
end

function MapHST:basicMapInfo()
	self.mapSize = self.map:MapDimensions()
	self.elmoMapSizeX = self.mapSize.x * 8
	self.elmoMapSizeZ = self.mapSize.z * 8
	self.elmoArea = self.elmoMapSizeX * self.elmoMapSizeZ
	self.gridSize = 256 --math.max( math.floor(math.max(MapHST.mapSize.x * 8, MapHST.mapSize.z * 8) / 128),32)-- don't make grids smaller than 32
	self.gridSizeHalf = self.gridSize/ 2
	self.gridArea = self.mapSize.x * self.mapSize.z
	self:EchoDebug("grid size: " .. self.gridSize)
end

function MapHST:SpotSimplyfier(metalSpots,geosSpots)
	local spots = {}
	local mirrorspots = {}
	local limit = (self.map:MapDimensions())
	local limit = limit.x/2  + limit.z/2
	for i,v in pairs(metalSpots) do
		table.insert(spots,v)
	end
	for i,v in pairs(geosSpots) do
		table.insert(spots,v)
	end
	self:EchoDebug('limit',tostring(limit))
	for index1,pos1 in pairs(spots) do
		if spots[index1]  then
			mirrorspots[index1] = {}
			table.insert(mirrorspots[index1],pos1)
			spots[index1] = false
			for index2,pos2 in pairs(spots) do
				if spots[index2] and pos1 ~= pos2 then
					local dist = self.ai.tool:distance(pos1,pos2)
					if dist < limit  and ((pos1.y > 0 and pos2.y > 0) or (pos1.y < 0 and pos2.y < 0)) then
						table.insert(mirrorspots[index1],pos2)
						spots[index2] = false
					end
				end

			end
		end

	end
	for i,v in pairs(mirrorspots) do
		local items = 0
		local x = 0
		local z = 0
		local y = 0
		for ii,vv in pairs(v) do
			items = items+1
			x = x + vv.x
			z = z + vv.z

		end
		x = x / items
		z = z / items
		y = Spring.GetGroundHeight(x,z)
		table.insert(self.hotSpots,{x=x,y=y,z=z,weight = items})
		--Spring.MarkerAddPoint(x,y,z,'hot ' ..items	)
	end
end

function MapHST:DrawDebug()
	local ch = 1
	self.map:EraseAll(ch)
	if not self.ai.drawDebug then
		return
	end
	local colours={
			red = {1,0,0,1},--'red'
			green = {0,1,0,1},--'green'
			blue = {0,0,1,1},--'blue'
			yellow = {0,1,1,1},
			pink = {1,1,0,1},
			white = {1,1,1,1},
			black = {0,0,0,1},

			}
	for i,p in pairs (self.hotSpots) do
		map:DrawPoint(p, green, i,  ch)
	end
	for i,p in pairs (self.metalSpots) do
		map:DrawPoint(p, white, i,  ch)
	end
	for i,p in pairs (self.geoSpots) do
		map:DrawPoint(p, white, i,  ch)
	end
end

function MapHST:MapMobility()
	for mtype, utypes in pairs(self.mobilityUnitTypes) do
		self.mobilityMap[mtype] = {}
		self.mobilityCount[mtype] = 0
	end
	for x = 1, self.mapSize.x do
		for mtype, utypes in pairs(self.mobilityUnitTypes) do
			self.mobilityMap[mtype][x] = {}
		end
		for z = 1, self.mapSize.z do
			-- all blocked unless unblocked below
			for mtype, utypes in pairs(self.mobilityUnitTypes) do
				self.mobilityMap[mtype][x][z] = 1
			end
			pos = {}
			pos.x = (x * self.gridSize) - self.gridSizeHalf
			pos.z = (z * self.gridSize) - self.gridSizeHalf
			-- find out if each mobility type can exist there
			for mtype, utypes in pairs(self.mobilityUnitTypes) do
				local canMoveHere = false
				local uname = self.ai.armyhst.mobUnitExampleName[mtype]
				local uDef = UnitDefNames[uname]
				canMoveHere = Spring.TestMoveOrder(uDef.id, pos.x, Spring.GetGroundHeight(pos.x,pos.z), pos.z)
				if canMoveHere then
					-- self:EchoDebug(mtype .. " at " .. x .. "," .. z .. " count " .. mobilityCount[mtype])
					self.mobilityCount[mtype] = self.mobilityCount[mtype] + 1
					self.mobilityMap[mtype][x][z] = 0
				end
			end
			-- self:EchoDebug(x .. "," .. z .. " sub " .. subMap[x][z] .. " bot " .. botMap[x][z] .. " veh " .. vehMap[x][z])
		end
	end
end

function MapHST:SimplifyMetalSpots(metalSpots, number)
	local divisor = math.ceil(math.sqrt(number))
	local spots = {}
	local spotsCount = 0
	for x = 0, self.elmoMapSizeX - number, number do
		for z = 0, self.elmoMapSizeX - number, number do
			for i,spot in pairs (self.metalSpots) do--i = 1, #metalSpots do
				if spot.x > x and spot.x < x + number and spot.z > z and spot.z < z + number then
					spotsCount = spotsCount + 1
					spots[spotsCount] = spot
					table.remove(self.metalSpots, i)
					break
				end
			end
		end
	end
 	return spots
end


local function Check1Topology(x, z, mtype, network,Map)
	if Map[mtype][x] == nil then
		return 1
	elseif Map[mtype][x][z] == nil then
		return 1
	else
		return Map[mtype][x][z]
	end
end

function MapHST:Flood4Topology(x, z, mtype, network)
	if x > self.mapSize.x or x < 1 or z > self.mapSize.z or z < 1 then
		return
	end
	--precheck throws out 1-wide bottlenecks
	local blocked = 0
	blocked = blocked + Check1Topology(x+1, z, mtype, network,self.mobilityMap)
	blocked = blocked + Check1Topology(x-1, z, mtype, network,self.mobilityMap)
	if blocked == 2 then
		return end
	blocked = blocked + Check1Topology(x, z+1, mtype, network,self.mobilityMap)
	if blocked == 2 then
		return end
	blocked = blocked + Check1Topology(x, z-1, mtype, network,self.mobilityMap)
	if blocked == 2 then
		return end
	-- now actually flood fill
	local actualValue = self.mobilityMap[mtype][x][z]
	if actualValue and (actualValue == 0) and self.topology[mtype][x][z] == nil then
		self.topology[mtype][x][z] = network
		self.networkSize[mtype][network] = self.networkSize[mtype][network] + 1
		self:Flood4Topology(x+1,z,mtype,network)
		self:Flood4Topology(x-1,z,mtype,network)
		self:Flood4Topology(x,z+1,mtype,network)
		self:Flood4Topology(x,z-1,mtype,network)
	end
end

function MapHST:Flood8Topology(x, z, mtype, network)
	if x > self.mapSize.x or x < 1 or z > self.mapSize.z or z < 1 then return end
	local actualValue = self.mobilityMap[mtype][x][z]
	if actualValue and (actualValue == 0) and self.topology[mtype][x][z] == nil then
		self.topology[mtype][x][z] = network
		self.networkSize[mtype][network] = self.networkSize[mtype][network] + 1
		self:Flood8Topology(x+1,z,mtype,network)
		self:Flood8Topology(x-1,z,mtype,network)
		self:Flood8Topology(x,z+1,mtype,network)
		self:Flood8Topology(x,z-1,mtype,network)
		self:Flood8Topology(x+1,z+1,mtype,network)
		self:Flood8Topology(x-1,z+1,mtype,network)
		self:Flood8Topology(x+1,z-1,mtype,network)
		self:Flood8Topology(x-1,z-1,mtype,network)
	end
end


function MapHST:InitializeTopology()
	self.topology = {}
	for mtype, utypes in pairs(self.mobilityUnitTypes) do
		self.topology[mtype] = {}
	end
	self.topology["air"] = {}
	for x = 1, self.mapSize.x do
		for mtype, utypes in pairs(self.mobilityUnitTypes) do
			self.topology[mtype][x] = {}
		end
		self.topology["air"][x] = {}
		for z = 1, self.mapSize.z do
			-- fill air self.topology with single network
			self.topology["air"][x][z] = 1
		end
	end
end


function MapHST:InitializeTopology2()
	for X,zetas in pairs(self.GRID) do
		for Z, CELL in pairs(zetas) do
			CELL.moveClassTypes = {}

end
function MapHST:MapSpotMobility(metals, geos)
	self.networkSize = {}
	self.mobNetworkGeos = {}
	self.mobNetworkGeos['air'] = {}
	self.mobNetworkGeos['air'][1] = geos
	self.scoutSpots = {}
	self.scoutSpots["air"] = {}
	self.scoutSpots["air"][1] = {}
	self.mobilityNetworkMetals = {}
	self.mobilityNetworkMetals["air"] = {}
	self.mobilityNetworkMetals["air"][1] = {}
	self.mobSpots = {}
	self.mobNetworkCount = {}
	for mtype, utypes in pairs(self.mobilityUnitTypes) do
		self.mobSpots[mtype] = {}
		self.mobilityNetworkMetals[mtype] = {}
		self.mobNetworkCount[mtype] = {}
		self.mobilityNets[mtype] = 0
		self.networkSize[mtype] = {}
		self.scoutSpots[mtype] = {}
		self.mobNetworkGeos[mtype] = {}
	end
	for metalOrGeo = 1, 2 do
		local spots
		if metalOrGeo == 1 then
			spots = metals
		else
			spots = geos
		end
		for i, spot in pairs(spots) do
			local landOrWater
			if metalOrGeo == 1 then
				if self.map:CanBuildHere(self.ai.armyhst.UWMetalSpotCheckUnitType, spot) then
					table.insert(self.UWMetalSpots, spot)
					landOrWater = 2
				else
					table.insert(self.landMetalSpots, spot)
					landOrWater = 1
				end
			end
			local x = math.ceil(spot.x / self.gridSize)
			local z = math.ceil(spot.z / self.gridSize)
			for mtype, utypes in pairs(self.mobilityUnitTypes) do
				if self.mobilityMap and self.mobilityMap[mtype] and self.mobilityMap[mtype][x] and self.mobilityMap[mtype][x][z] == 0 then
					local thisNetwork
					if self.topology[mtype][x][z] == nil then
						-- if self.topology is empty here, initiate a new network, and flood fill it
						self.mobilityNets[mtype] = self.mobilityNets[mtype] + 1
						thisNetwork = self.mobilityNets[mtype]
						self.mobNetworkCount[mtype][thisNetwork] = 1
						self.networkSize[mtype][thisNetwork] = 0
						self.mobilityNetworkMetals[mtype][thisNetwork] = {}
						self:Flood4Topology(x, z, mtype, self.mobilityNets[mtype])
					else
						-- if self.topology isn't empty here, add this spot to its count
						thisNetwork = self.topology[mtype][x][z]
						self.mobNetworkCount[mtype][thisNetwork] = self.mobNetworkCount[mtype][thisNetwork] + 1
					end
					table.insert(self.mobSpots[mtype], {x = x, z = z})
					if metalOrGeo == 1 then
						if landOrWater == 1 and mtype ~= "sub" and mtype ~= "shp" then
							table.insert(self.mobilityNetworkMetals[mtype][thisNetwork], spot)
						elseif landOrWater == 2 and mtype ~= "veh" and mtype ~= "bot" then
							table.insert(self.mobilityNetworkMetals[mtype][thisNetwork], spot)
						end
					else
						self.mobNetworkGeos[mtype][thisNetwork] = self.mobNetworkGeos[mtype][thisNetwork] or {}
						table.insert(self.mobNetworkGeos[mtype][thisNetwork], spot)
					end
					self.scoutSpots[mtype][thisNetwork] = self.scoutSpots[mtype][thisNetwork] or {}
					table.insert(self.scoutSpots[mtype][thisNetwork], spot)
				end
			end
			if metalOrGeo == 1 then table.insert(self.mobilityNetworkMetals["air"][1], spot) end
			table.insert(self.scoutSpots["air"][1], spot)
		end
	end

end

function MapHST:MergePositions(posTable, cutoff, includeNonMerged)
	local list = {} -- make copy to prevent clearing table
	for k, v in pairs(posTable) do table.insert(list, v) end
	self:EchoDebug('#list&cutof',#list .. " " .. cutoff)
	local merged = {}
	while #list > 0 do
		local lp = table.remove(list)
		local pos1 = api.Position()
		pos1.x, pos1.y, pos1.z = lp.x, lp.y, lp.z
		local merge = nil
		for i = #list, 1, -1 do
			local pos2 = list[i]
			local dist = self.ai.tool:Distance(pos1, pos2)
			if dist < cutoff then
				self:EchoDebug("merging " .. pos1.x .. "," .. pos1.z .. " with " .. pos2.x .. "," .. pos2.z .. " -- " .. dist .. " away")
				merge = self.ai.tool:MiddleOfTwo(pos1, pos2)
				pos1 = merge
				table.remove(list, i)
			end
		end
		if merge ~= nil then
			table.insert(merged, merge)
		elseif includeNonMerged then
			table.insert(merged, pos1)
		end
	end
	self:EchoDebug('#merged',#merged)
	return merged
end

function MapHST:Update()
-- 	-- workaround for shifting metal spots: map data is reloaded every two minutess

	local f = self.game:Frame()
-- 	if f > self.lastDataResetFrame + 10  and not self.dd then
-- 		self:DrawDebug()
-- 		self.dd = true
-- 	end
	if f > self.lastDataResetFrame + 3600 then
	self.lastDataResetFrame = f
	end
end





function MapHST:spotPathMobRank(spotscleaned)
    self:EchoDebug('self.spotPathMobRank START')
	local moveclass = {}
	local pathDistRatios = {}
	local pathDistRatiosSuccessOnly = {}
    for id,unitDef in pairs(UnitDefs) do
		if unitDef.moveDef.name  then--maybe because we have already chickens
			if moveclass[unitDef.moveDef.name] ==   nil then
				moveclass[unitDef.moveDef.name] = id
				self:EchoDebug('name&id',unitDef.moveDef.name,id)
			end
		end
	end
	for mclass, number in pairs(moveclass) do
		pathDistRatios[mclass] = 0
		pathDistRatiosSuccessOnly[mclass] = 0
		local mySpots = {}
		for i = 1, #spotscleaned do
			mySpots[i] = spotscleaned[i]
		end
		local pathCount = 0
		local pathSuccessCount = 0
		local pos1 = table.remove(mySpots)
		while #mySpots > 0 do
			local pos2 = table.remove(mySpots)
			if Spring.TestMoveOrder(number,pos1.x,pos1.y,pos1.z) == true and Spring.TestMoveOrder(number,pos2.x,pos2.y,pos2.z) == true then
				local metapath = Spring.RequestPath(mclass, pos1.x,pos1.y,pos1.z,pos2.x,pos2.y,pos2.z)
				if metapath then
					local waypoints, pathStartIdx = metapath:GetPathWayPoints()
 					local dist  = self.ai.tool:Distance3d(pos1,pos2)
					if waypoints and #waypoints > 0 and pos1 ~= pos2 then
						local waypointsNumber = #waypoints
						local last = waypoints[#waypoints]
						if pos2.x == last[1] and pos2.z == last[3] then
							local totalPathDist = 0
							for i = 2, waypointsNumber do
								local wp1 = waypoints[i-1]
								local wp2 = waypoints[i]
								local dx = wp2[1] - wp1[1]
								local dy = wp2[2] - wp1[2]
								local dz = wp2[3] - wp1[3]
								local segDist = math.sqrt(dx*dx + dy*dy + dz*dz) + 1
								totalPathDist = totalPathDist + segDist
--                                 self:EchoDebug(segDist)
-- 								if mclass == 'tank2' then
-- 									self.map:DrawLine({x=wp1[1], y=wp1[2], z=wp1[3]}, {x=wp2[1], y=wp2[2], z=wp2[3]}, {1,1,1,1}, nil, true, 1)
-- 								end
							end
							if totalPathDist == 0 then totalPathDist = 1 end --TODO understand why totalpathdist somtime is 0
							pathDistRatios[mclass] = pathDistRatios[mclass] + (dist / totalPathDist)
							pathCount = pathCount + 1
							pathSuccessCount = pathSuccessCount + 1
							--	self:EchoDebug('mclasstotpathdistdist',mclass,UnitDefs[number].name,dist, totalPathDist, dist / totalPathDist,pathDistRatios[mclass])
						else
							--self:EchoDebug('path does not get to destination')
							pathCount = pathCount + 1
						end
					end
				end
			end
			pos1 = pos2
		end
		if pathDistRatios[mclass] > 0 then
			if pathSuccessCount > 0 then
				-- dist ratio of only paths that get to their destinations
				pathDistRatiosSuccessOnly[mclass] = pathDistRatios[mclass] / pathSuccessCount
			end
			if pathCount > 0 then
				pathDistRatios[mclass] = pathDistRatios[mclass] / pathCount
			end
		end
		self:EchoDebug('spmr',mclass, pathDistRatios[mclass], pathDistRatiosSuccessOnly[mclass])
	end
    for pathType, rank in pairs(pathDistRatios) do
        self:EchoDebug('pathdistRatios',pathType .. ' = ' ..rank)
    end
    self:EchoDebug('self.spotPathMobRank STOP')
	self.spotPathMobRank, self.spotPathMobRankSuccessOnly = pathDistRatios, pathDistRatiosSuccessOnly
end

function MapHST:GuessStartLocations(spots)
	if spots == nil then return end
	if #spots == 0 then
		self:EchoDebug("spot table for start location guessing is empty")
		return
	end
	-- find links
	local spotsCopy = {}
	for i, v in pairs(spots) do table.insert(spotsCopy, v) end
	local minDist = 1000
	local links = {}
	local from = table.remove(spotsCopy)
	while #spotsCopy > 0 do
		local closest = nil
		for i, to in pairs(spotsCopy) do
			local dist = self.ai.tool:Distance(from, to)
			if dist < minDist then
				minDist = dist
				closest = i
			end
			local middle = self.ai.tool:MiddleOfTwo(from, to)
			table.insert(links, {dist = dist, middle = middle})
		end
		if closest ~= nil then
			from = table.remove(spotsCopy, closest)
		else
			from = table.remove(spotsCopy)
		end
	end
	-- look for matches
	local matches = {}
	local tolerance = minDist * 0.5
	local cutoff = minDist + tolerance
	self:EchoDebug("tolerance: " .. tolerance .. "  cutoff: " .. cutoff)
	for i, l in pairs(links) do
		if l.dist < cutoff then
			self:EchoDebug("metal spot link at " .. math.ceil(l.middle.x) .. "," .. math.ceil(l.middle.z) .. " within cutoff with self.ai.tool:distance of " .. math.ceil(l.dist))
			table.insert(matches, l.middle)
		end
	end
	if #matches == 0 then return end
	-- merge matches close to each other
	local merged = self:MergePositions(matches, cutoff, false)
	if #merged < 2 then
		self:EchoDebug("not enough merged, using all matches")
		return matches
	else
		self:EchoDebug("using merged links")
		return merged
	end
end





function MapHST:ClosestFreeSpot(unittype, builder, position)
-- 	local kbytes, threshold = gcinfo()
-- 	game:SendToConsole("maphst gcinfo: " .. kbytes .. " (before ClosestFreeSpot)")
	if position == nil then position = builder:GetPosition() end
	local spots = {}
	local bname = builder:Name()
	if self.ai.armyhst.commanderList[bname] then
		-- give the commander both hov and bot spots
		local pos = builder:GetPosition()
		local network = self:MobilityNetworkHere("bot", pos)
		if network ~= nil then
			-- self:EchoDebug("found bot metal spot network for commander")
			spots = self.mobilityNetworkMetals["bot"][network]
		end
		network = self:MobilityNetworkHere("hov", pos)
		if network ~= nil then
			-- self:EchoDebug("found hover metal spot network for commander")
			if #spots == 0 then
				spots = self.mobilityNetworkMetals["hov"][network]
			else
				for i, p in pairs(self.mobilityNetworkMetals["hov"][network]) do
					table.insert(spots, p)
				end
			end
		end
		-- give the commander all metal spots if shp or bot doesn't work out
		if #spots == 0 then spots = self.mobilityNetworkMetals["air"][1] end
	else
		local mtype, network = self:MobilityOfUnit(builder)
		if self.mobilityNetworkMetals[mtype][network] ~= nil then
			spots = self.mobilityNetworkMetals[mtype][network] --TODO check why on diana beach armck has 137 spots and armcv 50
-- 			self.map:EraseAll()
			if bname == 'armck' then
				for i,v in pairs (spots) do
-- 					self.map:DrawPoint(v, {1,1,1,1}, nil, 1)
				end
			end

		end
	end
	if spots == nil then
		self:EchoDebug(builder:Name() .. " has nil spots")
		return end
	if #spots == 0 then
		self:EchoDebug(builder:Name() .. " has zero spots")
		return
	end
	local uname = unittype:Name()
	local pos = nil
	local reclaimEnemyMex = false
	local bestDistance = math.huge
 	-- check for armed enemy units nearby
	local uw = nil
	local uwutype = nil
	if self.hasUWSpots then
		-- underwater mex check
		-- self:EchoDebug("map has uw spots")
		local coruwtype
		local armuwtype
		if uname == "cormex" or uname == "armmex" then
			coruwtype = self.game:GetTypeByName("cormex")--ex  coruwmex
			armuwtype = self.game:GetTypeByName("armmex")--ex  armuwmex
		elseif uname == "cormoho" or uname == "armoho" then
			coruwtype = self.game:GetTypeByName("coruwmme")
			armuwtype = self.game:GetTypeByName("armuwmme")
		end
		if coruwtype ~= nil then
			if builder:CanBuild(coruwtype) then
				uwutype = coruwtype
			elseif builder:CanBuild(armuwtype) then
				uwutype = armuwtype
			end
		end
		-- if uwutype ~= nil then self:EchoDebug("builder can build uw mexes") end
	end
	local f = self.game:Frame()
	for i,p in pairs(spots) do
		-- dont use this spot if we're already building there
		local alreadyPlanned = self.ai.buildsitehst:PlansOverlap(p, uname)
		if not alreadyPlanned and self:UnitCanGoHere(builder, p) then
			self:EchoDebug('1')
			local dist = self.ai.tool:Distance(position, p)
			-- don't add if it's already too high
			if dist < bestDistance then
				self:EchoDebug('2')
				-- now check if we can build there
				local uwcheck
				if uwutype ~= nil then
					 uwcheck = self.map:CanBuildHere(uwutype, p)
					 -- self:EchoDebug("builder can build uw mex here? " .. tostring(uwcheck))
				end
				if self.map:CanBuildHere(unittype, p) or uwcheck then
					self:EchoDebug('3')
					-- self:EchoDebug("can build mex at" .. p.x .. " " .. p.z)
					-- game:SendToConsole("before builder gets safe position", self.ai.id, self.ai.id, builder:Team())
					if self.ai.targethst:IsSafePosition(p, builder) then
						self:EchoDebug('4')
						bestDistance = dist
						pos = p
						reclaimEnemyMex = false
						if uwcheck then
							-- self:EchoDebug("uw mex is best self.ai.tool:distance")
							uw = uwutype
							self:EchoDebug('5')
						else
							uw = nil
							self:EchoDebug('6')
						end
					else
-- 						self.map:DrawPoint(p, {0,0,1,1}, nil, 1)
					end
				elseif self.ai.targethst:IsSafePosition(p, builder, 200) then
					self:EchoDebug('7')
					-- is it an enemy mex that's blocking a safe position (or an unknown radar blip)?
					for i, enemySpot in pairs(self.ai.targethst.enemyMexSpots) do
						local epos = enemySpot.position
						if p.x > epos.x - 100 and p.x < epos.x + 100 and p.z > epos.z - 100 and p.z < epos.z + 100 then
							bestDistance = dist
							pos = epos
							reclaimEnemyMex = enemySpot.unit
							if uwcheck then
								-- self:EchoDebug("uw mex is best self.ai.tool:distance")
								uw = uwutype
								self:EchoDebug('8')
							else
								uw = nil
								self:EchoDebug('9')
							end
							break
						end
					end
				end
			end
		else
-- 			self.map:DrawPoint(p, {1,0,0,1}, nil, 1)
		end
	end
-- 	local kbytes, threshold = gcinfo()
-- 	game:SendToConsole("maphst gcinfo: " .. kbytes .. " (after ClosestFreeSpot)")
	-- if uw then self:EchoDebug("uw mex is final best self.ai.tool:distance") end
	return pos, uw, reclaimEnemyMex
end

function MapHST:ClosestFreeGeo(unittype, builder, position)
	self:EchoDebug("closestfreegeo for " .. unittype:Name() .. " by " .. builder:Name())
	if not position then position = builder:GetPosition() end
	local bname = builder:Name()
	local uname = unittype:Name()
	local bestDistance, bestPos
	for i,p in pairs(self.geoSpots) do
		-- dont use this spot if we're already building there
		if not self.ai.buildsitehst:PlansOverlap(p, uname) and self:UnitCanGoHere(builder, p) and self.map:CanBuildHere(unittype, p) and self.ai.targethst:IsSafePosition(p, builder) then
			local dist = self.ai.tool:Distance(position, p)
			if not bestDistance or dist < bestDistance then
				bestDistance = dist
				bestPos = p
			end
		end
	end
	return bestPos
end

function MapHST:MobilityNetworkHere(mtype, position)
	if not mtype or not position then return nil end
	if mtype == "air" then return 1 end
	local x = math.ceil(position.x / self.gridSize)
	local z = math.ceil(position.z / self.gridSize)
	local network
	if self.topology[mtype][x] ~= nil then
		network = self.topology[mtype][x][z]
	end
	return network
end

function MapHST:MobilityOfUnit(unit)
	local position = unit:GetPosition()
	local name = unit:Name()

	local mtype = self.ai.armyhst.unitTable[name].mtype
	if self.activeMobTypes[mtype] == nil then self.activeMobTypes[mtype] = true end
	return mtype, self:MobilityNetworkHere(mtype, position)
end

function MapHST:UnitCanGoHere(unit, position)
	if unit == nil then return false end
	if position == nil then return false end
	local mtype, unet = self:MobilityOfUnit(unit)
	if mtype == 'air' then return true end
    -- check if it's even a valid move order
    local moveOrderTest = Spring.TestMoveOrder(unit:Type():ID(), position.x, position.y, position.z, nil, nil, nil, true, false)
    if not moveOrderTest then
        return false
    end
	local pnet = self:MobilityNetworkHere(mtype, position)
	if unet == pnet then
		return true
	else
		-- self:EchoDebug(mtype .. " " .. tostring(unet) .. " " .. tostring(pnet))
		return false
	end
end

function MapHST:UnitCanGetToUnit(unit1, unit2)
	local position = unit2:GetPosition()
	return self:UnitCanGoHere(unit1, position)
end



function MapHST:MobilitynetworkSizeHere(mtype, position)
	if mtype == "air" then return self.gridArea end
	local x = math.ceil(position.x / self.gridSize)
	local z = math.ceil(position.z / self.gridSize)
	if self.topology[mtype][x] == nil then
		return 0
	elseif self.topology[mtype][x][z] == nil then
		return 0
	else
		local network = self.topology[mtype][x][z]
		return self.networkSize[mtype][network]
	end
end

function MapHST:AccessibleMetalSpotsHere(mtype, position)
	local network = self:MobilityNetworkHere(mtype, position)
	return self.mobilityNetworkMetals[mtype][network] or {}
end

function MapHST:AccessibleGeoSpotsHere(mtype, position)
	local network = self:MobilityNetworkHere(mtype, position)
	return self.mobNetworkGeos[mtype][network] or {}
end

function MapHST:AccessibleMetalGeoSpotsHere(mtype, position)
	local network = self:MobilityNetworkHere(mtype, position)
	return self.scoutSpots[mtype][network] or {}
end

function MapHST:IsUnderWater(position)
	return Spring.GetGroundHeight(position.x, position.z) < 0
end



function MapHST:GetPathGraph(mtype, targetNodeSize)
	targetNodeSize = targetNodeSize or 256
	local cellsPerNodeSide = mCeil(targetNodeSize / self.gridSize)
	if pathGraphs[mtype] then
		if pathGraphs[mtype][cellsPerNodeSide] then
			return pathGraphs[mtype][cellsPerNodeSide]
		end
	end
	local nodeSize = cellsPerNodeSide * self.gridSize
	local nodeSizeHalf = nodeSize / 2
	local graph = {}
	local id = 1
	local myTopology = self.topology[mtype]
	for cx = 1, self.mapSize.x, cellsPerNodeSide do
		local x = ((cx * self.gridSize) - self.gridSizeHalf) + nodeSizeHalf
		for cz = 1, self.mapSize.z, cellsPerNodeSide do
			local cellsComplete = true
			local goodCells = {}
			local goodCellsCount = 0
			for ccx = cx, cx+cellsPerNodeSide-1 do
				for ccz = cz, cz+cellsPerNodeSide-1 do
					if myTopology[ccx] and myTopology[ccx][ccz] then
						goodCellsCount = goodCellsCount + 1
						goodCells[goodCellsCount] = {ccx, ccz}
					else
						cellsComplete = false
					end
				end
			end
			if goodCellsCount > 0 then
				local z = ((cz * self.gridSize) - self.gridSizeHalf) + nodeSizeHalf
				local position = api.Position()
				position.x = x
				position.z = z
				position.y = 0
				if not cellsComplete then
					local bestDist, bestX, bestZ
					for i = 1, goodCellsCount do
						local good = goodCells[i]
						local gx = (good[1] * self.gridSize) - self.gridSizeHalf
						local gz = (good[2] * self.gridSize) - self.gridSizeHalf
						local dx = x - gx
						local dz = z - gz
						local dist = dx*dx + dz*dz
						if not bestDist or dist < bestDist then
							bestDist = dist
							bestX = gx
							bestZ = gz
						end
					end
					position.x = bestX
					position.z = bestZ
				end

				position.y = Spring.GetGroundHeight(x, z)
				local nodeX = mCeil(cx / cellsPerNodeSide)
				local nodeY = mCeil(cz / cellsPerNodeSide)
				local node = { x = nodeX, y = nodeY, id = id, position = position }
				-- self.map:DrawPoint(position, {1,1,1,1}, mtype .. " " .. nodeX .. ", " .. nodeY, 8)
				graph[id] = node
				id = id + 1
			end
		end
	end
	local aGraph = GraphAStar()
	aGraph:Init(graph)
	aGraph:SetOctoGridSize(1)
	aGraph:SetPositionUnitsPerNodeUnits(nodeSize)
	pathGraphs[mtype] = pathGraphs[mtype] or {}
	pathGraphs[mtype][cellsPerNodeSide] = aGraph
	return aGraph
end



--[[
function MapHST:factoriesRating()
	local mtypesMapRatings = {}
	local factoryRating = {}
	self.ai.factoryBuilded = {}
	self.ai.factoryBuilded['air'] = {}
	for mtype, networks in pairs(self.networkSize) do
		self.ai.factoryBuilded[mtype] = {}
		for network, size in pairs(networks) do
			local spots = self.mobilityNetworkMetals[mtype][network] or {}
			spots = #spots
			if size > self.gridArea * 0.20 and spots > (#self.landMetalSpots + #self.UWMetalSpots) * 0.4 then
				-- area large enough and enough metal spots
				self.ai.factoryBuilded[mtype][network] = 0
			end
		end
	end
	self.ai.factoryBuilded['air'][1] = 0
	for mtype, unames in pairs(self.ai.armyhst.mobUnitNames) do
		local realMetals = 0
		local realSize = 0
		local realGeos = 0
		local spots = 0
		local geos= 0
		local realRating = self.mobilityRating[mtype] / 100
		if self.mobilityCount[mtype] ~= 0 then
			realSize = self.mobilityCount[mtype] / self.gridArea --relative area occupable
		end
		if #self.landMetalSpots + #self.UWMetalSpots ~= 0 then
			for network, index in pairs(self.mobilityNetworkMetals[mtype]) do
				spots=spots + #index
			end
			realMetals = spots / (#self.landMetalSpots + #self.UWMetalSpots)--relative metals occupable
		end
		if #self.geoSpots > 0 and mtype ~= ('shp' or 'sub') then
			realGeos = math.min(0.1 * #self.geoSpots,1) --if there are more then 10 geos is useless give it more weight on bestfactory type calculations
		end
		mtypesMapRatings[mtype] = (( realMetals + realSize + realGeos) / 3) * realRating
		mtypesMapRatings[mtype] = (self.mobilityRating[mtype] / self.mobilityRating['air']) * self.ai.armyhst.mobilityEffeciencyMultiplier[mtype]
		-- area is not as important as number of metal and geo
		-- mtypesMapRatings[mtype] = (( realMetals + (realSize*0.5) + realGeos) / 2.5) * self.ai.armyhst.mobilityEffeciencyMultiplier[mtype]
		self:EchoDebug('mtypes map rating ' ..mtype .. ' = ' .. mtypesMapRatings[mtype])
	end
	mtypesMapRatings['air'] = self.ai.armyhst.mobilityEffeciencyMultiplier['air']
	local bestPath = 0
	for factory,mtypes in pairs(self.ai.armyhst.factoryMobilities)do
		local factoryPathRating = 0
		local factoryMtypeRating = 0
		if mtypes[1] ~='air' then
			local factoryBuildsCons = false
			for index, unit in pairs( self.ai.armyhst.unitTable[factory].unitsCanBuild) do
				local mtype = self.ai.armyhst.unitTable[unit].mtype
				if self.ai.armyhst.unitTable[unit].buildOptions then
					if (self.hasUWSpots and mtype ~= 'veh') or (not self.hasUWSpots and mtype ~= 'amp') then
					-- if self.ai.hasUWSpots or not (mtype == 'amp' and mtypes[1] == 'veh') then
						factoryBuildsCons = true
						break
					end
				end
			end
			self:EchoDebug(factory .. " builds cons: " .. tostring(factoryBuildsCons))
			local count = 0
			local maxPath = 0
			local mediaPath = 0
			for index, unit in pairs( self.ai.armyhst.unitTable[factory].unitsCanBuild) do
				local mtype = self.ai.armyhst.unitTable[unit].mtype
				local mclass = self.ai.armyhst.unitTable[unit].mclass
				if self.ai.armyhst.unitTable[unit].buildOptions or not factoryBuildsCons then
					local ok = true
					-- if self.ai.hasUWSpots or not (mtype == 'amp' and mtypes[1] == 'veh') then
					if (self.hasUWSpots and mtype ~= 'veh') or (not self.hasUWSpots and mtype ~= 'amp') then
						count = count + 1
						factoryMtypeRating = factoryMtypeRating + mtypesMapRatings[mtype]
						self:EchoDebug(factory .. ' ' .. unit .. ' ' .. self.ai.armyhst.unitTable[unit].mtype .. ' ' .. mtypesMapRatings[self.ai.armyhst.unitTable[unit].mtype])
							bestPath = math.max(bestPath,self.spotPathMobRank[mclass])
							maxPath = math.max(maxPath,self.spotPathMobRank[mclass])
							mediaPath = mediaPath + self.spotPathMobRank[mclass]
							self:EchoDebug('bigdbg',factory .. ' ' .. unit .. ' ' .. self.ai.armyhst.unitTable[unit].mtype .. ' ' .. mtypesMapRatings[self.ai.armyhst.unitTable[unit].mtype],bestPath,maxPath,mediaPath,self.spotPathMobRank[mclass])
					end
				end
			end
			if count == 0 then
				factoryMtypeRating = 0
			else
				factoryMtypeRating = factoryMtypeRating / count
			end
			if maxPath == 0 then
				mediaPath = 0
			else
				mediaPath = (mediaPath / count)
				factoryPathRating = (maxPath + mediaPath) / 2
			end
		else
			self:EchoDebug('airfactory',factory)
			factoryPathRating = 1
			if #self.landMetalSpots + #self.UWMetalSpots == 0 then
				factoryMtypeRating = mtypesMapRatings['air']
			elseif self.ai.armyhst.unitTable[factory].needsWater then
				factoryMtypeRating = mtypesMapRatings['air'] * (#self.UWMetalSpots / (#self.landMetalSpots + #self.UWMetalSpots))
			else
				factoryMtypeRating = mtypesMapRatings['air'] * (#self.landMetalSpots / (#self.landMetalSpots + #self.UWMetalSpots))
			end
		end
		self:EchoDebug(factory .. ' mtype rating: ' .. factoryMtypeRating)
		local Rating
		self:EchoDebug(factory .. ' path rating: ' .. factoryPathRating)
		Rating = factoryPathRating * factoryMtypeRating * self.ai.armyhst.unitTable[factory].techLevel
		self:EchoDebug('Rating',factoryPathRating, factoryMtypeRating , self.ai.armyhst.unitTable[factory].techLevel)
		if self.ai.armyhst.factoryMobilities[factory][1] == ('hov') then
			Rating = Rating * (self.mobilityCount['shp'] /self.gridArea)
		end
		Rating = Rating * -1--reverse the value to get the right order
		if Rating ~= 0 then --useless add factory totally out of mode
			factoryRating[factory] = Rating
			self:EchoDebug('factory rating ' .. factory ..' = ' .. factoryRating[factory])
		end
		end
	local sorting = {}
	local rank = {}
	for name, rating in pairs(factoryRating) do
        self:EchoDebug('name,rating,rank[rating]',name,rating,rank[rating])
		if not rank[rating] then
			rank[rating] = {}
			table.insert(rank[rating],name)
		else
			table.insert(rank[rating],name)
		end
		table.insert(sorting, rating)
	end
	table.sort(sorting)
	local factoriesRanking = {}
	local ranksByFactories = {}
	for i,v in pairs(sorting) do
		for ii = #rank[v], 1, -1 do
			local factoryName = table.remove(rank[v],ii)
			table.insert(factoriesRanking, factoryName)
			ranksByFactories[factoryName] = #factoriesRanking
			self:EchoDebug('i-factoryname',(i .. ' ' .. factoryName))
		end
	end
	return factoriesRanking, ranksByFactories
end
]]
