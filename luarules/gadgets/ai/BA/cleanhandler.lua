 DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("CleanHandler: " .. inStr)
	end
end

CleanHandler = class(Module)

function CleanHandler:Name()
	return "CleanHandler"
end

function CleanHandler:internalName()
	return "cleanhandler"
end

function CleanHandler:Init()
	self.cleanables = {}
	self.isBeingCleanedBy = {}
	self.bigEnergyCount = 0
end

function CleanHandler:UnitBuilt(unit)
	if unit:Team() == self.ai.id then
		if self:IsCleanable(unit) then
			EchoDebug("cleanable " .. unit:Name())
			self.cleanables[#self.cleanables+1] = unit
		elseif self:IsBigEnergy(unit) then
			EchoDebug("big energy " .. unit:Name())
			self.bigEnergyCount = self.bigEnergyCount + 1
		end
	end
end

function CleanHandler:UnitDead(unit)
	if unit:Team() == self.ai.id then
		if self:IsBigEnergy(unit) then
			self.bigEnergyCount = self.bigEnergyCount - 1
		else
			for cleanableUnitID, clnrbehavior in pairs(self.isBeingCleanedBy) do
				if clnrbehavior.unit.engineID == unit:ID() then
					self.isBeingCleanedBy[cleanableUnitID] = nil
					break
				end
			end
			self:RemoveCleanable(unit)
		end
	end
end

function CleanHandler:RemoveCleanable(unit)
	local unitID = unit:ID()
	for i = #self.cleanables, 1, -1 do
		local cleanable = self.cleanables[i]
		if cleanable:ID() == unitID then
			EchoDebug("remove cleanable " .. cleanable:Name())
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

function CleanHandler:AmCleaning(clnrbehavior, unit)
	self.isBeingCleanedBy[unit:ID()] = clnrbehavior
end

function CleanHandler:IsBeingCleaned(unit)
	return self.isBeingCleanedBy[unit:ID()]
end

function CleanHandler:GetCleanables()
	if self.ai.Metal.full > 0.9 or self.bigEnergyCount < 2 or ai.Energy.full < 0.3 then
		return
	end
	return self.cleanables
end

function CleanHandler:ClosestCleanable(unit)
	local cleanables = self.ai.cleanhandler:GetCleanables()
	if not cleanables or #cleanables == 0 then
		return
	end
	local myPos = unit:GetPosition()
	local bestDist, bestCleanable
	for i = #cleanables, 1, -1 do
		local cleanable = cleanables[i]
		local p = cleanable:GetPosition()
		if p then
			local dist = Distance(myPos, p)
			if not bestDist or dist < bestDist then
				bestCleanable = cleanable
				bestDist = dist
			end
		else
			self:RemoveCleanable(cleanable)
		end
	end
	return bestCleanable
end