ReclaimBST = class(Behaviour)

function ReclaimBST:Name()
	return "ReclaimBST"
end

function ReclaimBST:Act()
	local timearea = 10000
	self.act = self.unit:Internal():AreaReclaim(self.unit:Internal():GetPosition(),timearea)
	self.unit:ElectBehaviour()
end

function ReclaimBST:Update()
-- 	 self.uFrame = self.uFrame or 0
	local f = self.game:Frame()
-- 	if f - self.uFrame < self.ai.behUp['reclaimbst']  then
-- 		return
-- 	end
-- 	self.uFrame = f
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'ReclaimBST' then return end
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
