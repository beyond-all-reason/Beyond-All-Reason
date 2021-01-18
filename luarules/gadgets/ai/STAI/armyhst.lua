ArmyHST = class(Module)

function ArmyHST:Name()
	return "ArmyHST"
end

function ArmyHST:internalName()
	return "armyhst"
end


function ArmyHST:Init()
	self.DebugEnabled = false
	self.unitTable = {}
	self.wrecks = {}
	self.featureTable = {}

	self.attackers = {}  --al the mobile units that can do damage and can be used to attack

	self.scouts = {}
	self.raiders = {} -- these units will be used to raid weakly defended spots
	self.techs = {}  --official builders
	self.amptechs = {} --amphibious builders
	self.jammers = {}
	self.radars = {}
	self.spys = {} -- spy bot
	self.engineers = {} --help builders and build thinghs
	self.wartechs = {} --decoy etc
	self.rezs = {} -- rezzers
	self.transports = {}
	self.artillerys = {}
	self.longranges = {}
	self.battles = {} -- sturdy, cheap units to be built in larger numbers than siege units
	self.breaks = {} -- sturdier units to use when battle units get killed
	self.miners = {}
	self.spiders = {} -- all terrain spider
	self.paralyzers = {} --have paralyzer weapon
	self.subkillers = {} -- submarine weaponed
	self.bomberairs = {}
	self.fighterairs = {}
	self.antiairs = {}
	self.antiairs2 = {} --in the case a lab have 2 antiair
	self.antinukes = {}
	self.amphibious = {} -- weapon amphibious
	self.crawlings = {}
	self.cloakables = {}

	self._targeting_ = {
		armtarg = true ,
		armfatf = true ,
		cortarg = true ,
		corfatf = true ,
	}

	self._geo_ = {
		corageo = true ,
		armageo = true ,
		armgeo = true ,
		corgeo = true ,
		corbhmth = true ,
		armgmm = true ,
	}


	self._nano_ = {
		armnanotc = true ,
		armnanotcplat = true ,
		cornanotc = true ,
		cornanotcplat = true ,
		cormoho = true ,
	}

	self._solar_ = {
		corsolar = true ,
		armsolar = true ,
	}

	self._advsol_ = {
		coradvsol = true ,
		armadvsol = true ,
	}

	self._mex_ = {
		cormex = true ,
		armuwmex = true ,
		coruwmex = true ,
		cormexp = true ,
		armmex = true ,
		armamex = true ,
		armmoho = true ,
		corexp = true ,
		armuwmme = true ,
		coruwmme = true ,
	}

	self._flak_ = {
		armfflak = true ,
		armflak = true ,
		corflak = true ,
		corenaa = true ,
	}

	self._mine_ = {
		armmine1 = true ,
		armmine2 = true ,
		armmine3 = true ,
		armfmine3 = true ,
		cormine1 = true ,
		cormine2 = true ,
		cormine3 = true ,
		cormine4 = true ,
		corfmine3 = true ,
	}

	self._eyes_ = {
		armeyes = true ,
		coreyes = true ,
	}

	self._fus_ = {
		armfus = true ,
		armafus = true ,
		armuwfus = true ,
		armckfus = true ,
		corfus = true ,
		corafus = true ,
		coruwfus = true ,
	}

	self._silo_ = {
		armsilo = true ,
		corsilo = true ,
	}

	self._wind_ ={
		armwin = true ,
		corwin = true ,
	}

	self._tide_ = {
		cortide = true ,
		armtide = true ,
	}

	self._plat_ = {
		corplat = true ,
		armplat = true ,
	}

	self._radar_ = {
		armrad = true ,
		armarad = true ,
		corrad = true ,
		corarad = true ,
		corfrad = true ,
		armfrad = true ,
	}

	self._jam_ = {
		armjamt = true ,
		corjamt = true ,
		armveil = true ,
		corshroud = true ,
	}

	self._sonar_ = {
		armsonar = true ,
		corsonar = true ,
		armason = true,
		corason = true,
	}

	self._shield_ = {
		armgate = true ,
		corgate = true ,
	}

	self._juno_ = {
		corjuno = true ,
		armjuno = true ,
	}

	self._popup1_ = {
		armclaw = true,
		cormaw = true,
	}

	self._llt_ = {
		armllt = true,
		corllt = true,
	}

	self._specialt_ = {
		armbeamer = true,
		corhllt = true,
	}

	self._heavyt_ = {
		armhlt = true,
		corhlt = true,
		armfhlt = true,
		corfhlt = true,
	}

	self._lol_ = {
		corbuzz = true ,
		armvulc = true ,
	}

	self._laser2_ = {
		cordoom = true ,
		armanni = true ,
	}

	self._coast1_ = {
		corpun = true ,
		armguard = true ,
	}

	self._coast2_ = {
		cortoast = true ,
		armamb = true ,
	}

	self._popup2_ = {
		armpb = true ,
		corvipe = true ,
	}

	self._plasma_ = {
		armbrtha = true ,
		corint = true ,
	}

	self._torpedo1_ = {
		cortl = true ,
		armtl = true ,
		armptl = true ,
		corptl = true ,
	}

	self._torpedo2_ = {
		coratl = true ,
		armatl = true ,
	}

	self._torpedoground_ = {
		armdl = true ,
		cordl = true ,
	}

	self._aa1_ = {
		armrl = true ,
		corrl = true ,
		armfrt = true ,
		corfrt = true ,
	}

	self._aabomb_ = {
		corerad = true ,
		armferret = true ,
	}

	self._aaheavy_ = {
		cormadsam = true ,
		armcir = true ,
	}
	self._aa2_ = {
		corscreamer = true ,
		armmercury = true ,
	}

	self._intrusion_ = {
		corsd = true ,
		armsd = true ,
	}

	self._antinuke_ = {
		armamd = true ,
		corfmd = true ,
	}

	self._airPlat_ = {
		armasp = true ,
		corasp = true ,
	}

	self._convs_ = {
		armmmkr = true ,
		armfmkr = true ,
		armmakr = true ,
		armuwmmm = true ,
		cormmkr = true ,
		corfmkr = true ,
		cormakr = true ,
	}

	self._estor_ = {
		armestor = true ,
		armuwes = true ,
		armuwadves = true ,
		corestor = true ,
		coruwes = true ,
		coruwadves = true ,
	}

	self._mstor_ = {
		cormstor = true ,
		armmstor = true ,
		armuwms = true ,
		coruwms = true ,
		coruwadvms = true ,
		armuwadvms = true ,
		coruwmmm = true ,
	}

	self._tactical_ = {
		armemp = true ,
		cortron = true ,
	}

	self._wall_ = {
		corfdrag = true ,
		armdrag = true ,
		armfort = true ,
		cordrag = true ,
		armfdrag = true ,
	}

	self:GetUnitTable()
	self:GetFeatureTable()
	self:setRanks()

	self.buildersRole = {
		default = {},
		eco = {},
		expand = {},
		support = {},

	}



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

