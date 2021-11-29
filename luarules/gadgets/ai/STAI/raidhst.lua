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
	self.DebugEnabled = true

	self.counter = {}
	self.ai.raiderCount = {}
	self.ai.IDsWeAreRaiding = {}
	self.pathValidFuncs = {}
	self.SQUADS = {}
	self.squadSize = 5
end


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
	self:updateSquads()

end

function RaidHST:countSquad(squad)
	local counter = 0
	for ID,status in pairs(self.SQUADS[squad].members)do
		counter= counter+1
	end
	return counter
end

function RaidHST:getSquadPos(squad)
	local midpos = {x=0,y=0,z=0}
	self.SQUADS[squad].counter = 0
	for ID,param in pairs(self.SQUADS[squad].members) do
		local raider = self.game:GetUnitByID(ID)
		if raider:IsAlive() then
			self.SQUADS[squad].counter = self.SQUADS[squad].counter + 1
			local raiderPos = raider:GetPosition()
			midpos.x = midpos.x + raiderPos.x
			midpos.z = midpos.z + raiderPos.z
		else
			table.remove(self.SQUADS[squad],ID)
		end
	end
	if self.SQUADS[squad].counter > 0 then
		midpos.x = midpos.x /self.SQUADS[squad].counter
		midpos.z = midpos.z /self.SQUADS[squad].counter
		midpos.y = Spring.GetGroundHeight(midpos.x,midpos.z)
		self.SQUADS[squad].POS = midpos

		return
	end
	self.SQUADS[squad].POS = nil
end


function RaidHST:squadRandevouz(squad)
	local dist = 0
	for ID,param in pairs(self.SQUADS[squad].members) do

		local raider = self.game:GetUnitByID(ID)
		if raider:IsAlive() then
			local raiderPos = raider:GetPosition()
			dist = dist + math.abs(self.ai.tool:Distance(self.SQUADS[squad].POS,raiderPos))
		end
	end
	return dist
end

function RaidHST:draftSquad(squad)
	self.SQUADS[squad] = {}
	self.SQUADS[squad].mode = -1
	self.SQUADS[squad].members = {}
	self.SQUADS[squad].target = nil
	self.SQUADS[squad].POS = nil
	self.SQUADS[squad].name = squad

end

function RaidHST:updateSquads()
	self:EchoDebug('update squads')
	for squad,params in pairs(self.SQUADS) do
		self:getSquadPos(squad)
		self:countSquad(squad)
		self:EchoDebug(squad,self.SQUADS[squad].counter,self.SQUADS[squad].target)
		if self.SQUADS[squad].counter < 1 and self.SQUADS.target  then
			self:EchoDebug('no enough raiders to do a squad' ,squad)
			self:draftSquad(squad)
		elseif self.SQUADS[squad].counter > 5 and not self.SQUADS[squad].target and self:squadRandevouz(squad) > 500 then
			self:EchoDebug('randevouz',squad)
			self.SQUADS[squad].mode = 500
		elseif self.SQUADS[squad].counter > 5 and not self.SQUADS[squad].target then
			self:EchoDebug('do a squad and get a target',squad)
			self:startSquad(squad)
		elseif self.SQUADS[squad].target then
			self.map:DrawCircle({x=self.SQUADS[squad].target.x*256,y = 100,z=self.SQUADS[squad].target.z*256},56, {1,1,1,1}, self.SQUADS[squad].name,true, 8)
			self:EchoDebug(squad, 'squad is running')
			self:runSquad(squad)
		elseif self.SQUADS[squad].target then

			self:EchoDebug(self.ai.tool:Distance(self.SQUADS[squad].target,self.SQUADS[squad].POS))

		else
			self:EchoDebug(squad, 'condition ',self.SQUADS[squad].counter,self.SQUADS[squad].target,self.SQUADS[squad].mode,self.SQUADS[squad].POS)
		end
	end

end

function RaidHST:squadMode(squad)
	if not self.SQUADS[squad] then
		self:EchoDebug('squad whith strange name')
	end
	squad = self.SQUADS[squad]
	if squad.counter < squadSize then
		squad.mode = 'formation'
	elseif squad.counter > squad.squadSize and not squad.target then
		squad.mode = 'targeting'
	elseif squad.targett and self:squadRandevouz() > 300 then
		squad.mode = 'randevouz'
	else
		self:EchoDebug('squad whith strange condition')
	end
end

function RaidHST:targetSquad(squad)
	local tg
	for ID,status in pairs (self.SQUADS[squad].members) do
		local raider = self.game:GetUnitByID(ID)
		if raider:IsAlive() then
			tg = self.ai.targethst:GetBestRaidCell(raider)

			if tg then
				self.SQUADS[squad].target = tg
			else
				self:EchoDebug('no target for squad', squad)
			end
		else
			table.remove(self.SQUADS[squad].members,ID)
		end

	end
end

function RaidHST:startSquad(squad)
	self:targetSquad(squad)
end

function RaidHST:runSquad(squad)
	self:EchoDebug('RUN',squad)
	self.SQUADS[squad].mode = 1001
	for ID,status in pairs(self.SQUADS[squad].members) do

		local raider = self.game:GetUnitByID(ID)
		if not raider:IsAlive() then

			table.remove(self.SQUADS[squad].members,ID)
		end
	end


end


function RaidHST:addToSquad(ID)
	local raider = self.game:GetUnitByID(ID)
	local raiderName = raider:Name()
	local raiderPos = raider:GetPosition()
	local raiderUT = self.ai.armyhst.unitTable[raiderName]
	local net = self.ai.maphst:MobilityNetworkHere(raiderUT.mtype, raiderPos)
	if not net then
		return
	end
	local squad = raiderName .. net
	if not self.SQUADS[squad] then
		self:draftSquad(squad)
	end
	return self.SQUADS[squad]
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
