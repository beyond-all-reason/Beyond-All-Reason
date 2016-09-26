--------------------------------------------------------------------------------
-- These represent both the area of effect and the camerashake amount
local smallExplosion = 200
local smallExplosionImpulseFactor = 0
local mediumExplosion = 400
local mediumExplosionImpulseFactor = 0
local largeExplosion = 600
local largeExplosionImpulseFactor = 0
local hugeExplosion = 1000
local hugeExplosionImpulseFactor = 0
local smallNukeExplosion = 750
local smallNukeExplosionImpulseFactor = 0
local hugeNukeExplosion = 1000
local hugeNukeExplosionImpulseFactor = 0
local smallNukeExplosionDamage = 500
local smallNukeExplosionDamageImpulseFactor = 0
local hugeNukeExplosionDamage = 1280
local hugeNukeExplosionDamageImpulseFactor = 0
local giganticNukeExplosionDamage = 1920
local giganticNukeExplosionDamageImpulseFactor = 0
local commanderNukeExplosionDamage = 720
local commanderNukeExplosionDamageImpulseFactor = 0

unitDeaths = {

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
			default            = 0,
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
	
	giganticNukeExplosionGenericDamage = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeNukeExplosionDamageImpulseFactor,
		AreaOfEffect=giganticNukeExplosionDamage,
		explosiongenerator="custom:nukedatbewm",
		cameraShake=giganticNukeExplosionDamage,
		damage = {
			commanders = 2500,
			default = 11500,
		},
	},
	
	commanderNukeExplosionGenericDamage = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeNukeExplosionDamageImpulseFactor,
		AreaOfEffect=commanderNukeExplosionDamage,
		explosiongenerator="custom:nukedatbewm",
		cameraShake=commanderNukeExplosionDamage,
		damage = {
			default = 50000,
		},
	},

--BUILDING DEATHS--

--Orange

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
	
--blue

	smallBuildingExplosionGenericBlue = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericbuildingexplosion-small-blue",
		cameraShake=smallExplosion,
		damage = {
			default            = 0,
		},
	},

	mediumBuildingExplosionGenericBlue = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericbuildingexplosion-medium-blue",
		cameraShake=mediumExplosion,
		damage = {
			default            = 0,
		},
	},
	
	largeBuildingExplosionGenericBlue = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-large-blue",
		cameraShake=largeExplosion,
		damage = {
			default            = 0,
		},
	},

	hugeBuildingExplosionGenericBlue = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-huge-Blue",
		cameraShake=hugeExplosion,
		damage = {
			default            = 0,
		},
	},
	
--blueEMP

	smallBuildingExplosionGenericBlueEMP = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericbuildingexplosion-small-blue-emp",
		cameraShake=smallExplosion,
		damage = {
			default            = 0,
		},
	},

	mediumBuildingExplosionGenericBlueEMP = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericbuildingexplosion-medium-blue-emp",
		cameraShake=mediumExplosion,
		damage = {
			default            = 0,
		},
	},
	
	largeBuildingExplosionGenericBlueEMP = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-large-blue-emp",
		cameraShake=largeExplosion,
		damage = {
			default            = 0,
		},
	},

	hugeBuildingExplosionGenericBlueEMP = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-huge-Blue-emp",
		cameraShake=hugeExplosion,
		damage = {
			default            = 0,
		},
	},
	
--green

	smallBuildingExplosionGenericGreen = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericbuildingexplosion-small-green",
		cameraShake=smallExplosion,
		damage = {
			default            = 0,
		},
	},

	mediumBuildingExplosionGenericGreen = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericbuildingexplosion-medium-green",
		cameraShake=mediumExplosion,
		damage = {
			default            = 0,
		},
	},
	
	largeBuildingExplosionGenericGreen = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-large-green",
		cameraShake=largeExplosion,
		damage = {
			default            = 0,
		},
	},

	hugeBuildingExplosionGenericGreen = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-huge-green",
		cameraShake=hugeExplosion,
		damage = {
			default            = 0,
		},
	},

--purple

	smallBuildingExplosionGenericPurple = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericbuildingexplosion-small-purple",
		cameraShake=smallExplosion,
		damage = {
			default            = 0,
		},
	},

	mediumBuildingExplosionGenericPurple = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericbuildingexplosion-medium-purple",
		cameraShake=mediumExplosion,
		damage = {
			default            = 0,
		},
	},
	
	largeBuildingExplosionGenericPurple = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-large-purple",
		cameraShake=largeExplosion,
		damage = {
			default            = 0,
		},
	},

	hugeBuildingExplosionGenericPurple = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-huge-purple",
		cameraShake=hugeExplosion,
		damage = {
			default            = 0,
		},
	},
	
--red

	smallBuildingExplosionGenericRed = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericbuildingexplosion-small-red",
		cameraShake=smallExplosion,
		damage = {
			default            = 0,
		},
	},

	mediumBuildingExplosionGenericRed = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericbuildingexplosion-medium-red",
		cameraShake=mediumExplosion,
		damage = {
			default            = 0,
		},
	},
	
	largeBuildingExplosionGenericRed = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-large-red",
		cameraShake=largeExplosion,
		damage = {
			default            = 0,
		},
	},

	hugeBuildingExplosionGenericRed = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-huge-red",
		cameraShake=hugeExplosion,
		damage = {
			default            = 0,
		},
	},
	
