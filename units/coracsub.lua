-- UNITDEF -- CORACSUB --
--------------------------------------------------------------------------------

local unitName = "coracsub"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.035,
  bmcode             = 1,
  brakeRate          = 0.212,
  buildCostEnergy    = 7911,
  buildCostMetal     = 690,
  buildDistance      = 300,
  builder            = true,
  buildPic           = [[CORACSUB.DDS]],
  buildTime          = 17228,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canreclamate       = 1,
  canstop            = 1,
  category           = [[ALL UNDERWATER MOBILE NOTLAND NOWEAPON NOTAIR]],
  collisionVolumeType = [[Ell]],
  collisionVolumeScales = [[40 11 80]],
  collisionVolumeOffsets = [[0 0 0]],
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
  maxDamage          = 370,
  maxVelocity        = 2.07,
  metalMake          = 0.3,
  metalStorage       = 150,
  minWaterDepth      = 20,
  mobilestandorders  = 1,
  movementClass      = [[UBOAT3]],
  name               = [[Advanced Construction Sub]],
  noAutoFire         = false,
  objectName         = [[CORACSUB]],
  radarDistance      = 50,
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_UNIT]],
  side               = [[core]],
  sightDistance      = 156,
  smoothAnim         = false,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[SHIP]],
  terraformSpeed     = 900,
  turnRate           = 364,
  unitname           = [[coracsub]],
  waterline          = 30,
  workerTime         = 300,
  buildoptions = {
    [[coruwfus]],
    [[coruwmme]],
    [[coruwmmm]],
    [[coruwadves]],
    [[coruwadvms]],
    [[corfatf]],
    [[corplat]],
    [[corsy]],
    [[corasy]],
    [[csubpen]],
    [[corason]],
    [[corenaa]],
    [[coratl]],
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
      [[sucormov]],
    },
    select = {
      [[sucorsel]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = false,
    category           = [[corpses]],
    damage             = 222,
    description        = [[Advanced Construction Sub Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    footprintX         = 4,
    footprintZ         = 4,
    height             = 20,
    hitdensity         = 100,
    metal              = 449,
    object             = [[CORACSUB_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 716,
    description        = [[Advanced Construction Sub Heap]],
    energy             = 0,
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 183,
    object             = [[4X4C]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
