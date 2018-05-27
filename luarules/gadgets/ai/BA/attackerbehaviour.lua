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
	--self.game:AddMarker({ x = startPosx, y = startPosy, z = startPosz }, "my start position")
	CMD.MOVE_STATE = 50
end

function AttackerBehaviour:Update()
	local unitID = self.unit:Internal().id
	-- Spring.Echo(unitID)
	local myRange = Spring.GetUnitMaxRange(unitID)
	local closestUnit = Spring.GetUnitNearestEnemy(unitID, myRange)
	local allyTeamID = self.ai.allyId
	if closestUnit and (Spring.IsUnitInLos(closestUnit, allyTeamID)) then
		local enemyRange = Spring.GetUnitMaxRange(closestUnit)
		if myRange > enemyRange then
			local ex,ey,ez = Spring.GetUnitPosition(closestUnit)
			local ux,uy,uz = Spring.GetUnitPosition(unitID)
			local pointDis = Spring.GetUnitSeparation(unitID,closestUnit)
			local dis = 120
			local f = dis/pointDis
			if (pointDis+dis > Spring.GetUnitMaxRange(unitID)) then
			  f = (Spring.GetUnitMaxRange(unitID)-pointDis)/pointDis
			end
			local cx = ux+(ux-ex)*f
			local cy = uy
			local cz = uz+(uz-ez)*f
			self.unit:Internal():ExecuteCustomCommand(CMD.MOVE, {cx, cy, cz})
		end
	end
end

function AttackerBehaviour:OwnerBuilt()
	self.ai.attackhandler:AddRecruit(self)
	self.unit:Internal():ExecuteCustomCommand(CMD.MOVE_STATE, { 2 }, {})
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
	local unit = self.unit:Internal()
	local currenthealth = unit:GetHealth()
	local maxhealth = unit:GetMaxHealth()
	local startPosx, startPosy, startPosz = Spring.GetTeamStartPosition(self.ai.id)
	local startBoxMinX, startBoxMinZ, startBoxMaxX, startBoxMaxZ = Spring.GetAllyTeamStartBox(self.ai.allyId)
	local ec, es = Spring.GetTeamResources(ai.id, "energy")
	--attack
	if currenthealth >= maxhealth - maxhealth * 0.2 or currenthealth > 3000 then
		p = api.Position()
		p.x = cell.posx
		p.z = cell.posz
		p.y = 0
		self.target = p
		self.attacking = true
		self.ai.attackhandler:AddRecruit(self)
		if self.active then
			self.unit:Internal():MoveAndFire(self.target)
		else
			self.unit:ElectBehaviour()
		end
	--retreat
	else
		if startBoxMinX == 0 and startBoxMinZ == 0 and startBoxMaxZ == Game.mapSizeZ and startBoxMaxX == Game.mapSizeX then
			p = api.Position()
			p.x = startPosx
			p.z = startPosz
		else
			p = api.Position()
			p.x = math.random(startBoxMinX, startBoxMaxX)
			p.z = math.random(startBoxMinZ, startBoxMaxZ)
		end
		
		p.y = startPosy
		self.target = p
		self.attacking = false
		self.ai.attackhandler:AddRecruit(self)
		if self.active then
			self.unit:Internal():Move(self.target)
		else
			self.unit:ElectBehaviour()
		end
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
