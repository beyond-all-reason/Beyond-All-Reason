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

function DamageHST:UnitDamaged(engineUnit, attacker, damage)
	local teamID = engineUnit:Team()
	if teamID ~= game:GetTeamID() and not self.ai.friendlyTeamID[teamID] then
		return
	end
	local unitID = engineUnit:ID()
	self.isDamaged[unitID] = engineUnit
	-- even if the attacker can't be seen, human players know what weapons look like
	-- in non-lua shard, the attacker is nil if it's an enemy engineUnit, so this becomes useless
	if attacker ~= nil and attacker:AllyTeam() ~= self.ai.allyId then --   we know what is it and self.ai.loshst:IsKnownEnemy(attacker) ~= 2 then
		local mtype
		local ut = self.ai.armyhst.unitTable[engineUnit:Name()]
		if ut then
			local threat = damage
			local attackerut = self.ai.armyhst.unitTable[attacker:Name()]
			if attackerut then
				if attackerut.isBuilding then
					self.ai.loshst:scanEnemy(attacker,isShoting)---isshoting maybe need to be true?
					return
				end
				threat = attackerut.metalCost
			end
			self:AddBadPosition(engineUnit:GetPosition(), ut.mtype, threat, 900)
		end
	end
end

function DamageHST:AddBadPosition(position, mtype, threat, duration)
	threat = threat or badCellThreat
	duration = duration or 1800
	local X, Z = self.ai.maphst:PosToGrid(position)
	local gas = self.ai.tool:WhatHurtsUnit(nil, mtype, position)
	local f = self.game:Frame()
	for groundAirSubmerged, yes in pairs(gas) do
		if yes then
			local newRecord =
					{
						X = X,
						Z = Z,
						groundAirSubmerged = groundAirSubmerged,
						frame = f,
						threat = threat,
						duration = duration,
						}
			self.DAMAGED[X] = self.DAMAGED[X] or {}
			self.DAMAGED[X][Z] = newRecord
-- 			selfai.maphst.GRID[px][pz].damageCell = selfai.maphst.GRID[px][pz].damageCell + 1
		end
	end
end

function DamageHST:UpdateBadPositions()
	local f = self.game:Frame()
	for X,cells in pairs(self.DAMAGED) do
		for Z, cell in pairs(cells) do
			if f - cell.frame  > 300 then	--reset  bad position every 10 seconds
				self.DAMAGED[X][Z] = nil
			end
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
end

function DamageHST:UnitDead(engineUnit)
	self.isDamaged[engineUnit:ID()] = nil
	local pos = engineUnit:GetPosition()
	local name = engineUnit:Name()
	local mtype = self.ai.armyhst.unitTable[name].mtype
	self:AddBadPosition(pos, mtype)
end
