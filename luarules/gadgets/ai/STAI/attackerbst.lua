function IsAttacker(unit)
	-- 	return self.ai.armyhst.attackerlist[unit:Internal():Name()] or false
	return self.ai.armyhst.unitTable[unit:Internal():Name()].isAttacker
end

AttackerBST = class(Behaviour)

function AttackerBST:Name()
	return "AttackerBST"
end

AttackerBST.DebugEnabled = false

function AttackerBST:Init()
	local mtype, network = self.ai.maphst:MobilityOfUnit(self.unit:Internal())
	self.mtype = mtype
	self.network = network
	self.name = self.unit:Internal():Name()
	local ut = self.ai.armyhst.unitTable[self.name]
	self.level = ut.techLevel - 1
	if self.level == 0 then self.level = 0.5 elseif self.level < 0 then self.level = 0.25 end
	self.size = math.max(ut.xsize, ut.zsize) * 8
	self.congSize = self.size * 1.5 -- how much self.ai.tool:distance between it and other attackers when congregating
	self.range = math.max(ut.groundRange, ut.airRange, ut.submergedRange)
	self.weaponDistance = self.range * 0.9
	self.sightDistance = ut.losRadius --* 0.9
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
	--self.ai.attackhst:NeedMore(self)
	self.ai.attackhst:RemoveRecruit(self)
	self.ai.attackhst:RemoveMember(self)
end

function AttackerBST:OwnerIdle()
	self.idle = true
	self.timeout = nil
	if self.active then
		self.ai.attackhst:MemberIdle(self)
	end
end

function AttackerBST:OwnerMoveFailed()
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
	self.movestateSet = false
	if self.target then
		self.needToMoveToTarget = true
	end
end

function AttackerBST:Deactivate()
	self.active = false
end

function AttackerBST:Update()
	 --self.uFrame = self.uFrame or 0
	local f = self.game:Frame()
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'AttackerBST' then return end
	--if f - self.uFrame < self.ai.behUp['attackerbst']  then
	--	return
	--end
	--self.uFrame = f
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
	if self.timeout then
		if f >= self.timeout	then
			self.game:SendToConsole("timeout triggered")
			self.timeout = nil
			-- self.ai.attackhst:RemoveMember(self)
			self.ai.attackhst:AddRecruit(self)
		end
	end
	if self.active and not self.movestateSet then
		self:SetMoveState()
	end
	if self.active and self.needToMoveToTarget then
		self.needToMoveToTarget = false
		--self.unit:Internal():Move(self.target)
		self.unit:Internal():AttackMove(self.target) --need to check this

	end
end

function AttackerBST:Advance(pos, perpendicularAttackAngle, reverseAttackAngle)
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
		self.target = self.ai.tool:RandomAway( pos, self.formationDist, nil, perpendicularAttackAngle)
	end
	local canMoveThere = self.ai.maphst:UnitCanGoHere(self.unit:Internal(), self.target)

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
		-- local framesToArrive = 30 * (self.ai.tool:Distance(self.unit:Internal():GetPosition(), self.target) / self.speed) * 2
		-- game:SendToConsole("frames to arrive", framesToArrive)
		-- self.timeout = self.game:Frame() + framesToArrive
		self.unit:Internal():AttackMove(self.target) --need to check this
		--self.unit:Internal():Move(self.target)
	end
	return canMoveThere
end

function AttackerBST:Free()
	self.attacking = false
	self.target = nil
	self.idle = nil
	self.timeout = nil
	if self.squad and self.squad.disbanding then
		self.squad = nil
	else
		self.ai.attackhst:RemoveMember(self)
	end
	-- self.squad = nil
	self.unit:ElectBehaviour()
end

-- this will issue the correct move state to all units
function AttackerBST:SetMoveState()
	self.movestateSet = true
	local thisUnit = self.unit
	if thisUnit then
		local unitName = self.name
		if self.ai.armyhst.battles[unitName] then
			thisUnit:Internal():HoldPosition()
		elseif self.ai.armyhst.breaks[unitName] then
			thisUnit:Internal():HoldPosition()
		else
			thisUnit:Internal():HoldPosition()
		end

	end
end
