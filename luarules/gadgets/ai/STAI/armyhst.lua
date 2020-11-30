ArmyHST = class(Module)

function ArmyHST:Name()
	return "ArmyHST"
end

function ArmyHST:internalName()
	return "armyhst"
end


function ArmyHST:Init()
	self.DebugEnabled = true
end

ArmyHST.techPenalty = {
	armamsub = -1,
	coramsub = -1,
	armfhp = -1,
	corfhp = -1,
	armhp = -1,
	corhp = -1,
}

ArmyHST.factoryMobilities = {
	corap = {"air"},
	armap = {"air"},
	corlab = {"bot"},
	armlab = {"bot"},
	corvp = {"veh", "amp"},
	armvp = {"veh", "amp"},
	coralab = {"bot"},
	coravp = {"veh", "amp"},
	corhp = {"hov"},
	armhp = {"hov"},
	corfhp = {"hov"},
	armfhp = {"hov"},
	armalab = {"bot"},
	armavp = {"veh", "amp"},
	coraap = {"air"},
	armaap = {"air"},
	corplat = {"air"},
	armplat = {"air"},
	corsy = {"shp", "sub"},
	armsy = {"shp", "sub"},
	corasy = {"shp", "sub"},
	armasy = {"shp", "sub"},
	coramsub = {"amp","sub"},
	armamsub = {"amp","sub"},
	corgant = {"bot", "amp"},
	armshltx = {"bot", "amp"},
	corgantuw = {"amp"},
	armshltxuw = {"amp"},
}

-- for calculating what factories to build
-- higher values mean more effecient
ArmyHST.mobilityEffeciencyMultiplier = {
	veh = 1,
	shp = 1,
	bot = 0.9,
	sub = 0.9,
	hov = 0.7,
	amp = 0.4,
	air = 0.55,
}

ArmyHST.factoryExitSides = {
	corap = 0,
	armap = 0,
	corlab = 2,
	armlab = 2,
	corvp = 1,
	armvp = 1,
	coralab = 3,
	coravp = 1,
	corhp = 2,
	armhp = 2,
	corfhp = 2,
	armfhp = 2,
	armalab = 2,
	armavp = 2,
	coraap = 0,
	armaap = 0,
	corplat = 0,
	armplat = 0,
	corsy = 4,
	armsy = 4,
	corasy = 4,
	armasy = 4,
	coramsub = 4,
	armamsub = 4,
	corgant = 1,
	armshltx = 1,
	corgantuw = 1,
	armshltxuw = 1,
}

ArmyHST.littlePlasmaList = {
	corpun = 1,
	armguard = 1,
	cortoast = 1,
	armamb = 1,
	corbhmth = 1,
}

-- these big energy plants will be shielded in addition to factories
ArmyHST.bigEnergyList = {
	corageo = 1,
	armageo = 1,
	corfus = 1,
	armfus = 1,
	corafus = 1,
	armafus = 1,
}

-- geothermal plants
ArmyHST.geothermalPlant = {
	corgeo = 1,
	armgeo = 1,
	corageo = 1,
	armageo = 1,
	corbhmth = 1,
	armgmm = 1,
}

-- what mexes upgrade to what
ArmyHST.mexUpgrade = {
	cormex = "cormoho",
	armmex = "armmoho",
	coruwmex = "coruwmme",--ex coruwmex caution this will be changed --TODO
	armuwmex = "armuwmme",--ex armuwmex
	armamex = "armmoho",
	corexp = "cormexp",

}

-- these will be abandoned faster
ArmyHST.hyperWatchdog = {
	armmex = 1,
	cormex = 1,
	armgeo = 1,
	corgeo = 1,
}

-- things we really need to construct other than factories
-- value is max number of assistants to get if available (0 is all available)
ArmyHST.helpList = {
	corfus = 0,
	armfus = 0,
	coruwfus = 0,
	armuwfus = 0,
	armafus = 0,
	corafus = 0,
	corgeo = 2,
	armgeo = 2,
	corageo = 0,
	armageo = 0,
	cormoho = 2,
	armmoho = 2,
	coruwmme = 2,
	armuwmme = 2,
}

