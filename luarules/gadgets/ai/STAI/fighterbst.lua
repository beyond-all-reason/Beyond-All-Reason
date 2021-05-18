shard_include( "attackers")

-- function IsFighter(unit) TODO maybe this file is not STAI related, not bad idea but need implementation
-- 	for i,name in ipairs(fighterlist) do
-- 		if name == unit:Internal():Name() then
-- 			return true
-- 		end
-- 	end
-- 	return false
-- end

FighterBST = class(Behaviour)

function FighterBST:Init()
end

function FighterBST:DoPatrol(positions)
	if #positions > 1 then
		local ct = 0
		self.unit:Internal():ExecuteCustomCommand(CMD.STOP, {}, {})
		for i = 1,4 do
			local pos = positions[math.random(1,#positions)]
			self.unit:Internal():ExecuteCustomCommand(CMD.PATROL, {pos.x, pos.y, pos.z}, {"shift"})
		end
	end
end

function FighterBST:OwnerBuilt()
	self.ai.fighterhst:AddRecruit(self)
end


function FighterBST:OwnerDead()
	self.ai.fighterhst:RemoveRecruit(self)
end

function FighterBST:OwnerIdle()
	self.ai.fighterhst:AddRecruit(self)
end

function FighterBST:FightCell(pos)
	self.ai.fighterhst:RemoveRecruit(self)
	self.unit:Internal():MoveAndFire(pos)
end

function FighterBST:Priority()
	return 100
end

function FighterBST:Activate()
	self.active = true
	self.ai.fighterhst:AddRecruit(self)
end


function FighterBST:OwnerDied()
	self.ai.fighterhst:RemoveRecruit(self)
	self.attacking = nil
	self.active = nil
	self.unit = nil
end
