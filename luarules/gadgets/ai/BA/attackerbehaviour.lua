shard_include( "attackers" )


-- speedups
local SpGetGameFrame = Spring.GetGameFrame
local SpGetUnitPosition = Spring.GetUnitPosition
local SpGetUnitSeparation = Spring.GetUnitSeparation
local SpGetUnitVelocity = Spring.GetUnitVelocity
local SpGetUnitMaxRange = Spring.GetUnitMaxRange
local SpValidUnitID = Spring.ValidUnitID
local SpGetUnitCurrentBuildPower = Spring.GetUnitCurrentBuildPower
local SpGetUnitNearestEnemy = Spring.GetUnitNearestEnemy
------


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
	if not self.active then -- do not even attempt anything if the unit is inactive...
		return
	end
	if not self.unitID then
		self.unitID = self.unit:Internal().id
	end
	if not self.AggFactor then
		self.AggFactor = self.ai.attackhandler:GetAggressiveness(self)
	end
	if not self.type then
		self.type = self.ai.attackhandler:GetRole(self)
	end
	local frame = SpGetGameFrame()
	if (frame%450 == self.unitID%450) or self.myRange == nil then --refresh "myRange" casually because it can change with experience
		self.myRange = SpGetUnitMaxRange(self.unitID)
	end
	if (frame%90 == self.unitID%90) then -- a unit on map stays 'visible' for max 3s, this also reduces lag
		local nearestVisibleAcrossMap = SpGetUnitNearestEnemy(self.unitID, self.AggFactor*self.myRange)
		if nearestVisibleAcrossMap and (GG.AiHelpers.VisibilityCheck.IsUnitVisible(nearestVisibleAcrossMap, self.ai.id)) then
			self.nearestVisibleAcrossMap = nearestVisibleAcrossMap
		end
	end
	if (frame%45 == self.unitID%45) then -- a unit in range stays 'visible' for max 1.5s, this also reduces lag
		local nearestVisibleInRange = SpGetUnitNearestEnemy(self.unitID, 2*self.myRange)
		local closestVisible = nearestVisibleInRange and GG.AiHelpers.VisibilityCheck.IsUnitVisible(nearestVisibleInRange, self.ai.id)
		if nearestVisibleInRange and closestVisible then
			self.nearestVisibleInRange = nearestVisibleInRange
			self.enemyRange = SpGetUnitMaxRange(nearestVisibleInRange)
		end
	end
	local distance = (self.nearestVisibleAcrossMap and SpGetUnitSeparation(self.unitID, self.nearestVisibleAcrossMap)) or 3000
	local refreshRate = math.max(math.floor(((distance or 500)/10)),10)
	if self.unitID%refreshRate == frame%refreshRate then
		self:AttackCell(self.type, self.nearestVisibleAcrossMap, self.nearestVisibleInRange, self.enemyRange)
	end
end

function AttackerBehaviour:OwnerBuilt()
	self.unit:Internal():ExecuteCustomCommand(CMD.MOVE_STATE, { 2 }, {})
	self.unit:Internal():ExecuteCustomCommand(CMD.FIRE_STATE, { 2 }, {})
	self.attacking = true
	self.active = true
	self.unitID = self.unit:Internal().id
	self.AggFactor = self.ai.attackhandler:GetAggressiveness(self)
	self.type = self.ai.attackhandler:GetRole(self)
end

function AttackerBehaviour:OwnerDead()
end

function AttackerBehaviour:OwnerIdle()
	self.attacking = true
	self.active = true
end