-- priorities of things to defend that can't be accounted for by the formula in turtlehst
ArmyHST.turtleList = {
	cormakr = 0.5,
	armmakr = 0.5,
	corfmkr = 0.5,
	armfmkr = 0.5,
	cormmkr = 4,
	armmmkr = 4,
	corfmmm = 4,
	armfmmm = 4,
	corestor = 0.5,
	armestor = 0.5,
	cormstor = 0.5,
	armmstor = 0.5,
	coruwes = 0.5,
	armuwes = 0.5,
	coruwms = 0.5,
	armuwms = 0.5,
	coruwadves = 2,
	armuwadves = 2,
	coruwadvms = 2,
	armuwadvms = 2,
}

-- factories that can build advanced construction units (i.e. moho mines)
ArmyHST.advFactories = {
	coravp = 1,
	coralab = 1,
	corasy = 1,
	coraap = 1,
	corplat = 1,
	armavp = 1,
	armalab = 1,
	armasy = 1,
	armaap = 1,
	armplat = 1,
}

-- experimental factories
ArmyHST.expFactories = {
	corgant = 1,
	armshltx = 1,
	corgantuw = 1,
	armshltxuw = 1,
}

-- leads to experimental
ArmyHST.leadsToExpFactories = {
	corlab = 1,
	armlab = 1,
	coralab = 1,
	armalab = 1,
	corsy = 1,
	armsy = 1,
	corasy = 1,
	armasy = 1,
}

-- sturdy, cheap units to be built in larger numbers than siege units
ArmyHST.battleList = {
	corraid = 1,
	armstump = 1,
	corthud = 1,
	armham = 1,
	corstorm = 1,
	armrock = 1,
	coresupp = 1,
	armdecade = 1,
	corroy = 1,
	armroy = 1,
	corsnap = 1,
	armanac = 1,
	corseal = 1,
	armcroc = 1,
	correap = 2,
	armbull = 2,
	corcan = 2,
	armzeus = 2,
	corcrus = 2,
	armcrus = 2,
	armmav = 2,
-- 	cordecom = 2,
-- 	armdecom = 2,
	corkarg = 3,
	armraz = 3,

}

-- sturdier units to use when battle units get killed
ArmyHST.breakthroughList = {
	corlevlr = 1,
	armwar = 1,
	corgol = 2,
	corsumo = 2,
	armfboy = 2,
	corparrow = 2,
	corhal = 2,
	corbats = 2,
	armbats = 2,
	corkorg = 3,
	corjugg = 3,
	armbanth = 3,
	corblackhy = 3,
	armepoch = 3,
	corcrw = 3,
	armliche = 3,
}

-- for milling about next to con units and factories only
ArmyHST.defenderList = {
	armaak = 1 ,
	corcrash = 1 ,
	armjeth = 1 ,
	corsent = 1 ,
	armyork = 1 ,
	corah = 1 ,
	armaas = 1 ,
	armah = 1 ,
	corarch = 1 ,
	armaser = 1 ,
	armjam = 1 ,
	armsjam = 1 ,
	coreter = 1 ,
	corsjam = 1 ,
	corspec = 1 ,
	armfig = 1 ,
	armhawk = 1 ,
	armsfig = 1 ,
	corveng = 1 ,
	corvamp = 1 ,
	corsfig = 1 ,
}

