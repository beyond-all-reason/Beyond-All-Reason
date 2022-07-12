BomberBST = class(Behaviour)

function BomberBST:Name()
	return "BomberBST"
end
--[[
local CMD_MOVE = 10
local CMD_OPT_SHIFT = 32
local CMD_OPT_RIGHT = 16
local CMD_INSERT = 1
local CMD_IDLEMODE = 145
local IDLEMODE_LAND = 1
local IDLEMODE_FLY = 0]]

function BomberBST:Init()
	self.DebugEnabled = false

	self.lastOrderFrame = self.game:Frame()
	self.name = self.unit:Internal():Name()
	if self.ai.armyhst.unitTable[self.name].submergedRange > 0 then
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

function BomberBST:OwnerBuilt()
	self:EchoDebug("built")
	self.ai.bomberhst:AddRecruit(self)
end

function BomberBST:OwnerDead()
	self:EchoDebug("dead")
	-- game:SendToConsole("bomber " .. self.name .. " died")
	self.ai.bomberhst:RemoveRecruit(self)
	self.ai.bomberhst:NeedMore()
	-- notify the command that area is too hot
	if self.target then
		local tpos = self.target:GetPosition()
		if tpos and tpos.x then
			self.ai.targethst:AddBadPosition(tpos, 'air')
		end
	end
end

function BomberBST:OwnerIdle()
	self:EchoDebug("idle")
	self.target = nil
	self.ai.bomberhst:AddRecruit(self)
end

function BomberBST:Priority()
	if self.target then
		return 100
	else
		return 0
	end
end

function BomberBST:Activate()
	self:EchoDebug("activate")
	self.active = true
	if self.target then
		self.lastOrderFrame = self.game:Frame()
		if self.path then
			self:FollowPathToTarget(self.path, self.target)
		else
			self:BombUnit(self.target)
		end
	else
		self.ai.bomberhst:AddRecruit(self)
	end
end

function BomberBST:Deactivate()
	self:EchoDebug("deactivate")
	self.active = false
	self.unit:Internal():Move(self.ai.tool:RandomAway( self.homepos, math.random(100,300))) -- you're drunk go home
end

function BomberBST:Update()
	 --self.uFrame = self.uFrame or 0
	--if f - self.uFrame < self.ai.behUp['bomberbst']then
	--	return
	--end
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'BomberBST' then return end
	self.uFrame = f
end

function BomberBST:BombPosition(position)
	self:EchoDebug("bomb position")
-- 	local floats = api.vectorFloat()
-- 	-- populate with x, y, z of the position
-- 	floats:push_back(position.x)
-- 	floats:push_back(position.y)
-- 	floats:push_back(position.z)
	self.unit:Internal():Attack(position,20) -- TEST
end

function BomberBST:FollowPathToTarget(path, targetUnit)
	--[[
	self:EchoDebug("follow path to target")
	-- self.unit:Internal():Move(path[2].position)
-- 	local optFloats = api.vectorFloat()
-- 	optFloats:push_back("alt")
	local firstMoved, secondMoved
	local myPos = self.unit:Internal():GetPosition()
	for i = 1, #path do
		local cmdPos
		local cmdID
		local cmdPos = path[i].position
		if secondMoved or self.ai.tool:DistanceSq(cmdPos, myPos) > 1210000 then
			if firstMoved then
-- 				local floats = api.vectorFloat()
-- 				floats:push_back(cmdPos.x)
-- 				floats:push_back(cmdPos.y)
-- 				floats:push_back(cmdPos.z)
				-- self.unit:Internal():ExecuteCustomCommand(CMD_INSERT, floats, optFloats)
				self.unit:Internal():Move(cmdPos)
				--self.unit:Internal():ExecuteCustomCommand(CMD_MOVE, floats, {"shift"})
				secondMoved = true
			else
				self.unit:Internal():Move(cmdPos)
				firstMoved = true
			end
		end
	end
	self.unit:Internal():Attack(targetUnit,20)--TODO set this better
	]]
end

function BomberBST:BombUnit(targetUnit)
	self:EchoDebug("bomb unit")
	local p = targetUnit:GetPosition()
	self.unit:Internal():Attack(targetUnit,20)
end

function BomberBST:BombTarget(targetUnit, path)
	self:EchoDebug("bomb target")
	if not self.unit or not self.unit:Internal() then
		self:EchoDebug("no unit or no engine unit")
		return
	end
	if not targetUnit then
		self:EchoDebug("no target given to :BombTarget")
		self.ai.bomberhst:AddRecruit(self)
		return
	end
	self.target = targetUnit
	self.path = path
	if self.active then
		self.lastOrderFrame = self.game:Frame()
		if path then
			self:FollowPathToTarget(path, targetUnit)
		else
			self:BombUnit(targetUnit)
		end
	end
	self.unit:ElectBehaviour()
end

function BomberBST:SetIdleMode()
-- 	local floats = api.vectorFloat()
-- 	floats:push_back(IDLEMODE_FLY)
-- 	self.unit:Internal():ExecuteCustomCommand(CMD_IDLEMODE, floats)
-- 	self.unit:Internal():IdleModeFly()
end
