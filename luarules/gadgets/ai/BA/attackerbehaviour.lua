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
	CMD.FIRE_STATE = 45
end

local function Distance(x1,z1, x2,z2)
	local vectx = x2 - x1
	local vectz = z2 - z1
	local dis = math.sqrt(vectx^2+vectz^2)
	return dis
end

function AttackerBehaviour:Update()

end

function AttackerBehaviour:OwnerBuilt()
	self.ai.attackhandler:AddRecruit(self)
	self.unit:Internal():ExecuteCustomCommand(CMD.MOVE_STATE, { 2 }, {})
	self.unit:Internal():ExecuteCustomCommand(CMD.FIRE_STATE, { 2 }, {})
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

function AttackerBehaviour:AttackCell()
	local unit = self.unit:Internal()
	local unitID = unit.id
	-- Spring.Echo(unitID)
	local myRange = Spring.GetUnitMaxRange(unitID)
	local closestUnit = Spring.GetUnitNearestEnemy(unitID, myRange)
	local allyTeamID = self.ai.allyId
	local currenthealth = unit:GetHealth()
	local maxhealth = unit:GetMaxHealth()
	local startPosx, startPosy, startPosz = Spring.GetTeamStartPosition(ai.id)
	local startBoxMinX, startBoxMinZ, startBoxMaxX, startBoxMaxZ = Spring.GetAllyTeamStartBox(allyTeamID)
	local utype = self.game:GetTypeByName(unit:Name())
	-- Skirmishing
	if (not utype:CanFly() == true) and unitID % 30 == Spring.GetGameFrame() % 30 then
		if closestUnit and (Spring.IsUnitInLos(closestUnit, allyTeamID)) and (currenthealth >= maxhealth*0.75 or currenthealth > 3000) then
			local enemyRange = Spring.GetUnitMaxRange(closestUnit)
			if myRange*0.9 > enemyRange and enemyRange > 50 and enemyRange ~= nil then
				local moverandom = math.random(0,2)
				if moverandom == 0 then
					self.unit:Internal():ExecuteCustomCommand(CMD.MOVE_STATE, { 0 }, {})
				elseif moverandom == 1 then
					self.unit:Internal():ExecuteCustomCommand(CMD.MOVE_STATE, { 1 }, {})
				else
					self.unit:Internal():ExecuteCustomCommand(CMD.MOVE_STATE, { 2 }, {})
				end
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
	
	-- Attacking
	if unitID % 150 == Spring.GetGameFrame() % 150 then
		local TeamID = ai.id
		local allyTeamID = ai.allyId
		local nearestVisibleUnit = Spring.GetUnitNearestEnemy(unitID, _, true)
		local nearestUnit = Spring.GetUnitNearestEnemy(unitID, _, false)
		if nearestUnit and not Spring.IsUnitInRadar(nearestUnit, allyTeamID) then
			nearestUnit = nil
		else
			nearestVisibleUnit = nearestUnit
		end
		--local nearestVisibleUnit = Spring.GetUnitNearestEnemy(unitID, _, true)
		local ec, es = Spring.GetTeamResources(ai.id, "energy")
		--attack
		if (currenthealth >= maxhealth*0.75 or currenthealth > 3000)  then
				local moverandom = math.random(0,2)
				if moverandom == 0 then
					self.unit:Internal():ExecuteCustomCommand(CMD.MOVE_STATE, { 0 }, {})
				elseif moverandom == 1 then
					self.unit:Internal():ExecuteCustomCommand(CMD.MOVE_STATE, { 1 }, {})
				else
					self.unit:Internal():ExecuteCustomCommand(CMD.MOVE_STATE, { 2 }, {})
				end
				--if nearestVisibleUnit == nil then
				if nearestVisibleUnit then
					enemyposx, enemyposy, enemyposz = Spring.GetUnitPosition(nearestVisibleUnit)
				else
					enemyposx = math.random(0,Game.mapSizeX)
					enemyposz = math.random(0,Game.mapSizeZ)
					enemyposy = Spring.GetGroundHeight(enemyposx, enemyposz)
				end
				--else
					--enemyposx, enemyposy, enemyposz = Spring.GetUnitPosition(nearestVisibleUnit)
				--end
				p = api.Position()
				p.x = enemyposx + math.random(0,200) - math.random(0,200)
				p.z = enemyposz + math.random(0,200) - math.random(0,200)
				p.y = enemyposy
				self.target = p
				self.attacking = true
				self.ai.attackhandler:AddRecruit(self)
				if self.active then
					if unit:Name() == "armrectr" or unit:Name() == "cornecro" then
						if Spring.GetUnitCurrentBuildPower(unit.id) == 0 then -- if currently IDLE
							unit:ExecuteCustomCommand(CMD.FIGHT, {p.x, p.y, p.z}, {"alt"})
						end
					else
						--if nearestVisibleUnit and Spring.IsUnitInLos(nearestVisibleUnit, allyTeamID) then
							local moverandom = math.random(0,4)
							if (utype:CanFly() == true) then
								moverandom = 0
							end
							if moverandom == 0 then
								unit:Patrol(self.target)
							elseif moverandom == 1 then
								unit:MoveAndFire(self.target)
							else
								unit:Move(self.target)
							end
						--else
							--local myUnits = Spring.GetTeamUnits(TeamID)
							--for i = 1,#myUnits do
								--pickMyUnit = myUnits[i]
								--local r = math.random(0,#myUnits)
								--if r == pickMyUnit then
									--local r2 = math.random(0,#myUnits)
									--if r2 == pickMyUnit then
										--unit:Move(self.target)
									--end
								--end
							--end
						--end
					end
				else
					self.unit:ElectBehaviour()
				end
		end
	end
	
	-- Retreating
	if unitID % 30 == Spring.GetGameFrame() % 30 then
		if not (currenthealth >= maxhealth*0.75 or currenthealth > 3000) then
		self.unit:Internal():ExecuteCustomCommand(CMD.MOVE_STATE, { 0 }, {})
		local nanotcx, nanotcy, nanotcz = GG.GetClosestNanoTC(unitID)
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
