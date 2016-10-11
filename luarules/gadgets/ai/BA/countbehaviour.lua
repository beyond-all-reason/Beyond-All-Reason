CountBehaviour = class(Behaviour)

function CountBehaviour:Name()
	return "CountBehaviour"
end

local DebugEnabled = false

local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("CountBehaviour: " .. inStr)
	end
end

function CountBehaviour:Init()
	self.finished = false
	self.name = self.unit:Internal():Name()
	self.id = self.unit:Internal():ID()
	local uTn = unitTable[self.name]
	-- game:SendToConsole(self.name .. " " .. self.id .. " init")
	if uTn.isBuilding then
		self.position = self.unit:Internal():GetPosition() -- buildings don't move
		self.isBuilding = true
	else
		if uTn.buildOptions then
			self.isCon = true
		elseif uTn.isWeapon then
			self.isCombat = true
			self.mtypedLv = tostring(uTn.mtype)..uTn.techLevel
			self.mobileMtyped = uTn.mtype
		end
	end
	if uTn.totalEnergyOut > 750 then self.isBigEnergy = true end
	if uTn.extractsMetal > 0 then self.isMex = true end
	if battleList[self.name] then self.isBattle = true end
	if breakthroughList[self.name] then self.isBreakthrough = true end
	if self.isCombat and not battleList[self.name] and not breakthroughList[self.name] then
		self.isSiege = true
	end
	if reclaimerList[self.name] then self.isReclaimer = true end
	if cleanable[self.name] then self.isCleanable = true end
	if assistList[self.name] then self.isAssist = true end
	if nanoTurretList[self.name] then self.isNano = true end
	if self.ai.nameCount[self.name] == nil then
		self.ai.nameCount[self.name] = 1
	else
		self.ai.nameCount[self.name] = self.ai.nameCount[self.name] + 1
	end
	EchoDebug(self.ai.nameCount[self.name] .. " " .. self.name .. " created")
	self.ai.lastNameCreated[self.name] = game:Frame()
	self.unit:ElectBehaviour()
end

function CountBehaviour:OwnerBuilt()
	-- game:SendToConsole(self.name .. " " .. self.id .. " built")
	if self.ai.nameCountFinished[self.name] == nil then
		self.ai.nameCountFinished[self.name] = 1
	else
		self.ai.nameCountFinished[self.name] = self.ai.nameCountFinished[self.name] + 1
	end
	if self.isMex then self.ai.mexCount = self.ai.mexCount + 1 end
	if self.isCon then 
		self.ai.conCount = self.ai.conCount + 1 
		self.ai.conList[self.id] = self
	end
	if self.isCombat then self.ai.combatCount = self.ai.combatCount + 1 end
	if self.isBattle then self.ai.battleCount = self.ai.battleCount + 1 end
	if self.isBreakthrough then self.ai.breakthroughCount = self.ai.breakthroughCount + 1 end
	if self.isSiege then self.ai.siegeCount = self.ai.siegeCount + 1 end
	if self.isReclaimer then self.ai.reclaimerCount = self.ai.reclaimerCount + 1 end
	if self.isAssist then self.ai.assistCount = self.ai.assistCount + 1 end
	if self.isBigEnergy then self.ai.bigEnergyCount = self.ai.bigEnergyCount + 1 end
	if self.isCleanable then self.ai.cleanable[self.unit.engineID] = self.position end
	if self.isNano then 
		self.ai.nanoList[self.id] = self.unit:Internal():GetPosition() 
		self.ai.lastNanoBuild = self.unit:Internal():GetPosition()
	end
	self.ai.lastNameFinished[self.name] = game:Frame()
	EchoDebug(self.ai.nameCountFinished[self.name] .. " " .. self.name .. " finished")
	self.finished = true
	--mtyped leveled counters
	if self.mobileMtyped then ai.mtypeCount[self.mobileMtyped] = ai.mtypeCount[self.mobileMtyped] + 1 end
	if self.mtypedLv then
		if self.ai.mtypeLvCount[self.mtypedLv] == nil then 
			self.ai.mtypeLvCount[self.mtypedLv] = 1 
		else
			self.ai.mtypeLvCount[self.mtypedLv] = self.ai.mtypeLvCount[self.mtypedLv] + 1
		end
	end
end

function CountBehaviour:Priority()
	return 0
end

function CountBehaviour:OwnerDead()
	self.ai.nameCount[self.name] = self.ai.nameCount[self.name] - 1
	if self.finished then
		self.ai.nameCountFinished[self.name] = self.ai.nameCountFinished[self.name] - 1
		if self.isMex then self.ai.mexCount = self.ai.mexCount - 1 end
		if self.isCon then
			self.ai.conCount = self.ai.conCount - 1
			self.ai.conList[self.id] = nil
		end
		if self.isCombat then self.ai.combatCount = self.ai.combatCount - 1 end
		if self.isBattle then self.ai.battleCount = self.ai.battleCount - 1 end
		if self.isBreakthrough then self.ai.breakthroughCount = self.ai.breakthroughCount - 1 end
		if self.isSiege then self.ai.siegeCount = self.ai.siegeCount - 1 end
		if self.isReclaimer then self.ai.reclaimerCount = self.ai.reclaimerCount - 1 end
		if self.isAssist then self.ai.assistCount = self.ai.assistCount - 1 end
		if self.isBigEnergy then self.ai.bigEnergyCount = self.ai.bigEnergyCount - 1 end
		if self.isCleanable then self.ai.cleanable[self.unit.engineID] = nil end
		if self.isNano then 
			self.ai.nanoList[self.id] = nil 
			if self.ai.lastNanoBuild == self.unit:Internal():GetPosition() then self.ai.lastNanoBuild = nil end
		end
		if self.mobileMtyped then ai.mtypeCount[self.mobileMtyped] = ai.mtypeCount[self.mobileMtyped] - 1 end
		if self.mtypedLv then
			self.ai.mtypeLvCount[self.mtypedLv] = self.ai.mtypeLvCount[self.mtypedLv] - 1
		end
	end
end