LabRegisterBST = class(Behaviour)

function LabRegisterBST:Name()
	return "LabRegisterBST"
end

function LabRegisterBST:Init()
	self.DebugEnabled = false
    self.name = self.unit:Internal():Name()
    self.id = self.unit:Internal():ID()
    self.position = self.unit:Internal():GetPosition()
    self.exitRect = {
    	x1 = self.position.x - 40,
    	z1 = self.position.z - 40,
    	x2 = self.position.x + 40,
    	z2 = self.position.z + 40,
	}
	self.sides = self.ai.armyhst.factoryExitSides[self.name]
    self.level = self.ai.armyhst.unitTable[self.name].techLevel
    self.ai.factoryUnderConstruction = self.id
	self:EchoDebug('starting building of ' ..self.name)
end

function LabRegisterBST:OwnerBuilt()
	self:EchoDebug('owner built lab register')
	self.finished = true
	self:Register()
	--self.ai.overviewhst:EvaluateSituation()
	self.ai.labbuildhst:UpdateFactories()
end

function LabRegisterBST:Priority()
	return 0
end

function LabRegisterBST:OwnerDead()
	if self.ai.factoryUnderConstruction == self.id then self.ai.factoryUnderConstruction = false end
	if self.finished then
		self:Unregister()
		--self.ai.overviewhst:EvaluateSituation()
		self.ai.labbuildhst:UpdateFactories()
	end
end

function LabRegisterBST:Unregister()
    local level = self.level
   	self:EchoDebug("factory " .. self.name .. " level " .. self.level .. " unregistering")
   	for i, factory in pairs(self.ai.factoriesAtLevel[self.level]) do
   		if factory == self then
   			table.remove(self.ai.factoriesAtLevel[self.level], i)
   			break
   		end
   	end
    local maxLevel = 0
    for level, factories in pairs(self.ai.factoriesAtLevel) do
    	if #factories > 0 and level > maxLevel then
    		maxLevel = level
    	end
    end
    self.ai.maxFactoryLevel = maxLevel
	if self.ai.factoryUnderConstruction == self.id then self.ai.factoryUnderConstruction = false end
	local mtype = self.ai.armyhst.factoryMobilities[self.name][1]
	local network = self.ai.maphst:MobilityNetworkHere(mtype,self.position)
	if self.ai.labbuildhst.factoryBuilded[mtype] and self.ai.labbuildhst.factoryBuilded[mtype][network] then
		self.ai.labbuildhst.factoryBuilded[mtype][network] = self.ai.labbuildhst.factoryBuilded[mtype][network] - self.level
	end
	self:EchoDebug('factory '  ,self.name, ' network '  ,mtype , '-' , network , ' level ' ,self.ai.labbuildhst.factoryBuilded[mtype][network] , ' subtract tech ', self.level)
end

function LabRegisterBST:Register()
    self:EchoDebug("factory " .. self.name .. " level " .. self.level .. " registering")
	self.ai.factoriesAtLevel[self.level] = self.ai.factoriesAtLevel[self.level] or {}

	table.insert(self.ai.factoriesAtLevel[self.level], self)
	if self.level > self.ai.maxFactoryLevel then
		self.ai.maxFactoryLevel = self.level
	end
	self:EchoDebug(self.ai.tool:countMyUnit({'factoryMobilities'}) .. " factories")
	if self.ai.factoryUnderConstruction == self.id then self.ai.factoryUnderConstruction = false end
	local mtype = self.ai.armyhst.factoryMobilities[self.name][1]
	local network = self.ai.maphst:MobilityNetworkHere(mtype,self.position) or 0
	self.ai.labbuildhst.factoryBuilded[mtype][network] = (self.ai.labbuildhst.factoryBuilded[mtype][network] or 0) + self.level
	self:EchoDebug('factory '  ..self.name.. ' network '  .. mtype .. '-' .. network .. ' level ' .. self.ai.labbuildhst.factoryBuilded[mtype][network] .. ' adding tech '.. self.level)
end
