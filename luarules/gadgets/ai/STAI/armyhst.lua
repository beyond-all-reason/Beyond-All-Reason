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
		cortex_constructionaircraft = true,
		armada_constructionhovercraft = true,
		corch = true,
		armada_advancedconstructionsub = true,
		armada_constructionaircraft = true,
		corcsa = true, --plat
		armada_constructionseaplane = true, --plat
		armada_constructionvehicle = true,
		coracv = true,
		cortex_advancedconstructionaircraft = true,
		armada_advancedconstructionvehicle = true,
		armada_advancedconstructionbot = true,
		corack = true,
		corcv = true,
		armada_advancedconstructionaircraft = true,
		corcs = true,
		armada_constructionship = true,
		corck = true,
		armada_constructionbot = true,



		}
	self.engineers = {
		armada_voyager = true,
		armada_butler = true,
		armada_consul = true,
		corfast = true,
		cormls = true,

		}
	self.wartechs = {
		armada_decoycommander = true,
		cortex_decoycommander = true,
		cormando = true,


		} --decoy etc
	self.rezs = {
		armada_lazarus = true,
		cornecro = true,
		armada_grimreaper = true,
		correcl = true,

		}
	self.amptechs = {
		armada_beaver = true,
		cormuskrat = true,


		} --amphibious builders
	self.miners = {
		armada_groundhog = true,
		cormlv = true,
		}

	self.jammers = {
		armada_bermuda = true,
		coreter = true,
		armada_radarjammerbot = true,
		armada_umbra = true,
		corsjam = true,
		corspec = true,


		}
	self.radars = {
		corfink = true,--is a scout but is better used as radar cause no weapon
		armada_blink = true,--is a scout but is better used as radar cause no weapon
		corvrad = true,
		armada_compass = true,
		armada_prophet = true,
		corvoyr = true,
		cortex_condor = true,
		armada_oracle = true,
		armada_horizon = true,
		corhunt = true,


		}
	self.spys = {
		armada_ghost = true,
		corspy = true,
		}
	self.transports = {
		cortex_hercules = true,
		armada_stork = true,
		armada_bearer = true,
		corthovr = true,
		corintr = true,
		armada_abductor = true,
		cortship = true,
		armada_convoy = true,
		cortex_skyhook = true,

		}

	self.scouts = {
		armada_rover = true,
		corfav = true,
		armada_tick = true,
		armada_sprinter = true,
		armada_dolphin = true,
		coresupp = true,



		}
	self.raiders = {
		armada_blitz = true,
		corgator = true,
		corak = true,
		armada_pawn = true,
		armada_jaguar = true,
		corseal = true,
		corpyro = true,
		armada_welder = true,
		armada_seeker = true,
		corsh = true,
		corsub = true,
		armada_eel = true,
		armada_barracuda = true,
		corshark = true,
		armada_razorback = true,
		corkarg = true,

		}
	self.artillerys = {
		armada_rocketeer = true,
		corstorm = true,
		armada_shellshocker = true,
		corwolv = true,
		armada_hound = true,
		cormort = true,
		armada_mauser = true,
		cormart = true,
		armada_vanguard = true,--t3a
		cortex_catapult = true,--t3c
		corbats = true,
		armada_dreadnought = true,

		--cortrem = true,
		corjugg = true,

		}
	self.rocketers = {
		armada_ambassador = true,
		corvroc = true, -- T2C
-- 		corban = true,T2C
		corhrk = true,
		cormship = true,
		armada_longbow = true,
		armada_possum = true,
		cormh = true,
		}

	self.battles = {
		armada_mace = true,
		corthud = true,
		armada_stout = true,
		corraid = true,
		armada_gunslinger = true,
		cortex_sumo = true,
		armada_bull = true,
		correap = true,
		armada_crocodile = true,--ha
		corsnap = true,--hc
		armada_ellysaw = true,--t1a
		corpship = true,--t1c
		corcrus = true,
		armada_paladin = true,
		armada_titan = true,--t3a



		--corhal = true,





		}
	self.breaks = {
		armada_centurion = true,
		armada_janus = true,
		corlevlr = true,
		armada_fatboy = true,
		corsumo = true,
		corgol = true,
		armada_starlight = true,
		armada_lunkhead = true,--hover
		corsok = true,--hover
		armada_corsair = true,
		corroy = true,



		corblackhy = true,
		armada_epoch = true,
		armada_thor = true, --t3a
		corkorg = true,--t3c

		}
	self.amphibious = {
		armada_pincer = true,
		corparrow = true,
		armada_turtle = true,
		armada_amphibiousbot = true,
		corgarp = true,
		coramph = true,
		armada_marauder = true,
		corshiva = true,

		}

	self.spiders = {
		cortermite = true,
		armada_recluse = true,

		}
	self.paralyzers = {
		cortex_shuriken = true,
		armada_webber = true,
		armada_stiletto = true,

		}
	self.subkillers = {
		armada_serpent = true,
		corssub = true,



		} -- submarine weaponed
	self.bomberairs = {
		cortex_whirlwind = true,
		armada_stormbringer = true,
		armada_tsunami = true, --plat
		cortex_hailstorm = true,
		armada_blizzard = true,
		armada_liche = true,
		corsb = true,--plat
		}

	self.fighterairs = {
		cortex_valiant = true,
		armada_falcon = true,
		corsfig = true, --plat
		armada_cyclone = true, --plat
		cortex_angler = true,
		armada_highwind = true,
		}

	self.tpbombers = {
		cortex_nighthawk = true,
		armada_cormorant = true,


		}

	self.airgun = {
		armada_banshee = true,
		cortex_dragonold = true,
		cortex_dragon = true,
		cortex_wasp = true,
		armada_roughneck = true,
		armada_hornet = true,
		armada_puffin = true, -- but is a torpedo gunship
		armada_sabre = true,
		corseap = true,
		corcut = true,

		}

	self.antiairs = {
		armada_sweeper = true,
		corah = true,
		armada_dragonslayer = true,
		armada_whistler = true,
		corsent = true,
		armada_archangel = true,
		armada_shredder = true,
		cormist = true,
		corcrash = true,
		armada_crossbow = true,
		coraak = true,
		corarch = true,
		armada_skater = true, --aa+scout
		corpt = true, --aa+scout
		}

	self.antinukes = {
		armada_haven = true,
		cortex_oasis = true,
		cormabm = true,
		armada_umbrella = true,
		}

	self.crawlings = {
		armada_tumbleweed = true,
		corroach = true,
		corsktl = true,
		}

	self.cloakables = {
		armada_sharpshooter = true,
		armada_gremlin = true,
		}

	-------IMMOBILE--------
	self._targeting_ = {
		armada_pinpointer = true ,
		armada_navalpinpointer = true ,
		cortarg = true ,
		corfatf = true ,
		}

	self._geo_ = {
		corageo = true ,
		armada_advancedgeothermalpowerplant = true ,
		armada_geothermalpowerplant = true ,
		corgeo = true ,
		corbhmth = true ,
		armada_prude = true ,
		}


	self._nano_ = {
		armada_constructionturret = true ,
		armada_constructionturretplat = true ,
		cornanotc = true ,
		cornanotcplat = true ,

		}

	self._solar_ = {
		corsolar = 'coradvsol' ,
		armada_solarcollector = 'armada_advancedsolarcollector' ,
		}


	self._mex_ = {
		cormex = 'cormoho' ,
		-- 		armada_navalmetalextractor = 'armada_navaladvancedmetalextractor' ,
		-- 		coruwmex = 'coruwmme' ,
		cormexp = true ,
		armada_metalextractor = "armada_advancedmetalextractor" ,
		armada_twilight = 'armada_advancedmetalextractor' ,
		armada_advancedmetalextractor = true ,
		cormoho = true ,
		corexp = 'cormexp' ,
		armada_navaladvancedmetalextractor = true ,
		coruwmme = true ,
		}
	ArmyHST.t2mex = {
		armada_advancedmetalextractor = true,
		cormoho = true,
		armada_navaladvancedmetalextractor = true,
		coruwmme = true,
		}
	-- what mexes upgrade to what
	ArmyHST.mexUpgrade = {
		cormex = "cormoho",
		armada_metalextractor = "armada_advancedmetalextractor",
		armada_twilight = "armada_advancedmetalextractor",
		corexp = "cormoho",
		}

	self._flak_ = {
		armada_navalarbalest = true ,
		armada_arbalest = true ,
		corflak = true ,
		corenaa = true ,
		}

	self._mine_ = {
		armada_lightmine = true ,
		armada_mediummine = true ,
		armada_heavymine = true ,
		armada_heavymine = true ,
		cormine1 = true ,
		cormine2 = true ,
		cormine3 = true ,
		cormine4 = true ,
		corfmine3 = true ,
		}

	self._eyes_ = {
		armada_beholder = true ,
		coreyes = true ,
		}

	-- 	self._afus_ = {
	-- 		armada_advancedfusionreactor = true ,
	-- 		corafus = true ,
	-- 	}


	self._fus_ = {
		armada_fusionreactor = 'armada_advancedfusionreactor' ,--will become afus in buildersbst:specialfilter()
		armada_navalfusionreactor = 'armada_navalfusionreactor' , --no advuwfus
		corfus = 'corafus' ,--will become afus in buildersbst:specialfilter()
		coruwfus = 'coruwfus' ,--no advuwfus
		-- 		armada_cloakablefusionreactor = true , --clackable, better to think about it later

		-- 		armada_advancedfusionreactor = true ,
		-- 		corafus = true ,
		--armada_decoyfusionreactor = true, --fake fus
		}

	self._silo_ = {
		armada_armageddon = true ,
		corsilo = true ,
		}

	self._wind_ ={
		armada_windturbine = true ,
		corwin = true ,
		}

	self._tide_ = {
		cortide = true ,
		armada_tidalgenerator = true ,
		}

	self._plat_ = {
		corplat = true ,
		armada_seaplaneplatform = true ,
		}

	self._radar_ = {
		armada_radartower = true ,
		armada_advancedradartower = true ,
		corrad = true ,
		corarad = true ,
		corfrad = true ,
		armada_navalradar = true ,
		}

	self._jam_ = {
		armada_sneakypete = true ,
		corjamt = true ,
		armada_veil = true ,
		corshroud = true ,
		}

	self._sonar_ = {
		armada_sonarstation = true ,
		corsonar = true ,
		armada_advancedsonarstation = true,
		corason = true,
		}

	self._shield_ = {
		armada_keeper = true ,
		corgate = true ,
		}

	self._juno_ = {
		corjuno = true ,
		armada_juno = true ,
		}

	self._popup1_ = {
		armada_dragonsclaw = true,
		cormaw = true,
		}

	self._llt_ = {
		armada_sentry = true,
		corllt = true,
		}

	self._specialt_ = {
		armada_beamer = true,
		corhllt = true,
		}

	self._heavyt_ = {
		armada_overwatch = true,
		corhlt = true,
		armada_manta = true,
		corfhlt = true,
		}

	self._lol_ = {
		corbuzz = true ,
		armada_ragnarok = true ,
		}

	self._laser2_ = {
		cordoom = true ,
		armada_pulsar = true ,
		}

	self._coast1_ = {
		corpun = true ,
		armada_gauntlet = true ,
		}

	self._coast2_ = {
		cortoast = true ,
		armada_rattlesnake = true ,
		}

	self._popup2_ = {
		armada_pitbull = true ,
		corvipe = true ,
		}

	self._plasma_ = {
		armada_basilica = true ,
		corint = true ,
		}

	self._torpedo1_ = {
		cortl = true ,
		armada_harpoon = true ,
		armada_harpoon2 = true ,
		corptl = true ,
		}

	self._torpedo2_ = {
		coratl = true ,
		armada_moray = true ,
		}

	self._torpedoground_ = {
		armada_anemone = true ,
		cordl = true ,
		}

	self._aa1_ = {
		armada_nettle = true ,
		corrl = true ,
		armada_navalnettle = true ,
		corfrt = true ,
		}

	self._aabomb_ = {
		corerad = true ,
		armada_ferret = true ,
		}

	self._aaheavy_ = {
		cormadsam = true ,
		armada_chainsaw = true ,
		}
	self._aa2_ = {
		corscreamer = true ,
		armada_mercury = true ,
		}

	self._intrusion_ = {
		corsd = true ,
		armada_tracer = true ,
		}

	self._antinuke_ = {
		armada_citadel = true ,
		corfmd = true ,
		}

	self._airPlat_ = {
		armasp = true ,
		armada_airrepairpad = true ,
		corasp = true ,
		corfasp = true ,
		}

	self._convs_ = {
		armada_advancedenergyconverter = true ,
		armada_navalenergyconverter = true ,
		armada_energyconverter = true ,
		armada_navaladvancedenergyconverter = true ,
		cormmkr = true ,
		corfmkr = true ,
		cormakr = true ,
		}

	self._estor_ = {
		armada_energystorage = true ,
		armada_navalenergystorage = true ,
		armada_hardenedenergystorage = true ,
		corestor = true ,
		coruwes = true ,
		coruwadves = true ,
		}

	self._mstor_ = {
		cormstor = true ,
		armada_metalstorage = true ,
		armada_navalmetalstorage = true ,
		coruwms = true ,
		coruwadvms = true ,
		armada_hardenedmetalstorage = true ,
		coruwmmm = true ,
		}

	self._tactical_ = {
		armada_paralyzer = true ,
		cortron = true ,
		}

	self._wall_ = {
		corfdrag = true ,
		armada_dragonsteeth = true ,
		armada_fortificationwall = true ,
		cordrag = true ,
		armada_sharksteeth = true ,
		}

	self:GetUnitTable()
	self:GetFeatureTable()

