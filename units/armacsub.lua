-- UNITDEF -- ARMACSUB --
--------------------------------------------------------------------------------

local unitName = "armacsub"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.038,
  bmcode             = 1,
  brakeRate          = 0.25,
  buildCostEnergy    = 7568,
  buildCostMetal     = 695,
  buildDistance      = 300,
  builder            = true,
  buildPic           = [[ARMACSUB.DDS]],
  buildTime          = 16565,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canreclamate       = 1,
  canstop            = 1,
  category           = [[UNDERWATER ALL NOTLAND MOBILE NOWEAPON NOTAIR]],
  collisionVolumeType = [[Ell]],
  collisionVolumeScales = [[41 22 79]],
  collisionVolumeOffsets = [[0 0 -1]],
  collisionVolumeTest = 1,
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Tech Level 2]],
  energyMake         = 30,
  energyStorage      = 150,
  energyUse          = 30,
  explodeAs          = [[SMALL_UNITEX]],
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[sea]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  maneuverleashlength = 640,
  maxDamage          = 360,
  maxVelocity        = 2.3,
  metalMake          = 0.3,
  metalStorage       = 150,
  minWaterDepth      = 20,
  mobilestandorders  = 1,
  movementClass      = [[UBOAT3]],
  name               = [[Advanced Construction Sub]],
  noAutoFire         = false,
  objectName         = [[ARMACSUB]],
  radarDistance      = 50,
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_UNIT]],
  side               = [[arm]],
  sightDistance      = 156,
  smoothAnim         = true,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[SHIP]],
  terraformSpeed     = 900,
  turnRate           = 382,
  unitname           = [[armacsub]],
  waterline          = 35,
  workerTime         = 300,
  buildoptions = {
    [[armuwfus]],
    [[armuwmme]],
    [[armuwmmm]],
    [[armuwadves]],
    [[armuwadvms]],
    [[armfatf]],
    [[armplat]],
    [[armsy]],
    [[armasy]],
    [[asubpen]],
    [[armason]],
    [[armfflak]],
    [[armatl]],
  },
  sounds = {
    build              = [[nanlath1]],
    canceldestruct     = [[cancel2]],
    capture            = [[capture1]],
    repair             = [[repair1]],
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
      [[suarmmov]],
    },
    select = {
      [[suarmsel]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 216,
    description        = [[Advanced Construction Sub Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    footprintX         = 4,
    footprintZ         = 4,
    height             = 20,
    hitdensity         = 100,
    metal              = 452,
    object             = [[ARMACSUB_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 2016,
    description        = [[Advanced Construction Sub Heap]],
    energy             = 0,
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 207,
    object             = [[2X2A]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
