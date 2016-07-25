 DebugEnabled = false
local DebugDrawEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("MapHandler: " .. inStr)
	end
end

-- mobTypes = {}
local mobUnitTypes = {}
local UWMetalSpotCheckUnitType

local mobMap = {}
local savepositions = {}

local function MapDataFilename()
	local mapName = string.gsub(map:MapName(), "%W", "_")
	return "cache/Shard-" .. game:GameName() .. "-" .. mapName .. ".lua"
end

local function serialize (o, keylist)
  if keylist == nil then keylist = "" end
  if type(o) == "number" then
    mapdatafile:write(o)
  elseif type(o) == "boolean" then
  	mapdatafile:write(tostring(o))
  elseif type(o) == "string" then
    mapdatafile:write(string.format("%q", o))
  elseif type(o) == "userdata" then
  	-- assume it's a position
  	mapdatafile:write("api.Position()")
  	table.insert(savepositions, {keylist = keylist, position = o})
  	--mapdatafile:write("{ x = " .. math.ceil(o.x) .. ", y = " .. math.ceil(o.y) .. ", z = " .. math.ceil(o.z) .. " }")
  elseif type(o) == "table" then
    mapdatafile:write("{\n")
    for k,v in pairs(o) do
      mapdatafile:write("  [")
      serialize(k)
      mapdatafile:write("] = ")
      local newkeylist
      if type(v) == "table" or type(v) == "userdata" then
      	if type(k) == "string" then
        	newkeylist = keylist .. "[\""  .. k .. "\"]"
        elseif type(k) == "number" then
        	newkeylist = keylist .. "["  .. k .. "]"
        end
      end
      serialize(v, newkeylist)
      mapdatafile:write(",\n")
    end
    mapdatafile:write("}\n")
  else
    error("cannot serialize a " .. type(o))
  end
end

local function EchoData(name, o)
	savepositions = {}
	mapdatafile:write(name)
	mapdatafile:write(" = ")
	serialize(o)
	mapdatafile:write("\n\n")
	if #savepositions > 0 then
		for i, sp in pairs (savepositions) do
			mapdatafile:write(name .. sp.keylist .. ".x = " .. sp.position.x .. "\n")
			mapdatafile:write(name .. sp.keylist .. ".y = " .. sp.position.y .. "\n")
			mapdatafile:write(name .. sp.keylist .. ".z = " .. sp.position.z .. "\n")
		end
		mapdatafile:write("\n\n")
	end
	EchoDebug("wrote " .. name)
end

local mapColors = {
	veh = { 1, 0, 0 },
	bot = { 0, 1, 0 },
	hov = { 0, 0, 1 },
	shp = { 1, 0, 0 },
	amp = { 0, 1, 0 },
	sub = { 0, 0, 1 },
	start = { 1, 1, 1, 1 },
}

local mapChannels = {
	veh = { 4 },
	bot = { 4 },
	hov = { 4 },
	sub = { 5 },
	amp = { 5 },
	shp = { 5 },
	start = { 4, 5 },
}

local function AddColors(colorA, colorB)
	local color = {}
	for i = 1, 4 do
		if colorA[i] or colorB[i] then
			color[i] = (colorA[i] or 0) + (colorB[i] or 0)
			color[i] = math.min(color[i], 1)
		end
	end
	return color
end

local function GetColorFromLabel(label)
	local color = mapColors[label] or { 1, 1, 1 }
	color[4] = color[4] or 0.33
	return color
end

local function GetChannelsFromLabel(label)
	local channels = mapChannels[label] or {4}
	return channels
end

local function PlotDebug(x, z, label, labelAdd)
	if DebugDrawEnabled then
		x = math.ceil(x)
		z = math.ceil(z)
		local pointString = x .. "  " .. z
		if label == nil then label= "nil" end
		local pos = api.Position()
		pos.x, pos.z = x, z
		local color = GetColorFromLabel(label)
		local channels = GetChannelsFromLabel(label)
		if labelAdd then label = label .. ' ' .. labelAdd end
		for i = 1, #channels do
			local channel = channels[i]
			map:DrawPoint(pos, color, label, channel)
		end
	end
end

MapHandler = class(Module)

local function MiddleOfTwo(pos1, pos2)
	local middle = api.Position()
	middle.x, middle.y, middle.z = (pos1.x+pos2.x)/2, (pos1.y+pos2.y)/2,(pos1.z+pos2.z)/2
	return middle
end

local function Check1Topology(x, z, mtype, network)
	if mobMap[mtype][x] == nil then
		return 1
	elseif mobMap[mtype][x][z] == nil then
		return 1
	else
		return mobMap[mtype][x][z]
	end
end

local function Flood4Topology(x, z, mtype, network)
	if x > ai.mobilityGridMaxX or x < 1 or z > ai.mobilityGridMaxZ or z < 1 then return end
	--precheck throws out 1-wide bottlenecks
	local blocked = 0
	blocked = blocked + Check1Topology(x+1, z, mtype, network)
	blocked = blocked + Check1Topology(x-1, z, mtype, network)
	if blocked == 2 then return end
	blocked = blocked + Check1Topology(x, z+1, mtype, network)
	if blocked == 2 then return end
	blocked = blocked + Check1Topology(x, z-1, mtype, network)
	if blocked == 2 then return end
	-- now actually flood fill
	local actualValue = mobMap[mtype][x][z]
	if actualValue and (actualValue == 0) and ai.topology[mtype][x][z] == nil then
		ai.topology[mtype][x][z] = network
		ai.networkSize[mtype][network] = ai.networkSize[mtype][network] + 1
		Flood4Topology(x+1,z,mtype,network)
		Flood4Topology(x-1,z,mtype,network)
		Flood4Topology(x,z+1,mtype,network)
		Flood4Topology(x,z-1,mtype,network)
	end
end

local function Flood8Topology(x, z, mtype, network)
	if x > ai.mobilityGridMaxX or x < 1 or z > ai.mobilityGridMaxZ or z < 1 then return end
	local actualValue = mobMap[mtype][x][z]
	if actualValue and (actualValue == 0) and ai.topology[mtype][x][z] == nil then
		ai.topology[mtype][x][z] = network
		ai.networkSize[mtype][network] = ai.networkSize[mtype][network] + 1
		Flood8Topology(x+1,z,mtype,network)
		Flood8Topology(x-1,z,mtype,network)
		Flood8Topology(x,z+1,mtype,network)
		Flood8Topology(x,z-1,mtype,network)
		Flood8Topology(x+1,z+1,mtype,network)
		Flood8Topology(x-1,z+1,mtype,network)
		Flood8Topology(x+1,z-1,mtype,network)
		Flood8Topology(x-1,z-1,mtype,network)
	end
