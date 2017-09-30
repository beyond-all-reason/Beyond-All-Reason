
local impulseboost = 0.123
local impulsefactor = 0.123

unitDeaths = {

    pyro = {
        weaponType = "Cannon",
        areaofeffect = 64,
        camerashake = 64,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg3",
        soundstart = "largegun",
        explosiongenerator = "custom:genericunitexplosion-large-fire",
        damage = {
            default = 50,
        },
    },
    pyroselfd = {
        weaponType = "Cannon",
        areaofeffect = 200,
        camerashake = 200,
        edgeeffectiveness = 0.5,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg3",
        soundstart = "largegun",
        explosiongenerator = "custom:genericunitexplosion-huge-fire",
        damage = {
            default = 1000,
        },
    },

    flamethrower = {
        weaponType = "Cannon",
        areaofeffect = 48,
        camerashake = 48,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg3",
        soundstart = "largegun",
        explosiongenerator = "custom:genericunitexplosion-medium-fire",
        damage = {
            default = 35,
        },
    },
    flamethrowerSelfd = {
        weaponType = "Cannon",
        areaofeffect = 140,
        camerashake = 140,
        edgeeffectiveness = 0.5,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg3",
        soundstart = "largegun",
        explosiongenerator = "custom:genericunitexplosion-large-fire",
        damage = {
            default = 650,
        },
    },
	
	nanoboom = {
		weaponType = "Cannon",
		areaofeffect = 128,
		camerashake = 128,
		edgeeffectiveness = 0.75,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundhit = "xplosml3",
		soundstart = "largegun",
		explosiongenerator = "custom:genericbuildingexplosion-nano",
		damage = {
			default = 10,
			nanos = 480,
		},
        customparams = {
            expl_light_color = "0.7 1 0.3",
        },
	},

    smallbuilder = {
        weaponType = "Cannon",
        areaofeffect = 64,
        camerashake = 64,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplomed2",
        soundstart = "largegun",
        explosiongenerator = "custom:genericunitexplosion-small",
        damage = {
            default = 25,
        },
    },
    smallbuilderSelfd= {
        weaponType = "Cannon",
        areaofeffect = 120,
        camerashake = 120,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplomed2",
        soundstart = "largegun",
        explosiongenerator = "custom:genericunitexplosion-large",
        damage = {
            default = 350,
        },
    },
	
	windboom = {
		weaponType = "Cannon",
		AreaOfEffect = 180,
		cameraShake = 180,
		edgeeffectiveness = 0.75,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundhit = "xplosml3",
		soundstart = "largegun",
		explosiongenerator="custom:genericbuildingexplosion-wind",
		damage = {
			default = 80,
		},
	},

	platformboom = {
		weaponType = "Cannon",
		AreaOfEffect = 40,
		cameraShake = 180,
		edgeeffectiveness = 1.0,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundhit = "xplosml3",
		soundstart = "largegun",
		explosionspeed = 1,
		explosiongenerator="custom:genericbuildingexplosion-small",
		damage = {
			default = 160000,
			platform = 1350,
		},
	},

    metalmaker = {
        weaponType = "Cannon",
        areaofeffect = 210,
        camerashake = 210,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg4",
        soundstart = "largegun",
        explosiongenerator = "custom:genericbuildingexplosion-metalmaker",
        damage = {
            default = 590,
        },
    },
    metalmakerSelfd = {
        weaponType = "Cannon",
        areaofeffect = 260,
        camerashake = 260,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg4",
        soundstart = "largegun",
        explosiongenerator = "custom:genericbuildingexplosion-metalmakerselfd",
        damage = {
            default = 950,
        },
    },

    advmetalmaker = {
        weaponType = "Cannon",
        areaofeffect = 320,
        camerashake = 320,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg4",
        soundstart = "largegun",
        explosiongenerator = "custom:genericbuildingexplosion-advmetalmaker",
        damage = {
            commanders = 900,
            default = 1100,
        },
    },
    advmetalmakerSelfd = {
        weaponType = "Cannon",
        areaofeffect = 480,
        camerashake = 480,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg4",
        soundstart = "largegun",
        explosiongenerator = "custom:genericbuildingexplosion-advmetalmakerselfd",
        damage = {
            commanders = 1400,
            default = 2400,
        },
    },

    energystorage = {
        weaponType = "Cannon",
        areaofeffect = 420,
        camerashake = 420,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg3",
        soundstart = "largegun",
        explosiongenerator = "custom:genericbuildingexplosion-large",
        damage = {
            default = 880,
        },
    },
    energystorageSelfd = {
        weaponType = "Cannon",
        areaofeffect = 520,
        camerashake = 520,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg3",
        soundstart = "largegun",
        explosiongenerator = "custom:genericbuildingexplosion-huge",
        damage = {
            default = 1280,
        },
    },
	
	advenergystorage = {
        weaponType = "Cannon",
        AreaOfEffect = 480,
        cameraShake = 480,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplonuk3",
        soundstart = "largegun",
        explosiongenerator="custom:genericbuildingexplosion-huge",
        damage = {
            commanders = 1400,
            default = 2400,
        },
    },
    advenergystorageSelfd = {
        weaponType = "Cannon",
        AreaOfEffect = 768,
        cameraShake = 768,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplonuk3",
        soundstart = "largegun",
        explosiongenerator="custom:genericbuildingexplosion-gigantic",
        damage = {
            commanders = 2200,
            default = 7500,
        },
    },

    geo = {
        weaponType = "Cannon",
        areaofeffect = 520,
        camerashake = 210,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg4",
        soundstart = "largegun",
        explosiongenerator = "custom:genericbuildingexplosion-large",
        damage = {
            default = 1280,
        },
    },

    advgeo = {
        weaponType = "Cannon",
        AreaOfEffect = 1280,
        cameraShake = 1280,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplonuk3",
        soundstart = "largegun",
        explosiongenerator="custom:nukedatbewm",
        damage = {
            commanders = 2500,
            default = 9500,
        },
    },

    nukeBuilding = {
        weaponType = "Cannon",
        AreaOfEffect = 480,
        cameraShake = 480,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplonuk3",
        soundstart = "largegun",
        explosiongenerator="custom:genericbuildingexplosion-huge",
        damage = {
            commanders = 1400,
            default = 2400,
        },
    },
    nukeBuildingSelfd = {
        weaponType = "Cannon",
        AreaOfEffect = 1280,
        cameraShake = 1280,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplonuk3",
        soundstart = "largegun",
        explosiongenerator="custom:nukedatbewm",
        damage = {
            commanders = 2500,
            default = 9500,
        },
    },

    penetrator = {
        weaponType = "Cannon",
        areaofeffect = 420,
        camerashake = 420,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg3",
        soundstart = "largegun",
        explosiongenerator = "custom:genericbuildingexplosion-large",
        damage = {
            default = 880,
        },
    },
    penetratorSelfd = {
        weaponType = "Cannon",
        areaofeffect = 520,
        camerashake = 520,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg3",
        soundstart = "largegun",
        explosiongenerator = "custom:genericbuildingexplosion-huge",
        damage = {
            default = 1280,
        },
    },

    bantha = {
        weaponType = "Cannon",
        areaofeffect = 500,
        camerashake = 500,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg3",
        soundstart = "largegun",
        explosiongenerator = "custom:genericbuildingexplosion-huge",
        damage = {
            commanders = 1250,
            default = 3500,
        },
    },
    banthaSelfd = {
        weaponType = "Cannon",
        areaofeffect = 800,
        camerashake = 800,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplomed4",
        soundstart = "misicbm1",
        explosiongenerator = "custom:genericbuildingexplosion-gigantic",
        damage = {
            commanders = 2000,
            default = 4500,
        },
    },

    flagshipExplosion = {
        weaponType = "Cannon",
        AreaOfEffect = 480,
        cameraShake = 480,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplonuk3",
        soundstart = "largegun",
        explosiongenerator="custom:genericbuildingexplosion-huge",
        damage = {
            commanders = 1400,
            default = 2400,
        },
    },
    flagshipExplosionSelfd = {
        weaponType = "Cannon",
        AreaOfEffect = 700,
        cameraShake = 700,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplonuk3",
        soundstart = "largegun",
        explosiongenerator="custom:genericbuildingexplosion-huge",
        damage = {
            commanders = 1900,
            default = 5000,
        },
    },


    decoycommander = {
        weaponType = "Cannon",
        AreaOfEffect = 48,
        cameraShake = 48,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplomed2",
        soundstart = "largegun",
        explosiongenerator="custom:decoycommander",
        damage = {
            default = 18,
        },
    },
    decoycommanderSelfd = {
        weaponType = "Cannon",
        AreaOfEffect = 96,
        cameraShake = 96,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplomed2",
        soundstart = "largegun",
        explosiongenerator="custom:decoycommander-selfd",
        damage = {
            default = 280,
        },
    },

    fusionExplosion = {
        weaponType = "Cannon",
        AreaOfEffect = 480,
        cameraShake = 480,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplonuk3",
        soundstart = "largegun",
        explosiongenerator="custom:genericbuildingexplosion-huge",
        damage = {
            commanders = 1400,
            default = 2400,
        },
    },
    fusionExplosionSelfd = {
        weaponType = "Cannon",
        AreaOfEffect = 768,
        cameraShake = 768,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplonuk3",
        soundstart = "largegun",
        explosiongenerator="custom:genericbuildingexplosion-gigantic",
        damage = {
            commanders = 2200,
            default = 7500,
        },
    },

    advancedFusionExplosion = {
        weaponType = "Cannon",
        AreaOfEffect = 1280,
        cameraShake = 1280,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplonuk3",
        soundstart = "largegun",
        explosiongenerator="custom:nukedatbewm",
        damage = {
            commanders = 2500,
            default = 9500,
        },
    },
    advancedFusionExplosionSelfd = {
        weaponType = "Cannon",
        AreaOfEffect = 1920,
        cameraShake = 1920,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplonuk3",
        soundstart = "largegun",
        explosiongenerator="custom:nukedatbewm",
        damage = {
            commanders = 2700,
            default = 11500,
        },
    },
	

--NUKE EXPLOSIONS WITH DAMAGE--

    commanderexplosion = {
		name = "Matter/AntimatterExplosion",
		weaponType = "Cannon",
		AreaOfEffect = 720,
		cameraShake = 720,
		impulseboost = 3,
		impulsefactor = 3,
		soundhit = "newboom",
		soundstart = "largegun",
		explosiongenerator="custom:COMMANDER_EXPLOSION",
		range = 380,
		weaponvelocity = 250,
		craterboost = 6,
		cratermult = 3,
		edgeeffectiveness = 0.25,
		reloadtime = 3.5999999046326,
		turret = 1,
		damage = {
			default = 50000,
			commanders = 9500,
		},
	},
    commanderexplosionselfd = {
		name = "Matter/AntimatterExplosion",
		weaponType = "Cannon",
		AreaOfEffect = 720,
		cameraShake = 720,
		impulseboost = 3,
		impulsefactor = 3,
		soundhit = "newboom",
		soundstart = "largegun",
		explosiongenerator="custom:COMMANDER_EXPLOSION",
		range = 380,
		weaponvelocity = 250,
		craterboost = 6,
		cratermult = 3,
		edgeeffectiveness = 0.25,
		reloadtime = 3.5999999046326,
		turret = 1,
		damage = {
			default = 50000,
		},
	},


--BUILDING DEATHS--

    tinyBuildingExplosionGeneric = {
        weaponType = "Cannon",
        AreaOfEffect =  25,
        cameraShake = 0,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplosml3",
        soundstart = "largegun",
        explosiongenerator="custom:genericbuildingexplosion-tiny",
        damage = {
            default = 10,
        },
    },
    tinyBuildingExplosionGenericSelfd = {
        weaponType = "Cannon",
        AreaOfEffect =  40,
        cameraShake = 0,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplosml3",
        soundstart = "largegun",
        explosiongenerator="custom:genericbuildingexplosion-small",
        damage = {
            default = 30,
        },
    },

    smallBuildingExplosionGeneric = {
        weaponType = "Cannon",
        AreaOfEffect =  180,
        cameraShake = 180,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplosml3",
        soundstart = "largegun",
        explosiongenerator="custom:genericbuildingexplosion-small",
        damage = {
            default = 80,
        },
    },
    smallBuildingExplosionGenericSelfd = {
        weaponType = "Cannon",
        AreaOfEffect =  240,
        cameraShake = 240,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplosml3",
        soundstart = "largegun",
        explosiongenerator="custom:genericbuildingexplosion-medium",
        damage = {
            default = 900,
        },
    },

    mediumBuildingExplosionGeneric = {
        weaponType = "Cannon",
        AreaOfEffect =  260,
        cameraShake = 260,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplomed1",
        soundstart = "largegun",
        explosiongenerator="custom:genericbuildingexplosion-medium",
        damage = {
            default = 200,
        },
    },
    mediumBuildingExplosionGenericSelfd = {
        weaponType = "Cannon",
        AreaOfEffect =  360,
        cameraShake = 360,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplomed1",
        soundstart = "largegun",
        explosiongenerator="custom:genericbuildingexplosion-large",
        damage = {
            default = 1400,
        },
    },

    largeBuildingExplosionGeneric = {
        weaponType = "Cannon",
        AreaOfEffect =  340,
        cameraShake = 340,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg3",
        soundstart = "largegun",
        explosiongenerator="custom:genericbuildingexplosion-large",
        damage = {
            default = 600,
        },
    },
    largeBuildingExplosionGenericSelfd = {
        weaponType = "Cannon",
        AreaOfEffect =  480,
        cameraShake = 480,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg3",
        soundstart = "largegun",
        explosiongenerator="custom:genericbuildingexplosion-huge",
        damage = {
            default = 1800,
        },
    },

    hugeBuildingExplosionGeneric = {
        weaponType = "Cannon",
        AreaOfEffect = 420,
        cameraShake = 420,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg4",
        soundstart = "largegun",
        explosiongenerator="custom:genericbuildingexplosion-huge",
        damage = {
            default = 1200,
        },
    },
    hugeBuildingExplosionGenericSelfd = {
        weaponType = "Cannon",
        AreaOfEffect = 580,
        cameraShake = 580,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg4",
        soundstart = "largegun",
        explosiongenerator="custom:genericbuildingexplosion-gigantic",
        damage = {
            default = 2800,
        },
    },
	
	
--UNIT DEATHS--

    tinyExplosionGeneric = {
        weaponType = "Cannon",
        AreaOfEffect = 24,
        cameraShake = 0,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplomed2",
        soundstart = "largegun",
        explosiongenerator="custom:genericunitexplosion-tiny",
        damage = {
            default = 5,
        },
    },
    tinyExplosionGenericSelfd = {
        weaponType = "Cannon",
        AreaOfEffect = 44,
        cameraShake = 0,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplomed2",
        soundstart = "largegun",
        explosiongenerator="custom:genericunitexplosion-small",
        damage = {
            default = 50,
        },
    },

    smallExplosionGeneric = {
        weaponType = "Cannon",
        AreaOfEffect = 36,
        cameraShake = 0,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg3",
        soundstart = "largegun",
        explosiongenerator="custom:genericunitexplosion-small",
        damage = {
            default = 10,
        },
    },
    smallExplosionGenericSelfd = {
        weaponType = "Cannon",
        AreaOfEffect = 60,
        cameraShake = 60,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg3",
        soundstart = "largegun",
        explosiongenerator="custom:genericunitexplosion-medium",
        damage = {
            default = 200,
        },
    },

    mediumExplosionGeneric = {
        weaponType = "Cannon",
        AreaOfEffect = 48,
        cameraShake = 48,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplomed2",
        soundstart = "largegun",
        explosiongenerator="custom:genericunitexplosion-medium",
        damage = {
            default = 18,
        },
    },
    mediumExplosionGenericSelfd = {
        weaponType = "Cannon",
        AreaOfEffect = 96,
        cameraShake = 96,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplomed2",
        soundstart = "largegun",
        explosiongenerator="custom:genericunitexplosion-large",
        damage = {
            default = 280,
        },
    },

    largeExplosionGeneric = {
        weaponType = "Cannon",
        AreaOfEffect = 64,
        cameraShake = 64,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg3",
        soundstart = "largegun",
        explosiongenerator="custom:genericunitexplosion-large",
        damage = {
            default = 25,
        },
    },
    largeExplosionGenericSelfd = {
        weaponType = "Cannon",
        AreaOfEffect = 120,
        cameraShake = 120,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg3",
        soundstart = "largegun",
        explosiongenerator="custom:genericunitexplosion-huge",
        damage = {
            default = 350,
        },
    },

    hugeExplosionGeneric = {
        weaponType = "Cannon",
        AreaOfEffect = 96,
        cameraShake = 96,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg4",
        soundstart = "largegun",
        explosiongenerator="custom:genericunitexplosion-huge",
        damage = {
            default = 35,
        },
    },
    hugeExplosionGenericSelfd = {
        weaponType = "Cannon",
        AreaOfEffect = 160,
        cameraShake = 160,
        impulseboost = impulseboost,
        impulsefactor = impulsefactor,
        soundhit = "xplolrg4",
        soundstart = "largegun",
        explosiongenerator="custom:genericunitexplosion-gigantic",
        damage = {
            default = 500,
        },
    },

	
}

return lowerkeys(unitDeaths)