ArmyHST.attackerlist = {
	armsam = 1 ,
	corwolv = 1 ,
	armart = 1 ,
	armjanus = 1 ,
	corlvlr = 1 ,
	corthud = 1 ,
	armham = 1 ,
	corraid = 1 ,
	armstump = 1 ,
	correap = 1 ,
	armbull = 1 ,
	corstorm = 1 ,
	armrock = 1 ,
	cormart = 1 ,
	armmart = 1 ,
	cormort = 1 ,
	armwar = 1 ,
	armsnipe = 1 ,
	armzeus = 1 ,
	corlevlr = 1 ,
	corsumo = 1 ,
	corcan = 1 ,
	corhrk = 1 ,
	corgol = 1 ,
	corvroc = 1 ,
	cormh = 1 ,
	armmanni = 1 ,
	armmerl = 1 ,
	armfido = 1 ,
	armsptk = 1 ,
	armmh = 1 ,
	corwolv = 1 ,
	cormist = 1 ,
	armfboy = 1 ,
	corcrw = 1 ,
	-- experimentals
	armraz = 1 ,
	armvang = 1 ,
	armbanth = 1 ,
	armshiva = 1 ,
	corcat = 1 ,
	corkarg = 1 ,
	corjugg = 1 ,
	corkorg = 1 ,
	-- ships
	coresupp = 1 ,
	armdecade = 1 ,
	corroy = 1 ,
	armroy = 1 ,
	corcrus = 1 ,
	armcrus = 1 ,
	corblackhy = 1 ,
	armepoch = 1 ,
	armserp = 1 ,
	corssub = 1 ,
	-- hover
	corsnap = 1 ,
	armanac = 1 ,
	corhal = 1 ,
	-- amphib
	corseal = 1 ,
	armcroc = 1 ,
	corparrow = 1 ,
}

-- these units will be used to raid weakly defended spots
ArmyHST.raiderList = {
	armfast = 1,
	corgator = 1,
	armflash = 1,
	corpyro = 1,
	armlatnk = 1,
	armpw = 1,
	corak = 1,
	armmar = 1,
	-- amphibious
	corgarp = 1,
	armpincer = 1,
	-- hover
	corsh = 1,
	armsh = 1,
	-- air gunships
	armbrawl = 1,
	armkam = 1,
	armsaber = 1,
	armblade = 1,
	corbw = 1,
	corape = 1,
	corcut = 1,
	corcrw = 1,
	-- subs
	corsub = 1,
	armsub = 1,
	armsubk = 1,
	corshark = 1,
}

ArmyHST.scoutList = {
	corfink = 1,
	armpeep = 1,
	corfav = 1,
	armfav = 1,
	armflea = 1,
	corawac = 1,
	armawac = 1,
	corpt = 1,
	armpt = 1,
	corhunt = 1,
	armsehak = 1,
}

ArmyHST.raiderDisarms = {
	corbw = 1,
}

-- units in this list are bombers or torpedo bombers
ArmyHST.bomberList = {
	corshad = 1,
	armthund = 1,
	corhurc = 2,
	armpnix = 2,
	armliche = 3,
	corsb = 2,
	armsb = 2,
	cortitan = 2,
	armlance = 2,
	corseap = 2,
	armseap = 2,
}

ArmyHST.antinukeList = {
	corfmd = 1,
	armamd = 1,
	corcarry = 1,
	armcarry = 1,
	cormabm = 1,
	armscab = 1,
}

ArmyHST.shieldList = {
	corgate = 1,
	armgate = 1,
}

ArmyHST.commanderList = {
	armcom = 1,
	corcom = 1,
}

ArmyHST.nanoTurretList = {
	cornanotc = 1,
	armnanotc = 1,
	armnanotcplat = 1,
	cornanotcplat = 1,
}

-- cheap construction units that can be built in large numbers
ArmyHST.assistList = {
	armfark = 1,
	corfast = 1,
	armconsul = 1,
}

ArmyHST.reclaimerList = {
	cornecro = 1,
	armrectr = 1,
	correcl = 1,
	armrecl = 1,
}

-- advanced construction units
ArmyHST.advConList = {
	corack = 1,
	armack = 1,
	coracv = 1,
	armacv = 1,
	coraca = 1,
	armaca = 1,
	coracsub = 1,
	armacsub = 1,
}

ArmyHST.groundFacList = {
	corvp = 1,
	armvp = 1,
	coravp = 1,
	armavp = 1,
	corlab = 1,
	armlab = 1,
	coralab = 1,
	armalab = 1,
	corhp = 1,
	armhp = 1,
	corfhp = 1,
	armfhp = 1,
	coramsub = 1,
	armamsub = 1,
	corgant = 1,
	armshltx = 1,
	corfast = 1,
	armconsul = 1,
	armfark = 1,
}

-- if any of these is found among enemy units, AA units and fighters will be built
ArmyHST.airFacList = {
	corap = 1,
	armap = 1,
	coraap = 1,
	armaap = 1,
	corplat = 1,
	armplat = 1,
}

