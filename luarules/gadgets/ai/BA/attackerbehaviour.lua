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
	self.ai.commpos = {x = 0, y = 0, z = 0}
end

local function Distance(x1,z1, x2,z2)
	local vectx = x2 - x1
	local vectz = z2 - z1
	local dis = math.sqrt(vectx^2+vectz^2)
	return dis
end

function AttackerBehaviour:Update()
	local x,y,z
	local comms = Spring.GetTeamUnitsByDefs(self.ai.id, {UnitDefNames.armcom.id, UnitDefNames.corcom.id})
	if comms[1] then
		x,y,z = Spring.GetUnitPosition(comms[1])
		self.ai.commpos = {x = x, y = y, z = z}
	end
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

function AttackerBehaviour:AttackCell(type)
	local attacker = (type == "attacker")
	local unit = self.unit:Internal()
	local unitID = unit.id
	local utype = self.game:GetTypeByName(unit:Name())
	local nearestUnit = Spring.GetUnitNearestEnemy(unitID, _, false)
	local distance = nearestUnit and Spring.GetUnitSeparation(unitID, nearestUnit)
	local refreshRate = math.max(math.floor(((distance or 500)/10)),10)
	local frame = Spring.GetGameFrame()
	-- Spring.Echo(unitID)
	if unitID%refreshRate == frame%refreshRate then
		local myRange = Spring.GetUnitMaxRange(unitID)
		local closestUnit = Spring.GetUnitNearestEnemy(unitID, myRange)
		local allyTeamID = self.ai.allyId
		local closestVisible = closestUnit and GG.AiHelpers.VisibilityCheck.IsUnitVisible(closestUnit, self.ai.id)
		local currenthealth = unit:GetHealth()
		local maxhealth = unit:GetMaxHealth()
		-- Skirmishing
		if (not utype:CanFly() == true) then
			if closestUnit and (closestVisible) and (not UnitDefs[Spring.GetUnitDefID(closestUnit)].canFly == true) and (currenthealth >= maxhealth*0.75 or currenthealth > 3000) then
				local enemyRange = Spring.GetUnitMaxRange(closestUnit)
				if myRange >= enemyRange and enemyRange > 50 and enemyRange ~= nil then
					local wantedRange = myRange
					local ex,ey,ez = Spring.GetUnitPosition(closestUnit)
					local ux,uy,uz = Spring.GetUnitPosition(unitID)
					local pointDis = Spring.GetUnitSeparation(unitID,closestUnit)
					local dis = 120
					local f = dis/pointDis
					if (pointDis+dis > Spring.GetUnitMaxRange(unitID)) then
					  f = (wantedRange-pointDis)/pointDis
					end
					local cx = ux+(ux-ex)*f
					local cy = uy
					local cz = uz+(uz-ez)*f
					self.unit:Internal():ExecuteCustomCommand(CMD.MOVE, {cx, cy, cz}, {"ctrl"})
					return
				end
			end
		end
		
		local nearestUnitRangeCheck = ((not attacker) and (400 + myRange)) or (5*myRange)
	-- Attacking
		local TeamID = self.ai.id
		local allyTeamID = self.ai.allyId
		if nearestUnit and not (GG.AiHelpers.VisibilityCheck.IsUnitVisible(nearestUnit, self.ai.id)) then
			nearestUnit = nil
		end
		if (currenthealth >= maxhealth*0.75 or currenthealth > 3000)  then
			if nearestUnit == nil and type == "defender" then
				local cms = self.ai.metalspothandler:ClosestFreeSpot(utype, self.unit:Internal():GetPosition())
				if cms then
					enemyposx, enemyposy, enemyposz = cms.x, cms.y, cms.z
				else
					return
				end
			elseif nearestUnit == nil and type == "attacker" then
				local cms = self.ai.metalspothandler:ClosestEnemySpot(utype, self.unit:Internal():GetPosition())
				if cms then
					enemyposx, enemyposy, enemyposz = cms.x, cms.y, cms.z
				else
					return
				end
			else
				enemyposx, enemyposy, enemyposz = Spring.GetUnitPosition(nearestUnit)
			end
			p = api.Position()
			p.x = enemyposx + math.random(-math.sqrt(2)/2*myRange*0.90, math.sqrt(2)/2*myRange*0.90)
			p.z = enemyposz + math.random(-math.sqrt(2)/2*myRange*0.90, math.sqrt(2)/2*myRange*0.90)
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
					if (utype:CanFly() == true) then
						unit:MoveAndFire(self.target)
					else
						unit:Move(self.target)
					end
				return
				end
			else
				self.unit:ElectBehaviour()
				return
			end
		end
	-- Retreating
		if not (currenthealth >= maxhealth*0.75 or currenthealth > 3000) then
		local nanotcx, nanotcy, nanotcz = GG.AiHelpers.NanoTC.GetClosestNanoTC(unitID)
			if nanotcx and nanotcy and nanotcz then
				p = api.Position()
				p.x, p.y, p.z = nanotcx, nanotcy, nanotcz
			else
				p = self.ai.commpos
			end
			self.target = p
			self.attacking = false
			self.ai.attackhandler:AddRecruit(self)
			if self.active then
				self.unit:Internal():Move(self.target)
			else
				self.unit:ElectBehaviour()
			end
			return
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
