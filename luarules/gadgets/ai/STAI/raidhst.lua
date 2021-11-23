RaidHST = class(Module)

function RaidHST:Name()
	return "RaidHST"
end

function RaidHST:internalName()
	return "raidhst"
end

local mCeil = math.ceil

-- these local variables are the same for all AI teams, in fact having them the same saves memory and processing

function RaidHST:Init()
	self.DebugEnabled = false

	self.counter = {}
	self.ai.raiderCount = {}
	self.ai.IDsWeAreRaiding = {}
	self.pathValidFuncs = {}
	self.RAIDERS = {}
	self.TARGETS = {}
	self.SQUADS = {}

end

-- function RaidHST:NeedMore(mtype, add)
-- 	if add == nil then add = 0.1 end
-- 	if mtype == nil then
-- 		for mtype, count in pairs(self.counter) do
-- 			if self.counter[mtype] == nil then self.counter[mtype] = self.ai.armyhst.baseRaidCounter end
-- 			self.counter[mtype] = self.counter[mtype] + add
-- 			self.counter[mtype] = math.min(self.counter[mtype], self.ai.armyhst.maxRaidCounter)
-- 			self:EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
-- 		end
-- 	else
-- 		if self.counter[mtype] == nil then self.counter[mtype] = self.ai.armyhst.baseRaidCounter end
-- 		self.counter[mtype] = self.counter[mtype] + add
-- 		self.counter[mtype] = math.min(self.counter[mtype], self.ai.armyhst.maxRaidCounter)
-- 		self:EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
-- 	end
-- end
--
-- function RaidHST:NeedLess(mtype)
-- 	if mtype == nil then
-- 		for mtype, count in pairs(self.counter) do
-- 			if self.counter[mtype] == nil then self.counter[mtype] = self.ai.armyhst.baseRaidCounter end
-- 			self.counter[mtype] = self.counter[mtype] - 0.5
-- 			self.counter[mtype] = math.max(self.counter[mtype], self.ai.armyhst.minRaidCounter)
-- 			self:EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
-- 		end
-- 	else
-- 		if self.counter[mtype] == nil then self.counter[mtype] = self.ai.armyhst.baseRaidCounter end
-- 		self.counter[mtype] = self.counter[mtype] - 0.5
-- 		self.counter[mtype] = math.max(self.counter[mtype], self.ai.armyhst.minRaidCounter)
-- 		self:EchoDebug(mtype .. " raid counter: " .. self.counter[mtype])
-- 	end
-- end

-- function RaidHST:GetCounter(mtype)
-- 	if mtype == nil then
-- 		local highestCounter = 0
-- 		for mtype, counter in pairs(self.counter) do
-- 			if counter > highestCounter then highestCounter = counter end
-- 		end
-- 		return highestCounter
-- 	end
-- 	if self.counter[mtype] == nil then
-- 		return self.ai.armyhst.baseRaidCounter
-- 	else
-- 		return self.counter[mtype]
-- 	end
-- end

function RaidHST:IDsWeAreRaiding(unitIDs, mtype)
	for i, unitID in pairs(unitIDs) do
		self.ai.IDsWeAreRaiding[unitID] = mtype
	end
end

function RaidHST:IDsWeAreNotRaiding(unitIDs)
	for i, unitID in pairs(unitIDs) do
		self.ai.IDsWeAreRaiding[unitID] = nil
	end
end

function RaidHST:TargetDied(mtype)
	self:EchoDebug("target died")
	--self:NeedMore(mtype, 0.35)
end

function RaidHST:GetPathValidFunc(unitName)
	if self.pathValidFuncs[unitName] then
		return self.pathValidFuncs[unitName]
	end
	local valid_node_func = function ( node )
		return self.ai.targethst:IsSafePosition(node.position, unitName, 1)
	end
	self.pathValidFuncs[unitName] = valid_node_func
	return valid_node_func
end


function RaidHST:Update()
	local f = self.game:Frame()
	if f % 113 ~= 0 then
		return
	end
	self.map:EraseAll(8)

end

function RaidHST:DraftSquad()
-- 	local counter = {}
-- 	for id, params in pairs(self.RAIDERS) do
-- 		local raider = self.game:GetUnitByID()
-- 		local raiderPos = raider:GetPosition()
-- 		local raiderName = raider:Name()
-- 		if not counter[params.squad] then
-- 			counter[params.squad] = 0
-- 		end
-- 		counter[params.squad] = counter[params.squad] + 1
-- 	end

	for squad,raiders in pairs(self.SQUADS) do
		if #raiders > 5 and not self.TARGETS[squad] then
			self:startSquad(squad)
		end
	end
end



function RaidHST:StartSquad(squad)
	for id, params in pairs(self.RAIDERS) do
		local raider = self.game:GetUnitByID()
		self.TARGETS[squad] = self.TARGETS[squad] or self.ai.targethst:GetBestRaidCell(raider)
		params.target = self.TARGETS[squad]
	end

end

function RaidHST:StopSquad(squad)
	self.TARGETS[squad] = nil
	for id, params in pairs(self.RAIDERS) do
		params.target = nil
	end
	self.SQUADS[squad] = {}

end

function RaidHST:removeRaiderFromSquad(id,squad)
	for i,ID in pairs(squad) do
		if ID == id then
			table.remove(self.SQUADS[squad],id)
		end
	end
end




