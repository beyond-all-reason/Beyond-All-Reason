TaskLabBST = class(Behaviour)

function TaskLabBST:Name()
	return "TaskLabBST"
end

function TaskLabBST:Init()
	self.DebugEnabled = true
	self:EchoDebug('initialize tasklab')
	local u = self.unit:Internal()
	self.id = u:ID()
	self.name = u:Name()
	self.position = u:GetPosition()
	self.army = self.ai.armyhst.unitTable[self.name]
	self.fails = 0
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

function TaskLabBST:getSoldier()
	self:EchoDebug('soldier')
	local soldier
	for index,param in ipairs(self.queue) do
		local soldiers = self:scanRanks(param[1])
		soldier = self:ecoCheck(soldiers)
		soldier = self:countCheck(soldier,param[2],param[3],param[4])
		soldier = self:toAmphibious(soldier)
		if soldier then
			self.fails = 0
			return soldier,param
		end
	end
	self.fails = self.fails +1
end
function TaskLabBST:ecoCheck(soldiers)
	self:EchoDebug('ecoCheck')
	if not soldiers then return end
	local metal = self.ai.Metal.full
	local threshold = 1 / #soldiers
	local army = self.ai.armyhst.unitTable
	local mMax = 0
	local mRatio = 0
	local soldier = false
	for index, uname in pairs (soldiers) do
		mMax = math.max(mMax,army[uname].metalCost)
		soldier = uname
	end
	self:EchoDebug('eco Mmax',Mmax)
	for index, uname in pairs (soldiers) do

		if army[uname].metalCost / mMax < threshold and army[uname].metalCost / mMax > mRatio then
			mRatio = army[uname].metalCost
			soldier = uname
		end
	end
	if soldier then
		self:EchoDebug('eco',soldier)
		return soldier

	end
end

function TaskLabBST:countCheck(soldier,Min,mType,Max)
	self:EchoDebug('countcheck',soldier)
	if not soldier then return end
	Min = Min or 0
	Max = Max or 1 / 0
	local team = game:GetTeamID()
	local func = 0
	local spec = self.ai.armyhst.unitTable[soldier]
	local counter = game:GetTeamUnitDefCount(team,spec.defId)
	local mtypeLv = self.ai.taskshst:GetMtypedLv(soldier)

	if mType then
		local mmType = (mtypeLv / mType) + 1
		func = math.min(math.max(Min , mmType), Max)
	else
		func = math.max(Min,Max)
	end
	self:EchoDebug('mmType',mmType , '/',counter,'func',func)
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





TaskLabBST.queue = {
		{'techs',1,10,15},
		{'raiders',nil,5,10,5},
		{'breaks',1,5,20,5},
		{'battles',nil,7,12,5},
		--{'scouts',1,nil,1},

		{'rezs',1,8,10}, -- rezzers
		{'engineers',1,8,10}, --help builders and build thinghs
		{'antiairs',nil,7,10},
		{'amptechs',1,7,5}, --amphibious builders
		{'jammers',1,nil,1	},
		{'radars',1,nil,1},
		{'bomberairs',10,4,20,5},
		{'bomberairs',1,5,20,5},
		{'fighterairs',1,5,10},
		{'paralyzers',1,10,5}, --have paralyzer weapon
		{'artillerys',0,10,5},
		{'wartechs',1,nil,1}, --decoy etc
		{'subkillers',1,7,5}, -- submarine weaponed
		{'breaks',nil,nil,40},
		{'amphibious',0,7,20}, -- weapon amphibious
-- 		{'transports',1,nil,nil},
-- 		{'spys',1,nil,1}, -- spy bot
-- 		{'miners',1,nil,nil},
-- 		{'spiders',0,0,10}, -- all terrain spider
-- 		{'antinukes',1,nil,nil},
-- 		{'crawlings',1,nil,1},
-- 		{'cloakables',0,0,10},
}

function TaskLabBST:preFilter()
	local spec = self.ai.armyhst.unitTable[self.name]
	local techLv = spec.techLevel
	local topLevel = self.ai.maxFactoryLevel
	local threshold = 1 - (techLv / self.ai.maxFactoryLevel)
	self:EchoDebug('prefilter threshold', threshold)
	if self.ai.Metal.full > threshold then
		return true
	end
end

function TaskLabBST:Update()
	local f = self.game:Frame()
	if f % 111 == 0 then
-- 		if not self:preFilter() then return end
		self:GetAmpOrGroundWeapon()
		self.isBuilding = game:GetUnitIsBuilding(self.id)--TODO better this?
		if Spring.GetFactoryCommands(self.id,0) > 0 then return end
		local soldier, param = self:getSoldier()
		self:EchoDebug('update',soldier)
		if soldier then
-- 			if param[5] then
				for i=1,param[5] or 1 do
					self.unit:Internal():Build(self.units[soldier].type,nil,nil,{-1})
				end
-- 			else
-- 				self.unit:Internal():Build(self.units[soldier].type,nil,nil,{-1})
-- 			end
		end
	end
end
