--------------------------------------------------------------------------------
-- These represent both the area of effect and the camerashake amount
local smallNukeExplosion = 480
local hugeNukeExplosion = 750

local smallNukeExplosionDamage = 500
local hugeNukeExplosionDamage = 1280
local commanderNukeExplosionDamage = 720

local impulseboost = 0.123
local impulsefactor = 0.123

unitDeaths = {
	
	pyro = {
		weaponType		   = "Cannon",
		areaofeffect = 64,
		camerashake = 64,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundstart = "xplolrg3",
		explosiongenerator = "custom:genericunitexplosion-large",
		damage = {
			default = 50,
		},
	},
	
	pyroselfd = {
		weaponType		   = "Cannon",
		areaofeffect = 200,
		camerashake = 200,
		edgeeffectiveness = 0.5,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundstart = "xplolrg3",
		explosiongenerator = "custom:genericunitexplosion-large",
		damage = {
			default = 1000,
		},
	},
	
	nanoboom = {
		weaponType		   = "Cannon",
		areaofeffect = 128,
		camerashake = 128,
		edgeeffectiveness = 0.75,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundhit = "xplosml3",
		explosiongenerator = "custom:genericbuildingexplosion-small",
		damage = {
			default = 10,
			nanos = 400,
		},
	},
	
	smallbuilderboom = {
		weaponType		   = "Cannon",
		areaofeffect = 64,
		camerashake = 64,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundstart = "xplomed2",
		explosiongenerator = "custom:genericbuildingexplosion-tiny",
		damage = {
			default = 25,
		},
	},
	
	windboom = {
		weaponType		   = "Cannon",
		AreaOfEffect = 180,
		cameraShake = 180,
		edgeeffectiveness = 0.6,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundstart = "xplosml3",
		explosiongenerator="custom:genericbuildingexplosion-small",
		damage = {
			default = 100,
		},
	},
	
	metalmaker = {
		weaponType		   = "Cannon",
		areaofeffect = 210,
		camerashake = 210,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundstart = "xplolrg4",
		explosiongenerator = "custom:genericbuildingexplosion-medium",
		damage = {
			default = 590,
		},
	},
	
	advmetalmaker = {
		weaponType		   = "Cannon",
		areaofeffect = 320,
		camerashake = 320,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundstart = "xplolrg4",
		explosiongenerator = "custom:genericbuildingexplosion-huge",
		damage = {
			default = 1100,
		},
	},
	
	energystorage = {
		weaponType		   = "Cannon",
		areaofeffect = 400,
		camerashake = 210,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundstart = "xplolrg3",
		explosiongenerator = "custom:genericbuildingexplosion-large",
		damage = {
			default = 880,
		},
	},
	
	advenergystorage = {
		weaponType		   = "Cannon",
		areaofeffect = 480,
		camerashake = 480,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundstart = "xplolrg3",
		explosiongenerator = "custom:genericbuildingexplosion-huge",
		damage = {
			default = 2400,
		},
	},
	
--NUKE EXPLOSIONS--

	smallNukeExplosionGeneric = {
		weaponType		   = "Cannon",
		AreaOfEffect = smallNukeExplosion,
		cameraShake = smallNukeExplosion,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundstart = "xplonuk3",
		explosiongenerator="custom:nukedatbewmsmall",
		damage = {
			default = 2400,
		},
	},

	hugeNukeExplosionGeneric = {
		weaponType		   = "Cannon",
		AreaOfEffect = hugeNukeExplosion,
		cameraShake = hugeNukeExplosion,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundstart = "xplonuk3",
		explosiongenerator="custom:nukedatbewm",
		damage = {
			default = 6500,
		},
	},
	

--NUKE EXPLOSIONS WITH DAMAGE--

	smallNukeExplosionGenericDamage = {
		weaponType		   = "Cannon",
		AreaOfEffect = smallNukeExplosionDamage,
		cameraShake = smallNukeExplosionDamage,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundstart = "xplonuk3",
		explosiongenerator="custom:nukedatbewmsmall",
		damage = {
			default = 2400,
		},
	},

	hugeNukeExplosionGenericDamage = {
		weaponType		   = "Cannon",
		AreaOfEffect = hugeNukeExplosionDamage,
		cameraShake = hugeNukeExplosionDamage,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundstart = "xplonuk3",
		explosiongenerator="custom:nukedatbewm",
		damage = {
			commanders = 2500,
			default = 9500,
		},
	},
	
	commanderNukeExplosionGenericDamage = {
		weaponType		   = "Cannon",
		AreaOfEffect = commanderNukeExplosionDamage,
		cameraShake = commanderNukeExplosionDamage,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundstart = "newboom",
		explosiongenerator="custom:nukedatbewm",
		damage = {
			default = 50000,
		},
	},


--BUILDING DEATHS--

	smallBuildingExplosionGeneric = {
		weaponType		   = "Cannon",
		AreaOfEffect =  180,
		cameraShake = 180,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundstart = "xplosml3",
		explosiongenerator="custom:genericbuildingexplosion-small",
		damage = {
			default = 80,
		},
	},

	mediumBuildingExplosionGeneric = {
		weaponType		   = "Cannon",
		AreaOfEffect =  260,
		cameraShake = 260,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundstart = "xplomed1",
		explosiongenerator="custom:genericbuildingexplosion-medium",
		damage = {
			default = 200,
		},
	},
	
	largeBuildingExplosionGeneric = {
		weaponType		   = "Cannon",
		AreaOfEffect =  340,
		cameraShake = 340,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundstart = "xplolrg3",
		explosiongenerator="custom:genericbuildingexplosion-large",
		damage = {
			default = 600,
		},
	},

	hugeBuildingExplosionGeneric = {
		weaponType		   = "Cannon",
		AreaOfEffect = 420,
		cameraShake = 420,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundstart = "xplolrg4",
		explosiongenerator="custom:genericbuildingexplosion-huge",
		damage = {
			default = 1200,
		},
	},
	
	
--UNIT DEATHS--

	tinyExplosionGeneric = {
		weaponType		   = "Cannon",
		AreaOfEffect = 24,
		cameraShake = 24,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundstart = "xplomed2",
		explosiongenerator="custom:genericunitexplosion-tiny",
		damage = {
			default = 5,
		},
	},

	smallExplosionGeneric = {
		weaponType		   = "Cannon",
		AreaOfEffect = 32,
		cameraShake = 32,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundstart = "xplomed2",
		explosiongenerator="custom:genericunitexplosion-small",
		damage = {
			default = 10,
		},
	},

	mediumExplosionGeneric = {
		weaponType		   = "Cannon",
		AreaOfEffect = 48,
		cameraShake = 48,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundstart = "xplomed2",
		explosiongenerator="custom:genericunitexplosion-medium",
		damage = {
			default = 20,
		},
	},
	
	largeExplosionGeneric = {
		weaponType		   = "Cannon",
		AreaOfEffect = 64,
		cameraShake = 64,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundstart = "xplolrg3",
		explosiongenerator="custom:genericunitexplosion-large",
		damage = {
			default = 40,
		},
	},
	
	hugeExplosionGeneric = {
		weaponType		   = "Cannon",
		AreaOfEffect = 96,
		cameraShake = 96,
		impulseboost = impulseboost,
		impulsefactor = impulsefactor,
		soundstart = "xplolrg4",
		explosiongenerator="custom:genericunitexplosion-huge",
		damage = {
			default = 80,
		},
	},
	
	
}

return lowerkeys(unitDeaths)
