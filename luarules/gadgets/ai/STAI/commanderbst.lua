CommanderBST = class(Behaviour)

function CommanderBST:Name()
	return "CommanderBST"
end

function CommanderBST:Init()
	self.DebugEnabled = false
	local u = self.unit:Internal()
	self.id = u:ID()

	self:EchoDebug("init")
end

function CommanderBST:Update()
	 --self.uFrame = self.uFrame or 0
	local f = self.game:Frame()
	--if f - self.uFrame < self.ai.behUp['commanderbst'] then
	--	return
--	end
	--self.uFrame = f
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'CommanderBST' then return end
	if self.lowHealth and f >= self.nextHealthCheck then
		if self.unit:Internal():GetHealth() >= self.unit:Internal():GetMaxHealth() * 0.95 then
			self.lowHealth = false
			self.unit:ElectBehaviour()
		end
	end
	if self.active and self.nextFactoryCheck 	 and f >= self.nextFactoryCheck  then
		self:EchoDebug('f',f,'self.nextFactoryCheck',self.nextFactoryCheck)

		self:FindSafeHouse()
	end
	if not self.active and self.ai.overviewhst.paranoidCommander then
		self:FindSafeHouse()
		self.unit:ElectBehaviour()
	end
end

function CommanderBST:OwnerIdle()
	self.unit:ElectBehaviour()
end

function CommanderBST:OwnerDamaged(attacker,damage)
	if not self.lowHealth then
		if self.unit:Internal():GetHealth() < self.unit:Internal():GetMaxHealth() * 0.95 then
			self.lowHealth = true
			self.nextHealthCheck = self.game:Frame() + 900
			self:FindSafeHouse()
		end
	end
end

function CommanderBST:Activate()
	self.active = true
	if not self.factoryToHelp then
		self:FindSafeHouse()
	end

	if self.factoryToHelp then
-- 		self:HelpFactory()
		self:HelpEconomist()
	elseif self.safeHouse then
		self:MoveToSafety()
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

	if (self.ai.Metal.income > 22 and self.ai.Energy.full > 0.5 and queueL == 0) or
			self.ai.overviewhst.T2LAB or
			((self.lowHealth or self.ai.overviewhst.paranoidCommander) and self.safeHouse) then
		return 200
	else
		return 0
	end
end

function CommanderBST:MoveToSafety()
	self.unit:Internal():Move(self.safeHouse)
end

function CommanderBST:HelpFactory()
	local factPos = self.factoryToHelp:GetPosition()
	local angle = math.random() * twicePi
	self.unit:Internal():Move(self.ai.tool:RandomAway( factPos, 200, nil, angle))
	for i = 1, 3 do
		local a = self.ai.tool:AngleAdd(angle, halfPi*i)
		local pos = self.ai.tool:RandomAway( factPos, 200, nil, a)
		if math.random() > 0.5 then --TODO workaround, wait to rework it better
			self.unit:Internal():Patrol({pos.x,pos.y,pos.z,0})
		else

			self.unit:Internal():Guard(self.factoryToHelp)
		end
	end
end

function CommanderBST:HelpEconomist()
	local economists = self.ai.armyhst.buildersRole.eco
	for i,v in pairs ( economists) do
		for index,unitID in pairs(v) do
			self.unit:Internal():Guard(unitID)
			break
		end
	end

end



function CommanderBST:FindSafeHouse()
	local factoryPos, factoryUnit
	local safePos = self.ai.turtlehst:MostTurtled(self.unit:Internal(), nil, false, true, true)
	if safePos then
		factoryPos, factoryUnit = self.ai.buildsitehst:ClosestHighestLevelFactory(safePos, 500)
	end
	if not factoryUnit then
		factoryPos, factoryUnit = self.ai.buildsitehst:ClosestHighestLevelFactory(self.unit:Internal():GetPosition(), 9999)
	end
	self.safeHouse = safePos or factoryPos
	local helpNew
	if self.active and factoryUnit and factoryUnit ~= self.factoryToHelp then
		helpNew = true
	end
	local safeNew = false
	if self.active and safePos and safePos ~= self.safeHouse then
		safeNew = true
	end
	self.factoryToHelp = factoryUnit
	if helpNew then
-- 		self:HelpFactory()
		self:HelpEconomist()
	elseif not factoryUnit and safeNew then
		self:MoveToSafety()
	end
	self.nextFactoryCheck = self.game:Frame() + 500
	self:EchoDebug(safePos, factoryUnit, factoryPos)
	self.unit:ElectBehaviour()
end
