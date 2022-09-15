TargetHST = class(Module)

function TargetHST:Name()
	return "TargetHST"
end

function TargetHST:internalName()
	return "targethst"
end

function TargetHST:Init()
	self.DebugEnabled = false
 	self.BLOBS = {}
	self.pathModParam = 0.3
	self.pathModifierFuncs = {}
	self.enemyFrontList = {}
end

function TargetHST:Update()
	if self.ai.schedulerhst.moduleTeam ~= self.ai.id or self.ai.schedulerhst.moduleUpdate ~= self:Name() then return end
	self:EnemiesCellsAnalisy()
	self:ScanEnemyCell()
	self:perifericalTarget()
	self:enemyFront()
	self:GetBlobs()
	self:drawDBG()
end

function TargetHST:EnemiesCellsAnalisy() --MOVE TO TACTICALHST!!!
	local enemybasecount = 0
	self.enemyBasePosition = nil
	for X, cells in pairs(self.ai.loshst.ENEMY) do
		for Z,cell in pairs(cells) do
			if cell.base then
				self.enemyBasePosition = self.enemyBasePosition or {x=0,z=0}
				self.enemyBasePosition.x = self.enemyBasePosition.x + cell.POS.x
				self.enemyBasePosition.z = self.enemyBasePosition.z + cell.POS.z
				enemybasecount = enemybasecount + 1
			end
		end
	end
	if enemybasecount > 0 then
		self.enemyBasePosition.x = self.enemyBasePosition.x / enemybasecount
		self.enemyBasePosition.z = self.enemyBasePosition.z / enemybasecount
		self.enemyBasePosition.y = Spring.GetGroundHeight(self.enemyBasePosition.x, self.enemyBasePosition.z)
	end
end



function TargetHST:GetBlobs()
	self.blobchecked = {}
	self.BLOBS = {}
	for X, cells in pairs(self.ai.loshst.ENEMY) do
		for Z,cell in pairs( cells) do
			local blobref = X..':'..Z
			if not self.blobchecked[blobref] then
				self:blobCell(self.ai.loshst.ENEMY,'SPEED',X,Z,blobref)
			end
		end
	end
	self.blobchecked = nil
	for ref, blob in pairs(self.BLOBS) do
		for i,v in pairs(blob.cells) do
			for id,name in pairs(v.units) do
				blob.units[id] = name
			end
			blob.position.x = blob.position.x + v.POS.x
			blob.position.z = blob.position.z + v.POS.z
			blob.metal = blob.metal + v.metal
		end
		blob.position.x = blob.position.x / #blob.cells
		blob.position.z = blob.position.z / #blob.cells
		blob.position.y = map:GetGroundHeight(blob.position.x,blob.position.z)
		local defendDist = math.huge
		local defendCell = nil
		for X, cells in pairs(self.ai.loshst.OWN) do
			for Z, cell in pairs(cells) do
				local dist = self.ai.tool:distance(cell.POS,blob.position)
				if dist < defendDist then
					defendDist = dist
					defendCell = cell
				end
			end
		end
		blob.defend = defendCell
	end
end

function TargetHST:blobCell(grid,param,x,z,blobref)--rolling on the cell to extrapolate blob of param
	self.blobchecked[x .. ':' .. z] = true
	if grid[x] and grid[x][z] and grid[x][z][param] and grid[x][z][param] > 0 then
		self.BLOBS[blobref] = self.BLOBS[blobref] or {metal = 0,position = {x=0,y=0,z=0},cells = {},units={},defend = nil}
		table.insert(self.BLOBS[blobref].cells,grid[x][z])
		for X = -1, 1,1 do
			for Z = -1,1,1 do
				if not self.blobchecked[x+X..':'..z+Z] then
					self:blobCell(grid,param,x+X,z+Z,blobref)
				end
			end
		end
	end
end

function TargetHST:enemyFront()
	self.enemyFrontCellsX = {}
	self.enemyFrontCellsZ = {}
	if not self.enemyBasePosition then
		return
	end
	local base = self.enemyBasePosition
	local basecell,baseX,baseZ = self.ai.maphst:GetCell(base,self.ai.loshst.ENEMY)
	for X, zetas in pairs(self.ai.loshst.ENEMY) do
		for Z,cell in pairs( zetas) do
			if cell.IMMOBILE > 0 then
				if not self.enemyFrontCellsX[X] then
					self.enemyFrontCellsX[X] = Z
				end
				if not self.enemyFrontCellsZ[Z] then
					self.enemyFrontCellsZ[Z] = X
				end
				if math.abs(cell.Z,baseZ) > math.abs(self.enemyFrontCellsX[X],baseZ) then
					self.enemyFrontCellsX[X] = Z
				end
				if math.abs(cell.X,baseX) > math.abs(self.enemyFrontCellsZ[Z],baseX) then
					self.enemyFrontCellsZ[Z] = X
				end
			end



		end
	end
	self.enemyFrontList = {}

	for X,Z in pairs(self.enemyFrontCellsX) do
		table.insert(self.enemyFrontList,self.ai.loshst.ENEMY[X][Z])
	end
	for Z,X in pairs(self.enemyFrontCellsZ) do
		table.insert(self.enemyFrontList,self.ai.loshst.ENEMY[X][Z])
	end
