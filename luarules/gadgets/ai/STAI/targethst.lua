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
			local blob
			local blobref = X..':'..Z
			if not self.blobchecked[X .. ':' ..Z] then
				blob = self:blobCell(self.ai.loshst.ENEMY,'SPEED',X,Z,blobref)
			end
			if blob then
				self.BLOBS[blobref] = blob
				--print('blob',blob.metal,blob.position.x,blob.position.z)
			end
		end
	end
	self.blobchecked = nil
end

function TargetHST:blobCell(grid,param,x,z,blobref)--rolling on the cell to extrapolate blob of param
	self.blobchecked[blobref] = true
	if x > self.ai.maphst.gridSideX or x < 1 or z > self.ai.maphst.gridSideZ or z < 1 then
		return
	end
	if grid[x][z][param] and grid[x][z][param] > 0 then
		if not self.BLOBS[blobref] then
			self.BLOBS[blobref] = {metal = 0,position = {x=0,y=0,z=0},cells = {}}
		end
		table.insert(self.BLOBS[blobref].cells,grid[x][z])
		for X = -1, 1,1 do
			for Z = -1,1,1 do
				if x ~= x + X or z ~= z + Z then
					if not self.blobchecked[blobref] then
						self:blobCell(grid,param,x+X,z+Z,blobref)
					end
				end
			end
		end
	end
	local blob = self.BLOBS[blobref]
	if not blob then return end
	local blobUnits = {}
	for i,v in pairs(blob.cells) do
		blob.position.x = blob.position.x + v.POS.x
		blob.position.z = blob.position.z + v.POS.z
		blob.metal = blob.metal + v.metal
		for id,name in pairs(v.units) do
			blobUnits[id] = name
		end

	end
	blob.position.x = blob.position.x / #blob.cells
	blob.position.z = blob.position.z / #blob.cells
	blob.position.y = map:GetGroundHeight(x,z)
	blob.units = blobUnits
	if blob.metal > 0 then return blob end


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
			map:DrawRectangle(pos1, pos2, colours.g, blob.metal, false, ch)

		end
		map:DrawCircle(blob.position, 128, colours.r, nil, true, ch)
	end
end
