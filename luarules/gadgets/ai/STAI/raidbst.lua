--[[function IsAttacker(unit)
	-- 	return self.ai.armyhst.attackerlist[unit:Internal():Name()] or false
	return self.ai.armyhst.unitTable[unit:Internal():Name()].isAttacker
end]]

RaidBST = class(Behaviour)

function RaidBST:Name()
	return "RaidBST"
end

function RaidBST:Init()
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
	self.congSize = self.size * 1.5 -- how much self.ai.tool:distance between it and other raiders when congregating
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

function RaidBST:OwnerBuilt()
	self.ai.raidhst:AddRecruit(self)
end

function RaidBST:SetLastCommandReceived(cmd,target)
	self.lastCommand = cmd
	self.lastTarget = target
end

function RaidBST:GetLastCommandReceived()
	return self.lastCommand, self.lastTarget
end

function RaidBST:OwnerDamaged(attacker,damage)
	self.damaged = self.game:Frame()
end

function RaidBST:OwnerDead()
	self.unit = nil
	self.ai.raidhst:RemoveRecruit(self)
	self.ai.raidhst:RemoveMember(self)
end

function RaidBST:OwnerIdle()
	self.idle = true
end

function RaidBST:OwnerMoveFailed(unit)
	self:Warn('OWNER MOVE FAILED')
	self:OwnerIdle()
end

function RaidBST:Priority()
	--if self.ai.raidhst:IsSoldier(self.id) then
	if self.ai.raidhst:RaiderHaveTarget(self.squad) then
		return 200
	else
		return 0
	end
end

function RaidBST:Activate()
end

function RaidBST:Deactivate()
end

function RaidBST:Update()
	local f = self.game:Frame()
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'RaidBST' then return end
	if not self.mtype then
		self:Warn('no mtype and network')
	end
	if self.damaged then
		if f > self.damaged + 450 then
			self.damaged = nil
		end
	end
end

function RaidBST:Free()
	self.target = nil
	self.idle = nil
	if self.squad and self.squad.disbanding then
		self.squad = nil
	else
		self.ai.raidhst:RemoveMember(self)
	end
	self.unit:ElectBehaviour()
end