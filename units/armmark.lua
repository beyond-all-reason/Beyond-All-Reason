-- UNITDEF -- ARMMARK --
--------------------------------------------------------------------------------

local unitName = "armmark"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0.045,
  activateWhenBuilt  = true,
  ai_limit           = [[limit ARMMARK 0]],
  bmcode             = 1,
  brakeRate          = 0.018,
  buildCostEnergy    = 1152,
  buildCostMetal     = 95,
  builder            = false,
  buildPic           = [[armmark.jpg]],
  buildTime          = 3800,
  canAttack          = false,
  canGuard           = true,
  canMove            = true,
  canPatrol          = true,
  canstop            = 1,
  category           = [[KBOT MOBILE ALL NOTSUB NOWEAPON NOTSHIP NOTAIR]],
  copyright          = [[Copyright 1997 Humongous Entertainment. All rights reserved.]],
  corpse             = [[dead]],
  defaultmissiontype = [[Standby]],
  description        = [[Radar Kbot]],
  designation        = [[ARM-MRB]],
  downloadable       = 1,
  energyMake         = 8,
  energyStorage      = 0,
  energyUse          = 20,
  explodeAs          = [[BIG_UNITEX]],
  footprintX         = 2,
  footprintZ         = 2,
  frenchdescription  = [[Radar KBot]],
  frenchname         = [[Marker]],
  germandescription  = [[Mobiler Radar-KBot]],
  germanname         = [[Marker]],
  italiandescription = [[KBot radar mobile]],
  italianname        = [[Marker]],
  maneuverleashlength = 640,
  maxDamage          = 320,
  maxSlope           = 16,
  maxVelocity        = 1.35,
  maxWaterDepth      = 0,
  metalStorage       = 0,
  mobilestandorders  = 1,
  movementClass      = [[KBOT2]],
  name               = [[Marky]],
  noAutoFire         = false,
  objectName         = [[ARMMARK]],
  onoffable          = true,
  radarDistance      = 2200,
  selfDestructAs     = [[BIG_UNIT]],
  shootme            = 1,
  side               = [[ARM]],
  sightDistance      = 900,
  smoothAnim         = true,
  sonarDistance      = 0,
  spanishdescription = [[Kbot de radar]],
  spanishname        = [[Marker]],
  standingmoveorder  = 1,
  steeringmode       = 1,
  TEDClass           = [[KBOT]],
  threed             = 1,
  turnRate           = 505,
  unitname           = [[armmark]],
  unitnumber         = 168,
  version            = 1.2,
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
      [[kbarmmov]],
    },
    select = {
      [[akradsel]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 256,
    description        = [[Marky Heap]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 4,
    hitdensity         = 100,
    metal              = 38,
    object             = [[2X2A]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
  dead = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 256,
    description        = [[Marky Wreckage]],
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 2,
    footprintZ         = 2,
    height             = 20,
    hitdensity         = 100,
    metal              = 76,
    object             = [[ARMMARK_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[All Worlds]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
