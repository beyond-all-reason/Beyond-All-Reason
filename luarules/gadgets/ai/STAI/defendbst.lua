DefendBST = class(Behaviour)

function DefendBST:Name()
	return "DefendBST"
end

function DefendBST:Init()
	self.DebugEnabled = false
	self.moving = {}
	self.unmoved = 0
	self.lastPos = self.unit:Internal():GetPosition()
	self.active = false
	self.id = self.unit:Internal():ID()
	self.name = self.unit:Internal():Name()
	local ut = self.ai.armyhst.unitTable[self.name]
	self.tough = self.ai.armyhst.battles[self.name] or self.ai.armyhst.breaks[self.name]
-- 	self.isDefender = self.ai.armyhst.defenderList[self.name]
	self.mtype = self.ai.armyhst.unitTable[self.name].mtype
	-- defenders need to be sorted into only one type of weapon
	if ut.groundRange > 0 then
		self.hits = "ground"
	elseif ut.submergedRange > 0 then
		self.hits = "submerged"
	elseif ut.airRange > 0 then
		self.hits = "air"
	end
	for i, name in pairs(self.ai.armyhst.raiders) do
		if name == self.name then
			self:EchoDebug(self.name .. " is scramble")
			self.scramble = true
			if self.mtype ~= "air" then
				self.ai.defendhst:AddScramble(self)
			end
			break
		end
	end
	-- keeping track of how many of each type of unit
	self:EchoDebug("added to unit "..self.name)
end

function DefendBST:OwnerDead()
	-- game:SendToConsole("defender " .. self.name .. " died")
	if self.scramble then
		self.ai.defendhst:RemoveScramble(self)
		if self.scrambled then
			self.ai.defendhst:RemoveDefender(self)
		end
	else
		self:EchoDebug('dfdfd',self.name)
		self.ai.defendhst:RemoveDefender(self)
	end
end

function DefendBST:OwnerIdle()
	self.unit:ElectBehaviour()
end

function DefendBST:Update()
	 --self.uFrame = self.uFrame or 0
	local f = self.game:Frame()
	--if f - self.uFrame < self.ai.behUp['mexupbst'] then
	--	return
	--end
	--self.uFrame = f
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'DefendBST' then return end
	if self.unit == nil then return end
	local unit = self.unit:Internal()
	if not unit:GetPosition() then
		-- game:SendToConsole(self.ai.id, "undead defend behaviour", unit:ID(), unit:Name())
		self:UnitDead(self.unit)
	end
	if unit == nil then return end
	if self.active then

-- 		if f % 60 == 0 then
			if self.target == nil then return end
			local targetPos = self.target.position or self.ai.tool:BehaviourPosition(self.target.behaviour)
			if targetPos == nil then return end
			targetPos.y = 0
			local guardDistance = self.target.guardDistance
			if not self.tough then guardDistance = guardDistance * 0.33 end
			local guardPos = self.ai.tool:RandomAway( targetPos, guardDistance, false, self.guardAngle)
			local safe = self.ai.defendhst:WardSafe(self.target)
			-- if targetPos.y > 100 then game:SendToConsole(targetPos.y .. " " .. type(self.target.behaviour)) end
			local unitPos = unit:GetPosition()
			local dist = self.ai.tool:Distance(unitPos, guardPos)
			local behaviour = self.target.behaviour
			if self.perpendicular then
				guardPos = self.ai.tool:RandomAway( guardPos, self.perpDist, false, self.perpendicular)
			end
			if behaviour ~= nil then
				if dist > 500 then
					if self.guarding ~= behaviour.id then
						self.unit:Internal():Guard(behaviour.id)
						self.guarding = behaviour.id
					end
				elseif not safe then
					if dist > 250 then
						unit:Move(guardPos)
						self.guarding = nil
					end
				elseif dist > 25 then
					unit:Move(guardPos)
					self.guarding = nil
				end
				self.moving = {}
			else
				self.guarding = nil
				local boredNow = self.ai.targethst:IsSafePosition(unitPos, unit)
				if self.moving.x ~= targetPos.x or self.moving.z ~= targetPos.z or (self.unmoved > 5 and boredNow) or (not self.tough and dist > self.target.guardDistance) then
					unit:Move(guardPos)
					self.moving.x = targetPos.x
					self.moving.z = targetPos.z
				end
			end
			if self.lastPos.x == unitPos.x and self.lastPos.z == unitPos.z then
				self.unmoved = self.unmoved + 1
			else
				self.unmoved = 0
			end
			self.lastPos = api.Position()
			self.lastPos.x, self.lastPos.z = unitPos.x+0, unitPos.z+0
			self.unit:ElectBehaviour()

	end
end

function DefendBST:Assign(ward, angle, dist)
	if ward == nil then
		self.target = nil
	else
		self.target = ward
		self.guardAngle = angle or math.random() * twicePi
		if dist then
			self.perpendicular = self.ai.tool:AngleAdd(angle, halfPi)
			self.perpDist = dist
		else
			self.perpendicular = nil
			self.perpDist = nil
		end
	end
end

function DefendBST:Scramble()
	self:EchoDebug(self.name .. " scrambled")
	self.scrambled = true
	self.unit:ElectBehaviour()
end

function DefendBST:Unscramble()
	self:EchoDebug(self.name .. " unscrambled")
	self.scrambled = false
	self.unit:ElectBehaviour()
end

function DefendBST:Activate()
	self:EchoDebug("active on "..self.name)
	self.active = true
	self.target = nil
	self.targetPos = nil
	self.guarding = nil
	self.ai.defendhst:AddDefender(self)
	self:SetMoveState()
end

function DefendBST:Deactivate()
	self:EchoDebug("inactive on "..self.name)
	self.active = false
	self.target = nil
	self.targetPos = nil
	self.guarding = nil
	self.ai.defendhst:RemoveDefender(self)
end

function DefendBST:Priority()
	if self.scramble then
		if self.scrambled then
			return 110
		else
			return 0
		end
	else
		return 51
	end
end

-- set all defenders to roam
function DefendBST:SetMoveState()
	local thisUnit = self.unit
	if thisUnit then
		thisUnit:Internal():Roam()
	end
end
