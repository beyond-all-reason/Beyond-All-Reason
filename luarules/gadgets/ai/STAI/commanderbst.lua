CommanderBST = class(Behaviour)

function CommanderBST:Name()
	return "CommanderBST"
end

function CommanderBST:Init()
	self.DebugEnabled = false
	local u = self.unit:Internal()
	self.id = u:ID()
	self.save = false
	self.position = self.unit:Internal():GetPosition()
	self.ai.loshst.CENTER = self.position
	self.ai.maphst:UnitMexMoveTest(self)
	self:EchoDebug("init")
end

function CommanderBST:Update()
	local f = self.game:Frame()
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'CommanderBST' then return end
	if self.ai.labshst.T2LAB then
		self.save = 1
	elseif self.unit:Internal():GetHealth() <= self.unit:Internal():GetMaxHealth() * 0.99 then
		self.save = 2
	elseif self.ai.maphst:getCellsFields(self.unit:Internal():GetPosition(),{'ARMED'},2,self.ai.loshst.ENEMY) > 500 then
		self.save = 2
	elseif self.unit:Internal():GetHealth() > self.unit:Internal():GetMaxHealth() * 0.99 then
		self.save = false
	end
	if self.active and self.save == 1 then
		if self.safeBuilder and game:GetUnitByID(self.safeBuilder) and game:GetUnitByID(self.safeBuilder):GetPosition() then
			return
		end
		self.safeBuilder = self.ai.buildingshst:NearestBuilderRole(self.unit:Internal(), 'eco')
		if self.safeBuilder then
			self.ai.tool:GiveOrder(self.id,CMD.GUARD,self.safeBuilder,0,'1-1')
		else
			self.safeHouse = self.ai.labshst:ClosestHighestLevelFactory(self.unit:Internal())
			if self.safeHouse then
				self:HelpFactory()
			end
		end
	end
	if self.active and self.save == 2 then
		if self.safeHouse and game:GetUnitByID(self.safeHouse.id) and game:GetUnitByID(self.safeHouse.id):GetPosition() then
			return
		end
		self.safeHouse = self.ai.labshst:ClosestHighestLevelFactory(self.unit:Internal())
		if self.safeHouse then
			self:HelpFactory()
		end
		--[[if self.safeBuilder and game:GetUnitByID(self.safeBuilder) and game:GetUnitByID(self.safeBuilder):GetPosition() then
			return
		end
		self.safeBuilder = self.ai.buildingshst:NearestBuilderRole(self.unit:Internal(), 'eco')
		if self.safeBuilder then
			self.ai.tool:GiveOrder(self.id,CMD.GUARD,self.safeBuilder,0,'1-1')
		end]]
		self.unit:ElectBehaviour()
	end
end

function CommanderBST:OwnerIdle()
	self.unit:ElectBehaviour()
end

function CommanderBST:OwnerDamaged(attacker,damage)
	if self.unit:Internal():GetHealth() < self.unit:Internal():GetMaxHealth() * 0.75 then
		self.save = true
	end
end

function CommanderBST:Activate()
	self.active = true

	if self.safeBuilder then
		self.ai.tool:GiveOrder(self.id,CMD.GUARD,self.safeBuilder,0,'1-1')
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
	--local _, queueL = Spring.GetRealBuildQueue(self.id)
	--self:EchoDebug('Spring.GetRealBuildQueue(self.id)',Spring.GetRealBuildQueue(self.id),'queueL',queueL)
	if self.save then
		return 200
	else
		return 0
	end
end


function CommanderBST:HelpFactory()
	self.ai.tool:GiveOrder(self.id,CMD.GUARD, self.safeHouse.id, 0,'1-1')
	--[[
	local angle = math.random() * twicePi
	--self.unit:Internal():Move(self.ai.tool:RandomAway( self.safeHouse.position, 200, nil, angle))
	self.ai.tool:GiveOrder(self.id,CMD.MOVE, self.ai.tool:RandomAway( self.safeHouse.position, 200, nil, angle), 0,'1-1')
	for i = 1, 3 do
		local a = self.ai.tool:AngleAdd(angle, halfPi*i)
		local pos = self.ai.tool:RandomAway( self.safeHouse.position, 200, nil, a)
		if math.random() > 0.5 then --TODO workaround, wait to rework it better
			self.ai.tool:GiveOrder(self.id,CMD.PATROL, pos, 0,'1-1')
			--self.unit:Internal():Patrol({pos.x,pos.y,pos.z,0})
		else
			
			--self.unit:Internal():Guard(game:GetUnitByID(self.safeHouse.id))
		end
	end]]
end
