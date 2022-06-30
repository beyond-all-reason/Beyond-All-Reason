TargetHST = class(Module)

function TargetHST:Name()
	return "TargetHST"
end

function TargetHST:internalName()
	return "targethst"
end

local cellElmos = 256
local cellElmosHalf = cellElmos / 2

function TargetHST:Init()
	self.DebugEnabled = false
	self.visualdbg = true
 	self.CELLS = {}
 	self.ENEMYCELLS = {}
 	self.BAD_CELLS = {}
 	self.SPOT_CELLS = {}
 	self:createGridCell()

	self.pathModParam = 0.33
	self.pathModifierFuncs = {}
	self.enemyMexSpots = {}
	self.enemyFrontList = {}
end




function TargetHST:setCellEnemyValues(enemy,CELL)
	CELL.enemyUnits[enemy.id] = enemy.name
	if not enemy.mobile then
		CELL.enemyBuildings[enemy.id] = enemy.name

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
		--print('radarValue',radarValue)
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
	if CELL.ENEMY > 0 then
		if not self.ENEMYCELLS[CELL.gx..':'..CELL.gz] then
			local grid = {x=CELL.gx,z=CELL.gz}
			self.ENEMYCELLS[CELL.gx..':'..CELL.gz] = grid
		end
 	end
end

function TargetHST:Update()
-- 	local f = self.game:Frame()
	if self.ai.schedulerhst.moduleTeam ~= self.ai.id or self.ai.schedulerhst.moduleUpdate ~= self:Name() then return end
	--if f == 0 or (f % 71 + game:GetTeamID() == 0) then
	--if f == 0 or (f % 71) == 0 then
-- 		self.cells = {}--TODO
		self:clearEnemies()--delete just the enemy data inside cells, leave other living --TEST
-- 		self.cellList = {}
		self:UpdateEnemies()
		self:EnemiesCellsAnalisy()
		self:UpdateMetalGeoSpots()
		self:UpdateDamagedUnits()
		self:UpdateBadPositions()
		self:perifericalTarget()
		self:enemyFront()
		self:drawDBG()
	--end
end

function TargetHST:UpdateEnemies()

	-- where is/are the party/parties tonight?
	self.enemyMexSpots = {}
	for unitID, e in pairs(self.ai.loshst.knownEnemies) do
		local los = e.los
		local ghost = e.ghost
		local name = e.name
		local ut = self.ai.armyhst.unitTable[name]
		local px, pz = self:PosToGrid(e.position)
		self:setCellEnemyValues(e,self.CELLS[px][pz])
		if self.ai.armyhst.unitTable[name].extractsMetal ~= 0 then
			table.insert(self.enemyMexSpots, { position = e.position, unit = e })
		end
	end
end

function TargetHST:EnemiesCellsAnalisy() --MOVE TO TACTICALHST!!!
	local enemybasecount = 0
	self.enemyBasePosition = nil
	for i, G in pairs(self.ai.targethst.ENEMYCELLS) do
		local cell = self.ai.targethst.CELLS[G.x][G.z]
		if cell.base then
			self.enemyBasePosition = self.enemyBasePosition or {x=0,z=0}
			self.enemyBasePosition.x = self.enemyBasePosition.x + cell.pos.x
			self.enemyBasePosition.z = self.enemyBasePosition.z + cell.pos.z
			enemybasecount = enemybasecount + 1
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
	local basecell,baseX,baseZ = self:GetCellHere(base)

	for i, G in pairs(self.ENEMYCELLS) do
		local cell = self.CELLS[G.x][G.z]
		if cell.IMMOBILE > 0 then
			if not self.enemyFrontCellsX[G.x] then
				self.enemyFrontCellsX[G.x] = G.z
			end
			if not self.enemyFrontCellsZ[G.z] then
				self.enemyFrontCellsZ[G.z] = G.x
			end
			if math.abs(G.z,baseZ) > math.abs(self.enemyFrontCellsX[G.x],baseZ) then
				self.enemyFrontCellsX[G.x] = G.z
			end

			if math.abs(G.x,baseX) > math.abs(self.enemyFrontCellsZ[G.z],baseX) then
				self.enemyFrontCellsZ[G.z] = G.x
			end
		end
	end
	self.enemyFrontList = {}
	for X,Z in pairs(self.enemyFrontCellsX) do
		table.insert(self.enemyFrontList,self.CELLS[X][Z])
	end
	for Z,X in pairs(self.enemyFrontCellsZ) do
		table.insert(self.enemyFrontList,self.CELLS[X][Z])
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
	for i, G in pairs(self.ENEMYCELLS) do
		local cell = self.CELLS[G.x][G.z]
		if cell.IM < 0 then
			--print('IM',cell.IM)
			if math.abs(cell.pos.x - base.x) > distX then
				distX = math.abs(cell.pos.x - base.x)
				tgX = cell
			end
			if math.abs(cell.pos.z - base.z) > distZ then
				distZ = math.abs(cell.pos.z - base.z)
				tgZ = cell
			end
			if self.ai.tool:Distance(base,cell.pos) > distXZ then
				distXZ = self.ai.tool:Distance(base,cell.pos)
				tgXZ = cell
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

