-- UNITDEF -- CORCS --
--------------------------------------------------------------------------------

local unitName = "corcs"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.1,
  bmcode             = 1,
  brakeRate          = 0.1,
  buildCostEnergy    = 2375,
  buildCostMetal     = 260,
  buildDistance      = 250,
  builder            = true,
  buildPic           = [[CORCS.DDS]],
  buildTime          = 5537,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canreclamate       = 1,
  canstop            = 1,
  category           = [[ALL NOTLAND MOBILE NOTSUB SHIP NOWEAPON NOTAIR]],
  collisionVolumeType = [[CylY]],
  collisionVolumeScales = [[33 18 79]],
  collisionVolumeOffsets= [[0 0 0]],
  collisionVolumeTest = 1,
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Tech Level 1]],
  energyMake         = 25,
  energyStorage      = 100,
  energyUse          = 25,
  explodeAs          = [[SMALL_UNITEX]],
  floater            = true,
  footprintX         = 4,
  footprintZ         = 4,
  iconType           = [[sea]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 1150,
  maxVelocity        = 2.3,
  metalMake          = 0.25,
  metalStorage       = 100,
  minWaterDepth      = 15,
  mobilestandorders  = 1,
  movementClass      = [[BOAT4]],
  name               = [[Construction Ship]],
  noAutoFire         = false,
  objectName         = [[CORCS]],
  radarDistance      = 50,
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_UNIT]],
  side               = [[core]],
  sightDistance      = 286,
  smoothAnim         = false,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[CNSTR]],
  terraformSpeed     = 750,
  turnRate           = 626,
  unitname           = [[corcs]],
  waterline          = 3,
  windgenerator      = 0.001,
  workerTime         = 250,
  buildoptions = {
    [[cortide]],
    [[coruwmex]],
    [[corfmkr]],
    [[coreyes]],
    [[coruwms]],
    [[coruwes]],
    [[corsy]],
    [[corasy]],
    [[corfhp]],
    [[csubpen]],
    [[corsonar]],
    [[corfrad]],
    [[corfdrag]],
    [[cordl]],
    [[corfrt]],
    [[corfhlt]],
    [[cortl]],
    [[corplat]],
  },
  sounds = {
    build              = [[nanlath2]],
    canceldestruct     = [[cancel2]],
    repair             = [[repair2]],
    underattack        = [[warning1]],
    working            = [[reclaim1]],
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
    damage             = 690,
    description        = [[Construction Ship Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    footprintX         = 5,
    footprintZ         = 5,
    height             = 4,
    hitdensity         = 100,
    metal              = 169,
    object             = [[CORCS_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 2016,
    description        = [[Construction Ship Heap]],
    energy             = 0,
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 66,
    object             = [[5X5C]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
