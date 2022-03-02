TargetHST = class(Module)

function TargetHST:Name()
	return "TargetHST"
end

function TargetHST:internalName()
	return "targethst"
end

local DebugDrawEnabled = false

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
		print('radarValue',radarValue)
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

function TargetHST:Update()
	local f = self.game:Frame()
	if f == 0 or f % 71 == 0 then
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
	end
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
	local tgX = 0
	local tgZ = 0
	local tgXZ = 0
	for i, G in pairs(self.ENEMYCELLS) do
		local cell = self.CELLS[G.x][G.z]
		if cell.IM < 0 then
			print('IM',cell.IM)
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
		if f - G.frame  > 300 then--reset  bad position every 10 seconds
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
-- 		if cell.distalX or cell.distalZ or cell.distalXZ then
-- 			map:DrawCircle(posB, cellElmosHalf/2, colours.p, cell.IM, true, 4)
-- 		end
-- 		if cell.frontX then
-- 			map:DrawCircle(posB, cellElmosHalf/2, colours.p, cell.IM, true, 4)
-- 		end
-- 		if cell.frontZ then
-- 			map:DrawCircle(posB, cellElmosHalf/2, colours.f, cell.IM, true, 4)
-- 		end

	end
-- 	for X,Z in pairs(self.enemyFrontCellsX) do
-- 		map:DrawCircle(self.CELLS[X][Z].pos, cellElmosHalf/2, colours.f, 'frontX', true, 4)
-- 	end
-- 	for Z,X in pairs(self.enemyFrontCellsZ) do
-- 		map:DrawCircle(self.CELLS[X][Z].pos, cellElmosHalf/2, colours.f, 'frontZ', true, 4)
-- 	end

	for i,cell in pairs(self.enemyFrontList) do
		map:DrawCircle(cell.pos, cellElmosHalf/2, colours.f, 'front', true, 4)
	end
end






--[[
-- for on-the-fly enemy evasion
function TargetHST:BestAdjacentPosition(unit, targetPosition)
	local position = unit:GetPosition()
	local px, pz = GetCellPosition(position)
	local tx, tz = GetCellPosition(targetPosition)
	if px >= tx - 1 and px <= tx + 1 and pz >= tz - 1 and pz <= tz + 1 then
		-- if we're already in the target cell or adjacent to it, keep moving
		return nil, true
	end
	--self:UpdateMap()
	local bestDist = 20000
	local best
	local notsafe = false
	local uname = unit:Name()
	local f = self.game:Frame()
	local maxThreat = baseUnitThreat
	-- 	local uthreat, urange = self.ai.tool:ThreatRange(uname)
	local uthreat = self.ai.armyhst.unitTable[uname].threat
	local urange = self.ai.armyhst.unitTable[uname].maxRange
	self:EchoDebug(uname .. ": " .. uthreat .. " " .. urange)
	if uthreat > maxThreat then maxThreat = uthreat end
	local doubleUnitRange = urange * 2
	for x = px - 1, px + 1 do
		for z = pz - 1, pz + 1 do
			if x == px and z == pz then
				-- don't move to the cell you're already in
			else
				local dist = self.ai.tool:DistanceXZ(tx, tz, x, z) * cellElmos
				if self:CellExist(x,z) then
					local value, threat = self:CellValueThreat(uname, self.cells[x][z])
					if self.ai.armyhst.raiders[uname] then
						-- self.cells with other raiders in or nearby are better places to go for raiders
						if self.cells[x][z].raiderHere then threat = threat - self.cells[x][z].raiderHere end
						if self.cells[x][z].raiderAdjacent then threat = threat - self.cells[x][z].raiderAdjacent end
					end
					if threat > maxThreat then
						-- if it's below baseUnitThreat, it's probably a lone construction unit
						dist = dist + threat
						notsafe = true
					end
				end
				-- if we just went to the same place, probably not a great place
				for i = #self.feints, 1, -1 do
					local feint = self.feints[i]
					if f > feint.frame + 900 then
						-- expire stored after 30 seconds
						table.remove(self.feints, i)
					elseif feint.x == x and feint.z == z and feint.px == px and feint.pz == pz and feint.tx == tx and feint.tz == tz then
						dist = dist + feintRepeatMod
					end
				end
				if dist < bestDist and self:CellExist(x,z) and self.ai.maphst:UnitCanGoHere(unit, self.cells[x][z].pos) then
					bestDist = dist
					best = self.cells[x][z]
				end
			end
		end
	end
	if best and notsafe then
		local mtype = self.ai.armyhst.unitTable[uname].mtype
		self:AddBadPosition(targetPosition, mtype, 16, 1200) -- every thing to avoid on the way to the target increases its threat a tiny bit
		table.insert(self.feints, {x = best.x, z = best.z, px = px, pz = pz, tx = tx, tz = tz, frame = f})
		return best.pos
	end
end



function TargetHST:RaidableCell(representative, position)
	position = position or representative:GetPosition()
	local cell = self:GetCellHere(position)
	if not cell or cell.value == 0 then return end
	local value, threat, gas = self:CellValueThreat(rname, cell)
	-- cells with other raiders in or nearby are better places to go for raiders
	if cell.raiderHere then threat = threat - cell.raiderHere end
	if cell.raiderAdjacent then threat = threat - cell.raiderAdjacent end
	local rname = representative:Name()
	local maxThreat = baseUnitThreat
	--local rthreat, rrange = self.ai.tool:ThreatRange(rname)
	local rthreat = self.ai.armyhst.unitTable[rname].threat
	local rrange = self.ai.armyhst.unitTable[rname].maxRange
	self:EchoDebug(rname .. ": " .. rthreat .. " " .. rrange)
	if rthreat > maxThreat then maxThreat = rthreat end
	-- self:EchoDebug(value .. " " .. threat)
	if threat <= maxThreat then
		return cell
	end
end
]]
-- function TargetHST:RaiderHere(raidbehaviour)
-- 	if raidbehaviour == nil then return end
-- 	if raidbehaviour.unit == nil then return end
-- 	if self.raiderCounted[raidbehaviour.id] then return end
-- 	local unit = raidbehaviour.unit:Internal()
-- 	if unit == nil then return end
-- 	--local uthreat, urange = self.ai.tool:ThreatRange(unit:Name())
-- 	local uthreat = self.ai.armyhst.unitTable[unit:Name()].threat
-- 	local rrange = self.ai.armyhst.unitTable[unit:Name()].maxRange
-- 	local position = unit:GetPosition()
-- 	local px, pz = GetCellPosition(position)
-- 	local inCell
-- 	if self:CellExist(px,pz) then
-- 		inCell = self.cells[px][pz]
-- 		if inCell.raiderHere == nil then inCell.raiderHere = 0 end
-- 		inCell.raiderHere = inCell.raiderHere + (uthreat * 0.67)
-- 	end
-- 	local adjacentThreatReduction = uthreat * 0.33
-- 	for cx , cz in pairs(self:adiaCells(px,pz,'raiderAdjacent')) do
-- 		self.cells[cx][cz].raiderAdjacent  = self.cells[cx][cz].raiderAdjacent + adjacentThreatReduction
-- 	end
-- 	self.raiderCounted[raidbehaviour.id] = true -- reset with UpdateMap()
-- end