--white

	smallBuildingExplosionGenericWhite = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericbuildingexplosion-small-white",
		cameraShake=smallExplosion,
		damage = {
			default            = 0,
		},
	},

	mediumBuildingExplosionGenericWhite = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericbuildingexplosion-medium-white",
		cameraShake=mediumExplosion,
		damage = {
			default            = 0,
		},
	},
	
	largeBuildingExplosionGenericWhite = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-large-white",
		cameraShake=largeExplosion,
		damage = {
			default            = 0,
		},
	},

	hugeBuildingExplosionGenericWhite = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:genericbuildingexplosion-huge-white",
		cameraShake=hugeExplosion,
		damage = {
			default            = 0,
		},
	},
	
	
--UNIT DEATHS--

--Orange

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
	
--Blue

	smallExplosionGenericBlue = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericunitexplosion-small-blue",
		cameraShake=smallExplosion,
		damage = {
			default            = 0,
		},
	},

	mediumExplosionGenericBlue = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericunitexplosion-medium-blue",
		cameraShake=mediumExplosion,
		damage = {
			default            = 0,
		},
	},
	
	largeExplosionGenericBlue = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:genericunitexplosion-large-blue",
		cameraShake=largeExplosion,
		damage = {
			default            = 0,
		},
	},
	
	hugeExplosionGenericBlue = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:genericunitexplosion-huge-blue",
		cameraShake=hugeExplosion,
		damage = {
			default            = 0,
		},
	},
	
--Green

	smallExplosionGenericGreen = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericunitexplosion-small-green",
		cameraShake=smallExplosion,
		damage = {
			default            = 0,
		},
	},

	mediumExplosionGenericGreen = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericunitexplosion-medium-green",
		cameraShake=mediumExplosion,
		damage = {
			default            = 0,
		},
	},
	
	largeExplosionGenericGreen = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:genericunitexplosion-large-green",
		cameraShake=largeExplosion,
		damage = {
			default            = 0,
		},
	},
	
	hugeExplosionGenericGreen = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:genericunitexplosion-huge-green",
		cameraShake=hugeExplosion,
		damage = {
			default            = 0,
		},
	},
	
--Purple

	smallExplosionGenericPurple = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericunitexplosion-small-purple",
		cameraShake=smallExplosion,
		damage = {
			default            = 0,
		},
	},

	mediumExplosionGenericPurple = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericunitexplosion-medium-purple",
		cameraShake=mediumExplosion,
		damage = {
			default            = 0,
		},
	},
	
	largeExplosionGenericPurple = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:genericunitexplosion-large-purple",
		cameraShake=largeExplosion,
		damage = {
			default            = 0,
		},
	},
	
	hugeExplosionGenericPurple = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:genericunitexplosion-huge-purple",
		cameraShake=hugeExplosion,
		damage = {
			default            = 0,
		},
	},
	
	
--Red

	smallExplosionGenericRed = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericunitexplosion-small-red",
		cameraShake=smallExplosion,
		damage = {
			default            = 0,
		},
	},

	mediumExplosionGenericRed = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericunitexplosion-medium-red",
		cameraShake=mediumExplosion,
		damage = {
			default            = 0,
		},
	},
	
	largeExplosionGenericRed = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:genericunitexplosion-large-red",
		cameraShake=largeExplosion,
		damage = {
			default            = 0,
		},
	},
	
	hugeExplosionGenericRed = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:genericunitexplosion-huge-red",
		cameraShake=hugeExplosion,
		damage = {
			default            = 0,
		},
	},
	
	
--White

	smallExplosionGenericWhite = {
		weaponType		   = "Cannon",
		impulseFactor      = smallExplosionImpulseFactor,
		AreaOfEffect=smallExplosion,
		explosiongenerator="custom:genericunitexplosion-small-white",
		cameraShake=smallExplosion,
		damage = {
			default            = 0,
		},
	},

	mediumExplosionGenericWhite = {
		weaponType		   = "Cannon",
		impulseFactor      = mediumExplosionImpulseFactor,
		AreaOfEffect=mediumExplosion,
		explosiongenerator="custom:genericunitexplosion-medium-white",
		cameraShake=mediumExplosion,
		damage = {
			default            = 0,
		},
	},
	
	largeExplosionGenericWhite = {
		weaponType		   = "Cannon",
		impulseFactor      = largeExplosionImpulseFactor,
		AreaOfEffect=largeExplosion,
		explosiongenerator="custom:genericunitexplosion-large-white",
		cameraShake=largeExplosion,
		damage = {
			default            = 0,
		},
	},
	
	hugeExplosionGenericWhite = {
		weaponType		   = "Cannon",
		impulseFactor      = hugeExplosionImpulseFactor,
		AreaOfEffect=hugeExplosion,
		explosiongenerator="custom:genericunitexplosion-huge-white",
		cameraShake=hugeExplosion,
		damage = {
			default            = 0,
		},
	},
}

return lowerkeys(unitDeaths)