end


ArmyHST.techPenalty = {
	armada_amphibiouscomplex = -1,
	coramsub = -1,
	armada_navalhovercraftplatform = -1,
	corfhp = -1,
	armada_hovercraftplatform = -1,
	corhp = -1,
	}

ArmyHST.factoryMobilities = {
	corap = {"air"},
	armada_aircraftplant = {"air"},
	corlab = {"bot"},
	armada_botlab = {"bot"},
	corvp = {"veh", "amp"},
	armada_vehicleplant = {"veh", "amp"},
	coralab = {"bot"},
	coravp = {"veh", "amp"},
	corhp = {"hov"},
	armada_hovercraftplatform = {"hov"},
	corfhp = {"hov"},
	armada_navalhovercraftplatform = {"hov"},
	armada_advancedbotlab = {"bot"},
	armada_advancedvehicleplant = {"veh", "amp"},
	coraap = {"air"},
	armada_advancedaircraftplant = {"air"},
	corplat = {"air"},
	armada_seaplaneplatform = {"air"},
	corsy = {"shp", "sub"},
	armada_shipyard = {"shp", "sub"},
	corasy = {"shp", "sub"},
	armada_advancedshipyard = {"shp", "sub"},
	coramsub = {"amp","sub"},
	armada_amphibiouscomplex = {"amp","sub"},
	corgant = {"bot", "amp"},
	armada_experimentalgantry = {"bot", "amp"},
	corgantuw = {"amp","hov"},
	armada_experimentalgantryuw = {"amp","hov"},
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
	armada_aircraftplant = 0,
	corlab = 2,
	armada_botlab = 2,
	corvp = 1,
	armada_vehicleplant = 1,
	coralab = 3,
	coravp = 1,
	corhp = 2,
	armada_hovercraftplatform = 2,
	corfhp = 2,
	armada_navalhovercraftplatform = 2,
	armada_advancedbotlab = 2,
	armada_advancedvehicleplant = 2,
	coraap = 0,
	armada_advancedaircraftplant = 0,
	corplat = 0,
	armada_seaplaneplatform = 0,
	corsy = 4,
	armada_shipyard = 4,
	corasy = 4,
	armada_advancedshipyard = 4,
	coramsub = 4,
	armada_amphibiouscomplex = 4,
	corgant = 1,
	armada_experimentalgantry = 1,
	corgantuw = 1,
	armada_experimentalgantryuw = 1,
	}

