LabsHST = class(Module)

function LabsHST:Name()
	return "LabsHST"
end

function LabsHST:internalName()
	return "labshst"
end

function LabsHST:Init()
	self.DebugEnabled = false
	self.labs = {}
	self.ECONOMY = 0
	self.lastLabEcoM = 0
	self.lastLabEcoE = 0
	self:factoriesRating()
end

function LabsHST:factoriesRating()
	local networks = self.ai.maphst.networks
	local factoryRating = {}
	local topRatingArea = 0
	local topRatingSpots = 0
	for factory,mtypes in pairs(self.ai.armyhst.factoryMobilities)do
		factoryRating[factory] = {}
		local unitCount = 0
		if mtypes[1] == 'air' then
			factoryRating[factory].area = 1
			factoryRating[factory].allSpots = 1
			factoryRating[factory].rating = 0.55
		else
			factoryRating[factory].area = 0
			factoryRating[factory].allSpots = 0
			for index, unit in pairs( self.ai.armyhst.unitTable[factory].unitsCanBuild) do
				unitCount = unitCount + 1
				local mtype = self.ai.armyhst.unitTable[unit].mtype
				if self.ai.maphst.layers[mtype] then
					factoryRating[factory].area = factoryRating[factory].area + (self.ai.maphst.layers[mtype].area or 0)
				end
				if self.ai.maphst.layers[mtype] then
					factoryRating[factory].allSpots = factoryRating[factory].allSpots + (self.ai.maphst.layers[mtype].allSpots or 0)
				end
			end
			factoryRating[factory].area  = (factoryRating[factory].area / unitCount)
			factoryRating[factory].allSpots = factoryRating[factory].allSpots / unitCount
			topRatingArea = math.max(topRatingArea,factoryRating[factory].area)
			topRatingSpots = math.max(topRatingSpots,factoryRating[factory].allSpots)
		end
	end
	local t= {}
	for i,v in pairs(factoryRating) do
		if v.rating then
			t[i] = v.rating
		elseif (v.area > 0) then
			v.area = v.area / topRatingArea
			v.allSpots = v.allSpots / topRatingSpots
			v.rating = (v.area+v.allSpots)/2


			t[i] = v.rating
			self:EchoDebug('tmp',i,v.rating)
		end
	end
	for i,v in pairs(t) do
		self:EchoDebug('pre sorted',i,v)
		if self.ai.armyhst.factoryMobilities[i][1] == 'hov' or self.ai.armyhst.factoryMobilities[i][1] == 'amp' then
			if not t['armsy'] or  t['armsy'] < 0.33 then
				t[i] = nil
			elseif i == 'armamsub' or i == 'coramsub' then
				t[i] = (t['armsy'] + t['armvp']) * 0.5
			elseif not t['armvp'] or  (t['armvp'] < 0.6 and t['armsy'] < 0.6) then

				t[i] = 1

			else
				t[i] = t[i] * 0.49
			end
		end
		if self.ai.armyhst.factoryMobilities[i][1] == 'veh' then
			local areaRatio = self.ai.maphst.gridArea / (64*64) --the ratio of max teoric  map dimension
			t[i] = t[i] * 1+(areaRatio *0.1)
		end
	end

	local sorting = {}
	local rank = {}
	for name, rating in pairs(t) do

        self:EchoDebug('name,rating,rank[rating]',name,rating,rank[rating])
		if not rank[rating] then
			rank[rating] = {}
			table.insert(rank[rating],name)
		else
			table.insert(rank[rating],name)
		end
		table.insert(sorting, rating)
	end
	table.sort(sorting)
	local factoriesRanking = {}
	local ranksByFactories = {}
	for i= #sorting,1,-1 do--in pairs(sorting) do
		local v = sorting[i]
		for ii = #rank[v], 1, -1 do
			local factoryName = table.remove(rank[v],ii)
			table.insert(factoriesRanking, factoryName)
			ranksByFactories[factoryName] = t[factoryName]
			self:EchoDebug('i-factoryname',i,factoryName,t[factoryName])
		end
	end
	self.factoryRating = factoriesRanking
	self.ranksByFactories = ranksByFactories
	for i,v in pairs(self.factoryRating) do
		self:EchoDebug(i,v,self.ranksByFactories[v])
	end
end

function LabsHST:FactoriesUnderConstruction()
	for id,project in pairs(self.ai.buildingshst.builders) do
		if self.ai.armyhst.factoryMobilities[project.unitName] then
			self:EchoDebug('factory under contruction',project.unitName,'at',project.position.x,project.position.z)
			return true
		end
	end
end

function LabsHST:EconomyToBuildFactories()
	local factoryCount = 0
	for id,factory in pairs(self.labs) do
		factoryCount = factoryCount + 1
	end
-- 	local factoryCountPow = factoryCount * factoryCount
-- 	if self.ECONOMY or 0 >= factoryCount * 4 or self.ai.ecohst.Energy.income > factoryCountPow * 800 then
-- 		return true
-- 	end
	if factoryCount == 0 then return true end
	if self.ai.ecohst.Energy.income > self.lastLabEcoE + (600*factoryCount) then return true end
	self:EchoDebug('not economy to build factory')
