DefendBST = class(Behaviour)

function DefendBST:Name()
	return "DefendBST"
end

function DefendBST:Init()
	self.DebugEnabled = false
	local u = self.unit:Internal()
	self.id = u:ID()
	self.name =u:Name()
	self.mtype = self.ai.armyhst.unitTable[self.name].mtype
	local p = u:GetPosition()
	--local Cell0 = self.ai.maphst:GetCell(p,)
	local net = self.ai.maphst:MobilityNetworkHere(self.mtype, p)
	if not net then
		self:EchoDebug('there is not a network for ', self.mtype, 'here', p.x,p.z)
		return
	end
	self.squad = nil
	self.ai.defendhst.units[self.id] = {}

end

