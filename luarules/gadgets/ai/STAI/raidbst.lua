function IsAttacker(unit)
	-- 	return self.ai.armyhst.attackerlist[unit:Internal():Name()] or false
	return self.ai.armyhst.unitTable[unit:Internal():Name()].isAttacker
end

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
	self.attacking = false
	self.ai.raidhst:AddRecruit(self)
end

function RaidBST:OwnerDamaged(attacker,damage)
	self.damaged = self.game:Frame()
end

function RaidBST:OwnerDead()
	self.attacking = nil
	self.active = nil
	self.unit = nil
	self.ai.raidhst:RemoveRecruit(self)
	self.ai.raidhst:RemoveMember(self)
end

function RaidBST:OwnerIdle()
	self.idle = true
	if self.active then
		self.ai.raidhst:MemberIdle(self)
	end
end

function RaidBST:OwnerMoveFailed(unit)
	self:Warn('OWNER MOVE FAILED')
	self:OwnerIdle()
end

function RaidBST:Priority()
	if not self.attacking then
		return 0
	else
		return 200
	end
end

function RaidBST:Activate()
	self.active = true
	self.movestateSet = false
	if self.target then
		self.needToMoveToTarget = true
	end
end

function RaidBST:Deactivate()
	self.active = false
end

function RaidBST:Update()
	local f = self.game:Frame()
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'RaidBST' then return end
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
	if self.active and not self.movestateSet then
		self:SetMoveState()
	end
	if self.active and self.needToMoveToTarget then
		self.needToMoveToTarget = false
		self.unit:Internal():AttackMove(self.target) --need to check this

	end
end

function RaidBST:MoveRandom(pos,dist)
	local away = self.ai.tool:RandomAway(pos, dist)
	if not self.unit then return end
	self.unit:Internal():AttackMove(away)
end

function RaidBST:Advance(pos, perpendicularAttackAngle, reverseAttackAngle)
	self.idle = false
	self.attacking = true
	if reverseAttackAngle then
		self:EchoDebug('adv reverse')
		local awayDistance = math.min(self.sightDistance, self.weaponDistance)
		if not self.sturdy or self.ai.loshst:posInLos(pos) then
			awayDistance = self.weaponDistance
		end
		local myAngle = self.ai.tool:AngleAdd(reverseAttackAngle, self.formationAngle)
		self.target = self.ai.tool:RandomAway( pos, awayDistance, nil, myAngle)
	else
		self:EchoDebug('adv drit')
		self.target = self.ai.tool:RandomAway2( pos, self.formationDist, nil, perpendicularAttackAngle,self.target)
	end
	--local canMoveThere = self.ai.maphst:UnitCanGoHere(self.unit:Internal(), self.target)
	local canMoveThere = Spring.TestMoveOrder(self.defID, self.target.x, self.target.y, self.target.z,nil,nil,nil,true,true,true)--TEST
	if canMoveThere and self.squad then
		self:EchoDebug('adv', canMoveThere)
		self.squad.lastValidMove = self.target
	elseif self.squad and self.squad.lastValidMove then
		self:EchoDebug('adv lastvalidMove',self.squad.lastValidMove)
		self.target = self.ai.tool:RandomAway( self.squad.lastValidMove, self.congSize)
		canMoveThere = self.ai.maphst:UnitCanGoHere(self.unit:Internal(), self.target)
	end
	self:EchoDebug('adv',self.attacking,self.active,self.target.x,self.target.z)
	if self.active and canMoveThere then
		self:EchoDebug('adv move',self.target.x,self.target.z)
		self.unit:Internal():Move(self.target) --need to check this
	end
	return canMoveThere
end

function RaidBST:Free()
	self.attacking = false
	self.target = nil
	self.idle = nil
	if self.squad and self.squad.disbanding then
		self.squad = nil
	else
		self.ai.raidhst:RemoveMember(self)
	end
	self.unit:ElectBehaviour()
end

-- this will issue the correct move state to all units
function RaidBST:SetMoveState()
	self.movestateSet = true
	local thisUnit = self.unit
	if thisUnit then
		thisUnit:Internal():HoldPosition()
	end
end