-- ArmyHST.littlePlasmaList = {
-- 	corpun = 1,
-- 	armada_gauntlet = 1,
-- 	cortoast = 1,
-- 	armada_rattlesnake = 1,
-- 	corbhmth = 1,
-- }

-- what mexes upgrade to what
--[[ArmyHST.mexUpgrade = {
	cormex = "cormoho",
	armada_metalextractor = "armada_advancedmetalextractor",
	coruwmex = "coruwmme",--ex coruwmex caution this will be changed --TODO
	armada_navalmetalextractor = "armada_navaladvancedmetalextractor",--ex armada_navalmetalextractor
	armada_twilight = "armada_advancedmetalextractor",
	corexp = "cormexp",

	}
]]

-- factories that can build advanced construction units (i.e. moho mines)
ArmyHST.advFactories = {
	coravp = 1,
	coralab = 1,
	corasy = 1,
	coraap = 1,
	corplat = 1,
	armada_advancedvehicleplant = 1,
	armada_advancedbotlab = 1,
	armada_advancedshipyard = 1,
	armada_advancedaircraftplant = 1,
	armada_seaplaneplatform = 1,
	}

-- experimental factories
ArmyHST.expFactories = {
	corgant = 1,
	armada_experimentalgantry = 1,
	corgantuw = 1,
	armada_experimentalgantryuw = 1,
	}

