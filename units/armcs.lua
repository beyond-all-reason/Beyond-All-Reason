-- UNITDEF -- ARMCS --
--------------------------------------------------------------------------------

local unitName = "armcs"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.1,
  bmcode             = 1,
  brakeRate          = 0.1,
  buildCostEnergy    = 2130,
  buildCostMetal     = 255,
  buildDistance      = 250,
  builder            = true,
  buildPic           = [[ARMCS.DDS]],
  buildTime          = 5121,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canreclamate       = 1,
  canstop            = 1,
  category           = [[ALL NOTLAND MOBILE NOTSUB NOWEAPON SHIP NOTAIR]],
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
  maxDamage          = 1105,
  maxVelocity        = 2.53,
  metalMake          = 0.25,
  metalStorage       = 100,
  minWaterDepth      = 15,
  mobilestandorders  = 1,
  movementClass      = [[BOAT4]],
  name               = [[Construction Ship]],
  noAutoFire         = false,
  objectName         = [[ARMCS]],
  radarDistance      = 50,
  seismicSignature   = 0,
  selfDestructAs     = [[SMALL_UNIT]],
  side               = [[arm]],
  sightDistance      = 291.2,
  smoothAnim         = true,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[SHIP]],
  terraformSpeed     = 750,
  turnRate           = 648,
  unitname           = [[armcs]],
  waterline          = 4,
  workerTime         = 250,
  buildoptions = {
    [[armtide]],
    [[armuwmex]],
    [[armfmkr]],
    [[armeyes]],
    [[armuwms]],
    [[armuwes]],
    [[armsy]],
    [[armasy]],
    [[armfhp]],
    [[asubpen]],
    [[armsonar]],
    [[armfrad]],
    [[armfdrag]],
    [[armdl]],
    [[armfrt]],
    [[armfhlt]],
    [[armtl]],
    [[armplat]],
  },
  sounds = {
    build              = [[nanlath1]],
    canceldestruct     = [[cancel2]],
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
    damage             = 663,
    description        = [[Construction Ship Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    footprintX         = 5,
    footprintZ         = 5,
    height             = 4,
    hitdensity         = 100,
    metal              = 166,
    object             = [[ARMCS_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 716,
    description        = [[Construction Ship Heap]],
    energy             = 0,
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 59,
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