function TargetHST:UpdateMetalGeoSpots()
	local spots = self.ai.scoutSpots.air[1]
	for index,spot in pairs(spots) do
		local underwater = self.ai.maphst:IsUnderWater(spot)
		local inLos = self.ai.loshst:posInLos(spot)
		local gridX,gridZ = self:PosToGrid(spot)
		local cell = self.CELLS[gridX][gridZ]
		self.SPOT_CELLS[gridX .. ':' .. gridZ] = {gridX = gridX, gridZ = gridZ, underwater = underwater,inLos = inLos}
		cell.spots = cell.spots + 1
	end
end

function TargetHST:UnitDamaged(unit, attacker, damage)
	-- even if the attacker can't be seen, human players know what weapons look like
	-- in non-lua shard, the attacker is nil if it's an enemy unit, so this becomes useless
	if attacker ~= nil and attacker:AllyTeam() ~= self.ai.allyId then --   we know what is it and self.ai.loshst:IsKnownEnemy(attacker) ~= 2 then
		local mtype
		local ut = self.ai.armyhst.unitTable[unit:Name()]
		if ut then
			local threat = damage
			local aut = self.ai.armyhst.unitTable[attacker:Name()]
			if aut then
				if aut.isBuilding then
					self.ai.loshst:scanEnemy(attacker,isShoting)
					return
				end
				threat = aut.metalCost
			end
			self:AddBadPosition(unit:GetPosition(), ut.mtype, threat, 900)
		end
	end
end

function TargetHST:AddBadPosition(position, mtype, threat, duration)
	threat = threat or badCellThreat
	duration = duration or 1800
	local px, pz = self:PosToGrid(position)
	local gas = self.ai.tool:WhatHurtsUnit(nil, mtype, position)
	local f = self.game:Frame()
	for groundAirSubmerged, yes in pairs(gas) do
		if yes then
			local newRecord =
					{
						gridX = px,
						gridZ = pz,
						groundAirSubmerged = groundAirSubmerged,
						frame = f,
						threat = threat,
						duration = duration,
						}
			self.BAD_CELLS[px .. ':' ..pz] = newRecord
			self.CELLS[px][pz].badPositions = self.CELLS[px][pz].badPositions + 1
		end
	end
end

function TargetHST:UpdateBadPositions()
	local f = self.game:Frame()
	for index,G in pairs(self.BAD_CELLS) do
		local cell = self.CELLS[G.gridX][G.gridZ]
		if not cell then
			self:Warn('no cell',G.gridX,G.gridZ,G.gx,G.gz)
		elseif f - G.frame  > 300 then	--reset  bad position every 10 seconds
			cell.badPositions = 0
			self.BAD_CELLS[G.gridX.. ':' ..G.gridZ] = nil
		end
	end
end

function TargetHST:UpdateDamagedUnits()
	for unitID, engineUnit in pairs(self.ai.damagehst:GetDamagedUnits()) do
		local eUnitPos = engineUnit:GetPosition()
		local cell = self:GetCellHere(eUnitPos)
		if not cell then return end
		cell.damagedUnits[engineUnit:ID()] = engineUnit
	end
end

function TargetHST:NearbyVulnerable()
	if unit == nil then return end
	local position = unit:GetPosition()
	local danger,subValues, cells = getCellsFields(position,{'armed','unarm'},1)
	if subValues.armed < 0 and subValues.unarm > 0 then
		for index , grid in pairs(cells) do
			local cell = self.CELLS[grid.gx][grid.gz]
			for id,name in pairs (cell.enemyUnits ) do
				return id
			end
		end
	end
end

function TargetHST:IsSafePosition(position, unitName, threshold, adjacent)
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
	local danger = self:getCellsFields(position,{'armed'},adjacent)
	return danger <= threshold
end


function TargetHST:GetPathModifierFunc(unitName, adjacent)
	if self.pathModifierFuncs[unitName] then
		return self.pathModifierFuncs[unitName]
	end
	local divisor = self.ai.armyhst.unitTable[unitName].metalCost * self.pathModParam
	local modifier_node_func = function ( node, distanceToGoal, distanceStartToGoal )
		--local threatMod = self:ThreatHere(node.position, unitName, adjacent) / divisor--BE CAREFULL DANGER CHECK
		local threatMod = self:getCellsFields(node.position,{'armed'}) / divisor
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
	self.map:EraseAll(4)
	if not self.visualdbg then
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
	for index,G in pairs (self.ENEMYCELLS) do
		local cell = self.CELLS[G.x][G.z]
		local p = cell.pos
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

	for i,cell in pairs(self.enemyFrontList) do
		map:DrawCircle(cell.pos, cellElmosHalf/2, colours.f, 'front', true, 4)
	end