-- function TargetHST:GetBestAttackCell(representative, position, ourThreat)
-- 	if not representative then return end
-- 	position = position or representative:GetPosition()
-- 	--self:UpdateMap()
-- 	local bestValueCell
-- 	local bestValue = -999999
-- 	local bestAnyValueCell
-- 	local bestAnyValue = -999999
-- 	local bestThreatCell
-- 	local bestThreat = 0
-- 	local name = representative:Name()
-- 	local longrange = self.ai.armyhst.unitTable[name].groundRange > 1000
-- 	local mtype = self.ai.armyhst.unitTable[name].mtype
-- 	ourThreat = ourThreat or self.ai.armyhst.unitTable[name].metalCost * self.ai.attackhst:GetCounter(mtype)
-- 	if mtype ~= "sub" and longrange then longrange = true end
-- 	local possibilities = {}
-- 	local highestDist = 0
-- 	local lowestDist = math.huge
-- 	for i, cell in pairs(self.cellList) do
-- 		if cell.pos then
-- 			if self.ai.maphst:UnitCanGoHere(representative, cell.pos) or longrange then
-- 				local value, threat = self:CellValueThreat(name, cell)
-- 				local dist = self.ai.tool:Distance(position, cell.pos)
-- 				if dist > highestDist then highestDist = dist end
-- 				if dist < lowestDist then lowestDist = dist end
-- 				table.insert(possibilities, { cell = cell, value = value, threat = threat, dist = dist })
-- 			end
-- 		end
-- 	end
-- 	local distRange = highestDist - lowestDist
-- 	for i, pb in pairs(possibilities) do
-- 		self.map:DrawCircle(pb.cell.pos,100, {0,1,0,1}, i,true, 6)
-- 		local fraction = 1.5 - ((pb.dist - lowestDist) / distRange)
-- 		local value = pb.value * fraction
-- 		local threat = pb.threat * fraction
-- 		if pb.value > 750 then
-- 			value = value - (threat * 0.5)
-- 			if value > bestValue then
-- 				bestValueCell = pb.cell
-- 				bestValue = value
-- 			end
-- 		elseif pb.value > 0 then
-- 			value = value - (threat * 0.5)
-- 			if value > bestAnyValue then
-- 				bestAnyValueCell = pb.cell
-- 				bestAnyValue = value
-- 			end
-- 		else
-- 			if threat > bestThreat then
-- 				bestThreatCell = pb.cell
-- 				bestThreat = threat
-- 			end
-- 		end
-- 	end
-- 	local best
-- 	if bestValueCell then
-- 		best = bestValueCell
-- 	elseif self.enemyBaseCell then
-- 		best = self.enemyBaseCell
-- 	elseif bestAnyValueCell then
-- 		best = bestAnyValueCell
-- 	elseif bestThreatCell then
-- 		best = bestThreatCell
-- 	elseif self.lastAttackCell then
-- 		best = self.lastAttackCell
-- 	end
-- 	self.lastAttackCell = best
-- 	return best
-- end
--
-- function TargetHST:GetNearestAttackCell(representative, position, ourThreat)
-- 	if not representative then return end
-- 	position = position or representative:GetPosition()
-- 	--self:UpdateMap()
-- 	local name = representative:Name()
-- 	local longrange = self.ai.armyhst.unitTable[name].groundRange > 1000
-- 	local mtype = self.ai.armyhst.unitTable[name].mtype
-- 	ourThreat = ourThreat or self.ai.armyhst.unitTable[name].metalCost * self.ai.attackhst:GetCounter(mtype)
-- 	if mtype ~= "sub" and longrange then longrange = true end
-- 	local lowestDistValueable
-- 	local lowestDistThreatening
-- 	local closestValuableCell
-- 	local closestThreateningCell
-- 	for i, cell in pairs(self.cellList) do
-- 		if cell.pos then
-- 			if self.ai.maphst:UnitCanGoHere(representative, cell.pos) or longrange then
-- 				local value, threat = self:CellValueThreat(name, cell)
-- 				if threat <= ourThreat * 0.67 then
-- 					if value > 0 then
-- 						local dist = self.ai.tool:Distance(position, cell.pos)
-- 						if not lowestDistValueable or dist < lowestDistValueable then
-- 							lowestDistValueable = dist
-- 							closestValuableCell = cell
-- 						end
-- 					elseif threat > 0 then
-- 						local dist = self.ai.tool:Distance(position, cell.pos)
-- 						if not lowestDistThreatening or dist < lowestDistThreatening then
-- 							lowestDistThreatening = dist
-- 							closestThreateningCell = cell
-- 						end
-- 					end
-- 				end
-- 			end
-- 		end
-- 	end
-- 	if closestValuableCell then
--
-- 		self.map:DrawCircle(closestValuableCell.pos  ,100, {1,0,0,1}, 'cvc',true, 6)
-- 	end
-- 	if closestThreateningCell then
-- 		self.map:DrawCircle(closestThreateningCell.pos ,100, {0,0,1,1}, 'ctc',true, 6)
-- 	end
--
-- 	return closestValuableCell or closestThreateningCell
-- end
--[[
function TargetHST:GetBestNukeCell()
	--self:UpdateMap()
	if self.enemyBaseCell then return self.enemyBaseCell end
	local best
	local bestValueThreat = 0
	for i, cell in pairs(self.cellList) do
		if cell.pos then
			local value, threat = self:CellValueThreat("ALL", cell)
			if value > minNukeValue then
				local valuethreat = value + threat
				if valuethreat > bestValueThreat then
					best = cell
					bestValueThreat = valuethreat
				end
			end
		end
	end
	return best, bestValueThreat
end
]]

