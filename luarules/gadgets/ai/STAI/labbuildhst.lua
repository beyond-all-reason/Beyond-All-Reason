LabBuildHST = class(Module)

function LabBuildHST:Name()
	return "LabBuildHST"
end

function LabBuildHST:internalName()
	return "labbuildhst"
end

function LabBuildHST:Init()
	self.DebugEnabled = true
	self.labs = {}
	self:factoriesRating()
end

function LabBuildHST:factoriesRating()
	local networks = self.ai.maphst.networks
 	for layer,net in pairs(networks) do
		self.factoryBuilded[layer] = {}
 		for index, network in pairs(net) do
			self.factoryBuilded[layer][index] = 0
 		end
 	end
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
			factoryRating[factory].area  =factoryRating[factory].area / unitCount
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
			if self.ai.armyhst.factoryMobilities[i][1] == 'hov' or self.ai.armyhst.factoryMobilities[i][1] == 'amp' then
				v.rating = v.rating * 0.66
			end

			t[i] = v.rating
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
	for i,v in pairs(sorting) do
		for ii = #rank[v], 1, -1 do
			local factoryName = table.remove(rank[v],ii)
			table.insert(factoriesRanking, factoryName)
			ranksByFactories[factoryName] = #factoriesRanking
			self:EchoDebug('i-factoryname',(i .. ' ' .. factoryName))
		end
	end

	self.factoryRating = factoriesRanking
	self.ranksByFactories = ranksByFactories
end


function LabBuildHST:FactoriesUnderConstruction()
	for id,sketch in pairs(self.ai.buildingshst.sketch) do
		if self.ai.armyhst.factoryMobilities[sketch.unitName] then
			self:EchoDebug('factory under contruction',sketch.unitName,'at',sketch.position.x,sketch.position.z)
			return true
		end
	end
end

function LabBuildHST:ConditionsToBuildFactories2()
	local fatoryCount = 0
	for id,factory in pairs(self.labs) do
		fatoryCount = fatoryCount + 1
	end
	if self.ai.Energy.income > factoryCount * 800 then
		return true
	end
end

function LabBuildHST:Update()
	if self.ai.schedulerhst.moduleTeam ~= self.ai.id or self.ai.schedulerhst.moduleUpdate ~= self:Name() then return end
	if self:FactoriesUnderConstruction() then
		return
	end
	if not self:ConditionsToBuildFactories2() then
		return
	end
	self:UpdateFactories()
	self.ai.buildingshst:VisualDBG()--here cause buildingshst have no update
end


function LabBuildHST:UpdateFactories()
	local factoriesPreCleaned = self:PrePositionFilter()
	local availableFactories = self:AvailableFactories(factoriesPreCleaned)

end

function LabBuildHST:AvailableFactories(factoriesPreCleaned)
	local availableFactories = {}
	for order,factoryName in pairs (factoriesPreCleaned) do
		local utype = self.game:GetTypeByName(factoryName)
		for id,role in pairs(self.ai.buildingshst.roles) do
		local builderType = self.game:GetTypeByName(builderName)
			if builderType:CanBuild(utype) then
				table.insert(availableFactories,factoryName)
				(factoryName , ' is available Factories' )
				break
			end
		end
	end
end

function LabBuildHST:GetLabListParam(param,value)
	for id, factory in pairs(self.labs) do
		if factory[param] and factory[param] == value then
			return id,factory.name
		end
	end
end

function LabBuildHST:PrePositionFilter()
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

function LabBuildHST:FactoryPosition(factoryName,builder)
	local utype = self.game:GetTypeByName(factoryName)
	local site = self.ai.buildingshst
	local p
	if p = site:BuildNearNano(builder, utype) then
		self:EchoDebug(' position to build', factoryName, 'found at', p.x,p.z,'near nano')
		return p
	end
	if p = site:searchPosNearCategories(utype, builder,50,nil,{'_nano_'}) then
		self:EchoDebug(' position to build', factoryName, 'found at', p.x,p.z,'near _nano_ ')
		return p
	end
	if p = site:searchPosNearCategories(utype, builder,50,1000,{'factoryMobilities'}) then
		self:EchoDebug(' position to build', factoryName, 'found at', p.x,p.z,'near factory')
		return p
	end
	if p = site:searchPosNearCategories(utype, builder,50,nil,{'_mex_'}) then
		self:EchoDebug(' position to build', factoryName, 'found at', p.x,p.z,'near mex')
		return p
	end
	if p = site:searchPosNearCategories(utype, builder,50,nil,{'_llt_'}) then
		self:EchoDebug(' position to build', factoryName, 'found at', p.x,p.z,'near llt')
		return p
	end
end

function LabBuildHST:PostPositionalFilter(factoryName,p)
	for i, mtype in pairs(self.ai.armyhst.factoryMobilities[factoryName]) do
		local network = self.ai.maphst:MobilityNetworkHere(mtype, p)
		if not self.ai.maphst.networks[mtype][network].area / self.ai.maphst.gridArea > 0.05 then--5% of the maphst
			self:EchoDebug('area to small to build lab: ',factoryName)
			return
		end
		if not #self.ai.maphst.networks[mtype][network].metals / #self.ai.maphst.metals > 0.05 then--5% of the metals
			self:EchoDebug('not enough spots to build lab: ', factoryName)
			return
		end
	end
end
