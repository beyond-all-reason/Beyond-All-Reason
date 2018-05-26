shard_include( "attackers" )

function IsAttacker(unit)
	for i,name in ipairs(attackerlist) do
		if name == unit:Internal():Name() then
			return true
		end
	end
	return false
end

AttackerBehaviour = class(Behaviour)

function AttackerBehaviour:Init()
	--self.ai.game:SendToConsole("attacker!")
end

function AttackerBehaviour:OwnerBuilt()
	self.ai.attackhandler:AddRecruit(self)
	self.attacking = true
	self.active = true
end


function AttackerBehaviour:OwnerDead()
	self.ai.attackhandler:RemoveRecruit(self)
end

function AttackerBehaviour:OwnerIdle()
	self.attacking = true
	self.active = true
	self.ai.attackhandler:AddRecruit(self)
end

function AttackerBehaviour:AttackCell(cell)
	p = api.Position()
	p.x = cell.posx + math.random(0,1000) - math.random(0,1000)
	p.z = cell.posz + math.random(0,1000) - math.random(0,1000)
	p.y = 0
	self.target = p
	self.attacking = true
	self.ai.attackhandler:AddRecruit(self)
	if self.active then
		self.unit:Internal():MoveAndFire(self.target)
	else
		self.unit:ElectBehaviour()
	end
end

function AttackerBehaviour:Priority()
	if not self.attacking then
		return 0
	else
		return 100
	end
end

function AttackerBehaviour:Activate()
	self.active = true
	if self.target then
		self.unit:Internal():MoveAndFire(self.target)
		self.target = nil
		self.ai.attackhandler:AddRecruit(self)
	else
		self.ai.attackhandler:AddRecruit(self)
	end
end


function AttackerBehaviour:OwnerDied()
	self.ai.attackhandler:RemoveRecruit(self)
	self.attacking = nil
	self.active = nil
	self.unit = nil
end
