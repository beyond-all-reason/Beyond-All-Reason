CleanHST = class(Module)

function CleanHST:Name()
	return "CleanHST"
end

function CleanHST:internalName()
	return "cleanhst"
end

function CleanHST:Init()
	self.DebugEnabled = false
	self.theCleaner = {}
	self.dirt = {}
end
 function CleanHST:UnitDead(unit)
 	if self.dirt[unit:ID()] then
 		self:EchoDebug(self.dirt[unit:ID()],'removed this unit' ,unit:ID())
 		local executer = self.game:GetUnitByID(self.dirt[unit:ID()])
		local uPos = executer:GetPosition()
		executer:Patrol({uPos.x,uPos.y,uPos.z,0})
 		self.theCleaner[self.dirt[unit:ID()]] = nil
 		self.dirt[unit:ID()] = nil
 	end
 end
