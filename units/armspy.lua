-- UNITDEF -- ARMSPY --
--------------------------------------------------------------------------------

local unitName = "armspy"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.24,
  activateWhenBuilt  = true,
  amphibious         = 1,
  bmcode             = 1,
  brakeRate          = 0.2,
  buildCostEnergy    = 8219,
  buildCostMetal     = 128,
  builder            = true,
  buildPic           = [[ARMSPY.DDS]],
  buildTime          = 17631,
  canAssist          = false,
  canGuard           = false,
  canMove            = true,
  canPatrol          = true,
  canreclamate       = 1,
  canRepair          = false,
  canRestore         = false,
  canstop            = 1,
  category           = [[KBOT MOBILE ALL NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  cloakCost          = 50,
  cloakCostMoving    = 100,
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Radar-Invisible Spy Kbot]],
  energyMake         = 5,
  energyStorage      = 0,
  energyUse          = 5,
  footprintX         = 2,
  footprintZ         = 2,
  idleAutoHeal       = 5,
  idleTime           = 1800,
  immunetoparalyzer  = 1,
  maneuverleashlength = 640,
  maxDamage          = 270,
  maxSlope           = 32,
  maxVelocity        = 2.18,
  maxWaterDepth      = 112,
  metalStorage       = 0,
  minCloakDistance   = 75,
  mobilestandorders  = 1,
  movementClass      = [[KBOT2]],
  name               = [[Infiltrator]],
  noAutoFire         = false,
  objectName         = [[ARMSPY]],
  onoffable          = true,
  seismicSignature   = 2,
  selfDestructAs     = [[SPYBOMBX]],
  selfDestructCountdown = 1,
  side               = [[ARM]],
  sightDistance      = 550,
  smoothAnim         = true,
  standingmoveorder  = 1,
  stealth            = true,
  steeringmode       = 2,
  TEDClass           = [[KBOT]],
  turnRate           = 1375,
  unitname           = [[armspy]],
  upright            = true,
  workerTime         = 50,
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
    damage             = 162,
    description        = [[Infiltrator Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 83,
    object             = [[ARMSPY_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 81,
    description        = [[Infiltrator Heap]],
    energy             = 0,
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 33,
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
