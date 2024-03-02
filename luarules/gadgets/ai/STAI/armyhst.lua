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
		cortex_constructionhovercraft = true,
		armada_advancedconstructionsub = true,
		armada_constructionaircraft = true,
		cortex_constructionseaplane = true, --plat
		armada_constructionseaplane = true, --plat
		armada_constructionvehicle = true,
		cortex_advancedconstructionvehicle = true,
		cortex_advancedconstructionaircraft = true,
		armada_advancedconstructionvehicle = true,
		armada_advancedconstructionbot = true,
		cortex_advancedconstructionbot = true,
		cortex_constructionvehicle = true,
		armada_advancedconstructionaircraft = true,
		cortex_constructionship = true,
		armada_constructionship = true,
		cortex_constructionbot = true,
		armada_constructionbot = true,



		}
	self.engineers = {
		armada_voyager = true,
		armada_butler = true,
		armada_consul = true,
		cortex_twitcher = true,
		cortex_pathfinder = true,

		}
	self.wartechs = {
		armada_decoycommander = true,
		cortex_decoycommander = true,
		cortex_commando = true,


		} --decoy etc
	self.rezs = {
		armada_lazarus = true,
		cortex_graverobber = true,
		armada_grimreaper = true,
		cortex_deathcavalry = true,

		}
	self.amptechs = {
		armada_beaver = true,
		cortex_muskrat = true,


		} --amphibious builders
	self.miners = {
		armada_groundhog = true,
		cortex_trapper = true,
		}

	self.jammers = {
		armada_bermuda = true,
		cortex_obscurer = true,
		armada_radarjammerbot = true,
		armada_umbra = true,
		cortex_phantasm = true,
		cortex_deceiver = true,


		}
	self.radars = {
		cortex_finch = true,--is a scout but is better used as radar cause no weapon
		armada_blink = true,--is a scout but is better used as radar cause no weapon
		cortex_omen = true,
		armada_compass = true,
		armada_prophet = true,
		cortex_augur = true,
		cortex_condor = true,
		armada_oracle = true,
		armada_horizon = true,
		cortex_watcher = true,


		}
	self.spys = {
		armada_ghost = true,
		cortex_spectre = true,
		}
	self.transports = {
		cortex_hercules = true,
		armada_stork = true,
		armada_bearer = true,
		cortex_caravan = true,
		cortex_intruder = true,
		armada_abductor = true,
		cortex_coffin = true,
		armada_convoy = true,
		cortex_skyhook = true,

		}

	self.scouts = {
		armada_rover = true,
		cortex_rascal = true,
		armada_tick = true,
		armada_sprinter = true,
		armada_dolphin = true,
		cortex_supporter = true,



		}
	self.raiders = {
		armada_blitz = true,
		cortex_incisor = true,
		cortex_grunt = true,
		armada_pawn = true,
		armada_jaguar = true,
		cortex_alligator = true,
		cortex_fiend = true,
		armada_welder = true,
		armada_seeker = true,
		cortex_goon = true,
		cortex_orca = true,
		armada_eel = true,
		armada_barracuda = true,
		cortex_predator = true,
		armada_razorback = true,
		cortex_karganeth = true,

		}
	self.artillerys = {
		armada_rocketeer = true,
		cortex_aggravator = true,
		armada_shellshocker = true,
		cortex_wolverine = true,
		armada_hound = true,
		cortex_sheldon = true,
		armada_mauser = true,
		cortex_quaker = true,
		armada_vanguard = true,--t3a
		cortex_catapult = true,--t3c
		cortex_despot = true,
		armada_dreadnought = true,

		--cortex_tremor = true,
		cortex_behemoth = true,

		}
	self.rocketers = {
		armada_ambassador = true,
		cortex_negotiator = true, -- T2C
-- 		cortex_banisher = true,T2C
		cortex_arbiter = true,
		cortex_messenger = true,
		armada_longbow = true,
		armada_possum = true,
		cortex_mangonel = true,
		}

	self.battles = {
		armada_mace = true,
		cortex_thug = true,
		armada_stout = true,
		cortex_brute = true,
		armada_gunslinger = true,
		cortex_sumo = true,
		armada_bull = true,
		cortex_tiger = true,
		armada_crocodile = true,--ha
		cortex_cayman = true,--hc
		armada_ellysaw = true,--t1a
		cortex_riptide = true,--t1c
		cortex_buccaneer = true,
		armada_paladin = true,
		armada_titan = true,--t3a



		--cortex_halberd = true,





		}
	self.breaks = {
		armada_centurion = true,
		armada_janus = true,
		cortex_pounder = true,
		armada_fatboy = true,
		cortex_mammoth = true,
		cortex_tzar = true,
		armada_starlight = true,
		armada_lunkhead = true,--hover
		cortex_cataphract = true,--hover
		armada_corsair = true,
		cortex_oppressor = true,



		cortex_blackhydra = true,
		armada_epoch = true,
		armada_thor = true, --t3a
		cortex_juggernaut = true,--t3c

		}
	self.amphibious = {
		armada_pincer = true,
		cortex_poisonarrow = true,
		armada_turtle = true,
		armada_amphibiousbot = true,
		cortex_garpike = true,
		cortex_duck = true,
		armada_marauder = true,
		cortex_shiva = true,

		}

	self.spiders = {
		cortex_termite = true,
		armada_recluse = true,

		}
	self.paralyzers = {
		cortex_shuriken = true,
		armada_webber = true,
		armada_stiletto = true,

		}
	self.subkillers = {
		armada_serpent = true,
		cortex_kraken = true,



		} -- submarine weaponed
	self.bomberairs = {
		cortex_whirlwind = true,
		armada_stormbringer = true,
		armada_tsunami = true, --plat
		cortex_hailstorm = true,
		armada_blizzard = true,
		armada_liche = true,
		cortex_dambuster = true,--plat
		}

	self.fighterairs = {
		cortex_valiant = true,
		armada_falcon = true,
		cortex_bat = true, --plat
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
		cortex_monsoon = true,
		cortex_cutlass = true,

		}

	self.antiairs = {
		armada_sweeper = true,
		cortex_birdeater = true,
		armada_dragonslayer = true,
		armada_whistler = true,
		cortex_fury = true,
		armada_archangel = true,
		armada_shredder = true,
		cortex_lasher = true,
		cortex_trasher = true,
		armada_crossbow = true,
		cortex_manticore = true,
		cortex_arrowstorm = true,
		armada_skater = true, --aa+scout
		cortex_herring = true, --aa+scout
		}

	self.antinukes = {
		armada_haven = true,
		cortex_oasis = true,
		cortex_saviour = true,
		armada_umbrella = true,
		}

	self.crawlings = {
		armada_tumbleweed = true,
		cortex_bedbug = true,
		cortex_skuttle = true,
		}

	self.cloakables = {
		armada_sharpshooter = true,
		armada_gremlin = true,
		}

	-------IMMOBILE--------
	self._targeting_ = {
		armada_pinpointer = true ,
		armada_navalpinpointer = true ,
		cortex_pinpointer = true ,
		cortex_navalpinpointer = true ,
		}

	self._geo_ = {
		cortex_advancedunderwatergeothermalpowerplant = true ,
		armada_advancedunderwatergeothermalpowerplant = true ,
		cortex_advancedgeothermalpowerplant = true ,
		armada_advancedgeothermalpowerplant = true ,
		cortex_underwatergeothermalpowerplant = true ,
		armada_underwatergeothermalpowerplant = true ,
		armada_geothermalpowerplant = true ,
		cortex_geothermalpowerplant = true ,
		cortex_cerberus = true ,
		armada_prude = true ,
		}


	self._nano_ = {
		armada_constructionturret = true ,
		armada_navalconstructionturret = true ,
		cortex_constructionturret = true ,
		cortex_navalconstructionturret = true ,

		}

	self._solar_ = {
		cortex_solarcollector = 'cortex_advancedsolarcollector' ,
		armada_solarcollector = 'armada_advancedsolarcollector' ,
		}


	self._mex_ = {
		cortex_metalextractor = 'cortex_advancedmetalextractor' ,
		-- 		armada_navalmetalextractor = 'armada_navaladvancedmetalextractor' ,
		-- 		cortex_navalmetalextractor = 'cortex_navaladvancedmetalextractor' ,
		cortex_advancedexploiter = true ,
		armada_metalextractor = "armada_advancedmetalextractor" ,
		armada_twilight = 'armada_advancedmetalextractor' ,
		armada_advancedmetalextractor = true ,
		cortex_advancedmetalextractor = true ,
		cortex_exploiter = 'cortex_advancedexploiter' ,
		armada_navaladvancedmetalextractor = true ,
		cortex_navaladvancedmetalextractor = true ,
		}
	ArmyHST.t2mex = {
		armada_advancedmetalextractor = true,
		cortex_advancedmetalextractor = true,
		armada_navaladvancedmetalextractor = true,
		cortex_navaladvancedmetalextractor = true,
		}
	-- what mexes upgrade to what
	ArmyHST.mexUpgrade = {
		cortex_metalextractor = "cortex_advancedmetalextractor",
		armada_metalextractor = "armada_advancedmetalextractor",
		armada_twilight = "armada_advancedmetalextractor",
		cortex_exploiter = "cortex_advancedmetalextractor",
		}

	self._flak_ = {
		armada_navalarbalest = true ,
		armada_arbalest = true ,
		cortex_birdshot = true ,
		cortex_navalbirdshot = true ,
		}

	self._mine_ = {
		armada_lightmine = true ,
		armada_mediummine = true ,
		armada_heavymine = true ,
		armada_heavymine = true ,
		cortex_lightmine = true ,
		cortex_mediummine = true ,
		cortex_heavymine = true ,
		cortex_mediumminecommando = true ,
		cortex_navalheavymine = true ,
		}

	self._eyes_ = {
		armada_beholder = true ,
		cortex_beholder = true ,
		}

	-- 	self._afus_ = {
	-- 		armada_advancedfusionreactor = true ,
	-- 		cortex_advancedfusionreactor = true ,
	-- 	}


	self._fus_ = {
		armada_fusionreactor = 'armada_advancedfusionreactor' ,--will become afus in buildersbst:specialfilter()
		armada_navalfusionreactor = 'armada_navalfusionreactor' , --no advuwfus
		cortex_fusionreactor = 'cortex_advancedfusionreactor' ,--will become afus in buildersbst:specialfilter()
		cortex_navalfusionreactor = 'cortex_navalfusionreactor' ,--no advuwfus
		-- 		armada_cloakablefusionreactor = true , --clackable, better to think about it later

		-- 		armada_advancedfusionreactor = true ,
		-- 		cortex_advancedfusionreactor = true ,
		--armada_decoyfusionreactor = true, --fake fus
		}

	self._silo_ = {
		armada_armageddon = true ,
		cortex_apocalypse = true ,
		}

	self._wind_ ={
		armada_windturbine = true ,
		cortex_windturbine = true ,
		}

	self._tide_ = {
		cortex_tidalgenerator = true ,
		armada_tidalgenerator = true ,
		}

	self._plat_ = {
		cortex_seaplaneplatform = true ,
		armada_seaplaneplatform = true ,
		}

	self._radar_ = {
		armada_radartower = true ,
		armada_advancedradartower = true ,
		cortex_radartower = true ,
		cortex_advancedradartower = true ,
		cortex_radarsonartower = true ,
		armada_navalradarsonar = true ,
		}

	self._jam_ = {
		armada_sneakypete = true ,
		cortex_castro = true ,
		armada_veil = true ,
		cortex_shroud = true ,
		}

	self._sonar_ = {
		armada_sonarstation = true ,
		cortex_sonarstation = true ,
		armada_advancedsonarstation = true,
		cortex_advancedsonarstation = true,
		}

	self._shield_ = {
		armada_keeper = true ,
		cortex_overseer = true ,
		}

	self._juno_ = {
		cortex_juno = true ,
		armada_juno = true ,
		}

	self._popup1_ = {
		armada_dragonsclaw = true,
		cortex_dragonsmaw = true,
		}

	self._llt_ = {
		armada_sentry = true,
		cortex_guard = true,
		}

	self._specialt_ = {
		armada_beamer = true,
		cortex_twinguard = true,
		}

	self._heavyt_ = {
		armada_overwatch = true,
		cortex_warden = true,
		armada_manta = true,
		cortex_coral = true,
		}

	self._lol_ = {
		cortex_calamity = true ,
		armada_ragnarok = true ,
		}

	self._laser2_ = {
		cortex_bulwark = true ,
		armada_pulsar = true ,
		}

	self._coast1_ = {
		cortex_agitator = true ,
		armada_gauntlet = true ,
		}

	self._coast2_ = {
		cortex_persecutor = true ,
		armada_rattlesnake = true ,
		}

	self._popup2_ = {
		armada_pitbull = true ,
		cortex_scorpion = true ,
		}

	self._plasma_ = {
		armada_basilica = true ,
		cortex_basilisk = true ,
		}

	self._torpedo1_ = {
		cortex_urchin = true ,
		armada_harpoon = true ,
		armada_harpoon2 = true ,
		cortex_oldurchin = true ,
		}

	self._torpedo2_ = {
		cortex_lamprey = true ,
		armada_moray = true ,
		}

	self._torpedoground_ = {
		armada_anemone = true ,
		cortex_jellyfish = true ,
		}

	self._aa1_ = {
		armada_nettle = true ,
		cortex_thistle = true ,
		armada_navalnettle = true ,
		cortex_slingshot = true ,
		}

	self._aabomb_ = {
		cortex_eradicator = true ,
		armada_ferret = true ,
		}

	self._aaheavy_ = {
		cortex_sam = true ,
		armada_chainsaw = true ,
		}
	self._aa2_ = {
		cortex_screamer = true ,
		armada_mercury = true ,
		}

	self._intrusion_ = {
		cortex_nemesis = true ,
		armada_tracer = true ,
		}

	self._antinuke_ = {
		armada_citadel = true ,
		cortex_prevailer = true ,
		}

	self._airPlat_ = {
		armada_airrepairpad = true ,
		armada_floatingairrepairpad = true ,
		cortex_airrepairpad = true ,
		cortex_floatingairrepairpad = true ,
		}

	self._convs_ = {
		armada_advancedenergyconverter = true ,
		armada_navalenergyconverter = true ,
		armada_energyconverter = true ,
		armada_navaladvancedenergyconverter = true ,
		cortex_advancedenergyconverter = true ,
		cortex_navalenergyconverter = true ,
		cortex_energyconverter = true ,
		}

	self._estor_ = {
		armada_energystorage = true ,
		armada_navalenergystorage = true ,
		armada_hardenedenergystorage = true ,
		cortex_energystorage = true ,
		cortex_navalenergystorage = true ,
		cortex_hardenedenergystorage = true ,
		}

	self._mstor_ = {
		cortex_metalstorage = true ,
		armada_metalstorage = true ,
		armada_navalmetalstorage = true ,
		cortex_navalmetalstorage = true ,
		cortex_hardenedmetalstorage = true ,
		armada_hardenedmetalstorage = true ,
		cortex_navaladvancedenergyconverter = true ,
		}

	self._tactical_ = {
		armada_paralyzer = true ,
		cortex_catalyst = true ,
		}

	self._wall_ = {
		cortex_sharksteeth = true ,
		armada_dragonsteeth = true ,
		armada_fortificationwall = true ,
		cortex_dragonsteeth = true ,
		armada_sharksteeth = true ,
		}

	self:GetUnitTable()
	self:GetFeatureTable()

