LabRegisterBST = class(Behaviour)

function LabRegisterBST:Name()
	return "LabRegisterBST"
end

LabRegisterBST.DebugEnabled = false


function LabRegisterBST:Init()
    self.name = self.unit:Internal():Name()
    self.id = self.unit:Internal():ID()
    self.position = self.unit:Internal():GetPosition() -- factories don't move
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
	self:EchoDebug('ownerbuilt')
	-- don't add factories to factory location table until they're done
	self.finished = true
	self:Register()
	self.ai.overviewhst:EvaluateSituation()
	self.ai.labbuildhst:UpdateFactories()
end

function LabRegisterBST:Priority()
	return 0
end

function LabRegisterBST:OwnerDead()
	if self.ai.factoryUnderConstruction == self.id then self.ai.factoryUnderConstruction = false end
	-- game:SendToConsole("factory " .. self.name .. " died")
	if self.finished then
		self:Unregister()
		self.ai.overviewhst:EvaluateSituation()
		self.ai.labbuildhst:UpdateFactories()
	end
end

function LabRegisterBST:Unregister()

	local un = self.name
    local level = self.level
   	self:EchoDebug("factory " .. un .. " level " .. level .. " unregistering")
   	for i, factory in pairs(self.ai.factoriesAtLevel[level]) do
   		if factory == self then
   			table.remove(self.ai.factoriesAtLevel[level], i)
   			break
   		end
   	end
    local maxLevel = 0
    -- reassess maxFactoryLevel
    for level, factories in pairs(self.ai.factoriesAtLevel) do
    	if #factories > 0 and level > maxLevel then
    		maxLevel = level
    	end
    end
    self.ai.maxFactoryLevel = maxLevel
	-- game:SendToConsole(self.ai.tool:countMyUnit({'factoryMobilities'}) .. " factories")

	if self.ai.factoryUnderConstruction == self.id then self.ai.factoryUnderConstruction = false end
	local mtype = self.ai.armyhst.factoryMobilities[self.name][1]
	local network = self.ai.maphst:MobilityNetworkHere(mtype,self.position)
	-- self:EchoDebug(mtype, network, self.ai.factoryBuilded[mtype], self.ai.factoryBuilded[mtype][network], self.name, self.ai.armyhst.unitTable[self.name], self.ai.armyhst.unitTable[self.name].techLevel)
	if self.ai.factoryBuilded[mtype] and self.ai.factoryBuilded[mtype][network] then
		self.ai.factoryBuilded[mtype][network] = self.ai.factoryBuilded[mtype][network] - self.level
	end
	self:EchoDebug('factory '  ,self.name, ' network '  ,mtype , '-' , network , ' level ' ,self.ai.factoryBuilded[mtype][network] , ' subtract tech ', self.level)
end

function LabRegisterBST:Register()
	-- register maximum factory level
    local un = self.name
    local level = self.level
    self:EchoDebug("factory " .. un .. " level " .. level .. " registering")
	if self.ai.factoriesAtLevel[level] == nil then
		self.ai.factoriesAtLevel[level] = {}
	end
	table.insert(self.ai.factoriesAtLevel[level], self)
	if level > self.ai.maxFactoryLevel then
		-- so that it will start producing combat units
-- 		self.ai.attackhst:NeedLess(nil, 2)
		self.ai.bomberhst:NeedLess()
-- 		self.ai.bomberhst:NeedLess() --TODO check why 2 time?
-- 		self.ai.raidhst:NeedMore(nil, 2)
		-- set the current maximum factory level
		self.ai.maxFactoryLevel = level
	end
	-- game:SendToConsole(self.ai.tool:countMyUnit({'factoryMobilities'}) .. " factories")

	if self.ai.factoryUnderConstruction == self.id then self.ai.factoryUnderConstruction = false end
	local mtype = self.ai.armyhst.factoryMobilities[self.name][1]
	local network = self.ai.maphst:MobilityNetworkHere(mtype,self.position) or 0
	self.ai.factoryBuilded[mtype][network] = (self.ai.factoryBuilded[mtype][network] or 0) + self.level
	self:EchoDebug('factory '  ..self.name.. ' network '  .. mtype .. '-' .. network .. ' level ' .. self.ai.factoryBuilded[mtype][network] .. ' adding tech '.. self.level)
end
