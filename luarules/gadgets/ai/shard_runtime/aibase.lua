
AIBase = class(function(a)
   --
end)


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