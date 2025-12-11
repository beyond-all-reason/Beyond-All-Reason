UnitHST = class(Module)

function UnitHST:Name()
	return "UnitHandler"
end

function UnitHST:internalName()
	return "unithst"
end

function UnitHST:Init()
	self.units = {}
	self.behaviourFactory = BehaviourFactory()
	self.behaviourFactory:SetAI(self.ai)
	self.behaviourFactory:Init()
end
function UnitHST:Update()--is before shardlua/unit
	for ID,unit in pairs(self.units) do
		local x,y,z = unit:Internal():GetRawPos() --Spring.GetUnitPosition(unit:Internal():ID())
		unit:Internal().x = x
 		unit:Internal().y = y
 		unit:Internal().z = z
-- 		unit.x = x
-- 		unit.y = y
-- 		unit.z = z
		if x then
			if unit:HasBehaviours() then
				--local RAM = gcinfo()
				unit:Update()
				--RAM = gcinfo() - RAM
				--if RAM > 0 then
				--	print (RAM,unit:Internal():Name())
				--end
			end
		end
	end
end

function UnitHST:GameEnd()
	for k,unit in pairs(self.units) do
		if unit:HasBehaviours() then
			unit:GameEnd()
		end
	end
end

function UnitHST:UnitCreated(unit, unitDefId, teamId, builderId)
	local u = self:AIRepresentation(unit)

	if not u then return end
	local x,y,z = u:Internal():GetRawPos() --Spring.GetUnitPosition(unit:Internal():ID())
	u:Internal().x = x
	u:Internal().y = y
	u:Internal().z = z
	if u:HasBehaviours() then
		u:UnitCreated(u, unitDefId, teamId, builderId)
	end

end

function UnitHST:UnitBuilt(engineUnit)
	local u = self:AIRepresentation(engineUnit)
	if not u then return end
	if u:HasBehaviours() then
		u:UnitBuilt(u)
	end
end

function UnitHST:UnitDead(engineUnit)
	local u = self:AIRepresentation(engineUnit)
	if not u then return end
	if u:HasBehaviours() then
		u:UnitDead(u)
	end
 	self.units[engineUnit:ID()] = nil

end

function UnitHST:UnitDamaged(engineUnit,engineAttacker,damage)
	local u = self:AIRepresentation(engineUnit)
	if not u then return end
	if u:HasBehaviours() then
		u:UnitDamaged(u,engineAttacker,damage)
	end
end


function UnitHST:UnitIdle(engineUnit)
	local u = self:AIRepresentation(engineUnit)
	if not u then return end
	if u:HasBehaviours() then
		u:UnitIdle(u)
	end
end

function UnitHST:AIRepresentation(engineUnit)
	if not engineUnit then
		return nil
	end
	if not engineUnit then
		return nil
	end

 	local u = self.units[engineUnit:ID()]
	if u == nil then
		u = Unit()
		u:SetAI(self.ai)
 		self.units[engineUnit:ID()] = u
		u:SetEngineRepresentation(engineUnit)
		u:Init()
		if engineUnit:Team() == self.game:GetTeamID() then
			self.behaviourFactory:AddBehaviours(u)
-- 			if inactive[engineUnit:Name()] then
-- 				self.myInactiveUnits[engineUnit:ID()] = u
-- 			else
-- 				-- game:SendToConsole(self.ai.id, "giving my unit behaviours", engineUnit:ID(), engineUnit:Name())
--
-- 				self.myActiveUnits[engineUnit:ID()] = u
-- 			end
		end
	end
	return u
end