end

function LabsHST:Update()
	if self.ai.schedulerhst.moduleTeam ~= self.ai.id or self.ai.schedulerhst.moduleUpdate ~= self:Name() then return end
	self:LabsLevels()
	local M = self.ai.ecohst.Metal
	local E = self.ai.ecohst.Energy
	self.X100M = self.ai.tool:countMyUnit({'extractsMetal'}) / #self.ai.maphst.METALS
	self.ECONOMY = math.floor(math.min(M.income / 10,E.income / 100))
	self.needT2 = ((M.income > 20 or self.X100M > 0.2) and E.income > 800 and self.T1LAB)
	self.needT3 = ((M.income > 50 or self.X100M > 0.4) and E.income > 4000 and self.T2LAB)
	self:EchoDebug('ECO',self.ECONOMY , ' M',math.floor(M.income / 10), 'E',math.floor(E.income / 100),'X100M',self.X100M,'lab',self.T1LAB,self.T2LAB,M.income > 20,E.income > 800)

	self.ai.buildingshst:VisualDBG()--here cause buildingshst have no update
end

function LabsHST:UpdateFactories()
	local factoriesPreCleaned = self:PrePositionFilter()
	return self:AvailableFactories(factoriesPreCleaned)


end

function LabsHST:AvailableFactories(factoriesPreCleaned)
	local availableFactories = {}
	for order,factoryName in pairs (factoriesPreCleaned) do
		local utype = self.game:GetTypeByName(factoryName)
		for id,role in pairs(self.ai.buildingshst.roles) do
		local builderType = self.game:GetTypeByName(role.builderName)
			if builderType:CanBuild(utype) then
				table.insert(availableFactories,factoryName)
				self:EchoDebug(factoryName , ' is available Factories' ,self.ranksByFactories[factoryName])
				break
			end
		end
	end
	return availableFactories
end

function LabsHST:GetLabListParam(param,value)
	for id, factory in pairs(self.labs) do
		if factory[param] and factory[param] == value then
			return id,factory.name
		end
	end
end

function LabsHST:LabsLevels()
	self.maxFactoryLevel = 0
	for id,lab in pairs(self.labs) do
		if lab.level > self.maxFactoryLevel then
			self.maxFactoryLevel = lab.level
		end
		if lab.level == 1 then
			self.T1LAB = true
		elseif lab.level == 3 then
			self.T2LAB = true
		elseif lab.level == 5 then
			self.T3LAB = true
		end
	end
end