-- if any of these is found among enemy units, torpedo launchers and sonar will be built
ArmyHST.subFacList = {
	corsy = 1,
	armsy = 1,
	corasy = 1,
	armasy = 1,
	coramsub = 1,
	armamsub = 1,
}

-- if any of these is found among enemy units, plasma shields will be built
ArmyHST.bigPlasmaList = {
	corint = 1,
	armbrtha = 1,
}

-- if any of these is found among enemy units, antinukes will be built
-- also used to assign nuke behaviour to own units
-- values are how many frames it takes to stockpile
ArmyHST.nukeList = {
	armsilo = 3600,
	corsilo = 5400,
	armemp = 2700,
	cortron = 2250,
}

ArmyHST.seaplaneConList = {
	corcsa = 1,
	armcsa = 1,
}


ArmyHST.Eco1={
	armsolar=1,
	armwin=1,
	armadvsol=1,
	armtide=1,

	corsolar=1,
	corwin=1,
	coradvsol=1,
	cortide=1,

	corgeo=1,
	armgeo=1,

	--store

	armestor=1,
	armmstor=1,
	armuwes=1,
	armuwms=1,

	corestor=1,
	cormstor=1,
	coruwes=1,
	coruwms=1,

	--conv
	armmakr=1,
	cormakr=1,
	armfmkr=1,
	corfmkr=1,


	--metalli
	corexp=1,
	armamex=1,

	cormex=1,
	armmex=1,

	armuwmex=1,
	coruwmex=1,

	armnanotc=1,
	cornanotc=1,
	armnanotcplat = 1,
	cornanotcplat = 1,
}

ArmyHST.Eco2={
	--metalli
	armmoho=4,
	cormoho=4,
	cormexp=4,

	coruwmme=0,
	armuwmme=0,

	--magazzini
	armuwadves=3,
	armuwadvms=3,

	coruwadves=3,
	coruwadvms=3,

	corageo = 4,
	armageo = 4,
	corbhmth = 4,
	armgmm = 4,

	corfus = 1,
	armfus = 1,
	corafus = 1,
	armafus = 1,
	armuwfus = 0,
	coruwfus = 0,

	--convertitori
	cormmkr=1,
	armmmkr=1,
	corfmmm=0,
	armfmmm=0,
}

ArmyHST.cleaners = {
	armbeaver = 1,
	cormuskrat = 1,
	armcom = 1,
	corcom = 1,
	armdecom = 1,
	cordecom = 1,
}
ArmyHST.decoy ={
	armdecom = 2,
	cordecom = 2,
}
ArmyHST.cleanable = {
	armsolar= 'ground',
	corsolar= 'ground',
	armadvsol = 'ground',
	coradvsol = 'ground',
	armtide = 'floating',
	cortite = 'floating',
	armfmkr = 'floating',
	corfmkr = 'floating',
	cormakr = 'ground',
	armmakr = 'ground',
	corwin = 'ground',
	armwin = 'ground',
}

-- minimum, maximum, starting point units required to attack, bomb
ArmyHST.minAttackCounter = 8
ArmyHST.maxAttackCounter = 30
ArmyHST.baseAttackCounter = 15
ArmyHST.breakthroughAttackCounter = 16 -- build heavier battle units
ArmyHST.siegeAttackCounter = 20 -- build siege units
ArmyHST.minBattleCount = 4 -- how many battle units to build before building any breakthroughs, even if counter is too high
ArmyHST.minBomberCounter = 0
ArmyHST.maxBomberCounter = 16
ArmyHST.baseBomberCounter = 2
ArmyHST.breakthroughBomberCounter = 8 -- build atomic bombers or air fortresses

-- raid counter works backwards: it determines the number of raiders to build
-- if it reaches ArmyHST.minRaidCounter, none are built
ArmyHST.minRaidCounter = 0
ArmyHST.maxRaidCounter = 8
ArmyHST.baseRaidCounter = 5

-- Taskqueuebehaviour was modified to skip this name
ArmyHST.DummyUnitName = "skipthisorder"

