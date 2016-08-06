CommanderBehaviour = class(Behaviour)

function CommanderBehaviour:Name()
	return "CommanderBehaviour"
end

local CMD_GUARD = 25
local CMD_PATROL = 15

function CommanderBehaviour:Init()
	self.DebugEnabled = false

	self:EchoDebug("init")
end

function CommanderBehaviour:Update()
	local f = game:Frame()
	if self.lowHealth and f >= self.nextHealthCheck then
		if self.unit:Internal():GetHealth() >= self.unit:Internal():GetMaxHealth() * 0.75 then
			self.lowHealth = false
			self.unit:ElectBehaviour()
		end
	end
	if self.active and f >= self.nextFactoryCheck then
		self:FindSafeHouse()
	end
	if f % 30 == 0 and not self.active and self.ai.overviewhandler.paranoidCommander then
		self:FindSafeHouse()
		self.unit:ElectBehaviour()
	end
end

function CommanderBehaviour:OwnerIdle()
	self.unit:ElectBehaviour()
end

function CommanderBehaviour:OwnerDamaged(attacker,damage)
	if not self.lowHealth then
		if self.unit:Internal():GetHealth() < self.unit:Internal():GetMaxHealth() * 0.75 then
			self.lowHealth = true
			self.nextHealthCheck = self.game:Frame() + 900
			self:FindSafeHouse()
		end
	end
end

function CommanderBehaviour:Activate()
	self.active = true
	if self.factoryToHelp then
		self:HelpFactory()
	elseif self.safeHouse then
		self:MoveToSafety()
	end
	self:EchoDebug("activated")
end

function CommanderBehaviour:Deactivate()
	self.active = false
	self:EchoDebug("deactivated")
end

function CommanderBehaviour:Priority()
	if (self.lowHealth or self.ai.overviewhandler.paranoidCommander) and self.safeHouse then
		return 200
	else
		return 0
	end
end

function CommanderBehaviour:MoveToSafety()
	self.unit:Internal():Move(self.safeHouse)
end

function CommanderBehaviour:HelpFactory()
	local factPos = self.factoryToHelp:GetPosition()
	local angle = math.random() * twicePi
	self.unit:Internal():Move(RandomAway(factPos, 200, nil, angle))
	for i = 1, 3 do
		local a = AngleAdd(angle, halfPi*i)
		local pos = RandomAway(factPos, 200, nil, a)
		local floats = api.vectorFloat()
		floats:push_back(pos.x)
		floats:push_back(pos.y)
		floats:push_back(pos.z)
		self.unit:Internal():ExecuteCustomCommand(CMD_PATROL, floats, {"shift"})
	end
	-- CustomCommand(self.unit:Internal(), CMD_GUARD, {self.factoryToHelp:ID()})
end

function CommanderBehaviour:FindSafeHouse()
	local factoryPos, factoryUnit
	local safePos = self.ai.turtlehandler:MostTurtled(self.unit:Internal(), nil, false, true, true)
	if safePos then
		factoryPos, factoryUnit = self.ai.buildsitehandler:ClosestHighestLevelFactory(safePos, 500)
	end
	if not factoryUnit then
		factoryPos, factoryUnit = self.ai.buildsitehandler:ClosestHighestLevelFactory(self.unit:Internal():GetPosition(), 9999)
	end
	self.safeHouse = safePos or factoryPos
	local helpNew
	if self.active and factoryUnit and factoryUnit ~= self.factoryToHelp then
		helpNew = true
	end
	if self.active and safePos and safePos ~= self.safeHouse then
		safeNew = true
	end
	self.factoryToHelp = factoryUnit
	if helpNew then
		self:HelpFactory()
	elseif not factoryUnit and safeNew then
		self:MoveToSafety()
	end
	self.nextFactoryCheck = self.game:Frame() + 500
	self:EchoDebug(safePos, factoryUnit, factoryPos)
	self.unit:ElectBehaviour()
end