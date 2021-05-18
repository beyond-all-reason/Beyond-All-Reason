CleanHST = class(Module)

-- distancePerPriority = 100

function CleanHST:Name()
	return "CleanHST"
end

function CleanHST:internalName()
	return "cleanhst"
end

function CleanHST:Init()
	self.DebugEnabled = false
-- 	self.cleanables = {}
-- 	self.priorities = {}
-- 	self.isObstructedBy = {}
-- 	self.isBeingCleanedBy = {}
-- 	self.bigEnergyCount = 0
	self.theCleaner = {}
	self.dirt = {}
end

-- function CleanHST:MyUnitBuilt(unit)
-- 	if unit:Team() == self.ai.id then
-- 		if self:IsCleanable(unit) then
-- 			self:EchoDebug("cleanable " .. unit:Name())
-- 			self.cleanables[#self.cleanables+1] = unit
-- 		elseif self:IsBigEnergy(unit) then
-- 			self:EchoDebug("big energy " .. unit:Name())
-- 			self.bigEnergyCount = self.bigEnergyCount + 1
-- 		end
-- 	end
-- end

function CleanHST:UnitDead(unit)
	if self.dirt[unit:ID()] then
		self:EchoDebug(self.dirt[unit:ID()],'removed this unit' ,unit:ID())
-- 		table.remove(self.theCleaner,self.dirt[unit:ID()])
-- 		table.remove(self.dirt,unit:ID())
		local executer = self.game:GetUnitByID(self.dirt[unit:ID()])
		executer:Patrol({-10,0,-10})
		self.theCleaner[self.dirt[unit:ID()]] = nil
		self.dirt[unit:ID()] = nil
	end
-- 	if self:IsBigEnergy(unit) then
-- 		self.bigEnergyCount = self.bigEnergyCount - 1
-- 	else
-- 		for cleanableUnitID, clnrbhvr in pairs(self.isBeingCleanedBy) do
-- 			if clnrbhvr.unit.engineID == unit:ID() then
-- 				self.isBeingCleanedBy[cleanableUnitID] = nil
-- 				break
-- 			end
-- 		end
-- 		for uid, obsUnits in pairs(self.isObstructedBy) do
-- 			if uid == unit:ID() then
-- 				self.isObstructedBy[uid] = nil
-- 				break
-- 			end
-- 		end
-- 		self:RemoveCleanable(unit)
--
--
-- 	end
end

-- function CleanHST:RemoveCleanable(unit)
-- 	local unitID = unit:ID()
-- 	self:EchoDebug('try to remove', unitID)
-- 	for i = #self.cleanables, 1, -1 do
-- 		local cleanable = self.cleanables[i]
-- 		self:EchoDebug('cleanable =', cleanable:ID() , 'unitid',unitID)
-- 		if cleanable:ID() == unitID then
-- 			self:EchoDebug("remove cleanable " .. cleanable:Name())
-- 			for uid, obsUnits in pairs(self.isObstructedBy) do
-- 				for i = #obsUnits, 1, -1 do
-- 					local obsUnit = obsUnits[i]
-- 					if obsUnit == unit then
-- 						table.remove(obsUnits, i)
-- 						self:EchoDebug('remove obstructions',i)
-- 						break
-- 					end
-- 				end
-- 			end
-- 			self.isBeingCleanedBy[unitID] = nil
-- 			table.remove(self.cleanables, i)
-- 			return
-- 		end
-- 	end
-- 	self:EchoDebug('exit remove ', unitID)
-- end
--[[
function CleanHST:IsCleanable(unit)
	return self.ai.armyhst.cleanable[unit:Name()]
end

function CleanHST:IsBigEnergy(unit)
	local ut = self.ai.armyhst.unitTable[unit:Name()]
	if ut then
		return (ut.totalEnergyOut > 750)
	end
end

function CleanHST:AmCleaning(clnrbhvr, unit)
	self.isBeingCleanedBy[unit:ID()] = clnrbhvr
end

function CleanHST:IsBeingCleaned(unit)
	self:EchoDebug('is being cleaned',unit,unit:ID())
	return self.isBeingCleanedBy[unit:ID()]
end

function CleanHST:FilterCleanable(cleanable,clnrbhvr )

	local who = self:IsBeingCleaned(cleanable)
	self:EchoDebug('who=',who,'cleanable=',cleanable,'clnrbhvr=',clnrbhvr)
	if who and who ~= clnrbhvr then
		self:EchoDebug('who not clnrbhvr')

		return
	end
	local priority = self.priorities[cleanable:ID()] or 0
-- 	if priority < 2 and (self.bigEnergyCount < 2 or self.ai.Metal.full > 0.5) then
-- 		self:EchoDebug('prio < 2')
-- 		return
-- 	end
-- 	if self.ai.armyhst.unitTable[cleanable:Name()].totalEnergyOut > 0 and (self.bigEnergyCount < 2 - priority or self.ai.Energy.full < 0.3) then
-- 		self:EchoDebug('dont clean E')
-- 		return
-- 	end
	self:EchoDebug('#filteredcleanable' , #cleanable)
	return cleanable
end]]

-- function CleanHST:GetCleanables(clnrbhvr)
-- 	local filtered = {}
-- 	local filteredCount = 0
-- 	self:EchoDebug('cleanable lenght', #self.cleanables)
-- 	for i = #self.cleanables, 1, -1 do
-- 		local cleanable = self:FilterCleanable(self.cleanables[i], clnrbhvr)
-- 		if cleanable then
--
-- 			filteredCount = filteredCount + 1
-- 			filtered[filteredCount] = cleanable
-- 			self:EchoDebug('filteredCount',filteredCount)
-- 		end
-- 	end
-- 	self:EchoDebug('get cleanables', filtered)
-- 	return filtered
-- end
--
-- function CleanHST:CleanablesWithinRadius(position, radius, clnrbhvr)
-- 	if not position or not position.x then return end
-- 	local within = {}
-- 	local withinCount = 0
-- 	for i = #self.cleanables, 1, -1 do
-- 		local cleanable = self.cleanables[i]
-- 		local p = cleanable:GetPosition()
-- 		if p then
-- 			local dist = self.ai.tool:Distance(position, p)
-- 			if dist < radius then
-- 				withinCount = withinCount + 1
-- 				within[withinCount] = cleanable
-- 			end
-- 		else
-- 			self:RemoveCleanable(cleanable)
-- 		end
-- 	end
-- 	self:EchoDebug('cleanables within' , within)
-- 	return within
-- end
--
-- function CleanHST:ClosestCleanable(unit)
-- 	if not self.cleanables or #self.cleanables == 0 then
-- 		return
-- 	end
-- 	local myPos = unit:GetPosition()
-- 	local bestDist, bestCleanable
-- 	for i = #self.cleanables, 1, -1 do
-- 		local cleanable = self:FilterCleanable(self.cleanables[i])
-- 		if cleanable then
-- 			local p = cleanable:GetPosition()
-- 			if p then
-- 				local priority = self.priorities[cleanable:ID()] or 0
-- 				local dist = self.ai.tool:Distance(myPos, p) - (priority * distancePerPriority)
-- 				if not bestDist or dist < bestDist then
-- 					bestCleanable = cleanable
-- 					bestDist = dist
-- 				end
-- 			else
-- 				self:RemoveCleanable(cleanable)
-- 			end
-- 		end
-- 	end
-- 	self:EchoDebug('best cleanable', bestCleanable)
-- 	return bestCleanable
-- end

-- function CleanHST:ObstructedBy(unit, obsUnit)
-- 	local obstructions = self.isObstructedBy[unit:ID()]
-- 	if not obstructions then
-- 		self:EchoDebug('nothing obstruct')
-- 		return
-- 	end
-- 	for i = 1, #obstructions do
-- 		local obstruction = obstructions[i]
-- 		if obsUnit == unit then
-- 			self:EchoDebug('obstruction')
-- 			return true
-- 		end
-- 	end
-- end

-- function CleanHST:UnitMoveFailed(unit)
-- 	self:EchoDebug("unit move failed", unit:Team(), unit:Name(), unit:ID())
-- 	if self.DebugEnabled then
-- 		unit:DrawHighlight({1,0,0}, "movefailed", 9)
-- 		self.hasHighlight = self.hasHighlight or {}
-- 		self.hasHighlight[unit:ID()] = 0
-- 	end
-- 	local obstructions = self:CleanablesWithinRadius(unit:GetPosition(), 80)
-- 	self:EchoDebug(#obstructions, "obstructions")
-- 	if self.DebugEnabled then
-- 		self.map:DrawCircle(unit:GetPosition(), 80, {0,0,1}, #obstructions, false, 9)
-- 	end
-- 	for i = 1, #obstructions do
-- 		local obstruction = obstructions[i]
-- 		if not self:ObstructedBy(unit, obstruction) then
-- 			self.priorities[obstruction:ID()] = (self.priorities[obstruction:ID()] or 0) + 1
-- 			self.isObstructedBy[unit:ID()] = self.isObstructedBy[unit:ID()] or {}
-- 			table.insert(self.isObstructedBy[unit:ID()], obstruction)
-- 			self:EchoDebug('something obstruct')
-- 			if self.DebugEnabled then
-- 				obstruction:EraseHighlight({1,1,0}, nil, 9)
-- 				obstruction:DrawHighlight({1,1,0}, tostring(self.priorities[obstruction:ID()]), 9)
-- 			end
-- 		end
-- 	end
-- end

-- function CleanHST:Update()
-- 	if self.DebugEnabled then
-- 		if not self.hasHighlight then return end
-- 		for id, counter in pairs(self.hasHighlight) do
-- 			self.hasHighlight[id] = self.hasHighlight[id] + 1
-- 			if self.hasHighlight[id] > 150 then
-- 				local unit = self.game:GetUnitByID(id)
-- 				unit:EraseHighlight({1,0,0}, "movefailed", 9)
-- 				self.hasHighlight[id] = nil
-- 			end
-- 		end
-- 	end
-- end