-- local function PlotSquareDebug(x, z, size, color, label, filled)
-- 	if DebugDrawEnabled then
-- 		x = mCeil(x)
-- 		z = mCeil(z)
-- 		size = mCeil(size)
-- 		local halfSize = size / 2
-- 		local pos1, pos2 = api.Position(), api.Position()
-- 		pos1.x, pos1.z = x - halfSize, z - halfSize
-- 		pos2.x, pos2.z = x + halfSize, z + halfSize
-- 		map:DrawRectangle(pos1, pos2, color, label, filled, 8)
-- 	end
-- end
--
-- function TargetHST:UpdateDebug()
-- 	if not DebugDrawEnabled then
-- 		return
-- 	end
-- 	map:EraseRectangle(nil, nil, nil, nil, true, 8)
-- 	map:EraseRectangle(nil, nil, nil, nil, false, 8)
-- 	local maxThreat = 0
-- 	local maxValue = 0
-- 	for cx, czz in pairs(self.cells) do
-- 		for cz, cell in pairs(czz) do
-- 			local value, threat = self:CellValueThreat("ALL", cell)
-- 			if threat > maxThreat then maxThreat = threat end
-- 			if value > maxValue then maxValue = value end
-- 		end
-- 	end
-- 	for cx, czz in pairs(self.cells) do
-- 		for cz, cell in pairs(czz) do
-- 			local x = cell.x * cellElmos - cellElmosHalf
-- 			local z = cell.z * cellElmos - cellElmosHalf
-- 			local value, threat = self:CellValueThreat("ALL", cell)
-- 			if value > 0 then
-- 				local g = value / maxValue
-- 				local b = 1 - g
-- 				PlotSquareDebug(x, z, cellElmos, {0,g,b}, tostring(value), false)
-- 			end
-- 			if threat > 0 then
-- 				local g = 1 - (threat / maxThreat)
-- 				PlotSquareDebug(x, z, cellElmos, {1,g,0}, tostring(threat), true)
-- 			end
-- 		end
-- 	end
-- end




