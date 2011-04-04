-- UNITDEF -- ARMSTUMP --
--------------------------------------------------------------------------------

local unitName = "armstump"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.0287,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.0298,
  buildCostEnergy    = 1921,
  buildCostMetal     = 201,
  builder            = false,
  buildPic           = [[ARMSTUMP.DDS]],
  buildTime          = 2904,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL TANK MOBILE WEAPON NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Medium Assault Tank]],
  energyMake         = 0.6,
  energyStorage      = 0,
  energyUse          = 0.6,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 2,
  footprintZ         = 2,
  iconType           = [[type1]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  leaveTracks        = true,
  maneuverleashlength = 640,
  maxDamage          = 1530,
  maxSlope           = 10,
  maxVelocity        = 2.9,
  maxWaterDepth      = 12,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[TANK2]],
  name               = [[Stumpy]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[ARMSTUMP]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 325,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[TANK]],
  trackOffset        = 3,
  trackStrength      = 6,
  trackStretch       = 1,
  trackType          = [[StdTank]],
  trackWidth         = 24,
  turnRate           = 484,
  unitname           = [[armstump]],
  workerTime         = 0,
  sounds = {
    canceldestruct     = [[cancel2]],
    underattack        = [[warning1]],
    cant = {
      [[cantdo4]],
    },
    count = {
      [[count6]],
      [[count5]],
      [[count4]],
      [[count3]],
      [[count2]],
      [[count1]],
    },
    ok = {
      [[tarmmove]],
    },
    select = {
      [[tarmsel]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[ARM_LIGHTCANNON]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  ARM_LIGHTCANNON = {
    areaOfEffect       = 48,
    avoidFeature       = false,
    ballistic          = true,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:LIGHT_PLASMA]],
    fireStarter        = 100,
    gravityaffected    = [[true]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    name               = [[LightCannon]],
    noSelfDamage       = true,
    range              = 350,
    reloadtime         = 1.19,
    renderType         = 4,
    soundHit           = [[xplosml3]],
    soundStart         = [[canlite3]],
    startsmoke         = 1,
    turret             = true,
    weaponType         = [[Cannon]],
    weaponVelocity     = 225,
    damage = {
      default            = 97,
      gunships           = 18,
      hgunships          = 18,
      l1bombers          = 18,
      l1fighters         = 18,
      l1subs             = 5,
      l2bombers          = 18,
      l2fighters         = 18,
      l2subs             = 5,
      l3subs             = 5,
      vradar             = 18,
      vtol               = 18,
      vtrans             = 18,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 1056,
    description        = [[Stumpy Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 152,
    object             = [[ARMSTUMP_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 528,
    description        = [[Stumpy Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 61,
    object             = [[2X2D]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
