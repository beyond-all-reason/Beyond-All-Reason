TargetHST = class(Module)

function TargetHST:Name()
	return "TargetHST"
end

function TargetHST:internalName()
	return "targethst"
end

function TargetHST:Init()
	self.DebugEnabled = false
 	self.ENEMIES = {}
	self.pathModParam = 0.3
	self.pathModifierFuncs = {}
	self.enemyMexSpots = {}
	self.enemyFrontList = {}
end

function TargetHST:Update()
	if self.ai.schedulerhst.moduleTeam ~= self.ai.id or self.ai.schedulerhst.moduleUpdate ~= self:Name() then return end
	self.enemyMexSpots = {}
	self:UpdateEnemies()
	self:EnemiesCellsAnalisy()
	self:perifericalTarget()
	self:enemyFront()
	self:drawDBG()
end

function TargetHST:UpdateEnemies()

	self.ENEMIES = {}
	for unitID, e in pairs(self.ai.loshst.knownEnemies) do
		local ut = self.ai.armyhst.unitTable[e.name]
		local X, Z = self.ai.maphst:PosToGrid(e.position)
		self:ResetCell(X,Z)
		self:setCellEnemyValues(e,X,Z)
		if ut.extractsMetal ~= 0 then
			table.insert(self.enemyMexSpots, { position = e.position, unit = e })
		end
	end
end

function TargetHST:EnemiesCellsAnalisy() --MOVE TO TACTICALHST!!!
	local enemybasecount = 0
	self.enemyBasePosition = nil
	for X, cells in pairs(self.ENEMIES) do
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

function TargetHST:enemyFront()
	self.enemyFrontCellsX = {}
	self.enemyFrontCellsZ = {}
	if not self.enemyBasePosition then
		return
	end
	local base = self.enemyBasePosition
	local basecell,baseX,baseZ = self.ai.maphst:GetCell(base,self.ENEMIES)
	for X, zetas in pairs(self.ENEMIES) do
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
		table.insert(self.enemyFrontList,self.ENEMIES[X][Z])
	end
	for Z,X in pairs(self.enemyFrontCellsZ) do
		table.insert(self.enemyFrontList,self.ENEMIES[X][Z])
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
	for X,zetas in pairs(self.ENEMIES) do
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
	local danger,subValues, cells = self.ai.maphst:getCellsFields(position,{'armed','unarm'},1,self.ENEMIES)
	if subValues.armed < 0 and subValues.unarm > 0 then
		for index , cell in pairs(cells) do
			--local cell = self.ENEMIES[grid.X][grid.Z]
			for id,name in pairs (cell.enemyUnits ) do
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
	local danger = self.ai.maphst:getCellsFields(position,{'armed'},adjacent,self.ENEMIES)
	return danger <= threshold
end

function TargetHST:GetPathModifierFunc(unitName, adjacent)
	if self.pathModifierFuncs[unitName] then
		return self.pathModifierFuncs[unitName]
	end
	local divisor = self.ai.armyhst.unitTable[unitName].metalCost * self.pathModParam
	local modifier_node_func = function ( node, distanceToGoal, distanceStartToGoal )
		--local threatMod = self:ThreatHere(node.position, unitName, adjacent) / divisor--BE CAREFULL DANGER CHECK
		local threatMod = self.ai.maphst:getCellsFields(node.position,{'armed'},1,self.ENEMIES) --/ divisor
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

