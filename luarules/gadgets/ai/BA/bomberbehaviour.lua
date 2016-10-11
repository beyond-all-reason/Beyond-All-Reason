function IsBomber(unit)
	local tmpName = unit:Internal():Name()
	return (bomberList[tmpName] or 0) > 0
end

BomberBehaviour = class(Behaviour)

function BomberBehaviour:Name()
	return "BomberBehaviour"
end

local CMD_MOVE = 10
local CMD_OPT_SHIFT = 32
local CMD_OPT_RIGHT = 16
local CMD_INSERT = 1
local CMD_IDLEMODE = 145
local IDLEMODE_LAND = 1
local IDLEMODE_FLY = 0

function BomberBehaviour:Init()
	self.DebugEnabled = false

	self.lastOrderFrame = game:Frame()
	self.name = self.unit:Internal():Name()
	if unitTable[self.name].submergedRange > 0 then
		self.weapon = "torpedo"
		self.hurts = "submerged"
	else
		self.weapon = "bomb"
		self.hurts = "ground"
	end
	self.homepos = self.unit:Internal():GetPosition()
	self:EchoDebug("init", self.weapon)
	self:SetIdleMode()
end

function BomberBehaviour:OwnerBuilt()
	self:EchoDebug("built")
	ai.bomberhandler:AddRecruit(self)
end

function BomberBehaviour:OwnerDead()
	self:EchoDebug("dead")
	-- game:SendToConsole("bomber " .. self.name .. " died")
	ai.bomberhandler:RemoveRecruit(self)
	ai.bomberhandler:NeedMore()
	-- notify the command that area is too hot
	if self.target then
		local tpos = self.target:GetPosition()
		if tpos and tpos.x then
			ai.targethandler:AddBadPosition(tpos, 'air')
		end
	end
end

function BomberBehaviour:OwnerIdle()
	self:EchoDebug("idle")
	self.target = nil
	self.ai.bomberhandler:AddRecruit(self)
end

function BomberBehaviour:Priority()
	if self.target then
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
		if self.path then
			self:FollowPathToTarget(self.path, self.target)
		else
			self:BombUnit(self.target)
		end
	else
		ai.bomberhandler:AddRecruit(self)
	end
end

function BomberBehaviour:Deactivate()
	self:EchoDebug("deactivate")
	self.active = false
	self.unit:Internal():Move(RandomAway(self.homepos, math.random(100,300))) -- you're drunk go home
end

function BomberBehaviour:Update()
	if not self.lastOrderFrame then
		return
	end
	if game:Frame() > self.lastOrderFrame + 1000 then
		self.lastOrderFrame = nil
		self:OwnerIdle()
	end
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

function BomberBehaviour:FollowPathToTarget(path, unit)
	self:EchoDebug("follow path to target")
	-- self.unit:Internal():Move(path[2].position)
	local optFloats = api.vectorFloat()
	optFloats:push_back("alt")
	local firstMoved, secondMoved
	local myPos = self.unit:Internal():GetPosition()
	for i = 1, #path do
		local cmdPos
		local cmdID
		local cmdPos = path[i].position
		if secondMoved or DistanceSq(cmdPos, myPos) > 1210000 then
			if firstMoved then
				local floats = api.vectorFloat()
				-- floats:push_back(-1)
				-- floats:push_back(CMD_MOVE)
				-- floats:push_back(CMD_OPT_SHIFT)
				floats:push_back(cmdPos.x)
				floats:push_back(cmdPos.y)
				floats:push_back(cmdPos.z)
				-- self.unit:Internal():ExecuteCustomCommand(CMD_INSERT, floats, optFloats)
				self.unit:Internal():ExecuteCustomCommand(CMD_MOVE, floats, {"shift"})
				secondMoved = true
			else
				self.unit:Internal():Move(cmdPos)
				firstMoved = true
			end
		end
	end
	local floats = api.vectorFloat()
	-- floats:push_back(-1)
	-- floats:push_back(CMD_ATTACK)
	-- floats:push_back(CMD_OPT_SHIFT)
	floats:push_back(unit:ID())
	-- self.unit:Internal():ExecuteCustomCommand(CMD_INSERT, floats, optFloats)
	self.unit:Internal():ExecuteCustomCommand(CMD_ATTACK, floats, {"shift"})
end

   -- Spring.GiveOrderToUnit(unitID,
   --   CMD.INSERT,
   --   {-1,CMD.ATTACK,CMD.OPT_SHIFT,unitID2},
   --   {"alt"}
   -- );

function BomberBehaviour:BombUnit(unit)
	self:EchoDebug("bomb unit")
	self.unit:Internal():Attack(unit)
end

function BomberBehaviour:BombTarget(targetUnit, path)
	self:EchoDebug("bomb target")
	if not self.unit or not self.unit:Internal() then
		self:EchoDebug("no unit or no engine unit")
		return
	end
	if not targetUnit then
		self:EchoDebug("no target given to :BombTarget")
		self.ai.bomberhandler:AddRecruit(self)
		return
	end
	self.target = targetUnit
	self.path = path
	if self.active then
		self.lastOrderFrame = game:Frame()
		if path then
			self:FollowPathToTarget(path, targetUnit)
		else
			self:BombUnit(targetUnit)
		end
	end
	self.unit:ElectBehaviour()
end

function BomberBehaviour:SetIdleMode()
	local floats = api.vectorFloat()
	floats:push_back(IDLEMODE_FLY)
	self.unit:Internal():ExecuteCustomCommand(CMD_IDLEMODE, floats)
end