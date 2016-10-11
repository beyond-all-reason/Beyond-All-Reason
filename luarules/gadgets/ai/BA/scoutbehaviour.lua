local DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("ScoutBehaviour: " .. inStr)
	end
end

function IsScout(unit)
	local unitName = unit:Internal():Name()
	if scoutList[unitName] then
		return true
	else
		return false
	end
end

ScoutBehaviour = class(Behaviour)

function ScoutBehaviour:Name()
	return "ScoutBehaviour"
end

function ScoutBehaviour:Init()
	self.evading = false
	self.active = false
	local mtype, network = ai.maphandler:MobilityOfUnit(self.unit:Internal())
	self.mtype = mtype
	self.name = self.unit:Internal():Name()
	self.armed = unitTable[self.name].isWeapon
	self.keepYourDistance = unitTable[self.name].losRadius * 0.5
	if mtype == "air" then
		self.airDistance = unitTable[self.name].losRadius * 1.5
		self.lastCircleFrame = game:Frame()
	end
	self.lastUpdateFrame = game:Frame()
end

function ScoutBehaviour:Priority()
	return 50
end

function ScoutBehaviour:Activate()
	EchoDebug("activated on " .. self.name)
	self.active = true
end

function ScoutBehaviour:Deactivate()
	EchoDebug("deactivated on " .. self.name)
	self.active = false
	self.target = nil
	self.evading = false
	self.attacking = false
	-- self.unit:Internal():EraseHighlight({0,0,1}, 'scout', 2)
end

function ScoutBehaviour:Update()
	if self.active then
		local f = game:Frame()
		if f > self.lastUpdateFrame + 30 then
			local unit = self.unit:Internal()
			-- reset target if it's in sight
			if self.target ~= nil then
				local los = ai.scouthandler:ScoutLos(self, self.target)
				EchoDebug("target los: " .. los)
				if los == 2 or los == 3 then
					self.target = nil
				end
			end
			-- attack small targets along the way if the scout is armed
			local attackTarget
			if self.armed then
				-- game:SendToConsole(unit:GetPosition(), unit)
				if ai.targethandler:IsSafePosition(unit:GetPosition(), unit, 1) then
					attackTarget = ai.targethandler:NearbyVulnerable(unit)
				end
			end
			if attackTarget and not self.attacking then
				CustomCommand(unit, CMD_ATTACK, {attackTarget.unitID})
				self.target = nil
				self.evading = false
				self.attacking = true
			elseif self.target ~= nil then	
				-- evade enemies along the way if possible
				local newPos, arrived = ai.targethandler:BestAdjacentPosition(unit, self.target)
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
				local topos = ai.scouthandler:ClosestSpot(self) -- first look for closest metal/geo spot that hasn't been seen recently
				if topos ~= nil then
					EchoDebug("scouting spot at " .. topos.x .. "," .. topos.z)
					self.target = RandomAway(topos, self.keepYourDistance) -- don't move directly onto the spot
					unit:Move(self.target)
					self.attacking = false
				else
					EchoDebug("nothing to scout!")
				end
			end
			self.lastUpdateFrame = f
		end
	end
	
	-- keep air units circling
	if self.mtype == "air" and self.active then
		local f = game:Frame()
		if f > self.lastCircleFrame + 60 then
			local unit = self.unit:Internal()
			local upos = unit:GetPosition()
			if self.target then
				local dist = Distance(upos, self.target)
				if dist < self.airDistance then
					unit:Move(RandomAway(self.target, 100))
				end
			else
				unit:Move(RandomAway(upos, 500))
			end
			self.lastCircleFrame = f
		end
	end
end