-- Taskqueuebehaviour was modified to use this as a generic "build me a factory" order
ArmyHST.FactoryUnitName = "buildfactory"

-- this unit is used to check for underwater metal spots
ArmyHST.UWMetalSpotCheckUnit = "coruwmex"

-- for non-lua only; tests build orders of these units to determine mobility there
-- multiple units for one mtype function as OR
ArmyHST.mobUnitNames = {
	veh = {"corcv", "armllt"},
	bot = {"corck", "armeyes"},
	amp = {"cormuskrat"},
	hov = {"corsh", "armfdrag"},
	shp = {"corcs"},
	sub = {"coracsub"},
}

-- tests move orders of these units to determine mobility there
ArmyHST.mobUnitExampleName = {
	veh = "armcv",
	bot = "armck",
	amp = "armbeaver",
	hov = "armch",
	shp = "armcs",
	sub = "armacsub"
}

-- side names
ArmyHST.CORESideName = "cortex"
ArmyHST.ARMSideName = "armada"

-- how much metal to assume features with these strings in their names have
ArmyHST.baseFeatureMetal = { rock = 30, heap = 80, wreck = 150 }

-- BEGIN CODE BLOCK TO COPY AND PASTE INTO shard_help_unit_feature_table.lua

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

-- local function scanLabs(units,utable)
-- 	local _metal , _energy, _los
-- 	for i, oid in pairs(units) do
-- 		print(i)
-- 		print(oid)
-- 		local buildDef = UnitDefs[oid]
-- 		local name = buildDef["name"]
-- 		local uTn = ArmyHST.unitTable[buildDef["name"]]
--
--
-- 		_metal = _metal + utn.metalCost
-- 		_energy = _energy + utn.energyCost
-- 		_los = _los + utn.losRadius
-- 		_speed = _speed + utn.speed
--
-- 	end
-- 	_metal_= _metal/#units
-- 	_energy_= _energy/#units
-- 	_los_= _los/#units
-- 	_speed_= _speed/#units
-- 	for i, oid in pairs(units) do
-- 		print(i)
-- 		print(oid)
-- 		local buildDef = UnitDefs[oid]
-- 		local name = buildDef["name"]
-- 		local uTn = ArmyHST.unitTable[buildDef["name"]]
-- 		if utn.metalCost < _metal_ and utn.energyCost < _energy_ then
-- 			utn.cheap = true
-- 		else
-- 			utn.cheap = true
-- 		end
--
-- 		if utn.losradius < _los_ then
-- 			utn.shortRange = true
-- 		else
-- 			utn.shortRange = true
-- 		end
--
-- 		if utn.speed < _speed_ then
-- 			utn.slow = true
-- 		else
-- 			utn.slow = false
-- 		end
--
--
-- 	end
--
-- end



local function GetUnitSide(name)--TODO change to the internal name armada cortex
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
			if ArmyHST.techPenalty[name] then sideTechLv[name] = sideTechLv[name] + ArmyHST.techPenalty[name] end--here cause some not corresponding at true and seaplane maybe
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
-- 			Spring:Echo(unitDef.name)
			utable.techLevel = unitsLevels[unitDef["name"]]
			if unitDef["modCategories"]["weapon"] then
				utable.isWeapon = true
				if unitDef["weapons"][1] then
					local defWepon1 = unitDef["weapons"][1]

					utable.firstWeapon = WeaponDefs[unitDef["weapons"][1]["weaponDef"]]
					utable.badTg = ''
					if defWepon1.badTargets then
						for ii,vv in pairs(defWepon1.badTargets) do
							--Spring:Echo(ii)
							utable.badTg = utable.badTg .. ii

						end
					end
					utable.onlyTg = ''
					if defWepon1.onlyTargets then
						for ii,vv in pairs(defWepon1.onlyTargets) do
							utable.onlyTg = utable.onlyTg .. ii
						end
					end
					utable.onlyBadTg = utable.onlyTg .. utable.badTg
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
ArmyHST.unitTable, ArmyHST.wrecks = GetUnitTable()
ArmyHST.featureTable = GetFeatureTable(ArmyHST.wrecks)
wrecks = nil







