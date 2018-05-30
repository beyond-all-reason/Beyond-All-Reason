function IsPointCapturer(unit, ai)
	local noncapturelist = ai.game:ControlPointNonCapturingUnits()
	for i = 1, #noncapturelist do
		local name = noncapturelist[i]
		if name == unit:Internal():Name() then
			return false
		end
	end
	return true
end

PointCapturerBehaviour = class(Behaviour)

local function RandomAway(pos, dist, angle)
	angle = angle or math.random() * math.pi * 2
	local away = api.Position()
	away.x = pos.x + dist * math.cos(angle)
	away.z = pos.z - dist * math.sin(angle)
	away.y = pos.y + 0
	return away
end

function PointCapturerBehaviour:Init()
	self.arePoints = self.game:UsesControlPoints()
	self.maxDist = math.ceil( self.game:ControlPointCaptureRadius() * 0.9 )
	self.minDist = math.ceil( self.maxDist / 3 )
end

function PointCapturerBehaviour:UnitIdle(unit)
	if not self.active then return end
	if unit.engineID == self.unit.engineID then
		self:GoForth()
	end
end

function PointCapturerBehaviour:Update()
	if not self.active then return end
	if not self.nextCheck or self.game:Frame() == self.nextCheck then
		self:GoForth()
	end
end

function PointCapturerBehaviour:Priority()
	if self.arePoints then
		return 40
	else
		return 0
	end
end

function PointCapturerBehaviour:Activate()
	self.active = true
end

function PointCapturerBehaviour:Deactivate()
	self.active = false
end

function PointCapturerBehaviour:GoForth()
	local upos = self.unit:Internal():GetPosition()
	local point = self.ai.controlpointhandler:ClosestUncapturedPoint(upos)
	if point and point ~= self.currentPoint then
		local movePos = RandomAway( point, math.random(self.minDist,self.maxDist) )
		self.unit:Internal():Move(movePos)
		self.currentPoint = point
	end
	self.nextCheck = self.game:Frame() + math.random(60, 90)
end
