RaidHandler = class(Module)

function RaidHandler:Name()
	return "RaidHandler"
end

function RaidHandler:internalName()
	return "raidhandler"
end

local mCeil = math.ceil

-- these local variables are the same for all AI teams, in fact having them the same saves memory and processing

function RaidHandler:Init()
	self.DebugEnabled = false

	self.counter = {}
	self.ai.raiderCount = {}
	self.ai.IDsWeAreRaiding = {}
	self.pathValidFuncs = {}
end

function RaidHandler:NeedMore(mtype, add)
	if add == nil then add = 0.1 end
	if mtype == nil then
		for mtype, count in pairs(self.counter) do
			if self.counter[mtype] == nil then self.counter[mtype] = baseRaidCounter end
			self.counter[mtype] = self.counter[mtype] + add
			self.counter[mtype] = math.min(self.counter[mtype], maxRaidCounter)
			self:EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
		end
	else
		if self.counter[mtype] == nil then self.counter[mtype] = baseRaidCounter end
		self.counter[mtype] = self.counter[mtype] + add
		self.counter[mtype] = math.min(self.counter[mtype], maxRaidCounter)
		self:EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
	end
end

function RaidHandler:NeedLess(mtype)
	if mtype == nil then
		for mtype, count in pairs(self.counter) do
			if self.counter[mtype] == nil then self.counter[mtype] = baseRaidCounter end
			self.counter[mtype] = self.counter[mtype] - 0.5
			self.counter[mtype] = math.max(self.counter[mtype], minRaidCounter)
			self:EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
		end
	else
		if self.counter[mtype] == nil then self.counter[mtype] = baseRaidCounter end
		self.counter[mtype] = self.counter[mtype] - 0.5
		self.counter[mtype] = math.max(self.counter[mtype], minRaidCounter)
		self:EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
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
	self:EchoDebug("target died")
	self:NeedMore(mtype, 0.35)
end

function RaidHandler:GetPathValidFunc(unitName)
	if self.pathValidFuncs[unitName] then
		return self.pathValidFuncs[unitName]
	end
	local valid_node_func = function ( node )
		return ai.targethandler:IsSafePosition(node.position, unitName, 1)
	end
	self.pathValidFuncs[unitName] = valid_node_func
	return valid_node_func
end