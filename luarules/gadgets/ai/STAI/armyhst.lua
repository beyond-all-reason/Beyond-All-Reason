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
	-------MOBILE----------------

	self.techs = {
		corca = true,
		armch = true,
		corch = true,
		armacsub = true,
		armca = true,
		corcsa = true, --plat
		armcsa = true, --plat
		armcv = true,
		coracv = true,
		coraca = true,
		armacv = true,
		armack = true,
		corack = true,
		corcv = true,
		armaca = true,
		corcs = true,
		armcs = true,
		corck = true,
		armck = true,



		}
	self.engineers = {
		armmls = 'armacs',
		armfark = 'armack',
		armconsul = 'amracv',
		corfast = 'corack',
		cormls = 'coracs',
		}
	self.wartechs = {
		armdecom = true,
		cordecom = true,
		cormando = true,


		} --decoy etc
	self.rezs = {
		armrectr = true,
		cornecro = true,
		armrecl = true,
		correcl = true,

		}
	self.amptechs = {
		armbeaver = true,
		cormuskrat = true,


		} --amphibious builders
	self.miners = {
		armmlv = true,
		cormlv = true,
		}

	self.jammers = {
		armsjam = true,
		coreter = true,
		armaser = true,
		armjam = true,
		corsjam = true,
		corspec = true,


		}
	self.radars = {
		corfink = true,--is a scout but is better used as radar cause no weapon
		armpeep = true,--is a scout but is better used as radar cause no weapon
		corvrad = true,
		armmark = true,
		armseer = true,
		corvoyr = true,
		corawac = true,
		armawac = true,
		armsehak = true,
		corhunt = true,


		}
	self.spys = {
		armspy = true,
		corspy = true,
		}
	self.transports = {
		corvalk = true,
		armatlas = true,
		armdfly = true,
		corseah = true,

		}

	self.scouts = {
		armfav = true,
		corfav = true,
		armflea = true,
		armfast = true,
		armdecade = true,
		coresupp = true,



		}
	self.raiders = {
		armflash = true,
		corgator = true,
		corak = true,
		armpw = true,
		armlatnk = true,
		corseal = true,
		corpyro = true,
		armzeus = true,
		armsh = true,
		corsh = true,
		corsub = true,
		armsub = true,
		armsubk = true,
		corshark = true,
		armraz = true,
		corkarg = true,

		}
	self.artillerys = {
		armrock = true,
		corstorm = true,
		armart = true,
		corwolv = true,
		armfboy = true,
		cormort = true,
		armmart = true,
		cormart = true,
		armvang = true,--t3a
		corcat = true,--t3c
		corbats = true,
		armbats = true,

		--cortrem = true,
		corjugg = true,

		}
	self.rocketers = {
		armmerl = true,
		corvroc = true, -- T2C
-- 		corban = true,T2C
		corhrk = true,
		cormship = true,
		armmship = true,
		armmh = true,
		cormh = true,
		}

	self.battles = {
		armham = true,
		corthud = true,
		armstump = true,
		corraid = true,
		armfido = 'armmav',
		corcan = true,
		armbull = true,
		correap = true,
		armanac = true,--ha
		corsnap = true,--hc
		armpship = true,--t1a
		corpship = true,--t1c
		corcrus = true,
		armcrus = true,
		armbanth = true,--t3a
		cordemon = true,



		--corhal = true,





		}
	self.breaks = {
		armwar = true,
		armjanus = true,
		corlevlr = true,
		armsnipe = true,
		corsumo = true,
		corgol = true,
		armmanni = true,
		armlun = true,--hover
		corsok = true,--hover
		armroy = true,
		corroy = true,



		corblackhy = true,
		armepoch = true,
		armthor = true, --t3a
		corkorg = true,--t3c

		}
	self.amphibious = {
		armpincer = true,
		corparrow = true,
		armcroc = true,
		armamph = true,
		corgarp = true,
		coramph = true,
		armmar = true,
		corshiva = true,

		}
	self.heavyAmphibious = {
	
		corparrow = true,
		armcroc = true,

		}
	self.spiders = {
		cortermite = true,
		armsptk = true,

		}
	self.paralyzers = {
		corbw = true,
		armspid = true,
		armstil = true,

		}
	self.subkillers = {
		armserp = true,
		corssub = true,



		} -- submarine weaponed
	self.bomberairs = {
		corshad = true,
		armthund = true,
		armsb = true, --plat
		corhurc = true,
		armpnix = true,
		armliche = true,
		corsb = true,--plat
		}

	self.fighterairs = {
		corveng = true,
		armfig = true,
		corsfig = true, --plat
		armsfig = true, --plat
		cortitan = true,
		armhawk = true,
		}

	self.tpbombers = {
		corvamp = true,
		armlance = true,


		}

	self.airgun = {
		armkam = true,
		corcrwh = true,
		corape = true,
		armbrawl = true,
		armblade = true,
		armseap = true, -- but is a torpedo gunship
		armsaber = true,
		corseap = true,
		corcut = true,

		}

	self.antiairs = {
		armah = true,
		corah = true,
		armaas = true,
		armsam = true,
		corsent = true,
		armaak = true,
		armyork = true,
		cormist = true,
		corcrash = true,
		armjeth = true,
		coraak = true,
		corarch = true,
		armpt = true, --aa+scout
		corpt = true, --aa+scout
		}

	self.antinukes = {
		armcarry = true,
		corcarry = true,
		cormabm = true,
		armscab = true,
		}

	self.crawlings = {
		armvader = true,
		corroach = true,
		corsktl = true,
		}

	self.cloakables = {
		armsnipe = true,
		armgremlin = true,
		}

	-------IMMOBILE--------
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

		}

	self._solar_ = {
		corsolar = 'coradvsol' ,
		armsolar = 'armadvsol' ,
		}


	self._mex_ = {
		cormex = 'cormoho' ,
		cormexp = true ,
		armmex = "armmoho" ,
		armamex = 'armmoho' ,
		armmoho = true ,
		cormoho = true ,
		corexp = 'cormexp' ,
		armuwmme = true ,
		coruwmme = true ,
		}
	ArmyHST.t2mex = {
		armmoho = true,
		cormoho = true,
		armuwmme = true,
		coruwmme = true,
		}
	-- what mexes upgrade to what
	ArmyHST.mexUpgrade = {
		cormex = "cormoho",
		armmex = "armmoho",
		armamex = "armmoho",
		corexp = "cormoho",
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

	-- 	self._afus_ = {
	-- 		armafus = true ,
	-- 		corafus = true ,
	-- 	}


	self._fus_ = {
		armfus = 'armafus' ,--will become afus in buildersbst:specialfilter()
		armuwfus = 'armuwfus' , --no advuwfus
		corfus = 'corafus' ,--will become afus in buildersbst:specialfilter()
		coruwfus = 'coruwfus' ,--no advuwfus
		-- 		armckfus = true , --clackable, better to think about it later

		-- 		armafus = true ,
		-- 		corafus = true ,
		--armdf = true, --fake fus
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
	corgantuw = {"amp","hov"},
	armshltxuw = {"amp","hov"},
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

-- ArmyHST.littlePlasmaList = {
-- 	corpun = 1,
-- 	armguard = 1,
-- 	cortoast = 1,
-- 	armamb = 1,
-- 	corbhmth = 1,
-- }

-- what mexes upgrade to what
--[[ArmyHST.mexUpgrade = {
	cormex = "cormoho",
	armmex = "armmoho",
	armamex = "armmoho",
	corexp = "cormexp",

	}
]]

-- factories that can build advanced construction units (i.e. moho mines)
ArmyHST.advFactories = {
	coravp = 'corvp',
	coralab = 'corlab',
	corasy = 'corsy',
	coraap = 'corap',
	corplat = 1,
	armavp = 'armvp',
	armalab = 'armlab',
	armasy = 'armsy',
	armaap = 'armap',
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
ArmyHST.t1tot2factory = {
	corlab = 'coralab',
	armlab = 'armalab',
	corsy = 'corasy',
	armsy = 'armasy',
	armvp = 'armavp',
	corvp = 'coravp',
	}

ArmyHST.commanderList = {
	armcom = 1,
	corcom = 1,
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
-- ArmyHST.minAttackCounter = 4
-- ArmyHST.maxAttackCounter = 16
-- ArmyHST.baseAttackCounter = 8
--ArmyHST.breakthroughAttackCounter = 10 -- build heavier battle units
-- ArmyHST.siegeAttackCounter = 10 -- build siege units
-- ArmyHST.minBattleCount = 4 -- how many battle units to build before building any breakthroughs, even if counter is too high
ArmyHST.minBomberCounter = 10
ArmyHST.maxBomberCounter = 20
ArmyHST.baseBomberCounter = 10
-- ArmyHST.breakthroughBomberCounter = 8 -- build atomic bombers or air fortresses

-- raid counter works backwards: it determines the number of raiders to build
-- if it reaches ArmyHST.minRaidCounter, none are built
-- ArmyHST.minRaidCounter =2
-- ArmyHST.maxRaidCounter = 8
-- ArmyHST.baseRaidCounter = 5

-- Taskqueuebehaviour was modified to skip this name
-- ArmyHST.DummyUnitName = "skipthisorder"
-- this unit is used to check for underwater metal spots
ArmyHST.UWMetalSpotCheckUnit = "cormex"

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
	--('targetable',targetable)
	return targetable
end

local function getParalyzer(unitDefID)
	local unitDef = UnitDefs[unitDefID]
	local weapons = unitDef["weapons"]
	local paralyzer = nil
	for i=1, #weapons do
		local weaponDefID = weapons[i]["weaponDef"]
		local weaponDef = WeaponDefs[weaponDefID]
		paralyzer  =  weaponDef['paralyzer']
	end
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
			end
		end
	end
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
		--print(weaponDefID)
		--print(weaponDef["canAttackGround"])
		--print(weaponDef["waterWeapon"])
		--print(weaponDef["range"])
		--print(weaponDef["type"])
		local wType = 0
		if weaponDef["canAttackGround"] == false then
			wType = 1
		elseif weaponDef["waterWeapon"] then
			wType = 2
		else
			wType = 0
		end
		-- --print(wType)
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

-- local function GetWeaponParams(weaponDefID)
-- 	local WD = WeaponDefs[weaponDefID]
-- 	local WDCP = WD.customParams
-- 	local weaponDamageSingle = tonumber(WDCP.statsdamage) or WD.damages[0] or 0
-- 	local weaponDamageMult = tonumber(WDCP.statsprojectiles) or ((tonumber(WDCP.script_burst) or WD.salvoSize) * WD.projectiles)
-- 	local weaponDamage = weaponDamageSingle * weaponDamageMult
-- 	local weaponRange = WD.range
--
-- 	local reloadTime = tonumber(WD.customParams.script_reload) or WD.reload
--
-- 	if WD.dyndamageexp and WD.dyndamageexp > 0 then
-- 		local dynDamageExp = WD.dyndamageexp
-- 		local dynDamageMin = WD.dyndamagemin or 0.0001
-- 		local dynDamageRange = WD.dyndamagerange or weaponRange
-- 		local dynDamageInverted = WD.dyndamageinverted or false
-- 		local dynMod
--
-- 		if dynDamageInverted then
-- 			dynMod = math.pow(distance3D / dynDamageRange, dynDamageExp)
-- 		else
-- 			dynMod = 1 - math.pow(distance3D / dynDamageRange, dynDamageExp)
-- 		end
--
-- 		weaponDamage = math.max(weaponDamage * dynMod, dynDamageMin)
-- 	end
--
-- 	local dps = weaponDamage / reloadTime
-- 	return dps, weaponDamage, reloadTime
-- end




local function GetUnitSide(name)--TODO change to the internal name armada cortex
	if string.find(name, 'arm') then
		return 'arm'
	elseif string.find(name, 'cor') then
		return 'core'
	elseif string.find(name, 'raptor') then
		return 'raptor'
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
			local canBuild = UnitDefNames[name].buildOptions
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

function ArmyHST:getThreatRange(unitName)
end

function ArmyHST:GetUnitTable()
	--local builtBy = GetBuiltBy()
	for unitDefID,unitDef in pairs(UnitDefs) do
		local side = GetUnitSide(unitDef.name)
		--if unitsLevels[unitDef.name] then



		-- --print(unitDef.name, "build slope", unitDef.maxHeightDif)
		-- if unitDef.moveDef.maxSlope then
		-- --print(unitDef.name, "move slope", unitDef.moveDef.maxSlope)
		-- end
		self.unitTable[unitDef.name] = {}
		-- 			Spring:Echo(unitDef.name)
		local utable = self.unitTable[unitDef.name]
		utable.name = unitDef.name
		utable.humanName = unitDef.humanName
		utable.side = side
		utable.defId = unitDefID
		utable.radarDistance = unitDef["radarDistance"]
		utable.airSightDistance = unitDef["airSightDistance"]
		utable.sightDistance = unitDef["losRadius"]
		utable.sonarDistance = unitDef["sonarDistance"]
		utable.radarDistanceJam = unitDef["radarDistanceJam"]
		utable.stealth = unitDef.stealth
		utable.metalCost = unitDef.metalCost
		utable.energyCost = unitDef.energyCost
		utable.buildTime = unitDef.buildTime
		utable.totalEnergyOut = unitDef.totalEnergyOut
		utable.extractsMetal = unitDef.extractsMetal
		utable.energyMake = unitDef.energyMake
		utable.energyUse = unitDef.energyUpkeep
		utable.isTransport = unitDef.isTransport
		utable.isImmobile = unitDef.isImmobile
		utable.isBuilding = unitDef.isBuilding
		utable.isBuilder = unitDef.isBuilder
		utable.isMobileBuilder = unitDef.isMobileBuilder
		utable.isStaticBuilder = unitDef.isStaticBuilder
		utable.isLab = unitDef.isLab
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
		utable.groundRange = GetLongestWeaponRange(unitDefID, 0) or 0
		utable.airRange = GetLongestWeaponRange(unitDefID, 1) or 0
		utable.submergedRange = GetLongestWeaponRange(unitDefID, 2) or 0
		utable.G_R = GetLongestWeaponRange(unitDefID, 0) or 0
		utable.A_R = GetLongestWeaponRange(unitDefID, 1) or 0
		utable.S_R = GetLongestWeaponRange(unitDefID, 2) or 0
		utable.weaponMtype = {}
		utable.weaponLayer = {}
		utable.longRange = nil
		utable.maxRange = 0
		utable.threat = 0
		utable.airThreat = 0
		utable.groundThreat = 0
		utable.submergedThreat = 0
		if utable.groundRange > 0 then
			utable.longRange = 'ground'
			utable.groundThreat = utable.metalCost
			utable.maxRange = utable.groundRange
			table.insert(utable.weaponLayer,'ground')
			table.insert(utable.weaponMtype, "veh")
			table.insert(utable.weaponMtype, "bot")
			table.insert(utable.weaponMtype, "amp")
			table.insert(utable.weaponMtype, "hov")
			table.insert(utable.weaponMtype, "shp")
		end

		if utable.airRange > 0 then
			if utable.airRange > utable.groundRange and utable.airRange > utable.submergedRange then
				utable.longRange = 'air'
				utable.maxRange = utable.airRange
			end
			utable.airThreat = utable.metalCost
			table.insert(utable.weaponLayer,'air')
			table.insert(utable.weaponMtype, "air")
		end
		if utable.submergedRange > 0 then
			if utable.submergedRange > utable.groundRange and utable.submergedRange > utable.airRange then
				utable.longRange = 'submberged'
				utable.maxRange = utable.submergedRange
			end
			utable.submergedThreat = utable.metalCost
			table.insert(utable.weaponLayer,'submerged')
			table.insert(utable.weaponMtype, "sub")
			table.insert(utable.weaponMtype, "shp")
			table.insert(utable.weaponMtype, "amp")
		end
		if utable.longRange then
			utable.threat = utable.metalCost
		end
		if self.antinukes[utable.name] or self.nukeList[utable.name] or self.bigPlasmaList[utable.name] or self._shield_[utable.name] or self._juno_ then
			utable.threat = 0
			utable.maxRange = 0
		end
		utable.threatLayers = {}
		utable.threatLayers.air = { threat = utable.airThreat , range = utable.airRange }
		utable.threatLayers.ground = { threat = utable.groundThreat , range = utable.groundRange }
		utable.threatLayers.submerged = { threat = utable.submergedThreat , range = utable.submergedRange }
		utable.dps = getDPS(unitDefID)
		utable.antiNuke = getInterceptor(unitDefID)
		utable.targetableWeapon = getTargetableWeapon(unitDefID)
		utable.paralyzer = getParalyzer(unitDefID)
		utable.techLevel = unitsLevels[unitDef["name"]] or 1
		if unitDef["modCategories"]["weapon"] then
			utable.isWeapon = true
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
				for ii,_ in pairs(defWepon1.onlyTargets) do
					utable.onlyTg = utable.onlyTg .. ii
				end
			end
			utable.onlyBadTg = utable.onlyTg .. utable.badTg
		end



		--Spring:Echo(unitDef.name,utable.antiNuke)
		if unitDef.speed > 0 and utable.isWeapon then
			utable.isMobileWeapon = true
		end
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
			utable.LAYER = 'A'
		elseif	utable.isBuilding and utable.needsWater then
			utable.mtype = 'sub'
			utable.LAYER = 'S'
		elseif	utable.isBuilding and not utable.needsWater then
			utable.mtype = 'veh'
			utable.LAYER = 'G'
		elseif  unitDef.moveDef.name and (string.find(unitDef.moveDef.name, 'abot') or string.find(unitDef.moveDef.name, 'commanderbot') or string.find(unitDef.moveDef.name, 'vbot')  or string.find(unitDef.moveDef.name,'atank'))  then
			utable.mtype = 'amp'
			utable.LAYER = 'X'
		elseif unitDef.moveDef.name and string.find(unitDef.moveDef.name, 'uboat') then
			utable.mtype = 'sub'
			utable.LAYER = 'S'
		elseif unitDef.moveDef.name and  string.find(unitDef.moveDef.name, 'hover') then
			utable.mtype = 'hov'
			utable.LAYER = 'G'
		elseif unitDef.moveDef.name and string.find(unitDef.moveDef.name, 'boat') then
			utable.mtype = 'shp'
			utable.LAYER = 'G'
		elseif unitDef.moveDef.name and string.find(unitDef.moveDef.name, 'tank') then
			utable.mtype = 'veh'
			utable.LAYER = 'G'
		elseif unitDef.moveDef.name and string.find(unitDef.moveDef.name, 'bot') then
			utable.mtype = 'bot'
			utable.LAYER = 'G'
		else
			if unitDef.maxwaterdepth and unitDef.maxwaterdepth < 0 then
				utable.mtype = 'shp'
				utable.LAYER = 'G'
			else
				utable.mtype = 'veh'
				utable.LAYER = 'G'
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

		utable.mtypedLv = tostring(utable.mtype)..utable.techLevel
		if self.scouts[utable.name] or self.raiders[utable.name] or self.battles[utable.name] or self.breaks[utable.name] or self.airgun[utable.name] or self.cloakables[utable.name] or self.amphibious[utable.name] or self.subkillers[utable.name] or self.spiders[utable.name] or self.paralyzers[utable.name] or self.artillerys[utable.name] or self.crawlings[utable.name]then
			utable.isAttacker = true
			--Spring:Echo(utable.name, 'isAttacker')
		end
		utable.bigExplosion = unitDef["deathExplosion"] == "atomic_blast"
		utable.xsize = unitDef["xsize"]
		utable.zsize = unitDef["zsize"]
		utable.corpse = unitDef["corpse"]
		self.wrecks[unitDef["corpse"]] = unitDef["name"]
		--end
	end
end

function ArmyHST:GetFeatureTable()
	local featureTable = {}
	-- feature defs
	for _, featureDef in pairs(FeatureDefs) do
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
