RaidBST = class(Behaviour)

function RaidBST:Name()
	return "RaidBST"
end

function RaidBST:Init()
	self.DebugEnabled = false
	local u = self.unit:Internal()
	self.id = u:ID()
	self.name =u:Name()
	self.mtype = self.ai.armyhst.unitTable[self.name].mtype
	local p = u:GetPosition()
	local Cell0,p0,z0 = self.ai.targethst:GetCellHere(p)
-- 	if not p0 then
-- 		self.ai.targethst:GetOrCreateCellHere(p)
-- 		Cell0,p0,z0 = self.ai.targethst:GetCellHere(p)
-- 	end
	--self.squadID = self.name .. p0.. ':'..z0
	local net = self.ai.maphst:MobilityNetworkHere(self.mtype, p)
	if not net then
		self:EchoDebug('there is not a network for ', self.mtype, 'here', p.x,p.z)
		return
	end
	self.squadID = self.name .. net
	self:EchoDebug(self.squadID,'squadID')
	self.ai.raidhst.raiders[u:ID()] = {name = self.name,squadID =  self.squadID, mclass = self.ai.armyhst.unitTable[self.name].mclass,mtype =  self.mtype}
end



function RaidBST:OwnerDead()
	if self.squadID then
		for index,unitID in pairs(self.ai.raidhst.squads[self.squadID].members) do
			if self.id == unitID then
				table.remove(self.ai.raidhst.squads[self.squadID].members,index)
	-- 			self.ai.raidhst.squads[self.squadID].members[index] = nil
			end
		end
	end
	self.ai.raidhst.raiders[self.id] = nil
end

function RaidBST:Priority()
	local raider = self.ai.raidhst.raiders[self.id]
	local mySquad = self.ai.raidhst.squads[self.squadID]
 	if raider and raider.inSquad and mySquad and  mySquad.target and mySquad.path then
		self:EchoDebug('be a raider')
 		return 101
 	else
		self:EchoDebug('not a raider')
 		return 0
 	end
end

function RaidBST:Update()
--	 self.uFrame = self.uFrame or 0
	local f = self.game:Frame()
-- 	if f - self.uFrame < self.ai.behUp['raidbst'] then
-- 		return
-- 	end
-- 	self.uFrame = f
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'RaidBST' then return end
	local u = self.unit:Internal()
	if not self.ai.raidhst.raiders[u:ID()] and self.unit:Internal():IsAlive() then
		local p = u:GetPosition()
		local net = self.ai.maphst:MobilityNetworkHere(self.mtype, p)
		if not net then
			u:Move(self.ai.tool:RandomAway( p, 50))
			self:EchoDebug('there is not a network for ', self.mtype, 'here', p.x,p.z)
			return
		end
		self.squadID = self.name .. net
		self:EchoDebug(self.squadID,'squadID')
		self.ai.raidhst.raiders[u:ID()] = {name = self.name,squadID =  self.squadID, mclass = self.ai.armyhst.unitTable[self.name].mclass,mtype = self.mtype}
	end
	self.unit:ElectBehaviour()
end

function RaidBST:Activate()
	self:EchoDebug("activated on " .. self.name)
	self.active = true
end

function RaidBST:Deactivate()
	self:EchoDebug("deactivated on " .. self.name)
	self.active = false
end
