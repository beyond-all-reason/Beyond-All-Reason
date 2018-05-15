Behaviour = class(AIBase)

function Behaviour:Init()
end

function Behaviour:Update()
end

function Behaviour:GameEnd()
end

function Behaviour:UnitCreated(unit)
end

function Behaviour:UnitBuilt(unit)
end

function Behaviour:OwnerBuilt()
end

function Behaviour:UnitDead(unit)
end

function Behaviour:OwnerDead()
	return
end

function Behaviour:UnitDamaged(unit,attacker,damage)
end

function Behaviour:OwnerDamaged(attacker,damage)
end

function Behaviour:UnitIdle(unit)
end

function Behaviour:OwnerIdle()
end

function Behaviour:UnitMoveFailed(unit)
	self:UnitIdle(unit)
end

function Behaviour:OwnerMoveFailed()
	self:OwnerIdle()
end

function Behaviour:SetUnit(unit)
	self.unit = unit
	self.engineID = unit.engineID
end

function Behaviour:SetAI(ai)
	self.ai = ai
	self.game = ai.game
	self.map = ai.map
end


function Behaviour:IsActive()
	return self.active
end

function Behaviour:Activate()
	--
end

function Behaviour:Deactivate()
	--
end

function Behaviour:Priority()
	return 0
end

function Behaviour:Passive()
	return false
end

function Behaviour:Name()
	return 'Behaviour'
end

function Behaviour:EchoDebug(...)
	if self.DebugEnabled then
		self.game:SendToConsole(self.game:GetTeamID(), self:Name(), self.unit:Internal():Name(), self.unit:Internal():ID(), ...)
	end
end