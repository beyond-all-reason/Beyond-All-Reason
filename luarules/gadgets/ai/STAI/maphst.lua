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
	local rules_param_mex_count = Spring.GetGameRulesParam("mex_count")
	self:EchoDebug('games rules param mex_count:',rules_param_mex_count)

	self.DebugEnabled = false
	self:EchoDebug('MapHST START')
	if self.map_loaded then
		print('map already loaded')
		return
	end
	self:basicMapInfo()
	--self:InitPathCost()
	self.topology = {air = {}}
	self:createGrid()
	self.METALS = map:GetMetalSpots()
	self.GEOS = map:GetGeoSpots()
	self.METALS = self:SimplifyMetalSpots(self.gridSize * 2)-- is a random choice, can be 1 or 9999999999
	self.allSpots = self.ai.tool:tableConcat({self.METALS,self.GEOS})
	self.hotSpots = {}
	self:hotSpotter()
	self.waterMetals = {}
	self.groundMetals = {}
	self.networks = {} --hold data in a "specific network" area(about GAS (area,mex,geos,trampling)
	self.layers = {} --hold the "global layer" data about a GAS (area,mex,geos,trampling)
	self.startLocations = {}
	self.ai.armyhst.UWMetalSpotCheckUnitType = self.game:GetTypeByName(self.ai.armyhst.UWMetalSpotCheckUnit)
	self:gridAnalisy()
	self:metalScan()
	self:geoScan()
	self:LayerScan()
	self.trampledCells = {}
	self:DrawDebug()
	self.map_loaded = true
	collectgarbage("collect")
	self:EchoDebug('MapHST STOP')
end

function MapHST:PosToHeightMap(pos)
	local x = (pos.x / 8) + 1
	local z = (pos.z / 8) + 1
	return x,z
end

function MapHST:HeightMapToPos(x,z)
	local pos = {}
	pos.x = x - 1 * 8
	pos.z = z - 1 * 8
	pos.y = map:GetGroundHeight(pos.x,pos.z)
	return pos
end

function MapHST:PosToNodeIndex(pos)
	local X,Z = self:PosToGrid(pos)
	return self:GridToNodeIndex(X,Z)
end

function MapHST:GridToNodeIndex(X,Z)
	return (((X - 1) *self.ai.maphst.gridSideX) + Z) -1
end

function MapHST:NodeIndexToGrid(index)
	index = index + 1
	local Z = index % self.gridSideX
	index = index - Z
	local X = index / self.gridSideX
	return X,Z
end

function MapHST:NormalizeHeighMapIndex(index)
	return index - 1
end

function  MapHST:NodeIndexToPos(index)
	local X,Z = self: NodeIndexToGrid(index)
	return self:GridToPos(X,Z)
end

function MapHST:NodeIndexToHeighMap(index)
	local pos = self:NodeIndexToPos(index)
	return self:PosToHeightMap(pos)
end

--[[function MapHST:Update()
	self:EchoDebug('MapHST Update')
	local f = self.game:Frame()
	if f % 100 == 0 then
		self:EchoDebug('MapHST Update',f)
		Spring.Echo(Spring.GetPathNodeCosts(game:GetTeamID()))
		print(game:GetTeamID())
		Spring.Echo('reset layer node costs',Spring.SetPathNodeCosts(game:GetTeamID()))
		for X,row in pairs(self.GRID) do
			for Z,CELL in pairs(row) do
				local hx = CELL.POS.x / 8 + 1
				local hz = CELL.POS.z / 8 + 1
				local cost = Spring.GetPathNodeCost(game:GetTeamID(),hx,hz)
				--if cost ~= 0 then
					Spring.MarkerAddPoint(CELL.POS.x,CELL.POS.y,CELL.POS.z, cost)
				--end
				
			end
		end
	end
end]]

function MapHST:InitPathCost()
	self:EchoDebug('init path test')
 	--local id = game:GetTeamID()
--
 	self.heightMapX = (self.elmoMapSizeX / 512)
 	self.heightMapZ = (self.elmoMapSizeZ / 512)
-- 	self:EchoDebug('self.heightMapX',self.heightMapX,'self.heightMapZ',self.heightMapZ)
-- 	self:EchoDebug(Spring.GetPathNodeCosts(id))
	self:EchoDebug('INIT new array node cost',Spring.InitPathNodeCostsArray(game:GetTeamID(),self.heightMapX,self.heightMapZ))
	local cost = 0
	local index = 1
	local heightpow = self.heightMapX * self.heightMapZ
	local halfheightX = self.heightMapX /2
	local halfheightZ = self.heightMapZ /2
	for i=1,self.heightMapX do
		
		for j=1,self.heightMapZ do

			cost = (cost +  math.abs (index+((heightpow)/2) - (heightpow))*-1)+(heightpow)/2
			Spring.SetPathNodeCost(game:GetTeamID(),index,cost)
			--self:EchoDebug('init path node cost',i,j,Spring.GetPathNodeCost(id,i,j))
			cost = 0
			index = index + 1
		end
	end
	self:EchoDebug('SET new array node layer non sync',Spring.SetPathNodeCosts(game:GetTeamID()))
-- 	self:EchoDebug(#Spring.GetPathNodeCosts(game:GetTeamID()))
-- 	self:EchoDebug(Spring.SetPathNodeCost(game:GetTeamID(),0,123))
-- 	self:EchoDebug(Spring.SetPathNodeCost(game:GetTeamID(),1,111))
--
-- 	self:EchoDebug(Spring.SetPathNodeCost(game:GetTeamID(),575,999))
-- 	self:EchoDebug(Spring.SetPathNodeCost(game:GetTeamID(),576,987))
--
-- 	self:EchoDebug(Spring.SetPathNodeCosts(id))
-- 	for i,v in pairs(Spring.GetPathNodeCosts(game:GetTeamID())) do
-- 		if v > 0 then
-- 			self:EchoDebug('get path node cost',i,v)
-- 		end
-- 	end
-- 	self:EchoDebug(Spring.SetPathNodeCost(game:GetTeamID(),0,0))
-- 	self:EchoDebug(Spring.SetPathNodeCost(game:GetTeamID(),1,0))
--
-- 	self:EchoDebug(Spring.SetPathNodeCost(game:GetTeamID(),575,0))
-- 	self:EchoDebug(Spring.SetPathNodeCost(game:GetTeamID(),576,0))
	self:EchoDebug('end init path test')

end

function MapHST:basicMapInfo()--capture and set foundamental map info
	self.mapSize = map:MapDimensions()
	self.elmoMapSizeX = self.mapSize.x * 8
	self.elmoMapSizeZ = self.mapSize.z * 8
	self.elmoMapCenter = {x = self.elmoMapSizeX/2,y = map:GetGroundHeight(self.elmoMapSizeX/2,self.elmoMapSizeZ/2), z = self.elmoMapSizeZ/2}
	self.elmoMapMaxCenterDistance = self.ai.tool:distance({x=0,y=0,z=0},self.elmoMapCenter)
	self.elmoMapMaxDistance = self.ai.tool:distance({x=0,y=0,z=0},{x=self.elmoMapSizeX,y = 0,z=self.elmoMapSizeZ})
	self:EchoDebug('self.elmoMapMaxDistance',self.elmoMapMaxDistance,'self.elmoMapMaxCenterDistance',self.elmoMapMaxCenterDistance)
	self:EchoDebug(self.ai.tool:gcd(self.elmoMapSizeX,self.elmoMapSizeZ))
	self.elmoArea = self.elmoMapSizeX * self.elmoMapSizeZ
	self.gridSize = 256 --math.max( math.floor(math.max(MapHST.mapSize.x * 8, MapHST.mapSize.z * 8) / 128),32)-- don't make grids smaller than 32
	self.gridSizeHalf = self.gridSize / 2
	self.gridSizeDouble = self.gridSize * 2
	self.gridSideX = self.elmoMapSizeX / self.gridSize
	self.gridSideZ = self.elmoMapSizeZ / self.gridSize
	self.gridArea = self.gridSideX * self.gridSideZ
	self:EchoDebug('ElmoX',self.elmoMapSizeX , 'ElmoZ',self.elmoMapSizeZ ,'ElmoArea',self.elmoArea)
	self:EchoDebug("grid size: " .. self.gridSize ..'grid area', self.gridArea,self.gridSideX,self.gridSideZ)
end

function MapHST:createGrid()
	self.GRID = {}
	for X = 1, self.gridSideX do
		if not self.GRID[X] then
			self.GRID[X] = {}
		end
		for Z = 1, self.gridSideZ do
			self.GRID[X][Z] = self:NewCell(X,Z)
		end
	end
end

function MapHST:RawPosIsInMap(x,y,z)
	if (x <= 0) or (x > self.elmoMapSizeX) or (z <= 0) or (z > self.elmoMapSizeZ) then
		self:EchoDebug("bad position: " .. pos.x .. ", " .. pos.z)
		return nil
	else
		return x,y,z
	end
end

function MapHST:isInMap(pos)
	if (pos.x <= 0) or (pos.x > self.elmoMapSizeX) or (pos.z <= 0) or (pos.z > self.elmoMapSizeZ) then
		self:EchoDebug("bad position: " .. pos.x .. ", " .. pos.z)
		return nil
	else
		return pos
	end
end

function MapHST:PosToGrid(pos)
	local X = math.ceil(pos.x / self.gridSize)
	local Z = math.ceil(pos.z / self.gridSize)
	if not self.GRID[X] or not self.GRID[X][Z] then
		self:EchoDebug( X,Z,'is out of GRID',pos.x,pos.z)
	end
	return X, Z
end

function MapHST:RawPosToGrid(x,y,z)
	local X = math.ceil(x / self.gridSize)
	local Z = math.ceil(z / self.gridSize)
	if not self.GRID[X] or not self.GRID[X][Z] then
		self:EchoDebug( X,Z,'is out of GRID',x,z)
	end
	return X, Z
end

function MapHST:IsCellInGrid(X,Z)
	if X < 1 or Z < 1 or X > self.gridSideX or Z > self.gridSideZ then
		return nil
	end
	return true
end

function MapHST:GridToPos(X,Z)
	local pos = {}
	pos.x = X * self.gridSize - self.gridSizeHalf
	pos.z = Z * self.gridSize - self.gridSizeHalf
	pos.y  = map:GetGroundHeight(pos.x,pos.z)
	if not self:isInMap(pos) then
		self:Warn(pos.x,pos.z,'is not in map')
		return
	end
	return pos
end

function MapHST:GridToRawPos(X,Z)
	local x = X * self.gridSize - self.gridSizeHalf
	local z = Z * self.gridSize - self.gridSizeHalf
	local y  = map:GetGroundHeight(x,z)
	if not self:RawPosIsInMap(x,y,z) then
		self:Warn(x,z,'is not in map')
		return
	end
	return x,y,z
end

function MapHST:NewCell(gx, gz)
	local x = (gx * self.gridSize) - self.gridSizeHalf
	local z = (gz * self.gridSize) - self.gridSizeHalf
	local cellPos = {}
	cellPos.x, cellPos.z = x, z
	cellPos.y = Spring.GetGroundHeight(x, z)
	self:isInMap(cellPos)--move here ,is in map!!
	local cell = {}
	cell.POS = cellPos --the cell position
	cell.X = gx --the cell coordinate X on the grid
	cell.Z = gz --the cell coordinate Z on the grid
	cell.moveLayers = self:moveLayerTest(cellPos) --hold the  layers and networks in this cell
	cell.metalSpots = {} --hold the metalSpots of this cell
	cell.geoSpots = {} --hold the geoSpots of this cell
	cell.allSpots = {} --hold all the interesting spots
	cell.trampled = 0 --how many times it is trampled by non-flying units
	return cell
end

function MapHST:areaCells(X,Z,R,grid) -- return alist of cells in range R from a cell
	if not X or not Z then
		self:Warn('no grid XZ for areacells')
	end
	local AC = {}
	R = R or 0
	for x = X - R , X + R,1  do
		for z = Z - R , Z + R,1 do
			if grid[x] and grid[x][z] then
				table.insert(AC, grid[x][z])
			end
		end
	end
	return AC
end

function MapHST:GetCell(X,Z,grid) --accept 1one position({t.x,t.y,t.z}) OR 2two XZ grid coordinate; return a CEll if exist
	local grid = grid
	if type(X) == 'table' and X.x and X.z then
		grid = Z
		X,Z = self:PosToGrid(X)
	end
	if not grid[X] then
		return
	end
	if not grid[X][Z] then
		return
	end
	return grid[X][Z]
end

function MapHST:getCellsFields(p,fields,range,grid) --return the required list of values of a cell/cells
	if not fields or not p or type(fields) ~= 'table' then
		self:Warn('incomplete or incorrect params for get cells params',p,fields,range,grid)
		return
	end
	range = range or 0
	local X, Z = self:PosToGrid(p)
	local cells = self:areaCells(X,Z,range,grid)
	local value = 0 --VALUE is a total count of all request fields
	local subValues = {} --subValues is the sum of this fields of each asked cell
	for i, f in pairs(fields) do
		subValues[f] = 0
	end
	for index , cell in pairs(cells) do
		for i, field in pairs(fields) do
			value = value + cell[field]
			subValues[field] = subValues[field] + cell[field]
		end
	end
	return value , subValues , cells
end

function MapHST:moveLayerTest(pos)--check where units can stay or not
	local layers = {}
	layers.air = 1
	for layer,unitName in pairs(self.ai.armyhst.mobUnitExampleName) do
		if not self.topology[layer] then
			self.topology[layer] = {}
		end
		if Spring.TestMoveOrder(self.ai.armyhst.unitTable[unitName].defId, pos.x, pos.y, pos.z,nil,nil,nil,true,false,true) then
			layers[layer] = 0
		else
			layers[layer] = false
		end
	end
	return layers
end

function MapHST:gridAnalisy()--do the first analisy of the grid
	local net = {}
	for X,Zetas in pairs(self.GRID) do
		for Z, CELL in pairs(Zetas) do
			for layer,anteNetwork in pairs(CELL.moveLayers) do
				if anteNetwork == 0 then
					if not net[layer] then
						net[layer] = 0
						self.networks[layer] = {}
					end
					net[layer] = net[layer] + 1
					self.networks[layer][net[layer]] = {}
					self.networks[layer][net[layer]].area = 0
					self.networks[layer][net[layer]].metals = {}
					self.networks[layer][net[layer]].geos = {}
					self.networks[layer][net[layer]].allSpots = {}
					self:TopologyFooded(X,Z,layer,net)
				end
			end
		end
	end
	self.networks.air = {}
	self.networks.air[1] = {
		area = self.gridArea,
		metals = {},
		geos = {},
		allSpots = {}
		}
end

function MapHST:LayerScan() --a most approfondite analisy of the layers
	for layer,net in pairs(self.networks) do
		local main = {}
		main[layer] = {}
		main[layer].area = 0
		main[layer].metals = 0
		main[layer].geos = 0
		main[layer].allSpots = 0
		main[layer].ratioArea = 0
		main[layer].ratioMetals = 0
		main[layer].ratioGeos = 0
		for index,network in pairs(net) do
			network.allSpots = self.ai.tool:tableConcat({network.metals,network.geos})
			network.ratioArea = network.area / self.gridArea
			if #network.allSpots == 0 or #self.allSpots == 0 then
				network.ratioSpots = 0
			else
				network.ratioSpots = #network.allSpots / #self.allSpots
			end

			if #network.metals == 0 or #self.METALS == 0 then
				network.ratioMetals = 0
			else
				network.ratioMetals = #network.metals / #self.METALS
			end

			if #network.geos == 0 or #self.GEOS == 0 then
				network.ratioGeos = 0
			else
				network.ratioGeos = #network.geos / #self.GEOS
			end
			self:EchoDebug(layer,'Network :',index,network.area,#network.metals,#network.geos,network.ratioArea,network.ratioMetals,network.ratioGeos)
			main[layer].area 		= main[layer].area + network.area
			main[layer].metals 		= main[layer].metals + #network.metals
			main[layer].geos 		= main[layer].geos + #network.geos
			main[layer].allSpots 	= main[layer].allSpots + #network.metals + #network.geos
		end
		main[layer].ratioArea 	= main[layer].area / self.gridArea
		if main[layer].metals == 0 or #self.METALS == 0 then
			main[layer].ratioMetals = 0
		else
			main[layer].ratioMetals = main[layer].metals / #self.METALS
		end
		if main[layer].geos == 0 or #self.GEOS == 0 then
			main[layer].ratioGeos 	=  0
		else
			main[layer].ratioGeos 	= main[layer].geos / #self.GEOS
		end
		self.layers[layer] = main[layer]

	self:EchoDebug('layers',layer,main[layer].area,main[layer].metals,main[layer].geos,main[layer].ratioArea,main[layer].ratioMetals,main[layer].ratioGeos)
	end
end

function MapHST:TopologyFooded(x, z, layer,net)--rolling on the cell to extrapolate where unit can go
	if x > self.gridSideX or x < 1 or z > self.gridSideZ or z < 1 then
		return
	end
	if self.GRID[x][z].moveLayers[layer] == 0   then
		self.GRID[x][z].moveLayers[layer] = net[layer]
		self.topology[layer][x] =  self.topology[layer][x] or {}
		self.topology[layer][x][z] = true
		self.networks[layer][net[layer]].area = self.networks[layer][net[layer]].area + 1
		for X = -1, 1,1 do
			for Z = -1,1,1 do
				if x ~= x + X or z ~= z + Z then
					self:TopologyFooded(x+X,z+Z,layer,net)
				end
			end
		end
	end
end



function MapHST:hotSpotter()
	local spots = {}
	local mirrorspots = {}
	local limit = (self.map:MapDimensions())
	local limit = limit.x/2  + limit.z/2
	for i,v in pairs(self.METALS) do
		table.insert(spots,v)
	end
	for i,v in pairs(self.GEOS) do
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

function MapHST:SimplifyMetalSpots(number) --reduce the number of metal spots for speed metal maps
	if #self.METALS <= 1024 then-- metal map is too complex, simplify it
		return self.METALS
	end
	local spots = {}
	local spotsCount = 0
	for x = 0, self.elmoMapSizeX - number, number do
		for z = 0, self.elmoMapSizeX - number, number do
			for i,spot in pairs (self.METALS) do
				if spot.x > x and spot.x < x + number and spot.z > z and spot.z < z + number then
					spotsCount = spotsCount + 1
					spots[spotsCount] = spot
					table.remove(self.METALS, i)
					break
				end
			end
		end
	end
	return spots
end

function MapHST:metalScan()--insert MEX in to the correct CELL and layer's network
	for i, spot in pairs(self.METALS) do
		local CELL = self:GetCell(spot,self.GRID)
		if not CELL then
			self:EchoDebug('no cell for this metal spot',spot)
			return
		end
		table.insert(CELL.metalSpots,spot)
		for layer,nets in pairs(self.networks) do
			if CELL.moveLayers[layer] then
				table.insert(self.networks[layer][CELL.moveLayers[layer]].metals,spot)
			end
		end
		if map:CanBuildHere(self.ai.armyhst.UWMetalSpotCheckUnitType, spot) then
			table.insert(self.waterMetals, spot)
		else
			table.insert(self.groundMetals, spot)
		end
	end
end

function MapHST:geoScan()--insert GEOS in to the correct CELL and layer's network
	for i, spot in pairs(self.GEOS) do
		local CELL = self:GetCell(spot,self.GRID)
		if not CELL then
			self:EchoDebug('no cell for this geo spot',spot)
			return
		end
		table.insert(CELL.geoSpots,spot)
		for layer,nets in pairs(self.networks) do
			if CELL.moveLayers[layer] then
				table.insert(self.networks[layer][CELL.moveLayers[layer]].geos,spot)
			end
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
			local dist = self.ai.tool:distance(pos1, pos2)
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


function MapHST:getPath(unitName,POS1,POS2,toGrid)
	local mclass = self.ai.armyhst.unitTable[unitName].mclass
	local pathObject = map:GetPathObject(mclass, POS1.x,POS1.y,POS1.z, POS2.x,POS2.y,POS2.z)
	if not pathObject then 
		self:Warn('no path found',POS1,POS2) 
		return
	end
	local waypoints = map:GetPathWaypoints(pathObject)
	if not waypoints then
		self:Warn('no waypoints for the object found',POS1,POS2)
		return
	end
	if toGrid then
		waypoints = self:gridThePath(waypoints)
	end
	return waypoints
	
end
function MapHST:gridThePath(wp,factor)
	factor = factor or self.gridSize
	local prev = #wp
	for i = #wp,1,-1 do
		if i and i ~= prev then
			if self.ai.tool:RawDistance(wp[prev][1],wp[prev][2],wp[prev][3],wp[i][1],wp[i][2],wp[i][3]) < factor then
				table.remove(wp,i)
				prev = prev - 1
			else
				prev = i
			end
		end
	end
	for index,pos in pairs(wp) do
		pos.x = table.remove(pos,1)
		pos.y = table.remove(pos,1)
		pos.z = table.remove(pos,1)
	end
	return wp
end

function MapHST:UnitMexMoveTest(testUnit)--check how many time a unit(i chose commander) walk on a CELL, the analisy is from cell to cell foreach cell, CAUTION is heavy computable
	self:EchoDebug('UnitMexMoveTest  START')
	local counter = 0
	local testUnitName = testUnit.unit:Internal():Name()
	local testUnitPos = testUnit.unit:Internal():GetPosition()
	self.ttt={trampled = 0}
	local first,firstX,firstZ
	local wpos,wposX,wposZ
	local waypoints
	local  total = 0
	for index1 , POS1 in pairs(self.METALS) do
		waypoints = self:getPath(testUnitName,testUnitPos,POS1,true)
		if  waypoints then
			counter = counter + 1
			first = table.remove(waypoints)
			
			for i,v in pairs(waypoints) do
				firstX,firstZ = self:PosToGrid(first)
				wpos = table.remove(waypoints)
				wposX,wposZ = self:PosToGrid(wpos)
				if firstX ~= wposX or firstZ ~= wposZ then
					self.GRID[firstX][firstZ].trampled = self.GRID[firstX][firstZ].trampled + (2 + (self.ai.tool:distance(wpos,self.elmoMapCenter)/self.elmoMapMaxCenterDistance)) *(1-((self.ai.tool:distance(testUnitPos,POS1)/self.elmoMapMaxDistance)))
					total = total + 1

					self.ttt.trampled = math.max(self.ttt.trampled,self.GRID[firstX][firstZ].trampled)
					first = wpos
				end
			end
		end
	
	end
	local sum = 0
	local count = 0
	local average = 0
	for X, Zetas in pairs(self.GRID) do
		for Z, CELL in pairs(Zetas) do
			if CELL.trampled > 0 then
				
				sum = sum + CELL.trampled
				count = count + 1
			end
		end
	end	
	average = sum / count
	self:EchoDebug('average trampled',average)
	for X, Zetas in pairs(self.GRID) do
		for Z, CELL in pairs(Zetas) do
			if CELL.trampled < average * 1.5 then
				CELL.trampled = nil
			else 
				table.insert(self.trampledCells,CELL.POS)
			end

		end
	end
	self:EchoDebug(counter,'mobility commander evalutated:', 'most trampled',self.ttt.trampled,'average',average)
end

function MapHST:SetStartLocation()-- find start locations (loading them into air's list for later localization)
	if self.startLocations["air"] == nil then
		self.startLocations["air"] = {}
	end
	self.startLocations["air"][1] = self:GuessStartLocations(self.METALS)
	if self.startLocations["air"][1] ~= nil then
		-- localize start locations into mobility networks
		for i, start in pairs(self.startLocations["air"][1]) do
			self:EchoDebug("start location guessed at: " .. start.x .. ", " .. start.z)
			for layer, net in pairs(self.networks) do
				if layer ~= "air" then -- air list is already filled
					for index, network in pairs(layer) do
						if self.startLocations[layer] == nil then self.startLocations[layer] = {} end
						if self.startLocations[layer][index] == nil then self.startLocations[layer][index] = {} end
						table.insert(self.startLocations[layer][index], start)
					end
				end
			end
		end
	end
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
			local dist = self.ai.tool:distance(from, to)
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

function MapHST:ClosestFreeMex(unittype, builder, position)--get the closest free metal spot for the request unittype
	position = position or builder:GetPosition()
	local layer, net = self:MobilityOfUnit(builder)
	local uname = unittype:Name()
	local spotPosition = true
	if not layer or not net then return end
	local sortlist = self.ai.tool:sortByDistance(position,self.networks[layer][net].metals)
	local CELL
	for index, spot in pairs(sortlist) do
		spotPosition = true
		if spotPosition and not self.ai.buildingshst:PlansOverlap(spot, uname) then
			self:EchoDebug(spot.x,spot.z,'dont overlap')
		else
			self:EchoDebug(spot.x,spot.z,'reject cause Plans Overlap')
			spotPosition = false
		end
		if spotPosition and map:CanBuildHere(unittype, spot) then
			self:EchoDebug(spot.x,spot.z,'is buildable')
		else
			self:EchoDebug(spot.x,spot.z,'reject cause CANTBUILDHERE')
			spotPosition = false
		end
		
		CELL = self:GetCell(spot,self.ai.loshst.ENEMY)
		if spotPosition and  (not CELL or CELL.ENEMY == 0) then
			self:EchoDebug(spot.x,spot.z,'no enemy')
		else
			self:EchoDebug(spot.x,spot.z,'reject cause ENEMY')
			spotPosition = false
		end
		if spotPosition and self.ai.targethst:IsSafeCell(spot, builder) then
			self:EchoDebug(spot.x,spot.z,'is safe')
		else
			self:EchoDebug(spot.x,spot.z,'reject cause NOTSAFE')
			spotPosition = false
		end

		if spotPosition and self:UnitCanGoHere(builder, spot) then
			self:EchoDebug(spot.x,spot.z,'is reachable')
		else
			self:EchoDebug(spot.x,spot.z,'reject cause CANT GO HERE')
			spotPosition = false
		end
		if spotPosition == true then
			return spot
		end
	end
	--[[for index, spot in pairs(sortlist) do
		if self:UnitCanGoHere(builder, spot) then
			if not self.ai.buildingshst:PlansOverlap(spot, uname) then
				if self.ai.targethst:IsSafeCell(spot, builder) then
					if map:CanBuildHere(unittype, spot) then
						local CELL = self:GetCell(spot,self.ai.loshst.ENEMY)
						if not CELL or CELL.ENEMY == 0 then
							return spot
						else
							self:EchoDebug(spot.x,spot.z,'reject cause ENEMY')
						end
					else
						self:EchoDebug(spot.x,spot.z,'reject cause CANTBUILDHERE')
					end
				else
					self:EchoDebug(spot.x,spot.z,'reject cause NOTSAFE')
				end
			else
				self:EchoDebug(spot.x,spot.z,'reject cause PLANsOverlap')
			end
		else
			self:EchoDebug(spot.x,spot.z,'reject cause CANT GO HER')
		end
	end
	return spotPosition]]
end

function MapHST:ClosestFreeGeo(unittype, builder, position)--get the closest free geo spot for the request unittype
	self:EchoDebug("closestfreegeo for " .. unittype:Name() .. " by " .. builder:Name())
	if not position then position = builder:GetPosition() end
	local layer, net = self:MobilityOfUnit(builder)
	local uname = unittype:Name()
	local bestDistance, bestPos
	for i,p in pairs(self.networks[layer][net].geos) do----(self.GEOS) do
		-- dont use this spot if we're already building there
		if not self.ai.buildingshst:PlansOverlap(p, uname) and self:UnitCanGoHere(builder, p) and self.map:CanBuildHere(unittype, p) and self.ai.targethst:IsSafeCell(p, builder) then
			local dist = self.ai.tool:distance(position, p)
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
	local cell = self:GetCell(position,self.GRID)
	if cell then
		return cell.moveLayers[mtype]
	end
end

function MapHST:MobilityOfUnit(unit)
	local position = unit:GetPosition()
	local name = unit:Name()
	local mtype = self.ai.armyhst.unitTable[name].mtype
	return mtype, self:MobilityNetworkHere(mtype, position)
end

function MapHST:UnitCanGoHere(unit, position,maxDistance)
	if not unit  or not position then return false end
	local mtype, unet = self:MobilityOfUnit(unit)
	if mtype == 'air' then return true end
	
	maxDistance = maxDistance or 128
	local ux,uy,uz = unit:GetRawPos()
	if self.ai.tool:RawDistance(ux,uy,uz,position.x,position.y,position.z) < 32  then
		self:EchoDebug(unit:Name(),'ask for a short pathtest: pass')
		return 32
	end
	local pathtest = map:TestPath(self.ai.armyhst.unitTable[unit:Name()].mclass,ux,uy,uz ,position.x,position.y,position.z,nil,unit:Name())
	if pathtest and pathtest < maxDistance then
		self:EchoDebug(unit:Name(),'ask for a pathtest: pass')
		return pathtest
	end
end

function MapHST:UnitCanGetToUnit(unit1, unit2)
	local position = unit2:GetPosition()
	return self:UnitCanGoHere(unit1, position)
end

function MapHST:MobilitynetworkSizeHere(layer, position)
	if layer == "air" then return self.gridArea end
	local network = self:GetCell(position,self.GRID).moveLayers[layer]
	if layer then
		return self.networks[layer][network].size
	end
end

function MapHST:AccessibleMetalSpotsHere(mtype, position)
-- 	if layer == "air" then return self.METALS end
	local network = self:MobilityNetworkHere(mtype, position)
	if network then
		return self.networks[mtype][network].metals or {}
	end
	return {}

end

function MapHST:AccessibleGeoSpotsHere(mtype, position)
-- 	if layer == "air" then return self.GEOS end
	local network = self:MobilityNetworkHere(mtype, position)
	if network then
		return self.networks[mtype][network].geos or {}
	end
	return {}
end

function MapHST:AccessibleSpotsHere(mtype, position)
	local network = self:MobilityNetworkHere(mtype, position)
	if network then
		return self.networks[mtype][network].allSpots or {}
	end
	return {}
end

function MapHST:IsUnderWater(position)
	return position.y < 0
end

function MapHST:DrawDebug()
	for i=0,9 do
		self.map:EraseAll(i)
	end
	if not self.ai.drawDebug then
		return
	end
	local ch = 1
	local colours={
		{1,0,0,1},--'red'
		{0,1,0,1},--'green'
		{0,0,1,1},--'blue'
		{0,1,1,1},
		{1,1,0,1},
		{1,1,1,1},
		{0,0,0,1},
		}
	for i,p in pairs (self.hotSpots) do
		map:DrawPoint(p, colours[2], i,  ch)
	end
	for i,p in pairs (self.METALS) do
		map:DrawPoint(p, colours[6], i,  ch)
	end
	for i,p in pairs (self.GEOS) do
		map:DrawPoint(p, colours[6], i,  ch)
	end
	for X,Zetas in pairs(self.GRID) do
		for Z, CELL in pairs(Zetas) do
			map:DrawPoint(CELL.POS, nil, X .. ':' ..Z.. ' = ' ..((X - 1) *self.ai.maphst.gridSideX) + Z, 9)
 			if CELL.trampled then --and CELL.trampled > self.ttt.trampled / 2 then --CELL.trampled > 1 then --
 				map:DrawPoint(CELL.POS, {1,1,1,1}, math.ceil(CELL.trampled), 9)
 			end
			local pos1, pos2 = {},{}
			pos1.x, pos1.z = CELL.POS.x - self.gridSizeHalf, CELL.POS.z - self.gridSizeHalf
			pos2.x, pos2.z = CELL.POS.x + self.gridSizeHalf, CELL.POS.z + self.gridSizeHalf
			pos1.y=0
			pos2.y=0
			map:DrawRectangle(pos1,pos2, colours[6], nil, false, ch)
			ch = 0
			for layer,unitName in pairs(CELL.moveLayers) do
				ch = ch+1
				if CELL.moveLayers[layer] then
					map:DrawRectangle(pos1,pos2, colours[ch],CELL.moveLayers[layer], true, ch)
				end
			end
		end
	end
end

function MapHST:GetPathGraph(mtype, targetNodeSize)
	targetNodeSize = targetNodeSize or 256
	local cellsPerNodeSide = mCeil(targetNodeSize / self.gridSize)
	if pathGraphs[mtype] then
		if pathGraphs[mtype][cellsPerNodeSide] then
			return pathGraphs[mtype][cellsPerNodeSide]
		end
	end
-- 	local self.gridSize = self.gridSize--cellsPerNodeSide * self.gridSize
-- 	local self.gridSizeHalf = self.gridSize / 2
	local graph = {}
	local id = 1
	local myTopology = self.topology[mtype]
	if mtype == 'air' then
		myTopology = self.GRID --workaround to fix air
	end
	for cx = 1, self.gridSideX, cellsPerNodeSide do
		local x = ((cx * self.gridSize) - self.gridSizeHalf) + self.gridSizeHalf
		for cz = 1, self.gridSideZ, cellsPerNodeSide do
			local cellsComplete = true
			local goodCells = {}
			local goodCellsCount = 0
			for ccx = cx, cx + cellsPerNodeSide - 1 do
				for ccz = cz, cz + cellsPerNodeSide - 1 do
					if myTopology[ccx] and myTopology[ccx][ccz] then
						goodCellsCount = goodCellsCount + 1
						goodCells[goodCellsCount] = {ccx, ccz}
					else
						cellsComplete = false
					end
				end
			end
			if goodCellsCount > 0 then
				local z = ((cz * self.gridSize) - self.gridSizeHalf) + self.gridSizeHalf
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
	aGraph:SetPositionUnitsPerNodeUnits(self.gridSize)
	pathGraphs[mtype] = pathGraphs[mtype] or {}
	pathGraphs[mtype][cellsPerNodeSide] = aGraph
	return aGraph
end


--[[function MapHST:gridThePathBackup(wp)
	--local first = table.remove(waypoints)
	--first = {x = first[1],y = first[2],z = first[3]}
	local gridPath = {}
	gridPath[1] = gridPath[1] or {x = wp[1][1],y = wp[1][2],z = wp[1][3]}
-- 	table.remove(wp)
	for i,wpos in pairs(wp) do
		wpos = {x = wpos[1],y = wpos[2],z = wpos[3]}
		local lastX,lastZ = self.ai.maphst:PosToGrid(gridPath[#gridPath])
		local wposX,wposZ = self.ai.maphst:PosToGrid(wpos)
		if lastX ~= wposX or lastZ ~= wposZ then
			gridPath[#gridPath + 1] = wpos
		end

	end
	return gridPath
end]]