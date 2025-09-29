TargetHST = class(Module)

function TargetHST:Name()
	return "TargetHST"
end

function TargetHST:internalName()
	return "targethst"
end

function TargetHST:Init()
	self.DebugEnabled = false
	self.enemyCenter = self.elmoMapCenter
	self.IMMOBILE_BLOBS = {}
	self.MOBILE_BLOBS = {}
	self.pathModParam = 0.3
	self.pathModifierFuncs = {}
	self.enemyFrontList = {}
	self.blobchecked = {}
	self.enemyCenter = {x = 0,y = 0,z = 0}
	self.enemyBasePosition = {x = 0,y = 0,z = 0}
	self.enemybasecount = 0
	self.cellCount = 0
end

function TargetHST:Update()
	if self.ai.schedulerhst.moduleTeam ~= self.ai.id or self.ai.schedulerhst.moduleUpdate ~= self:Name() then return end
	self:EnemiesCellsAnalisy()
	self:GetBlobs('MOBILE_BLOBS','SPEED')
	self:GetBlobs('IMMOBILE_BLOBS','IMMOBILE')
	self:drawDBG()
end




function TargetHST:GetBlobs(_blobs_,param) --reset all the old blobs
	--for ref,blob in pairs(self[_blobs_]) do --reset all the old blobs
		self.ai.tool:ResetTable(self[_blobs_])
	--end
	local blobref
	for X, cells in pairs(self.ai.loshst.ENEMY) do --find all the bew blobs
		for Z,cell in pairs( cells) do
			blobref = X..':'..Z
			if not self.blobchecked[blobref] then
				self:Blobbing(self.ai.loshst.ENEMY,param,X,Z,_blobs_,blobref)
			end
		end
	end
	for i,v in pairs(self.blobchecked) do --clean all the cell/blobs checked
		self.blobchecked[i] = nil
	end
	for ref, blob in pairs(self[_blobs_]) do-- fill the blobs with data
		for i,v in pairs(blob.cells) do
			
			for id,name in pairs(self.ai.loshst.ENEMY[v.X][v.Z].units) do
				blob.units[id] = name
			end
			blob.position.x = blob.position.x + self.ai.loshst.ENEMY[v.X][v.Z].POS.x
			blob.position.z = blob.position.z + self.ai.loshst.ENEMY[v.X][v.Z].POS.z
			blob.metal = blob.metal + self.ai.loshst.ENEMY[v.X][v.Z].metal
		end
		blob.position.x = blob.position.x / #blob.cells
		blob.position.z = blob.position.z / #blob.cells
		blob.position.y = map:GetGroundHeight(blob.position.x,blob.position.z)
		blob.targetCell.X,blob.targetCell.Z = self.ai.maphst:PosToGrid(blob.position)
	end
	self:EchoDebug('selfblob',_blobs_,self[_blobs_])
end

function TargetHST:Blobbing(grid,param,x,z,_blobs_,blobref)--rolling on the cell to extrapolate blob of param
	self.blobchecked[x .. ':' .. z] = true
	
	if grid[x] and grid[x][z] and grid[x][z][param] and grid[x][z][param] > 0 then
		if not self[_blobs_][blobref] then
			self[_blobs_][blobref] = self.ai.tool:RezTable()
			self[_blobs_][blobref].position = self.ai.tool:RezTable()
			self[_blobs_][blobref].position.x = 0
			self[_blobs_][blobref].position.y = 0
			self[_blobs_][blobref].position.z = 0
			self[_blobs_][blobref].cells = self.ai.tool:RezTable()
			self[_blobs_][blobref].units = self.ai.tool:RezTable()
			self[_blobs_][blobref].metal = 0
			self[_blobs_][blobref].targetCell = self.ai.tool:RezTable()			
		end
		local cellCoord = self.ai.tool:RezTable()
		cellCoord.X = x
		cellCoord.Z = z
		table.insert(self[_blobs_][blobref].cells,cellCoord)
		for X = -1, 1,1 do
			for Z = -1,1,1 do
				if not self.blobchecked[x+X..':'..z+Z] then
					self:Blobbing(grid,param,x+X,z+Z,_blobs_,blobref)
				end
			end
		end
	end
end