-- leads to experimental
ArmyHST.leadsToExpFactories = {
	corlab = 1,
	armada_botlab = 1,
	coralab = 1,
	armada_advancedbotlab = 1,
	corsy = 1,
	armada_shipyard = 1,
	corasy = 1,
	armada_advancedshipyard = 1,
	}

ArmyHST.commanderList = {
	armada_commander = 1,
	cortex_commander = 1,
	}

ArmyHST.groundFacList = {
	corvp = 1,
	armada_vehicleplant = 1,
	coravp = 1,
	armada_advancedvehicleplant = 1,
	corlab = 1,
	armada_botlab = 1,
	coralab = 1,
	armada_advancedbotlab = 1,
	corhp = 1,
	armada_hovercraftplatform = 1,
	corfhp = 1,
	armada_navalhovercraftplatform = 1,
	coramsub = 1,
	armada_amphibiouscomplex = 1,
	corgant = 1,
	armada_experimentalgantry = 1,
	corfast = 1,
	armada_consul = 1,
	armada_butler = 1,
	}

-- if any of these is found among enemy units, AA units and fighters will be built
ArmyHST.airFacList = {
	corap = 1,
	armada_aircraftplant = 1,
	coraap = 1,
	armada_advancedaircraftplant = 1,
	corplat = 1,
	armada_seaplaneplatform = 1,
	}

