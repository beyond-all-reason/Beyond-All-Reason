Unit = class(AIBase)

function Unit:SetEngineRepresentation(engineUnit)
	self.engineUnit = engineUnit
	self.engineID = engineUnit:ID()
end

function Unit:Internal()
	return self.engineUnit
end

function Unit:Init()
	if self.engineUnit == nil then
		self.game:SendToConsole("Warning: Shard Unit:Init nil engineUnit?!")
	end
	self.behaviours = {}
	self.nextBehaviour = nil
	self.activeBehaviour = nil
end

function Unit:Update()
	if self.behaviours == nil then
		self.behaviours = {}
	end

	-- handle switching behaviours
	if self.nextBehaviour ~= nil then
		self.activeBehaviour = self.nextBehaviour
		self.nextBehaviour = nil
		self.activeBehaviour:PreActivate()
		self.activeBehaviour:Activate()
	end

	for k,v in pairs(self.behaviours) do
		v:Update()
	end
end

function Unit:GameEnd()
	for k,v in pairs(self.behaviours) do
		v:GameEnd()
	end
end

function Unit:UnitCreated(unit)
	if unit then -- TEMPORARY FIX
		if unit.engineID == self.engineID then
			return
		end
		for k,v in pairs(self.behaviours) do
			v:UnitCreated(unit)
		end
	end
end

function Unit:UnitBuilt(unit)
	if unit.engineID == self.engineID then
		self:ElectBehaviour()
		for k,v in pairs(self.behaviours) do
			v:OwnerBuilt()
		end
	else
		for k,v in pairs(self.behaviours) do
			v:UnitBuilt(unit)
		end
 	end
end

function Unit:UnitDead(unit)

	if unit.engineID == self.engineID then
		if self.behaviours then
			-- game:SendToConsole("unit died, removing behaviours", self.engineID, self:Internal():Name())
			for k,v in pairs(self.behaviours) do
				self.behaviours[k]:OwnerDead()
				self.behaviours[k] = nil
			end
			self.behaviours = nil
		end
		self.engineUnit = nil
	else
		for k,v in pairs(self.behaviours) do
			v:UnitDead(unit)
		end
	end
end


function Unit:UnitDamaged(unit,attacker,damage)
	if unit.engineID == self.engineID then
		for k,v in pairs(self.behaviours) do
			v:OwnerDamaged(attacker,damage)
		end
	else
		for k,v in pairs(self.behaviours) do
			v:UnitDamaged(unit,attacker,damage)
		end
	end
end

function Unit:UnitIdle(unit)
	if unit.engineID == self.engineID then
		for k,v in pairs(self.behaviours) do
			v:OwnerIdle()
		end
	else
		for k,v in pairs(self.behaviours) do
			v:UnitIdle(unit)
		end
	end
end

function Unit:UnitMoveFailed(unit)
	if unit.engineID == self.engineID then
		for k,v in pairs(self.behaviours) do
			v:OwnerMoveFailed()
		end
	else
		for k,v in pairs(self.behaviours) do
			v:UnitMoveFailed(unit)
		end
	end
end

function Unit:AddBehaviour(behaviour)
	table.insert(self.behaviours,behaviour)
end

function Unit:ActiveBehaviour()
	return self.activeBehaviour
end

function Unit:ElectBehaviour()
	if self.behaviours == nil then --probably we are dead.
		return
	end
	local bestBehaviour = nil
	local bestScore = -1
	if #self.behaviours > 0 then
		for k,behaviour in pairs(self.behaviours) do
			if bestBehaviour == nil then
				bestBehaviour = behaviour
				bestScore = behaviour:Priority()
			else
				local score = behaviour:Priority()
				if ( score > 0 ) and ( score > bestScore ) then
					bestScore = score
					bestBehaviour = behaviour
				end
			end
		end

		if bestBehaviour ~= nil then
			if ( self.activeBehaviour ~= bestBehaviour ) and ( self.nextBehaviour ~= bestBehaviour ) then
				if self.activeBehaviour ~= nil then
					self.activeBehaviour:PreDeactivate()
					self.activeBehaviour:Deactivate()
				end
				self.nextBehaviour = bestBehaviour
			end
		end
	end
end
