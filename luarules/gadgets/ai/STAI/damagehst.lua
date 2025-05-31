DamageHST = class(Module)-- keeps track of hits to our units

function DamageHST:Name()
	return "DamageHST"
end

function DamageHST:internalName()
	return "damagehst"
end

function DamageHST:Init()
	self.DebugEnabled = false
	self.isDamaged = {}
	self.DAMAGED = {}
end

function DamageHST:UnitDamaged(defender, attacker, damage)
	local teamID = defender:Team()
	if teamID ~= game:GetTeamID() and not self.ai.friendlyTeamID[teamID] then
		return
	end
	local defenderID = defender:ID()
	local defenderName = defender:Name()
	self.isDamaged[defenderID] = defender
	-- even if the attacker can't be seen, human players know what weapons look like
	-- in non-lua shard, the attacker is nil if it's an enemy defender, so this becomes useless
	if attacker ~= nil and attacker:AllyTeam() ~= self.ai.allyId then --   we know what is it and self.ai.loshst:IsKnownEnemy(attacker) ~= 2 then
		local mtype
		local defenderUt = self.ai.armyhst.unitTable[defenderName]
		if defenderUt then
			local attackerut = self.ai.armyhst.unitTable[attacker:Name()]
			local attackerThreat = attackerut.metalCost or damage or 100
			local defenderThreat = defenderUt.metalCost or damage or 100

 			if attackerut then
 				if attackerut.isBuilding then
					self.ai.loshst.losEnemy[attacker:ID()] = defenderUt.defId
					self.ai.loshst.radarEnemy[attacker:ID()] = 	nil
--  					self.ai.loshst:scanEnemy(attacker,isShoting)---isshoting maybe need to be true?
--  					return
 				end

 			end
			self:AddBadPosition(defender:GetPosition(), defenderUt.mtype, attackerThreat,defenderThreat, 900)
		end
	end
end

function DamageHST:AddBadPosition(position, mtype, attackerThreat,defenderThreat, duration)
	duration = duration or 1800
	local X, Z = self.ai.maphst:PosToGrid(position)
	--local gas = self.ai.tool:WhatHurtsUnit(nil, mtype, position)
	local f = self.game:Frame()
	--for groundAirSubmerged, yes in pairs(gas) do
	--	if yes then
			local newRecord =
					{
						X = X,
						Z = Z,

						POS = self.ai.maphst:GridToPos(X,Z),
						groundAirSubmerged = groundAirSubmerged,
						frame = f,
						attackerThreat = attackerThreat,
						defenderThreat = defenderThreat,
						duration = duration,
						nodeCostIndex = self.ai.maphst:GridToNodeIndex(X,Z)
						}

			self.DAMAGED[X] = self.DAMAGED[X] or {}
			if not self.DAMAGED[X][Z] then
				self.DAMAGED[X][Z] = newRecord
			else
				self.DAMAGED[X][Z].frame = f
				self.DAMAGED[X][Z].attackerThreat = self.DAMAGED[X][Z].attackerThreat + newRecord.attackerThreat
				self.DAMAGED[X][Z].defenderThreat = self.DAMAGED[X][Z].defenderThreat + newRecord.defenderThreat

			end
		--end
	--end
end

function DamageHST:UpdateBadPositions()
	local f = self.game:Frame()
	for X,cells in pairs(self.DAMAGED) do
		for Z, cell in pairs(cells) do
			if f - cell.frame  > 300 then	-- reduce  bad position every 10 seconds
				cell.frame = f
				cell.attackerThreat = math.floor(cell.attackerThreat * 0.9)
				cell.defenderThreat = math.floor(cell.defenderThreat * 0.9)
				self:EchoDebug(self.DAMAGED[X][Z].defenderThreat)


				if cell.defenderThreat < 1 then
					self.DAMAGED[X][Z] = nil
				end

			end
-- 			self:EchoDebug(Spring.SetPathNodeCost(game:GetTeamID(),cell.nodeCostIndex,cell.defenderThreat))
-- 			self:EchoDebug('cost of ',cell.nodeCostIndex)
-- 			self:EchoDebug('X,Z',X,Z,'index',self.ai.maphst:GridToNodeIndex(X,Z))
-- 			self:EchoDebug('cell.POS.x,cell.POS.z',cell.POS.x,cell.POS.z ,self.ai.maphst:PosToNodeIndex(cell.POS))
-- 			self:EchoDebug('node cost PosToHeightMap',Spring.GetPathNodeCost(game:GetTeamID(),self.ai.maphst:PosToHeightMap(cell.POS)))
--
--
-- 			self:EchoDebug('cost of ',cell.nodeCostIndex , X,Z , cell.POS.x,cell.POS.z ,cell.defenderThreat , Spring.GetPathNodeCost(game:GetTeamID(),self.ai.maphst:PosToHeightMap(cell.POS)))
		end
	end
end

function DamageHST:UpdateDamagedUnits()
	for unitID, engineUnit in pairs(self.isDamaged) do
		local health = engineUnit:GetHealth()
		if not health or (health == engineUnit:GetMaxHealth()) then
			self.isDamaged[unitID] = nil
		end
	end
end

function DamageHST:Update()
	if self.ai.schedulerhst.moduleTeam ~= self.ai.id or self.ai.schedulerhst.moduleUpdate ~= self:Name() then return end
	self:UpdateBadPositions()
	self:UpdateDamagedUnits()
-- 	local prepathnodecost = Spring.GetPathNodeCosts(game:GetTeamID())
-- 	for i,v in pairs(prepathnodecost) do
-- 		if v > 0 then
-- 			self:EchoDebug('get path node cost',i,v)
-- 		end
-- 	end
	self:VisualDBG()
end

function DamageHST:UnitDead(engineUnit)
	self.isDamaged[engineUnit:ID()] = nil
end

function DamageHST:VisualDBG()
	
 	
	if not self.ai.drawDebug then
		return
	end
	local ch = 1
	self.map:EraseAll(ch)
	local colours = self.ai.tool.COLOURS
	for id,damaged in pairs(self.isDamaged) do
		damaged:EraseHighlight(nil, nil, ch )
		damaged:DrawHighlight(colours.green ,nil , ch )
	end
	local cellElmosHalf = self.ai.maphst.gridSizeHalf
	for X,cells in pairs(self.DAMAGED) do
		for Z, cell in pairs(cells) do
			local p = cell.POS
			if not p then
				self:EchoDebug('no p in draw debug')
				
				return
			end
			local pos1, pos2 = api.Position(), api.Position()--z,api.Position(),api.Position(),api.Position()
			pos1.x, pos1.z = p.x - cellElmosHalf, p.z - cellElmosHalf
			pos2.x, pos2.z = p.x + cellElmosHalf, p.z + cellElmosHalf
			pos1.y=Spring.GetGroundHeight(pos1.x,pos1.z)
			pos2.y=Spring.GetGroundHeight(pos2.x,pos2.z)
			map:DrawRectangle(p, pos2, colours.blue, cell.defenderThreat, false, ch)
			map:DrawRectangle(pos1, p, colours.red, cell.attackerThreat, false, ch)
			map:DrawPoint(p, colours.black, cell.X .. ':' ..cell.Z .. '=' .. cell.nodeCostIndex, ch)
		end
	end
end


