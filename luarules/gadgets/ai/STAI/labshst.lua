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
	local factoryCountPow = factoryCount * factoryCount
	if self.ai.overviewhst.ECONOMY >= factoryCount * 4 or self.ai.Energy.income > factoryCountPow * 800 then
		return true
	end
	self:EchoDebug('not economy to build factory')
end

function LabsHST:Update()
	if self.ai.schedulerhst.moduleTeam ~= self.ai.id or self.ai.schedulerhst.moduleUpdate ~= self:Name() then return end
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
		self:EchoDebug(factoryName,isAdvanced,isExperimental)
		if self.game:GetTeamUnitDefCount(self.ai.id,utn.defId) > 0 then
			self:EchoDebug(' already have a ',factoryName)
			buildMe = false
		end
		if buildMe and mtype == 'bot' and level == 1 then--dont start bot if veh is up and we d not have t3
			for id,lab in pairs(self.labs) do
				if lab.mtype == 'veh' and not self.ai.overviewhst.T3LAB then
					buildMe = false
					self:EchoDebug(' already have a ',lab.name,'but no t3 then',factoryName, 'is early')
					break
				end
			end
		end
		if buildMe and mtype == 'veh' and level == 1 then--dont start veh if bot is up and we d not have t3
			for id,lab in pairs(self.labs) do
				if lab.mtype == 'bot' and not self.ai.overviewhst.T3LAB then
					buildMe = false
					self:EchoDebug(' already have a ',lab.name,'but no t3 then',factoryName, 'is early')
					break
				end
			end
		end

 		if buildMe and mtype == 'air' and not self.ai.overviewhst.T2LAB  then
 			self:EchoDebug(factoryName ..' dont build air before advanced ')
 			buildMe = false
 		end
		if self.ai.overviewhst.needT2 and not self.ai.overviewhst.T2LAB and not T2 then
			self:EchoDebug(factoryName ..' not advanced when i need it')
			buildMe = false
		end
		if buildMe and self.ai.overviewhst.needT3 and not self.ai.overviewhst.T3LAB and not T3 then
			self:EchoDebug(factoryName ..' not Experimental when i need it')
			buildMe = false
		end
		if buildMe and not self.ai.overviewhst.needT2  and T2 then
			self:EchoDebug(factoryName .. ' Advanced when i dont need it')
			buildMe = false
		end
		if buildMe and not self.ai.overviewhst.needT3  and T3 then
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

function LabsHST:FactoryPosition(factoryName,builder)
	if not factoryName or not builder then return end
	local utype = self.game:GetTypeByName(factoryName)
	local site = self.ai.buildingshst
	local p = site:BuildNearNano(builder, utype)

	if p then
		self:EchoDebug(' position to build', factoryName, 'found at', p.x,p.z,'near nano')
		return p
	end
	p = site:searchPosNearCategories(utype, builder,50,780,{'_nano_'})
	if p then
		self:EchoDebug(' position to build', factoryName, 'found at', p.x,p.z,'near _nano_ ')
		return p
	end
	p = site:searchPosNearCategories(utype, builder,50,1000,{'factoryMobilities'})
	if p then
		self:EchoDebug(' position to build', factoryName, 'found at', p.x,p.z,'near factory')
		return p
	end
	p = site:searchPosNearCategories(utype, builder,50,nil,{'_mex_'})
	if p then
		self:EchoDebug(' position to build', factoryName, 'found at', p.x,p.z,'near mex')
		return p
	end
	p = site:searchPosNearCategories(utype, builder,50,nil,{'_llt_'})
	if p then
		self:EchoDebug(' position to build', factoryName, 'found at', p.x,p.z,'near llt')
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

function LabsHST:GetBuilderFactory(builder)

	if self:FactoriesUnderConstruction() then
		return
	end
	if not self:EconomyToBuildFactories() then
		return
	end
	local availableFactories = self:UpdateFactories()
	if builder:CanBuild(availableFactories[1]) then
		local p = self:FactoryPosition(availableFactories[1],builder)
		if p then
			p = self:PostPositionalFilter(p,availableFactories[1])
			if p then
				return p,availableFactories[1]
			end
		end
	end
end

function LabsHST:ClosestHighestLevelFactory(builder, maxDist)
	if not builder then return end
	local builderPos = builder:GetPosition()
	local minDist = maxDist or math.huge
	local Lab
	local maxLevel = 0
	for id, lab in pairs(self.ai.labshst.labs) do
		if self.ai.maphst:UnitCanGoHere(builder, lab.position) then
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
