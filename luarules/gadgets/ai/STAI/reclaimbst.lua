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
	local f = self.game:Frame()
	if f % 257 == 0 then
		self:Act()
	end
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