function AttackerBehaviour:AttackCell(type, nearestVisibleAcrossMap, nearestVisibleInRange, enemyRange)
	local p
	local unit = self.unit:Internal()
	local unitID = unit.id
	local currenthealth = unit:GetHealth()
	local maxhealth = unit:GetMaxHealth()
	-- Retreating first so we have less data process/only what matters
	if not (currenthealth >= maxhealth*0.75 or currenthealth > 3000) then
	local nanotcx, nanotcy, nanotcz = GG.AiHelpers.NanoTC.GetClosestNanoTC(self.unitID)
		if nanotcx and nanotcy and nanotcz then
			p = api.Position()
			p.x, p.y, p.z = nanotcx, nanotcy, nanotcz
		else
			p = self.ai.attackhandler.commpos
		end
		self.target = p
		self.attacking = false
		if self.active then
			self.active = false -- until it is idle (= getting repaired)
			self.unit:Internal():Move(self.target)
		end
		return
	end
	
	local utype = self.game:GetTypeByName(unit:Name())
	local attacker = (type == "attacker")
	
	-- nil/invalid checks
	if nearestVisibleInRange and (not SpValidUnitID(nearestVisibleInRange)) then 
		nearestVisibleInRange = nil 
		self.nearestVisibleInRange = nil
	end
	if nearestVisibleAcrossMap and (not SpValidUnitID(nearestVisibleAcrossMap)) then 
		nearestVisibleAcrossMap = nil 
		self.nearestVisibleAcrossMap = nil 
	end
	
	if nearestVisibleInRange and (not utype:CanFly() == true) then -- process cases where there isn't any visible nearestVisibleInRange first
		local ex,ey,ez = SpGetUnitPosition(nearestVisibleInRange)
		local ux,uy,uz = SpGetUnitPosition(self.unitID)
		local pointDis = SpGetUnitSeparation(self.unitID,nearestVisibleInRange)
		local dis = 120
		local f = dis/pointDis
		local wantedRange
		if self.myRange and enemyRange and self.myRange >= enemyRange and enemyRange > 50 then -- we skirm here
			wantedRange = self.myRange
		else -- randomize wantedRange between 25-75% of myRange
			wantedRange = math.random(self.myRange*0.25, self.myRange*0.75)
		end
		-- offset upos randomly so it moves a bit while keeping distance
		local dx, _, dz, dw = SpGetUnitVelocity(self.unitID) -- attempt to not always queue awful turns
		local modifier = "ctrl"
		ux = ux + 10*dx + math.random (-80,80)
		uy = uy
		uz = uz + 10*dz + math.random (-80,80)
		if wantedRange <= pointDis then
			modifier = nil -- Do not try to move backwards if attempting to get closer to target
		end
		-- here we find the goal position
		if (pointDis+dis > wantedRange) then
			f = (wantedRange-pointDis)/pointDis
		end
		local cx = ux+(ux-ex)*f
		local cy = uy
		local cz = uz+(uz-ez)*f
		self.unit:Internal():ExecuteCustomCommand(CMD.MOVE, {cx, cy, cz}, {modifier})
		return
	end
	
	-- We have processed units that had to retreat and units that had visible enemies within 2* their range
	-- what are left are units with no visible enemies within 2*maxRange (no radar/los/prevLOS buildings)
	local enemyposx, enemyposy, enemyposz
	if nearestVisibleAcrossMap then
		enemyposx, enemyposy, enemyposz = SpGetUnitPosition(nearestVisibleAcrossMap) -- visible on map
	else
		local attacker = type == "attacker"
		if attacker then
			local cms = self.ai.attackhandler.targetMexes[(self.unitID%5)+1]
			if cms then -- there is an enemy metal spot
				enemyposx, enemyposy, enemyposz = cms.x, cms.y, cms.z
			else -- there is nothing to target
				return
			end
		else
			local cms = self.ai.metalspothandler:ClosestFreeSpot(self.game:GetTypeByName("armmex"), self.unit:Internal():GetPosition())
			if cms then
				enemyposx, enemyposy, enemyposz = cms.x, cms.y, cms.z
			else
				return
			end
		end
	end

	p = api.Position()
	p.x = enemyposx + math.random(-math.sqrt(2)/2*self.myRange*0.90, math.sqrt(2)/2*self.myRange*0.90)
	p.z = enemyposz + math.random(-math.sqrt(2)/2*self.myRange*0.90, math.sqrt(2)/2*self.myRange*0.90)
	p.y = enemyposy
	self.target = p
	self.attacking = true
	if unit:Name() == "armrectr" or unit:Name() == "cornecro" then
		if SpGetUnitCurrentBuildPower(unit.id) == 0 then -- if currently IDLE
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
	else
	end
end


function AttackerBehaviour:OwnerDied()
	self.attacking = nil
	self.active = nil
	self.unit = nil
end
