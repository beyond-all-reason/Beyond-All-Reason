CleanHandler = class(Module)

local distancePerPriority = 100

function CleanHandler:Name()
	return "CleanHandler"
end

function CleanHandler:internalName()
	return "cleanhandler"
end

function CleanHandler:Init()
	self.DebugEnabled = false

	self.cleanables = {}
	self.priorities = {}
	self.isObstructedBy = {}
	self.isBeingCleanedBy = {}
	self.bigEnergyCount = 0
end

function CleanHandler:UnitBuilt(unit)
	if unit:Team() == self.ai.id then
		if self:IsCleanable(unit) then
			self:EchoDebug("cleanable " .. unit:Name())
			self.cleanables[#self.cleanables+1] = unit
		elseif self:IsBigEnergy(unit) then
			self:EchoDebug("big energy " .. unit:Name())
			self.bigEnergyCount = self.bigEnergyCount + 1
		end
	end
end

function CleanHandler:UnitDead(unit)
	if self:IsBigEnergy(unit) then
		self.bigEnergyCount = self.bigEnergyCount - 1
	else
		for cleanableUnitID, clnrbhvr in pairs(self.isBeingCleanedBy) do
			if clnrbhvr.unit.engineID == unit:ID() then
				self.isBeingCleanedBy[cleanableUnitID] = nil
				break
			end
		end
		for uid, obsUnits in pairs(self.isObstructedBy) do
			if uid == unit:ID() then
				self.isObstructedBy[uid] = nil
				break
			end
		end
		self:RemoveCleanable(unit)
	end
end

function CleanHandler:RemoveCleanable(unit)
	local unitID = unit:ID()
	for i = #self.cleanables, 1, -1 do
		local cleanable = self.cleanables[i]
		if cleanable:ID() == unitID then
			self:EchoDebug("remove cleanable " .. cleanable:Name())
			for uid, obsUnits in pairs(self.isObstructedBy) do
				for i = #obsUnits, 1, -1 do
					local obsUnit = obsUnits[i]
					if obsUnit == unit then
						table.remove(obsUnits, i)
						break
					end
				end
			end
			self.isBeingCleanedBy[unitID] = nil
			table.remove(self.cleanables, i)
			return
		end
	end
end

function CleanHandler:IsCleanable(unit)
	return cleanable[unit:Name()]
end

function CleanHandler:IsBigEnergy(unit)
	local ut = unitTable[unit:Name()]
	if ut then
		return (ut.totalEnergyOut > 750)
	end
end

function CleanHandler:AmCleaning(clnrbhvr, unit)
	self.isBeingCleanedBy[unit:ID()] = clnrbhvr
end

function CleanHandler:IsBeingCleaned(unit)
	return self.isBeingCleanedBy[unit:ID()]
end

function CleanHandler:FilterCleanable(cleanable, clnrbhvr)
	local who = self:IsBeingCleaned(cleanable)
	if who and who ~= clnrbhvr then return end
	local priority = self.priorities[cleanable:ID()] or 0
	if priority < 2 and (self.bigEnergyCount < 2 or self.ai.Metal.full > 0.1) then return end
	if unitTable[cleanable:Name()].totalEnergyOut > 0 and (self.bigEnergyCount < 2 - priority or self.ai.Energy.full < 0.3) then
		return
	end
	return cleanable
end

function CleanHandler:GetCleanables(clnrbhvr)
	local filtered = {}
	for i = #self.cleanables, 1, -1 do
		local cleanable = self:FilterCleanable(self.cleanables[i], clnrbhvr)
		if cleanable then
			filtered[#filtered+1] = cleanable
		end
	end
	return filtered
end

function CleanHandler:CleanablesWithinRadius(position, radius, clnrbhvr)
	if not position or not position.x then return end
	local within = {}
	for i = #self.cleanables, 1, -1 do
		local cleanable = self.cleanables[i]
		local p = cleanable:GetPosition()
		if p then
			local dist = Distance(position, p)
			if dist < radius then
				within[#within+1] = cleanable
			end
		else
			self:RemoveCleanable(cleanable)
		end
	end
	return within
end

function CleanHandler:ClosestCleanable(unit)
	if not self.cleanables or #self.cleanables == 0 then
		return
	end
	local myPos = unit:GetPosition()
	local bestDist, bestCleanable
	for i = #self.cleanables, 1, -1 do
		local cleanable = self:FilterCleanable(self.cleanables[i])
		if cleanable then
			local p = cleanable:GetPosition()
			if p then
				local priority = self.priorities[cleanable:ID()] or 0
				local dist = Distance(myPos, p) - (priority * distancePerPriority)
				if not bestDist or dist < bestDist then
					bestCleanable = cleanable
					bestDist = dist
				end
			else
				self:RemoveCleanable(cleanable)
			end
		end
	end
	return bestCleanable
end

function CleanHandler:ObstructedBy(unit, obsUnit)
	local obstructions = self.isObstructedBy[unit:ID()]
	if not obstructions then return end
	for i = 1, #obstructions do
		local obstruction = obstructions[i]
		if obsUnit == unit then
			return true
		end
	end
end

function CleanHandler:UnitMoveFailed(unit)
	self:EchoDebug("unit move failed", unit:Team(), unit:Name(), unit:ID())
	if self.DebugEnabled then 
		unit:DrawHighlight({1,0,0}, "movefailed", 9)
		self.hasHighlight = self.hasHighlight or {}
		self.hasHighlight[unit:ID()] = 0
	end
	local obstructions = self:CleanablesWithinRadius(unit:GetPosition(), 80)
	self:EchoDebug(#obstructions, "obstructions")
	if self.DebugEnabled then
		self.map:DrawCircle(unit:GetPosition(), 80, {0,0,1}, #obstructions, false, 9)
	end
	for i = 1, #obstructions do
		local obstruction = obstructions[i]
		if not self:ObstructedBy(unit, obstruction) then
			self.priorities[obstruction:ID()] = (self.priorities[obstruction:ID()] or 0) + 1
			self.isObstructedBy[unit:ID()] = self.isObstructedBy[unit:ID()] or {}
			table.insert(self.isObstructedBy[unit:ID()], obstruction)
			if self.DebugEnabled then
				obstruction:EraseHighlight({1,1,0}, nil, 9)
				obstruction:DrawHighlight({1,1,0}, tostring(self.priorities[obstruction:ID()]), 9)
			end
		end
	end
end

function CleanHandler:Update()
	if self.DebugEnabled then
		if not self.hasHighlight then return end
		for id, counter in pairs(self.hasHighlight) do
			self.hasHighlight[id] = self.hasHighlight[id] + 1
			if self.hasHighlight[id] > 150 then
				local unit = self.game:GetUnitByID(id)
				unit:EraseHighlight({1,0,0}, "movefailed", 9)
				self.hasHighlight[id] = nil
			end
		end
	end
end