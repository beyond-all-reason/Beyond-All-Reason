CleanerBST = class(Behaviour)

function CleanerBST:Name()
	return "CleanerBST"
end

function CleanerBST:Init()
	self.DebugEnabled = false
	self.name = self.unit:Internal():Name()
	self.id = self.unit:Internal():ID()
	self.position = self.unit:Internal():GetPosition()
	self:EchoDebug("init")
	self.cleaningRadius = 390
	self.frameCounter = 0
end

function CleanerBST:Update()
	local f = self.game:Frame()
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'CleanerBST' then return end
	if not self.ai.cleanhst.theCleaner[self.id]   then
		self:EchoDebug(self.id,'do update')
		self:Search()
	else
		self:EchoDebug('cleanthis', self.ai.cleanhst.theCleaner[self.id])
		self:Clean(self.ai.cleanhst.theCleaner[self.id])
	end
end

function CleanerBST:OwnerBuilt()
	self:Patroling()
end

function CleanerBST:OwnerIdle()
	self:EchoDebug("idle",self.id)
	self:Patroling()
end

function CleanerBST:Activate()
	self:EchoDebug('activate command',self.ai.cleanhst.theCleaner[self.id])

end
function CleanerBST:Deactivate()
	self:EchoDebug('deactivate command',self.ai.cleanhst.theCleaner[self.id])
end

function CleanerBST:Priority()
end

function CleanerBST:Clean(targetId)
	self:EchoDebug("clean this",targetId)
	local currentOrder = self.unit:Internal():GetUnitCommands(1)[1]
	if not currentOrder or not  currentOrder.id or currentOrder.id ~= 90 then
		local target = self.game:GetUnitByID(targetId)

		local exec = self.unit:Internal():Reclaim(target)
		self:EchoDebug('exec',exec,'target',targetId)
	end
end

function CleanerBST:reset()
	self.ai.cleanhst.theCleaner = nil
	self.ai.cleanhst.dirt = nil
end

function CleanerBST:ecoCondition()
	if self.ai.ecohst.Metal.full < 0.5  or (self.ai.ecohst.Energy.income > 5000 and self.ai.ecohst.Metal.full < 0.75) then
		local team = self.game:GetTeamID()
		local counter = 0
		for name,v in pairs(self.ai.armyhst._fus_) do
			local id = self.ai.armyhst.unitTable[name].defId
			counter = counter + self.game:GetTeamUnitDefCount(team,id)
		end
		self:EchoDebug('counter',counter)
		if counter > 2 then
			return true
		end
	end
end

function CleanerBST:Search()
	self:EchoDebug(self.id,'search fo cleanables')
	if not self:ecoCondition() then return end
	local unitsNear = self.game:getUnitsInCylinder(self.position, self.cleaningRadius)
	if not unitsNear  then return false end
	for idx, tg in pairs(unitsNear) do
		self:EchoDebug('target',tg)
		local target = self.game:GetUnitByID(tg)
		local unitName = target:Name()
		local targetID = target:ID()
		if self.ai.armyhst.cleanable[unitName] and not self.ai.cleanhst.dirt[targetID] then
			self:EchoDebug('name',unitName)
			self.ai.cleanhst.theCleaner[self.id] = targetID
			self.ai.cleanhst.dirt[targetID] = self.id
			return targetID
		end
	end
end

function CleanerBST:Patroling()
-- 	local uPosX,uPosY,uPosZ = self.unit:Internal():GetRawPos()
	local currentOrder = self.unit:Internal():GetUnitCommands(1)[1]

	if not currentOrder or not  currentOrder.id  then
		self.unit:Internal():Patrol({self.position.x,self.position.y,self.position.z,0})
	end
end
