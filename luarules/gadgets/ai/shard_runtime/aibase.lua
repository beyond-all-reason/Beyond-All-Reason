
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

function AIBase:UnitCreated(unit, unitDefId, teamId, builderId)
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

function AIBase:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
end

function AIBase:UnitLeftLos(unitID, unitTeam, allyTeam, unitDefID)
end

function AIBase:UnitEnteredRadar(unitID, unitTeam, allyTeam, unitDefID)
end

function AIBase:UnitLeftRadar(unitID, unitTeam, allyTeam, unitDefID)
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

if tracy  then 
	Spring.Echo("Enabled Tracy support for AIBase")
	AIBase.lastGCinfo = 0
	local logRAM = true
	--local function tracyZoneBeginMem() return end
	--local function tracyZoneEndMem() return end
	function AIBase:tracyZoneBeginN (fname) tracy.ZoneBeginN(self:Name() .. ":".. fname) end 
	function AIBase:tracyZoneEnd() tracy.ZoneEnd() end 
	
	function AIBase:tracyZoneBeginMem()
		if logRAM then lastGCinfo = gcinfo() end 
		tracy.ZoneBeginN(fname)
	end
	
	function AIBase:tracyZoneEndMem () 
		if logRAM then 
			local nowGCinfo = gcinfo() 
			local delta = nowGCinfo - lastGCinfo
			if delta > 0 then 
				tracy.Message(tostring(nowGCinfo - lastGCinfo))
			end
			lastGCinfo = nowGCinfo
		end
		tracy.ZoneEnd()
	end
end