end

-- gives all kinds of unexpected results
-- function MapHandler:GetFactoryMobilities()
-- 	local factMobs = {}
-- 	for uname, utable in pairs(unitTable) do
-- 		if utable.unitsCanBuild and #utable.unitsCanBuild > 0 then
-- 			factMobs[uname] = {}
-- 			local haveMtype = {}
-- 			for i = 1, #utable.unitsCanBuild do
-- 				local canBuildName = utable.unitsCanBuild[i]
-- 				local mtype = unitTable[canBuildName].mtype
-- 				if not haveMtype[mtype] then
-- 					factMobs[uname][#factMobs[uname]+1] = mtype
-- 					haveMtype[mtype] = true
-- 					EchoDebug(uname .. " " .. mtype)
-- 				end
-- 			end
-- 		end
-- 	end
-- 	return factMobs
-- end

function MapHandler:SpotSimplyfier(metalSpots,geoSpots)
	local spots = {}
	local mirrorspots = {}
	local limit = (map:MapDimensions())
	local limit = limit.x/2  + limit.z/2
	for i,v in pairs(metalSpots) do 
		table.insert(spots,v)
	end
	for i,v in pairs(geoSpots) do 
		table.insert(spots,v)
	end
	local spotscleaned={ }
	EchoDebug(tostring(limit))
	for index1,pos1 in pairs(spots) do 
		if spots[index1] ~= false then
			mirrorspots[index1] = {}
			mirrorspots[index1][index1] = pos1
			spots[index1] = false
			--Spring.MarkerAddPoint(pos1.x,pos1.y,pos1.z, tostring(i))--uncomment this to draw the hotspot reducing system
			for index2,pos2 in pairs(spots) do 
				if spots[index2] ~= false then
					local dist = Distance(pos1,pos2)
					if dist < limit and dist > 0 and ((pos1.y > 0 and pos2.y > 0) or (pos1.y < 0 and pos2.y < 0)) then
						mirrorspots[index1][index2] = pos2
						--Spring.MarkerAddLine(pos1.x, pos1.y, pos1.z, pos2.x, pos2.y, pos2.z)--uncomment this to draw all the hotspot on map
						spots[index2] = false
					end
				end
			end
		end
	end
	for i,v in pairs(mirrorspots) do
		local items = 0
		mirrorspots[i] = api.Position()
		for ii,vv in pairs(v) do
			items = items+1
			mirrorspots[i].x = mirrorspots[i].x+vv.x
			mirrorspots[i].y = mirrorspots[i].y+vv.y
			mirrorspots[i].z = mirrorspots[i].z+vv.z
		end
		local x =mirrorspots[i].x/items
		local z = mirrorspots[i].z/items
		local y = 0
		if ShardSpringLua then y = Spring.GetGroundHeight(x,z) end
		mirrorspots[i].x = x
		mirrorspots[i].y = y
		mirrorspots[i].z = z
		if DebugDrawEnabled then self.map:DrawPoint(mirrorspots[i], {1,0,1}, 'hotspot', 6) end
	end
	return mirrorspots
end

function MapHandler:SpotPathMobRank(spotscleaned)
	local moveclass={}
	local waypointstable={}
	for id,unitDef in pairs(UnitDefs) do
		if unitDef.moveDef.name  and unitDef.techLevel >=0 then 
			if moveclass[unitDef.moveDef.name] ==   nil then
				moveclass[unitDef.moveDef.name] = id
			end
		end
	end
	for mclass, number in pairs(moveclass) do
		waypointstable[mclass] = 0
		local alreadypath = {}
		for index,pos1 in pairs(spotscleaned) do
			alreadypath[index]={}
			for index2,pos2 in pairs(spotscleaned) do
				if Spring.TestMoveOrder(number,pos1.x,pos1.y,pos1.z) == true and Spring.TestMoveOrder(number,pos2.x,pos2.y,pos2.z) == true then
					if alreadypath[index2] == nil  or alreadypath[index2][index] == nil then
						if index2~=index then
							alreadypath[index][index2] = true
							local metapath = Spring.RequestPath(mclass, pos1.x,pos1.y,pos1.z,pos2.x,pos2.y,pos2.z)
							if metapath then 
								local waypoints, detpath =metapath:GetPathWayPoints()
								local waypointsNumber = #waypoints
								local dist  = Distance(pos1,pos2)
								if waypointsNumber > 0 and dist > 0 then
									waypointstable[mclass] = waypointstable[mclass] + (dist / waypointsNumber)
									--Spring.MarkerAddLine(pos1.x, pos1.y, pos1.z, pos2.x, pos2.y, pos2.z)--uncomment this line to draw on screen all the calculated path
								end
							end
						end
					end
				end
			end
		end
	end
	if DebugEnabled then
		for pathType, rank in pairs(waypointstable) do
			EchoDebug(pathType .. ' = ' ..rank)
		end
	end
			
	return waypointstable
end


local function MapMobility()
	-- check for water map works like this:
	-- the map is divided into sectors, then center of each sector is tested if specific unit can be built there (water, kbot, vehicle)
	local mapSize = map:MapDimensions()
	ai.mobilityGridSize = math.floor(math.max(mapSize.x * 8, mapSize.z * 8) / 128)
	ai.mobilityGridSize = math.max(ai.mobilityGridSize, 32) -- don't make grids smaller than 32
	ai.mobilityGridSizeHalf = ai.mobilityGridSize/ 2
	EchoDebug("grid size: " .. ai.mobilityGridSize)
	local maxX = math.ceil((mapSize.x * 8) / ai.mobilityGridSize)
	local maxZ = math.ceil((mapSize.z * 8) / ai.mobilityGridSize)
	EchoDebug("Map size in grids: x "..maxX.." z "..maxZ)
	ai.mobilityGridMaxX = maxX
	ai.mobilityGridMaxZ = maxZ
	local mobCount = {}
	local totalCount = maxX * maxZ
	ai.mobilityGridArea = totalCount
	local half = ai.mobilityGridSizeHalf
	local pos = api.Position()
	pos.y = 0
	for mtype, utypes in pairs(mobUnitTypes) do
		mobMap[mtype] = {}
		mobCount[mtype] = 0
	end
	for x = 1, maxX do
		for mtype, utypes in pairs(mobUnitTypes) do
			mobMap[mtype][x] = {}
		end
		for z = 1, maxZ do
			-- all blocked unless unblocked below
			for mtype, utypes in pairs(mobUnitTypes) do
				mobMap[mtype][x][z] = 1
			end
			pos.x = (x * ai.mobilityGridSize) - half
			pos.z = (z * ai.mobilityGridSize) - half
			-- find out if each mobility type can exist there
			for mtype, utypes in pairs(mobUnitTypes) do
				local canbuild = false
				if ShardSpringLua then
					local uname = mobUnitExampleName[mtype]
					local uDef = UnitDefNames[uname]
					canbuild = Spring.TestMoveOrder(uDef.id, pos.x, Spring.GetGroundHeight(pos.x,pos.z), pos.z)
				else
					for _, utype in pairs(utypes) do
						canbuild = game.map:CanBuildHere(utype, pos)
						if canbuild then break end
					end
				end
				if canbuild then
					-- EchoDebug(mtype .. " at " .. x .. "," .. z .. " count " .. mobCount[mtype])
					mobCount[mtype] = mobCount[mtype] + 1
					mobMap[mtype][x][z] = 0
				end
			end
			-- EchoDebug(x .. "," .. z .. " sub " .. subMap[x][z] .. " bot " .. botMap[x][z] .. " veh " .. vehMap[x][z])
		end
	end
	return totalCount, maxX, maxZ, mobCount
end

local function InitializeTopology()
	ai.topology = {}
	for mtype, utypes in pairs(mobUnitTypes) do
		ai.topology[mtype] = {}
	end
	ai.topology["air"] = {}
	for x = 1, ai.mobilityGridMaxX do
		for mtype, utypes in pairs(mobUnitTypes) do
			ai.topology[mtype][x] = {}
		end
		ai.topology["air"][x] = {}
		for z = 1, ai.mobilityGridMaxZ do
			-- fill air topology with single network
			ai.topology["air"][x][z] = 1
		end
	end
end

local function MapSpotMobility(metals, geos)
	local half = ai.mobilityGridSizeHalf
	ai.networkSize = {}
	ai.mobNetworkGeos = {}
	ai.mobNetworkGeos['air'] = {}
	ai.mobNetworkGeos['air'][1] = geos
	ai.scoutSpots = {}
	ai.scoutSpots["air"] = {}
	ai.scoutSpots["air"][1] = {}
	local mobNetworkMetals = {}
	mobNetworkMetals["air"] = {}
	mobNetworkMetals["air"][1] = {}
	local mobSpots = {}
	local mobNetworks = {}
	local mobNetworkCount = {}
	for mtype, utypes in pairs(mobUnitTypes) do
		mobSpots[mtype] = {}
		mobNetworkMetals[mtype] = {}
		mobNetworkCount[mtype] = {}
		mobNetworks[mtype] = 0
		ai.networkSize[mtype] = {}
		ai.scoutSpots[mtype] = {}
		ai.mobNetworkGeos[mtype] = {}
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
				if game.map:CanBuildHere(UWMetalSpotCheckUnitType, spot) then
					table.insert(ai.UWMetalSpots, spot)
					landOrWater = 2
				else
					table.insert(ai.landMetalSpots, spot)
					landOrWater = 1
				end
			end
			local x = math.ceil(spot.x / ai.mobilityGridSize)
			local z = math.ceil(spot.z / ai.mobilityGridSize)
			for mtype, utypes in pairs(mobUnitTypes) do
				if mobMap and mobMap[mtype] and mobMap[mtype][x] and mobMap[mtype][x][z] == 0 then
					local thisNetwork
					if ai.topology[mtype][x][z] == nil then
						-- if topology is empty here, initiate a new network, and flood fill it
						mobNetworks[mtype] = mobNetworks[mtype] + 1
						thisNetwork = mobNetworks[mtype]
						mobNetworkCount[mtype][thisNetwork] = 1
						ai.networkSize[mtype][thisNetwork] = 0
						mobNetworkMetals[mtype][thisNetwork] = {}
						PlotDebug(x * ai.mobilityGridSize - ai.mobilityGridSizeHalf, z * ai.mobilityGridSize - ai.mobilityGridSizeHalf, mtype, thisNetwork)
						Flood4Topology(x, z, mtype, mobNetworks[mtype])
					else
						-- if topology isn't empty here, add this spot to its count
						thisNetwork = ai.topology[mtype][x][z]
						mobNetworkCount[mtype][thisNetwork] = mobNetworkCount[mtype][thisNetwork] + 1
					end
					table.insert(mobSpots[mtype], {x = x, z = z})
					if metalOrGeo == 1 then
						if landOrWater == 1 and mtype ~= "sub" and mtype ~= "shp" then
							table.insert(mobNetworkMetals[mtype][thisNetwork], spot)
						elseif landOrWater == 2 and mtype ~= "veh" and mtype ~= "bot" then
							table.insert(mobNetworkMetals[mtype][thisNetwork], spot)
						end
					else
						ai.mobNetworkGeos[mtype][thisNetwork] = ai.mobNetworkGeos[mtype][thisNetwork] or {}
						table.insert(ai.mobNetworkGeos[mtype][thisNetwork], spot)
					end
					ai.scoutSpots[mtype][thisNetwork] = ai.scoutSpots[mtype][thisNetwork] or {}
					table.insert(ai.scoutSpots[mtype][thisNetwork], spot)
				end
			end
			if metalOrGeo == 1 then table.insert(mobNetworkMetals["air"][1], spot) end
			table.insert(ai.scoutSpots["air"][1], spot)
		end
	end
	return mobSpots, mobNetworkMetals, mobNetworks, mobNetworkCount
end

local function MergePositions(posTable, cutoff, includeNonMerged)
	local list = {} -- make copy to prevent clearing table
	for k, v in pairs(posTable) do table.insert(list, v) end
	EchoDebug(#list .. " " .. cutoff)
	local merged = {}
	while #list > 0 do
		local lp = table.remove(list)
		local pos1 = api.Position()
		pos1.x, pos1.y, pos1.z = lp.x, lp.y, lp.z
		local merge = nil
		for i = #list, 1, -1 do
			local pos2 = list[i]
			local dist = Distance(pos1, pos2)
			if dist < cutoff then
				EchoDebug("merging " .. pos1.x .. "," .. pos1.z .. " with " .. pos2.x .. "," .. pos2.z .. " -- " .. dist .. " away")
				merge = MiddleOfTwo(pos1, pos2)
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
	EchoDebug(#merged)
	return merged
end

function MapHandler:GuessStartLocations(spots)
	if spots == nil then return end
	if #spots == 0 then
		EchoDebug("spot table for start location guessing is empty")
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
			local dist = Distance(from, to)
			if dist < minDist then
				minDist = dist
				closest = i
			end
			local middle = MiddleOfTwo(from, to)
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
	EchoDebug("tolerance: " .. tolerance .. "  cutoff: " .. cutoff)
	for i, l in pairs(links) do
		if l.dist < cutoff then
			EchoDebug("metal spot link at " .. math.ceil(l.middle.x) .. "," .. math.ceil(l.middle.z) .. " within cutoff with distance of " .. math.ceil(l.dist))
			table.insert(matches, l.middle)
		end
	end
	if #matches == 0 then return end

	-- merge matches close to each other
	local merged = MergePositions(matches, cutoff, false)
	if #merged < 2 then
		EchoDebug("not enough merged, using all matches")
		return matches
	else
		EchoDebug("using merged links")
		return merged
	end
end

function MapHandler:factoriesRating()
	local mtypesMapRatings = {}
	local factoryRating = {}
	ai.factoryBuilded = {}
	ai.factoryBuilded['air'] = {}
	for mtype, networks in pairs(ai.networkSize) do
		ai.factoryBuilded[mtype] = {}
		for network, size in pairs(networks) do
			local spots = ai.mobNetworkMetals[mtype][network] or {}
			spots = #spots
			if size > ai.mobilityGridArea * 0.20 and spots > (#ai.landMetalSpots + #ai.UWMetalSpots) * 0.4 then
				-- area large enough and enough metal spots
				ai.factoryBuilded[mtype][network] = 0 
			end
		end
	end
	ai.factoryBuilded['air'][1] = 0
	for mtype, unames in pairs(mobUnitNames) do
		local realMetals = 0
		local realSize = 0
		local realGeos = 0
		local spots = 0
		local geos= 0
		local realRating = ai.mobRating[mtype] / 100
		if ai.mobCount[mtype] ~= 0 then
			realSize = ai.mobCount[mtype] / ai.mobilityGridArea --relative area occupable
		end
		
		if #ai.landMetalSpots + #ai.UWMetalSpots ~= 0 then
			for network, index in pairs(ai.mobNetworkMetals[mtype]) do
				spots=spots + #index
			end
			realMetals = spots / (#ai.landMetalSpots + #ai.UWMetalSpots)--relative metals occupable
		end
		
		if #ai.geoSpots ~= 0 and mtype ~= ('shp' or 'sub') then 
			realGeos = math.min(0.1 * #ai.geoSpots,1) --if there are more then 10 geos is useless give it more weight on bestfactory type calculations
		end 
		
		-- mtypesMapRatings[mtype] = (( realMetals + realSize + realGeos) / 3) * realRating
		mtypesMapRatings[mtype] = (ai.mobRating[mtype] / ai.mobRating['air']) * mobilityEffeciencyMultiplier[mtype]
		-- area is not as important as number of metal and geo
		-- mtypesMapRatings[mtype] = (( realMetals + (realSize*0.5) + realGeos) / 2.5) * mobilityEffeciencyMultiplier[mtype]
		EchoDebug('mtypes map rating ' ..mtype .. ' = ' .. mtypesMapRatings[mtype])
	end
	mtypesMapRatings['air'] = mobilityEffeciencyMultiplier['air']


	local bestPath = 0
	for factory,mtypes in pairs(factoryMobilities)do
		local factoryPathRating = 0
		local factoryMtypeRating = 0
		if mtypes[1] ~='air' then
			local factoryBuildsCons = false
			for index, unit in pairs(unitTable[factory].unitsCanBuild) do
				local mtype = unitTable[unit].mtype
				if unitTable[unit].buildOptions then
					if (ai.hasUWSpots and mtype ~= 'veh') or (not ai.hasUWSpots and mtype ~= 'amp') then
					-- if ai.hasUWSpots or not (mtype == 'amp' and mtypes[1] == 'veh') then
						factoryBuildsCons = true
						break
					end
				end
			end
			EchoDebug(factory .. " builds cons: " .. tostring(factoryBuildsCons))
			local count = 0
			local maxPath = 0
			local mediaPath = 0
			for index, unit in pairs(unitTable[factory].unitsCanBuild) do
				local mtype = unitTable[unit].mtype
				local mclass = unitTable[unit].mclass
				if unitTable[unit].buildOptions or not factoryBuildsCons then
					local ok = true
					-- if ai.hasUWSpots or not (mtype == 'amp' and mtypes[1] == 'veh') then
					if (ai.hasUWSpots and mtype ~= 'veh') or (not ai.hasUWSpots and mtype ~= 'amp') then
						count = count + 1
						factoryMtypeRating = factoryMtypeRating + mtypesMapRatings[mtype]
						-- EchoDebug(factory .. ' ' .. unit .. ' ' .. unitTable[unit].mtype .. ' ' .. mtypesMapRatings[unitTable[unit].mtype])
						if ShardSpringLua then
							bestPath = math.max(maxPath,ai.spotPathMobRank[mclass])
							maxPath = math.max(maxPath,ai.spotPathMobRank[mclass])
							mediaPath = mediaPath + ai.spotPathMobRank[mclass]
						end
					end
				end
			end
			if count == 0 then 
				factoryMtypeRating = 0
			else
				factoryMtypeRating = factoryMtypeRating / count
			end
			if ShardSpringLua then
				if maxPath == 0 then
					mediaPath = 0
				else
					mediaPath = (mediaPath / count)/bestPath
					maxPath = maxPath /bestPath
					factoryPathRating = (maxPath + mediaPath) / 2
				end
			end
		else
			factoryPathRating = 1
			if #ai.landMetalSpots + #ai.UWMetalSpots == 0 then
				factoryMtypeRating = mtypesMapRatings['air']
			elseif unitTable[factory].needsWater then
				factoryMtypeRating = mtypesMapRatings['air'] * (#ai.UWMetalSpots / (#ai.landMetalSpots + #ai.UWMetalSpots))
			else
				factoryMtypeRating = mtypesMapRatings['air'] * (#ai.landMetalSpots / (#ai.landMetalSpots + #ai.UWMetalSpots))
			end
		end
		EchoDebug(factory .. ' mtype rating: ' .. factoryMtypeRating)

		local Rating
		if ShardSpringLua then
			EchoDebug(factory .. ' path rating: ' .. factoryPathRating)
			Rating = factoryPathRating * factoryMtypeRating * unitTable[factory].techLevel
		else
			Rating = factoryMtypeRating * unitTable[factory].techLevel
		end

		if factoryMobilities[factory][1] == ('hov') then
			Rating = Rating * (ai.mobCount['shp'] /ai.mobilityGridArea)
		end
		if factory == 'armfhp' or factory == 'corfhp' then 
			Rating = Rating * 0.999 -- better a ground one, nanos around
		end 
		Rating = Rating * -1--reverse the value to get the right order
		
		if Rating ~= 0 then --useless add factory totally out of mode
			factoryRating[factory] = Rating
			EchoDebug('factory rating ' .. factory ..' = ' .. factoryRating[factory])
		end
		
		
	end
	
	local sorting = {}
	local rank = {}
	
	for name, rating in pairs(factoryRating) do
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
			EchoDebug((i .. ' ' .. factoryName))
		end
	end
	return factoriesRanking, ranksByFactories
end

function MapHandler:Name()
	return "MapHandler"
end

function MapHandler:internalName()
	return "maphandler"
end

function MapHandler:SaveMapData()
	local mdfilename = MapDataFilename()
	EchoDebug("saving map data to " .. mdfilename)
	mapdatafile = io.open(mdfilename,'w')
	if mapdatafile ~= nil then
		EchoData("ai.mobilityGridSize", ai.mobilityGridSize)
		EchoData("ai.mobilityGridMaxX", ai.mobilityGridMaxX)
		EchoData("ai.mobilityGridMaxZ", ai.mobilityGridMaxZ)
		EchoData("ai.waterMap", ai.waterMap)
		EchoData("ai.mapHasGeothermal", ai.mapHasGeothermal)
		EchoData("ai.mobilityRatingFloor", ai.mobilityRatingFloor)
		EchoData("ai.hasUWSpots", ai.hasUWSpots)
		EchoData("ai.mobilityGridSizeHalf", ai.mobilityGridSizeHalf)
		EchoData("ai.mobilityGridArea", ai.mobilityGridArea)
		EchoData("ai.mobRating", ai.mobRating)
		EchoData("ai.mobCount", ai.mobCount)
		EchoData("ai.mobNetworks", ai.mobNetworks)
		EchoData("ai.networkSize", ai.networkSize)
		EchoData("ai.landMetalSpots", ai.landMetalSpots)
		EchoData("ai.UWMetalSpots", ai.UWMetalSpots)
		EchoData("ai.geoSpots", ai.geoSpots)
		EchoData("ai.startLocations", ai.startLocations)
		EchoData("ai.mobNetworkMetals", ai.mobNetworkMetals)
		EchoData("ai.scoutSpots", ai.scoutSpots)
		EchoData("ai.topology", ai.topology)
		mapdatafile:close()
	else
		EchoDebug("unable to write map data file " .. mdfilename)
	end
end

function MapHandler:LoadMapData()
	-- check for existing map data and load it
	local dataloaded = false
	local mdfilename = MapDataFilename()
	local mapdatafile = io.open(mdfilename ,"r")
	if mapdatafile ~= nil then
		mapdatafile:close()
		dofile(mdfilename)
		dataloaded = true
		EchoDebug("map data loaded from " .. mdfilename)
	end
	return dataloaded
end

function MapHandler:Update()
	-- workaround for shifting metal spots: map dats is reloaded every two minutess
	local f = game:Frame()
	if f > self.lastDataResetFrame + 3600 then
		-- self:LoadMapData()
		self.lastDataResetFrame = f
	end
end

function MapHandler:Init()
	if DebugDrawEnabled then
		self.map:EraseAll(4, 5)
	end

	local mapSize = self.map:MapDimensions()
	self.ai.elmoMapSizeX = mapSize.x * 8
	self.ai.elmoMapSizeZ = mapSize.z * 8

	-- factoryMobilities = self:GetFactoryMobilities()

	ai.conUnitPerTypeLimit = math.max(map:SpotCount() / 6, 4)--add here cause map:spotcount not correctly load or so
	ai.conUnitAdvPerTypeLimit = math.max(map:SpotCount() / 8, 2)
	ai.activeMobTypes = {}
	ai.factoryListMap = {}

	-- local dataloaded = self:LoadMapData()

	self.lastDataResetFrame = game:Frame()

	if dataloaded then
		return
	end

	ai.mobilityGridSize = 256 -- will be recalculated by MapMobility()

	for mtype, unames in pairs(mobUnitNames) do
		mobUnitTypes[mtype] = {}
		for i, uname in pairs(unames) do
			mobUnitTypes[mtype][i] = game:GetTypeByName(uname)
		end
	end
	UWMetalSpotCheckUnitType = game:GetTypeByName(UWMetalSpotCheckUnit)

	local totalCount, maxX, maxZ, mobCount = MapMobility()
	ai.mobilityGridMaxX = maxX
	ai.mobilityGridMaxZ = maxZ
	ai.mobCount = mobCount
	InitializeTopology()

	-- now let's see how much water we found
	EchoDebug("total sectors "..totalCount)
	local wetness = mobCount["sub"] * 100 / totalCount
	EchoDebug("map wetness is "..wetness)
	ai.waterMap = wetness >= 10
	EchoDebug("there is water on the map")

	for mtype, count in pairs(mobCount) do
		local ness = count * 100 / totalCount
		EchoDebug("map " .. mtype .. "-ness is " .. ness .. " and total grids: " .. count)
	end

	self.spots = game.map:GetMetalSpots()
	-- copy metal spots
	local metalSpots = {}
	for k, v in pairs(self.spots) do table.insert(metalSpots, v) end
	if #metalSpots > 1600 then
		-- metal map is too complex, simplify it
		metalSpots = self:SimplifyMetalSpots(metalSpots, 1600)
		self.spots = metalSpots
	end

	-- now let's find out are there any geo spots on the map
	-- and add them to allSpots
	-- supposedly they have "geo" in names (don't know of a better way)
	local tmpFeatures = map:GetMapFeatures()
	ai.mapHasGeothermal = false
	local geoSpots = {}
	if tmpFeatures then
		for _, feature in pairs(tmpFeatures) do
			if feature then
				tmpName = feature:Name()
				if tmpName == "geovent" then
					ai.mapHasGeothermal = true
					table.insert(geoSpots, feature:GetPosition())
				end
			end
		end
	end
	ai.geoSpots = geoSpots
	game:SendToConsole(#geoSpots, "geovents")

	ai.UWMetalSpots = {}
	ai.landMetalSpots = {}
	local mobSpots, mobNetworks, mobNetworkCount
	mobSpots, ai.mobNetworkMetals, mobNetworks, mobNetworkCount = MapSpotMobility(metalSpots, geoSpots)
	ai.mobNetworks = mobNetworks
	ai.hotSpot = self:SpotSimplyfier(metalSpots,geoSpots)
	if ShardSpringLua then
		ai.spotPathMobRank = self:SpotPathMobRank(ai.hotSpot)
	end
	for mtype, mspots in pairs(mobSpots) do
		EchoDebug(mtype .. " spots: " .. #mspots)
	end
	-- EchoDebug(" spots sub:" .. #mobSpots["sub"] .. " bot:" .. #mobSpots["bot"] .. " veh:" .. #mobSpots["veh"])
	for mtype, utypes in pairs(mobUnitTypes) do
		EchoDebug(mtype .. "  networks: " .. mobNetworks[mtype])
		for n, count in pairs(mobNetworkCount[mtype]) do
			EchoDebug("network #" .. n .. " has " .. count .. " spots and " .. ai.networkSize[mtype][n] .. " grids")
		end
	end


	-- deciding what kind of map it is
	local maxSpots = 0
	local minNetworks = 5
	local best = nil
	local mobRating = {}
	local totalRating = 0
	local numberOfRatings = 0
	for mtype, spots in pairs(mobSpots) do
		if #spots > maxSpots then
			if mobNetworks[mtype] < minNetworks then
				maxSpots = #spots
				minNetworks = mobNetworks[mtype]
				best = mtype
			end
		end
		local mostGrids = 0
		local mostSpots = 0
		if ai.networkSize[mtype] ~= nil then
			for n, size in pairs(ai.networkSize[mtype]) do
				if size > mostGrids and #ai.scoutSpots[mtype][n] > mostSpots then
					mostGrids = size
					mostSpots = #ai.scoutSpots[mtype][n]
				end
			end
		end
		if mobNetworks[mtype] == 0 then
			mobRating[mtype] = 0
		else
			mobRating[mtype] = ((mostSpots - mobNetworks[mtype]) + ((mostGrids / ai.mobilityGridArea) * mostSpots * 0.25))
		end
		totalRating = totalRating + mobRating[mtype]
		numberOfRatings = numberOfRatings + 1
		EchoDebug(mtype .. " rating: " .. mobRating[mtype])
	end

	-- add in bechmark air rating
	-- local airRating = (#ai.scoutSpots["air"][1] + (#ai.scoutSpots["air"][1] * 0.25)) * 0.5
	local airRating = #ai.scoutSpots["air"][1] + (#ai.scoutSpots["air"][1] * 0.25)
	mobRating['air'] = airRating
	totalRating = totalRating + airRating
	numberOfRatings = numberOfRatings + 1
	EchoDebug('air rating: ' .. airRating)
	local avgRating = totalRating / numberOfRatings
	local ratingFloor = avgRating * 0.65
	EchoDebug('average rating: ' .. avgRating)
	EchoDebug('rating floor: ' .. ratingFloor)
	ai.mobilityRatingFloor = ratingFloor

	ai.mobRating = mobRating

	ai.hasUWSpots = #mobSpots["sub"] > 0

	if ai.hasUWSpots then
		EchoDebug("MapHandler: Submerged metal spots detected")
	end

	-- find start locations (loading them into air's list for later localization)
	ai.startLocations = {}
	if ai.startLocations["air"] == nil then ai.startLocations["air"] = {} end
	ai.startLocations["air"][1] = self:GuessStartLocations(metalSpots)
	if ai.startLocations["air"][1] ~= nil then
		-- localize start locations into mobility networks
		for i, start in pairs(ai.startLocations["air"][1]) do
			EchoDebug("start location guessed at: " .. start.x .. ", " .. start.z)
			PlotDebug(start.x, start.z, "start")
			for mtype, networkList in pairs(ai.scoutSpots) do
				if mtype ~= "air" then -- air list is already filled
					for n, spots in pairs(networkList) do
						if ai.startLocations[mtype] == nil then ai.startLocations[mtype] = {} end
						if ai.startLocations[mtype][n] == nil then ai.startLocations[mtype][n] = {} end
						table.insert(ai.startLocations[mtype][n], start)
					end
				end
			end
		end
	end

	-- self:SaveMapData()

	-- cleanup
	mobMap = {}
	self.ai.factoriesRanking, self.ai.ranksByFactories = self:factoriesRating()

	self:DebugDrawMobilities()
end

function MapHandler:DebugDrawMobilities()
	if not DebugDrawEnabled then
		return
	end
	local size = ai.mobilityGridSize
	local halfSize = ai.mobilityGridSize / 2
	local squares = {}
	for mtype, xx in pairs(ai.topology) do
		if mtype ~= 'air' then
			for x, zz in pairs(xx) do
				squares[x] = squares[x] or {}
				for z, network in pairs(zz) do
					squares[x][z] = squares[x][z] or {}
					squares[x][z][#squares[x][z]+1] = {network=network, mtype=mtype}
				end
			end
		end
	end
	for x, zz in pairs(squares) do
		x = x * size
		for z, square in pairs(zz) do
			z = z * size
			local colorA = {0, 0, 0}
			local colorB = {0, 0, 0}
			local channels = {}
			for i = 1, #square do
				local layer = square[i]
				-- Spring.Echo(layer.mtype)
				local channel = mapChannels[layer.mtype][1]
				channels[channel] = true
				if channel == 4 then
					colorA = AddColors(colorA, mapColors[layer.mtype])
				elseif channel == 5 then
					colorB = AddColors(colorB, mapColors[layer.mtype])
				end
			end
			local pos1 = api.Position()
			local pos2 = api.Position()
			pos1.x = x - size
			pos1.z = z - size
			pos2.x = x
			pos2.z = z
			-- Spring.Echo(x, z, colorA[1], colorA[2], colorA[3], colorA[4], channels[4])
			colorA[4], colorB[4] = 0.33, 0.33
			if channels[4] then
				self.map:DrawRectangle(pos1, pos2, colorA, nil, true, 4)
			end
			if channels[5] then
				self.map:DrawRectangle(pos1, pos2, colorB, nil, true, 5)
			end
		end
	end
end

function MapHandler:SimplifyMetalSpots(metalSpots, number)
	-- for maps that are all metal for example
	-- pretend for the sake of calculations that there are only 100 metal spots
	local mapSize = self.map:MapDimensions()
	local maxX = mapSize.x * 8
	local maxZ = mapSize.z * 8
	local divisor = math.ceil(math.sqrt(number))
	local gridSize = math.ceil( math.max(maxX, maxZ) / divisor )
	local halfGrid = math.ceil( gridSize / 2 )
	local spots = {}
	for x = 0, maxX-gridSize, gridSize do
		for z = 0, maxZ-gridSize, gridSize do
			for i = 1, #metalSpots do
				local spot = metalSpots[i]
				if spot.x > x and spot.x < x + gridSize and spot.z > z and spot.z < z + gridSize then
					spots[#spots+1] = spot
					table.remove(metalSpots, i)
					break
				end
			end
		end
	end
	return spots
end
 
function MapHandler:ClosestFreeSpot(unittype, builder, position)

	-- local kbytes, threshold = gcinfo()
	-- game:SendToConsole("maphandler gcinfo: " .. kbytes .. " (before ClosestFreeSpot)")

	if position == nil then position = builder:GetPosition() end
	local spots = {}
	local bname = builder:Name()
	if commanderList[bname] then
		-- give the commander both hov and bot spots
		local pos = builder:GetPosition()
		local network = self:MobilityNetworkHere("bot", pos)
		if network ~= nil then
			-- EchoDebug("found bot metal spot network for commander")
			spots = ai.mobNetworkMetals["bot"][network]
		end
		network = self:MobilityNetworkHere("hov", pos)
		if network ~= nil then
			-- EchoDebug("found hover metal spot network for commander")
			if #spots == 0 then
				spots = ai.mobNetworkMetals["hov"][network]
			else
				for i, p in pairs(ai.mobNetworkMetals["hov"][network]) do
					table.insert(spots, p)
				end
			end
		end
		-- give the commander all metal spots if shp or bot doesn't work out
		if #spots == 0 then spots = ai.mobNetworkMetals["air"][1] end
	else
		local mtype, network = self:MobilityOfUnit(builder)
		if ai.mobNetworkMetals[mtype][network] ~= nil then
			spots = ai.mobNetworkMetals[mtype][network]
		end
	end
	if spots == nil then 
		EchoDebug(builder:Name() .. " has nil spots")
		return end
	if #spots == 0 then
		EchoDebug(builder:Name() .. " has zero spots")
		return
	end
	local uname = unittype:Name()
	local pos = nil
	local reclaimEnemyMex = false
	local bestDistance = 10000
 	-- check for armed enemy units nearby
	local uw = nil
	local uwutype = nil
	if ai.hasUWSpots then
		-- underwater mex check
		-- EchoDebug("map has uw spots")
		local coruwtype
		local armuwtype
		if uname == "cormex" or uname == "armmex" then
			coruwtype = game:GetTypeByName("coruwmex")
			armuwtype = game:GetTypeByName("armuwmex")
		elseif uname == "cormoho" or uname == "armoho" then
			coruwtype = game:GetTypeByName("coruwmme")
			armuwtype = game:GetTypeByName("armuwmme")
		end
		if coruwtype ~= nil then
			if builder:CanBuild(coruwtype) then
				uwutype = coruwtype
			elseif builder:CanBuild(armuwtype) then
				uwutype = armuwtype
			end
		end
		-- if uwutype ~= nil then EchoDebug("builder can build uw mexes") end
	end
	local f = game:Frame()
	for i,p in pairs(spots) do
		-- dont use this spot if we're already building there
		local alreadyPlanned = ai.buildsitehandler:PlansOverlap(p, uname)
		if not alreadyPlanned then
			local dist = Distance(position, p)
			-- don't add if it's already too high
			if dist < bestDistance then
				-- now check if we can build there
				local uwcheck
				if uwutype ~= nil then
					 uwcheck = game.map:CanBuildHere(uwutype, p)
					 -- EchoDebug("builder can build uw mex here? " .. tostring(uwcheck))
				end
				if game.map:CanBuildHere(unittype, p) or uwcheck then
					-- EchoDebug("can build mex at" .. p.x .. " " .. p.z)
					-- game:SendToConsole("before builder gets safe position", self.ai.id, ai.id, builder:Team())
					if ai.targethandler:IsSafePosition(p, builder) then
						bestDistance = dist
						pos = p
						reclaimEnemyMex = false
						if uwcheck then
							-- EchoDebug("uw mex is best distance")
							uw = uwutype
						else
							uw = nil
						end
					end
				elseif ai.targethandler:IsSafePosition(p, builder, 200) then
					-- is it an enemy mex that's blocking a safe position (or an unknown radar blip)?
					for i, enemySpot in pairs(ai.enemyMexSpots) do
						local epos = enemySpot.position
						if p.x > epos.x - 100 and p.x < epos.x + 100 and p.z > epos.z - 100 and p.z < epos.z + 100 then
							bestDistance = dist
							pos = epos
							reclaimEnemyMex = enemySpot.unit
							if uwcheck then
								-- EchoDebug("uw mex is best distance")
								uw = uwutype
							else
								uw = nil
							end
							break
						end
					end
				end
			end
		end
	end
	
	-- local kbytes, threshold = gcinfo()
	-- game:SendToConsole("maphandler gcinfo: " .. kbytes .. " (after ClosestFreeSpot)")

	-- if uw then EchoDebug("uw mex is final best distance") end
	return pos, uw, reclaimEnemyMex
end

function MapHandler:ClosestFreeGeo(unittype, builder, position)
	EchoDebug("closestfreegeo for " .. unittype:Name() .. " by " .. builder:Name())
	if not position then position = builder:GetPosition() end
	local bname = builder:Name()
	local uname = unittype:Name()
	local bestDistance, bestPos
	for i,p in pairs(self.ai.geoSpots) do
		-- dont use this spot if we're already building there
		if not ai.buildsitehandler:PlansOverlap(p, uname) and self:UnitCanGoHere(builder, p) and game.map:CanBuildHere(unittype, p) and ai.targethandler:IsSafePosition(p, builder) then
			local dist = Distance(position, p)
			if not bestDistance or dist < bestDistance then
				bestDistance = dist
				bestPos = p
			end
		end
	end
	return bestPos
end

function MapHandler:MobilityNetworkHere(mtype, position)
	if mtype == "air" then return 1 end
	local x = math.ceil(position.x / ai.mobilityGridSize)
	local z = math.ceil(position.z / ai.mobilityGridSize)
	local network
	if ai.topology[mtype][x] ~= nil then
		network = ai.topology[mtype][x][z]
	end
	return network
end

function MapHandler:MobilityOfUnit(unit)
	local position = unit:GetPosition()
	local name = unit:Name()
	local mtype = unitTable[name].mtype
	if ai.activeMobTypes[mtype] == nil then ai.activeMobTypes[mtype] = true end
	return mtype, self:MobilityNetworkHere(mtype, position)
end

function MapHandler:UnitCanGoHere(unit, position)
	if unit == nil then return false end
	if position == nil then return false end
	local mtype, unet = self:MobilityOfUnit(unit)
	if mtype == 'air' then return true end
	if ShardSpringLua then
		-- first check if it's even a valid move order
		local moveOrderTest = Spring.TestMoveOrder(unit:Type():ID(), position.x, position.y, position.z, nil, nil, nil, true, false)
		-- if mtype == 'air' then
		-- 	local newMoveOrderTest = Spring.TestMoveOrder(unit:Type():ID(), position.x, position.y, position.z)
		-- 	if moveOrderTest or newMoveOrderTest then
		-- 		Spring.Echo('air moveordertest', moveOrderTest, newMoveOrderTest)
		-- 		self.map:DrawPoint(position, {0, 0.25, 1}, 'air', 3)
		-- 	end
		-- 	return true
		-- end
		if not moveOrderTest then
			return false
		end
	end
	local pnet = self:MobilityNetworkHere(mtype, position)
	if unet == pnet then
		return true
	else
		-- EchoDebug(mtype .. " " .. tostring(unet) .. " " .. tostring(pnet))
		return false
	end
end

function MapHandler:UnitCanGetToUnit(unit1, unit2)
	local position = unit2:GetPosition()
	return self:UnitCanGoHere(unit1, position)
end

function MapHandler:UnitCanHurtVictim(unit, victim)
	if unit:WeaponCount() == 0 then return false end
	local vname = victim:Name()
	local mtype = unitTable[vname].mtype
	local name = unit:Name()
	local canhurt = false
	if unitTable[name].groundRange > 0 and mtype == "veh" or mtype == "bot" or mtype == "amp" or mtype == "hov" then
		canhurt = "ground"
	elseif unitTable[name].airRange > 0 and mtype == "air" then
		canhurt = "air"
	elseif unitTable[name].submergedRange > 0 and mtype == "shp" or mtype == "sub" or mtype == "amp" then
		canhurt = "submerged"
	end
	return canhurt
end

function MapHandler:MobilityNetworkSizeHere(mtype, position)
	if mtype == "air" then return ai.mobilityGridArea end
	local x = math.ceil(position.x / ai.mobilityGridSize)
	local z = math.ceil(position.z / ai.mobilityGridSize)
	if ai.topology[mtype][x] == nil then
		return 0
	elseif ai.topology[mtype][x][z] == nil then
		return 0
	else
		local network = ai.topology[mtype][x][z]
		return ai.networkSize[mtype][network]
	end
end

function MapHandler:AccessibleMetalSpotsHere(mtype, position)
	local network = self:MobilityNetworkHere(mtype, position)
	return self.ai.mobNetworkMetals[mtype][network] or {}
end

function MapHandler:AccessibleGeoSpotsHere(mtype, position)
	local network = self:MobilityNetworkHere(mtype, position)
	return self.ai.mobNetworkGeos[mtype][network] or {}
end

function MapHandler:AccessibleMetalGeoSpotsHere(mtype, position)
	local network = self:MobilityNetworkHere(mtype, position)
	return self.ai.scoutSpots[mtype][network] or {}
end

function MapHandler:IsUnderWater(position)
	if ShardSpringLua then return Spring.GetGroundHeight(position.x, position.z) < 0 end
	local x = math.ceil(position.x / ai.mobilityGridSize)
	local z = math.ceil(position.z / ai.mobilityGridSize)
	if ai.topology["sub"][x] ~= nil then
		if ai.topology["sub"][x][z] then return true end
	end
	return false
end

function MapHandler:OutmodedFactoryHere(mtype, position, network)
	if mtype == "air" then return false end
	if position and network == nil then
		network = self:MobilityNetworkHere(mtype, position)
	end
	if network == nil then
		return false
	else
		if ai.networkSize[mtype][network] < ai.mobCount[mtype] * 0.67 and ai.mobNetworks[mtype] > 1 then
	 		return true
		else
			return false
		end
	end
end

function MapHandler:CheckDefenseLocalization(unitName, position)
	local size = 0
	if unitTable[unitName].groundRange > 0 then
		local vehsize = self:MobilityNetworkSizeHere("veh", position)
		local botsize = self:MobilityNetworkSizeHere("bot", position)
		size = math.max(vehsize, botsize)
	elseif unitTable[unitName].airRange > 0 then
		return true
	elseif  unitTable[unitName].submergedRange > 0 then
		size = self:MobilityNetworkSizeHere("sub", position)
	else
		return true
	end
	local minimumSize = ai.mobilityGridArea / 4
	EchoDebug("network size here: " .. size .. ", minimum: " .. minimumSize)
	if size < minimumSize then
		return false
	else
		return true
	end
end
