--[[function IsAttacker(unit)
	-- 	return self.ai.armyhst.attackerlist[unit:Internal():Name()] or false
	return self.ai.armyhst.unitTable[unit:Internal():Name()].isAttacker
end]]

AttackerBST = class(Behaviour)

function AttackerBST:Name()
	return "AttackerBST"
end

function AttackerBST:Init()
	self.DebugEnabled = false
	local mtype, network = self.ai.maphst:MobilityOfUnit(self.unit:Internal())
	self.mtype = mtype
	self.network = network
	self.name = self.unit:Internal():Name()
	self.id = self.unit:Internal():ID()
	self.x = self.unit:Internal().x
	self.y = self.unit:Internal().y
	self.z = self.unit:Internal().z
	self.defID = self.ai.armyhst.unitTable[self.name].defId
	local ut = self.ai.armyhst.unitTable[self.name]
	self.level = ut.techLevel - 1
	if self.level == 0 then self.level = 0.5 elseif self.level < 0 then self.level = 0.25 end
	self.size = math.max(ut.xsize, ut.zsize) * 8
	self.congSize = self.size * 1.5 -- how much self.ai.tool:distance between it and other attackers when congregating
	self.range = math.max(ut.groundRange, ut.airRange, ut.submergedRange)
	self.weaponDistance = self.range * 0.9
	self.sightDistance = ut.sightDistance --* 0.9
	self.sturdy = self.ai.armyhst.battles[self.name] or self.ai.armyhst.breaks[self.name]
	if ut.groundRange > 0 then
		self.hits = "ground"
	elseif ut.submergedRange > 0 then
		self.hits = "submerged"
	elseif ut.airRange > 0 then
		self.hits = "air"
	end
	self.speed = ut.speed
	self.threat = ut.metalCost
	self.mass = ut.metalCost
end

function AttackerBST:OwnerBuilt()
	self.attacking = false
	self.ai.attackhst:AddRecruit(self)
end

function AttackerBST:OwnerDamaged(attacker,damage)
	self.damaged = self.game:Frame()
end

function AttackerBST:OwnerDead()
	self.attacking = nil
	self.active = nil
	self.unit = nil
	self.ai.attackhst:RemoveRecruit(self)
	self.ai.attackhst:RemoveMember(self)
end

function AttackerBST:OwnerIdle()
	self.idle = true
	if self.active then
		self.ai.attackhst:MemberIdle(self)
	end
end

function AttackerBST:OwnerMoveFailed(unit)
	self:Warn('OWNER MOVE FAILED')
	self:OwnerIdle()
end

function AttackerBST:Priority()
	if not self.attacking then
		return 0
	else
		return 200
	end
end

function AttackerBST:Activate()
	self.active = true
end

function AttackerBST:Deactivate()
	self.active = false
end

function AttackerBST:Update()
	local f = self.game:Frame()
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'AttackerBST' then return end
	if not self.active and self.squad and self.target then
		self.unit:ElectBehaviour()
	end
	if not self.mtype then
		self:Warn('no mtype and network')
	end
	if self.damaged then
		if f > self.damaged + 450 then
			self.damaged = nil
		end
	end
end

function AttackerBST:Free()
	self.attacking = false
	self.target = nil
	self.idle = nil
	if self.squad and self.squad.disbanding then
		self.squad = nil
	else
		self.ai.attackhst:RemoveMember(self)
	end
	self.unit:ElectBehaviour()
end

