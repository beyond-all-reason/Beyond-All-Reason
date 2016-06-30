Behaviour = class(Behaviour)

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
		else
			if uTn.buildOptions then
				self.isCon = true
			elseif uTn.isWeapon then
				self.isCombat = true
			end
		end
	self.level = uTn.techLevel
	if not self.isBuilding and not self.isCon then
		self.mtypedLv = tostring(uTn.mtype)..self.level
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
	if self.ai.nameCount[self.name] == nil then
		self.ai.nameCount[self.name] = 1
	else
		self.ai.nameCount[self.name] = self.ai.nameCount[self.name] + 1
	end
	EchoDebug(self.ai.nameCount[self.name] .. " " .. self.name .. " created")
	self.ai.lastNameCreated[self.name] = game:Frame()
	self.unit:ElectBehaviour()
end

function CountBehaviour:UnitCreated(unit)
	if unit.engineID == self.unit.engineID then
		-- game:SendToConsole(self.name .. " " .. self.id .. " created")
	end
end

function CountBehaviour:UnitBuilt(unit)
	if unit.engineID == self.unit.engineID then
		-- game:SendToConsole(self.name .. " " .. self.id .. " built")
		if self.ai.nameCountFinished[self.name] == nil then
			self.ai.nameCountFinished[self.name] = 1
		else
			self.ai.nameCountFinished[self.name] = self.ai.nameCountFinished[self.name] + 1
		end
		if self.isMex then self.ai.mexCount = self.ai.mexCount + 1 end
		if self.isCon then self.ai.conCount = self.ai.conCount + 1 end
		if self.isCombat then self.ai.combatCount = self.ai.combatCount + 1 end
		if self.isBattle then self.ai.battleCount = self.ai.battleCount + 1 end
		if self.isBreakthrough then self.ai.breakthroughCount = self.ai.breakthroughCount + 1 end
		if self.isSiege then self.ai.siegeCount = self.ai.siegeCount + 1 end
		if self.isReclaimer then self.ai.reclaimerCount = self.ai.reclaimerCount + 1 end
		if self.isAssist then self.ai.assistCount = self.ai.assistCount + 1 end
		if self.isBigEnergy then self.ai.bigEnergyCount = self.ai.bigEnergyCount + 1 end
		if self.isCleanable then self.ai.cleanable[unit.engineID] = self.position end
		self.ai.lastNameFinished[self.name] = game:Frame()
		EchoDebug(self.ai.nameCountFinished[self.name] .. " " .. self.name .. " finished")
		self.finished = true
		--mtyped leveled counters
		if self.mtypedLv then
			if self.ai.mtypeLvCount[self.mtypedLv] == nil then 
				self.ai.mtypeLvCount[self.mtypedLv] = 1 
			else
				self.ai.mtypeLvCount[self.mtypedLv] = self.ai.mtypeLvCount[self.mtypedLv] + 1
			end
		end
	end
end

function CountBehaviour:UnitIdle(unit)

end

function CountBehaviour:Update()

end

function CountBehaviour:Activate()

end

function CountBehaviour:Deactivate()
end

function CountBehaviour:Priority()
	return 0
end

function CountBehaviour:UnitDead(unit)
	if unit.engineID == self.unit.engineID then
		self.ai.nameCount[self.name] = self.ai.nameCount[self.name] - 1
		if self.finished then
			self.ai.nameCountFinished[self.name] = self.ai.nameCountFinished[self.name] - 1
			if self.isMex then self.ai.mexCount = self.ai.mexCount - 1 end
			if self.isCon then self.ai.conCount = self.ai.conCount - 1 end
			if self.isCombat then self.ai.combatCount = self.ai.combatCount - 1 end
			if self.isBattle then self.ai.battleCount = self.ai.battleCount - 1 end
			if self.isBreakthrough then self.ai.breakthroughCount = self.ai.breakthroughCount - 1 end
			if self.isSiege then self.ai.siegeCount = self.ai.siegeCount - 1 end
			if self.isReclaimer then self.ai.reclaimerCount = self.ai.reclaimerCount - 1 end
			if self.isAssist then self.ai.assistCount = self.ai.assistCount - 1 end
			if self.isBigEnergy then self.ai.bigEnergyCount = self.ai.bigEnergyCount - 1 end
			if self.isCleanable then self.ai.cleanable[unit.engineID] = nil end
			if self.mtypedLv then
				self.ai.mtypeLvCount[self.mtypedLv] = self.ai.mtypeLvCount[self.mtypedLv] - 1
			end
			
		end
	end
end