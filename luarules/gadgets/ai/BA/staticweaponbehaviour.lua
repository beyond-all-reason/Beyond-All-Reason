shard_include( "staticweapons" )

local CMD_STOCKPILE = 100

function IsStaticWeapon(unit)
	for i,name in ipairs(staticweaponlist) do
		if name == unit:Internal():Name() then
			return true
		end
	end
	return false
end

StaticWeaponBehaviour = class(Behaviour)

function StaticWeaponBehaviour:Init()
	self.stockpiler = UnitDefs[UnitDefNames[self.unit:Internal():Name()].id].canStockpile
	CMD.FIRE_STATE = 45
	self.unit:Internal():ExecuteCustomCommand(CMD.FIRE_STATE, { 2 }, {})
end

function StaticWeaponBehaviour:Update()
	if Spring.GetGameFrame() % 120 == 0 then
		if self.stockpiler then
			local _,curStockQ = Spring.GetUnitStockpile(self.unit:Internal().id)
			if curStockQ <1 then
				self.unit:Internal():ExecuteCustomCommand(CMD_STOCKPILE)
			end
		end
		if not self.target then
			self.target = GG.AiHelpers.TargetsOfInterest.LongRangeWeapon(self.unit:Internal().id, self.ai.id)
		end
		if self.target then
			if not Spring.ValidUnitID(self.target) then
				self.target = nil
				self.unit:Internal():ExecuteCustomCommand(CMD.STOP, {}, {})
			else
				local x,y,z = Spring.GetUnitPosition(self.target)
				self.unit:Internal():ExecuteCustomCommand(CMD.ATTACK, {x,y,z}, {})
			end
		end
	end
end

function StaticWeaponBehaviour:OwnerBuilt()

end

function StaticWeaponBehaviour:OwnerDead()

end

function StaticWeaponBehaviour:Priority()
	return 100
end

function StaticWeaponBehaviour:Activate()
	self.active = true
end


function StaticWeaponBehaviour:OwnerDied()
	self.active = nil
	self.unit = nil
end
