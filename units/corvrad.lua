-- UNITDEF -- CORVRAD --
--------------------------------------------------------------------------------

local unitName = "corvrad"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.03,
  activateWhenBuilt  = true,
  bmcode             = 1,
  brakeRate          = 0.012,
  buildCostEnergy    = 1209,
  buildCostMetal     = 86,
  builder            = false,
  buildPic           = [[corvrad.jpg]],
  buildTime          = 4223,
  canAttack          = false,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[ALL TANK MOBILE NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  copyright          = [[Copyright 1997 Humongous Entertainment. All rights reserved.]],
  corpse             = [[dead]],
  defaultmissiontype = [[Standby]],
  description        = [[Radar Vehicle]],
  energyMake         = 8,
  energyStorage      = 0,
  energyUse          = 20,
  explodeAs          = [[BIG_UNITEX]],
  footprintX         = 3,
  footprintZ         = 3,
  frenchdescription  = [[Radar mobile]],
  frenchname         = [[Scrutator]],
  germandescription  = [[Mobiles Radar]],
  germanname         = [[Informer]],
  italiandescription = [[Radar mobile]],
  italianname        = [[Informer]],
  leaveTracks        = true,
  maneuverleashlength = 640,
  maxDamage          = 510,
  maxSlope           = 16,
  maxVelocity        = 1.25,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[TANK3]],
  name               = [[Informer]],
  noAutoFire         = false,
  objectName         = [[CORVRAD]],
  onoffable          = true,
  ovradjust          = 1,
  radarDistance      = 2200,
  selfDestructAs     = [[BIG_UNIT]],
  shootme            = 1,
  side               = [[CORE]],
  sightDistance      = 900,
  smoothAnim         = true,
  sonarDistance      = 0,
  spanishdescription = [[Radar móvil]],
  spanishname        = [[Informer]],
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[TANK]],
  threed             = 1,
  trackOffset        = 0,
  trackStrength      = 10,
  trackStretch       = 1,
  trackType          = [[StdTank]],
  trackWidth         = 23,
  turnRate           = 210,
  unitname           = [[corvrad]],
  unitnumber         = 151,
  version            = 1,
  workerTime         = 0,
  zbuffer            = 1,
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
      [[vcormove]],
    },
    select = {
      [[cvradsel]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 273,
    description        = [[Informer Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 48,
    object             = [[2X2F]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  dead = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 546,
    description        = [[Informer Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 64,
    object             = [[CORVRAD_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
