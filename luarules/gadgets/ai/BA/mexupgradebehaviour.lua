MexUpgradeBehavior = class(Behaviour)


function MexUpgradeBehavior:Name()
	return "mexupgradebehavior"
end

function MexUpgradeBehavior:Init()
	self.teamid = self.unit:Internal():Team()
	CMD_UPGRADEMEX = 31244 
	UDC = Spring.GetTeamUnitDefCount
	UDN = UnitDefNames
	mc, ms, mp, mi, me = Spring.GetTeamResources(self.teamid, "metal")
	self.active = false
end

function MexUpgradeBehavior:OwnerBuilt()

end

function MexUpgradeBehavior:Update()
	local unit = self.unit:Internal()
	local countT1mex = UDC(self.teamid, UDN.cormex.id) + UDC(self.teamid, UDN.corexp.id) + UDC(self.teamid, UDN.armmex.id) + UDC(self.teamid, UDN.armamex.id)
	if countT1mex == 0 then
		unit:ExecuteCustomCommand(CMD_UPGRADEMEX, {'UpgMex OFF'}, {})
		self.unit:ElectBehaviour()
	else
		unit:ExecuteCustomCommand(CMD_UPGRADEMEX, {'UpgMex ON'}, {})
	end
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
		return 0
	else
		return 100
	end
end