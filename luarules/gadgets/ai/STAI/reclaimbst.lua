ReclaimBST = class(Behaviour)

function ReclaimBST:Name()
	return "ReclaimBST"
end

function ReclaimBST:Init()
	self.position = self.unit:Internal():GetPosition()
end

function ReclaimBST:Act()
	local timearea = 10000
	if self.unit:Internal():CurrentCommand() ~= CMD.RECLAIM then
		if #Spring.GetFeaturesInCylinder(self.position.x,self.position.z,10000) > 0 then
			self.ai.tool:GiveOrder(self.unit:Internal():ID(),CMD.RECLAIM,{self.position.x,self.position.y,self.position.z,timearea},0,'1-1')	
		end
		
	end
end

function ReclaimBST:Update()
	local f = self.game:Frame()
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'ReclaimBST' then return end
	self.position.x,self.position.y,self.position.z = self.unit:Internal():GetRawPos()
	self:Act()

end

function ReclaimBST:Priority()
	if self.act then
		self:EchoDebug("priority HIGH")
		return 101
	else
		self:EchoDebug("priority LOW")
		return 0
	end
end