end



function TargetHST:perifericalTarget()
	self.distals = {}
	if not self.enemyBasePosition then
		return
	end
	local base = self.enemyBasePosition
	local distX = 0
	local distZ = 0
	local distXZ = 0
	local tgX = nil
	local tgZ = nil
	local tgXZ = nil
	for X,zetas in pairs(self.ai.loshst.ENEMY) do
		for Z, cell in pairs(zetas) do
			if cell.IM < 0 then
				if math.abs(cell.POS.x - base.x) > distX then
					distX = math.abs(cell.POS.x - base.x)
					tgX = cell
				end
				if math.abs(cell.POS.z - base.z) > distZ then
					distZ = math.abs(cell.POS.z - base.z)
					tgZ = cell
				end
				if self.ai.tool:Distance(base,cell.POS) > distXZ then
					distXZ = self.ai.tool:Distance(base,cell.POS)
					tgXZ = cell
				end
			end
		end
	end
	if not tgX or not tgZ then return end
	tgX.distalX = true
	tgZ.distalZ = true
	tgXZ.distalXZ = true
	self.distals.tgX = tgX
	self.distals.tgZ = tgZ
	self.distals.tgXZ = tgXZ
	return tgX,tgZ,tgXZ
end

function TargetHST:NearbyVulnerable(position)
	local danger,subValues, cells = self.ai.maphst:getCellsFields(position,{'ARMED','UNARM'},1,self.ai.loshst.ENEMY)
	if subValues.armed == 0 and subValues.unarm > 0 then
		for index , cell in pairs(cells) do
			for id,name in pairs (cell.units ) do
				return id
			end
		end
	end
end



function TargetHST:IsSafeCell(position, unitName, threshold, adjacent)
	if not position then
		self:Warn('nil position in safe position check')
		return
	end
 	threshold = threshold or 0
 	adjacent = adjacent or 0
-- 	local layer = --here implement a count of danger per layer, but now we count all danger layer as dangerous
-- 	if unit then
-- 		layer = self.ai.armyhst.unitTable[unitName].LAYER
-- 	end
	--WARNING here implement a count of danger per layer, but now we count all danger layer as dangerous
	local danger = self.ai.maphst:getCellsFields(position,{'ARMED'},adjacent,self.ai.loshst.ENEMY)
	return danger <= threshold
end

function TargetHST:GetPathModifierFunc(unitName, adjacent)
	if self.pathModifierFuncs[unitName] then
		return self.pathModifierFuncs[unitName]
	end
	local divisor = self.ai.armyhst.unitTable[unitName].metalCost * self.pathModParam
	local modifier_node_func = function ( node, distanceToGoal, distanceStartToGoal )
		--local threatMod = self:ThreatHere(node.position, unitName, adjacent) / divisor--BE CAREFULL DANGER CHECK
		local threatMod = self.ai.maphst:getCellsFields(node.position,{'ARMED'},1,self.ai.loshst.ENEMY) --/ divisor
		if distanceToGoal then
			if distanceToGoal <= 500 then
				return 0
			else
				return threatMod * ((distanceToGoal  - 500) / 1000)
			end
		else
			return threatMod
		end
	end
	self.pathModifierFuncs[unitName] = modifier_node_func
	return modifier_node_func
end

function TargetHST:ScanEnemyCell()
	self.enemyEdgeNordEst = nil
 	self.enemyEdgeNordWest = nil
 	self.enemyEdgeSudEst = nil
 	self.enemyEdgeSudWest = nil
	self.enemyEdgeNord = nil
	self.enemyEdgeSud = nil
	self.enemyEdgeEst = nil
	self.enemyEdgeWest = nil
	self.borders = {}

	for X,cells in pairs (self.ai.loshst.ENEMY) do
		for Z, cell in pairs(cells) do
			self:FindEnemyEdges(cell)
		end
	end
	if self.enemyEdgeEst then
		for Z = self.enemyEdgeEst.Z , self.enemyEdgeSudEst.Z , 1 do
			self.borders[self.enemyEdgeEst.X] = self.borders[self.enemyEdgeEst.X] or {}
			self.borders[self.enemyEdgeEst.X][Z] = {X = self.enemyEdgeEst.X, Z = Z, POS = self.ai.maphst:GridToPos(self.enemyEdgeEst.X,Z) }
		end
	end
