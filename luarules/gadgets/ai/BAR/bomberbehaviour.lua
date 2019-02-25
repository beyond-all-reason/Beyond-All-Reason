shard_include( "attackers" )

function IsBomber(unit)
	for i,name in ipairs(bomberlist) do
		if name == unit:Internal():Name() then
			return true
		end
	end
	return false
end

BomberBehaviour = class(Behaviour)

function BomberBehaviour:Init()
end

function BomberBehaviour:Update()
	if Spring.GetGameFrame() %30 == 0 then
		if self.target and not Spring.ValidUnitID(self.target) then
			self.target = nil
			self.unit:Internal():ExecuteCustomCommand(CMD.STOP, {}, {})
			self.ai.bomberhandler:AddRecruit(self)
		end
	end
end
		

	

function BomberBehaviour:DoPatrol(positions)
	if #positions > 1 then
		local ct = 0
		self.unit:Internal():ExecuteCustomCommand(CMD.STOP, {}, {})
		for i = 1,4 do
			local pos = positions[math.random(1,#positions)]
			self.unit:Internal():ExecuteCustomCommand(CMD.PATROL, {pos.x, pos.y, pos.z}, {"shift"})
		end
	end
end

function BomberBehaviour:OwnerBuilt()
	self.ai.bomberhandler:AddRecruit(self)
end


function BomberBehaviour:OwnerDead()
	self.ai.bomberhandler:RemoveRecruit(self)
end

function BomberBehaviour:OwnerIdle()
	self.ai.bomberhandler:AddRecruit(self)
end

function BomberBehaviour:AttackTarget(targetID)
	if Spring.ValidUnitID(targetID) then
		local x, y, z = Spring.GetUnitPosition(targetID)
		self.target = targetID
		self.ai.bomberhandler:RemoveRecruit(self)
		self.unit:Internal():ExecuteCustomCommand(CMD.ATTACK, {x, y, z}, {})
	end
end

function BomberBehaviour:Priority()
	return 100
end

function BomberBehaviour:Activate()
	self.active = true
	self.ai.bomberhandler:AddRecruit(self)
end


function BomberBehaviour:OwnerDied()
	self.ai.bomberhandler:RemoveRecruit(self)
	self.attacking = nil
	self.active = nil
	self.unit = nil
end
