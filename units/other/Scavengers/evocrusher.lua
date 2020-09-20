-- UNITDEF -- evocrusher --
--------------------------------------------------------------------------------

unitName = "evocrusher"

--------------------------------------------------------------------------------

isUpgraded	= [[0]]

humanName = "Crusher"

objectName = "Units/scavboss/evocrusher.s3o"
script = "Units/scavboss/evocrusher_lus.lua"

tech = [[tech2]]
armortype = [[armored]]
supply = [[4]]

unitDef                    = {
	acceleration                 = 0.05,
	brakeRate                    = 0.05,
	buildCostEnergy              = 0,
	buildCostMetal               = 59,
	builder                      = false,
	buildTime                    = 5,
	buildpic					 = "scavengers/evocrusher.png",
	canAttack                    = true,
	canGuard                     = true,
	canHover                     = true,
	canMove                      = true,
	canPatrol                    = true,
	canstop                      = "1",
	category                     = "ALL HOVER MOBILE WEAPON NOTSUB NOTSHIP NOTAIR SURFACE EMPABLE",
	description                  = [[Main Battle Tank]],
	energyMake                   = 0,
	energyStorage                = 0,
	energyUse                    = 0,
	explodeAs                    = "largeexplosiongeneric",
	footprintX                   = 4,
	footprintZ                   = 4,
	iconType                     = "td_arm_all",
	idleAutoHeal                 = .5,
	idleTime                     = 2200,
	leaveTracks                  = false,
	maxDamage                    = 375,
	maxSlope                     = 26,
	maxVelocity                  = 2.5,
	maxReverseVelocity           = 0.5,
	maxWaterDepth                = 10,
	metalStorage                 = 0,
	movementClass                = "HOVER4",
	name                         = humanName,
	noChaseCategory              = "VTOL",
	objectName                   = objectName,
	script			             = script,
	radarDistance                = 0,
	repairable		             = false,
	selfDestructAs               = "largeExplosionGenericRed",
	side                         = "CORE",
	sightDistance                = 650,
	smoothAnim                   = true,
	stealth			             = true,
	seismicSignature             = 2,
	transportbyenemy             = false;
	--  turnInPlace              = false,
	--  turnInPlaceSpeedLimit    = 2.8,
	turnInPlace                  = true,
	turnRate                     = 500,
	--  turnrate                 = 350,
	unitname                     = unitName,
	upright                      = true,
	workerTime                   = 0,
	sfxtypes                     = { 
		pieceExplosionGenerators = { 
			"deathceg3", 
			"deathceg4", 
		}, 

		explosiongenerators      = {
			"custom:gdhcannon",
			"custom:dirt",
			"custom:blacksmoke",
		},
	},
	sounds                       = {
		underattack              = "other/unitsunderattack1",
		ok                       = {
			"hovlgok1",
		},
		select                   = {
			"hovlgsl1",
		},
	},
	weapons                      = {
		[1]                      = {
			def                  = "heavytankweapon",
			--onlyTargetCategory   = "",
			badTargetCategory    = "VTOL",
		},
	},
	customParams                 = {
		isupgraded			  	 = isUpgraded,
		unittype				 = "mobile",
		canbetransported 		 = "true",
		needed_cover             = 3,
		death_sounds             = "generic",
		RequireTech              = tech,
		armortype                = armortype,
		nofriendlyfire	         = "1",
		supply_cost              = supply,
		normaltex                = "unittextures/evotexnormals.dds", 
		buckettex                = "unittextures/evotexbucket.dds",
		factionname	             = "ateran",
		corpse                   = "energycore",
	}
}

weaponDefs                 = {
	heavytankweapon              = {
		AreaOfEffect             = 0,
		avoidFriendly            = true,
		avoidFeature             = false,
		collideFriendly          = true,
		collideFeature           = true,	
		cegTag                   = "antiassualtshot2",
		explosionGenerator       = "custom:genericshellexplosion-medium",
		energypershot            = 0,
		impulseFactor            = 0,
		interceptedByShieldType  = 4,
		name                     = unitName .. "Weapon",
		range                    = 650,
		reloadtime               = 1,
		size					 = 8,
		weaponType		         = "Cannon",
		soundHit                 = "weapons/bimpact3.wav",
		soundStart               = "weapons/triotfire.wav",
		tolerance                = 2000,
		turret                   = true,
		weaponVelocity           = 1000,
		customparams             = {
			isupgraded			 = isUpgraded,			
			damagetype		     = "eheavytank3",  
		},      
		damage                   = {
			default              = 150,
		},
	},
}
	
unitDef.weaponDefs = weaponDefs
--------------------------------------------------------------------------------

return lowerkeys({ [unitName]    = unitDef })

--------------------------------------------------------------------------------
