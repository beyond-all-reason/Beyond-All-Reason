TaskLabBST = class(Behaviour)

function TaskLabBST:Name()
	return "TaskLabBST"
end

function TaskLabBST:Init()
	self.DebugEnabled = false
	self:EchoDebug('initialize tasklab')
	local u = self.unit:Internal()
	self.id = u:ID()
	self.name = u:Name()
	self.position = u:GetPosition()
	self:EchoDebug(self.name)
	self.spec = self.ai.armyhst.unitTable[self.name]
	self.mtype = self.ai.armyhst.factoryMobilities[self.name]
	self.isAirFactory = self.mtype == 'air'
	self.qIndex = 1
	self:resetCounters()
	self:ampRating() -- amph rating for this factory
	self.uDef = UnitDefNames[self.name]
	self.unities = self.uDef.buildOptions
	self.units = {}
	for index,unit in pairs(self.unities) do
		self:EchoDebug(index,unit)
		local uName = UnitDefs[unit].name
		self.units[uName] = {}
		self.units[uName].name = uName
		self.units[uName].type = self.game:GetTypeByName(uName)
		self.units[uName].army = self.ai.armyhst.unitTable[uName]
		self.units[uName].defId = unit
	end

end

function TaskLabBST:preFilter()
	local techLv = self.spec.techLevel
	local topLevel = self.ai.maxFactoryLevel
 	local threshold = 1 - (techLv / topLevel) + 0.05
	self:EchoDebug('prefilter threshold', threshold)
	if self.ai.Energy.full > 0.1 and self.ai.Metal.full > threshold then
		self.unit:Internal():FactoryUnWait()
	else
		self.unit:Internal():FactoryWait()
-- 		return true
	end
end

function TaskLabBST:Update()
-- 	 self.uFrame = self.uFrame or 0
	local f = self.game:Frame()
-- 	if f - self.uFrame < self.ai.behUp['tasklabbst'] then
-- 		return
-- 	end
-- 	self.uFrame = f
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'TaskLabBST' then return end
	self:preFilter() -- work or no resource??
	if Spring.GetFactoryCommands(self.id,0) > 1 then return end --factory alredy work
	self:GetAmpOrGroundWeapon() -- need more amph to attack in this map?

	local soldier, param, utype = self:getSoldier()
	self:EchoDebug('update',soldier)
	if soldier then
		for i=1,param.wave or 1 do
			utype = self.game:GetTypeByName(soldier)
			self.unit:Internal():Build(utype,self.unit:Internal():GetPosition(),0,{-1})
		end
	end
end

function TaskLabBST:getQueue()
	return self.ai.taskshst.labs.default
end

function TaskLabBST:getSoldier()
	self:EchoDebug('soldier')
	local soldier
	local param
	local utype
	self.queue = self:getQueue(self.name)
	for i = self.qIndex , #self.queue do
		param = self.queue[i]
		soldier,utype = self:getSoldierFromCategory(param.category)
		self:EchoDebug('soldier',soldier)
		soldier = self:ecoCheck(param.category,param.economy,soldier)
		self:EchoDebug('eco',soldier)
		soldier = self:countCheck(soldier,param.numeric)
		self:EchoDebug('count',soldier)
		soldier = self:toAmphibious(soldier)
		self:EchoDebug('amp',soldier)
		soldier = self:specialFilters(soldier,param.category)
		self:EchoDebug('special',soldier)
		self.qIndex = self.qIndex + 1
		if self.qIndex > #self.queue then
			self.qIndex = 1
		end
		if soldier then
			return soldier,param,utype
		end
	end

end

function TaskLabBST:specialFilters(soldier,category)
	if category == 'antiairs' and not self.ai.needAntiAir then
		return nil
	end
	return soldier
end

function TaskLabBST:getSoldierFromCategory(category)--we will take care about only one soldier per category per lab, if there are more than create another category
	for name,_ in pairs(self.ai.armyhst[category]) do
		utype = self.game:GetTypeByName(name)
		if self.unit:Internal():CanBuild(utype) then
			return name,utype
		end
	end
end

