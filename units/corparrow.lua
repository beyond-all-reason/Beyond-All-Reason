-- UNITDEF -- CORPARROW --
--------------------------------------------------------------------------------

local unitName = "corparrow"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.015,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.0715,
  buildCostEnergy    = 26854,
  buildCostMetal     = 988,
  builder            = false,
  buildPic           = [[CORPARROW.DDS]],
  buildTime          = 22181,
  canAttack          = true,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL TANK PHIB WEAPON NOTSUB NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Very Heavy Amphibious Tank]],
  energyMake         = 2.1,
  energyStorage      = 0,
  energyUse          = 2.1,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  footprintX         = 3,
  footprintZ         = 3,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  leaveTracks        = true,
  maneuverleashlength = 640,
  maxDamage          = 5700,
  maxSlope           = 12,
  maxVelocity        = 1.95,
  maxWaterDepth      = 255,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[ATANK3]],
  name               = [[Poison Arrow]],
  noAutoFire         = false,
  noChaseCategory    = [[VTOL]],
  objectName         = [[CORPARROW]],
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 385,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[TANK]],
  trackOffset        = -6,
  trackStrength      = 10,
  trackStretch       = 1,
  trackType          = [[StdTank]],
  trackWidth         = 45,
  turnRate           = 400,
  unitname           = [[corparrow]],
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
      [[tcormove]],
    },
    select = {
      [[tcorsel]],
    },
  },
  weapons = {
    [1]  = {
      badTargetCategory  = [[VTOL]],
      def                = [[CORE_PARROW]],
    },
  },
}


--------------------------------------------------------------------------------

local weaponDefs = {
  CORE_PARROW = {
    areaOfEffect       = 160,
    ballistic          = true,
    craterBoost        = 0,
    craterMult         = 0,
    explosionGenerator = [[custom:FLASH96]],
    gravityaffected    = [[true]],
    impulseBoost       = 0.123,
    impulseFactor      = 0.123,
    name               = [[PoisonArrowCannon]],
    noSelfDamage       = true,
    range              = 575,
    reloadtime         = 1.8,
    renderType         = 4,
    soundHit           = [[xplomed1]],
    soundStart         = [[largegun]],
    startsmoke         = 1,
    turret             = true,
    weaponType         = [[Cannon]],
    weaponVelocity     = 300,
    damage = {
      default            = 370,
      gunships           = 60,
      hgunships          = 60,
      l1bombers          = 60,
      l1fighters         = 60,
      l1subs             = 5,
      l2bombers          = 60,
      l2fighters         = 60,
      l2subs             = 5,
      l3subs             = 5,
      vradar             = 60,
      vtol               = 60,
      vtrans             = 60,
    },
  },
}
unitDef.weaponDefs = weaponDefs


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 3420,
    description        = [[Poison Arrow Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 9,
    hitdensity         = 100,
    metal              = 642,
    object             = [[CORPARROW_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[all]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 1710,
    description        = [[Poison Arrow Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    hitdensity         = 100,
    metal              = 257,
    object             = [[3X3A]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[all]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
