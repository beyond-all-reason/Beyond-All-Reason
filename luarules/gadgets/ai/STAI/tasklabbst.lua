TaskLabBST = class(Behaviour)

function TaskLabBST:Name()
	return "TaskLabBST"
end

function TaskLabBST:Init()
	self.DebugEnabled = true
	self:EchoDebug('armlab loaded')
	local u = self.unit:Internal()
	self.id = u:ID()
	self.name = u:Name()
	self:EchoDebug(self.name)
	self.uDef = UnitDefNames[self.name]
	self:EchoDebug(self.uDef)
	self.unities = self.uDef.buildOptions
	self.units = {}
	for index,unit in pairs(self.unities) do
		self:EchoDebug(index,unit)
		self.units[UnitDefs[unit].name] = game:GetTypeByName(UnitDefs[unit].name)
	end
-- 	self.unit:Internal():Build(value)
end


function TaskLabBST:Choice()

end


function TaskLabBST:Update()
	local f = self.game:Frame()
	if f % 311 == 0 then
		self.isBuilding = Spring.GetUnitIsBuilding(self.id)
		self:EchoDebug('isBuilding',isBuilding,type(isBuilding))
		if  self.isBuilding then return end
		for index,unit in pairs(self.units) do
			self:EchoDebug(index,unit)
			self.unit:Internal():Build(unit)




		end
	end
end