function TaskLabBST:ecoCheck(category,param,name,test)
	self:EchoDebug(category ,name, " (before eco check)")
	if not name  or not param then
		self:EchoDebug('ecofilter stop',name,cat, param)
		return
	end
	--print('soldier22',name,test)
	if self.queue[self.qIndex]:economy(name) then
		return name
	end
end

function TaskLabBST:countCheck(soldier,numeric)
	self:EchoDebug('countcheck',soldier)
	if not soldier then return end
	local Min = numeric.min or 0
	local Max = numeric.max or math.huge
	local mtypeFactor = numeric.mtype or 1
	local team = game:GetTeamID()
	local func = 0
	local spec = self.ai.armyhst.unitTable[soldier]
	local counter = self.game:GetTeamUnitDefCount(team,spec.defId)
	local mtypeLvCount = self.ai.tool:mtypedLvCount(self.ai.armyhst.unitTable[soldier].mtypedLv)
	local mTypeRelative = mtypeLvCount / mtypeFactor
	func = math.min(math.max(Min , mTypeRelative), Max)
	self:EchoDebug('mmType',mType , '/',counter,'func',func)
	if counter < func then
		self:EchoDebug('counter',soldier)
		return soldier
	end
end

function TaskLabBST:toAmphibious(soldier)
	local army = self.ai.armyhst
	local amphRank = (((ai.mobCount['shp']) / self.ai.mobilityGridArea ) +  ((#ai.UWMetalSpots) /(#ai.landMetalSpots + #ai.UWMetalSpots)))/ 2
	amphRank = self.amphRank or 0.5
	self:EchoDebug('amphRank',amphRank)
	if army.raiders[soldier] or army.battles[soldier] or army.breaks[soldier] or army.artillerys[soldier] then
		if math.random() < amphRank then
			for name,v in pairs(self.units) do
				if army.amphibious[name] then
					soldier = name
				end
			end
		end
	elseif army.techs[soldier] then
		if math.random() < amphRank then
			for name,v in pairs(self.units) do
				if army.amptechs[name] then
					soldier = name
				end
			end
		end
	end
	self:EchoDebug('toAmphibious', soldier)
	return soldier
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



             --[[

             function TaskLabBST:getSoldier()
	self:EchoDebug('soldier')
	local param
	local soldiers
	local queue = self:getQueue()
	for i = 0 , #queue do
		param = queue[self.qIndex]
		soldiers = self:scanRanks(param.category)
		if soldiers then
			self.qIndex = self.qIndex + 1
			if self.qIndex > #queue then
				self.qIndex = 1
			end
			break

		end
		self.qIndex = self.qIndex + 1
		if self.qIndex > #queue then
			self.qIndex = 1
		end
	end

 	soldier = self:ecoCheck(soldiers,param.economy)
	self:EchoDebug('eco',soldier)
 	soldier = self:countCheck(soldier,param.numeric)
 	self:EchoDebug('count',soldier)
	soldier = self:toAmphibious(soldier)
	self:EchoDebug('amp',soldier)
	soldier = self:specialFilters(soldier,param.category)
	self:EchoDebug('special',soldier)

 	if soldier then
 		return soldier,param
 	end
end


function TaskLabBST:scanRanks(rank)
	self:EchoDebug('rank',rank)
	local soldiers = {}
	local army = self.ai.armyhst
	for uName, spec in pairs (self.units) do
		if army[rank][uName] then
			table.insert(soldiers,uName)
		end
	end
	if #soldiers > 0 then
		self:EchoDebug('scanRank',#soldiers)
		return soldiers
	end
end

             function TaskLabBST:ecoCheck(soldiers)
	if not soldiers then return end
	self:EchoDebug('ecoCheck')
	local metal = self.ai.Metal.full
	local threshold = #soldiers
	local army = self.ai.armyhst.unitTable
	local mMax = 0
	local mRatio = 0
	local soldier = false
	local tmp = {}
	local first = table.remove(soldiers,1)
	tmp[1] = first
	while # soldiers > 0 do
		first = table.remove(soldiers,1)
		for i,v in pairs(tmp) do
			if army[first].metalCost < army[v].metalCost then
				table.insert(tmp,i,first)
				first = nil
				break
			end
		end
		if first then table.insert(tmp,-1,first) end
	end
	local idx = metal * threshold
	local idxN = math.ceil(idx)
	local target = tmp[idxN]

	self:EchoDebug(unpack(tmp),metal,threshold,idx,idxN,target)
	return target
end

             function TaskLabBST:getQueue()
	local queue = {

		{'techs',3,nil,10,2},
		{'scouts',1,10,2,2},
		{'raiders',1,nil,20,self.ai.raidhst.wave},
		{'techs',3,nil,10,1},
		{'battles',3,nil,25,5},
		{'techs',3,6,7,1},
		{'artillerys',1,10,10,5},
		{'techs',3,nil,10,1},
		{'breaks',2,5,15,3},
		{'techs',3,nil,10,1},
		{'rezs',1,8,10,2}, -- rezzers
		{'engineers',1,8,10}, --help builders and build thinghs
		{'antiairs',1,7,8,2},
		{'amptechs',1,7,5,1}, --amphibious builders
		{'jammers',1,nil,1	},
		{'radars',1,nil,1},
		{'airgun',1,5,10,5},
		{'bomberairs',10,4,20,5},
		{'fighterairs',1,5,10},
		{'paralyzers',1,10,5,3}, --have paralyzer weapon

		{'wartechs',1,nil,1}, --decoy etc
		{'techs',3,nil,5,3},
		{'subkillers',1,7,5}, -- submarine weaponed
		{'breaks',nil,nil,40,3},
		{'amphibious',0,7,20}, -- weapon amphibious
		{'spiders',nil,nil,15,10}, -- all terrain spider



-- 		{'transports',1,nil,nil},
-- 		{'spys',1,nil,1}, -- spy bot
-- 		{'miners',1,nil,nil},
-- 		{'antinukes',1,nil,nil},
-- 		{'crawlings',1,nil,1},
-- 		{'cloakables',0,0,10},
}
	return queue
end

TaskLabBST.queue = {

		{'techs',3,nil,10,1},
		{'scouts',1,10,2,2},
		{'raiders',1,nil,20,10},
		{'techs',3,nil,10,1},
		{'battles',3,nil,25,5},
		{'techs',3,6,7,1},
		{'artillerys',1,10,10,3},
		{'techs',3,nil,10,3},
		{'breaks',2,5,15,3},
		{'techs',3,nil,10,1},
		{'rezs',1,8,10,2}, -- rezzers
		{'engineers',1,8,10}, --help builders and build thinghs
		{'antiairs',1,7,8,2},
		{'amptechs',1,7,5,1}, --amphibious builders
		{'jammers',1,nil,1	},
		{'radars',1,nil,1},
		{'airgun',1,5,10,5},
		{'bomberairs',10,4,20,5},
		{'fighterairs',1,5,10},
		{'paralyzers',1,10,5,3}, --have paralyzer weapon

		{'wartechs',1,nil,1}, --decoy etc
		{'techs',3,nil,5,3},
		{'subkillers',1,7,5}, -- submarine weaponed
		{'breaks',nil,nil,40,3},
		{'amphibious',0,7,20}, -- weapon amphibious
		{'spiders',nil,nil,15,10}, -- all terrain spider



-- 		{'transports',1,nil,nil},
-- 		{'spys',1,nil,1}, -- spy bot
-- 		{'miners',1,nil,nil},
-- 		{'antinukes',1,nil,nil},
-- 		{'crawlings',1,nil,1},
-- 		{'cloakables',0,0,10},
}



-- 	for index,unit in pairs(self.unities) do
-- 		self:EchoDebug(index,unit)
-- 		local uName = UnitDefs[unit].name
-- 		self.units[uName] = {}
-- 		self.units[uName].name = uName
-- 		self.units[uName].type = self.game:GetTypeByName(uName)
-- 		self.units[uName].army = self.ai.armyhst.unitTable[uName]
-- 		self.units[uName].defId = unit
-- 	end
-- 	self.uDef = UnitDefNames[self.name]
-- 	self:EchoDebug(self.uDef)
-- 	self.unities = self.uDef.buildOptions
-- 	self.units = {}


function TaskLabBST:GetMtypedLvCount(unitName)
	local counter = self.ai.tool:mtypedLvCount(self.ai.armyhst.unitTable[unitName].mtypedLv)
	self:EchoDebug('mtypedLvmtype ' , counter)
	return counter
end
]]
