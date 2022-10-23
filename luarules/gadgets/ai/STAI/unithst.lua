UnitHST = class(Module)
local inactive = {}
function UnitHST:Name()
	return "UnitHandler"
end

function UnitHST:internalName()
	return "unithst"
end

function UnitHST:Init()
	--local RAM = gcinfo()
	self.units = {}
	self.myActiveUnits = {}
	self.myInactiveUnits = {}
	self.reallyActuallyDead = {}
	self.behaviourFactory = BehaviourFactory()
	self.behaviourFactory:SetAI(self.ai)
	self.behaviourFactory:Init()
	--self:EchoDebug('unithst',gcinfo() - RAM)

end

function UnitHST:Update()--is before shardlua/unit
	for k,unit in pairs(self.myActiveUnits) do
		local RAM = gcinfo()
		if ShardSpringLua then
			local ux, uy, uz = Spring.GetUnitPosition(unit:Internal():ID())
			if not ux then
				-- game:SendToConsole(self.ai.id, "nil unit position", unit:Internal():ID(), unit:Internal():Name(), k)
				self.myActiveUnits[k] = nil
				unit = nil
			end
		end
		if unit then
			if unit:HasBehaviours() then
				unit:Update()

			end
		end
		RAM = gcinfo() - RAM
		if RAM > 100 then
			self:EchoDebug('unithst gcinfo',RAM/1000)
		end
	end
	for uID, frame in pairs(self.reallyActuallyDead) do
		if self.game:Frame() > frame + 1800 then
			self.reallyActuallyDead[uID] = nil
		end
	end
end

function UnitHST:GameEnd()
	for k,unit in pairs(self.myActiveUnits) do
		if unit:HasBehaviours() then
			unit:GameEnd()
		end
	end
end

function UnitHST:UnitCreated(unit, unitDefId, teamId, builderId)
	local u = self:AIRepresentation(unit)
	if u == nil then return end
	if u:HasBehaviours() then

		u:UnitCreated(u, unitDefId, teamId, builderId)
	end
	--TODO fix this expensive load
-- 	self.game:StartTimer(u:Internal():Name()..' UC')
-- 	for k,unit in pairs(self.myActiveUnits) do
-- 		if unit:HasBehaviours() then
-- 			self.game:StartTimer(unit:Internal():Name()..' crea')
-- 			unit:UnitCreated(u)
-- 			self:EchoDebug(u:Internal():Name() .. ' UC ' .. unit:Internal():Name())
-- 			self.game:StopTimer(unit:Internal():Name()..' crea')
-- 		end
-- 	end
-- 	self.game:StopTimer(u:Internal():Name()..' UC')
end

function UnitHST:UnitBuilt(engineUnit)
	local u = self:AIRepresentation(engineUnit)
	if u == nil then return end
-- 	u:UnitBuilt(u)
-- 	for k,unit in pairs(self.myActiveUnits) do
 		if u:HasBehaviours() then
 			u:UnitBuilt(u)
 		end
-- 	end
end

function UnitHST:UnitDead(engineUnit)
	local u = self:AIRepresentation(engineUnit)
	if u ~= nil then
		--u:UnitDead(u)
 		for k,unit in pairs(self.myActiveUnits) do
 			if u:HasBehaviours() then
 				u:UnitDead(u)
 			end
 		end
	end
	-- game:SendToConsole(self.ai.id, "removing unit from unithst tables", engineUnit:ID(), engineUnit:Name())
	self.units[engineUnit:ID()] = nil
	self.myActiveUnits[engineUnit:ID()] = nil
	self.myInactiveUnits[engineUnit:ID()] = nil
	self.reallyActuallyDead[engineUnit:ID()] = self.game:Frame()
end

function UnitHST:UnitDamaged(engineUnit,engineAttacker,damage)
	local u = self:AIRepresentation(engineUnit)
	if u == nil then return end
-- 	u:UnitDamaged(u,engineAttacker,damage)
	-- local a = self:AIRepresentation(engineAttacker)
-- 	for k,unit in pairs(self.myActiveUnits) do
 		if u:HasBehaviours() then
 			u:UnitDamaged(u,engineAttacker,damage)
 		end
-- 	end
end


function UnitHST:UnitIdle(engineUnit)
	local u = self:AIRepresentation(engineUnit)
	if u == nil then return end
-- 	u:UnitIdle(u)
-- 	for k,unit in pairs(self.units) do
 		if u:HasBehaviours() then
 			u:UnitIdle(u)
 		end
-- 	end
end

function UnitHST:AIRepresentation(engineUnit)
	if engineUnit == nil then
		return nil
	end
	if self.reallyActuallyDead[engineUnit:ID()] then
		return nil
	end
	local ux, uy, uz = engineUnit:GetPosition()
	if not ux then
		return nil
	end

	local u = self.units[engineUnit:ID()]
	if u == nil then
		u = Unit()
		u:SetAI( self.ai )
		self.units[engineUnit:ID()] = u
		u:SetEngineRepresentation(engineUnit)
		u:Init()
		if engineUnit:Team() == self.game:GetTeamID() then
			if inactive[engineUnit:Name()] then
				self.myInactiveUnits[engineUnit:ID()] = u
			else
				-- game:SendToConsole(self.ai.id, "giving my unit behaviours", engineUnit:ID(), engineUnit:Name())
				self.behaviourFactory:AddBehaviours(u)
				self.myActiveUnits[engineUnit:ID()] = u
			end
		end
	end
	return u
end

