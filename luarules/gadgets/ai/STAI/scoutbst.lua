ScoutBST = class(Behaviour)

function ScoutBST:Name()
	return "ScoutBST"
end

ScoutBST.DebugEnabled = true

function ScoutBST:Init()
	self.evading = false
	self.active = false
	local mtype, network = self.ai.maphst:MobilityOfUnit(self.unit:Internal())
	self.mtype = mtype
	self.name = self.unit:Internal():Name()
	self.armed = self.ai.armyhst.unitTable[self.name].isWeapon
	self.keepYourDistance = self.ai.armyhst.unitTable[self.name].losRadius * 0.5
	if mtype == "air" then
		self.airDistance = self.ai.armyhst.unitTable[self.name].losRadius * 1.5
		self.lastCircleFrame = self.game:Frame()
	end
	self.lastUpdateFrame = self.game:Frame()
end

function ScoutBST:Priority()
	return 50
end

function ScoutBST:Activate()
	self:EchoDebug("activated on " .. self.name)
	self.active = true
end

function ScoutBST:Deactivate()
	self:EchoDebug("deactivated on " .. self.name)
	self.active = false
	self.target = nil
	self.evading = false
	self.attacking = false
	-- self.unit:Internal():EraseHighlight({0,0,1}, 'scout', 2)
end

function ScoutBST:Update()
	if self.active then
		local f = self.game:Frame()
		if f > self.lastUpdateFrame + 30 then
			local unit = self.unit:Internal()
			-- reset target if it's in sight
			if self.target ~= nil then
				if self.ai.loshst:viewPos(self.target) == 1 then--TEST
					self.target = nil
				end
-- 				local los = self.ai.scouthst:ScoutLos(self, self.target)  --TEST
-- 				self:EchoDebug("target los: " .. los)
-- 				if los == 2 or los == 3 then
-- 					self.target = nil
-- 				end
			end
			-- attack small targets along the way if the scout is armed
			local attackTarget
			if self.armed then
				-- game:SendToConsole(unit:GetPosition(), unit)
				if self.ai.targethst:IsSafePosition(unit:GetPosition(), unit, 1) then
					attackTarget = self.ai.targethst:NearbyVulnerable(unit)
				end
			end
			if attackTarget and not self.attacking then
				self.ai.tool:CustomCommand(unit, CMD_ATTACK, {attackTarget.unitID})
				self.target = nil
				self.evading = false
				self.attacking = true
			elseif self.target ~= nil then
				-- evade enemies along the way if possible
				local newPos, arrived = self.ai.targethst:BestAdjacentPosition(unit, self.target)
				if newPos then
					unit:Move(newPos)
					self.evading = true
					self.attacking = false
				elseif arrived then
					-- if we're at the target, find a new target
					self.target = nil
					self.evading = false
				elseif self.evading then
					-- return to course to target after evading
					unit:Move(self.target)
					self.evading = false
					self.attacking = false
				end
			end
			-- find new scout spot if none and not attacking
			if self.target == nil and attackTarget == nil then
				local topos = self.ai.scouthst:ClosestSpot(self) -- first look for closest metal/geo spot that hasn't been seen recently
				if topos ~= nil then
					self:EchoDebug("scouting spot at " .. topos.x .. "," .. topos.z)
					self.target = self.ai.tool:RandomAway( topos, self.keepYourDistance) -- don't move directly onto the spot
					unit:Move(self.target)
					self.attacking = false
				else
					self:EchoDebug("nothing to scout!")
				end
			end
			self.lastUpdateFrame = f
		end
	end

	-- keep air units circling
	if self.mtype == "air" and self.active then
		local f = self.game:Frame()
		if f > self.lastCircleFrame + 60 then
			local unit = self.unit:Internal()
			local upos = unit:GetPosition()
			if self.target then
				local dist = self.ai.tool:Distance(upos, self.target)
				if dist < self.airDistance then
					unit:Move(self.ai.tool:RandomAway( self.target, 100))
				end
			else
				unit:Move(self.ai.tool:RandomAway( upos, 500))
			end
			self.lastCircleFrame = f
		end
	end
end
