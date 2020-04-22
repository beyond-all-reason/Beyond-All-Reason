NullBehaviour = class(Behaviour)

-- this gets called when the unit is idle, which means we finished our
-- stop command, yield control. This probably won't work though because
-- it's a stop command
function NullBehaviour:OwnerIdle()
	if self:IsActive() then
		self:YieldControl()
	end
end

function NullBehaviour:Priority()
	return 0
end

function NullBehaviour:Activate()
	-- normally we would issue a command here, then when finished,
	-- the behaviour would give up control of the unit

	-- but this is a null behaviour, we'll just tell the unit to stop
	self.unit:Internal():Stop()
end
