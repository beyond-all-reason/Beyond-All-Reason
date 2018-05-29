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

local function Distance(x1,z1, x2,z2)
	local vectx = x2 - x1
	local vectz = z2 - z1
	local dis = math.sqrt(vectx^2+vectz^2)
	return dis
end

local function GetClosestNanotc(unitID)
	local teamID = Spring.GetUnitTeam(unitID)
	local ux, uy, uz = Spring.GetUnitPosition(unitID)
	local bestID
	local mindis = 800
	for ct, uid in pairs (Spring.GetUnitsInCylinder(ux, uz, 800, teamID)) do
		if UnitDefs[Spring.GetUnitDefID(uid)].name == "armnanotc" then
			local gx, gy, gz = Spring.GetUnitPosition(uid)
			if Distance(ux, uz, gx, gz) < mindis then
				bestID = uid
			end
		end
	end
	local bestx, besty, bestz
	if bestID then
		bestx, besty, bestz = Spring.GetUnitPosition(bestID)
	end
	return bestx, besty, bestz
end

function AttackerBehaviour:Update()
	local unitID = self.unit:Internal().id
	-- Spring.Echo(unitID)
	local myRange = Spring.GetUnitMaxRange(unitID)
	local closestUnit = Spring.GetUnitNearestEnemy(unitID, myRange)
	local allyTeamID = self.ai.allyId
	if unitID % 30 == Spring.GetGameFrame() % 30 then
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
				self.unit:Internal():ExecuteCustomCommand(CMD.MOVE, {cx, cy, cz}, {"ctrl"})
			end
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
			if unit:Name() == "Rector" or "Necro" then
				unit:ExecuteCustomCommand(CMD.FIGHT, {p.x, p.y, p.z}, {"alt"})
			else
				unit:MoveAndFire(self.target)
			end
		else
			self.unit:ElectBehaviour()
		end
	--retreat
	else	
	local unitID = self.unit:Internal().id
	local nanotcx, nanotcy, nanotcz = GetClosestNanotc(unitID)
		if nanotcx and nanotcy and nanotcz then
			p = api.Position()
			p.x, p.y, p.z = nanotcx, nanotcy, nanotcz
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
		end
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