--[[
function TargetHST:Value(unitName)--used only here DEPRECATED
	local v = unitValue[unitName]
	if v then return v end
	local utable = self.ai.armyhst.unitTable[unitName]
	if not utable then return 0 end
	local val = utable.metalCost + (utable.techLevel * techValue)
	if utable.buildOptions ~= nil then
		if utable.isBuilding then
			-- factory
			val = val + factoryValue
		else
			-- construction unit
			val = val + conValue
		end
	end
	if utable.extractsMetal > 0 then
		val = val + 800000 * utable.extractsMetal
	end
	if utable.totalEnergyOut > 0 then
		val = val + (utable.totalEnergyOut * energyOutValue)
	end
	unitValue[unitName] = val
	return val
end



-- need to change because: amphibs can't be hurt by non-submerged threats in water, and can't be hurt by anything but ground on land
function TargetHST:CellValueThreat(unitName, cell)--DEPRECATED
	if cell == nil then return 0, 0 end
	local gas, weapons
	if unitName == "ALL" then
		gas = threatTypesAsKeys
		weapons = threatTypes
		unitName = "nothing"
	else
		gas = self.ai.tool:WhatHurtsUnit(unitName, nil, cell.pos)
		weapons = self.ai.armyhst.unitTable[unitName].weaponLayer--self.ai.tool:UnitWeaponLayerList(unitName)
	end
	local threat = 0
	local value = 0
	local notThreat = 0
	for i = 1, #threatTypes do
		local GAS = threatTypes[i]
		local yes = gas[GAS]
		if yes then
			threat = threat + cell.threat[GAS]
			for i, weaponGAS in pairs(weapons) do
				value = value + cell.values[GAS][weaponGAS]
			end
		elseif self.ai.armyhst.airgun[unitName] then
			notThreat = notThreat + cell.threat[GAS]
		end
	end
	if gas.air and self.ai.armyhst.raiders[unitName] and not self.ai.armyhst.airgun[unitName] then
		threat = threat + cell.threat.ground * 0.1
	end
	if self.ai.armyhst.airgun[unitName] then
		value = notThreat
		-- if notThreat == 0 then value = 0 end
	end
	return value, threat, gas
end


function TargetHST:ValueHere(position, unitOrName)--DEPRECATED APART ATTACK
	--self:UpdateMap()
	local uname = self.ai.tool:UnitNameSanity(unitOrName)
	if not uname then return end
	local cell, px, pz = self:GetCellHere(position)
	if cell == nil then return 0, nil, uname end
	local value, _ = self:CellValueThreat(uname, cell)
	return value, cell, uname
end

function TargetHST:ThreatHere(position, unitOrName, check_adjacent)--DEPRECATED APART ATTACK
	--self:UpdateMap()
	local uname = self.ai.tool:UnitNameSanity(unitOrName)
	if not uname then return end
	local cell, px, pz = self:GetCellHere(position)
	if cell == nil then return 0, nil, uname end
	local value, threat = self:CellValueThreat(uname, cell)
	if check_adjacent then
		for cx = px-1, px+1 do
			if self.cells[cx] then
				for cz = pz-1, pz+1 do
					if not (cx == px and cz == pz) then
						local c = self.cells[cx][cz]
						if c then
							local cvalue, cthreat = self:CellValueThreat(uname, c)
							threat = threat + cthreat
						end
					end
				end
			end
		end
	end
	return threat, cell, uname
end

function TargetHST:IsSafePositionORIGINAL(position, unit, threshold, adjacent)
	local threat, cell, uname = self:ThreatHere(position, unit, adjacent)
	if not cell then
		return true
	end
	if threshold then
		return threat < self.ai.armyhst.unitTable[uname].metalCost * threshold, cell.response
	else
		return threat == 0, cell.response
	end
end

function TargetHST:IsBombardPosition(position, unitName)
	--self:UpdateMap()
	local px, pz = GetCellPosition(position)
	local radius = self.ai.armyhst.unitTable[unitName].groundRange
	local groundValue, groundThreat = self:CheckInRadius(px, pz, radius, "threat", "ground")
	if groundValue + groundThreat > self:Value(unitName) * 1.5 then
		return true
	else
		return false
	end
end


function TargetHST:GetBestBomberTarget(torpedo)
	--self:UpdateMap()
	local best
	local bestValue = 0
	for i, cell in pairs(self.cellList) do
		local value = cell.explosionValue
		if torpedo then
			value = value + cell.values.air.submerged
		else
			value = value + cell.values.air.ground
		end
		if value > 0 then
			value = value - cell.threat.air
			if value > bestValue then
				best = cell
				bestValue = value
			end
		end
	end
	if best then
		local bestTarget
		bestValue = 0
		local target = best.explosiveTarget
		if target == nil then
			if torpedo then
				target = best.targets.air.submerged.unit
			else
				target = best.targets.air.ground.unit
			end
		end
		return target
	end
end



function TargetHST:GetBestBombardCell(position, range, minValueThreat, ignoreValue, ignoreThreat)
	if ignoreValue and ignoreThreat then
		game:SendToConsole("trying to find a place to bombard but ignoring both value and threat doesn't work")
		return
	end
	--self:UpdateMap()
	if self.enemyBaseCell and not ignoreValue then
		local dist = self.ai.tool:Distance(position, self.enemyBaseCell.pos)
		if dist < range then
			local value = self.enemyBaseCell.values.ground.ground + self.enemyBaseCell.values.air.ground + self.enemyBaseCell.values.submerged.ground
			return self.enemyBaseCell, value + self.enemyBaseCell.response.ground
		end
	end
	local best
	local bestValueThreat = 0
	if minValueThreat then bestValueThreat = minValueThreat end
	for i, cell in pairs(self.cellList) do
		if #cell.buildingIDs > 0 then
			local dist = self.ai.tool:Distance(position, cell.pos)
			if dist < range then
				local value = cell.values.ground.ground + cell.values.air.ground + cell.values.submerged.ground
				local valuethreat = 0
				if not ignoreValue then valuethreat = valuethreat + value end
				if not ignoreThreat then valuethreat = valuethreat + cell.response.ground end
				if valuethreat > bestValueThreat then
					best = cell
					bestValueThreat = valuethreat
				end
			end
		end
	end
	if best then
		local bestBuildingID, bestBuildingVT
		for i, buildingID in pairs(best.buildingIDs) do
			local building = self.game:GetUnitByID(buildingID)
			if building then
				local uname = building:Name()
				local value = self:Value(uname)
				--local threat = self.ai.tool:ThreatRange(uname, "ground") + self.ai.tool:ThreatRange(uname, "air")
				local threat = self.ai.armyhst.unitTable[uname].groundThreat + self.ai.armyhst.unitTable[uname].airThreat
				local valueThreat = value + threat
				if not bestBuildingVT or valueThreat > bestBuildingVT then
					bestBuildingVT = valueThreat
					bestBuildingID = buildingID
				end
			end
		end
	end
	return best, bestValueThreat, bestBuildingID
end

local function CellVulnerable(cell, hurtByGAS, weaponsGAS)
	hurtByGAS = hurtByGAS or threatTypesAsKeys
	weaponsGAS = weaponsGAS or threatTypes
	if cell == nil then return end
	for GAS, yes in pairs(hurtByGAS) do
		for i, wGAS in pairs(weaponsGAS) do
			local vulnerable = cell.vulnerables[GAS][wGAS]
			if vulnerable ~= nil then return vulnerable end
		end
	end
end

function TargetHST:NearbyVulnerable(unit)
	if unit == nil then return end
	--self:UpdateMap()
	local position = unit:GetPosition()
	local px, pz = GetCellPosition(position)
	local unitName = unit:Name()
	local gas = self.ai.tool:WhatHurtsUnit(unitName, nil, position)
	local weapons = self.ai.armyhst.unitTable[unitName].weaponLayer  --self.ai.tool:UnitWeaponLayerList(unitName)
	-- check this cell
	local vulnerable = nil
	if self:CellExist(px,pz) then
		vulnerable = CellVulnerable(self.cells[px][pz], gas, weapons)

	end
	-- check adjacent self.cells
	if vulnerable == nil then
		for ix = px - 1, px + 1 do
			for iz = pz - 1, pz + 1 do
				if self.cells[ix] ~= nil then
					if self.cells[ix][iz] ~= nil then
						vulnerable = CellVulnerable(self.cells[ix][iz], gas, weapons)
						if vulnerable then break end
					end
				end
			end
			if vulnerable then break end
		end
	end
	return vulnerable
end

function TargetHST:adiaCells(px,pz,field)--return a list with 8 adiacent cells respect the reference cell
	local adiacents = {}
	for x = px - 1, px + 1 do
		if self.cells[x] ~= nil then
			for z = pz - 1, pz + 1 do
				if (x ~= px or z ~= pz) and self.cells[x][z] then -- ignore center cell
				if field and self.cells[x][z][field] == nil then
					self.cells[x][z][field] = 0
				end
				adiacents[x] = z
			end
		end
	end
end
return adiacents
end

]]



