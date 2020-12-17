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
	self.army = self.ai.armyhst.unitTable[self.name]
	self:EchoDebug(self.name)
	self.uDef = UnitDefNames[self.name]
	self:EchoDebug(self.uDef)
	self.unities = self.uDef.buildOptions
	self.units = {}
	for index,unit in pairs(self.unities) do
		self:EchoDebug(index,unit)
		local uName = UnitDefs[unit].name
		self.units[uName] = {}
		self.units[uName].name = uName
		self.units[uName].type = game:GetTypeByName(uName)
		self.units[uName].army = self.ai.armyhst.unitTable[uName]
		self.units[uName].defId = unit
	end
end

--tech
--engineer
--scout
--raider
--battle
--breakthrough
--artillery
--other wave

function TaskLabBST:Choice()
	local team = game:GetTeamID()
	print(team)
	local build = false
-- 	print(units)
-- 	for i,v in pairs(units) do
-- 		print(i)
-- 		print(v)
-- 	end
	for name, spec in pairs(self.units) do

		print(name)
		self:EchoDebug('handling',name,spec.defId,type(spec.defId))
		local mtypedLv = self.ai.taskshst:GetMtypedLv(name)
		if spec.army.buildOptions then

			if game:GetTeamUnitDefCount(team,spec.defId) < math.min((mtypedLv / 6) + 1, self.ai.conUnitPerTypeLimit) then
				build = name
			end

		elseif spec.army.isWeapon then
			print(spec.army.onlyTg)
			self:EchoDebug('weapon')
			if spec.army.onlyTg == 'vtol' and self.ai.needAirDefense then
				self:EchoDebug('Anti air')
				if game:GetTeamUnitDefCount(team,spec.defId) < (mtypedLv / 10) + 1 then
					build = name
				end

			else
				self:EchoDebug('terrain')
				if self.ai.Metal.full < 0.5 then
					self:EchoDebug('metal<05')
					if spec.army.metalRatio < 1 then
						self:EchoDebug('ratio-1')
						build = name
					end
				else
					self:EchoDebug('metalok')
					if spec.army.metalRatio >  1 then
						self:EchoDebug('ratio+1')
						build = name
					end
				end

			end
		else
			self:EchoDebug('not handled',name)
		end

	end
	if not build then build = 'armwar' end
	return build
end

function TaskLabBST:Update()
	local f = self.game:Frame()
	if f % 311 == 0 then
		self.isBuilding = game:GetUnitIsBuilding(self.id)
		if Spring.GetFactoryCommands(self.id,0) >=2 then return end
-- 		if  self.isBuilding then return end
-- 		for index,unit in pairs(self.units) do
-- 			self:EchoDebug(index,unit)
-- 			self.unit:Internal():Build(unit.type)
-- 		end
		local choice = self:Choice()
		self:EchoDebug(choice)
		if choice then
			self.unit:Internal():Build(self.units[choice].type,nil,nil,{-1})
		end
	end
end
