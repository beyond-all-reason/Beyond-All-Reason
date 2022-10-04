CommanderBST = class(Behaviour)

function CommanderBST:Name()
	return "CommanderBST"
end

function CommanderBST:Init()
	self.DebugEnabled = true
	local u = self.unit:Internal()
	self.id = u:ID()

	self:EchoDebug("init")
end

function CommanderBST:Update()
	local f = self.game:Frame()
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'CommanderBST' then return end
	if self.lowHealth and f >= self.nextHealthCheck then
		if self.unit:Internal():GetHealth() >= self.unit:Internal():GetMaxHealth() * 0.95 then
			self.lowHealth = false

		end
	end
	self.unit:ElectBehaviour()
end

function CommanderBST:OwnerIdle()
	self.unit:ElectBehaviour()
end

function CommanderBST:OwnerDamaged(attacker,damage)
	if not self.lowHealth then
		if self.unit:Internal():GetHealth() < self.unit:Internal():GetMaxHealth() * 0.95 then
			self.lowHealth = true
			self.nextHealthCheck = self.game:Frame() + 900

		end
	end
end

function CommanderBST:Activate()
	self.active = true
	self:GetSafeBuilder()
	self:GetSafeHouse()
	if self.safeBuilder then
		self.unit:Internal():Guard(game:GetUnitByID(self.safeBuilder))
	elseif self.safeHouse then
		self:HelpFactory()
	end
	self:EchoDebug("activated")
end

function CommanderBST:Deactivate()
	self.active = false
	self:EchoDebug("deactivated")
end

function CommanderBST:Priority()

	local _, queueL = Spring.GetRealBuildQueue(self.id)
	self:EchoDebug('Spring.GetRealBuildQueue(self.id)',Spring.GetRealBuildQueue(self.id),'queueL',queueL)
	if self.safeHouse or self.safeBuilder then
		if (self.ai.Metal.income > 22 and self.ai.Energy.full > 0.5 and queueL == 0) or
				self.ai.overviewhst.T2LAB or
				(self.lowHealth or self.ai.overviewhst.paranoidCommander) then
			print(' d dd d dc')
			return 200
		end
	else
		return 0
	end
end


function CommanderBST:HelpFactory()
	local angle = math.random() * twicePi
	self.unit:Internal():Move(self.ai.tool:RandomAway( self.safeHouse.posiosition, 200, nil, angle))
	for i = 1, 3 do
		local a = self.ai.tool:AngleAdd(angle, halfPi*i)
		local pos = self.ai.tool:RandomAway( self.safeHouse.posiosition, 200, nil, a)
		if math.random() > 0.5 then --TODO workaround, wait to rework it better
			self.unit:Internal():Patrol({pos.x,pos.y,pos.z,0})
		else

			self.unit:Internal():Guard(game:GetUnitByID(self.safeHouse.id))
		end
	end
end

function CommanderBST:GetSafeBuilder()
	for id,role in pairs ( self.ai.buildingshst.roles) do
		if role.role == 'eco' then
			self.safeBuilder = id
		end
	end
end

function CommanderBST:GetSafeHouse()
	self.safeHouse = self.ai.buildingshst:ClosestHighestLevelFactory(self.unit:Internal():GetPosition(), 9999)
end
