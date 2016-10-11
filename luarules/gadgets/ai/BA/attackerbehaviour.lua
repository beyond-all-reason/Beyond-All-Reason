local DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("AttackerBehaviour: " .. inStr)
	end
end

function IsAttacker(unit)
	return attackerlist[unit:Internal():Name()] or false
end

AttackerBehaviour = class(Behaviour)

function AttackerBehaviour:Name()
	return "AttackerBehaviour"
end

function AttackerBehaviour:Init()
	local mtype, network = self.ai.maphandler:MobilityOfUnit(self.unit:Internal())
	self.mtype = mtype
	self.name = self.unit:Internal():Name()
	local ut = unitTable[self.name]
	self.level = ut.techLevel - 1
	if self.level == 0 then self.level = 0.5 elseif self.level < 0 then self.level = 0.25 end
	self.size = math.max(ut.xsize, ut.zsize) * 8
	self.congSize = self.size * 0.67 -- how much distance between it and other attackers when congregating
	self.range = math.max(ut.groundRange, ut.airRange, ut.submergedRange)
	self.weaponDistance = self.range * 0.9
	self.sightDistance = ut.losRadius * 0.9
	self.sturdy = battleList[self.name] or breakthroughList[self.name]
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

function AttackerBehaviour:OwnerBuilt()
	self.attacking = false
	self.ai.attackhandler:AddRecruit(self)
end

function AttackerBehaviour:OwnerDamaged(attacker,damage)
	self.damaged = game:Frame()
end

function AttackerBehaviour:OwnerDead()
	self.attacking = nil
	self.active = nil
	self.unit = nil
	self.ai.attackhandler:NeedMore(self)
	self.ai.attackhandler:RemoveRecruit(self)
	self.ai.attackhandler:RemoveMember(self)
end

function AttackerBehaviour:OwnerIdle()
	self.idle = true
	self.timeout = nil
	if self.active then
		self.ai.attackhandler:MemberIdle(self)
	end
end

function AttackerBehaviour:OwnerMoveFailed()
	self:OwnerIdle()
end

function AttackerBehaviour:Priority()
	if not self.attacking then
		return 0
	else
		return 100
	end
end

function AttackerBehaviour:Activate()
	self.active = true
	self.movestateSet = false
	if self.target then
		self.needToMoveToTarget = true
	end
end

function AttackerBehaviour:Deactivate()
	self.active = false
end

function AttackerBehaviour:Update()
	if self.damaged then
		local f = game:Frame()
		if f > self.damaged + 450 then
			self.damaged = nil
		end
	end
	if self.timeout then
		if game:Frame() >= self.timeout	then
			game:SendToConsole("timeout triggered")
			self.timeout = nil
			-- self.ai.attackhandler:RemoveMember(self)
			self.ai.attackhandler:AddRecruit(self)
		end
	end
	if self.active and not self.movestateSet then
		self:SetMoveState()
	end
	if self.active and self.needToMoveToTarget then
		self.needToMoveToTarget = false
		self.unit:Internal():Move(self.target)
	end
end

function AttackerBehaviour:Advance(pos, perpendicularAttackAngle, reverseAttackAngle)
	self.idle = false
	self.attacking = true
	if reverseAttackAngle then
		local awayDistance = math.min(self.sightDistance, self.weaponDistance)
		if not self.sturdy or self.ai.loshandler:IsInLos(pos) then
			awayDistance = self.weaponDistance
		end
		local myAngle = AngleAdd(reverseAttackAngle, self.formationAngle)
		self.target = RandomAway(pos, awayDistance, nil, myAngle)
	else
		self.target = RandomAway(pos, self.formationDist, nil, perpendicularAttackAngle)
	end
	local canMoveThere = self.ai.maphandler:UnitCanGoHere(self.unit:Internal(), self.target)
	if canMoveThere then
		self.squad.lastValidMove = self.target
	elseif self.squad.lastValidMove then
		self.target = RandomAway(self.squad.lastValidMove, self.congSize)
		canMoveThere = self.ai.maphandler:UnitCanGoHere(self.unit:Internal(), self.target)
	end
	if self.active and canMoveThere then
		-- local framesToArrive = 30 * (Distance(self.unit:Internal():GetPosition(), self.target) / self.speed) * 2
		-- game:SendToConsole("frames to arrive", framesToArrive)
		-- self.timeout = game:Frame() + framesToArrive
		self.unit:Internal():Move(self.target)
	end
	return canMoveThere
end

function AttackerBehaviour:Free()
	self.attacking = false
	self.target = nil
	self.idle = nil
	self.timeout = nil
	if self.squad and self.squad.disbanding then
		self.squad = nil
	else
		self.ai.attackhandler:RemoveMember(self)
	end
	-- self.squad = nil
	self.unit:ElectBehaviour()
end

-- this will issue the correct move state to all units
function AttackerBehaviour:SetMoveState()
	self.movestateSet = true
	local thisUnit = self.unit
	if thisUnit then
		local unitName = self.name
		local floats = api.vectorFloat()
		if battleList[unitName] then
			-- floats:push_back(MOVESTATE_ROAM)
			floats:push_back(MOVESTATE_MANEUVER)
		elseif breakthroughList[unitName] then
			floats:push_back(MOVESTATE_MANEUVER)
		else
			floats:push_back(MOVESTATE_HOLDPOS)
		end
		thisUnit:Internal():ExecuteCustomCommand(CMD_MOVE_STATE, floats)
	end
end
