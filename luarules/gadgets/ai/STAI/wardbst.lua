WardBST = class(Behaviour)

function WardBST:Name()
	return "WardBST"
end

WardBST.DebugEnabled = false

function WardBST:Init()
	self.minFleeDistance = 500
	self.lastAttackedFrame = self.game:Frame()
	self.initialLocation = self.unit:Internal():GetPosition()
	self.name = self.unit:Internal():Name()
	self.id = self.unit:Internal():ID()
	self.mtype = self.ai.armyhst.unitTable[self.name].mtype
	self.water = self.mtype == "sub" or self.mtype == "shp" or self.mtype == "amp" -- can be hurt by submerged weapons
	self.isCommander = self.ai.armyhst.commanderList[self.name]
	self.mobile = not self.ai.armyhst.unitTable[self.name].isBuilding and not self.ai.armyhst._nano_[self.name] -- for some reason nano turrets are not buildings
	self.isScout = self.ai.armyhst.scouts[self.name]
	if self.isCommander then
		self.threshold = 0.2
	elseif self.isScout then
		self.threshold = 1
	elseif self.mobile then
		self.threshold = 0.5
	end
	-- any threat whatsoever will trigger for buildings
	self:EchoDebug("WardBST: added to unit "..self.name)
end

function WardBST:OwnerBuilt()
	if self.mobile and not self.isScout then
		self.ai.defendhst:AddWard(self) -- just testing
	end
end

function WardBST:OwnerDead()
	if self.mobile and not self.isScout then
		self.ai.defendhst:RemoveWard(self) -- just testing
	end
end

function WardBST:OwnerIdle()
	if self:IsActive() then
		self.underFire = false
		self.unit:ElectBehaviour()
	end
end

function WardBST:Update()
-- 	 self.uFrame = self.uFrame or 0
	local f = self.game:Frame()

	-- timeout on underFire condition
	if self.underFire then
		if f > self.lastAttackedFrame + 300 then
			self.underFire = false
		end
	else
		self.withinTurtle = false
		if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'WardBST' then return end
-- 		if f - self.uFrame < self.ai.behUp['wardbst']	 then
-- 			return
-- 		end
-- 		self.uFrame = f
		-- run away preemptively from positions within range of enemy weapons, and notify defenders that the unit is in danger
		local unit = self.unit:Internal()
		local position
		if not self.mobile then
			position = self.initialLocation
		else
			position = unit:GetPosition()
		end
		local safe, response = self.ai.targethst:IsSafePosition(position, unit, self.threshold)
		if safe then
			self.underFire = false
			self.response = nil
		else
			self:EchoDebug(self.name .. " is not safe")
			self.underFire = true
			self.response = response
			self.lastAttackedFrame = self.game:Frame()
			if not self.mobile then self.ai.defendhst:Danger(self) end
		end
		if self.mobile then self.withinTurtle = self.ai.turtlehst:SafeWithinTurtle(position, self.name) end
		self.unit:ElectBehaviour()
	end
end

function WardBST:Activate()
	self:EchoDebug("activated on unit "..self.name)

	-- can we move at all?
	if self.mobile then
		-- run to the most defended base location
		local salvation = self:NearestNano() or self.ai.turtlehst:MostTurtled(self.unit:Internal(), nil, nil, true) or self:NearestCombat()

		self:EchoDebug(tostring(salvation), "salvation")
		if salvation and self.ai.tool:Distance(self.unit:Internal():GetPosition(), salvation) > self.minFleeDistance then

			self.unit:Internal():Move( self.ai.tool:RandomAway(salvation,150))
			self.noSalvation = false
			self.active = true
			self:EchoDebug("unit ".. self.name .." runs away from danger to ", salvation.x,salvation.z)
		else
			-- we're already as safe as we can get
			self:EchoDebug("no salvation for", self.name)
			self.noSalvation = true
			self.unit:ElectBehaviour()
		end
	end
end

function WardBST:NearestNano()
	local nanoHots = self.ai.nanohst:GetHotSpots()
	if not nanoHots then return false end
	for i = 1, #nanoHots do
		local hotPos = nanoHots[i]
		return hotPos

	end
end


function WardBST:NearestCombat()
	local best
	local ownUnits = self.game:GetFriendlies()
	local fleeing = self.unit:Internal()
	local fn = fleeing:Name()
	local fid = fleeing:ID()
	local fpos = fleeing:GetPosition()
	local bestDistance = 10000
	for i,unit in pairs(ownUnits) do
		local un = unit:Name()
		if unit:ID() ~= fid and un ~= "corcom" and un ~= "armcom" and not self.ai.defendhst:IsDefendingMe(unit, self) then
			if self.ai.armyhst.unitTable[un].isWeapon and (self.ai.armyhst.battles[un] or self.ai.armyhst.breaks[un]) then
				local upos = unit:GetPosition()
				if self.ai.targethst:IsSafePosition(upos, fleeing) and unit:GetHealth() > unit:GetMaxHealth() * 0.9 and self.ai.maphst:UnitCanGetToUnit(fleeing, unit) and not unit:IsBeingBuilt() then
					local dist = self.ai.tool:Distance(fpos, upos) - self.ai.armyhst.unitTable[un].metalCost
					if dist < bestDistance then
						bestDistance = dist
						best = upos
					end
				end
			end
		end
	end
	if best then self:EchoDebug("got NearestCombat for ", fn, bestDistance, "away") end
	return best
end

function WardBST:Deactivate()
	self:EchoDebug("WardBST: deactivated on unit "..self.name)
	self.active = false
	self.underFire = false
end

function WardBST:Priority()
	if self.underFire and self.mobile and not self.withinTurtle and not self.noSalvation then
		return 110
	else
		return 0
	end
end

function WardBST:OwnerDamaged(attacker,damage)
	if not self.underFire then
		if self.unit:Internal():GetHealth() < self.unit:Internal():GetMaxHealth() * 0.95 then
			self.underFire = true
			self.lastAttackedFrame = self.game:Frame()
			self.ai.defendhst:Danger(self)--TEST
			--if not self.mobile then self.ai.defendhst:Danger(self) end--TEST
			self.unit:ElectBehaviour()
		end
	end
end