--[[
function TargetHST:HorizontalLine(x, z, tx, threatResponse, groundAirSubmerged, val)
	self.game:StartTimer('hl')
	-- self:EchoDebug("horizontal line from " .. x .. " to " .. tx .. " along z " .. z .. " with value " .. val .. " in " .. groundAirSubmerged)
	for ix = x, tx do
		local cell =self:GetOrCreateCellHere(ix,z)
		if cell then
			self.cells[ix][z][threatResponse][groundAirSubmerged] = self.cells[ix][z][threatResponse][groundAirSubmerged] + val
		else
			--self:Warn('Cell not exist or is not in map in horizontalLine',ix,z)
		end
	end
	self.game:StopTimer('hl')
end

function TargetHST:Plot4(cx, cz, x, z, threatResponse, groundAirSubmerged, val)
	self.game:StartTimer('p4')
	self:HorizontalLine(cx - x, cz + z, cx + x, threatResponse, groundAirSubmerged, val)
	if x ~= 0 and z ~= 0 then
		self:HorizontalLine(cx - x, cz - z, cx + x, threatResponse, groundAirSubmerged, val)
	end
	self.game:StopTimer('p4')
end

function TargetHST:FillCircle(cx, cz, radius, threatResponse, groundAirSubmerged, val)
	self.game:StartTimer('fc')
	local radius = mCeil(radius / cellElmos)
	if radius > 0 then
		local err = -radius
		local x = radius
		local z = 0
		while x >= z do
			local lastZ = z
			err = err + z
			z = z + 1
			err = err + z
			self:Plot4(cx, cz, x, lastZ, threatResponse, groundAirSubmerged, val)
			if err >= 0 then
				if x ~= lastZ then self:Plot4(cx, cz, lastZ, x, threatResponse, groundAirSubmerged, val) end
				err = err - x
				x = x - 1
				err = err - x
			end
		end
	end
	self.game:StopTimer('fc')
end

function TargetHST:CheckHorizontalLine(x, z, tx, threatResponse, groundAirSubmerged)
	self.game:StartTimer('chl')
	-- self:EchoDebug("horizontal line from " .. x .. " to " .. tx .. " along z " .. z .. " in " .. groundAirSubmerged)
	local value = 0
	local threat = 0
	for ix = x, tx do
		if self:CellExist(ix,z) then
			local cell = self.cells[ix][z]
			local value = cell.values[groundAirSubmerged].value -- can't hurt it
			local threat = cell[threatResponse][groundAirSubmerged]
			self.game:StopTimer('chl')
			return value, threat

		end
	end
	self.game:StopTimer('chl')
	return value, threat
end

function TargetHST:Check4(cx, cz, x, z, threatResponse, groundAirSubmerged)
	self.game:StartTimer('c4')
	local value = 0
	local threat = 0
	local v, t = self:CheckHorizontalLine(cx - x, cz + z, cx + x, threatResponse, groundAirSubmerged)
	value = value + v
	threat = threat + t
	if x ~= 0 and z ~= 0 then
		local v, t = self:CheckHorizontalLine(cx - x, cz - z, cx + x, threatResponse, groundAirSubmerged)
		value = value + v
		threat = threat + t
	end
	self.game:StopTimer('c4')
	return value, threat
end

function TargetHST:CheckInRadius(cx, cz, radius, threatResponse, groundAirSubmerged)
	self.game:StartTimer('cr')
	local radius = mCeil(radius / cellElmos)
	local value = 0
	local threat = 0
	if radius > 0 then
		local err = -radius
		local x = radius
		local z = 0
		while x >= z do
			local lastZ = z
			err = err + z
			z = z + 1
			err = err + z
			local v, t = self:Check4(cx, cz, x, lastZ, threatResponse, groundAirSubmerged)
			value = value + v
			threat = threat + t
			if err >= 0 then
				if x ~= lastZ then
					local v, t = self:Check4(cx, cz, lastZ, x, threatResponse, groundAirSubmerged)
					value = value + v
					threat = threat + t
				end
				err = err - x
				x = x - 1
				err = err - x
			end
		end
	end
	self.game:StopTimer('cr')
	return value, threat
end


function TargetHST:CountEnemyThreat(unitID, unitName, threat)
	if not self.enemyAlreadyCounted[unitID] then
		self.currentEnemyThreatCount = self.currentEnemyThreatCount + threat
		if self.ai.armyhst.unitTable[unitName].isBuilding then
			self.currentEnemyImmobileThreatCount = self.currentEnemyImmobileThreatCount + threat
		else
			self.currentEnemyMobileThreatCount = self.currentEnemyMobileThreatCount + threat
		end
		self.enemyAlreadyCounted[unitID] = true
	end
end

]]

