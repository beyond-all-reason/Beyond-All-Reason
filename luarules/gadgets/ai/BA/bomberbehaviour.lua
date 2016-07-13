ion IsBomber(unit)
	local tmpName = unit:Internal():Name()
	return (bomberList[tmpName] or 0) > 0
end

BomberBehaviour = class(Behaviour)

function BomberBehaviour:Name()
	return "BomberBehaviour"
end

function BomberBehaviour:Init()
	self.DebugEnabled = false

	self.lastOrderFrame = game:Frame()
	local mtype, network = ai.maphandler:MobilityOfUnit(self.unit:Internal())
	self.mtype = mtype
	self.name = self.unit:Internal():Name()
	if unitTable[self.name].submergedRange > 0 then
		self.weapon = "torpedo"
	else
		self.weapon = "bomb"
	end
	self.homepos = self.unit:Internal():GetPosition()
	self:EchoDebug("init", self.weapon)
end

function BomberBehaviour:OwnerBuilt()
	self.bombing = false
	self.targetpos = nil
	self:EchoDebug("built")
	ai.bomberhandler:AddRecruit(self)
end

function BomberBehaviour:OwnerDead()
	-- game:SendToConsole("bomber " .. self.name .. " died")
	ai.bomberhandler:RemoveRecruit(self)
	ai.bomberhandler:NeedMore()
	-- notify the command that area is too hot
	if self.targetpos then
		ai.targethandler:AddBadPosition(self.targetpos, self.mtype)
	end
end

function BomberBehaviour:OwnerIdle()
	self:EchoDebug("idle")
	self.bombing = false
	self.targetpos = nil
end

function BomberBehaviour:BombPosition(position)
	self:EchoDebug("bomb position")
	local floats = api.vectorFloat()
	-- populate with x, y, z of the position
	floats:push_back(position.x)
	floats:push_back(position.y)
	floats:push_back(position.z)
	self.unit:Internal():ExecuteCustomCommand(CMD_ATTACK, floats)
end

function BomberBehaviour:BombTarget(target)
	self:EchoDebug("bomb target")
	if not self.unit or not self.unit:Internal() then
		self:EchoDebug("no unit or no engine unit")
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
		end
	else
		self.bombing = false
	end
	self.unit:ElectBehaviour()
end

function BomberBehaviour:Priority()
	if self.bombing then
		return 100
	else
		return 0
	end
end

function BomberBehaviour:Activate()
	self:EchoDebug("activate")
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
	self:EchoDebug("deactivate")
	self.active = false
	self.unit:Internal():Move(RandomAway(self.homepos, math.random(100,300))) -- you're drunk go home
end

function BomberBehaviour:Update()
	-- retargeting trigger
	-- if the unit is already in recruit lists, do nothing
	if ai.bomberhandler:IsRecruit(self) then
		return
	end
	local tmpFrame = game:Frame()
	if (self.lastOrderFrame or 0) + 450 < tmpFrame then
		ai.bomberhandler:AddRecruit(self)
		self.targetpos = nil
		self.bombing = false
	end
end