function TargetHST:EnemiesCellsAnalisy() --TODO:--MOVE TO TACTICALHST!!!
	self.enemybasecount = 0
	self.cellCount = 0

	self.enemyBasePosition.x = 0
	self.enemyBasePosition.y = 0
	self.enemyBasePosition.z = 0

	self.enemyCenter.x = 0
	self.enemyCenter.y = 0
	self.enemyCenter.z = 0
	
	for X, cells in pairs(self.ai.loshst.ENEMY) do
		for Z,cell in pairs(cells) do
			self.enemyCenter.x = self.enemyCenter.x + cell.POS.x
			self.enemyCenter.y = self.enemyCenter.y + cell.POS.y
			self.enemyCenter.z = self.enemyCenter.z + cell.POS.z
			self.cellCount = self.cellCount + 1
			if cell.base then
				self.enemyBasePosition.x = self.enemyBasePosition.x + cell.POS.x
				self.enemyBasePosition.z = self.enemyBasePosition.z + cell.POS.z
				self.enemybasecount = self.enemybasecount + 1
			end
		end
	end
	if self.cellCount > 0 then
		
		
		self.enemyCenter.x = self.enemyCenter.x / self.cellCount
		self.enemyCenter.z = self.enemyCenter.z / self.cellCount
		self.enemyCenter.y = map:GetGroundHeight(self.enemyCenter.x,self.enemyCenter.z)
	end
	if self.enemybasecount > 0 then
		self.enemyBasePosition.x = self.enemyBasePosition.x / self.enemybasecount
		self.enemyBasePosition.z = self.enemyBasePosition.z / self.enemybasecount
		self.enemyBasePosition.y = map:GetGroundHeight(self.enemyBasePosition.x, self.enemyBasePosition.z)
	end
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

function TargetHST:IsSafeCell(position, unitName, threshold, adjacent) --TODO move and improve in damagehst
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
	local divisor = self.ai.armyhst.unitTable[unitName].metalCost * self.pathModParam
	local modifier_node_func = function ( node, distanceToGoal, distanceStartToGoal )
		local threatMod = self.ai.maphst:getCellsFields(node.position,{'defenderThreat'},1,self.ai.damagehst.DAMAGED) --/ divisor
		self:EchoDebug('threatMod',threatMod)
		if distanceToGoal then
			if distanceToGoal <= 500 then
				return 0
			else
				return threatMod * ((distanceToGoal  - 500))
			end
		else
			return threatMod
		end
	end
	self:EchoDebug('modifier_node_func',modifier_node_func)
	self.pathModifierFuncs[unitName] = modifier_node_func
	return modifier_node_func
end

function TargetHST:drawDBG()
	
	
	if not self.ai.drawDebug then
		return
	end
	local ch = 4
	self.map:EraseAll(ch)
	local colours = self.ai.tool.COLOURS
	if self.enemyBasePosition then
		map:DrawPoint(self.enemyBasePosition, colours.black, 'BASE',  ch)
	end
	map:DrawPoint(self.enemyCenter, colours.black, 'CENTER',  ch)
--[[
	for i,cell in pairs(self.enemyFrontList) do
		map:DrawCircle(cell.POS, cellElmosHalf/2, colours.f, 'front', true, ch)
	end]]
	local cellElmosHalf = self.ai.maphst.gridSizeHalf
	for i,blob in pairs(self.MOBILE_BLOBS) do

		for ref,cell in pairs(blob.cells) do
			local pos1 = {}
			local pos2 = {}
			pos1.x, pos1.z = cell.POS.x - cellElmosHalf, cell.POS.z - cellElmosHalf
			pos2.x, pos2.z = cell.POS.x + cellElmosHalf, cell.POS.z + cellElmosHalf
			map:DrawRectangle(pos1, pos2, colours.yellow, i, false, ch)

		end
		map:DrawCircle(blob.position, 128, colours.red, nil, true, ch)
	end
	for i,blob in pairs(self.IMMOBILE_BLOBS) do

		for ref,cell in pairs(blob.cells) do
			local pos1 = {}
			local pos2 = {}
			pos1.x, pos1.z = cell.POS.x - cellElmosHalf, cell.POS.z - cellElmosHalf
			pos2.x, pos2.z = cell.POS.x + cellElmosHalf, cell.POS.z + cellElmosHalf
			map:DrawRectangle(pos1, pos2, colours.aqua, i, false, ch)

		end
		map:DrawCircle(blob.position, 128, colours.blue, nil, true, ch)
	end
end

