CleanerBST = class(Behaviour)

function CleanerBST:Name()
	return "CleanerBST"
end

function CleanerBST:Init()
	self.DebugEnabled = false
	self.name = self.unit:Internal():Name()
	self.id = self.unit:Internal():ID()
	self.position = self.unit:Internal():GetPosition()
	self.patrolCommand = {self.position.x,self.position.y,self.position.z,0}
	self:EchoDebug("init")
	self.cleaningRadius = 390
	self.frameCounter = 0
	self.ai.tool:GiveOrder(self.id,CMD.MOVE_STATE,2,0,'1-1')
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
	self:EchoDebug('nano idle:',self.id)
	self:reset()
	if  self.unit:Internal():CurrentCommand() ~= CMD.PATROL then
		self:Patroling()
	end
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
	self:EchoDebug("clean:",targetId)
	if  self.unit:Internal():CurrentCommand() ~= CMD.RECLAIM then
		self.ai.tool:GiveOrder(self.unit:Internal():ID(),CMD.RECLAIM,targetId,0,'1-1')
	end
end

function CleanerBST:reset()
	if self.ai.cleanhst.theCleaner[self.id] then
		self.ai.cleanhst.dirt[self.ai.cleanhst.theCleaner[self.id]] = nil
	end
	self.ai.cleanhst.theCleaner[self.id] = nil
	
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
	for id in pairs(self.ai.cleanhst.cleanableByID) do
		local target = game:GetUnitByID(id)
		local tgx,tgy,tgz = target:GetRawPos()
		if not tgx then return end
		local distance = self.ai.tool:RawDistance(self.position.x,self.position.y,self.position.z,tgx,tgy,tgz)
		if  not self.ai.cleanhst.dirt[id] and distance < self.cleaningRadius then
			self.ai.cleanhst.theCleaner[self.id] = id
			self.ai.cleanhst.dirt[id] = self.id
			return id
		end
	end
	if not self:ecoCondition() then return end
	
	local unitsNear = self.game:getUnitsInCylinder(self.position, self.cleaningRadius)
	if not unitsNear  then return false end
	for idx, tg in pairs(unitsNear) do
		self:EchoDebug('cleanable',tg)
		local target = self.game:GetUnitByID(tg)
		local tgx,tgy,tgz = target:GetRawPos()
		local distance = self.ai.tool:RawDistance(self.position.x,self.position.y,self.position.z,tgx,tgy,tgz)
		local unitName = target:Name()
		local targetID = target:ID()
		if self.ai.armyhst.cleanable[unitName] and not self.ai.cleanhst.dirt[targetID] and distance < self.cleaningRadius then
			self:EchoDebug('name',unitName)
			self.ai.cleanhst.theCleaner[self.id] = targetID
			self.ai.cleanhst.dirt[targetID] = self.id
			return targetID
		end
	end
end

function CleanerBST:Patroling()
	local currentCommand = self.unit:Internal():CurrentCommand()
	if currentCommand ~= CMD.PATROL then
		self.ai.tool:GiveOrder(self.id,CMD.PATROL,self.patrolCommand,0,'1-1')
	end
end