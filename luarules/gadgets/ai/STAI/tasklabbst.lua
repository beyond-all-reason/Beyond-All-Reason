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
	self.position = u:GetPosition()
	self.army = self.ai.armyhst.unitTable[self.name]
	self:EchoDebug(self.name)
	self.uDef = UnitDefNames[self.name]
	self:EchoDebug(self.uDef)
	self.unities = self.uDef.buildOptions
	self.units = {}
	self.mtype = self.ai.armyhst.factoryMobilities[self.name]
	self.isAirFactory = self.mtype == 'air'
	for index,unit in pairs(self.unities) do
		self:EchoDebug(index,unit)
		local uName = UnitDefs[unit].name
		self.units[uName] = {}
		self.units[uName].name = uName
		self.units[uName].type = game:GetTypeByName(uName)
		self.units[uName].army = self.ai.armyhst.unitTable[uName]
		self.units[uName].defId = unit
	end
	self:resetCounters()
	self:ampRating()
end

function TaskLabBST:ampRating()
	-- precalculate amphibious rank
	local ampSpots = self.ai.maphst:AccessibleMetalGeoSpotsHere('amp', self.unit:Internal():GetPosition())
	local vehSpots = self.ai.maphst:AccessibleMetalGeoSpotsHere('veh', self.unit:Internal():GetPosition())
	local amphRank = 0
	if #ampSpots > 0 and #vehSpots > 0 then
		amphRank = 1 - (#vehSpots / #ampSpots)
	elseif #vehSpots == 0 and #ampSpots > 0 then
		amphRank = 1
	end
	self.amphRank = amphRank
end

function TaskLabBST:resetCounters()
	if self.isAirFactory then
		self.ai.couldBomb = 0
		self.ai.hasBombed = 0
	else
		self.ai.couldAttack = 0
		self.ai.hasAttacked = 0
	end
end

function TaskLabBST:GetAmpOrGroundWeapon()
	if (self.ai.armyhst.factoryMobilities[self.name][1] == 'bot' or self.ai.armyhst.factoryMobilities[self.name][1] == 'veh') then
		return
	end
	if self.ai.enemyBasePosition then
		if self.ai.maphst:MobilityNetworkHere('veh', self.position) ~= self.ai.maphst:MobilityNetworkHere('veh', self.ai.enemyBasePosition) and self.ai.maphst:MobilityNetworkHere('amp', self.position) == self.ai.maphst:MobilityNetworkHere('amp', self.ai.enemyBasePosition) then
			self:EchoDebug('canbuild amphibious because of enemyBasePosition')
			return true
		end
	end
	local mtype = self.ai.armyhst.factoryMobilities[self.name][1]
	local network = self.ai.maphst:MobilityNetworkHere(mtype, self.position)
	if not network or not self.ai.factoryBuilded[mtype] or not self.ai.factoryBuilded[mtype][network] then
		self:EchoDebug('canbuild amphibious because ' .. mtype .. ' network here is too small or has not enough spots')
		return true
	end
	return false
end

function TaskLabBST:Choice()
	local team = game:GetTeamID()
	local build = false
	for uName, spec in pairs(self.units) do
		local army = self.ai.armyhst.ranks[self.name][uName]
		if army == 'scout' then
			if game:GetTeamUnitDefCount(team,spec.defId) < 15 then
				return uName
			end
		end
		if army == 'tech' then
			if game:GetTeamUnitDefCount(team,spec.defId) < 5 then
				return uName
			end
		end
		if army == 'raider' then
			if game:GetTeamUnitDefCount(team,spec.defId) < 20 then
				return uName
			end
		end
		if army == 'artillery' then
			if game:GetTeamUnitDefCount(team,spec.defId) < 20 then
				return uName
			end
		end
		if army == 'battle' then
			if game:GetTeamUnitDefCount(team,spec.defId) < 20 then
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
			if game:GetTeamUnitDefCount(team,spec.defId) < 20 then
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



function TaskLabBST:Update()
	local f = self.game:Frame()
	if f % 111 == 0 then
		self:GetAmpOrGroundWeapon()
		self.isBuilding = game:GetUnitIsBuilding(self.id)
		if Spring.GetFactoryCommands(self.id,0) >=2 then return end
		local choice = self:Choice()
		self:EchoDebug(choice)
		if choice then
			self.unit:Internal():Build(self.units[choice].type,nil,nil,{-1})
		end
	end
end


--TODO
--tech
--engineer
--scout
--raider
--battle
--breakthrough
--artillery
--other wave


-- if self.isFactory and self.ai.factoryUnderConstruction and ( self.ai.Metal.full < 0.5 or self.ai.Energy.full < 0.5) then
	-- 	self:EchoDebug('limitate construction permiss')
	-- 	q = {}
	-- end



	-- 			if game:GetTeamUnitDefCount(team,spec.defId) < math.min((mtypedLv / 6) + 1, self.ai.conUnitPerTypeLimit) then
		-- 				build = name
		-- 			end



		-- 	if self.ai.taskshst:outmodedTaskqueues()[self.name] ~= nil and not q then
			-- 		local threshold =  1 - (uT[self.name].techLevel / self.ai.maxFactoryLevel)
			-- 		if self.isFactory  and (self.ai.Metal.full < threshold or self.ai.Energy.full < threshold) then
			-- 			local mtype = self.ai.armyhst.factoryMobilities[self.name][1]
			-- 			for level, factories in pairs (self.ai.factoriesAtLevel)  do
			-- 				for index, factory in pairs(factories) do
			-- 					local factoryName = factory.unit:Internal():Name()
			-- 					if mtype == self.ai.armyhst.factoryMobilities[factoryName][1] and uT[self.name].techLevel < level then
			-- 						self:EchoDebug( self.name .. ' have major factory ' .. factoryName)
			-- 						-- stop buidling lvl1 attackers if we have a lvl2, unless we're with proportioned resources
			-- 						q = self.ai.taskshst:outmodedTaskqueues()[self.name]
			-- 						self.outmodedTechLevel = true
			-- 						self:EchoDebug(self.name, 'is outmoded')
			-- 						break
			-- 					end
			-- 				end
			-- 				if q then break end
			-- 			end
			--
			-- 		elseif self.outmodedFactory then
			-- 			q = self.ai.taskshst:outmodedTaskqueues()[self.name]
			-- 		end
			-- 	end






			-- 	if self.isFactory and f % 311 == 0 and (self.ai.armyhst.factoryMobilities[self.name][1] == 'bot' or self.ai.armyhst.factoryMobilities[self.name][1] == 'veh') then
			-- 		self.AmpOrGroundWeapon = self:GetAmpOrGroundWeapon()
			-- 	end



-- 			                               success = self.unit:Internal():Build(utype)
