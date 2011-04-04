-- UNITDEF -- CORTSHIP --
--------------------------------------------------------------------------------

local unitName = "cortship"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.062,
  bmcode             = 1,
  brakeRate          = 0.085,
  buildAngle         = 16384,
  buildCostEnergy    = 4786,
  buildCostMetal     = 887,
  builder            = false,
  buildPic           = [[CORTSHIP.DDS]],
  buildTime          = 13663,
  canAttack          = false,
  canGuard           = true,
  canload            = 1,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL NOTLAND MOBILE WEAPON SHIP NOTSUB NOTAIR]],
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
  maxDamage          = 11420,
  maxVelocity        = 3.22,
  metalStorage       = 0,
  minWaterDepth      = 12,
  mobilestandorders  = 1,
  movementClass      = [[BOAT5]],
  name               = [[Envoy]],
  noAutoFire         = false,
  noChaseCategory    = [[ALL]],
  objectName         = [[CORTSHIP]],
  scale              = 0.5,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 325,
  smoothAnim         = true,
  standingfireorder  = 2,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[SHIP]],
  transportCapacity  = 40,
  transportSize      = 4,
  turnRate           = 373,
  unitname           = [[cortship]],
  waterline          = 6,
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
      [[shcormov]],
    },
    select = {
      [[shcorsel]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 6852,
    description        = [[Envoy Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    footprintX         = 5,
    footprintZ         = 5,
    height             = 4,
    hitdensity         = 100,
    metal              = 577,
    object             = [[CORTSHIP_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 2016,
    description        = [[Envoy Heap]],
    energy             = 0,
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 291,
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
