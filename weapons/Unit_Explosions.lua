--------------------------------------------------------------------------------
-- These represent both the area of effect and the camerashake amount
local smallExplosion = 60
local smallExplosionImpulseFactor = 0
local mediumExplosion = 120
local mediumExplosionImpulseFactor = 0
local largeExplosion = 240
local largeExplosionImpulseFactor = 0
local hugeExplosion = 350
local hugeExplosionImpulseFactor = 0
local smallNukeExplosion = 450
local smallNukeExplosionImpulseFactor = 0
local hugeNukeExplosion = 750
local hugeNukeExplosionImpulseFactor = 0

local smallNukeExplosionDamage = 500
local smallNukeExplosionDamageImpulseFactor = 0
local hugeNukeExplosionDamage = 1280
local hugeNukeExplosionDamageImpulseFactor = 0
local commanderNukeExplosionDamage = 720
local commanderNukeExplosionDamageImpulseFactor = 0


unitDeaths = {
	
	pyro = {
		weaponType		   = "Cannon",
		areaofeffect = 64,
		explosiongenerator = "custom:genericunitexplosion-large",
		damage = {
			default = 50,
		},
	},
	
	pyroselfd = {
		weaponType		   = "Cannon",
		areaofeffect = 200,
		edgeeffectiveness = 0.5,
		explosiongenerator = "custom:genericunitexplosion-large",
		damage = {
			default = 1000,
		},
	},
	
	nanoboom = {
		weaponType		   = "Cannon",
		areaofeffect = 128,
		edgeeffectiveness = 0.75,
		explosiongenerator = "custom:genericbuildingexplosion-small",
		damage = {
			default = 10,
			nanos = 400,
		},
	},
	
	smallbuilderboom = {
		weaponType		   = "Cannon",
		areaofeffect = 64,
		explosiongenerator = "custom:genericbuildingexplosion-small",
		damage = {
			default = 25,
		},
	},
	
	metalmaker = {
		weaponType		   = "Cannon",
		areaofeffect = 210,
		explosiongenerator = "custom:genericbuildingexplosion-medium",
		damage = {
			default = 590,
		},
	},
	
	advmetalmaker = {
		weaponType		   = "Cannon",
		areaofeffect = 320,
		explosiongenerator = "custom:genericbuildingexplosion-large",
		damage = {
			default = 1100,
		},
	},
	
	energystorage = {
		weaponType		   = "Cannon",
		areaofeffect = 210,
		explosiongenerator = "custom:genericbuildingexplosion-large",
		damage = {
			default = 590,
		},
	},
	
	advenergystorage = {
		weaponType		   = "Cannon",
		areaofeffect = 480,
		explosiongenerator = "custom:genericbuildingexplosion-huge",
		damage = {
			default = 2400,
		},
	},
	
--NUKE EXPLOSIONS--

	smallNukeExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = smallNukeExplosionImpulseFactor,
		AreaOfEffect=smallNukeExplosion,
		explosiongenerator="custom:nukedatbewmsmall",
		cameraShake=smallNukeExplosion,
		damage = {
			default            = 0,
		},
	},

	hugeNukeExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeNukeExplosionImpulseFactor,
		AreaOfEffect=hugeNukeExplosion,
		explosiongenerator="custom:nukedatbewm",
		cameraShake=hugeNukeExplosion,
		damage = {
			default            = 6500,
		},
	},
	

--NUKE EXPLOSIONS WITH DAMAGE--

	smallNukeExplosionGenericDamage = {
		weaponType		   = "Cannon",
		impulseFactor      = smallNukeExplosionDamageImpulseFactor,
		AreaOfEffect=smallNukeExplosionDamage,
		explosiongenerator="custom:nukedatbewmsmall",
		cameraShake=smallNukeExplosionDamage,
		damage = {
			default            = 2400,
		},
	},

	hugeNukeExplosionGenericDamage = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeNukeExplosionDamageImpulseFactor,
		AreaOfEffect=hugeNukeExplosionDamage,
		explosiongenerator="custom:nukedatbewm",
		cameraShake=hugeNukeExplosionDamage,
		damage = {
			commanders = 2500,
			default = 9500,
		},
	},
	
	commanderNukeExplosionGenericDamage = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeNukeExplosionDamageImpulseFactor,
		AreaOfEffect=commanderNukeExplosionDamage,
		explosiongenerator="custom:nukedatbewm",
		cameraShake=commanderNukeExplosionDamage,
		soundstart = "xplonuk3",
		damage = {
			default = 50000,
		},
	},


--BUILDING DEATHS--

	smallBuildingExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericbuildingexplosion-small",
		cameraShake=smallExplosion,
		damage = {
			default            = 0,
		},
	},

	mediumBuildingExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericbuildingexplosion-medium",
		cameraShake=mediumExplosion,
		damage = {
			default            = 0,
		},
	},
	
	largeBuildingExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-large",
		cameraShake=largeExplosion,
		damage = {
			default            = 0,
		},
	},

	hugeBuildingExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-huge",
		cameraShake=hugeExplosion,
		damage = {
			default            = 0,
		},
	},
	
	
	
--UNIT DEATHS--

	smallExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericunitexplosion-small",
		cameraShake=smallExplosion,
		damage = {
			default            = 0,
		},
	},

	mediumExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericunitexplosion-medium",
		cameraShake=mediumExplosion,
		damage = {
			default            = 0,
		},
	},
	
	largeExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:genericunitexplosion-large",
		cameraShake=largeExplosion,
		damage = {
			default            = 0,
		},
	},
	
	hugeExplosionGeneric = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:genericunitexplosion-huge",
		cameraShake=hugeExplosion,
		damage = {
			default            = 0,
		},
	},
	
	
}

return lowerkeys(unitDeaths)
