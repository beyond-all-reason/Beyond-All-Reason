 DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("RaidHandler: " .. inStr)
	end
end

RaidHandler = class(Module)

function RaidHandler:Name()
	return "RaidHandler"
end

function RaidHandler:internalName()
	return "raidhandler"
end

function RaidHandler:Init()
	self.counter = {}
	self.ai.raiderCount = {}
	self.ai.IDsWeAreRaiding = {}
end

function RaidHandler:NeedMore(mtype, add)
	if add == nil then add = 0.1 end
	if mtype == nil then
		for mtype, count in pairs(self.counter) do
			if self.counter[mtype] == nil then self.counter[mtype] = baseRaidCounter end
			self.counter[mtype] = self.counter[mtype] + add
			self.counter[mtype] = math.min(self.counter[mtype], maxRaidCounter)
			EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
		end
	else
		if self.counter[mtype] == nil then self.counter[mtype] = baseRaidCounter end
		self.counter[mtype] = self.counter[mtype] + add
		self.counter[mtype] = math.min(self.counter[mtype], maxRaidCounter)
		EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
	end
end

function RaidHandler:NeedLess(mtype)
	if mtype == nil then
		for mtype, count in pairs(self.counter) do
			if self.counter[mtype] == nil then self.counter[mtype] = baseRaidCounter end
			self.counter[mtype] = self.counter[mtype] - 0.5
			self.counter[mtype] = math.max(self.counter[mtype], minRaidCounter)
			EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
		end
	else
		if self.counter[mtype] == nil then self.counter[mtype] = baseRaidCounter end
		self.counter[mtype] = self.counter[mtype] - 0.5
		self.counter[mtype] = math.max(self.counter[mtype], minRaidCounter)
		EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
	end
end

function RaidHandler:GetCounter(mtype)
	if mtype == nil then
		local highestCounter = 0
		for mtype, counter in pairs(self.counter) do
			if counter > highestCounter then highestCounter = counter end
		end
		return highestCounter
	end
	if self.counter[mtype] == nil then
		return baseRaidCounter
	else
		return self.counter[mtype]
	end
end

function RaidHandler:IDsWeAreRaiding(unitIDs, mtype)
	for i, unitID in pairs(unitIDs) do
		self.ai.IDsWeAreRaiding[unitID] = mtype
	end
end

function RaidHandler:IDsWeAreNotRaiding(unitIDs)
	for i, unitID in pairs(unitIDs) do
		self.ai.IDsWeAreRaiding[unitID] = nil
	end
end

function RaidHandler:TargetDied(mtype)
	EchoDebug("target died")
	self:NeedMore(mtype, 0.35)
end