MexUpgradeBehavior = class(Behaviour)


function MexUpgradeBehavior:Name()
	return "mexupgradebehavior"
end

function MexUpgradeBehavior:Init()
	self.teamid = self.unit:Internal():Team()
	CMD_AUTOMEX = 31143 
	UDC = Spring.GetTeamUnitDefCount
	UDN = UnitDefNames
	mc, ms, mp, mi, me = Spring.GetTeamResources(self.teamid, "metal")
	self.active = false
	self.unit:Internal():ExecuteCustomCommand(CMD_AUTOMEX, {1}, {})
end

function MexUpgradeBehavior:OwnerBuilt()

end

function MexUpgradeBehavior:Update()
	local unit = self.unit:Internal()
	local countT1mex = UDC(self.teamid, UDN.cormex.id) + UDC(self.teamid, UDN.corexp.id) + UDC(self.teamid, UDN.armmex.id) + UDC(self.teamid, UDN.armamex.id)
	local curQueue = Spring.GetUnitCommands(unit.id, 1)
	if countT1mex == 0 and not (#curQueue > 0) then
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
	local countT1mex = UDC(self.teamid, UDN.cormex.id) + UDC(self.teamid, UDN.corexp.id) + UDC(self.teamid, UDN.armmex.id) + UDC(self.teamid, UDN.armamex.id)
	if countT1mex == 0 then
		self.unit:Internal():ExecuteCustomCommand(CMD_AUTOMEX, {0}, {})
		return 0
	else
		return 100
	end
end