function LabsHST:PrePositionFilter()
	self:EchoDebug('pre positional filtering...')
	local factoriesPreCleaned = {}
	for rank, factoryName in pairs(self.factoryRating) do
		local buildMe = true
		local utn=self.ai.armyhst.unitTable[factoryName]
		local level = utn.techLevel
		local T1 = level == 1
		local T2 = level == 3
		local T3 = level == 5
		local mtype = self.ai.armyhst.factoryMobilities[factoryName][1]
		self:EchoDebug(factoryName, 'rank', rank, 'level', level, 'mtype', mtype)
		if self.game:GetTeamUnitDefCount(self.ai.id,utn.defId) > 0 then
			self:EchoDebug(' already have a ',factoryName)
			buildMe = false
		end
		if self.ai.armyhst.factoryMobilities[factoryName][1] == 'hov'  then
			for id,lab in pairs(self.labs) do
				if lab.mtype == 'hov' then
					buildMe = false
					self:EchoDebug(' already have a ',lab.name,' another hover factory',factoryName, 'is duplicated')
					buildMe = false
				end
			end
		end
		if buildMe and mtype == 'bot' and level == 1 then--dont start bot if veh is up and we d not have t3
			for id,lab in pairs(self.labs) do
				if lab.mtype == 'veh' and not self.T3LAB then
					buildMe = false
					self:EchoDebug(' already have a ',lab.name,'but no t3 then',factoryName, 'is early')
					break
				end
			end
		end
		if buildMe and mtype == 'veh' and level == 1 then--dont start veh if bot is up and we d not have t3
			for id,lab in pairs(self.labs) do
				if lab.mtype == 'bot' and not self.T3LAB then
					buildMe = false
					self:EchoDebug(' already have a ',lab.name,'but no t3 then',factoryName, 'is early')
					break
				end
			end
		end

 		if buildMe and mtype == 'air' and not self.T2LAB  then
 			self:EchoDebug(factoryName ..' dont build air before advanced ')
 			buildMe = false
 		end
		if self.needT2 and not self.T2LAB and not T2 then
			self:EchoDebug(factoryName ..' not advanced when i need it')
			buildMe = false
		end
		if buildMe and self.needT3 and not self.T3LAB and not T3 then
			self:EchoDebug(factoryName ..' not Experimental when i need it')
			buildMe = false
		end
		if buildMe and not self.needT2  and T2 then

			self:EchoDebug(factoryName .. ' Advanced when i dont need it',buildMe,self.needT2,T2)
			buildMe = false
		end
		if buildMe and not self.needT3  and T3 then
			self:EchoDebug(factoryName .. ' Experimental when i dont need it')
			buildMe = false
		end
		if buildMe and mtype == 'air' and utn.needsWater and self:GetLabListParam('mtype','air') then
			self:EchoDebug(factoryName .. ' dont build seaplane if i have normal planes')
			buildMe = false
		end
		if buildMe then
			table.insert(factoriesPreCleaned,factoryName)
			self:EchoDebug('rank ', #factoriesPreCleaned, factoryName, ' in factoryPreCleaned')
		end
	end
	return factoriesPreCleaned
end

function LabsHST:FactoryPosition(factoryName,builder)--TODO test ildpos with bigger labs and do a check for exitside with bigger units
	if not factoryName or not builder then self:EchoDebug('no factory or builder')return end
	local utype = self.game:GetTypeByName(factoryName)
	local site = self.ai.buildingshst
	
	local p = site:BuildNearNano(builder, utype)


	if not p then
		self:EchoDebug(' not position to build', factoryName, 'near nano')
	else
		self:EchoDebug(' position to build', factoryName, 'near nano')
		return p
	end
	p = site:searchPosNearCategories(utype, builder,50,390,{'_nano_'})
	if not p then
		self:EchoDebug(' not position to build', factoryName, 'near _nano_ ')
	else
		self:EchoDebug(' position to build', factoryName, 'near _nano_')
		return p
	end
	p = site:searchPosNearCategories(utype, builder,250,780,{'factoryMobilities'})
	if not p then
		self:EchoDebug('not position to build', factoryName, 'near factory')
	else
		self:EchoDebug(' position to build', factoryName, 'near factory')
		return p
	end
	p = site:searchPosNearCategories(utype, builder,150,nil,{'_mex_'})
	if not p then
		self:EchoDebug(' not position to build', factoryName, 'near mex')
	else
		self:EchoDebug(' position to build', factoryName, 'near _mex_')
		return p
	end
	p = site:searchPosNearCategories(utype, builder,50,nil,{'_llt_'})
	if not p then
		self:EchoDebug(' not position to build', factoryName, 'near _llt_')
	else
		self:EchoDebug(' position to build', factoryName, 'near _llt_')
		return p
	end
	
end

function LabsHST:PostPositionalFilter(p,factoryName)
	for i, mtype in pairs(self.ai.armyhst.factoryMobilities[factoryName]) do
		local network = self.ai.maphst:MobilityNetworkHere(mtype, p)
		if  (self.ai.maphst.networks[mtype][network].area / self.ai.maphst.gridArea) < 0.05 then--5% of the maphst
			self:EchoDebug('area to small to build lab: ',factoryName)
			return
		end
		if #self.ai.maphst.networks[mtype][network].metals / #self.ai.maphst.METALS < 0.05 then--5% of the metals
			self:EchoDebug('not enough spots to build lab: ', factoryName)
			return
		end
	end
	return p,factoryName
end

function LabsHST:LandOrWaterType(builder,factory)
	local _,y,_ = builder:GetRawPos()
	local water = y < 0
	local factoryName = factory
	if water then
		if factoryName == 'corhp' then
			factoryName = 'corfhp'
		end
		if factoryName == 'armhp' then
			factoryName = 'armfhp'
		end
	else
		if factoryName == 'corfhp' then
			factoryName = 'corhp'
		end
		if factoryName == 'armfhp' then
			factoryName = 'armhp'
		end
	end
	return factoryName
end

function LabsHST:GetBuilderFactory(builder)

	if self:FactoriesUnderConstruction() then
		self:EchoDebug('factory under construction')
		return
	end
	if not self:EconomyToBuildFactories() then
		self:EchoDebug('not enough economy to build factory')
		return
	end
	local availableFactories = self:UpdateFactories()
	local factoryName = self:LandOrWaterType(builder,availableFactories[1])
	if not builder:CanBuild(factoryName) then
		self:EchoDebug('builder cant build',factoryName)
		return
	end

	local p = self:FactoryPosition(factoryName,builder)
	if not p then
		self:EchoDebug('no position to build',factoryName)
		return
	end
	p = self:PostPositionalFilter(p,factoryName)
	if not p then
		self:EchoDebug('post position failed to build',factoryName)
		return
	end
	return p,factoryName
end

function LabsHST:ClosestHighestLevelFactory(builder, maxDist)
	if not builder then return end
	local builderPos = builder:GetPosition()
	local minDist = maxDist or math.huge
	local Lab
	local maxLevel = 0
	for id, lab in pairs(self.ai.labshst.labs) do
		if self.ai.maphst:UnitCanGoHere(builder, self.ai.tool:RandomAway(lab.position,300)) then
			local dist = self.ai.tool:distance(builderPos, lab.position)
			if lab.level >= maxLevel and dist <= minDist then
				minDist = dist
				maxLevel = lab.level
				Lab = lab
			end
		end
	end
	return Lab
end