end
function TargetHST:FindEnemyEdges(cell)
	--print('immobile',cell.IMMOBILE)
		self.enemyEdgeNordEst = self.enemyEdgeNordEst or cell
	self.enemyEdgeNordWest = self.enemyEdgeNordWest or cell
	self.enemyEdgeSudEst = self.enemyEdgeSudEst or cell
	self.enemyEdgeSudWest = self.enemyEdgeSudWest or cell
	self.enemyEdgeNord = self.enemyEdgeNord or cell
	self.enemyEdgeSud = self.enemyEdgeSud or cell
	self.enemyEdgeEst = self.enemyEdgeEst or cell
	self.enemyEdgeWest = self.enemyEdgeWest or cell
	if cell.IMMOBILE == 0 then
		return
	end



	local pos = cell.POS
	if pos.x >= self.enemyEdgeEst.POS.x then
		self.enemyEdgeEst = cell
	end
	if pos.x <= self.enemyEdgeWest.POS.x then
		self.enemyEdgeWest = cell
	end
	if pos.z >= self.enemyEdgeSud.POS.z then
		self.enemyEdgeSud = cell
	end
	if pos.z <= self.enemyEdgeNord.POS.z then
		self.enemyEdgeNord = cell
	end
	if pos.x <= self.enemyEdgeNordWest.POS.x and pos.z <= self.enemyEdgeNordWest.POS.z then
		self.enemyEdgeNordWest = cell
	end
	if pos.x >= self.enemyEdgeSudEst.POS.x and pos.z >= self.enemyEdgeSudEst.POS.z then
		self.enemyEdgeSudEst = cell
	end
	if pos.x >= self.enemyEdgeNordEst.POS.x and pos.z <= self.enemyEdgeNordEst.POS.z then
		self.enemyEdgeNordEst = cell
	end
	if pos.x <= self.enemyEdgeSudWest.POS.x and pos.z >= self.enemyEdgeSudWest.POS.z then
		self.enemyEdgeSudWest = cell
	end



end

function TargetHST:drawDBG()
	local ch = 4
	self.map:EraseAll(ch)
	if not self.ai.drawDebug then
		return
	end
	local colours={
			g = {1,0,0,1},--'red'
			a = {0,1,0,1},--'green'
			s = {0,0,1,1},--'blue'
			p = {0,1,1,1},
			f = {1,1,0,1},
			unbalance = {1,1,1,1},
			balance = {0,0,0,1},

			}
	if self.enemyBasePosition then
		map:DrawPoint(self.enemyBasePosition, {1,1,1,1}, 'BASE',  ch)
	end

	for i,cell in pairs(self.enemyFrontList) do
		map:DrawCircle(cell.POS, cellElmosHalf/2, colours.f, 'front', true, ch)
	end
	local cellElmosHalf = self.ai.maphst.gridSizeHalf
	for i,blob in pairs(self.BLOBS) do

		for ref,cell in pairs(blob.cells) do
			local pos1 = {}
			local pos2 = {}
			pos1.x, pos1.z = cell.POS.x - cellElmosHalf, cell.POS.z - cellElmosHalf
			pos2.x, pos2.z = cell.POS.x + cellElmosHalf, cell.POS.z + cellElmosHalf
			map:DrawRectangle(pos1, pos2, colours.g, i, false, ch)

		end
		map:DrawCircle(blob.position, 128, colours.s, nil, true, ch)
	end
	if self.enemyEdgeNordEst then
		map:DrawCircle(self.enemyEdgeNordEst.POS, 128, colours.a, 'NordEst', true, ch)
		map:DrawCircle(self.enemyEdgeNordWest.POS, 128, colours.a, 'NordWest', true, ch)
		map:DrawCircle(self.enemyEdgeSudEst.POS, 128, colours.a, 'SudEst', true, ch)
		map:DrawCircle(self.enemyEdgeSudWest.POS, 128, colours.a, 'SudWest', true, ch)
		map:DrawCircle(self.enemyEdgeNord.POS, 128, colours.a, 'Nord', true, ch)
		map:DrawCircle(self.enemyEdgeWest.POS, 128, colours.a, 'West', true, ch)
		map:DrawCircle(self.enemyEdgeEst.POS, 128, colours.a, 'Est', true, ch)
		map:DrawCircle(self.enemyEdgeSud.POS, 128, colours.a, 'Sud', true, ch)
	end
	for X,cells in pairs(self.borders) do
		for Z,cell in pairs(cells) do
			map:DrawCircle(cell.POS, 128, colours.p, 'B', true, ch)
		end
	end



end
