

local DebugEnabled = false

function IsCleaner(unit)
	local tmpName = unit:Internal():Name()
	return (cleanerList[tmpName] or 0) > 0
end

CleanerBehaviour = class(Behaviour)

function CleanerBehaviour:EchoDebug(...)
	if DebugEnabled then
		local s = ""
		local args = {...}
		for i = 1, #args do
			local a = args[i]
			s = s .. tostring(a)
			if i < #args then
				s = s .. ", "
			end
		end
		game:SendToConsole("CleanerBehaviour " .. self.unit:Internal():Name() .. " " .. self.unit:Internal():ID() .. " : " .. s)
	end
end

function CleanerBehaviour:Init()
	self.name = self.unit:Internal():Name()
	self:EchoDebug("init")
	if nanoTurretList[self.name] then
		self.isStationary = true
		self.cleaningRadius = 390
	else
		self.cleaningRadius = 300
	end
	self.ignore = {}
	self.frameCounter = 0
end

function CleanerBehaviour:Update()
	self.frameCounter = self.frameCounter + 1
	if self.moveFailed or (self.isStationary and self.frameCounter == 90) or (not self.isStationary and self.frameCounter == 150) then
		self.frameCounter = 0
		self.moveFailed = false
		self:Search()
		self.unit:ElectBehaviour()
	end
end

function CleanerBehaviour:OwnerIdle()
	-- self:EchoDebug("idle")
	self.cleanThis = nil
	self:Search()
	self.unit:ElectBehaviour()
end

function CleanerBehaviour:UnitDead(unit)
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

function CleanerBehaviour:Activate()
	CustomCommand(self.unit:Internal(), CMD_RECLAIM, {self.cleanThis:ID()})
end

function CleanerBehaviour:Priority()
	if self.cleanThis then
		return 103
	else
		return 0
	end
end

function CleanerBehaviour:Clean(unit)
	self:EchoDebug("clean this", unit:ID())
	self.cleanThis = unit
	self.ai.cleanhandler:AmCleaning(self, unit)
	self.unit:ElectBehaviour()
end

function CleanerBehaviour:Search()
	if self.cleanThis then return end
	local cleanables = self.ai.cleanhandler:GetCleanables(self)
	if not cleanables or #cleanables == 0 then return end
	local myPos = self.unit:Internal():GetPosition()
	for i = #cleanables, 1, -1 do
		local cleanable = cleanables[i]
		if not self.ignore[cleanable:ID()] then
			local p = cleanable:GetPosition()
			if p then
				local dist = Distance(myPos, p)
				if dist < self.cleaningRadius then
					self:Clean(cleanable)
					return
				elseif self.isStationary then
					self.ignore[cleanable:ID()] = true
				end
			else
				self.ignore[cleanable:ID()] = nil
				self.ai.cleanhandler:RemoveCleanable(cleanable)
			end
		end
	end
end

function CleanerBehaviour:OwnerMoveFailed()
	self.moveFailed = true
end