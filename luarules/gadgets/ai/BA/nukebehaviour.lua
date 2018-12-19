local CMD_STOCKPILE = 100

NukeBehaviour = class(Behaviour)

function NukeBehaviour:Init()
	self.stockpiler = UnitDefs[UnitDefNames[self.unit:Internal():Name()].id].canStockpile
end

function NukeBehaviour:Update()
	if Spring.GetGameFrame() % 120 == 0 then
		if self.stockpiler then
			local curStocked,curStockQ = Spring.GetUnitStockpile(self.unit:Internal().id)
			if curStockQ < 2 then
				self.unit:Internal():ExecuteCustomCommand(CMD_STOCKPILE)
			end
			if curStocked > 0 then
				if not self.target then
					self.target = GG.AiHelpers.TargetsOfInterest.Nuke(self.ai.id)
				end
				if self.target then
					if not Spring.ValidUnitID(self.target) then
						self.target = nil
						self.unit:Internal():ExecuteCustomCommand(CMD.STOP, {}, {})
					else
						local x,y,z = Spring.GetUnitPosition(self.target)
						self.unit:Internal():ExecuteCustomCommand(CMD.ATTACK, {x,y,z}, {})
					end
				end
			end
		end
	end
end

function NukeBehaviour:OwnerBuilt()

end

function NukeBehaviour:OwnerDead()

end

function NukeBehaviour:Priority()
	return 100
end

function NukeBehaviour:Activate()
	self.active = true
end


function NukeBehaviour:OwnerDied()
	self.active = nil
	self.unit = nil
end
