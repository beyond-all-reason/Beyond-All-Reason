-- keeps track of hits to our units

DamageHST = class(Module)

function DamageHST:Name()
	return "DamageHST"
end

function DamageHST:internalName()
	return "damagehst"
end

DamageHST.DebugEnabled = false

function DamageHST:Init()
	self.isDamaged = {}
	self.lastDamageCheckFrame = 0
end

function DamageHST:UnitDamaged(engineUnit, attacker, damage)
	local teamID = engineUnit:Team()
	if teamID ~= self.game:GetTeamID() and not self.ai.friendlyTeamID[teamID] then
		return
	end
	local unitID = engineUnit:ID()
	self.isDamaged[unitID] = engineUnit
end

function DamageHST:Update()
-- 	local f = self.game:Frame()
-- 	if f > self.lastDamageCheckFrame + 90 then
		if self.ai.schedulerhst.moduleTeam ~= self.ai.id or self.ai.schedulerhst.moduleUpdate ~= self:Name() then return end
		for unitID, engineUnit in pairs(self.isDamaged) do
			local health = engineUnit:GetHealth()
			if not health or (health == engineUnit:GetMaxHealth()) then
				self.isDamaged[unitID] = nil
			end
		end
		--self.lastDamageCheckFrame = f
	--end
end

function DamageHST:UnitDead(engineUnit)
	self.isDamaged[engineUnit:ID()] = nil
end

function DamageHST:GetDamagedUnits()
	return self.isDamaged
end
