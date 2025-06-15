BomberBST = class(Behaviour)

function BomberBST:Name()
	return "BomberBST"
end

function BomberBST:Init()
	self.DebugEnabled = false
	self.lastOrderFrame = self.game:Frame()
	self.name = self.unit:Internal():Name()
	self.id = self.unit:Internal():ID()
	self.mass = self.ai.armyhst.unitTable[self.name].metalCost
	if self.ai.armyhst.unitTable[self.name].submergedRange > 0 then
		self.weapon = "torpedo"
		self.hurts = "submerged"
		self.layer = 'S'
	else
		self.weapon = "bomb"
		self.hurts = "ground"
		self.layer = 'G'
	end
	self.homepos = self.ai.tool:UnitPos(self)
	self:EchoDebug("init", self.weapon)
	self:SetIdleMode()
	self.unit:ElectBehaviour()
end

function BomberBST:OwnerBuilt()
	self:EchoDebug("built")
 	self.ai.bomberhst:AddRecruit(self)
	self:SetIdleMode()
end

function BomberBST:OwnerDead()
	self:EchoDebug("dead")
	self.ai.bomberhst:RemoveRecruit(self)
end

function BomberBST:OwnerIdle()
	self:EchoDebug("idle")
end

function BomberBST:Priority()
	return 100
end

function BomberBST:Activate()
	self:EchoDebug("activate")
	self.active = true
	--if self.squad and self.ai.bomberhst.squads[self.squad] and self.ai.bomberhst.squads[self.squad].target then
	--	self:BombUnit(self.ai.bomberhst.squads[self.squad].targetUnit)
	--end
end

function BomberBST:Deactivate()
	self:EchoDebug("deactivate")
	self.active = false
	self.unit:Internal():Move(self.ai.tool:RandomAway( self.homepos, math.random(100,300))) -- you're drunk go home
	self.ai.tool:GiveOrderToUnit(self.unit:Internal(),CMD.MOVE, self.homepos, 0,'1-1')
end

--[[function BomberBST:Update()
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'BomberBST' then return end
self:EchoDebug('update squad',self.squad)
	if self.squad and self.ai.bomberhst.squads[self.squad] and self.ai.bomberhst.squads[self.squad].target then
		self:EchoDebug('update',self.squad,self.ai.bomberhst.squads[self.squad].target)
		self:EchoDebug('go to bomb',self.ai.bomberhst.squads[self.squad].target)
		self:BombUnit(self.ai.bomberhst.squads[self.squad].targetUnit)
	end
end]]

function BomberBST:BombPosition(position)
	self:EchoDebug("bomb position")
	--self.unit:Internal():Attack(position,32)
	self.ai.tool:GiveOrder(self.unit:Internal():ID(),CMD.ATTACK, position, 0,'1-1')
end



function BomberBST:SetIdleMode()
 	--self.unit:Internal():IdleModeFly()
	self.ai.tool:GiveOrder(self.unit:Internal():ID(),CMD.IDLEMODE, 1, 0,'1-1')

end

--[[function BomberBST:BombUnit(targetUnit)
	self:EchoDebug("bomb unit")
	--self.unit:Internal():Attack(targetUnit,32)
	self.ai.tool:GiveOrder(self.unit:Internal():ID(),CMD.ATTACK, targetUnit, 0,'1-1')
end

function BomberBST:BombTarget(targetUnit, path)
	self:EchoDebug("bomb target")
	if not self.unit or not self.unit:Internal() then
		self:EchoDebug("no unit or no engine unit")
		return
	end
	self:BombPosition(self.target.POS,32)
end]]