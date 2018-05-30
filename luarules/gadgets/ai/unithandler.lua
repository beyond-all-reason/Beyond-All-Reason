UnitHandler = class(Module)

function UnitHandler:Name()
	return "UnitHandler"
end

function UnitHandler:internalName()
	return "unithandler"
end

function UnitHandler:Init()
	self.units = {}
	self.myUnits = {}
	self.reallyActuallyDead = {}
	self.behaviourFactory = BehaviourFactory()
	self.behaviourFactory:SetAI(self.ai)
	self.behaviourFactory:Init()
end

function UnitHandler:Update()
	for k,v in pairs(self.myUnits) do
		if ShardSpringLua then
			local ux, uy, uz = Spring.GetUnitPosition(v:Internal():ID())
			if not ux then
				-- game:SendToConsole(self.ai.id, "nil unit position", v:Internal():ID(), v:Internal():Name(), k)
				self.myUnits[k] = nil
				v = nil
			end
		end
		if v then
			v:Update()
		end
	end
	for uID, frame in pairs(self.reallyActuallyDead) do
		if self.game:Frame() > frame + 1800 then
			self.reallyActuallyDead[uID] = nil
		end
	end
end

function UnitHandler:GameEnd()
	for k,v in pairs(self.myUnits) do
		v:GameEnd()
	end
end

function UnitHandler:UnitCreated(engineUnit)
	local u = self:AIRepresentation(engineUnit)
	for k,v in pairs(self.myUnits) do
		v:UnitCreated(u)
	end
end

function UnitHandler:UnitBuilt(engineUnit)
	local u = self:AIRepresentation(engineUnit)
	if u ~= nil then
		for k,v in pairs(self.myUnits) do
			v:UnitBuilt(u)
		end
	end
end

function UnitHandler:UnitDead(engineUnit)
	local u = self:AIRepresentation(engineUnit)
	if u ~= nil then
		for k,v in pairs(self.myUnits) do
			v:UnitDead(u)
		end
	end
	-- game:SendToConsole(self.ai.id, "removing unit from unithandler tables", engineUnit:ID(), engineUnit:Name())
	self.units[engineUnit:ID()] = nil
	self.myUnits[engineUnit:ID()] = nil
	self.reallyActuallyDead[engineUnit:ID()] = self.game:Frame()
end

function UnitHandler:UnitDamaged(engineUnit,engineAttacker,damage)
	local u = self:AIRepresentation(engineUnit)
	-- local a = self:AIRepresentation(engineAttacker)
	for k,v in pairs(self.myUnits) do
		v:UnitDamaged(u,engineAttacker,damage)
	end
end

function UnitHandler:AIRepresentation(engineUnit)
	if engineUnit == nil then
		return nil
	end
	if self.reallyActuallyDead[engineUnit:ID()] then
		-- self.game:SendToConsole(self.ai.id, "unit already died, not representing unit", engineUnit:ID(), engineUnit:Name())
		return nil
	end
	local ux, uy, uz = engineUnit:GetPosition()
	if not ux then
		-- self.game:SendToConsole(self.ai.id, "nil engineUnit position, not representing unit", engineUnit:ID(), engineUnit:Name())
		return nil
	end
	local unittable = self.units
	local u = unittable[engineUnit:ID()]
	if u == nil then
		-- self.game:SendToConsole(self.ai.id, "adding unit to unithandler tables", engineUnit:ID(), engineUnit:Name())
		u = Unit()
		u:SetAI( self.ai )
		self.units[engineUnit:ID()] = u
		
		u:SetEngineRepresentation(engineUnit)
		u:Init()
		if engineUnit:Team() == self.game:GetTeamID() then
			-- game:SendToConsole(self.ai.id, "giving my unit behaviours", engineUnit:ID(), engineUnit:Name())
			self.behaviourFactory:AddBehaviours(u)
			self.myUnits[engineUnit:ID()] = u
		end
	end
	return u
end

function UnitHandler:UnitIdle(engineUnit)
	local u = self:AIRepresentation(engineUnit)
	if u ~= nil then
		for k,v in pairs(self.units) do
			v:UnitIdle(u)
		end
	end
end