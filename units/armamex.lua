-- UNITDEF -- ARMAMEX --
--------------------------------------------------------------------------------

local unitName = "armamex"

--------------------------------------------------------------------------------

local unitDef = {
  acceleration       = 0,
  activateWhenBuilt  = true,
  bmcode             = 0,
  brakeRate          = 0,
  buildAngle         = 6092,
  buildCostEnergy    = 1665,
  buildCostMetal     = 190,
  builder            = false,
  buildingGroundDecalDecaySpeed = 30,
  buildingGroundDecalSizeX = 5,
  buildingGroundDecalSizeY = 5,
  buildingGroundDecalType = [[armamex_aoplane.dds]],
  buildPic           = [[ARMAMEX.DDS]],
  buildTime          = 1800,
  category           = [[ALL NOTSUB NOWEAPON NOTAIR]],
  cloakCost          = 12,
  corpse             = [[DEAD]],
  description        = [[Stealthy Cloakable Metal Extractor]],
  energyStorage      = 0,
  energyUse          = 3,
  explodeAs          = [[TWILIGHT]],
  extractsMetal      = 0.001,
  footprintX         = 3,
  footprintZ         = 3,
  iconType           = [[building]],
  idleAutoHeal       = 5,
  idleTime           = 1800,
  initCloaked        = true,
  maxDamage          = 1450,
  maxSlope           = 20,
  maxVelocity        = 0,
  maxWaterDepth      = 0,
  metalStorage       = 75,
  minCloakDistance   = 66,
  name               = [[Twilight]],
  noAutoFire         = false,
  objectName         = [[ARMAMEX]],
  onoffable          = true,
  seismicSignature   = 0,
  selfDestructAs     = [[TWILIGHT]],
  selfDestructCountdown = 1,
  side               = [[ARM]],
  sightDistance      = 286,
  smoothAnim         = false,
  stealth            = true,
  TEDClass           = [[METAL]],
  turnRate           = 0,
  unitname           = [[armamex]],
  useBuildingGroundDecal = true,
  workerTime         = 0,
  yardMap            = [[ooooooooo]],
  sounds = {
    activate           = [[mexrun2]],
    canceldestruct     = [[cancel2]],
    deactivate         = [[mexoff2]],
    underattack        = [[warning1]],
    working            = [[mexrun2]],
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
      [[servmed2]],
    },
    select = {
      [[mexon2]],
    },
  },
}


--------------------------------------------------------------------------------

local featureDefs = {
  DEAD = {
    blocking           = true,
    category           = [[corpses]],
    damage             = 870,
    description        = [[Twilight Wreckage]],
    energy             = 0,
    featureDead        = [[HEAP]],
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    height             = 9,
    hitdensity         = 100,
    metal              = 103,
    object             = [[ARMAMEX_DEAD]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[all]],
  },
  HEAP = {
    blocking           = false,
    category           = [[heaps]],
    damage             = 435,
    description        = [[Twilight Heap]],
    energy             = 0,
    featurereclamate   = [[SMUDGE01]],
    footprintX         = 3,
    footprintZ         = 3,
    hitdensity         = 100,
    metal              = 41,
    object             = [[3X3A]],
    reclaimable        = true,
    seqnamereclamate   = [[TREE1RECLAMATE]],
    world              = [[all]],
  },
}
unitDef.featureDefs = featureDefs


--------------------------------------------------------------------------------

return lowerkeys({ [unitName] = unitDef })

--------------------------------------------------------------------------------
