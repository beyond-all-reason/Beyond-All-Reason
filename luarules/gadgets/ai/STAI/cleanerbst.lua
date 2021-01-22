

function IsCleaner(unit)
	local tmpName = unit:Internal():Name()
	return (cleanerList[tmpName] or 0) > 0
end

CleanerBST = class(Behaviour)

-- function CleanerBST:EchoDebug(...)
-- 	if DebugEnabled then
-- 		local s = ""
-- 		local args = {...}
-- 		for i = 1, #args do
-- 			local a = args[i]
-- 			s = s .. tostring(a)
-- 			if i < #args then
-- 				s = s .. ", "
-- 			end
-- 		end
-- 		game:SendToConsole("CleanerBST " .. self.unit:Internal():Name() .. " " .. self.unit:Internal():ID() .. " : " .. s)
-- 	end
-- end

function CleanerBST:Init()
	self.DebugEnabled = false
	self.name = self.unit:Internal():Name()
	self:EchoDebug("init")
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
	self.frameCounter = self.frameCounter + 1
	if self.moveFailed or (self.isStationary and self.frameCounter == 90) or (not self.isStationary and self.frameCounter == 150) then
		self.frameCounter = 0
		self.moveFailed = false
		self:Search()
		self.unit:ElectBehaviour()
	end
end

function CleanerBST:OwnerIdle()
	-- self:EchoDebug("idle")
	self.cleanThis = nil
	self:Search()
	self.unit:ElectBehaviour()
end

function CleanerBST:UnitDead(unit)
	if not unit.engineID then
		self:EchoDebug("nil engineID")
	elseif self.ignore[unit.engineID] then
		self:EchoDebug("dead unit in ignore table")
		self.ignore[unit.engineID] = nil
	elseif self.cleanThis and self.cleanThis.id == unit.engineID then
		self:EchoDebug("what i was cleaning died")
		self.cleanThis = nil
	end
end

function CleanerBST:Activate()
	self.unit:Internal():Reclaim(self.cleanThis)
end

function CleanerBST:Priority()
	if self.cleanThis then
		return 103
	else
		return 0
	end
end

function CleanerBST:Clean(unit)
	self:EchoDebug("clean this", unit:ID())
	self.cleanThis = unit
	self.ai.cleanhst:AmCleaning(self, unit)
	self.unit:ElectBehaviour()
end

function CleanerBST:Search()
	if self.cleanThis then return end
	local cleanables = self.ai.cleanhst:GetCleanables(self)
	if not cleanables or #cleanables == 0 then
		self:EchoDebug('no cleanables')
		return
	end
	local myPos = self.unit:Internal():GetPosition()
	for i = #cleanables, 1, -1 do
		local cleanable = cleanables[i]
		if not self.ignore[cleanable:ID()] then
			local p = cleanable:GetPosition()
			if p then
				local dist = self.ai.tool:Distance(myPos, p)
				if dist < self.cleaningRadius then
					self:Clean(cleanable)
					return
				elseif self.isStationary then
					self.ignore[cleanable:ID()] = true
				end
			else
				self:EchoDebug('nil cleanable pos ')
				self.ignore[cleanable:ID()] = nil
				self.ai.cleanhst:RemoveCleanable(cleanable)
			end
		end
	end
end

function CleanerBST:OwnerMoveFailed()
	self.moveFailed = true
end