--[[
function TargetHST:CountDanger(layer, id)
	local danger = self.dangers[layer]
	if not danger.alreadyCounted[id] then
		danger.count = danger.count + 1
		self:EchoDebug("spotted " .. layer .. " threat")
		danger.alreadyCounted[id] = true
	end
end

function TargetHST:DangerCheck(unitName, unitID)
	local un = unitName
	local ut = self.ai.armyhst.unitTable[un]
	local id = unitID
	if ut.isBuilding then
		if ut.needsWater then
			self:CountDanger("watertarget", id)
		else
			self:CountDanger("landtarget", id)
		end
	end
	if not ut.isBuilding and not self.ai.armyhst.commanderList[un] and ut.mtype ~= "air" and ut.mtype ~= "sub" and ut.groundRange > 0 then
		self:CountDanger("ground", id)
	elseif self.ai.armyhst.groundFacList[un] then
		self:CountDanger("ground", id)
	end
	if ut.mtype == "air" and ut.groundRange > 0 then
		self:CountDanger("air", id)
	elseif self.ai.armyhst.airFacList[un] then
		self:CountDanger("air", id)
	end
	if (ut.mtype == "sub" or ut.mtype == "shp") and ut.isWeapon and not ut.isBuilding then
		self:CountDanger("submerged", id)
	elseif self.ai.armyhst.subFacList[un] then
		self:CountDanger("submerged", id)
	end
	if self.ai.armyhst.bigPlasmaList[un] then
		self:CountDanger("plasma", id)
	end
	if self.ai.armyhst.nukeList[un] then
		self:CountDanger("nuke", id)
	end
	if self.ai.armyhst.antinukes[un] then
		self:CountDanger("antinuke", id)
	end
	if ut.mtype ~= "air" and ut.mtype ~= "sub" and ut.groundRange > 1000 then
		self:CountDanger("longrange", id)
	end
end

local function NewDangerLayer()
	return { count = 0, alreadyCounted = {}, present = false, obsolesce = 0, threshold = 1, duration = 1800, }
end

function TargetHST:InitializeDangers()
	self.dangers = {}
	self.dangers["watertarget"] = NewDangerLayer()
	self.dangers["landtarget"] = NewDangerLayer()
	self.dangers["landtarget"].duration = 2400
	self.dangers["landtarget"].present = true
	self.dangers["landtarget"].obsolesce = self.game:Frame() + 5400
	self.dangers["ground"] = NewDangerLayer()
	self.dangers["ground"].duration = 2400 -- keep ground threat alive for one and a half minutes
	-- assume there are ground threats for the first three minutes
	self.dangers["ground"].present = true
	self.dangers["ground"].obsolesce = self.game:Frame() + 5400
	self.dangers["air"] = NewDangerLayer()
	self.dangers["submerged"] = NewDangerLayer()
	self.dangers["plasma"] = NewDangerLayer()
	self.dangers["nuke"] = NewDangerLayer()
	self.dangers["antinuke"] = NewDangerLayer()
	self.dangers["longrange"] = NewDangerLayer()
end

function TargetHST:UpdateDangers()
	local f = self.game:Frame()

	for layer, danger in pairs(self.dangers) do
		if danger.count >= danger.threshold then
			danger.present = true
			danger.obsolesce = f + danger.duration
			danger.count = 0
			danger.alreadyCounted = {}
			self:EchoDebug(layer .. " danger present")
		elseif danger.present and f >= danger.obsolesce then
			self:EchoDebug(layer .. " obsolete")
			danger.present = false
		end
	end

	self.ai.areWaterTargets = self.dangers.watertarget.present
	self.ai.areLandTargets = self.dangers.landtarget.present or not self.dangers.watertarget.present
	self.ai.needGroundDefense = self.dangers.ground.present or (not self.dangers.air.present and not self.dangers.submerged.present) -- don't turn off ground defense if there aren't air or submerged self.dangers
	self.ai.needAirDefense = self.dangers.air.present
	self.ai.needSubmergedDefense = self.dangers.submerged.present
	self.ai.needShields = self.dangers.plasma.present
	self.ai.needAntinuke = self.dangers.nuke.present
	self.ai.canNuke = not self.dangers.antinuke.present
	self.ai.needJammers = self.dangers.longrange.present or self.dangers.air.present or self.dangers.nuke.present or self.dangers.plasma.present
end
]]
--[[








		--if ghost and not ghost.position and not e.beingBuilt then
		if e.view < 0 then
			-- count ghosts with unknown positions as non-positioned threats
			self:DangerCheck(name, unitID)
			-- 			local threatLayers = self.ai.tool:UnitThreatRangeLayers(name)
			local threatLayers = self.ai.armyhst.unitTable[name].threatLayers
			for groundAirSubmerged, layer in pairs(threatLayers) do
				self:CountEnemyThreat(unitID, name, layer.threat)
			end
		--elseif (los ~= 0 or (ghost and ghost.position)) and not e.beingBuilt then
		else
			-- count those we know about and that aren't being built
			local pos
			if ghost then pos = ghost.position else pos = e.position end
			if self.ai.buildsitehst:isInMap(pos) then

				local px, pz = GetCellPosition(pos)
				if not self:CellExist(px,pz) then
					--self:Warn('warning cell is not already defined!!!!',px,pz)
				end
				local cell = self:GetOrCreateCellHere(pos)
				if e.SPEED then
					--cell.target.x = math.max(cell.target.x , e.target.x)
					--cell.target.z = math.max(cell.target.z , e.target.z)
					--cell.target.y = Spring.GetGroundHeight(cell.target.x,cell.target.z)
					--cell.risksNum = cell.risksNum + 1 --TODO become metal amount
				end
-- 				if los == 1 then
				if e.view == 0 then--radar
					if ut.isBuilding then
						cell.value = cell.value + baseBuildingValue
					else
						-- if it moves, assume it's out to get you--TEST
						--self:FillCircle(px, pz, baseUnitRange, "threat", "ground", baseUnitThreat)
						--self:FillCircle(px, pz, baseUnitRange, "threat", "air", baseUnitThreat)
						--self:FillCircle(px, pz, baseUnitRange, "threat", "submerged", baseUnitThreat)
					end
-- 				elseif los == 2 then
				elseif e.view > 0 then --LOS, full view
					local mtype = ut.mtype
					self:DangerCheck(name, unitID)
-- 					local value = self:Value(name)
					local value = ut.metalCost
					if self.ai.armyhst.unitTable[name].extractsMetal ~= 0 then
						table.insert(self.ai.enemyMexSpots, { position = pos, unit = e })
					end
					if self.ai.armyhst.unitTable[name].isBuilding then
						table.insert(cell.buildingIDs, unitID)
					end
					local hurtBy = self.ai.tool:WhatHurtsUnit(name)
					-- 					local threatLayers = self.ai.tool:UnitThreatRangeLayers(name)
					local threatLayers = self.ai.armyhst.unitTable[name].threatLayers
					local threatToTurtles = threatLayers.ground.threat + threatLayers.submerged.threat
					local maxRange = max(threatLayers.ground.range, threatLayers.submerged.range)
					for groundAirSubmerged, layer in pairs(threatLayers) do
						if threatToTurtles ~= 0 and hurtBy[groundAirSubmerged] then
							if ut.isBuilding then--TEST
								self:FillCircle(px, pz, maxRange, "response", groundAirSubmerged, threatToTurtles)
							end
						end
						local threat, range = layer.threat, layer.range
						if mtype == "air" and groundAirSubmerged == "ground" or groundAirSubmerged == "submerged" then threat = 0 end -- because air units are pointless to run from
						if threat ~= 0 then
							if ut.isBuilding then--TEST
								self:FillCircle(px, pz, range, "threat", groundAirSubmerged, threat)
							end
							self:CountEnemyThreat(unitID, name, threat)
						elseif mtype ~= "air" then -- air units are too hard to attack
						local health = e.health
						for hurtGAS, hit in pairs(hurtBy) do
							cell.values[groundAirSubmerged][hurtGAS] = cell.values[groundAirSubmerged][hurtGAS] + value
							if cell.targets[groundAirSubmerged][hurtGAS] == nil then
								cell.targets[groundAirSubmerged][hurtGAS] = e
							else
-- 								if value > self:Value(cell.targets[groundAirSubmerged][hurtGAS].unitName) then
-- 								print(value)
-- 								print(self.ai.armyhst.unitTable[cell.targets[groundAirSubmerged][hurtGAS].name].metalCost)
								if value > self.ai.armyhst.unitTable[cell.targets[groundAirSubmerged][hurtGAS].name].metalCost then
									cell.targets[groundAirSubmerged][hurtGAS] = e
								end
							end
							if health < vulnerableHealth then

								cell.vulnerables[groundAirSubmerged][hurtGAS] = e
							end
							if groundAirSubmerged == "air" and hurtGAS == "ground" and threatLayers.ground.threat > cell.lastDisarmThreat then
								cell.disarmTarget = e
								cell.lastDisarmThreat = threatLayers.ground.threat
							end
						end
						if ut.bigExplosion then
							cell.explosionValue = cell.explosionValue + bomberExplosionValue
							if cell.explosiveTarget == nil then
								cell.explosiveTarget = e
							else
								if value > self:Value(cell.explosiveTarget.unitName) then
									cell.explosiveTarget = e
								end
							end
						end
					end
				end
				cell.value = cell.value + value
				if cell.value > highestValue then
					highestValue = cell.value
					highestValueCell = cell

				end
			end
		end
		-- we dont want to target the center of the cell encase its a ledge with nothing
		-- on it etc so target this units position instead
			if cell then
				cell.pos = pos
			end
		end
	self.game:StopTimer(name)
	end
	if highestValueCell then
		self.enemyBaseCell = highestValueCell
		self.ai.enemyBasePosition = highestValueCell.pos
	else
		self.enemyBaseCell = nil
		self.ai.enemyBasePosition = nil
	end
	]]

