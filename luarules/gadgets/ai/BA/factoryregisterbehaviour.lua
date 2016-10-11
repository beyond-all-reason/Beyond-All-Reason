FactoryRegisterBehaviour = class(Behaviour)

local DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("FactoryRegisterBehaviour: " .. inStr)
	end
end

function FactoryRegisterBehaviour:Init()
    self.name = self.unit:Internal():Name()
    self.id = self.unit:Internal():ID()
    self.position = self.unit:Internal():GetPosition() -- factories don't move
    self.exitRect = {
    	x1 = self.position.x - 40,
    	z1 = self.position.z - 40,
    	x2 = self.position.x + 40,
    	z2 = self.position.z + 40,
	}
	self.sides = factoryExitSides[self.name]
    self.level = unitTable[self.name].techLevel

    self.ai.factoryUnderConstruction = self.id
	EchoDebug('starting building of ' ..self.name)
end

function FactoryRegisterBehaviour:OwnerBuilt()
	-- don't add factories to factory location table until they're done
	self.finished = true
	self:Register()
	self.ai.overviewhandler:EvaluateSituation()
	self.ai.factorybuildershandler:UpdateFactories()
end

function FactoryRegisterBehaviour:Priority()
	return 0
end

function FactoryRegisterBehaviour:OwnerDead()
	if self.ai.factoryUnderConstruction == self.id then self.ai.factoryUnderConstruction = false end
	-- game:SendToConsole("factory " .. self.name .. " died")
	if self.finished then
		self:Unregister()
		self.ai.overviewhandler:EvaluateSituation()
		ai.factorybuildershandler:UpdateFactories()
	end
end

function FactoryRegisterBehaviour:Unregister()
	self.ai.factories = self.ai.factories - 1
	local un = self.name
    local level = self.level
   	EchoDebug("factory " .. un .. " level " .. level .. " unregistering")
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
	-- game:SendToConsole(self.ai.factories .. " factories")
	
	if self.ai.factoryUnderConstruction == self.id then self.ai.factoryUnderConstruction = false end
	local mtype = factoryMobilities[self.name][1]
	local network = self.ai.maphandler:MobilityNetworkHere(mtype,self.position)
	-- EchoDebug(mtype, network, self.ai.factoryBuilded[mtype], self.ai.factoryBuilded[mtype][network], self.name, unitTable[self.name], unitTable[self.name].techLevel)
	if self.ai.factoryBuilded[mtype] and self.ai.factoryBuilded[mtype][network] then
		self.ai.factoryBuilded[mtype][network] = self.ai.factoryBuilded[mtype][network] - self.level
	end
	EchoDebug('factory '  ..self.name.. ' network '  .. mtype .. '-' .. network .. ' level ' .. self.ai.factoryBuilded[mtype][network] .. ' subtract tech '.. self.level)
end

function FactoryRegisterBehaviour:Register()
	if self.ai.factories ~= nil then
		self.ai.factories = self.ai.factories + 1
	else
		self.ai.factories = 1
	end
	-- register maximum factory level
    local un = self.name
    local level = self.level
    EchoDebug("factory " .. un .. " level " .. level .. " registering")
	if self.ai.factoriesAtLevel[level] == nil then
		self.ai.factoriesAtLevel[level] = {}
	end
	table.insert(self.ai.factoriesAtLevel[level], self)
	if level > self.ai.maxFactoryLevel then
		-- so that it will start producing combat units
		self.ai.attackhandler:NeedLess(nil, 2)
		self.ai.bomberhandler:NeedLess()
		self.ai.bomberhandler:NeedLess()
		self.ai.raidhandler:NeedMore(nil, 2)
		-- set the current maximum factory level
		self.ai.maxFactoryLevel = level
	end
	-- game:SendToConsole(self.ai.factories .. " factories")
	
	if self.ai.factoryUnderConstruction == self.id then self.ai.factoryUnderConstruction = false end
	local mtype = factoryMobilities[self.name][1]
	local network = self.ai.maphandler:MobilityNetworkHere(mtype,self.position) or 0
	self.ai.factoryBuilded[mtype][network] = (self.ai.factoryBuilded[mtype][network] or 0) + self.level
	EchoDebug('factory '  ..self.name.. ' network '  .. mtype .. '-' .. network .. ' level ' .. self.ai.factoryBuilded[mtype][network] .. ' adding tech '.. self.level)
end
