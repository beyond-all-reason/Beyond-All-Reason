
AIBase = class(function(a)
   --
end)

function AIBase:Name()
	return 'error no name defined'
end

-- overriding this is mandatory
function AIBase:internalName()
	return "error"
end

function AIBase:Init()
end

function AIBase:Update()
end

function AIBase:GameEnd()
end

function AIBase:GameMessage(text)
end

function AIBase:UnitCreated(engineunit)
end

function AIBase:UnitBuilt(engineunit)
	if engineunit:IsMine( self.game:GetTeamID() ) then
		self:MyUnitBuilt(engineunit)
	elseif engineunit:IsFriendly( self.game:GetAllyTeamID() ) then
		self:FriendlyUnitBuilt(engineunit)
	elseif engineunit:IsEnemy( self.game:GetAllyTeamID() ) then
		self:EnemyUnitBuilt(engineunit)
	elseif engineunit:isNeutral() then
		self:NeutralUnitBuilt(engineunit)
	end
end

function AIBase:MyUnitBuilt(engineunit)
end

function AIBase:FriendlyUnitBuilt(engineunit)
end

function AIBase:EnemyUnitBuilt(engineunit)
end

function AIBase:NeutralUnitBuilt(engineunit)
end

function AIBase:UnitGiven(engineunit)
	self:UnitCreated(engineunit)
	self:UnitBuilt(engineunit)
end


function AIBase:UnitDead(engineunit)
end

function AIBase:UnitIdle(engineunit)
end

function AIBase:UnitDamaged(engineunit,enginedamage)
end

function AIBase:UnitMoveFailed(engineunit)
end

function AIBase:SetAI(ai)
	self.ai = ai
	self.game = ai.game
	self.map = ai.map
end

function AIBase:Warn(...)
	self.game:SendToConsole(self.game:GetTeamID(), self:Name(), 'Warning: ', ...)
end

function AIBase:Info(...)
	self.game:SendToConsole(self.game:GetTeamID(), self:Name(), 'Info: ', ...)
end

function AIBase:EchoDebug(...)
	if self.DebugEnabled then
		self.game:SendToConsole(self.game:GetTeamID(), self:Name(), 'Debug: ',...)
	end
end