function TargetHST:setCellEnemyValues(enemy,X,Z)
	local CELL = self.ENEMIES[X][Z]
	CELL.units[enemy.id] = enemy.name
	if not enemy.mobile then
		CELL.buildings[enemy.id] = enemy.name
	end
	local ut = self.ai.armyhst.unitTable[enemy.name]
	if enemy.view == 1 then
		if ut.isFactory then
			CELL.base = enemy.name
		end
		if ut.isWeapon then
			CELL.armed = CELL.armed + enemy.M
			if ut.speed > 0 then
				CELL.offense = CELL.offense + enemy.M
				CELL.MOBILE = CELL.MOBILE + enemy.M
				if enemy.layer == 0 then
					CELL.armedGM = CELL.armedGM + enemy.M
				elseif enemy.layer == 1 then
					CELL.armedAM = CELL.armedAM + enemy.M
				elseif enemy.layer == -1 then
					CELL.armedSM = CELL.armedSM + enemy.M
				end
			else
				CELL.defense = CELL.defense + enemy.M
				CELL.IMMOBILE = CELL.MOBILE + enemy.M
				if enemy.layer == 0 then
					CELL.armedGI = CELL.armedGI + enemy.M
				elseif enemy.layer == 1 then
					CELL.armedAI = CELL.armedAI + enemy.M
				elseif enemy.layer == -1 then
					CELL.armedSI = CELL.armedSI + enemy.M
				end
			end

		else
			CELL.unarm = CELL.unarm + enemy.M
			if ut.speed > 0 then
				CELL.intelligence = CELL.intelligence + enemy.M
				CELL.MOBILE = CELL.MOBILE + enemy.M
				if enemy.layer > 0 then
					CELL.unarmAM = CELL.unarmAM + enemy.M
				elseif enemy.layer < 0  then
					CELL.unarmSM = CELL.unarmSM + enemy.M
				elseif enemy.layer == 0 then
					CELL.unarmGM = CELL.unarmGM + enemy.M
				end
			else
				CELL.economy = CELL.economy + enemy.M
				CELL.IMMOBILE = CELL.IMMOBILE + enemy.M
				if enemy.layer > 0 then
					CELL.unarmAI = CELL.unarmAM + enemy.M
				elseif enemy.layer < 0 then
					CELL.unarmSI = CELL.unarmSM + enemy.M
				elseif enemy.layer == 0 then
					CELL.unarmGI = CELL.unarmGM + enemy.M
				end
			end
		end

		CELL.unarmG = CELL.unarmGM + CELL.unarmGI
		CELL.unarmA = CELL.unarmAM + CELL.unarmAI
		CELL.unarmS = CELL.unarmSM + CELL.unarmSI
		CELL.armedG = CELL.armedGI + CELL.armedGM
		CELL.armedA = CELL.armedAI + CELL.armedAM
		CELL.armedS = CELL.armedSI + CELL.armedSM
		CELL.G = CELL.armedG + CELL.unarmG
		CELL.A = CELL.armedA + CELL.unarmA
		CELL.S = CELL.armedS + CELL.unarmS
		CELL.G_balance = CELL.armedG - CELL.unarmG
		CELL.A_balance = CELL.armedA - CELL.unarmA
		CELL.S_balance = CELL.armedS - CELL.unarmS
		CELL.ENEMY = CELL.armed + CELL.unarm --TOTAL VALUE
		CELL.ENEMY_BALANCE = CELL.armed - CELL.unarm
		CELL.IM = CELL.MOBILE - CELL.IMMOBILE
	elseif enemy.view == 0 then --RADAR--TODO this need to be refined
		local f = self.game:Frame()
		local radarValue = 20 + f / 300
		CELL.ENEMY = CELL.ENEMY + radarValue --(adjust for time or other param during game)
		CELL.ENEMY_BALANCE = CELL.ENEMY_BALANCE + radarValue
		if enemy.SPEED > 0 then --TODO refine
			CELL. IMMOBILE = CELL.IMMOBILE - radarValue
			CELL. MOBILE = CELL.MOBILE + radarValue
		else
			CELL. IMMOBILE = CELL.IMMOBILE + radarValue
			CELL. MOBILE = CELL.MOBILE - radarValue
		end
	elseif enemy.view == -1 then--HIDDEN
		--hidden superflous for now
	end
	self.ENEMIES[X][Z] = CELL
end


function TargetHST:ResetCell(X,Z)--GAS are 3 layer. Unit of measure is usually metal cost!
	if self.ENEMIES[X] and self.ENEMIES[X][Z] then return end
	if not self.ENEMIES[X] then
		self.ENEMIES[X] = {}
	end

	--I = immoble
	-- M = mobile
	--G = ground
	--A = air
	--S = submerged