end


ArmyHST.techPenalty = {
	armada_amphibiouscomplex = -1,
	cortex_amphibiouscomplex = -1,
	armada_navalhovercraftplatform = -1,
	cortex_navalhovercraftplatform = -1,
	armada_hovercraftplatform = -1,
	cortex_hovercraftplatform = -1,
	}

ArmyHST.factoryMobilities = {
	cortex_aircraftplant = {"air"},
	armada_aircraftplant = {"air"},
	cortex_botlab = {"bot"},
	armada_botlab = {"bot"},
	cortex_vehicleplant = {"veh", "amp"},
	armada_vehicleplant = {"veh", "amp"},
	cortex_advancedbotlab = {"bot"},
	cortex_advancedvehicleplant = {"veh", "amp"},
	cortex_hovercraftplatform = {"hov"},
	armada_hovercraftplatform = {"hov"},
	cortex_navalhovercraftplatform = {"hov"},
	armada_navalhovercraftplatform = {"hov"},
	armada_advancedbotlab = {"bot"},
	armada_advancedvehicleplant = {"veh", "amp"},
	cortex_advancedaircraftplant = {"air"},
	armada_advancedaircraftplant = {"air"},
	cortex_seaplaneplatform = {"air"},
	armada_seaplaneplatform = {"air"},
	cortex_shipyard = {"shp", "sub"},
	armada_shipyard = {"shp", "sub"},
	cortex_advancedshipyard = {"shp", "sub"},
	armada_advancedshipyard = {"shp", "sub"},
	cortex_amphibiouscomplex = {"amp","sub"},
	armada_amphibiouscomplex = {"amp","sub"},
	cortex_experimentalgantry = {"bot", "amp"},
	armada_experimentalgantry = {"bot", "amp"},
	cortex_underwaterexperimentalgantry = {"amp","hov"},
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
	cortex_aircraftplant = 0,
	armada_aircraftplant = 0,
	cortex_botlab = 2,
	armada_botlab = 2,
	cortex_vehicleplant = 1,
	armada_vehicleplant = 1,
	cortex_advancedbotlab = 3,
	cortex_advancedvehicleplant = 1,
	cortex_hovercraftplatform = 2,
	armada_hovercraftplatform = 2,
	cortex_navalhovercraftplatform = 2,
	armada_navalhovercraftplatform = 2,
	armada_advancedbotlab = 2,
	armada_advancedvehicleplant = 2,
	cortex_advancedaircraftplant = 0,
	armada_advancedaircraftplant = 0,
	cortex_seaplaneplatform = 0,
	armada_seaplaneplatform = 0,
	cortex_shipyard = 4,
	armada_shipyard = 4,
	cortex_advancedshipyard = 4,
	armada_advancedshipyard = 4,
	cortex_amphibiouscomplex = 4,
	armada_amphibiouscomplex = 4,
	cortex_experimentalgantry = 1,
	armada_experimentalgantry = 1,
	cortex_underwaterexperimentalgantry = 1,
	armada_experimentalgantryuw = 1,
	}

