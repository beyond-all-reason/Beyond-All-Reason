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
end

function Unit:Update()
	if self.behaviours == nil then
		self.behaviours = {}
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
	return self.activebeh
end

function Unit:ElectBehaviour()
	if self.behaviours == nil then --probably we are dead.
		return
	end
	local bestbeh = nil
	local bestscore = -1
	if #self.behaviours > 0 then
		for k,v in pairs(self.behaviours) do
			if bestbeh == nil then
				bestbeh = v
				bestscore = v:Priority()
			else
				local score = v:Priority()
				if score > bestscore then
					bestscore = score
					bestbeh = v
				end
			end
		end
		
		if self.activebeh ~= bestbeh then
			if self.activebeh ~= nil then
				self.activebeh:PreDeactivate()
				self.activebeh:Deactivate()
			end
			self.activebeh = bestbeh
			self.activebeh:PreActivate()
			self.activebeh:Activate()
		end
	end
end
