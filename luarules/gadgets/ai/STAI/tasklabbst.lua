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
	local build = false
	for uName, spec in pairs(self.units) do
		local army = self.ai.armyhst.ranks[self.name][uName]
		if army == 'scout' then
			if game:GetTeamUnitDefCount(team,spec.defId) < 1 then
				return uName
			end
		end
		if army == 'tech' then
			if game:GetTeamUnitDefCount(team,spec.defId) < 1 then
				return uName
			end
		end
		if army == 'raider' then
			if game:GetTeamUnitDefCount(team,spec.defId) < 1 then
				return uName
			end
		end
		if army == 'artillery' then
			if game:GetTeamUnitDefCount(team,spec.defId) < 1 then
				return uName
			end
		end
		if army == 'battle' then
			if game:GetTeamUnitDefCount(team,spec.defId) < 1 then
				return uName
			end
		end
		if army == 'radar' then
			if game:GetTeamUnitDefCount(team,spec.defId) < 1 then
				return uName
			end
		end
		if army == 'jammer' then
			if game:GetTeamUnitDefCount(team,spec.defId) < 1 then
				return uName
			end
		end
		if army == 'antiair' then
			if game:GetTeamUnitDefCount(team,spec.defId) < 1 then
				return uName
			end
		end
		if army == 'AntiNuke' then
			if game:GetTeamUnitDefCount(team,spec.defId) < 1 then
				return uName
			end
		end
		if army == 'break' then
			if game:GetTeamUnitDefCount(team,spec.defId) < 1 then
				return uName
			end
		end
		if army == 'paralyzer' then
			if game:GetTeamUnitDefCount(team,spec.defId) < 1 then
				return uName
			end
		end
		if army == 'artillery' then
			if game:GetTeamUnitDefCount(team,spec.defId) < 1 then
				return uName
			end
		end
		if army == 'longrange' then
			if game:GetTeamUnitDefCount(team,spec.defId) < 1 then
				return uName
			end
		end
		if army == 'subKiller' then
			if game:GetTeamUnitDefCount(team,spec.defId) < 1 then
				return uName
			end
		end
		if army == 'wartech' then
			if game:GetTeamUnitDefCount(team,spec.defId) < 1 then
				return uName
			end
		end

	end
end
-- 			if game:GetTeamUnitDefCount(team,spec.defId) < math.min((mtypedLv / 6) + 1, self.ai.conUnitPerTypeLimit) then
-- 				build = name
-- 			end



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
