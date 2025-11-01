LabsBST = class(Behaviour)

function LabsBST:Name()
	return "LabsBST"
end

function LabsBST:Init()
	self.DebugEnabled = false
	self:EchoDebug('initialize tasklab')
	local u = self.unit:Internal()
	self.id = u:ID()
	self.name = u:Name()
	self.position = u:GetPosition()
	self:EchoDebug(self.name)
	self.spec = self.ai.armyhst.unitTable[self.name]
	self.mtype = self.ai.armyhst.factoryMobilities[self.name][1]
	self.network = self.ai.maphst:MobilityNetworkHere(self.mtype,self.position)
	self.isAirFactory = self.mtype == 'air'
	self.face = u:GetFacing(self.id)
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
    self.exitRect = {
    	x1 = self.position.x - 40,
    	z1 = self.position.z - 40,
    	x2 = self.position.x + 40,
    	z2 = self.position.z + 40,
	}
	--self:ExitCheck()


end

function LabsBST:ExitCheck()
	for i,v in pairs(self.ai.armyhst.unitTable[self.name].unitsCanBuild) do

		if not Spring.TestMoveOrder(self.ai.armyhst.unitTable[v].defId, self.position.x, self.position.y, self.position.z) then
			self:EchoDebug('exitcheck failed',self.name)
			self.ai.cleanhst.cleanableByID[self.id] = self.id
			self.exitClosed = true
			return
		end
	end
end

function LabsBST:OwnerCreated()
	self.ai.labshst.labs[self.id] = {id = self.id,behaviour = self,name = self.name , position = self.position, underConstruction = true,level = self.spec.techLevel,exitRect = self.exitRect,mtype = self.mtype}

end
function LabsBST:OwnerBuilt()
	self.ai.labshst.labs[self.id].underConstruction = nil
	self.ai.labshst.lastLabEcoE = self.ai.ecohst.Energy.income
	local outX, outZ
	if self.face == 0 then
		outX = 0
		outZ = 200
	elseif self.face == 2 then
		outX = 0
		outZ = -200
	elseif self.face == 3 then
		outX = -200
		outZ = 0
	elseif self.face == 1 then
		outX = 200
		outZ = 0
	end
	self.ai.tool:GiveOrder(self.id,CMD.MOVE,{self.position.x + outX, self.position.y, self.position.z + outZ},0,'1-1')
	--self.unit:Internal():Move({x= self.position.x + outX, y = self.position.y, z = self.position.z + outZ})
end

function LabsBST:OwnerDead()
	self.ai.labshst.labs[self.id] = nil
end

function LabsBST:preFilter()
	self:EchoDebug('prefilter')

	if self.ai.ecohst.Energy.full > 0.1  then
		if self.unit:Internal():IsWaiting() then
			self:EchoDebug('lab is waiting -> restart')
			self.ai.tool:GiveOrder(self.id,CMD.WAIT,0,0,'1-1')
		end

	elseif self.ai.ecohst.Metal.full < 0.1 then
		for id, lab in pairs(self.ai.labshst.labs) do
			if lab.underConstruction  and not self.unit:Internal():IsWaiting() then
				self:EchoDebug('not enough metal and lab under construction -> wait')
				self.ai.tool:GiveOrder(self.id,CMD.WAIT,0,0,'1-1')
			end
		end
	else
		if not self.unit:Internal():IsWaiting() then
			self:EchoDebug('lab working under E-Stall -> wait')
			self.ai.tool:GiveOrder(self.id,CMD.WAIT,0,0,'1-1')
		end
	end
end

function LabsBST:Update()
	--if self.exitClosed then
	--	return
	--end
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'LabsBST' then return end
	local f = self.game:Frame()
	self:preFilter() -- work or no resource??
	if Spring.GetFactoryCommandCount(self.id) > 1 then return end -- factory already work
	self:GetAmpOrGroundWeapon() -- need more amph to attack in this map?
	local soldier, param, utype = self:getSoldier()
	if soldier then
		local limit = param.wave
   		if type(param.wave) == 'function' then
			self:EchoDebug('function param wave',self.queue[self.qIndex].wave)
			limit = param:wave(_)
		end

		self:EchoDebug('param.wave',param.wave,soldier)
		local unitList = {}
		local unitCmd = self.game:GetTypeByName(soldier):ID() *-1
		local unitParams = {}
		local unitOptions = {}
		for i=1,limit or 1 do
			unitList[i] = unitCmd
			unitParams[i] = 0
			unitOptions[i] = 0
		end
		self.ai.tool:GiveOrder(self.id,unitList,unitParams,unitOptions,'2-1')
	end
end

