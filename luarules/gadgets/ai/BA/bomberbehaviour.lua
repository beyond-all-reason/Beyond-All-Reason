ion IsBomber(unit)
	local tmpName = unit:Internal():Name()
	return (bomberList[tmpName] or 0) > 0
end

BomberBehaviour = class(Behaviour)

function BomberBehaviour:Init()
	self.lastOrderFrame = game:Frame()
	local mtype, network = ai.maphandler:MobilityOfUnit(self.unit:Internal())
	self.mtype = mtype
	self.name = self.unit:Internal():Name()
	if unitTable[self.name].submergedRange > 0 then
		self.weapon = "torpedo"
	else
		self.weapon = "bomb"
	end
end

function BomberBehaviour:UnitBuilt(unit)
	if unit.engineID == self.unit.engineID then
		self.bombing = false
		self.targetpos = nil
		ai.bomberhandler:AddRecruit(self)
	end
end

function BomberBehaviour:UnitDead(unit)
	if unit.engineID == self.unit.engineID then
		-- game:SendToConsole("bomber " .. self.name .. " died")
		ai.bomberhandler:RemoveRecruit(self)
		ai.bomberhandler:NeedMore()
		-- notify the command that area is too hot
		if self.targetpos then
			ai.targethandler:AddBadPosition(self.targetpos, self.mtype)
		end
	end
end

function BomberBehaviour:UnitIdle(unit)
	if unit.engineID == self.unit.engineID then
		self.bombing = false
		self.targetpos = nil
	end
end

function BomberBehaviour:BombPosition(position)
	local floats = api.vectorFloat()
	-- populate with x, y, z of the position
	floats:push_back(position.x)
	floats:push_back(position.y)
	floats:push_back(position.z)
	self.unit:Internal():ExecuteCustomCommand(CMD_ATTACK, floats)
end

function BomberBehaviour:BombTarget(target)
	if not self.unit or not self.unit:Internal() then
		return
	end
	if target ~= nil then
		local pos = target.position
		if pos ~= nil then
			self.target = target.unitID
			self.bombing = true
			self.lastOrderFrame = game:Frame()
			if self.active then
				self:BombPosition(pos)
				self.targetpos = pos
			end
		else
			self.unit:ElectBehaviour()
		end
	else
		self.bombing = false
		self.unit:ElectBehaviour()
	end
end

function BomberBehaviour:Priority()
	if not self.bombing then
		return 0
	else
		return 100
	end
end

function BomberBehaviour:Activate()
	self.active = true
	if self.target then
		self.lastOrderFrame = game:Frame()
		CustomCommand(self.unit:Internal(), CMD_ATTACK, {self.target})
		self.target = nil
		self.targetpos = nil
	else
		ai.bomberhandler:AddRecruit(self)
		self.targetpos = nil
	end
end

function BomberBehaviour:Deactivate()
	self.active = false
end

function BomberBehaviour:Update()
	-- retargeting trigger
	-- if the unit is already in recruit lists, do nothing
	if ai.bomberhandler:IsRecruit(self) then
		return
	end
	local tmpFrame = game:Frame()
	if (self.lastOrderFrame or 0) + 900 < tmpFrame then
		ai.bomberhandler:AddRecruit(self)
		self.targetpos = nil
	end
end