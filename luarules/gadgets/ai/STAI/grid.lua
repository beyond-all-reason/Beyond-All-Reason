GridHST = class(Module)

function GridHST:Name()
	return "GridHST"
end

function GridHST:internalName()
	return "gridhst"
end

function GridHST:Init()
	self.DebugEnabled = false
	self.visualdbg = true
	self.Measure = 256
	self.HalfMeasure = self.Measure / 2
	self.GRID = {}
	self.ENEMY = {}
	self.OWN = {}
	self.ALLY = {}
	self:createGridCell()
end

function GridHST:createGridCell()
	for x = 1, Game.mapSizeX / self.Measure do
		if not self.GRID[x] then
			self.GRID[x] = {}
		end
		for z = 1, Game.mapSizeZ / self.Measure do
			self.GRID[x][z] = {}
			self:NewCell(x,z)
		end
	end
end

function GridHST:clearGrid(target)
-- 	for x,Ztable in pairs(self.GRID.ENEMY) do
-- 		for z, cell in pairs(Ztable)do
-- 			self:NewCell(x,z)
-- 		end
-- 	end
	self[target] = {}
end

function GridHST:PosToGrid(pos)
	local gridX = math.ceil(pos.x / self.Measure)
	local gridZ = math.ceil(pos.z / self.Measure)
	return gridX, gridZ
end

function GridHST:areaCells(X,Z,R)
	if not X or not Z then
		self:Warn('no grid XZ for areacells')
	end
	local AC = {}
	R = R or 0
	for x = X - R , X + R,1  do
		for z = Z - R , Z + R,1 do
			if self.GRID[x] and self.GRID[x][z] then
				table.insert(AC, {gx = x, gz = z})
			end
		end
	end
	return AC
end

function GridHST:GetCellHere(pos)
	local gridX,gridZ = self:PosToGrid(pos)
	if self.GRID[gridX] and self.GRID[gridX][gridZ] then
		return self.GRID[gridX][gridZ] , gridX , gridZ
	else
		self:Warn('try to get non-existing cell ',gridX,gridZ,pos.x,pos.z)
	end
end

function GridHST:getCellsFields(owner,position,fields,range)--maybe we can run just through ENEMYCELLS
	if not owner or not fields or not position or type(fields) ~= 'table' then
		self:Warn('incomplete or incorrect params for get cells params',owner,fields,position, range)
		return
	end
	range = range or 0
	local gridX, gridZ = self:PosToGrid(position)
	local cells = self:areaCells(gridX,gridZ,range)
	local VALUE = 0 --VALUE is a total count of all request fields
	local subValues = {} --subValues is the sum of this fields of each asked cell
	for i, f in pairs(fields) do
		subValues[f] = 0
	end
	for index , grid in pairs(cells) do
		local cell = self.GRID[owner][grid.gx][grid.gz]
		for i, field in pairs(fields) do
			VALUE = VALUE + cell[field]
			subValues[field] = subValues[field] + cell[field]
		end
	end
	return VALUE , subValues , cells
end

function TargetHST:NewCell(px, pz)
	local x = px * gridElmos - gridElmosHalf
	local z = pz * gridElmos - gridElmosHalf
	local cellPos = api.Position()
	cellPos.x, cellPos.z = x, z
	cellPos.y = Spring.GetGroundHeight(x, z)
	self.ai.buildsitehst:isInMap(cellPos)
-- 	map:DrawCircle(cellPos, gridElmosHalf,{1,1,1,1} , 'G', true, 4)

	local cell = {}
	cell.P = cellPos
	cell.X = px
	cell.Z = pz
	cell.enemyUnits = {}
	cell.enemyBuildings = {}
	cell.friendlyUnits = {}
	cell.myUnits = {}
	cell.badPositions = 0
	cell.spots = 0
	cell.damagedUnits = {}
	cell.base = nil
	--targets of this cell per layer is immobile unit NO weapon express in metal here is the layer that count
	cell.unarmGI = 0
	cell.unarmAI = 0
	cell.unarmSI = 0
	cell.unarmI = 0
	--targets of this cell per layer is mobile unit NO weapon express in metal
	cell.unarmGM = 0
	cell.unarmAM = 0
	cell.unarmSM = 0
	cell.unarmM = 0
	--the WEAPONED mobiles units express in metal amount
	cell.armedGM = 0
	cell.armedAM = 0
	cell.armedSM = 0
	cell.armedM = 0
	--the WEAPONED immobiles units express in metal amount
	cell.armedGI = 0
	cell.armedAI = 0
	cell.armedSI = 0
	cell.armedI = 0

	cell.unarmG = 0
	cell.unarmA = 0
	cell.unarmS = 0
	cell.armedG = 0
	cell.armedA = 0
	cell.armedS = 0
	cell.G = 0
	cell.A = 0
	cell.S = 0
	cell.G_balance = 0
	cell.S_balance = 0
	cell.A_balance = 0

	cell.unarm = 0
	cell.armed = 0
	cell.ENEMY = 0
	cell.ENEMY_BALANCE = 0

	cell.offense = 0
	cell.defense = 0
	cell.economy = 0
	cell.intelligence = 0
	cell.base = nil
	cell.resurrectables = {}
	cell.reclamables = {}
	cell.repairable = {}

	cell.MOBILE = 0
	cell.IMMOBILE = 0
	cell.IM = 0

	cell.CONTROL = nil --can be false for enemy and nil for no units
	self.GRID[px][pz] = cell
end