--[[


function TargetHST:UpdateFronts(number)
	local highestCells = {}
	local highestResponses = {}
	for n = 1, number do
		local highestCell = {}
		local highestResponse = { ground = 0, air = 0, submerged = 0 }
		for i = 1, #self.cellList do
			local cell = self.cellList[i]
			for groundAirSubmerged, response in pairs(cell.response) do
				local okay = true
				if n > 1 then
					local highCell = highestCells[n-1][groundAirSubmerged]
					if highCell ~= nil then
						if cell == highCell then
							okay = false
						elseif response >= highestResponses[n-1][groundAirSubmerged] then
							okay = false
						else
							local dist = self.ai.tool:DistanceXZ(highCell.x, highCell.z, cell.x, cell.z)
							if dist < 2 then okay = false end
						end
					end
				end
				if okay and response > highestResponse[groundAirSubmerged] then
					highestResponse[groundAirSubmerged] = response
					highestCell[groundAirSubmerged] = cell
				end
			end
		end
		highestResponses[n] = highestResponse
		highestCells[n] = highestCell
	end
	self.ai.defendhst:FindFronts(highestCells)
end
]]

--[[



--[[

local mFloor = math.floor
local mCeil = math.ceil

local threatTypes = { "ground", "air", "submerged" }
local threatTypesAsKeys = { ground = true, air = true, submerged = true }
local baseUnitThreat = 0 -- 150
local baseUnitRange = 0 -- 250
local unseenMetalGeoValue = 50
local baseBuildingValue = 150
local bomberExplosionValue = 2000
local vulnerableHealth = 400
local wreckMult = 100
local vulnerableReclaimDistMod = 100
local badCellThreat = 300
local attackDistMult = 0.5 -- between 0 and 1, the lower number, the less self.ai.tool:distance matters
local reclaimModMult = 0.5 -- how much does the cell's metal & energy modify the self.ai.tool:distance to the cell for reclaim cells

local factoryValue = 1000
local conValue = 300
local techValue = 50
local energyOutValue = 2
local minNukeValue = factoryValue + techValue + 500

local feintRepeatMod = 25

local unitValue = {}


local function NewCell(px, pz)
	local x = px * cellElmos - cellElmosHalf
	local z = pz * cellElmos - cellElmosHalf
	local position = api.Position()
	position.x, position.z = x, z
	position.y = Spring.GetGroundHeight(x, z)
	if x < 0 or z < 0 or x > Game.mapSizeX or z > Game.mapSizeZ  then
		--print(px,pz,'cell not in map',x,z)
		return
	end
	local values = {
		ground = {ground = 0, air = 0, submerged = 0, value = 0},
		air = {ground = 0, air = 0, submerged = 0, value = 0},
		submerged = {ground = 0, air = 0, submerged = 0, value = 0},
		} -- value to our units first to who can be hurt by those things, then to those who have those kinds of weapons
	-- [GAS].value is just everything that doesn't hurt that kind of thing
	local targets = { ground = {}, air = {}, submerged = {}, } -- just one target for each [GAS][hurtGAS]
	local vulnerables = { ground = {}, air = {}, submerged = {}, } -- just one vulnerable for each [GAS][hurtGAS]
	local threat = { ground = 0, air = 0, submerged = 0 } -- threats (including buildings) by what they hurt
	local response = { ground = 0, air = 0, submerged = 0 } -- count mobile threat by what can hurt it
	local preresponse = { ground = 0, air = 0, submerged = 0 } -- count where mobile threat will probably be by what can hurt it

	local newcell = { value = 0, explosionValue = 0, values = values, threat = threat, response = response, buildingIDs = {}, targets = targets, vulnerables = vulnerables, resurrectables = {}, reclaimables = {}, lastDisarmThreat = 0, metal = 0, energy = 0, x = px, z = pz, pos = position }

	return newcell
end


function TargetHST:GetOrCreateCellHere(pos,posZ)--can be a position or 2 grid location(px,pz)
	local px,pz
	if type(pos) == 'table' then
		px, pz = GetCellPosition(pos)
	else
		px = pos
		pz = posZ
	end

	local cell = self:CellExist(px,pz)
	if cell then
		return cell

	end
	cell = NewCell(px,pz)
	if cell then
		table.insert(self.cellList, cell)
		self:EchoDebug('#selfcelllist',#self.cellList)
		if not self.cells[px] then self.cells[px] = {} end
		self.cells[px][pz] = cell
		return self.cells[px][pz]
	end
end

local function GetCellPosition(pos)
	local px = mCeil(pos.x / cellElmos)
	local pz = mCeil(pos.z / cellElmos)
	return px, pz
end

function TargetHST:GetCellHere(pos)
	local px, pz = GetCellPosition(pos)
	if self.cells[px] and self.cells[px][pz] then
		return self.cells[px][pz], px, pz
	end
end

function TargetHST:CellExist(x,z)
	if not self.cells[x] or not  self.cells[x][z] then
		return false
	end
	return self.cells[x][z],x,z
end

-- 	self.enemyAlreadyCounted = {}
-- 	self.currentEnemyThreatCount = 0
-- 	self.currentEnemyImmobileThreatCount = 0
-- 	self.currentEnemyMobileThreatCount = 0
-- 	self.cells = {}
-- 	self.cellList = {}
-- 	self.badPositions = {}
-- 	self.dangers = {}

-- 	self.ai.enemyMexSpots = {}
-- 	self.ai.totalEnemyThreat = 10000
-- 	self.ai.totalEnemyImmobileThreat = 5000
-- 	self.ai.totalEnemyMobileThreat = 5000
-- 	self.ai.needGroundDefense = true
-- 	self.ai.areLandTargets = true
-- 	self.ai.canNuke = true
	--self:InitializeDangers()
	-- 	self.lastEnemyThreatUpdateFrame = 0
-- 	self.feints = {}
-- 	self.raiderCounted = {}
-- 	self.lastUpdateFrame = 0












]]


