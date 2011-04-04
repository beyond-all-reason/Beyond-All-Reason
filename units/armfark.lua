-- UNITDEF -- ARMFARK --
--------------------------------------------------------------------------------

local unitName = "armfark"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.216,
  autoHeal           = 5,
  bmcode             = 1,
  brakeRate          = 0.75,
  buildCostEnergy    = 2793,
  buildCostMetal     = 201,
  buildDistance      = 128,
  builder            = true,
  buildPic           = [[ARMFARK.DDS]],
  buildTime          = 4302,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canreclamate       = 1,
  canstop            = 1,
  category           = [[KBOT MOBILE ALL NOTSUB NOWEAPON NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Fast Assist/Repair Kbot]],
  energyMake         = 12,
  energyStorage      = 25,
  energyUse          = 12,
  explodeAs          = [[BIG_UNITEX]],
  footprintX         = 2,
  footprintZ         = 2,
  idleAutoHeal       = 5,
  idleTime           = 90,
  maneuverleashlength = 640,
  maxDamage          = 300,
  maxSlope           = 14,
  maxVelocity        = 2.64,
  maxWaterDepth      = 22,
  metalMake          = 0.12,
  metalStorage       = 25,
  mobilestandorders  = 1,
  movementClass      = [[KBOT2]],
  name               = [[Fark]],
  noAutoFire         = false,
  objectName         = [[ARMFARK]],
  radarDistance      = 50,
  repairSpeed        = 150,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[arm]],
  sightDistance      = 377,
  smoothAnim         = true,
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[KBOT]],
  terraformSpeed     = 360,
  turnRate           = 1100,
  unitname           = [[armfark]],
  upright            = true,
  workerTime         = 120,
  buildoptions = {
    [[armsolar]],
    [[armwin]],
    [[armmex]],
    [[armmakr]],
    [[armeyes]],
    [[armmark]],
    [[armaser]],
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
      [[kbarmmov]],
    },
    select = {
      [[kbarmsel]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 120,
    description        = [[Fark Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 131,
    object             = [[ARMFARK_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 60,
    description        = [[Fark Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 52,
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
