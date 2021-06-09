CleanerBST = class(Behaviour)

function CleanerBST:Name()
	return "CleanerBST"
end

function CleanerBST:Init()
	self.DebugEnabled = false

	self.name = self.unit:Internal():Name()
	self.id = self.unit:Internal():ID()
	self:EchoDebug("init")
	self.cleaningRadius = 390
	if self.ai.armyhst._nano_[self.name] then
		self.isStationary = true
		self.cleaningRadius = 390
	else
		self.cleaningRadius = 300
	end
	self.ignore = {}
	self.frameCounter = 0
end

function CleanerBST:Update()
	local f = self.game:Frame()
	if f % 123 == 0 then
	local cleanH =self.ai.cleanhst
		if not cleanH.theCleaner[self.id]   then
			self:EchoDebug(self.id,'do update')
			self:Search()
		else
			self:EchoDebug('cleanthis', cleanH.theCleaner[self.id])
			self:Clean(cleanH.theCleaner[self.id])
			self.unit:ElectBehaviour()
		end
		self.frameCounter = 0
	end
end

function CleanerBST:OwnerIdle()
	self:EchoDebug("idle",self.id)
	if not self.ai.cleanhst.theCleaner[self.id] then
		self:Search()
	end
	self.unit:ElectBehaviour()
end

-- function CleanerBST:UnitDead(unit)
-- 	if not unit.engineID then
-- 		self:EchoDebug("nil engineID")
-- 	elseif self.ignore[unit.engineID] then
-- 		self:EchoDebug("dead unit in ignore table")
-- 		self.ignore[unit.engineID] = nil
-- 	elseif self.cleanThis and self.cleanThis.id == unit.engineID then
-- 		self:EchoDebug("what i was dirtg died")
-- 		self.cleanThis = nil
-- 	end
-- end

function CleanerBST:Activate()
	self:EchoDebug('activate command',self.ai.cleanhst.theCleaner[self.id])

end
function CleanerBST:Deactivate()
	self:Patroling()
	self:EchoDebug('deactivate command',self.ai.cleanhst.theCleaner[self.id])
end

function CleanerBST:Priority()
	if self.ai.cleanhst.theCleaner[self.id] then
		return 103
	else
		self:Deactivate()
		return 0
	end
end

function CleanerBST:Clean(targetId)
	self:EchoDebug("clean this",targetId)
	local target = self.game:GetUnitByID(targetId)
	local exec = self.unit:Internal():Reclaim(target)
	self:EchoDebug('exec',exec,'target',targetId)
end

function CleanerBST:reset()
	self.ai.cleanhst.theCleaner = {}
	self.ai.cleanhst.dirt = {}
end

function CleanerBST:ecoCondition()
	if self.ai.Metal.full < 0.5  or self.ai.Energy.income > 5000 then
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
-- 	self:reset()

end

function CleanerBST:Search()
	self:EchoDebug(self.id,'search fo cleanables')
	if not self:ecoCondition() then return end
	local unitsNear = self.game:getUnitsInCylinder(self.unit:Internal():GetPosition(), self.cleaningRadius)
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
			return
		end
	end
end

function CleanerBST:Patroling() --TODO move nano patroling to another place (activate-deactivate behaviour)
	-- set nano turrets to patrol
	local upos = self.ai.tool:RandomAway( self.unit:Internal():GetPosition(), 50)
	local floats = api.vectorFloat()
	-- populate with x, y, z of the position
	floats:push_back(upos.x)
	floats:push_back(upos.y)
	floats:push_back(upos.z)
-- 	self.unit:Internal():ExecuteCustomCommand(CMD_PATROL, floats)
	self.unit:Internal():Patrol(upos)
end
