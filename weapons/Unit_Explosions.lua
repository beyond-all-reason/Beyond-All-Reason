local impulsefactor = 0.123

local unitDeaths = {

	blank = {
		areaofeffect = 0,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		explosiongenerator = "custom:blank",
		damage = {
			default = 0,
		},
	},

	empblast = {    -- for armamex
		areaofeffect = 400,
		commandfire = 1,
		craterboost = 0,
		cratermult = 0,
		edgeeffectiveness = 0.75,
		explosiongenerator = "custom:genericshellexplosion-huge-lightning",
		impulsefactor = 0,
		name = "EMPboom",
		paralyzer = 1,
		paralyzetime = 15,
		soundhit = "EMGPULS1",
		soundstart = "bombrel",
		damage = {
			default = 4450,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	pyro = {
		areaofeffect = 64,
		camerashake = 64,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-large-fire",
		damage = {
			default = 56,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	pyroselfd = {
		areaofeffect = 200,
		camerashake = 200,
		edgeeffectiveness = 0.5,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-huge-fire",
		damage = {
			default = 1110,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	flamethrower = {
		areaofeffect = 48,
		camerashake = 48,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-medium-fire",
		damage = {
			default = 39,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	flamethrowerSelfd = {
		areaofeffect = 140,
		camerashake = 140,
		edgeeffectiveness = 0.5,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-large-fire",
		damage = {
			default = 720,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	tidal = {
		areaofeffect = 180,
		craterboost = 0,
		cratermult = 0,
		explosiongenerator = "custom:genericbuildingexplosion-medium",
		impulsefactor = 0.12300000339746,
		name = "TidalDeath",
		soundhit = "xplosml3",
		soundstart = "largegun",
		damage = {
			default = 167,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	tidalSelfd = {
		areaofeffect = 240,
		craterboost = 0,
		cratermult = 0,
		explosiongenerator = "custom:genericbuildingexplosion-medium",
		impulsefactor = 0.12300000339746,
		name = "TidalDeath",
		soundhit = "xplosml3",
		soundstart = "largegun",
		damage = {
			default = 335,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	nanoboom = {
		areaofeffect = 128,
		camerashake = 128,
		edgeeffectiveness = 0.75,
		impulsefactor = impulsefactor,
		soundhit = "xplosml3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-nano",
		damage = {
			default = 11,
			nanos = 530,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	nanoselfd = {
		areaofeffect = 64,
		camerashake = 64,
		edgeeffectiveness = 0.75,
		impulsefactor = impulsefactor,
		soundhit = "xplosml3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-nano",
		damage = {
			default = 6,
			nanos = 78,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	smallbuilder = {
		areaofeffect = 64,
		camerashake = 64,
		impulsefactor = impulsefactor,
		soundhit = "xplomed2",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-small-builder",
		damage = {
			default = 28,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	smallbuilderSelfd = {
		areaofeffect = 120,
		camerashake = 120,
		impulsefactor = impulsefactor,
		soundhit = "xplomed2",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-large-builder",
		damage = {
			default = 390,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	windboom = {
		AreaOfEffect = 180,
		cameraShake = 180,
		edgeeffectiveness = 0.75,
		impulsefactor = impulsefactor,
		soundhit = "xplosml3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-wind",
		damage = {
			default = 89,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	metalmaker = {
		areaofeffect = 210,
		camerashake = 210,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg4",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-metalmaker",
		damage = {
			default = 660,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	metalmakerSelfd = {
		areaofeffect = 260,
		camerashake = 260,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg4",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-metalmakerselfd",
		damage = {
			default = 1060,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	advmetalmaker = {
		areaofeffect = 320,
		camerashake = 320,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg4",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-advmetalmaker",
		damage = {
			commanders = 1000,
			default = 1220,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	advmetalmakerSelfd = {
		areaofeffect = 480,
		camerashake = 480,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg4",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-advmetalmakerselfd",
		damage = {
			commanders = 1560,
			default = 2650,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	energystorage = {
		areaofeffect = 420,
		camerashake = 420,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-large",
		damage = {
			default = 980,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	energystorageSelfd = {
		areaofeffect = 520,
		camerashake = 520,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-huge",
		damage = {
			default = 1420,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['energystorage-uw'] = {
		areaofeffect = 420,
		camerashake = 420,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-large-uw",
		damage = {
			default = 980,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['energystorageSelfd-uw'] = {
		areaofeffect = 520,
		camerashake = 520,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-huge-uw",
		damage = {
			default = 1420,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	advenergystorage = {
		AreaOfEffect = 480,
		cameraShake = 480,
		impulsefactor = impulsefactor,
		soundhit = "xplonuk3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-huge",
		damage = {
			commanders = 1560,
			default = 2650,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	advenergystorageSelfd = {
		AreaOfEffect = 768,
		cameraShake = 768,
		impulsefactor = impulsefactor,
		soundhit = "xplonuk3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-gigantic",
		damage = {
			commanders = 2450,
			default = 8300,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['advenergystorage-uw'] = {
		AreaOfEffect = 480,
		cameraShake = 480,
		impulsefactor = impulsefactor,
		soundhit = "xplonuk3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-huge-uw",
		damage = {
			commanders = 1560,
			default = 2650,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['advenergystorageSelfd-uw'] = {
		AreaOfEffect = 768,
		cameraShake = 768,
		impulsefactor = impulsefactor,
		soundhit = "xplonuk3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-gigantic-uw",
		damage = {
			commanders = 2450,
			default = 8300,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	geo = {
		areaofeffect = 520,
		camerashake = 210,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg4",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-large",
		damage = {
			default = 1420,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	advgeo = {
		AreaOfEffect = 1280,
		cameraShake = 1280,
		impulsefactor = impulsefactor,
		soundhit = "xplonuk3",
		soundstart = "largegun",
		explosiongenerator = "custom:afusexpl",
		damage = {
			commanders = 2800,
			default = 10600,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	nukeBuilding = {
		AreaOfEffect = 480,
		cameraShake = 480,
		impulsefactor = impulsefactor,
		soundhit = "xplonuk3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-huge",
		damage = {
			commanders = 1560,
			default = 2650,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	nukeBuildingSelfd = {
		AreaOfEffect = 1280,
		cameraShake = 1280,
		impulsefactor = impulsefactor,
		soundhit = "xplonuk3",
		soundstart = "largegun",
		explosiongenerator = "custom:afusexpl",
		damage = {
			commanders = 2800,
			default = 10600,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	nukeSub = {
		AreaOfEffect = 780,
		cameraShake = 780,
		impulsefactor = impulsefactor,
		soundhit = "xplonuk3",
		soundstart = "largegun",
		explosiongenerator = "custom:afusexpl",
		damage = {
			commanders = 1800,
			default = 4000,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	penetrator = {
		areaofeffect = 420,
		camerashake = 420,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-large",
		damage = {
			default = 980,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	penetratorSelfd = {
		areaofeffect = 520,
		camerashake = 520,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-huge",
		damage = {
			default = 1420,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	deadeyeSelfd = {
		areaofeffect = 520,
		camerashake = 520,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg2",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-huge",
		damage = {
			default = 540,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	bantha = {
		areaofeffect = 500,
		camerashake = 500,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:t3unitexplosionxxl",
		damage = {
			commanders = 1390,
			default = 3900,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	banthaSelfd = {
		areaofeffect = 800,
		camerashake = 800,
		impulsefactor = impulsefactor,
		soundhit = "xplomed4",
		soundstart = "misicbm1",
		explosiongenerator = "custom:t3unitexplosionxxxl",
		damage = {
			commanders = 2200,
			default = 5000,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	korgExplosion = {
		AreaOfEffect = 1280,
		cameraShake = 1280,
		impulsefactor = impulsefactor,
		soundhit = "xplonuk3",
		soundstart = "largegun",
		explosiongenerator = "custom:newnuke",
		damage = {
			commanders = 2800,
			default = 10600,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	korgExplosionSelfd = {
		AreaOfEffect = 1920,
		cameraShake = 1920,
		impulsefactor = impulsefactor,
		soundhit = "xplonuk3",
		soundstart = "largegun",
		explosiongenerator = "custom:newnukecor",
		damage = {
			commanders = 3000,
			default = 12800,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	juggernaut = {
		areaofeffect = 280,
		camerashake = 280,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:t3unitexplosionxl",
		damage = {
			commanders = 1000,
			crawlingbombs = 110,
			default = 2000,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	juggernautSelfd = {
		areaofeffect = 430,
		camerashake = 430,
		impulsefactor = impulsefactor,
		soundhit = "xplomed4",
		soundstart = "misicbm1",
		explosiongenerator = "custom:newnuketac",
		damage = {
			commanders = 1390,
			crawlingbombs = 220,
			default = 3350,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	flagshipExplosion = {
		AreaOfEffect = 480,
		cameraShake = 480,
		impulsefactor = impulsefactor,
		soundhit = "xplonuk3",
		soundstart = "largegun",
		explosiongenerator = "custom:t3unitexplosion",
		damage = {
			commanders = 1560,
			default = 2650,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	flagshipExplosionSelfd = {
		AreaOfEffect = 700,
		cameraShake = 700,
		impulsefactor = impulsefactor,
		soundhit = "xplonuk3",
		soundstart = "largegun",
		explosiongenerator = "custom:t3unitexplosionxl",
		damage = {
			commanders = 2100,
			default = 5600,
		},
		customparams = {
			unitexplosion = 1,
		}
	},


	decoycommander = {
		AreaOfEffect = 48,
		cameraShake = 48,
		impulsefactor = impulsefactor,
		soundhit = "xplomed2",
		soundstart = "largegun",
		explosiongenerator = "custom:decoycommander",
		damage = {
			default = 20,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	decoycommanderSelfd = {
		AreaOfEffect = 96,
		cameraShake = 96,
		impulsefactor = impulsefactor,
		soundhit = "xplomed2",
		soundstart = "largegun",
		explosiongenerator = "custom:decoycommander-selfd",
		damage = {
			default = 310,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	minifusionExplosion = {
		AreaOfEffect = 320,
		cameraShake = 320,
		impulsefactor = impulsefactor,
		soundhit = "xplonuk3",
		soundstart = "largegun",
		explosiongenerator = "custom:fusexpl",
		damage = {
			commanders = 1000,
			default = 1780,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	fusionExplosion = {
		AreaOfEffect = 480,
		cameraShake = 480,
		impulsefactor = impulsefactor,
		soundhit = "xplonuk3",
		soundstart = "largegun",
		explosiongenerator = "custom:fusexpl",
		damage = {
			commanders = 1560,
			default = 2650,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	fusionExplosionSelfd = {
		AreaOfEffect = 768,
		cameraShake = 768,
		impulsefactor = impulsefactor,
		soundhit = "xplonuk3",
		soundstart = "largegun",
		explosiongenerator = "custom:fusexpl",
		damage = {
			commanders = 2450,
			default = 8300,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	['fusionExplosion-uw'] = {
		AreaOfEffect = 480,
		cameraShake = 480,
		impulsefactor = impulsefactor,
		soundhit = "xplonuk3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-huge-uw",
		damage = {
			commanders = 1560,
			default = 2650,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['fusionExplosionSelfd-uw'] = {
		AreaOfEffect = 768,
		cameraShake = 768,
		impulsefactor = impulsefactor,
		soundhit = "xplonuk3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-gigantic-uw",
		damage = {
			commanders = 2450,
			default = 8300,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	advancedFusionExplosion = { --this explosion does not generate a distortion effect for unknown reasons
		AreaOfEffect = 1280,
		cameraShake = 1280,
		impulsefactor = impulsefactor,
		soundhit = "xplonuk3",
		soundstart = "largegun",
		explosiongenerator = "custom:afusexpl",
		damage = {
			commanders = 2800,
			default = 10600,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	customfusionexplo = {
		AreaOfEffect = 1280,
		cameraShake = 1280,
		impulsefactor = impulsefactor,
		soundhit = "xplonuk3",
		soundstart = "largegun",
		explosiongenerator = "custom:afusexpl",
		damage = {
			commanders = 2800,
			default = 10600,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	advancedFusionExplosionSelfd = {
		AreaOfEffect = 1920,
		cameraShake = 1920,
		impulsefactor = impulsefactor,
		soundhit = "xplonuk3",
		soundstart = "largegun",
		explosiongenerator = "custom:afusexplxl",
		damage = {
			commanders = 3000,
			default = 12800,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	scavcomexplosion = {
		areaofeffect = 500,
		camerashake = 500,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:scav_commander_explosion",
		damage = {
			commanders = 1390,
			default = 5600,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	ScavComBossExplo = {
		AreaOfEffect = 3000,
		cameraShake = 3000,
		impulsefactor = impulsefactor,
		soundhitwet = "newboomuw",
		soundhit = "newboom",
		soundstart = "largegun",
		explosiongenerator = "custom:newnukehuge",
		damage = {
			commanders = 2150,
			default = 16700,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	--NUKE EXPLOSIONS WITH DAMAGE--

	oldcommanderexplosion = {
		name = "Matter/AntimatterExplosion",
		AreaOfEffect = 700,
		cameraShake = 510,
		explosionSpeed = 725,
		impulsefactor = impulsefactor,
		soundhitwet = "newboomuw",
		soundhit = "newboom",
		soundstart = "largegun",
		soundstartvolume = 25,
		soundhitvolume = 25,
		soundhitwetvolume = 34,
		explosiongenerator = "custom:COMMANDER_EXPLOSION",
		craterboost = 4,
		cratermult = 2,
		edgeeffectiveness = 0,
		damage = {
			default = 5000,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	commanderexplosion = {
		name = "Matter/AntimatterExplosion",
		AreaOfEffect = 700,
		cameraShake = 510,
		explosionSpeed = 725,
		impulsefactor = impulsefactor,
		soundhitwet = "newboomuw",
		soundhit = "newboom",
		soundstart = "largegun",
		soundstartvolume = 25,
		soundhitvolume = 25,
		soundhitwetvolume = 34,
		explosiongenerator = "custom:shockwaveceg",
		craterboost = 4,
		cratermult = 2,
		edgeeffectiveness = 0,
		damage = {
			default = 5000,
		},
		customparams = {
			unitexplosion = 1,
		}
	},


	--BUILDING DEATHS--

	WallExplosionMetal = {
		AreaOfEffect = 36,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		soundhit = "xplodragmetal",
		--soundstart = "metalhit",
		explosiongenerator = "custom:wallexplosion-metal",
		damage = {
			default = 0,
		},
		customparams = {
			unitexplosion = 1,
		},
	},
	WallExplosionMetalXL = {
		AreaOfEffect = 38,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		soundhit = "xplodragmetal",
		--soundstart = "metalhit",
		explosiongenerator = "custom:wallexplosion-metal",
		damage = {
			default = 0,
		},
		customparams = {
			unitexplosion = 1,
		},
	},
	WallExplosionConcrete = {
		AreaOfEffect = 36,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		soundhit = "xplodragconcrete",
		--soundstart = "metalhit",
		explosiongenerator = "custom:wallexplosion-concrete",
		damage = {
			default = 0,
		},
		customparams = {
			unitexplosion = 1,
		},
	},
	WallExplosionConcreteXL = {
		AreaOfEffect = 38,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		soundhit = "xplodragconcrete",
		--soundstart = "metalhit",
		explosiongenerator = "custom:wallexplosion-concrete",
		damage = {
			default = 0,
		},
		customparams = {
			unitexplosion = 1,
		},
	},
	WallExplosionWater = {
		AreaOfEffect = 48,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		soundhit = "xplodragwater",
		--soundstart = "metalhit",
		explosiongenerator = "custom:wallexplosion-water",
		damage = {
			default = 0,
		},
		customparams = {
			unitexplosion = 1,
		},
	},
	tinyBuildingExplosionGeneric = {
		AreaOfEffect = 25,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		soundhit = "xplosml3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-tiny",
		damage = {
			default = 11,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	tinyBuildingExplosionGenericSelfd = {
		AreaOfEffect = 40,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		soundhit = "xplosml3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-small",
		damage = {
			default = 33,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['tinyBuildingExplosionGeneric-uw'] = {
		AreaOfEffect = 25,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		soundhit = "xplosml3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-tiny-uw",
		damage = {
			default = 11,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['tinyBuildingExplosionGenericSelfd-uw'] = {
		AreaOfEffect = 40,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		soundhit = "xplosml3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-small-uw",
		damage = {
			default = 33,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	smallBuildingExplosionGeneric = {
		AreaOfEffect = 180,
		cameraShake = 180,
		impulsefactor = impulsefactor,
		soundhit = "xplosml3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-small",
		damage = {
			default = 89,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	smallBuildingExplosionGenericSelfd = {
		AreaOfEffect = 240,
		cameraShake = 240,
		impulsefactor = impulsefactor,
		soundhit = "xplosml3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-medium",
		damage = {
			default = 1000,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	smallMex = {
		AreaOfEffect = 240,
		cameraShake = 240,
		impulsefactor = impulsefactor,
		soundhit = "xplosml3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-small",
		damage = {
			default = 390,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['smallBuildingExplosionGeneric-uw'] = {
		AreaOfEffect = 180,
		cameraShake = 180,
		impulsefactor = impulsefactor,
		soundhit = "xplosml3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-small-uw",
		damage = {
			default = 89,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['smallBuildingExplosionGenericSelfd-uw'] = {
		AreaOfEffect = 240,
		cameraShake = 240,
		impulsefactor = impulsefactor,
		soundhit = "xplosml3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-medium-uw",
		damage = {
			default = 1000,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	mediumBuildingExplosionGeneric = {
		AreaOfEffect = 260,
		cameraShake = 260,
		impulsefactor = impulsefactor,
		soundhit = "xplomed1",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-medium",
		damage = {
			default = 220,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	mediumBuildingExplosionGenericSelfd = {
		AreaOfEffect = 360,
		cameraShake = 360,
		impulsefactor = impulsefactor,
		soundhit = "xplomed1",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-large",
		damage = {
			default = 1560,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['mediumBuildingExplosionGeneric-uw'] = {
		AreaOfEffect = 260,
		cameraShake = 260,
		impulsefactor = impulsefactor,
		soundhit = "xplomed1",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-medium-uw",
		damage = {
			default = 220,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['mediumBuildingExplosionGenericSelfd-uw'] = {
		AreaOfEffect = 360,
		cameraShake = 360,
		impulsefactor = impulsefactor,
		soundhit = "xplomed1",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-large-uw",
		damage = {
			default = 1560,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	largeBuildingExplosionGeneric = {
		AreaOfEffect = 340,
		cameraShake = 340,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-large",
		damage = {
			default = 670,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	largeBuildingExplosionGenericSelfd = {
		AreaOfEffect = 480,
		cameraShake = 480,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-huge",
		damage = {
			default = 2000,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['largeBuildingExplosionGeneric-uw'] = {
		AreaOfEffect = 340,
		cameraShake = 340,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-large-uw",
		damage = {
			default = 670,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['largeBuildingExplosionGenericSelfd-uw'] = {
		AreaOfEffect = 480,
		cameraShake = 480,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-huge-uw",
		damage = {
			default = 2000,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	hugeBuildingExplosionGeneric = {
		AreaOfEffect = 420,
		cameraShake = 420,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg4",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-huge",
		damage = {
			default = 1330,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	hugeBuildingExplosionGenericSelfd = {
		AreaOfEffect = 580,
		cameraShake = 580,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg4",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-gigantic",
		damage = {
			default = 3100,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['hugeBuildingExplosionGeneric-uw'] = {
		AreaOfEffect = 420,
		cameraShake = 420,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg4",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-gigantic-uw",
		damage = {
			default = 1330,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['hugeBuildingExplosionGenericSelfd-uw'] = {
		AreaOfEffect = 580,
		cameraShake = 580,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg4",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-gigantic-uw",
		damage = {
			default = 3100,
		},
		customparams = {
			unitexplosion = 1,
		}
	},


	--UNIT DEATHS--

	tinyExplosionGeneric = {
		AreaOfEffect = 24,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		soundhit = "xplomed2",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-tiny",
		damage = {
			default = 6,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	tinyExplosionGenericSelfd = {
		AreaOfEffect = 44,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		soundhit = "xplomed2",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-small",
		damage = {
			default = 56,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['tinyExplosionGeneric-builder'] = {
		AreaOfEffect = 24,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		soundhit = "xplomed2",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-tiny-builder",
		damage = {
			default = 6,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['tinyExplosionGenericSelfd-builder'] = {
		AreaOfEffect = 44,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		soundhit = "xplomed2",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-small-builder",
		damage = {
			default = 56,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['tinyExplosionGeneric-uw'] = {
		AreaOfEffect = 24,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		soundhit = "xplomed2",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-tiny-uw",
		damage = {
			default = 6,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['tinyExplosionGenericSelfd-uw'] = {
		AreaOfEffect = 44,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		soundhit = "xplomed2",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-small-uw",
		damage = {
			default = 56,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['tinyExplosionGeneric-phib'] = {
		AreaOfEffect = 24,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		soundhit = "xplomed2",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-tiny-phib",
		damage = {
			default = 6,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['tinyExplosionGenericSelfd-phib'] = {
		AreaOfEffect = 44,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		soundhit = "xplomed2",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-small-phib",
		damage = {
			default = 56,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	smallExplosionGenericAir = {
		AreaOfEffect = 24,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-small",
		damage = {
			default = 6,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	smallExplosionGeneric = {
		AreaOfEffect = 36,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-small",
		damage = {
			default = 11,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	smallExplosionGenericSelfd = {
		AreaOfEffect = 60,
		cameraShake = 60,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-medium",
		damage = {
			default = 220,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['smallExplosionGeneric-builder'] = {
		AreaOfEffect = 36,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-small-builder",
		damage = {
			default = 11,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['smallExplosionGenericSelfd-builder'] = {
		AreaOfEffect = 60,
		cameraShake = 60,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-medium-builder",
		damage = {
			default = 220,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['smallExplosionGeneric-uw'] = {
		AreaOfEffect = 36,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-small-uw",
		damage = {
			default = 11,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['smallExplosionGenericSelfd-uw'] = {
		AreaOfEffect = 60,
		cameraShake = 60,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-medium-uw",
		damage = {
			default = 220,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['smallExplosionGeneric-phib'] = {
		AreaOfEffect = 36,
		cameraShake = 0,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-small-phib",
		damage = {
			default = 11,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['smallExplosionGenericSelfd-phib'] = {
		AreaOfEffect = 60,
		cameraShake = 60,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-medium-phib",
		damage = {
			default = 220,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	mediumExplosionGeneric = {
		AreaOfEffect = 48,
		cameraShake = 48,
		impulsefactor = impulsefactor,
		soundhit = "xplomed2",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-medium",
		damage = {
			default = 20,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	mediumExplosionGenericSelfd = {
		AreaOfEffect = 96,
		cameraShake = 96,
		impulsefactor = impulsefactor,
		soundhit = "xplomed2",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-large",
		damage = {
			default = 310,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['mediumExplosionGeneric-builder'] = {
		AreaOfEffect = 48,
		cameraShake = 48,
		impulsefactor = impulsefactor,
		soundhit = "xplomed2",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-medium-builder",
		damage = {
			default = 20,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['mediumExplosionGenericSelfd-builder'] = {
		AreaOfEffect = 96,
		cameraShake = 96,
		impulsefactor = impulsefactor,
		soundhit = "xplomed2",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-large-builder",
		damage = {
			default = 310,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['mediumExplosionGeneric-uw'] = {
		AreaOfEffect = 48,
		cameraShake = 48,
		impulsefactor = impulsefactor,
		soundhit = "xplomed2",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-medium-uw",
		damage = {
			default = 20,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['mediumExplosionGenericSelfd-uw'] = {
		AreaOfEffect = 96,
		cameraShake = 96,
		impulsefactor = impulsefactor,
		soundhit = "xplomed2",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-large-uw",
		damage = {
			default = 310,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['mediumExplosionGeneric-phib'] = {
		AreaOfEffect = 48,
		cameraShake = 48,
		impulsefactor = impulsefactor,
		soundhit = "xplomed2",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-medium-phib",
		damage = {
			default = 20,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['mediumExplosionGenericSelfd-phib'] = {
		AreaOfEffect = 96,
		cameraShake = 96,
		impulsefactor = impulsefactor,
		soundhit = "xplomed2",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-large-phib",
		damage = {
			default = 310,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	largeExplosionGeneric = {
		AreaOfEffect = 64,
		cameraShake = 64,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-large",
		damage = {
			default = 28,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	largeExplosionGenericSelfd = {
		AreaOfEffect = 120,
		cameraShake = 120,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-huge",
		damage = {
			default = 390,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['largeExplosionGeneric-builder'] = {
		AreaOfEffect = 64,
		cameraShake = 64,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-large-builder",
		damage = {
			default = 28,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['largeExplosionGenericSelfd-builder'] = {
		AreaOfEffect = 120,
		cameraShake = 120,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-huge-builder",
		damage = {
			default = 390,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['largeExplosionGeneric-uw'] = {
		AreaOfEffect = 64,
		cameraShake = 64,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-large-uw",
		damage = {
			default = 28,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['largeExplosionGenericSelfd-uw'] = {
		AreaOfEffect = 120,
		cameraShake = 120,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-huge-uw",
		damage = {
			default = 390,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['largeExplosionGeneric-phib'] = {
		AreaOfEffect = 64,
		cameraShake = 64,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-large-phib",
		damage = {
			default = 28,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['largeExplosionGenericSelfd-phib'] = {
		AreaOfEffect = 120,
		cameraShake = 120,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-huge-phib",
		damage = {
			default = 390,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	hugeExplosionGeneric = {
		AreaOfEffect = 96,
		cameraShake = 96,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg4",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-huge",
		damage = {
			default = 39,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	explosiont3 = {
		AreaOfEffect = 96,
		cameraShake = 96,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg4",
		soundstart = "largegun",
		explosiongenerator = "custom:t3unitexplosion",
		damage = {
			default = 78,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	explosiont3med = {
		AreaOfEffect = 48,
		cameraShake = 48,
		impulsefactor = impulsefactor,
		soundhit = "xplomed2",
		soundstart = "largegun",
		explosiongenerator = "custom:t3unitexplosionmed",
		damage = {
			default = 20,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	explosiont3xl = {
		AreaOfEffect = 160,
		cameraShake = 160,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg4",
		soundstart = "largegun",
		explosiongenerator = "custom:t3unitexplosionxl",
		damage = {
			default = 1110,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	explosiont3xxl = {
		AreaOfEffect = 280,
		cameraShake = 280,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg4",
		soundstart = "largegun",
		explosiongenerator = "custom:t3unitexplosionxxxl",
		damage = {
			default = 2000,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	hugeExplosionGenericSelfd = {
		AreaOfEffect = 160,
		cameraShake = 160,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg4",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-gigantic",
		damage = {
			default = 560,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['hugeExplosionGeneric-builder'] = {
		AreaOfEffect = 96,
		cameraShake = 96,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg4",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-huge-builder",
		damage = {
			default = 39,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['hugeExplosionGenericSelfd-builder'] = {
		AreaOfEffect = 160,
		cameraShake = 160,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg4",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-gigantic-builder",
		damage = {
			default = 560,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['hugeExplosionGeneric-uw'] = {
		AreaOfEffect = 96,
		cameraShake = 96,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg4",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-huge-uw",
		damage = {
			default = 39,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['hugeExplosionGenericSelfd-uw'] = {
		AreaOfEffect = 160,
		cameraShake = 160,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg4",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-gigantic-uw",
		damage = {
			default = 560,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['hugeExplosionGeneric-phib'] = {
		AreaOfEffect = 96,
		cameraShake = 96,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg4",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-huge-phib",
		damage = {
			default = 39,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	['hugeExplosionGenericSelfd-phib'] = {
		AreaOfEffect = 160,
		cameraShake = 160,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg4",
		soundstart = "largegun",
		explosiongenerator = "custom:genericunitexplosion-gigantic-phib",
		damage = {
			default = 560,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	lootboxExplosion1 = {
		AreaOfEffect = 340,
		cameraShake = 340,
		impulsefactor = impulsefactor,
		soundhit = "xplomed3",
		soundstart = "largegun",
		explosiongenerator = "custom:t3unitexplosionxl",
		damage = {
			default = 670,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	lootboxExplosion2 = {
		AreaOfEffect = 620,
		cameraShake = 620,
		impulsefactor = impulsefactor,
		soundhit = "xplolrg4",
		soundstart = "largegun",
		explosiongenerator = "custom:t3unitexplosionxxl",
		damage = {
			default = 1330,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	lootboxExplosion3 = {
		AreaOfEffect = 920,
		cameraShake = 920,
		impulsefactor = impulsefactor,
		soundhit = "xplonuk3",
		soundstart = "largegun",
		explosiongenerator = "custom:t3unitexplosionxxxl",
		damage = {
			default = 2650,
		},
		customparams = {
			unitexplosion = 1,
		}
	},
	lootboxExplosion4 = {
		AreaOfEffect = 1280,
		cameraShake = 1280,
		impulsefactor = impulsefactor,
		soundhit = "newboom",
		soundstart = "largegun",
		explosiongenerator = "custom:t3unitexplosionxxxxl",
		damage = {
			default = 5300,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	mistexplo = {    -- for scavmist
		areaofeffect = 200,
		craterboost = 0,
		cratermult = 0,
		edgeeffectiveness = 0.55,
		explosiongenerator = "custom:scav_mist_explosion",
		firestarter = 20,
		impulsefactor = 0,
		name = "ScavMistExplo",
		paralyzer = 1,
		paralyzetime = 20,
		soundhit = "xploelc1",
		soundstart = "bombrel",
		damage = {
			default = 3000,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	mistexploxl = {    -- for scavmist
		areaofeffect = 350,
		craterboost = 0,
		cratermult = 0,
		edgeeffectiveness = 0.75,
		explosiongenerator = "custom:scav_mist_explosion",
		firestarter = 20,
		impulsefactor = 0,
		name = "ScavMistExplo",
		paralyzer = 1,
		paralyzetime = 20,
		soundhit = "xploelc1",
		soundstart = "bombrel",
		damage = {
			default = 6000,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

	mistexploxxl = {    -- for scavmist
		areaofeffect = 400,
		craterboost = 0,
		cratermult = 0,
		edgeeffectiveness = 0.75,
		explosiongenerator = "custom:scav_mist_explosion",
		firestarter = 20,
		impulsefactor = 0,
		name = "ScavMistExplo",
		paralyzer = 1,
		paralyzetime = 20,
		soundhit = "xploelc1",
		soundstart = "bombrel",
		damage = {
			default = 20000,
		},
		customparams = {
			unitexplosion = 1,
		}
	},

}

local scavengerDefs = {}
for name, def in pairs(unitDeaths) do
	if string.find(string.lower(name), 'explosiont3') or string.find(string.lower(name), 'explosiongeneric') or string.find(string.lower(name), 'buildingexplosiongeneric') then
		scavengerDefs[name .. '-purple'] = table.copy(def)
		scavengerDefs[name .. '-purple'].explosiongenerator = scavengerDefs[name .. '-purple'].explosiongenerator .. '-purple'
	elseif string.find(def.explosiongenerator, 't3unitexplosion') then
		scavengerDefs[name .. '-purple'] = table.copy(def)
		scavengerDefs[name .. '-purple'].explosiongenerator = scavengerDefs[name .. '-purple'].explosiongenerator .. '-purple'
	end
end
for name, ud in pairs(scavengerDefs) do
	unitDeaths[name] = ud
end

return lowerkeys(unitDeaths)
