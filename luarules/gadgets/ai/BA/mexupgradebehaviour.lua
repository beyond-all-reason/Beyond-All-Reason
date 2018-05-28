MexUpgradeBehavior = class(Behaviour)


function MexUpgradeBehavior:Name()
	return "mexupgradebehavior"
end

function MexUpgradeBehavior:Init()
	--self.teamid = self.unit:Internal():Team()
	CMD_AUTOMEX = 31143 
	UDC = Spring.GetTeamUnitDefCount
	UDN = UnitDefNames
	mc, ms, mp, mi, me = Spring.GetTeamResources(self.ai.id, "metal")
	self.active = false
end

function MexUpgradeBehavior:OwnerBuilt()
	self.unit:Internal():ExecuteCustomCommand(CMD_AUTOMEX, {1}, {})
end

function MexUpgradeBehavior:Update()
	local unit = self.unit:Internal()
	local countT1mex = UDC(self.ai.id, UDN.cormex.id) + UDC(self.ai.id, UDN.corexp.id) + UDC(self.ai.id, UDN.armmex.id)
	local curQueue = Spring.GetUnitCommands(unit.id, 1)
	if countT1mex < 2 and not (#curQueue > 0) then
		self.unit:Internal():ExecuteCustomCommand(CMD_AUTOMEX, {0}, {})
		self.unit:ElectBehaviour()
	end
end

function MexUpgradeBehavior:Idle()
end

function MexUpgradeBehavior:Activate()
		self.active = true
end


function MexUpgradeBehavior:Deactivate()
		self.active = false
end

function MexUpgradeBehavior:Priority()
	local countT1mex = UDC(self.ai.id, UDN.cormex.id) + UDC(self.ai.id, UDN.corexp.id) + UDC(self.ai.id, UDN.armmex.id)
	if countT1mex < 2 then
		return 0
	else
		return 100
	end
end