-- if any of these is found among enemy units, torpedo launchers and sonar will be built
ArmyHST.subFacList = {
	corsy = 1,
	armada_shipyard = 1,
	corasy = 1,
	armada_advancedshipyard = 1,
	coramsub = 1,
	armada_amphibiouscomplex = 1,
	}

-- if any of these is found among enemy units, plasma shields will be built
ArmyHST.bigPlasmaList = {
	corint = 1,
	armada_basilica = 1,
	}

-- if any of these is found among enemy units, antinukes will be built
-- also used to assign nuke behaviour to own units
-- values are how many frames it takes to stockpile
ArmyHST.nukeList = {
	armada_armageddon = 3600,
	corsilo = 5400,
	armada_paralyzer = 2700,
	cortron = 2250,
	}

ArmyHST.cleanable = {
	armada_solarcollector= 'ground',
	corsolar= 'ground',
	armada_advancedsolarcollector = 'ground',
	coradvsol = 'ground',
	armada_tidalgenerator = 'floating',
	cortite = 'floating',
	armada_navalenergyconverter = 'floating',
	corfmkr = 'floating',
	cormakr = 'ground',
	armada_energyconverter = 'ground',
	corwin = 'ground',
	armada_windturbine = 'ground',
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
ArmyHST.UWMetalSpotCheckUnit = "coruwmex"

-- for non-lua only; tests build orders of these units to determine mobility there
-- multiple units for one mtype function as OR
ArmyHST.mobUnitNames = {
	veh = {"corcv", "armada_sentry"},
	bot = {"corck", "armada_beholder"},
	amp = {"cormuskrat"},
	hov = {"corsh", "armada_sharksteeth"},
	shp = {"corcs"},
	sub = {"coracsub"},
	}

-- tests move orders of these units to determine mobility there
ArmyHST.mobUnitExampleName = {
	veh = "armada_constructionvehicle",
	bot = "armada_constructionbot",
	amp = "armada_beaver",
	hov = "armada_constructionhovercraft",
	shp = "armada_constructionship",
	sub = "armada_advancedconstructionsub"
}

-- side names
ArmyHST.CORESideName = "cortex"
ArmyHST.ARMSideName = "armada"

-- how much metal to assume features with these strings in their names have
ArmyHST.baseFeatureMetal = { rock = 30, heap = 80, wreck = 150 }


local unitsLevels = {}
local armTechLv ={}
local corTechLv ={}
corTechLv.cortex_commander = false
armTechLv.armada_commander = false
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
	local paralyzer = nil
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
	local builtBy = GetBuiltBy()
	local unitTable = {}
	local wrecks = {}
	for unitDefID,unitDef in pairs(UnitDefs) do
		local side = GetUnitSide(unitDef.name)
		--if unitsLevels[unitDef.name] then



		-- --Spring.Echo(unitDef.name, "build slope", unitDef.maxHeightDif)
		-- if unitDef.moveDef.maxSlope then
		-- --Spring.Echo(unitDef.name, "move slope", unitDef.moveDef.maxSlope)
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
		utable.sightDistance = unitDef["sightDistance"]
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
		if longRange then
			utable.threat = utable.metalCost
		end
		if self.antinukes[unitName] or self.nukeList[unitName] or self.bigPlasmaList[unitName] or self._shield_[unitName] or self._juno_ then
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
				for ii,vv in pairs(defWepon1.onlyTargets) do
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
