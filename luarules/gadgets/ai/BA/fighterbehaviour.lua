shard_include( "attackers" )

function IsFighter(unit)
	for i,name in ipairs(fighterlist) do
		if name == unit:Internal():Name() then
			return true
		end
	end
	return false
end

FighterBehaviour = class(Behaviour)

function FighterBehaviour:Init()
end

function FighterBehaviour:DoPatrol(positions)
	if #positions > 1 then
		local ct = 0
		self.unit:Internal():ExecuteCustomCommand(CMD.STOP, {}, {})
		for i = 1,4 do
			local pos = positions[math.random(1,#positions)]
			self.unit:Internal():ExecuteCustomCommand(CMD.PATROL, {pos.x, pos.y, pos.z}, {"shift"})
		end
	end
end

function FighterBehaviour:OwnerBuilt()
	self.ai.fighterhandler:AddRecruit(self)
end


function FighterBehaviour:OwnerDead()
	self.ai.fighterhandler:RemoveRecruit(self)
end

function FighterBehaviour:OwnerIdle()
	self.ai.fighterhandler:AddRecruit(self)
end

function FighterBehaviour:FightCell(pos)
	self.ai.fighterhandler:RemoveRecruit(self)
	self.unit:Internal():MoveAndFire(pos)
end

function FighterBehaviour:Priority()
	return 100
end

function FighterBehaviour:Activate()
	self.active = true
	self.ai.fighterhandler:AddRecruit(self)
end


function FighterBehaviour:OwnerDied()
	self.ai.fighterhandler:RemoveRecruit(self)
	self.attacking = nil
	self.active = nil
	self.unit = nil
end
