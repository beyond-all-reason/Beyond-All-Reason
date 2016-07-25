ocal DebugEnabled = false


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
	self.size = ut.xsize * ut.zsize * 16
	self.congSize = self.size * 0.15 -- how much distance between it and other attackers when congregating
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
end

function AttackerBehaviour:Attack(pos, realClose, perpendicularAttackAngle, maxOutFromMid)
	if self.unit == nil then
		-- wtf
	elseif self.unit:Internal() == nil then
		-- wwttff
	else
		if realClose then
			self.target = self:AwayFromTarget(pos, halfPi, maxOutFromMid)
		elseif perpendicularAttackAngle and self.distFromMid then
			self.target = RandomAway(pos, self.distFromMid, nil, perpendicularAttackAngle)
		else
			self.target = RandomAway(pos, 150)
		end
		self.attacking = true
		self.congregating = false
		if self.active then
			self.unit:Internal():Move(self.target)
		end
		self.idle = nil
		self.unit:ElectBehaviour()
	end
end

function AttackerBehaviour:AwayFromTarget(pos, spread, maxOutFromMid)
	local upos = self.unit:Internal():GetPosition()
	local dx = upos.x - pos.x
	local dz = upos.z - pos.z
	local angle = atan2(-dz, dx)
	if spread then
		local halfSpread = spread / 2
		local myAngle
		if self.outFromMid and maxOutFromMid then
			myAngle = (self.outFromMid / maxOutFromMid) * halfSpread
		else
			myAngle = (random() * spread) - halfSpread
		end
		angle = angle + myAngle
	end
	if angle > twicePi then
		angle = angle - twicePi
	elseif angle < 0 then
		angle = angle + twicePi
	end
	local awayDistance = math.min(self.sightDistance, self.weaponDistance)
	if not self.sturdy or self.ai.loshandler:IsInLos(pos) then
		awayDistance = self.weaponDistance
	end
	return RandomAway(pos, awayDistance, false, angle)
end

function AttackerBehaviour:Congregate(pos)
	local ordered = false
	if self.unit == nil then
		return false
	elseif self.unit:Internal() == nil then
		return false
	else
		local unit = self.unit:Internal()
		self.target = pos
		if self.ai.maphandler:UnitCanGoHere(unit, pos) then
			self.attacking = true
			self.congregating = true
			if self.active then
				unit:Move(self.target)
			end
			ordered = true
		end
		self.idle = nil
		self.unit:ElectBehaviour()
	end
	return ordered
end

function AttackerBehaviour:Free()
	self.attacking = false
	self.congregating = false
	self.target = nil
	self.idle = nil
	self.unit:ElectBehaviour()
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
	self:SetMoveState()
	if self.target then
		if self.congregating then
			self.unit:Internal():Move(self.target)
		else
			self.unit:Internal():Move(self.target)
		end
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
end

-- this will issue the correct move state to all units
function AttackerBehaviour:SetMoveState()
	local thisUnit = self.unit
	if thisUnit then
		local unitName = self.name
		if battleList[unitName] then
			local floats = api.vectorFloat()
			floats:push_back(MOVESTATE_ROAM)
			thisUnit:Internal():ExecuteCustomCommand(CMD_MOVE_STATE, floats)
		elseif breakthroughList[unitName] then
			local floats = api.vectorFloat()
			floats:push_back(MOVESTATE_MANEUVER)
			thisUnit:Internal():ExecuteCustomCommand(CMD_MOVE_STATE, floats)
		else
			local floats = api.vectorFloat()
			floats:push_back(MOVESTATE_HOLDPOS)
			thisUnit:Internal():ExecuteCustomCommand(CMD_MOVE_STATE, floats)
		end
	end
end
