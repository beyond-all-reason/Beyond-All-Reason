CleanHST = class(Module)

-- distancePerPriority = 100

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
local CMD_PATROL = 15
 function CleanHST:UnitDead(unit)
 	if self.dirt[unit:ID()] then
 		self:EchoDebug(self.dirt[unit:ID()],'removed this unit' ,unit:ID())
 		local executer = self.game:GetUnitByID(self.dirt[unit:ID()])
		local uPos = executer:GetPosition()
		local floats = api.vectorFloat()
		-- populate with x, y, z of the position
		floats:push_back(uPos.x + math.random(25,50))
		floats:push_back(uPos.y)
		floats:push_back(uPos.z + math.random(25,50))
 		executer:ExecuteCustomCommand(CMD_PATROL,floats , {"shift"})
 		self.theCleaner[self.dirt[unit:ID()]] = nil
 		self.dirt[unit:ID()] = nil
 	end
 end
