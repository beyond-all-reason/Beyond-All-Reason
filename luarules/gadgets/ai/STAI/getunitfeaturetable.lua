-- BEGIN CODE BLOCK TO COPY AND PASTE INTO shard_help_unit_feature_table.lua

local backupUnitFeature = false

local hoverplatform = {
	armhp = 1,
	armfhp = 1,
	corhp = 1,
	corfhp = 1,
}

local fighter = {
	armfig = 1,
	corveng = 1,
	armhawk = 1,
	corvamp = 1,
}


local commanderSide = {
	armcom = "arm",
	corcom = "core",
}

local unitsLevels = {}
local armTechLv ={}
local corTechLv ={}
corTechLv.corcom = false
armTechLv.armcom = false
local parent = 0
local continue = false

local featureKeysToGet = { "metal" , "energy", "reclaimable", "blocking", }


local function GetLongestWeaponRange(unitDefID, GroundAirSubmerged)
	local weaponRange = 0
	local unitDef = UnitDefs[unitDefID]
	local weapons = unitDef["weapons"]
	for i=1, #weapons do
		local weaponDefID = weapons[i]["weaponDef"]
		local weaponDef = WeaponDefs[weaponDefID]
		-- Spring.Echo(weaponDefID)
		-- Spring.Echo(weaponDef["canAttackGround"])
		-- Spring.Echo(weaponDef["waterWeapon"])
		 --Spring.Echo(weaponDef["range"])
		 --Spring.Echo(weaponDef["type"])
		local wType = 0
		if weaponDef["canAttackGround"] == false then
			wType = 1
		elseif weaponDef["waterWeapon"] then
			wType = 2
		else
			wType = 0
		end
		-- Spring.Echo(wType)
		if wType == GroundAirSubmerged then
			if weaponDef["range"] > weaponRange then
				weaponRange = weaponDef["range"]
			end
		end
	end
	return weaponRange
end

local function GetBuiltBy()
	local builtBy = {}
	for unitDefID,unitDef in pairs(UnitDefs) do
		if unitDef.buildOptions and #unitDef.buildOptions > 0 then
			for i, buildDefID in pairs(unitDef.buildOptions) do
				local buildDef = UnitDefs[buildDefID]
				builtBy[buildDefID] = builtBy[buildDefID] or {}
				table.insert(builtBy[buildDefID], unitDefID)
			end
		end
	end
	return builtBy
end

local function GetUnitSide(name)
	if string.find(name, 'arm') then
		return 'arm'
	elseif string.find(name, 'cor') then
		return 'core'
	elseif string.find(name, 'chicken') then
		return 'chicken'
	end
	return 'unknown'
end

local function getTechTree(sideTechLv)
	continue = false
	local tmp = {}
	for name,lv in pairs(sideTechLv) do
		if lv == false then
			sideTechLv[name] = parent
			canBuild = UnitDefNames[name].buildOptions
			if canBuild and #canBuild > 0 then
				for index,id in pairs(UnitDefNames[name].buildOptions) do
					if not sideTechLv[UnitDefs[id].name] then
						tmp[UnitDefs[id].name] = false
						continue = true
					end
				end
			end
		end
	end
	for name,lv in pairs(tmp) do
		sideTechLv[name] = lv
	end
	if continue  then
		parent = parent + 1
		getTechTree(sideTechLv)
	end
	parent = 0
end

