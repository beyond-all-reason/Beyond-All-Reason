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
end

function MexUpgradeBehavior:OwnerBuilt()

end

function MexUpgradeBehavior:Update()
	local countT1mex = UDC(self.teamid, UDN.cormex.id) + UDC(self.teamid, UDN.corexp.id) + UDC(self.teamid, UDN.armmex.id) + UDC(self.teamid, UDN.armamex.id)
	if countT1mex == 0 then
		self.unit:ElectBehaviour()
	end
end


function MexUpgradeBehavior:Activate()
		unit = self.unit:Internal()
		unit:ExecuteCustomCommand(CMD_AUTOMEX)
		self.active = true
end


function MexUpgradeBehavior:Deactivate()
		self.active = false
end

function MexUpgradeBehavior:Priority()
	local countT1mex = UDC(self.teamid, UDN.cormex.id) + UDC(self.teamid, UDN.corexp.id) + UDC(self.teamid, UDN.armmex.id) + UDC(self.teamid, UDN.armamex.id)
	if countT1mex == 0 then
		return 0
	else
		return 55
	end
end