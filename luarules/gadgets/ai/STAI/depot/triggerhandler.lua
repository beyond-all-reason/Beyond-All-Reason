TriggerHandler = class(Module)

function TriggerHandler:Name()
	return "TriggerHandler"
end

function TriggerHandler:internalName()
	return "triggerhandler"
end

function TriggerHandler:Init()

end

function TriggerHandler:Update()
	local frame = Spring.GetGameFrame()
	if frame%600 == (self.ai.id*15) then
		local x,y,z
		local comms = Spring.GetTeamUnitsByDefs(self.ai.id, {UnitDefNames.armcom.id, UnitDefNames.corcom.id})
		if comms[1] then
			x,y,z = Spring.GetUnitPosition(comms[1])
			self.commpos = {x = x, y = y, z = z}
			local CommSurrounding = Spring.GetUnitsInCylinder(self.commpos.x, self.commpos.z, 2000)
			for ct, uid in pairs(CommSurrounding) do
				if not Spring.GetUnitNeutral(uid) and not Spring.GetUnitIsBuilding(uid) and not Spring.AreTeamsAllied(Spring.GetUnitTeam(uid), self.ai.id) then
					ax,ay,az = Spring.GetUnitPosition(uid)
					self.CommAttackerPos = {x = ax, y = ay, z = az}
					self.CommInDanger = true
					break
				else
					self.CommAttackerPos = nil
					self.CommInDanger = false
				end
			end
		else
			self.CommAttackerPos = nil
			self.CommInDanger = false
		end
	end
end