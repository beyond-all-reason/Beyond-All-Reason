-- UNITDEF -- ARMTSHIP --
--------------------------------------------------------------------------------

local unitName = "armtship"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.067,
  badTargetCategory  = [[VTOL]],
  bmcode             = 1,
  brakeRate          = 0.09,
  buildAngle         = 16384,
  buildCostEnergy    = 4639,
  buildCostMetal     = 919,
  builder            = false,
  buildPic           = [[ARMTSHIP.DDS]],
  buildTime          = 14538,
  canAttack          = false,
  canGuard           = true,
  canload            = 1,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND MOBILE WEAPON NOTSUB SHIP NOTAIR]],
  collisionVolumeType = [[CylY]],
  collisionVolumeScales = [[60 80 120]],
  collisionVolumeOffsets= [[0 -2 -4]],
  collisionVolumeTest = 1,
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Armored Transport]],
  energyMake         = 0.3,
  energyStorage      = 0,
  energyUse          = 0.3,
  explodeAs          = [[BIG_UNITEX]],
  firestandorders    = 1,
  floater            = true,
  footprintX         = 5,
  footprintZ         = 5,
  iconType           = [[sea]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 11010,
  maxVelocity        = 3.34,
  metalStorage       = 0,
  minWaterDepth      = 12,
  mobilestandorders  = 1,
  movementClass      = [[BOAT5]],
  name               = [[Hulk]],
  noAutoFire         = false,
  noChaseCategory    = [[ALL]],
  objectName         = [[ARMTSHIP]],
  scale              = 0.5,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[ARM]],
  sightDistance      = 325,
  smoothAnim         = false,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[SHIP]],
  transportCapacity  = 40,
  transportSize      = 4,
  turnRate           = 361,
  unitname           = [[armtship]],
  waterline          = 13,
  windgenerator      = 0.001,
  workerTime         = 0,
  wpri_badtargetcategory = [[VTOL]],
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
      [[sharmmov]],
    },
    select = {
      [[sharmsel]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 6606,
    description        = [[Hulk Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    footprintX         = 5,
    footprintZ         = 5,
    height             = 4,
    hitdensity         = 100,
    metal              = 597,
    object             = [[ARMTSHIP_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 2016,
    description        = [[Hulk Heap]],
    energy             = 0,
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 209,
    object             = [[5X5A]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