ArmyHST.raiderDisarms = {
	corbw = 1,
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

-- ArmyHST.seaplaneConList = {
-- 	corcsa = 1,
-- 	armcsa = 1,
-- }


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


local unitsLevels = {}
local armTechLv ={}
local corTechLv ={}
corTechLv.corcom = false
armTechLv.armcom = false
local parent = 0
local continue = false

local featureKeysToGet = { "metal" , "energy", "reclaimable", "blocking", }

local function getDPS(unitDefID)
	local unitDef = UnitDefs[unitDefID]
	local weapons = unitDef["weapons"]
	local dps = 0
	for i=1, #weapons do
		local weaponDefID = weapons[i]["weaponDef"]
		local weaponDef = WeaponDefs[weaponDefID]
		dps = dps + weaponDef['damages'][0] / weaponDef['reload']
	end
	----Spring.Echo('dps',dps)
	return dps
end



local function getInterceptor(unitDefID)
	local unitDef = UnitDefs[unitDefID]
	local weapons = unitDef["weapons"]
	local interceptor = false
	for i=1, #weapons do
		local weaponDefID = weapons[i]["weaponDef"]
		local weaponDef = WeaponDefs[weaponDefID]
		if weaponDef['interceptor'] then
			interceptor  =  weaponDef['interceptor'] == 1
		end
	end
	----Spring.Echo('interceptor',interceptor)
	return interceptor
end

local function getTargetableWeapon(unitDefID)
	local unitDef = UnitDefs[unitDefID]
	local weapons = unitDef["weapons"]
	local targetable = false
	for i=1, #weapons do
		local weaponDefID = weapons[i]["weaponDef"]
		local weaponDef = WeaponDefs[weaponDefID]
		if weaponDef['targetable'] then
			targetable  =  weaponDef['targetable'] == 1
		end
	end
	----Spring.Echo('targetable',targetable)
	return targetable
end

local function getParalyzer(unitDefID)
	local unitDef = UnitDefs[unitDefID]
	local weapons = unitDef["weapons"]
	for i=1, #weapons do
		local weaponDefID = weapons[i]["weaponDef"]
		local weaponDef = WeaponDefs[weaponDefID]
		paralyzer  =  weaponDef['paralyzer']
	end
	----Spring.Echo('paralyzer',paralyzer)
	return paralyzer
end

local function getOnlyTargets(weapons)
	local targets = {}
	for index,weapon in pairs (weapons) do
		if weapon.onlyTargets then
			for name,_ in pairs(weapon.onlyTargets) do
				local  weaponDefID = weapon["weaponDef"]
				local weaponDef = WeaponDefs[weaponDefID]
				targets[name] = weaponDef.range
			end
		end
	end
	return targets
end

local function getBadTargets(weapons)
	local targets = {}
	for index,weapon in pairs (weapons) do
		if weapon.badTargets then
			for name,_ in pairs(weapon.badTargets) do
				local  weaponDefID = weapon["weaponDef"]
				local weaponDef = WeaponDefs[weaponDefID]
				targets[name] = weaponDef.range
				----Spring.Echo('defbadtargets', targets[name])
			end
		end
	end
	----Spring.Echo('badtargets',targets)
	return targets
end
local function GetLongestWeaponRange(unitDefID, GroundAirSubmerged)
	local weaponRange = 0
	local unitDef = UnitDefs[unitDefID]
	local weapons = unitDef["weapons"]
	local dps = 0
	for i=1, #weapons do
		local weaponDefID = weapons[i]["weaponDef"]
		local weaponDef = WeaponDefs[weaponDefID]
		-- --Spring.Echo(weaponDefID)
		-- --Spring.Echo(weaponDef["canAttackGround"])
		-- --Spring.Echo(weaponDef["waterWeapon"])
		----Spring.Echo(weaponDef["range"])
		----Spring.Echo(weaponDef["type"])
		local wType = 0
		if weaponDef["canAttackGround"] == false then
			wType = 1
		elseif weaponDef["waterWeapon"] then
			wType = 2
		else
			wType = 0
		end
		-- --Spring.Echo(wType)
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

local function GetWeaponParams(weaponDefID)
	local WD = WeaponDefs[weaponDefID]
	local WDCP = WD.customParams
	local weaponDamageSingle = tonumber(WDCP.statsdamage) or WD.damages[0] or 0
	local weaponDamageMult = tonumber(WDCP.statsprojectiles) or ((tonumber(WDCP.script_burst) or WD.salvoSize) * WD.projectiles)
	local weaponDamage = weaponDamageSingle * weaponDamageMult
	local weaponRange = WD.range

	local reloadTime = tonumber(WD.customParams.script_reload) or WD.reload

	if WD.dyndamageexp and WD.dyndamageexp > 0 then
		local dynDamageExp = WD.dyndamageexp
		local dynDamageMin = WD.dyndamagemin or 0.0001
		local dynDamageRange = WD.dyndamagerange or weaponRange
		local dynDamageInverted = WD.dyndamageinverted or false
		local dynMod

		if dynDamageInverted then
			dynMod = math.pow(distance3D / dynDamageRange, dynDamageExp)
		else
			dynMod = 1 - math.pow(distance3D / dynDamageRange, dynDamageExp)
		end

		weaponDamage = math.max(weaponDamage * dynMod, dynDamageMin)
	end

	local dps = weaponDamage / reloadTime
	return dps, weaponDamage, reloadTime
end



function ArmyHST:getJammer(units,lab)
	local cost = 0
	local target = nil

	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if  not spec.buildOptions then
				if spec.jammerRadius and spec.jammerRadius > cost then
					cost = spec.jammerRadius
					target = name
				end
			end
		end
	end

	if target then
		self:EchoDebug(target,'is jammer of', lab)
		self.ranks[lab][target] = 'jammer'
		self.jammers[target] = true
	end

end

function ArmyHST:getEngineer(units,lab)
	local cost = 0
	local target = nil
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if  spec.isBuilder and spec.canAssist and not spec.isWeapon  then
				if spec.buildSpeed > cost then
					target = name
					cost = spec.buildSpeed
				end

			end
		end
	end
	if target then
		self:EchoDebug(target,'is Engineer of', lab)
		self.ranks[lab][target] = 'engineer'
		self.engineers[target] = true
	end
end
function ArmyHST:getWartech(units,lab)
	local cost = 0
	local target = nil
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if  spec.buildOptions and spec.isWeapon  then
				self.ranks[lab][name] = 'wartech'
				self:EchoDebug(name,'is fightingBuilders of', lab)
				self.wartechs[name] = true
			end
		end
	end
end



function ArmyHST:getCloakabe(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.canCloak and spec.isWeapon and not spec.isBuilder then
				self:EchoDebug(name,'is cloakable of', lab)
				self.ranks[lab][name] = 'cloakable'
				self.cloakables[name] = true
			end
		end
	end
end

function ArmyHST:getSpy(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.canCloak and not spec.isWeapon and spec.isBuilder then
				self:EchoDebug(name,'is spy of', lab)
				self.ranks[lab][name] = 'spy'
				self.spys[name] = true
			end
		end
	end
end

function ArmyHST:getSpiders(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isWeapon and spec.mclass == 'tbot3' then
				self:EchoDebug(name,'is spider of', lab)
				self.ranks[lab][name] = 'spider'
				self.spiders[name] = true
			end
		end
	end
end

function ArmyHST:getMiner(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isBuilder and spec.buildOptions and not spec.canAssist then
				self:EchoDebug(name,'is miner of', lab)
				self.ranks[lab][name] = 'miner'
				self.miners[name] = true
			end
		end
	end
end

function ArmyHST:getBomberAir(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isAirUnit and spec.isBomberAirUnit then
				self:EchoDebug(name,'is BomberAir of', lab)
				self.ranks[lab][name] = 'bomberair'
				self.bomberairs[name] = true
			end
		end
	end
end

function ArmyHST:getFighterAir(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isAirUnit and spec.isFighterAirUnit then
				self:EchoDebug(name,'is fighterair of', lab)
				self.ranks[lab][name] = 'fighterair'
				self.fighterairs[name] = true
			end
		end
	end
end

function ArmyHST:getRez(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.canResurrect  then
				self:EchoDebug(name,'is rez of', lab)
				self.ranks[lab][name] = 'rez'
				self.rezs[name] = true
			end
		end
	end
end

function ArmyHST:getAntiNuke(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.antiNuke then
				self:EchoDebug(name,'is antinuke of', lab)
				self.ranks[lab][name] = 'antinuke'
				self.antinukes[name] = true
			end
		end
	end
end

function ArmyHST:getFreezer(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isWeapon and spec.paralyzer and not spec.buildOptions then
				self:EchoDebug(name,'is paralyzer of', lab)
				self.ranks[lab][name] = 'paralyzer'
				self.paralyzers[name] = true
			end
		end
	end
end

function ArmyHST:getTransport(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isTransport then
				self:EchoDebug(name,'is transport of', lab)
				self.ranks[lab][name] = 'transport'
				self.transports[name] = true
			end
		end
	end
end


function ArmyHST:getTech(units,lab)
	local cost = 0
	local target = nil
	local ampBuilder = nil
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if  spec.isCon and not spec.isWeapon  then
				for i,v in pairs(spec.factoriesCanBuild) do
					if v == lab then
						if spec.mtype == 'amp' then
							ampBuilder = name
						else
							target = name
						end
					end
				end
			end
		end
	end

	if target then
		self:EchoDebug(target,'is tech of', lab)
		self.ranks[lab][target] = 'tech'
		self.techs[target] = true
	end
	if ampBuilder then
		self:EchoDebug(ampBuilder,'is amptech of', lab)
		self.ranks[lab][ampBuilder] = 'amptech'
		self.amptechs[ampBuilder] = true
	end

end

function ArmyHST:getRadar(units,lab)
	local cost = 0
	local target = nil

	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if  not spec.buildOptions and not spec.isWeapon and spec.radarRadius and not spec.isBuilder then
				if  spec.radarRadius > cost then
					cost = spec.radarRadius
					target = name
				end
			end
		end
	end

	if target then
		self:EchoDebug(target,'is radar of', lab)
		self.ranks[lab][target] = 'radar'
		self.radars[target] = true
	end
end

function ArmyHST:getCrawlingBomb(units,lab)
	local cost = 0
	local target = nil

	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.mclass == 'abotbomb2' then
				target = name
				self.ranks[lab][name] = 'crawling'
				self:EchoDebug(target,'is crowling bomb of', lab)
				self.crawlings[target] = true
			end
		end
	end

end



function ArmyHST:getRaiders(units,lab)
	local cost = 0
	local target = nil

	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isWeapon and spec.noChaseCat['vtol'] and not spec.buildOptions then
				if (spec.move * spec.dps ) / spec.metalCost > cost then
					cost = (spec.move * spec.dps ) / spec.metalCost
					target = name
				end
			end
		end
	end
	if target then
		self:EchoDebug(target,'is raider of', lab)
		self.ranks[lab][target] = 'raider'
		self.raiders[target] = true
	end
end

function ArmyHST:getBattle(units,lab)
	local cost = 0
	local target = nil

	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isWeapon  then
				if  spec.dps   > cost then
					cost =  spec.dps
					target = name
				end
			end
		end
	end
	if target then
		self:EchoDebug(target,'is battle of', lab)
		self.ranks[lab][target] = 'battle'
		self.battles[target] = true
	end
end

function ArmyHST:getBreak(units,lab)
	local cost = 0
	local target = nil

	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isWeapon and spec.noChaseCat['vtol'] and not spec.buildOptions then
				if  spec.dps   > cost then
					cost =  spec.dps
					target = name
				end
			end
		end
	end
	if target then
		self:EchoDebug(target,'is break of', lab)
		self.ranks[lab][target] = 'break'
		self.breaks[target] = true
	end
end

function ArmyHST:getLongRange(units,lab)
	local cost = 0
	local target = nil
	local spec = self.unitTable
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isWeapon  and spec.noChaseCat['vtol']  and  spec.mtype ~='air' then
				if spec.maxWeaponRange  > cost then
					cost = spec.maxWeaponRange
					target = name
				end
			end
		end
	end
	if target then
		self:EchoDebug(target,'is LongRange of', lab)
		self.ranks[lab][target] = 'longrange'
		self.longranges[target] = true
	end
end

function ArmyHST:getArtillery(units,lab)
	local cost = 0
	local target = nil
	local spec = self.unitTable
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isWeapon  and spec.noChaseCat['vtol']  and  spec.mtype ~='air' then
				if spec.maxWeaponRange / spec.metalCost > cost then
					cost = spec.maxWeaponRange / spec.metalCost
					target = name
				end
			end
		end
	end
	if target then
		self:EchoDebug(target,'is artillery of', lab)
		self.ranks[lab][target] = 'artillery'
		self.artillerys[target] = true
	end
end

function ArmyHST:getAmphibious(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isWeapon  and spec.noChaseCat['vtol']  and  spec.mtype == 'amp' then
				self:EchoDebug(name,'is amphibious of', lab)
				self.ranks[lab][name] = 'amphibious'
				self.amphibious[name] = true
			end
		end
	end
end

function ArmyHST:getSubK(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isWeapon    and  spec.mtype == 'sub' and not spec.buildOptions then
				self:EchoDebug(name,'is subKiller of', lab)
				self.ranks[lab][name] = 'subkiller'
				self.subkillers[name] = true
			end
		end
	end
end

function ArmyHST:getAttackers(units,lab)
	local spec = self.unitTable
	for i, name in pairs(units) do
		if utable.isWeapon and not utable.buildOptions   and not utable.antiNuke  and utable.noChaseCat ~= 'notair' and not utable.isBuilding and  utable.radarRadius < 1 and utable.jammerRadius < 1 and not utable.isTransport and not utable.isFighterAirUnit and not utable.isBomberAirUnit and not utable.canResurrect then
			spec.isAttacker = true
			self:EchoDebug(target,'is attacker ')
		end
	end

end

function ArmyHST:getScouts(units,lab)
	local cost = 1/0
	local target = nil

	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isWeapon and not spec.onlyTargets['vtol'] and not spec.buildOptions and spec.metalCost  < cost then
				cost = spec.metalCost
				target = name
			end
		end
	end

	if target then
		self:EchoDebug(target,'is scout of', lab)
		self.ranks[lab][target] = 'scout'
		self.scouts[target] = true
	end


end

function ArmyHST:getAntiAir(units,lab)
	local range = 0
	local aa = nil
	local spec = self.unitTable
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			if spec[name].noChaseCat['notair'] then
				aa = name
			end
		end
	end
	if not aa then
		for i, name in pairs(units) do
			if not self.ranks[lab][name] then
				if spec[name].onlyTargets and spec[name].onlyTargets['vtol'] then
					if spec[name].onlyTargets['vtol'] > range then
						range = spec[name].onlyTargets['vtol']
						aa = name
					end
				end
			end
		end
	end
	if not aa then
		for i, name in pairs(units) do
			if not self.ranks[lab][name] then
				if spec[name].badTargets and spec[name].badTargets['notair'] then
					if spec[name].badTargets['notair'] > range then
						range = spec[name].badTargets['notair']
						aa = name
					end
				end
			end
		end
	end

	if aa then
		self:EchoDebug(aa,'is AntiAir of', lab)
		self.ranks[lab][aa] = 'antiair'
		self.antiairs[aa] = true
	end

end

function ArmyHST:getAntiAir2(units,lab)
	local range = 0
	local aa = nil

	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.noChaseCat['notair'] then
				aa = name
			end
		end
	end
	if aa then
		self:EchoDebug(aa,'is AntiAir2 of', lab)
		self.ranks[lab][aa] = 'antiair2'
		self.antiairs2[aa] = true
	end
end


function ArmyHST:getUnranked(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			Spring:Echo(name,'is UNRANKED in', lab)
		end
	end
end




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
function ArmyHST:GetUnitTable()
	local builtBy = GetBuiltBy()
	local unitTable = {}
	local wrecks = {}
	for unitDefID,unitDef in pairs(UnitDefs) do
		local side = GetUnitSide(unitDef.name)
		if unitsLevels[unitDef.name] then



			-- --Spring.Echo(unitDef.name, "build slope", unitDef.maxHeightDif)
			-- if unitDef.moveDef.maxSlope then
			-- --Spring.Echo(unitDef.name, "move slope", unitDef.moveDef.maxSlope)
			-- end
			self.unitTable[unitDef.name] = {}

			local utable = self.unitTable[unitDef.name]
			utable.name = unitDef.name
			utable.side = side
			utable.defId = unitDefID
			utable.radarRadius = unitDef["radarRadius"]
			utable.airLosRadius = unitDef["airLosRadius"]
			utable.losRadius = unitDef["losRadius"]
			utable.sonarRadius = unitDef["sonarRadius"]
			utable.jammerRadius = unitDef["jammerRadius"]
			utable.stealth = unitDef.stealth
			utable.metalCost = unitDef["metalCost"]
			utable.energyCost = unitDef["energyCost"]
			utable.buildTime = unitDef["buildTime"]
			utable.totalEnergyOut = unitDef["totalEnergyOut"]
			utable.extractsMetal = unitDef["extractsMetal"]
			utable.energyMake = unitDef.energyMake
			utable.energyUse = unitDef.energyUpkeep
			utable.isTransport = unitDef.isTransport
			utable.isImmobile = unitDef.isImmobile
			utable.isBuilding = unitDef.isBuilding
			utable.isBuilder = unitDef.isBuilder
			utable.isMobileBuilder = unitDef.isMobileBuilder
			utable.isStaticBuilder = unitDef.isStaticBuilder
			utable.isFactory = unitDef.isLab
			utable.isExtractor = unitDef.Extractor
			utable.isGroundUnit = unitDef.isGroundUnit
			utable.isAirUnit = unitDef.isAirUnit
			utable.isStrafingAirUnit = unitDef.isStrafingAirUnit
			utable.isHoveringAirUnit = unitDef.isHoveringAirUnit
			utable.isFighterAirUnit = unitDef.isFighterAirUnit
			utable.isBomberAirUnit = unitDef.isBomberAirUnit
			utable.noChaseCat = unitDef.noChaseCategories
			utable.maxWeaponRange = unitDef.maxWeaponRange
			utable.mclass = unitDef.moveDef.name
			utable.speed = unitDef.speed
			utable.accel = unitDef.maxAcc
			utable.move = unitDef.speed * unitDef.maxAcc * unitDef.turnRate * unitDef.maxDec
			utable.hp = unitDef.health
			utable.buildSpeed = unitDef.buildSpeed
			utable.canAssist = unitDef.canAssist
			utable.canCloak = unitDef.canCloak
			utable.upright = unitDef.upright
			utable.canResurrect = unitDef.canResurrect
			utable.windGenerator = unitDef.windGenerator
			utable.tidalGenerator = unitDef.tidalGenerator
			utable.energyStorage = unitDef.energyStorage
			utable.metalStorage = unitDef.metalStorage
			utable.energyConv = unitDef.customParams.energyconv
			utable.groundRange = GetLongestWeaponRange(unitDefID, 0)
			utable.airRange = GetLongestWeaponRange(unitDefID, 1)
			utable.submergedRange = GetLongestWeaponRange(unitDefID, 2)
			utable.dps = getDPS(unitDefID)
			utable.antiNuke = getInterceptor(unitDefID)
			utable.targetableWeapon = getTargetableWeapon(unitDefID)
			utable.paralyzer = getParalyzer(unitDefID)
-- 			Spring:Echo(unitDef.name)
			utable.techLevel = unitsLevels[unitDef["name"]]
			if unitDef["modCategories"]["weapon"] then
				utable.isWeapon = true
			else
				utable.isWeapon = false
			end
			if unitDef["weapons"][1] then
				local defWepon1 = unitDef["weapons"][1]
				utable.onlyTargets = getOnlyTargets(unitDef["weapons"])
				utable.badTargets = getBadTargets(unitDef["weapons"])
				utable.firstWeapon = WeaponDefs[unitDef["weapons"][1]["weaponDef"]]
				utable.weaponType = utable.firstWeapon['type']
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



			--Spring:Echo(unitDef.name,utable.antiNuke)
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
			if utable.isFighterAirUnit then
				utable.airRange = utable.groundRange
			end
			utable.needsWater = unitDef.minWaterDepth > 0
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
						table.insert(utable.unitsCanBuild, buildDef["name"])
						--and save all the mtype that can andle
						--utable.isFactory[unitName[buildDef.name].mtype] = TODO
					end

				else
					utable.factoriesCanBuild = {}
					utable.buildingsCanBuild = {}
					for i, oid in pairs (unitDef["buildOptions"]) do

						local buildDef = UnitDefs[oid]
						table.insert(utable.buildingsCanBuild, buildDef["name"])
						if #buildDef["buildOptions"] > 0 and buildDef["isBuilding"] then
							-- build option is a factory, add it to factories this unit can build
							table.insert(utable.factoriesCanBuild, buildDef["name"])

						end
					end
					if #utable.factoriesCanBuild > 0 then
						utable.isCon = true
					else
						utable.isEngineer = true
					end



				end
			end
			if utable.isWeapon and not utable.buildOptions   and not utable.antiNuke  and utable.noChaseCat ~= 'notair' and not utable.isBuilding and  utable.radarRadius < 1 and utable.jammerRadius < 1 and not utable.isTransport and not utable.isFighterAirUnit and not utable.isBomberAirUnit and not utable.canResurrect then
				utable.isAttacker = true
				--Spring:Echo(utable.name, 'isAttacker')
			end
			utable.bigExplosion = unitDef["deathExplosion"] == "atomic_blast"
			utable.xsize = unitDef["xsize"]
			utable.zsize = unitDef["zsize"]
			utable.wreckName = unitDef["wreckName"]
			self.wrecks[unitDef["wreckName"]] = unitDef["name"]
		end
	end
end

function ArmyHST:GetFeatureTable()
	local featureTable = {}
	-- feature defs
	for featureDefID, featureDef in pairs(FeatureDefs) do
		local ftable = {}
		for i, k in pairs(featureKeysToGet) do
			local v = featureDef[k]
			ftable[k] = v
		end
		if self.wrecks[featureDef["name"]] then
			ftable.unitName = self.wrecks[featureDef["name"]]
		end
		self.featureTable[featureDef.name] = ftable
	end

end

getTechTree(armTechLv)
getTechTree(corTechLv)
for k,v in pairs(corTechLv) do unitsLevels[k] = v end
for k,v in pairs(armTechLv) do unitsLevels[k] = v end
--ArmyHST.unitTable, ArmyHST.wrecks = GetUnitTable()


function ArmyHST:setRanks()
	self.ranks = {}
	for lab,t in pairs (self.unitTable) do
		if t.isFactory then
			self.ranks[lab] = {}
			--scanLabs(t.unitsCanBuild,lab)

			self:getSpy(t.unitsCanBuild,lab)
			self:getSpiders(t.unitsCanBuild,lab)--
			self:getFreezer(t.unitsCanBuild,lab)--
			self:getBomberAir(t.unitsCanBuild,lab)
			self:getFighterAir(t.unitsCanBuild,lab)
			self:getAntiNuke(t.unitsCanBuild,lab)--
			self:getCrawlingBomb(t.unitsCanBuild,lab)
			self:getTransport(t.unitsCanBuild,lab)
			self:getCloakabe(t.unitsCanBuild,lab)
			self:getJammer(t.unitsCanBuild,lab)--
			self:getRadar(t.unitsCanBuild,lab)--
			self:getScouts(t.unitsCanBuild,lab)--
			self:getAntiAir(t.unitsCanBuild,lab)
			self:getTech(t.unitsCanBuild,lab)--
			self:getRez(t.unitsCanBuild,lab)--
			self:getMiner(t.unitsCanBuild,lab)--
			self:getWartech(t.unitsCanBuild,lab)--
			self:getEngineer(t.unitsCanBuild,lab)--
			self:getSubK(t.unitsCanBuild,lab)--
			self:getArtillery(t.unitsCanBuild,lab)--
			self:getAmphibious(t.unitsCanBuild,lab)
			self:getAntiAir(t.unitsCanBuild,lab)--
			self:getRaiders(t.unitsCanBuild,lab)--
			self:getBattle(t.unitsCanBuild,lab)--
			self:getBreak(t.unitsCanBuild,lab)--
			self:getLongRange(t.unitsCanBuild,lab)--
			self:getUnranked(t.unitsCanBuild,lab)
		end
	end
end
wrecks = nil
--[[








   [f=-000001] 0, ArmyHST, corbw, is paralyzer of, corap
   [f=-000001] 0, ArmyHST, corshad, is BomberAir of, corap
   [f=-000001] 0, ArmyHST, corveng, is fighterair of, corap
   [f=-000001] 0, ArmyHST, corvalk, is transport of, corap
   [f=-000001] 0, ArmyHST, corfink, is radar of, corap
   [f=-000001] 0, ArmyHST, corca, is tech of, corap

   [f=-000001] 0, ArmyHST, armthovr, is transport of, armfhp
   [f=-000001] 0, ArmyHST, armsh, is scout of, armfhp
   [f=-000001] 0, ArmyHST, armah, is AntiAir of, armfhp
   [f=-000001] 0, ArmyHST, armch, is tech of, armfhp
   [f=-000001] 0, ArmyHST, armmh, is artillery of, armfhp
   [f=-000001] 0, ArmyHST, armanac, is raider of, armfhp

   [f=-000001] 0, ArmyHST, armcarry, is antinuke of, armasy
   [f=-000001] 0, ArmyHST, armsjam, is jammer of, armasy
   [f=-000001] 0, ArmyHST, armsubk, is scout of, armasy
   [f=-000001] 0, ArmyHST, armaas, is AntiAir of, armasy
   [f=-000001] 0, ArmyHST, armacsub, is tech of, armasy
   [f=-000001] 0, ArmyHST, armmls, is Engineer of, armasy
   [f=-000001] 0, ArmyHST, armserp, is subKiller of, armasy
   [f=-000001] 0, ArmyHST, armmship, is artillery of, armasy
   [f=-000001] 0, ArmyHST, armcrus, is raider of, armasy
   [f=-000001] 0, ArmyHST, armepoch, is battle of, armasy
   [f=-000001] 0, ArmyHST, armbats, is break of, armasy

   [f=-000001] 0, ArmyHST, armthund, is BomberAir of, armap
   [f=-000001] 0, ArmyHST, armfig, is fighterair of, armap
   [f=-000001] 0, ArmyHST, armatlas, is transport of, armap
   [f=-000001] 0, ArmyHST, armpeep, is radar of, armap
   [f=-000001] 0, ArmyHST, armkam, is scout of, armap
   [f=-000001] 0, ArmyHST, armca, is tech of, armap

   [f=-000001] 0, ArmyHST, corsb, is BomberAir of, corplat
   [f=-000001] 0, ArmyHST, corsfig, is fighterair of, corplat
   [f=-000001] 0, ArmyHST, corhunt, is radar of, corplat
   [f=-000001] 0, ArmyHST, corcut, is scout of, corplat
   [f=-000001] 0, ArmyHST, corcsa, is tech of, corplat
   [f=-000001] 0, ArmyHST, corseap, is raider of, corplat

   [f=-000001] 0, ArmyHST, armfav, is scout of, armvp
   [f=-000001] 0, ArmyHST, armsam, is AntiAir of, armvp
   [f=-000001] 0, ArmyHST, armcv, is tech of, armvp
   [f=-000001] 0, ArmyHST, armbeaver, is amptech of, armvp
   [f=-000001] 0, ArmyHST, armmlv, is miner of, armvp
   [f=-000001] 0, ArmyHST, armart, is artillery of, armvp
   [f=-000001] 0, ArmyHST, armpincer, is amphibious of, armvp
   [f=-000001] 0, ArmyHST, armflash, is raider of, armvp
   [f=-000001] 0, ArmyHST, armjanus, is battle of, armvp
   [f=-000001] 0, ArmyHST, armstump, is break of, armvp

   [f=-000001] 0, ArmyHST, cormabm, is antinuke of, coravp
   [f=-000001] 0, ArmyHST, corintr, is transport of, coravp
   [f=-000001] 0, ArmyHST, coreter, is jammer of, coravp
   [f=-000001] 0, ArmyHST, corvrad, is radar of, coravp
   [f=-000001] 0, ArmyHST, cormart, is scout of, coravp
   [f=-000001] 0, ArmyHST, corsent, is AntiAir of, coravp
   [f=-000001] 0, ArmyHST, coracv, is tech of, coravp
   [f=-000001] 0, ArmyHST, corvroc, is artillery of, coravp
   [f=-000001] 0, ArmyHST, corseal, is amphibious of, coravp
   [f=-000001] 0, ArmyHST, corparrow, is amphibious of, coravp
   [f=-000001] 0, ArmyHST, correap, is raider of, coravp
   [f=-000001] 0, ArmyHST, cortrem, is battle of, coravp
   [f=-000001] 0, ArmyHST, corgol, is break of, coravp

   [f=-000001] 0, ArmyHST, corban, is LongRange of, coravp
   [f=-000001] 0, ArmyHST, corhurc, is BomberAir of, coraap
   [f=-000001] 0, ArmyHST, cortitan, is BomberAir of, coraap
   [f=-000001] 0, ArmyHST, corvamp, is fighterair of, coraap
   [f=-000001] 0, ArmyHST, corseah, is transport of, coraap
   [f=-000001] 0, ArmyHST, corawac, is radar of, coraap
   [f=-000001] 0, ArmyHST, corape, is scout of, coraap
   [f=-000001] 0, ArmyHST, coraca, is tech of, coraap

   [f=-000001] 0, ArmyHST, corcrw, is raider of, coraap
   [f=-000001] 0, ArmyHST, corsok, is scout of, corgant
   [f=-000001] 0, ArmyHST, corkarg, is AntiAir of, corgant
   [f=-000001] 0, ArmyHST, corshiva, is artillery of, corgant
   [f=-000001] 0, ArmyHST, corkorg, is amphibious of, corgant
   [f=-000001] 0, ArmyHST, corcat, is raider of, corgant
   [f=-000001] 0, ArmyHST, corjugg, is battle of, corgant

   [f=-000001] 0, ArmyHST, armpincer, is scout of, armamsub
   [f=-000001] 0, ArmyHST, armaak, is AntiAir of, armamsub
   [f=-000001] 0, ArmyHST, armbeaver, is amptech of, armamsub
   [f=-000001] 0, ArmyHST, armdecom, is fightingBuilders of, armamsub
   [f=-000001] 0, ArmyHST, armcroc, is artillery of, armamsub
   [f=-000001] 0, ArmyHST, armjeth, is AntiAir of, armamsub

   [f=-000001] 0, ArmyHST, corintr, is transport of, coramsub
   [f=-000001] 0, ArmyHST, corgarp, is scout of, coramsub
   [f=-000001] 0, ArmyHST, coraak, is AntiAir of, coramsub
   [f=-000001] 0, ArmyHST, cormuskrat, is amptech of, coramsub
   [f=-000001] 0, ArmyHST, cordecom, is fightingBuilders of, coramsub
   [f=-000001] 0, ArmyHST, corseal, is artillery of, coramsub
   [f=-000001] 0, ArmyHST, corparrow, is amphibious of, coramsub
   [f=-000001] 0, ArmyHST, corcrash, is AntiAir of, coramsub

   [f=-000001] 0, ArmyHST, armspy, is spy of, armalab
   [f=-000001] 0, ArmyHST, armsptk, is spider of, armalab
   [f=-000001] 0, ArmyHST, armscab, is spider of, armalab
   [f=-000001] 0, ArmyHST, armspid, is paralyzer of, armalab
   [f=-000001] 0, ArmyHST, armvader, is crowling bomb of, armalab
   [f=-000001] 0, ArmyHST, armsnipe, is cloakable of, armalab
   [f=-000001] 0, ArmyHST, armaser, is jammer of, armalab
   [f=-000001] 0, ArmyHST, armmark, is radar of, armalab
   [f=-000001] 0, ArmyHST, armfast, is scout of, armalab
   [f=-000001] 0, ArmyHST, armaak, is AntiAir of, armalab
   [f=-000001] 0, ArmyHST, armack, is tech of, armalab
   [f=-000001] 0, ArmyHST, armdecom, is fightingBuilders of, armalab
   [f=-000001] 0, ArmyHST, armfark, is Engineer of, armalab
   [f=-000001] 0, ArmyHST, armfido, is artillery of, armalab
   [f=-000001] 0, ArmyHST, armamph, is AntiAir of, armalab
   [f=-000001] 0, ArmyHST, armmav, is raider of, armalab
   [f=-000001] 0, ArmyHST, armfboy, is battle of, armalab
   [f=-000001] 0, ArmyHST, armzeus, is break of, armalab

   [f=-000001] 0, ArmyHST, armgremlin, is cloakable of, armavp
   [f=-000001] 0, ArmyHST, armjam, is jammer of, armavp
   [f=-000001] 0, ArmyHST, armseer, is radar of, armavp
   [f=-000001] 0, ArmyHST, armmart, is scout of, armavp
   [f=-000001] 0, ArmyHST, armyork, is AntiAir of, armavp
   [f=-000001] 0, ArmyHST, armacv, is tech of, armavp
   [f=-000001] 0, ArmyHST, armconsul, is Engineer of, armavp
   [f=-000001] 0, ArmyHST, armlatnk, is artillery of, armavp
   [f=-000001] 0, ArmyHST, armcroc, is amphibious of, armavp
   [f=-000001] 0, ArmyHST, armbull, is raider of, armavp
   [f=-000001] 0, ArmyHST, armmanni, is battle of, armavp
   [f=-000001] 0, ArmyHST, armmerl, is break of, armavp

   [f=-000001] 0, ArmyHST, corfav, is scout of, corvp
   [f=-000001] 0, ArmyHST, cormist, is AntiAir of, corvp
   [f=-000001] 0, ArmyHST, corcv, is tech of, corvp
   [f=-000001] 0, ArmyHST, cormuskrat, is amptech of, corvp
   [f=-000001] 0, ArmyHST, cormlv, is miner of, corvp
   [f=-000001] 0, ArmyHST, corwolv, is artillery of, corvp
   [f=-000001] 0, ArmyHST, corgarp, is amphibious of, corvp
   [f=-000001] 0, ArmyHST, corgator, is raider of, corvp
   [f=-000001] 0, ArmyHST, corlevlr, is battle of, corvp
   [f=-000001] 0, ArmyHST, corraid, is break of, corvp

   [f=-000001] 0, ArmyHST, armthovr, is transport of, armhp
   [f=-000001] 0, ArmyHST, armsh, is scout of, armhp
   [f=-000001] 0, ArmyHST, armah, is AntiAir of, armhp
   [f=-000001] 0, ArmyHST, armch, is tech of, armhp
   [f=-000001] 0, ArmyHST, armmh, is artillery of, armhp
   [f=-000001] 0, ArmyHST, armanac, is raider of, armhp

   [f=-000001] 0, ArmyHST, armcroc, is scout of, armshltxuw
   [f=-000001] 0, ArmyHST, armmar, is AntiAir of, armshltxuw
   [f=-000001] 0, ArmyHST, armbanth, is artillery of, armshltxuw

   [f=-000001] 0, ArmyHST, armstil, is paralyzer of, armaap
   [f=-000001] 0, ArmyHST, armpnix, is BomberAir of, armaap
   [f=-000001] 0, ArmyHST, armlance, is BomberAir of, armaap
   [f=-000001] 0, ArmyHST, armhawk, is fighterair of, armaap
   [f=-000001] 0, ArmyHST, armliche, is fighterair of, armaap
   [f=-000001] 0, ArmyHST, armdfly, is transport of, armaap
   [f=-000001] 0, ArmyHST, armawac, is radar of, armaap
   [f=-000001] 0, ArmyHST, armbrawl, is scout of, armaap
   [f=-000001] 0, ArmyHST, armaca, is tech of, armaap
   [f=-000001] 0, ArmyHST, armblade, is raider of, armaap

   [f=-000001] 0, ArmyHST, cortship, is transport of, corsy
   [f=-000001] 0, ArmyHST, coresupp, is scout of, corsy
   [f=-000001] 0, ArmyHST, corpt, is AntiAir of, corsy
   [f=-000001] 0, ArmyHST, corcs, is tech of, corsy
   [f=-000001] 0, ArmyHST, correcl, is rez of, corsy
   [f=-000001] 0, ArmyHST, corsub, is subKiller of, corsy
   [f=-000001] 0, ArmyHST, corpship, is artillery of, corsy
   [f=-000001] 0, ArmyHST, corroy, is raider of, corsy

   [f=-000001] 0, ArmyHST, corcarry, is antinuke of, corasy
   [f=-000001] 0, ArmyHST, corsjam, is jammer of, corasy
   [f=-000001] 0, ArmyHST, corshark, is scout of, corasy
   [f=-000001] 0, ArmyHST, corarch, is AntiAir of, corasy
   [f=-000001] 0, ArmyHST, coracsub, is tech of, corasy
   [f=-000001] 0, ArmyHST, cormls, is Engineer of, corasy
   [f=-000001] 0, ArmyHST, corssub, is subKiller of, corasy
   [f=-000001] 0, ArmyHST, cormship, is artillery of, corasy
   [f=-000001] 0, ArmyHST, corcrus, is raider of, corasy
   [f=-000001] 0, ArmyHST, corblackhy, is battle of, corasy
   [f=-000001] 0, ArmyHST, corbats, is break of, corasy

   [f=-000001] 0, ArmyHST, corak, is scout of, corlab
   [f=-000001] 0, ArmyHST, corcrash, is AntiAir of, corlab
   [f=-000001] 0, ArmyHST, corck, is tech of, corlab
   [f=-000001] 0, ArmyHST, cornecro, is rez of, corlab
   [f=-000001] 0, ArmyHST, corstorm, is artillery of, corlab
   [f=-000001] 0, ArmyHST, corthud, is raider of, corlab

   [f=-000001] 0, ArmyHST, armsb, is BomberAir of, armplat
   [f=-000001] 0, ArmyHST, armsfig, is fighterair of, armplat
   [f=-000001] 0, ArmyHST, armsehak, is radar of, armplat
   [f=-000001] 0, ArmyHST, armsaber, is scout of, armplat
   [f=-000001] 0, ArmyHST, armcsa, is tech of, armplat
   [f=-000001] 0, ArmyHST, armseap, is raider of, armplat

   [f=-000001] 0, ArmyHST, corthovr, is transport of, corhp
   [f=-000001] 0, ArmyHST, corsh, is scout of, corhp
   [f=-000001] 0, ArmyHST, corah, is AntiAir of, corhp
   [f=-000001] 0, ArmyHST, corch, is tech of, corhp
   [f=-000001] 0, ArmyHST, cormh, is artillery of, corhp
   [f=-000001] 0, ArmyHST, corsnap, is raider of, corhp
   [f=-000001] 0, ArmyHST, corhal, is battle of, corhp

   [f=-000001] 0, ArmyHST, corseal, is scout of, corgantuw
   [f=-000001] 0, ArmyHST, corparrow, is artillery of, corgantuw
   [f=-000001] 0, ArmyHST, corkorg, is amphibious of, corgantuw
   [f=-000001] 0, ArmyHST, corshiva, is amphibious of, corgantuw

   [f=-000001] 0, ArmyHST, corthovr, is transport of, corfhp
   [f=-000001] 0, ArmyHST, corsh, is scout of, corfhp
   [f=-000001] 0, ArmyHST, corah, is AntiAir of, corfhp
   [f=-000001] 0, ArmyHST, corch, is tech of, corfhp
   [f=-000001] 0, ArmyHST, cormh, is artillery of, corfhp
   [f=-000001] 0, ArmyHST, corsnap, is raider of, corfhp
   [f=-000001] 0, ArmyHST, corhal, is battle of, corfhp

   [f=-000001] 0, ArmyHST, corspy, is spy of, coralab
   [f=-000001] 0, ArmyHST, cortermite, is spider of, coralab
   [f=-000001] 0, ArmyHST, corroach, is crowling bomb of, coralab
   [f=-000001] 0, ArmyHST, corsktl, is crowling bomb of, coralab
   [f=-000001] 0, ArmyHST, corspec, is jammer of, coralab
   [f=-000001] 0, ArmyHST, corvoyr, is radar of, coralab
   [f=-000001] 0, ArmyHST, corpyro, is scout of, coralab
   [f=-000001] 0, ArmyHST, coraak, is AntiAir of, coralab
   [f=-000001] 0, ArmyHST, corack, is tech of, coralab
   [f=-000001] 0, ArmyHST, cordecom, is fightingBuilders of, coralab
   [f=-000001] 0, ArmyHST, cormando, is fightingBuilders of, coralab
   [f=-000001] 0, ArmyHST, corfast, is Engineer of, coralab
   [f=-000001] 0, ArmyHST, cormort, is artillery of, coralab
   [f=-000001] 0, ArmyHST, coramph, is amphibious of, coralab
   [f=-000001] 0, ArmyHST, corcan, is raider of, coralab
   [f=-000001] 0, ArmyHST, corsumo, is battle of, coralab
   [f=-000001] 0, ArmyHST, corhrk, is break of, coralab

   [f=-000001] 0, ArmyHST, armflea, is scout of, armlab
   [f=-000001] 0, ArmyHST, armjeth, is AntiAir of, armlab
   [f=-000001] 0, ArmyHST, armck, is tech of, armlab
   [f=-000001] 0, ArmyHST, armrectr, is rez of, armlab
   [f=-000001] 0, ArmyHST, armrock, is artillery of, armlab
   [f=-000001] 0, ArmyHST, armpw, is raider of, armlab
   [f=-000001] 0, ArmyHST, armwar, is battle of, armlab
   [f=-000001] 0, ArmyHST, armham, is break of, armlab

   [f=-000001] 0, ArmyHST, armtship, is transport of, armsy
   [f=-000001] 0, ArmyHST, armdecade, is scout of, armsy
   [f=-000001] 0, ArmyHST, armpt, is AntiAir of, armsy
   [f=-000001] 0, ArmyHST, armcs, is tech of, armsy
   [f=-000001] 0, ArmyHST, armrecl, is rez of, armsy
   [f=-000001] 0, ArmyHST, armsub, is subKiller of, armsy
   [f=-000001] 0, ArmyHST, armpship, is artillery of, armsy
   [f=-000001] 0, ArmyHST, armroy, is raider of, armsy

   [f=-000001] 0, ArmyHST, armvang, is scout of, armshltx
   [f=-000001] 0, ArmyHST, armmar, is AntiAir of, armshltx
   [f=-000001] 0, ArmyHST, armlun, is artillery of, armshltx
   [f=-000001] 0, ArmyHST, armbanth, is amphibious of, armshltx
   [f=-000001] 0, ArmyHST, armraz, is battle of, armshltx
]]



--[[
armdf fake
   ]]--