-- ArmyHST.littlePlasmaList = {
-- 	cortex_agitator = 1,
-- 	armada_gauntlet = 1,
-- 	cortex_persecutor = 1,
-- 	armada_rattlesnake = 1,
-- 	cortex_cerberus = 1,
-- }

-- what mexes upgrade to what
--[[ArmyHST.mexUpgrade = {
	cortex_metalextractor = "cortex_advancedmetalextractor",
	armada_metalextractor = "armada_advancedmetalextractor",
	cortex_navalmetalextractor = "cortex_navaladvancedmetalextractor",--ex cortex_navalmetalextractor caution this will be changed --TODO
	armada_navalmetalextractor = "armada_navaladvancedmetalextractor",--ex armada_navalmetalextractor
	armada_twilight = "armada_advancedmetalextractor",
	cortex_exploiter = "cortex_advancedexploiter",

	}
]]

-- factories that can build advanced construction units (i.e. moho mines)
ArmyHST.advFactories = {
	cortex_advancedvehicleplant = 1,
	cortex_advancedbotlab = 1,
	cortex_advancedshipyard = 1,
	cortex_advancedaircraftplant = 1,
	cortex_seaplaneplatform = 1,
	armada_advancedvehicleplant = 1,
	armada_advancedbotlab = 1,
	armada_advancedshipyard = 1,
	armada_advancedaircraftplant = 1,
	armada_seaplaneplatform = 1,
	}