local function GetUnitTable()
	local builtBy = GetBuiltBy()
	local unitTable = {}
	local wrecks = {}
	for unitDefID,unitDef in pairs(UnitDefs) do
		local side = GetUnitSide(unitDef.name)
		if unitsLevels[unitDef.name] then

			-- Spring.Echo(unitDef.name, "build slope", unitDef.maxHeightDif)
			-- if unitDef.moveDef.maxSlope then
				-- Spring.Echo(unitDef.name, "move slope", unitDef.moveDef.maxSlope)
				-- end
			local utable = {}
			utable.side = side
			utable.techLevel = unitsLevels[unitDef["name"]]
			if unitDef["modCategories"]["weapon"] then
				utable.isWeapon = true
				if unitDef["weapons"][1] then
					utable.firstWeapon = WeaponDefs[unitDef["weapons"][1]["weaponDef"]]
				end
			else
				utable.isWeapon = false
			end
			if unitDef["isBuilding"] then
				utable.isBuilding = true
			else
				utable.isBuilding = false
			end
			utable.groundRange = GetLongestWeaponRange(unitDefID, 0)
			utable.airRange = GetLongestWeaponRange(unitDefID, 1)
			utable.submergedRange = GetLongestWeaponRange(unitDefID, 2)
			if unitDef.speed == 0 and utable.isWeapon then
				utable.isTurret = true
				if unitDef.modCategories.mine then
					utable.isMine = utable.techLevel
				elseif utable.firstWeapon and utable.firstWeapon['type'] == ('StarburstLauncher' or 'MissileLauncher') then
					utable.isTacticalTurret =  utable.techLevel
				elseif utable.firstWeapon and utable.firstWeapon['type'] == 'Cannon' then
					utable.isCannonTurret = utable.techLevel
					if not utable.firstWeapon.selfExplode then
						utable.isPlasmaCannon = utable.techLevel
					end
				elseif utable.firstWeapon and utable.firstWeapon['type'] == 'BeamLaser' then
					utable.isLaserTurret = utable.techLevel
				elseif utable.firstWeapon and utable.firstWeapon['type'] == 'TorpedoLauncher' then
					utable.isTorpedoTurret = utable.techLevel
				end
				if utable.groundRange and utable.groundRange > 0 then
					utable.isGroundTurret = utable.groundRange
				end
				if utable.airRange and utable.airRange > 0 then
					utable.isAirTurret = utable.airRange
				end
				if utable.submergedRange and utable.submergedRange > 0 then
					utable.isSubTurret = utable.submergedRange
				end
			end
			if fighter[unitDef["name"]] then
				utable.airRange = utable.groundRange
			end
			utable.radarRadius = unitDef["radarRadius"]
			utable.airLosRadius = unitDef["airLosRadius"]
			utable.losRadius = unitDef["losRadius"]
			utable.sonarRadius = unitDef["sonarRadius"]
			utable.jammerRadius = unitDef["jammerRadius"]
			utable.stealth = unitDef["stealth"]
			utable.metalCost = unitDef["metalCost"]
			utable.energyCost = unitDef["energyCost"]
			utable.buildTime = unitDef["buildTime"]
			utable.totalEnergyOut = unitDef["totalEnergyOut"]
			utable.extractsMetal = unitDef["extractsMetal"]
			utable.mclass = unitDef.moveDef.name
			utable.speed = unitDef.speed
			if unitDef["minWaterDepth"] > 0 then
				utable.needsWater = true
			else
				utable.needsWater = false
			end
			if unitDef["canFly"] then
				utable.mtype = "air"
			elseif	utable.isBuilding and utable.needsWater then
				utable.mtype = 'sub'
			elseif	utable.isBuilding and not utable.needsWater then
				utable.mtype = 'veh'
			elseif  unitDef.moveDef.name and (string.find(unitDef.moveDef.name, 'abot') or string.find(unitDef.moveDef.name, 'vbot')  or string.find(unitDef.moveDef.name,'atank'))  then
				utable.mtype = 'amp'
			elseif unitDef.moveDef.name and string.find(unitDef.moveDef.name, 'uboat') then
				utable.mtype = 'sub'
			elseif unitDef.moveDef.name and  string.find(unitDef.moveDef.name, 'hover') then
				utable.mtype = 'hov'
			elseif unitDef.moveDef.name and string.find(unitDef.moveDef.name, 'boat') then
				utable.mtype = 'shp'
			elseif unitDef.moveDef.name and string.find(unitDef.moveDef.name, 'tank') then
				utable.mtype = 'veh'
			elseif unitDef.moveDef.name and string.find(unitDef.moveDef.name, 'bot') then
				utable.mtype = 'bot'
			else
				if unitDef.maxwaterdepth and unitDef.maxwaterdepth < 0 then
					utable.mtype = 'shp'
				else
					utable.mtype = 'veh'
				end
			end
			if unitDef["isBuilder"] and #unitDef["buildOptions"] < 1 and not unitDef.moveDef.name then
				utable.isNano = true
			end
			if unitDef["isBuilder"] and #unitDef["buildOptions"] > 0 then
				utable.buildOptions = true
				if unitDef["isBuilding"] then
					utable['isFactory'] = {}
					utable.unitsCanBuild = {}
					for i, oid in pairs (unitDef["buildOptions"]) do
						local buildDef = UnitDefs[oid]
						-- if is a factory insert all the units that can build
						table.insert(utable.unitsCanBuild, buildDef["name"])
						--and save all the mtype that can andle
						--utable.isFactory[unitName[buildDef.name].mtype] = TODO
					end
				else
					utable.factoriesCanBuild = {}
					for i, oid in pairs (unitDef["buildOptions"]) do
						local buildDef = UnitDefs[oid]
						if #buildDef["buildOptions"] > 0 and buildDef["isBuilding"] then
							-- build option is a factory, add it to factories this unit can build
							table.insert(utable.factoriesCanBuild, buildDef["name"])
						end
					end
				end
			end
			utable.bigExplosion = unitDef["deathExplosion"] == "atomic_blast"
			utable.xsize = unitDef["xsize"]
			utable.zsize = unitDef["zsize"]
			utable.wreckName = unitDef["wreckName"]
			wrecks[unitDef["wreckName"]] = unitDef["name"]
			unitTable[unitDef.name] = utable
		end
	end
	return unitTable, wrecks
end

local function GetFeatureTable(wrecks)
	local featureTable = {}
	-- feature defs
	for featureDefID, featureDef in pairs(FeatureDefs) do
		local ftable = {}
		for i, k in pairs(featureKeysToGet) do
			local v = featureDef[k]
			ftable[k] = v
		end
		if wrecks[featureDef["name"]] then
			ftable.unitName = wrecks[featureDef["name"]]
		end
		featureTable[featureDef.name] = ftable
	end
	return featureTable
end

getTechTree(armTechLv)
getTechTree(corTechLv)
for k,v in pairs(corTechLv) do unitsLevels[k] = v end
for k,v in pairs(armTechLv) do unitsLevels[k] = v end
local unitTable, wrecks = GetUnitTable()

local featureTable = GetFeatureTable(wrecks)

wrecks = nil

return unitTable, featureTable