--	CELL.CONTROL = nil --can be false for enemy and nil for no units
--	CELL.resurrectables = {}
--	CELL.reclamables = {}
--	CELL.repairable = {}

	local CELL = {}
	CELL.X = X
	CELL.Z = Z
	CELL.POS = self.ai.maphst:GridToPos(X,Z)
	CELL.units = {}--hold all the units
	CELL.base = nil --hold the factotory
	CELL.buildings = {} --hold the buildings

	--unarm GAS immobiles
	CELL.unarmGI = 0
	CELL.unarmAI = 0
	CELL.unarmSI = 0
	CELL.unarmI = 0
	--unarm GAS mobile
	CELL.unarmGM = 0
	CELL.unarmAM = 0
	CELL.unarmSM = 0
	CELL.unarmM = 0
	--armed GAS mobile
	CELL.armedGM = 0
	CELL.armedAM = 0
	CELL.armedSM = 0
	CELL.armedM = 0
	--armed GAS immobile
	CELL.armedGI = 0
	CELL.armedAI = 0
	CELL.armedSI = 0
	CELL.armedI = 0
	--  unarm GAS sum
	CELL.unarmG = 0
	CELL.unarmA = 0
	CELL.unarmS = 0
	--armed GAS sum
	CELL.armedG = 0
	CELL.armedA = 0
	CELL.armedS = 0
	--GAS SUM
	CELL.G = 0
	CELL.A = 0
	CELL.S = 0
	-- GAS balanced unarm - armed
	CELL.G_balance = 0
	CELL.S_balance = 0
	CELL.A_balance = 0
	--totals unarmed armed
	CELL.unarm = 0
	CELL.armed = 0
	--total metal amount of metal in cell
	CELL.ENEMY = 0
	CELL.ENEMY_BALANCE = 0-- this is balanced

	CELL.offense = 0
	CELL.defense = 0
	CELL.economy = 0
	CELL.intelligence = 0


	CELL.MOBILE = 0
	CELL.IMMOBILE = 0
	CELL.IM = 0
	self.ENEMIES[X][Z] = CELL
end

function TargetHST:drawDBG()
	self.map:EraseAll(4)
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
		map:DrawPoint(self.enemyBasePosition, {1,1,1,1}, 'BASE',  4)
	end
	local cellElmosHalf = self.ai.maphst.gridSizeHalf
	for X,cells in pairs (self.ENEMIES) do
		for Z,cell in pairs (cells) do
			local p = cell.POS
			--map:DrawCircle(p,cellElmosHalf, colours.balance, cell.ENEMY,false,  4)
			local pos1, pos2 = api.Position(), api.Position()--z,api.Position(),api.Position(),api.Position()
			pos1.x, pos1.z = p.x - cellElmosHalf, p.z - cellElmosHalf
			pos2.x, pos2.z = p.x + cellElmosHalf, p.z + cellElmosHalf
			pos1.y=Spring.GetGroundHeight(pos1.x,pos1.z)
			pos2.y=Spring.GetGroundHeight(pos2.x,pos2.z)
			self:EchoDebug('drawing',pos1.x,pos1.z,pos2.x,pos2.z)
			if cell.ENEMY_BALANCE > 0 then
				map:DrawRectangle(pos1, pos2, colours.balance, cell.ENEMY_BALANCE, false, 4)
			else
				map:DrawRectangle(pos1, pos2, colours.unbalance, cell.ENEMY_BALANCE, false, 4)
			end
			posG = {x = p.x - cellElmosHalf/2, y = p.y , z = p.z - cellElmosHalf/2}
			posS = {x = p.x + cellElmosHalf/2, y = p.y , z = p.z - cellElmosHalf/2}
			posB = {x = p.x - cellElmosHalf/2, y = p.y , z = p.z + cellElmosHalf/2}
			posA = {x = p.x + cellElmosHalf/2, y = p.y , z = p.z + cellElmosHalf/2}

			if cell.G > 0 then
				map:DrawCircle(posG, cellElmosHalf/2,colours.g , cell.G, true, 4)
			end
			if cell.A > 0 then
				map:DrawCircle(posA, cellElmosHalf/2,colours.a, cell.A, true, 4)
			end
			if cell.S > 0 then
				map:DrawCircle(posS, cellElmosHalf/2, colours.s, cell.S, true, 4)
			end
		end

	end

	for i,cell in pairs(self.enemyFrontList) do
		map:DrawCircle(cell.POS, cellElmosHalf/2, colours.f, 'front', true, 4)
	end
end
