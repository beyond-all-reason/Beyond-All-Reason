-- the meteor was made by modifying the roost, from chickens 
unitDef = {
  unitname          = "meteor",
  name              = "meteor",
  description       = "Falls out of the sky and kills you",
  acceleration      = 0,
  activateWhenBuilt = true,
  bmcode            = "0",
  brakeRate         = 0,
  buildCostEnergy   = 1,
  buildCostMetal    = 1,
  builder           = false,
  buildTime         = 1,
  category          = "NOTAIR NOTSUB NOTSHIP NOTHOVER ALL SURFACE",
  explodeAs         = "",
  footprintX        = 2,
  footprintZ        = 2,
  iconType          = "special",
  idleAutoHeal      = 0,
  idleTime          = 0,
  autoHeal			= 0,
  levelGround       = false,
  mass              = 165.75,
  maxDamage         = 1, --explodes on impact (destroyed by its own weapon) 
  maxVelocity       = 0,
  seismicSignature  = 4,
  noAutoFire        = false,
  objectName        = "meteor.s3o",
  selfDestructAs    = "",
  
  sfxtypes          = {

    explosiongenerators = {
      --"custom:dirt2",
      --"custom:dirt3",
    },

  },

  side              = "CORE", 
  sightDistance     = 450,
  radardistance     = 900,
  smoothAnim        = true,
  TEDClass          = "ENERGY",
  turnRate          = 0,
  upright           = false,
  waterline         = 0,
  workerTime        = 0,
  yardMap           = "ooooooooo",
  collisionVolumeType = "box",
  collisionVolumeOffsets = "0 0 0",
  collisionVolumeScales = "56 11 56",
  
  weapons             = {

    {
      def                = "WEAPON",
    },

  },

  weaponDefs          = {

    WEAPON = {
      name = "Asteroid",
	  rendertype=1,
	  lineofsight=0,
	  turret=1,

	  --model = "greyrock2.s3o",

	  range=29999,
	  reloadtime=5.0,
	  weapontimer=10,
	  weaponvelocity=2000,
	  startvelocity=2000,
	  weaponacceleration=120,
	  edgeeffectiveness=0.6,
	  areaofeffect=450,
	  metalpershot=0,
	  wobble=0,
      craterBoost             = 0,
      craterMult              = 0,

	  soundhit="xplonuk4",
	  explosionGenerator      = "custom:meteor_explosion",

	  firestarter=70,
	  smokedelay=0.1,
	  selfprop=1,
	  smoketrail=1,
	  flighttime=100,

	  startsmoke=1,
	  CollideFriendly=1,
	  cegTag="ASTEROIDTRAIL_Expl",

      damage = {
        default = 700,
        vtol = 2500,
        commanders = 10,
    },

    },
  },

  featureDefs       = {
  },

}

return lowerkeys({ meteor = unitDef })