-- experimental factories
ArmyHST.expFactories = {
	cortex_experimentalgantry = 1,
	armada_experimentalgantry = 1,
	cortex_underwaterexperimentalgantry = 1,
	armada_experimentalgantryuw = 1,
	}

-- leads to experimental
ArmyHST.leadsToExpFactories = {
	cortex_botlab = 1,
	armada_botlab = 1,
	cortex_advancedbotlab = 1,
	armada_advancedbotlab = 1,
	cortex_shipyard = 1,
	armada_shipyard = 1,
	cortex_advancedshipyard = 1,
	armada_advancedshipyard = 1,
	}

ArmyHST.commanderList = {
	armada_commander = 1,
	cortex_commander = 1,
	}

ArmyHST.groundFacList = {
	cortex_vehicleplant = 1,
	armada_vehicleplant = 1,
	cortex_advancedvehicleplant = 1,
	armada_advancedvehicleplant = 1,
	cortex_botlab = 1,
	armada_botlab = 1,
	cortex_advancedbotlab = 1,
	armada_advancedbotlab = 1,
	cortex_hovercraftplatform = 1,
	armada_hovercraftplatform = 1,
	cortex_navalhovercraftplatform = 1,
	armada_navalhovercraftplatform = 1,
	cortex_amphibiouscomplex = 1,
	armada_amphibiouscomplex = 1,
	cortex_experimentalgantry = 1,
	armada_experimentalgantry = 1,
	cortex_twitcher = 1,
	armada_consul = 1,
	armada_butler = 1,
	}