end


function TargetHST:createGridCell()
	for x = 1, Game.mapSizeX / cellElmos do
		if not self.CELLS[x] then
			self.CELLS[x] = {}
		end
		for z = 1, Game.mapSizeZ / cellElmos do
			self.CELLS[x][z] = {}
			self:NewCell(x,z)
		end
	end
end

function TargetHST:areaCells(X,Z,R)
	if not X or not Z then
		self:Warn('no grid XZ for areacells')
	end
	local AC = {}
	R = R or 0
	myself = myself or false
	for x = X - R , X + R,1  do
		for z = Z - R , Z + R,1 do
			if self.CELLS[x] and self.CELLS[x][z] then
				table.insert(AC, {gx = x, gz = z})
			end
		end
	end
	return AC
end


function TargetHST:clearEnemies()---wrong, clear the cells by parsing enemycells
	for x,Ztable in pairs(self.CELLS) do
		for z, cell in pairs(Ztable)do
			self:NewCell(x,z)
		end
	end
	self.ENEMYCELLS = {}
end

function TargetHST:PosToGrid(pos)
	local gridX = math.ceil(pos.x / cellElmos)
	local gridZ = math.ceil(pos.z / cellElmos)
	return gridX, gridZ
end

function TargetHST:GetCellHere(pos)
	local gridX,gridZ = self:PosToGrid(pos)
	if self.CELLS[gridX] and self.CELLS[gridX][gridZ] then
		return self.CELLS[gridX][gridZ] , gridX , gridZ
	else
		self:Warn('try to get non-existing cell ',gridX,gridZ,pos.x,pos.z)
	end
end

function TargetHST:NewCell(px, pz)
	local x = px * cellElmos - cellElmosHalf
	local z = pz * cellElmos - cellElmosHalf
	local cellPos = api.Position()
	cellPos.x, cellPos.z = x, z
	cellPos.y = Spring.GetGroundHeight(x, z)
	self.ai.buildsitehst:isInMap(cellPos)
-- 	map:DrawCircle(cellPos, cellElmosHalf,{1,1,1,1} , 'G', true, 4)

	local CELL = {}
	CELL.pos = cellPos
	CELL.gx = px
	CELL.gz = pz
	CELL.enemyUnits = {}
	CELL.enemyBuildings = {}
	CELL.friendlyUnits = {}
	CELL.myUnits = {}
	CELL.badPositions = 0
	CELL.spots = 0
	CELL.damagedUnits = {}
	CELL.base = nil
	--targets of this cell per layer is immobile unit NO weapon express in metal here is the layer that count
	CELL.unarmGI = 0
	CELL.unarmAI = 0
	CELL.unarmSI = 0
	CELL.unarmI = 0
	--targets of this cell per layer is mobile unit NO weapon express in metal
	CELL.unarmGM = 0
	CELL.unarmAM = 0
	CELL.unarmSM = 0
	CELL.unarmM = 0
	--the WEAPONED mobiles units express in metal amount
	CELL.armedGM = 0
	CELL.armedAM = 0
	CELL.armedSM = 0
	CELL.armedM = 0
	--the WEAPONED immobiles units express in metal amount
	CELL.armedGI = 0
	CELL.armedAI = 0
	CELL.armedSI = 0
	CELL.armedI = 0

	CELL.unarmG = 0
	CELL.unarmA = 0
	CELL.unarmS = 0
	CELL.armedG = 0
	CELL.armedA = 0
	CELL.armedS = 0
	CELL.G = 0
	CELL.A = 0
	CELL.S = 0
	CELL.G_balance = 0
	CELL.S_balance = 0
	CELL.A_balance = 0

	CELL.unarm = 0
	CELL.armed = 0
	CELL.ENEMY = 0
	CELL.ENEMY_BALANCE = 0

	CELL.offense = 0
	CELL.defense = 0
	CELL.economy = 0
	CELL.intelligence = 0
	CELL.base = nil
	CELL.resurrectables = {}
	CELL.reclamables = {}
	CELL.repairable = {}

	CELL.MOBILE = 0
	CELL.IMMOBILE = 0
	CELL.IM = 0

	CELL.CONTROL = nil --can be false for enemy and nil for no units
	self.CELLS[px][pz] = CELL
end


function TargetHST:getCellsFields(position,fields,range)--maybe we can run just through ENEMYCELLS
	if not fields or not position or type(fields) ~= 'table' then
		self:Warn('incomplete or incorrect params for get cells params',fields,position, range)
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
		local cell = self.CELLS[grid.gx][grid.gz]
		for i, field in pairs(fields) do
			VALUE = VALUE + cell[field]
			subValues[field] = subValues[field] + cell[field]
		end
	end
	return VALUE , subValues , cells
end
