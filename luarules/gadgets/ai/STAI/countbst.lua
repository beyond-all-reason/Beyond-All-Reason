CountBST = class(Behaviour)

function CountBST:Name()
	return "CountBST"
end

function CountBST:Updade()
	--nothing to do
end

function CountBST:Init()
	self.DebugEnabled = false
	self.finished = false
	self.name = self.unit:Internal():Name()
	self.id = self.unit:Internal():ID()
	local uTn = self.ai.armyhst.unitTable[self.name]
	-- game:SendToConsole(self.name .. " " .. self.id .. " init")
	if uTn.isBuilding then
		self.position = self.unit:Internal():GetPosition() -- buildings don't move
		self.isBuilding = true
	else
		if uTn.buildOptions then
-- 			self.isCon = true
		elseif uTn.isWeapon then
			self.isCombat = true
			self.mtypedLv = tostring(uTn.mtype)..uTn.techLevel
			self.mobileMtyped = uTn.mtype
		end
	end
-- 	if uTn.extractsMetal > 0 then self.isMex = true end
	if self.ai.armyhst.battles[self.name] then self.isBattle = true end
	if self.ai.armyhst.breaks[self.name] then self.isBreakthrough = true end
	if self.isCombat and not self.ai.armyhst.battles[self.name] and not self.ai.armyhst.breaks[self.name] then
		self.isSiege = true
	end
-- 	if self.ai.armyhst.rezs[self.name] then self.isReclaimer = true end
	if self.ai.armyhst.cleanable[self.name] then self.isCleanable = true end
-- 	if self.ai.armyhst.engineers[self.name] then self.isAssist = true end
	if self.ai.armyhst._nano_[self.name] then self.isNano = true end
-- 	if self.ai.nameCount[self.name] == nil then
-- 		self.ai.nameCount[self.name] = 1
-- 	else
-- 		self.ai.nameCount[self.name] = self.ai.nameCount[self.name] + 1
-- 	end
	self:EchoDebug(self.ai.nameCount[self.name] .. " " .. self.name .. " created")
	self.ai.lastNameCreated[self.name] = self.game:Frame()
	self.unit:ElectBehaviour()
end

function CountBST:OwnerBuilt()
	-- game:SendToConsole(self.name .. " " .. self.id .. " built")
	if self.ai.nameCountFinished[self.name] == nil then
		self.ai.nameCountFinished[self.name] = 1
	else
		self.ai.nameCountFinished[self.name] = self.ai.nameCountFinished[self.name] + 1
	end
-- 	if self.isMex then self.ai.mexCount = self.ai.mexCount + 1 end
	if self.isCon then
-- 		self.ai.conCount = self.ai.conCount + 1
		self.ai.conList[self.id] = self
	end
	if self.isCombat then self.ai.combatCount = self.ai.combatCount + 1 end
	if self.isBattle then self.ai.battleCount = self.ai.battleCount + 1 end
	if self.isBreakthrough then self.ai.breakthroughCount = self.ai.breakthroughCount + 1 end
	if self.isSiege then self.ai.siegeCount = self.ai.siegeCount + 1 end
-- 	if self.isReclaimer then self.ai.reclaimerCount = self.ai.reclaimerCount + 1 end
-- 	if self.isAssist then self.ai.assistCount = self.ai.assistCount + 1 end
	if self.isCleanable then self.ai.armyhst.cleanable[self.unit.engineID] = self.position end
-- 	if self.ai.armyhst.unitTable.isAttacker then self.ai.attackerCount = self.ai.attackerCount + 1 end
	if self.isNano then
		self.ai.nanoList[self.id] = self.unit:Internal():GetPosition()
		self.ai.lastNanoBuild = self.unit:Internal():GetPosition()
	end
	self.ai.lastNameFinished[self.name] = self.game:Frame()
	self:EchoDebug(self.ai.nameCountFinished[self.name] .. " " .. self.name .. " finished")
	self.finished = true
	--mtyped leveled counters
	if self.mobileMtyped then self.ai.mtypeCount[self.mobileMtyped] = self.ai.mtypeCount[self.mobileMtyped] + 1 end
	if self.mtypedLv then
		if self.ai.mtypeLvCount[self.mtypedLv] == nil then
			self.ai.mtypeLvCount[self.mtypedLv] = 1
		else
			self.ai.mtypeLvCount[self.mtypedLv] = self.ai.mtypeLvCount[self.mtypedLv] + 1
		end
	end
end

function CountBST:Priority()
	return 0
end

function CountBST:OwnerDead()
-- 	self.ai.nameCount[self.name] = self.ai.nameCount[self.name] - 1
	if self.finished then
		self.ai.nameCountFinished[self.name] = self.ai.nameCountFinished[self.name] - 1
-- 		if self.isMex then self.ai.mexCount = self.ai.mexCount - 1 end
		if self.isCon then
-- 			self.ai.conCount = self.ai.conCount - 1
			self.ai.conList[self.id] = nil
		end
		if self.isCombat then self.ai.combatCount = self.ai.combatCount - 1 end
		if self.isBattle then self.ai.battleCount = self.ai.battleCount - 1 end
		if self.isBreakthrough then self.ai.breakthroughCount = self.ai.breakthroughCount - 1 end
		if self.isSiege then self.ai.siegeCount = self.ai.siegeCount - 1 end
-- 		if self.isReclaimer then self.ai.reclaimerCount = self.ai.reclaimerCount - 1 end
-- 		if self.isAssist then self.ai.assistCount = self.ai.assistCount - 1 end
		if self.isCleanable then self.ai.armyhst.cleanable[self.unit.engineID] = nil end
-- 		if self.ai.armyhst.unitTable.isAttacker then self.ai.attackerCount = self.ai.attackerCount - 1 end
		if self.isNano then
			self.ai.nanoList[self.id] = nil
			if self.ai.lastNanoBuild == self.unit:Internal():GetPosition() then self.ai.lastNanoBuild = nil end
		end
		if self.mobileMtyped then self.ai.mtypeCount[self.mobileMtyped] = self.ai.mtypeCount[self.mobileMtyped] - 1 end
		if self.mtypedLv then
			self.ai.mtypeLvCount[self.mtypedLv] = self.ai.mtypeLvCount[self.mtypedLv] - 1
		end
	end
end
