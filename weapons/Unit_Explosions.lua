local impulsefactor = 0.123

local unitDeaths = {

	blank = {
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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

	commanderexplosion = {
		name = "Matter/AntimatterExplosion",
		weaponType = "Cannon",
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

	--BUILDING DEATHS--

	WallExplosionMetal = {
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
		weaponType = "Cannon",
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
