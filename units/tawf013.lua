-- UNITDEF -- TAWF013 --
--------------------------------------------------------------------------------

local unitName = "tawf013"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.0154,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.0154,
  buildCostEnergy    = 2016,
  buildCostMetal     = 142,
  builder            = false,
  buildPic           = [[TAWF013.DDS]],
  buildTime          = 2998,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL TANK WEAPON NOTSUB NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Light Artillery Vehicle]],
  energyMake         = 1,
  energyStorage      = 0,
  energyUse          = 1,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  highTrajectory     = 1,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  leaveTracks        = true,
  maneuverleashlength = 640,
  maxDamage          = 530,
  maxSlope           = 15,
  maxVelocity        = 1.958,
  maxWaterDepth      = 8,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[TANK3]],
  name               = [[Shellshocker]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[TAWF013]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 364,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[TANK]],
  trackOffset        = 6,
  trackStrength      = 5,
  trackStretch       = 1,
  trackType          = [[StdTank]],
  trackWidth         = 30,
  turnRate           = 393.8,
  unitname           = [[tawf013]],
  workerTime         = 0,
  customparams = {
    canareaattack      = 1,
  },
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
      def                = [[TAWF113_WEAPON]],
      mainDir            = [[0 0 1]],
      maxAngleDif        = 180,
      onlyTargetCategory = [[NOTAIR]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  TAWF113_WEAPON = {
    accuracy           = 250,
    areaOfEffect       = 105,
    ballistic          = true,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:FLASH4]],
    gravityaffected    = [[true]],
    hightrajectory     = 1,
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    name               = [[LightArtillery]],
    noSelfDamage       = true,
    range              = 710,
    reloadtime         = 3,
    renderType         = 4,
    soundHit           = [[TAWF113b]],
    soundStart         = [[TAWF113a]],
    startsmoke         = 1,
    turret             = true,
    weaponType         = [[Cannon]],
    weaponVelocity     = 370,
    damage = {
      default            = 130,
      gunships           = 13,
      hgunships          = 13,
      l1bombers          = 13,
      l1fighters         = 13,
      l1subs             = 5,
      l2bombers          = 13,
      l2fighters         = 13,
      l2subs             = 5,
      l3subs             = 5,
      vradar             = 13,
      vtol               = 13,
      vtrans             = 13,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 318,
    description        = [[Shellshocker Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 24,
    hitdensity         = 100,
    metal              = 92,
    object             = [[TAWF013_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 159,
    description        = [[Shellshocker Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 4,
    hitdensity         = 100,
    metal              = 37,
    object             = [[3X3A]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
