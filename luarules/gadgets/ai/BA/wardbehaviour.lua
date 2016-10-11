local DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("WardBehaviour: ", inStr)
	end
end

WardBehaviour = class(Behaviour)

function WardBehaviour:Name()
	return "WardBehaviour"
end

function WardBehaviour:Init()
	self.minFleeDistance = 500
	self.lastAttackedFrame = game:Frame()
	self.initialLocation = self.unit:Internal():GetPosition()
	self.name = self.unit:Internal():Name()
	self.id = self.unit:Internal():ID()
	self.mtype = unitTable[self.name].mtype
	self.water = self.mtype == "sub" or self.mtype == "shp" or self.mtype == "amp" -- can be hurt by submerged weapons
	self.isCommander = commanderList[self.name]
	self.mobile = not unitTable[self.name].isBuilding and not nanoTurretList[self.name] -- for some reason nano turrets are not buildings
	self.isScout = scoutList[self.name]
	if self.isCommander then
		self.threshold = 0.2
	elseif self.isScout then
		self.threshold = 1
	elseif self.mobile then
		self.threshold = 0.5
	end
	-- any threat whatsoever will trigger for buildings
	EchoDebug("WardBehaviour: added to unit "..self.name)
end

function WardBehaviour:OwnerBuilt()
	if self.mobile and not self.isScout then
		self.ai.defendhandler:AddWard(self) -- just testing 
	end
end

function WardBehaviour:OwnerDead()
	if self.mobile and not self.isScout then
		self.ai.defendhandler:RemoveWard(self) -- just testing 
	end
end

function WardBehaviour:OwnerIdle()
	if self:IsActive() then
		self.underFire = false
		self.unit:ElectBehaviour()
	end
end

function WardBehaviour:Update()
	local f = game:Frame()

	-- timeout on underFire condition
	if self.underFire then
		if f > self.lastAttackedFrame + 300 then
			self.underFire = false
		end
	else
		self.withinTurtle = false
		if f % 30 == 0 then
			-- run away preemptively from positions within range of enemy weapons, and notify defenders that the unit is in danger
			local unit = self.unit:Internal()
			if not self.mobile then
				position = self.initialLocation
			else
				position = unit:GetPosition()
			end
			local safe, response = self.ai.targethandler:IsSafePosition(position, unit, self.threshold)
			if safe then
				self.underFire = false
				self.response = nil
			else
				EchoDebug(self.name .. " is not safe")
				self.underFire = true
				self.response = response
				self.lastAttackedFrame = game:Frame()
				if not self.mobile then self.ai.defendhandler:Danger(self) end
			end
			if self.mobile then self.withinTurtle = self.ai.turtlehandler:SafeWithinTurtle(position, self.name) end
			self.unit:ElectBehaviour()
		end
	end
end

function WardBehaviour:Activate()
	EchoDebug("activated on unit "..self.name)

	-- can we move at all?
	if self.mobile then
		-- run to the most defended base location
		local salvation = self.ai.turtlehandler:MostTurtled(self.unit:Internal(), nil, nil, true) or self:NearestCombat()
		EchoDebug(tostring(salvation), "salvation")
		if salvation and Distance(self.unit:Internal():GetPosition(), salvation) > self.minFleeDistance then
			self.unit:Internal():Move(RandomAway(salvation,150))
			self.noSalvation = false
			self.active = true
			EchoDebug("unit ".. self.name .." runs away from danger")
		else
			-- we're already as safe as we can get
			EchoDebug("no salvation for", self.name)
			self.noSalvation = true
			self.unit:ElectBehaviour()
		end
	end
end

function WardBehaviour:NearestCombat()
	local best
	local ownUnits = self.game:GetFriendlies()
	local fleeing = self.unit:Internal()
	local fn = fleeing:Name()
	local fid = fleeing:ID()
	local fpos = fleeing:GetPosition()
	local bestDistance = 10000
	for i,unit in pairs(ownUnits) do
		local un = unit:Name()
		if unit:ID() ~= fid and un ~= "corcom" and un ~= "armcom" and not self.ai.defendhandler:IsDefendingMe(unit, self) then
			if unitTable[un].isWeapon and (battleList[un] or breakthroughList[un]) then
				local upos = unit:GetPosition()
				if self.ai.targethandler:IsSafePosition(upos, fleeing) and unit:GetHealth() > unit:GetMaxHealth() * 0.9 and self.ai.maphandler:UnitCanGetToUnit(fleeing, unit) and not unit:IsBeingBuilt() then
					local dist = Distance(fpos, upos) - unitTable[un].metalCost
					if dist < bestDistance then
						bestDistance = dist
						best = upos
					end
				end
			end
		end
	end
	if best then EchoDebug("got NearestCombat for ", fn, bestDistance, "away") end
	return best
end

function WardBehaviour:Deactivate()
	EchoDebug("WardBehaviour: deactivated on unit "..self.name)
	self.active = false
	self.underFire = false
end

function WardBehaviour:Priority()
	if self.underFire and self.mobile and not self.withinTurtle and not self.noSalvation then
		return 110
	else
		return 0
	end
end

function WardBehaviour:OwnerDamaged(attacker,damage)
	if not self.underFire then
		if self.unit:Internal():GetHealth() < self.unit:Internal():GetMaxHealth() * 0.8 then
			self.underFire = true
			self.lastAttackedFrame = game:Frame()
			if not self.mobile then self.ai.defendhandler:Danger(self) end
			self.unit:ElectBehaviour()
		end
	end
end