function LabsBST:getQueue()
	if self.name == 'armamsub' or self.name == 'coramsub' then
		return self.ai.taskshst.labs.amphibiousComplex

	end
	if self.spec.techLevel >= 3 then
		if self.ai.tool:countFinished({'_fus_'}) < 1 and self.ai.tool:countFinished({'t2mex'}) < 2 then
			return self.ai.taskshst.labs.premode
		end
	end
	if self.ai.armyhst.t1tot2factory[self.name]  then
		if self.ai.tool:countFinished({self.ai.armyhst.t1tot2factory[self.name]}) > 0 and self.ai.tool:countFinished({'_fus_'}) > 0 and self.ai.tool:countFinished({'t2mex'}) then
			return self.ai.taskshst.labs.t1postmode
		end
	end
	return self.ai.taskshst.labs.default
end

function LabsBST:getSoldier()
	self:EchoDebug('soldier')
	local soldier
	local param
	local utype
	self.queue = self:getQueue()

	for i = self.qIndex , #self.queue do
		param = self.queue[i]
		soldier,utype = self:getSoldierFromCategory(param.category)
		self:EchoDebug('soldier',soldier)
		if soldier then
			soldier = self:ecoCheck(param.category,param.economy,soldier)
			self:EchoDebug('eco',soldier)
			if soldier then
				soldier = self:countCheck(soldier,param.numeric)
				self:EchoDebug('count',soldier)
				if soldier then
					soldier = self:toAmphibious(soldier)
					self:EchoDebug('amp',soldier)
					if soldier then
						soldier,utype = self:specialFilters(soldier,param,utype)
						self:EchoDebug('special',soldier)
					end
				end
			end
		end
		self.qIndex = self.qIndex + 1
		if self.qIndex > #self.queue then
			self.qIndex = 1
		end
		if soldier then
			return soldier,param,utype
		end
	end

end

function LabsBST:specialFilters(soldier,param,utype)
	if param.category == 'antiairs' and not self.ai.needAntiAir then
		return nil,nil
	end
	if param.special and type(param.special) == 'function' then
		self:EchoDebug('function param special',self.queue[self.qIndex].wave)
		local newSoldier,newUtype = param:special(soldier,utype)
		return newSoldier,newUtype
	end

	return soldier,utype
end

function LabsBST:getSoldierFromCategory(category)--we will take care about only one soldier per category per lab, if there are more than create another category
	for name,_ in pairs(self.ai.armyhst[category]) do
		local utype = self.game:GetTypeByName(name)
		if self.unit:Internal():CanBuild(utype) then
			return name,utype
		end
	end
end

function LabsBST:ecoCheck(category,param,name,test)
	self:EchoDebug(category ,name, " (before eco check)")
	if not name  or not param then
		self:EchoDebug('ecofilter stop',name,category, param)
		return
	end
	if self.queue[self.qIndex]:economy(name) then
		return name
	end
end

function LabsBST:countCheck(soldier,numeric)
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
	self:EchoDebug('mmType',mtypeLvCount , '/',counter,'func',func)
	if counter < func then
		self:EchoDebug('counter',soldier)
		return soldier
	end
end

function LabsBST:toAmphibious(soldier)
	local army = self.ai.armyhst
-- 	local amphRank = (((maphst.mobilityCount['shp']) / maphst.gridArea ) +  ((#maphst.UWMetalSpots) /(#maphst.landMetalSpots + #maphst.UWMetalSpots)))/ 2
	local amphRank = self.amphRank or 0.5
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

function LabsBST:ampRating()
	-- precalculate amphibious rank
	local ampSpots = self.ai.maphst:AccessibleSpotsHere('amp', self.position)
	local vehSpots = self.ai.maphst:AccessibleSpotsHere('veh', self.position)
	local amphRank = 0
	if #ampSpots > 0 and #vehSpots > 0 then
		amphRank = 1 - (#vehSpots / #ampSpots)
	elseif #vehSpots == 0 and #ampSpots > 0 then
		amphRank = 1
	end
	self.amphRank = amphRank
end

function LabsBST:resetCounters()
	if self.isAirFactory then
		self.ai.couldBomb = 0
		self.ai.hasBombed = 0
	end
end

function LabsBST:GetMtypedLvCount(unitName)
	local counter = self.ai.tool:mtypedLvCount(self.ai.armyhst.unitTable[unitName].mtypedLv)
	self:EchoDebug('mtypedLvmtype ' , counter)
	return counter
end

function LabsBST:GetAmpOrGroundWeapon()
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
	if not network then
		self:EchoDebug('canbuild amphibious because no network')
		return true
	end
	return false
end
