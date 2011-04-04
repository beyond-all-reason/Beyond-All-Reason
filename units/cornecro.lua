-- UNITDEF -- CORNECRO --
--------------------------------------------------------------------------------

local unitName = "cornecro"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.2,
  bmcode             = 1,
  brakeRate          = 0.25,
  buildCostEnergy    = 1400,
  buildCostMetal     = 102,
  buildDistance      = 128,
  builder            = true,
  buildPic           = [[CORNECRO.DDS]],
  buildTime          = 2400,
  canAssist          = false,
  canMove            = true,
  canPatrol          = true,
  canreclamate       = 1,
  canResurrect       = true,
  canstop            = 1,
  category           = [[KBOT MOBILE ALL NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  corpse             = [[DEAD]],
  defaultmissiontype = [[Standby]],
  description        = [[Stealthy Rez Kbot]],
  energyMake         = 1.75,
  energyStorage      = 0,
  energyUse          = 1.75,
  explodeAs          = [[BIG_UNITEX]],
  footprintX         = 2,
  footprintZ         = 2,
  idleAutoHeal       = 5,
  idleTime           = 60,
  maneuverleashlength = 640,
  maxDamage          = 200,
  maxSlope           = 14,
  maxVelocity        = 2.6,
  maxWaterDepth      = 22,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[KBOT2]],
  name               = [[Necro]],
  noAutoFire         = false,
  objectName         = [[CORNECRO]],
  radarDistance      = 50,
  resurrect          = 1,
  seismicSignature   = 0,
  selfDestructAs     = [[BIG_UNIT]],
  side               = [[CORE]],
  sightDistance      = 430,
  smoothAnim         = true,
  standingmoveorder  = 1,
  stealth            = true,
  steeringmode       = 2,
  TEDClass           = [[KBOT]],
  turnRate           = 1118,
  unitname           = [[cornecro]],
  upright            = true,
  workerTime         = 200,
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
      [[necrok2]],
    },
    select = {
      [[necrsel2]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 794,
    description        = [[Necro Wreckage]],
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 72,
    object             = [[CORNECRO_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 794,
    description        = [[Necro Heap]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 26,
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