-- if any of these is found among enemy units, AA units and fighters will be built
ArmyHST.airFacList = {
	cortex_aircraftplant = 1,
	armada_aircraftplant = 1,
	cortex_advancedaircraftplant = 1,
	armada_advancedaircraftplant = 1,
	cortex_seaplaneplatform = 1,
	armada_seaplaneplatform = 1,
	}

-- if any of these is found among enemy units, torpedo launchers and sonar will be built
ArmyHST.subFacList = {
	cortex_shipyard = 1,
	armada_shipyard = 1,
	cortex_advancedshipyard = 1,
	armada_advancedshipyard = 1,
	cortex_amphibiouscomplex = 1,
	armada_amphibiouscomplex = 1,
	}

-- if any of these is found among enemy units, plasma shields will be built
ArmyHST.bigPlasmaList = {
	cortex_basilisk = 1,
	armada_basilica = 1,
	}

-- if any of these is found among enemy units, antinukes will be built
-- also used to assign nuke behaviour to own units
-- values are how many frames it takes to stockpile
ArmyHST.nukeList = {
	armada_armageddon = 3600,
	cortex_apocalypse = 5400,
	armada_paralyzer = 2700,
	cortex_catalyst = 2250,
	}

ArmyHST.cleanable = {
	armada_solarcollector= 'ground',
	cortex_solarcollector= 'ground',
	armada_advancedsolarcollector = 'ground',
	cortex_advancedsolarcollector = 'ground',
	armada_tidalgenerator = 'floating',
	cortite = 'floating',
	armada_navalenergyconverter = 'floating',
	cortex_navalenergyconverter = 'floating',
	cortex_energyconverter = 'ground',
	armada_energyconverter = 'ground',
	cortex_windturbine = 'ground',
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
ArmyHST.UWMetalSpotCheckUnit = "cortex_navalmetalextractor"

-- for non-lua only; tests build orders of these units to determine mobility there
-- multiple units for one mtype function as OR
ArmyHST.mobUnitNames = {
	veh = {"cortex_constructionvehicle", "armada_sentry"},
	bot = {"cortex_constructionbot", "armada_beholder"},
	amp = {"cortex_muskrat"},
	hov = {"cortex_goon", "armada_sharksteeth"},
	shp = {"cortex_constructionship"},
	sub = {"cortex_advancedconstructionsub"},
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
